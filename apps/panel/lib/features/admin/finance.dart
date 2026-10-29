import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'people_common.dart';
import 'people_customers.dart' show adjustWalletDialog;
import 'package:panel/l10n/overrides.dart';

const _reasons = {'topup': 'Top-up', 'order': 'Order', 'refund': 'Refund', 'referral': 'Referral', 'cashback': 'Cashback', 'admin': 'Admin adjustment'};

// ═══════════════════════════════ WALLET TRANSACTIONS ═══════════════════════════════

class WalletTxnsPage extends StatelessWidget {
  const WalletTxnsPage({super.key});

  Future<void> _adjust(BuildContext context) async {
    final u = await pickUser(context, title: 'Adjust a customer wallet', roles: const ['customer']);
    if (u == null || !context.mounted) return;
    await adjustWalletDialog(context, u.id, u.s('name', u.s('email')));
  }

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Wallet transactions',
        subtitle: 'Every credit and debit across customer wallets',
        actions: [FilledButton.icon(onPressed: () => _adjust(context), icon: const Icon(Icons.tune_rounded, size: 18), label: Text(tr('Adjust wallet')))],
        child: StreamBuilder<List<Doc>>(
          stream: withNames(recent(Fs.walletTransactions, 500, label: 'walletTransactions_createdAt'), 'userId'),
          builder: (context, snap) {
            final l = snap.data ?? const <Doc>[];
            final credit = l.where((d) => d.s('type') == 'credit').fold<double>(0, (a, d) => a + d.n('amount'));
            final debit = l.where((d) => d.s('type') == 'debit').fold<double>(0, (a, d) => a + d.n('amount'));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minItemWidth: 220, children: [
                KpiCard(label: 'Credits (latest 500)', value: Fmt.money(credit), icon: Icons.south_west_rounded, color: G4MColors.success),
                KpiCard(label: 'Debits (latest 500)', value: Fmt.money(debit), icon: Icons.north_east_rounded, color: G4MColors.danger),
                KpiCard(label: 'Refunds to wallet', value: Fmt.money(l.where((d) => d.s('reason') == 'refund').fold<double>(0, (a, d) => a + d.n('amount'))), icon: Icons.replay_rounded, color: G4MColors.info),
                KpiCard(label: 'Referral rewards', value: Fmt.money(l.where((d) => d.s('reason') == 'referral').fold<double>(0, (a, d) => a + d.n('amount'))), icon: Icons.card_giftcard_rounded, color: G4MColors.accent),
              ]),
              const SizedBox(height: 20),
              DataView<Doc>(
                id: 'wallet_txns',
                source: (q) => withNames(recent(Fs.walletTransactions, q.limit, label: 'walletTransactions_createdAt'), 'userId'),
                rowId: (d) => d.id,
                searchText: (d) => '${d.s('_name')} ${d.s('reason')} ${d.s('refId')} ${d.s('note')}',
                filters: [
                  TableFilter('type', 'Type', const {'credit': 'Credit', 'debit': 'Debit'}, test: (d, v) => d.s('type') == v),
                  TableFilter('reason', 'Reason', _reasons, test: (d, v) => d.s('reason') == v),
                ],
                onTap: (d) => context.go('/customers/${d.s('userId')}'),
                emptyIcon: Icons.account_balance_wallet_outlined,
                emptyTitle: 'No wallet transactions',
                columns: [
                  Col('Customer', flex: 3, text: (d) => d.s('_name')),
                  Col('Type', flex: 2, text: (d) => d.s('type'), cell: (c, d) => statusPill(d.s('type', 'credit'))),
                  Col('Reason', flex: 2, text: (d) => _reasons[d.s('reason')] ?? Fmt.titleCase(d.s('reason'))),
                  Col('Amount', flex: 2, numeric: true, text: (d) => '${d.s('type') == 'debit' ? '−' : '+'}${Fmt.money(d.n('amount'))}', sort: (d) => d.n('amount'),
                      cell: (c, d) => Text('${d.s('type') == 'debit' ? '−' : '+'}${Fmt.money(d.n('amount'))}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: d.s('type') == 'debit' ? G4MColors.danger : G4MColors.success))),
                  Col('Balance after', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('balanceAfter'))),
                  Col('Reference', flex: 3, text: (d) => d.s('note', d.s('refId'))),
                  Col('Date', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
                ],
              ),
            ]);
          },
        ),
      );
}

/// Searchable user picker across users / sellers / delivery partners.
Future<Doc?> pickUser(BuildContext context, {required String title, List<String> roles = const ['customer', 'seller', 'delivery']}) =>
    showDialog<Doc>(context: context, builder: (_) => _UserPicker(title: title, roles: roles));

class _UserPicker extends StatefulWidget {
  const _UserPicker({required this.title, required this.roles});
  final String title;
  final List<String> roles;
  @override
  State<_UserPicker> createState() => _UserPickerState();
}

class _UserPickerState extends State<_UserPicker> {
  String _q = '';
  late String _role = widget.roles.first;
  late Future<List<Doc>> _f = _load();

  Future<List<Doc>> _load() async {
    final out = <Doc>[];
    switch (_role) {
      case 'seller':
        out.addAll((await Fs.sellers.limit(500).get()).docs.map(Doc.fromSnap).map((d) => d..data['_label'] = d.s('storeName')));
      case 'delivery':
        out.addAll((await Fs.deliveryPartners.limit(500).get()).docs.map(Doc.fromSnap).map((d) => d..data['_label'] = d.s('name')));
      default:
        out.addAll((await fetchDocs(Fs.users.where('role', isEqualTo: _role).limit(800))).map((d) => d..data['_label'] = d.s('name', d.s('email'))));
    }
    out.sort((a, b) => a.s('_label').toLowerCase().compareTo(b.s('_label').toLowerCase()));
    return out;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 460,
          height: 460,
          child: Column(children: [
            if (widget.roles.length > 1) ...[
              Segmented<String>(
                value: _role,
                options: {for (final r in widget.roles) r: r == 'delivery' ? 'Delivery partners' : '${Fmt.titleCase(r)}s'},
                onChanged: (r) => setState(() {
                  _role = r;
                  _f = _load();
                }),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search name, email or phone…', prefixIcon: Icon(Icons.search_rounded)),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Doc>>(
                future: _f,
                builder: (context, s) {
                  if (s.hasError) return ErrorBox(s.error!);
                  if (!s.hasData) return const LoadingBlock(rows: 4);
                  final l = s.data!.where((d) => _q.isEmpty || '${d.s('_label')} ${d.s('email')} ${d.s('phone')}'.toLowerCase().contains(_q)).take(60).toList();
                  if (l.isEmpty) return Center(child: Text('No matches', style: TextStyle(color: context.pal.muted)));
                  return ListView.builder(
                    itemCount: l.length,
                    itemBuilder: (_, i) => ListTile(
                      leading: Avatar(name: l[i].s('_label'), url: l[i].s('logo', l[i].s('photoUrl')), size: 34),
                      title: Text(l[i].s('_label')),
                      subtitle: Text([l[i].s('email'), l[i].s('phone')].where((e) => e.isNotEmpty).join(' · ')),
                      trailing: l[i].data.containsKey('balance') ? Text(Fmt.money(l[i].n('balance')), style: const TextStyle(fontWeight: FontWeight.w700)) : null,
                      onTap: () => Navigator.pop(context, l[i]..data['_role'] = _role),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel')))],
      );
}

// ═══════════════════════════════ WITHDRAWALS ═══════════════════════════════

/// Adds payee name + bank details from the seller / partner profile.
Stream<List<Doc>> _withPayee(Stream<List<Doc>> s) {
  final cache = <String, Future<Doc?>>{};
  return s.asyncMap((list) async {
    await Future.wait(list.map((d) async {
      final uid = d.s('userId');
      final col = d.s('role') == 'delivery' ? Fs.deliveryPartners : Fs.sellers;
      final p = await cache.putIfAbsent('${d.s('role')}/$uid', () => col.doc(uid).get().then((x) => x.exists ? Doc.fromSnap(x) : null).catchError((_) => null));
      d.data['_name'] = p == null ? await UserNames.of(uid) : (d.s('role') == 'delivery' ? p.s('name') : p.s('storeName'));
      d.data['_bank'] = p == null ? '' : [p.s('bank.holder'), p.s('bank.account'), p.s('bank.ifsc'), p.s('bank.upi')].where((e) => e.isNotEmpty).join(' · ');
      d.data['_phone'] = p?.s('phone') ?? '';
      d.data['_balance'] = p?.n('balance') ?? 0;
    }));
    return list;
  });
}

Future<void> processWithdrawal(BuildContext context, Doc d, String status) async {
  final label = switch (status) { 'approved' => 'Approve', 'rejected' => 'Reject', 'paid' => 'Mark as paid', _ => status };
  final note = await promptText(
    context,
    '$label · ${Fmt.money(d.n('amount'))} to ${d.s('_name')}',
    label: status == 'paid' ? 'Payment reference (UTR / txn id)' : status == 'rejected' ? 'Reason' : 'Remark (optional)',
    required: status != 'approved',
    confirmLabel: label,
  );
  if (note == null) return;
  await callApi(() => G4MApi.instance.processWithdrawal(d.id, status, note.isEmpty ? null : note), success: 'Withdrawal ${status == 'paid' ? 'marked paid' : status}');
}

class WithdrawalsAdminPage extends StatelessWidget {
  const WithdrawalsAdminPage({super.key});

  void _detail(BuildContext context, Doc d) => showSideSheet<void>(
        context,
        width: 480,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Withdrawal request', style: ctx.tt.titleLarge)),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 16),
            Center(child: Text(Fmt.money(d.n('amount')), style: ctx.tt.displaySmall)),
            Center(child: statusPill(d.s('status', 'pending'))),
            const SizedBox(height: 20),
            InfoRow('Payee', d.s('_name')),
            InfoRow('Role', Fmt.titleCase(d.s('role'))),
            InfoRow('Phone', d.s('_phone')),
            InfoRow('Method', Fmt.titleCase(d.s('method'))),
            InfoRow('Bank / UPI', d.s('_bank')),
            InfoRow('Current balance', Fmt.money(d.n('_balance'))),
            InfoRow('Note', d.s('note')),
            InfoRow('Requested', Fmt.dateTime(d.createdAt)),
            InfoRow('Updated', Fmt.dateTime(d.dt('updatedAt'))),
            const Spacer(),
            if (d.s('status', 'pending') == 'pending')
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => processWithdrawal(ctx, d, 'rejected').then((_) => ctx.mounted ? Navigator.pop(ctx) : null), child: Text(tr('Reject')))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: () => processWithdrawal(ctx, d, 'approved').then((_) => ctx.mounted ? Navigator.pop(ctx) : null), child: Text(tr('Approve')))),
              ]),
            if (d.s('status', 'pending') == 'pending' || d.s('status') == 'approved') ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: G4MColors.success),
                onPressed: () => processWithdrawal(ctx, d, 'paid').then((_) => ctx.mounted ? Navigator.pop(ctx) : null),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: Text(tr('Mark as paid')),
              ),
            ],
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Withdrawal requests',
        subtitle: 'Payout requests from sellers and delivery partners',
        child: DataView<Doc>(
          id: 'withdrawals',
          source: (q) => _withPayee(recent(Fs.withdrawals, q.limit, label: 'withdrawals_createdAt')),
          rowId: (d) => d.id,
          searchText: (d) => '${d.s('_name')} ${d.s('_bank')} ${d.s('method')} ${d.s('note')}',
          filters: [
            TableFilter('status', 'Status', const {'pending': 'Pending', 'approved': 'Approved', 'paid': 'Paid', 'rejected': 'Rejected'}, test: (d, v) => d.s('status', 'pending') == v, initial: 'pending'),
            TableFilter('role', 'Role', const {'seller': 'Sellers', 'delivery': 'Delivery partners'}, test: (d, v) => d.s('role') == v),
          ],
          onTap: (d) => _detail(context, d),
          actions: [
            RowAction('Details', Icons.visibility_outlined, (d) => _detail(context, d)),
            RowAction('Approve', Icons.check_circle_outline_rounded, (d) => processWithdrawal(context, d, 'approved'), visible: (d) => d.s('status', 'pending') == 'pending'),
            RowAction('Mark paid', Icons.verified_outlined, (d) => processWithdrawal(context, d, 'paid'), visible: (d) => const {'pending', 'approved'}.contains(d.s('status', 'pending'))),
            RowAction('Reject', Icons.cancel_outlined, (d) => processWithdrawal(context, d, 'rejected'), visible: (d) => d.s('status', 'pending') == 'pending', danger: true),
          ],
          bulkActions: [
            BulkAction('Approve', Icons.done_all_rounded,
                (rows) => Future.wait(rows.where((d) => d.s('status', 'pending') == 'pending').map((d) => G4MApi.instance.processWithdrawal(d.id, 'approved')))),
            BulkAction('Mark paid', Icons.verified_rounded,
                (rows) => Future.wait(rows.where((d) => const {'pending', 'approved'}.contains(d.s('status', 'pending'))).map((d) => G4MApi.instance.processWithdrawal(d.id, 'paid', 'Bulk payout ${Fmt.date(DateTime.now())}')))),
          ],
          emptyIcon: Icons.outbox_outlined,
          emptyTitle: 'No withdrawal requests',
          columns: [
            Col('Payee', flex: 3, text: (d) => d.s('_name'), cell: (c, d) => TwoLine(d.s('_name'), Fmt.titleCase(d.s('role')))),
            Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('amount')), sort: (d) => d.n('amount'), csv: (d) => d.n('amount').toStringAsFixed(2)),
            Col('Method', flex: 2, text: (d) => Fmt.titleCase(d.s('method'))),
            Col('Bank / UPI', flex: 4, text: (d) => d.s('_bank')),
            Col('Status', flex: 2, text: (d) => d.s('status', 'pending'), cell: (c, d) => statusPill(d.s('status', 'pending'))),
            Col('Requested', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
          ],
        ),
      );
}

// ═══════════════════════════════ FUND TRANSFERS ═══════════════════════════════

class FundTransfersPage extends StatelessWidget {
  const FundTransfersPage({super.key});

  Future<void> _new(BuildContext context) async {
    final u = await pickUser(context, title: 'Transfer funds to…', roles: const ['seller', 'delivery']);
    if (u == null || !context.mounted) return;
    final r = await amountDialog(context, 'Transfer to ${u.s('_label')}', initial: u.n('balance') > 0 ? u.n('balance') : null, confirmLabel: 'Transfer');
    if (r == null) return;
    await callApi(() => G4MApi.instance.transferFunds({'toUserId': u.id, 'amount': r.$1, 'note': r.$2, 'role': u.s('_role')}), success: 'Transferred ${Fmt.money(r.$1)}');
  }

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Fund transfers',
        subtitle: 'Settlements paid out to sellers and delivery partners',
        actions: [FilledButton.icon(onPressed: () => _new(context), icon: const Icon(Icons.send_rounded, size: 18), label: Text(tr('New transfer')))],
        child: StreamBuilder<List<Doc>>(
          stream: recent(Fs.fundTransfers, 500, label: 'fundTransfers_createdAt'),
          builder: (context, snap) {
            final l = snap.data ?? const <Doc>[];
            double sum(bool Function(Doc) f) => l.where(f).fold(0, (a, d) => a + d.n('amount'));
            final now = DateTime.now();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minItemWidth: 220, children: [
                KpiCard(label: 'This month', value: Fmt.money(sum((d) => d.createdAt != null && d.createdAt!.year == now.year && d.createdAt!.month == now.month)), icon: Icons.calendar_month_rounded),
                KpiCard(label: 'To sellers', value: Fmt.money(sum((d) => d.s('role') == 'seller')), icon: Icons.storefront_rounded, color: G4MColors.accent),
                KpiCard(label: 'To delivery partners', value: Fmt.money(sum((d) => d.s('role') == 'delivery')), icon: Icons.delivery_dining_rounded, color: G4MColors.info),
              ]),
              const SizedBox(height: 20),
              DataView<Doc>(
                id: 'fund_transfers',
                source: (q) => withNames(recent(Fs.fundTransfers, q.limit, label: 'fundTransfers_createdAt'), 'toUserId'),
                rowId: (d) => d.id,
                searchText: (d) => '${d.s('_name')} ${d.s('note')}',
                filters: [TableFilter('role', 'Recipient', const {'seller': 'Sellers', 'delivery': 'Delivery partners'}, test: (d, v) => d.s('role') == v)],
                onTap: (d) => context.go(d.s('role') == 'delivery' ? '/delivery/partners/${d.s('toUserId')}' : '/sellers/${d.s('toUserId')}'),
                emptyIcon: Icons.swap_horiz_rounded,
                emptyTitle: 'No transfers yet',
                columns: [
                  Col('Recipient', flex: 3, text: (d) => d.s('_name'), cell: (c, d) => TwoLine(d.s('_name'), Fmt.titleCase(d.s('role')))),
                  Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('amount')), sort: (d) => d.n('amount'), csv: (d) => d.n('amount').toStringAsFixed(2)),
                  Col('Note', flex: 4, text: (d) => d.s('note')),
                  Col('By', flex: 2, text: (d) => d.s('by'), cell: (c, d) => UserNameText(d.s('by'), style: const TextStyle(fontSize: 13))),
                  Col('Date', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
                ],
              ),
            ]);
          },
        ),
      );
}

// ═══════════════════════════════ SELLER PAYOUTS ═══════════════════════════════

class PayoutsPage extends StatelessWidget {
  const PayoutsPage({super.key});

  Future<List<Doc>> _load() async {
    final sellers = (await Fs.sellers.where('status', isEqualTo: 'approved').limit(1000).get()).docs.map(Doc.fromSnap).toList();
    final wds = await fetchDocs(Fs.withdrawals.where('role', isEqualTo: 'seller').limit(5000));
    final transfers = await fetchDocs(Fs.fundTransfers.where('role', isEqualTo: 'seller').limit(5000));
    final paid = <String, double>{}, pending = <String, double>{}, transferred = <String, double>{};
    for (final w in wds) {
      final st = w.s('status', 'pending');
      if (st == 'paid') paid[w.s('userId')] = (paid[w.s('userId')] ?? 0) + w.n('amount');
      if (st == 'pending' || st == 'approved') pending[w.s('userId')] = (pending[w.s('userId')] ?? 0) + w.n('amount');
    }
    for (final t in transfers) {
      transferred[t.s('toUserId')] = (transferred[t.s('toUserId')] ?? 0) + t.n('amount');
    }
    for (final s in sellers) {
      final comm = s.n('totalSales') * s.n('commissionPct', 10) / 100;
      s.data['_commission'] = comm;
      s.data['_net'] = s.n('totalSales') - comm;
      s.data['_paid'] = (paid[s.id] ?? 0) + (transferred[s.id] ?? 0);
      s.data['_pending'] = pending[s.id] ?? 0;
    }
    return sellers;
  }

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Seller payouts',
        subtitle: 'What each seller has earned, what was paid and what is outstanding',
        child: FutureBuilder<List<Doc>>(
          future: _load(),
          builder: (context, snap) {
            if (snap.hasError) return ErrorBox(snap.error!);
            final l = snap.data ?? const <Doc>[];
            double sum(String k) => l.fold(0, (a, d) => a + d.n(k));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minItemWidth: 200, children: [
                KpiCard(label: 'Gross sales', value: Fmt.money(sum('totalSales')), icon: Icons.trending_up_rounded, color: G4MColors.success),
                KpiCard(label: 'Platform commission', value: Fmt.money(sum('_commission')), icon: Icons.percent_rounded, color: G4MColors.accent),
                KpiCard(label: 'Paid out', value: Fmt.money(sum('_paid')), icon: Icons.verified_rounded, color: G4MColors.info),
                KpiCard(label: 'Pending requests', value: Fmt.money(sum('_pending')), icon: Icons.hourglass_top_rounded, color: G4MColors.warning),
                KpiCard(label: 'Unpaid balance', value: Fmt.money(sum('balance')), icon: Icons.account_balance_wallet_rounded),
              ]),
              const SizedBox(height: 20),
              DataView<Doc>(
                id: 'payouts',
                source: (q) => snap.hasData ? Stream.value(l) : const Stream<List<Doc>>.empty(),
                rowId: (d) => d.id,
                searchText: (d) => '${d.s('storeName')} ${d.s('city')}',
                onTap: (d) => context.go('/sellers/${d.id}'),
                leading: (c, d) => Avatar(url: d.s('logo'), name: d.s('storeName'), size: 36),
                defaultSort: 7,
                actions: [
                  RowAction('Pay balance', Icons.send_rounded, (d) async {
                    final r = await amountDialog(context, 'Pay ${d.s('storeName')}', initial: d.n('balance') > 0 ? d.n('balance') : null, confirmLabel: 'Transfer');
                    if (r == null) return;
                    await callApi(() => G4MApi.instance.transferFunds({'toUserId': d.id, 'amount': r.$1, 'note': r.$2.isEmpty ? 'Payout ${Fmt.date(DateTime.now())}' : r.$2, 'role': 'seller'}),
                        success: 'Payout recorded');
                  }),
                ],
                emptyIcon: Icons.request_quote_outlined,
                emptyTitle: 'No approved sellers',
                columns: [
                  Col('Seller', flex: 3, text: (d) => d.s('storeName')),
                  Col('Gross sales', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('totalSales')), sort: (d) => d.n('totalSales')),
                  Col('Comm. %', flex: 1, numeric: true, text: (d) => d.n('commissionPct', 10).toStringAsFixed(1), sort: (d) => d.n('commissionPct')),
                  Col('Commission', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('_commission')), sort: (d) => d.n('_commission')),
                  Col('Net earnings', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('_net')), sort: (d) => d.n('_net')),
                  Col('Paid out', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('_paid')), sort: (d) => d.n('_paid')),
                  Col('Pending', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('_pending')), sort: (d) => d.n('_pending')),
                  Col('Balance', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('balance')), sort: (d) => d.n('balance')),
                ],
              ),
            ]);
          },
        ),
      );
}

// ═══════════════════════════════ PAYMENT TRANSACTIONS ═══════════════════════════════

const _onlineMethods = ['razorpay', 'stripe', 'paypal', 'wallet'];

class PaymentTxnsPage extends StatelessWidget {
  const PaymentTxnsPage({super.key});
  @override
  Widget build(BuildContext context) {
    Stream<List<Doc>> src(int limit) => liveDocs(
          Fs.orders.where('paymentMethod', whereIn: _onlineMethods).orderBy('createdAt', descending: true).limit(limit),
          fallback: Fs.orders.where('paymentMethod', whereIn: _onlineMethods).limit(limit),
          label: 'orders_paymentMethod_createdAt',
        );
    return PanelPage(
      title: 'Payment transactions',
      subtitle: 'Online and wallet payments captured for orders',
      child: StreamBuilder<List<Doc>>(
        stream: src(500),
        builder: (context, snap) {
          final l = snap.data ?? const <Doc>[];
          double sum(bool Function(Doc) f) => l.where(f).fold(0, (a, d) => a + d.n('payable', d.n('total')));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ResponsiveGrid(minItemWidth: 200, children: [
              KpiCard(label: 'Captured', value: Fmt.money(sum((d) => d.s('paymentStatus') == 'paid')), icon: Icons.verified_rounded, color: G4MColors.success),
              KpiCard(label: 'Pending', value: Fmt.money(sum((d) => d.s('paymentStatus', 'pending') == 'pending')), icon: Icons.hourglass_top_rounded, color: G4MColors.warning),
              KpiCard(label: 'Failed', value: Fmt.money(sum((d) => d.s('paymentStatus') == 'failed')), icon: Icons.error_outline_rounded, color: G4MColors.danger),
              KpiCard(label: 'Refunded', value: Fmt.money(sum((d) => d.s('paymentStatus') == 'refunded')), icon: Icons.replay_rounded, color: G4MColors.info),
            ]),
            const SizedBox(height: 20),
            DataView<Doc>(
              id: 'payment_txns',
              source: (q) => src(q.limit),
              rowId: (d) => d.id,
              searchText: (d) => '${d.s('orderNo')} ${d.s('customer.name')} ${d.s('paymentRef')} ${d.s('paymentMethod')}',
              filters: [
                TableFilter('method', 'Gateway', const {'razorpay': 'Razorpay', 'stripe': 'Stripe', 'paypal': 'PayPal', 'wallet': 'Wallet'}, test: (d, v) => d.s('paymentMethod') == v),
                TableFilter('pstatus', 'Payment status', const {'paid': 'Paid', 'pending': 'Pending', 'failed': 'Failed', 'refunded': 'Refunded'}, test: (d, v) => d.s('paymentStatus', 'pending') == v),
              ],
              onTap: (d) => context.go('/orders/${d.id}'),
              emptyIcon: Icons.credit_card_outlined,
              emptyTitle: 'No online payments yet',
              columns: [
                Col('Order', flex: 2, text: (d) => d.s('orderNo', d.id)),
                Col('Customer', flex: 3, text: (d) => d.s('customer.name'), cell: (c, d) => TwoLine(d.s('customer.name', 'Customer'), d.s('customer.email'))),
                Col('Gateway', flex: 2, text: (d) => Fmt.titleCase(d.s('paymentMethod'))),
                Col('Txn reference', flex: 3, text: (d) => d.s('paymentRef'), cell: (c, d) => SelectableText(d.s('paymentRef', '—'), style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5))),
                Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('payable', d.n('total'))), sort: (d) => d.n('payable', d.n('total'))),
                Col('Status', flex: 2, text: (d) => d.s('paymentStatus', 'pending'), cell: (c, d) => statusPill(d.s('paymentStatus', 'pending'))),
                Col('Date', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
              ],
            ),
          ]);
        },
      ),
    );
  }
}

