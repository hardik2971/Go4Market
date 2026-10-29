import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import '../common/preferences_section.dart';
import 'delivery_data.dart';
import 'delivery_widgets.dart';

/// Profile, vehicle, service cities and KYC documents (stored on users/{uid}.documents,
/// since rules only let partners write online/location fields on deliveryPartners/{uid}).
class DeliveryProfileTab extends StatefulWidget {
  const DeliveryProfileTab({super.key});
  @override
  State<DeliveryProfileTab> createState() => _DeliveryProfileTabState();
}

class _DeliveryProfileTabState extends State<DeliveryProfileTab> {
  late final Stream<DeliveryPartner?> _me = DeliveryData.me();
  late final Stream<Json> _user = DeliveryData.userDoc();

  Future<void> _upload(String key) async {
    final url = await pickAndUploadImage(context, 'deliveryPartners/$myUid/docs');
    if (url == null || !mounted) return;
    await runBusy(
      context,
      () => Fs.user(myUid).set({
        'documents': {
          key: {'url': url, 'status': 'submitted', 'uploadedAt': Fs.now},
        },
        'updatedAt': Fs.now,
      }, SetOptions(merge: true)),
      success: context.tr('Document uploaded', 'दस्तावेज़ अपलोड हुआ'),
    );
  }

  Future<void> _changePhoto() async {
    final url = await pickAndUploadImage(context, 'deliveryPartners/$myUid', maxWidth: 800);
    if (url == null || !mounted) return;
    await runBusy(context, () => Fs.user(myUid).set({'photoUrl': url, 'updatedAt': Fs.now}, SetOptions(merge: true)),
        success: context.tr('Photo updated', 'फ़ोटो अपडेट हुई'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.profile)),
      body: StreamBuilder<DeliveryPartner?>(
        stream: _me,
        builder: (context, meSnap) {
          final me = meSnap.data;
          return StreamBuilder<Json>(
            stream: _user,
            builder: (context, uSnap) {
              final user = uSnap.data ?? const <String, dynamic>{};
              final photo = me?.photoUrl.isNotEmpty == true ? me!.photoUrl : '${user['photoUrl'] ?? ''}';
              final docs = user['documents'] is Map ? Map<String, dynamic>.from(user['documents'] as Map) : <String, dynamic>{};
              return ListView(padding: pagePad, children: [
                HeroPanel(
                  child: Row(children: [
                    GestureDetector(
                      onTap: _changePhoto,
                      child: Stack(children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: Avatar(name: me?.name ?? '', url: photo, size: 72),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: G4MColors.accent, shape: BoxShape.circle),
                            child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(me?.name ?? '', style: context.tt.titleLarge?.copyWith(color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(me?.email.isNotEmpty == true ? me!.email : (FirebaseAuthEmail.current), style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          _heroChip(Icons.star_rounded, (me?.rating ?? 0) > 0 ? me!.rating.toStringAsFixed(1) : '—'),
                          _heroChip(Icons.task_alt_rounded, '${me?.completedCount ?? 0}'),
                          _heroChip(Icons.verified_rounded, Fmt.titleCase(me?.status ?? '')),
                        ]),
                      ]),
                    ),
                  ]),
                ).popIn(),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    MenuTile(icon: Icons.call_rounded, title: context.s.phone, subtitle: me?.phone.isNotEmpty == true ? me!.phone : '—', trailing: const SizedBox.shrink()),
                    MenuTile(
                      icon: vehicleIcon(me?.vehicleType ?? 'bike'),
                      title: context.tr('Vehicle', 'वाहन'),
                      subtitle: '${vehicleLabel(context, me?.vehicleType ?? 'bike')} · ${me?.vehicleNo.isNotEmpty == true ? me!.vehicleNo : '—'}',
                      trailing: const SizedBox.shrink(),
                    ),
                    MenuTile(
                      icon: Icons.location_city_rounded,
                      title: context.tr('Service cities', 'सेवा शहर'),
                      subtitle: (me?.cities ?? const []).isEmpty ? '—' : me!.cities.join(', '),
                      trailing: const SizedBox.shrink(),
                    ),
                    MenuTile(
                      icon: Icons.groups_rounded,
                      title: context.tr('Fleet', 'फ़्लीट'),
                      subtitle: me?.ownerType == 'seller'
                          ? context.tr('Store delivery team', 'स्टोर डिलीवरी टीम')
                          : context.tr('Go4Market delivery network', 'Go4Market डिलीवरी नेटवर्क'),
                      trailing: const SizedBox.shrink(),
                    ),
                  ]),
                ).stagger(1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                    context.tr('To change vehicle or cities, contact support.', 'वाहन या शहर बदलने के लिए सहायता से संपर्क करें।'),
                    style: context.tt.bodySmall,
                  ),
                ),
                const SizedBox(height: 8),
                SectionTitle(context.tr('Documents', 'दस्तावेज़')),
                for (final (i, d) in [
                  ('licence', Icons.badge_rounded, context.tr('Driving licence', 'ड्राइविंग लाइसेंस')),
                  ('idProof', Icons.perm_identity_rounded, context.tr('ID proof (Aadhaar / PAN)', 'पहचान पत्र (आधार / पैन)')),
                  ('vehicleRc', Icons.description_rounded, context.tr('Vehicle RC', 'वाहन RC')),
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _docTile(d.$1, d.$2, d.$3, docs[d.$1]).stagger(i + 2),
                  ),
                const SizedBox(height: 8),
                const PreferencesSection(),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _heroChip(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(G4MRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );

  Widget _docTile(String key, IconData icon, String title, dynamic raw) {
    final m = raw is Map ? raw : const {};
    final url = '${m['url'] ?? ''}';
    final status = '${m['status'] ?? ''}';
    return AppCard(
      onTap: () => _upload(key),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        url.isEmpty
            ? Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: context.rc.cardAlt, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: context.rc.faint),
              )
            : NetImage(url, width: 56, height: 56, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.tt.titleSmall),
            Text(url.isEmpty ? context.tr('Tap to upload a photo', 'फ़ोटो अपलोड करने के लिए टैप करें') : context.tr('Tap to replace', 'बदलने के लिए टैप करें'),
                style: context.tt.bodySmall),
          ]),
        ),
        if (url.isEmpty)
          Icon(Icons.upload_rounded, color: context.rc.brand)
        else
          InfoChip(
            icon: status == 'verified' ? Icons.verified_rounded : Icons.schedule_rounded,
            label: Fmt.titleCase(status.isEmpty ? 'submitted' : status),
            color: status == 'verified' ? G4MColors.success : (status == 'rejected' ? G4MColors.danger : G4MColors.info),
          ),
      ]),
    );
  }
}

/// Small accessor so the profile can show the auth email when the partner doc lacks one.
abstract final class FirebaseAuthEmail {
  static String get current => AuthRepo.instance.user?.email ?? '';
}
