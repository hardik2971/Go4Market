import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../ui/kit.dart';
import '../shared/a_common.dart';
import 'package:panel/l10n/overrides.dart';

/// Live map of online delivery partners + active order drop points (OpenStreetMap).
class LiveMapPage extends StatefulWidget {
  const LiveMapPage({super.key});
  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage> {
  final _map = MapController();
  final _riders = liveDocs(Fs.deliveryPartners.where('online', isEqualTo: true), label: 'deliveryPartners online');
  final _orders = liveQuery<ShopOrder>(
    Fs.orders.where('status', whereIn: [OrderStatus.packed, OrderStatus.assigned, OrderStatus.pickedUp, OrderStatus.outForDelivery]).limit(300),
    ShopOrder.fromDoc,
    label: 'orders active statuses',
  );
  String _q = '';
  String? _selected;
  bool _showOrders = true;
  bool _fitted = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh "updated x ago" labels.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  LatLng? _pos(Doc d) => d['lat'] == null || d['lng'] == null ? null : LatLng(d.n('lat'), d.n('lng'));

  void _focus(Doc d) {
    final p = _pos(d);
    setState(() => _selected = d.id);
    if (p != null) _map.move(p, 15);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1000;
    return PanelPage(
      title: 'Live rider map',
      subtitle: 'Online delivery partners and active deliveries in real time.',
      scroll: false,
      actions: [
        FilterChip(label: Text(tr('Show active orders')), selected: _showOrders, onSelected: (v) => setState(() => _showOrders = v)),
      ],
      child: StreamBuilder<List<Doc>>(
        stream: _riders,
        builder: (context, rs) => StreamBuilder<List<ShopOrder>>(
          stream: _orders,
          builder: (context, os) {
            if (rs.hasError) return SectionCard(child: ErrorBox(rs.error!));
            final riders = (rs.data ?? const <Doc>[]).where((d) => d.s('status', 'approved') == 'approved').toList();
            final located = riders.where((d) => _pos(d) != null).toList();
            final orders = os.data ?? const <ShopOrder>[];
            final drops = orders.where((o) => o.address['lat'] != null && o.address['lng'] != null).toList();
            if (!_fitted && located.isNotEmpty) {
              _fitted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final pts = [for (final d in located) _pos(d)!, for (final o in drops) LatLng(toNum(o.address['lat']), toNum(o.address['lng']))];
                if (pts.length == 1) {
                  _map.move(pts.first, 14);
                } else if (pts.length > 1) {
                  _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(60), maxZoom: 15));
                }
              });
            }
            final list = riders
                .where((d) => _q.isEmpty || '${d.s('name')} ${d.s('phone')} ${d.s('vehicleNo')} ${d.list('cities').join(' ')}'.toLowerCase().contains(_q))
                .toList()
              ..sort((a, b) => (b.dt('locationUpdatedAt') ?? DateTime(0)).compareTo(a.dt('locationUpdatedAt') ?? DateTime(0)));
            final activeByRider = <String, List<ShopOrder>>{};
            for (final o in orders) {
              if (o.deliveryPartnerId.isNotEmpty) activeByRider.putIfAbsent(o.deliveryPartnerId, () => []).add(o);
            }

            final map = ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(children: [
                FlutterMap(
                  mapController: _map,
                  options: const MapOptions(
                    initialCenter: LatLng(20.5937, 78.9629),
                    initialZoom: 5,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.panel'),
                    if (_showOrders)
                      MarkerLayer(markers: [
                        for (final o in drops)
                          Marker(
                            point: LatLng(toNum(o.address['lat']), toNum(o.address['lng'])),
                            width: 34,
                            height: 34,
                            alignment: Alignment.topCenter,
                            child: Tooltip(
                              message: '${o.orderNo} · ${OrderStatus.label(o.status)}\n${o.customerName}',
                              child: GestureDetector(
                                onTap: () => context.go('/orders/${o.id}'),
                                child: Icon(Icons.location_on_rounded, size: 34, color: orderStatusColor(o.status)),
                              ),
                            ),
                          ),
                      ]),
                    MarkerLayer(markers: [
                      for (final d in located)
                        Marker(
                          point: _pos(d)!,
                          width: _selected == d.id ? 180 : 44,
                          height: _selected == d.id ? 92 : 44,
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = _selected == d.id ? null : d.id),
                            child: _RiderMarker(rider: d, selected: _selected == d.id, active: activeByRider[d.id]?.length ?? 0),
                          ),
                        ),
                    ]),
                    SimpleAttributionWidget(source: Text(tr('OpenStreetMap contributors'))),
                  ],
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Wrap(spacing: 8, children: [
                    _chip(context, Icons.two_wheeler_rounded, '${riders.length} online', G4MColors.success),
                    _chip(context, Icons.local_shipping_rounded, '${orders.length} active orders', G4MColors.accent),
                    if (riders.length > located.length) _chip(context, Icons.location_off_rounded, '${riders.length - located.length} without GPS', G4MColors.warning),
                  ]),
                ),
                Positioned(
                  right: 12,
                  bottom: 30,
                  child: Column(children: [
                    _mapBtn(Icons.add_rounded, () => _map.move(_map.camera.center, _map.camera.zoom + 1)),
                    const SizedBox(height: 6),
                    _mapBtn(Icons.remove_rounded, () => _map.move(_map.camera.center, _map.camera.zoom - 1)),
                    const SizedBox(height: 6),
                    _mapBtn(Icons.center_focus_strong_rounded, () {
                      final pts = [for (final d in located) _pos(d)!];
                      if (pts.length > 1) _map.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(60), maxZoom: 15));
                      if (pts.length == 1) _map.move(pts.first, 14);
                    }),
                  ]),
                ),
              ]),
            );

            final side = SectionCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Search riders, city, vehicle…', prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (v) => setState(() => _q = v.toLowerCase()),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: !rs.hasData
                      ? const LoadingBlock(rows: 5)
                      : list.isEmpty
                          ? const EmptyState(icon: Icons.two_wheeler_rounded, title: 'No riders online', message: 'Partners appear here when they go online in the delivery panel or app.')
                          : ListView.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.line),
                              itemBuilder: (_, i) {
                                final d = list[i];
                                final active = activeByRider[d.id] ?? const [];
                                final stale = (d.dt('locationUpdatedAt') == null) || DateTime.now().difference(d.dt('locationUpdatedAt')!).inMinutes > 10;
                                return ListTile(
                                  selected: _selected == d.id,
                                  selectedTileColor: context.pal.accent.withValues(alpha: .08),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  leading: Avatar(name: d.s('name'), url: d.s('photoUrl'), color: G4MColors.accent),
                                  title: Text(d.s('name'), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    '${Fmt.titleCase(d.s('vehicleType', 'bike'))} · ${_pos(d) == null ? 'no GPS' : 'seen ${Fmt.ago(d.dt('locationUpdatedAt'))}'}${active.isNotEmpty ? ' · ${active.length} active' : ''}',
                                    style: TextStyle(fontSize: 12, color: stale ? G4MColors.warning : context.pal.muted),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Partner profile',
                                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                    onPressed: () => context.go('/delivery/partners/${d.id}'),
                                  ),
                                  onTap: () => _focus(d),
                                ).animate(delay: (20 * i).ms).fadeIn();
                              },
                            ),
                ),
              ]),
            );

            if (!wide) {
              return Column(children: [Expanded(flex: 3, child: map), const SizedBox(height: 14), Expanded(flex: 2, child: side)]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: map),
              const SizedBox(width: 16),
              SizedBox(width: 340, child: side),
            ]);
          },
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: BorderRadius.circular(99),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      );

  Widget _mapBtn(IconData i, VoidCallback onTap) => Material(
        color: context.pal.surface,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(8), child: Icon(i, size: 20))),
      );
}

class _RiderMarker extends StatelessWidget {
  const _RiderMarker({required this.rider, required this.selected, required this.active});
  final Doc rider;
  final bool selected;
  final int active;
  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: active > 0 ? G4MColors.accent : G4MColors.success,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: (active > 0 ? G4MColors.accent : G4MColors.success).withValues(alpha: .5), blurRadius: 12)],
      ),
      child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
    );
    if (!selected) {
      return Tooltip(message: rider.s('name'), child: dot.animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(.95, .95), end: const Offset(1.05, 1.05), duration: 1200.ms));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: G4MColors.primaryDeep, borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(rider.s('name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          Text('${rider.s('vehicleNo', Fmt.titleCase(rider.s('vehicleType', 'bike')))} · ${Fmt.ago(rider.dt('locationUpdatedAt'))}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
        ]),
      ),
      const SizedBox(height: 4),
      dot,
    ]);
  }
}
