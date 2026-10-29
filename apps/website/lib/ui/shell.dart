import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/data.dart';
import '../core/shop.dart';
import '../core/web_bridge.dart';
import '../l10n/l10n.dart';
import 'kit.dart';
import 'voice.dart' deferred as voice;

const kSellerUrl = 'https://go4market-seller.web.app';
const kDeliveryUrl = 'https://go4market-delivery.web.app';
const kPlayUrl = 'https://play.google.com/store/apps/details?id=com.go4market.customer';

IconData moduleIcon(String id) => switch (id) {
      'grocery' => Icons.local_grocery_store_rounded,
      'pharmacy' => Icons.medication_rounded,
      'food' => Icons.restaurant_rounded,
      'ecommerce' => Icons.shopping_bag_rounded,
      _ => Icons.storefront_rounded,
    };

Color moduleColor(String? id) => G4MColors.fromHex(id == null ? null : Shop.instance.module(id)?.themeColor);

class SiteShell extends StatefulWidget {
  const SiteShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  State<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends State<SiteShell> {
  final _scrolled = ValueNotifier(false);
  StreamSubscription? _popupSub;

  @override
  void initState() {
    super.initState();
    if (WebBridge.session('g4m_popup_seen') == null) {
      _popupSub = live('popups', Data.webPopups).listen((l) {
        if (l.isEmpty || !mounted || WebBridge.session('g4m_popup_seen') != null) return;
        WebBridge.setSession('g4m_popup_seen', '1');
        _popupSub?.cancel();
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) showPromoPopup(context, l.first);
        });
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _popupSub?.cancel();
    super.dispose();
  }

  int get _navIndex {
    final l = widget.location;
    if (l.startsWith('/categories') || l.startsWith('/c/')) return 1;
    if (l.startsWith('/cart')) return 2;
    if (l.startsWith('/orders')) return 3;
    if (l.startsWith('/account') || l.startsWith('/login') || l.startsWith('/wallet') || l.startsWith('/wishlist')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final c = context.l.common;
    return Scaffold(
      drawer: phone ? SiteDrawer(location: widget.location) : null,
      body: Column(children: [
        ListenableBuilder(
          listenable: Shop.instance,
          builder: (context, _) => !Shop.instance.settings.maintenance
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  color: G4MColors.accentSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    context.l.common.maintenance,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kAccentInk, fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                ),
        ),
        ValueListenableBuilder(valueListenable: _scrolled, builder: (_, s, _) => SiteHeader(scrolled: s, location: widget.location)),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.depth == 0 && n.metrics.axis == Axis.vertical) _scrolled.value = n.metrics.pixels > 8;
              return false;
            },
            child: widget.child,
          ),
        ),
      ]),
      bottomNavigationBar: phone
          ? ListenableBuilder(
              listenable: Shop.instance,
              builder: (context, _) => NavigationBar(
                height: 66,
                selectedIndex: _navIndex,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (i) => context.go(const ['/', '/categories', '/cart', '/orders', '/account'][i]),
                destinations: [
                  NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: c.navHome),
                  NavigationDestination(icon: const Icon(Icons.grid_view_outlined), selectedIcon: const Icon(Icons.grid_view_rounded), label: c.navBrowse),
                  NavigationDestination(
                    icon: Badge(isLabelVisible: Shop.instance.cartCount > 0, label: Text(context.l.number(Shop.instance.cartCount)), child: const Icon(Icons.shopping_bag_outlined)),
                    selectedIcon: const Icon(Icons.shopping_bag_rounded),
                    label: c.navCart,
                  ),
                  NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long_rounded), label: c.navOrders),
                  NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: c.navAccount),
                ],
              ),
            )
          : null,
    );
  }
}

// ------------------------------------------------------------------ header

class SiteHeader extends StatelessWidget {
  const SiteHeader({super.key, required this.scrolled, required this.location});
  final bool scrolled;
  final String location;

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final c = context.l.common;
    return AnimatedContainer(
      duration: G4MMotion.standard,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: scrolled ? .97 : 1),
        border: Border(bottom: BorderSide(color: scrolled ? Colors.transparent : G4MColors.line)),
        boxShadow: scrolled ? const [BoxShadow(color: Color(0x140A4A33), blurRadius: 24, offset: Offset(0, 6))] : const [],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Contained(
            child: SizedBox(
              height: phone ? 60 : 76,
              child: Row(children: [
                if (phone) ...[
                  Builder(
                    builder: (ctx) => IconButton(
                      tooltip: c.openMenu,
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      icon: const Icon(Icons.menu_rounded, color: G4MColors.ink),
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
                AppLink(to: '/', label: c.homeLink, child: G4MWordmark(size: phone ? 30 : 38)),
                if (!phone) ...[const SizedBox(width: 20), const LocationChip()],
                if (!phone) ...[const SizedBox(width: 20), const Expanded(child: SearchBox())] else const Spacer(),
                const SizedBox(width: 12),
                if (phone) const LocationChip(compact: true),
                if (!phone) ...[
                  const LanguageButton(),
                  _IconNav(icon: Icons.favorite_border_rounded, label: c.wishlist, to: '/wishlist'),
                  _IconNav(icon: Icons.receipt_long_outlined, label: c.myOrders, to: '/orders'),
                  const SizedBox(width: 6),
                  const CartButton(),
                  const SizedBox(width: 10),
                  const AccountButton(),
                ] else
                  const _IconCart(),
              ]),
            ),
          ),
          if (phone)
            const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 10), child: SearchBox())
          else
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: G4MColors.line))),
              child: Contained(child: SizedBox(height: 54, child: ModuleBar(location: location))),
            ),
        ]),
      ),
    );
  }
}

class ModuleBar extends StatelessWidget {
  const ModuleBar({super.key, required this.location, this.padding = EdgeInsets.zero});
  final String location;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final mods = Shop.instance.modules;
          final current = location.startsWith('/m/') ? location.split('/')[2] : (location == '/' ? '' : null);
          return Row(children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: padding,
                children: [
                  _ModulePill(label: context.l.common.all, icon: Icons.auto_awesome_rounded, to: '/', color: G4MColors.primary, selected: current == ''),
                  for (final m in mods)
                    _ModulePill(
                      label: m.name,
                      icon: moduleIcon(m.id),
                      to: '/m/${m.id}',
                      color: G4MColors.fromHex(m.themeColor),
                      selected: current == m.id,
                    ),
                ],
              ),
            ),
            if (!context.isPhone && context.w > 1180) ...[
              TextLink(context.l.common.blog, to: '/blog', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: G4MColors.ink)),
              const SizedBox(width: 22),
              TextLink(context.l.common.helpFaq, to: '/faq', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: G4MColors.ink)),
              const SizedBox(width: 22),
              TextLink(context.l.common.sellOnGo4Market, to: kSellerUrl, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kAccentInk), hoverColor: kAccentInk),
            ],
          ]);
        },
      );
}

class _ModulePill extends StatefulWidget {
  const _ModulePill({required this.label, required this.icon, required this.to, required this.color, required this.selected});
  final String label;
  final IconData icon;
  final String to;
  final Color color;
  final bool selected;
  @override
  State<_ModulePill> createState() => _ModulePillState();
}

class _ModulePillState extends State<_ModulePill> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final sel = widget.selected;
    // Darken light module colours so white text keeps AA contrast.
    final fill = c.computeLuminance() > .2 ? Color.lerp(c, Colors.black, .35)! : c;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Center(
        child: MouseRegion(
          onEnter: (_) => setState(() => _h = true),
          onExit: (_) => setState(() => _h = false),
          child: AppLink(
            to: widget.to,
            label: context.l.common.storeOf(widget.label),
            child: AnimatedContainer(
              duration: G4MMotion.standard,
              curve: G4MMotion.curve,
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: sel ? fill : (_h ? c.withValues(alpha: .1) : Colors.white),
                borderRadius: BorderRadius.circular(G4MRadius.pill),
                border: Border.all(color: sel ? fill : (_h ? c.withValues(alpha: .4) : G4MColors.line)),
                boxShadow: sel ? [BoxShadow(color: fill.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 6))] : const [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, size: 18, color: sel ? Colors.white : fill),
                const SizedBox(width: 7),
                Text(widget.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: sel ? Colors.white : G4MColors.ink)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconNav extends StatelessWidget {
  const _IconNav({required this.icon, required this.label, required this.to});
  final IconData icon;
  final String label;
  final String to;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: AppLink(
          to: to,
          label: label,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            child: Icon(icon, color: G4MColors.ink, size: 24),
          ),
        ),
      );
}

/// Cart pill with an animated badge bump whenever something is added.
class CartButton extends StatelessWidget {
  const CartButton({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final n = Shop.instance.cartCount;
          return AppLink(
            to: '/cart',
            label: context.l.common.cartItems(n),
            child: Container(
              height: 46,
              padding: const EdgeInsetsDirectional.only(start: 14, end: 16),
              decoration: BoxDecoration(color: G4MColors.primaryDeep, borderRadius: BorderRadius.circular(G4MRadius.pill)),
              child: Row(children: [
                _Bump(child: Badge(
                  isLabelVisible: n > 0,
                  backgroundColor: G4MColors.accent,
                  textColor: G4MColors.ink,
                  label: Text(context.l.number(n), style: const TextStyle(fontWeight: FontWeight.w800)),
                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
                )),
                const SizedBox(width: 10),
                Text(context.l.common.navCart, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
            ),
          );
        },
      );
}

class _IconCart extends StatelessWidget {
  const _IconCart();
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final n = Shop.instance.cartCount;
          return AppLink(
            to: '/cart',
            label: context.l.common.cartItems(n),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: _Bump(
                  child: Badge(
                    isLabelVisible: n > 0,
                    backgroundColor: G4MColors.accent,
                    textColor: G4MColors.ink,
                    label: Text(context.l.number(n), style: const TextStyle(fontWeight: FontWeight.w800)),
                    child: const Icon(Icons.shopping_bag_outlined, color: G4MColors.ink, size: 26),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _Bump extends StatelessWidget {
  const _Bump({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: Shop.instance.cartBump,
        builder: (context, v, _) => TweenAnimationBuilder<double>(
          key: ValueKey(v),
          tween: Tween(begin: v == 0 || context.reduceMotion ? 1 : 1.45, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.elasticOut,
          builder: (_, s, c) => Transform.scale(scale: s, child: c),
          child: child,
        ),
      );
}

class AccountButton extends StatelessWidget {
  const AccountButton({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final c = context.l.common;
          if (!shop.signedIn) {
            return OutlinedButton.icon(
              onPressed: () => context.go('/login'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), shape: const StadiumBorder()),
              icon: const Icon(Icons.person_outline_rounded, size: 20),
              label: Text(c.signIn),
            );
          }
          final name = shop.profile?.data['name'] as String? ?? shop.user?.displayName ?? c.navAccount;
          return PopupMenuButton<String>(
            tooltip: c.accountMenu,
            offset: const Offset(0, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(G4MRadius.md)),
            onSelected: (v) async {
              if (v == 'out') {
                await shop.signOut();
                if (context.mounted) context.go('/');
              } else {
                context.go(v);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(c.hi(name.split(' ').first), style: const TextStyle(fontWeight: FontWeight.w800, color: G4MColors.ink))),
              const PopupMenuDivider(),
              _mi('/account', Icons.person_outline_rounded, c.myAccount),
              _mi('/orders', Icons.receipt_long_outlined, c.myOrders),
              _mi('/wallet', Icons.account_balance_wallet_outlined, '${c.wallet}  ·  ${context.l.money(shop.walletBalance)}'),
              _mi('/wishlist', Icons.favorite_border_rounded, c.wishlist),
              _mi('/account?tab=refer', Icons.card_giftcard_rounded, c.referAndEarn),
              const PopupMenuDivider(),
              _mi('out', Icons.logout_rounded, c.signOut),
            ],
            child: Container(
              height: 46,
              padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
              decoration: BoxDecoration(border: Border.all(color: G4MColors.line), borderRadius: BorderRadius.circular(G4MRadius.pill)),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: G4MColors.primarySoft,
                  child: Text(name.isEmpty ? 'G' : name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: G4MColors.primaryDeep)),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(name.split(' ').first, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.expand_more_rounded, size: 18),
              ]),
            ),
          );
        },
      );

  PopupMenuItem<String> _mi(String v, IconData i, String t) =>
      PopupMenuItem(value: v, child: Row(children: [Icon(i, size: 20, color: G4MColors.primaryDeep), const SizedBox(width: 12), Text(t)]));
}

// ------------------------------------------------------------------ search + voice

class SearchBox extends StatefulWidget {
  const SearchBox({super.key, this.initial = '', this.autofocus = false, this.onSubmit});
  final String initial;
  final bool autofocus;
  final ValueChanged<String>? onSubmit;
  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final _c = TextEditingController(text: widget.initial);
  List<String> get _hints => context.l.common.searchHints;
  int _hint = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _c.text.isEmpty) setState(() => _hint = (_hint + 1) % _hints.length);
    });
  }

  @override
  void didUpdateWidget(SearchBox old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial) _c.text = widget.initial;
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _go(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    if (widget.onSubmit != null) return widget.onSubmit!(t);
    context.go('/search?q=${Uri.encodeQueryComponent(t)}');
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: TextField(
          controller: _c,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onSubmitted: _go,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: _hints[_hint],
            filled: true,
            fillColor: const Color(0xFFF2F7F4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            prefixIcon: const Icon(Icons.search_rounded, color: G4MColors.inkMuted),
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: VoiceButton(onResult: (t) {
                _c.text = t;
                _go(t);
              }),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(G4MRadius.pill), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(G4MRadius.pill), borderSide: const BorderSide(color: Color(0xFFE3EDE7))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(G4MRadius.pill), borderSide: const BorderSide(color: G4MColors.primary, width: 1.6)),
          ),
        ),
      );
}

/// Microphone button. Opens a listening sheet and returns the final transcript.
class VoiceButton extends StatelessWidget {
  const VoiceButton({super.key, required this.onResult});
  final ValueChanged<String> onResult;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: context.l.common.searchByVoice,
        icon: const Icon(Icons.mic_none_rounded, color: G4MColors.primary),
        onPressed: () async {
          await voice.loadLibrary();
          if (!context.mounted) return;
          final t = await showDialog<String>(context: context, builder: (_) => voice.VoiceDialog());
          if (t != null && t.trim().isNotEmpty) onResult(t.trim());
        },
      );
}

// ------------------------------------------------------------------ location

class LocationChip extends StatelessWidget {
  const LocationChip({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: Shop.instance.city,
        builder: (context, city, _) {
          void open() => showCityPicker(context);
          if (compact) {
            return IconButton(tooltip: city == null ? context.l.common.chooseCity : context.l.common.deliveringTo(city), onPressed: open, icon: const Icon(Icons.location_on_outlined));
          }
          return Semantics(
            button: true,
            label: city == null ? context.l.common.chooseDeliveryCity : context.l.common.deliveringToChange(city),
            excludeSemantics: true,
            child: Pressable(
              onTap: open,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: G4MColors.line), borderRadius: BorderRadius.circular(G4MRadius.md)),
                child: Row(children: [
                  const Icon(Icons.location_on_rounded, color: G4MColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.l.common.deliverTo, style: const TextStyle(fontSize: 11.5, color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
                    Text(city ?? context.l.common.selectCity, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ]),
              ),
            ),
          );
        },
      );
}

Future<void> showCityPicker(BuildContext context) => showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StreamBuilder<List<Json>>(
              stream: live('cities', Data.cities),
              builder: (ctx, s) {
                final cities = s.data ?? const [];
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ctx.l.common.whereDeliver, style: ctx.tt.titleLarge),
                  const SizedBox(height: 6),
                  Text(ctx.l.common.whereDeliverSub, style: const TextStyle(color: G4MColors.inkMuted)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(ctx.l.common.useMyLocation),
                    onPressed: () async {
                      final pos = await WebBridge.locate();
                      if (pos == null) {
                        if (ctx.mounted) toast(ctx, ctx.l.common.locationDenied, error: true);
                        return;
                      }
                      Json? best;
                      var bestD = double.infinity;
                      for (final c in cities) {
                        final la = (c['lat'] as num?)?.toDouble(), ln = (c['lng'] as num?)?.toDouble();
                        if (la == null || ln == null) continue;
                        final d = math.pow(la - pos.lat, 2) + math.pow(ln - pos.lng, 2);
                        if (d < bestD) (bestD, best) = (d.toDouble(), c);
                      }
                      if (best != null) Shop.instance.setCity('${best['name']}');
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!s.hasData && !s.hasError) const LinearProgressIndicator(),
                  if (s.hasData && cities.isEmpty) Text(ctx.l.common.citiesSoon, style: const TextStyle(color: G4MColors.inkMuted)),
                  Flexible(
                    child: ListView(shrinkWrap: true, children: [
                      for (final c in cities)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(G4MRadius.sm)),
                          leading: const Icon(Icons.location_city_rounded, color: G4MColors.primary),
                          title: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${c['state'] ?? ''}'),
                          selected: Shop.instance.city.value == c['name'],
                          onTap: () {
                            Shop.instance.setCity('${c['name']}');
                            Navigator.pop(ctx);
                          },
                        ),
                    ]),
                  ),
                  if (Shop.instance.city.value != null)
                    TextButton(
                      onPressed: () {
                        Shop.instance.setCity(null);
                        Navigator.pop(ctx);
                      },
                      child: Text(ctx.l.common.showAllCities),
                    ),
                ]);
              },
            ),
          ),
        ),
      ),
    );

// ------------------------------------------------------------------ popup

Future<void> showPromoPopup(BuildContext context, PromoBanner p) => showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: L.current.common.closeOffer,
      barrierColor: const Color(0x990A1A12),
      transitionDuration: G4MMotion.emphasized,
      transitionBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(CurvedAnimation(parent: a, curve: G4MMotion.spring)), child: child),
      ),
      pageBuilder: (ctx, _, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(G4MRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(children: [
                if (p.image.isNotEmpty) AspectRatio(aspectRatio: 1.25, child: NetImage(p.image, semanticLabel: p.title)),
                PositionedDirectional(
                  end: 10,
                  top: 10,
                  child: RoundIconButton(icon: Icons.close_rounded, tooltip: ctx.l.common.close, size: 36, onTap: () => Navigator.pop(ctx)),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(children: [
                  if (p.title.isNotEmpty) Text(p.title, textAlign: TextAlign.center, style: ctx.tt.titleLarge),
                  if (p.link.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        openLink(context, p.link);
                      },
                      child: Text(p.ctaText),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );

// ------------------------------------------------------------------ page scroll + footer

/// Page body: vertical scroll with the footer appended. [onNearEnd] powers infinite scroll.
class PageScroll extends StatefulWidget {
  const PageScroll({super.key, required this.children, this.onNearEnd, this.footer = true, this.padTop = 0});
  final List<Widget> children;
  final VoidCallback? onNearEnd;
  final bool footer;
  final double padTop;
  @override
  State<PageScroll> createState() => _PageScrollState();
}

class _PageScrollState extends State<PageScroll> {
  final _c = ScrollController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (widget.onNearEnd != null && n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 900) widget.onNearEnd!();
          return false;
        },
        child: Scrollbar(
          controller: _c,
          child: SingleChildScrollView(
            controller: _c,
            padding: EdgeInsets.only(top: widget.padTop),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ...widget.children,
              if (widget.footer) const SiteFooter(),
            ]),
          ),
        ),
      );
}

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});
  static const _muted = Color(0xFFC4DBCF);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final s = Shop.instance.settings;
          final social = s.social;
          final phone = context.isPhone;
          final c = context.l.common;
          Widget col(String title, List<(String, String)> links) => SizedBox(
                width: phone ? (context.w - 48) / 2 : 190,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(
                    header: true,
                    headingLevel: 2,
                    child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(height: 14),
                  for (final l in links)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextLink(l.$1, to: l.$2, style: const TextStyle(color: _muted, fontSize: 14.5, height: 1.4), hoverColor: Colors.white),
                    ),
                ]),
              );
          return Container(
            margin: const EdgeInsets.only(top: 48),
            decoration: const BoxDecoration(
              color: G4MColors.primaryDeep,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Contained(
              vertical: 0,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 56),
                Wrap(spacing: 48, runSpacing: 36, children: [
                  SizedBox(
                    width: phone ? double.infinity : 320,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(G4MRadius.md)),
                        child: const G4MWordmark(size: 34),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        c.footerAbout(s.tagline),
                        style: const TextStyle(color: _muted, height: 1.6, fontSize: 14.5),
                      ),
                      const SizedBox(height: 18),
                      if (s.contactPhone.isNotEmpty) _contact(Icons.call_outlined, s.contactPhone, 'tel:${s.contactPhone}'),
                      if (s.contactEmail.isNotEmpty) _contact(Icons.mail_outline_rounded, s.contactEmail, 'mailto:${s.contactEmail}'),
                      if (s.address.isNotEmpty) _contact(Icons.location_on_outlined, s.address, null),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final e in const [
                          ('facebook', 'Facebook'),
                          ('instagram', 'Instagram'),
                          ('x', 'X'),
                          ('youtube', 'YouTube'),
                          ('linkedin', 'LinkedIn'),
                        ])
                          if ('${social[e.$1] ?? ''}'.startsWith('http')) _Social(kind: e.$1, label: e.$2, url: '${social[e.$1]}'),
                      ]),
                      const SizedBox(height: 18),
                      const LanguageButton(onDark: true),
                    ]),
                  ),
                  col(c.footerShop, [
                    for (final m in Shop.instance.modules) (m.name, '/m/${m.id}'),
                    (c.allCategories, '/categories'),
                    (c.searchLabel, '/search'),
                  ]),
                  col(c.footerHelp, [
                    (c.aboutUs, '/page/about'),
                    (c.faqs, '/faq'),
                    (c.blog, '/blog'),
                    (c.shippingPolicy, '/page/shipping'),
                    (c.refundPolicy, '/page/refund'),
                    (c.cancellationPolicy, '/page/cancellation'),
                  ]),
                  col(c.yourAccount, [
                    (c.myOrders, '/orders'),
                    (c.wallet, '/wallet'),
                    (c.wishlist, '/wishlist'),
                    (c.referAndEarnLong, '/account?tab=refer'),
                    (c.terms, '/page/terms'),
                    (c.privacy, '/page/privacy'),
                  ]),
                  col(c.partnerWithUs, [
                    (c.becomeSeller, kSellerUrl),
                    (c.becomeRider, kDeliveryUrl),
                    (c.requestProduct, '/account?tab=request'),
                  ]),
                ]),
                const SizedBox(height: 40),
                const Divider(color: Color(0x33FFFFFF)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 14, children: [
                    Text(c.rights(DateTime.now().year, s.appName), style: const TextStyle(color: _muted, fontSize: 13.5)),
                    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(c.weAccept, style: const TextStyle(color: _muted, fontSize: 13.5)),
                      for (final m in c.paymentBadges)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(8)),
                          child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ),
                    ]),
                  ]),
                ),
              ]),
            ),
          );
        },
      );

  Widget _contact(IconData i, String t, String? url) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, size: 18, color: const Color(0xFF8FD3AE)),
          const SizedBox(width: 10),
          Expanded(
            child: url == null
                ? Text(t, style: const TextStyle(color: _muted, fontSize: 14))
                : InkWell(onTap: () => launchUrl(Uri.parse(url)), child: Text(t, style: const TextStyle(color: _muted, fontSize: 14))),
          ),
        ]),
      );
}

class _Social extends StatelessWidget {
  const _Social({required this.kind, required this.label, required this.url});
  final String kind, label, url;
  @override
  Widget build(BuildContext context) {
    final Widget glyph = switch (kind) {
      'facebook' => const Icon(Icons.facebook_rounded, color: Colors.white, size: 20),
      'instagram' => const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 19),
      'youtube' => const Icon(Icons.smart_display_rounded, color: Colors.white, size: 20),
      'linkedin' => const Text('in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      _ => const Text('𝕏', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
    };
    return Tooltip(
      message: label,
      child: AppLink(
        to: url,
        label: context.l.common.onSocial(label),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(12)),
          child: glyph,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ language

/// Header / footer language switcher. Lists only languages whose `languages/{code}.active` is true.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.onDark = false});
  final bool onDark;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: LangController.instance,
        builder: (context, _) {
          final lc = LangController.instance;
          final langs = lc.languages;
          if (langs.length < 2 && !onDark) return const SizedBox.shrink();
          final c = context.l.common;
          final current = langs.where((l) => l.code == lc.code).firstOrNull?.nativeName ?? kLangNative[lc.code]!;
          final fg = onDark ? Colors.white : G4MColors.ink;
          return PopupMenuButton<String>(
            tooltip: c.languageCurrent(current),
            offset: const Offset(0, 50),
            enabled: langs.length > 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(G4MRadius.md)),
            onSelected: (code) => lc.select(code),
            itemBuilder: (_) => [
              PopupMenuItem<String>(enabled: false, height: 36, child: Text(c.chooseLanguage, style: const TextStyle(fontWeight: FontWeight.w800, color: G4MColors.inkMuted, fontSize: 13))),
              for (final l in langs)
                PopupMenuItem<String>(
                  value: l.code,
                  child: Row(children: [
                    Icon(l.code == lc.code ? Icons.check_circle_rounded : Icons.circle_outlined, size: 20, color: l.code == lc.code ? G4MColors.primary : G4MColors.inkFaint),
                    const SizedBox(width: 12),
                    Text(l.nativeName, style: TextStyle(fontWeight: l.code == lc.code ? FontWeight.w800 : FontWeight.w600)),
                    if (l.nativeName != l.name) ...[
                      const SizedBox(width: 8),
                      Text(l.name, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13)),
                    ],
                  ]),
                ),
            ],
            child: Container(
              height: 44,
              padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
              decoration: BoxDecoration(
                color: onDark ? const Color(0x1AFFFFFF) : null,
                border: onDark ? null : Border.all(color: G4MColors.line),
                borderRadius: BorderRadius.circular(G4MRadius.pill),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.translate_rounded, size: 19, color: onDark ? const Color(0xFF8FD3AE) : G4MColors.primary),
                const SizedBox(width: 6),
                Text(current, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: fg)),
                Icon(Icons.expand_more_rounded, size: 18, color: fg),
              ]),
            ),
          );
        },
      );
}

// ------------------------------------------------------------------ mobile drawer

class SiteDrawer extends StatelessWidget {
  const SiteDrawer({super.key, required this.location});
  final String location;
  @override
  Widget build(BuildContext context) {
    final c = context.l.common;
    void go(String to) {
      Navigator.of(context).pop();
      openLink(context, to);
    }

    Widget item(IconData icon, String label, String to) {
      final selected = to == '/' ? location == '/' : location.startsWith(to);
      return ListTile(
        leading: Icon(icon, color: selected ? G4MColors.primary : G4MColors.ink),
        title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        selected: selected,
        selectedTileColor: G4MColors.primarySoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(G4MRadius.sm)),
        onTap: () => go(to),
      );
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([LangController.instance, Shop.instance]),
          builder: (context, _) {
            final lc = LangController.instance;
            return ListView(padding: const EdgeInsets.fromLTRB(12, 16, 12, 24), children: [
              const Padding(padding: EdgeInsetsDirectional.only(start: 8, bottom: 16), child: Align(alignment: AlignmentDirectional.centerStart, child: G4MWordmark(size: 30))),
              item(Icons.home_outlined, c.navHome, '/'),
              item(Icons.grid_view_outlined, c.allCategories, '/categories'),
              for (final m in Shop.instance.modules) item(moduleIcon(m.id), m.name, '/m/${m.id}'),
              const Divider(height: 24),
              item(Icons.receipt_long_outlined, c.myOrders, '/orders'),
              item(Icons.favorite_border_rounded, c.wishlist, '/wishlist'),
              item(Icons.account_balance_wallet_outlined, c.wallet, '/wallet'),
              item(Icons.person_outline_rounded, Shop.instance.signedIn ? c.myAccount : c.signIn, Shop.instance.signedIn ? '/account' : '/login'),
              const Divider(height: 24),
              item(Icons.article_outlined, c.blog, '/blog'),
              item(Icons.help_outline_rounded, c.helpFaq, '/faq'),
              item(Icons.storefront_outlined, c.sellOnGo4Market, kSellerUrl),
              if (lc.languages.length > 1) ...[
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, bottom: 6, top: 4),
                  child: Semantics(
                    header: true,
                    child: Row(children: [
                      const Icon(Icons.translate_rounded, size: 18, color: G4MColors.primary),
                      const SizedBox(width: 8),
                      Text(c.language, style: const TextStyle(fontWeight: FontWeight.w800, color: G4MColors.inkMuted)),
                    ]),
                  ),
                ),
                for (final l in lc.languages)
                  ListTile(
                    leading: Icon(l.code == lc.code ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                        color: l.code == lc.code ? G4MColors.primary : G4MColors.inkFaint),
                    title: Text(l.nativeName, style: TextStyle(fontWeight: l.code == lc.code ? FontWeight.w800 : FontWeight.w600)),
                    subtitle: l.nativeName == l.name ? null : Text(l.name),
                    selected: l.code == lc.code,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(G4MRadius.sm)),
                    onTap: () {
                      Navigator.of(context).pop();
                      lc.select(l.code);
                    },
                  ),
              ],
            ]);
          },
        ),
      ),
    );
  }
}
