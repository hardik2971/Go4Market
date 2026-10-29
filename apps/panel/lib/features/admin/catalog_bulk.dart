import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:intl/intl.dart';

import '../../core/doc.dart';
import '../../core/session.dart';
import '../../core/web_utils.dart';
import '../../ui/image_upload.dart';
import '../../ui/kit.dart';
import 'catalog_util.dart';
import 'package:panel/l10n/overrides.dart';

const _cols = [
  'id', 'name', 'slug', 'sku', 'barcode', 'moduleId', 'categoryId', 'brandId', 'price', 'mrp', 'stock', 'lowStockAt', 'unit',
  'tags', 'images', 'shortDescription', 'description', 'isVeg', 'featured', 'status', 'deliveryMinutes', 'sellerId',
];
const _numCols = {'price', 'mrp', 'stock', 'lowStockAt', 'deliveryMinutes'};

class _Row {
  _Row(this.line, this.values);
  final int line;
  final Map<String, String> values;
  String action = 'create'; // create | update | error
  String? matchId;
  final errors = <String>[];
}

/// CSV bulk create / update with validated preview, plus export for bulk editing.
class BulkProductsPage extends StatefulWidget {
  const BulkProductsPage({super.key});
  @override
  State<BulkProductsPage> createState() => _BulkProductsPageState();
}

class _BulkProductsPageState extends State<BulkProductsPage> {
  List<_Row>? _rows;
  String? _fileName;
  bool _busy = false;
  int _done = 0;
  Map<String, Doc> _cats = {};
  Map<String, Doc> _brands = {};

  Future<List<Doc>> _existing() async {
    Query<Json> q = Fs.products;
    if (isSeller) q = q.where('sellerId', isEqualTo: session.uid);
    return (await q.limit(5000).get()).docs.map(Doc.fromSnap).toList();
  }

  void _template() {
    final sample = [
      ['', 'Organic Basmati Rice 1kg', '', 'RICE-1KG', '8901234567890', 'grocery', '<categoryId>', '<brandId>', '149', '199', '120', '10', '1 kg',
        'rice|organic', 'https://…/rice.webp', 'Aged long-grain basmati', 'Full **markdown** description', 'true', 'false', isSeller ? 'pending' : 'active', '30', ''],
    ];
    downloadText('go4market_products_template.csv', toCsv(_cols, sample));
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final list = await _existing();
      final rows = [
        for (final d in list)
          [
            d.id, d.s('name'), d.s('slug'), d.s('sku'), d.s('barcode'), d.s('moduleId'), d.s('categoryId'), d.s('brandId'),
            d.n('price'), d.n('mrp'), d.i('stock'), d.i('lowStockAt', 5), d.s('unit'), d.list('tags').join('|'), d.list('images').join('|'),
            d.s('shortDescription'), d.s('description'), d['isVeg'] is bool ? '${d['isVeg']}' : '', '${d.b('featured')}', d.s('status', 'active'),
            d.i('deliveryMinutes', 30), d.s('sellerId'),
          ],
      ];
      downloadText('go4market_products_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv', toCsv(_cols, rows));
      toast('Exported ${rows.length} products — edit and re-upload to update');
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final files = await pickFiles(extensions: ['csv']);
    if (files.isEmpty) return;
    setState(() {
      _busy = true;
      _rows = null;
      _fileName = files.first.$1;
    });
    try {
      final text = utf8.decode(files.first.$2, allowMalformed: true);
      final grid = parseCsv(text);
      if (grid.length < 2) throw 'The file has no data rows';
      final header = grid.first.map((h) => h.trim()).toList();
      if (!header.contains('name') && !header.contains('id')) throw 'Header must include at least "name" (or "id" for updates)';
      final results = await Future.wait([_existing(), Fs.categories.get(), Fs.brands.get()]);
      final existing = results[0] as List<Doc>;
      _cats = {for (final d in (results[1] as QuerySnapshot<Json>).docs) d.id: Doc.fromSnap(d)};
      _brands = {for (final d in (results[2] as QuerySnapshot<Json>).docs) d.id: Doc.fromSnap(d)};
      final byId = {for (final d in existing) d.id: d};
      final bySku = {for (final d in existing.where((d) => d.s('sku').isNotEmpty)) d.s('sku').toLowerCase(): d};
      final byBarcode = {for (final d in existing.where((d) => d.s('barcode').isNotEmpty)) d.s('barcode'): d};
      final bySlug = {for (final d in existing.where((d) => d.s('slug').isNotEmpty)) d.s('slug'): d};

      final rows = <_Row>[];
      for (var i = 1; i < grid.length; i++) {
        final m = <String, String>{};
        for (var c = 0; c < header.length && c < grid[i].length; c++) {
          m[header[c]] = grid[i][c].trim();
        }
        final r = _Row(i + 1, m);
        Doc? match;
        final id = m['id'] ?? '';
        if (id.isNotEmpty) {
          match = byId[id];
          if (match == null) r.errors.add(isSeller ? 'id not found among your products' : 'id not found');
        }
        match ??= (m['sku'] ?? '').isNotEmpty ? bySku[m['sku']!.toLowerCase()] : null;
        match ??= (m['barcode'] ?? '').isNotEmpty ? byBarcode[m['barcode']] : null;
        match ??= (m['slug'] ?? '').isNotEmpty ? bySlug[m['slug']] : null;
        if (match != null) {
          r.action = 'update';
          r.matchId = match.id;
        } else {
          if ((m['name'] ?? '').isEmpty) r.errors.add('name required');
          if ((m['price'] ?? '').isEmpty) r.errors.add('price required');
        }
        for (final k in _numCols) {
          final v = m[k] ?? '';
          if (v.isNotEmpty && num.tryParse(v) == null) r.errors.add('$k is not a number');
        }
        final cat = m['categoryId'] ?? '';
        if (cat.isNotEmpty && !_cats.containsKey(cat)) r.errors.add('unknown categoryId');
        final brand = m['brandId'] ?? '';
        if (brand.isNotEmpty && !_brands.containsKey(brand)) r.errors.add('unknown brandId');
        if (r.action == 'create' && cat.isEmpty) r.errors.add('categoryId required for new products');
        if (r.errors.isNotEmpty) r.action = 'error';
        rows.add(r);
      }
      setState(() => _rows = rows);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, dynamic> _data(_Row r) {
    final m = r.values;
    final out = <String, dynamic>{};
    for (final k in _cols) {
      if (k == 'id' || !m.containsKey(k)) continue;
      final v = m[k]!;
      if (v.isEmpty && r.action == 'update') continue; // blank cells keep the current value
      if (_numCols.contains(k)) {
        out[k] = k == 'price' || k == 'mrp' ? (num.tryParse(v) ?? 0) : (num.tryParse(v) ?? 0).toInt();
      } else if (k == 'tags' || k == 'images') {
        out[k] = v.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (k == 'isVeg') {
        out[k] = v.toLowerCase() == 'true' ? true : v.toLowerCase() == 'false' ? false : null;
      } else if (k == 'featured') {
        out[k] = v.toLowerCase() == 'true';
      } else {
        out[k] = v;
      }
    }
    if (out['categoryId'] != null) out['categoryPath'] = categoryChain('${out['categoryId']}', _cats);
    if (out['brandId'] != null) out['brandName'] = _brands['${out['brandId']}']?.s('name') ?? '';
    if (isSeller) {
      out['sellerId'] = session.uid;
      out['sellerName'] = session.profile?.s('storeName') ?? session.displayName;
      out.remove('featured');
      if (r.action == 'create') {
        out['status'] = 'pending';
      } else {
        out.remove('status');
      }
    }
    if (r.action == 'create') {
      out['slug'] = '${out['slug'] ?? ''}'.isEmpty ? Fmt.slugify('${out['name']}') : out['slug'];
      out['mrp'] = (out['mrp'] ?? 0) == 0 ? out['price'] : out['mrp'];
      out
        ..putIfAbsent('status', () => 'active')
        ..putIfAbsent('moduleId', () => _cats['${out['categoryId']}']?.s('moduleId') ?? 'ecommerce')
        ..putIfAbsent('stock', () => 0)
        ..putIfAbsent('lowStockAt', () => 5)
        ..putIfAbsent('images', () => <String>[])
        ..putIfAbsent('variants', () => <dynamic>[])
        ..['rating'] = 0
        ..['ratingCount'] = 0
        ..['soldCount'] = 0
        ..['viewCount'] = 0
        ..['createdAt'] = FieldValue.serverTimestamp();
      if (!isSeller && '${out['sellerId'] ?? ''}'.isEmpty) out['sellerName'] = 'Go4Market';
    }
    if (out.containsKey('name') || out.containsKey('tags')) {
      out['keywords'] = productKeywords(out, categoryName: _cats['${out['categoryId'] ?? ''}']?.s('name') ?? '');
    }
    out['updatedAt'] = FieldValue.serverTimestamp();
    return out;
  }

  Future<void> _commit() async {
    final ok = _rows!.where((r) => r.action != 'error').toList();
    if (ok.isEmpty) return;
    final creates = ok.where((r) => r.action == 'create').length;
    if (!await confirm(context, 'Import ${ok.length} rows?', message: '$creates new · ${ok.length - creates} updates. Rows with errors are skipped.', confirmLabel: 'Import')) return;
    setState(() {
      _busy = true;
      _done = 0;
    });
    try {
      for (var i = 0; i < ok.length; i += 400) {
        final b = Fs.db.batch();
        for (final r in ok.skip(i).take(400)) {
          final data = _data(r);
          if (r.action == 'update') {
            b.set(Fs.products.doc(r.matchId), data, SetOptions(merge: true));
          } else {
            b.set(Fs.products.doc(), data);
          }
        }
        await b.commit();
        setState(() => _done = (i + 400).clamp(0, ok.length));
      }
      toast('Imported ${ok.length} products');
      setState(() => _rows = null);
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final errors = rows?.where((r) => r.action == 'error').length ?? 0;
    final creates = rows?.where((r) => r.action == 'create').length ?? 0;
    final updates = rows?.where((r) => r.action == 'update').length ?? 0;
    return PanelPage(
      title: 'Bulk upload & update',
      subtitle: 'Create or update many products at once with a CSV file',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ResponsiveGrid(minItemWidth: 300, children: [
          _step(context, '1', 'Download the template', 'Column headers, formats and an example row. Lists (tags, images) use | as separator.',
              OutlinedButton.icon(onPressed: _template, icon: Icon(Icons.description_outlined, size: 18), label: Text(tr('Template CSV')))),
          _step(context, '2', 'Or export current products', 'Edit prices, stock or details in Excel / Sheets, then upload to update by id.',
              OutlinedButton.icon(onPressed: _busy ? null : _export, icon: Icon(Icons.download_rounded, size: 18), label: Text(tr('Export products')))),
          _step(context, '3', 'Upload and review', 'Rows are matched by id, then SKU, barcode or slug. Nothing is written until you confirm.',
              FilledButton.icon(onPressed: _busy ? null : _pick, icon: Icon(Icons.upload_file_rounded, size: 18), label: Text(tr('Choose CSV')))),
        ]),
        SizedBox(height: 20),
        if (_busy && rows == null) SectionCard(child: LoadingBlock(rows: 3)),
        if (rows != null)
          SectionCard(
            title: 'Preview · $_fileName',
            subtitle: '${rows.length} rows · $creates new · $updates updates · $errors with errors${isSeller ? ' · new products are submitted for approval' : ''}',
            trailing: Wrap(spacing: 8, children: [
              TextButton(onPressed: _busy ? null : () => setState(() => _rows = null), child: Text(tr('Discard'))),
              FilledButton.icon(
                onPressed: _busy || creates + updates == 0 ? null : _commit,
                icon: _busy ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.done_all_rounded, size: 18),
                label: Text(_busy ? 'Importing $_done…' : 'Import ${creates + updates} rows'),
              ),
            ]),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columns: [
                  DataColumn(label: Text(tr('Line'))),
                  DataColumn(label: Text(tr('Action'))),
                  DataColumn(label: Text(tr('Name'))),
                  DataColumn(label: Text(tr('SKU'))),
                  DataColumn(label: Text(tr('Price'))),
                  DataColumn(label: Text(tr('Stock'))),
                  DataColumn(label: Text(tr('Category'))),
                  DataColumn(label: Text(tr('Issues'))),
                ],
                rows: [
                  for (final r in rows.take(500))
                    DataRow(cells: [
                      DataCell(Text('${r.line}')),
                      DataCell(Tag(r.action, color: r.action == 'error' ? G4MColors.danger : r.action == 'update' ? G4MColors.info : G4MColors.success)),
                      DataCell(SizedBox(width: 240, child: Text(r.values['name'] ?? '', overflow: TextOverflow.ellipsis))),
                      DataCell(Text(r.values['sku'] ?? '')),
                      DataCell(Text(r.values['price'] ?? '')),
                      DataCell(Text(r.values['stock'] ?? '')),
                      DataCell(Text(_cats[r.values['categoryId']]?.s('name') ?? (r.values['categoryId'] ?? ''))),
                      DataCell(Text(r.errors.join('; '), style: const TextStyle(color: G4MColors.danger, fontWeight: FontWeight.w600))),
                    ]),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Column reference',
          icon: Icons.info_outline_rounded,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _cols) Tag(c, color: c == 'name' || c == 'price' || c == 'categoryId' ? context.pal.accent : null),
          ]),
        ),
      ]),
    );
  }

  Widget _step(BuildContext context, String n, String title, String text, Widget action) => SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 16, backgroundColor: context.pal.accent.withValues(alpha: .14), child: Text(n, style: TextStyle(color: context.pal.accent, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(color: context.pal.muted, fontSize: 13)),
          const SizedBox(height: 14),
          action,
        ]),
      );
}
