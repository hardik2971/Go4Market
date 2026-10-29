import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/crud.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'catalog_util.dart';
import 'package:panel/l10n/overrides.dart';

export 'catalog_bulk.dart' show BulkProductsPage;
export 'catalog_categories.dart' show CategoriesPage;
export 'catalog_media.dart' show MediaPage;

// ───────────────────────── Brands ─────────────────────────

class BrandsPage extends StatelessWidget {
  const BrandsPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'brands',
        title: 'Brands',
        singular: 'Brand',
        subtitle: 'Brands shown on product pages and brand filters',
        collection: Fs.brands,
        labelOf: (d) => d.s('name'),
        search: (d) => d.s('name'),
        columns: [
          imageTitleCol('Brand', image: 'logo', sub: 'slug', flex: 5),
          Col<Doc>('Background', flex: 2, text: (d) => d.s('bgColor'), cell: (ctx, d) => d.s('bgColor').isEmpty
              ? Text(tr('—'))
              : Row(children: [
                  Container(width: 18, height: 18, decoration: BoxDecoration(color: G4MColors.fromHex(d.s('bgColor')), borderRadius: BorderRadius.circular(5), border: Border.all(color: ctx.pal.line))),
                  const SizedBox(width: 6),
                  Text(d.s('bgColor')),
                ])),
          dateCol('Added'),
        ],
        card: (ctx, d) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(
              height: 90,
              decoration: BoxDecoration(color: G4MColors.fromHex(d.s('bgColor'), ctx.pal.surfaceAlt), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: d.s('logo').isEmpty ? Icon(Icons.workspace_premium_outlined, size: 36, color: ctx.pal.faint) : NetImage(d.s('logo'), height: 64, fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Text(d.s('name'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
        fields: const [
          F('name', 'Brand name', FT.text, required: true),
          F('slug', 'Slug', FT.text, help: 'Generated from the name if empty'),
          F('logo', 'Logo', FT.image, folder: 'brands', help: 'Transparent PNG/WebP works best'),
          F('bgColor', 'Tile background', FT.color),
          F('description', 'Description', FT.multiline),
        ],
        beforeSave: (v, _) {
          if ('${v['slug'] ?? ''}'.isEmpty) v['slug'] = Fmt.slugify('${v['name']}');
          return v;
        },
      ));
}

// ───────────────────────── Taxes ─────────────────────────

class TaxesPage extends StatelessWidget {
  const TaxesPage({super.key});
  @override
  Widget build(BuildContext context) => CrudPage(Crud(
        id: 'taxes',
        title: 'Taxes',
        singular: 'Tax',
        subtitle: 'Tax classes (e.g. GST 5%, 12%, 18%) that can be assigned to products',
        collection: Fs.col('taxes'),
        labelOf: (d) => d.s('title'),
        search: (d) => d.s('title'),
        columns: [
          Col<Doc>('Title', flex: 4, text: (d) => d.s('title'), cell: (ctx, d) => TwoLine(d.s('title'), d.s('description'))),
          Col<Doc>('Rate', flex: 2, numeric: true, sort: (d) => d.n('percent'), text: (d) => '${d.n('percent').toStringAsFixed(d.n('percent') % 1 == 0 ? 0 : 2)}%'),
          dateCol('Updated', 'updatedAt'),
        ],
        fields: const [
          F('title', 'Title', FT.text, required: true, hint: 'GST 18%'),
          F('percent', 'Rate', FT.percent, required: true, min: 0, max: 100),
          F('description', 'Description', FT.multiline),
        ],
        beforeSave: (v, _) => v..['percent'] = toNum(v['percent']),
      ));
}

// ───────────────────────── Custom fields ─────────────────────────

const _cfTargets = {'products': 'Products', 'sellers': 'Sellers', 'delivery': 'Delivery partners', 'customers': 'Customers'};
const _cfTypes = {'text': 'Text', 'number': 'Number', 'boolean': 'Yes / No', 'select': 'Dropdown', 'file': 'File upload'};

class CustomFieldsPage extends StatefulWidget {
  const CustomFieldsPage({super.key});
  @override
  State<CustomFieldsPage> createState() => _CustomFieldsPageState();
}

class _CustomFieldsPageState extends State<CustomFieldsPage> {
  String _target = 'products';
  @override
  Widget build(BuildContext context) => CrudPage(
        key: ValueKey(_target),
        Crud(
          id: 'customFields_$_target',
          title: 'Custom fields',
          singular: 'Field',
          subtitle: 'Extra fields collected for products, sellers, delivery partners and customers (veg marker, allergens, licences…)',
          collection: Fs.col('customFields'),
          query: () => Fs.col('customFields').where('target', isEqualTo: _target),
          top: Segmented<String>(value: _target, options: _cfTargets, onChanged: (t) => setState(() => _target = t)),
          labelOf: (d) => d.s('name'),
          search: (d) => '${d.s('name')} ${d.s('key')}',
          defaults: {'target': _target, 'type': 'text', 'required': false},
          columns: [
            Col<Doc>('Field', flex: 4, text: (d) => d.s('name'), cell: (ctx, d) => TwoLine(d.s('name'), d.s('key'))),
            Col<Doc>('Type', flex: 2, text: (d) => _cfTypes[d.s('type')] ?? d.s('type'), cell: (ctx, d) => Tag(_cfTypes[d.s('type')] ?? d.s('type'), color: ctx.pal.accent)),
            Col<Doc>('Options', flex: 3, text: (d) => d.list('options').join(', ')),
            Col<Doc>('Required', flex: 1, text: (d) => d.b('required') ? 'Yes' : 'No'),
          ],
          fields: [
            const F('name', 'Field label', FT.text, required: true, hint: 'Allergens'),
            const F('key', 'Key', FT.text, help: 'Generated from the label if empty'),
            const F('type', 'Type', FT.select, required: true, options: _cfTypes),
            const F('target', 'Applies to', FT.select, required: true, options: _cfTargets),
            F('options', 'Dropdown options', FT.tags, visibleIf: (v) => v['type'] == 'select'),
            const F('help', 'Help text', FT.text, wide: true),
            const F('required', 'Required', FT.toggle),
          ],
          beforeSave: (v, _) {
            if ('${v['key'] ?? ''}'.isEmpty) v['key'] = Fmt.slugify('${v['name']}').replaceAll('-', '_');
            return v;
          },
        ),
      );
}

// ───────────────────────── Attributes ─────────────────────────

class AttributesPage extends StatefulWidget {
  const AttributesPage({super.key});
  @override
  State<AttributesPage> createState() => _AttributesPageState();
}

class _AttributesPageState extends State<AttributesPage> {
  int _tab = 0; // seller: 0 own, 1 global, 2 custom fields

  static const _fields = [
    F('name', 'Attribute name', FT.text, required: true, hint: 'Size, Colour, Weight'),
    F('values', 'Values', FT.tags, required: true, help: 'e.g. S, M, L, XL — press Enter after each'),
    F('displayType', 'Display as', FT.select, options: {'chips': 'Chips', 'color': 'Colour swatches', 'dropdown': 'Dropdown'}, initial: 'chips'),
  ];

  Col<Doc> get _valuesCol => Col<Doc>('Values', flex: 6, text: (d) => d.list('values').join(', '), cell: (ctx, d) => Wrap(spacing: 4, runSpacing: 4, children: [
        for (final v in d.list('values').take(10)) Tag(v),
        if (d.list('values').length > 10) Tag('+${d.list('values').length - 10}'),
      ]));

  @override
  Widget build(BuildContext context) {
    if (!isSeller) {
      return CrudPage(Crud(
        id: 'attributes',
        title: 'Attributes',
        singular: 'Attribute',
        subtitle: 'Global attributes are shared by every seller; sellers can also define their own',
        collection: Fs.attributes,
        activeField: null,
        labelOf: (d) => d.s('name'),
        search: (d) => '${d.s('name')} ${d.list('values').join(' ')}',
        filters: [
          TableFilter<Doc>('owner', 'Owner', const {'global': 'Global', 'seller': 'Seller-owned'}, test: (d, v) => (d.s('sellerId').isEmpty) == (v == 'global')),
        ],
        columns: [
          Col<Doc>('Attribute', flex: 3, text: (d) => d.s('name'), cell: (ctx, d) => TwoLine(d.s('name'), '${d.list('values').length} values')),
          _valuesCol,
          Col<Doc>('Owner', flex: 2, text: (d) => d.s('sellerId').isEmpty ? 'Global' : 'Seller',
              cell: (ctx, d) => d.s('sellerId').isEmpty ? Tag('Global', color: ctx.pal.accent, icon: Icons.public_rounded) : LookupText(_sellerName(d.s('sellerId')))),
          dateCol('Updated', 'updatedAt'),
        ],
        fields: _fields,
        beforeSave: (v, d) {
          if (d == null) v['sellerId'] = null;
          return v;
        },
      ));
    }

    final globalQ = Fs.attributes.where('sellerId', isNull: true);
    final ownQ = Fs.attributes.where('sellerId', isEqualTo: session.uid);
    return PanelPage(
      title: 'Attributes & custom fields',
      subtitle: 'Use global attributes or create your own for variants',
      actions: [
        if (_tab == 0) FilledButton.icon(onPressed: () => _editOwn(), icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('New attribute'))),
        if (_tab == 2) FilledButton.icon(onPressed: () => _editField(), icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('New custom field'))),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _MigrationAlerts(query: globalQ),
        Segmented<int>(value: _tab, options: const {0: 'My attributes', 1: 'Global attributes', 2: 'My custom fields'}, onChanged: (t) => setState(() => _tab = t)),
        const SizedBox(height: 16),
        if (_tab == 0)
          DataView<Doc>(
            key: const ValueKey('own'),
            id: 'seller_attributes',
            source: (q) => liveDocs(ownQ.limit(q.limit), label: 'attributes(sellerId)'),
            rowId: (d) => d.id,
            searchText: (d) => '${d.s('name')} ${d.list('values').join(' ')}',
            columns: [Col<Doc>('Attribute', flex: 3, text: (d) => d.s('name')), _valuesCol, dateCol('Updated', 'updatedAt')],
            onTap: (d) => _editOwn(d),
            actions: [
              RowAction('Edit', Icons.edit_outlined, (d) => _editOwn(d)),
              RowAction('Delete', Icons.delete_outline_rounded, (d) async {
                if (await confirm(context, 'Delete "${d.s('name')}"?', danger: true, confirmLabel: 'Delete')) await runToast(() => d.ref!.delete(), success: 'Deleted');
              }, danger: true),
            ],
            emptyIcon: Icons.tune_rounded,
            emptyTitle: 'No custom attributes',
            emptyMessage: 'Create attributes like “Pack size” to generate product variants.',
          )
        else if (_tab == 1)
          DataView<Doc>(
            key: const ValueKey('global'),
            id: 'global_attributes',
            source: (q) => liveDocs(globalQ.limit(q.limit), label: 'attributes(global)'),
            rowId: (d) => d.id,
            searchText: (d) => '${d.s('name')} ${d.list('values').join(' ')}',
            columns: [
              Col<Doc>('Attribute', flex: 3, text: (d) => d.s('name'), cell: (ctx, d) => TwoLine(d.s('name'), 'Read-only · managed by Go4Market')),
              _valuesCol,
              dateCol('Updated', 'updatedAt'),
            ],
            emptyTitle: 'No global attributes',
          )
        else
          DataView<Doc>(
            key: const ValueKey('fields'),
            id: 'seller_custom_fields',
            source: (q) => liveDocs(Fs.col('customFields').where('sellerId', isEqualTo: session.uid).limit(q.limit), label: 'customFields(sellerId)'),
            rowId: (d) => d.id,
            searchText: (d) => d.s('name'),
            columns: [
              Col<Doc>('Field', flex: 4, text: (d) => d.s('name')),
              Col<Doc>('Type', flex: 2, text: (d) => _cfTypes[d.s('type')] ?? d.s('type')),
              Col<Doc>('Options', flex: 4, text: (d) => d.list('options').join(', ')),
            ],
            onTap: (d) => _editField(d),
            actions: [
              RowAction('Edit', Icons.edit_outlined, (d) => _editField(d)),
              RowAction('Delete', Icons.delete_outline_rounded, (d) => runToast(() => d.ref!.delete(), success: 'Deleted'), danger: true),
            ],
            emptyIcon: Icons.dynamic_form_outlined,
            emptyTitle: 'No custom fields',
            emptyMessage: 'Custom fields appear as suggestions in the product editor (e.g. “Material”, “Warranty”).',
          ),
      ]),
    );
  }

  Future<void> _editOwn([Doc? d]) => openEditor(
        context,
        title: d == null ? 'New attribute' : 'Edit attribute',
        fields: _fields,
        initial: d?.data,
        onSave: (raw) async {
          final v = cleanValues(raw)
            ..['sellerId'] = session.uid
            ..['updatedAt'] = FieldValue.serverTimestamp();
          if (d == null) {
            v['createdAt'] = FieldValue.serverTimestamp();
            await Fs.attributes.add(v);
          } else {
            await d.ref!.set(v, SetOptions(merge: true));
          }
        },
      );

  Future<void> _editField([Doc? d]) => openEditor(
        context,
        title: d == null ? 'New custom field' : 'Edit custom field',
        fields: [
          const F('name', 'Field label', FT.text, required: true),
          const F('type', 'Type', FT.select, required: true, options: _cfTypes, initial: 'text'),
          F('options', 'Dropdown options', FT.tags, visibleIf: (v) => v['type'] == 'select'),
        ],
        initial: d?.data,
        onSave: (raw) async {
          final v = cleanValues(raw)
            ..['sellerId'] = session.uid
            ..['target'] = 'products'
            ..['active'] = true
            ..['key'] = Fmt.slugify('${raw['name']}').replaceAll('-', '_')
            ..['updatedAt'] = FieldValue.serverTimestamp();
          if (d == null) {
            v['createdAt'] = FieldValue.serverTimestamp();
            await Fs.col('customFields').add(v);
          } else {
            await d.ref!.set(v, SetOptions(merge: true));
          }
        },
      );
}

final _sellerNames = <String, Future<String>>{};
Future<String> _sellerName(String id) => _sellerNames.putIfAbsent(id, () async {
      try {
        return '${(await Fs.sellers.doc(id).get()).data()?['storeName'] ?? id}';
      } catch (_) {
        return id;
      }
    });

/// Feature 71: warns sellers when global attributes changed recently.
class _MigrationAlerts extends StatelessWidget {
  const _MigrationAlerts({required this.query});
  final Query<Json> query;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Doc>>(
        stream: liveDocs(query, label: 'attributes(global)'),
        builder: (context, s) {
          final cutoff = DateTime.now().subtract(const Duration(days: 14));
          final changed = (s.data ?? const <Doc>[]).where((d) => (d.dt('updatedAt') ?? DateTime(2000)).isAfter(cutoff)).toList();
          if (changed.isEmpty) return const SizedBox();
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: G4MColors.warning.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: G4MColors.warning.withValues(alpha: .4)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: G4MColors.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Global attributes were updated', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '${changed.map((d) => '${d.s('name')} (${Fmt.ago(d.dt('updatedAt'))})').join(', ')}. '
                    'Review your product variants that use these attributes so names and values stay in sync.',
                    style: TextStyle(color: context.pal.muted),
                  ),
                ]),
              ),
              TextButton(onPressed: () => context.go('/catalog/products'), child: Text(tr('Review products'))),
            ]),
          );
        },
      );
}

// ───────────────────────── Stock ─────────────────────────

class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final Stream<List<Doc>> _kpi = scopedProducts(limit: 1000).asBroadcastStream();

  Future<void> _variantDialog(Doc d) async {
    final vars = d.list('variants').isEmpty ? <Map<String, dynamic>>[] : (d['variants'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final ctrls = [for (final v in vars) TextEditingController(text: '${toNum(v['stock']).toInt()}')];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Variant stock · ${d.s('name')}'),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < vars.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Expanded(flex: 3, child: TwoLine('${vars[i]['name']}', '${vars[i]['sku'] ?? ''}')),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: ctrls[i],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Stock'),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          AsyncButton(
            label: 'Save stock',
            onPressed: () async {
              for (var i = 0; i < vars.length; i++) {
                vars[i]['stock'] = int.tryParse(ctrls[i].text) ?? 0;
              }
              final total = vars.fold<int>(0, (a, v) => a + (v['stock'] as int));
              final ok = await runToast(() => d.ref!.update({'variants': vars, 'stock': total, 'updatedAt': FieldValue.serverTimestamp()}), success: 'Stock updated');
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Stock management',
        subtitle: 'Live inventory with low-stock alerts and quick restock',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StreamBuilder<List<Doc>>(
            stream: _kpi,
            builder: (context, s) {
              final l = s.data ?? const <Doc>[];
              final out = l.where((d) => stockState(d) == 'out').length;
              final low = l.where((d) => stockState(d) == 'low').length;
              final units = l.fold<int>(0, (a, d) => a + effectiveStock(d));
              final value = l.fold<double>(0, (a, d) => a + effectiveStock(d) * d.n('price'));
              return ResponsiveGrid(minItemWidth: 220, children: [
                KpiCard(label: 'Products tracked', value: Fmt.number(l.length), icon: Icons.inventory_2_rounded),
                KpiCard(label: 'Out of stock', value: Fmt.number(out), icon: Icons.remove_shopping_cart_rounded, color: G4MColors.danger),
                KpiCard(label: 'Low stock', value: Fmt.number(low), icon: Icons.warning_amber_rounded, color: G4MColors.warning),
                KpiCard(label: 'Units · stock value', value: '${Fmt.number(units)} · ${Fmt.moneyCompact(value)}', icon: Icons.warehouse_rounded, color: G4MColors.info),
              ]);
            },
          ),
          const SizedBox(height: 20),
          DataView<Doc>(
            id: 'stock',
            source: (q) => scopedProducts(limit: q.limit < 1000 ? 1000 : q.limit),
            initialLimit: 1000,
            rowId: (d) => d.id,
            searchText: (d) => '${d.s('name')} ${d.s('sku')} ${d.s('barcode')} ${d.s('sellerName')}',
            filters: [
              TableFilter<Doc>('stock', 'Stock state', const {'low': 'Low stock', 'out': 'Out of stock', 'in': 'Healthy'}, initial: 'low', test: (d, v) => stockState(d) == v),
              TableFilter<Doc>('module', 'Module', moduleOptionsLocal, initial: session.moduleId, test: (d, v) => d.s('moduleId', 'ecommerce') == v),
            ],
            defaultSort: 2,
            defaultDesc: false,
            leading: (ctx, d) => RowThumb(d.list('images').isEmpty ? '' : d.list('images').first),
            columns: [
              Col<Doc>('Product', flex: 5, text: (d) => d.s('name'), cell: (ctx, d) => TwoLine(d.s('name'), [d.s('sku'), if (!isSeller) d.s('sellerName')].where((e) => e.isNotEmpty).join(' · '))),
              Col<Doc>('Alert at', flex: 1, numeric: true, sort: (d) => d.i('lowStockAt', 5), text: (d) => '${d.i('lowStockAt', 5)}'),
              Col<Doc>('Stock', flex: 2, numeric: true, sort: (d) => effectiveStock(d), text: (d) => '${effectiveStock(d)}',
                  cell: (ctx, d) => Tag(stockState(d) == 'out' ? 'Out of stock' : '${effectiveStock(d)} units', color: stockColor(stockState(d)))),
              Col<Doc>('Restock', flex: 4, cell: (ctx, d) => d.list('variants').isNotEmpty
                  ? OutlinedButton.icon(onPressed: () => _variantDialog(d), icon: const Icon(Icons.layers_outlined, size: 16), label: Text('${d.list('variants').length} variants'))
                  : _InlineStock(doc: d)),
            ],
            emptyIcon: Icons.check_circle_outline_rounded,
            emptyTitle: 'Inventory looks healthy',
          ),
        ]),
      );
}

class _InlineStock extends StatefulWidget {
  const _InlineStock({required this.doc});
  final Doc doc;
  @override
  State<_InlineStock> createState() => _InlineStockState();
}

class _InlineStockState extends State<_InlineStock> {
  late final _c = TextEditingController(text: '${widget.doc.i('stock')}');
  bool _busy = false;

  Future<void> _save([int? add]) async {
    final n = add != null ? widget.doc.i('stock') + add : int.tryParse(_c.text);
    if (n == null || n < 0) return;
    setState(() => _busy = true);
    final ok = await runToast(() => widget.doc.ref!.update({'stock': n, 'updatedAt': FieldValue.serverTimestamp()}), success: '${widget.doc.s('name')}: stock $n');
    if (ok) _c.text = '$n';
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 84,
          height: 36,
          child: TextField(
            controller: _c,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6)),
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: 'Save',
          onPressed: _busy ? null : _save,
          icon: _busy ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded, size: 18),
        ),
        TextButton(onPressed: _busy ? null : () => _save(10), child: Text(tr('+10'))),
        TextButton(onPressed: _busy ? null : () => _save(50), child: Text(tr('+50'))),
      ]);
}

// ───────────────────────── Ratings ─────────────────────────

class RatingsPage extends StatefulWidget {
  const RatingsPage({super.key});
  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  String _pid(Doc d) => d.ref?.parent.parent?.id ?? '';

  /// Seller: one-shot fetch of reviews across own products.
  Stream<List<Doc>> _sellerReviews(int limit) async* {
    final prods = await Fs.products.where('sellerId', isEqualTo: session.uid).limit(200).get();
    final out = <Doc>[];
    await Future.wait(prods.docs.map((p) async {
      try {
        final r = await Fs.reviews(p.id).limit(50).get();
        out.addAll(r.docs.map(Doc.fromSnap));
      } catch (_) {}
    }));
    out.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    yield out.take(limit).toList();
  }

  @override
  Widget build(BuildContext context) {
    final group = Fs.db.collectionGroup('reviews');
    return PanelPage(
      title: isSeller ? 'Reviews' : 'Product ratings',
      subtitle: isSeller ? 'What customers say about your products' : 'Moderate customer reviews across the catalog',
      child: DataView<Doc>(
        id: 'ratings',
        source: (q) => isSeller
            ? _sellerReviews(q.limit)
            : liveDocs(group.orderBy('createdAt', descending: true).limit(q.limit), fallback: group.limit(q.limit), label: 'reviews(collectionGroup,createdAt)'),
        rowId: (d) => d.ref?.path ?? d.id,
        searchText: (d) => '${d.s('userName')} ${d.s('comment')}',
        filters: [
          TableFilter<Doc>('rating', 'Rating', const {'5': '5 ★', '4': '4 ★', '3': '3 ★', '2': '2 ★', '1': '1 ★'}, test: (d, v) => d.i('rating') == int.parse(v)),
          if (!isSeller) TableFilter<Doc>('hidden', 'Visibility', const {'visible': 'Visible', 'hidden': 'Hidden'}, test: (d, v) => d.b('hidden') == (v == 'hidden')),
        ],
        columns: [
          Col<Doc>('Product', flex: 3, cell: (ctx, d) => LookupText(productName(_pid(d)), style: const TextStyle(fontWeight: FontWeight.w700))),
          Col<Doc>('Customer', flex: 2, text: (d) => d.s('userName', 'Customer')),
          Col<Doc>('Rating', flex: 2, sort: (d) => d.i('rating'), text: (d) => '${d.i('rating')}', cell: (ctx, d) => stars(d.n('rating'))),
          Col<Doc>('Review', flex: 5, text: (d) => d.s('comment'), cell: (ctx, d) => Row(children: [
                Expanded(child: Text(d.s('comment').isEmpty ? '—' : d.s('comment'), maxLines: 2, overflow: TextOverflow.ellipsis)),
                for (final img in d.list('images').take(3)) Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: RowThumb(img, size: 30)),
              ])),
          dateCol('Date'),
          if (!isSeller) Col<Doc>('Visible', flex: 1, text: (d) => d.b('hidden') ? 'Hidden' : 'Visible', cell: (ctx, d) => Icon(d.b('hidden') ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: d.b('hidden') ? G4MColors.danger : G4MColors.success)),
        ],
        onTap: (d) => _show(d),
        actions: [
          RowAction('View', Icons.open_in_full_rounded, _show),
          RowAction('Open product', Icons.inventory_2_outlined, (d) => context.go('/catalog/products/${_pid(d)}/edit')),
          if (!isSeller) ...[
            RowAction('Hide', Icons.visibility_off_outlined, (d) => runToast(() => d.ref!.update({'hidden': true}), success: 'Review hidden'), visible: (d) => !d.b('hidden')),
            RowAction('Unhide', Icons.visibility_outlined, (d) => runToast(() => d.ref!.update({'hidden': false}), success: 'Review visible'), visible: (d) => d.b('hidden')),
            RowAction('Delete', Icons.delete_outline_rounded, (d) async {
              if (await confirm(context, 'Delete this review?', message: 'Product rating will be recalculated by the backend.', danger: true, confirmLabel: 'Delete')) {
                await runToast(() => d.ref!.delete(), success: 'Review deleted');
              }
            }, danger: true),
          ],
        ],
        bulkActions: isSeller
            ? const []
            : [
                BulkAction('Hide', Icons.visibility_off_outlined, (rows) async {
                  final b = ChunkedBatch();
                  for (final d in rows) {
                    b.update(d.ref!, {'hidden': true});
                  }
                  await b.commit();
                }),
                BulkAction('Delete', Icons.delete_outline_rounded, (rows) async {
                  final b = ChunkedBatch();
                  for (final d in rows) {
                    b.delete(d.ref!);
                  }
                  await b.commit();
                }, danger: true),
              ],
        emptyIcon: Icons.star_outline_rounded,
        emptyTitle: 'No reviews yet',
      ),
    );
  }

  void _show(Doc d) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: LookupText(productName(_pid(d))),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [stars(d.n('rating'), size: 20), const SizedBox(width: 10), Text(d.s('userName', 'Customer'), style: const TextStyle(fontWeight: FontWeight.w700))]),
              const SizedBox(height: 4),
              Text(Fmt.dateTime(d.createdAt), style: TextStyle(color: ctx.pal.muted, fontSize: 12)),
              const SizedBox(height: 12),
              SelectableText(d.s('comment').isEmpty ? 'No written review.' : d.s('comment')),
              if (d.list('images').isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final i in d.list('images')) NetImage(i, width: 110, height: 110, radius: 10)]),
              ],
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Close')))],
        ),
      );
}

// ───────────────────────── Product order ─────────────────────────

class ProductOrderPage extends StatefulWidget {
  const ProductOrderPage({super.key});
  @override
  State<ProductOrderPage> createState() => _ProductOrderPageState();
}

class _ProductOrderPageState extends State<ProductOrderPage> {
  String? _catId;
  String _catLabel = '';
  List<Doc>? _items;
  bool _loading = false;
  bool _dirty = false;

  Future<void> _choose() async {
    final id = await pickCategory(context, moduleId: session.moduleId);
    if (id == null || id.isEmpty) return;
    final cats = {for (final d in (await Fs.categories.get()).docs) d.id: Doc.fromSnap(d)};
    setState(() {
      _catId = id;
      _catLabel = categoryLabel(id, cats);
      _loading = true;
      _dirty = false;
    });
    try {
      final s = await Fs.products.where('categoryPath', arrayContains: id).limit(300).get();
      final l = s.docs.map(Doc.fromSnap).toList()
        ..sort((a, b) {
          final x = a['sortOrder'] is num ? a.n('sortOrder') : 1e9, y = b['sortOrder'] is num ? b.n('sortOrder') : 1e9;
          final r = x.compareTo(y);
          return r != 0 ? r : a.s('name').compareTo(b.s('name'));
        });
      setState(() => _items = l);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final b = ChunkedBatch();
    for (var i = 0; i < _items!.length; i++) {
      b.update(_items![i].ref!, {'sortOrder': i});
    }
    if (await runToast(b.commit, success: 'Product order saved')) setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Product order',
        subtitle: 'Control the order products appear in within a category',
        actions: [
          OutlinedButton.icon(onPressed: _choose, icon: const Icon(Icons.account_tree_outlined, size: 18), label: Text(_catId == null ? 'Choose category' : 'Change category')),
          if (_items != null) AsyncButton(onPressed: _dirty ? _save : null, icon: Icons.save_outlined, label: 'Save order'),
        ],
        child: SectionCard(
          title: _catId == null ? null : _catLabel,
          subtitle: _items == null ? null : '${_items!.length} products · drag the handle to reorder',
          child: _catId == null
              ? EmptyState(
                  icon: Icons.sort_rounded,
                  title: 'Pick a category',
                  message: 'Products will be listed in their current order so you can drag them into place.',
                  action: FilledButton(onPressed: _choose, child: Text(tr('Choose category'))),
                )
              : _loading
                  ? const LoadingBlock()
                  : _items!.isEmpty
                      ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'No products in this category')
                      : ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          buildDefaultDragHandles: false,
                          itemCount: _items!.length,
                          onReorder: (a, b) => setState(() {
                            if (b > a) b--;
                            _items!.insert(b, _items!.removeAt(a));
                            _dirty = true;
                          }),
                          itemBuilder: (ctx, i) {
                            final d = _items![i];
                            return ListTile(
                              key: ValueKey(d.id),
                              leading: Row(mainAxisSize: MainAxisSize.min, children: [
                                ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator_rounded)),
                                const SizedBox(width: 8),
                                SizedBox(width: 28, child: Text('${i + 1}', style: TextStyle(color: ctx.pal.muted, fontWeight: FontWeight.w700))),
                                RowThumb(d.list('images').isEmpty ? '' : d.list('images').first, size: 40),
                              ]),
                              title: Text(d.s('name'), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${Fmt.money(d.n('price'))} · ${d.s('sellerName')}'),
                              trailing: statusPill(d.s('status', 'active')),
                            );
                          },
                        ),
        ),
      );
}

// ───────────────────────── Customer product requests ─────────────────────────

class ProductRequestsPage extends StatelessWidget {
  const ProductRequestsPage({super.key});

  Future<void> _set(Doc d, String status, {String? note}) => runToast(
        () => d.ref!.update({'status': status, 'note': ?note, 'updatedAt': FieldValue.serverTimestamp()}),
        success: 'Marked ${status == 'added' ? 'as added' : status}',
      );

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Product requests',
        subtitle: 'Products customers asked for that are not listed yet',
        child: DataView<Doc>(
          id: 'productRequests',
          source: (q) => liveDocs(Fs.productRequests.orderBy('createdAt', descending: true).limit(q.limit), fallback: Fs.productRequests.limit(q.limit), label: 'productRequests'),
          rowId: (d) => d.id,
          searchText: (d) => '${d.s('name')} ${d.s('description')}',
          filters: [
            TableFilter<Doc>('status', 'Status', const {'open': 'Open', 'added': 'Added', 'rejected': 'Rejected'}, initial: 'open', test: (d, v) => d.s('status', 'open') == v),
          ],
          columns: [
            Col<Doc>('Requested product', flex: 5, text: (d) => d.s('name'), cell: (ctx, d) => TwoLine(d.s('name'), d.s('description'))),
            Col<Doc>('Customer', flex: 3, cell: (ctx, d) => LookupText(userName(d.s('userId')))),
            statusCol('Status', 'status', f: 'open'),
            dateCol('Requested'),
          ],
          card: (ctx, d) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline_rounded, color: G4MColors.accent),
              const SizedBox(height: 8),
              Text(d.s('name'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text(d.s('description'), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: ctx.pal.muted)),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: LookupText(userName(d.s('userId')), prefix: 'by ')), statusPill(d.s('status', 'open'))]),
            ]),
          ),
          actions: [
            RowAction('Create product', Icons.add_box_outlined, (d) => context.go('/catalog/products/new')),
            RowAction('Mark as added', Icons.check_circle_outline_rounded, (d) => _set(d, 'added'), visible: (d) => d.s('status', 'open') != 'added'),
            RowAction('Reject', Icons.block_rounded, (d) async {
              final note = await promptText(context, 'Reject request', label: 'Reason (optional)');
              if (note != null) await _set(d, 'rejected', note: note.isEmpty ? null : note);
            }, visible: (d) => d.s('status', 'open') == 'open'),
            RowAction('Delete', Icons.delete_outline_rounded, (d) async {
              if (await confirm(context, 'Delete request?', danger: true, confirmLabel: 'Delete')) await runToast(() => d.ref!.delete(), success: 'Deleted');
            }, danger: true),
          ],
          bulkActions: [
            BulkAction('Mark added', Icons.check_circle_outline_rounded, (rows) async {
              final b = ChunkedBatch();
              for (final d in rows) {
                b.update(d.ref!, {'status': 'added'});
              }
              await b.commit();
            }),
            BulkAction('Reject', Icons.block_rounded, (rows) async {
              final b = ChunkedBatch();
              for (final d in rows) {
                b.update(d.ref!, {'status': 'rejected'});
              }
              await b.commit();
            }),
          ],
          emptyIcon: Icons.lightbulb_outline_rounded,
          emptyTitle: 'No product requests',
        ),
      );
}
