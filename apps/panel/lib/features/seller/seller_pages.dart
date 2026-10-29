import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:latlong2/latlong.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../core/session.dart';
import '../../core/web_utils.dart';
import '../../ui/crud.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import '../shared/withdrawals_self.dart';
import 'package:panel/l10n/overrides.dart';

const _registerUrl = 'https://go4market-delivery.web.app/register';

// ───────────────────────── My delivery partners ─────────────────────────

class SellerRidersPage extends StatelessWidget {
  const SellerRidersPage({super.key});

  Query<Json> get _q => Fs.deliveryPartners.where('ownerType', isEqualTo: 'seller').where('sellerId', isEqualTo: session.uid);

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'My delivery partners',
        subtitle: 'Riders in your own fleet. Assign them from an order to deliver it yourself.',
        actions: [
          FilledButton.icon(onPressed: () => _addRider(context), icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: Text(tr('Add rider'))),
        ],
        child: StreamBuilder<List<Doc>>(
          stream: liveDocs(_q.limit(200), label: 'deliveryPartners(ownerType, sellerId)'),
          builder: (context, snap) {
            final list = snap.data ?? const <Doc>[];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minItemWidth: 200, children: [
                KpiCard(label: 'Riders', value: '${list.length}', icon: Icons.two_wheeler_rounded),
                KpiCard(label: 'Online now', value: '${list.where((d) => d.b('online')).length}', icon: Icons.wifi_tethering_rounded, color: G4MColors.success),
                KpiCard(label: 'Cash in hand', value: Fmt.money(list.fold<double>(0, (a, d) => a + d.n('cashInHand'))), icon: Icons.payments_rounded, color: G4MColors.accent),
                KpiCard(label: 'Deliveries done', value: Fmt.number(list.fold<int>(0, (a, d) => a + d.i('completedCount'))), icon: Icons.task_alt_rounded, color: G4MColors.info),
              ]),
              const SizedBox(height: 20),
              DataView<Doc>(
                id: 'seller_riders',
                source: (q) => liveDocs(_q.limit(q.limit), label: 'deliveryPartners(ownerType, sellerId)'),
                rowId: (d) => d.id,
                onTap: (d) => _riderSheet(context, d),
                searchText: (d) => '${d.s('name')} ${d.s('phone')} ${d.s('email')} ${d.s('vehicleNo')} ${d.list('cities').join(' ')}',
                filters: [
                  TableFilter('online', 'Availability', const {'on': 'Online', 'off': 'Offline'}, test: (d, v) => d.b('online') == (v == 'on')),
                  TableFilter('status', 'Status', const {'approved': 'Approved', 'pending': 'Pending', 'suspended': 'Suspended'}, test: (d, v) => d.s('status') == v),
                ],
                leading: (c, d) => Avatar(name: d.s('name'), url: d.s('photoUrl'), size: 40),
                columns: [
                  Col('Rider', flex: 3, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), d.s('phone'))),
                  Col('Vehicle', flex: 2, text: (d) => '${Fmt.titleCase(d.s('vehicleType', 'bike'))} ${d.s('vehicleNo')}'),
                  Col('Cities', flex: 2, text: (d) => d.list('cities').join(', ')),
                  Col('Online', flex: 1, text: (d) => d.b('online') ? 'Online' : 'Offline', cell: (c, d) => _onlineDot(c, d)),
                  Col('Done', flex: 1, numeric: true, text: (d) => '${d.i('completedCount')}', sort: (d) => d.i('completedCount')),
                  Col('Rating', flex: 1, numeric: true, text: (d) => d.n('rating') == 0 ? '—' : d.n('rating').toStringAsFixed(1), sort: (d) => d.n('rating')),
                  moneyCol('Cash in hand', 'cashInHand'),
                  statusCol('Status', 'status', f: 'pending'),
                ],
                card: (c, d) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Avatar(name: d.s('name'), url: d.s('photoUrl'), size: 48),
                      const SizedBox(width: 12),
                      Expanded(child: TwoLine(d.s('name'), d.s('phone'))),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _onlineDot(c, d),
                      Tag('${Fmt.titleCase(d.s('vehicleType', 'bike'))} ${d.s('vehicleNo')}', icon: Icons.two_wheeler_rounded),
                      Tag('${d.i('completedCount')} done', icon: Icons.task_alt_rounded, color: G4MColors.info),
                      if (d.n('cashInHand') > 0) Tag('${Fmt.money(d.n('cashInHand'))} cash', color: G4MColors.accent),
                    ]),
                  ]),
                ),
                emptyIcon: Icons.delivery_dining_outlined,
                emptyTitle: 'No riders in your fleet yet',
                emptyMessage: 'Invite riders to register as delivery partners, then ask Go4Market to link them to your store.',
                emptyAction: OutlinedButton.icon(onPressed: () => _addRider(context), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(tr('Invite a rider'))),
                csvName: 'my_riders',
              ),
            ]);
          },
        ),
      );

  Widget _onlineDot(BuildContext c, Doc d) => Tag(d.b('online') ? 'Online' : 'Offline', color: d.b('online') ? G4MColors.success : c.pal.faint, icon: Icons.circle);

  Future<void> _addRider(BuildContext context) => showSideSheet<void>(
        context,
        width: 520,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Add a rider to your fleet', style: ctx.tt.titleLarge)),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 16),
            for (final (i, step) in [
              'Share the partner registration link with your rider. They sign up with their own email and phone.',
              'They fill in vehicle details and the cities they serve, and submit the application.',
              'Contact Go4Market support with the rider’s email — the admin approves them as a seller-owned rider linked to your store.',
              'They appear on this page. Assign them from any order (“Assign my rider”).',
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(radius: 13, backgroundColor: ctx.pal.accent, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(step, style: const TextStyle(height: 1.45))),
                ]),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ctx.pal.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: ctx.pal.line)),
              child: Row(children: [
                const Icon(Icons.link_rounded),
                const SizedBox(width: 10),
                const Expanded(child: SelectableText(_registerUrl, style: TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  tooltip: 'Copy link',
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: _registerUrl));
                    toast('Link copied');
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton(tooltip: 'Open', onPressed: () => openUrl(_registerUrl), icon: const Icon(Icons.open_in_new_rounded)),
              ]),
            ),
            const SizedBox(height: 16),
            Text(
              'Sellers cannot create rider logins directly — rider accounts are verified and approved by the Go4Market admin team.',
              style: TextStyle(color: ctx.pal.muted, fontSize: 12.5),
            ),
          ]),
        ),
      );

  Future<void> _riderSheet(BuildContext context, Doc d) => showSideSheet<void>(
        context,
        width: 520,
        builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
            child: Row(children: [
              Avatar(name: d.s('name'), url: d.s('photoUrl'), size: 52),
              const SizedBox(width: 14),
              Expanded(child: TwoLine(d.s('name'), d.s('email'))),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                statusPill(d.s('status', 'pending')),
                _onlineDot(ctx, d),
              ]),
              const SizedBox(height: 12),
              InfoRow('Phone', d.s('phone')),
              InfoRow('Vehicle', '${Fmt.titleCase(d.s('vehicleType', 'bike'))} · ${d.s('vehicleNo')}'),
              InfoRow('Cities', d.list('cities').join(', ')),
              InfoRow('Deliveries', Fmt.number(d.i('completedCount'))),
              InfoRow('Rating', d.n('rating') == 0 ? '—' : '${d.n('rating').toStringAsFixed(1)} ★'),
              InfoRow('Cash in hand', Fmt.money(d.n('cashInHand'))),
              InfoRow('Salary', '${Fmt.titleCase(d.s('salary.type', 'per_order'))} · ${Fmt.money(d.n('salary.amount'))}'),
              InfoRow('Last location', d.dt('locationUpdatedAt') == null ? '—' : Fmt.ago(d.dt('locationUpdatedAt'))),
              const SizedBox(height: 16),
              if (d['lat'] is num && d['lng'] is num)
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(initialCenter: LatLng(d.n('lat'), d.n('lng')), initialZoom: 14),
                      children: [
                        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.panel'),
                        MarkerLayer(markers: [
                          Marker(point: LatLng(d.n('lat'), d.n('lng')), width: 36, height: 36, child: const Icon(Icons.two_wheeler_rounded, color: G4MColors.primary, size: 30)),
                        ]),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Active orders', style: ctx.tt.titleSmall),
              const SizedBox(height: 8),
              StreamBuilder<List<Doc>>(
                stream: liveDocs(
                  Fs.orders.where('sellerIds', arrayContains: session.uid).where('deliveryPartnerId', isEqualTo: d.id).limit(30),
                  label: 'orders(sellerIds, deliveryPartnerId)',
                ),
                builder: (c, s) {
                  if (s.hasError) return Text('Could not load orders', style: TextStyle(color: ctx.pal.muted));
                  final l = (s.data ?? const <Doc>[]).where((o) => !OrderStatus.terminal.contains(o.s('status'))).toList();
                  if (l.isEmpty) return Text('No active orders', style: TextStyle(color: ctx.pal.muted));
                  return Column(children: [
                    for (final o in l)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(o.s('orderNo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(o.s('customer.name')),
                        trailing: statusPill(o.s('status')),
                        onTap: () {
                          Navigator.pop(ctx);
                          context.go('/orders/${o.id}');
                        },
                      ),
                  ]);
                },
              ),
            ]),
          ),
        ]),
      );
}

// ───────────────────────── Earnings ─────────────────────────

class _OrderEarn {
  _OrderEarn(this.order, this.gross, this.commission, this.at);
  final Doc order;
  final double gross;
  final double commission;
  final DateTime? at;
  double get net => gross - commission;
}

class SellerEarningsPage extends StatefulWidget {
  const SellerEarningsPage({super.key});
  @override
  State<SellerEarningsPage> createState() => _SellerEarningsPageState();
}

class _SellerEarningsPageState extends State<SellerEarningsPage> {
  bool _monthly = false;
  int _tab = 0;

  Query<Json> get _delivered =>
      Fs.orders.where('sellerIds', arrayContains: session.uid).where('status', isEqualTo: OrderStatus.delivered);

  late final Stream<List<Doc>> _orders = liveDocs(
    _delivered.orderBy('createdAt', descending: true).limit(1000),
    fallback: _delivered.limit(1000),
    label: 'orders(sellerIds, status, createdAt desc)',
  ).asBroadcastStream();

  late final Stream<List<Doc>> _pendingW = liveDocs(
    Fs.withdrawals.where('userId', isEqualTo: session.uid).where('status', isEqualTo: 'pending'),
    label: 'withdrawals(userId, status)',
  ).asBroadcastStream();

  List<_OrderEarn> _calc(List<Doc> orders, double pct) => [
        for (final o in orders)
          () {
            final items = o['items'] is List ? (o['items'] as List).whereType<Map>() : const <Map>[];
            final gross = items.where((i) => '${i['sellerId']}' == session.uid).fold<double>(0, (a, i) => a + toNum(i['price']) * toNum(i['qty'], 1));
            DateTime? at;
            final t = o['timeline'];
            if (t is List) {
              for (final e in t.reversed) {
                if (e is Map && e['status'] == OrderStatus.delivered) {
                  at = toDate(e['at']);
                  break;
                }
              }
            }
            return _OrderEarn(o, gross, double.parse((gross * pct / 100).toStringAsFixed(2)), at ?? o.dt('updatedAt') ?? o.createdAt);
          }(),
      ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final p = session.profile;
          final pct = p?.n('commissionPct', 10) ?? 10;
          return PanelPage(
            title: 'Earnings',
            subtitle: 'What you earned on delivered orders, after Go4Market commission',
            actions: [
              OutlinedButton.icon(onPressed: () => context.go('/finance/withdrawals'), icon: const Icon(Icons.history_rounded, size: 18), label: Text(tr('Withdrawal history'))),
              FilledButton.icon(
                onPressed: (p?.n('balance') ?? 0) <= 0 ? null : () => requestWithdrawalDialog(context),
                icon: const Icon(Icons.outbox_rounded, size: 18),
                label: Text(tr('Withdraw')),
              ),
            ],
            child: StreamBuilder<List<Doc>>(
              stream: _orders,
              builder: (context, snap) {
                final rows = _calc(snap.data ?? const [], pct);
                final net = rows.fold<double>(0, (a, r) => a + r.net);
                final comm = rows.fold<double>(0, (a, r) => a + r.commission);
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ResponsiveGrid(minItemWidth: 210, children: [
                    KpiCard(label: 'Available balance', value: Fmt.money(p?.n('balance') ?? 0), icon: Icons.account_balance_wallet_rounded, color: G4MColors.primary),
                    KpiCard(label: 'Total sales', value: Fmt.money(p?.n('totalSales') ?? rows.fold<double>(0, (a, r) => a + r.gross)), icon: Icons.trending_up_rounded, color: G4MColors.info),
                    KpiCard(label: 'Commission rate', value: '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%', caption: 'Paid so far ${Fmt.money(comm)}', icon: Icons.percent_rounded, color: G4MColors.accent),
                    StreamBuilder<List<Doc>>(
                      stream: _pendingW,
                      builder: (c, s) => KpiCard(
                        label: 'Pending withdrawals',
                        value: Fmt.money((s.data ?? const <Doc>[]).fold<double>(0, (a, d) => a + d.n('amount'))),
                        caption: '${(s.data ?? const []).length} request(s)',
                        icon: Icons.hourglass_top_rounded,
                        color: G4MColors.warning,
                        onTap: () => context.go('/finance/withdrawals'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Net earnings',
                    subtitle: '${_monthly ? 'Last 12 months' : 'Last 12 weeks'} · lifetime net ${Fmt.money(net)}',
                    icon: Icons.bar_chart_rounded,
                    trailing: Segmented<bool>(value: _monthly, options: const {false: 'Weekly', true: 'Monthly'}, onChanged: (v) => setState(() => _monthly = v)),
                    child: SizedBox(height: 260, child: snap.hasData ? _chart(context, rows) : const Center(child: CircularProgressIndicator())),
                  ),
                  const SizedBox(height: 20),
                  Segmented<int>(value: _tab, options: const {0: 'Order earnings', 1: 'Wallet transactions'}, onChanged: (v) => setState(() => _tab = v)),
                  const SizedBox(height: 12),
                  if (_tab == 0) _ordersTable(context, pct) else _walletTable(),
                ]);
              },
            ),
          );
        },
      );

  Widget _chart(BuildContext context, List<_OrderEarn> rows) {
    final now = DateTime.now();
    final buckets = <DateTime>[];
    if (_monthly) {
      for (var i = 11; i >= 0; i--) {
        buckets.add(DateTime(now.year, now.month - i));
      }
    } else {
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      for (var i = 11; i >= 0; i--) {
        buckets.add(monday.subtract(Duration(days: 7 * i)));
      }
    }
    final vals = List<double>.filled(buckets.length, 0);
    for (final r in rows) {
      final d = r.at;
      if (d == null) continue;
      for (var i = buckets.length - 1; i >= 0; i--) {
        if (!d.isBefore(buckets[i])) {
          final end = _monthly ? DateTime(buckets[i].year, buckets[i].month + 1) : buckets[i].add(const Duration(days: 7));
          if (d.isBefore(end)) vals[i] += r.net;
          break;
        }
      }
    }
    final maxV = vals.fold<double>(0, (a, b) => a > b ? a : b);
    final accent = context.pal.accent;
    String lbl(DateTime d) => _monthly ? DateFormat('MMM').format(d) : DateFormat('d MMM').format(d);
    return Directionality(textDirection: TextDirection.ltr, child: BarChart(
      BarChartData(
        maxY: maxV == 0 ? 100 : maxV * 1.2,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: context.pal.line, strokeWidth: 1)),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => G4MColors.primaryDeep,
            getTooltipItem: (g, _, r, _) => BarTooltipItem('${lbl(buckets[g.x])}\n${Fmt.money(r.toY)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (v, m) => SideTitleWidget(meta: m, child: Text(Fmt.moneyCompact(v), style: TextStyle(fontSize: 10.5, color: context.pal.muted))),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= buckets.length) return const SizedBox();
                return SideTitleWidget(meta: m, child: Text(lbl(buckets[i]), style: TextStyle(fontSize: 10.5, color: context.pal.muted)));
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: vals[i],
                width: 18,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [accent.withValues(alpha: .5), accent]),
              ),
            ]),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    ));
  }

  Widget _ordersTable(BuildContext context, double pct) => DataView<_OrderEarn>(
        key: const ValueKey('orders'),
        id: 'seller_earnings',
        source: (q) => liveDocs(
          _delivered.orderBy('createdAt', descending: true).limit(q.limit),
          fallback: _delivered.limit(q.limit),
          label: 'orders(sellerIds, status, createdAt desc)',
        ).map((l) => _calc(l, pct)),
        rowId: (r) => r.order.id,
        onTap: (r) => context.go('/orders/${r.order.id}'),
        searchText: (r) => '${r.order.s('orderNo')} ${r.order.s('customer.name')}',
        filters: [
          TableFilter('channel', 'Channel', const {'web': 'Web', 'app': 'App', 'pos': 'POS'}, test: (r, v) => r.order.s('channel') == v),
        ],
        columns: [
          Col('Order', flex: 2, text: (r) => r.order.s('orderNo'), cell: (c, r) => TwoLine(r.order.s('orderNo'), r.order.s('customer.name'))),
          Col('Delivered', flex: 2, text: (r) => Fmt.date(r.at), sort: (r) => r.at?.millisecondsSinceEpoch ?? 0),
          Col('Channel', flex: 1, text: (r) => r.order.s('channel').toUpperCase()),
          Col('Gross (your items)', flex: 2, numeric: true, text: (r) => Fmt.money(r.gross), sort: (r) => r.gross, csv: (r) => r.gross.toStringAsFixed(2)),
          Col('Commission', flex: 2, numeric: true, text: (r) => '−${Fmt.money(r.commission)}', sort: (r) => r.commission, csv: (r) => r.commission.toStringAsFixed(2)),
          Col('Net', flex: 2, numeric: true, text: (r) => Fmt.money(r.net), sort: (r) => r.net, csv: (r) => r.net.toStringAsFixed(2)),
        ],
        defaultSort: 1,
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: 'No delivered orders yet',
        emptyMessage: 'Earnings appear here once orders containing your products are delivered.',
        csvName: 'seller_earnings',
      );

  Widget _walletTable() => DataView<Doc>(
        key: const ValueKey('wallet'),
        id: 'seller_wallet_txns',
        source: (q) => liveDocs(
          Fs.walletTransactions.where('userId', isEqualTo: session.uid).orderBy('createdAt', descending: true).limit(q.limit),
          fallback: Fs.walletTransactions.where('userId', isEqualTo: session.uid).limit(q.limit),
          label: 'walletTransactions(userId, createdAt desc)',
        ),
        rowId: (d) => d.id,
        searchText: (d) => '${d.s('reason')} ${d.s('refId')}',
        filters: [TableFilter('type', 'Type', const {'credit': 'Credit', 'debit': 'Debit'}, test: (d, v) => d.s('type') == v)],
        columns: [
          dateCol('Date'),
          Col('Type', flex: 1, text: (d) => d.s('type'), cell: (c, d) => statusPill(d.s('type'))),
          Col('Reason', flex: 2, text: (d) => Fmt.titleCase(d.s('reason'))),
          Col('Amount', flex: 2, numeric: true, text: (d) => '${d.s('type') == 'debit' ? '−' : '+'}${Fmt.money(d.n('amount'))}', sort: (d) => d.n('amount')),
          moneyCol('Balance after', 'balanceAfter'),
          Col('Ref', flex: 2, text: (d) => d.s('refId')),
        ],
        emptyIcon: Icons.account_balance_wallet_outlined,
        emptyTitle: 'No wallet transactions',
        csvName: 'seller_wallet',
      );
}

// ───────────────────────── Store profile & settings ─────────────────────────

class StoreProfilePage extends StatefulWidget {
  const StoreProfilePage({super.key});
  @override
  State<StoreProfilePage> createState() => _StoreProfilePageState();
}

class _StoreProfilePageState extends State<StoreProfilePage> {
  int _tab = 0;
  Map<String, dynamic>? _v;
  bool _dirty = false;
  bool _saving = false;
  final _forms = [GlobalKey<EntityFormState>(), GlobalKey<EntityFormState>(), GlobalKey<EntityFormState>(), GlobalKey<EntityFormState>()];

  static const _editable = [
    'storeName', 'description', 'logo', 'banner', 'phone', 'address', 'city', 'lat', 'lng', 'gstin', 'bank', //
    'selfPickupEnabled', 'openTime', 'closeTime', 'minOrder', 'acceptingOrders', 'prepMinutes', 'pan', 'fssai', 'supportEmail',
  ];

  void _init() {
    if (_v != null || session.profile == null) return;
    final d = session.profile!.data;
    _v = {for (final k in _editable) if (d.containsKey(k)) k: d[k] is Map ? deepCopy(Map<String, dynamic>.from(d[k] as Map)) : d[k]};
    _v!.putIfAbsent('acceptingOrders', () => true);
    _v!['email'] = d['email'];
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    for (final f in _forms) {
      if (!(f.currentState?.validate() ?? true)) {
        toast('Please fix the highlighted fields', kind: ToastKind.error);
        return;
      }
    }
    setState(() => _saving = true);
    final v = cleanValues(_v!);
    v.removeWhere((k, _) => !_editable.contains(k));
    final ok = await runToast(
      () => Fs.sellers.doc(session.uid).set({...v, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
      success: 'Store settings saved',
    );
    if (mounted) {
      setState(() {
        _saving = false;
        if (ok) _dirty = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          _init();
          final p = session.profile;
          if (p == null || _v == null) return const PanelPage(title: 'Store profile', child: LoadingBlock());
          return Column(children: [
            Expanded(
              child: PanelPage(
                title: 'Store profile & settings',
                subtitle: 'How your store appears to customers, and how you get paid',
                maxWidth: 1100,
                actions: [
                  Segmented<int>(
                    value: _tab,
                    options: const {0: 'Store', 1: 'Tax & bank', 2: 'Settings', 3: 'Policies'},
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                ],
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _header(context, p),
                  const SizedBox(height: 20),
                  // Keep all forms mounted so validation covers every tab.
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Offstage(offstage: _tab != 0, child: _storeTab(context, p)),
                    Offstage(offstage: _tab != 1, child: _bankTab(context, p)),
                    Offstage(offstage: _tab != 2, child: _settingsTab(context)),
                    Offstage(offstage: _tab != 3, child: _policiesTab(context, p)),
                  ]),
                ]),
              ),
            ),
            AnimatedSize(
              duration: G4MMotion.standard,
              curve: G4MMotion.curve,
              child: !_dirty
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.pal.surface,
                        border: Border(top: BorderSide(color: context.pal.line)),
                        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))],
                      ),
                      child: Row(children: [
                        const Icon(Icons.edit_note_rounded, color: G4MColors.warning),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('You have unsaved changes', style: TextStyle(fontWeight: FontWeight.w700))),
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                    _v = null;
                                    _dirty = false;
                                    _init();
                                  }),
                          child: Text(tr('Discard')),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(tr('Save changes')),
                        ),
                      ]),
                    ),
            ),
          ]);
        },
      );

  Widget _header(BuildContext context, Doc p) => Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: context.pal.line), color: context.pal.surface),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 120,
            child: '${_v!['banner'] ?? ''}'.isEmpty
                ? Container(decoration: const BoxDecoration(gradient: G4MColors.heroGradient))
                : NetImage('${_v!['banner']}', fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: context.pal.line), color: context.pal.surfaceAlt),
                clipBehavior: Clip.antiAlias,
                child: '${_v!['logo'] ?? ''}'.isEmpty ? const Icon(Icons.storefront_rounded) : NetImage('${_v!['logo']}'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_v!['storeName'] ?? p.s('storeName')}', style: context.tt.titleLarge),
                  Text('${p.s('city')} · ${p.s('email')}', style: TextStyle(color: context.pal.muted)),
                ]),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                statusPill(p.s('status', 'pending')),
                Tag('Commission ${p.n('commissionPct', 10).toStringAsFixed(0)}%', color: G4MColors.accent, icon: Icons.percent_rounded),
                if (p.n('rating') > 0) Tag('${p.n('rating').toStringAsFixed(1)} ★', color: const Color(0xFFF5A524)),
                Tag(_v!['acceptingOrders'] == false ? 'Paused' : 'Accepting orders', color: _v!['acceptingOrders'] == false ? G4MColors.danger : G4MColors.success),
              ]),
            ]),
          ),
        ]),
      );

  Widget _storeTab(BuildContext context, Doc p) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionCard(
          title: 'Store details',
          icon: Icons.storefront_outlined,
          child: EntityForm(key: _forms[0], values: _v!, onChanged: _changed, fields: [
            const F('storeName', 'Store name', FT.text, required: true),
            const F('phone', 'Store phone', FT.text, required: true),
            const F('email', 'Login email', FT.text, readOnly: true, help: 'Contact support to change your login email'),
            const F('supportEmail', 'Customer support email', FT.email),
            const F('description', 'About the store', FT.multiline),
            const F('logo', 'Logo', FT.image, folder: 'sellers/logo', help: 'Square, at least 256×256 · JPG, PNG or WebP'),
            const F('banner', 'Banner', FT.image, folder: 'sellers/banner', aspect: 3, help: 'Wide 3:1 image · JPG, PNG or WebP'),
          ]),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Location',
          subtitle: 'Used for pickup routing and distance-based delivery estimates',
          icon: Icons.place_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            EntityForm(key: _forms[3], values: _v!, onChanged: _changed, fields: [
              F('city', 'City', FT.select, required: true, optionsStream: () => optionsOf(Fs.cities, 'name').map((m) => {for (final v in m.values) v: v})),
              const F('address', 'Full address', FT.multiline, required: true),
            ]),
            const SizedBox(height: 16),
            _LocationPicker(
              lat: _v!['lat'] is num ? (_v!['lat'] as num).toDouble() : null,
              lng: _v!['lng'] is num ? (_v!['lng'] as num).toDouble() : null,
              onChanged: (la, ln) {
                setState(() {
                  _v!['lat'] = double.parse(la.toStringAsFixed(6));
                  _v!['lng'] = double.parse(ln.toStringAsFixed(6));
                });
                _changed();
              },
            ),
          ]),
        ),
      ]);

  Widget _bankTab(BuildContext context, Doc p) => SectionCard(
        title: 'Tax & payout details',
        subtitle: 'Withdrawals are paid to this account',
        icon: Icons.account_balance_outlined,
        child: EntityForm(key: _forms[1], values: _v!, onChanged: _changed, fields: [
          const F.section('Tax registration'),
          F('gstin', 'GSTIN', FT.text, uppercase: true, validator: (v, _) {
            final s = '${v ?? ''}';
            return s.isEmpty || RegExp(r'^[0-9]{2}[A-Z0-9]{13}$').hasMatch(s) ? null : '15-character GSTIN';
          }),
          const F('pan', 'PAN', FT.text, uppercase: true),
          const F('fssai', 'FSSAI licence (food / grocery)', FT.text),
          const F.section('Bank account'),
          const F('bank.holder', 'Account holder name', FT.text, required: true),
          const F('bank.account', 'Account number', FT.text, required: true),
          F('bank.ifsc', 'IFSC', FT.text, required: true, uppercase: true, validator: (v, _) {
            final s = '${v ?? ''}';
            return s.isEmpty || RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(s) ? null : 'Invalid IFSC (e.g. HDFC0001234)';
          }),
          const F('bank.upi', 'UPI ID', FT.text, hint: 'store@bank'),
        ]),
      );

  Widget _settingsTab(BuildContext context) => SectionCard(
        title: 'Store operations',
        icon: Icons.tune_rounded,
        child: EntityForm(key: _forms[2], values: _v!, onChanged: _changed, fields: [
          const F('acceptingOrders', 'Accepting orders', FT.toggle, help: 'Turn off to temporarily pause new orders (holiday, stock-take)'),
          const F('selfPickupEnabled', 'Allow self-pickup', FT.toggle, help: 'Customers can choose to collect orders from your store'),
          F('openTime', 'Opens at', FT.text, hint: '09:00', validator: _time),
          F('closeTime', 'Closes at', FT.text, hint: '21:00', validator: _time),
          const F('minOrder', 'Minimum order value', FT.money, min: 0),
          const F('prepMinutes', 'Average preparation time (minutes)', FT.integer, min: 0, max: 240),
        ]),
      );

  String? _time(dynamic v, Map<String, dynamic> _) {
    final s = '${v ?? ''}';
    return s.isEmpty || RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s) ? null : 'Use 24h HH:mm';
  }

  Widget _policiesTab(BuildContext context, Doc p) => SectionCard(
        title: 'Seller policies',
        subtitle: p.b('policiesAccepted') ? 'Accepted ${Fmt.dateTime(p.dt('policiesAcceptedAt'))}' : 'Please review and accept',
        icon: Icons.policy_outlined,
        trailing: p.b('policiesAccepted') ? const Tag('Accepted', color: G4MColors.success, icon: Icons.verified_rounded) : const Tag('Action needed', color: G4MColors.warning),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 420),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.pal.surfaceAlt.withValues(alpha: .5), borderRadius: BorderRadius.circular(12)),
            child: StreamBuilder<Doc?>(
              stream: liveDoc(Fs.pages.doc('seller-policy')),
              builder: (c, s) {
                if (!s.hasData && !s.hasError) return const LoadingBlock(rows: 3);
                final md = s.data?.s('content') ?? '';
                return SingleChildScrollView(
                  child: MarkdownBody(data: md.isEmpty ? '_The seller policy has not been published yet._' : md, selectable: true),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Text(
                'By accepting you agree to list only genuine products, ship on time and the commission terms shown above.',
                style: TextStyle(color: context.pal.muted, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            AsyncButton(
              label: p.b('policiesAccepted') ? 'Accept again' : 'I accept',
              icon: Icons.verified_rounded,
              outlined: p.b('policiesAccepted'),
              onPressed: () => runToast(
                () => Fs.sellers.doc(session.uid).set({'policiesAccepted': true, 'policiesAcceptedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
                success: 'Policies accepted',
              ),
            ),
          ]),
        ]),
      );
}

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({required this.lat, required this.lng, required this.onChanged});
  final double? lat, lng;
  final void Function(double lat, double lng) onChanged;
  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  final _map = MapController();
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
    final has = widget.lat != null && widget.lng != null;
    final center = has ? LatLng(widget.lat!, widget.lng!) : const LatLng(19.0760, 72.8777);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(Icons.touch_app_outlined, size: 16, color: context.pal.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(has ? 'Pinned at ${widget.lat!.toStringAsFixed(5)}, ${widget.lng!.toStringAsFixed(5)} — click the map to move' : 'Click on the map to pin your store',
              style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
        ),
        TextButton.icon(
          onPressed: _locating
              ? null
              : () async {
                  setState(() => _locating = true);
                  try {
                    final (la, ln) = await currentPosition();
                    widget.onChanged(la, ln);
                    _map.move(LatLng(la, ln), 16);
                  } catch (e) {
                    toast('Location unavailable: $e', kind: ToastKind.error);
                  } finally {
                    if (mounted) setState(() => _locating = false);
                  }
                },
          icon: _locating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(tr('Use my location')),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: has ? 15 : 11,
              onTap: (_, p) => widget.onChanged(p.latitude, p.longitude),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.go4market.panel'),
              if (has)
                MarkerLayer(markers: [
                  Marker(
                    point: center,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_on_rounded, color: context.pal.accent, size: 44),
                  ),
                ]),
              const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
            ],
          ),
        ),
      ),
    ]);
  }
}
