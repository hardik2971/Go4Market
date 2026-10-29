import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';

/// OpenStreetMap tiles + required attribution.
List<Widget> osmBase() => [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.go4market.website',
        maxZoom: 19,
      ),
      SimpleAttributionWidget(
        source: Text(L.current.cart.osmContributors),
        onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
      ),
    ];

const kDefaultCenter = LatLng(28.6139, 77.2090);

class MapPin extends StatelessWidget {
  const MapPin({super.key, this.color = G4MColors.primary, this.icon = Icons.home_rounded, this.size = 44});
  final Color color;
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: G4MShadows.lifted),
          child: Icon(icon, color: Colors.white, size: size * .5),
        ),
        Container(width: 3, height: 10, color: color),
      ]);
}

/// Drag-the-map address picker: the pin stays centred and reports the map centre.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.initial, required this.onChanged, this.controller});
  final LatLng initial;
  final ValueChanged<LatLng> onChanged;
  final MapController? controller;
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(G4MRadius.md),
        child: Stack(children: [
          FlutterMap(
            mapController: widget.controller,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 15,
              onPositionChanged: (cam, _) => widget.onChanged(cam.center),
            ),
            children: osmBase(),
          ),
          const IgnorePointer(child: Center(child: Padding(padding: EdgeInsets.only(bottom: 52), child: MapPin(icon: Icons.location_on_rounded)))),
          PositionedDirectional(
            start: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(G4MRadius.pill), boxShadow: G4MShadows.soft),
              child: Text(context.l.cart.movePinHint, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );
}
