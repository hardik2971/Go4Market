import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/device.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';
import 'product_editor_screen.dart';
import 'seller_data.dart';
import 'seller_store.dart';
import 'seller_widgets.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});
  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  String _q = '';
  String _status = 'all';
  bool _low = false;
  String? _module;
  bool _grid = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SellerStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.s.products),
        actions: [
          IconButton(
            tooltip: context.tr('Toggle view', 'दृश्य बदलें'),
            icon: AnimatedSwitcher(
              duration: G4MMotion.standard,
              transitionBuilder: (c, a) => RotationTransition(turns: Tween(begin: .75, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
              child: Icon(_grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded, key: ValueKey(_grid)),
            ),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addProduct',
        onPressed: () => Go.push(context, const ProductEditorScreen()),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('Add product', 'उत्पाद जोड़ें')),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([store.products, store.productsError]),
        builder: (context, _) {
          final all = store.products.value;
          if (all == null) {
            return store.productsError.value != null ? ErrorView(store.productsError.value!) : const SkeletonList(itemHeight: 88);
          }
          final modules = all.map((p) => p.moduleId).toSet().toList()..sort();
          final q = _q.toLowerCase();
          final list = all.where((p) {
            if (_status != 'all' && p.status != _status) return false;
            if (_low && !SellerData.isLowStock(p)) return false;
            if (_module != null && p.moduleId != _module) return false;
            if (q.isNotEmpty && !(p.name.toLowerCase().contains(q) || p.barcode.contains(q) || p.brandName.toLowerCase().contains(q))) return false;
            return true;
          }).toList();
          final statuses = <(String, String)>[
            ('all', context.tr('All', 'सभी')),
            ('active', context.tr('Active', 'सक्रिय')),
            ('pending', context.tr('Pending', 'लंबित')),
            ('rejected', context.tr('Rejected', 'अस्वीकृत')),
            ('draft', context.tr('Draft', 'ड्राफ्ट')),
          ];
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: context.tr('Search name, brand or barcode', 'नाम, ब्रांड या बारकोड खोजें'),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: () async {
                      final code = await scanBarcode(context);
                      if (code != null) {
                        _search.text = code;
                        setState(() => _q = code);
                      }
                    },
                  ),
                ),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                for (final s in statuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${s.$2} ${s.$1 == 'all' ? all.length : all.where((p) => p.status == s.$1).length}'),
                      selected: _status == s.$1,
                      onSelected: (_) => setState(() => _status = s.$1),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: Text(context.tr('Low stock', 'कम स्टॉक')),
                    selected: _low,
                    onSelected: (v) => setState(() => _low = v),
                  ),
                ),
                if (modules.length > 1)
                  for (final m in modules)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(Fmt.titleCase(m)),
                        selected: _module == m,
                        onSelected: (v) => setState(() => _module = v ? m : null),
                      ),
                    ),
              ]),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: G4MMotion.standard,
                child: list.isEmpty
                    ? AppEmpty(
                        key: const ValueKey('empty'),
                        icon: Icons.inventory_2_outlined,
                        title: all.isEmpty ? context.tr('No products yet', 'अभी कोई उत्पाद नहीं') : context.tr('No matches', 'कोई मेल नहीं'),
                        message: all.isEmpty ? context.tr('Add your first product to start selling.', 'बेचना शुरू करने के लिए पहला उत्पाद जोड़ें।') : null,
                      )
                    : _grid
                        ? GridView.builder(
                            key: const ValueKey('grid'),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .72),
                            itemCount: list.length,
                            itemBuilder: (c, i) => _gridCard(c, list[i]).stagger(i),
                          )
                        : ListView.separated(
                            key: const ValueKey('list'),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (c, i) => _listCard(c, list[i]).stagger(i),
                          ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  void _open(Product p) => Go.push(context, ProductEditorScreen(product: p));

  Widget _stockText(BuildContext context, Product p) {
    final s = SellerData.totalStock(p);
    final low = SellerData.isLowStock(p);
    return Text(
      s == 0 ? context.tr('Out of stock', 'स्टॉक खत्म') : '${context.tr('Stock', 'स्टॉक')}: $s',
      style: context.tt.bodySmall?.copyWith(color: s == 0 ? G4MColors.danger : (low ? G4MColors.warning : null), fontWeight: low ? FontWeight.w700 : null),
    );
  }

  Widget _listCard(BuildContext context, Product p) => AppCard(
        onTap: () => _open(p),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Hero(tag: 'p_${p.id}', child: ProductThumb(p.image, size: 64)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (p.isVeg != null) ...[VegMark(isVeg: p.isVeg!, size: 12), const SizedBox(width: 6)],
                Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(Fmt.money(p.price), style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (p.mrp > p.price) ...[
                  const SizedBox(width: 6),
                  Text(Fmt.money(p.mrp), style: context.tt.bodySmall?.copyWith(decoration: TextDecoration.lineThrough)),
                ],
                if (p.variants.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('· ${p.variants.length} ${context.tr('variants', 'वेरिएंट')}', style: context.tt.bodySmall),
                ],
              ]),
              const SizedBox(height: 4),
              _stockText(context, p),
            ]),
          ),
          StatusPill(p.status, label: Fmt.titleCase(p.status)),
        ]),
      );

  Widget _gridCard(BuildContext context, Product p) => AppCard(
        onTap: () => _open(p),
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Hero(
                tag: 'p_${p.id}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(G4MRadius.md)),
                  child: p.image.isEmpty
                      ? Container(color: context.rc.cardAlt, child: Icon(Icons.inventory_2_outlined, color: context.rc.faint, size: 40))
                      : NetImage(p.image),
                ),
              ),
              Positioned(top: 8, left: 8, child: StatusPill(p.status, label: Fmt.titleCase(p.status))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall),
              const SizedBox(height: 4),
              Text(Fmt.money(p.price), style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              _stockText(context, p),
            ]),
          ),
        ]),
      );
}
