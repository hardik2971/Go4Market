import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../auth/root_gate.dart';
import 'delivery_data.dart';

/// Four-step `registerDeliveryPartner` wizard: you, vehicle, cities, review.
class DeliveryRegistrationScreen extends StatefulWidget {
  const DeliveryRegistrationScreen({super.key});
  @override
  State<DeliveryRegistrationScreen> createState() => _DeliveryRegistrationScreenState();
}

class _DeliveryRegistrationScreenState extends State<DeliveryRegistrationScreen> {
  final _page = PageController();
  int _step = 0;

  // Prefilled from the sign-in provider (phone / Google) when available.
  final _name = TextEditingController(text: _pick(Session.instance.prefill.name, Session.instance.user?.displayName));
  final _phone = TextEditingController(text: _pick(Session.instance.prefill.phone, Session.instance.user?.phoneNumber));

  static String _pick(String? a, String? b) => (a != null && a.trim().isNotEmpty) ? a.trim() : (b ?? '').trim();
  final _vehicleNo = TextEditingController();
  final _cityText = TextEditingController();
  String _vehicle = 'bike';
  String _photo = '';
  final Set<String> _cities = {};
  bool _agree = false;

  static const _vehicles = ['bike', 'scooter', 'bicycle', 'car', 'van'];

  @override
  void initState() {
    super.initState();
    // Prefill from users/{uid} if the account already has a profile.
    Fs.user(myUid).get().then((d) {
      final m = d.data() ?? const {};
      if (!mounted) return;
      setState(() {
        if (_name.text.isEmpty && m['name'] is String) _name.text = m['name'] as String;
        if (_phone.text.isEmpty && m['phone'] is String) _phone.text = m['phone'] as String;
        if (_photo.isEmpty && m['photoUrl'] is String) _photo = m['photoUrl'] as String;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _phone.dispose();
    _vehicleNo.dispose();
    _cityText.dispose();
    super.dispose();
  }

  bool get _valid => switch (_step) {
        0 => _name.text.trim().length >= 2 && _phone.text.replaceAll(RegExp(r'\D'), '').length >= 10,
        1 => _vehicle == 'bicycle' || _vehicleNo.text.trim().length >= 4,
        2 => _cities.isNotEmpty,
        _ => _agree,
      };

  void _go(int s) {
    FocusScope.of(context).unfocus();
    setState(() => _step = s);
    _page.animateToPage(s, duration: G4MMotion.emphasized, curve: G4MMotion.curve);
  }

  Future<void> _submit() async {
    final ok = await runBusy(context, () async {
      final email = Session.instance.user?.email ?? '';
      await G4MApi.instance.registerDeliveryPartner({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'vehicleType': _vehicle,
        'vehicleNo': _vehicleNo.text.trim().toUpperCase(),
        'cities': _cities.toList(),
        if (_photo.isNotEmpty) 'photoUrl': _photo,
        if (email.isNotEmpty) 'email': email,
      });
      try {
        await Fs.user(myUid).set({
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          if (_photo.isNotEmpty) 'photoUrl': _photo,
          'updatedAt': Fs.now,
        }, SetOptions(merge: true));
      } catch (_) {}
      await Session.instance.refreshClaims();
      return true;
    });
    if (ok == true && mounted) {
      await showSuccess(context,
          title: context.tr('Application sent', 'आवेदन भेजा गया'),
          subtitle: context.tr('We will verify your details shortly.', 'हम जल्द ही आपके विवरण की जांच करेंगे।'));
      if (mounted) Go.root(context, const RootGate());
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('About you', 'आपके बारे में'),
      context.tr('Your vehicle', 'आपका वाहन'),
      context.tr('Where you deliver', 'आप कहां डिलीवरी करेंगे'),
      context.tr('Review & submit', 'समीक्षा करें और जमा करें'),
    ];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did && _step > 0) _go(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.s.deliverWith),
          leading: _step == 0
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () async {
                    await Session.instance.signOut();
                    if (context.mounted) Go.root(context, const RootGate());
                  },
                )
              : IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _go(_step - 1)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: G4MMotion.emphasized,
                      curve: G4MMotion.curve,
                      height: 5,
                      margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: i <= _step ? context.rc.brand : context.rc.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: G4MMotion.standard,
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(.08, 0), end: Offset.zero).animate(a), child: c)),
                child: Column(key: ValueKey(_step), crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${context.tr('Step', 'चरण')} ${_step + 1} / 4', style: context.tt.labelMedium?.copyWith(color: context.rc.brand)),
                  Text(titles[_step], style: context.tt.headlineSmall),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [_you(), _vehicleStep(), _citiesStep(), _review()],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: !_valid ? null : () => _step < 3 ? _go(_step + 1) : _submit(),
                  child: Text(_step < 3 ? context.s.next : context.s.submit),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _you() => ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: Pressable(
            onTap: () async {
              final url = await pickAndUploadImage(context, 'deliveryPartners/$myUid', maxWidth: 800);
              if (url != null) setState(() => _photo = url);
            },
            child: Stack(children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(shape: BoxShape.circle, color: context.rc.brandSoft, border: Border.all(color: context.rc.brand, width: 2)),
                clipBehavior: Clip.antiAlias,
                child: _photo.isEmpty ? Icon(Icons.person_rounded, size: 56, color: context.rc.brand) : NetImage(_photo, width: 112, height: 112),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: G4MColors.primaryDeep, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ).popIn(),
        const SizedBox(height: 8),
        Text(context.tr('Profile photo (customers see this)', 'प्रोफ़ाइल फ़ोटो (ग्राहक इसे देखेंगे)'), textAlign: TextAlign.center, style: context.tt.bodySmall),
        FieldLabel(context.s.fullName),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined))).stagger(1),
        FieldLabel(context.s.phone),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.call_outlined), hintText: '+91 98765 43210'),
        ).stagger(2),
      ]);

  Widget _vehicleStep() => ListView(padding: const EdgeInsets.all(20), children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (var i = 0; i < _vehicles.length; i++)
              Pressable(
                onTap: () => setState(() => _vehicle = _vehicles[i]),
                child: AnimatedContainer(
                  duration: G4MMotion.standard,
                  decoration: BoxDecoration(
                    color: _vehicle == _vehicles[i] ? context.rc.brandSoft : context.rc.card,
                    borderRadius: BorderRadius.circular(G4MRadius.md),
                    border: Border.all(color: _vehicle == _vehicles[i] ? context.rc.brand : context.rc.line, width: _vehicle == _vehicles[i] ? 2 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedScale(
                      scale: _vehicle == _vehicles[i] ? 1.15 : 1,
                      duration: G4MMotion.standard,
                      curve: G4MMotion.spring,
                      child: Icon(vehicleIcon(_vehicles[i]), size: 32, color: _vehicle == _vehicles[i] ? context.rc.brand : context.rc.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(vehicleLabel(context, _vehicles[i]), style: context.tt.labelLarge),
                  ]),
                ),
              ).stagger(i),
          ],
        ),
        FieldLabel(context.tr('Vehicle number', 'वाहन नंबर')),
        TextField(
          controller: _vehicleNo,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.pin_outlined),
            hintText: 'DL 01 AB 1234',
            helperText: _vehicle == 'bicycle' ? context.tr('Optional for bicycles', 'साइकिल के लिए वैकल्पिक') : null,
          ),
        ),
      ]);

  Widget _citiesStep() => StreamBuilder<List<Json>>(
        stream: Fs.cities.where('active', isEqualTo: true).snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()),
        builder: (context, snap) {
          final names = <String>{
            ...(snap.data ?? const []).map((c) => '${c['name'] ?? c['id']}'),
            ..._cities,
          }.toList()
            ..sort();
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text(
              context.tr('Pick every city you can deliver in. You can serve more than one.', 'वे सभी शहर चुनें जहां आप डिलीवरी कर सकते हैं।'),
              style: context.tt.bodyMedium?.copyWith(color: context.rc.muted),
            ),
            const SizedBox(height: 16),
            if (!snap.hasData && !snap.hasError)
              const Wrap(spacing: 8, runSpacing: 8, children: [Shimmer(width: 90, height: 34), Shimmer(width: 110, height: 34), Shimmer(width: 80, height: 34)])
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < names.length; i++)
                  FilterChip(
                    label: Text(names[i]),
                    selected: _cities.contains(names[i]),
                    selectedColor: context.rc.brandSoft,
                    checkmarkColor: context.rc.brand,
                    onSelected: (v) => setState(() => v ? _cities.add(names[i]) : _cities.remove(names[i])),
                  ).animate(delay: (i.clamp(0, 15) * 30).ms).fadeIn().scale(begin: const Offset(.9, .9)),
              ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _cityText,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(hintText: context.tr('Add another city', 'दूसरा शहर जोड़ें'), prefixIcon: const Icon(Icons.location_city_rounded)),
                  onSubmitted: (_) => _addCity(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _addCity, icon: const Icon(Icons.add_rounded)),
            ]),
          ]);
        },
      );

  void _addCity() {
    final c = _cityText.text.trim();
    if (c.isEmpty) return;
    setState(() {
      _cities.add(Fmt.titleCase(c));
      _cityText.clear();
    });
  }

  Widget _review() => ListView(padding: const EdgeInsets.all(20), children: [
        AppCard(
          child: Column(children: [
            Row(children: [
              Avatar(name: _name.text, url: _photo, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_name.text, style: context.tt.titleMedium),
                  Text(_phone.text, style: context.tt.bodySmall),
                ]),
              ),
            ]),
            const Divider(height: 28),
            _row(vehicleIcon(_vehicle), context.tr('Vehicle', 'वाहन'), '${vehicleLabel(context, _vehicle)} ${_vehicleNo.text.toUpperCase()}'),
            _row(Icons.location_city_rounded, context.tr('Cities', 'शहर'), _cities.join(', ')),
          ]),
        ).popIn(),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _agree,
          onChanged: (v) => setState(() => _agree = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.tr('I confirm these details are correct and agree to the Go4Market partner terms, including COD cash handling and live location sharing while online.',
                'मैं पुष्टि करता/करती हूं कि विवरण सही हैं और Go4Market पार्टनर शर्तों से सहमत हूं, जिसमें COD नकद और ऑनलाइन रहते समय लाइव लोकेशन साझा करना शामिल है।'),
            style: context.tt.bodySmall,
          ),
        ),
      ]);

  Widget _row(IconData i, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 20, color: context.rc.brand),
          const SizedBox(width: 10),
          SizedBox(width: 72, child: Text(k, style: context.tt.bodySmall)),
          Expanded(child: Text(v, style: context.tt.titleSmall)),
        ]),
      );
}
