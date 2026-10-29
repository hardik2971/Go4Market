import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/location.dart';
import '../../core/nav.dart';
import '../../core/prefs.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ui.dart';

/// Result of the map picker when used for an address form.
class PickedPoint {
  const PickedPoint(this.point, this.address);
  final LatLng point;
  final GeoAddress? address;
}

/// OpenStreetMap picker: the map moves under a fixed centre pin, the address below updates
/// (reverse geocoded via Nominatim). Cities from `cities` are quick-jump chips.
///
/// [forAddress] = true returns a [PickedPoint]; otherwise returns a [ShopLocation].
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.forAddress = false, this.initial});
  final bool forAddress;
  final LatLng? initial;
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> with SingleTickerProviderStateMixin {
  final _map = MapController();
  late LatLng _center;
  GeoAddress? _addr;
  bool _resolving = false, _locating = false, _moving = false;
  Timer? _debounce;
  late final _pinBounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);
  final _searchCtl = TextEditingController();
  List<(String, LatLng)> _results = [];
  List<Json> _cities = [];

  @override
  void initState() {
    super.initState();
    final saved = AppPrefs.instance.location;
    _center = widget.initial ?? (saved?.hasPoint == true ? LatLng(saved!.lat!, saved.lng!) : LocationService.fallback);
    _resolve();
    Fs.cities.where('active', isEqualTo: true).get().then((s) {
      if (mounted) setState(() => _cities = s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
    }).catchError((_) {});
    if (widget.initial == null && saved?.hasPoint != true) WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrent());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pinBounce.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    final p = await LocationService.current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      context.toast('Location unavailable. Allow location access or move the map.', error: true);
      return;
    }
    _map.move(p, 16);
    _center = p;
    _resolve();
  }

  void _resolve() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 550), () async {
      setState(() => _resolving = true);
      final a = await LocationService.reverse(_center);
      if (!mounted) return;
      setState(() {
        _addr = a;
        _resolving = false;
      });
    });
  }

  void _onMove(MapCamera cam, bool gesture) {
    _center = cam.center;
    if (gesture && !_moving) setState(() => _moving = true);
  }

  void _onMoveEnd() {
    if (!_moving) return;
    setState(() => _moving = false);
    _pinBounce.forward(from: 0);
    _resolve();
  }

  Future<void> _search(String q) async {
    final r = await LocationService.search(q);
    if (mounted) setState(() => _results = r);
  }

  void _confirm() {
    final a = _addr;
    if (widget.forAddress) {
      Navigator.of(context).pop(PickedPoint(_center, a));
      return;
    }
    final city = a?.city ?? '';
    final label = a == null ? 'Pinned location' : (a.area.isNotEmpty ? '${a.area}, ${a.city}' : (city.isNotEmpty ? city : 'Pinned location'));
    Navigator.of(context).pop(ShopLocation(label: label, city: city, lat: _center.latitude, lng: _center.longitude, pincode: a?.pincode ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(children: [
        Listener(
          onPointerUp: (_) => Future.delayed(const Duration(milliseconds: 250), _onMoveEnd),
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 19,
              onPositionChanged: _onMove,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.go4market.customer',
                tileBuilder: context.isDark ? _darkTiles : null,
              ),
              const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
            ],
          ),
        ),
        // Centre pin.
        IgnorePointer(
          child: Center(
            child: AnimatedBuilder(
              animation: _pinBounce,
              builder: (_, child) {
                final lift = _moving ? -16.0 : -16 * (1 - Curves.bounceOut.transform(_pinBounce.value));
                return Transform.translate(offset: Offset(0, -24 + lift), child: child);
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: G4MColors.primaryDeep, borderRadius: BorderRadius.circular(10)),
                  child: Text(widget.forAddress ? 'Your address is here' : 'Deliver here',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const Icon(Icons.location_on_rounded, color: G4MColors.primary, size: 48),
              ]),
            ),
          ),
        ),
        // Top bar with search.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(children: [
              Row(children: [
                IconButton.filledTonal(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded)),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    elevation: 0,
                    color: Colors.transparent,
                    child: TextField(
                      controller: _searchCtl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: 'Search area, street, landmark',
                        prefixIcon: const Icon(Icons.search_rounded),
                        fillColor: context.card,
                        suffixIcon: _searchCtl.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() {
                                  _searchCtl.clear();
                                  _results = [];
                                }),
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ]),
              if (_results.isNotEmpty)
                AppCard(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    for (final r in _results)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined),
                        title: Text(r.$1, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _map.move(r.$2, 16);
                          _center = r.$2;
                          setState(() => _results = []);
                          _resolve();
                        },
                      ),
                  ]),
                ).animate().fadeIn().slideY(begin: -.05),
              if (_cities.isNotEmpty && _results.isEmpty)
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: _cities.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = _cities[i];
                      return ActionChip(
                        avatar: const Icon(Icons.location_city_rounded, size: 16),
                        label: Text('${c['name'] ?? c['id']}'),
                        backgroundColor: context.card,
                        onPressed: () {
                          final lat = c['lat'], lng = c['lng'];
                          if (lat is num && lng is num) {
                            final p = LatLng(lat.toDouble(), lng.toDouble());
                            _map.move(p, 13);
                            _center = p;
                            _resolve();
                          }
                        },
                      );
                    },
                  ),
                ),
            ]),
          ),
        ),
        // Bottom sheet.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: const [BoxShadow(color: Color(0x220A4A33), blurRadius: 30, offset: Offset(0, -6))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _locating ? null : _useCurrent,
                  icon: _locating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded),
                  label: Text(l.useCurrentLocation),
                ),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: context.softPrimary, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.location_on_rounded, color: G4MColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: G4MMotion.standard,
                    child: _resolving || _moving
                        ? const Column(key: ValueKey('l'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Shimmer(width: 160, height: 16),
                            SizedBox(height: 8),
                            Shimmer(height: 12),
                          ])
                        : Column(key: ValueKey(_addr?.display), crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              _addr == null ? 'Pinned location' : (_addr!.area.isNotEmpty ? _addr!.area : (_addr!.city.isNotEmpty ? _addr!.city : 'Pinned location')),
                              style: context.text.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _addr?.display ?? '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall,
                            ),
                          ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              FilledButton(onPressed: _moving ? null : _confirm, child: Text(l.confirmLocation)),
            ]),
          ),
        ),
      ]),
    );
  }

  static Widget _darkTiles(BuildContext context, Widget tile, TileImage image) => ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -0.8, 0, 0, 0, 220, //
          0, -0.8, 0, 0, 230,
          0, 0, -0.8, 0, 225,
          0, 0, 0, 1, 0,
        ]),
        child: tile,
      );
}
