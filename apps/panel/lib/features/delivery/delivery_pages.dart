
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:latlong2/latlong.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../core/web_utils.dart';
import '../../ui/crud.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'delivery_common.dart';
import 'package:panel/l10n/overrides.dart';

export 'delivery_common.dart' show LocationBeacon;

bool _sameDay(DateTime? a, DateTime b) => a != null && a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? _deliveredAt(Doc o) {
  final t = o['timeline'];
  if (t is List) {
    for (final e in t.reversed) {
      if (e is Map && e['status'] == OrderStatus.delivered) return toDate(e['at']);
    }
  }
  return o.s('status') == OrderStatus.delivered ? (o.dt('updatedAt') ?? o.createdAt) : null;
}

// ───────────────────────── Dashboard ─────────────────────────

class DeliveryDashboardPage extends StatefulWidget {
  const DeliveryDashboardPage({super.key});
  @override
  State<DeliveryDashboardPage> createState() => _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends State<DeliveryDashboardPage> {
  late final Stream<List<Doc>> _orders = myDeliveries(limit: 300).asBroadcastStream();

  @override
  void initState() {
    super.initState();
    LocationBeacon.instance.resumeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([session, LocationBeacon.instance]),
      builder: (context, _) {
        final p = session.profile;
        final beacon = LocationBeacon.instance;
        return PanelPage(
          title: 'Hi, ${session.displayName.split(' ').first} 👋',
          subtitle: beacon.online ? 'You are online and visible for new deliveries' : 'Go online to start receiving delivery requests',
          child: StreamBuilder<List<Doc>>(
            stream: _orders,
            builder: (context, snap) {
              final all = snap.data ?? const <Doc>[];
              final now = DateTime.now();
              final active = all.where((o) => activeDeliveryStatuses.contains(o.s('status'))).toList();
              final deliveredToday = all.where((o) => o.s('status') == OrderStatus.delivered && _sameDay(_deliveredAt(o), now)).toList();
              final todayEarn = deliveredToday.fold<double>(0, (a, o) => a + estEarning(p, o));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _OnlineHero(beacon: beacon),
                const SizedBox(height: 20),
                ResponsiveGrid(minItemWidth: 190, children: [
                  KpiCard(label: "Today's deliveries", value: '${deliveredToday.length}', icon: Icons.task_alt_rounded, color: G4MColors.success),
                  KpiCard(label: "Today's earnings (est.)", value: Fmt.money(todayEarn), icon: Icons.trending_up_rounded, color: G4MColors.primary),
                  KpiCard(
                      label: 'Cash in hand',
                      value: Fmt.money(p?.n('cashInHand') ?? 0),
                      icon: Icons.payments_rounded,
                      color: G4MColors.accent,
                      onTap: () => context.go('/finance/cash')),
                  KpiCard(
                      label: 'Balance',
                      value: Fmt.money(p?.n('balance') ?? 0),
                      icon: Icons.account_balance_wallet_rounded,
                      color: G4MColors.info,
                      onTap: () => context.go('/finance/earnings')),
                  KpiCard(label: 'Rating', value: (p?.n('rating') ?? 0) == 0 ? '—' : p!.n('rating').toStringAsFixed(1), icon: Icons.star_rounded, color: const Color(0xFFF5A524)),
                  KpiCard(label: 'Completed', value: Fmt.number(p?.i('completedCount') ?? 0), icon: Icons.emoji_events_rounded, color: const Color(0xFF7C3AED)),
                ]),
                const SizedBox(height: 20),
                LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth > 900;
                  final activeCard = SectionCard(
                    title: 'Active deliveries',
                    subtitle: active.isEmpty ? null : '${active.length} in progress',
                    icon: Icons.delivery_dining_rounded,
                    trailing: TextButton(onPressed: () => context.go('/orders'), child: Text(tr('View all'))),
                    child: snap.hasError
                        ? ErrorBox(snap.error!)
                        : !snap.hasData
                            ? const LoadingBlock(rows: 2)
                            : active.isEmpty
                                ? EmptyState(
                                    icon: Icons.local_mall_outlined,
                                    title: 'No active delivery',
                                    message: beacon.online ? 'Pick an order from the pool to get started.' : 'Go online, then pick an order from the pool.',
                                    action: FilledButton.icon(
                                      onPressed: () => context.go('/orders/available'),
                                      icon: const Icon(Icons.local_mall_rounded, size: 18),
                                      label: Text(tr('Open order pool')),
                                    ),
                                  )
                                : Column(children: [
                                    for (final o in active)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: DeliveryOrderCard(order: o, onOpen: () => context.go('/orders/${o.id}')),
                                      ),
                                  ]),
                  );
                  final recent = SectionCard(
                    title: 'Recent deliveries',
                    icon: Icons.history_rounded,
                    child: Column(children: [
                      if (all.where((o) => !activeDeliveryStatuses.contains(o.s('status'))).isEmpty)
                        Padding(padding: const EdgeInsets.all(16), child: Text('No completed deliveries yet', style: TextStyle(color: context.pal.muted))),
                      for (final o in all.where((o) => !activeDeliveryStatuses.contains(o.s('status'))).take(8))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => context.go('/orders/${o.id}'),
                          leading: CircleAvatar(
                            backgroundColor: statusColor(o.s('status')).withValues(alpha: .12),
                            child: Icon(o.s('status') == OrderStatus.delivered ? Icons.check_rounded : Icons.close_rounded, color: statusColor(o.s('status')), size: 18),
                          ),
                          title: Text(o.s('orderNo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${o.s('customer.name')} · ${Fmt.ago(_deliveredAt(o) ?? o.createdAt)}'),
                          trailing: Text(Fmt.money(o.n('payable', o.n('total'))), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  );
                  return wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 3, child: activeCard),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: recent),
                        ])
                      : Column(children: [activeCard, const SizedBox(height: 16), recent]);
                }),
              ]);
            },
          ),
        );
      },
    );
  }
}

class _OnlineHero extends StatelessWidget {
  const _OnlineHero({required this.beacon});
  final LocationBeacon beacon;
  @override
  Widget build(BuildContext context) {
    final on = beacon.online;
    final color = on ? G4MColors.success : const Color(0xFF64748B);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: on ? const [Color(0xFF0A4A33), Color(0xFF0B8A4F)] : const [Color(0xFF1E293B), Color(0xFF334155)],
        ),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .25), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        spacing: 16,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Stack(alignment: Alignment.center, children: [
              if (on)
                Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .15)))
                    .animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(.7, .7), end: const Offset(1.3, 1.3), duration: 1600.ms)
                    .fadeOut(duration: 1600.ms),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .18)),
                child: Icon(on ? Icons.wifi_tethering_rounded : Icons.portable_wifi_off_rounded, color: Colors.white),
              ),
            ]),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedSwitcher(
                duration: G4MMotion.standard,
                child: Text(on ? "You're online" : "You're offline",
                    key: ValueKey(on), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 2),
              Text(
                beacon.error != null
                    ? 'GPS: ${beacon.error}'
                    : on
                        ? (beacon.lastFix == null ? 'Locating…' : 'Location shared ${Fmt.ago(beacon.lastFix)} · updates every 30s')
                        : 'Location sharing is paused',
                style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 13),
              ),
            ]),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (on)
              IconButton(
                tooltip: 'Refresh location now',
                onPressed: beacon.refreshNow,
                icon: const Icon(Icons.my_location_rounded, color: Colors.white),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: beacon.busy ? null : () => beacon.setOnline(!on),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: 132,
                  height: 52,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                  child: Stack(children: [
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      alignment: on ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: beacon.busy
                            ? const Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2.4))
                            : Icon(Icons.power_settings_new_rounded, color: color),
                      ),
                    ),
                    Align(
                      alignment: on ? const Alignment(-.55, 0) : const Alignment(.6, 0),
                      child: Text(on ? 'ONLINE' : 'OFFLINE',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ───────────────────────── Order pool ─────────────────────────

class AvailableOrdersPage extends StatefulWidget {
  const AvailableOrdersPage({super.key});
  @override
  State<AvailableOrdersPage> createState() => _AvailableOrdersPageState();
}

class _AvailableOrdersPageState extends State<AvailableOrdersPage> {
  late Stream<List<Doc>> _pool = _make();
  bool _myCities = true;

  Stream<List<Doc>> _make() => liveDocs(Fs.orders.where('deliveryPartnerId', isNull: true).where('deliveryType', isEqualTo: 'home').where('status', whereIn: [OrderStatus.confirmed, OrderStatus.packed]).limit(150), label: 'orders(pool)');

  @override
  void initState() {
    super.initState();
    LocationBeacon.instance.resumeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final beacon = LocationBeacon.instance;
    final cities = (session.profile?.list('cities') ?? const <String>[]).map((c) => c.toLowerCase()).toSet();
    return ListenableBuilder(
      listenable: beacon,
      builder: (context, _) => PanelPage(
        title: 'Available orders',
        subtitle: 'Packed orders waiting for a delivery partner',
        actions: [
          if (cities.isNotEmpty)
            Segmented<bool>(value: _myCities, options: const {true: 'My cities', false: 'All cities'}, onChanged: (v) => setState(() => _myCities = v)),
          OutlinedButton.icon(onPressed: () => setState(() => _pool = _make()), icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(tr('Refresh'))),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!beacon.online)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: G4MColors.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: G4MColors.warning),
                const SizedBox(width: 10),
                Expanded(child: Text(tr('You are offline. Go online so customers can track you once you accept an order.'))),
                TextButton(onPressed: () => beacon.setOnline(true), child: Text(tr('Go online'))),
              ]),
            ),
          StreamBuilder<List<Doc>>(
            stream: _pool,
            builder: (context, snap) {
              if (snap.hasError) {
                final denied = '${snap.error}'.contains('permission-denied');
                return SectionCard(
                  child: denied
                      ? const EmptyState(
                          icon: Icons.lock_clock_outlined,
                          title: 'Order pool not available yet',
                          message: 'Your account can only read orders assigned to you. The open delivery pool needs Firestore rules that let '
                              'approved partners read packed, unassigned orders (backend rules update). Assigned orders still appear in My deliveries.',
                        )
                      : ErrorBox(snap.error!, onRetry: () => setState(() => _pool = _make())),
                );
              }
              if (!snap.hasData) return const SectionCard(child: LoadingBlock(rows: 4));
              var list = snap.data!
                  .where((o) => o.s('deliveryPartnerId').isEmpty && o.s('deliveryType', 'home') != 'pickup')
                  .toList();
              if (_myCities && cities.isNotEmpty) {
                list = list.where((o) {
                  final c = o.s('address.city').toLowerCase();
                  return c.isEmpty || cities.contains(c);
                }).toList();
              }
              double? dist(Doc o) {
                final la = o['address.lat'], ln = o['address.lng'];
                if (beacon.lat == null || la is! num || ln is! num) return null;
                return distanceKm(beacon.lat!, beacon.lng!, la.toDouble(), ln.toDouble());
              }

              list.sort((a, b) {
                final da = dist(a), db = dist(b);
                if (da != null && db != null) return da.compareTo(db);
                return (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000));
              });
              if (list.isEmpty) {
                return const SectionCard(
                  child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No orders waiting',
                    message: 'New packed orders appear here in real time. Keep this page open while online.',
                  ),
                );
              }
              return ResponsiveGrid(minItemWidth: 360, children: [
                for (var i = 0; i < list.length; i++)
                  DeliveryOrderCard(
                    order: list[i],
                    distance: dist(list[i]),
                    trailing: AsyncButton(
                      label: 'Accept',
                      icon: Icons.check_circle_rounded,
                      onPressed: () async {
                        final o = list[i];
                        if (!await confirm(context, 'Accept ${o.s('orderNo')}?', message: 'You will be responsible for picking up and delivering this order.', confirmLabel: 'Accept')) {
                          return;
                        }
                        final ok = await runToast(() => G4MApi.instance.acceptDelivery(o.id), success: 'Order ${o.s('orderNo')} is yours');
                        if (ok && context.mounted) context.go('/orders/${o.id}');
                      },
                    ),
                  ).animate(delay: (i * 40).ms).fadeIn(duration: 240.ms).slideY(begin: .05),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── My deliveries ─────────────────────────

class MyDeliveriesPage extends StatefulWidget {
  const MyDeliveriesPage({super.key});
  @override
  State<MyDeliveriesPage> createState() => _MyDeliveriesPageState();
}

class _MyDeliveriesPageState extends State<MyDeliveriesPage> {
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    return PanelPage(
      title: 'My deliveries',
      subtitle: 'Orders assigned to you',
      actions: [Segmented<bool>(value: _active, options: const {true: 'Active', false: 'Completed'}, onChanged: (v) => setState(() => _active = v))],
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _active ? _activeList(context) : _history(context),
      ),
    );
  }

  Widget _activeList(BuildContext context) => StreamBuilder<List<Doc>>(
        key: const ValueKey('active'),
        stream: myDeliveries(),
        builder: (context, snap) {
          if (snap.hasError) return SectionCard(child: ErrorBox(snap.error!));
          if (!snap.hasData) return const SectionCard(child: LoadingBlock(rows: 3));
          final list = snap.data!.where((o) => activeDeliveryStatuses.contains(o.s('status'))).toList();
          if (list.isEmpty) {
            return SectionCard(
              child: EmptyState(
                icon: Icons.delivery_dining_outlined,
                title: 'No active deliveries',
                message: 'Accepted and assigned orders show up here.',
                action: FilledButton(onPressed: () => context.go('/orders/available'), child: Text(tr('Find orders'))),
              ),
            );
          }
          return ResponsiveGrid(minItemWidth: 380, children: [
            for (final o in list) DeliveryOrderCard(order: o, onOpen: () => context.go('/orders/${o.id}')),
          ]);
        },
      );

  Widget _history(BuildContext context) => DataView<Doc>(
        key: const ValueKey('history'),
        id: 'my_deliveries_done',
        source: (q) => myDeliveries(limit: q.limit).map((l) => l.where((o) => !activeDeliveryStatuses.contains(o.s('status'))).toList()),
        rowId: (d) => d.id,
        onTap: (d) => context.go('/orders/${d.id}'),
        searchText: (d) => '${d.s('orderNo')} ${d.s('customer.name')} ${d.s('customer.phone')} ${addressLine(d)}',
        filters: [
          TableFilter('status', 'Status', const {'delivered': 'Delivered', 'cancelled': 'Cancelled', 'returned': 'Returned'}, test: (d, v) => d.s('status') == v),
          TableFilter('pay', 'Payment', const {'cod': 'Cash (COD)', 'online': 'Prepaid'}, test: (d, v) => v == 'cod' ? d.s('paymentMethod') == 'cod' : d.s('paymentMethod') != 'cod'),
        ],
        columns: [
          Col('Order', flex: 2, text: (d) => d.s('orderNo'), cell: (c, d) => TwoLine(d.s('orderNo'), Fmt.dateTime(d.createdAt))),
          Col('Customer', flex: 3, text: (d) => d.s('customer.name'), cell: (c, d) => TwoLine(d.s('customer.name'), addressLine(d))),
          Col('Delivered', flex: 2, text: (d) => Fmt.dateTime(_deliveredAt(d)), sort: (d) => _deliveredAt(d)?.millisecondsSinceEpoch ?? 0),
          Col('Payment', flex: 2, text: (d) => d.s('paymentMethod').toUpperCase()),
          Col('Cash collected', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('cashCollected')), sort: (d) => d.n('cashCollected')),
          moneyCol('Order total', 'total'),
          statusCol('Status', 'status'),
        ],
        emptyIcon: Icons.history_rounded,
        emptyTitle: 'No completed deliveries yet',
        csvName: 'my_deliveries',
        defaultSort: 2,
      );
}

// ───────────────────────── Route map ─────────────────────────

class DeliveryRoutePage extends StatefulWidget {
  const DeliveryRoutePage({super.key});
  @override
  State<DeliveryRoutePage> createState() => _DeliveryRoutePageState();
}

class _DeliveryRoutePageState extends State<DeliveryRoutePage> {
  final _sellerCache = <String, Future<Doc?>>{};
  final _map = MapController();

  Future<Doc?> _seller(String id) =>
      _sellerCache.putIfAbsent(id, () => Fs.sellers.doc(id).get().then((d) => d.exists ? Doc.fromSnap(d) : null).catchError((_) => null));

  @override
  void initState() {
    super.initState();
    LocationBeacon.instance.resumeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return PanelPage(
      title: 'Route map',
      subtitle: 'Pickups and drops for your active deliveries',
      scroll: false,
      child: StreamBuilder<List<Doc>>(
        stream: myDeliveries(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorBox(snap.error!);
          final active = (snap.data ?? const <Doc>[]).where((o) => activeDeliveryStatuses.contains(o.s('status'))).toList();
          final sellerIds = {for (final o in active) ...o.list('sellerIds')}.toList();
          return FutureBuilder<List<Doc?>>(
            future: Future.wait(sellerIds.map(_seller)),
            builder: (context, sSnap) {
              final sellers = {for (final s in (sSnap.data ?? const <Doc?>[]).whereType<Doc>()) s.id: s};
              return LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 900;
                final map = ListenableBuilder(listenable: LocationBeacon.instance, builder: (context, _) => _mapView(context, active, sellers));
                final list = _stopList(context, active, sellers);
                return wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(flex: 3, child: map),
                        const SizedBox(width: 16),
                        SizedBox(width: 360, child: list),
                      ])
                    : Column(children: [Expanded(child: map), const SizedBox(height: 12), SizedBox(height: 260, child: list)]);
              });
            },
          );
        },
      ),
    );
  }

  LatLng? _drop(Doc o) {
    final la = o['address.lat'], ln = o['address.lng'];
    return la is num && ln is num ? LatLng(la.toDouble(), ln.toDouble()) : null;
  }

  LatLng? _pickup(Doc? s) => s == null || s['lat'] is! num || s['lng'] is! num ? null : LatLng(s.n('lat'), s.n('lng'));

  Widget _mapView(BuildContext context, List<Doc> active, Map<String, Doc> sellers) {
    final b = LocationBeacon.instance;
    final me = b.lat == null ? null : LatLng(b.lat!, b.lng!);
    final markers = <Marker>[];
    final lines = <Polyline>[];
    final pts = <LatLng>[?me];
    for (final o in active) {
      final drop = _drop(o);
      final pickedUp = o.s('status') != OrderStatus.assigned;
      final route = <LatLng>[?me];
      for (final sid in o.list('sellerIds')) {
        final p = _pickup(sellers[sid]);
        if (p == null) continue;
        pts.add(p);
        if (!pickedUp) route.add(p);
        markers.add(Marker(point: p, width: 40, height: 40, child: _pin(Icons.storefront_rounded, G4MColors.accent, sellers[sid]!.s('storeName'))));
      }
      if (drop != null) {
        pts.add(drop);
        route.add(drop);
        markers.add(Marker(point: drop, width: 40, height: 40, child: _pin(Icons.home_rounded, G4MColors.primary, '${o.s('orderNo')} · ${o.s('customer.name')}')));
      }
      if (route.length > 1) {
        lines.add(Polyline(points: route, color: (pickedUp ? G4MColors.primary : G4MColors.accent).withValues(alpha: .8), strokeWidth: 4, pattern: pickedUp ? const StrokePattern.solid() : StrokePattern.dashed(segments: const [10, 8])));
      }
    }
    if (me != null) {
      markers.add(Marker(
        point: me,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(color: G4MColors.info.withValues(alpha: .2), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(color: G4MColors.info, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
          ),
        ),
      ));
    }
    final center = pts.isNotEmpty ? pts.first : const LatLng(19.076, 72.8777);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(children: [
        FlutterMap(
          key: ValueKey('${pts.length}'),
          mapController: _map,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            initialCameraFit: pts.length > 1 ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(60), maxZoom: 16) : null,
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.panel'),
            PolylineLayer(polylines: lines),
            MarkerLayer(markers: markers),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Wrap(spacing: 8, children: [
            _legend(context, G4MColors.info, 'You'),
            _legend(context, G4MColors.accent, 'Pickup'),
            _legend(context, G4MColors.primary, 'Drop'),
          ]),
        ),
        if (me == null)
          Positioned(
            right: 12,
            top: 12,
            child: FilledButton.icon(
              onPressed: () => b.setOnline(true),
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(tr('Share my location')),
            ),
          )
        else
          Positioned(
            right: 12,
            bottom: 28,
            child: FloatingActionButton.small(
              heroTag: 'me',
              onPressed: () => _map.move(me, 15),
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
      ]),
    );
  }

  Widget _legend(BuildContext context, Color c, String l) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 5, backgroundColor: c),
          const SizedBox(width: 6),
          Text(l, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _pin(IconData icon, Color c, String tip) => Tooltip(
        message: tip,
        child: Container(
          decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)]),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Widget _stopList(BuildContext context, List<Doc> active, Map<String, Doc> sellers) {
    if (active.isEmpty) {
      return const SectionCard(child: EmptyState(icon: Icons.route_outlined, title: 'No active route', message: 'Accept an order to see pickups and drops here.'));
    }
    return Container(
      decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.pal.line)),
      child: ListView(padding: const EdgeInsets.all(12), children: [
        for (final o in active) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Row(children: [
              Text(o.s('orderNo'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              statusPill(o.s('status')),
              const Spacer(),
              IconButton(tooltip: 'Open order', onPressed: () => context.go('/orders/${o.id}'), icon: const Icon(Icons.open_in_new_rounded, size: 18)),
            ]),
          ),
          for (final sid in o.list('sellerIds'))
            _stop(context, Icons.storefront_rounded, G4MColors.accent, sellers[sid]?.s('storeName') ?? 'Store', sellers[sid]?.s('address') ?? '', _pickup(sellers[sid])),
          _stop(context, Icons.home_rounded, G4MColors.primary, o.s('customer.name', 'Customer'), addressLine(o), _drop(o)),
          Divider(color: context.pal.line),
        ],
      ]),
    );
  }

  Widget _stop(BuildContext context, IconData icon, Color c, String title, String sub, LatLng? at) => ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: CircleAvatar(radius: 16, backgroundColor: c.withValues(alpha: .14), child: Icon(icon, size: 16, color: c)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: at == null
            ? null
            : IconButton(
                tooltip: 'Directions in Google Maps',
                icon: const Icon(Icons.directions_rounded),
                onPressed: () => openUrl('https://www.google.com/maps/dir/?api=1&destination=${at.latitude},${at.longitude}&travelmode=driving'),
              ),
        onTap: at == null ? null : () => _map.move(at, 16),
      );
}

// ───────────────────────── Earnings ─────────────────────────

class DeliveryEarningsPage extends StatefulWidget {
  const DeliveryEarningsPage({super.key});
  @override
  State<DeliveryEarningsPage> createState() => _DeliveryEarningsPageState();
}

class _DeliveryEarningsPageState extends State<DeliveryEarningsPage> {
  int _days = 14;
  int _tab = 0;
  late final Stream<List<Doc>> _orders = myDeliveries(limit: 500).asBroadcastStream();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final p = session.profile;
          final salaryType = p?.s('salary.type', 'per_order') ?? 'per_order';
          final salaryAmt = p?.n('salary.amount') ?? 0;
          return PanelPage(
            title: 'Earnings',
            subtitle: 'Your balance, deliveries and payouts',
            actions: [
              FilledButton.icon(onPressed: () => context.go('/finance/withdrawals'), icon: const Icon(Icons.outbox_rounded, size: 18), label: Text(tr('Withdraw'))),
            ],
            child: StreamBuilder<List<Doc>>(
              stream: _orders,
              builder: (context, snap) {
                final delivered = (snap.data ?? const <Doc>[]).where((o) => o.s('status') == OrderStatus.delivered).toList();
                final now = DateTime.now();
                final monthEarn = delivered
                    .where((o) {
                      final d = _deliveredAt(o);
                      return d != null && d.year == now.year && d.month == now.month;
                    })
                    .fold<double>(0, (a, o) => a + estEarning(p, o));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ResponsiveGrid(minItemWidth: 210, children: [
                    KpiCard(label: 'Available balance', value: Fmt.money(p?.n('balance') ?? 0), icon: Icons.account_balance_wallet_rounded, color: G4MColors.primary),
                    KpiCard(label: 'This month (est.)', value: Fmt.money(monthEarn), icon: Icons.calendar_month_rounded, color: G4MColors.info),
                    KpiCard(label: 'Completed deliveries', value: Fmt.number(p?.i('completedCount') ?? delivered.length), icon: Icons.task_alt_rounded, color: G4MColors.success),
                    KpiCard(
                      label: 'Salary plan',
                      value: salaryAmt > 0 ? Fmt.money(salaryAmt) : '—',
                      caption: salaryType == 'monthly' ? 'Fixed monthly salary' : 'Per delivered order',
                      icon: Icons.badge_rounded,
                      color: const Color(0xFF7C3AED),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Deliveries over time',
                    subtitle: salaryType == 'per_order' ? 'Bars = deliveries · estimated earnings in tooltip' : 'Delivered orders per day',
                    icon: Icons.bar_chart_rounded,
                    trailing: Segmented<int>(value: _days, options: const {7: '7D', 14: '14D', 30: '30D'}, onChanged: (v) => setState(() => _days = v)),
                    child: SizedBox(height: 240, child: _chart(context, delivered, p)),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Segmented<int>(value: _tab, options: const {0: 'Fund transfers', 1: 'Wallet transactions'}, onChanged: (v) => setState(() => _tab = v)),
                  ]),
                  const SizedBox(height: 12),
                  if (_tab == 0) _transfers() else _walletTxns(),
                ]);
              },
            ),
          );
        },
      );

  Widget _chart(BuildContext context, List<Doc> delivered, Doc? p) {
    final today = DateTime.now();
    final days = [for (var i = _days - 1; i >= 0; i--) DateTime(today.year, today.month, today.day).subtract(Duration(days: i))];
    final counts = List<int>.filled(days.length, 0);
    final earn = List<double>.filled(days.length, 0);
    for (final o in delivered) {
      final d = _deliveredAt(o);
      if (d == null) continue;
      final idx = days.indexWhere((x) => _sameDay(d, x));
      if (idx >= 0) {
        counts[idx]++;
        earn[idx] += estEarning(p, o);
      }
    }
    final maxY = (counts.fold<int>(0, (a, b) => a > b ? a : b) + 1).toDouble();
    final accent = context.pal.accent;
    return Directionality(textDirection: TextDirection.ltr, child: BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: context.pal.line, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => G4MColors.primaryDeep,
            getTooltipItem: (g, gi, r, ri) => BarTooltipItem(
              '${DateFormat('d MMM').format(days[g.x])}\n${counts[g.x]} deliveries · ${Fmt.money(earn[g.x])}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxY <= 5 ? 1 : (maxY / 4).ceilToDouble(),
              getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text(v.toInt().toString(), style: TextStyle(fontSize: 11, color: context.pal.muted))),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= days.length || (_days > 14 && i % 3 != 0)) return const SizedBox();
                return SideTitleWidget(meta: m, child: Text(DateFormat('d/M').format(days[i]), style: TextStyle(fontSize: 10.5, color: context.pal.muted)));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: counts[i].toDouble(),
                width: _days > 14 ? 8 : 16,
                borderRadius: BorderRadius.circular(5),
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [accent.withValues(alpha: .55), accent]),
              ),
            ]),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    ));
  }

  Widget _transfers() => DataView<Doc>(
        key: const ValueKey('transfers'),
        id: 'my_fund_transfers',
        source: (q) => liveDocs(
          Fs.fundTransfers.where('toUserId', isEqualTo: session.uid).orderBy('createdAt', descending: true).limit(q.limit),
          fallback: Fs.fundTransfers.where('toUserId', isEqualTo: session.uid).limit(q.limit),
          label: 'fundTransfers(toUserId, createdAt desc)',
        ),
        rowId: (d) => d.id,
        searchText: (d) => '${d.s('note')} ${d.id}',
        columns: [
          dateCol('Date'),
          moneyCol('Amount', 'amount'),
          Col('Note', flex: 4, text: (d) => d.s('note')),
          Col('Ref', flex: 2, text: (d) => '#${d.id.substring(0, 8).toUpperCase()}'),
        ],
        emptyIcon: Icons.swap_horiz_rounded,
        emptyTitle: 'No fund transfers yet',
        emptyMessage: 'Salary and settlements transferred by admin appear here.',
        csvName: 'fund_transfers',
      );

  Widget _walletTxns() => DataView<Doc>(
        key: const ValueKey('wallet'),
        id: 'my_wallet_txns',
        source: (q) => liveDocs(
          Fs.walletTransactions.where('userId', isEqualTo: session.uid).orderBy('createdAt', descending: true).limit(q.limit),
          fallback: Fs.walletTransactions.where('userId', isEqualTo: session.uid).limit(q.limit),
          label: 'walletTransactions(userId, createdAt desc)',
        ),
        rowId: (d) => d.id,
        searchText: (d) => '${d.s('reason')} ${d.s('refId')}',
        filters: [TableFilter('type', 'Type', const {'credit': 'Credit', 'debit': 'Debit'}, test: (d, v) => d.s('type') == v)],
        columns: [
          dateCol('Date'),
          Col('Type', flex: 1, text: (d) => d.s('type'), cell: (c, d) => statusPill(d.s('type'))),
          Col('Reason', flex: 2, text: (d) => Fmt.titleCase(d.s('reason'))),
          Col('Amount', flex: 2, numeric: true, text: (d) => '${d.s('type') == 'debit' ? '−' : '+'}${Fmt.money(d.n('amount'))}', sort: (d) => d.n('amount')),
          moneyCol('Balance after', 'balanceAfter'),
          Col('Ref', flex: 2, text: (d) => d.s('refId')),
        ],
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: 'No wallet transactions',
        csvName: 'wallet_transactions',
      );
}

// ───────────────────────── Cash in hand ─────────────────────────

class CashInHandPage extends StatelessWidget {
  const CashInHandPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final cash = session.profile?.n('cashInHand') ?? 0;
          final q = Fs.cashCollections.where('deliveryPartnerId', isEqualTo: session.uid);
          return PanelPage(
            title: 'Cash in hand',
            subtitle: 'Cash collected on COD orders and settlements with Go4Market',
            child: StreamBuilder<List<Doc>>(
              stream: liveDocs(q.orderBy('createdAt', descending: true).limit(300), fallback: q.limit(300), label: 'cashCollections(deliveryPartnerId, createdAt desc)'),
              builder: (context, snap) {
                final list = snap.data ?? const <Doc>[];
                final collected = list.fold<double>(0, (a, d) => a + d.n('amount'));
                final settled = list.where((d) => d.s('status') == 'settled').fold<double>(0, (a, d) => a + d.n('amount'));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ResponsiveGrid(minItemWidth: 230, children: [
                    KpiCard(label: 'Cash in hand (to settle)', value: Fmt.money(cash), icon: Icons.payments_rounded, color: cash > 0 ? G4MColors.accent : G4MColors.success),
                    KpiCard(label: 'Total collected', value: Fmt.money(collected), icon: Icons.savings_rounded, color: G4MColors.info),
                    KpiCard(label: 'Settled', value: Fmt.money(settled), icon: Icons.task_alt_rounded, color: G4MColors.success),
                    KpiCard(label: 'COD deliveries', value: '${list.length}', icon: Icons.receipt_rounded, color: const Color(0xFF7C3AED)),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: G4MColors.info.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: G4MColors.info.withValues(alpha: .25)),
                    ),
                    child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline_rounded, color: G4MColors.info),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'How settlement works: hand over the cash you collected to your Go4Market hub or deposit it as instructed by the admin team. '
                          'Once the admin records the settlement, your cash-in-hand goes down and the entries below move to “Settled”.',
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  DataView<Doc>(
                    id: 'my_cash',
                    source: (s) => liveDocs(q.orderBy('createdAt', descending: true).limit(s.limit), fallback: q.limit(s.limit), label: 'cashCollections(deliveryPartnerId, createdAt desc)'),
                    rowId: (d) => d.id,
                    onTap: (d) => d.s('orderId').isEmpty ? null : context.go('/orders/${d.s('orderId')}'),
                    searchText: (d) => '${d.s('orderId')} ${d.s('orderNo')}',
                    filters: [TableFilter('status', 'Status', const {'collected': 'Collected', 'settled': 'Settled'}, test: (d, v) => d.s('status', 'collected') == v)],
                    columns: [
                      dateCol('Date'),
                      Col('Order', flex: 3, text: (d) => d.s('orderNo', d.s('orderId'))),
                      moneyCol('Amount', 'amount'),
                      statusCol('Status', 'status', f: 'collected'),
                      dateCol('Settled on', 'settledAt'),
                    ],
                    emptyIcon: Icons.payments_outlined,
                    emptyTitle: 'No cash collections yet',
                    emptyMessage: 'Cash collected on COD deliveries shows up here.',
                    csvName: 'cash_collections',
                  ),
                ]);
              },
            ),
          );
        },
      );
}

// ───────────────────────── Profile ─────────────────────────

class DeliveryProfilePage extends StatefulWidget {
  const DeliveryProfilePage({super.key});
  @override
  State<DeliveryProfilePage> createState() => _DeliveryProfilePageState();
}

class _DeliveryProfilePageState extends State<DeliveryProfilePage> {
  Map<String, dynamic>? _values;
  final _form = GlobalKey<EntityFormState>();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final p = session.profile;
          _values ??= {
            'name': session.userDoc?.s('name') ?? p?.s('name') ?? '',
            'phone': session.userDoc?.s('phone') ?? p?.s('phone') ?? '',
            'photoUrl': session.userDoc?.s('photoUrl') ?? p?.s('photoUrl') ?? '',
          };
          final details = SectionCard(
            title: 'Partner details',
            subtitle: 'Managed by Go4Market — contact support to change',
            icon: Icons.badge_outlined,
            child: Column(children: [
              Row(children: [
                Avatar(name: p?.s('name') ?? session.displayName, url: p?.s('photoUrl') ?? '', size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p?.s('name') ?? session.displayName, style: context.tt.titleMedium),
                    Text(session.user?.email ?? '', style: TextStyle(color: context.pal.muted)),
                  ]),
                ),
                statusPill(p?.s('status', 'pending') ?? 'pending'),
              ]),
              const SizedBox(height: 12),
              InfoRow('Vehicle', '${Fmt.titleCase(p?.s('vehicleType', 'bike') ?? '')} · ${p?.s('vehicleNo') ?? ''}'),
              InfoRow('Cities', (p?.list('cities') ?? const []).join(', ')),
              InfoRow('Works for', p?.s('ownerType', 'admin') == 'seller' ? 'Seller fleet (${p?.s('sellerId')})' : 'Go4Market fleet'),
              InfoRow('Salary', '${Fmt.titleCase(p?.s('salary.type', 'per_order') ?? '')} · ${Fmt.money(p?.n('salary.amount') ?? 0)}'),
              InfoRow('Rating', (p?.n('rating') ?? 0) == 0 ? '—' : '${p!.n('rating').toStringAsFixed(1)} ★'),
              InfoRow('Deliveries', Fmt.number(p?.i('completedCount') ?? 0)),
              InfoRow('Joined', Fmt.date(p?.createdAt)),
            ]),
          );
          final edit = SectionCard(
            title: 'Contact & photo',
            icon: Icons.person_outline_rounded,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              EntityForm(key: _form, values: _values!, fields: [
                const F('name', 'Full name', FT.text, required: true),
                const F('phone', 'Phone', FT.text, required: true),
                F('photoUrl', 'Profile photo', FT.image, folder: 'users/${session.uid}', wide: true),
              ]),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AsyncButton(
                  label: 'Save changes',
                  icon: Icons.check_rounded,
                  onPressed: () async {
                    if (!(_form.currentState?.validate() ?? false)) return;
                    final v = cleanValues(_values!);
                    await runToast(() async {
                      await Fs.user(session.uid).set({...v, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                      if ('${v['name']}'.isNotEmpty) await session.user?.updateDisplayName('${v['name']}');
                    }, success: 'Profile updated');
                  },
                ),
              ),
            ]),
          );
          final security = SectionCard(
            title: 'Security',
            icon: Icons.lock_outline_rounded,
            child: Row(children: [
              Expanded(child: Text(tr('Change the password you use to sign in to the partner panel and app.'))),
              OutlinedButton.icon(onPressed: () => changePasswordDialog(context), icon: const Icon(Icons.password_rounded, size: 18), label: Text(tr('Change password'))),
            ]),
          );
          return PanelPage(
            title: 'Profile',
            subtitle: 'Your partner account',
            maxWidth: 1100,
            child: LayoutBuilder(builder: (context, c) {
              if (c.maxWidth > 860) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  Expanded(child: Column(children: [edit, const SizedBox(height: 16), security])),
                ]);
              }
              return Column(children: [details, const SizedBox(height: 16), edit, const SizedBox(height: 16), security]);
            }),
          );
        },
      );
}

/// Re-authenticates with the current password, then updates it.
Future<void> changePasswordDialog(BuildContext context) async {
  final cur = TextEditingController(), next = TextEditingController(), again = TextEditingController();
  final key = GlobalKey<FormState>();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Change password')),
      content: SizedBox(
        width: 400,
        child: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password'), validator: (v) => (v ?? '').isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password'), validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null),
            const SizedBox(height: 12),
            TextFormField(controller: again, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password'), validator: (v) => v != next.text ? 'Passwords do not match' : null),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
        AsyncButton(
          label: 'Update password',
          onPressed: () async {
            if (!key.currentState!.validate()) return;
            final u = FirebaseAuth.instance.currentUser;
            if (u == null || u.email == null) return;
            final ok = await runToast(() async {
              try {
                await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: cur.text));
              } on FirebaseAuthException catch (e) {
                throw e.code == 'invalid-credential' || e.code == 'wrong-password' ? 'Current password is incorrect' : (e.message ?? e.code);
              }
              await u.updatePassword(next.text);
            }, success: 'Password updated');
            if (ok && ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ],
    ),
  );
}

