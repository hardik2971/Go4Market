import 'dart:async';

import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../core/data.dart';
import '../core/shop.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/product_widgets.dart';
import '../ui/shell.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.moduleId});
  final String? moduleId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final m = moduleId == null ? null : shop.module(moduleId!);
          final accent = m == null ? G4MColors.primary : G4MColors.fromHex(m.themeColor);
          final seo = shop.settings.seo;
          final gap = SizedBox(height: context.isPhone ? 40 : 64);
          final t = context.l.home;
          return SeoMeta(
            // The admin-set SEO copy is English; other languages use the translated defaults.
            title: m == null ? (context.l.code == 'en' ? seo['title'] as String? : null) : t.moduleSeoTitle(m.name),
            description: m == null ? (context.l.code == 'en' ? seo['description'] as String? : null) : (m.tagline.isEmpty ? null : t.moduleSeoDescription(m.name, m.tagline)),
            child: PageScroll(children: [
              if (context.isPhone) SizedBox(height: 56, child: ModuleBar(location: moduleId == null ? '/' : '/m/$moduleId', padding: const EdgeInsets.symmetric(horizontal: 16))),
              SizedBox(height: context.isPhone ? 4 : 24),
              Contained(child: HeroBento(moduleId: moduleId, accent: accent, module: m)),
              const SizedBox(height: 20),
              const Contained(child: PromiseStrip()),
              gap,
              Contained(child: CategoryRail(moduleId: moduleId, accent: accent)),
              gap,
              _FeaturedSections(moduleId: moduleId, accent: accent),
              Contained(child: SellerStrip(moduleId: moduleId)),
              gap,
              Contained(
                child: ProductsFuture(
                  key: ValueKey('best$moduleId'),
                  load: () => Data.list(moduleId: moduleId, sort: 'popular', limit: 12),
                  skeleton: const ProductGrid(products: [], loading: true),
                  builder: (l) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SectionHeader(
                      eyebrow: t.bestEyebrow,
                      title: t.bestTitle,
                      subtitle: t.bestSubtitle,
                      viewAll: '/search?sort=popular${moduleId == null ? '' : '&module=$moduleId'}',
                      accent: accent,
                    ),
                    ProductGrid(products: l),
                    gap,
                  ]),
                ),
              ),
              Contained(child: _OfferBand(position: 'home_mid', moduleId: moduleId, skip: 1)),
              Contained(child: _TrendingDeals(moduleId: moduleId, accent: accent)),
              const Contained(child: _RecentlyViewed()),
              if (moduleId == null) const Contained(child: _BlogTeasers()),
              const Contained(child: AppBand()),
              SizedBox(height: context.isPhone ? 24 : 32),
              const Contained(child: GrowBand()),
            ]),
          );
        },
      );
}

// ------------------------------------------------------------------ hero

class HeroBento extends StatelessWidget {
  const HeroBento({super.key, this.moduleId, required this.accent, this.module});
  final String? moduleId;
  final Color accent;
  final MarketModule? module;

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final h = phone ? 230.0 : (context.isTablet ? 340.0 : 440.0);
    return StreamBuilder<List<PromoBanner>>(
      stream: live('sliders$moduleId', () => CatalogRepo.instance.sliders(moduleId: moduleId)),
      builder: (context, s) {
        final slides = s.data ?? const [];
        final slider = SizedBox(
          height: h,
          child: !s.hasData && !s.hasError
              ? const Skeleton(radius: 28)
              : (slides.isEmpty ? _DefaultHero(module: module, accent: accent) : HeroSlider(slides: slides, accent: accent)),
        );
        final side = _HeroSide(moduleId: moduleId, accent: accent, height: h);
        if (phone || context.isTablet) {
          return Column(children: [slider, const SizedBox(height: 14), SizedBox(height: phone ? 132 : 170, child: side)]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: slider),
          const SizedBox(width: 18),
          Expanded(flex: 3, child: SizedBox(height: h, child: side)),
        ]);
      },
    );
  }
}

class _DefaultHero extends StatelessWidget {
  const _DefaultHero({this.module, required this.accent});
  final MarketModule? module;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final s = Shop.instance.settings;
    final phone = context.isPhone;
    return Container(
      decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        PositionedDirectional(end: -60, bottom: -80, child: Container(width: 360, height: 360, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),
        PositionedDirectional(end: phone ? 16 : 60, top: 0, bottom: 0, child: Opacity(opacity: phone ? .25 : 1, child: G4MLogo(size: phone ? 120 : 220))),
        Padding(
          padding: EdgeInsets.all(phone ? 22 : 48),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Pill(module?.name ?? context.l.home.heroPill, bg: G4MColors.accent, fg: G4MColors.ink),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Heading(module?.tagline.isNotEmpty == true ? module!.tagline : s.tagline,
                  level: 1, maxLines: 3, style: TextStyle(color: Colors.white, fontSize: phone ? 24 : 44, height: 1.1)),
            ),
            if (!phone) ...[
              const SizedBox(height: 12),
              Text(context.l.home.heroBody, style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 17)),
            ],
            SizedBox(height: phone ? 14 : 26),
            _HeroCta(label: context.l.home.startShopping, to: module == null ? '/categories' : '/categories?module=${module!.id}'),
          ]),
        ),
      ]),
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label, required this.to});
  final String label, to;
  @override
  Widget build(BuildContext context) => AppLink(
        to: to,
        label: label,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: context.isPhone ? 16 : 24, vertical: context.isPhone ? 10 : 14),
          decoration: BoxDecoration(color: G4MColors.accent, borderRadius: BorderRadius.circular(G4MRadius.pill), boxShadow: G4MShadows.glowAccent),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: G4MColors.ink, fontSize: context.isPhone ? 14 : 16)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 18, color: G4MColors.ink),
          ]),
        ),
      );
}

/// Auto-playing hero slider: crossfade + Ken Burns zoom, pauses on hover.
class HeroSlider extends StatefulWidget {
  const HeroSlider({super.key, required this.slides, required this.accent});
  final List<PromoBanner> slides;
  final Color accent;
  @override
  State<HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<HeroSlider> {
  int _i = 0;
  Timer? _t;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 5500), (_) {
      if (!_paused && mounted && widget.slides.length > 1) setState(() => _i = (_i + 1) % widget.slides.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _go(int d) => setState(() => _i = (_i + d) % widget.slides.length);

  @override
  Widget build(BuildContext context) {
    final n = widget.slides.length;
    final idx = _i % n;
    final b = widget.slides[idx];
    final phone = context.isPhone;
    return MouseRegion(
      onEnter: (_) => _paused = true,
      onExit: (_) => _paused = false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(fit: StackFit.expand, children: [
          AnimatedSwitcher(
            duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            layoutBuilder: (cur, prev) => Stack(fit: StackFit.expand, children: [...prev, ?cur]),
            child: _Slide(key: ValueKey(b.id), banner: b, first: idx == 0),
          ),
          if (n > 1)
            PositionedDirectional(
              start: phone ? 18 : 48,
              bottom: phone ? 14 : 28,
              child: Row(children: [
                for (var i = 0; i < n; i++)
                  Semantics(
                    button: true,
                    label: context.l.home.showSlide(i + 1),
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _i = i),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: G4MMotion.emphasized,
                          curve: G4MMotion.curve,
                          margin: const EdgeInsetsDirectional.only(end: 6),
                          width: i == idx ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(color: i == idx ? G4MColors.accent : Colors.white.withValues(alpha: .6), borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          if (n > 1 && !phone)
            PositionedDirectional(
              end: 24,
              bottom: 20,
              child: Row(children: [
                RoundIconButton(icon: Icons.chevron_left_rounded, tooltip: context.l.home.previousSlide, onTap: () => _go(-1)),
                const SizedBox(width: 8),
                RoundIconButton(icon: Icons.chevron_right_rounded, tooltip: context.l.home.nextSlide, onTap: () => _go(1), filled: true),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({super.key, required this.banner, required this.first});
  final PromoBanner banner;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final b = banner;
    final phone = context.isPhone;
    final bg = G4MColors.fromHex(b.bgColor, G4MColors.primaryDeep);
    final hasText = b.title.isNotEmpty || b.subtitle.isNotEmpty;
    return AppLink(
      to: b.link.isEmpty ? '/' : b.link,
      label: b.title.isEmpty ? context.l.home.featuredOffer : b.title,
      scale: 1,
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: bg),
        _KenBurns(child: NetImage(b.image, semanticLabel: b.title.isEmpty ? context.l.home.featuredOffer : b.title)),
        if (hasText)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd, colors: [bg.withValues(alpha: .92), bg.withValues(alpha: .55), bg.withValues(alpha: 0)], stops: const [0, .45, .8]),
            ),
          ),
        if (hasText)
          Padding(
            padding: EdgeInsets.fromLTRB(phone ? 20 : 48, 20, phone ? 20 : 48, phone ? 34 : 64),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: phone ? 240 : 520),
                child: first
                    ? Heading(b.title, level: 1, maxLines: 3, style: TextStyle(color: onColor(bg), fontSize: phone ? 22 : 46, height: 1.08))
                    : Text(b.title, maxLines: 3, style: TextStyle(color: onColor(bg), fontSize: phone ? 22 : 46, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -.8)),
              ),
              if (b.subtitle.isNotEmpty) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: phone ? 240 : 460),
                  child: Text(b.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: onColor(bg).withValues(alpha: .92), fontSize: phone ? 13.5 : 18, height: 1.4)),
                ),
              ],
              SizedBox(height: phone ? 12 : 26),
              Container(
                padding: EdgeInsets.symmetric(horizontal: phone ? 14 : 22, vertical: phone ? 8 : 13),
                decoration: BoxDecoration(color: G4MColors.accent, borderRadius: BorderRadius.circular(G4MRadius.pill), boxShadow: G4MShadows.glowAccent),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(b.ctaText, style: TextStyle(fontWeight: FontWeight.w800, color: G4MColors.ink, fontSize: phone ? 13 : 15.5)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: G4MColors.ink),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _KenBurns extends StatefulWidget {
  const _KenBurns({required this.child});
  final Widget child;
  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => context.reduceMotion
      ? widget.child
      : AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (_, c) => Transform.scale(scale: 1 + .08 * Curves.easeOut.transform(_c.value), alignment: const Alignment(.4, -.2), child: c),
        );
}

class _HeroSide extends StatelessWidget {
  const _HeroSide({this.moduleId, required this.accent, required this.height});
  final String? moduleId;
  final Color accent;
  final double height;
  @override
  Widget build(BuildContext context) {
    final stacked = !context.isDesktop;
    return StreamBuilder<List<PromoBanner>>(
      stream: live('offers_top$moduleId', () => Data.offers('home_top', moduleId: moduleId)),
      builder: (context, s) {
        final offers = (s.data ?? const <PromoBanner>[]).take(2).toList();
        final tiles = <Widget>[
          for (final o in offers) _OfferTile(offer: o),
          if (offers.length < 2) const _QuickTile(),
          if (offers.isEmpty) const _ReferTile(),
        ];
        final gapW = stacked ? const SizedBox(width: 14) : const SizedBox(height: 18);
        final kids = <Widget>[];
        for (var i = 0; i < tiles.length; i++) {
          if (i > 0) kids.add(gapW);
          kids.add(Expanded(child: Reveal(index: i, child: tiles[i])));
        }
        return stacked
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids)
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);
      },
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer});
  final PromoBanner offer;
  @override
  Widget build(BuildContext context) => AppLink(
        to: offer.link.isEmpty ? '/search?sort=discount' : offer.link,
        label: offer.title.isEmpty ? context.l.home.offer : offer.title,
        child: HoverLift(
          radius: 24,
          border: false,
          child: Stack(fit: StackFit.expand, children: [
            NetImage(offer.image, semanticLabel: offer.title.isEmpty ? context.l.home.offer : offer.title),
            if (offer.title.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                  decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x000A1A12), Color(0xCC0A1A12)])),
                  child: Text(offer.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
          ]),
        ),
      );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile();
  @override
  Widget build(BuildContext context) {
    final s = Shop.instance.settings;
    final quick = s.quick15Enabled ? '15' : (s.quick30Enabled ? '30' : null);
    final phone = context.isPhone;
    final t = context.l.home;
    return AppLink(
      to: '/m/grocery',
      label: t.quickDelivery,
      child: HoverLift(
        radius: 24,
        color: const Color(0xFFFFF1E2),
        border: false,
        child: Padding(
          padding: EdgeInsets.all(phone ? 14 : 22),
          child: Stack(children: [
            PositionedDirectional(end: -6, bottom: -10, child: Icon(Icons.bolt_rounded, size: phone ? 72 : 120, color: G4MColors.accent.withValues(alpha: .35))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Pill(t.quickDelivery, bg: Colors.white, fg: kAccentInk, icon: Icons.bolt_rounded),
              SizedBox(height: phone ? 6 : 12),
              Text(quick == null ? t.sameDayDelivery : t.deliveredInMinutes(quick),
                  maxLines: 2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: phone ? 15 : 22, height: 1.15, color: G4MColors.ink)),
              if (!phone) ...[
                const SizedBox(height: 6),
                Text(t.freeDeliveryAbove(context.l.money(s.freeDeliveryAbove)), style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ReferTile extends StatelessWidget {
  const _ReferTile();
  @override
  Widget build(BuildContext context) {
    final s = Shop.instance.settings;
    final phone = context.isPhone;
    final t = context.l.home;
    return AppLink(
      to: '/account?tab=refer',
      label: t.referAndEarnLink,
      child: HoverLift(
        radius: 24,
        color: G4MColors.primarySoft,
        border: false,
        child: Padding(
          padding: EdgeInsets.all(phone ? 14 : 22),
          child: Stack(children: [
            PositionedDirectional(end: -6, bottom: -10, child: Icon(Icons.card_giftcard_rounded, size: phone ? 64 : 110, color: G4MColors.primary.withValues(alpha: .25))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Pill(t.referAndEarn, bg: Colors.white, fg: G4MColors.primaryDeep, icon: Icons.favorite_rounded),
              SizedBox(height: phone ? 6 : 12),
              Text(t.referReward(context.l.money(s.referralReward)),
                  maxLines: 2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: phone ? 15 : 22, height: 1.15, color: G4MColors.ink)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ promises

class PromiseStrip extends StatelessWidget {
  const PromiseStrip({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final s = Shop.instance.settings;
          final t = context.l.home;
          final items = [
            if (s.quick15Enabled || s.quick30Enabled)
              (Icons.bolt_rounded, t.minuteDelivery(s.quick15Enabled ? 15 : 30), t.onEverydayEssentials),
            (Icons.local_shipping_outlined, t.freeDelivery, t.onOrdersAbove(context.l.money(s.freeDeliveryAbove))),
            if (s.scheduledEnabled) (Icons.event_available_outlined, t.scheduledSlots, t.pickATime),
            (Icons.verified_user_outlined, t.payYourWay, t.payMethods),
          ];
          final phone = context.isPhone;
          final children = [
            for (var i = 0; i < items.length; i++)
              Reveal(
                index: i,
                child: Container(
                  width: phone ? 230 : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(G4MRadius.md), border: Border.all(color: G4MColors.line)),
                  child: Row(children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: G4MColors.pastels[i % G4MColors.pastels.length], borderRadius: BorderRadius.circular(12)),
                      child: Icon(items[i].$1, color: G4MColors.primaryDeep, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(items[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        Text(items[i].$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ];
          if (phone) {
            return SizedBox(
              height: 72,
              child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: children.length, separatorBuilder: (_, _) => const SizedBox(width: 10), itemBuilder: (_, i) => children[i]),
            );
          }
          return Row(children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 14), Expanded(child: children[i])],
          ]);
        },
      );
}

// ------------------------------------------------------------------ categories

class CategoryRail extends StatelessWidget {
  const CategoryRail({super.key, this.moduleId, required this.accent});
  final String? moduleId;
  final Color accent;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Shop.instance,
        builder: (context, _) {
          final shop = Shop.instance;
          final cats = shop.roots(moduleId).take(moduleId == null ? 16 : 24).toList();
          if (shop.catalogReady && cats.isEmpty) return const SizedBox.shrink();
          final phone = context.isPhone;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(
              eyebrow: context.l.home.browseEyebrow,
              title: context.l.home.shopByCategory,
              subtitle: context.l.home.shopByCategorySub,
              viewAll: '/categories${moduleId == null ? '' : '?module=$moduleId'}',
              accent: accent,
            ),
            LayoutBuilder(builder: (context, c) {
              final tile = phone ? 96.0 : (c.maxWidth - 14 * 7) / 8;
              if (!shop.catalogReady) {
                return Wrap(spacing: 14, runSpacing: 14, children: [for (var i = 0; i < 8; i++) Skeleton(width: tile, height: tile + 34, radius: 22)]);
              }
              final tiles = [for (var i = 0; i < cats.length; i++) Reveal(index: i % 8, child: CategoryTile(category: cats[i], size: tile, index: i))];
              if (phone) {
                return SizedBox(
                  height: tile + 52,
                  child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: tiles.length, separatorBuilder: (_, _) => const SizedBox(width: 12), itemBuilder: (_, i) => tiles[i]),
                );
              }
              return Wrap(spacing: 14, runSpacing: 18, children: tiles);
            }),
          ]);
        },
      );
}

class CategoryTile extends StatefulWidget {
  const CategoryTile({super.key, required this.category, required this.size, required this.index});
  final Category category;
  final double size;
  final int index;
  @override
  State<CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<CategoryTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    final bg = G4MColors.pastels[widget.index % G4MColors.pastels.length];
    return SizedBox(
      width: widget.size,
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: AppLink(
          to: '/c/${c.slug}',
          label: c.name,
          child: Column(children: [
            AnimatedContainer(
              duration: G4MMotion.standard,
              curve: G4MMotion.curve,
              width: widget.size,
              height: widget.size,
              transform: Matrix4.translationValues(0, _h && !context.reduceMotion ? -4 : 0, 0),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(22),
                boxShadow: _h ? G4MShadows.lifted : const [],
              ),
              padding: EdgeInsets.all(widget.size * .14),
              child: AnimatedScale(
                scale: _h && !context.reduceMotion ? 1.08 : 1,
                duration: G4MMotion.emphasized,
                curve: G4MMotion.curve,
                child: c.image.isEmpty
                    ? Icon(moduleIcon(c.moduleId), size: widget.size * .4, color: G4MColors.primaryDeep)
                    : NetImage(c.image, fit: BoxFit.contain, semanticLabel: c.name),
              ),
            ),
            const SizedBox(height: 10),
            Text(c.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.25)),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ featured sections

class _FeaturedSections extends StatelessWidget {
  const _FeaturedSections({this.moduleId, required this.accent});
  final String? moduleId;
  final Color accent;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<FeaturedSection>>(
        stream: live('fs$moduleId', () => CatalogRepo.instance.featuredSections(moduleId: moduleId)),
        builder: (context, s) {
          final gap = SizedBox(height: context.isPhone ? 40 : 64);
          final list = s.data ?? const <FeaturedSection>[];
          final out = <Widget>[];
          if (s.hasData && list.isEmpty || s.hasError) {
            out.add(Contained(
              child: ProductsFuture(
                key: ValueKey('new$moduleId'),
                load: () => Data.list(moduleId: moduleId, limit: 14),
                builder: (l) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionHeader(eyebrow: context.l.home.freshInEyebrow, title: context.l.home.justArrived, subtitle: context.l.home.justArrivedSub, viewAll: '/search?sort=newest', accent: accent),
                  ProductCarousel(products: l),
                  gap,
                ]),
              ),
            ));
          }
          for (var i = 0; i < list.length; i++) {
            out.add(Contained(child: FeaturedSectionView(section: list[i], accent: accent, after: gap)));
            if (i == 1) out.add(Contained(child: _OfferBand(position: 'home_mid', moduleId: moduleId, take: 1)));
          }
          if (list.length < 2 && s.hasData) out.add(Contained(child: _OfferBand(position: 'home_mid', moduleId: moduleId, take: 1)));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
        },
      );
}

class FeaturedSectionView extends StatelessWidget {
  const FeaturedSectionView({super.key, required this.section, required this.accent, required this.after});
  final FeaturedSection section;
  final Color accent;
  final Widget after;

  String get _viewAll {
    final f = section;
    if (f.type == 'category') {
      final c = Shop.instance.categoryById(f.categoryId);
      if (c != null) return '/c/${c.slug}';
    }
    final sort = switch (f.type) { 'bestsellers' => 'popular', 'top_rated' => 'rating', 'deals' => 'discount', _ => 'newest' };
    return '/search?sort=$sort${f.moduleId.isEmpty ? '' : '&module=${f.moduleId}'}';
  }

  @override
  Widget build(BuildContext context) {
    final f = section;
    final header = SectionHeader(title: f.title, subtitle: f.subtitle, viewAll: _viewAll, accent: accent);
    return ProductsFuture(
      key: ValueKey('fs${f.id}${f.data['updatedAt']}'),
      load: () => Data.section(f, limit: f.style == 'grid' ? 12 : 14),
      skeleton: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const ProductCarousel(products: [], loading: true), after]),
      builder: (l) {
        final Widget body = switch (f.style) {
          'grid' => ProductGrid(products: l),
          'banner_left' => _BannerLeft(section: f, products: l, viewAll: _viewAll),
          _ => ProductCarousel(products: l),
        };
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, body, after]);
      },
    );
  }
}

class _BannerLeft extends StatelessWidget {
  const _BannerLeft({required this.section, required this.products, required this.viewAll});
  final FeaturedSection section;
  final List<Product> products;
  final String viewAll;
  @override
  Widget build(BuildContext context) {
    final bg = G4MColors.fromHex(section.bgColor, G4MColors.pastels[section.title.length % G4MColors.pastels.length]);
    final phone = context.isPhone;
    final cw = cardWidthFor(context);
    final banner = AppLink(
      to: viewAll,
      label: section.title,
      child: HoverLift(
        radius: 22,
        border: false,
        color: Colors.white,
        child: SizedBox(
          width: phone ? double.infinity : 280,
          height: phone ? 150 : cw + 170,
          child: section.bannerImage.isEmpty
              ? Container(
                  decoration: const BoxDecoration(gradient: G4MColors.heroGradient),
                  padding: const EdgeInsets.all(22),
                  alignment: AlignmentDirectional.bottomStart,
                  child: Text(section.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24, height: 1.15)),
                )
              : NetImage(section.bannerImage, semanticLabel: section.title),
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.all(phone ? 12 : 18),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
      child: phone
          ? Column(children: [banner, const SizedBox(height: 12), ProductCarousel(products: products)])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 8), child: banner),
              const SizedBox(width: 18),
              Expanded(child: Padding(padding: const EdgeInsetsDirectional.only(end: 18), child: ProductCarousel(products: products))),
            ]),
    );
  }
}

class _OfferBand extends StatelessWidget {
  const _OfferBand({required this.position, this.moduleId, this.skip = 0, this.take = 1});
  final String position;
  final String? moduleId;
  final int skip, take;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<PromoBanner>>(
        stream: live('offers$position$moduleId', () => Data.offers(position, moduleId: moduleId)),
        builder: (context, s) {
          final l = (s.data ?? const <PromoBanner>[]).skip(skip).take(take).toList();
          if (l.isEmpty) return const SizedBox.shrink();
          final phone = context.isPhone;
          return Padding(
            padding: EdgeInsets.only(bottom: phone ? 40 : 64),
            child: Column(children: [
              for (final o in l)
                Reveal(
                  child: AppLink(
                    to: o.link.isEmpty ? '/search?sort=discount' : o.link,
                    label: o.title.isEmpty ? context.l.home.offer : o.title,
                    child: HoverLift(
                      radius: 28,
                      lift: 4,
                      border: false,
                      child: AspectRatio(aspectRatio: phone ? 2.2 : 4.4, child: NetImage(o.image, semanticLabel: o.title.isEmpty ? context.l.home.offer : o.title)),
                    ),
                  ),
                ),
            ]),
          );
        },
      );
}

// ------------------------------------------------------------------ sellers

class SellerStrip extends StatelessWidget {
  const SellerStrip({super.key, this.moduleId});
  final String? moduleId;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: Shop.instance.city,
        builder: (context, city, _) => StreamBuilder<List<Seller>>(
          stream: live('sellers', () => CatalogRepo.instance.sellers(limit: 24)),
          builder: (context, s) {
            var l = s.data ?? const <Seller>[];
            if (city != null) {
              final inCity = l.where((e) => e.city.toLowerCase() == city.toLowerCase()).toList();
              if (inCity.isNotEmpty) l = inCity;
            }
            if (s.hasData && l.isEmpty || s.hasError) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(bottom: context.isPhone ? 40 : 64),
              child: Container(
                padding: EdgeInsets.all(context.isPhone ? 16 : 28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF1F8F4), Color(0xFFFFF7EE)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionHeader(
                    eyebrow: city == null ? context.l.home.marketplace : context.l.home.nearYouIn(city),
                    title: context.l.home.shopByStore,
                    subtitle: context.l.home.shopByStoreSub,
                  ),
                  SizedBox(
                    height: 96,
                    child: !s.hasData
                        ? ListView(scrollDirection: Axis.horizontal, children: [for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsetsDirectional.only(end: 12), child: Skeleton(width: 250, height: 96, radius: 20))])
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: l.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (_, i) => Reveal(index: i, child: SellerCard(seller: l[i])),
                          ),
                  ),
                ]),
              ),
            );
          },
        ),
      );
}

class SellerCard extends StatelessWidget {
  const SellerCard({super.key, required this.seller});
  final Seller seller;
  @override
  Widget build(BuildContext context) => AppLink(
        to: '/store/${seller.slug}',
        label: context.l.common.storeOf(seller.storeName),
        child: HoverLift(
          radius: 20,
          lift: 4,
          child: SizedBox(
            width: 260,
            height: 96,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: G4MColors.surfaceAlt, borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: seller.logo.isEmpty
                      ? Center(child: Text(seller.storeName.isEmpty ? 'S' : seller.storeName[0], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: G4MColors.primaryDeep)))
                      : NetImage(seller.logo, semanticLabel: context.l.home.storeLogo(seller.storeName)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(seller.storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (seller.rating > 0) ...[
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5A524)),
                        Text(' ${seller.rating.toStringAsFixed(1)}  ·  ', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ],
                      Flexible(
                        child: Text('${context.l.home.productsCount(seller.productCount)}${seller.city.isEmpty ? '' : ' · ${seller.city}'}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted)),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ------------------------------------------------------------------ deals / recent / blog

class _TrendingDeals extends StatelessWidget {
  const _TrendingDeals({this.moduleId, required this.accent});
  final String? moduleId;
  final Color accent;
  @override
  Widget build(BuildContext context) => ProductsFuture(
        key: ValueKey('deals$moduleId'),
        load: () => Data.deals(moduleId: moduleId, limit: 9),
        skeleton: const SizedBox(height: 200),
        builder: (l) => Padding(
          padding: EdgeInsets.only(bottom: context.isPhone ? 40 : 64),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(
              eyebrow: context.l.home.dealsEyebrow,
              title: context.l.home.trendingDeals,
              subtitle: context.l.home.trendingDealsSub,
              viewAll: '/search?sort=discount${moduleId == null ? '' : '&module=$moduleId'}',
              accent: kAccentInk,
            ),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth > 1000 ? 3 : (c.maxWidth > 640 ? 2 : 1);
              final w = (c.maxWidth - 14 * (cols - 1)) / cols;
              return Wrap(spacing: 14, runSpacing: 14, children: [
                for (var i = 0; i < l.length; i++)
                  SizedBox(
                    width: w,
                    child: Reveal(
                      index: i % 3,
                      child: Stack(children: [
                        ProductRow(product: l[i], dense: true),
                        PositionedDirectional(
                          top: 8,
                          start: 8,
                          child: Pill('-${context.l.pct(l[i].discountPct)}', bg: G4MColors.accent, fg: G4MColors.ink),
                        ),
                      ]),
                    ),
                  ),
              ]);
            }),
          ]),
        ),
      );
}

class _RecentlyViewed extends StatelessWidget {
  const _RecentlyViewed();
  @override
  Widget build(BuildContext context) {
    final ids = Shop.instance.recentlyViewed.take(14).toList();
    if (ids.isEmpty) return const SizedBox.shrink();
    return ProductsFuture(
      key: ValueKey(ids.join()),
      load: () => CatalogRepo.instance.productsByIds(ids),
      skeleton: const SizedBox.shrink(),
      builder: (l) => Padding(
        padding: EdgeInsets.only(bottom: context.isPhone ? 40 : 64),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader(eyebrow: context.l.home.recentEyebrow, title: context.l.home.recentlyViewed),
          ProductCarousel(products: l),
        ]),
      ),
    );
  }
}

class _BlogTeasers extends StatelessWidget {
  const _BlogTeasers();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Blog>>(
        stream: live('blogs3', () => Data.blogs(limit: 3)),
        builder: (context, s) {
          final l = s.data ?? const <Blog>[];
          if (l.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(bottom: context.isPhone ? 40 : 64),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionHeader(eyebrow: context.l.home.journalEyebrow, title: context.l.home.journalTitle, viewAll: '/blog'),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 600 ? 2 : 1);
                final w = (c.maxWidth - 18 * (cols - 1)) / cols;
                return Wrap(spacing: 18, runSpacing: 18, children: [
                  for (var i = 0; i < l.length; i++) SizedBox(width: w, child: Reveal(index: i, child: BlogCard(blog: l[i]))),
                ]);
              }),
            ]),
          );
        },
      );
}

class BlogCard extends StatelessWidget {
  const BlogCard({super.key, required this.blog});
  final Blog blog;
  @override
  Widget build(BuildContext context) => AppLink(
        to: '/blog/${blog.slug}',
        label: blog.title,
        child: HoverLift(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 16 / 9, child: NetImage(blog.cover, semanticLabel: blog.title)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${context.l.date(blog.publishedAt)}  ·  ${blog.author}', style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(blog.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.3)),
                const SizedBox(height: 8),
                Text(blog.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: G4MColors.inkMuted, height: 1.5)),
                const SizedBox(height: 12),
                Text(context.l.home.readArticle, style: const TextStyle(color: G4MColors.primary, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ bands

class AppBand extends StatelessWidget {
  const AppBand({super.key});
  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    return Reveal(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(32)),
        child: Stack(children: [
          PositionedDirectional(end: -80, top: -80, child: Container(width: 320, height: 320, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),
          PositionedDirectional(end: 120, bottom: -120, child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, color: G4MColors.accent.withValues(alpha: .18)))),
          Padding(
            padding: EdgeInsets.all(phone ? 24 : 48),
            child: Flex(direction: phone ? Axis.vertical : Axis.horizontal, crossAxisAlignment: phone ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
              Flexible(
                flex: phone ? 0 : 1,
                fit: FlexFit.loose,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Pill(context.l.home.appPill, bg: G4MColors.accent, fg: G4MColors.ink, icon: Icons.phone_iphone_rounded),
                  const SizedBox(height: 14),
                  Heading(context.l.home.appTitle, level: 2, style: TextStyle(color: Colors.white, fontSize: phone ? 24 : 34)),
                  const SizedBox(height: 10),
                  Text(context.l.home.appBody,
                      style: const TextStyle(color: Color(0xFFD6EADF), fontSize: 16, height: 1.5)),
                  const SizedBox(height: 22),
                  _StoreBadge(icon: Icons.shop_rounded, top: context.l.home.getItOn, label: 'Google Play', to: kPlayUrl),
                ]),
              ),
              if (!phone) ...[
                const SizedBox(width: 40),
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(48), boxShadow: G4MShadows.lifted),
                  padding: const EdgeInsets.all(36),
                  child: const G4MLogo(size: 150),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StoreBadge extends StatelessWidget {
  const _StoreBadge({required this.icon, required this.top, required this.label, required this.to});
  final IconData icon;
  final String top, label, to;
  @override
  Widget build(BuildContext context) => AppLink(
        to: to,
        label: context.l.home.getItOnStore(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF07110C), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x33FFFFFF))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(top, style: const TextStyle(color: Color(0xFFD6EADF), fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .8)),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
          ]),
        ),
      );
}

class GrowBand extends StatelessWidget {
  const GrowBand({super.key});
  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final t = context.l.home;
    Widget card({required Color bg, required IconData icon, required Color iconBg, required String title, required String body, required List<String> points, required String cta, required String to, required int i}) =>
        Reveal(
          index: i,
          child: HoverLift(
            radius: 28,
            color: bg,
            border: false,
            child: Padding(
              padding: EdgeInsets.all(phone ? 22 : 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 56, height: 56, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(18)), child: Icon(icon, color: Colors.white, size: 28)),
                const SizedBox(height: 18),
                Heading(title, level: 3, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 8),
                Text(body, style: const TextStyle(color: G4MColors.inkMuted, height: 1.5, fontSize: 15)),
                const SizedBox(height: 14),
                for (final p in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: G4MColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ]),
                  ),
                const SizedBox(height: 16),
                AppLink(
                  to: to,
                  label: cta,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: G4MColors.primaryDeep, borderRadius: BorderRadius.circular(G4MRadius.pill)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(cta, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Transform.flip(flipX: context.l.rtl, child: const Icon(Icons.north_east_rounded, color: Colors.white, size: 18)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        );
    final a = card(
      i: 0,
      bg: const Color(0xFFFFF4E6),
      icon: Icons.storefront_rounded,
      iconBg: kAccentInk,
      title: t.becomeSeller,
      body: t.sellerBody,
      points: t.sellerPoints,
      cta: t.startSelling,
      to: kSellerUrl,
    );
    final b = card(
      i: 1,
      bg: const Color(0xFFE8F6EE),
      icon: Icons.delivery_dining_rounded,
      iconBg: G4MColors.primary,
      title: t.becomeRider,
      body: t.riderBody,
      points: t.riderPoints,
      cta: t.joinAsRider,
      to: kDeliveryUrl,
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(eyebrow: t.growEyebrow, title: t.partnerWithUs, subtitle: t.partnerSub),
      phone ? Column(children: [a, const SizedBox(height: 14), b]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 18), Expanded(child: b)]),
    ]);
  }
}
