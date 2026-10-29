import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/session.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import '../admin/catalog_util.dart';
import 'package:panel/l10n/overrides.dart';

/// Full-page product create / edit (admin + seller).
class ProductEditorPage extends StatefulWidget {
  const ProductEditorPage({super.key, this.id});
  final String? id;
  @override
  State<ProductEditorPage> createState() => _ProductEditorPageState();
}

class _ProductEditorPageState extends State<ProductEditorPage> {
  final Map<String, dynamic> _v = {};
  Doc? _existing;
  bool _loading = true;
  Object? _error;
  bool _dirty = false;
  bool _saving = false;
  bool _ai = false;
  int _rev = 0; // bump to rebuild forms after programmatic changes
  final _keys = List.generate(4, (_) => GlobalKey<EntityFormState>());
  List<Map<String, dynamic>> _variants = [];
  Map<String, Doc> _cats = {};
  Map<String, Doc> _brands = {};
  Map<String, Doc> _taxes = {};

  bool get _isNew => widget.id == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Lookups are best-effort: a failed read (rules/offline) must not block the editor.
    var lookupFailed = false;
    Future<Map<String, Doc>> lookup(Query<Json> q) async {
      try {
        return {for (final d in (await q.get()).docs) d.id: Doc.fromSnap(d)};
      } catch (_) {
        lookupFailed = true;
        return {};
      }
    }

    try {
      final results = await Future.wait([lookup(Fs.categories), lookup(Fs.brands), lookup(Fs.col('taxes'))]);
      _cats = results[0];
      _brands = results[1];
      _taxes = results[2];
      if (lookupFailed) toast('Some lists (categories, brands or taxes) could not be loaded', kind: ToastKind.info);
      if (!_isNew) {
        final d = await Fs.products.doc(widget.id).get();
        if (!d.exists) throw 'Product not found';
        _existing = Doc.fromSnap(d);
        if (isSeller && _existing!.s('sellerId') != session.uid) throw 'You can only edit your own products';
        _v.addAll(deepCopy(_existing!.data));
        _variants = (_v['variants'] is List ? _v['variants'] as List : const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _v.addAll({
          'moduleId': session.moduleId ?? 'ecommerce',
          'lowStockAt': 5,
          'stock': 0,
          'deliveryMinutes': 30,
          'unit': '',
          'status': 'active',
          'featured': false,
          'images': <String>[],
          'tags': <String>[],
        });
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _generateAi() async {
    final name = '${_v['name'] ?? ''}'.trim();
    if (name.isEmpty) {
      toast('Enter a product name first', kind: ToastKind.error);
      return;
    }
    setState(() => _ai = true);
    try {
      final cat = _cats[_v['categoryId']]?.s('name') ?? '';
      final r = await G4MApi.instance.generateDescription({
        'name': name,
        'category': cat,
        'keywords': [...(_v['tags'] as List? ?? const []).map((e) => '$e'), if ('${_v['brandName'] ?? ''}'.isNotEmpty) '${_v['brandName']}'],
      });
      setState(() {
        if ('${r['short'] ?? ''}'.isNotEmpty) _v['shortDescription'] = '${r['short']}';
        if ('${r['long'] ?? ''}'.isNotEmpty) _v['description'] = '${r['long']}';
        _rev++;
        _dirty = true;
      });
      toast('Description generated — review before saving');
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _ai = false);
    }
  }

  Future<void> _save() async {
    var ok = true;
    for (final k in _keys) {
      if (!(k.currentState?.validate() ?? true)) ok = false;
    }
    if ('${_v['categoryId'] ?? ''}'.isEmpty) {
      ok = false;
      toast('Choose a category', kind: ToastKind.error);
    }
    for (final v in _variants) {
      if ('${v['name'] ?? ''}'.trim().isEmpty || toNum(v['price']) <= 0) {
        ok = false;
        toast('Every variant needs a name and price', kind: ToastKind.error);
        break;
      }
    }
    if (!ok) {
      toast('Please fix the highlighted fields', kind: ToastKind.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final data = cleanValues(_v)..remove('id');
      final name = '${data['name']}';
      if ('${data['slug'] ?? ''}'.isEmpty) data['slug'] = Fmt.slugify(name);
      data['price'] = toNum(data['price']);
      data['mrp'] = toNum(data['mrp']) > 0 ? toNum(data['mrp']) : data['price'];
      data['stock'] = toNum(data['stock']).toInt();
      data['lowStockAt'] = toNum(data['lowStockAt'], 5).toInt();
      data['deliveryMinutes'] = toNum(data['deliveryMinutes'], 30).toInt();
      data['variants'] = [
        for (final v in _variants)
          {
            'id': '${v['id'] ?? ''}'.isEmpty ? _vid() : v['id'],
            'name': '${v['name']}'.trim(),
            'price': toNum(v['price']),
            'mrp': toNum(v['mrp']) > 0 ? toNum(v['mrp']) : toNum(v['price']),
            'stock': toNum(v['stock']).toInt(),
            'sku': '${v['sku'] ?? ''}'.trim(),
          },
      ];
      if (_variants.isNotEmpty) {
        data['stock'] = (data['variants'] as List).fold<int>(0, (a, e) => a + ((e as Map)['stock'] as int));
      }
      final catId = '${data['categoryId']}';
      data['categoryPath'] = categoryChain(catId, _cats);
      final brandId = '${data['brandId'] ?? ''}';
      data['brandName'] = brandId.isEmpty ? '' : _brands[brandId]?.s('name') ?? '';
      final taxId = '${data['taxId'] ?? ''}';
      data['taxPct'] = taxId.isEmpty ? 0 : _taxes[taxId]?.n('percent') ?? 0;
      if (isSeller) {
        data['sellerId'] = session.uid;
        data['sellerName'] = session.profile?.s('storeName') ?? session.displayName;
        data.remove('featured');
        if (_isNew) {
          data['status'] = 'pending';
        } else {
          data['status'] = _existing!.s('status', 'pending');
        }
      } else {
        final sid = '${data['sellerId'] ?? ''}';
        if (sid.isEmpty) {
          data['sellerId'] = '';
          data['sellerName'] = 'Go4Market';
        }
      }
      data['keywords'] = productKeywords(data, categoryName: _cats[catId]?.s('name') ?? '');
      data['updatedAt'] = FieldValue.serverTimestamp();
      if (_isNew) {
        data
          ..['createdAt'] = FieldValue.serverTimestamp()
          ..['rating'] = 0
          ..['ratingCount'] = 0
          ..['soldCount'] = 0
          ..['viewCount'] = 0;
        await Fs.products.add(data);
      } else {
        await _existing!.ref!.set(data, SetOptions(merge: true));
      }
      _dirty = false;
      toast(_isNew ? (isSeller ? 'Product submitted for approval' : 'Product created') : 'Product saved');
      if (mounted) context.go('/catalog/products');
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _vid() => 'v${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(999)}';

  Future<void> _cancel() async {
    if (_dirty && !await confirm(context, 'Discard unsaved changes?', danger: true, confirmLabel: 'Discard')) return;
    if (mounted) context.go('/catalog/products');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const PanelPage(title: 'Loading product…', child: LoadingBlock());
    if (_error != null) return PanelPage(title: 'Product', child: ErrorBox(_error!));
    final wide = MediaQuery.sizeOf(context).width > 1250;
    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(
        title: 'Basic information',
        icon: Icons.notes_rounded,
        trailing: FilledButton.tonalIcon(
          onPressed: _ai ? null : _generateAi,
          icon: _ai ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(tr('Generate with AI')),
        ),
        child: EntityForm(
          key: _keys[0],
          onChanged: _touch,
          values: _v,
          fields: const [
            F('name', 'Product name', FT.text, required: true, wide: true),
            F('slug', 'URL slug', FT.text, help: 'Leave empty to generate from the name', wide: true),
            F('shortDescription', 'Short description', FT.multiline, help: 'One or two lines shown on product cards'),
            F('description', 'Full description', FT.markdown),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Images',
        icon: Icons.photo_library_outlined,
        subtitle: 'First image is the cover. Drag to reorder. WebP supported.',
        child: EntityForm(
          key: ValueKey('img$_rev'),
          onChanged: _touch,
          values: _v,
          fields: [F('images', 'Product images', FT.images, folder: 'products/${isSeller ? session.uid : 'admin'}')],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Pricing & inventory',
        icon: Icons.sell_outlined,
        child: EntityForm(
          key: _keys[1],
          onChanged: _touch,
          values: _v,
          columns: 3,
          fields: [
            const F('price', 'Selling price', FT.money, required: true, min: 0),
            F('mrp', 'MRP', FT.money, min: 0, validator: (v, all) => v != null && toNum(v) > 0 && toNum(v) < toNum(all['price']) ? 'MRP must be ≥ price' : null),
            const F('unit', 'Unit', FT.text, hint: '500 g, 1 L, pack of 6'),
            F('taxId', 'Tax', FT.select, options: {for (final t in _taxes.values) t.id: '${t.s('title')} (${t.n('percent').toStringAsFixed(t.n('percent') % 1 == 0 ? 0 : 1)}%)'}),
            F('stock', 'Stock', FT.integer, min: 0, help: _variants.isEmpty ? null : 'Calculated from variants', readOnly: _variants.isNotEmpty),
            const F('lowStockAt', 'Low-stock alert at', FT.integer, min: 0),
            const F('sku', 'SKU', FT.text),
            const F('barcode', 'Barcode (EAN/UPC)', FT.text, help: 'Used by the POS scanner'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Variants',
        icon: Icons.layers_outlined,
        subtitle: 'Sizes, colours or packs — each with its own price and stock',
        trailing: Wrap(spacing: 8, children: [
          OutlinedButton.icon(onPressed: _generateVariants, icon: const Icon(Icons.auto_fix_high_rounded, size: 18), label: Text(tr('From attributes'))),
          FilledButton.tonalIcon(
            onPressed: () => setState(() {
              _variants.add({'id': _vid(), 'name': '', 'price': _v['price'], 'mrp': _v['mrp'], 'stock': 0, 'sku': ''});
              _dirty = true;
            }),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(tr('Add variant')),
          ),
        ]),
        child: _VariantsEditor(
          key: ValueKey('var$_rev'),
          variants: _variants,
          onChanged: () => setState(() => _dirty = true),
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Specifications',
        icon: Icons.list_alt_rounded,
        subtitle: 'Dietary marker and custom fields (allergens, specs, warranty…)',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('Dietary marker', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 16),
            Segmented<String>(
              value: _v['isVeg'] == true ? 'veg' : _v['isVeg'] == false ? 'nonveg' : 'na',
              options: const {'na': 'Not applicable', 'veg': 'Veg', 'nonveg': 'Non-veg'},
              onChanged: (x) => setState(() {
                _v['isVeg'] = x == 'veg' ? true : x == 'nonveg' ? false : null;
                _dirty = true;
              }),
            ),
            const SizedBox(width: 10),
            if (_v['isVeg'] is bool) VegMark(isVeg: _v['isVeg'] == true),
          ]),
          const SizedBox(height: 16),
          StreamBuilder<List<String>>(
            stream: Fs.col('customFields').snapshots().map((s) => s.docs
                .where((d) => (d.data()['target'] ?? 'products') == 'products' && d.data()['active'] != false && (d.data()['sellerId'] == null || d.data()['sellerId'] == session.uid))
                .map((d) => '${d.data()['name'] ?? d.id}')
                .toList()).handleError((_) {}),
            builder: (context, s) => KeyValueField(
              key: ValueKey('cf$_rev${s.data?.length ?? 0}'),
              label: 'Custom fields',
              suggestions: s.data ?? const [],
              value: _v['customFields'] is Map ? Map<String, dynamic>.from(_v['customFields'] as Map) : {},
              onChanged: (m) {
                _v['customFields'] = m;
                _touch();
              },
            ),
          ),
        ]),
      ),
    ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionCard(
        title: 'Publishing',
        icon: Icons.publish_rounded,
        child: isSeller
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text(tr('Status  ')), statusPill(_isNew ? 'pending' : _existing!.s('status', 'pending'))]),
                const SizedBox(height: 8),
                Text(_isNew ? 'New products go live after Go4Market approves them.' : 'Status is managed by Go4Market.',
                    style: TextStyle(fontSize: 12.5, color: context.pal.muted)),
                if ((_existing?.s('rejectReason') ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Rejected: ${_existing!.s('rejectReason')}', style: const TextStyle(color: G4MColors.danger, fontWeight: FontWeight.w600)),
                ],
              ])
            : EntityForm(
                key: _keys[2],
                onChanged: _touch,
                values: _v,
                columns: 1,
                fields: [
                  const F('status', 'Status', FT.select, required: true, options: {'active': 'Active (live)', 'pending': 'Pending review', 'draft': 'Draft', 'rejected': 'Rejected'}),
                  const F('featured', 'Featured product', FT.toggle, help: 'Eligible for featured sections & badges'),
                  F('sellerId', 'Seller', FT.select,
                      optionsStream: () => optionsOf(Fs.sellers.where('status', isEqualTo: 'approved'), 'storeName'),
                      help: 'Leave empty for a Go4Market-owned product'),
                ],
              ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        title: 'Organisation',
        icon: Icons.category_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Category *'),
            child: Row(children: [
              Expanded(
                child: Text(
                  '${_v['categoryId'] ?? ''}'.isEmpty ? 'Not selected' : categoryLabel('${_v['categoryId']}', _cats),
                  style: TextStyle(color: '${_v['categoryId'] ?? ''}'.isEmpty ? context.pal.muted : null, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final id = await pickCategory(context, moduleId: '${_v['moduleId'] ?? ''}'.isEmpty ? null : '${_v['moduleId']}');
                  if (id == null || id.isEmpty) return;
                  setState(() {
                    _v['categoryId'] = id;
                    final m = _cats[id]?.s('moduleId');
                    if (m != null && m.isNotEmpty) _v['moduleId'] = m;
                    _rev++;
                    _dirty = true;
                  });
                },
                child: Text(tr('Choose')),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          EntityForm(
            key: _keys[3],
            onChanged: _touch,
            values: _v,
            columns: 1,
            fields: [
              F('moduleId', 'Module', FT.select, required: true, options: moduleOptionsLocal, initial: 'ecommerce'),
              F('brandId', 'Brand', FT.select, options: {
                for (final b in (_brands.values.toList()..sort((a, b) => a.s('name').compareTo(b.s('name'))))) b.id: b.s('name'),
              }),
              const F('tags', 'Tags', FT.tags),
              const F('deliveryMinutes', 'Delivery estimate (minutes)', FT.integer, min: 5, help: '15 / 30 enables quick delivery badges'),
            ],
          ),
        ]),
      ),
      if (!_isNew) ...[
        const SizedBox(height: 16),
        SectionCard(
          title: 'Performance',
          icon: Icons.query_stats_rounded,
          child: Column(children: [
            InfoRow('Sold', Fmt.number(_existing!.n('soldCount'))),
            InfoRow('Views', Fmt.number(_existing!.n('viewCount'))),
            InfoRow('Rating', '${_existing!.n('rating').toStringAsFixed(1)} (${_existing!.i('ratingCount')} reviews)'),
            InfoRow('Created', Fmt.dateTime(_existing!.createdAt)),
            InfoRow('Product ID', _existing!.id),
          ]),
        ),
      ],
    ]);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save},
      child: Column(children: [
        Expanded(
          child: PanelPage(
            title: _isNew ? 'Add product' : 'Edit product',
            subtitle: _isNew ? (isSeller ? 'Submitted products are reviewed before going live' : 'Create a product in any module') : '${_v['name'] ?? ''}',
            actions: [OutlinedButton.icon(onPressed: _cancel, icon: const Icon(Icons.arrow_back_rounded, size: 18), label: Text(tr('Back to products')))],
            child: KeyedSubtree(
              key: ValueKey(_rev),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 7, child: main),
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: side),
                    ])
                  : Column(children: [side, const SizedBox(height: 16), main]),
            ),
          ),
        ),
        // Sticky save bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: context.pal.surface,
            border: Border(top: BorderSide(color: context.pal.line)),
            boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: Row(children: [
            AnimatedOpacity(
              opacity: _dirty ? 1 : 0,
              duration: G4MMotion.standard,
              child: const Row(children: [
                Icon(Icons.circle, size: 8, color: G4MColors.warning),
                SizedBox(width: 8),
                Text('Unsaved changes', style: TextStyle(fontWeight: FontWeight.w700, color: G4MColors.warning)),
              ]),
            ),
            const Spacer(),
            OutlinedButton(onPressed: _cancel, child: Text(tr('Cancel'))),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isNew ? (isSeller ? 'Submit for approval' : 'Create product') : 'Save changes'),
            ),
          ]),
        ),
      ]),
    );
  }

  /// Builds variant combinations from attribute values.
  Future<void> _generateVariants() async {
    List<Doc> attrs;
    try {
      final global = await Fs.attributes.where('sellerId', isNull: true).get();
      final own = isSeller ? await Fs.attributes.where('sellerId', isEqualTo: session.uid).get() : null;
      final all = isSeller ? null : await Fs.attributes.get();
      attrs = [
        ...(all?.docs ?? [...global.docs, ...?own?.docs]).map(Doc.fromSnap),
      ];
      final seen = <String>{};
      attrs = attrs.where((a) => seen.add(a.id)).toList();
    } catch (e) {
      toastError(e);
      return;
    }
    if (!mounted) return;
    if (attrs.isEmpty) {
      toast('No attributes defined yet — add some under Attributes', kind: ToastKind.info);
      return;
    }
    final picked = <String, Set<String>>{};
    final combos = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        List<String> build() {
          var acc = <String>[''];
          for (final a in attrs) {
            final vals = picked[a.id];
            if (vals == null || vals.isEmpty) continue;
            acc = [for (final p in acc) for (final v in a.list('values').where(vals.contains)) p.isEmpty ? v : '$p / $v'];
          }
          return acc.where((e) => e.isNotEmpty).toList();
        }

        final preview = build();
        return AlertDialog(
          title: Text(tr('Generate variants')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                for (final a in attrs) ...[
                  Text(a.s('name'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final v in a.list('values'))
                      FilterChip(
                        label: Text(v),
                        selected: picked[a.id]?.contains(v) ?? false,
                        onSelected: (on) => set(() {
                          final s = picked.putIfAbsent(a.id, () => <String>{});
                          on ? s.add(v) : s.remove(v);
                        }),
                      ),
                  ]),
                  const SizedBox(height: 14),
                ],
                Text('${preview.length} combination(s)', style: TextStyle(color: ctx.pal.muted, fontWeight: FontWeight.w700)),
                if (preview.isNotEmpty) Text(preview.take(12).join(', ') + (preview.length > 12 ? '…' : ''), style: TextStyle(fontSize: 12, color: ctx.pal.muted)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
            FilledButton(onPressed: preview.isEmpty ? null : () => Navigator.pop(ctx, preview), child: Text('Add ${preview.length}')),
          ],
        );
      }),
    );
    if (combos == null) return;
    setState(() {
      final existing = _variants.map((v) => '${v['name']}').toSet();
      for (final c in combos.where((c) => !existing.contains(c))) {
        _variants.add({'id': _vid(), 'name': c, 'price': _v['price'], 'mrp': _v['mrp'], 'stock': 0, 'sku': ''});
      }
      _rev++;
      _dirty = true;
    });
  }
}

class _VariantsEditor extends StatelessWidget {
  const _VariantsEditor({super.key, required this.variants, required this.onChanged});
  final List<Map<String, dynamic>> variants;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('No variants — the product is sold as a single item using the price and stock above.', style: TextStyle(color: context.pal.muted)),
      );
    }
    Widget cell(Map<String, dynamic> v, String k, String hint, {bool number = false, int flex = 2}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextFormField(
              initialValue: v[k] == null ? '' : (v[k] is num && (v[k] as num) % 1 == 0 ? '${(v[k] as num).toInt()}' : '${v[k]}'),
              keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
              inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
              decoration: InputDecoration(hintText: hint, labelText: hint, prefixText: k == 'price' || k == 'mrp' ? '₹ ' : null),
              onChanged: (x) {
                v[k] = number ? (num.tryParse(x) ?? 0) : x;
                onChanged();
              },
            ),
          ),
        );
    return Column(children: [
      for (var i = 0; i < variants.length; i++)
        Padding(
          key: ValueKey(variants[i]['id']),
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            cell(variants[i], 'name', 'Name', flex: 3),
            cell(variants[i], 'price', 'Price', number: true),
            cell(variants[i], 'mrp', 'MRP', number: true),
            cell(variants[i], 'stock', 'Stock', number: true),
            cell(variants[i], 'sku', 'SKU'),
            IconButton(
              tooltip: 'Remove variant',
              icon: const Icon(Icons.remove_circle_outline_rounded, color: G4MColors.danger),
              onPressed: () {
                variants.removeAt(i);
                onChanged();
              },
            ),
          ]),
        ),
    ]);
  }
}
