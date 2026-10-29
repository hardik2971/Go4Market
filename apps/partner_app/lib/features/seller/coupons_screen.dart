import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/live.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'seller_data.dart';

class SellerCouponsScreen extends StatelessWidget {
  const SellerCouponsScreen({super.key});

  void _edit(BuildContext context, [Coupon? c]) =>
      showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _CouponSheet(coupon: c));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Coupons', 'कूपन'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'coupon',
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('New coupon', 'नया कूपन')),
      ),
      body: LiveList<List<Coupon>>(
        stream: SellerData.coupons(),
        empty: AppEmpty(
          icon: Icons.local_offer_outlined,
          title: context.tr('No coupons yet', 'अभी कोई कूपन नहीं'),
          message: context.tr('Create a coupon to reward your customers.', 'ग्राहकों को इनाम देने के लिए कूपन बनाएं।'),
        ),
        builder: (context, list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _ticket(context, list[i]).stagger(i),
        ),
      ),
    );
  }

  Widget _ticket(BuildContext context, Coupon c) {
    final expired = c.endAt != null && c.endAt!.isBefore(DateTime.now());
    final live = c.active && !expired;
    return Pressable(
      onTap: () => _edit(context, c),
      child: Opacity(
        opacity: live ? 1 : .55,
        child: Container(
          decoration: BoxDecoration(color: context.rc.card, borderRadius: BorderRadius.circular(G4MRadius.md), border: Border.all(color: context.rc.line)),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                width: 96,
                decoration: BoxDecoration(gradient: live ? G4MColors.accentGradient : null, color: live ? null : context.rc.cardAlt),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(8),
                child: Text(c.label, textAlign: TextAlign.center,
                    style: TextStyle(color: live ? Colors.white : context.rc.muted, fontWeight: FontWeight.w900, fontSize: 18, height: 1.1)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(c.code, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      const Spacer(),
                      StatusPill(live ? 'active' : 'cancelled', label: live ? context.tr('Live', 'लाइव') : (expired ? context.tr('Expired', 'समाप्त') : context.tr('Off', 'बंद'))),
                    ]),
                    if (c.message.isNotEmpty) Text(c.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (c.minOrder > 0) '${context.tr('Min', 'न्यूनतम')} ${Fmt.money(c.minOrder)}',
                        if (c.endAt != null) '${context.tr('till', 'तक')} ${Fmt.date(c.endAt)}',
                        '${c.usedCount}${c.usageLimit > 0 ? '/${c.usageLimit}' : ''} ${context.tr('used', 'उपयोग')}',
                      ].join(' · '),
                      style: context.tt.bodySmall?.copyWith(color: context.rc.muted),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CouponSheet extends StatefulWidget {
  const _CouponSheet({this.coupon});
  final Coupon? coupon;
  @override
  State<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<_CouponSheet> {
  final _form = GlobalKey<FormState>();
  late final c = widget.coupon;
  late final _code = TextEditingController(text: c?.code);
  late final _msg = TextEditingController(text: c?.message);
  late final _value = TextEditingController(text: c == null ? '' : _n(c!.value));
  late final _max = TextEditingController(text: c == null || c!.maxDiscount == 0 ? '' : _n(c!.maxDiscount));
  late final _min = TextEditingController(text: c == null || c!.minOrder == 0 ? '' : _n(c!.minOrder));
  late final _limit = TextEditingController(text: c == null || c!.usageLimit == 0 ? '' : '${c!.usageLimit}');
  late final _perUser = TextEditingController(text: '${c?.data['perUserLimit'] ?? 1}');
  late String _type = c?.discountType ?? 'percent';
  late bool _active = c?.active ?? true;
  late DateTime _start = c?.startAt ?? DateTime.now();
  late DateTime _end = c?.endAt ?? DateTime.now().add(const Duration(days: 30));

  static String _n(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final x in [_code, _msg, _value, _max, _min, _limit, _perUser]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => start ? _start = d : _end = DateTime(d.year, d.month, d.day, 23, 59));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_end.isBefore(_start)) {
      toast(context, context.tr('End date must be after start', 'समाप्ति तिथि प्रारंभ के बाद होनी चाहिए'), error: true);
      return;
    }
    final code = _code.text.trim().toUpperCase();
    final data = {
      'message': _msg.text.trim(),
      'discountType': _type,
      'value': double.tryParse(_value.text) ?? 0,
      'maxDiscount': double.tryParse(_max.text) ?? 0,
      'minOrder': double.tryParse(_min.text) ?? 0,
      'startAt': Timestamp.fromDate(_start),
      'endAt': Timestamp.fromDate(_end),
      'usageLimit': int.tryParse(_limit.text) ?? 0,
      'perUserLimit': int.tryParse(_perUser.text) ?? 1,
      'active': _active,
      'sellerId': myUid,
      'updatedAt': Fs.now,
      if (c == null) ...{'usedCount': 0, 'createdAt': Fs.now},
    };
    try {
      final ok = await runBusy(context, () async {
        final ref = Fs.coupons.doc(code);
        if (c == null) {
          final exists = await ref.get().then((d) => d.exists).catchError((_) => false);
          if (exists) throw Exception('Coupon code $code already exists');
        }
        await ref.set(data, SetOptions(merge: true));
        return true;
      });
      if (ok == true && mounted) {
        Navigator.pop(context);
        toast(context, context.tr('Coupon saved', 'कूपन सहेजा गया'));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _form,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Text(c == null ? context.tr('New coupon', 'नया कूपन') : context.tr('Edit coupon', 'कूपन संपादित करें'), style: context.tt.titleLarge),
          const SizedBox(height: 14),
          TextFormField(
            controller: _code,
            enabled: c == null,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(16)],
            decoration: InputDecoration(labelText: context.tr('Code', 'कोड'), hintText: 'SAVE20'),
            validator: (v) => (v ?? '').trim().length < 3 ? context.tr('Min 3 characters', 'कम से कम 3 अक्षर') : null,
          ),
          const SizedBox(height: 10),
          TextFormField(controller: _msg, decoration: InputDecoration(labelText: context.tr('Message for customers', 'ग्राहकों के लिए संदेश'))),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'percent', icon: const Icon(Icons.percent_rounded), label: Text(context.tr('Percent', 'प्रतिशत'))),
              ButtonSegment(value: 'flat', icon: const Icon(Icons.currency_rupee_rounded), label: Text(context.tr('Flat', 'फ्लैट'))),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _num(_value, _type == 'percent' ? context.tr('Value %', 'मान %') : context.tr('Value ₹', 'मान ₹'), required: true)),
            const SizedBox(width: 10),
            Expanded(child: _num(_max, context.tr('Max discount ₹', 'अधिकतम छूट ₹'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _num(_min, context.tr('Min order ₹', 'न्यूनतम ऑर्डर ₹'))),
            const SizedBox(width: 10),
            Expanded(child: _num(_limit, context.tr('Total uses', 'कुल उपयोग'), integer: true)),
            const SizedBox(width: 10),
            Expanded(child: _num(_perUser, context.tr('Per user', 'प्रति उपयोगकर्ता'), integer: true)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dateTile(context.tr('Starts', 'शुरू'), _start, () => _pickDate(true))),
            const SizedBox(width: 10),
            Expanded(child: _dateTile(context.tr('Ends', 'समाप्त'), _end, () => _pickDate(false))),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Active', 'सक्रिय')),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: Text(context.s.save)),
        ]),
      ),
    );
  }

  Widget _dateTile(String label, DateTime d, VoidCallback onTap) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.tt.bodySmall),
          Text(Fmt.date(d), style: context.tt.titleSmall),
        ]),
      );

  Widget _num(TextEditingController ctrl, String label, {bool integer = false, bool required = false}) => TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(integer ? r'[0-9]' : r'[0-9.]'))],
        decoration: InputDecoration(labelText: label, isDense: true),
        validator: required ? (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? context.tr('Required', 'आवश्यक') : null : null,
      );
}
