import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';

Stream<List<Withdrawal>> myWithdrawals() => resilientQuery<Withdrawal>(
      [
        () => Fs.withdrawals.where('userId', isEqualTo: myUid).orderBy('createdAt', descending: true).limit(100),
        () => Fs.withdrawals.where('userId', isEqualTo: myUid).limit(100),
      ],
      Withdrawal.fromDoc,
      sort: (a, b) => newestFirst(a.createdAt, b.createdAt),
    );

/// Withdrawals for both roles: balance hero, request sheet (`requestWithdrawal`) and history.
class WithdrawalsScreen extends StatefulWidget {
  const WithdrawalsScreen({super.key, required this.role, required this.balance});
  final PartnerRole role;

  /// Live withdrawable balance (`sellers/{uid}.balance` or `deliveryPartners/{uid}.balance`).
  final Stream<double> balance;

  @override
  State<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends State<WithdrawalsScreen> {
  late final Stream<double> _balance = widget.balance.distinct();
  late final Stream<List<Withdrawal>> _list = myWithdrawals();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s.withdrawals)),
      body: StreamBuilder<double>(
        stream: _balance,
        builder: (context, bal) {
          final b = bal.data ?? 0;
          return StreamBuilder<List<Withdrawal>>(
            stream: _list,
            builder: (context, snap) {
              final list = snap.data ?? const <Withdrawal>[];
              final pending = list.where((w) => w.status == 'pending' || w.status == 'approved').fold<double>(0, (a, w) => a + w.amount);
              final paid = list.where((w) => w.status == 'paid').fold<double>(0, (a, w) => a + w.amount);
              return ListView(padding: pagePad, children: [
                HeroPanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('Available balance', 'उपलब्ध बैलेंस'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    AnimatedCounter(b, money: true, style: context.tt.displaySmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _mini(context, context.tr('In process', 'प्रक्रिया में'), pending),
                      const SizedBox(width: 24),
                      _mini(context, context.tr('Paid out', 'भुगतान हुआ'), paid),
                    ]),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: G4MColors.primaryDeep),
                        icon: const Icon(Icons.north_east_rounded),
                        label: Text(context.tr('Request withdrawal', 'निकासी का अनुरोध')),
                        onPressed: b <= 0
                            ? null
                            : () => showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => _RequestSheet(balance: b),
                                ),
                      ),
                    ),
                  ]),
                ).popIn(),
                const SizedBox(height: 20),
                SectionTitle(context.s.history),
                if (snap.hasError)
                  SizedBox(height: 260, child: ErrorView(snap.error!))
                else if (!snap.hasData)
                  const SizedBox(height: 300, child: SkeletonList(count: 3, itemHeight: 70, padding: EdgeInsets.zero))
                else if (list.isEmpty)
                  SizedBox(
                    height: 260,
                    child: AppEmpty(
                      icon: Icons.account_balance_wallet_outlined,
                      title: context.tr('No withdrawals yet', 'अभी कोई निकासी नहीं'),
                      message: context.tr('Your payout requests will show here.', 'आपके भुगतान अनुरोध यहां दिखेंगे।'),
                    ),
                  )
                else
                  for (var i = 0; i < list.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Row(children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: statusColor(list[i].status).withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.north_east_rounded, color: statusColor(list[i].status)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(Fmt.money(list[i].amount), style: context.tt.titleMedium),
                              Text('${Fmt.titleCase(list[i].method.isEmpty ? 'bank' : list[i].method)} · ${Fmt.dateTime(list[i].createdAt)}',
                                  style: context.tt.bodySmall),
                              if (list[i].note.isNotEmpty) Text(list[i].note, style: context.tt.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                            ]),
                          ),
                          StatusPill(list[i].status, label: Fmt.titleCase(list[i].status)),
                        ]),
                      ).stagger(i),
                    ),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _mini(BuildContext context, String label, double v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        AnimatedCounter(v, money: true, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      ]);
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.balance});
  final double balance;
  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  late final _amount = TextEditingController(text: widget.balance.floor().toString());
  String _method = 'bank';

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(_amount.text) ?? 0;
    final valid = v > 0 && v <= widget.balance;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.tr('Withdraw funds', 'राशि निकालें'), style: context.tt.titleLarge),
        const SizedBox(height: 4),
        Text('${context.tr('Available', 'उपलब्ध')}: ${Fmt.money(widget.balance)}', style: context.tt.bodySmall),
        const SizedBox(height: 16),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: context.tt.headlineSmall,
          decoration: InputDecoration(prefixText: '₹ ', labelText: context.s.amount),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final p in const [.25, .5, 1.0])
            ActionChip(
              label: Text(p == 1 ? context.tr('All', 'सभी') : '${(p * 100).round()}%'),
              onPressed: () => setState(() => _amount.text = (widget.balance * p).floor().toString()),
            ),
        ]),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'bank', icon: const Icon(Icons.account_balance_rounded), label: Text(context.tr('Bank', 'बैंक'))),
            const ButtonSegment(value: 'upi', icon: Icon(Icons.qr_code_rounded), label: Text('UPI')),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() => _method = s.first),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: !valid
              ? null
              : () async {
                  final ok = await runBusy(context, () => G4MApi.instance.requestWithdrawal(v, _method));
                  if (ok != null && context.mounted) {
                    Navigator.pop(context);
                    showSuccess(context,
                        title: context.tr('Request sent', 'अनुरोध भेजा गया'),
                        subtitle: context.tr('We will notify you once it is processed.', 'प्रोसेस होने पर हम आपको सूचित करेंगे।'));
                  }
                },
          child: Text('${context.tr('Withdraw', 'निकालें')} ${valid ? Fmt.money(v) : ''}'),
        ),
      ]),
    );
  }
}
