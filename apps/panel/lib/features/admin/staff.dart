import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide kIsWasm;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../panels/admin_spec.dart' show adminPermissions;
import '../../ui/crud.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'people_common.dart';
import 'package:panel/l10n/overrides.dart';

Stream<Map<String, String>> _roleOptions() => optionsOf(Fs.adminRoles, 'name');

// ═══════════════════════════════ STAFF ═══════════════════════════════

class StaffPage extends StatelessWidget {
  const StaffPage({super.key});

  Future<void> _create(BuildContext context) => openEditor(
        context,
        title: 'Invite staff user',
        subtitle: 'Creates an admin login limited by the selected role',
        saveLabel: 'Create user',
        width: 520,
        fields: [
          const F('name', 'Full name', FT.text, required: true, wide: true),
          const F('email', 'Email', FT.email, required: true, wide: true),
          F('password', 'Temporary password', FT.password, required: true, wide: true, validator: (v, _) => '$v'.length < 8 ? 'At least 8 characters' : null),
          F('roleId', 'Role', FT.select, optionsStream: _roleOptions, required: true, wide: true, help: 'Manage roles under Staff › Roles'),
        ],
        onSave: (v) async {
          final r = await G4MApi.instance.createStaffUser({'email': '${v['email']}'.trim(), 'password': v['password'], 'name': '${v['name']}'.trim(), 'role': Roles.admin});
          final uid = '${r['uid'] ?? ''}';
          if (uid.isEmpty) throw 'createStaffUser did not return a uid';
          await Fs.staff.doc(uid).set({'name': '${v['name']}'.trim(), 'email': '${v['email']}'.trim().toLowerCase(), 'roleId': v['roleId'], 'createdAt': ts, 'updatedAt': ts}, SetOptions(merge: true));
        },
      );

  Future<void> _changeRole(BuildContext context, Doc d) => openEditor(
        context,
        title: 'Change role · ${d.s('name')}',
        width: 460,
        initial: {'roleId': d.s('roleId')},
        fields: [F('roleId', 'Role', FT.select, optionsStream: _roleOptions, required: true, wide: true)],
        onSave: (v) => d.ref!.update({'roleId': v['roleId'], 'updatedAt': ts}),
      );

  Future<void> _remove(BuildContext context, Doc d) async {
    if (d.id == session.uid) {
      toast('You cannot remove your own access', kind: ToastKind.error);
      return;
    }
    if (!await confirm(context, 'Remove ${d.s('name')} from staff?', message: 'Their admin access is revoked (role set back to customer).', danger: true, confirmLabel: 'Remove access')) return;
    await runToast(() async {
      await G4MApi.instance.setUserRole(d.id, Roles.customer);
      await d.ref!.delete();
    }, success: 'Access removed');
  }

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Staff users',
        subtitle: 'Admin panel accounts and the role that limits what each can see',
        actions: [FilledButton.icon(onPressed: () => _create(context), icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: Text(tr('Invite staff')))],
        child: StreamBuilder<Map<String, String>>(
          stream: _roleOptions(),
          builder: (context, roles) => DataView<Doc>(
            id: 'staff',
            source: (q) => recent(Fs.staff, q.limit, label: 'staff_createdAt'),
            rowId: (d) => d.id,
            searchText: (d) => '${d.s('name')} ${d.s('email')} ${roles.data?[d.s('roleId')] ?? ''}',
            filters: [TableFilter('role', 'Role', roles.data ?? const {}, test: (d, v) => d.s('roleId') == v)],
            leading: (c, d) => Avatar(name: d.s('name', d.s('email')), size: 38),
            onTap: (d) => _changeRole(context, d),
            actions: [
              RowAction('Change role', Icons.manage_accounts_outlined, (d) => _changeRole(context, d)),
              RowAction('Remove access', Icons.person_remove_outlined, (d) => _remove(context, d), danger: true),
            ],
            emptyIcon: Icons.admin_panel_settings_outlined,
            emptyTitle: 'No staff users yet',
            emptyMessage: 'Admins without a staff record have full (super admin) access.',
            columns: [
              Col('User', flex: 4, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), d.s('email'), d.id == session.uid ? Tag('You', color: c.pal.accent) : null)),
              Col('Role', flex: 3, text: (d) => roles.data?[d.s('roleId')] ?? d.s('roleId'),
                  cell: (c, d) => Tag(roles.data?[d.s('roleId')] ?? (d.s('roleId').isEmpty ? 'Super admin' : d.s('roleId')), color: G4MColors.info, icon: Icons.shield_outlined)),
              Col('Added', flex: 2, text: (d) => Fmt.date(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
            ],
          ),
        ),
      );
}

// ═══════════════════════════════ ROLES ═══════════════════════════════

class RolesPage extends StatelessWidget {
  const RolesPage({super.key});

  Widget _permEditor(BuildContext context, dynamic value, ValueChanged<dynamic> onChanged) {
    final sel = value is List ? value.map((e) => '$e').toSet() : <String>{};
    final full = sel.contains('*');
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Permissions', helperText: 'Sections of the admin panel this role can open'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: full,
          title: const Text('Full access (super admin)', style: TextStyle(fontWeight: FontWeight.w800)),
          onChanged: (v) => onChanged(v == true ? ['*'] : <String>[]),
        ),
        const Divider(),
        Wrap(children: [
          for (final e in adminPermissions.entries)
            SizedBox(
              width: 250,
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: full || sel.contains(e.key),
                title: Text(e.value),
                subtitle: Text(e.key, style: TextStyle(fontSize: 11, color: context.pal.faint)),
                onChanged: full
                    ? null
                    : (v) {
                        final n = {...sel};
                        v == true ? n.add(e.key) : n.remove(e.key);
                        onChanged(n.toList());
                      },
              ),
            ),
        ]),
        Row(children: [
          TextButton(onPressed: full ? null : () => onChanged(adminPermissions.keys.toList()), child: Text(tr('Select all'))),
          TextButton(onPressed: () => onChanged(<String>[]), child: Text(tr('Clear'))),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'admin_roles',
        title: 'Roles & permissions',
        singular: 'Role',
        subtitle: 'Group permissions and assign them to staff users',
        collection: Fs.adminRoles,
        activeField: null,
        labelOf: (d) => d.s('name'),
        search: (d) => '${d.s('name')} ${d.s('description')} ${d.list('permissions').join(' ')}',
        editorWidth: 640,
        fields: [
          const F('name', 'Role name', FT.text, required: true, wide: true),
          const F('description', 'Description', FT.text, wide: true),
          F('permissions', 'Permissions', FT.custom, wide: true, initial: const <String>[], builder: (c, v, on, _) => _permEditor(c, v, on),
              validator: (v, _) => v is List && v.isNotEmpty ? null : 'Pick at least one permission'),
        ],
        beforeSave: (v, _) => {...v, 'permissions': (v['permissions'] as List? ?? const []).map((e) => '$e').toList()},
        columns: [
          Col('Role', flex: 3, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), d.s('description'))),
          Col('Permissions', flex: 6, text: (d) => d.list('permissions').join(', '), cell: (c, d) {
            final p = d.list('permissions');
            if (p.contains('*')) return const Tag('Full access', color: G4MColors.success, icon: Icons.all_inclusive_rounded);
            return Wrap(spacing: 4, runSpacing: 4, children: [
              for (final k in p.take(5)) Tag(adminPermissions[k]?.split(' ').first ?? k),
              if (p.length > 5) Tag('+${p.length - 5}'),
            ]);
          }),
          Col('Updated', flex: 2, text: (d) => Fmt.date(d.dt('updatedAt')), sort: (d) => d.dt('updatedAt')?.millisecondsSinceEpoch ?? 0),
        ],
        top: const _RoleHint(),
      ));
}

class _RoleHint extends StatelessWidget {
  const _RoleHint();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: G4MColors.info.withValues(alpha: .07), borderRadius: BorderRadius.circular(12), border: Border.all(color: G4MColors.info.withValues(alpha: .25))),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: G4MColors.info, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text('Seller and Delivery roles are built in (their own panels). Roles here apply to admin staff only; '
                'an admin with no staff record is a super admin.'),
          ),
        ]),
      );
}

// ═══════════════════════════════ SYSTEM ═══════════════════════════════

class _Check {
  _Check(this.label, this.ok, this.detail, [this.ms]);
  final String label;
  final bool ok;
  final String detail;
  final int? ms;
}

class SystemPage extends StatefulWidget {
  const SystemPage({super.key});
  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  static const _collections = ['users', 'sellers', 'deliveryPartners', 'products', 'categories', 'orders', 'returns', 'withdrawals', 'coupons', 'reviews'];
  List<_Check>? _checks;
  Map<String, int?> _counts = {};
  Doc? _lastOrder;
  Doc? _overview;
  bool _running = false;
  DateTime? _ranAt;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final checks = <_Check>[];

    // Cloud Functions reachability.
    final sw = Stopwatch()..start();
    try {
      await G4MApi.instance.call('validateCoupon', {'code': '__PING__', 'subtotal': 0});
      checks.add(_Check('Cloud Functions (asia-south1)', true, 'Reachable', sw.elapsedMilliseconds));
    } on FirebaseFunctionsException catch (e) {
      final down = e.code == 'unavailable' || e.code == 'not-found' || e.code == 'internal' && (e.message ?? '').contains('fetch');
      checks.add(_Check('Cloud Functions (asia-south1)', !down, down ? '${e.code}: ${e.message}' : 'Reachable (${e.code})', sw.elapsedMilliseconds));
    } catch (e) {
      checks.add(_Check('Cloud Functions (asia-south1)', false, friendlyError(e), sw.elapsedMilliseconds));
    }

    // Firestore round-trip.
    sw.reset();
    try {
      final d = await Fs.statsOverview.get(const GetOptions(source: Source.server));
      _overview = d.exists ? Doc.fromSnap(d) : null;
      checks.add(_Check('Firestore', true, 'Server read OK', sw.elapsedMilliseconds));
    } catch (e) {
      checks.add(_Check('Firestore', false, friendlyError(e), sw.elapsedMilliseconds));
    }

    // Auth token.
    try {
      final t = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
      checks.add(_Check('Auth session', t != null, 'Role claim: ${t?.claims?['role'] ?? '—'} · expires ${Fmt.time(t?.expirationTime)}'));
    } catch (e) {
      checks.add(_Check('Auth session', false, friendlyError(e)));
    }

    // Stats freshness.
    final upd = _overview?.dt('updatedAt');
    checks.add(_Check('Stats aggregation (stats/overview)', _overview != null,
        _overview == null ? 'Not written yet — dashboard falls back to live queries' : 'Last updated ${Fmt.ago(upd)}'));

    // Counts + last order in parallel.
    final counts = <String, int?>{};
    await Future.wait([
      for (final c in _collections)
        (c == 'reviews' ? Fs.db.collectionGroup('reviews').count().get() : Fs.col(c).count().get())
            .then((s) => counts[c] = s.count)
            .catchError((_) => counts[c] = null),
      Fs.orders.orderBy('createdAt', descending: true).limit(1).get().then((s) => _lastOrder = s.docs.isEmpty ? null : Doc.fromSnap(s.docs.first)).catchError((_) => null),
    ]);
    checks.add(_Check('Order flow', _lastOrder != null, _lastOrder == null ? 'No orders yet' : 'Last order ${_lastOrder!.s('orderNo')} · ${Fmt.ago(_lastOrder!.createdAt)}'));

    if (!mounted) return;
    setState(() {
      _checks = checks;
      _counts = counts;
      _running = false;
      _ranAt = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final checks = _checks;
    final healthy = checks?.every((c) => c.ok) ?? false;
    return PanelPage(
      title: 'System health',
      subtitle: _ranAt == null ? 'Running checks…' : 'Checked ${Fmt.time(_ranAt)}',
      actions: [AsyncButton(onPressed: _running ? null : _run, icon: Icons.refresh_rounded, label: 'Run checks again', outlined: true)],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (checks != null)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: (healthy ? G4MColors.success : G4MColors.warning).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (healthy ? G4MColors.success : G4MColors.warning).withValues(alpha: .3)),
            ),
            child: Row(children: [
              Icon(healthy ? Icons.verified_rounded : Icons.warning_amber_rounded, color: healthy ? G4MColors.success : G4MColors.warning, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Text(healthy ? 'All systems operational' : '${checks.where((c) => !c.ok).length} check(s) need attention',
                    style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        const SizedBox(height: 16),
        ResponsiveGrid(minItemWidth: 420, children: [
          SectionCard(
            title: 'Service checks',
            icon: Icons.monitor_heart_outlined,
            child: checks == null
                ? const LoadingBlock(rows: 4)
                : Column(children: [
                    for (final c in checks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(c.ok ? Icons.check_circle_rounded : Icons.error_rounded, color: c.ok ? G4MColors.success : G4MColors.danger),
                        title: Text(c.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(c.detail),
                        trailing: c.ms == null
                            ? null
                            : Tag('${c.ms} ms', color: c.ms! < 600 ? G4MColors.success : c.ms! < 2000 ? G4MColors.warning : G4MColors.danger),
                      ),
                  ]),
          ),
          SectionCard(
            title: 'Data volume',
            icon: Icons.storage_rounded,
            child: _counts.isEmpty
                ? const LoadingBlock(rows: 4)
                : Column(children: [
                    for (final c in _collections) InfoRow(Fmt.titleCase(c.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}')), _counts[c] == null ? 'n/a' : Fmt.number(_counts[c]!)),
                  ]),
          ),
          SectionCard(
            title: 'Build',
            icon: Icons.info_outline_rounded,
            child: Column(children: [
              InfoRow('Panel', 'Go4Market ${session.panel.title}'),
              InfoRow('Host', Uri.base.host),
              InfoRow('Renderer', kIsWasm ? 'WebAssembly' : 'JavaScript (CanvasKit)'),
              InfoRow('Mode', kReleaseMode ? 'Release' : kProfileMode ? 'Profile' : 'Debug'),
              InfoRow('Firebase project', G4MFirebaseOptions.web.projectId),
              const InfoRow('Functions region', kFunctionsRegion),
              InfoRow('Signed in as', '${session.user?.email} (${session.staffRoleName})'),
            ]),
          ),
          SectionCard(
            title: 'Platform totals',
            subtitle: 'From stats/overview (function-maintained)',
            icon: Icons.analytics_outlined,
            child: _overview == null
                ? Text('No aggregate stats yet', style: TextStyle(color: context.pal.muted))
                : Column(children: [
                    for (final k in const ['orders', 'revenue', 'customers', 'sellers', 'products', 'delivered', 'pending', 'cancelled'])
                      InfoRow(Fmt.titleCase(k), k == 'revenue' ? Fmt.money(_overview!.n(k)) : Fmt.number(_overview!.n(k))),
                  ]),
          ),
        ]),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: IndexLog.instance,
          builder: (context, _) {
            final e = IndexLog.instance.entries;
            return SectionCard(
              title: 'Firestore indexes requested this session',
              subtitle: e.isEmpty ? 'No missing-index errors so far — views fell back gracefully if any occurred.' : 'Open each link (or add to firestore.indexes.json) to build the index.',
              icon: Icons.account_tree_outlined,
              child: e.isEmpty
                  ? const SizedBox()
                  : Column(children: [
                      for (final x in e.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.hourglass_top_rounded, color: G4MColors.warning),
                          title: Text(x.key, style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                          subtitle: SelectableText(x.value, maxLines: 3),
                          trailing: IconButton(
                            tooltip: 'Copy',
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: x.value));
                              toast('Copied');
                            },
                          ),
                        ),
                    ]),
            );
          },
        ),
      ]),
    );
  }
}

// ═══════════════════════════════ ACCOUNT ═══════════════════════════════

const _notifyStatuses = [
  'placed',
  'pending',
  'confirmed',
  'packed',
  'assigned',
  'picked_up',
  'out_for_delivery',
  'ready_for_pickup',
  'delivered',
  'cancelled',
  'returned',
  'return_requested',
];

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final _name = TextEditingController(text: session.userDoc?.s('name') ?? session.user?.displayName ?? '');
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  final _pwKey = GlobalKey<FormState>();
  Map<String, dynamic>? _prefs;
  bool _prefsDirty = false;
  late final StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = Fs.col('settings').doc('notifications').snapshots().listen((d) {
      if (_prefsDirty) return;
      setState(() => _prefs = deepCopy(d.data() ?? <String, dynamic>{}));
    }, onError: (_) => setState(() => _prefs = <String, dynamic>{}));
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _saveName() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    await runToast(() async {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(n);
      await Fs.user(session.uid).set({'name': n, 'updatedAt': ts}, SetOptions(merge: true));
      if ((await Fs.staff.doc(session.uid).get()).exists) await Fs.staff.doc(session.uid).update({'name': n});
    }, success: 'Name updated');
  }

  Future<void> _changePassword() async {
    if (!_pwKey.currentState!.validate()) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.email == null) return;
    final ok = await runToast(() async {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: _cur.text));
      await u.updatePassword(_new.text);
    }, success: 'Password changed');
    if (ok) {
      _cur.clear();
      _new.clear();
      _confirm.clear();
    }
  }

  bool _flag(String status, String ch) => getPath(_prefs ?? const {}, 'statuses.$status.$ch') == true;

  void _setFlag(String status, String ch, bool v) => setState(() {
        _prefsDirty = true;
        setPath(_prefs ??= <String, dynamic>{}, 'statuses.$status.$ch', v);
      });

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'My account',
        subtitle: session.user?.email,
        maxWidth: 1100,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ResponsiveGrid(minItemWidth: 420, children: [
            SectionCard(
              title: 'Profile',
              icon: Icons.person_outline_rounded,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Avatar(name: session.displayName, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(session.displayName, style: context.tt.titleMedium),
                      Text('${session.staffRoleName} · ${session.user?.email}', style: TextStyle(color: context.pal.muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Display name')),
                const SizedBox(height: 12),
                Align(alignment: AlignmentDirectional.centerEnd, child: AsyncButton(onPressed: _saveName, icon: Icons.check_rounded, label: 'Save name')),
              ]),
            ),
            SectionCard(
              title: 'Change password',
              icon: Icons.lock_outline_rounded,
              child: Form(
                key: _pwKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(controller: _cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password'), validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'New password'), validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password'), validator: (v) => v != _new.text ? 'Passwords do not match' : null),
                  const SizedBox(height: 12),
                  Align(alignment: AlignmentDirectional.centerEnd, child: AsyncButton(onPressed: _changePassword, icon: Icons.key_rounded, label: 'Update password')),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Order notification settings',
            subtitle: 'Which order status changes notify customers, per channel (read by the notification functions)',
            icon: Icons.notifications_active_outlined,
            trailing: AsyncButton(
              onPressed: _prefs == null
                  ? null
                  : () async {
                      final ok = await runToast(
                          () => Fs.col('settings').doc('notifications').set({...?_prefs, 'updatedAt': ts}, SetOptions(merge: true)),
                          success: 'Notification settings saved');
                      if (ok && mounted) setState(() => _prefsDirty = false);
                    },
              icon: Icons.save_outlined,
              label: _prefsDirty ? 'Save changes' : 'Saved',
            ),
            child: _prefs == null
                ? const LoadingBlock(rows: 4)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      color: context.pal.surfaceAlt.withValues(alpha: .6),
                      child: const Row(children: [
                        Expanded(flex: 3, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6))),
                        Expanded(child: Center(child: Text('EMAIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)))),
                        Expanded(child: Center(child: Text('SMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)))),
                        Expanded(child: Center(child: Text('PUSH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .6)))),
                      ]),
                    ),
                    for (final st in _notifyStatuses)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.line))),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(st == 'return_requested' ? 'Return requested' : OrderStatus.label(st), style: const TextStyle(fontWeight: FontWeight.w600))),
                          for (final ch in const ['email', 'sms', 'push'])
                            Expanded(child: Center(child: Checkbox(value: _flag(st, ch), onChanged: (v) => _setFlag(st, ch, v ?? false)))),
                        ]),
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: ValueKey('adminEmails_${_prefs.hashCode}'),
                      initialValue: (getPath(_prefs!, 'adminEmails') as List?)?.join(', ') ?? '',
                      decoration: const InputDecoration(labelText: 'Admin alert recipients', helperText: 'Comma-separated emails that receive new-order and low-stock alerts'),
                      onChanged: (v) => setState(() {
                        _prefsDirty = true;
                        _prefs!['adminEmails'] = v.split(',').map((e) => e.trim()).where((e) => e.contains('@')).toList();
                      }),
                    ),
                  ]),
          ),
        ]),
      );
}
