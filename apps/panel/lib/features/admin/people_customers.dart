import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt, EmptyState;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/live.dart';
import '../../ui/data_view.dart';
import '../../ui/kit.dart';
import 'people_common.dart';
import 'package:panel/l10n/overrides.dart';

Future<void> adjustWalletDialog(BuildContext context, String uid, String name) async {
  final r = await amountDialog(context, 'Adjust wallet · $name', withType: true, noteLabel: 'Reason (shown in the customer\'s wallet history)', noteRequired: true, confirmLabel: 'Apply');
  if (r == null) return;
  await callApi(() => G4MApi.instance.adjustWallet({'userId': uid, 'amount': r.$1, 'type': r.$3, 'note': r.$2}),
      success: '${r.$3 == 'credit' ? 'Credited' : 'Debited'} ${Fmt.money(r.$1)}');
}

Future<void> _toggleBlock(BuildContext context, Doc d) async {
  final blocked = d.s('status', 'active') == 'blocked';
  final name = d.s('name', d.s('email'));
  if (!await confirm(context, blocked ? 'Unblock $name?' : 'Block $name?',
      message: blocked ? 'They will be able to sign in and order again.' : 'Blocked customers cannot place orders.', danger: !blocked, confirmLabel: blocked ? 'Unblock' : 'Block')) {
    return;
  }
  await runToast(() => d.ref!.update({'status': blocked ? 'active' : 'blocked', 'updatedAt': ts}), success: blocked ? 'Customer unblocked' : 'Customer blocked');
}

Future<void> _changeRole(BuildContext context, Doc d) async {
  var role = d.s('role', 'customer');
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Change role · ${d.s('name', d.s('email'))}'),
        content: SizedBox(
          width: 380,
          child: RadioGroup<String>(
            groupValue: role,
            onChanged: (v) => set(() => role = v!),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final r in const ['customer', 'seller', 'delivery', 'admin'])
                RadioListTile<String>(value: r, title: Text(Fmt.titleCase(r)), subtitle: r == 'admin' ? Text(tr('Full access to this admin panel')) : null),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, role), child: Text(tr('Continue'))),
        ],
      ),
    ),
  );
  if (picked == null || picked == d.s('role', 'customer') || !context.mounted) return;
  if (!await confirm(context, 'Make this user ${Fmt.titleCase(picked)}?', message: 'This changes their custom claim and what they can access.', danger: picked == 'admin', confirmLabel: 'Change role')) return;
  await callApi(() => G4MApi.instance.setUserRole(d.id, picked), success: 'Role changed to $picked');
}

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Customers',
        subtitle: 'Profiles, wallets and account status',
        child: DataView<Doc>(
          id: 'customers',
          source: (q) => liveDocs(
            Fs.users.where('role', isEqualTo: Roles.customer).orderBy('createdAt', descending: true).limit(q.limit),
            fallback: Fs.users.where('role', isEqualTo: Roles.customer).limit(q.limit),
            label: 'users_role_createdAt',
          ),
          rowId: (d) => d.id,
          searchText: (d) => '${d.s('name')} ${d.s('email')} ${d.s('phone')} ${d.s('city')} ${d.s('referralCode')}',
          filters: [
            TableFilter('status', 'Status', const {'active': 'Active', 'blocked': 'Blocked'}, test: (d, v) => d.s('status', 'active') == v),
            TableFilter('wallet', 'Wallet', const {'positive': 'Has balance', 'zero': 'Empty'}, test: (d, v) => v == 'positive' ? d.n('walletBalance') > 0 : d.n('walletBalance') <= 0),
            TableFilter('member', 'Membership', const {'yes': 'Members', 'no': 'Non-members'}, test: (d, v) => (d.s('membership.planId').isNotEmpty) == (v == 'yes')),
          ],
          onTap: (d) => context.go('/customers/${d.id}'),
          leading: (c, d) => Avatar(url: d.s('photoUrl'), name: d.s('name', d.s('email')), size: 38),
          actions: [
            RowAction('View profile', Icons.open_in_new_rounded, (d) => context.go('/customers/${d.id}')),
            RowAction('Adjust wallet', Icons.account_balance_wallet_outlined, (d) => adjustWalletDialog(context, d.id, d.s('name', d.s('email')))),
            RowAction('Block', Icons.block_rounded, (d) => _toggleBlock(context, d), visible: (d) => d.s('status', 'active') != 'blocked', danger: true),
            RowAction('Unblock', Icons.lock_open_rounded, (d) => _toggleBlock(context, d), visible: (d) => d.s('status', 'active') == 'blocked'),
          ],
          bulkActions: [
            BulkAction('Block', Icons.block_rounded, (rows) async {
              final b = Fs.db.batch();
              for (final d in rows) {
                b.update(d.ref!, {'status': 'blocked'});
              }
              await b.commit();
            }, danger: true),
            BulkAction('Unblock', Icons.lock_open_rounded, (rows) async {
              final b = Fs.db.batch();
              for (final d in rows) {
                b.update(d.ref!, {'status': 'active'});
              }
              await b.commit();
            }),
          ],
          defaultSort: 5,
          emptyIcon: Icons.people_outline_rounded,
          emptyTitle: 'No customers yet',
          columns: [
            Col('Customer', flex: 4, text: (d) => d.s('name'), cell: (c, d) => TwoLine(d.s('name', 'Customer'), d.s('email'))),
            Col('Phone', flex: 2, text: (d) => d.s('phone')),
            Col('City', flex: 2, text: (d) => d.s('city')),
            Col('Wallet', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('walletBalance')), sort: (d) => d.n('walletBalance'), csv: (d) => d.n('walletBalance').toStringAsFixed(2)),
            Col('Status', flex: 2, text: (d) => d.s('status', 'active'), cell: (c, d) => statusPill(d.s('status', 'active'))),
            Col('Joined', flex: 2, text: (d) => Fmt.date(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
          ],
          card: (c, d) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(url: d.s('photoUrl'), name: d.s('name', d.s('email')), size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.s('name', 'Customer'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(d.s('email'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.pal.muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                statusPill(d.s('status', 'active')),
                const Spacer(),
                Icon(Icons.account_balance_wallet_outlined, size: 16, color: c.pal.muted),
                const SizedBox(width: 4),
                Text(Fmt.money(d.n('walletBalance')), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              Text('${d.s('phone').isEmpty ? 'No phone' : d.s('phone')} · Joined ${Fmt.date(d.createdAt)}', style: TextStyle(color: c.pal.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => StreamBuilder<Doc?>(
        stream: liveDoc(Fs.user(id)),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: ErrorBox(snap.error!));
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(28), child: LoadingBlock());
          final d = snap.data;
          if (d == null) {
            return EmptyState(icon: Icons.person_off_outlined, title: 'User not found', action: OutlinedButton(onPressed: () => context.go('/customers'), child: Text(tr('Back'))));
          }
          final name = d.s('name', d.s('email'));
          final blocked = d.s('status', 'active') == 'blocked';
          return PanelPage(
            title: name,
            subtitle: 'Customer since ${Fmt.date(d.createdAt)}',
            actions: [OutlinedButton.icon(onPressed: () => context.go('/customers'), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: Text(tr('All customers')))],
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DetailHeader(
                title: name,
                subtitle: [d.s('email'), d.s('phone')].where((e) => e.isNotEmpty).join(' · '),
                image: d.s('photoUrl'),
                chips: [
                  statusPill(d.s('status', 'active')),
                  Tag(Fmt.titleCase(d.s('role', 'customer')), color: G4MColors.info, icon: Icons.verified_user_outlined),
                  if (d.s('city').isNotEmpty) Tag(d.s('city'), icon: Icons.place_outlined),
                  if (d.s('membership.planId').isNotEmpty) const Tag('Member', color: G4MColors.accent, icon: Icons.workspace_premium_rounded),
                ],
                actions: [
                  FilledButton.icon(
                      onPressed: () => adjustWalletDialog(context, id, name), icon: const Icon(Icons.account_balance_wallet_outlined, size: 18), label: Text(tr('Adjust wallet'))),
                  OutlinedButton.icon(
                    onPressed: () => _toggleBlock(context, d),
                    icon: Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 18),
                    label: Text(blocked ? 'Unblock' : 'Block'),
                  ),
                  OutlinedButton.icon(onPressed: () => _changeRole(context, d), icon: const Icon(Icons.manage_accounts_outlined, size: 18), label: Text(tr('Change role'))),
                ],
              ),
              const SizedBox(height: 16),
              ResponsiveGrid(minItemWidth: 200, children: [
                KpiCard(label: 'Wallet balance', value: Fmt.money(d.n('walletBalance')), icon: Icons.account_balance_wallet_rounded),
                FutureBuilder<int>(
                  future: Fs.orders.where('userId', isEqualTo: id).count().get().then((s) => s.count ?? 0),
                  builder: (c, s) => KpiCard(label: 'Orders', value: s.hasData ? '${s.data}' : '…', icon: Icons.receipt_long_rounded, color: G4MColors.info),
                ),
                KpiCard(label: 'Referral code', value: d.s('referralCode', '—'), icon: Icons.card_giftcard_rounded, color: G4MColors.accent, caption: d.s('referredBy').isEmpty ? null : 'Referred by ${d.s('referredBy')}'),
                KpiCard(label: 'Recently viewed', value: '${d.list('recentlyViewed').length}', icon: Icons.history_rounded, color: G4MColors.success),
              ]),
              const SizedBox(height: 20),
              InlineTabs(tabs: [
                ('Orders', Icons.receipt_long_outlined, (c) => ordersTable(c, 'cust_orders_$id', Fs.orders.where('userId', isEqualTo: id), label: 'orders_userId_createdAt')),
                ('Wallet', Icons.account_balance_wallet_outlined, (c) => _walletTab(c)),
                ('Addresses', Icons.home_work_outlined, (c) => _addresses(c)),
                ('Wishlist', Icons.favorite_outline_rounded, (c) => _productList(c, Fs.wishlist(id), 'Wishlist is empty')),
                ('Cart', Icons.shopping_cart_outlined, (c) => _productList(c, Fs.cart(id), 'Cart is empty', cart: true)),
                ('Membership', Icons.workspace_premium_outlined, (c) => _membership(c, d)),
              ]),
            ]),
          );
        },
      );

  Widget _walletTab(BuildContext context) => DataView<Doc>(
        id: 'cust_wallet_$id',
        source: (q) => recent(Fs.walletTransactions.where('userId', isEqualTo: id), q.limit, label: 'walletTransactions_userId_createdAt'),
        rowId: (d) => d.id,
        searchText: (d) => '${d.s('reason')} ${d.s('refId')} ${d.s('note')}',
        pageSize: 10,
        emptyIcon: Icons.account_balance_wallet_outlined,
        emptyTitle: 'No wallet activity',
        columns: [
          Col('Type', flex: 2, text: (d) => d.s('type'), cell: (c, d) => statusPill(d.s('type', 'credit'))),
          Col('Reason', flex: 2, text: (d) => Fmt.titleCase(d.s('reason'))),
          Col('Amount', flex: 2, numeric: true, text: (d) => '${d.s('type') == 'debit' ? '−' : '+'}${Fmt.money(d.n('amount'))}', sort: (d) => d.n('amount')),
          Col('Balance after', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('balanceAfter'))),
          Col('Reference', flex: 3, text: (d) => d.s('note', d.s('refId'))),
          Col('Date', flex: 2, text: (d) => Fmt.dateTime(d.createdAt), sort: (d) => d.createdAt?.millisecondsSinceEpoch ?? 0),
        ],
      );

  Widget _addresses(BuildContext context) => StreamBuilder<List<Doc>>(
        stream: liveDocs(Fs.addresses(id)),
        builder: (context, s) {
          if (s.hasError) return ErrorBox(s.error!);
          final l = s.data;
          if (l == null) return const LoadingBlock(rows: 2);
          if (l.isEmpty) return const EmptyState(icon: Icons.home_work_outlined, title: 'No saved addresses');
          return ResponsiveGrid(minItemWidth: 280, children: [
            for (final a in l)
              SectionCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Tag(a.s('label', 'Home'), icon: Icons.place_outlined, color: context.pal.accent),
                    const Spacer(),
                    if (a.b('isDefault')) const Tag('Default', color: G4MColors.success),
                  ]),
                  const SizedBox(height: 10),
                  Text(a.s('name'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text([a.s('line1'), a.s('line2'), a.s('landmark'), a.s('city'), a.s('state'), a.s('pincode')].where((e) => e.isNotEmpty).join(', '),
                      style: TextStyle(color: context.pal.muted, fontSize: 13)),
                  if (a.s('phone').isNotEmpty) Text(a.s('phone'), style: TextStyle(color: context.pal.muted, fontSize: 13)),
                ]),
              ),
          ]);
        },
      );

  Widget _productList(BuildContext context, CollectionReference<Json> col, String empty, {bool cart = false}) => FutureBuilder<(List<Doc>, Map<String, Product>)>(
        future: () async {
          final docs = (await col.get()).docs.map(Doc.fromSnap).toList();
          final ids = docs.map((d) => cart ? d.s('productId') : d.id).where((e) => e.isNotEmpty).toSet().toList();
          final prods = await CatalogRepo.instance.productsByIds(ids);
          return (docs, {for (final p in prods) p.id: p});
        }(),
        builder: (context, s) {
          if (s.hasError) return ErrorBox(s.error!);
          if (!s.hasData) return const LoadingBlock(rows: 3);
          final (docs, prods) = s.data!;
          if (docs.isEmpty) return EmptyState(icon: cart ? Icons.shopping_cart_outlined : Icons.favorite_outline_rounded, title: empty);
          final total = cart ? docs.fold<double>(0, (a, d) => a + (prods[d.s('productId')]?.price ?? 0) * d.i('qty', 1)) : 0.0;
          return SectionCard(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(children: [
              for (final d in docs)
                Builder(builder: (context) {
                  final p = prods[cart ? d.s('productId') : d.id];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: RowThumb(p?.image ?? ''),
                    title: Text(p?.name ?? 'Product removed', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([if (p != null) Fmt.money(p.price), if (cart) 'Qty ${d.i('qty', 1)}', 'Added ${Fmt.ago(d.dt('addedAt'))}'].join(' · ')),
                    onTap: p == null ? null : () => context.go('/catalog/products/${p.id}/edit'),
                  );
                }),
              if (cart) ...[
                const Divider(),
                InfoRow('Cart value', Fmt.money(total), bold: true),
              ],
            ]),
          );
        },
      );

  Widget _membership(BuildContext context, Doc d) {
    final planId = d.s('membership.planId');
    if (planId.isEmpty) return const EmptyState(icon: Icons.workspace_premium_outlined, title: 'Not a member', message: 'This customer has no active membership plan.');
    final exp = d.dt('membership.expiresAt');
    return StreamBuilder<Doc?>(
      stream: liveDoc(Fs.membershipPlans.doc(planId)),
      builder: (context, s) => SectionCard(
        title: s.data?.s('name') ?? 'Membership',
        icon: Icons.workspace_premium_rounded,
        child: Column(children: [
          InfoRow('Plan', s.data?.s('name') ?? planId),
          InfoRow('Price', s.data == null ? '' : Fmt.money(s.data!.n('price'))),
          InfoRow('Expires', Fmt.date(exp)),
          InfoRow('Status', '', valueWidget: Align(alignment: AlignmentDirectional.centerStart, child: statusPill(exp != null && exp.isAfter(DateTime.now()) ? 'active' : 'expired'))),
          InfoRow('Benefits', s.data?.list('benefits').join(' · ') ?? ''),
        ]),
      ),
    );
  }
}

class WishlistsPage extends StatelessWidget {
  const WishlistsPage({super.key});

  Stream<List<Doc>> _source(int limit) => liveDocs(Fs.db.collectionGroup('wishlist').limit(limit), label: 'collectionGroup_wishlist').asyncMap((list) async {
        final pids = list.map((d) => d.id).toSet().toList();
        final prods = {for (final p in await CatalogRepo.instance.productsByIds(pids)) p.id: p};
        await Future.wait(list.map((d) async {
          final uid = d.ref?.parent.parent?.id ?? '';
          d.data['_uid'] = uid;
          d.data['_user'] = await UserNames.of(uid);
          final p = prods[d.id];
          d.data['_product'] = p?.name ?? 'Removed product';
          d.data['_image'] = p?.image ?? '';
          d.data['_price'] = p?.price ?? 0;
        }));
        return list;
      });

  @override
  Widget build(BuildContext context) => PanelPage(
        title: 'Wishlists',
        subtitle: 'What customers are saving for later',
        child: StreamBuilder<List<Doc>>(
          stream: _source(1000),
          builder: (context, snap) {
            final all = snap.data ?? const <Doc>[];
            final counts = <String, (int, Doc)>{};
            for (final d in all) {
              final c = counts[d.id];
              counts[d.id] = ((c?.$1 ?? 0) + 1, d);
            }
            final top = counts.values.toList()..sort((a, b) => b.$1.compareTo(a.$1));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ResponsiveGrid(minItemWidth: 220, children: [
                KpiCard(label: 'Wishlisted items', value: '${all.length}', icon: Icons.favorite_rounded, color: const Color(0xFFDB2777)),
                KpiCard(label: 'Customers with wishlists', value: '${all.map((d) => d.s('_uid')).toSet().length}', icon: Icons.people_alt_rounded),
                KpiCard(label: 'Distinct products', value: '${counts.length}', icon: Icons.inventory_2_rounded, color: G4MColors.info),
              ]),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Most wishlisted products',
                subtitle: 'Good candidates for offers and restocks',
                icon: Icons.trending_up_rounded,
                child: top.isEmpty
                    ? Padding(padding: const EdgeInsets.all(12), child: Text(snap.hasData ? 'No wishlists yet' : 'Loading…', style: TextStyle(color: context.pal.muted)))
                    : Column(children: [
                        for (final (i, t) in top.take(8).indexed)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Row(mainAxisSize: MainAxisSize.min, children: [
                              SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: context.pal.muted))),
                              RowThumb(t.$2.s('_image'), size: 38),
                            ]),
                            title: Text(t.$2.s('_product'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(Fmt.money(t.$2.n('_price'))),
                            trailing: Tag('${t.$1} saves', color: const Color(0xFFDB2777), icon: Icons.favorite_rounded),
                            onTap: () => context.go('/catalog/products/${t.$2.id}/edit'),
                          ),
                      ]),
              ),
              const SizedBox(height: 16),
              DataView<Doc>(
                id: 'wishlists',
                source: (q) => _source(q.limit),
                rowId: (d) => d.ref?.path ?? d.id,
                searchText: (d) => '${d.s('_user')} ${d.s('_product')}',
                onTap: (d) => context.go('/customers/${d.s('_uid')}'),
                leading: (c, d) => RowThumb(d.s('_image')),
                emptyIcon: Icons.favorite_outline_rounded,
                emptyTitle: 'No wishlisted products yet',
                defaultSort: 3,
                columns: [
                  Col('Product', flex: 4, text: (d) => d.s('_product')),
                  Col('Price', flex: 2, numeric: true, text: (d) => Fmt.money(d.n('_price')), sort: (d) => d.n('_price')),
                  Col('Customer', flex: 3, text: (d) => d.s('_user')),
                  Col('Added', flex: 2, text: (d) => Fmt.dateTime(d.dt('addedAt')), sort: (d) => d.dt('addedAt')?.millisecondsSinceEpoch ?? 0),
                ],
              ),
            ]);
          },
        ),
      );
}
