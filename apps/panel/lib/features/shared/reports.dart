import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:intl/intl.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'a_common.dart';
import 'package:panel/l10n/overrides.dart';

/// Reports: sales | products | categories | sellers | commission | pos.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.kind});
  final String kind;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _Data {
  _Data(this.orders, this.extra);
  final List<ShopOrder> orders;
  final Map<String, dynamic> extra;
}

class _ReportsPageState extends State<ReportsPage> {
  DateTimeRange _range = DateRangeBar.preset('30d');
  bool _allStatuses = false;
  bool _line = true;
  late Future<_Data> _future = _load();

  @override
  void didUpdateWidget(covariant ReportsPage old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) _future = _load();
  }

  String get _title => switch (widget.kind) {
        'products' => 'Product sales report',
        'categories' => 'Category report',
        'sellers' => 'Seller report',
        'commission' => 'Commission report',
        'pos' => 'POS report',
        _ => 'Sales report',
      };

  String get _subtitle => switch (widget.kind) {
        'products' => 'Best and worst selling products, units and revenue.',
        'categories' => 'Revenue and units by top-level category.',
        'sellers' => 'Revenue, orders and units per seller.',
        'commission' => 'Platform commission earned per seller.',
        'pos' => 'In-store sales made through the point of sale.',
        _ => 'Revenue, orders and order value over time.',
      };

  Future<_Data> _load() async {
    final orders = await ordersInRange(_range.start, _range.end, sellerId: isSellerPanel ? session.uid : null);
    final extra = <String, dynamic>{};
    final kind = widget.kind;
    if (kind == 'products' || kind == 'categories') {
      try {
        final q = isSellerPanel ? Fs.products.where('sellerId', isEqualTo: session.uid) : Fs.products.where('status', isEqualTo: 'active');
        extra['products'] = await fetchDocs(q.limit(1500), label: 'products report');
      } catch (_) {
        extra['products'] = <Doc>[];
      }
    }
    if (kind == 'categories') {
      try {
        extra['categories'] = {for (final d in (await Fs.categories.get()).docs) d.id: '${d.data()['name'] ?? d.id}'};
      } catch (_) {
        extra['categories'] = <String, String>{};
      }
    }
    if (kind == 'sellers' || kind == 'commission') {
      try {
        extra['sellers'] = {for (final d in (await Fs.sellers.get()).docs) d.id: Doc.fromSnap(d)};
      } catch (_) {
        extra['sellers'] = <String, Doc>{};
      }
    }
    return _Data(orders, extra);
  }

  void _reload() => setState(() => _future = _load());

  List<ShopOrder> _filter(List<ShopOrder> l) {
    var out = l;
    if (!_allStatuses) out = out.where(countsAsSale).toList();
    if (widget.kind == 'pos') out = out.where((o) => o.channel == 'pos').toList();
    return out;
  }

  Iterable<OrderItem> _items(ShopOrder o) => isSellerPanel ? o.items.where((i) => i.sellerId == session.uid) : o.items;
  double _amount(ShopOrder o) => isSellerPanel ? sellerSubtotal(o, session.uid) : o.total;

  @override
  Widget build(BuildContext context) {
    return PanelPage(
      title: _title,
      subtitle: _subtitle,
      actions: [
        FilterChip(
          label: Text(tr('Include cancelled / unpaid')),
          selected: _allStatuses,
          onSelected: (v) => setState(() => _allStatuses = v),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DateRangeBar(range: _range, onChanged: (r) {
          _range = r;
          _reload();
        }),
        const SizedBox(height: 18),
        FutureBuilder<_Data>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return SectionCard(child: ErrorBox(snap.error!, onRetry: _reload));
            if (!snap.hasData) {
              return Column(children: [
                ResponsiveGrid(minItemWidth: 200, children: List.generate(4, (_) => const Shimmer(height: 120, radius: 16))),
                const SizedBox(height: 18),
                const Shimmer(height: 320, radius: 16),
              ]);
            }
            final d = snap.data!;
            final orders = _filter(d.orders);
            final body = switch (widget.kind) {
              'products' => _products(context, orders, d),
              'categories' => _categories(context, orders, d),
              'sellers' || 'commission' => _sellers(context, orders, d, commission: widget.kind == 'commission'),
              _ => _sales(context, orders),
            };
            return body.animate().fadeIn(duration: 280.ms).slideY(begin: .02);
          },
        ),
      ]),
    );
  }

  String get _rangeKey => '${widget.kind}_${_range.start.millisecondsSinceEpoch}_${_range.end.millisecondsSinceEpoch}_$_allStatuses';
  String get _csvBase => '${widget.kind}_report_${DateFormat('yyyyMMdd').format(_range.start)}-${DateFormat('yyyyMMdd').format(_range.end.subtract(const Duration(days: 1)))}';

  // ───── Sales / POS ─────

  Widget _sales(BuildContext context, List<ShopOrder> orders) {
    final days = _range.end.difference(_range.start).inDays;
    final monthly = days > 92;
    final buckets = <String, Map<String, double>>{};
    final keys = <String>[];
    final kf = DateFormat(monthly ? 'yyyy-MM' : 'yyyy-MM-dd');
    final lf = DateFormat(monthly ? 'MMM yy' : 'd MMM');
    for (var dd = _range.start; dd.isBefore(_range.end); dd = dd.add(const Duration(days: 1))) {
      final k = kf.format(dd);
      if (!buckets.containsKey(k)) {
        keys.add(k);
        buckets[k] = {'orders': 0, 'items': 0, 'gross': 0, 'discount': 0, 'delivery': 0, 'tax': 0, 'net': 0};
      }
    }
    final byMethod = <String, double>{};
    final byChannel = <String, double>{};
    double gross = 0, disc = 0, deliv = 0, tax = 0, items = 0;
    for (final o in orders) {
      final b = buckets[kf.format(o.createdAt ?? _range.start)];
      final amt = _amount(o);
      final it = _items(o).fold<int>(0, (a, i) => a + i.qty).toDouble();
      gross += amt;
      items += it;
      disc += isSellerPanel ? 0 : o.discount;
      deliv += isSellerPanel ? 0 : o.deliveryFee;
      tax += isSellerPanel ? 0 : o.tax;
      byMethod[o.paymentMethod] = (byMethod[o.paymentMethod] ?? 0) + amt;
      byChannel[o.channel] = (byChannel[o.channel] ?? 0) + 1;
      if (b != null) {
        b['orders'] = b['orders']! + 1;
        b['items'] = b['items']! + it;
        b['gross'] = b['gross']! + amt;
        b['discount'] = b['discount']! + (isSellerPanel ? 0 : o.discount);
        b['delivery'] = b['delivery']! + (isSellerPanel ? 0 : o.deliveryFee);
        b['tax'] = b['tax']! + (isSellerPanel ? 0 : o.tax);
        b['net'] = b['net']! + (isSellerPanel ? amt : o.subtotal - o.discount);
      }
    }
    final aov = orders.isEmpty ? 0.0 : gross / orders.length;
    final points = [for (final k in keys) (lf.format(DateTime.parse(monthly ? '$k-01' : k)), buckets[k]!['gross']!)];
    final rows = [
      for (final k in keys.reversed)
        if (buckets[k]!['orders']! > 0 || days <= 31) Doc(k, {'period': lf.format(DateTime.parse(monthly ? '$k-01' : k)), 'sortKey': k, ...buckets[k]!}),
    ];
    final wide = MediaQuery.sizeOf(context).width > 1100;
    final methodColors = {'cod': G4MColors.accent, 'cash': G4MColors.accent, 'razorpay': G4MColors.info, 'card': G4MColors.info, 'upi': const Color(0xFF7C3AED), 'stripe': const Color(0xFF635BFF), 'paypal': const Color(0xFF003087), 'wallet': G4MColors.primary};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ResponsiveGrid(minItemWidth: 190, spacing: 14, children: [
        KpiCard(label: widget.kind == 'pos' ? 'POS revenue' : 'Gross revenue', value: Fmt.money(gross), icon: Icons.currency_rupee_rounded),
        KpiCard(label: 'Orders', value: Fmt.number(orders.length), icon: Icons.shopping_bag_rounded, color: G4MColors.info),
        KpiCard(label: 'Avg. order value', value: Fmt.money(aov.roundToDouble()), icon: Icons.analytics_rounded, color: const Color(0xFF7C3AED)),
        KpiCard(label: 'Items sold', value: Fmt.number(items), icon: Icons.inventory_2_rounded, color: const Color(0xFF0891B2)),
        if (!isSellerPanel) KpiCard(label: 'Discounts given', value: Fmt.money(disc), icon: Icons.discount_rounded, color: G4MColors.accent),
        if (!isSellerPanel && widget.kind != 'pos') KpiCard(label: 'Delivery fees', value: Fmt.money(deliv), icon: Icons.local_shipping_rounded, color: G4MColors.success),
        if (!isSellerPanel) KpiCard(label: 'Tax collected', value: Fmt.money(tax), icon: Icons.account_balance_rounded, color: G4MColors.primaryDeep),
      ]),
      const SizedBox(height: 18),
      _twoUp(wide, [
        (
          3,
          SectionCard(
            title: 'Revenue ${monthly ? 'by month' : 'by day'}',
            icon: Icons.show_chart_rounded,
            trailing: IconButton(onPressed: () => setState(() => _line = !_line), icon: Icon(_line ? Icons.bar_chart_rounded : Icons.show_chart_rounded, size: 20)),
            child: SeriesChart(points: points, money: true, line: _line, height: 280),
          )
        ),
        (
          2,
          SectionCard(
            title: 'By payment method',
            icon: Icons.payments_rounded,
            child: Column(children: [
              DonutChart(money: true, slices: [for (final e in byMethod.entries) (Fmt.titleCase(e.key), e.value, methodColors[e.key] ?? G4MColors.inkFaint)]),
              if (widget.kind != 'pos' && byChannel.length > 1) ...[
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in byChannel.entries) Tag('${e.key == 'pos' ? 'POS' : Fmt.titleCase(e.key)}: ${e.value.toInt()} orders', color: G4MColors.info),
                ]),
              ],
            ]),
          )
        ),
      ]),
      const SizedBox(height: 18),
      DataView<Doc>(
        key: ValueKey('sales_$_rangeKey'),
        id: 'report_${widget.kind}',
        csvName: _csvBase,
        source: (_) => Stream.value(rows),
        rowId: (d) => d.id,
        defaultSort: 0,
        dense: true,
        columns: [
          Col('Period', flex: 2, text: (d) => d.s('period'), sort: (d) => d.s('sortKey'), csv: (d) => d.s('sortKey')),
          Col('Orders', flex: 1, numeric: true, text: (d) => Fmt.number(d.n('orders')), sort: (d) => d.n('orders'), csv: (d) => '${d.i('orders')}'),
          Col('Items', flex: 1, numeric: true, text: (d) => Fmt.number(d.n('items')), sort: (d) => d.n('items'), csv: (d) => '${d.i('items')}'),
          Col('Gross', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('gross')), sort: (d) => d.n('gross'), csv: (d) => d.n('gross').toStringAsFixed(2)),
          if (!isSellerPanel) ...[
            Col('Discount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('discount')), sort: (d) => d.n('discount'), csv: (d) => d.n('discount').toStringAsFixed(2)),
            Col('Delivery', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('delivery')), sort: (d) => d.n('delivery'), csv: (d) => d.n('delivery').toStringAsFixed(2)),
            Col('Tax', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('tax')), sort: (d) => d.n('tax'), csv: (d) => d.n('tax').toStringAsFixed(2)),
          ],
          Col('Net sales', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('net')), sort: (d) => d.n('net'), csv: (d) => d.n('net').toStringAsFixed(2)),
        ],
        emptyIcon: Icons.insights_rounded,
        emptyTitle: 'No sales in this period',
      ),
    ]);
  }

  // ───── Products ─────

  Widget _products(BuildContext context, List<ShopOrder> orders, _Data d) {
    final agg = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      for (final i in _items(o)) {
        final m = agg.putIfAbsent(i.productId, () => {'name': i.name, 'seller': i.sellerName, 'image': i.image, 'units': 0.0, 'revenue': 0.0, 'orders': <String>{}, 'variants': <String>{}});
        m['units'] = (m['units'] as double) + i.qty;
        m['revenue'] = (m['revenue'] as double) + i.lineTotal;
        (m['orders'] as Set<String>).add(o.id);
        if (i.variantName.isNotEmpty) (m['variants'] as Set<String>).add(i.variantName);
      }
    }
    final catalog = (d.extra['products'] as List<Doc>?) ?? const [];
    for (final p in catalog) {
      agg.putIfAbsent(p.id, () => {
            'name': p.s('name'),
            'seller': p.s('sellerName'),
            'image': p.list('images').isEmpty ? '' : p.list('images').first,
            'units': 0.0,
            'revenue': 0.0,
            'orders': <String>{},
            'variants': <String>{},
          });
      agg[p.id]!['stock'] = p.n('stock');
    }
    final rows = [
      for (final e in agg.entries)
        Doc(e.key, {
          ...e.value,
          'orders': (e.value['orders'] as Set).length,
          'variants': (e.value['variants'] as Set).join(', '),
        }),
    ];
    final best = [...rows]..sort((a, b) => b.n('units').compareTo(a.n('units')));
    final zero = rows.where((r) => r.n('units') == 0).length;
    final totalUnits = rows.fold<double>(0, (a, r) => a + r.n('units'));
    final totalRev = rows.fold<double>(0, (a, r) => a + r.n('revenue'));
    final wide = MediaQuery.sizeOf(context).width > 1100;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ResponsiveGrid(minItemWidth: 200, spacing: 14, children: [
        KpiCard(label: 'Products sold', value: Fmt.number(rows.where((r) => r.n('units') > 0).length), icon: Icons.inventory_2_rounded),
        KpiCard(label: 'Units sold', value: Fmt.number(totalUnits), icon: Icons.shopping_cart_rounded, color: G4MColors.info),
        KpiCard(label: 'Product revenue', value: Fmt.money(totalRev), icon: Icons.currency_rupee_rounded, color: const Color(0xFF7C3AED)),
        KpiCard(label: 'No sales in period', value: Fmt.number(zero), icon: Icons.trending_down_rounded, color: G4MColors.danger),
      ]),
      const SizedBox(height: 18),
      _twoUp(wide, [
        (
          1,
          SectionCard(
            title: 'Best sellers',
            icon: Icons.local_fire_department_rounded,
            child: RankBars(rows: [for (final r in best.where((r) => r.n('units') > 0).take(8)) (r.s('name'), r.n('units'), Fmt.money(r.n('revenue')))]),
          )
        ),
        (
          1,
          SectionCard(
            title: 'Worst sellers',
            subtitle: 'Lowest units sold (including products with no sales)',
            icon: Icons.trending_down_rounded,
            child: RankBars(
              color: G4MColors.danger,
              rows: [for (final r in best.reversed.take(8)) (r.s('name'), r.n('units'), r['stock'] == null ? null : 'stock ${r.i('stock')}')],
            ),
          )
        ),
      ]),
      const SizedBox(height: 18),
      DataView<Doc>(
        key: ValueKey('prod_$_rangeKey'),
        id: 'report_products',
        csvName: _csvBase,
        source: (_) => Stream.value(best),
        rowId: (r) => r.id,
        searchText: (r) => '${r.s('name')} ${r.s('seller')}',
        filters: [TableFilter('sales', 'Sales', const {'sold': 'With sales', 'none': 'No sales'}, test: (r, v) => v == 'sold' ? r.n('units') > 0 : r.n('units') == 0)],
        leading: (c, r) => RowThumb(r.s('image'), size: 38),
        columns: [
          Col('Product', flex: 4, text: (r) => r.s('name'), cell: (c, r) => TwoLine(r.s('name'), r.s('variants').isEmpty ? null : r.s('variants'))),
          if (!isSellerPanel) Col('Seller', flex: 2, text: (r) => r.s('seller')),
          Col('Units', flex: 1, numeric: true, text: (r) => Fmt.number(r.n('units')), sort: (r) => r.n('units'), csv: (r) => '${r.i('units')}'),
          Col('Orders', flex: 1, numeric: true, text: (r) => '${r.i('orders')}', sort: (r) => r.n('orders')),
          Col('Revenue', flex: 2, numeric: true, text: (r) => Fmt.money(r.n('revenue')), sort: (r) => r.n('revenue'), csv: (r) => r.n('revenue').toStringAsFixed(2)),
          Col('Stock', flex: 1, numeric: true, text: (r) => r['stock'] == null ? '—' : '${r.i('stock')}', sort: (r) => r.n('stock', -1)),
        ],
        emptyTitle: 'No product sales',
      ),
    ]);
  }

  // ───── Categories ─────

  Widget _categories(BuildContext context, List<ShopOrder> orders, _Data d) {
    final products = {for (final p in (d.extra['products'] as List<Doc>?) ?? const <Doc>[]) p.id: p};
    final names = (d.extra['categories'] as Map<String, String>?) ?? const {};
    return FutureBuilder<Map<String, Doc>>(
      future: () async {
        final missing = <String>{};
        for (final o in orders) {
          for (final i in _items(o)) {
            if (!products.containsKey(i.productId)) missing.add(i.productId);
          }
        }
        final extra = <String, Doc>{};
        if (missing.isNotEmpty) {
          try {
            for (final p in await CatalogRepo.instance.productsByIds(missing.toList())) {
              extra[p.id] = Doc(p.id, p.data);
            }
          } catch (_) {}
        }
        return {...products, ...extra};
      }(),
      builder: (context, snap) {
        if (!snap.hasData) return const SectionCard(child: LoadingBlock());
        final pmap = snap.data!;
        final agg = <String, Map<String, dynamic>>{};
        for (final o in orders) {
          for (final i in _items(o)) {
            final p = pmap[i.productId];
            final path = p?.list('categoryPath') ?? const <String>[];
            final cat = path.isNotEmpty ? path.first : (p?.s('categoryId') ?? '');
            final key = cat.isEmpty ? '_none' : cat;
            final m = agg.putIfAbsent(key, () => {'units': 0.0, 'revenue': 0.0, 'orders': <String>{}, 'products': <String>{}});
            m['units'] = (m['units'] as double) + i.qty;
            m['revenue'] = (m['revenue'] as double) + i.lineTotal;
            (m['orders'] as Set<String>).add(o.id);
            (m['products'] as Set<String>).add(i.productId);
          }
        }
        final rows = [
          for (final e in agg.entries)
            Doc(e.key, {
              'name': e.key == '_none' ? 'Uncategorised' : (names[e.key] ?? e.key),
              'units': e.value['units'],
              'revenue': e.value['revenue'],
              'orders': (e.value['orders'] as Set).length,
              'products': (e.value['products'] as Set).length,
            }),
        ]..sort((a, b) => b.n('revenue').compareTo(a.n('revenue')));
        final total = rows.fold<double>(0, (a, r) => a + r.n('revenue'));
        final wide = MediaQuery.sizeOf(context).width > 1100;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _twoUp(wide, [
            (
              2,
              SectionCard(
                title: 'Revenue share',
                icon: Icons.donut_large_rounded,
                child: DonutChart(money: true, size: 200, slices: [
                  for (var i = 0; i < rows.length && i < 8; i++) (rows[i].s('name'), rows[i].n('revenue'), chartPalette[i % chartPalette.length]),
                  if (rows.length > 8) ('Others', rows.skip(8).fold<double>(0, (a, r) => a + r.n('revenue')), G4MColors.inkFaint),
                ]),
              )
            ),
            (
              3,
              SectionCard(
                title: 'Top categories',
                icon: Icons.category_rounded,
                child: RankBars(money: true, rows: [for (final r in rows.take(8)) (r.s('name'), r.n('revenue'), '${r.i('units')} units')]),
              )
            ),
          ]),
          const SizedBox(height: 18),
          DataView<Doc>(
            key: ValueKey('cat_$_rangeKey'),
            id: 'report_categories',
            csvName: _csvBase,
            source: (_) => Stream.value(rows),
            rowId: (r) => r.id,
            searchText: (r) => r.s('name'),
            columns: [
              Col('Category', flex: 3, text: (r) => r.s('name')),
              Col('Products sold', flex: 1, numeric: true, text: (r) => '${r.i('products')}', sort: (r) => r.n('products')),
              Col('Units', flex: 1, numeric: true, text: (r) => Fmt.number(r.n('units')), sort: (r) => r.n('units'), csv: (r) => '${r.i('units')}'),
              Col('Orders', flex: 1, numeric: true, text: (r) => '${r.i('orders')}', sort: (r) => r.n('orders')),
              Col('Revenue', flex: 2, numeric: true, text: (r) => Fmt.money(r.n('revenue')), sort: (r) => r.n('revenue'), csv: (r) => r.n('revenue').toStringAsFixed(2)),
              Col('Share', flex: 1, numeric: true, text: (r) => total == 0 ? '0%' : '${(r.n('revenue') / total * 100).toStringAsFixed(1)}%', sort: (r) => r.n('revenue')),
            ],
            emptyTitle: 'No category sales in this period',
          ),
        ]);
      },
    );
  }

  // ───── Sellers / commission ─────

  Widget _sellers(BuildContext context, List<ShopOrder> orders, _Data d, {required bool commission}) {
    final sellers = (d.extra['sellers'] as Map<String, Doc>?) ?? const {};
    final agg = <String, Map<String, dynamic>>{};
    for (final o in orders) {
      for (final i in _items(o)) {
        final m = agg.putIfAbsent(i.sellerId, () => {'name': i.sellerName, 'units': 0.0, 'revenue': 0.0, 'orders': <String>{}});
        m['units'] = (m['units'] as double) + i.qty;
        m['revenue'] = (m['revenue'] as double) + i.lineTotal;
        (m['orders'] as Set<String>).add(o.id);
      }
    }
    final rows = <Doc>[];
    for (final e in agg.entries) {
      final s = sellers[e.key];
      final pct = s?.n('commissionPct', 10) ?? (isSellerPanel ? session.profile?.n('commissionPct', 10) ?? 10 : 10);
      final rev = e.value['revenue'] as double;
      rows.add(Doc(e.key, {
        'name': s?.s('storeName', '${e.value['name']}') ?? e.value['name'],
        'city': s?.s('city') ?? '',
        'units': e.value['units'],
        'revenue': rev,
        'orders': (e.value['orders'] as Set).length,
        'pct': pct,
        'commission': rev * pct / 100,
        'net': rev - rev * pct / 100,
      }));
    }
    rows.sort((a, b) => b.n('revenue').compareTo(a.n('revenue')));
    final totalRev = rows.fold<double>(0, (a, r) => a + r.n('revenue'));
    final totalCom = rows.fold<double>(0, (a, r) => a + r.n('commission'));
    final wide = MediaQuery.sizeOf(context).width > 1100;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ResponsiveGrid(minItemWidth: 200, spacing: 14, children: [
        KpiCard(label: 'Seller revenue', value: Fmt.money(totalRev), icon: Icons.currency_rupee_rounded),
        KpiCard(label: 'Platform commission', value: Fmt.money(totalCom), icon: Icons.percent_rounded, color: G4MColors.accent),
        KpiCard(label: 'Net to sellers', value: Fmt.money(totalRev - totalCom), icon: Icons.account_balance_wallet_rounded, color: G4MColors.success),
        KpiCard(label: 'Active sellers', value: Fmt.number(rows.length), icon: Icons.storefront_rounded, color: G4MColors.info),
      ]),
      const SizedBox(height: 18),
      _twoUp(wide, [
        (
          1,
          SectionCard(
            title: commission ? 'Commission by seller' : 'Revenue by seller',
            icon: Icons.leaderboard_rounded,
            child: RankBars(money: true, rows: [for (final r in rows.take(8)) (r.s('name'), r.n(commission ? 'commission' : 'revenue'), commission ? '${r.n('pct').toStringAsFixed(1)}%' : '${r.i('orders')} orders')]),
          )
        ),
        (
          1,
          SectionCard(
            title: 'Share of revenue',
            icon: Icons.pie_chart_rounded,
            child: DonutChart(money: true, slices: [
              for (var i = 0; i < rows.length && i < 7; i++) (rows[i].s('name'), rows[i].n('revenue'), chartPalette[i % chartPalette.length]),
              if (rows.length > 7) ('Others', rows.skip(7).fold<double>(0, (a, r) => a + r.n('revenue')), G4MColors.inkFaint),
            ]),
          )
        ),
      ]),
      const SizedBox(height: 18),
      DataView<Doc>(
        key: ValueKey('sel_$_rangeKey'),
        id: 'report_${widget.kind}',
        csvName: _csvBase,
        source: (_) => Stream.value(rows),
        rowId: (r) => r.id,
        searchText: (r) => '${r.s('name')} ${r.s('city')}',
        columns: [
          Col('Seller', flex: 3, text: (r) => r.s('name'), cell: (c, r) => TwoLine(r.s('name'), r.s('city'))),
          Col('Orders', flex: 1, numeric: true, text: (r) => '${r.i('orders')}', sort: (r) => r.n('orders')),
          Col('Units', flex: 1, numeric: true, text: (r) => Fmt.number(r.n('units')), sort: (r) => r.n('units'), csv: (r) => '${r.i('units')}'),
          Col('Revenue', flex: 2, numeric: true, text: (r) => Fmt.money(r.n('revenue')), sort: (r) => r.n('revenue'), csv: (r) => r.n('revenue').toStringAsFixed(2)),
          Col('Commission %', flex: 1, numeric: true, text: (r) => '${r.n('pct').toStringAsFixed(1)}%', sort: (r) => r.n('pct')),
          Col('Commission', flex: 2, numeric: true, text: (r) => Fmt.money(r.n('commission')), sort: (r) => r.n('commission'), csv: (r) => r.n('commission').toStringAsFixed(2)),
          Col('Net payable', flex: 2, numeric: true, text: (r) => Fmt.money(r.n('net')), sort: (r) => r.n('net'), csv: (r) => r.n('net').toStringAsFixed(2)),
        ],
        emptyTitle: 'No seller sales in this period',
      ),
    ]);
  }

  Widget _twoUp(bool wide, List<(int, Widget)> c) {
    if (!wide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(height: 18), c[i].$2],
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(width: 18), Expanded(flex: c[i].$1, child: c[i].$2)],
      ]);
  }
}
