import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import '../admin/catalog_util.dart';
import 'package:panel/l10n/overrides.dart';

export 'b_product_editor.dart' show ProductEditorPage;

/// Product list. Admin: every product; seller: own products.
/// [approvals] shows seller submissions awaiting review.
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, this.approvals = false});
  final bool approvals;
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late final Stream<List<Doc>> _cats = allCategories();
  late final Stream<Map<String, String>> _sellers = isSeller
      ? Stream.value(const <String, String>{})
      : Fs.sellers.snapshots().map((s) => {for (final d in s.docs) d.id: '${d.data()['storeName'] ?? d.id}'}).handleError((_) {});

  Future<void> _setStatus(List<Doc> rows, String status, {String? reason}) async {
    final b = ChunkedBatch();
    for (final d in rows) {
      b.update(d.ref!, {
        'status': status,
        'rejectReason': ?reason,
        if (status == 'active') 'approvedAt': FieldValue.serverTimestamp(),
        if (status == 'active') 'rejectReason': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await b.commit();
  }

  Future<void> _reject(BuildContext context, List<Doc> rows) async {
    final reason = await promptText(context, 'Reject ${rows.length} product(s)', label: 'Reason shown to the seller', required: true, maxLines: 3, confirmLabel: 'Reject');
    if (reason == null) return;
    await runToast(() => _setStatus(rows, 'rejected', reason: reason), success: 'Rejected');
  }

  Future<void> _duplicate(Doc d) async {
    final data = Map<String, dynamic>.from(d.data)
      ..['name'] = '${d.s('name')} (copy)'
      ..['slug'] = '${d.s('slug', d.id)}-copy-${DateTime.now().millisecondsSinceEpoch % 100000}'
      ..['status'] = isSeller ? 'pending' : 'draft'
      ..['featured'] = false
      ..['rating'] = 0
      ..['ratingCount'] = 0
      ..['soldCount'] = 0
      ..['viewCount'] = 0
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await runToast(() => Fs.products.add(data), success: 'Duplicated as ${isSeller ? 'pending' : 'draft'}');
  }

  @override
  Widget build(BuildContext context) {
    final approvals = widget.approvals;
    return PanelPage(
      title: approvals ? 'Product approvals' : (isSeller ? 'My products' : 'Products'),
      subtitle: approvals
          ? 'Seller submissions waiting for review'
          : isSeller
              ? 'New products and edits are reviewed by Go4Market before going live'
              : 'Every product across modules and sellers',
      actions: [
        if (!approvals) OutlinedButton.icon(onPressed: () => context.go('/catalog/bulk'), icon: const Icon(Icons.upload_file_rounded, size: 18), label: Text(tr('Bulk upload'))),
        if (!approvals) FilledButton.icon(onPressed: () => context.go('/catalog/products/new'), icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('Add product'))),
      ],
      child: StreamBuilder<List<Doc>>(
        stream: _cats,
        builder: (context, cs) {
          final byId = {for (final c in cs.data ?? const <Doc>[]) c.id: c};
          final catOpts = <String, String>{
            for (final c in (cs.data ?? const <Doc>[]).where((c) => c.i('depth') <= 1).toList()..sort((a, b) => categoryLabel(a.id, byId).compareTo(categoryLabel(b.id, byId))))
              c.id: categoryLabel(c.id, byId),
          };
          return StreamBuilder<Map<String, String>>(
            stream: _sellers,
            builder: (context, ss) {
              final sellers = ss.data ?? const {};
              return DataView<Doc>(
                id: approvals ? 'product_approvals' : 'products',
                csvName: 'products',
                source: (q) => scopedProducts(limit: q.limit, status: approvals ? 'pending' : null),
                rowId: (d) => d.id,
                searchText: (d) => '${d.s('name')} ${d.s('brandName')} ${d.s('sellerName')} ${d.s('barcode')} ${d.s('sku')} ${d.list('tags').join(' ')}',
                defaultSort: null,
                filters: [
                  if (!approvals)
                    TableFilter<Doc>('status', 'Status', const {'active': 'Active', 'pending': 'Pending', 'rejected': 'Rejected', 'draft': 'Draft'},
                        test: (d, v) => d.s('status', 'active') == v),
                  TableFilter<Doc>('module', 'Module', moduleOptionsLocal, initial: session.moduleId, test: (d, v) => d.s('moduleId', 'ecommerce') == v),
                  if (catOpts.isNotEmpty) TableFilter<Doc>('category', 'Category', catOpts, test: (d, v) => d.list('categoryPath').contains(v) || d.s('categoryId') == v),
                  TableFilter<Doc>('stock', 'Stock', const {'in': 'In stock', 'low': 'Low stock', 'out': 'Out of stock'}, test: (d, v) => stockState(d) == v),
                  if (!isSeller) TableFilter<Doc>('featured', 'Featured', const {'yes': 'Featured', 'no': 'Not featured'}, test: (d, v) => d.b('featured') == (v == 'yes')),
                  if (!isSeller && sellers.isNotEmpty) TableFilter<Doc>('seller', 'Seller', sellers, test: (d, v) => d.s('sellerId') == v),
                ],
                leading: (ctx, d) => RowThumb(d.list('images').isEmpty ? '' : d.list('images').first),
                columns: [
                  Col<Doc>('Product', flex: 5, text: (d) => d.s('name'), cell: (ctx, d) => TwoLine(d.s('name'), [d.s('brandName'), if (d.s('unit').isNotEmpty) d.s('unit')].where((e) => e.isNotEmpty).join(' · '),
                      d['isVeg'] is bool ? VegMark(isVeg: d.b('isVeg'), size: 12) : null)),
                  Col<Doc>('Category', flex: 3, text: (d) => byId[d.s('categoryId')]?.s('name') ?? '—'),
                  if (!isSeller) Col<Doc>('Seller', flex: 3, text: (d) => d.s('sellerName', sellers[d.s('sellerId')] ?? '—')),
                  Col<Doc>('Price', flex: 2, numeric: true, sort: (d) => d.n('price'), text: (d) => Fmt.money(d.n('price')),
                      cell: (ctx, d) => Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                            Text(Fmt.money(d.n('price')), style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (d.n('mrp') > d.n('price'))
                              Text(Fmt.money(d.n('mrp')), style: TextStyle(fontSize: 11.5, color: ctx.pal.muted, decoration: TextDecoration.lineThrough)),
                          ])),
                  Col<Doc>('Stock', flex: 2, numeric: true, sort: (d) => effectiveStock(d), text: (d) => '${effectiveStock(d)}', cell: (ctx, d) {
                    final st = stockState(d);
                    return Tag(st == 'out' ? 'Out' : '${effectiveStock(d)}${d.list('variants').isNotEmpty ? ' (var)' : ''}', color: stockColor(st));
                  }),
                  Col<Doc>('Rating', flex: 2, sort: (d) => d.n('rating'), text: (d) => d.n('rating').toStringAsFixed(1),
                      cell: (ctx, d) => d.i('ratingCount') == 0
                          ? Text('—', style: TextStyle(color: ctx.pal.faint))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A524)),
                              Text(' ${d.n('rating').toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(' (${d.i('ratingCount')})', style: TextStyle(fontSize: 12, color: ctx.pal.muted)),
                            ])),
                  Col<Doc>('Status', flex: 2, text: (d) => d.s('status', 'active'), cell: (ctx, d) => Tooltip(message: d.s('rejectReason'), child: statusPill(d.s('status', 'active')))),
                  if (!isSeller && !approvals)
                    Col<Doc>('Featured', flex: 1, text: (d) => d.b('featured') ? 'Yes' : 'No', cell: (ctx, d) => Transform.scale(
                          scale: .8,
                          alignment: AlignmentDirectional.centerStart,
                          child: Switch(value: d.b('featured'), onChanged: (v) => runToast(() => d.ref!.update({'featured': v, 'updatedAt': FieldValue.serverTimestamp()}))),
                        )),
                  if (approvals) Col<Doc>('Submitted', flex: 2, text: (d) => Fmt.ago(d.dt('updatedAt') ?? d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
                ],
                card: (ctx, d) => _ProductCard(d: d, category: byId[d.s('categoryId')]?.s('name') ?? ''),
                cardMinWidth: 230,
                onTap: (d) => context.go('/catalog/products/${d.id}/edit'),
                actions: [
                  RowAction('Edit', Icons.edit_outlined, (d) => context.go('/catalog/products/${d.id}/edit')),
                  if (!isSeller) RowAction('Approve', Icons.check_circle_outline_rounded, (d) => runToast(() => _setStatus([d], 'active'), success: 'Approved'), visible: (d) => d.s('status') != 'active'),
                  if (!isSeller) RowAction('Reject', Icons.block_rounded, (d) => _reject(context, [d]), visible: (d) => d.s('status') == 'pending'),
                  RowAction('Duplicate', Icons.copy_all_outlined, _duplicate),
                  if (!isSeller)
                    RowAction('Toggle featured', Icons.star_outline_rounded,
                        (d) => runToast(() => d.ref!.update({'featured': !d.b('featured')}), success: d.b('featured') ? 'Removed from featured' : 'Marked featured')),
                  RowAction('Move to draft', Icons.drafts_outlined, (d) => runToast(() => _setStatus([d], 'draft'), success: 'Moved to draft'),
                      visible: (d) => d.s('status') != 'draft' && !isSeller),
                  RowAction('Delete', Icons.delete_outline_rounded, (d) async {
                    if (await confirm(context, 'Delete "${d.s('name')}"?', message: 'The product is removed from the store permanently.', danger: true, confirmLabel: 'Delete')) {
                      await runToast(() => d.ref!.delete(), success: 'Product deleted');
                    }
                  }, danger: true),
                ],
                bulkActions: [
                  if (approvals || !isSeller) BulkAction('Approve', Icons.check_circle_outline_rounded, (rows) => _setStatus(rows, 'active')),
                  if (approvals) BulkAction('Reject', Icons.block_rounded, (rows) => _reject(context, rows)),
                  if (!approvals && !isSeller) ...[
                    BulkAction('Move to draft', Icons.drafts_outlined, (rows) => _setStatus(rows, 'draft')),
                    BulkAction('Feature', Icons.star_outline_rounded, (rows) async {
                      final b = ChunkedBatch();
                      for (final d in rows) {
                        b.update(d.ref!, {'featured': true});
                      }
                      await b.commit();
                    }),
                  ],
                  BulkAction('Delete', Icons.delete_outline_rounded, (rows) async {
                    final b = ChunkedBatch();
                    for (final d in rows) {
                      b.delete(d.ref!);
                    }
                    await b.commit();
                  }, danger: true),
                ],
                emptyIcon: approvals ? Icons.fact_check_outlined : Icons.inventory_2_outlined,
                emptyTitle: approvals ? 'No pending products' : 'No products yet',
                emptyMessage: approvals ? 'Seller submissions will appear here for review.' : 'Add your first product or import a CSV.',
                emptyAction: approvals ? null : FilledButton.icon(onPressed: () => context.go('/catalog/products/new'), icon: const Icon(Icons.add_rounded), label: Text(tr('Add product'))),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.d, required this.category});
  final Doc d;
  final String category;
  @override
  Widget build(BuildContext context) {
    final img = d.list('images').isEmpty ? '' : d.list('images').first;
    final st = stockState(d);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 1.25,
        child: Stack(fit: StackFit.expand, children: [
          Container(color: context.pal.surfaceAlt, child: img.isEmpty ? Icon(Icons.image_outlined, color: context.pal.faint, size: 40) : NetImage(img, fit: BoxFit.cover)),
          PositionedDirectional(start: 8, top: 8, child: statusPill(d.s('status', 'active'))),
          if (d.b('featured')) const PositionedDirectional(start: 8, bottom: 8, child: Tag('Featured', color: G4MColors.accent, icon: Icons.star_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.s('name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text([category, d.s('sellerName')].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: context.pal.muted)),
          const SizedBox(height: 8),
          Row(children: [
            Text(Fmt.money(d.n('price')), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            if (d.n('mrp') > d.n('price')) ...[
              const SizedBox(width: 6),
              Text(Fmt.money(d.n('mrp')), style: TextStyle(fontSize: 12, color: context.pal.muted, decoration: TextDecoration.lineThrough)),
            ],
            const Spacer(),
            Tag(st == 'out' ? 'Out of stock' : '${effectiveStock(d)} in stock', color: stockColor(st)),
          ]),
        ]),
      ),
    ]);
  }
}

/// Re-exported for other screens that need a live product list.
Stream<List<Doc>> productsStream({int limit = 300}) => scopedProducts(limit: limit);

/// Live single product.
Stream<Doc?> productDoc(String id) => liveDoc(Fs.products.doc(id));
