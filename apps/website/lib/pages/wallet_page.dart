import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/data.dart';
import '../core/payment_flow.dart';
import '../core/shop.dart';
import '../l10n/l10n.dart';
import '../ui/gate.dart';
import '../ui/kit.dart';
import '../ui/shell.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});
  @override
  Widget build(BuildContext context) => SeoMeta(
        title: context.l.common.wallet,
        child: PageScroll(children: [
          Contained(
            vertical: 24,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Heading(context.l.account.walletHeading),
              const SizedBox(height: 16),
              SignedInGate(
                next: '/wallet',
                icon: Icons.account_balance_wallet_outlined,
                title: context.l.account.walletSignInTitle,
                message: context.l.account.walletSignInMessage,
                builder: (context) => const _WalletBody(),
              ),
            ]),
          ),
        ]),
      );
}

class _WalletBody extends StatefulWidget {
  const _WalletBody();
  @override
  State<_WalletBody> createState() => _WalletBodyState();
}

class _WalletBodyState extends State<_WalletBody> {
  final _amount = TextEditingController(text: '500');
  String? _provider;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _topup() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    final t = context.l.account;
    if (amt < 10) return toast(context, t.minTopup(context.l.money(10)), error: true);
    if (_provider == null) return toast(context, t.onlineUnavailable, error: true);
    setState(() => _busy = true);
    try {
      final r = await G4MApi.instance.walletTopup(amt, _provider!);
      final id = '${r['topupId'] ?? r['id'] ?? r['orderId'] ?? ''}';
      final payment = r['payment'] is Map ? Map<String, dynamic>.from(r['payment'] as Map) : {...r, 'provider': r['provider'] ?? _provider};
      final me = Shop.instance.profile;
      final out = await runPayment(payment, id: id, topup: true, prefill: {'name': me?.name ?? '', 'email': me?.email ?? '', 'contact': me?.phone ?? ''});
      if (!mounted) return;
      if (out == PayOutcome.paid) toast(context, t.addedToWallet(context.l.money(amt)));
      if (out == PayOutcome.dismissed) toast(context, t.topupCancelled, error: true);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final pay = shop.payments;
          final l = context.l;
          final t = l.account;
          final providers = [
            if (pay.razorpayEnabled) ('razorpay', t.providerRazorpay),
            if (pay.stripeEnabled) ('stripe', t.providerStripe),
            if (pay.paypalEnabled) ('paypal', 'PayPal'),
          ];
          if (_provider == null || !providers.any((p) => p.$1 == _provider)) _provider = providers.isEmpty ? null : providers.first.$1;
          final balance = Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(28), boxShadow: G4MShadows.lifted),
            child: Stack(children: [
              PositionedDirectional(end: -20, top: -20, child: Icon(Icons.account_balance_wallet_rounded, size: 140, color: Colors.white.withValues(alpha: .08))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.availableBalance, style: const TextStyle(color: Color(0xFFD6EADF), fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: shop.walletBalance),
                  duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
                  curve: G4MMotion.curve,
                  builder: (_, v, _) => Text(l.money(v.roundToDouble()), style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1)),
                ),
                const SizedBox(height: 8),
                Text(t.balanceHint, style: const TextStyle(color: Color(0xFFD6EADF))),
              ]),
            ]),
          );
          final add = Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t.addMoney, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: t.amount, prefixText: '₹ '),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in const [100, 250, 500, 1000, 2000]) ActionChip(label: Text('+ ${l.money(a)}'), onPressed: () => setState(() => _amount.text = '$a')),
              ]),
              const SizedBox(height: 14),
              if (providers.isEmpty)
                Text(t.gatewaysSetup, style: const TextStyle(color: G4MColors.inkMuted))
              else
                RadioGroup<String>(
                  groupValue: _provider,
                  onChanged: (v) => setState(() => _provider = v),
                  child: Column(children: [
                    for (final p in providers) RadioListTile<String>(contentPadding: EdgeInsets.zero, value: p.$1, title: Text(p.$2, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
              const SizedBox(height: 8),
              FilledButton(onPressed: _busy || providers.isEmpty ? null : _topup, child: Text(_busy ? t.processing : t.addToWallet)),
            ]),
          );
          final history = Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(t.transactions, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              StreamBuilder<List<WalletTxn>>(
                stream: live('wtx_${shop.user!.uid}', Data.walletTxns),
                builder: (context, s) => asyncView(s, (txns) {
                  if (txns.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text(t.noTransactions, style: const TextStyle(color: G4MColors.inkMuted)));
                  return Column(children: [
                    for (final x in txns)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: x.isCredit ? G4MColors.primarySoft : const Color(0xFFFDECEC),
                          child: Icon(x.isCredit ? Icons.south_west_rounded : Icons.north_east_rounded, color: x.isCredit ? kDiscountInk : G4MColors.danger),
                        ),
                        title: Text(t.txnReason(x.reason), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${l.dateTime(x.createdAt)} · ${t.balanceAfter(l.money(x.balanceAfter))}'),
                        trailing: Semantics(
                          label: x.isCredit ? t.credit(l.money(x.amount)) : t.debit(l.money(x.amount)),
                          excludeSemantics: true,
                          child: Text('${x.isCredit ? '+' : '−'} ${l.money(x.amount)}',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: x.isCredit ? kDiscountInk : G4MColors.ink)),
                        ),
                      ),
                  ]);
                }),
              ),
            ]),
          );
          if (!context.isDesktop) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [balance, const SizedBox(height: 16), add, const SizedBox(height: 16), history]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 420, child: Column(children: [balance, const SizedBox(height: 16), add])),
            const SizedBox(width: 24),
            Expanded(child: history),
          ]);
        },
      );
}
