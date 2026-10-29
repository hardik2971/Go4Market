import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'package:panel/l10n/overrides.dart';

/// Resolves a uid to a display name (users → sellers → deliveryPartners), cached.
abstract final class UserNames {
  static final _cache = <String, Future<String>>{};

  static Future<String> of(String uid) {
    if (uid.isEmpty) return Future.value('—');
    return _cache.putIfAbsent(uid, () async {
      try {
        final u = await Fs.users.doc(uid).get();
        final n = '${u.data()?['name'] ?? ''}'.trim();
        if (n.isNotEmpty) return n;
        final s = await Fs.sellers.doc(uid).get();
        if (s.exists) return '${s.data()?['storeName'] ?? uid}';
        final p = await Fs.deliveryPartners.doc(uid).get();
        if (p.exists) return '${p.data()?['name'] ?? uid}';
        final e = '${u.data()?['email'] ?? ''}';
        return e.isNotEmpty ? e : uid.substring(0, uid.length.clamp(0, 8));
      } catch (_) {
        return uid.substring(0, uid.length.clamp(0, 8));
      }
    });
  }
}

/// Enriches each doc with `_name` resolved from [uidField] so search/CSV can use it.
Stream<List<Doc>> withNames(Stream<List<Doc>> s, String uidField) => s.asyncMap((list) async {
      await Future.wait(list.map((d) async => d.data['_name'] = await UserNames.of(d.s(uidField))));
      return list;
    });

class UserNameText extends StatelessWidget {
  const UserNameText(this.uid, {super.key, this.style});
  final String uid;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: UserNames.of(uid),
        builder: (c, s) => Text(s.data ?? '…', maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      );
}

/// Simple animated tab strip that renders the selected child inline (no fixed height needed).
class InlineTabs extends StatefulWidget {
  const InlineTabs({super.key, required this.tabs});
  final List<(String, IconData, WidgetBuilder)> tabs;
  @override
  State<InlineTabs> createState() => _InlineTabsState();
}

class _InlineTabsState extends State<InlineTabs> with SingleTickerProviderStateMixin {
  late final _c = TabController(length: widget.tabs.length, vsync: this)..addListener(() => setState(() {}));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.pal.line))),
          child: TabBar(
            controller: _c,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: context.pal.accent,
            unselectedLabelColor: context.pal.muted,
            indicatorColor: context.pal.accent,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
            dividerColor: Colors.transparent,
            tabs: [for (final t in widget.tabs) Tab(height: 44, child: Row(children: [Icon(t.$2, size: 17), const SizedBox(width: 8), Text(tr(t.$1))]))],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, .02), end: Offset.zero).animate(a), child: c),
          ),
          child: KeyedSubtree(key: ValueKey(_c.index), child: widget.tabs[_c.index].$3(context)),
        ),
      ]);
}

/// Live query helper with orderBy(createdAt) + index fallback.
Stream<List<Doc>> recent(Query<Json> base, int limit, {String label = 'query', String field = 'createdAt'}) =>
    liveDocs(base.orderBy(field, descending: true).limit(limit), fallback: base.limit(limit), sortField: field, label: label);

/// Reusable orders table for detail pages.
Widget ordersTable(BuildContext context, String id, Query<Json> base, {String label = 'orders'}) => DataView<Doc>(
      id: id,
      source: (q) => recent(base, q.limit, label: label),
      rowId: (d) => d.id,
      searchText: (d) => '${d.s('orderNo')} ${d.s('customer.name')} ${d.s('customer.phone')} ${d.s('status')}',
      onTap: (d) => context.go('/orders/${d.id}'),
      pageSize: 10,
      initialLimit: 100,
      defaultSort: 4,
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'No orders yet',
      filters: [
        TableFilter('status', 'Status', {for (final s in [...OrderStatus.homeFlow, OrderStatus.readyForPickup, OrderStatus.cancelled, OrderStatus.returned]) s: OrderStatus.label(s)},
            test: (d, v) => d.s('status') == v),
      ],
      columns: [
        Col('Order', flex: 2, text: (d) => d.s('orderNo', d.id), cell: (c, d) => TwoLine(d.s('orderNo', d.id), '${d.list('items').length} items · ${d.s('channel')}')),
        Col('Customer', flex: 3, text: (d) => d.s('customer.name'), cell: (c, d) => TwoLine(d.s('customer.name', 'Customer'), d.s('customer.phone'))),
        Col('Total', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('total')), sort: (d) => d.n('total'), csv: (d) => d.n('total').toStringAsFixed(2)),
        Col('Status', flex: 2, text: (d) => d.s('status'), cell: (c, d) => statusPill(d.s('status'))),
        Col('Date', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
      ],
    );

Widget withdrawalsTable(BuildContext context, String id, Query<Json> base) => DataView<Doc>(
      id: id,
      source: (q) => recent(base, q.limit, label: id),
      rowId: (d) => d.id,
      searchText: (d) => '${d.s('method')} ${d.s('status')} ${d.s('note')}',
      pageSize: 10,
      initialLimit: 100,
      emptyIcon: Icons.outbox_outlined,
      emptyTitle: 'No withdrawals',
      columns: [
        Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('amount')), sort: (d) => d.n('amount')),
        Col('Method', flex: 2, text: (d) => Fmt.titleCase(d.s('method'))),
        Col('Status', flex: 2, text: (d) => d.s('status'), cell: (c, d) => statusPill(d.s('status'))),
        Col('Note', flex: 3, text: (d) => d.s('note')),
        Col('Requested', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
      ],
    );

Widget transfersTable(BuildContext context, String id, Query<Json> base, {bool showUser = false}) => DataView<Doc>(
      id: id,
      source: (q) => withNames(recent(base, q.limit, label: id), 'toUserId'),
      rowId: (d) => d.id,
      searchText: (d) => '${d.s('_name')} ${d.s('note')} ${d.s('role')}',
      pageSize: 10,
      initialLimit: 100,
      emptyIcon: Icons.swap_horiz_rounded,
      emptyTitle: 'No transfers',
      columns: [
        if (showUser) Col('To', flex: 3, text: (d) => d.s('_name'), cell: (c, d) => TwoLine(d.s('_name'), Fmt.titleCase(d.s('role')))),
        Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('amount')), sort: (d) => d.n('amount')),
        Col('Note', flex: 4, text: (d) => d.s('note')),
        Col('By', flex: 2, text: (d) => d.s('by'), cell: (c, d) => UserNameText(d.s('by'), style: const TextStyle(fontSize: 13))),
        Col('Date', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
      ],
    );

/// OSM mini map with a single marker.
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, required this.lat, required this.lng, this.height = 220, this.label});
  final double? lat;
  final double? lng;
  final double height;
  final String? label;
  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      return Container(
        height: height,
        decoration: BoxDecoration(color: context.pal.surfaceAlt, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_off_outlined, color: context.pal.faint, size: 32),
          const SizedBox(height: 6),
          Text('No location shared yet', style: TextStyle(color: context.pal.muted)),
        ]),
      );
    }
    final p = LatLng(lat!, lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(initialCenter: p, initialZoom: 14),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.panel'),
            MarkerLayer(markers: [
              Marker(
                point: p,
                width: 44,
                height: 44,
                child: Tooltip(
                  message: label ?? '',
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.pal.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
          ],
        ),
      ),
    );
  }
}

/// Header block for detail pages (banner, avatar, title, chips, actions).
class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.title, this.subtitle, this.image = '', this.banner = '', this.chips = const [], this.actions = const []});
  final String title;
  final String? subtitle;
  final String image;
  final String banner;
  final List<Widget> chips;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.pal.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 120,
            child: Stack(fit: StackFit.expand, children: [
              if (banner.isNotEmpty)
                NetImage(banner)
              else
                Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0A4A33), context.pal.accent]))),
              Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x66000000)]))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 12,
              children: [
                Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.pal.surface, width: 4)),
                      child: Avatar(url: image, name: title, size: 84),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      if (subtitle != null) Text(subtitle!, style: TextStyle(color: context.pal.muted)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: chips),
                    ]),
                  ),
                ]),
                Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
              ],
            ),
          ),
        ]),
      );
}

/// Calls a callable with toast + error handling. Returns the result or null.
Future<Json?> callApi(Future<Json> Function() fn, {String? success}) async {
  try {
    final r = await fn();
    if (success != null) toast(success);
    return r;
  } catch (e) {
    toastError(e);
    return null;
  }
}

/// Dialog with an amount + note (and optional credit/debit choice).
Future<(double, String, String)?> amountDialog(BuildContext context, String title,
    {double? initial, bool withType = false, String noteLabel = 'Note', bool noteRequired = false, String confirmLabel = 'Confirm', double? max}) {
  final amount = TextEditingController(text: initial == null || initial == 0 ? '' : initial.toStringAsFixed(initial % 1 == 0 ? 0 : 2));
  final note = TextEditingController();
  var type = 'credit';
  final key = GlobalKey<FormState>();
  return showDialog<(double, String, String)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (withType) ...[
                Segmented<String>(value: type, options: const {'credit': 'Credit (add)', 'debit': 'Debit (deduct)'}, onChanged: (v) => set(() => type = v)),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Amount', prefixText: '₹ ', helperText: max == null ? null : 'Max ${Fmt.money(max)}'),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter an amount greater than 0';
                  if (max != null && n > max + 0.001) return 'Cannot exceed ${Fmt.money(max)}';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: note,
                maxLines: 2,
                decoration: InputDecoration(labelText: noteLabel),
                validator: (v) => noteRequired && (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, (double.parse(amount.text), note.text.trim(), type));
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

String monthLabel([DateTime? d]) {
  const m = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final x = d ?? DateTime.now();
  return '${m[x.month - 1]} ${x.year}';
}

Widget dotOnline(bool online) => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: online ? G4MColors.success : const Color(0xFF9CA3AF), shape: BoxShape.circle),
    );

/// Wraps a future-built list into a stream for DataView sources.
Stream<List<T>> futureStream<T>(Future<List<T>> Function() f) => Stream.fromFuture(f());

FieldValue get ts => FieldValue.serverTimestamp();
