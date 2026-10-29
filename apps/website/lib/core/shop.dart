import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:g4m_core/g4m_core.dart';

import '../l10n/l10n.dart';
import 'cart_merge.dart';
import 'web_bridge.dart';

/// Outcome of a Google or phone sign-in.
class SocialOutcome {
  SocialOutcome({required this.user, required this.needsProfile}) : error = null;
  SocialOutcome.failed(Object this.error)
      : user = null,
        needsProfile = false;
  final User? user;
  final bool needsProfile;
  final Object? error;
}

/// An OTP that has been sent; [confirm] finishes sign-in with the 6-digit code.
class PhoneSignIn {
  PhoneSignIn._(this._shop, this._c, this._guest);
  final Shop _shop;
  final ConfirmationResult _c;
  final List<Map<String, dynamic>> _guest;
  Future<SocialOutcome> confirm(String code) async => _shop._afterSocial(await _c.confirm(code), _guest);
}

/// App-wide shopper state: auth, profile, cart, wishlist and cached catalogue metadata.
/// Everything is live (Firestore snapshots) so admin-panel changes show up immediately.
class Shop extends ChangeNotifier {
  Shop._();
  static final instance = Shop._();

  User? user;
  AppUser? profile;
  PlatformSettings settings = PlatformSettings(const {});
  PaymentSettings payments = PaymentSettings(const {});
  List<MarketModule> modules = const [];
  List<Category> categories = const [];
  bool catalogReady = false;

  /// True once Firebase has restored (or failed to restore) a persisted session.
  bool authResolved = false;
  Map<String, CartItem> cart = {};
  Set<String> wishlist = {};

  /// Increments each time something is added so the header badge can bump.
  final cartBump = ValueNotifier<int>(0);
  final city = ValueNotifier<String?>(WebBridge.local('g4m_city'));

  final _userSubs = <StreamSubscription>[];
  bool _started = false;

  bool get isGuest => user == null || user!.isAnonymous;
  bool get signedIn => user != null && !user!.isAnonymous;
  int get cartCount => cart.values.fold(0, (a, b) => a + b.qty);
  double get walletBalance => profile?.walletBalance ?? 0;

  void init() {
    if (_started) return;
    _started = true;
    SettingsRepo.instance.platform().listen((s) {
      settings = s;
      notifyListeners();
    }, onError: (_) {});
    SettingsRepo.instance.payments().listen((p) {
      payments = p;
      notifyListeners();
    }, onError: (_) {});
    CatalogRepo.instance.modules().listen((m) {
      modules = m;
      notifyListeners();
    }, onError: (_) {});
    Fs.categories.where('active', isEqualTo: true).snapshots().listen((s) {
      categories = s.docs.map(Category.fromDoc).toList()..sort((a, b) => a.order.compareTo(b.order));
      catalogReady = true;
      notifyListeners();
    }, onError: (_) {
      catalogReady = true;
      notifyListeners();
    });
    FirebaseAuth.instance.authStateChanges().listen(_onAuth);
    final redirecting = WebBridge.session(_redirectKey) != null;
    if (redirecting) unawaited(_finishRedirect());
    if (FirebaseAuth.instance.currentUser == null && !redirecting) {
      // Restore a persisted session first; only fall back to an anonymous guest if none.
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (FirebaseAuth.instance.currentUser == null) ensureUser();
      });
    }
  }

  void _onAuth(User? u) {
    for (final s in _userSubs) {
      s.cancel();
    }
    _userSubs.clear();
    authResolved = true;
    user = u;
    profile = null;
    cart = {};
    wishlist = {};
    notifyListeners();
    if (u == null) return;
    _userSubs.add(Fs.cart(u.uid).snapshots().listen((s) {
      cart = {for (final d in s.docs) d.id: CartItem.fromDoc(d)};
      notifyListeners();
    }, onError: (_) {}));
    _userSubs.add(Fs.wishlist(u.uid).snapshots().listen((s) {
      wishlist = s.docs.map((d) => d.id).toSet();
      notifyListeners();
    }, onError: (_) {}));
    _userSubs.add(Fs.user(u.uid).snapshots().listen((d) {
      profile = d.exists ? AppUser.fromDoc(d) : null;
      if (!u.isAnonymous) LangController.instance.adoptFromProfile(d.data()?['lang'] as String?);
      notifyListeners();
    }, onError: (_) {}));
  }

  Future<bool> ensureUser() async {
    if (FirebaseAuth.instance.currentUser != null) return true;
    try {
      await AuthRepo.instance.guest();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------- cart ----------------
  int qty(String productId, [String variantId = 'default']) => cart['${productId}_$variantId']?.qty ?? 0;

  Future<void> setQty(Product p, int q, {String variantId = 'default'}) async {
    if (!await ensureUser()) throw Exception(L.current.common.signInForCart);
    final id = '${p.id}_$variantId';
    final old = cart[id]?.qty ?? 0;
    if (q > old) cartBump.value++;
    // Optimistic update so the stepper feels instant.
    if (q <= 0) {
      cart.remove(id);
    } else {
      cart[id] = CartItem(id, {'productId': p.id, 'variantId': variantId, 'qty': q, 'sellerId': p.sellerId});
    }
    notifyListeners();
    await ShopperRepo.instance.setCartQty(p, q, variantId: variantId);
  }

  /// Adds a customised line (food add-ons / modifiers). Lines with different add-ons are separate cart docs.
  Future<void> addWithAddons(Product p, String variantId, List<String> addonIds, {int qty = 1}) async {
    if (!await ensureUser()) throw Exception(L.current.common.signInForCart);
    final ids = [...addonIds]..sort();
    final id = cartLineId(p.id, variantId, ids);
    final next = (cart[id]?.qty ?? 0) + qty;
    cartBump.value++;
    final data = {'productId': p.id, 'variantId': variantId, 'qty': next, 'sellerId': p.sellerId, 'addonIds': ids};
    cart[id] = CartItem(id, data);
    notifyListeners();
    await Fs.cart(user!.uid).doc(id).set({...data, 'addedAt': Fs.now}, SetOptions(merge: true));
  }

  /// Sets the quantity of an existing cart line by its doc id (used for customised lines).
  Future<void> setLineQty(CartItem c, int q) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    if (q <= 0) return removeItem(c.id);
    if (q > c.qty) cartBump.value++;
    cart[c.id] = CartItem(c.id, {...c.data, 'qty': q});
    notifyListeners();
    await Fs.cart(u.uid).doc(c.id).set({'qty': q}, SetOptions(merge: true));
  }

  Future<void> removeItem(String itemId) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    cart.remove(itemId);
    notifyListeners();
    await Fs.cart(u.uid).doc(itemId).delete();
  }

  // ---------------- wishlist ----------------
  bool wished(String productId) => wishlist.contains(productId);
  Future<void> toggleWish(String productId) async {
    if (!await ensureUser()) throw Exception(L.current.common.signInToSave);
    final on = !wishlist.contains(productId);
    on ? wishlist.add(productId) : wishlist.remove(productId);
    notifyListeners();
    await ShopperRepo.instance.toggleWishlist(productId, on);
  }

  // ---------------- auth with guest-cart merge ----------------
  Future<List<Map<String, dynamic>>> _guestCart() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || !u.isAnonymous) return const [];
    try {
      final s = await Fs.cart(u.uid).get();
      return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _merge(List<Map<String, dynamic>> items) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || items.isEmpty) return;
    final ref = Fs.cart(u.uid);
    final existing = {for (final d in (await ref.get()).docs) d.id: (d.data()['qty'] as num?)?.toInt() ?? 0};
    final b = Fs.db.batch();
    for (final it in items) {
      // Keeps the doc id and addonIds exactly as stored, so customised food lines survive sign-in.
      final line = mergedCartLine(it, existing[it['id']]);
      b.set(ref.doc(line.id), {...line.data, 'addedAt': Fs.now}, SetOptions(merge: true));
    }
    await b.commit();
  }

  Future<void> signIn(String email, String password) async {
    final guest = await _guestCart();
    await AuthRepo.instance.signIn(email, password);
    try {
      await _merge(guest);
    } catch (_) {}
  }

  Future<void> signUp({required String name, required String email, required String password, String? phone, String? referralCode}) async {
    final guest = await _guestCart();
    await AuthRepo.instance.signUp(name: name, email: email, password: password, phone: phone, referralCode: referralCode);
    try {
      await _merge(guest);
    } catch (_) {}
  }

  // ---------------- Google + phone sign-in ----------------
  static const _redirectKey = 'g4m_auth_redirect';

  /// Result of a Google redirect sign-in that completed on this page load (consumed by the auth pages).
  final redirectOutcome = ValueNotifier<SocialOutcome?>(null);

  /// Google sign-in in a popup; falls back to a full-page redirect when the popup is blocked.
  /// Returns null when the browser is navigating away for the redirect.
  Future<SocialOutcome?> signInWithGoogle() async {
    final guest = await _guestCart();
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    UserCredential cred;
    try {
      cred = await FirebaseAuth.instance.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'popup-blocked' && e.code != 'operation-not-supported-in-this-environment') rethrow;
      // Guest cart docs belong to the anonymous uid, which is gone after the redirect: stash them.
      // Only JSON-safe fields (docs also carry an `addedAt` Timestamp).
      const keep = {'id', 'productId', 'variantId', 'sellerId', 'qty', 'addonIds'};
      WebBridge.setSession(_redirectKey, jsonEncode([for (final g in guest) {for (final e in g.entries) if (keep.contains(e.key)) e.key: e.value}]));
      await FirebaseAuth.instance.signInWithRedirect(provider);
      return null;
    }
    return _afterSocial(cred, guest);
  }

  Future<void> _finishRedirect() async {
    final raw = WebBridge.session(_redirectKey);
    WebBridge.setSession(_redirectKey, null);
    try {
      final cred = await FirebaseAuth.instance.getRedirectResult();
      if (cred.user == null) {
        if (FirebaseAuth.instance.currentUser == null) await ensureUser();
        return;
      }
      final guest = raw == null ? const <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from((jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)));
      redirectOutcome.value = await _afterSocial(cred, guest);
    } catch (e) {
      redirectOutcome.value = SocialOutcome.failed(e);
      if (FirebaseAuth.instance.currentUser == null) await ensureUser();
    }
  }

  /// Sends the OTP. Firebase renders an invisible reCAPTCHA (RecaptchaVerifier) for the request.
  Future<PhoneSignIn> startPhoneSignIn(String e164) async {
    final guest = await _guestCart();
    final confirmation = await FirebaseAuth.instance.signInWithPhoneNumber(e164);
    return PhoneSignIn._(this, confirmation, guest);
  }

  Future<SocialOutcome> _afterSocial(UserCredential cred, List<Map<String, dynamic>> guest) async {
    try {
      await _merge(guest);
    } catch (_) {}
    final u = cred.user!;
    var needsProfile = cred.additionalUserInfo?.isNewUser ?? false;
    if (!needsProfile) {
      try {
        final d = await Fs.user(u.uid).get();
        final name = (d.data()?['name'] as String?)?.trim() ?? '';
        needsProfile = name.isEmpty;
      } catch (_) {}
    }
    return SocialOutcome(user: u, needsProfile: needsProfile);
  }

  /// Saves the "Complete your profile" step via the `completeProfile` callable,
  /// or merges into `users/{uid}` while the callable is not deployed.
  Future<void> completeProfile({required String name, String? email, String? phone, String? referralCode}) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final ref = referralCode?.trim().toUpperCase();
    final payload = <String, dynamic>{
      'name': name.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (ref != null && ref.isNotEmpty) 'referralCode': ref,
    };
    try {
      await FirebaseFunctions.instanceFor(region: kFunctionsRegion).httpsCallable('completeProfile').call<dynamic>(payload);
    } on FirebaseFunctionsException catch (e) {
      if (!const {'not-found', 'internal', 'unimplemented', 'unavailable'}.contains(e.code)) rethrow;
      final doc = await Fs.user(u.uid).get();
      await Fs.user(u.uid).set({
        'name': payload['name'],
        'email': ?payload['email'],
        'phone': ?payload['phone'],
        if (ref != null && ref.isNotEmpty && doc.data()?['referredBy'] == null) 'referredBy': ref,
        'lang': LangController.instance.code,
        'updatedAt': Fs.now,
      }, SetOptions(merge: true));
    }
    try {
      await u.updateDisplayName(name.trim());
    } catch (_) {}
  }

  Future<void> signOut() async {
    await AuthRepo.instance.signOut();
    await ensureUser();
  }

  // ---------------- location ----------------
  void setCity(String? c) {
    city.value = c;
    WebBridge.setLocal('g4m_city', c);
  }

  // ---------------- catalogue lookups ----------------
  MarketModule? module(String id) => modules.where((m) => m.id == id).firstOrNull;
  Category? categoryBySlug(String slug) => categories.where((c) => c.slug == slug || c.id == slug).firstOrNull;
  Category? categoryById(String id) => categories.where((c) => c.id == id).firstOrNull;
  List<Category> roots([String? moduleId]) =>
      categories.where((c) => (c.parentId == null || c.parentId!.isEmpty) && (moduleId == null || c.moduleId == moduleId)).toList();
  List<Category> children(String parentId) => categories.where((c) => c.parentId == parentId).toList();
  List<Category> trail(Category c) => [...c.path.map(categoryById).whereType<Category>(), c];

  /// Recently-viewed ids. Signed-in shoppers sync to `users/{uid}.recentlyViewed`; guests keep a local copy too.
  List<String> get recentlyViewed {
    final remote = profile?.recentlyViewed ?? const <String>[];
    if (remote.isNotEmpty) return remote;
    final raw = WebBridge.local('g4m_recent');
    return raw == null ? const [] : List<String>.from(jsonDecode(raw) as List);
  }

  Future<void> markViewed(String productId) async {
    final l = [...recentlyViewed]
      ..remove(productId)
      ..insert(0, productId);
    WebBridge.setLocal('g4m_recent', jsonEncode(l.take(20).toList()));
    try {
      await ShopperRepo.instance.markViewed(productId);
    } catch (_) {}
  }
}
