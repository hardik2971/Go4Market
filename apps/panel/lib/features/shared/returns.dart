import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../core/web_utils.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'a_common.dart';
import 'package:panel/l10n/overrides.dart';

const _returnStatuses = {'requested': 'Requested', 'approved': 'Approved', 'picked': 'Picked up', 'refunded': 'Refunded', 'rejected': 'Rejected'};

double _itemsTotal(Doc d) => (d['items'] is List ? d['items'] as List : const [])
    .fold<double>(0, (a, e) => a + (e is Map ? toNum(e['price']) * toNum(e['qty'], 1) : 0));

int _itemsQty(Doc d) => (d['items'] is List ? d['items'] as List : const []).fold<int>(0, (a, e) => a + (e is Map ? toNum(e['qty'], 1).toInt() : 0));

/// Return / refund requests. Admin sees all, sellers see returns containing their items.
class ReturnsPage extends StatelessWidget {
  const ReturnsPage({super.key});

  Stream<List<Doc>> _source(SourceQuery q) {
    Query<Json> base = Fs.returns;
    if (isSellerPanel) base = base.where('sellerIds', arrayContains: session.uid);
    final st = q.filters['status'];
    if (st != null) base = base.where('status', isEqualTo: st);
    return liveDocs(base.orderBy('createdAt', descending: true).limit(q.limit), fallback: base.limit(q.limit), label: 'returns ${isSellerPanel ? 'sellerIds+' : ''}${st != null ? 'status+' : ''}createdAt');
  }

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Return requests',
        subtitle: isSellerPanel ? 'Returns raised on orders that include your products.' : 'Review, approve and refund customer returns.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StreamBuilder<List<Doc>>(
            stream: _source(const SourceQuery(300, {})),
            builder: (context, s) {
              final l = s.data ?? const <Doc>[];
              int n(String st) => l.where((d) => d.s('status', 'requested') == st).length;
              final refunded = l.where((d) => d.s('status') == 'refunded').fold<double>(0, (a, d) => a + d.n('refundAmount', _itemsTotal(d)));
              return ResponsiveGrid(minItemWidth: 180, spacing: 12, children: [
                KpiCard(label: 'New requests', value: s.hasData ? '${n('requested')}' : '—', icon: Icons.mark_email_unread_rounded, color: G4MColors.warning),
                KpiCard(label: 'Approved', value: s.hasData ? '${n('approved')}' : '—', icon: Icons.thumb_up_alt_rounded, color: G4MColors.info),
                KpiCard(label: 'Picked up', value: s.hasData ? '${n('picked')}' : '—', icon: Icons.local_shipping_rounded, color: G4MColors.accent),
                KpiCard(label: 'Refunded', value: s.hasData ? Fmt.money(refunded) : '—', icon: Icons.currency_rupee_rounded, color: G4MColors.success),
              ]);
            },
          ),
          const SizedBox(height: 18),
          DataView<Doc>(
            id: 'returns',
            csvName: 'returns',
            source: _source,
            rowId: (d) => d.id,
            searchText: (d) => '${d.id} ${d.s('orderNo')} ${d.s('orderId')} ${d.s('userName')} ${d.s('customer.name')} ${d.s('reason')} ${(d['items'] is List ? (d['items'] as List).map((e) => e is Map ? e['name'] : '').join(' ') : '')}',
            filters: [
              const TableFilter('status', 'Status', _returnStatuses, server: true),
              TableFilter('refundTo', 'Refund to', const {'wallet': 'Wallet', 'source': 'Original method'}, test: (d, v) => d.s('refundTo', 'wallet') == v),
            ],
            leading: (c, d) {
              final items = d['items'] is List ? d['items'] as List : const [];
              final img = items.isNotEmpty && items.first is Map ? '${(items.first as Map)['image'] ?? ''}' : '';
              return RowThumb(img, icon: Icons.assignment_return_outlined);
            },
            columns: [
              Col('Return', flex: 2, text: (d) => '#${d.id.substring(0, 6).toUpperCase()}', sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0,
                  cell: (c, d) => TwoLine('#${d.id.substring(0, 6).toUpperCase()}', Fmt.dateTime(d.createdAt))),
              Col('Order', flex: 2, text: (d) => d.s('orderNo', d.s('orderId')),
                  cell: (c, d) => InkWell(
                        onTap: d.s('orderId').isEmpty ? null : () => context.go('/orders/${d.s('orderId')}'),
                        child: Text(d.s('orderNo', d.s('orderId').isEmpty ? '—' : '${d.s('orderId').substring(0, 6)}…'),
                            style: TextStyle(color: c.pal.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                      )),
              Col('Customer', flex: 2, text: (d) => d.s('userName', d.s('customer.name', d.s('userId')))),
              Col('Items', flex: 3, text: (d) {
                final items = d['items'] is List ? d['items'] as List : const [];
                return items.map((e) => e is Map ? '${e['name'] ?? ''}${e['variantName'] != null && '${e['variantName']}'.isNotEmpty ? ' (${e['variantName']})' : ''} ×${e['qty'] ?? 1}' : '').join(', ');
              }),
              Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('refundAmount', _itemsTotal(d))), sort: (d) => d.n('refundAmount', _itemsTotal(d))),
              Col('Reason', flex: 3, text: (d) => d.s('reason')),
              Col('Status', flex: 2, text: (d) => d.s('status', 'requested'), cell: (c, d) => statusPill(d.s('status', 'requested'), label: _returnStatuses[d.s('status', 'requested')])),
            ],
            onTap: (d) => _openReturn(context, d),
            actions: [
              RowAction('Review', Icons.visibility_outlined, (d) => _openReturn(context, d)),
              RowAction('Approve', Icons.check_circle_outline_rounded, (d) => _process(context, d, 'approved'), visible: (d) => d.s('status', 'requested') == 'requested'),
              RowAction('Reject', Icons.cancel_outlined, (d) => _process(context, d, 'rejected'), danger: true, visible: (d) => d.s('status', 'requested') == 'requested'),
              RowAction('Mark picked up', Icons.local_shipping_outlined, (d) => _process(context, d, 'picked'), visible: (d) => d.s('status') == 'approved'),
              RowAction('Refund', Icons.currency_rupee_rounded, (d) => _process(context, d, 'refunded'), visible: (d) => {'approved', 'picked'}.contains(d.s('status'))),
            ],
            emptyIcon: Icons.assignment_return_outlined,
            emptyTitle: 'No return requests',
            emptyMessage: isSellerPanel ? 'Returns on your products will show up here.' : 'Customer return requests will show up here.',
          ),
        ]),
      );
}

Future<void> _process(BuildContext context, Doc d, String status) async {
  String? note;
  double? amount;
  String refundTo = d.s('refundTo', 'wallet');
  if (status == 'rejected') {
    note = await promptText(context, 'Reject return', label: 'Reason (shared with customer)', required: true, maxLines: 3, confirmLabel: 'Reject');
    if (note == null) return;
  } else if (status == 'refunded') {
    final r = await showDialog<(double, String)>(context: context, builder: (_) => _RefundDialog(doc: d));
    if (r == null) return;
    amount = r.$1;
    refundTo = r.$2;
  } else if (!context.mounted || !await confirm(context, '${_returnStatuses[status]} this return?', confirmLabel: _returnStatuses[status]!)) {
    return;
  }
  await runToast(
    () => G4MApi.instance.processReturn({
      'returnId': d.id,
      'status': status,
      'refundAmount': ?amount,
      if (status == 'refunded') 'refundTo': refundTo,
      'note': ?note,
    }),
    success: 'Return ${_returnStatuses[status]!.toLowerCase()}',
  );
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.doc});
  final Doc doc;
  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  late final _amount = TextEditingController(text: widget.doc.n('refundAmount', _itemsTotal(widget.doc)).toStringAsFixed(2));
  late String _to = widget.doc.s('refundTo', 'wallet');
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr('Issue refund')),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Refund amount', prefixText: '₹ ')),
            const SizedBox(height: 14),
            Segmented<String>(value: _to, options: const {'wallet': 'To wallet (instant)', 'source': 'Original method'}, onChanged: (v) => setState(() => _to = v)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(_amount.text);
              if (v == null || v <= 0) {
                toast('Enter a valid amount', kind: ToastKind.error);
                return;
              }
              Navigator.pop(context, (v, _to));
            },
            child: Text(tr('Refund')),
          ),
        ],
      );
}

void _openReturn(BuildContext context, Doc d) {
  showSideSheet<void>(
    context,
    width: 560,
    builder: (ctx) {
      final items = d['items'] is List ? (d['items'] as List).whereType<Map>().toList() : <Map>[];
      final images = d.list('images');
      final st = d.s('status', 'requested');
      return Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 12, 14),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: ctx.pal.line))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Return #${d.id.substring(0, 6).toUpperCase()}', style: ctx.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text('Requested ${Fmt.dateTime(d.createdAt)}', style: TextStyle(color: ctx.pal.muted, fontSize: 13)),
              ]),
            ),
            statusPill(st, label: _returnStatuses[st]),
            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            SectionCard(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                InfoRow('Order', d.s('orderNo', d.s('orderId'))),
                InfoRow('Customer', d.s('userName', d.s('customer.name', d.s('userId')))),
                InfoRow('Refund to', d.s('refundTo', 'wallet') == 'wallet' ? 'Wallet' : 'Original payment method'),
                InfoRow('Refund amount', Fmt.money(d.n('refundAmount', _itemsTotal(d))), bold: true),
                if (d.s('note').isNotEmpty) InfoRow('Note', d.s('note')),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Reason', style: TextStyle(fontWeight: FontWeight.w800, color: ctx.pal.muted, fontSize: 12.5)),
            const SizedBox(height: 4),
            Text(d.s('reason', '—'), style: const TextStyle(height: 1.5)),
            const SizedBox(height: 16),
            Text('Items (${_itemsQty(d)})', style: TextStyle(fontWeight: FontWeight.w800, color: ctx.pal.muted, fontSize: 12.5)),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  RowThumb('${i['image'] ?? ''}', size: 44),
                  const SizedBox(width: 12),
                  Expanded(child: TwoLine('${i['name'] ?? ''}', [if ('${i['variantName'] ?? ''}'.isNotEmpty) '${i['variantName']}', 'Qty ${i['qty'] ?? 1}', if ('${i['sellerName'] ?? ''}'.isNotEmpty) '${i['sellerName']}'].join(' · '))),
                  Text(Fmt.money(toNum(i['price']) * toNum(i['qty'], 1)), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Photos', style: TextStyle(fontWeight: FontWeight.w800, color: ctx.pal.muted, fontSize: 12.5)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final u in images)
                  InkWell(onTap: () => openUrl(u), child: NetImage(u, width: 110, height: 110, radius: 10)),
              ]),
            ],
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: ctx.pal.line))),
          child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
            if (d.s('orderId').isNotEmpty)
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/orders/${d.s('orderId')}');
                  },
                  child: Text(tr('Open order'))),
            if (st == 'requested') ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: G4MColors.danger),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _process(context, d, 'rejected');
                },
                child: Text(tr('Reject')),
              ),
              FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _process(context, d, 'approved');
                  },
                  child: Text(tr('Approve'))),
            ],
            if (st == 'approved')
              OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _process(context, d, 'picked');
                  },
                  child: Text(tr('Mark picked up'))),
            if (st == 'approved' || st == 'picked')
              FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _process(context, d, 'refunded');
                  },
                  child: Text(tr('Refund'))),
          ]),
        ),
      ]);
    },
  );
}
