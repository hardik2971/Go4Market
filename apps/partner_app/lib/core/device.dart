import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';
import 'motion.dart';
import 'partner_theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------------------
// Launchers
// ---------------------------------------------------------------------------

Future<void> callPhone(BuildContext context, String phone) async {
  final p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (p.isEmpty) {
    toast(context, context.tr('No phone number available', 'फ़ोन नंबर उपलब्ध नहीं है'), error: true);
    return;
  }
  await launchUrl(Uri(scheme: 'tel', path: p));
}

/// Opens turn-by-turn navigation in Google Maps (falls back to the browser).
Future<void> openNavigation(double lat, double lng) async {
  final nav = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
  if (await canLaunchUrl(nav)) {
    await launchUrl(nav);
    return;
  }
  await launchUrl(
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'),
    mode: LaunchMode.externalApplication,
  );
}

const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.go4market.partner';

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

/// Asks camera/gallery, compresses, uploads via [StorageRepo] and returns the URL.
Future<String?> pickAndUploadImage(BuildContext context, String folder, {double maxWidth = 1600}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(c.tr('Take photo', 'फ़ोटो लें')),
          onTap: () => Navigator.pop(c, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(c.tr('Choose from gallery', 'गैलरी से चुनें')),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null || !context.mounted) return null;
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(source: source, maxWidth: maxWidth, imageQuality: 82);
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e), error: true);
    return null;
  }
  if (file == null || !context.mounted) return null;
  final f = file;
  return runBusy<String>(context, () async {
    final bytes = await f.readAsBytes();
    final name = f.name.isEmpty ? 'image.jpg' : f.name;
    final type = name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    return StorageRepo.instance.upload(folder, name, bytes, contentType: type);
  });
}

// ---------------------------------------------------------------------------
// Barcode scanner
// ---------------------------------------------------------------------------

/// Pushes a full-screen scanner; resolves with the first barcode value or null.
Future<String?> scanBarcode(BuildContext context) => Go.push<String>(context, const BarcodeScanScreen());

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});
  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> with SingleTickerProviderStateMixin {
  final _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  late final _line = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _line.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_done) return;
    final v = cap.barcodes.map((b) => b.rawValue).whereType<String>().where((s) => s.isNotEmpty).firstOrNull;
    if (v == null) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(context.tr('Scan barcode', 'बारकोड स्कैन करें')),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on_rounded), onPressed: () => _ctrl.toggleTorch()),
          IconButton(icon: const Icon(Icons.cameraswitch_rounded), onPressed: () => _ctrl.switchCamera()),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: _onDetect,
          errorBuilder: (c, e) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                c.tr('Camera unavailable. Allow camera access in settings.', 'कैमरा उपलब्ध नहीं है। सेटिंग्स में अनुमति दें।'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Center(
          child: SizedBox(
            width: 270,
            height: 170,
            child: Stack(children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: .9), width: 2.5),
                ),
              ),
              AnimatedBuilder(
                animation: _line,
                builder: (_, _) => Positioned(
                  left: 14,
                  right: 14,
                  top: 12 + 146 * Curves.easeInOut.transform(_line.value),
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: G4MColors.accent,
                      boxShadow: [BoxShadow(color: G4MColors.accent.withValues(alpha: .7), blurRadius: 12)],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Column(children: [
            Text(context.tr('Point the camera at a barcode', 'कैमरा को बारकोड पर रखें'),
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final v = await promptText(context, title: context.tr('Enter code manually', 'कोड दर्ज करें'), keyboard: TextInputType.number);
                if (v != null && context.mounted) Navigator.pop(context, v);
              },
              child: Text(context.tr('Type it instead', 'टाइप करें'), style: const TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Maps (OpenStreetMap via flutter_map)
// ---------------------------------------------------------------------------

/// Standard OSM tile layer (dark mode dims tiles with a colour filter at the call site if wanted).
TileLayer osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.go4market.partner',
      maxZoom: 19,
    );

/// OSM attribution, required by the tile usage policy.
Widget osmAttribution() => const SimpleAttributionWidget(source: Text('OpenStreetMap contributors'));

/// Map pin used for store / customer / rider markers.
class MapPin extends StatelessWidget {
  const MapPin({super.key, required this.icon, required this.color, this.pulse = false});
  final IconData icon;
  final Color color;
  final bool pulse;
  @override
  Widget build(BuildContext context) {
    final pin = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .45), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
    if (!pulse) return pin;
    return Stack(alignment: Alignment.center, children: [
      PulseDot(color: color, size: 28),
      pin,
    ]);
  }
}

Marker pinMarker(LatLng p, IconData icon, Color color, {bool pulse = false}) =>
    Marker(point: p, width: pulse ? 64 : 44, height: pulse ? 64 : 44, child: MapPin(icon: icon, color: color, pulse: pulse));

/// Full-screen picker: drag the map under a fixed centre pin; returns the chosen LatLng.
class MapPickScreen extends StatefulWidget {
  const MapPickScreen({super.key, this.initial});
  final LatLng? initial;
  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  final _map = MapController();
  late LatLng _center = widget.initial ?? const LatLng(28.6139, 77.2090); // New Delhi fallback
  bool _moving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Pin your store location', 'स्टोर का स्थान चुनें'))),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 15,
            onPositionChanged: (cam, gesture) {
              _center = cam.center;
              if (gesture && !_moving) setState(() => _moving = true);
            },
            onMapEvent: (e) {
              if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd) setState(() => _moving = false);
            },
          ),
          children: [osmTiles(), osmAttribution()],
        ),
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: AnimatedSlide(
                offset: Offset(0, _moving ? -.25 : 0),
                duration: G4MMotion.standard,
                curve: G4MMotion.curve,
                child: Icon(Icons.location_on_rounded, size: 52, color: context.rc.brand, shadows: const [Shadow(color: Colors.black26, blurRadius: 10)]),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: SafeArea(
            child: FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: Text(context.tr('Use this location', 'यह स्थान उपयोग करें')),
              onPressed: () => Navigator.pop(context, _center),
            ),
          ),
        ),
      ]),
    );
  }
}
