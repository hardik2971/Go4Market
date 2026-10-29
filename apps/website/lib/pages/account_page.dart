import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/shop.dart';
import '../core/web_bridge.dart';
import '../l10n/l10n.dart';
import '../ui/address_form.dart';
import '../ui/gate.dart';
import '../ui/kit.dart';
import '../ui/shell.dart';

List<(String, String, IconData)> _tabs(L l) => [
      ('profile', l.account.profile, Icons.person_outline_rounded),
      ('addresses', l.account.addresses, Icons.location_on_outlined),
      ('notifications', l.account.notifications, Icons.notifications_none_rounded),
      ('refer', l.common.referAndEarn, Icons.card_giftcard_rounded),
      ('membership', l.account.membership, Icons.workspace_premium_outlined),
      ('subscriptions', l.account.subscriptions, Icons.autorenew_rounded),
      ('returns', l.account.returns, Icons.assignment_return_outlined),
      ('request', l.common.requestProduct, Icons.add_task_rounded),
    ];

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, this.params = const {}});
  final Map<String, String> params;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final tabs = _tabs(l);
    final tab = tabs.any((t) => t.$1 == params['tab']) ? params['tab']! : 'profile';
    final label = tabs.firstWhere((t) => t.$1 == tab).$2;
    return SeoMeta(
      title: tab == 'profile' ? l.common.myAccount : label,
      child: PageScroll(children: [
        Contained(
          vertical: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Heading(l.common.myAccount),
            const SizedBox(height: 16),
            SignedInGate(
              next: '/account?tab=$tab',
              icon: Icons.person_outline_rounded,
              title: l.account.signInTitle,
              message: l.account.signInMessage,
              builder: (context) {
                final nav = context.isDesktop
                    ? SizedBox(
                        width: 260,
                        child: Panel(
                          padding: const EdgeInsets.all(10),
                          child: Column(children: [
                            for (final t in tabs)
                              ListTile(
                                selected: t.$1 == tab,
                                selectedTileColor: G4MColors.primarySoft,
                                selectedColor: G4MColors.primaryDeep,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                leading: Icon(t.$3),
                                title: Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                                onTap: () => context.go('/account?tab=${t.$1}'),
                              ),
                            const Divider(),
                            ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              leading: const Icon(Icons.logout_rounded, color: G4MColors.danger),
                              title: Text(l.common.signOut, style: const TextStyle(fontWeight: FontWeight.w700, color: G4MColors.danger)),
                              onTap: () async {
                                await Shop.instance.signOut();
                                if (context.mounted) context.go('/');
                              },
                            ),
                          ]),
                        ),
                      )
                    : SizedBox(
                        height: 44,
                        child: ListView(scrollDirection: Axis.horizontal, children: [
                          for (final t in tabs)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(avatar: Icon(t.$3, size: 18), label: Text(t.$2), selected: t.$1 == tab, onSelected: (_) => context.go('/account?tab=${t.$1}')),
                            ),
                        ]),
                      );
                final Widget body = switch (tab) {
                  'addresses' => const _Addresses(),
                  'notifications' => const _Notifications(),
                  'refer' => const _Refer(),
                  'membership' => const _Membership(),
                  'subscriptions' => const _Subscriptions(),
                  'returns' => const _Returns(),
                  'request' => _ProductRequest(prefill: params['name']),
                  _ => const _Profile(),
                };
                if (!context.isDesktop) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [nav, const SizedBox(height: 18), body]);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [nav, const SizedBox(width: 24), Expanded(child: body)]);
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, [this.sub]);
  final String text;
  final String? sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Heading(text, level: 2, style: const TextStyle(fontSize: 22)),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub!, style: const TextStyle(color: G4MColors.inkMuted))),
        ]),
      );
}

// ------------------------------------------------------------------ profile

class _Profile extends StatefulWidget {
  const _Profile();
  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _init = false, _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final me = shop.profile;
          if (!_init && me != null) {
            _init = true;
            _name.text = me.name == 'Guest' ? '' : me.name;
            _phone.text = me.phone;
          }
          final m = me?.membership ?? const {};
          final l = context.l;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Title(l.account.profile),
            Wrap(spacing: 14, runSpacing: 14, children: [
              _Stat(icon: Icons.account_balance_wallet_outlined, label: l.common.wallet, value: l.money(shop.walletBalance), to: '/wallet'),
              _Stat(icon: Icons.favorite_border_rounded, label: l.common.wishlist, value: l.number(shop.wishlist.length), to: '/wishlist'),
              _Stat(icon: Icons.workspace_premium_outlined, label: l.account.membership, value: m['planId'] == null ? l.account.none : l.account.active, to: '/account?tab=membership'),
            ]),
            const SizedBox(height: 18),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: _name, decoration: InputDecoration(labelText: l.account.fullName)),
                const SizedBox(height: 12),
                TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.account.mobileNumber)),
                const SizedBox(height: 12),
                TextField(enabled: false, controller: TextEditingController(text: me?.email ?? shop.user?.email ?? ''), decoration: InputDecoration(labelText: l.account.email)),
                const SizedBox(height: 16),
                Row(children: [
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await Fs.user(shop.user!.uid).set({'name': _name.text.trim(), 'phone': _phone.text.trim(), 'updatedAt': Fs.now}, SetOptions(merge: true));
                              await shop.user!.updateDisplayName(_name.text.trim());
                              if (context.mounted) toast(context, l.account.profileSaved);
                            } catch (e) {
                              if (context.mounted) toast(context, friendlyError(e), error: true);
                            }
                            if (mounted) setState(() => _busy = false);
                          },
                    child: Text(l.account.saveChanges),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () async {
                      final email = shop.user?.email;
                      if (email == null) return;
                      await AuthRepo.instance.resetPassword(email);
                      if (context.mounted) toast(context, l.account.resetLinkSent(email));
                    },
                    child: Text(l.account.changePassword),
                  ),
                ]),
              ]),
            ),
            if (!context.isDesktop) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: G4MColors.danger),
                onPressed: () async {
                  await shop.signOut();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(l.common.signOut),
              ),
            ],
          ]);
        },
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.to});
  final IconData icon;
  final String label, value, to;
  @override
  Widget build(BuildContext context) => AppLink(
        to: to,
        label: '$label: $value',
        child: HoverLift(
          radius: 20,
          lift: 3,
          child: SizedBox(
            width: 200,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: G4MColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: G4MColors.primaryDeep)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ]),
              ]),
            ),
          ),
        ),
      );
}

// ------------------------------------------------------------------ addresses

class _Addresses extends StatelessWidget {
  const _Addresses();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _Title(context.l.account.savedAddresses)),
          FilledButton.icon(onPressed: () => showAddressForm(context), icon: const Icon(Icons.add_location_alt_outlined), label: Text(context.l.account.addAddress)),
        ]),
        StreamBuilder<List<Address>>(
          stream: live('addr_${Shop.instance.user!.uid}', ShopperRepo.instance.addresses),
          builder: (context, s) => asyncView(s, (l) {
            if (l.isEmpty) return EmptyState(icon: Icons.location_off_outlined, title: context.l.account.noAddresses, message: context.l.account.noAddressesMsg);
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final a in l)
                SizedBox(
                  width: context.isPhone ? double.infinity : 340,
                  child: Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Pill(context.l.account.addressLabel(a.label), bg: G4MColors.primarySoft, fg: G4MColors.primaryDeep),
                        if (a.isDefault) ...[const SizedBox(width: 6), Pill(context.l.account.defaultLabel)],
                        const Spacer(),
                        IconButton(tooltip: context.l.account.editAddress, onPressed: () => showAddressForm(context, existing: a), icon: const Icon(Icons.edit_outlined)),
                        IconButton(
                          tooltip: context.l.account.deleteAddress,
                          onPressed: () async {
                            try {
                              await ShopperRepo.instance.deleteAddress(a.id);
                            } catch (e) {
                              if (context.mounted) toast(context, friendlyError(e), error: true);
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text('${a.name} · ${a.phone}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(a.oneLine, style: const TextStyle(color: G4MColors.inkMuted, height: 1.5)),
                    ]),
                  ),
                ),
            ]);
          }),
        ),
      ]);
}

// ------------------------------------------------------------------ notifications

class _Notifications extends StatelessWidget {
  const _Notifications();
  @override
  Widget build(BuildContext context) {
    final uid = Shop.instance.user!.uid;
    return StreamBuilder<List<AppNotification>>(
      stream: live('inbox_$uid', ShopperRepo.instance.notifications),
      builder: (context, s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _Title(context.l.account.notifications, context.l.account.notificationsSub)),
          if ((s.data ?? const []).any((n) => !n.read))
            TextButton(
              onPressed: () async {
                final b = Fs.db.batch();
                for (final n in s.data!.where((n) => !n.read)) {
                  b.update(Fs.inbox(uid).doc(n.id), {'read': true});
                }
                await b.commit();
              },
              child: Text(context.l.account.markAllRead),
            ),
        ]),
        asyncView(s, (l) {
          if (l.isEmpty) return EmptyState(icon: Icons.notifications_none_rounded, title: context.l.account.allCaughtUp);
          return Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (final n in l)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: n.read ? G4MColors.surfaceAlt : G4MColors.primarySoft,
                    child: Icon(n.type.contains('order') ? Icons.receipt_long_outlined : Icons.campaign_outlined, color: n.read ? G4MColors.inkMuted : G4MColors.primaryDeep),
                  ),
                  title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800)),
                  subtitle: Text('${n.body}\n${context.l.ago(n.createdAt)}'),
                  isThreeLine: true,
                  trailing: n.read ? null : const CircleAvatar(radius: 5, backgroundColor: G4MColors.accent),
                  onTap: () {
                    if (!n.read) Fs.inbox(uid).doc(n.id).update({'read': true});
                    final link = n.payload['link'], oid = n.payload['orderId'];
                    if (link is String && link.startsWith('/')) {
                      context.go(link);
                    } else if (oid != null) {
                      context.go('/orders/$oid');
                    }
                  },
                ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ------------------------------------------------------------------ refer

class _Refer extends StatelessWidget {
  const _Refer();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final code = shop.profile?.referralCode ?? '';
          final link = '$kSiteUrl/signup?ref=$code';
          final s = shop.settings;
          final referee = (s.data['refereeReward'] as num?) ?? 0;
          final l = context.l;
          final t = l.account;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Title(l.common.referAndEarn),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(gradient: G4MColors.accentGradient, borderRadius: BorderRadius.circular(28)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.giveGet(l.money(referee), l.money(s.referralReward)),
                    style: TextStyle(color: G4MColors.ink, fontSize: context.isPhone ? 24 : 32, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                const SizedBox(height: 8),
                Text(t.referBody,
                    style: const TextStyle(color: G4MColors.ink, fontSize: 15.5, height: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.yourCode, style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted, fontWeight: FontWeight.w700)),
                        SelectableText(code.isEmpty ? t.generating : code, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
                      ]),
                    ),
                    IconButton(tooltip: t.copyCode, onPressed: code.isEmpty ? null : () => copyText(context, code, t.codeCopied), icon: const Icon(Icons.copy_rounded)),
                  ]),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: G4MColors.primaryDeep),
                    onPressed: code.isEmpty
                        ? null
                        : () async {
                            final ok = await WebBridge.share(title: t.shareTitle, text: t.shareText(code, l.money(referee)), url: link);
                            if (!ok && context.mounted) copyText(context, link, t.inviteLinkCopied);
                          },
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(t.shareInvite),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                    onPressed: code.isEmpty ? null : () => copyText(context, link, t.inviteLinkCopied),
                    icon: const Icon(Icons.link_rounded),
                    label: Text(t.copyLink),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.howItWorks, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 10),
                Text(t.howItWorksSteps, style: const TextStyle(height: 1.8)),
              ]),
            ),
          ]);
        },
      );
}

// ------------------------------------------------------------------ membership

class _Membership extends StatelessWidget {
  const _Membership();

  Future<void> _join(BuildContext context, Json plan) async {
    final price = (plan['price'] as num?)?.toDouble() ?? 0;
    final l = context.l;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.account.joinPlan('${plan['name']}')),
        content: Text(l.account.joinBody(l.money(price), l.money(Shop.instance.walletBalance))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.account.notNow)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.account.payAndJoin)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      // purchaseMembership (functions/src/wallet) is paid from the wallet; top up first if short.
      await G4MApi.instance.call('purchaseMembership', {'planId': plan['id']});
      if (context.mounted) toast(context, l.account.welcomePlan('${plan['name']}'));
    } catch (e) {
      if (!context.mounted) return;
      final msg = friendlyError(e);
      toast(context, msg, error: true, actionLabel: msg.toLowerCase().contains('wallet') || msg.contains(l.common.wallet) ? l.account.topUp : null, onAction: () => context.go('/wallet'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Shop.instance.profile;
    final m = me?.membership ?? const {};
    DateTime? exp = m['expiresAt'] is Timestamp ? (m['expiresAt'] as Timestamp).toDate() : null;
    final active = m['planId'] != null && (exp == null || exp.isAfter(DateTime.now()));
    final t = context.l.account;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Title(t.membership, t.membershipSub),
      if (active)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Panel(
            color: G4MColors.primarySoft,
            child: Row(children: [
              const Icon(Icons.workspace_premium_rounded, color: G4MColors.primaryDeep, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(exp == null ? t.membershipActive : t.membershipActiveUntil(context.l.date(exp)), style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
        ),
      StreamBuilder<List<Json>>(
        stream: live('plans', Data.membershipPlans),
        builder: (context, s) => asyncView(s, (l) {
          if (l.isEmpty) return EmptyState(icon: Icons.workspace_premium_outlined, title: t.plansSoon);
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (var i = 0; i < l.length; i++)
              SizedBox(
                width: context.isPhone ? double.infinity : 300,
                child: Reveal(
                  index: i,
                  child: HoverLift(
                    radius: 24,
                    color: i == 1 ? const Color(0xFFF2FAF5) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${l[i]['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                        const SizedBox(height: 6),
                        Text.rich(TextSpan(children: [
                          TextSpan(text: context.l.money((l[i]['price'] as num?) ?? 0), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                          TextSpan(text: t.perDays(((l[i]['durationDays'] as num?) ?? 30).toInt()), style: const TextStyle(color: G4MColors.inkMuted)),
                        ])),
                        const SizedBox(height: 12),
                        for (final b in [
                          if (l[i]['freeDelivery'] == true) t.freeDeliveryAll,
                          if (((l[i]['discountPct'] as num?) ?? 0) > 0) t.extraOff(context.l.pct(l[i]['discountPct'] as num)),
                          ...((l[i]['benefits'] as List?) ?? const []).map((e) => '$e'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.check_circle_rounded, size: 18, color: G4MColors.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(b, style: const TextStyle(fontWeight: FontWeight.w600))),
                            ]),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: active && m['planId'] == l[i]['id'] ? null : () => _join(context, l[i]),
                            child: Text(active && m['planId'] == l[i]['id'] ? t.currentPlan : t.joinNow),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ subscriptions

class _Subscriptions extends StatelessWidget {
  const _Subscriptions();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Title(context.l.account.subscriptions, context.l.account.subscriptionsSub),
        StreamBuilder<List<Json>>(
          stream: live('subs_${Shop.instance.user!.uid}', Data.mySubscriptions),
          builder: (context, s) => asyncView(s, (l) {
            final list = l.where((e) => e['status'] != 'cancelled').toList();
            if (list.isEmpty) {
              return EmptyState(
                icon: Icons.autorenew_rounded,
                title: context.l.account.noSubscriptions,
                message: context.l.account.noSubscriptionsMsg,
                action: OutlinedButton(onPressed: () => context.go('/m/grocery'), child: Text(context.l.account.browseGrocery)),
              );
            }
            return FutureBuilder<List<Product>>(
              future: CatalogRepo.instance.productsByIds(list.map((e) => '${e['productId']}').toSet().toList()),
              builder: (context, ps) {
                final byId = {for (final p in ps.data ?? const <Product>[]) p.id: p};
                return Column(children: [
                  for (final sub in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          SizedBox(width: 56, height: 56, child: NetImage(byId[sub['productId']]?.image ?? '', fit: BoxFit.contain)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(byId[sub['productId']]?.name ?? context.l.account.product, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text(
                                context.l.account.subLine(
                                  sub['qty'] is num ? context.l.number(sub['qty'] as num) : '${sub['qty']}',
                                  context.l.account.frequency('${sub['frequency']}'),
                                  sub['nextRunAt'] is Timestamp ? context.l.date((sub['nextRunAt'] as Timestamp).toDate()) : '—',
                                ),
                                style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13),
                              ),
                            ]),
                          ),
                          StatusChip('${sub['status']}', label: context.l.account.status('${sub['status']}')),
                          PopupMenuButton<String>(
                            tooltip: context.l.account.manageSubscription,
                            onSelected: (v) async {
                              try {
                                await Fs.subscriptions.doc('${sub['id']}').update({'status': v, 'updatedAt': Fs.now});
                              } catch (e) {
                                if (context.mounted) toast(context, friendlyError(e), error: true);
                              }
                            },
                            itemBuilder: (_) => [
                              if (sub['status'] == 'active') PopupMenuItem(value: 'paused', child: Text(context.l.account.pause)),
                              if (sub['status'] == 'paused') PopupMenuItem(value: 'active', child: Text(context.l.account.resume)),
                              PopupMenuItem(value: 'cancelled', child: Text(context.l.account.cancelSubscription)),
                            ],
                          ),
                        ]),
                      ),
                    ),
                ]);
              },
            );
          }),
        ),
      ]);
}

// ------------------------------------------------------------------ returns

class _Returns extends StatelessWidget {
  const _Returns();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Title(context.l.account.returnsTitle, context.l.account.returnsSub),
        StreamBuilder<List<Json>>(
          stream: live('returns_${Shop.instance.user!.uid}', Data.myReturns),
          builder: (context, s) => asyncView(s, (l) {
            if (l.isEmpty) return EmptyState(icon: Icons.assignment_return_outlined, title: context.l.account.noReturns);
            return Column(children: [
              for (final r in l)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppLink(
                    to: '/orders/${r['orderId']}',
                    label: context.l.account.returnForOrder,
                    child: Panel(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        const Icon(Icons.assignment_return_outlined, color: G4MColors.primaryDeep),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${context.l.account.items((r['items'] as List?)?.length ?? 0)} · ${r['reason'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (r['refundAmount'] != null) Text(context.l.account.refundTo(context.l.money(r['refundAmount'] as num), context.l.account.refundDest('${r['refundTo'] ?? 'wallet'}')), style: const TextStyle(color: G4MColors.inkMuted)),
                          ]),
                        ),
                        StatusChip('${r['status']}', label: context.l.account.status('${r['status']}')),
                      ]),
                    ),
                  ),
                ),
            ]);
          }),
        ),
      ]);
}

// ------------------------------------------------------------------ product request

class _ProductRequest extends StatefulWidget {
  const _ProductRequest({this.prefill});
  final String? prefill;
  @override
  State<_ProductRequest> createState() => _ProductRequestState();
}

class _ProductRequestState extends State<_ProductRequest> {
  late final _name = TextEditingController(text: widget.prefill);
  final _desc = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Title(context.l.common.requestProduct, context.l.account.requestSub),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: context.l.account.productName)),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 3, decoration: InputDecoration(labelText: context.l.account.productDetails)),
            const SizedBox(height: 14),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (_name.text.trim().length < 2) return toast(context, context.l.account.enterProductName, error: true);
                        setState(() => _busy = true);
                        try {
                          await ShopperRepo.instance.requestProduct(_name.text.trim(), _desc.text.trim());
                          _name.clear();
                          _desc.clear();
                          if (context.mounted) toast(context, context.l.account.requestSent);
                        } catch (e) {
                          if (context.mounted) toast(context, friendlyError(e), error: true);
                        }
                        if (mounted) setState(() => _busy = false);
                      },
                child: Text(context.l.account.sendRequest),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        StreamBuilder<List<Json>>(
          stream: live('preq_${Shop.instance.user!.uid}', Data.myProductRequests),
          builder: (context, s) {
            final l = s.data ?? const <Json>[];
            if (l.isEmpty) return const SizedBox.shrink();
            return Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (final r in l) ListTile(title: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${r['description'] ?? ''}'), trailing: StatusChip('${r['status']}', label: context.l.account.status('${r['status']}'))),
              ]),
            );
          },
        ),
      ]);
}
