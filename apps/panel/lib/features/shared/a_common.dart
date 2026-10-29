import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../ui/kit.dart';
import 'package:panel/l10n/overrides.dart';

// ───────────────────────── Orders helpers ─────────────────────────

const orderStatusOptions = {
  OrderStatus.pending: 'Awaiting payment',
  OrderStatus.placed: 'Placed',
  OrderStatus.confirmed: 'Confirmed',
  OrderStatus.packed: 'Packed',
  OrderStatus.assigned: 'Rider assigned',
  OrderStatus.pickedUp: 'Picked up',
  OrderStatus.outForDelivery: 'Out for delivery',
  OrderStatus.readyForPickup: 'Ready for pickup',
  OrderStatus.delivered: 'Delivered',
  OrderStatus.cancelled: 'Cancelled',
  OrderStatus.returned: 'Returned',
};

const paymentMethodOptions = {'cod': 'Cash on delivery', 'razorpay': 'Razorpay', 'stripe': 'Stripe', 'paypal': 'PayPal', 'wallet': 'Wallet', 'cash': 'Cash (POS)', 'card': 'Card (POS)', 'upi': 'UPI (POS)'};
const paymentStatusOptions = {'pending': 'Pending', 'paid': 'Paid', 'failed': 'Failed', 'refunded': 'Refunded'};
const speedOptions = {'standard': 'Standard', 'quick15': 'Quick 15 min', 'quick30': 'Quick 30 min', 'scheduled': 'Scheduled'};
const channelOptions = {'web': 'Website', 'app': 'App', 'pos': 'POS'};

Color orderStatusColor(String s) => switch (s) {
      OrderStatus.placed => G4MColors.info,
      OrderStatus.confirmed => const Color(0xFF0891B2),
      OrderStatus.packed => const Color(0xFF7C3AED),
      OrderStatus.readyForPickup => const Color(0xFF7C3AED),
      _ => statusColor(s),
    };

List<String> flowOf(ShopOrder o) => o.deliveryType == 'pickup' ? OrderStatus.pickupFlow : OrderStatus.homeFlow;

/// Next status in the order's flow (null when terminal).
String? nextStatusOf(ShopOrder o) {
  if (o.status == OrderStatus.pending) return OrderStatus.placed;
  final f = flowOf(o);
  final i = f.indexOf(o.status);
  if (i < 0 || i >= f.length - 1) return null;
  return f[i + 1];
}

bool canCancel(ShopOrder o) => !OrderStatus.terminal.contains(o.status);

/// Subtotal of only the signed-in seller's items (seller panel).
double sellerSubtotal(ShopOrder o, String sellerId) =>
    o.items.where((i) => i.sellerId == sellerId).fold(0.0, (a, i) => a + i.lineTotal);

String dayId(DateTime d) => 'daily_${DateFormat('yyyyMMdd').format(d)}';

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Orders between [from] and [to] (createdAt). Seller → own orders only.
Future<List<ShopOrder>> ordersInRange(DateTime from, DateTime to, {String? sellerId, int limit = 3000}) async {
  Query<Json> base = Fs.orders;
  if (sellerId != null) base = base.where('sellerIds', arrayContains: sellerId);
  final primary = base
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('createdAt', isLessThan: Timestamp.fromDate(to))
      .orderBy('createdAt', descending: true)
      .limit(limit);
  try {
    final s = await primary.get();
    return s.docs.map(ShopOrder.fromDoc).toList();
  } catch (e) {
    if (!isIndexError(e)) rethrow;
    IndexLog.instance.report('orders range${sellerId != null ? ' (seller)' : ''}', (e as FirebaseException).message);
    final s = await base.limit(limit).get();
    return s.docs.map(ShopOrder.fromDoc).where((o) {
      final c = o.createdAt;
      return c != null && !c.isBefore(from) && c.isBefore(to);
    }).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  }
}

/// Whether an order counts as revenue (not cancelled / awaiting payment / returned).
bool countsAsSale(ShopOrder o) => !{OrderStatus.cancelled, OrderStatus.pending, OrderStatus.returned}.contains(o.status);

/// Opens Google Maps directions.
String directionsUrl(double lat, double lng) => 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

String htmlEsc(Object? v) => '${v ?? ''}'.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

// ───────────────────────── Charts ─────────────────────────

const chartPalette = [
  Color(0xFF0B8A4F),
  Color(0xFFF7860F),
  Color(0xFF2563EB),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFF0891B2),
  Color(0xFF65A30D),
  Color(0xFFDC2626),
  Color(0xFF94A39A),
];

/// Bar or line chart of labelled values.
class SeriesChart extends StatelessWidget {
  const SeriesChart({super.key, required this.points, this.line = false, this.money = false, this.height = 260, this.color});
  final List<(String, double)> points;
  final bool line;
  final bool money;
  final double height;
  final Color? color;

  String _fmt(double v) => money ? Fmt.moneyCompact(v) : NumberFormat.compact().format(v);

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.accent;
    if (points.isEmpty) {
      return SizedBox(height: height, child: Center(child: Text('No data for this period', style: TextStyle(color: context.pal.muted))));
    }
    final maxV = points.map((p) => p.$2).fold<double>(0, math.max);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.18;
    final step = (points.length / 8).ceil().clamp(1, 1000);
    Widget bottom(double v, TitleMeta meta) {
      final i = v.round();
      if (i < 0 || i >= points.length || (i % step != 0 && i != points.length - 1)) return const SizedBox();
      return SideTitleWidget(meta: meta, child: Text(points[i].$1, style: TextStyle(fontSize: 10.5, color: context.pal.muted)));
    }

    Widget left(double v, TitleMeta meta) {
      if (v == meta.max) return const SizedBox();
      return SideTitleWidget(meta: meta, child: Text(_fmt(v), style: TextStyle(fontSize: 10.5, color: context.pal.muted)));
    }

    final titles = FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1, getTitlesWidget: bottom)),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48, getTitlesWidget: left)),
    );
    final grid = FlGridData(
      drawVerticalLine: false,
      horizontalInterval: maxY / 4,
      getDrawingHorizontalLine: (_) => FlLine(color: context.pal.line, strokeWidth: 1, dashArray: [4, 4]),
    );
    final chart = line
        ? LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: grid,
              titlesData: titles,
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => G4MColors.primaryDeep,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem('${points[s.x.toInt()].$1}\n${money ? Fmt.money(s.y) : Fmt.number(s.y)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].$2)],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: c,
                  barWidth: 3,
                  dotData: FlDotData(show: points.length <= 14),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.withValues(alpha: .28), c.withValues(alpha: 0)]),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          )
        : BarChart(
            BarChartData(
              maxY: maxY,
              gridData: grid,
              titlesData: titles,
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => G4MColors.primaryDeep,
                  getTooltipItem: (g, _, rod, _) => BarTooltipItem('${points[g.x].$1}\n${money ? Fmt.money(rod.toY) : Fmt.number(rod.toY)}',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: points[i].$2,
                      width: (220 / points.length).clamp(4, 26).toDouble(),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c.withValues(alpha: .65), c]),
                      backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: context.pal.surfaceAlt.withValues(alpha: .5)),
                    ),
                  ]),
              ],
            ),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
    // Charts keep a left-to-right time/number axis in every language (incl. Arabic RTL).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(height: height, child: Padding(padding: const EdgeInsets.only(top: 8, right: 8), child: chart)),
    );
  }
}

/// Donut with legend.
class DonutChart extends StatefulWidget {
  const DonutChart({super.key, required this.slices, this.size = 180, this.centerLabel, this.money = false});
  final List<(String, double, Color)> slices;
  final double size;
  final String? centerLabel;
  final bool money;
  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touched = -1;
  @override
  Widget build(BuildContext context) {
    final slices = widget.slices.where((s) => s.$2 > 0).toList();
    final total = slices.fold<double>(0, (a, s) => a + s.$2);
    if (slices.isEmpty) {
      return SizedBox(height: widget.size, child: Center(child: Text(tr('No data'), style: TextStyle(color: context.pal.muted))));
    }
    final donut = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: widget.size * .3,
            pieTouchData: PieTouchData(touchCallback: (e, r) {
              setState(() => _touched = (e.isInterestedForInteractions && r?.touchedSection != null) ? r!.touchedSection!.touchedSectionIndex : -1);
            }),
            sections: [
              for (var i = 0; i < slices.length; i++)
                PieChartSectionData(
                  value: slices[i].$2,
                  color: slices[i].$3,
                  radius: i == _touched ? widget.size * .2 + 6 : widget.size * .2,
                  showTitle: false,
                ),
            ],
          ),
          duration: const Duration(milliseconds: 300),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            _touched >= 0 && _touched < slices.length
                ? (widget.money ? Fmt.moneyCompact(slices[_touched].$2) : Fmt.number(slices[_touched].$2))
                : (widget.money ? Fmt.moneyCompact(total) : Fmt.number(total)),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Text(_touched >= 0 && _touched < slices.length ? tr(slices[_touched].$1) : tr(widget.centerLabel ?? 'Total'),
              style: TextStyle(fontSize: 11, color: context.pal.muted)),
        ]),
      ]),
    );
    final legend = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      for (final s in slices)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Flexible(child: Text(tr(s.$1), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            Text('${(s.$2 / total * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: context.pal.muted)),
          ]),
        ),
    ]);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < widget.size + 160) return Column(children: [donut, const SizedBox(height: 12), legend]);
      return Row(children: [donut, const SizedBox(width: 20), Expanded(child: legend)]);
    });
  }
}

/// Horizontal ranking bars (top categories / products…).
class RankBars extends StatelessWidget {
  const RankBars({super.key, required this.rows, this.money = false, this.color, this.onTap});
  final List<(String, double, String?)> rows; // label, value, subtitle
  final bool money;
  final Color? color;
  final void Function(int index)? onTap;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('No data yet', style: TextStyle(color: context.pal.muted))));
    final maxV = rows.map((r) => r.$2).fold<double>(0, math.max);
    return Column(children: [
      for (var i = 0; i < rows.length; i++)
        InkWell(
          onTap: onTap == null ? null : () => onTap!(i),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${i + 1}', style: TextStyle(color: context.pal.faint, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(width: 10),
                Expanded(child: Text(rows[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                if (rows[i].$3 != null) Text(rows[i].$3!, style: TextStyle(color: context.pal.muted, fontSize: 12)),
                const SizedBox(width: 10),
                Text(money ? Fmt.money(rows[i].$2) : Fmt.number(rows[i].$2), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: maxV <= 0 ? 0 : rows[i].$2 / maxV),
                  duration: Duration(milliseconds: 500 + i * 60),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: context.pal.surfaceAlt,
                    color: color ?? chartPalette[i % chartPalette.length],
                  ),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Small coloured order-status pill using order-status colours.
Widget orderStatusPill(String s) {
  final c = orderStatusColor(s);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(tr(OrderStatus.label(s)), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    ]),
  );
}

/// Date-range presets used by reports & dashboards.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({super.key, required this.range, required this.onChanged});
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onChanged;

  static DateTimeRange preset(String k) {
    final now = DateTime.now();
    final today = dayStart(now);
    final end = today.add(const Duration(days: 1));
    return switch (k) {
      'today' => DateTimeRange(start: today, end: end),
      '7d' => DateTimeRange(start: today.subtract(const Duration(days: 6)), end: end),
      '30d' => DateTimeRange(start: today.subtract(const Duration(days: 29)), end: end),
      'month' => DateTimeRange(start: DateTime(now.year, now.month), end: end),
      'lastmonth' => DateTimeRange(start: DateTime(now.year, now.month - 1), end: DateTime(now.year, now.month)),
      '90d' => DateTimeRange(start: today.subtract(const Duration(days: 89)), end: end),
      'year' => DateTimeRange(start: DateTime(now.year), end: end),
      _ => DateTimeRange(start: today.subtract(const Duration(days: 29)), end: end),
    };
  }

  static const presets = {'today': 'Today', '7d': '7 days', '30d': '30 days', 'month': 'This month', 'lastmonth': 'Last month', '90d': '90 days', 'year': 'This year'};

  @override
  Widget build(BuildContext context) {
    String? active;
    for (final k in presets.keys) {
      final p = preset(k);
      if (p.start == range.start && p.end == range.end) active = k;
    }
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final e in presets.entries)
        ChoiceChip(
          label: Text(e.value),
          selected: active == e.key,
          onSelected: (_) => onChanged(preset(e.key)),
        ),
      ActionChip(
        avatar: const Icon(Icons.date_range_rounded, size: 16),
        label: Text(active == null ? '${Fmt.date(range.start)} – ${Fmt.date(range.end.subtract(const Duration(days: 1)))}' : 'Custom'),
        onPressed: () async {
          final r = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2023),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            initialDateRange: DateTimeRange(start: range.start, end: range.end.subtract(const Duration(days: 1))),
          );
          if (r != null) onChanged(DateTimeRange(start: dayStart(r.start), end: dayStart(r.end).add(const Duration(days: 1))));
        },
      ),
    ]);
  }
}

/// True when running in the seller panel.
bool get isSellerPanel => session.panel == PanelRole.seller;
bool get isDeliveryPanel => session.panel == PanelRole.delivery;
bool get isAdminPanel => session.panel == PanelRole.admin;

/// Convenience reading a Doc as ShopOrder.
ShopOrder orderOf(Doc d) => ShopOrder(d.id, d.data);
