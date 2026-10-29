import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/crud.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'package:panel/l10n/overrides.dart';

/// Seller / delivery partner: own balance + withdrawal requests (requestWithdrawal callable).
class MyWithdrawalsPage extends StatelessWidget {
  const MyWithdrawalsPage({super.key});

  Stream<List<Doc>> _mine(int limit) => liveDocs(
        Fs.withdrawals.where('userId', isEqualTo: session.uid).orderBy('createdAt', descending: true).limit(limit),
        fallback: Fs.withdrawals.where('userId', isEqualTo: session.uid).limit(limit),
        label: 'withdrawals(userId, createdAt desc)',
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final balance = session.profile?.n('balance') ?? 0;
          return PanelPage(
            title: 'Withdrawals',
            subtitle: 'Request payouts of your available balance',
            actions: [
              FilledButton.icon(
                onPressed: balance <= 0 ? null : () => requestWithdrawalDialog(context),
                icon: const Icon(Icons.outbox_rounded, size: 18),
                label: Text(tr('Request withdrawal')),
              ),
            ],
            child: StreamBuilder<List<Doc>>(
              stream: _mine(200),
              builder: (context, snap) {
                final list = snap.data ?? const <Doc>[];
                double sum(String st) => list.where((d) => d.s('status', 'pending') == st).fold(0.0, (a, d) => a + d.n('amount'));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ResponsiveGrid(minItemWidth: 220, children: [
                    KpiCard(label: 'Available balance', value: Fmt.money(balance), icon: Icons.account_balance_wallet_rounded, color: G4MColors.primary),
                    KpiCard(label: 'Pending requests', value: Fmt.money(sum('pending')), icon: Icons.hourglass_top_rounded, color: G4MColors.warning),
                    KpiCard(label: 'Approved (in process)', value: Fmt.money(sum('approved')), icon: Icons.verified_rounded, color: G4MColors.info),
                    KpiCard(label: 'Paid out', value: Fmt.money(sum('paid')), icon: Icons.task_alt_rounded, color: G4MColors.success),
                  ]),
                  const SizedBox(height: 20),
                  DataView<Doc>(
                    id: 'my_withdrawals',
                    source: (q) => _mine(q.limit),
                    rowId: (d) => d.id,
                    searchText: (d) => '${d.s('method')} ${d.s('status')} ${d.s('note')} ${d.id}',
                    filters: [
                      TableFilter('status', 'Status', const {'pending': 'Pending', 'approved': 'Approved', 'paid': 'Paid', 'rejected': 'Rejected'},
                          test: (d, v) => d.s('status', 'pending') == v),
                    ],
                    columns: [
                      Col('Request', flex: 3, text: (d) => '#${d.id.substring(0, 8).toUpperCase()}', cell: (c, d) => TwoLine('#${d.id.substring(0, 8).toUpperCase()}', Fmt.dateTime(d.createdAt))),
                      moneyCol('Amount', 'amount'),
                      Col('Method', flex: 2, text: (d) => Fmt.titleCase(d.s('method', 'bank'))),
                      statusCol('Status', 'status', f: 'pending'),
                      Col('Note', flex: 3, text: (d) => d.s('note')),
                      dateCol('Updated', 'updatedAt'),
                    ],
                    emptyIcon: Icons.outbox_outlined,
                    emptyTitle: 'No withdrawal requests yet',
                    emptyMessage: 'When you have a balance, request a payout to your bank or UPI.',
                    csvName: 'my_withdrawals',
                  ),
                ]);
              },
            ),
          );
        },
      );
}

/// Shared request dialog (also used from earnings pages).
Future<void> requestWithdrawalDialog(BuildContext context) async {
  final p = session.profile;
  final balance = p?.n('balance') ?? 0;
  final amount = TextEditingController(text: balance > 0 ? balance.toStringAsFixed(balance % 1 == 0 ? 0 : 2) : '');
  final key = GlobalKey<FormState>();
  var method = 'bank';
  final bankLine = [p?.s('bank.holder'), p?.s('bank.account').let((a) => a.length > 4 ? '••••${a.substring(a.length - 4)}' : a), p?.s('bank.ifsc')]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');
  final upi = p?.s('bank.upi') ?? '';
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(tr('Request withdrawal')),
        content: SizedBox(
          width: 440,
          child: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: G4MColors.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: G4MColors.primary),
                  const SizedBox(width: 10),
                  Text(tr('Available')),
                  const Spacer(),
                  Text(Fmt.money(balance), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter an amount';
                  if (n > balance) return 'Cannot exceed your balance';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Segmented<String>(value: method, options: const {'bank': 'Bank transfer', 'upi': 'UPI'}, onChanged: (m) => set(() => method = m)),
              const SizedBox(height: 10),
              Text(
                method == 'bank'
                    ? (bankLine.isEmpty ? 'No bank account on file — add it in your profile first.' : 'Pays to: $bankLine')
                    : (upi.isEmpty ? 'No UPI ID on file — add it in your profile first.' : 'Pays to: $upi'),
                style: TextStyle(fontSize: 12.5, color: ctx.pal.muted),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          AsyncButton(
            label: 'Submit request',
            icon: Icons.send_rounded,
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              final ok = await runToast(() => G4MApi.instance.requestWithdrawal(double.parse(amount.text), method),
                  success: 'Withdrawal requested — admin will review it shortly');
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}
