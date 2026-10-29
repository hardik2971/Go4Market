import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'seller_store.dart';
import 'seller_widgets.dart';

class _Line {
  _Line(this.product, this.variant, this.qty);
  final Product product;
  final Variant? variant;
  int qty;
  String get key => '${product.id}_${variant?.id ?? 'default'}';
  double get price => variant?.price ?? product.price;
  String get name => variant == null ? product.name : '${product.name} (${variant!.name})';
  double get total => price * qty;
}

/// In-store quick sale -> `posCheckout`.
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});
  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _cart = <String, _Line>{};
  String _q = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _count => _cart.values.fold(0, (a, l) => a + l.qty);
  double get _subtotal => _cart.values.fold(0, (a, l) => a + l.total);

  Future<void> _add(Product p, [Variant? v]) async {
    if (v == null && p.variants.isNotEmpty) {
      final picked = await showModalBottomSheet<Variant>(
        context: context,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(p.name, style: c.tt.titleMedium)),
            for (final x in p.variants)
              ListTile(
                enabled: x.stock > 0,
                title: Text(x.name),
                subtitle: Text('${c.tr('Stock', 'स्टॉक')}: ${x.stock}'),
                trailing: Text(Fmt.money(x.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(c, x),
              ),
          ]),
        ),
      );
      if (picked == null) return;
      v = picked;
    }
    HapticFeedback.lightImpact();
    setState(() {
      final key = '${p.id}_${v?.id ?? 'default'}';
      _cart.update(key, (l) => l..qty += 1, ifAbsent: () => _Line(p, v, 1));
    });
  }

  Future<void> _scan(List<Product> products) async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    for (final p in products) {
      if (p.barcode.isNotEmpty && p.barcode == code) {
        await _add(p);
        return;
      }
      for (final v in p.variants) {
        if (v.sku.isNotEmpty && v.sku == code) {
          await _add(p, v);
          return;
        }
      }
    }
    if (mounted) toast(context, context.tr('No product with code $code', 'कोड $code वाला कोई उत्पाद नहीं'), error: true);
  }

  @override
  Widget build(BuildContext context) {
    final store = SellerStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Quick sale', 'त्वरित बिक्री')),
        actions: [
          if (_cart.isNotEmpty)
            TextButton(onPressed: () => setState(_cart.clear), child: Text(context.tr('Clear', 'साफ़ करें'))),
        ],
      ),
      body: ValueListenableBuilder<List<Product>?>(
        valueListenable: store.products,
        builder: (context, all, _) {
          if (all == null) return const SkeletonList(itemHeight: 72);
          final active = all.where((p) => p.status == 'active').toList();
          final q = _q.toLowerCase();
          final list = q.isEmpty
              ? active
              : active.where((p) => p.name.toLowerCase().contains(q) || p.barcode.contains(q) || p.brandName.toLowerCase().contains(q)).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.tr('Search products', 'उत्पाद खोजें')),
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  width: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => _scan(active),
                    child: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? AppEmpty(
                      icon: Icons.point_of_sale_rounded,
                      title: active.isEmpty ? context.tr('No active products', 'कोई सक्रिय उत्पाद नहीं') : context.tr('No matches', 'कोई मेल नहीं'),
                      message: active.isEmpty ? context.tr('Approved products appear here for billing.', 'स्वीकृत उत्पाद बिलिंग के लिए यहां दिखेंगे।') : null,
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, _cart.isEmpty ? 24 : 110),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .72),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final inCart = _cart.values.where((l) => l.product.id == p.id).fold<int>(0, (a, l) => a + l.qty);
                        final out = !p.inStock;
                        return Opacity(
                          opacity: out ? .45 : 1,
                          child: AppCard(
                            padding: const EdgeInsets.all(8),
                            borderColor: inCart > 0 ? context.rc.brand : null,
                            onTap: out ? null : () => _add(p),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Stack(children: [
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(color: context.rc.cardAlt, borderRadius: BorderRadius.circular(10)),
                                      clipBehavior: Clip.antiAlias,
                                      child: p.image.isEmpty
                                          ? Icon(Icons.inventory_2_outlined, color: context.rc.faint, size: 28)
                                          : NetImage(p.image),
                                    ),
                                  ),
                                  if (inCart > 0)
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: CircleAvatar(
                                        radius: 11,
                                        backgroundColor: context.rc.brand,
                                        child: Text('$inCart', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                      ).animate(key: ValueKey(inCart)).scale(begin: const Offset(.5, .5), curve: Curves.easeOutBack, duration: 300.ms),
                                    ),
                                ]),
                              ),
                              const SizedBox(height: 6),
                              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.labelMedium),
                              Text(Fmt.money(p.price), style: context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                            ]),
                          ),
                        ).stagger(i, stepMs: 25);
                      },
                    ),
            ),
          ]);
        },
      ),
      bottomSheet: _cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Pressable(
                  onTap: _openCart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(gradient: context.rc.hero, borderRadius: BorderRadius.circular(G4MRadius.md), boxShadow: G4MShadows.lifted),
                    child: Row(children: [
                      const Icon(Icons.shopping_bag_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Text('$_count ${context.tr('items', 'आइटम')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      AnimatedCounter(_subtotal, money: true, duration: const Duration(milliseconds: 400), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ]),
                  ),
                ),
              ).animate().slideY(begin: 1, duration: 350.ms, curve: Curves.easeOutCubic),
            ),
    );
  }

  Future<void> _openCart() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CheckoutSheet(cart: _cart, onChanged: () => setState(() {})),
    );
    if (done == true) setState(_cart.clear);
  }
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({required this.cart, required this.onChanged});
  final Map<String, _Line> cart;
  final VoidCallback onChanged;
  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _discount = TextEditingController();
  String _method = 'cash';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _discount.dispose();
    super.dispose();
  }

  double get _subtotal => widget.cart.values.fold(0, (a, l) => a + l.total);
  double get _disc => (double.tryParse(_discount.text) ?? 0).clamp(0, _subtotal).toDouble();

  Future<void> _checkout() async {
    final lines = widget.cart.values.toList();
    final input = {
      'items': [
        for (final l in lines)
          {'productId': l.product.id, 'variantId': l.variant?.id ?? 'default', 'qty': l.qty, 'name': l.name, 'price': l.price},
      ],
      'customer': {'name': _name.text.trim().isEmpty ? 'Walk-in customer' : _name.text.trim(), 'phone': _phone.text.trim()},
      'paymentMethod': _method,
      'discount': _disc,
    };
    final r = await runBusy(context, () => G4MApi.instance.posCheckout(input));
    if (r == null || !mounted) return;
    final receipt = _Receipt(
      orderNo: '${r['orderNo'] ?? r['orderId'] ?? ''}',
      lines: lines.map((l) => (l.name, l.qty, l.price)).toList(),
      subtotal: _subtotal,
      discount: _disc,
      total: (r['total'] is num) ? (r['total'] as num).toDouble() : (r['payable'] is num ? (r['payable'] as num).toDouble() : _subtotal - _disc),
      method: _method,
      customer: _name.text.trim(),
      store: SellerStore.instance.seller.value?.storeName ?? 'Go4Market',
    );
    final nav = Navigator.of(context);
    nav.pop(true);
    await showSuccess(nav.context, title: nav.context.tr('Sale complete', 'बिक्री पूरी'), subtitle: Fmt.money(receipt.total));
    if (nav.mounted) await Go.push(nav.context, _ReceiptScreen(receipt: receipt));
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.cart.values.toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (context, sc) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          Expanded(
            child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
              Text(context.tr('Bill', 'बिल'), style: context.tt.titleLarge),
              const SizedBox(height: 8),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
                        Text(Fmt.money(l.price), style: context.tt.bodySmall),
                      ]),
                    ),
                    QtyStepper(
                      value: l.qty,
                      onChanged: (v) {
                        setState(() {
                          if (v <= 0) {
                            widget.cart.remove(l.key);
                          } else {
                            l.qty = v;
                          }
                        });
                        widget.onChanged();
                        if (widget.cart.isEmpty) Navigator.pop(context);
                      },
                    ),
                    SizedBox(width: 76, child: Text(Fmt.money(l.total), textAlign: TextAlign.right, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                  ]),
                ),
              const Divider(height: 24),
              Row(children: [
                Expanded(child: TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: context.tr('Customer (optional)', 'ग्राहक (वैकल्पिक)'), isDense: true))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.s.phone, isDense: true))),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(labelText: context.tr('Discount', 'छूट'), prefixText: '₹ ', isDense: true),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'cash', icon: const Icon(Icons.payments_outlined), label: Text(context.tr('Cash', 'नकद'))),
                  ButtonSegment(value: 'card', icon: const Icon(Icons.credit_card_rounded), label: Text(context.tr('Card', 'कार्ड'))),
                  const ButtonSegment(value: 'upi', icon: Icon(Icons.qr_code_2_rounded), label: Text('UPI')),
                ],
                selected: {_method},
                onSelectionChanged: (s) => setState(() => _method = s.first),
              ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: context.rc.line))),
              child: Column(children: [
                Row(children: [
                  Text(context.tr('Subtotal', 'उप-योग'), style: context.tt.bodyMedium),
                  const Spacer(),
                  Text(Fmt.money(_subtotal)),
                ]),
                if (_disc > 0)
                  Row(children: [
                    Text(context.tr('Discount', 'छूट'), style: context.tt.bodyMedium),
                    const Spacer(),
                    Text('-${Fmt.money(_disc)}', style: const TextStyle(color: G4MColors.success)),
                  ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: lines.isEmpty ? null : _checkout,
                    child: Text('${context.tr('Charge', 'भुगतान लें')} ${Fmt.money(_subtotal - _disc)}'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Receipt {
  _Receipt({
    required this.orderNo,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.method,
    required this.customer,
    required this.store,
  });
  final String orderNo, method, customer, store;
  final List<(String, int, double)> lines;
  final double subtotal, discount, total;
  final DateTime at = DateTime.now();

  String toText() {
    final b = StringBuffer()
      ..writeln(store)
      ..writeln('Receipt${orderNo.isEmpty ? '' : ' #$orderNo'}')
      ..writeln(Fmt.dateTime(at));
    if (customer.isNotEmpty) b.writeln('Customer: $customer');
    b.writeln('------------------------------');
    for (final l in lines) {
      b.writeln('${l.$1}\n  ${l.$2} x ${Fmt.money(l.$3)} = ${Fmt.money(l.$2 * l.$3)}');
    }
    b
      ..writeln('------------------------------')
      ..writeln('Subtotal: ${Fmt.money(subtotal)}');
    if (discount > 0) b.writeln('Discount: -${Fmt.money(discount)}');
    b
      ..writeln('TOTAL: ${Fmt.money(total)}')
      ..writeln('Paid by ${method.toUpperCase()}')
      ..writeln()
      ..writeln('Thank you for shopping with us!')
      ..writeln('Powered by Go4Market');
    return b.toString();
  }
}

class _ReceiptScreen extends StatelessWidget {
  const _ReceiptScreen({required this.receipt});
  final _Receipt receipt;
  @override
  Widget build(BuildContext context) {
    final r = receipt;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Receipt', 'रसीद'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const G4MLogo(size: 44),
            const SizedBox(height: 8),
            Text(r.store, style: context.tt.titleLarge, textAlign: TextAlign.center),
            Text(Fmt.dateTime(r.at), style: context.tt.bodySmall),
            if (r.orderNo.isNotEmpty) Text('#${r.orderNo}', style: context.tt.labelLarge),
            const Divider(height: 28),
            for (final l in r.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text('${l.$2} × ${l.$1}', style: context.tt.bodyMedium)),
                  Text(Fmt.money(l.$2 * l.$3), style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
            const Divider(height: 28),
            if (r.discount > 0)
              Row(children: [Text(context.tr('Discount', 'छूट')), const Spacer(), Text('-${Fmt.money(r.discount)}')]),
            Row(children: [
              Text(context.tr('Total', 'कुल'), style: context.tt.titleMedium),
              const Spacer(),
              Text(Fmt.money(r.total), style: context.tt.headlineSmall),
            ]),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: StatusPill('paid', label: '${context.tr('Paid', 'भुगतान')} · ${r.method.toUpperCase()}')),
          ]),
        ).popIn(),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(Icons.share_rounded),
          label: Text(context.tr('Share receipt', 'रसीद साझा करें')),
          onPressed: () => SharePlus.instance.share(ShareParams(text: r.toText(), subject: '${r.store} receipt')),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('New sale', 'नई बिक्री'))),
      ]),
    );
  }
}
