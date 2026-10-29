import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import '../shared/a_common.dart';
import 'package:panel/l10n/overrides.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) => _Dashboard(key: ValueKey(session.moduleId), moduleId: session.moduleId),
      );
}

/// Aggregated numbers for a period (from stats/daily_* or, as a fallback, raw orders).
class _Period {
  _Period();
  final revenue = <(String, double)>[];
  final orders = <(String, double)>[];
  double rev = 0, ord = 0, prevRev = 0, prevOrd = 0, delivered = 0, cancelled = 0, prevDelivered = 0, newUsers = 0, prevNewUsers = 0;
  final byChannel = <String, double>{};
  final byCategory = <String, double>{};
  final byStatus = <String, double>{};
  bool fromStats = true;

  double pct(double cur, double prev) => prev <= 0 ? (cur > 0 ? 100 : 0) : (cur - prev) / prev * 100;
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({super.key, this.moduleId});
  final String? moduleId;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  String _period = '7d';
  bool _revenueMode = true;
  bool _line = false;
  late Future<_Period> _data = _load();

  // Chart labels (weekday / month names) are formatted at load time: reload on a language switch.
  void _onLang() {
    if (mounted) setState(() => _data = _load());
  }

  @override
  void initState() {
    super.initState();
    L10n.instance.addListener(_onLang);
  }

  @override
  void dispose() {
    L10n.instance.removeListener(_onLang);
    super.dispose();
  }
  late final Future<Map<String, int>> _counts = _loadCounts();
  late final Future<Map<String, String>> _catNames = _loadCategoryNames();

  int get _days => switch (_period) { '30d' => 30, '12m' => 365, _ => 7 };

  Future<Map<String, String>> _loadCategoryNames() async {
    try {
      final s = await Fs.categories.get();
      return {for (final d in s.docs) d.id: '${d.data()['name'] ?? d.id}'};
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, int>> _loadCounts() async {
    Future<int> c(Query<Json> q) async {
      try {
        return (await q.count().get()).count ?? 0;
      } catch (_) {
        return -1;
      }
    }

    Query<Json> prod = Fs.products;
    if (widget.moduleId != null) prod = prod.where('moduleId', isEqualTo: widget.moduleId);
    final r = await Future.wait([
      c(prod),
      c(Fs.sellers.where('status', isEqualTo: 'approved')),
      c(widget.moduleId == null ? Fs.categories : Fs.categories.where('moduleId', isEqualTo: widget.moduleId)),
      c(Fs.brands),
      c(prod.where('stock', isEqualTo: 0)),
      c(prod.where('stock', isGreaterThan: 0).where('stock', isLessThanOrEqualTo: 5)),
      c(Fs.users.where('role', isEqualTo: 'customer')),
      c(Fs.deliveryPartners.where('online', isEqualTo: true)),
    ]);
    return {
      'products': r[0],
      'sellers': r[1],
      'categories': r[2],
      'brands': r[3],
      'out': r[4],
      'low': r[5],
      'customers': r[6],
      'online': r[7],
    };
  }

  Future<_Period> _load() async {
    final p = _Period();
    final today = dayStart(DateTime.now());
    final days = _days;
    final start = today.subtract(Duration(days: days - 1));
    final prevStart = start.subtract(Duration(days: days));
    final ids = [for (var d = prevStart; !d.isAfter(today); d = d.add(const Duration(days: 1))) dayId(d)];

    // stats/daily_* by id, 30 per whereIn.
    final docs = <String, Map<String, dynamic>>{};
    try {
      final chunks = <Future<QuerySnapshot<Json>>>[];
      for (var i = 0; i < ids.length; i += 30) {
        chunks.add(Fs.stats.where(FieldPath.documentId, whereIn: ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30)).get());
      }
      for (final s in await Future.wait(chunks)) {
        for (final d in s.docs) {
          docs[d.id] = d.data();
        }
      }
    } catch (_) {}

    final mod = widget.moduleId;
    double revOf(Map<String, dynamic> m) {
      if (mod != null && m['byModule'] is Map) {
        final v = (m['byModule'] as Map)[mod];
        if (v is Map) return toNum(v['revenue']);
        return toNum(v);
      }
      return toNum(m['revenue']);
    }

    double ordOf(Map<String, dynamic> m) {
      if (mod != null && m['byModule'] is Map) {
        final v = (m['byModule'] as Map)[mod];
        if (v is Map) return toNum(v['orders']);
      }
      return toNum(m['orders']);
    }

    if (docs.isNotEmpty) {
      final daily = <DateTime, (double, double)>{};
      for (var d = prevStart; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
        final m = docs[dayId(d)];
        if (m == null) continue;
        final cur = !d.isBefore(start);
        final r = revOf(m), o = ordOf(m);
        if (cur) {
          daily[d] = (r, o);
          p.rev += r;
          p.ord += o;
          p.delivered += toNum(m['delivered']);
          p.cancelled += toNum(m['cancelled']);
          p.newUsers += toNum(m['newUsers']);
          (m['byChannel'] as Map?)?.forEach((k, v) => p.byChannel['$k'] = (p.byChannel['$k'] ?? 0) + toNum(v));
          (m['byCategory'] as Map?)?.forEach((k, v) => p.byCategory['$k'] = (p.byCategory['$k'] ?? 0) + toNum(v is Map ? v['revenue'] : v));
        } else {
          p.prevRev += r;
          p.prevOrd += o;
          p.prevDelivered += toNum(m['delivered']);
          p.prevNewUsers += toNum(m['newUsers']);
        }
      }
      _bucket(p, start, today, (d) => daily[d]);
      return p;
    }

    // Fallback: aggregate raw orders.
    p.fromStats = false;
    final orders = await ordersInRange(prevStart, today.add(const Duration(days: 1)), limit: 5000);
    final daily = <DateTime, (double, double)>{};
    for (final o in orders) {
      final c = o.createdAt;
      if (c == null) continue;
      final d = dayStart(c);
      final cur = !d.isBefore(start);
      final sale = countsAsSale(o);
      if (cur) {
        p.byStatus[o.status] = (p.byStatus[o.status] ?? 0) + 1;
        if (o.status == OrderStatus.cancelled) p.cancelled++;
        if (o.status == OrderStatus.delivered) p.delivered++;
        if (!sale) continue;
        final prev = daily[d] ?? (0, 0);
        daily[d] = (prev.$1 + o.total, prev.$2 + 1);
        p.rev += o.total;
        p.ord += 1;
        p.byChannel[o.channel] = (p.byChannel[o.channel] ?? 0) + 1;
      } else if (sale) {
        p.prevRev += o.total;
        p.prevOrd += 1;
        if (o.status == OrderStatus.delivered) p.prevDelivered++;
      }
    }
    _bucket(p, start, today, (d) => daily[d]);
    return p;
  }

  void _bucket(_Period p, DateTime start, DateTime today, (double, double)? Function(DateTime) at) {
    if (_period == '12m') {
      final months = <String, (double, double)>{};
      final order = <String>[];
      for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
        final k = DateFormat('MMM yy').format(d);
        if (!months.containsKey(k)) order.add(k);
        final v = at(d) ?? (0, 0);
        final m = months[k] ?? (0, 0);
        months[k] = (m.$1 + v.$1, m.$2 + v.$2);
      }
      for (final k in order) {
        p.revenue.add((k, months[k]!.$1));
        p.orders.add((k, months[k]!.$2));
      }
    } else {
      final f = DateFormat(_period == '7d' ? 'EEE' : 'd MMM');
      for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
        final v = at(d) ?? (0, 0);
        p.revenue.add((f.format(d), v.$1));
        p.orders.add((f.format(d), v.$2));
      }
    }
  }

  void _setPeriod(String v) => setState(() {
        _period = v;
        _data = _load();
      });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1200;
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return PanelPage(
      title: '${tr(greet)}, ${session.displayName.split(' ').first}',
      subtitle: '${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}${widget.moduleId != null ? ' · ${tr(Fmt.titleCase(widget.moduleId!))}' : ' · ${S.allModules}'}',
      actions: [
        Segmented<String>(value: _period, options: const {'7d': '7 days', '30d': '30 days', '12m': '12 months'}, onChanged: _setPeriod),
        OutlinedButton.icon(onPressed: () => context.go('/orders'), icon: const Icon(Icons.receipt_long_rounded, size: 18), label: Text(tr('View orders'))),
        FilledButton.icon(onPressed: () => context.go('/catalog/products/new'), icon: const Icon(Icons.add_rounded, size: 18), label: Text(tr('Add product'))),
      ],
      child: StreamBuilder<Doc?>(
        stream: liveDoc(Fs.statsOverview).handleError((_) {}),
        builder: (context, ov) {
          final overview = ov.data;
          return FutureBuilder<_Period>(
            future: _data,
            builder: (context, snap) {
              final p = snap.data;
              final loading = !snap.hasData && !snap.hasError;
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (snap.hasError) ...[SectionCard(child: ErrorBox(snap.error!, onRetry: () => _setPeriod(_period))), const SizedBox(height: 16)],
                _kpis(context, p, overview, loading),
                const SizedBox(height: 18),
                _row(wide, [
                  (3, _salesCard(context, p, loading)),
                  (2, _statusCard(context, p, overview, loading)),
                ]),
                const SizedBox(height: 18),
                _row(wide, [
                  (1, _topCategoriesCard(context, p, loading)),
                  (1, _channelCard(context, p, loading)),
                  (1, _inventoryCard(context)),
                ]),
                const SizedBox(height: 18),
                _row(wide, [
                  (1, _TopProducts(moduleId: widget.moduleId, field: 'soldCount', title: 'Top selling products', icon: Icons.local_fire_department_rounded)),
                  (1, _TopProducts(moduleId: widget.moduleId, field: 'rating', title: 'Top rated products', icon: Icons.star_rounded)),
                  (1, const _TopSellers()),
                ]),
                const SizedBox(height: 18),
                const _RecentOrders(),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _row(bool wide, List<(int, Widget)> children) {
    if (!wide) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 18), children[i].$2],
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 18), Expanded(flex: children[i].$1, child: children[i].$2)],
      ]);
  }

  Widget _kpis(BuildContext context, _Period? p, Doc? ov, bool loading) => FutureBuilder<Map<String, int>>(future: _counts, builder: (context, cs) => _kpiGrid(context, p, ov, loading, cs.data));

  Widget _kpiGrid(BuildContext context, _Period? p, Doc? ov, bool loading, Map<String, int>? counts) {
    String v(String Function() f) => loading || p == null ? '—' : f();
    final aov = p == null || p.ord == 0 ? 0.0 : p.rev / p.ord;
    final prevAov = p == null || p.prevOrd == 0 ? 0.0 : p.prevRev / p.prevOrd;
    final pending = ov?.n('pending', ov.n('byStatus.placed'));
    final trend = _period != '12m' && p != null;
    final cards = [
      KpiCard(label: 'Revenue', value: v(() => Fmt.money(p!.rev)), icon: Icons.currency_rupee_rounded, trend: trend ? p.pct(p.rev, p.prevRev) : null, onTap: () => context.go('/reports/sales')),
      KpiCard(label: 'Orders', value: v(() => Fmt.number(p!.ord)), icon: Icons.shopping_bag_rounded, color: G4MColors.info, trend: trend ? p.pct(p.ord, p.prevOrd) : null, onTap: () => context.go('/orders')),
      KpiCard(label: 'Avg. order value', value: v(() => Fmt.money(aov.roundToDouble())), icon: Icons.analytics_rounded, color: const Color(0xFF7C3AED), trend: trend ? p.pct(aov, prevAov) : null),
      KpiCard(
        label: 'Customers',
        value: ov != null && ov['customers'] != null ? Fmt.number(ov.n('customers')) : (counts == null ? '—' : (counts['customers']! < 0 ? 'n/a' : Fmt.number(counts['customers']!))),
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF0891B2),
        caption: p != null && p.newUsers > 0 ? '+${p.newUsers.toInt()} new this period' : null,
        onTap: () => context.go('/customers'),
      ),
      KpiCard(label: 'Pending orders', value: pending == null ? v(() => Fmt.number(p!.byStatus[OrderStatus.placed] ?? 0)) : Fmt.number(pending), icon: Icons.pending_actions_rounded, color: G4MColors.warning, onTap: () => context.go('/orders')),
      KpiCard(label: 'Delivered', value: v(() => Fmt.number(p!.delivered)), icon: Icons.task_alt_rounded, color: G4MColors.success, trend: trend ? p.pct(p.delivered, p.prevDelivered) : null),
    ];
    return ResponsiveGrid(minItemWidth: 190, spacing: 14, children: [
      for (var i = 0; i < cards.length; i++) cards[i].animate(delay: (45 * i).ms).fadeIn(duration: 300.ms).slideY(begin: .1, curve: Curves.easeOutCubic),
    ]);
  }

  Widget _salesCard(BuildContext context, _Period? p, bool loading) => SectionCard(
        title: 'Sales overview',
        subtitle: p == null ? null : (p.fromStats ? 'From daily stats' : 'Computed from orders (stats not yet available)'),
        icon: Icons.insights_rounded,
        trailing: Wrap(spacing: 8, children: [
          Segmented<bool>(value: _revenueMode, options: const {true: 'Revenue', false: 'Orders'}, onChanged: (v) => setState(() => _revenueMode = v)),
          IconButton(
            tooltip: _line ? 'Bar chart' : 'Line chart',
            onPressed: () => setState(() => _line = !_line),
            icon: Icon(_line ? Icons.bar_chart_rounded : Icons.show_chart_rounded, size: 20),
          ),
        ]),
        child: loading || p == null
            ? const SizedBox(height: 260, child: Center(child: Shimmer(height: 220)))
            : SeriesChart(points: _revenueMode ? p.revenue : p.orders, money: _revenueMode, line: _line),
      );

  Widget _statusCard(BuildContext context, _Period? p, Doc? ov, bool loading) {
    final src = <String, double>{};
    final bs = ov?['byStatus'];
    if (bs is Map && bs.isNotEmpty) {
      bs.forEach((k, v) => src['$k'] = toNum(v));
    } else if (p != null) {
      src.addAll(p.byStatus);
    }
    final slices = [
      for (final e in src.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) (OrderStatus.label(e.key), e.value, orderStatusColor(e.key)),
    ];
    return SectionCard(
      title: 'Order status',
      subtitle: bs is Map && bs.isNotEmpty ? 'All time' : 'Selected period',
      icon: Icons.donut_large_rounded,
      child: loading && slices.isEmpty ? const SizedBox(height: 200, child: Center(child: Shimmer(width: 180, height: 180, radius: 90))) : DonutChart(slices: slices, centerLabel: 'Orders'),
    );
  }

  Widget _topCategoriesCard(BuildContext context, _Period? p, bool loading) => SectionCard(
        title: 'Top categories',
        icon: Icons.category_rounded,
        child: FutureBuilder<Map<String, String>>(
          future: _catNames,
          builder: (context, names) {
            if (p != null && p.byCategory.isNotEmpty) {
              final rows = p.byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              return RankBars(money: true, rows: [for (final e in rows.take(6)) (names.data?[e.key] ?? Fmt.titleCase(e.key), e.value, null)]);
            }
            // Fallback: categories by product count.
            Query<Json> q = Fs.categories.where('parentId', isNull: true);
            if (widget.moduleId != null) q = q.where('moduleId', isEqualTo: widget.moduleId);
            return FutureBuilder<List<Doc>>(
              future: fetchDocs(q.limit(50)),
              builder: (context, s) {
                if (!s.hasData) return const LoadingBlock(rows: 4);
                final l = s.data!..sort((a, b) => b.n('productCount').compareTo(a.n('productCount')));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('By number of products', style: TextStyle(fontSize: 12, color: context.pal.muted)),
                  const SizedBox(height: 6),
                  RankBars(rows: [for (final d in l.take(6)) (d.s('name'), d.n('productCount'), null)]),
                ]);
              },
            );
          },
        ),
      );

  Widget _channelCard(BuildContext context, _Period? p, bool loading) {
    final ch = p?.byChannel ?? const {};
    final colors = {'web': G4MColors.info, 'app': G4MColors.primary, 'pos': G4MColors.accent, 'android': G4MColors.primary, 'ios': const Color(0xFF111827)};
    return SectionCard(
      title: 'Customers by platform',
      subtitle: 'Orders per channel',
      icon: Icons.devices_rounded,
      child: loading
          ? const SizedBox(height: 180, child: Center(child: Shimmer(width: 160, height: 160, radius: 80)))
          : DonutChart(
              size: 160,
              centerLabel: 'Orders',
              slices: [for (final e in ch.entries) (e.key == 'pos' ? 'POS' : Fmt.titleCase(e.key), e.value, colors[e.key] ?? G4MColors.inkFaint)],
            ),
    );
  }

  Widget _inventoryCard(BuildContext context) => SectionCard(
        title: 'Catalog & inventory',
        icon: Icons.inventory_rounded,
        child: FutureBuilder<Map<String, int>>(
          future: _counts,
          builder: (context, s) {
            final c = s.data;
            Widget tile(String label, String key, IconData icon, Color color, String path) => Pressable(
                  onTap: () => context.go(path),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withValues(alpha: .07), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c == null ? '—' : (c[key]! < 0 ? 'n/a' : Fmt.number(c[key]!)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          Text(label, style: TextStyle(fontSize: 11.5, color: context.pal.muted, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                );
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              children: [
                tile('Products', 'products', Icons.inventory_2_rounded, G4MColors.primary, '/catalog/products'),
                tile('Sellers', 'sellers', Icons.storefront_rounded, G4MColors.info, '/sellers'),
                tile('Categories', 'categories', Icons.account_tree_rounded, const Color(0xFF7C3AED), '/catalog/categories'),
                tile('Brands', 'brands', Icons.workspace_premium_rounded, const Color(0xFF0891B2), '/catalog/brands'),
                tile('Sold out', 'out', Icons.remove_shopping_cart_rounded, G4MColors.danger, '/catalog/stock'),
                tile('Low stock', 'low', Icons.warning_amber_rounded, G4MColors.warning, '/catalog/stock'),
                tile('Riders online', 'online', Icons.two_wheeler_rounded, G4MColors.accent, '/live-map'),
                tile('Customers', 'customers', Icons.people_alt_rounded, G4MColors.primaryDeep, '/customers'),
              ],
            );
          },
        ),
      );
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.moduleId, required this.field, required this.title, required this.icon});
  final String? moduleId;
  final String field;
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    Query<Json> base = Fs.products.where('status', isEqualTo: 'active');
    if (moduleId != null) base = base.where('moduleId', isEqualTo: moduleId);
    return SectionCard(
      title: title,
      icon: icon,
      trailing: TextButton(onPressed: () => context.go(field == 'rating' ? '/catalog/ratings' : '/reports/products'), child: Text(tr('See all'))),
      child: StreamBuilder<List<Doc>>(
        stream: liveDocs(base.orderBy(field, descending: true).limit(6), fallback: base.limit(60), sortField: field, label: 'products status+${moduleId != null ? 'moduleId+' : ''}$field'),
        builder: (context, s) {
          if (s.hasError) return ErrorBox(s.error!);
          if (!s.hasData) return const LoadingBlock(rows: 5);
          final l = s.data!.take(6).toList();
          if (l.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'No products yet');
          return Column(children: [
            for (var i = 0; i < l.length; i++)
              InkWell(
                onTap: () => context.go('/catalog/products/${l[i].id}/edit'),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    RowThumb(l[i].list('images').isEmpty ? '' : l[i].list('images').first, size: 40),
                    const SizedBox(width: 10),
                    Expanded(child: TwoLine(l[i].s('name'), l[i].s('sellerName', l[i].s('brandName')))),
                    const SizedBox(width: 8),
                    field == 'rating'
                        ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            RatingStars(l[i].n('rating'), size: 12),
                            Text('${l[i].i('ratingCount')} reviews', style: TextStyle(fontSize: 11, color: context.pal.muted)),
                          ])
                        : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${l[i].i('soldCount')} sold', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            Text(Fmt.money(l[i].n('price')), style: TextStyle(fontSize: 11.5, color: context.pal.muted)),
                          ]),
                  ]),
                ),
              ).animate(delay: (40 * i).ms).fadeIn(),
          ]);
        },
      ),
    );
  }
}

class _TopSellers extends StatelessWidget {
  const _TopSellers();
  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Highest revenue sellers',
        icon: Icons.emoji_events_rounded,
        trailing: TextButton(onPressed: () => context.go('/reports/sellers'), child: Text(tr('Report'))),
        child: StreamBuilder<List<Doc>>(
          stream: liveDocs(Fs.sellers.where('status', isEqualTo: 'approved').orderBy('totalSales', descending: true).limit(6),
              fallback: Fs.sellers.where('status', isEqualTo: 'approved').limit(60), sortField: 'totalSales', label: 'sellers status+totalSales'),
          builder: (context, s) {
            if (s.hasError) return ErrorBox(s.error!);
            if (!s.hasData) return const LoadingBlock(rows: 5);
            final l = s.data!.take(6).toList();
            if (l.isEmpty) return const EmptyState(icon: Icons.storefront_outlined, title: 'No approved sellers yet');
            return RankBars(
              money: true,
              rows: [for (final d in l) (d.s('storeName'), d.n('totalSales'), d.s('city').isEmpty ? null : d.s('city'))],
              onTap: (i) => context.go('/sellers/${l[i].id}'),
            );
          },
        ),
      );
}

class _RecentOrders extends StatelessWidget {
  const _RecentOrders();
  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Recent orders',
        icon: Icons.receipt_long_rounded,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        trailing: TextButton(onPressed: () => context.go('/orders'), child: Text(tr('All orders'))),
        child: StreamBuilder<List<ShopOrder>>(
          stream: liveQuery<ShopOrder>(Fs.orders.orderBy('createdAt', descending: true).limit(8), ShopOrder.fromDoc, label: 'orders createdAt'),
          builder: (context, s) {
            if (s.hasError) return ErrorBox(s.error!);
            if (!s.hasData) return const LoadingBlock(rows: 5);
            final l = s.data!;
            if (l.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet', message: 'Orders will stream in here live.');
            return Column(children: [
              for (var i = 0; i < l.length; i++)
                InkWell(
                  onTap: () => context.go('/orders/${l[i].id}'),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(children: [
                      Avatar(name: l[i].customerName, size: 36),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: TwoLine(l[i].orderNo, '${l[i].customerName} · ${Fmt.ago(l[i].createdAt)}')),
                      Expanded(flex: 2, child: Text('${l[i].itemCount} items · ${Fmt.titleCase(l[i].channel)}', style: TextStyle(color: context.pal.muted, fontSize: 12.5))),
                      orderStatusPill(l[i].status),
                      const SizedBox(width: 16),
                      SizedBox(width: 90, child: Text(Fmt.money(l[i].total), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
                    ]),
                  ),
                ).animate(delay: (30 * i).ms).fadeIn(),
            ]);
          },
        ),
      );
}
