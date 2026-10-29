import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../ui/data_view.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'people_common.dart';
import 'package:panel/l10n/overrides.dart';

export 'people_customers.dart';

// ═══════════════════════════════ SELLERS ═══════════════════════════════

Future<void> _approveSeller(BuildContext context, Doc d) async {
  final v = await promptText(context, 'Approve ${d.s('storeName')}', label: 'Commission %', initial: d.n('commissionPct', 10).toStringAsFixed(0), number: true, required: true, confirmLabel: 'Approve');
  if (v == null) return;
  await callApi(() => G4MApi.instance.reviewSeller({'uid': d.id, 'status': 'approved', 'commissionPct': double.parse(v)}), success: 'Seller approved');
}

Future<void> _setSellerStatus(BuildContext context, Doc d, String status) async {
  String? note;
  if (status == 'rejected' || status == 'suspended') {
    note = await promptText(context, '${status == 'rejected' ? 'Reject' : 'Suspend'} ${d.s('storeName')}', label: 'Reason (shared with the seller)', maxLines: 3, confirmLabel: Fmt.titleCase(status));
    if (note == null) return;
  } else if (!await confirm(context, 'Reactivate ${d.s('storeName')}?', confirmLabel: 'Reactivate')) {
    return;
  }
  await callApi(() => G4MApi.instance.reviewSeller({'uid': d.id, 'status': status, if (note != null && note.isNotEmpty) 'note': note}),
      success: 'Seller ${status == 'approved' ? 'reactivated' : status}');
}

Future<void> _editCommission(BuildContext context, Doc d) async {
  final v = await promptText(context, 'Commission for ${d.s('storeName')}', label: 'Commission %', initial: d.n('commissionPct', 10).toStringAsFixed(1), number: true, required: true);
  if (v == null) return;
  await callApi(() => G4MApi.instance.reviewSeller({'uid': d.id, 'status': d.s('status', 'approved'), 'commissionPct': double.parse(v)}), success: 'Commission updated');
}

Future<void> _addSeller(BuildContext context) => openEditor(
      context,
      title: 'Add seller',
      subtitle: 'Creates the login and an approved store',
      saveLabel: 'Create seller',
      fields: [
        const F.section('Login'),
        const F('ownerName', 'Owner name', FT.text, required: true),
        const F('email', 'Email', FT.email, required: true),
        const F('phone', 'Mobile', FT.text, required: true),
        F('password', 'Password', FT.password, required: true, validator: (v, _) => '$v'.length < 8 ? 'At least 8 characters' : null),
        const F.section('Store'),
        const F('storeName', 'Store name', FT.text, required: true),
        F('city', 'City', FT.select, optionsStream: () => optionsOf(Fs.cities, 'name').map((m) => {for (final v in m.values) v: v})),
        const F('commissionPct', 'Commission', FT.percent, initial: 10, required: true),
        const F('moduleIds', 'Modules', FT.multiselect, options: moduleOptions),
        const F('address', 'Address', FT.multiline),
        const F('gstin', 'GSTIN', FT.text, uppercase: true),
        const F('logo', 'Logo', FT.image, folder: 'sellers'),
        const F('autoApproveProducts', 'Auto-approve products', FT.toggle, help: 'Skip admin review for this seller\'s product listings'),
      ],
      onSave: (v) async {
        final r = await G4MApi.instance.createStaffUser({'email': v['email'], 'password': v['password'], 'name': v['ownerName'], 'role': 'seller'});
        final uid = '${r['uid'] ?? ''}';
        if (uid.isEmpty) throw 'createStaffUser did not return a uid';
        final store = '${v['storeName']}'.trim();
        await Fs.sellers.doc(uid).set({
          'storeName': store,
          'slug': Fmt.slugify(store),
          'ownerName': v['ownerName'],
          'email': '${v['email']}'.trim(),
          'phone': v['phone'],
          'city': v['city'] ?? '',
          'address': v['address'] ?? '',
          'gstin': v['gstin'] ?? '',
          'logo': v['logo'] ?? '',
          'moduleIds': v['moduleIds'] ?? const [],
          'commissionPct': toNum(v['commissionPct'], 10),
          'autoApproveProducts': v['autoApproveProducts'] == true,
          'status': 'approved',
          'balance': 0,
          'totalSales': 0,
          'productCount': 0,
          'rating': 0,
          'ratingCount': 0,
          'policiesAccepted': true,
          'createdAt': ts,
          'updatedAt': ts,
        }, SetOptions(merge: true));
      },
    );

Future<void> _editSellerProfile(BuildContext context, Doc d) => openEditor(
      context,
      title: 'Edit ${d.s('storeName')}',
      initial: d.data,
      fields: [
        const F('storeName', 'Store name', FT.text, required: true),
        const F('ownerName', 'Owner', FT.text),
        const F('email', 'Email', FT.email),
        const F('phone', 'Phone', FT.text),
        F('city', 'City', FT.select, optionsStream: () => optionsOf(Fs.cities, 'name').map((m) => {for (final v in m.values) v: v})),
        const F('gstin', 'GSTIN', FT.text, uppercase: true),
        const F('address', 'Address', FT.multiline),
        const F('description', 'Description', FT.multiline),
        const F('moduleIds', 'Modules', FT.multiselect, options: moduleOptions),
        const F('autoApproveProducts', 'Auto-approve products', FT.toggle),
        const F('lat', 'Latitude', FT.number),
        const F('lng', 'Longitude', FT.number),
        const F('logo', 'Logo', FT.image, folder: 'sellers'),
        const F('banner', 'Banner', FT.image, folder: 'sellers', aspect: 3),
        const F.section('Bank'),
        const F('bank.holder', 'Account holder', FT.text),
        const F('bank.account', 'Account number', FT.text),
        const F('bank.ifsc', 'IFSC', FT.text, uppercase: true),
      ],
      onSave: (v) async {
        final out = cleanValues(v)..removeWhere((k, _) => const {'status', 'commissionPct', 'balance', 'totalSales', 'createdAt'}.contains(k));
        await d.ref!.set({...out, 'updatedAt': ts}, SetOptions(merge: true));
      },
    );

List<RowAction<Doc>> _sellerActions(BuildContext context) => [
      RowAction('View details', Icons.open_in_new_rounded, (d) => context.go('/sellers/${d.id}')),
      RowAction('Approve', Icons.check_circle_outline_rounded, (d) => _approveSeller(context, d), visible: (d) => d.s('status', 'pending') != 'approved'),
      RowAction('Reject', Icons.cancel_outlined, (d) => _setSellerStatus(context, d, 'rejected'), visible: (d) => d.s('status', 'pending') == 'pending', danger: true),
      RowAction('Edit commission', Icons.percent_rounded, (d) => _editCommission(context, d), visible: (d) => d.s('status') == 'approved'),
      RowAction('Edit profile', Icons.edit_outlined, (d) => _editSellerProfile(context, d)),
      RowAction('Suspend', Icons.block_rounded, (d) => _setSellerStatus(context, d, 'suspended'), visible: (d) => d.s('status') == 'approved', danger: true),
      RowAction('Reactivate', Icons.restart_alt_rounded, (d) => _setSellerStatus(context, d, 'approved'), visible: (d) => d.s('status') == 'suspended'),
    ];

const _sellerStatuses = {'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected', 'suspended': 'Suspended'};

class SellersPage extends StatelessWidget {
  const SellersPage({super.key, this.requests = false});
  final bool requests;

  @override
  Widget build(BuildContext context) {
    return PanelPage(
      title: requests ? 'Seller requests' : 'Sellers',
      subtitle: requests ? 'Review new store applications and set their commission' : 'Every store selling on Go4Market',
      actions: [FilledButton.icon(onPressed: () => _addSeller(context), icon: const Icon(Icons.add_business_rounded, size: 18), label: Text(tr('Add seller')))],
      child: DataView<Doc>(
        key: ValueKey('sellers_$requests'),
        id: requests ? 'seller_requests' : 'sellers',
        source: (q) {
          final st = q.filters['status'];
          final base = st == null ? Fs.sellers : Fs.sellers.where('status', isEqualTo: st);
          return recent(base, q.limit, label: 'sellers_status_createdAt');
        },
        filters: [
          TableFilter('status', 'Status', requests ? const {'pending': 'Pending', 'rejected': 'Rejected'} : _sellerStatuses,
              server: true, initial: requests ? 'pending' : null),
          TableFilter('module', 'Module', moduleOptions, test: (d, v) => d.list('moduleIds').contains(v)),
        ],
        rowId: (d) => d.id,
        searchText: (d) => '${d.s('storeName')} ${d.s('ownerName')} ${d.s('email')} ${d.s('phone')} ${d.s('city')} ${d.s('gstin')}',
        onTap: (d) => context.go('/sellers/${d.id}'),
        actions: _sellerActions(context),
        bulkActions: requests
            ? [
                BulkAction('Approve (10%)', Icons.done_all_rounded,
                    (rows) => Future.wait(rows.map((d) => G4MApi.instance.reviewSeller({'uid': d.id, 'status': 'approved', 'commissionPct': d.n('commissionPct', 10)})))),
              ]
            : const [],
        emptyIcon: requests ? Icons.how_to_reg_outlined : Icons.storefront_outlined,
        emptyTitle: requests ? 'No pending applications' : 'No sellers yet',
        emptyMessage: requests ? 'New seller registrations will appear here for review.' : null,
        leading: (c, d) => Avatar(url: d.s('logo'), name: d.s('storeName'), size: 40),
        defaultSort: 8,
        columns: [
          Col('Store', flex: 4, text: (d) => d.s('storeName'), cell: (c, d) => TwoLine(d.s('storeName', 'Unnamed store'), d.s('city'))),
          Col('Owner', flex: 3, text: (d) => d.s('ownerName'), cell: (c, d) => TwoLine(d.s('ownerName'), d.s('phone').isEmpty ? d.s('email') : d.s('phone'))),
          Col('Commission', flex: 2, numeric: true, text: (d) => '${d.n('commissionPct', 10).toStringAsFixed(1)}%', sort: (d) => d.n('commissionPct')),
          Col('Products', flex: 2, numeric: true, text: (d) => '${d.i('productCount')}', sort: (d) => d.n('productCount')),
          Col('Balance', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('balance')), sort: (d) => d.n('balance')),
          Col('Sales', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('totalSales')), sort: (d) => d.n('totalSales')),
          Col('Rating', flex: 1, numeric: true, text: (d) => d.n('rating').toStringAsFixed(1), sort: (d) => d.n('rating')),
          Col('Status', flex: 2, text: (d) => d.s('status', 'pending'), cell: (c, d) => statusPill(d.s('status', 'pending'))),
          Col('Joined', flex: 2, text: (d) => Fmt.date(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
        ],
        card: (c, d) => _SellerCard(d: d, requests: requests),
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.d, required this.requests});
  final Doc d;
  final bool requests;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 84,
          child: d.s('banner').isNotEmpty
              ? NetImage(d.s('banner'))
              : Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFF0A4A33), context.pal.accent.withValues(alpha: .8)]))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.pal.surface, width: 3)),
                child: Avatar(url: d.s('logo'), name: d.s('storeName'), size: 52),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(d.s('storeName', 'Unnamed store'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                  statusPill(d.s('status', 'pending')),
                ]),
                Text('${d.s('ownerName')} · ${d.s('city')}', style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
                const SizedBox(height: 12),
                Row(children: [
                  _mini(context, 'Balance', Fmt.money(d.n('balance'))),
                  _mini(context, 'Sales', Fmt.moneyCompact(d.n('totalSales'))),
                  _mini(context, 'Commission', '${d.n('commissionPct', 10).toStringAsFixed(0)}%'),
                ]),
                if (requests && d.s('status', 'pending') == 'pending') ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => _setSellerStatus(context, d, 'rejected'), child: Text(tr('Reject')))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(onPressed: () => _approveSeller(context, d), child: Text(tr('Approve')))),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ]);

  Widget _mini(BuildContext context, String l, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          Text(l, style: TextStyle(color: context.pal.muted, fontSize: 11)),
        ]),
      );
}

class SellerDetailPage extends StatelessWidget {
  const SellerDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => StreamBuilder<Doc?>(
        stream: liveDoc(Fs.sellers.doc(id)),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: ErrorBox(snap.error!));
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(28), child: LoadingBlock());
          final d = snap.data;
          if (d == null) {
            return EmptyState(
              icon: Icons.storefront_outlined,
              title: 'Seller not found',
              action: OutlinedButton(onPressed: () => context.go('/sellers'), child: Text(tr('Back to sellers'))),
            );
          }
          final st = d.s('status', 'pending');
          return PanelPage(
            title: d.s('storeName', 'Seller'),
            subtitle: 'Seller since ${Fmt.date(d.createdAt)}',
            actions: [
              OutlinedButton.icon(onPressed: () => context.go('/sellers'), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: Text(tr('All sellers'))),
            ],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DetailHeader(
                title: d.s('storeName', 'Seller'),
                subtitle: '${d.s('ownerName')} · ${d.s('email')} · ${d.s('phone')}',
                image: d.s('logo'),
                banner: d.s('banner'),
                chips: [
                  statusPill(st),
                  if (d.s('city').isNotEmpty) Tag(d.s('city'), icon: Icons.place_outlined),
                  for (final m in d.list('moduleIds')) Tag(moduleOptions[m] ?? m, color: context.pal.accent),
                  if (d.b('autoApproveProducts')) const Tag('Auto-approve', color: G4MColors.info, icon: Icons.bolt_rounded),
                ],
                actions: [
                  if (st != 'approved') FilledButton.icon(onPressed: () => _approveSeller(context, d), icon: const Icon(Icons.check_rounded, size: 18), label: Text(tr('Approve'))),
                  if (st == 'pending')
                    OutlinedButton.icon(onPressed: () => _setSellerStatus(context, d, 'rejected'), icon: const Icon(Icons.close_rounded, size: 18), label: Text(tr('Reject'))),
                  if (st == 'approved')
                    OutlinedButton.icon(onPressed: () => _setSellerStatus(context, d, 'suspended'), icon: const Icon(Icons.block_rounded, size: 18), label: Text(tr('Suspend'))),
                  OutlinedButton.icon(onPressed: () => _editSellerProfile(context, d), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(tr('Edit'))),
                ],
              ),
              const SizedBox(height: 16),
              ResponsiveGrid(minItemWidth: 190, children: [
                KpiCard(label: 'Wallet balance', value: Fmt.money(d.n('balance')), icon: Icons.account_balance_wallet_rounded),
                KpiCard(label: 'Total sales', value: Fmt.money(d.n('totalSales')), icon: Icons.trending_up_rounded, color: G4MColors.success),
                KpiCard(
                    label: 'Commission',
                    value: '${d.n('commissionPct', 10).toStringAsFixed(1)}%',
                    icon: Icons.percent_rounded,
                    color: G4MColors.accent,
                    caption: '≈ ${Fmt.money(d.n('totalSales') * d.n('commissionPct', 10) / 100)} earned',
                    onTap: () => _editCommission(context, d)),
                KpiCard(label: 'Products', value: '${d.i('productCount')}', icon: Icons.inventory_2_rounded, color: G4MColors.info),
                KpiCard(label: 'Rating', value: '${d.n('rating').toStringAsFixed(1)} ★', icon: Icons.star_rounded, color: const Color(0xFFF5A524), caption: '${d.i('ratingCount')} ratings'),
              ]),
              const SizedBox(height: 20),
              InlineTabs(tabs: [
                ('Overview', Icons.info_outline_rounded, (c) => _overview(c, d)),
                ('Products', Icons.inventory_2_outlined, (c) => _products(c)),
                ('Orders', Icons.receipt_long_outlined, (c) => ordersTable(c, 'seller_orders_$id', Fs.orders.where('sellerIds', arrayContains: id), label: 'orders_sellerIds_createdAt')),
                ('Payouts', Icons.outbox_outlined, (c) => withdrawalsTable(c, 'seller_wd_$id', Fs.withdrawals.where('userId', isEqualTo: id))),
                ('Transfers', Icons.swap_horiz_rounded, (c) => transfersTable(c, 'seller_tr_$id', Fs.fundTransfers.where('toUserId', isEqualTo: id))),
                ('Delivery partners', Icons.delivery_dining_outlined, (c) => _riders(c)),
              ]),
            ]),
          );
        },
      );

  Widget _overview(BuildContext context, Doc d) => ResponsiveGrid(minItemWidth: 380, children: [
        SectionCard(
          title: 'Store profile',
          icon: Icons.storefront_outlined,
          child: Column(children: [
            InfoRow('Store name', d.s('storeName')),
            InfoRow('Slug', d.s('slug')),
            InfoRow('Owner', d.s('ownerName')),
            InfoRow('Email', d.s('email')),
            InfoRow('Phone', d.s('phone')),
            InfoRow('City', d.s('city')),
            InfoRow('Address', d.s('address')),
            InfoRow('GSTIN', d.s('gstin')),
            InfoRow('Location', d['lat'] == null ? '' : '${d.n('lat').toStringAsFixed(5)}, ${d.n('lng').toStringAsFixed(5)}'),
            InfoRow('About', d.s('description')),
          ]),
        ),
        Column(children: [
          SectionCard(
            title: 'Bank & payouts',
            icon: Icons.account_balance_outlined,
            child: Column(children: [
              InfoRow('Account holder', d.s('bank.holder')),
              InfoRow('Account no.', d.s('bank.account')),
              InfoRow('IFSC', d.s('bank.ifsc')),
              InfoRow('UPI', d.s('bank.upi')),
            ]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Compliance',
            icon: Icons.verified_outlined,
            child: Column(children: [
              InfoRow('Policies accepted', '', valueWidget: Align(alignment: AlignmentDirectional.centerStart, child: d.b('policiesAccepted') ? const Tag('Accepted', color: G4MColors.success, icon: Icons.check_rounded) : const Tag('Not accepted', color: G4MColors.danger))),
              InfoRow('Product approval', d.b('autoApproveProducts') ? 'Auto-approved' : 'Requires admin review'),
              InfoRow('Review note', d.s('reviewNote', d.s('note'))),
              InfoRow('Last updated', Fmt.dateTime(d.dt('updatedAt'))),
            ]),
          ),
        ]),
      ]);

  Widget _products(BuildContext context) => DataView<Doc>(
        id: 'seller_products_$id',
        source: (q) => recent(Fs.products.where('sellerId', isEqualTo: id), q.limit, label: 'products_sellerId_createdAt'),
        rowId: (d) => d.id,
        searchText: (d) => '${d.s('name')} ${d.s('barcode')} ${d.s('status')}',
        pageSize: 10,
        initialLimit: 200,
        onTap: (d) => context.go('/catalog/products/${d.id}/edit'),
        leading: (c, d) => RowThumb(d.list('images').isEmpty ? '' : d.list('images').first),
        filters: [TableFilter('status', 'Status', const {'active': 'Active', 'pending': 'Pending', 'rejected': 'Rejected', 'draft': 'Draft'}, test: (d, v) => d.s('status') == v)],
        emptyIcon: Icons.inventory_2_outlined,
        emptyTitle: 'No products listed',
        columns: [
          Col('Product', flex: 4, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), d.s('brandName'))),
          Col('Price', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('price')), sort: (d) => d.n('price')),
          Col('Stock', flex: 1, numeric: true, text: (d) => '${d.i('stock')}', sort: (d) => d.n('stock')),
          Col('Sold', flex: 1, numeric: true, text: (d) => '${d.i('soldCount')}', sort: (d) => d.n('soldCount')),
          Col('Status', flex: 2, text: (d) => d.s('status'), cell: (c, d) => statusPill(d.s('status', 'active'))),
        ],
      );

  Widget _riders(BuildContext context) => DataView<Doc>(
        id: 'seller_riders_$id',
        source: (q) => liveDocs(Fs.deliveryPartners.where('sellerId', isEqualTo: id).limit(q.limit), label: 'partners_sellerId'),
        rowId: (d) => d.id,
        searchText: (d) => '${d.s('name')} ${d.s('phone')} ${d.s('vehicleNo')}',
        pageSize: 10,
        onTap: (d) => context.go('/delivery/partners/${d.id}'),
        emptyIcon: Icons.delivery_dining_outlined,
        emptyTitle: 'This seller has no own delivery partners',
        columns: [
          Col('Partner', flex: 3, text: (d) => d.s('name'), cell: (c, d) => Row(children: [dotOnline(d.b('online')), const SizedBox(width: 8), Expanded(child: TwoLine(d.s('name'), d.s('phone')))])),
          Col('Vehicle', flex: 2, text: (d) => '${d.s('vehicleType')} ${d.s('vehicleNo')}'),
          Col('Deliveries', flex: 1, numeric: true, text: (d) => '${d.i('completedCount')}', sort: (d) => d.n('completedCount')),
          Col('Status', flex: 2, text: (d) => d.s('status'), cell: (c, d) => statusPill(d.s('status', 'pending'))),
        ],
      );
}

class SellerWalletPage extends StatelessWidget {
  const SellerWalletPage({super.key});
  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Seller wallet',
        subtitle: 'Balances owed to sellers, commission earned and money moved',
        child: StreamBuilder<List<Doc>>(
          stream: liveDocs(Fs.sellers.where('status', isEqualTo: 'approved').limit(1000), label: 'sellers_approved'),
          builder: (context, snap) {
            final list = snap.data ?? const <Doc>[];
            final bal = list.fold<double>(0, (a, d) => a + d.n('balance'));
            final sales = list.fold<double>(0, (a, d) => a + d.n('totalSales'));
            final comm = list.fold<double>(0, (a, d) => a + d.n('totalSales') * d.n('commissionPct', 10) / 100);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minItemWidth: 220, children: [
                KpiCard(label: 'Owed to sellers', value: Fmt.money(bal), icon: Icons.account_balance_wallet_rounded),
                KpiCard(label: 'Gross seller sales', value: Fmt.money(sales), icon: Icons.trending_up_rounded, color: G4MColors.success),
                KpiCard(label: 'Commission earned (est.)', value: Fmt.money(comm), icon: Icons.percent_rounded, color: G4MColors.accent),
                KpiCard(label: 'Active sellers', value: '${list.length}', icon: Icons.storefront_rounded, color: G4MColors.info),
              ]),
              const SizedBox(height: 20),
              DataView<Doc>(
                id: 'seller_wallet',
                source: (q) => liveDocs(Fs.sellers.where('status', isEqualTo: 'approved').limit(q.limit), label: 'sellers_approved'),
                rowId: (d) => d.id,
                searchText: (d) => '${d.s('storeName')} ${d.s('city')}',
                onTap: (d) => context.go('/sellers/${d.id}'),
                leading: (c, d) => Avatar(url: d.s('logo'), name: d.s('storeName'), size: 36),
                defaultSort: 1,
                actions: [
                  RowAction('Transfer funds', Icons.send_rounded, (d) async {
                    final r = await amountDialog(context, 'Transfer to ${d.s('storeName')}', initial: d.n('balance'), confirmLabel: 'Transfer');
                    if (r == null) return;
                    await callApi(() => G4MApi.instance.transferFunds({'toUserId': d.id, 'amount': r.$1, 'note': r.$2, 'role': 'seller'}), success: 'Transfer recorded');
                  }),
                ],
                columns: [
                  Col('Seller', flex: 4, text: (d) => d.s('storeName'), cell: (c, d) => TwoLine(d.s('storeName'), d.s('city'))),
                  Col('Balance', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('balance')), sort: (d) => d.n('balance')),
                  Col('Total sales', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('totalSales')), sort: (d) => d.n('totalSales')),
                  Col('Commission %', flex: 2, numeric: true, text: (d) => '${d.n('commissionPct', 10).toStringAsFixed(1)}%', sort: (d) => d.n('commissionPct')),
                  Col('Commission ₹', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('totalSales') * d.n('commissionPct', 10) / 100), sort: (d) => d.n('totalSales') * d.n('commissionPct', 10)),
                ],
              ),
              const SizedBox(height: 24),
              Text('Transfers to sellers', style: context.tt.titleMedium),
              const SizedBox(height: 10),
              transfersTable(context, 'seller_transfers', Fs.fundTransfers.where('role', isEqualTo: 'seller'), showUser: true),
              const SizedBox(height: 24),
              Text('Seller withdrawals', style: context.tt.titleMedium),
              const SizedBox(height: 10),
              DataView<Doc>(
                id: 'seller_withdrawals_ledger',
                source: (q) => withNames(recent(Fs.withdrawals.where('role', isEqualTo: 'seller'), q.limit, label: 'withdrawals_role_createdAt'), 'userId'),
                rowId: (d) => d.id,
                searchText: (d) => '${d.s('_name')} ${d.s('status')}',
                pageSize: 10,
                onTap: (_) => context.go('/finance/withdrawals'),
                columns: [
                  Col('Seller', flex: 3, text: (d) => d.s('_name')),
                  Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('amount')), sort: (d) => d.n('amount')),
                  Col('Status', flex: 2, text: (d) => d.s('status'), cell: (c, d) => statusPill(d.s('status', 'pending'))),
                  Col('Date', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
                ],
              ),
            ]);
          },
        ),
      );
}

// ═══════════════════════════════ DELIVERY PARTNERS ═══════════════════════════════

Future<void> _reviewPartner(BuildContext context, Doc d, String status) async {
  final verb = switch (status) { 'approved' => 'Approve', 'rejected' => 'Reject', 'suspended' => 'Suspend', _ => status };
  if (!await confirm(context, '$verb ${d.s('name')}?', confirmLabel: verb, danger: status != 'approved')) return;
  await callApi(() => G4MApi.instance.reviewDeliveryPartner({'uid': d.id, 'status': status}), success: 'Partner ${status == 'approved' ? 'approved' : status}');
}

Stream<Map<String, String>> _cityOptions() => optionsOf(Fs.cities, 'name').map((m) => {for (final v in m.values) v: v});
Stream<Map<String, String>> _sellerOptions() => optionsOf(Fs.sellers.where('status', isEqualTo: 'approved'), 'storeName');

List<F> _partnerFields({bool create = false}) => [
      if (create) ...[
        const F.section('Login'),
        const F('email', 'Email', FT.email, required: true),
        F('password', 'Password', FT.password, required: true, validator: (v, _) => '$v'.length < 8 ? 'At least 8 characters' : null),
      ],
      const F.section('Profile'),
      const F('name', 'Full name', FT.text, required: true),
      const F('phone', 'Mobile', FT.text, required: true),
      const F('vehicleType', 'Vehicle', FT.select, options: {'bike': 'Motorbike', 'scooter': 'Scooter', 'bicycle': 'Bicycle', 'ev': 'Electric', 'car': 'Car / Van'}, initial: 'bike'),
      const F('vehicleNo', 'Vehicle number', FT.text, uppercase: true),
      const F('photoUrl', 'Photo', FT.image, folder: 'delivery'),
      const F.section('Service area', help: 'Partners can serve multiple cities (feature 74).'),
      F('cities', 'Cities', FT.multiselect, optionsStream: _cityOptions, required: true),
      const F.section('Fleet & salary'),
      const F('ownerType', 'Managed by', FT.select, options: {'admin': 'Go4Market (admin fleet)', 'seller': 'A seller (own fleet)'}, initial: 'admin', required: true),
      F('sellerId', 'Seller', FT.select, optionsStream: _sellerOptions, visibleIf: (v) => v['ownerType'] == 'seller', required: true),
      const F('salary.type', 'Salary type', FT.select, options: {'per_order': 'Per delivery', 'monthly': 'Monthly fixed'}, initial: 'per_order'),
      const F('salary.amount', 'Salary amount', FT.money, initial: 30),
    ];

Future<void> _addPartner(BuildContext context) => openEditor(
      context,
      title: 'Add delivery partner',
      subtitle: 'Creates the login and an approved partner profile',
      saveLabel: 'Create partner',
      fields: _partnerFields(create: true),
      onSave: (v) async {
        final r = await G4MApi.instance.createStaffUser({'email': v['email'], 'password': v['password'], 'name': v['name'], 'role': 'delivery'});
        final uid = '${r['uid'] ?? ''}';
        if (uid.isEmpty) throw 'createStaffUser did not return a uid';
        final c = cleanValues(v)..remove('password');
        await Fs.deliveryPartners.doc(uid).set({
          ...c,
          'email': '${v['email']}'.trim(),
          if (c['ownerType'] != 'seller') 'sellerId': null,
          'status': 'approved',
          'online': false,
          'cashInHand': 0,
          'balance': 0,
          'rating': 0,
          'completedCount': 0,
          'createdAt': ts,
          'updatedAt': ts,
        }, SetOptions(merge: true));
      },
    );

Future<void> _editPartner(BuildContext context, Doc d) => openEditor(
      context,
      title: 'Edit ${d.s('name')}',
      initial: d.data,
      fields: _partnerFields(),
      onSave: (v) async {
        final c = cleanValues(v)
          ..removeWhere((k, _) => const {'status', 'balance', 'cashInHand', 'online', 'lat', 'lng', 'locationUpdatedAt', 'createdAt', 'completedCount', 'rating'}.contains(k));
        if (c['ownerType'] != 'seller') c['sellerId'] = null;
        await d.ref!.set({...c, 'updatedAt': ts}, SetOptions(merge: true));
      },
    );

Future<void> _settle(BuildContext context, Doc d) async {
  final r = await amountDialog(context, 'Settle cash · ${d.s('name')}', initial: d.n('cashInHand'), max: d.n('cashInHand'), noteLabel: 'Note (optional)', confirmLabel: 'Settle');
  if (r == null) return;
  await callApi(() => G4MApi.instance.settleCash(d.id, r.$1), success: '${Fmt.money(r.$1)} settled');
}

Future<void> _transferTo(BuildContext context, String uid, String name, String role, {double? initial, String note = ''}) async {
  final r = await amountDialog(context, 'Transfer to $name', initial: initial, confirmLabel: 'Transfer');
  if (r == null) return;
  await callApi(() => G4MApi.instance.transferFunds({'toUserId': uid, 'amount': r.$1, 'note': r.$2.isEmpty ? note : r.$2, 'role': role}), success: 'Transfer recorded');
}

List<RowAction<Doc>> _partnerActions(BuildContext context) => [
      RowAction('View details', Icons.open_in_new_rounded, (d) => context.go('/delivery/partners/${d.id}')),
      RowAction('Approve', Icons.check_circle_outline_rounded, (d) => _reviewPartner(context, d, 'approved'), visible: (d) => d.s('status', 'pending') != 'approved'),
      RowAction('Reject', Icons.cancel_outlined, (d) => _reviewPartner(context, d, 'rejected'), visible: (d) => d.s('status', 'pending') == 'pending', danger: true),
      RowAction('Edit / cities / salary', Icons.edit_outlined, (d) => _editPartner(context, d)),
      RowAction('Settle cash', Icons.payments_outlined, (d) => _settle(context, d), visible: (d) => d.n('cashInHand') > 0),
      RowAction('Transfer funds', Icons.send_rounded, (d) => _transferTo(context, d.id, d.s('name'), 'delivery')),
      RowAction('Suspend', Icons.block_rounded, (d) => _reviewPartner(context, d, 'suspended'), visible: (d) => d.s('status') == 'approved', danger: true),
      RowAction('Reactivate', Icons.restart_alt_rounded, (d) => _reviewPartner(context, d, 'approved'), visible: (d) => d.s('status') == 'suspended'),
    ];

class DeliveryPartnersPage extends StatefulWidget {
  const DeliveryPartnersPage({super.key, this.requests = false});
  final bool requests;
  @override
  State<DeliveryPartnersPage> createState() => _DeliveryPartnersPageState();
}

class _DeliveryPartnersPageState extends State<DeliveryPartnersPage> {
  String _fleet = 'all';

  @override
  Widget build(BuildContext context) {
    final requests = widget.requests;
    return PanelPage(
      title: requests ? 'Partner requests' : 'Delivery partners',
      subtitle: requests ? 'Verify new riders before they can take orders' : 'Admin fleet and seller-owned riders across all cities',
      actions: [
        if (!requests)
          Segmented<String>(
            value: _fleet,
            options: const {'all': 'All', 'admin': 'Admin fleet', 'seller': 'Seller fleets'},
            onChanged: (v) => setState(() => _fleet = v),
          ),
        FilledButton.icon(onPressed: () => _addPartner(context), icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: Text(tr('Add partner'))),
      ],
      child: StreamBuilder<Map<String, String>>(
        stream: _cityOptions(),
        builder: (context, cities) => DataView<Doc>(
          key: ValueKey('partners_${requests}_$_fleet'),
          id: requests ? 'partner_requests' : 'partners',
          source: (q) {
            final st = q.filters['status'];
            final base = st == null ? Fs.deliveryPartners : Fs.deliveryPartners.where('status', isEqualTo: st);
            final s = recent(base, q.limit, label: 'deliveryPartners_status_createdAt');
            return _fleet == 'all' ? s : s.map((l) => l.where((d) => d.s('ownerType', 'admin') == _fleet).toList());
          },
          filters: [
            TableFilter('status', 'Status', requests ? const {'pending': 'Pending', 'rejected': 'Rejected'} : const {'approved': 'Approved', 'pending': 'Pending', 'suspended': 'Suspended', 'rejected': 'Rejected'},
                server: true, initial: requests ? 'pending' : null),
            if (!requests) TableFilter('online', 'Availability', const {'on': 'Online', 'off': 'Offline'}, test: (d, v) => d.b('online') == (v == 'on')),
            TableFilter('city', 'City', cities.data ?? const {}, test: (d, v) => d.list('cities').contains(v)),
            TableFilter('vehicle', 'Vehicle', const {'bike': 'Motorbike', 'scooter': 'Scooter', 'bicycle': 'Bicycle', 'ev': 'Electric', 'car': 'Car'}, test: (d, v) => d.s('vehicleType') == v),
          ],
          rowId: (d) => d.id,
          searchText: (d) => '${d.s('name')} ${d.s('phone')} ${d.s('email')} ${d.s('vehicleNo')} ${d.list('cities').join(' ')}',
          onTap: (d) => context.go('/delivery/partners/${d.id}'),
          actions: _partnerActions(context),
          bulkActions: requests
              ? [BulkAction('Approve', Icons.done_all_rounded, (rows) => Future.wait(rows.map((d) => G4MApi.instance.reviewDeliveryPartner({'uid': d.id, 'status': 'approved'}))))]
              : const [],
          leading: (c, d) => Stack(children: [
            Avatar(url: d.s('photoUrl'), name: d.s('name'), size: 40),
            PositionedDirectional(end: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(1.5), decoration: BoxDecoration(color: c.pal.surface, shape: BoxShape.circle), child: dotOnline(d.b('online')))),
          ]),
          emptyIcon: Icons.delivery_dining_outlined,
          emptyTitle: requests ? 'No pending partner requests' : 'No delivery partners yet',
          defaultSort: 8,
          columns: [
            Col('Partner', flex: 3, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name', 'Unnamed'), d.s('phone'))),
            Col('Vehicle', flex: 2, text: (d) => '${Fmt.titleCase(d.s('vehicleType', 'bike'))} ${d.s('vehicleNo')}', cell: (c, d) => TwoLine(Fmt.titleCase(d.s('vehicleType', 'bike')), d.s('vehicleNo'))),
            Col('Cities', flex: 3, text: (d) => d.list('cities').join(', ')),
            Col('Fleet', flex: 2, text: (d) => d.s('ownerType', 'admin'), cell: (c, d) => d.s('ownerType', 'admin') == 'seller'
                ? Tag('Seller', color: G4MColors.accent, icon: Icons.storefront_outlined)
                : Tag('Admin', color: c.pal.accent, icon: Icons.shield_outlined)),
            Col('Done', flex: 1, numeric: true, text: (d) => '${d.i('completedCount')}', sort: (d) => d.n('completedCount')),
            Col('Cash', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('cashInHand')), sort: (d) => d.n('cashInHand'),
                cell: (c, d) => Text(Fmt.money(d.n('cashInHand')), style: TextStyle(fontWeight: FontWeight.w700, color: d.n('cashInHand') > 0 ? G4MColors.warning : null))),
            Col('Balance', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('balance')), sort: (d) => d.n('balance')),
            Col('Status', flex: 2, text: (d) => d.s('status', 'pending'), cell: (c, d) => statusPill(d.s('status', 'pending'))),
            Col('Joined', flex: 2, text: (d) => Fmt.date(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
          ],
          card: (c, d) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(url: d.s('photoUrl'), name: d.s('name'), size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [dotOnline(d.b('online')), const SizedBox(width: 6), Flexible(child: Text(d.s('name'), overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)))]),
                    Text('${Fmt.titleCase(d.s('vehicleType', 'bike'))} · ${d.s('vehicleNo')}', style: TextStyle(color: c.pal.muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                statusPill(d.s('status', 'pending')),
                for (final city in d.list('cities').take(3)) Tag(city, icon: Icons.place_outlined),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: InfoCol('Balance', Fmt.money(d.n('balance')))),
                Expanded(child: InfoCol('Cash in hand', Fmt.money(d.n('cashInHand')))),
                Expanded(child: InfoCol('Deliveries', '${d.i('completedCount')}')),
              ]),
              if (requests && d.s('status', 'pending') == 'pending') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _reviewPartner(context, d, 'rejected'), child: Text(tr('Reject')))),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(onPressed: () => _reviewPartner(context, d, 'approved'), child: Text(tr('Approve')))),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class InfoCol extends StatelessWidget {
  const InfoCol(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        Text(label, style: TextStyle(color: context.pal.muted, fontSize: 11)),
      ]);
}

class DeliveryPartnerDetailPage extends StatelessWidget {
  const DeliveryPartnerDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => StreamBuilder<Doc?>(
        stream: liveDoc(Fs.deliveryPartners.doc(id)),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: ErrorBox(snap.error!));
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(28), child: LoadingBlock());
          final d = snap.data;
          if (d == null) {
            return EmptyState(icon: Icons.delivery_dining_outlined, title: 'Partner not found', action: OutlinedButton(onPressed: () => context.go('/delivery/partners'), child: Text(tr('Back'))));
          }
          final st = d.s('status', 'pending');
          return PanelPage(
            title: d.s('name', 'Partner'),
            subtitle: 'Partner since ${Fmt.date(d.createdAt)}',
            actions: [OutlinedButton.icon(onPressed: () => context.go('/delivery/partners'), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: Text(tr('All partners')))],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DetailHeader(
                title: d.s('name', 'Partner'),
                subtitle: '${d.s('phone')} · ${d.s('email')}',
                image: d.s('photoUrl'),
                chips: [
                  statusPill(st),
                  Tag(d.b('online') ? 'Online' : 'Offline', color: d.b('online') ? G4MColors.success : context.pal.muted, icon: Icons.circle),
                  Tag('${Fmt.titleCase(d.s('vehicleType', 'bike'))} ${d.s('vehicleNo')}', icon: Icons.two_wheeler_rounded),
                  Tag(d.s('ownerType', 'admin') == 'seller' ? 'Seller fleet' : 'Admin fleet', color: G4MColors.info),
                ],
                actions: [
                  if (st != 'approved') FilledButton.icon(onPressed: () => _reviewPartner(context, d, 'approved'), icon: const Icon(Icons.check_rounded, size: 18), label: Text(tr('Approve'))),
                  if (st == 'pending') OutlinedButton(onPressed: () => _reviewPartner(context, d, 'rejected'), child: Text(tr('Reject'))),
                  if (st == 'approved') OutlinedButton(onPressed: () => _reviewPartner(context, d, 'suspended'), child: Text(tr('Suspend'))),
                  if (d.n('cashInHand') > 0) OutlinedButton.icon(onPressed: () => _settle(context, d), icon: const Icon(Icons.payments_outlined, size: 18), label: Text(tr('Settle cash'))),
                  OutlinedButton.icon(onPressed: () => _transferTo(context, d.id, d.s('name'), 'delivery'), icon: const Icon(Icons.send_rounded, size: 18), label: Text(tr('Transfer'))),
                  OutlinedButton.icon(onPressed: () => _editPartner(context, d), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(tr('Edit'))),
                ],
              ),
              const SizedBox(height: 16),
              ResponsiveGrid(minItemWidth: 190, children: [
                KpiCard(label: 'Deliveries completed', value: '${d.i('completedCount')}', icon: Icons.task_alt_rounded, color: G4MColors.success),
                KpiCard(label: 'Earnings balance', value: Fmt.money(d.n('balance')), icon: Icons.account_balance_wallet_rounded),
                KpiCard(label: 'Cash in hand', value: Fmt.money(d.n('cashInHand')), icon: Icons.payments_rounded, color: G4MColors.warning),
                KpiCard(label: 'Rating', value: '${d.n('rating').toStringAsFixed(1)} ★', icon: Icons.star_rounded, color: const Color(0xFFF5A524)),
                KpiCard(
                    label: 'Salary',
                    value: Fmt.money(d.n('salary.amount')),
                    caption: d.s('salary.type', 'per_order') == 'monthly' ? 'per month' : 'per delivery',
                    icon: Icons.badge_rounded,
                    color: G4MColors.info),
              ]),
              const SizedBox(height: 16),
              ResponsiveGrid(minItemWidth: 380, children: [
                SectionCard(
                  title: 'Last known location',
                  subtitle: d.dt('locationUpdatedAt') == null ? null : 'Updated ${Fmt.ago(d.dt('locationUpdatedAt'))}',
                  icon: Icons.my_location_rounded,
                  child: MiniMap(lat: d['lat'] == null ? null : d.n('lat'), lng: d['lng'] == null ? null : d.n('lng'), label: d.s('name')),
                ),
                SectionCard(
                  title: 'Profile',
                  icon: Icons.badge_outlined,
                  child: Column(children: [
                    InfoRow('Cities', d.list('cities').join(', ')),
                    InfoRow('Fleet', d.s('ownerType', 'admin') == 'seller' ? 'Seller-owned' : 'Admin'),
                    if (d.s('sellerId').isNotEmpty) InfoRow('Seller', '', valueWidget: UserNameText(d.s('sellerId'))),
                    InfoRow('Licence', d.s('licenseNo')),
                    InfoRow('Date of birth', Fmt.date(d.dt('dob'))),
                    InfoRow('Bank', [d.s('bank.holder'), d.s('bank.account'), d.s('bank.ifsc')].where((e) => e.isNotEmpty).join(' · ')),
                    InfoRow('UPI', d.s('bank.upi')),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),
              InlineTabs(tabs: [
                ('Deliveries', Icons.delivery_dining_outlined, (c) => ordersTable(c, 'partner_orders_$id', Fs.orders.where('deliveryPartnerId', isEqualTo: id), label: 'orders_deliveryPartnerId_createdAt')),
                ('Cash collections', Icons.payments_outlined, (c) => _cashTable(c, Fs.cashCollections.where('deliveryPartnerId', isEqualTo: id), 'partner_cash_$id', showPartner: false)),
                ('Withdrawals', Icons.outbox_outlined, (c) => withdrawalsTable(c, 'partner_wd_$id', Fs.withdrawals.where('userId', isEqualTo: id))),
                ('Transfers', Icons.swap_horiz_rounded, (c) => transfersTable(c, 'partner_tr_$id', Fs.fundTransfers.where('toUserId', isEqualTo: id))),
              ]),
            ]),
          );
        },
      );
}

Widget _cashTable(BuildContext context, Query<Json> base, String id, {bool showPartner = true}) => DataView<Doc>(
      id: id,
      source: (q) {
        final s = recent(base, q.limit, label: 'cashCollections_createdAt');
        return showPartner ? withNames(s, 'deliveryPartnerId') : s;
      },
      rowId: (d) => d.id,
      searchText: (d) => '${d.s('_name')} ${d.s('orderId')} ${d.s('status')}',
      filters: [TableFilter('status', 'Status', const {'collected': 'Collected', 'settled': 'Settled'}, test: (d, v) => d.s('status') == v)],
      onTap: (d) => d.s('orderId').isEmpty ? null : context.go('/orders/${d.s('orderId')}'),
      emptyIcon: Icons.payments_outlined,
      emptyTitle: 'No cash collections yet',
      columns: [
        if (showPartner) Col('Partner', flex: 3, text: (d) => d.s('_name')),
        Col('Order', flex: 2, text: (d) => d.s('orderNo', d.s('orderId')), cell: (c, d) => Text(d.s('orderNo', d.s('orderId').length > 8 ? '#${d.s('orderId').substring(0, 8)}' : d.s('orderId')), style: TextStyle(color: c.pal.accent, fontWeight: FontWeight.w700))),
        Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('amount')), sort: (d) => d.n('amount')),
        Col('Status', flex: 2, text: (d) => d.s('status', 'collected'), cell: (c, d) => statusPill(d.s('status', 'collected'))),
        Col('Collected', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
        Col('Settled', flex: 2, text: (d) => Fmt.dateTime(d.dt('settledAt'))),
      ],
    );

class CashCollectionPage extends StatelessWidget {
  const CashCollectionPage({super.key});
  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Cash collection',
        subtitle: 'COD cash held by riders and settlements back to Go4Market',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StreamBuilder<List<Doc>>(
            stream: liveDocs(Fs.deliveryPartners.where('cashInHand', isGreaterThan: 0).limit(500), label: 'partners_cashInHand'),
            builder: (context, snap) {
              final list = snap.data ?? const <Doc>[];
              final total = list.fold<double>(0, (a, d) => a + d.n('cashInHand'));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ResponsiveGrid(minItemWidth: 220, children: [
                  KpiCard(label: 'Cash with riders', value: Fmt.money(total), icon: Icons.payments_rounded, color: G4MColors.warning),
                  KpiCard(label: 'Riders holding cash', value: '${list.length}', icon: Icons.two_wheeler_rounded),
                  KpiCard(
                      label: 'Largest balance',
                      value: list.isEmpty ? '—' : Fmt.money(list.map((d) => d.n('cashInHand')).reduce((a, b) => a > b ? a : b)),
                      icon: Icons.priority_high_rounded,
                      color: G4MColors.danger),
                ]),
                const SizedBox(height: 20),
                SectionCard(
                  title: 'Riders to settle',
                  subtitle: 'Collect the cash and record it with Settle',
                  icon: Icons.account_balance_wallet_outlined,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text(snap.hasData ? 'No rider is holding cash right now' : 'Loading…', style: TextStyle(color: context.pal.muted))),
                        )
                      : Column(children: [
                          for (final d in (List.of(list)..sort((a, b) => b.n('cashInHand').compareTo(a.n('cashInHand')))))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Avatar(url: d.s('photoUrl'), name: d.s('name')),
                              title: Text(d.s('name'), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${d.s('phone')} · ${d.list('cities').join(', ')}'),
                              onTap: () => context.go('/delivery/partners/${d.id}'),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(Fmt.money(d.n('cashInHand')), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: G4MColors.warning)),
                                const SizedBox(width: 12),
                                FilledButton(onPressed: () => _settle(context, d), child: Text(tr('Settle'))),
                              ]),
                            ),
                        ]),
                ),
              ]);
            },
          ),
          const SizedBox(height: 20),
          Text('Collection ledger', style: context.tt.titleMedium),
          const SizedBox(height: 10),
          _cashTable(context, Fs.cashCollections, 'cash_collections'),
        ]),
      );
}

class SalaryPage extends StatelessWidget {
  const SalaryPage({super.key});
  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Salary',
        subtitle: 'Salary structure per partner and salary payouts',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DataView<Doc>(
            id: 'salary',
            source: (q) => liveDocs(Fs.deliveryPartners.where('status', isEqualTo: 'approved').limit(q.limit), label: 'partners_approved'),
            rowId: (d) => d.id,
            searchText: (d) => '${d.s('name')} ${d.s('phone')} ${d.s('salary.type')}',
            filters: [
              TableFilter('type', 'Salary type', const {'per_order': 'Per delivery', 'monthly': 'Monthly'}, test: (d, v) => d.s('salary.type', 'per_order') == v),
              TableFilter('fleet', 'Fleet', const {'admin': 'Admin', 'seller': 'Seller'}, test: (d, v) => d.s('ownerType', 'admin') == v),
            ],
            leading: (c, d) => Avatar(url: d.s('photoUrl'), name: d.s('name'), size: 36),
            onTap: (d) => _editSalary(context, d),
            actions: [
              RowAction('Edit salary', Icons.edit_outlined, (d) => _editSalary(context, d)),
              RowAction('Pay salary', Icons.send_rounded, (d) => _paySalary(context, d)),
            ],
            emptyIcon: Icons.badge_outlined,
            emptyTitle: 'No approved partners',
            columns: [
              Col('Partner', flex: 3, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name'), d.s('phone'))),
              Col('Type', flex: 2, text: (d) => d.s('salary.type', 'per_order') == 'monthly' ? 'Monthly' : 'Per delivery'),
              Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('salary.amount')), sort: (d) => d.n('salary.amount')),
              Col('Deliveries', flex: 2, numeric: true, text: (d) => '${d.i('completedCount')}', sort: (d) => d.n('completedCount')),
              Col('Balance', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('balance')), sort: (d) => d.n('balance')),
              Col('Fleet', flex: 2, text: (d) => Fmt.titleCase(d.s('ownerType', 'admin'))),
            ],
          ),
          const SizedBox(height: 24),
          Text('Salary payouts', style: context.tt.titleMedium),
          const SizedBox(height: 10),
          DataView<Doc>(
            id: 'salary_payouts',
            source: (q) => withNames(recent(Fs.fundTransfers.where('role', isEqualTo: 'delivery'), q.limit, label: 'fundTransfers_role_createdAt'), 'toUserId')
                .map((l) => l.where((d) => d.s('note').toLowerCase().startsWith('salary')).toList()),
            rowId: (d) => d.id,
            searchText: (d) => '${d.s('_name')} ${d.s('note')}',
            emptyIcon: Icons.payments_outlined,
            emptyTitle: 'No salary payouts recorded',
            columns: [
              Col('Partner', flex: 3, text: (d) => d.s('_name')),
              Col('Amount', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('amount')), sort: (d) => d.n('amount')),
              Col('Note', flex: 3, text: (d) => d.s('note')),
              Col('Date', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
            ],
          ),
        ]),
      );

  Future<void> _editSalary(BuildContext context, Doc d) => openEditor(
        context,
        title: 'Salary · ${d.s('name')}',
        width: 480,
        initial: {'salary': d['salary'] is Map ? Map<String, dynamic>.from(d['salary'] as Map) : <String, dynamic>{}},
        fields: const [
          F('salary.type', 'Salary type', FT.select, options: {'per_order': 'Per delivery', 'monthly': 'Monthly fixed'}, initial: 'per_order', required: true, wide: true),
          F('salary.amount', 'Amount', FT.money, required: true, wide: true, min: 0),
        ],
        onSave: (v) => d.ref!.set({'salary': {'type': getPath(v, 'salary.type'), 'amount': toNum(getPath(v, 'salary.amount'))}, 'updatedAt': ts}, SetOptions(merge: true)),
      );

  Future<void> _paySalary(BuildContext context, Doc d) async {
    final monthly = d.s('salary.type', 'per_order') == 'monthly';
    final r = await amountDialog(context, 'Pay salary · ${d.s('name')}',
        initial: monthly ? d.n('salary.amount') : null, noteLabel: 'Note', confirmLabel: 'Pay');
    if (r == null) return;
    final note = 'Salary ${monthLabel()}${r.$2.isEmpty ? '' : ' · ${r.$2}'}';
    await callApi(() => G4MApi.instance.transferFunds({'toUserId': d.id, 'amount': r.$1, 'note': note, 'role': 'delivery'}), success: 'Salary paid');
  }
}
