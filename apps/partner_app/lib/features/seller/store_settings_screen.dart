import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'seller_registration_screen.dart' show gstinPattern, ifscPattern;

/// Edit own store profile. Writes only profile fields (never status/commissionPct/balance).
class StoreSettingsScreen extends StatelessWidget {
  const StoreSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Fs.sellers.doc(myUid).get(),
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(appBar: AppBar(), body: ErrorView(snap.error!));
        if (!snap.hasData) return Scaffold(appBar: AppBar(), body: const SkeletonList(count: 5));
        final d = snap.data!;
        return _StoreForm(seller: Seller(d.id, d.data() ?? {}));
      },
    );
  }
}

class _StoreForm extends StatefulWidget {
  const _StoreForm({required this.seller});
  final Seller seller;
  @override
  State<_StoreForm> createState() => _StoreFormState();
}

class _StoreFormState extends State<_StoreForm> {
  final _form = GlobalKey<FormState>();
  late final s = widget.seller;
  late final Json _bank = s.data['bank'] is Map ? Map<String, dynamic>.from(s.data['bank'] as Map) : {};
  late final _name = TextEditingController(text: s.storeName);
  late final _desc = TextEditingController(text: s.description);
  late final _phone = TextEditingController(text: s.phone);
  late final _address = TextEditingController(text: s.address);
  late final _city = TextEditingController(text: s.city);
  late final _gstin = TextEditingController(text: '${s.data['gstin'] ?? ''}');
  late final _holder = TextEditingController(text: '${_bank['holder'] ?? ''}');
  late final _account = TextEditingController(text: '${_bank['account'] ?? ''}');
  late final _ifsc = TextEditingController(text: '${_bank['ifsc'] ?? ''}');
  late String _logo = s.logo;
  late String _banner = s.banner;
  late LatLng? _pin = (s.data['lat'] is num && s.data['lng'] is num)
      ? LatLng((s.data['lat'] as num).toDouble(), (s.data['lng'] as num).toDouble())
      : null;

  @override
  void dispose() {
    for (final c in [_name, _desc, _phone, _address, _city, _gstin, _holder, _account, _ifsc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runBusy(context, () async {
      await Fs.sellers.doc(myUid).update({
        'storeName': _name.text.trim(),
        'description': _desc.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'gstin': _gstin.text.trim().toUpperCase(),
        'bank': {'holder': _holder.text.trim(), 'account': _account.text.trim(), 'ifsc': _ifsc.text.trim().toUpperCase()},
        'logo': _logo,
        'banner': _banner,
        'lat': ?_pin?.latitude,
        'lng': ?_pin?.longitude,
        'updatedAt': Fs.now,
      });
      return true;
    });
    if (ok == true && mounted) {
      toast(context, context.tr('Store updated', 'स्टोर अपडेट हुआ'));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? req(String? v) => (v ?? '').trim().isEmpty ? context.tr('Required', 'आवश्यक') : null;
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Store settings', 'स्टोर सेटिंग्स'))),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 110), children: [
          // Banner + logo header
          SizedBox(
            height: 190,
            child: Stack(clipBehavior: Clip.none, children: [
              Pressable(
                onTap: () async {
                  final u = await pickAndUploadImage(context, 'sellers/$myUid', maxWidth: 1800);
                  if (u != null) setState(() => _banner = u);
                },
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(gradient: context.rc.hero, borderRadius: BorderRadius.circular(G4MRadius.lg)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(fit: StackFit.expand, children: [
                    if (_banner.isNotEmpty) NetImage(_banner),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircleAvatar(backgroundColor: Colors.black45, child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18)),
                      ),
                    ),
                  ]),
                ),
              ),
              Positioned(
                left: 20,
                bottom: 0,
                child: Pressable(
                  onTap: () async {
                    final u = await pickAndUploadImage(context, 'sellers/$myUid', maxWidth: 800);
                    if (u != null) setState(() => _logo = u);
                  },
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.rc.card, width: 4), boxShadow: G4MShadows.soft),
                    child: Avatar(name: _name.text, url: _logo, size: 80),
                  ),
                ),
              ),
            ]),
          ).stagger(i++),
          _card(context.tr('Store', 'स्टोर'), [
            TextFormField(controller: _name, validator: req, decoration: InputDecoration(labelText: context.tr('Store name', 'स्टोर का नाम'))),
            const SizedBox(height: 10),
            TextFormField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: context.tr('Description', 'विवरण'))),
            const SizedBox(height: 10),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, validator: req, decoration: InputDecoration(labelText: context.s.phone)),
          ]).stagger(i++),
          _card(context.tr('Address', 'पता'), [
            TextFormField(controller: _address, maxLines: 2, validator: req, decoration: InputDecoration(labelText: context.tr('Address', 'पता'))),
            const SizedBox(height: 10),
            TextFormField(controller: _city, validator: req, decoration: InputDecoration(labelText: context.tr('City', 'शहर'))),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: Icon(_pin == null ? Icons.add_location_alt_rounded : Icons.where_to_vote_rounded),
              label: Text(_pin == null
                  ? context.tr('Pin on map', 'मानचित्र पर पिन करें')
                  : '${_pin!.latitude.toStringAsFixed(4)}, ${_pin!.longitude.toStringAsFixed(4)}'),
              onPressed: () async {
                final p = await Go.push<LatLng>(context, MapPickScreen(initial: _pin));
                if (p != null) setState(() => _pin = p);
              },
            ),
          ]).stagger(i++),
          _card(context.tr('Tax & bank', 'टैक्स और बैंक'), [
            TextFormField(
              controller: _gstin,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'GSTIN'),
              validator: (v) {
                final t = (v ?? '').trim().toUpperCase();
                return t.isEmpty || gstinPattern.hasMatch(t) ? null : context.tr('Invalid GSTIN format', 'GSTIN प्रारूप अमान्य है');
              },
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _holder, decoration: InputDecoration(labelText: context.tr('Account holder', 'खाताधारक'))),
            const SizedBox(height: 10),
            TextFormField(controller: _account, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('Account number', 'खाता संख्या'))),
            const SizedBox(height: 10),
            TextFormField(
              controller: _ifsc,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'IFSC'),
              validator: (v) {
                final t = (v ?? '').trim().toUpperCase();
                return t.isEmpty || ifscPattern.hasMatch(t) ? null : context.tr('Invalid IFSC', 'अमान्य IFSC');
              },
            ),
          ]).stagger(i++),
          const SizedBox(height: 12),
          AppCard(
            child: Row(children: [
              Icon(Icons.verified_user_rounded, color: statusColor(s.status)),
              const SizedBox(width: 10),
              Expanded(child: Text('${context.s.status}: ${Fmt.titleCase(s.status)} · ${context.tr('Commission', 'कमीशन')} ${s.commissionPct.toStringAsFixed(0)}%')),
            ]),
          ).stagger(i++),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(onPressed: _save, child: Text(context.s.save)),
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: context.tt.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );
}
