import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'info_screens.dart';

/// Contact options from `settings/platform` (email, phone, address, social links).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, this.orderNo});
  final String? orderNo;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Help & support')),
        body: ValueListenableBuilder<PlatformSettings>(
          valueListenable: AppConfig.platform,
          builder: (context, st, _) {
            final email = st.contactEmail.isNotEmpty ? st.contactEmail : 'support@go4market.com';
            final phone = st.contactPhone;
            final subject = orderNo == null ? 'Go4Market support' : 'Help with order #$orderNo';
            final social = st.social.entries.where((e) => '${e.value}'.startsWith('http')).toList();
            var i = 0;
            Widget s(Widget w) => w.stagger(i++);
            return ListView(padding: const EdgeInsets.all(16), children: [
              s(Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(24)),
                child: Row(children: [
                  const Icon(Icons.support_agent_rounded, color: Colors.white, size: 44),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('How can we help?', style: context.text.titleLarge?.copyWith(color: Colors.white)),
                      Text(orderNo == null ? 'We usually reply within a few hours.' : 'About order #$orderNo',
                          style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                ]),
              )),
              const SizedBox(height: 16),
              s(AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded, color: G4MColors.primary),
                    title: const Text('Email us'),
                    subtitle: Text(email),
                    onTap: () => launchUrl(Uri(scheme: 'mailto', path: email, queryParameters: {'subject': subject})),
                  ),
                  if (phone.isNotEmpty) ...[
                    Divider(height: 1, color: context.line),
                    ListTile(
                      leading: const Icon(Icons.call_outlined, color: G4MColors.primary),
                      title: const Text('Call us'),
                      subtitle: Text(phone),
                      onTap: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                    ),
                  ],
                  Divider(height: 1, color: context.line),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: G4MColors.primary),
                    title: const Text('Browse FAQs'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(const FaqScreen()),
                  ),
                ]),
              )),
              if (st.address.isNotEmpty) ...[
                const SizedBox(height: 12),
                s(AppCard(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.business_rounded, color: G4MColors.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(st.address, style: context.text.bodyMedium)),
                  ]),
                )),
              ],
              if (social.isNotEmpty) ...[
                const SizedBox(height: 16),
                s(Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  for (final e in social)
                    ActionChip(
                      avatar: Icon(_socialIcon(e.key), size: 18),
                      label: Text(Fmt.titleCase(e.key)),
                      onPressed: () => launchUrl(Uri.parse('${e.value}'), mode: LaunchMode.externalApplication),
                    ),
                ])),
              ],
            ]);
          },
        ),
      );

  static IconData _socialIcon(String k) => switch (k) {
        'facebook' => Icons.facebook_rounded,
        'instagram' => Icons.camera_alt_outlined,
        'youtube' => Icons.ondemand_video_rounded,
        'linkedin' => Icons.work_outline_rounded,
        _ => Icons.public_rounded,
      };
}
