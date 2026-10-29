import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/payments.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

// ------------------------------------------------------------------ refer & earn (#12)

class ReferScreen extends StatelessWidget {
  const ReferScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Refer & earn')),
        body: ValueListenableBuilder<AppUser?>(
          valueListenable: Session.instance.profile,
          builder: (context, u, _) {
            final code = u?.referralCode ?? '';
            final st = AppConfig.platform.value;
            final reward = st.referralReward;
            final referee = jsonNum(st.data['refereeReward'], reward);
            final msg = 'Shop groceries, medicines, food and more on Go4Market! Use my code $code when you sign up '
                'and get ${Fmt.money(referee)} in your wallet. https://go4market.web.app';
            return ListView(padding: const EdgeInsets.all(20), children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: G4MColors.accentGradient, borderRadius: BorderRadius.circular(28), boxShadow: G4MShadows.glowAccent),
                child: Column(children: [
                  const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 64)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .rotate(begin: -.03, end: .03, duration: 1200.ms)
                      .scaleXY(end: 1.06, duration: 1200.ms),
                  const SizedBox(height: 14),
                  Text('Give ${Fmt.money(referee)}, get ${Fmt.money(reward)}',
                      textAlign: TextAlign.center, style: context.text.headlineSmall?.copyWith(color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('Your friend gets wallet cash on sign-up. You earn when they place their first order.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
                ]),
              ).animate().fadeIn().slideY(begin: .1),
              const SizedBox(height: 24),
              Text('Your referral code', style: context.text.titleSmall, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Pressable(
                onTap: code.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: code));
                        context.toast('Code copied');
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: context.softAccent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: G4MColors.accent, width: 1.5),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(code.isEmpty ? 'Generating…' : code, style: context.text.headlineMedium?.copyWith(letterSpacing: 4, color: G4MColors.accent)),
                    const SizedBox(width: 12),
                    const Icon(Icons.copy_rounded, color: G4MColors.accent),
                  ]),
                ),
              ).stagger(1),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: code.isEmpty ? null : () => SharePlus.instance.share(ShareParams(text: msg, subject: 'Join me on Go4Market')),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Invite friends'),
              ).stagger(2),
              const SizedBox(height: 28),
              for (final (i, s) in const [
                (Icons.share_rounded, 'Share your code', 'Send it to friends and family.'),
                (Icons.person_add_alt_1_rounded, 'They sign up', 'They enter your code while creating an account.'),
                (Icons.account_balance_wallet_rounded, 'You both earn', 'Rewards land in your Go4Market wallets.'),
              ].indexed)
                ListTile(
                  leading: CircleAvatar(backgroundColor: context.softPrimary, child: Icon(s.$1, color: G4MColors.primary)),
                  title: Text(s.$2, style: context.text.titleSmall),
                  subtitle: Text(s.$3),
                ).stagger(i + 3),
            ]);
          },
        ),
      );
}

// ------------------------------------------------------------------ membership (#10)

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  Future<void> _join(BuildContext context, Json plan) async {
    final price = jsonNum(plan['price']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Join ${plan['name']}?'),
        content: Text('${Fmt.money(price)} for ${plan['durationDays'] ?? 30} days, paid from your wallet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // The contract has no membership callable yet; try the likely names, accept any response shape.
    for (final fn in ['purchaseMembership', 'buyMembership', 'subscribeMembership']) {
      try {
        final r = await G4MApi.instance.call(fn, {'planId': plan['id'], 'paymentMethod': 'wallet'});
        final pay = PaymentFlow.payloadOf(r, '${(r['payment'] as Map?)?['provider'] ?? ''}');
        if (pay != null && context.mounted) {
          await PaymentFlow.run(context, refId: '${r['orderId'] ?? r['id'] ?? ''}', payment: pay, amount: price);
        }
        if (context.mounted) context.toast('Welcome to ${plan['name']}!');
        return;
      } catch (e) {
        if (isMissingFunction(e)) continue;
        if (context.mounted) context.toast(friendlyError(e), error: true);
        return;
      }
    }
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.workspace_premium_rounded, color: G4MColors.accent, size: 40),
          title: const Text('Coming soon'),
          content: const Text('Membership checkout opens shortly. We will notify you as soon as it is live.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Membership')),
        body: StreamBuilder<List<Json>>(
          stream: Fs.membershipPlans.where('active', isEqualTo: true).snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()),
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            final plans = snap.data;
            if (plans == null) return const ListSkeleton(count: 3, height: 180);
            plans.sort((a, b) => jsonNum(a['price']).compareTo(jsonNum(b['price'])));
            final mine = Session.instance.profile.value?.membership ?? const {};
            final activeId = asDate(mine['expiresAt'])?.isAfter(DateTime.now()) == true ? '${mine['planId']}' : '';
            if (plans.isEmpty) return const EmptyState(icon: Icons.workspace_premium_outlined, title: 'No plans yet', message: 'Membership plans will appear here.');
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Text('Save more on every order with free delivery and member-only discounts.',
                          style: context.text.bodyLarge?.copyWith(color: context.muted))
                      .stagger(0);
                }
                final p = plans[i - 1];
                final active = p['id'] == activeId;
                final benefits = (p['benefits'] is List ? p['benefits'] as List : const []).map((e) => '$e').toList();
                final featured = i == plans.length ~/ 2 + 1;
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: featured ? G4MColors.heroGradient : null,
                    color: featured ? null : context.card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: featured ? G4MShadows.lifted : context.softShadow,
                    border: active ? Border.all(color: G4MColors.accent, width: 2) : null,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: featured ? Colors.white : null),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.workspace_premium_rounded, color: featured ? Colors.white : G4MColors.accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text('${p['name']}', style: context.text.titleLarge?.copyWith(color: featured ? Colors.white : null))),
                        if (active) const Tag('ACTIVE'),
                      ]),
                      const SizedBox(height: 10),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: Fmt.money(jsonNum(p['price'])), style: context.text.headlineMedium?.copyWith(color: featured ? Colors.white : null)),
                        TextSpan(text: '  / ${p['durationDays'] ?? 30} days'),
                      ])),
                      const SizedBox(height: 12),
                      if (p['freeDelivery'] == true) _benefit('Free delivery on every order', featured),
                      if (jsonNum(p['discountPct']) > 0) _benefit('${jsonNum(p['discountPct']).toStringAsFixed(0)}% extra off', featured),
                      for (final b in benefits) _benefit(b, featured),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: featured ? G4MColors.accent : G4MColors.primary),
                          onPressed: active ? null : () => _join(context, p),
                          child: Text(active ? 'Current plan' : 'Join now'),
                        ),
                      ),
                    ]),
                  ),
                ).stagger(i);
              },
            );
          },
        ),
      );

  Widget _benefit(String t, bool light) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, size: 18, color: light ? Colors.white : G4MColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text(t)),
        ]),
      );
}

// ------------------------------------------------------------------ subscriptions (#11)

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  Future<void> _set(BuildContext context, String id, String status) async {
    try {
      await Fs.subscriptions.doc(id).update({'status': status, 'updatedAt': Fs.now});
      if (context.mounted) context.toast(status == 'cancelled' ? 'Subscription cancelled' : 'Subscription ${status == 'paused' ? 'paused' : 'resumed'}');
    } catch (e) {
      if (context.mounted) context.toast(friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Subscriptions')),
        body: StreamBuilder<List<Json>>(
          stream: MyData.subscriptions(),
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            final list = snap.data;
            if (list == null) return const ListSkeleton(count: 3, height: 110);
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.autorenew_rounded,
                title: 'No subscriptions',
                message: 'Open any product and tap "Subscribe" to get it delivered daily, weekly or monthly.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final s = list[i];
                final status = '${s['status'] ?? 'active'}';
                return AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Img('${s['image'] ?? ''}', width: 54, height: 54, radius: 12, iconSize: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${s['productName'] ?? 'Product'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                          Text('${s['qty'] ?? 1} × ${Fmt.titleCase('${s['frequency'] ?? 'daily'}')}', style: context.text.bodySmall),
                          if (asDate(s['nextRunAt']) != null && status == 'active')
                            Text('Next: ${Fmt.dateTime(asDate(s['nextRunAt']))}', style: context.text.bodySmall?.copyWith(color: G4MColors.primary)),
                        ]),
                      ),
                      StatusChip(status == 'paused' ? 'pending' : status, label: Fmt.titleCase(status)),
                    ]),
                    if (status != 'cancelled') ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _set(context, '${s['id']}', status == 'paused' ? 'active' : 'paused'),
                            icon: Icon(status == 'paused' ? Icons.play_arrow_rounded : Icons.pause_rounded),
                            label: Text(status == 'paused' ? 'Resume' : 'Pause'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: G4MColors.danger),
                            onPressed: () => _set(context, '${s['id']}', 'cancelled'),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ]),
                    ],
                  ]),
                ).stagger(i);
              },
            );
          },
        ),
      );
}

// ------------------------------------------------------------------ product request (#61)

class ProductRequestScreen extends StatefulWidget {
  const ProductRequestScreen({super.key});
  @override
  State<ProductRequestScreen> createState() => _ProductRequestScreenState();
}

class _ProductRequestScreenState extends State<ProductRequestScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _busy = false, _done = false;

  Future<void> _submit() async {
    if (_name.text.trim().length < 2) return context.toast('Tell us the product name', error: true);
    setState(() => _busy = true);
    try {
      await ShopperRepo.instance.requestProduct(_name.text.trim(), _desc.text.trim());
      setState(() => _done = true);
    } catch (e) {
      if (mounted) context.toast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Request a product')),
        body: AnimatedSwitcher(
          duration: G4MMotion.emphasized,
          child: _done
              ? EmptyState(
                  key: const ValueKey('done'),
                  icon: Icons.check_circle_rounded,
                  title: 'Request received!',
                  message: 'We will let our sellers know and notify you when it is available.',
                  action: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
                )
              : ListView(key: const ValueKey('form'), padding: const EdgeInsets.all(16), children: [
                  Text("Can't find something? Tell us and we'll try to stock it.", style: context.text.bodyLarge?.copyWith(color: context.muted)),
                  const SizedBox(height: 16),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Product name', prefixIcon: Icon(Icons.shopping_basket_outlined))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _desc,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Details (brand, size, quantity…)', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Sending…' : 'Submit request')),
                ]),
        ),
      );
}

// ------------------------------------------------------------------ FAQs (#96)

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});
  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _q = '';
  final _faqs = CatalogRepo.instance.faqs();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('FAQs')),
        body: StreamBuilder<List<Faq>>(
          stream: _faqs,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            final all = snap.data;
            if (all == null) return const ListSkeleton(count: 6, height: 56);
            final list = all.where((f) => _q.isEmpty || '${f.question} ${f.answer}'.toLowerCase().contains(_q)).toList();
            final groups = <String, List<Faq>>{};
            for (final f in list) {
              groups.putIfAbsent(f.category, () => []).add(f);
            }
            var i = 0;
            return ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                decoration: const InputDecoration(hintText: 'Search questions', prefixIcon: Icon(Icons.search_rounded)),
                onChanged: (v) => setState(() => _q = v.toLowerCase().trim()),
              ),
              const SizedBox(height: 8),
              if (all.isEmpty) const EmptyState(icon: Icons.help_outline_rounded, title: 'No FAQs yet'),
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(g.key, style: context.text.titleMedium),
                ),
                for (final f in g.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Theme(
                        data: context.theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(),
                          title: Text(f.question, style: context.text.titleSmall),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          expandedAlignment: Alignment.centerLeft,
                          children: [Text(f.answer, style: context.text.bodyMedium?.copyWith(color: context.muted, height: 1.5))],
                        ),
                      ),
                    ),
                  ).stagger(i++),
              ],
            ]);
          },
        ),
      );
}

// ------------------------------------------------------------------ CMS pages

class CmsPageScreen extends StatelessWidget {
  const CmsPageScreen({super.key, required this.slug, required this.title});
  final String slug, title;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: FutureBuilder<CmsPage?>(
          future: CatalogRepo.instance.page(slug),
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!);
            if (snap.connectionState != ConnectionState.done) return const ListSkeleton(count: 8, height: 18);
            final p = snap.data;
            if (p == null || p.content.isEmpty) {
              return EmptyState(icon: Icons.article_outlined, title: '$title is being written', message: 'Please check back soon.');
            }
            return Markdown(
              data: p.content,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              onTapLink: (_, href, _) {
                if (href != null) launchUrl(Uri.parse(href), mode: LaunchMode.inAppBrowserView);
              },
              styleSheet: MarkdownStyleSheet.fromTheme(context.theme).copyWith(
                p: context.text.bodyLarge?.copyWith(height: 1.6),
                h1: context.text.headlineSmall,
                h2: context.text.titleLarge,
              ),
            ).animate().fadeIn(duration: 400.ms);
          },
        ),
      );
}
