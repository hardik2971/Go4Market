import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/live.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'seller_data.dart';
import 'seller_store.dart';
import 'seller_widgets.dart';

/// Quick stock control: +/- with debounced writes of `stock` / `variants` only.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _q = '';
  bool _lowOnly = false;
  // Pending local edits: productId -> (stock, variants)
  final Map<String, int> _stock = {};
  final Map<String, List<Json>> _variants = {};
  final Map<String, Timer> _timers = {};

  @override
  void initState() {
    super.initState();
    SellerStore.instance.start();
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _flushAll();
    SellerStore.instance.stop();
    super.dispose();
  }

  void _flushAll() {
    for (final id in {..._stock.keys, ..._variants.keys}) {
      _write(id);
    }
  }

  Future<void> _write(String id) async {
    _timers.remove(id)?.cancel();
    final s = _stock.remove(id);
    final v = _variants.remove(id);
    if (s == null && v == null) return;
    try {
      await Fs.products.doc(id).update({
        'stock': ?s,
        'variants': ?v,
        'updatedAt': Fs.now,
      });
    } catch (e) {
      if (mounted) toast(context, describeError(e), error: true);
    }
  }

  void _schedule(String id) {
    _timers[id]?.cancel();
    _timers[id] = Timer(const Duration(milliseconds: 900), () => _write(id));
  }

  int _curStock(Product p) => _stock[p.id] ?? p.stock;

  List<Json> _curVariants(Product p) => _variants[p.id] ?? p.variants.map((v) => Map<String, dynamic>.from(v.data)).toList();

  void _setStock(Product p, int v) {
    HapticFeedback.selectionClick();
    setState(() => _stock[p.id] = v < 0 ? 0 : v);
    _schedule(p.id);
  }

  void _setVariant(Product p, int idx, int v) {
    HapticFeedback.selectionClick();
    final list = _curVariants(p);
    list[idx] = {...list[idx], 'stock': v < 0 ? 0 : v};
    setState(() {
      _variants[p.id] = list;
      _stock[p.id] = list.fold<int>(0, (a, e) => a + ((e['stock'] as num?)?.toInt() ?? 0));
    });
    _schedule(p.id);
  }

  Future<void> _restock(Product p) async {
    final r = await promptText(context,
        title: '${context.tr('Restock', 'स्टॉक भरें')} · ${p.name}',
        hint: context.tr('Units to add', 'जोड़ने हेतु इकाइयां'),
        suggestions: const ['10', '25', '50', '100'],
        keyboard: TextInputType.number,
        confirmText: context.tr('Add stock', 'स्टॉक जोड़ें'));
    final n = int.tryParse(r ?? '');
    if (n == null || n <= 0) return;
    _setStock(p, _curStock(p) + n);
    await _write(p.id);
    if (mounted) toast(context, context.tr('Added $n units', '$n इकाइयां जोड़ी गईं'));
  }

  @override
  Widget build(BuildContext context) {
    final store = SellerStore.instance;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Stock management', 'स्टॉक प्रबंधन'))),
      body: ValueListenableBuilder<List<Product>?>(
        valueListenable: store.products,
        builder: (context, all, _) {
          if (all == null) {
            return store.productsError.value != null ? ErrorView(store.productsError.value!) : const SkeletonList(itemHeight: 80);
          }
          final q = _q.toLowerCase();
          final list = all.where((p) => (q.isEmpty || p.name.toLowerCase().contains(q)) && (!_lowOnly || SellerData.isLowStock(p))).toList()
            ..sort((a, b) {
              final la = SellerData.isLowStock(a) ? 0 : 1, lb = SellerData.isLowStock(b) ? 0 : 1;
              return la != lb ? la.compareTo(lb) : SellerData.totalStock(a).compareTo(SellerData.totalStock(b));
            });
          final lowCount = all.where(SellerData.isLowStock).length;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: context.s.search, isDense: true),
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: Text('${context.tr('Low', 'कम')} $lowCount'),
                  selected: _lowOnly,
                  onSelected: (v) => setState(() => _lowOnly = v),
                ),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? AppEmpty(icon: Icons.inventory_outlined, title: context.s.noData)
                  : ListView.separated(
                      padding: pagePad,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _tile(context, list[i]).stagger(i),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Product p) {
    final low = SellerData.isLowStock(p);
    final variants = _curVariants(p);
    final total = p.variants.isEmpty ? _curStock(p) : variants.fold<int>(0, (a, e) => a + ((e['stock'] as num?)?.toInt() ?? 0));
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: low ? (total == 0 ? G4MColors.danger : G4MColors.warning).withValues(alpha: .5) : null,
      child: Column(children: [
        Row(children: [
          ProductThumb(p.image, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                total == 0
                    ? context.tr('Out of stock', 'स्टॉक खत्म')
                    : '${context.tr('In stock', 'स्टॉक में')}: $total · ${context.tr('alert at', 'अलर्ट')} ${p.lowStockAt}',
                style: context.tt.bodySmall?.copyWith(color: total == 0 ? G4MColors.danger : (low ? G4MColors.warning : null)),
              ),
            ]),
          ),
          if (p.variants.isEmpty) QtyStepper(value: _curStock(p), onChanged: (v) => _setStock(p, v)),
          IconButton(
            tooltip: context.tr('Restock', 'स्टॉक भरें'),
            icon: Icon(Icons.add_box_outlined, color: context.rc.brand),
            onPressed: p.variants.isEmpty ? () => _restock(p) : null,
          ),
        ]),
        if (p.variants.isNotEmpty)
          for (var k = 0; k < variants.length; k++)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 60),
              child: Row(children: [
                Expanded(child: Text('${variants[k]['name'] ?? ''}', style: context.tt.bodyMedium)),
                QtyStepper(
                  value: (variants[k]['stock'] as num?)?.toInt() ?? 0,
                  onChanged: (v) => _setVariant(p, k, v),
                ),
              ]),
            ),
      ]),
    );
  }
}
