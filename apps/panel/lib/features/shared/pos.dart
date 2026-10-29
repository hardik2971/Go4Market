import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../core/web_utils.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'a_common.dart';
import 'a_invoice.dart';
import 'package:panel/l10n/overrides.dart';

class _Line {
  _Line(this.product, this.variant, this.qty);
  final Product product;
  final Variant? variant;
  int qty;
  String get key => '${product.id}_${variant?.id ?? 'default'}';
  double get price => variant?.price ?? product.price;
  int get stock => variant?.stock ?? product.stock;
  double get total => price * qty;
}

class _Held {
  _Held(this.label, this.lines, this.customerName, this.customerPhone);
  final String label;
  final List<_Line> lines;
  final String customerName;
  final String customerPhone;
}

/// Point of sale for admin (any product) and sellers (own products only).
class PosPage extends StatefulWidget {
  const PosPage({super.key});
  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final _search = TextEditingController();
  final _barcode = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _custName = TextEditingController();
  final _custPhone = TextEditingController();
  final _discount = TextEditingController();
  final _tendered = TextEditingController();
  final _lines = <_Line>[];
  final _held = <_Held>[];
  String _q = '';
  String? _category;
  bool _discountPct = false;
  String _method = 'cash';
  bool _busy = false;
  List<Product> _remote = const [];
  bool _remoteBusy = false;

  late final Stream<List<Product>> _products = isSellerPanel
      ? liveQuery<Product>(Fs.products.where('sellerId', isEqualTo: session.uid).limit(600), Product.fromDoc, label: 'products sellerId')
      : liveQuery<Product>(Fs.products.where('status', isEqualTo: 'active').limit(600), Product.fromDoc, label: 'products status');

  late final Stream<List<Doc>> _cats = liveDocs(Fs.categories.where('parentId', isNull: true), sortField: 'order', desc: false, label: 'categories roots');

  @override
  void dispose() {
    for (final c in [_search, _barcode, _custName, _custPhone, _discount, _tendered]) {
      c.dispose();
    }
    _barcodeFocus.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0, (a, l) => a + l.total);
  double get _discountAmt {
    final v = double.tryParse(_discount.text) ?? 0;
    final d = _discountPct ? _subtotal * v / 100 : v;
    return d.clamp(0, _subtotal).toDouble();
  }

  double get _total => (_subtotal - _discountAmt).clamp(0, double.infinity).toDouble();

  Future<void> _add(Product p, {Variant? variant}) async {
    if (p.status != 'active' && !isAdminPanel) {
      toast('${p.name} is not active yet', kind: ToastKind.error);
      return;
    }
    var v = variant;
    if (v == null && p.variants.isNotEmpty) {
      v = p.variants.length == 1 ? p.variants.first : await _pickVariant(p);
      if (v == null) return;
    }
    final key = '${p.id}_${v?.id ?? 'default'}';
    setState(() {
      final existing = _lines.where((l) => l.key == key).firstOrNull;
      if (existing != null) {
        existing.qty++;
      } else {
        _lines.insert(0, _Line(p, v, 1));
      }
    });
    final line = _lines.firstWhere((l) => l.key == key);
    if (line.qty > line.stock) toast('Only ${line.stock} in stock for ${p.name}', kind: ToastKind.info);
  }

  Future<Variant?> _pickVariant(Product p) => showDialog<Variant>(
        context: context,
        builder: (c) => SimpleDialog(
          title: Text(p.name),
          children: [
            for (final v in p.variants)
              SimpleDialogOption(
                onPressed: v.stock > 0 ? () => Navigator.pop(c, v) : null,
                child: Row(children: [
                  Expanded(child: Text(v.name, style: TextStyle(fontWeight: FontWeight.w700, color: v.stock > 0 ? null : c.pal.faint))),
                  Text(Fmt.money(v.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  Tag(v.stock > 0 ? '${v.stock} left' : 'Out', color: v.stock > 0 ? G4MColors.success : G4MColors.danger),
                ]),
              ),
          ],
        ),
      );

  Future<void> _scan(String code, List<Product> local) async {
    code = code.trim();
    if (code.isEmpty) return;
    _barcode.clear();
    _barcodeFocus.requestFocus();
    for (final p in local) {
      if (p.barcode == code) return _add(p);
      for (final v in p.variants) {
        if (v.sku == code) return _add(p, variant: v);
      }
    }
    try {
      Query<Json> q = Fs.products.where('barcode', isEqualTo: code);
      if (isSellerPanel) q = q.where('sellerId', isEqualTo: session.uid);
      final s = await q.limit(1).get();
      if (s.docs.isEmpty) {
        toast('No product with barcode $code', kind: ToastKind.error);
        return;
      }
      await _add(Product.fromDoc(s.docs.first));
    } catch (e) {
      toastError(e);
    }
  }

  Future<void> _remoteSearch(String q) async {
    if (isSellerPanel || q.trim().length < 2) return;
    setState(() => _remoteBusy = true);
    try {
      final r = await CatalogRepo.instance.search(q, limit: 30);
      if (mounted && _q == q) setState(() => _remote = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _remoteBusy = false);
    }
  }

  void _hold() {
    if (_lines.isEmpty) return;
    setState(() {
      _held.add(_Held('Sale ${_held.length + 1} · ${Fmt.time(DateTime.now())}', List.of(_lines), _custName.text, _custPhone.text));
      _clear();
    });
    toast('Sale on hold');
  }

  void _clear() {
    _lines.clear();
    _custName.clear();
    _custPhone.clear();
    _discount.clear();
    _tendered.clear();
    _method = 'cash';
  }

  Future<void> _checkout() async {
    if (_lines.isEmpty) return;
    final tendered = double.tryParse(_tendered.text);
    if (_method == 'cash' && tendered != null && tendered < _total) {
      toast('Cash tendered is less than the total', kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    final lines = [for (final l in _lines) (l.product.name, l.variant?.name ?? '', l.qty, l.price)];
    final sub = _subtotal, disc = _discountAmt, total = _total;
    final cust = _custName.text.trim();
    try {
      final r = await G4MApi.instance.posCheckout({
        'items': [for (final l in _lines) {'productId': l.product.id, 'variantId': l.variant?.id ?? 'default', 'qty': l.qty}],
        'customer': {'name': cust.isEmpty ? 'Walk-in customer' : cust, 'phone': _custPhone.text.trim()},
        'paymentMethod': _method,
        'discount': double.parse(disc.toStringAsFixed(2)),
      });
      final orderNo = '${r['orderNo'] ?? r['orderId'] ?? ''}';
      final orderId = '${r['orderId'] ?? ''}';
      final serverTotal = r['total'] is num ? (r['total'] as num).toDouble() : total;
      final html = receiptHtml(
        orderNo: orderNo,
        lines: lines,
        subtotal: sub,
        discount: disc,
        total: serverTotal,
        method: _method,
        tendered: _method == 'cash' ? tendered : null,
        customer: cust,
        storeName: isSellerPanel ? session.displayName : 'Go4Market',
      );
      setState(_clear);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: G4MColors.success, size: 56),
          title: Text(tr('Sale completed')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Order $orderNo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text(Fmt.money(serverTotal), style: c.tt.headlineMedium),
            if (_method == 'cash' && tendered != null && tendered > serverTotal)
              Text('Change due: ${Fmt.money(tendered - serverTotal)}', style: const TextStyle(color: G4MColors.success, fontWeight: FontWeight.w700)),
          ]),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            if (orderId.isNotEmpty)
              TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    context.go('/orders/$orderId');
                  },
                  child: Text(tr('View order'))),
            OutlinedButton.icon(onPressed: () => printHtml(html), icon: const Icon(Icons.print_rounded, size: 18), label: Text(tr('Print receipt'))),
            FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('New sale'))),
          ],
        ),
      );
      _barcodeFocus.requestFocus();
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1100;
    return PanelPage(
      title: 'Point of sale',
      subtitle: isSellerPanel ? 'Sell in store from your catalog — scan a barcode or tap a product.' : 'Counter checkout across the catalog — scan a barcode or tap a product.',
      scroll: false,
      actions: [
        if (_held.isNotEmpty)
          PopupMenuButton<int>(
            tooltip: 'Held sales',
            onSelected: (i) => setState(() {
              final h = _held.removeAt(i);
              _lines
                ..clear()
                ..addAll(h.lines);
              _custName.text = h.customerName;
              _custPhone.text = h.customerPhone;
            }),
            itemBuilder: (_) => [
              for (var i = 0; i < _held.length; i++)
                PopupMenuItem(value: i, child: Text('${_held[i].label} · ${_held[i].lines.length} item(s)')),
            ],
            child: Chip(avatar: const Icon(Icons.pause_circle_outline_rounded, size: 18), label: Text('${_held.length} on hold')),
          ),
        OutlinedButton.icon(onPressed: () => context.go('/orders/pos'), icon: const Icon(Icons.history_rounded, size: 18), label: Text(tr('POS orders'))),
      ],
      child: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snap) {
          final all = (snap.data ?? const <Product>[]).where((p) => isAdminPanel || p.status == 'active').toList();
          final catalog = _catalog(context, all, snap);
          final cart = _cart(context);
          if (!wide) {
            return Column(children: [Expanded(flex: 5, child: catalog), const SizedBox(height: 14), Expanded(flex: 6, child: cart)]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: catalog),
            const SizedBox(width: 16),
            SizedBox(width: 420, child: cart),
          ]);
        },
      ),
    );
  }

  Widget _catalog(BuildContext context, List<Product> all, AsyncSnapshot<List<Product>> snap) {
    final q = _q.toLowerCase();
    var list = all.where((p) {
      if (_category != null && !p.categoryPath.contains(_category) && p.categoryId != _category) return false;
      if (q.isEmpty) return true;
      return '${p.name} ${p.brandName} ${p.barcode} ${p.tags.join(' ')}'.toLowerCase().contains(q);
    }).toList();
    if (q.isNotEmpty && _remote.isNotEmpty) {
      final ids = list.map((p) => p.id).toSet();
      list = [...list, ..._remote.where((p) => !ids.contains(p.id))];
    }
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _remoteBusy ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
              ),
              onChanged: (v) {
                setState(() {
                  _q = v;
                  _remote = const [];
                });
                Future.delayed(const Duration(milliseconds: 350), () {
                  if (_q == v) _remoteSearch(v);
                });
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _barcode,
              focusNode: _barcodeFocus,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Scan / type barcode ↵', prefixIcon: Icon(Icons.qr_code_scanner_rounded)),
              onSubmitted: (v) => _scan(v, all),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: StreamBuilder<List<Doc>>(
            stream: _cats,
            builder: (context, cs) {
              final cats = (cs.data ?? const <Doc>[]).where((c) => c.b('active', true)).toList();
              return ListView(scrollDirection: Axis.horizontal, children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(label: Text(tr('All')), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                ),
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(label: Text(c.s('name')), selected: _category == c.id, onSelected: (_) => setState(() => _category = _category == c.id ? null : c.id)),
                  ),
              ]);
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: snap.hasError
              ? ErrorBox(snap.error!)
              : !snap.hasData
                  ? GridView.count(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, children: List.generate(8, (_) => const Shimmer(radius: 14)))
                  : list.isEmpty
                      ? EmptyState(icon: Icons.search_off_rounded, title: all.isEmpty ? 'No products to sell' : 'No matching products', message: all.isEmpty ? 'Add active products to your catalog first.' : null)
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisExtent: 222, mainAxisSpacing: 10, crossAxisSpacing: 10),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _ProductTile(product: list[i], onTap: () => _add(list[i]), inCart: _lines.where((l) => l.product.id == list[i].id).fold(0, (a, l) => a + l.qty))
                              .animate(delay: (i < 24 ? i * 15 : 0).ms)
                              .fadeIn(duration: 200.ms),
                        ),
        ),
      ]),
    );
  }

  Widget _cart(BuildContext context) {
    final tendered = double.tryParse(_tendered.text);
    return SectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('Current sale', style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          if (_lines.isNotEmpty) Tag('${_lines.fold<int>(0, (a, l) => a + l.qty)} items', color: context.pal.accent),
          const Spacer(),
          IconButton(tooltip: 'Hold sale', onPressed: _lines.isEmpty ? null : _hold, icon: const Icon(Icons.pause_circle_outline_rounded)),
          IconButton(
            tooltip: 'Clear',
            onPressed: _lines.isEmpty
                ? null
                : () async {
                    if (await confirm(context, 'Clear this sale?', danger: true, confirmLabel: 'Clear')) setState(_clear);
                  },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _custName, decoration: const InputDecoration(hintText: 'Customer (walk-in)', prefixIcon: Icon(Icons.person_outline_rounded, size: 20)))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _custPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone', prefixIcon: Icon(Icons.phone_outlined, size: 20)))),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: _lines.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.qr_code_scanner_rounded, size: 48, color: context.pal.faint),
                    const SizedBox(height: 8),
                    Text('Scan a barcode or tap a product', style: TextStyle(color: context.pal.muted)),
                  ]),
                )
              : ListView.separated(
                  itemCount: _lines.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: context.pal.line),
                  itemBuilder: (_, i) {
                    final l = _lines[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        RowThumb(l.product.image, size: 42),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('${l.variant != null ? '${l.variant!.name} · ' : ''}${Fmt.money(l.price)}${l.qty > l.stock ? ' · only ${l.stock} in stock' : ''}',
                                style: TextStyle(fontSize: 11.5, color: l.qty > l.stock ? G4MColors.danger : context.pal.muted)),
                          ]),
                        ),
                        _qtyBtn(Icons.remove_rounded, () => setState(() => l.qty > 1 ? l.qty-- : _lines.removeAt(i))),
                        SizedBox(width: 28, child: Text('${l.qty}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
                        _qtyBtn(Icons.add_rounded, () => setState(() => l.qty++)),
                        SizedBox(width: 74, child: Text(Fmt.money(l.total), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
                      ]),
                    ).animate().fadeIn(duration: 180.ms).slideX(begin: .05);
                  },
                ),
        ),
        Divider(color: context.pal.line),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(hintText: 'Discount', prefixIcon: const Icon(Icons.discount_outlined, size: 20), prefixText: _discountPct ? null : '₹ ', suffixText: _discountPct ? '%' : null),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Segmented<bool>(value: _discountPct, options: const {false: '₹', true: '%'}, onChanged: (v) => setState(() => _discountPct = v)),
        ]),
        const SizedBox(height: 10),
        Segmented<String>(
          value: _method,
          options: const {'cash': 'Cash', 'card': 'Card', 'upi': 'UPI'},
          onChanged: (v) => setState(() => _method = v),
        ),
        if (_method == 'cash') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _tendered,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              hintText: 'Cash tendered',
              prefixText: '₹ ',
              prefixIcon: const Icon(Icons.payments_outlined, size: 20),
              suffixText: tendered != null && tendered >= _total && _lines.isNotEmpty ? 'Change ${Fmt.money(tendered - _total)}' : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 12),
        _sumRow(context, 'Subtotal', Fmt.money(_subtotal)),
        if (_discountAmt > 0) _sumRow(context, 'Discount', '− ${Fmt.money(_discountAmt)}', color: G4MColors.success),
        const SizedBox(height: 4),
        Row(children: [
          Text('Total', style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(Fmt.money(_total), key: ValueKey(_total), style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: context.pal.accent)),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _lines.isEmpty || _busy ? null : _checkout,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(_busy ? 'Processing…' : 'Charge ${Fmt.money(_total)}', style: const TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  Widget _sumRow(BuildContext context, String l, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Text(l, style: TextStyle(color: context.pal.muted)), const Spacer(), Text(v, style: TextStyle(fontWeight: FontWeight.w700, color: color))]),
      );

  Widget _qtyBtn(IconData i, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(border: Border.all(color: context.pal.line), borderRadius: BorderRadius.circular(8)),
          child: Icon(i, size: 16),
        ),
      );
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap, required this.inCart});
  final Product product;
  final VoidCallback onTap;
  final int inCart;
  @override
  Widget build(BuildContext context) {
    final p = product;
    final out = !p.inStock;
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: inCart > 0 ? context.pal.accent : context.pal.line, width: inCart > 0 ? 1.6 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(aspectRatio: 1.25, child: Opacity(opacity: out ? .45 : 1, child: NetImage(p.image))),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.25)),
                const SizedBox(height: 4),
                Row(children: [
                  Text(Fmt.money(p.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(out ? 'Out' : p.variants.isNotEmpty ? '${p.variants.length} var.' : '${p.stock}',
                      style: TextStyle(fontSize: 11, color: out ? G4MColors.danger : context.pal.muted, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ]),
          if (inCart > 0)
            Positioned(
              top: 6,
              right: 6,
              child: CircleAvatar(radius: 12, backgroundColor: context.pal.accent, child: Text('$inCart', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
            ),
          if (p.isVeg != null) PositionedDirectional(top: 8, start: 8, child: VegMark(isVeg: p.isVeg!)),
        ]),
      ),
    );
  }
}
