import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/partner_theme.dart';
import '../splash/doodle_painter.dart';

/// Compares dotted versions: negative if a is older than b, 0 if equal, positive if newer.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// Wraps the whole app: when `settings/platform.appVersions.partner.min` is newer
/// than the installed version, a blocking Force Update screen covers everything.
/// Also surfaces `maintenance` as a slim banner.
class VersionGate extends StatefulWidget {
  const VersionGate({super.key, required this.child});
  final Widget child;
  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  late final Stream<PlatformSettings> _settings = SettingsRepo.instance.platform().handleError((_) {});
  String? _installed;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _installed = p.version);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlatformSettings>(
      stream: _settings,
      builder: (context, snap) {
        final s = snap.data;
        final partner = s?.appVersions['partner'];
        final min = partner is Map ? '${partner['min'] ?? ''}' : '';
        final latest = partner is Map ? '${partner['latest'] ?? ''}' : '';
        final mustUpdate = _installed != null && min.isNotEmpty && compareVersions(_installed!, min) < 0;
        return Stack(children: [
          widget.child,
          if (s?.maintenance == true && !mustUpdate)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: G4MColors.warning,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      context.tr('Scheduled maintenance in progress. Some features may be unavailable.',
                          'रखरखाव जारी है। कुछ सुविधाएं उपलब्ध नहीं हो सकती हैं।'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          if (mustUpdate)
            Positioned.fill(child: ForceUpdateScreen(installed: _installed!, latest: latest.isEmpty ? min : latest).animate().fadeIn(duration: 400.ms)),
        ]);
      },
    );
  }
}

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.installed, required this.latest});
  final String installed;
  final String latest;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: DoodleBackground(color: G4MColors.primary, opacity: .05)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Spacer(),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(color: context.rc.brandSoft, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const G4MLogo(size: 84),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(.96, .96), end: const Offset(1.04, 1.04), duration: 1400.ms, curve: Curves.easeInOut),
                const SizedBox(height: 32),
                Text(context.s.updateRequired, textAlign: TextAlign.center, style: context.tt.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    'A new version of Go4Market Partner is available with important improvements. Please update to keep receiving orders.',
                    'Go4Market Partner का नया संस्करण उपलब्ध है। ऑर्डर मिलते रहने के लिए कृपया अपडेट करें।',
                  ),
                  textAlign: TextAlign.center,
                  style: context.tt.bodyMedium?.copyWith(color: context.rc.muted, height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: context.rc.cardAlt, borderRadius: BorderRadius.circular(G4MRadius.pill)),
                  child: Text('v$installed  →  v$latest', style: context.tt.labelLarge),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.system_update_rounded),
                    label: Text(context.s.updateNow),
                    onPressed: () => launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
