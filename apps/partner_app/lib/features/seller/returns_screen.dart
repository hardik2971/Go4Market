import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'order_detail_screen.dart';
import 'seller_store.dart';
import 'seller_widgets.dart';

/// Return request (no core model exists yet; mirrors `returns/{id}` in the contract).
class ReturnRequest {
  ReturnRequest(this.id, this.data);
  factory ReturnRequest.fromDoc(DocumentSnapshot<Json> d) => ReturnRequest(d.id, d.data() ?? {});
  final String id;
  final Json data;
  String get orderId => '${data['orderId'] ?? ''}';
  String get reason => '${data['reason'] ?? ''}';
  String get status => '${data['status'] ?? 'requested'}';
  double get refundAmount => (data['refundAmount'] as num?)?.toDouble() ?? 0;
  String get refundTo => '${data['refundTo'] ?? 'wallet'}';
  List<OrderItem> get items => (data['items'] is List ? data['items'] as List : const [])
      .whereType<Map>()
      .map((e) => OrderItem(Map<String, dynamic>.from(e)))
      .toList();
  List<String> get images => (data['images'] is List ? data['images'] as List : const []).map((e) => '$e').toList();
  DateTime? get createdAt => data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null;
  double get itemsTotal => items.fold(0, (a, i) => a + i.lineTotal);
}

class SellerReturnsScreen extends StatefulWidget {
  const SellerReturnsScreen({super.key});
  @override
  State<SellerReturnsScreen> createState() => _SellerReturnsScreenState();
}

class _SellerReturnsScreenState extends State<SellerReturnsScreen> {
  late Future<List<ReturnRequest>> _future = _load();

  Future<List<ReturnRequest>> _load() async {
    var orders = SellerStore.instance.orders.value;
    if (orders == null) {
      final s = await Fs.orders.where('sellerIds', arrayContains: myUid).limit(300).get();
      orders = s.docs.map(ShopOrder.fromDoc).toList();
    }
    final ids = orders.where((o) => o.status == OrderStatus.delivered || o.status == OrderStatus.returned).map((o) => o.id).toList();
    final out = <ReturnRequest>[];
    Object? lastError;
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      try {
        final s = await Fs.returns.where('orderId', whereIn: chunk).get();
        out.addAll(s.docs.map(ReturnRequest.fromDoc));
      } catch (e) {
        lastError = e;
      }
    }
    if (out.isEmpty && lastError != null) throw lastError;
    out.sort((a, b) => newestFirst(a.createdAt, b.createdAt));
    return out;
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Returns', 'रिटर्न'))),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future.catchError((_) => <ReturnRequest>[]);
        },
        child: FutureBuilder<List<ReturnRequest>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(snap.error!, onRetry: _reload);
            if (!snap.hasData) return const SkeletonList(itemHeight: 90);
            final list = snap.data!;
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                AppEmpty(
                  icon: Icons.assignment_return_outlined,
                  title: context.tr('No return requests', 'कोई रिटर्न अनुरोध नहीं'),
                  message: context.tr('Customer return requests for your orders show up here.', 'आपके ऑर्डर के रिटर्न अनुरोध यहां दिखेंगे।'),
                ),
              ]);
            }
            return ListView.separated(
              padding: pagePad,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = list[i];
                final order = SellerStore.instance.orders.value?.where((o) => o.id == r.orderId).firstOrNull;
                return AppCard(
                  onTap: () async {
                    final changed = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _ReturnSheet(ret: r, order: order),
                    );
                    if (changed == true) _reload();
                  },
                  child: Row(children: [
                    ProductThumb(r.items.isEmpty ? '' : r.items.first.image, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(order == null ? r.orderId : '#${order.orderNo}', style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text(r.reason.isEmpty ? '—' : r.reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
                        Text('${r.items.length} ${context.tr('items', 'आइटम')} · ${Fmt.ago(r.createdAt)}', style: context.tt.bodySmall),
                      ]),
                    ),
                    StatusPill(r.status, label: Fmt.titleCase(r.status)),
                  ]),
                ).stagger(i);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReturnSheet extends StatefulWidget {
  const _ReturnSheet({required this.ret, this.order});
  final ReturnRequest ret;
  final ShopOrder? order;
  @override
  State<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends State<_ReturnSheet> {
  late final _amount = TextEditingController(
      text: (widget.ret.refundAmount > 0 ? widget.ret.refundAmount : widget.ret.itemsTotal).toStringAsFixed(0));

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _process(String status) async {
    final r = widget.ret;
    final nav = Navigator.of(context);
    final res = await runBusy(
      context,
      () => G4MApi.instance.processReturn({
        'returnId': r.id,
        'id': r.id,
        'status': status,
        if (status == 'approved' || status == 'refunded') 'refundAmount': double.tryParse(_amount.text) ?? r.itemsTotal,
        'refundTo': 'wallet',
      }),
      success: context.tr('Return updated', 'रिटर्न अपडेट हुआ'),
    );
    if (res != null) nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ret;
    final open = r.status == 'requested' || r.status == 'approved' || r.status == 'picked';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Row(children: [
          Expanded(child: Text(context.tr('Return request', 'रिटर्न अनुरोध'), style: context.tt.titleLarge)),
          StatusPill(r.status, label: Fmt.titleCase(r.status)),
        ]),
        const SizedBox(height: 8),
        Text('${context.tr('Reason', 'कारण')}: ${r.reason.isEmpty ? '—' : r.reason}', style: context.tt.bodyMedium),
        const SizedBox(height: 12),
        for (final it in r.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              ProductThumb(it.image, size: 40),
              const SizedBox(width: 10),
              Expanded(child: Text('${it.qty}× ${it.name}', style: context.tt.bodyMedium)),
              Text(Fmt.money(it.lineTotal), style: context.tt.titleSmall),
            ]),
          ),
        if (r.images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: r.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => NetImage(r.images[i], width: 80, height: 80, radius: 12),
            ),
          ),
        ],
        if (widget.order != null)
          TextButton.icon(
            icon: const Icon(Icons.receipt_long_rounded),
            label: Text(context.tr('View order', 'ऑर्डर देखें')),
            onPressed: () => Go.push(context, SellerOrderDetailScreen(orderId: widget.order!.id)),
          ),
        if (open) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.tr('Refund to customer wallet', 'ग्राहक वॉलेट में रिफंड'), prefixText: '₹ '),
          ),
          const SizedBox(height: 16),
          Row(children: [
            if (r.status == 'requested') ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _process('rejected'),
                  child: Text(context.tr('Reject', 'अस्वीकार'), style: const TextStyle(color: G4MColors.danger)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: () => _process('approved'), child: Text(context.tr('Approve', 'स्वीकृत करें')))),
            ] else
              Expanded(child: FilledButton(onPressed: () => _process('refunded'), child: Text(context.tr('Refund now', 'अभी रिफंड करें')))),
          ]),
        ],
      ]),
    );
  }
}
