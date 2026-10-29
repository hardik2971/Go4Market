import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/prefs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui.dart';
import '../link_router.dart';
import '../location/location_picker_screen.dart';
import '../product/product_list_screen.dart';
import '../product/seller_screen.dart';
import '../profile/notifications_screen.dart';
import '../search/search_screen.dart';
import '../shell/main_shell.dart';
import '../wishlist/wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _prefs = AppPrefs.instance;
  final _sectionFutures = <String, Future<List<Product>>>{};
  List<MarketModule> _modules = [];
  int _refresh = 0;
  bool _popupChecked = false;

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_onPrefs);
    _modules = AppConfig.modules.value;
    AppConfig.modules.addListener(_onModules);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePopup());
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefs);
    AppConfig.modules.removeListener(_onModules);
    super.dispose();
  }

  void _onModules() {
    final m = AppConfig.modules.value;
    if (!mounted) return;
    setState(() => _modules = m);
    if (m.isNotEmpty && !m.any((e) => e.id == _prefs.moduleId)) _prefs.setModule(m.first.id);
  }

  String _lastModule = AppPrefs.instance.moduleId;
  void _onPrefs() {
    if (_prefs.moduleId != _lastModule) {
      _lastModule = _prefs.moduleId;
      _sectionFutures.clear();
    }
    if (mounted) setState(() {});
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _sectionFutures.clear();
      _refresh++;
    });
    await Future.delayed(const Duration(milliseconds: 700));
  }

  Future<void> _maybePopup() async {
    if (_popupChecked) return;
    _popupChecked = true;
    try {
      final list = await CatalogRepo.instance.popups().first.timeout(const Duration(seconds: 8));
      final p = list.where((b) {
        final on = '${b.data['showOn'] ?? 'both'}';
        if (on == 'web') return false;
        if (!inWindow(b.data)) return false;
        return !_prefs.popupSeenToday(b.id);
      }).toList();
      if (p.isEmpty || !mounted) return;
      final b = p.first;
      _prefs.markPopupSeen(b.id);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'popup',
        transitionDuration: G4MMotion.emphasized,
        transitionBuilder: (_, a, _, child) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: a, child: child),
        ),
        pageBuilder: (ctx, _, _) => _PopupDialog(banner: b),
      );
    } catch (_) {}
  }

  MarketModule? get _module {
    for (final m in _modules) {
      if (m.id == _prefs.moduleId) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mod = _module;
    final modColor = GColor.of(mod);
    final moduleId = _prefs.moduleId;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
        onRefresh: _onRefresh,
        color: modColor,
        edgeOffset: 60,
        child: CustomScrollView(
          key: ValueKey('home-$moduleId-$_refresh'),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _HomeTop(color: modColor)),
            SliverPersistentHeader(pinned: true, delegate: _SearchHeader(hint: l.searchHint, color: modColor)),
            SliverToBoxAdapter(child: _ModuleSwitcher(modules: _modules, selected: moduleId)),
            SliverToBoxAdapter(child: _SliderBlock(moduleId: moduleId)),
            SliverToBoxAdapter(child: _OfferStrip(moduleId: moduleId, position: 'home_top')),
            SliverToBoxAdapter(child: _CategoryGrid(moduleId: moduleId, color: modColor, title: l.shopByCategory)),
            SliverToBoxAdapter(child: _CouponStrip(title: l.offersForYou)),
            StreamBuilder<List<FeaturedSection>>(
              stream: CatalogRepo.instance.featuredSections(moduleId: moduleId),
              builder: (context, snap) {
                final secs = snap.data ?? const <FeaturedSection>[];
                if (snap.connectionState == ConnectionState.waiting && secs.isEmpty) {
                  return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 20), child: CarouselSkeleton()));
                }
                final children = <Widget>[];
                if (secs.isEmpty) {
                  children
                    ..add(_AutoSection(title: 'Popular right now', moduleId: moduleId, sort: 'popular', futures: _sectionFutures))
                    ..add(_AutoSection(title: 'Fresh arrivals', moduleId: moduleId, sort: 'newest', futures: _sectionFutures));
                } else {
                  for (var i = 0; i < secs.length; i++) {
                    children.add(_FeaturedBlock(section: secs[i], futures: _sectionFutures));
                    if (i == 1) children.add(_OfferStrip(moduleId: moduleId, position: 'home_mid'));
                  }
                  if (secs.length < 2) children.add(_OfferStrip(moduleId: moduleId, position: 'home_mid'));
                }
                return SliverList.list(children: children);
              },
            ),
            SliverToBoxAdapter(child: _SellersStrip(title: l.topSellers)),
            SliverToBoxAdapter(child: _RecentlyViewed(title: l.recentlyViewed)),
            const SliverToBoxAdapter(child: SizedBox(height: kNavPad)),
          ],
        ),
      ),
      ),
    );
  }
}

abstract final class GColor {
  static Color of(MarketModule? m) => m == null ? G4MColors.primary : G4MColors.fromHex(m.themeColor);
}

// --------------------------------------------------------------------------- header

class _HomeTop extends StatelessWidget {
  const _HomeTop({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: G4MMotion.slow,
        curve: G4MMotion.curve,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: context.isDark ? .22 : .16), context.theme.scaffoldBackgroundColor],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
        child: Row(children: [
          Expanded(child: _LocationChip(color: color)),
          IconButton(onPressed: () => context.push(const WishlistScreen()), icon: const Icon(Icons.favorite_border_rounded)),
          const _BellButton(),
        ]),
      );
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  _SearchHeader({required this.hint, required this.color});
  final String hint;
  final Color color;
  @override
  double get minExtent => 72;
  @override
  double get maxExtent => 72;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final pinned = shrinkOffset > 0 || overlapsContent;
    return AnimatedContainer(
      duration: G4MMotion.standard,
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor.withValues(alpha: pinned ? 1 : 0),
        boxShadow: pinned && !context.isDark ? const [BoxShadow(color: Color(0x140A4A33), blurRadius: 16, offset: Offset(0, 6))] : null,
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Hero(tag: 'search-bar', child: _SearchField(hint: hint, color: color)),
    );
  }

  @override
  bool shouldRebuild(_SearchHeader old) => old.hint != hint || old.color != color;
}
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loc = AppPrefs.instance.location;
    return Pressable(
      onTap: () async {
        final r = await context.push<ShopLocation>(const LocationPickerScreen(), style: RouteStyle.sharedY);
        if (r != null) AppPrefs.instance.setLocation(r);
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.location_on_rounded, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(l.deliverTo, style: context.text.labelSmall?.copyWith(color: context.muted, fontWeight: FontWeight.w600)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(loc?.label ?? l.selectLocation,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: Session.instance.epoch,
        builder: (context, _, _) => StreamBuilder<List<AppNotification>>(
          stream: Session.instance.signedIn ? MyData.inbox() : const Stream.empty(),
          builder: (context, snap) {
            final unread = (snap.data ?? const []).where((n) => !n.read).length;
            return IconButton(
              onPressed: () => context.push(const NotificationsScreen()),
              icon: Badge(
                isLabelVisible: unread > 0,
                backgroundColor: G4MColors.accent,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            );
          },
        ),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.color});
  final String hint;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Pressable(
          scale: .985,
          onTap: () => context.push(const SearchScreen(), style: RouteStyle.fadeThrough),
          child: Container(
            height: 52,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: context.softShadow,
              border: Border.all(color: context.line),
            ),
            child: Row(children: [
              Icon(Icons.search_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.muted, fontSize: 14))),
              Container(width: 1, height: 24, color: context.line),
              IconButton(
                tooltip: 'Voice search',
                onPressed: () => context.push(const SearchScreen(voice: true), style: RouteStyle.fadeThrough),
                icon: Icon(Icons.mic_rounded, color: color),
              ),
            ]),
          ),
        ),
      );
}

// --------------------------------------------------------------------------- modules

class _ModuleSwitcher extends StatelessWidget {
  const _ModuleSwitcher({required this.modules, required this.selected});
  final List<MarketModule> modules;
  final String selected;
  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, _) => const Shimmer(width: 100, height: 80, radius: 18),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: modules.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final m = modules[i];
          final on = m.id == selected;
          final c = G4MColors.fromHex(m.themeColor);
          return Pressable(
            onTap: () => AppPrefs.instance.setModule(m.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              width: on ? 118 : 96,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: on ? c : context.card,
                borderRadius: BorderRadius.circular(18),
                boxShadow: on ? [BoxShadow(color: c.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8))] : context.softShadow,
                border: on ? null : Border.all(color: context.line),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                m.icon.startsWith('http')
                    ? Img(m.icon, width: 30, height: 30, fit: BoxFit.contain)
                    : AnimatedScale(
                        scale: on ? 1.15 : 1,
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutBack,
                        child: Icon(moduleIcon(m), color: on ? Colors.white : c, size: 28),
                      ),
                const SizedBox(height: 6),
                Text(m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: on ? Colors.white : context.ink)),
              ]),
            ),
          ).stagger(i, dy: 0);
        },
      ),
    );
  }
}

// --------------------------------------------------------------------------- sliders

class _SliderBlock extends StatefulWidget {
  const _SliderBlock({required this.moduleId});
  final String moduleId;
  @override
  State<_SliderBlock> createState() => _SliderBlockState();
}

class _SliderBlockState extends State<_SliderBlock> {
  final _pc = PageController(viewportFraction: .9);
  Timer? _timer;
  int _count = 0;
  double _page = 0;
  late Stream<List<PromoBanner>> _stream = CatalogRepo.instance.sliders(moduleId: widget.moduleId);

  @override
  void didUpdateWidget(_SliderBlock old) {
    super.didUpdateWidget(old);
    if (old.moduleId != widget.moduleId) _stream = CatalogRepo.instance.sliders(moduleId: widget.moduleId);
  }

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _count < 2 || !_pc.hasClients) return;
      if (!TickerMode.valuesOf(context).enabled) return;
      final next = ((_pc.page ?? 0).round() + 1) % _count;
      _pc.animateToPage(next, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<PromoBanner>>(
        stream: _stream,
        builder: (context, snap) {
          final list = snap.data ?? const <PromoBanner>[];
          _count = list.length;
          if (snap.connectionState == ConnectionState.waiting && list.isEmpty) {
            return const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Shimmer(height: 168, radius: 22));
          }
          if (list.isEmpty) return const SizedBox(height: 4);
          return Column(children: [
            const SizedBox(height: 12),
            SizedBox(
              height: 172,
              child: PageView.builder(
                controller: _pc,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final b = list[i];
                  final d = (_page - i).abs().clamp(0.0, 1.0);
                  return Transform.scale(
                    scale: 1 - d * .06,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Pressable(
                        onTap: () => openLink(context, b.link),
                        child: _BannerCard(banner: b, parallax: (_page - i) * 40),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < list.length; i++)
                AnimatedContainer(
                  duration: G4MMotion.standard,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page.round() == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page.round() == i ? G4MColors.primary : context.line,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
            ]),
          ]).animate().fadeIn(duration: 400.ms);
        },
      );
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, this.parallax = 0});
  final PromoBanner banner;
  final double parallax;
  @override
  Widget build(BuildContext context) {
    final b = banner;
    final bg = G4MColors.fromHex(b.bgColor, G4MColors.primaryDeep);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(fit: StackFit.expand, children: [
        Container(color: bg),
        Transform.translate(offset: Offset(parallax, 0), child: Transform.scale(scale: 1.12, child: Img(b.image))),
        if (b.title.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.black.withValues(alpha: .55), Colors.transparent], stops: const [0, .75]),
            ),
          ),
        if (b.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(b.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15)),
              if (b.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(b.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: G4MColors.accent, borderRadius: BorderRadius.circular(20)),
                child: Text(b.ctaText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _OfferStrip extends StatelessWidget {
  const _OfferStrip({required this.moduleId, required this.position});
  final String moduleId, position;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<PromoBanner>>(
        stream: CatalogRepo.instance.offers(moduleId: moduleId),
        builder: (context, snap) {
          final list = (snap.data ?? const <PromoBanner>[]).where((b) {
            if (b.position.isNotEmpty && b.position != position) return false;
            if (b.position.isEmpty && position != 'home_top') return false;
            return inWindow(b.data);
          }).toList();
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => Pressable(
                  onTap: () => openLink(context, list[i].link),
                  child: SizedBox(
                    width: list.length == 1 ? MediaQuery.sizeOf(context).width - 32 : 260,
                    child: Stack(fit: StackFit.expand, children: [
                      Img(list[i].image, radius: 18),
                      if (list[i].image.isEmpty)
                        Container(
                          decoration: BoxDecoration(gradient: G4MColors.accentGradient, borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.centerLeft,
                          child: Text(list[i].title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                        ),
                    ]),
                  ),
                ).stagger(i, dy: 0),
              ),
            ),
          );
        },
      );
}

// --------------------------------------------------------------------------- categories

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.moduleId, required this.color, required this.title});
  final String moduleId;
  final Color color;
  final String title;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Category>>(
        stream: CatalogRepo.instance.categories(moduleId: moduleId),
        builder: (context, snap) {
          final all = snap.data ?? const <Category>[];
          final roots = all.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();
          if (snap.connectionState == ConnectionState.waiting && roots.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: List.generate(8, (_) => const Shimmer(height: 80, radius: 18)),
              ),
            );
          }
          if (roots.isEmpty) return const SizedBox.shrink();
          final shown = roots.take(7).toList();
          return Column(children: [
            SectionHeader(title, onViewAll: () => shellTab.value = 1),
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shown.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 10,
                childAspectRatio: .74,
              ),
              itemBuilder: (_, i) {
                if (i == shown.length) {
                  return _CatTile(
                    name: 'All',
                    bg: color.withValues(alpha: .12),
                    icon: Icons.apps_rounded,
                    iconColor: color,
                    onTap: () => shellTab.value = 1,
                  ).stagger(i);
                }
                final c = shown[i];
                return _CatTile(
                  name: c.name,
                  image: c.image,
                  bg: context.isDark ? context.cardAlt : G4MColors.pastels[i % G4MColors.pastels.length],
                  onTap: () => context.push(ProductListScreen(title: c.name, categoryId: c.id, moduleId: moduleId)),
                ).stagger(i);
              },
            ),
          ]);
        },
      );
}

class _CatTile extends StatelessWidget {
  const _CatTile({required this.name, required this.bg, required this.onTap, this.image = '', this.icon, this.iconColor});
  final String name, image;
  final Color bg;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Column(children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.all(10),
              child: icon != null ? Icon(icon, color: iconColor, size: 30) : Img(image, fit: BoxFit.contain, radius: 10, iconSize: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
        ]),
      );
}

// --------------------------------------------------------------------------- coupons

class _CouponStrip extends StatelessWidget {
  const _CouponStrip({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Coupon>>(
        stream: CatalogRepo.instance.activeCoupons(),
        builder: (context, snap) {
          final list = snap.data ?? const <Coupon>[];
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => CouponTicket(coupon: list[i]).stagger(i, dy: 0),
              ),
            ),
          ]);
        },
      );
}

/// Ticket-shaped coupon with a dashed divider. Tap to copy.
class CouponTicket extends StatelessWidget {
  const CouponTicket({super.key, required this.coupon, this.onTap, this.width = 250});
  final Coupon coupon;
  final VoidCallback? onTap;
  final double width;
  @override
  Widget build(BuildContext context) {
    final c = coupon;
    return Pressable(
      onTap: onTap ??
          () {
            Clipboard.setData(ClipboardData(text: c.code));
            context.toast('Code ${c.code} copied');
          },
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: context.softAccent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: G4MColors.accent.withValues(alpha: .35)),
        ),
        child: Row(children: [
          Container(
            width: 76,
            decoration: const BoxDecoration(
              gradient: G4MColors.accentGradient,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(15)),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(6),
            child: Text(c.label,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, height: 1.1)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(c.code, style: context.text.titleSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  c.message.isNotEmpty ? c.message : (c.minOrder > 0 ? 'On orders above ${Fmt.money(c.minOrder)}' : 'Tap to copy'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// --------------------------------------------------------------------------- featured sections

class _FeaturedBlock extends StatelessWidget {
  const _FeaturedBlock({required this.section, required this.futures});
  final FeaturedSection section;
  final Map<String, Future<List<Product>>> futures;

  @override
  Widget build(BuildContext context) {
    final f = section;
    final fut = futures.putIfAbsent(f.id, () => Catalog.section(f));
    final bg = f.bgColor.isEmpty ? null : G4MColors.fromHex(f.bgColor);
    return FutureBuilder<List<Product>>(
      future: fut,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error!, compact: true);
        final list = snap.data;
        if (list != null && list.isEmpty) return const SizedBox.shrink();
        Session.instance.remember(list ?? const []);
        void seeAll() => context.push(ProductListScreen(title: f.title, section: f, moduleId: f.moduleId.isEmpty ? null : f.moduleId));
        final header = SectionHeader(f.title, subtitle: f.subtitle, onViewAll: seeAll);
        Widget body;
        if (list == null) {
          body = const CarouselSkeleton();
        } else if (f.style == 'grid') {
          final shown = list.take(4).toList();
          body = GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: (MediaQuery.sizeOf(context).width - 44) / 2 + 150,
            ),
            itemBuilder: (_, i) => ProductCard(product: shown[i], scope: 'fs-${f.id}').stagger(i),
          );
        } else if (f.style == 'banner_left') {
          body = SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Pressable(
                    onTap: seeAll,
                    child: SizedBox(
                      width: 150,
                      child: Stack(fit: StackFit.expand, children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: G4MColors.heroGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        Img(f.bannerImage, radius: 18),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          right: 12,
                          child: Row(children: [
                            Expanded(
                              child: Text(f.bannerImage.isEmpty ? f.title : '',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                            ),
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.arrow_forward_rounded, size: 18, color: G4MColors.primaryDeep),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  ).stagger(0, dy: 0);
                }
                return ProductCard(product: list[i - 1], scope: 'fs-${f.id}', width: 160).stagger(i, dy: 0);
              },
            ),
          );
        } else {
          body = ProductCarousel(products: list, scope: 'fs-${f.id}');
        }
        return Container(
          margin: bg == null ? null : const EdgeInsets.only(top: 14),
          padding: bg == null ? null : const EdgeInsets.only(bottom: 14),
          color: bg?.withValues(alpha: context.isDark ? .12 : .25),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, body]),
        );
      },
    );
  }
}

class _AutoSection extends StatelessWidget {
  const _AutoSection({required this.title, required this.moduleId, required this.sort, required this.futures});
  final String title, moduleId, sort;
  final Map<String, Future<List<Product>>> futures;
  @override
  Widget build(BuildContext context) {
    final fut = futures.putIfAbsent('auto-$sort', () => Catalog.products(moduleId: moduleId, sort: sort, limit: 12));
    return FutureBuilder<List<Product>>(
      future: fut,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error!, compact: true);
        final list = snap.data;
        if (list != null && list.isEmpty) {
          return sort == 'popular'
              ? const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Stores are stocking up',
                    message: 'Products for this section will appear here shortly.',
                  ),
                )
              : const SizedBox.shrink();
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title, onViewAll: () => context.push(ProductListScreen(title: title, moduleId: moduleId, initialSort: sort))),
          list == null ? const CarouselSkeleton() : ProductCarousel(products: list, scope: 'auto-$sort'),
        ]);
      },
    );
  }
}

// --------------------------------------------------------------------------- sellers + recently viewed

class _SellersStrip extends StatelessWidget {
  const _SellersStrip({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Seller>>(
        stream: CatalogRepo.instance.sellers(limit: 30),
        builder: (context, snap) {
          var list = snap.data ?? const <Seller>[];
          if (list.isEmpty) return const SizedBox.shrink();
          // Location-based: prefer stores in the selected city when any exist.
          final city = AppPrefs.instance.location?.city.toLowerCase() ?? '';
          final local = city.isEmpty ? <Seller>[] : list.where((s) => s.city.toLowerCase() == city).toList();
          final shown = local.isNotEmpty ? local : (List<Seller>.from(list)..sort((a, b) => b.rating.compareTo(a.rating)));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title, subtitle: local.isNotEmpty ? 'Delivering in ${AppPrefs.instance.location!.city}' : null),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: shown.length.clamp(0, 12),
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final s = shown[i];
                  return SizedBox(
                    width: 140,
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      onTap: () => context.push(SellerScreen(sellerId: s.id, seller: s)),
                      child: Column(children: [
                        SizedBox(
                          height: 64,
                          child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: s.banner.isEmpty
                                  ? Container(decoration: const BoxDecoration(gradient: G4MColors.heroGradient))
                                  : Img(s.banner),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: -24,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: context.card, shape: BoxShape.circle),
                                  child: ClipOval(child: Img(s.logo, width: 44, height: 44, iconSize: 18)),
                                ),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 30),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(s.storeName,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontSize: 13)),
                        ),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A524)),
                          Text(' ${s.rating.toStringAsFixed(1)}', style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (s.city.isNotEmpty) Flexible(child: Text(' · ${s.city}', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall)),
                        ]),
                      ]),
                    ),
                  ).stagger(i, dy: 0);
                },
              ),
            ),
          ]);
        },
      );
}

class _RecentlyViewed extends StatelessWidget {
  const _RecentlyViewed({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppUser?>(
        valueListenable: Session.instance.profile,
        builder: (context, u, _) {
          final ids = u?.recentlyViewed ?? const <String>[];
          if (ids.isEmpty) return const SizedBox.shrink();
          return FutureBuilder<Map<String, Product>>(
            future: Session.instance.ensureProducts(ids.take(12)),
            builder: (context, snap) {
              final m = snap.data;
              if (m == null) return const SizedBox.shrink();
              final list = [for (final id in ids) if (m[id] != null) m[id]!];
              if (list.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHeader(title),
                ProductCarousel(products: list, scope: 'recent'),
              ]);
            },
          );
        },
      );
}

class _PopupDialog extends StatelessWidget {
  const _PopupDialog({required this.banner});
  final PromoBanner banner;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Material(
            color: Colors.transparent,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Pressable(
                onTap: () {
                  Navigator.of(context).pop();
                  openLink(context, banner.link);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: G4MShadows.lifted,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (banner.image.isNotEmpty) AspectRatio(aspectRatio: 4 / 5, child: Img(banner.image)),
                    if (banner.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(banner.title, textAlign: TextAlign.center, style: context.text.titleLarge),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: G4MColors.ink),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
        ),
      );
}
