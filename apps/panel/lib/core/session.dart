import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import 'doc.dart';

enum PanelRole { admin, seller, delivery }

extension PanelRoleX on PanelRole {
  String get claim => switch (this) {
        PanelRole.admin => Roles.admin,
        PanelRole.seller => Roles.seller,
        PanelRole.delivery => Roles.delivery,
      };
  String get title => switch (this) {
        PanelRole.admin => 'Admin',
        PanelRole.seller => 'Seller Hub',
        PanelRole.delivery => 'Delivery',
      };
  Color get color => switch (this) {
        PanelRole.admin => G4MColors.primary,
        PanelRole.seller => const Color(0xFFE8740C),
        PanelRole.delivery => const Color(0xFF2563EB),
      };
  G4MClient get client => switch (this) {
        PanelRole.admin => G4MClient.admin,
        PanelRole.seller => G4MClient.seller,
        PanelRole.delivery => G4MClient.delivery,
      };
}

/// Profile state of the signed-in seller / delivery partner.
enum ProfileState { none, pending, approved, rejected, suspended }

/// Global auth + preference state. Drives the router guards.
class Session extends ChangeNotifier {
  Session(this.panel);
  static late Session instance;

  final PanelRole panel;
  User? user;
  String role = 'guest';
  bool ready = false;

  /// sellers/{uid} or deliveryPartners/{uid} (null for admin / missing).
  Doc? profile;
  ProfileState profileState = ProfileState.none;
  Doc? userDoc;

  /// Staff permissions (null = super admin / unrestricted).
  List<String>? permissions;
  String staffRoleName = 'Super Admin';

  ThemeMode themeMode = ThemeMode.light;
  String? moduleId; // admin module switcher, null = all modules
  Color moduleColor = G4MColors.primary;

  final _subs = <StreamSubscription>[];
  StreamSubscription? _authSub;
  final _firstReady = Completer<void>();
  Future<void> get firstReady => _firstReady.future;

  String get uid => user?.uid ?? '';
  String get displayName =>
      (profile?.s(panel == PanelRole.seller ? 'storeName' : 'name') ?? '').isNotEmpty
          ? profile!.s(panel == PanelRole.seller ? 'storeName' : 'name')
          : (userDoc?.s('name') ?? '').isNotEmpty
              ? userDoc!.s('name')
              : user?.displayName ?? user?.email ?? 'User';

  bool get signedIn => user != null && !user!.isAnonymous;
  bool get authorized => signedIn && role == panel.claim;
  bool get approved => panel == PanelRole.admin ? authorized : authorized && profileState == ProfileState.approved;

  Color get accent => panel == PanelRole.admin ? moduleColor : panel.color;

  bool can(String permission) => permissions == null || permissions!.contains(permission);

  void start() {
    _authSub = FirebaseAuth.instance.idTokenChanges().listen(_onUser);
  }

  Future<void> _onUser(User? u) async {
    // Token refresh for the same user (hourly, or after refreshClaims): only update the
    // role claim; keep profile listeners so guards don't momentarily see "no profile".
    if (u != null && user != null && u.uid == user!.uid && _subs.isNotEmpty) {
      user = u;
      String? r;
      try {
        final t = await u.getIdTokenResult();
        r = (t.claims?['role'] as String?) ?? Roles.customer;
      } catch (_) {}
      // Same role → nothing to rebuild. A changed role falls through to a full re-init
      // (e.g. customer → seller after registerSeller) so the right listeners start.
      if (r == null || r == role) return;
    }
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    user = u;
    profile = null;
    userDoc = null;
    permissions = null;
    profileState = ProfileState.none;
    if (u == null || u.isAnonymous) {
      role = 'guest';
      _markReady();
      return;
    }
    try {
      final t = await u.getIdTokenResult();
      role = (t.claims?['role'] as String?) ?? Roles.customer;
    } catch (_) {
      role = Roles.customer;
    }
    _subs.add(Fs.user(u.uid).snapshots().listen((d) {
      userDoc = d.exists ? Doc.fromSnap(d) : null;
      notifyListeners();
    }, onError: (_) {}));

    switch (panel) {
      case PanelRole.admin:
        if (role != Roles.admin) {
          _markReady();
          return;
        }
        var gotStaff = false;
        _subs.add(Fs.staff.doc(u.uid).snapshots().listen((d) async {
          if (!d.exists || (d.data()?['roleId'] ?? '') == '') {
            permissions = null;
            staffRoleName = 'Super Admin';
          } else {
            try {
              final r = await Fs.adminRoles.doc('${d.data()!['roleId']}').get();
              final perms = (r.data()?['permissions'] as List?)?.map((e) => '$e').toList();
              staffRoleName = '${r.data()?['name'] ?? 'Staff'}';
              permissions = (perms == null || perms.contains('*')) ? null : perms;
            } catch (_) {
              permissions = null;
            }
          }
          if (!gotStaff) {
            gotStaff = true;
            _markReady();
          }
          notifyListeners();
        }, onError: (_) {
          if (!gotStaff) {
            gotStaff = true;
            _markReady();
          }
        }));
      case PanelRole.seller:
      case PanelRole.delivery:
        final ref = panel == PanelRole.seller ? Fs.sellers.doc(u.uid) : Fs.deliveryPartners.doc(u.uid);
        var first = true;
        _subs.add(ref.snapshots().listen((d) async {
          final prevState = profileState;
          profile = d.exists ? Doc.fromSnap(d) : null;
          profileState = _stateOf(profile);
          // Claim might have been granted after approval/registration; refresh token once.
          if (prevState != profileState && profile != null && role != panel.claim) {
            try {
              final t = await u.getIdTokenResult(true);
              role = (t.claims?['role'] as String?) ?? role;
            } catch (_) {}
          }
          if (first) {
            first = false;
            _markReady();
          }
          notifyListeners();
        }, onError: (_) {
          if (first) {
            first = false;
            _markReady();
          }
          notifyListeners();
        }));
    }
    notifyListeners();
  }

  ProfileState _stateOf(Doc? p) {
    if (p == null) return ProfileState.none;
    return switch (p.s('status', 'pending')) {
      'approved' => ProfileState.approved,
      'rejected' => ProfileState.rejected,
      'suspended' => ProfileState.suspended,
      _ => ProfileState.pending,
    };
  }

  void _markReady() {
    ready = true;
    if (!_firstReady.isCompleted) _firstReady.complete();
    notifyListeners();
  }

  /// Force-refresh the ID token (after a callable changed custom claims).
  Future<void> refreshClaims() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final t = await u.getIdTokenResult(true);
    role = (t.claims?['role'] as String?) ?? Roles.customer;
    notifyListeners();
  }

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setModule(String? id, Color color) {
    moduleId = id;
    moduleColor = color;
    notifyListeners();
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

/// Shortcut used across features.
Session get session => Session.instance;

FieldValue get serverNow => FieldValue.serverTimestamp();
