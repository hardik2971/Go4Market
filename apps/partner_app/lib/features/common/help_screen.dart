import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';

/// Help & FAQ: live FAQs from `faqs` plus contact options from `settings/platform`.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _q = '';

  static final _fallback = [
    Faq('f1', {'question': 'How do I get paid?', 'answer': 'Your earnings are added to your balance once an order is delivered. Request a withdrawal from Earnings → Withdrawals; payouts are processed by the Go4Market team.', 'category': 'Payments'}),
    Faq('f2', {'question': 'Why is my account pending?', 'answer': 'Every new seller and delivery partner is verified by our team. You will be notified as soon as your account is approved.', 'category': 'Account'}),
    Faq('f3', {'question': 'How does cash on delivery work?', 'answer': 'Collect the exact amount shown in the app, confirm "Cash collected" before marking delivered, and settle your cash in hand with the Go4Market team.', 'category': 'Delivery'}),
    Faq('f4', {'question': 'Why is my product pending?', 'answer': 'New and edited products are reviewed by an admin before they go live. This keeps the catalogue accurate.', 'category': 'Products'}),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.helpFaq)),
      body: StreamBuilder<List<Faq>>(
        stream: CatalogRepo.instance.faqs(),
        builder: (context, snap) {
          final faqs = (snap.data == null || snap.data!.isEmpty) ? _fallback : snap.data!;
          final q = _q.toLowerCase();
          final shown = q.isEmpty ? faqs : faqs.where((f) => f.question.toLowerCase().contains(q) || f.answer.toLowerCase().contains(q)).toList();
          return ListView(padding: pagePad, children: [
            TextField(
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('Search help', 'सहायता खोजें')),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 16),
            StreamBuilder<PlatformSettings>(
              stream: SettingsRepo.instance.platform(),
              builder: (context, s) {
                final p = s.data;
                return Row(children: [
                  Expanded(
                    child: _contact(context, Icons.call_rounded, context.s.call, p?.contactPhone ?? '',
                        () => launchUrl(Uri(scheme: 'tel', path: p?.contactPhone ?? ''))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _contact(context, Icons.mail_rounded, context.s.email, p?.contactEmail ?? '',
                        () => launchUrl(Uri(scheme: 'mailto', path: p?.contactEmail ?? '', query: 'subject=Partner support'))),
                  ),
                ]);
              },
            ).stagger(0),
            const SizedBox(height: 20),
            SectionTitle(context.tr('Frequently asked', 'अक्सर पूछे जाने वाले')),
            for (var i = 0; i < shown.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: const Border(),
                      title: Text(shown[i].question, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      subtitle: Text(shown[i].category, style: context.tt.bodySmall),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(shown[i].answer, style: context.tt.bodyMedium?.copyWith(color: context.rc.muted, height: 1.5))],
                    ),
                  ),
                ).stagger(i + 1),
              ),
          ]);
        },
      ),
    );
  }

  Widget _contact(BuildContext context, IconData icon, String label, String value, VoidCallback onTap) => AppCard(
        onTap: value.isEmpty ? null : onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: context.rc.brand),
          const SizedBox(height: 10),
          Text(label, style: context.tt.titleSmall),
          Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
        ]),
      );
}
