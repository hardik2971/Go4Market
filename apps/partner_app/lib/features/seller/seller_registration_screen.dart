import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:latlong2/latlong.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../auth/auth_routing.dart';
import '../auth/root_gate.dart';

final gstinPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
final ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

/// Multi-step seller onboarding -> `registerSeller`.
class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});
  @override
  State<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _page = PageController();
  int _step = 0;
  static const _steps = 5;
  final _forms = List.generate(5, (_) => GlobalKey<FormState>());

  final _storeName = TextEditingController();
  // Prefilled from the sign-in provider (phone / Google) when available.
  final _owner = TextEditingController(text: _pick(Session.instance.prefill.name, FirebaseAuth.instance.currentUser?.displayName));
  final _phone = TextEditingController(text: nationalPhone(_pick(Session.instance.prefill.phone, FirebaseAuth.instance.currentUser?.phoneNumber)));
  final _email = TextEditingController(text: _pick(Session.instance.prefill.email, FirebaseAuth.instance.currentUser?.email));

  static String _pick(String? a, String? b) => (a != null && a.trim().isNotEmpty) ? a.trim() : (b ?? '').trim();
  final _desc = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  final _gstin = TextEditingController();
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  final Set<String> _modules = {};
  LatLng? _pin;
  String _logo = '';
  String _banner = '';
  bool _policies = false;

  @override
  void dispose() {
    _page.dispose();
    for (final c in [_storeName, _owner, _phone, _email, _desc, _address, _city, _pincode, _gstin, _holder, _account, _ifsc]) {
      c.dispose();
    }
    super.dispose();
  }

  String _title(BuildContext c, int i) => [
        c.tr('Store details', 'स्टोर विवरण'),
        c.tr('Store address', 'स्टोर का पता'),
        c.tr('Tax & bank', 'टैक्स और बैंक'),
        c.tr('Branding', 'ब्रांडिंग'),
        c.tr('Review & submit', 'समीक्षा और जमा करें'),
      ][i];

  void _go(int i) {
    FocusScope.of(context).unfocus();
    setState(() => _step = i);
    _page.animateToPage(i, duration: G4MMotion.emphasized, curve: G4MMotion.curve);
  }

  void _next() {
    if (!(_forms[_step].currentState?.validate() ?? true)) {
      HapticFeedback.lightImpact();
      return;
    }
    if (_step == 1 && _pin == null) {
      toast(context, context.tr('Pin your store on the map', 'मानचित्र पर स्टोर पिन करें'), error: true);
      return;
    }
    if (_step < _steps - 1) {
      _go(_step + 1);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (!_policies) {
      toast(context, context.tr('Please accept the seller policies', 'कृपया विक्रेता नीतियां स्वीकार करें'), error: true);
      return;
    }
    final bank = {'holder': _holder.text.trim(), 'account': _account.text.trim(), 'ifsc': _ifsc.text.trim().toUpperCase()};
    final address = [_address.text.trim(), _city.text.trim(), _pincode.text.trim()].where((e) => e.isNotEmpty).join(', ');
    final input = <String, dynamic>{
      'storeName': _storeName.text.trim(),
      'ownerName': _owner.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'city': _city.text.trim(),
      'address': address,
      'pincode': _pincode.text.trim(),
      if (_gstin.text.trim().isNotEmpty) 'gstin': _gstin.text.trim().toUpperCase(),
      'description': _desc.text.trim(),
      'modules': _modules.toList(),
      'lat': _pin?.latitude,
      'lng': _pin?.longitude,
      'bank': bank,
      'logo': _logo,
      'banner': _banner,
      'policiesAccepted': true,
    };
    final ok = await runBusy<bool>(context, () async {
      await G4MApi.instance.registerSeller(input);
      await Session.instance.refreshClaims();
      try {
        await Fs.sellers.doc(myUid).set({
          if (_logo.isNotEmpty) 'logo': _logo,
          if (_banner.isNotEmpty) 'banner': _banner,
          'lat': ?_pin?.latitude,
          'lng': ?_pin?.longitude,
          'description': _desc.text.trim(),
          'bank': bank,
          if (_gstin.text.trim().isNotEmpty) 'gstin': _gstin.text.trim().toUpperCase(),
          'policiesAccepted': true,
          'updatedAt': Fs.now,
        }, SetOptions(merge: true));
      } catch (_) {}
      return true;
    });
    if (ok == true && mounted) {
      await showSuccess(context,
          title: context.tr('Application submitted', 'आवेदन जमा हुआ'),
          subtitle: context.tr('We will review your store shortly.', 'हम जल्द ही आपके स्टोर की समीक्षा करेंगे।'));
      if (mounted) Go.root(context, const RootGate());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did && _step > 0) _go(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _step == 0
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.maybePop(context))
              : IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _go(_step - 1)),
          title: Text(context.s.sellOn),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: G4MMotion.standard,
                    child: Text(_title(context, _step), key: ValueKey(_step), style: context.tt.headlineSmall),
                  ),
                ),
                Text('${_step + 1}/$_steps', style: context.tt.labelLarge?.copyWith(color: context.rc.muted)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                for (var i = 0; i < _steps; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: G4MMotion.emphasized,
                      curve: G4MMotion.curve,
                      height: 5,
                      margin: EdgeInsets.only(right: i == _steps - 1 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i <= _step ? context.rc.brand : context.rc.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [_storeStep(), _addressStep(), _bankStep(), _brandStep(), _reviewStep()],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_step == _steps - 1 ? context.tr('Submit application', 'आवेदन जमा करें') : context.s.next),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _wrap(int i, List<Widget> children) => Form(
        key: _forms[i],
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [for (var k = 0; k < children.length; k++) children[k].stagger(k, stepMs: 35)],
        ),
      );

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('Required', 'आवश्यक') : null;

  Widget _storeStep() => _wrap(0, [
        FieldLabel(context.tr('Store name', 'स्टोर का नाम')),
        TextFormField(controller: _storeName, validator: _req, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront_rounded))),
        FieldLabel(context.tr('Owner name', 'मालिक का नाम')),
        TextFormField(controller: _owner, validator: _req, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded))),
        FieldLabel(context.s.phone),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? context.tr('Enter a valid phone', 'मान्य फ़ोन दर्ज करें') : null,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.call_outlined), prefixText: '+91 '),
        ),
        FieldLabel(context.s.email),
        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, validator: _req,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline_rounded))),
        FieldLabel(context.tr('About your store', 'आपके स्टोर के बारे में')),
        TextFormField(controller: _desc, maxLines: 3, decoration: InputDecoration(hintText: context.tr('What do you sell?', 'आप क्या बेचते हैं?'))),
        FieldLabel(context.tr('What will you sell?', 'आप क्या बेचेंगे?')),
        StreamBuilder<List<MarketModule>>(
          stream: CatalogRepo.instance.modules(),
          builder: (context, s) {
            final mods = s.data ??
                [
                  for (final m in const ['ecommerce', 'grocery', 'pharmacy', 'food']) MarketModule(m, {'name': Fmt.titleCase(m)}),
                ];
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in mods)
                FilterChip(
                  label: Text(m.name.isEmpty ? Fmt.titleCase(m.id) : m.name),
                  selected: _modules.contains(m.id),
                  onSelected: (v) => setState(() => v ? _modules.add(m.id) : _modules.remove(m.id)),
                ),
            ]);
          },
        ),
      ]);

  Widget _addressStep() => _wrap(1, [
        FieldLabel(context.tr('Shop address', 'दुकान का पता')),
        TextFormField(controller: _address, validator: _req, maxLines: 2,
            decoration: InputDecoration(hintText: context.tr('Shop no, street, area', 'दुकान नं, गली, क्षेत्र'))),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FieldLabel(context.tr('City', 'शहर')),
              TextFormField(controller: _city, validator: _req, textCapitalization: TextCapitalization.words),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FieldLabel(context.tr('Pincode', 'पिनकोड')),
              TextFormField(controller: _pincode, keyboardType: TextInputType.number, maxLength: 6,
                  decoration: const InputDecoration(counterText: '')),
            ]),
          ),
        ]),
        FieldLabel(context.tr('Map location', 'मानचित्र स्थान')),
        AppCard(
          onTap: () async {
            final p = await Go.push<LatLng>(context, MapPickScreen(initial: _pin));
            if (p != null) setState(() => _pin = p);
          },
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: context.rc.brandSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(_pin == null ? Icons.add_location_alt_rounded : Icons.where_to_vote_rounded, color: context.rc.brand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_pin == null ? context.tr('Pin your store on the map', 'मानचित्र पर स्टोर पिन करें') : context.tr('Location pinned', 'स्थान पिन हो गया'),
                    style: context.tt.titleSmall),
                Text(
                  _pin == null
                      ? context.tr('Helps riders and customers find you', 'राइडर और ग्राहकों को आपको ढूंढने में मदद करता है')
                      : '${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}',
                  style: context.tt.bodySmall,
                ),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: context.rc.faint),
          ]),
        ),
      ]);

  Widget _bankStep() => _wrap(2, [
        FieldLabel(context.tr('GSTIN (optional)', 'GSTIN (वैकल्पिक)')),
        TextFormField(
          controller: _gstin,
          textCapitalization: TextCapitalization.characters,
          maxLength: 15,
          validator: (v) {
            final s = (v ?? '').trim().toUpperCase();
            if (s.isEmpty) return null;
            return gstinPattern.hasMatch(s) ? null : context.tr('Invalid GSTIN format', 'GSTIN प्रारूप अमान्य है');
          },
          decoration: const InputDecoration(hintText: '22AAAAA0000A1Z5', counterText: '', prefixIcon: Icon(Icons.receipt_long_outlined)),
        ),
        const SizedBox(height: 8),
        SectionTitle(context.tr('Payout bank account', 'भुगतान बैंक खाता')),
        FieldLabel(context.tr('Account holder', 'खाताधारक')),
        TextFormField(controller: _holder, validator: _req, textCapitalization: TextCapitalization.words),
        FieldLabel(context.tr('Account number', 'खाता संख्या')),
        TextFormField(
          controller: _account,
          keyboardType: TextInputType.number,
          validator: (v) => (v ?? '').trim().length < 6 ? context.tr('Enter a valid account number', 'मान्य खाता संख्या दर्ज करें') : null,
        ),
        FieldLabel('IFSC'),
        TextFormField(
          controller: _ifsc,
          textCapitalization: TextCapitalization.characters,
          maxLength: 11,
          decoration: const InputDecoration(counterText: '', hintText: 'HDFC0001234'),
          validator: (v) => ifscPattern.hasMatch((v ?? '').trim().toUpperCase()) ? null : context.tr('Invalid IFSC', 'अमान्य IFSC'),
        ),
      ]);

  Widget _brandStep() => _wrap(3, [
        Text(context.tr('Add a logo and banner so customers recognise your store. You can change these later.',
            'लोगो और बैनर जोड़ें ताकि ग्राहक आपका स्टोर पहचानें। आप इन्हें बाद में बदल सकते हैं।'),
            style: context.tt.bodyMedium?.copyWith(color: context.rc.muted)),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 2.4,
          child: _uploadBox(_banner, context.tr('Upload banner', 'बैनर अपलोड करें'), Icons.panorama_rounded, () async {
            final u = await pickAndUploadImage(context, 'sellers/$myUid', maxWidth: 1800);
            if (u != null) setState(() => _banner = u);
          }),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 130,
            height: 130,
            child: _uploadBox(_logo, context.tr('Logo', 'लोगो'), Icons.add_photo_alternate_rounded, () async {
              final u = await pickAndUploadImage(context, 'sellers/$myUid', maxWidth: 800);
              if (u != null) setState(() => _logo = u);
            }, radius: 65),
          ),
        ),
      ]);

  Widget _uploadBox(String url, String label, IconData icon, VoidCallback onTap, {double radius = G4MRadius.md}) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: G4MMotion.standard,
          decoration: BoxDecoration(
            color: context.rc.cardAlt,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.rc.line, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: url.isNotEmpty
              ? Stack(fit: StackFit.expand, children: [
                  NetImage(url),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: CircleAvatar(radius: 16, backgroundColor: Colors.black54, child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white)),
                  ),
                ]).animate().fadeIn()
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: context.rc.brand, size: 30),
                  const SizedBox(height: 6),
                  Text(label, style: context.tt.labelLarge?.copyWith(color: context.rc.muted)),
                ]),
        ),
      );

  Widget _reviewStep() {
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: context.tt.bodySmall)),
            Expanded(child: Text(v.isEmpty ? '—' : v, style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          ]),
        );
    final acct = _account.text.trim();
    return _wrap(4, [
      AppCard(
        child: Column(children: [
          row(context.tr('Store', 'स्टोर'), _storeName.text),
          row(context.tr('Owner', 'मालिक'), _owner.text),
          row(context.s.phone, _phone.text),
          row(context.s.email, _email.text),
          row(context.tr('Address', 'पता'), [_address.text, _city.text, _pincode.text].where((e) => e.trim().isNotEmpty).join(', ')),
          row('GSTIN', _gstin.text.toUpperCase()),
          row(context.tr('Bank', 'बैंक'), acct.isEmpty ? '' : '•••• ${acct.length > 4 ? acct.substring(acct.length - 4) : acct} · ${_ifsc.text.toUpperCase()}'),
          row(context.tr('Modules', 'मॉड्यूल'), _modules.map(Fmt.titleCase).join(', ')),
        ]),
      ),
      const SizedBox(height: 16),
      AppCard(
        borderColor: _policies ? context.rc.brand : null,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(children: [
          Checkbox(value: _policies, onChanged: (v) => setState(() => _policies = v ?? false)),
          Expanded(
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(context.tr('I accept the ', 'मैं स्वीकार करता/करती हूं ')),
              GestureDetector(
                onTap: () => _showPolicies(context),
                child: Text(context.tr('seller policies & terms', 'विक्रेता नीतियां और शर्तें'),
                    style: TextStyle(color: context.rc.brand, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  void _showPolicies(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        builder: (c, sc) => FutureBuilder<CmsPage?>(
          future: CatalogRepo.instance.page('terms'),
          builder: (c, s) {
            final content = s.data?.content.isNotEmpty == true
                ? s.data!.content
                : '''• List only genuine products you are authorised to sell, with accurate prices, MRP and stock.
• Accept or reject new orders promptly and pack them within the promised time.
• Go4Market charges a commission on each delivered order, deducted before payout.
• Returns and refunds follow the platform return policy.
• Products and edits are reviewed by the Go4Market team before going live.
• Misleading listings, counterfeit goods or poor service may lead to suspension.''';
            return ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
              Text(s.data?.title.isNotEmpty == true ? s.data!.title : c.tr('Seller policies', 'विक्रेता नीतियां'), style: c.tt.titleLarge),
              const SizedBox(height: 12),
              if (s.connectionState == ConnectionState.waiting)
                const Shimmer(height: 200)
              else
                Text(content.replaceAll(RegExp(r'[#*_`]'), ''), style: c.tt.bodyMedium?.copyWith(height: 1.6)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  setState(() => _policies = true);
                  Navigator.pop(c);
                },
                child: Text(c.tr('I agree', 'मैं सहमत हूं')),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
