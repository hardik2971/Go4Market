import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/payments.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/doodle.dart';
import '../../widgets/ui.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.wallet)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ValueListenableBuilder<AppUser?>(
          valueListenable: Session.instance.profile,
          builder: (context, u, _) => _BalanceCard(balance: u?.walletBalance ?? 0, l: l),
        ).animate().fadeIn().slideY(begin: .08),
        const SizedBox(height: 22),
        Text(l.transactions, style: context.text.titleMedium),
        const SizedBox(height: 10),
        StreamBuilder<List<WalletTxn>>(
          stream: MyData.walletTxns(),
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!, compact: true);
            final list = snap.data;
            if (list == null) return const ListSkeleton(count: 4, height: 64);
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(icon: Icons.receipt_outlined, title: 'No transactions yet', message: 'Top-ups, refunds and cashback will show here.'),
              );
            }
            return Column(children: [
              for (final (i, t) in list.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (t.isCredit ? G4MColors.success : G4MColors.danger).withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon(t.reason, t.isCredit), color: t.isCredit ? G4MColors.success : G4MColors.danger, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_title(t.reason), style: context.text.titleSmall),
                          Text(Fmt.dateTime(t.createdAt), style: context.text.bodySmall),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${t.isCredit ? '+' : '−'}${Fmt.money(t.amount)}',
                            style: context.text.titleSmall?.copyWith(color: t.isCredit ? G4MColors.success : G4MColors.danger)),
                        if (t.balanceAfter > 0) Text('Bal ${Fmt.money(t.balanceAfter)}', style: context.text.bodySmall),
                      ]),
                    ]),
                  ),
                ).stagger(i),
            ]);
          },
        ),
      ]),
    );
  }

  static IconData _icon(String r, bool credit) => switch (r) {
        'topup' => Icons.add_card_rounded,
        'order' => Icons.shopping_bag_outlined,
        'refund' => Icons.replay_rounded,
        'referral' => Icons.card_giftcard_rounded,
        'cashback' => Icons.savings_outlined,
        _ => credit ? Icons.south_west_rounded : Icons.north_east_rounded,
      };

  static String _title(String r) => switch (r) {
        'topup' => 'Money added',
        'order' => 'Paid for order',
        'refund' => 'Refund',
        'referral' => 'Referral reward',
        'cashback' => 'Cashback',
        'admin' => 'Adjustment',
        _ => Fmt.titleCase(r.isEmpty ? 'Transaction' : r),
      };
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.l});
  final double balance;
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: const BoxDecoration(gradient: G4MColors.heroGradient),
          child: Stack(children: [
            const Positioned.fill(child: DoodleBackground(color: Colors.white, opacity: .08, cell: 52)),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(l.walletBalance, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                MoneyText(balance, style: context.text.displaySmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: G4MColors.accent, minimumSize: const Size(0, 46)),
                  onPressed: () => showAppSheet(context, builder: (_) => const AddFundsSheet()),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.addFunds),
                ),
              ]),
            ),
          ]),
        ),
      );
}

/// Amount chips + gateway -> walletTopup -> payment hand-off -> confirmWalletTopup.
class AddFundsSheet extends StatefulWidget {
  const AddFundsSheet({super.key});
  @override
  State<AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<AddFundsSheet> {
  final _ctl = TextEditingController(text: '500');
  String? _provider;
  bool _busy = false;

  List<(String, String, IconData)> get _providers {
    final p = AppConfig.payments.value;
    return [
      if (p.razorpayEnabled) ('razorpay', 'UPI, cards & netbanking', Icons.account_balance_rounded),
      if (p.stripeEnabled) ('stripe', 'Card (Stripe)', Icons.credit_card_rounded),
      if (p.paypalEnabled) ('paypal', 'PayPal', Icons.paypal_rounded),
    ];
  }

  Future<void> _go() async {
    final amount = double.tryParse(_ctl.text.trim()) ?? 0;
    if (amount < 10) return context.toast('Enter at least ₹10', error: true);
    final provider = _provider ?? (_providers.isEmpty ? null : _providers.first.$1);
    if (provider == null) return context.toast('No online payment method is enabled', error: true);
    setState(() => _busy = true);
    try {
      final r = await G4MApi.instance.walletTopup(amount, provider);
      final refId = '${r['topupId'] ?? r['id'] ?? r['orderId'] ?? ''}';
      final payment = PaymentFlow.payloadOf(r, provider);
      if (refId.isEmpty || payment == null) throw Exception('Top-up could not be started');
      if (!mounted) return;
      final u = Session.instance.profile.value;
      final res = await PaymentFlow.run(
        context,
        refId: refId,
        payment: payment,
        topup: true,
        amount: amount,
        prefill: {'name': u?.name ?? '', 'email': u?.email ?? '', 'phone': u?.phone ?? ''},
      );
      if (!mounted) return;
      if (res.ok) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop();
        globalToast('${Fmt.money(amount)} added to your wallet');
      } else if (!res.cancelled) {
        context.toast(res.message.isEmpty ? 'Payment failed' : res.message, error: true);
      }
    } catch (e) {
      if (mounted) context.toast(isMissingFunction(e) ? 'Wallet top-up is not available yet.' : friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = _providers;
    _provider ??= providers.isEmpty ? null : providers.first.$1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Add money', style: context.text.titleLarge),
          const SizedBox(height: 14),
          TextField(
            controller: _ctl,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            style: context.text.headlineSmall,
            decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Amount'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final a in const [100, 250, 500, 1000, 2000])
              ChoiceChip(
                label: Text('₹$a'),
                selected: _ctl.text == '$a',
                onSelected: (_) => setState(() => _ctl.text = '$a'),
              ),
          ]),
          const SizedBox(height: 16),
          if (providers.isEmpty)
            Text('Online payments are not enabled yet.', style: context.text.bodySmall)
          else
            RadioGroup<String>(
              groupValue: _provider,
              onChanged: (v) => setState(() => _provider = v),
              child: Column(children: [
                for (final p in providers)
                  RadioListTile<String>(value: p.$1, title: Text(p.$2), secondary: Icon(p.$3), contentPadding: EdgeInsets.zero, dense: true),
              ]),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || providers.isEmpty ? null : _go,
            child: Text(_busy ? 'Processing…' : 'Add ${Fmt.money(double.tryParse(_ctl.text) ?? 0)}'),
          ),
        ]),
      ),
    );
  }
}
