import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/prefs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../core/addons.dart';
import '../../widgets/addon_selector.dart';
import '../../widgets/cart_fx.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui.dart';
import '../auth/auth_screens.dart';
import '../cart/cart_screen.dart';
import '../profile/addresses_screen.dart';
import 'seller_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product, required this.heroTag});
  final Product product;
  final String heroTag;
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _p = widget.product;
  String? _variantId;
  int _img = 0;
  bool _descOpen = false;

  /// Selected food add-on ids (FEATURES #04).
  Set<String> _addons = {};
  List<ProductAddon> get _addonList => addonsOf(_p);
  double get _addonTotal => addonTotal(_addonList, _addons);
  late final Future<Seller?> _seller = _loadSeller();
  late final Future<List<Product>> _similar = Catalog.similar(widget.product);
  late final Future<List<Product>> _cross = Catalog.crossSell(widget.product);
  late final Stream<Product?> _live = CatalogRepo.instance.watchProduct(widget.product.id);
  late final Stream<List<Review>> _reviewStream = CatalogRepo.instance.reviews(widget.product.id);

  @override
  void initState() {
    super.initState();
    _variantId = _p.variants.isEmpty ? null : (_p.variants.firstWhere((v) => v.stock > 0, orElse: () => _p.variants.first)).id;
    if (Session.instance.signedIn) ShopperRepo.instance.markViewed(_p.id).catchError((_) {});
  }

  Future<Seller?> _loadSeller() async {
    if (_p.sellerId.isEmpty) return null;
    try {
      final d = await Fs.sellers.doc(_p.sellerId).get();
      return d.exists ? Seller.fromDoc(d) : null;
    } catch (_) {
      return null;
    }
  }

  Variant? get _variant {
    if (_variantId == null) return null;
    for (final v in _p.variants) {
      if (v.id == _variantId) return v;
    }
    return null;
  }

  double get _price => _variant?.price ?? _p.price;
  double get _mrp => _variant?.mrp ?? _p.mrp;
  int get _stock => _variant?.stock ?? _p.stock;

  void _share() {
    final url = 'https://go4market.web.app/product/${_p.slug}';
    SharePlus.instance.share(ShareParams(text: '${_p.name} for ${Fmt.money(_price)} on Go4Market\n$url', subject: _p.name));
  }

  Future<void> _writeReview() async {
    if (!await requireAccount(context)) return;
    final ok = await MyData.hasDelivered(_p.id);
    if (!mounted) return;
    if (!ok) {
      context.toast('You can review this product after it is delivered to you.');
      return;
    }
    await showAppSheet(context, builder: (_) => ReviewSheet(productId: _p.id, productName: _p.name));
  }

  Future<void> _subscribe() async {
    if (!await requireAccount(context)) return;
    if (!mounted) return;
    await showAppSheet(context, builder: (_) => SubscribeSheet(product: _p, variantId: _variantId ?? 'default'));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<Product?>(
      stream: _live,
      initialData: widget.product,
      builder: (context, snap) {
        if (snap.data != null) _p = snap.data!;
        final images = _p.images.isEmpty ? [''] : _p.images;
        final width = MediaQuery.sizeOf(context).width;
        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: width * .95,
              backgroundColor: context.card,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(backgroundColor: context.card.withValues(alpha: .9)),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              actions: [
                IconButton(onPressed: _share, icon: const Icon(Icons.ios_share_rounded)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: WishButton(productId: _p.id, size: 20)),
                const CartAction(),
              ],
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(children: [
                  PageView.builder(
                    itemCount: images.length,
                    onPageChanged: (i) => setState(() => _img = i),
                    itemBuilder: (_, i) {
                      final img = Padding(
                        padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 56, 24, 28),
                        child: Img(images[i], fit: BoxFit.contain, radius: 20, iconSize: 64),
                      );
                      return GestureDetector(
                        onTap: () => _openViewer(images, i),
                        child: i == 0 ? Hero(tag: widget.heroTag, child: img) : img,
                      );
                    },
                  ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < images.length; i++)
                          AnimatedContainer(
                            duration: G4MMotion.standard,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _img ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(color: i == _img ? G4MColors.primary : context.line, borderRadius: BorderRadius.circular(4)),
                          ),
                      ]),
                    ),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: _info(context, l)),
            SliverToBoxAdapter(
              child: _ProductRail(title: l.frequentlyBought, future: _cross, scope: 'cross-${_p.id}'),
            ),
            SliverToBoxAdapter(
              child: _ProductRail(title: l.similarProducts, future: _similar, scope: 'sim-${_p.id}'),
            ),
            SliverToBoxAdapter(child: _reviews(context, l)),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ]),
          bottomNavigationBar: _bottomBar(context, l),
        );
      },
    );
  }

  void _openViewer(List<String> images, int start) {
    if (images.first.isEmpty) return;
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _ImageViewer(images: images, start: start),
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  Widget _info(BuildContext context, AppLocalizations l) {
    final p = _p;
    // Add-ons are added to both price and MRP, the same way the order engine prices the line.
    final unit = _price + _addonTotal;
    final unitMrp = _mrp + _addonTotal;
    final off = unitMrp > unit && unitMrp > 0 ? (((unitMrp - unit) / unitMrp) * 100).round() : 0;
    final addons = _addonList;
    return Container(
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (p.isVeg != null) ...[VegMark(isVeg: p.isVeg!, size: 16), const SizedBox(width: 8)],
          if (p.brandName.isNotEmpty)
            Text(p.brandName.toUpperCase(), style: context.text.labelMedium?.copyWith(color: G4MColors.primary, letterSpacing: 1, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (p.rating > 0) ...[
            RatingStars(p.rating, size: 15),
            Text(' ${p.rating.toStringAsFixed(1)} (${p.ratingCount})', style: context.text.bodySmall),
          ],
        ]).stagger(0),
        const SizedBox(height: 8),
        Text(p.name, style: context.text.headlineSmall?.copyWith(height: 1.25)).stagger(1),
        if (p.unit.isNotEmpty) Text(p.unit, style: context.text.bodyMedium?.copyWith(color: context.muted)).stagger(2),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          AnimatedSwitcher(
            duration: G4MMotion.standard,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, .3), end: Offset.zero).animate(a), child: c)),
            child: Text(Fmt.money(unit), key: ValueKey(unit), style: context.text.headlineMedium),
          ),
          const SizedBox(width: 10),
          if (off > 0) ...[
            Text(Fmt.money(unitMrp), style: TextStyle(decoration: TextDecoration.lineThrough, color: context.muted, fontSize: 16)),
            const SizedBox(width: 10),
            Tag('$off% OFF'),
          ],
        ]).stagger(3),
        Text('Inclusive of all taxes', style: context.text.bodySmall),
        if (p.variants.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Choose an option', style: context.text.titleSmall),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final v in p.variants) _VariantChip(v: v, selected: v.id == _variantId, onTap: () => setState(() => _variantId = v.id)),
          ]).stagger(4),
        ],
        if (addons.isNotEmpty) ...[
          const SizedBox(height: 18),
          AddonSelector(
            addons: addons,
            selected: _addons,
            onChanged: (s) => setState(() => _addons = s),
            onLimit: (g) => context.toast(
                '${g.name.isEmpty ? 'You can' : '${g.name}: you can'} choose up to ${g.maxSelect} add-on${g.maxSelect == 1 ? '' : 's'}'),
          ).stagger(4),
        ],
        const SizedBox(height: 16),
        _StockLine(stock: _stock, lowAt: p.lowStockAt, l: l).stagger(5),
        const SizedBox(height: 14),
        FutureBuilder<Seller?>(
          future: _seller,
          builder: (context, snap) => _DeliveryCard(product: p, seller: snap.data, l: l),
        ).stagger(6),
        const SizedBox(height: 12),
        FutureBuilder<Seller?>(
          future: _seller,
          builder: (context, snap) {
            final s = snap.data;
            final name = s?.storeName ?? p.sellerName;
            if (name.isEmpty) return const SizedBox.shrink();
            return AppCard(
              padding: const EdgeInsets.all(12),
              onTap: p.sellerId.isEmpty ? null : () => context.push(SellerScreen(sellerId: p.sellerId, seller: s)),
              child: Row(children: [
                ClipOval(child: Img(s?.logo ?? '', width: 42, height: 42, iconSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.seller, style: context.text.bodySmall),
                    Text(name, style: context.text.titleSmall),
                  ]),
                ),
                if ((s?.rating ?? 0) > 0) Tag('★ ${s!.rating.toStringAsFixed(1)}', color: G4MColors.success),
                const Icon(Icons.chevron_right_rounded),
              ]),
            );
          },
        ).stagger(7),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(12),
          color: context.softAccent,
          onTap: _subscribe,
          child: Row(children: [
            const Icon(Icons.autorenew_rounded, color: G4MColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Subscribe & never run out', style: context.text.titleSmall),
                Text('Daily, weekly or monthly delivery. Pause any time.', style: context.text.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ).stagger(8),
        if (p.description.isNotEmpty || p.shortDescription.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l.description, style: context.text.titleMedium),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: G4MMotion.emphasized,
            curve: G4MMotion.curve,
            alignment: Alignment.topCenter,
            child: Text(
              p.description.isNotEmpty ? p.description : p.shortDescription,
              maxLines: _descOpen ? null : 4,
              overflow: _descOpen ? TextOverflow.visible : TextOverflow.fade,
              style: context.text.bodyMedium?.copyWith(height: 1.55, color: context.muted),
            ),
          ),
          TextButton(onPressed: () => setState(() => _descOpen = !_descOpen), child: Text(_descOpen ? 'Show less' : 'Read more')),
        ],
        if (p.customFields.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Details', style: context.text.titleMedium),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, e) in p.customFields.entries.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    border: i == 0 ? null : Border(top: BorderSide(color: context.line)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 130, child: Text(Fmt.titleCase(e.key), style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
                    Expanded(child: Text(_fieldValue(e.value), style: context.text.bodyMedium)),
                  ]),
                ),
            ]),
          ),
        ],
        if (p.tags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final t in p.tags) Chip(label: Text('#$t'), visualDensity: VisualDensity.compact)]),
        ],
      ]),
    );
  }

  static String _fieldValue(dynamic v) => switch (v) {
        bool b => b ? 'Yes' : 'No',
        List l => l.join(', '),
        Map m => m.entries.map((e) => '${e.key}: ${e.value}').join(', '),
        _ => '$v',
      };

  Widget _reviews(BuildContext context, AppLocalizations l) => StreamBuilder<List<Review>>(
        stream: _reviewStream,
        builder: (context, snap) {
          final list = snap.data ?? const <Review>[];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l.reviews, style: context.text.titleLarge?.copyWith(fontSize: 19))),
                TextButton.icon(onPressed: _writeReview, icon: const Icon(Icons.rate_review_outlined, size: 18), label: Text(l.writeReview)),
              ]),
              if (_p.ratingCount > 0)
                AppCard(
                  child: Row(children: [
                    Column(children: [
                      Text(_p.rating.toStringAsFixed(1), style: context.text.displaySmall),
                      RatingStars(_p.rating, size: 14),
                      const SizedBox(height: 4),
                      Text('${_p.ratingCount} ratings', style: context.text.bodySmall),
                    ]),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(children: [
                        for (var s = 5; s >= 1; s--) _RatingBar(star: s, share: list.isEmpty ? 0 : list.where((r) => r.rating == s).length / list.length),
                      ]),
                    ),
                  ]),
                ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                Text('No reviews yet. Be the first after your delivery.', style: context.text.bodySmall)
              else
                for (final (i, r) in list.take(6).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: context.softPrimary,
                            child: Text(r.userName.isEmpty ? '?' : r.userName[0].toUpperCase(),
                                style: const TextStyle(color: G4MColors.primary, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(r.userName, style: context.text.titleSmall)),
                          Text(Fmt.ago(r.createdAt), style: context.text.bodySmall),
                        ]),
                        const SizedBox(height: 8),
                        RatingStars(r.rating.toDouble(), size: 14),
                        if (r.comment.isNotEmpty) ...[const SizedBox(height: 6), Text(r.comment, style: context.text.bodyMedium)],
                      ]),
                    ),
                  ).stagger(i),
            ]),
          );
        },
      );

  Widget _bottomBar(BuildContext context, AppLocalizations l) {
    final inStock = _stock > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: context.card,
        boxShadow: const [BoxShadow(color: Color(0x140A4A33), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            MoneyText(_price + _addonTotal, style: context.text.titleLarge),
            Text(
              _addons.isEmpty ? (_variant?.name ?? _p.unit) : '${_addons.length} add-on${_addons.length == 1 ? '' : 's'} · ${Fmt.money(_addonTotal)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Row(children: [
            Expanded(
              child: _addonList.isNotEmpty
                  ? _AddCustomisedButton(
                      product: _p,
                      variantId: _variantId ?? 'default',
                      addonIds: _addons,
                      unitPrice: _price + _addonTotal,
                      stock: _stock,
                      label: inStock ? l.addToCart : l.outOfStock,
                    )
                  : AddToCartButton(
                      key: ValueKey(_variantId),
                      product: _p,
                      variantId: _variantId,
                      height: 50,
                      expanded: true,
                      label: inStock ? l.addToCart : l.outOfStock,
                    ),
            ),
            ValueListenableBuilder(
              valueListenable: Session.instance.cart,
              builder: (context, _, _) {
                final has = Session.instance.cartCount > 0;
                return AnimatedSize(
                  duration: G4MMotion.standard,
                  child: has
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: G4MColors.accent, minimumSize: const Size(50, 50)),
                            onPressed: () => context.push(const CartScreen(standalone: true), style: RouteStyle.sharedY),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ).animate().scale(curve: Curves.easeOutBack),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

/// "Add · ₹X" for items with add-ons. Every tap adds one of the current combination as its own
/// cart line (lines with different add-on sets stay separate); a badge counts this item in the cart.
class _AddCustomisedButton extends StatefulWidget {
  const _AddCustomisedButton({
    required this.product,
    required this.variantId,
    required this.addonIds,
    required this.unitPrice,
    required this.stock,
    required this.label,
  });
  final Product product;
  final String variantId;
  final Set<String> addonIds;
  final double unitPrice;
  final int stock;
  final String label;
  @override
  State<_AddCustomisedButton> createState() => _AddCustomisedButtonState();
}

class _AddCustomisedButtonState extends State<_AddCustomisedButton> {
  bool _busy = false;

  Future<void> _add(BuildContext bctx) async {
    final s = Session.instance;
    final inCart = s.qtyVariantAll(widget.product.id, widget.variantId);
    if (widget.stock > 0 && inCart + 1 > widget.stock) {
      context.toast('Only ${widget.stock} available');
      return;
    }
    HapticFeedback.mediumImpact();
    flyToCart(bctx, widget.product.image);
    setState(() => _busy = true);
    try {
      // Only ids the product still offers (the live doc may have changed since they were picked).
      final chosen = selectedAddons(widget.product, widget.addonIds);
      await s.addLine(widget.product, widget.variantId, chosen.map((a) => a.id));
      if (mounted && chosen.isNotEmpty) context.toast('Added with ${chosen.map((a) => a.name).join(', ')}');
    } catch (e) {
      if (mounted) context.toast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stock <= 0) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: context.cardAlt, borderRadius: BorderRadius.circular(10)),
        child: Text(widget.label, style: TextStyle(fontWeight: FontWeight.w700, color: context.muted)),
      );
    }
    return Builder(
      builder: (bctx) => Pressable(
        onTap: _busy ? null : () => _add(bctx),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: G4MColors.primary,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0x330B8A4F), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: AnimatedSwitcher(
                duration: G4MMotion.standard,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0, .5), end: Offset.zero).animate(a), child: c),
                ),
                child: Text(
                  'Add · ${Fmt.money(widget.unitPrice)}',
                  key: ValueKey(widget.unitPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: Session.instance.cart,
              builder: (context, _, _) {
                final n = Session.instance.qtyAll(widget.product.id);
                return AnimatedSwitcher(
                  duration: G4MMotion.standard,
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: n == 0
                      ? const SizedBox.shrink()
                      : Container(
                          key: ValueKey(n),
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(G4MRadius.pill)),
                          child: Text('$n', style: const TextStyle(color: G4MColors.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({required this.v, required this.selected, required this.onTap});
  final Variant v;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: G4MMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? context.softPrimary : context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? G4MColors.primary : context.line, width: selected ? 1.6 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name.isEmpty ? v.id : v.name,
                style: TextStyle(fontWeight: FontWeight.w800, color: v.stock <= 0 ? context.muted : context.ink)),
            const SizedBox(height: 2),
            Text(v.stock <= 0 ? 'Sold out' : Fmt.money(v.price),
                style: TextStyle(fontSize: 12, color: v.stock <= 0 ? G4MColors.danger : context.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _StockLine extends StatelessWidget {
  const _StockLine({required this.stock, required this.lowAt, required this.l});
  final int stock, lowAt;
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) {
    final (color, text, icon) = stock <= 0
        ? (G4MColors.danger, l.outOfStock, Icons.remove_shopping_cart_outlined)
        : stock <= lowAt
            ? (G4MColors.warning, l.onlyLeft(stock), Icons.local_fire_department_rounded)
            : (G4MColors.success, l.inStock, Icons.check_circle_rounded);
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      if (stock > 0 && stock <= lowAt) ...[
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (stock / (lowAt * 2)).clamp(.05, 1)),
              duration: G4MMotion.slow,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, color: color, backgroundColor: color.withValues(alpha: .15)),
            ),
          ),
        ),
      ],
    ]);
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.product, required this.seller, required this.l});
  final Product product;
  final Seller? seller;
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) {
    final loc = AppPrefs.instance.location;
    double? km;
    final sLat = seller?.data['lat'], sLng = seller?.data['lng'];
    if (loc?.hasPoint == true && sLat is num && sLng is num) {
      km = haversineKm(loc!.lat!, loc.lng!, sLat.toDouble(), sLng.toDouble());
    }
    final eta = product.deliveryMinutes + (km == null ? 0 : (km * 2.5).round());
    final quick = eta <= 30;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: quick ? context.softAccent : context.softPrimary, borderRadius: BorderRadius.circular(14)),
          child: Icon(quick ? Icons.bolt_rounded : Icons.local_shipping_outlined, color: quick ? G4MColors.accent : G4MColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.deliveryIn(eta), style: context.text.titleSmall),
            Text(
              [
                if (km != null) '${km.toStringAsFixed(1)} km away',
                if (loc != null) 'to ${loc.label}' else 'Set your location for an exact ETA',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.star, required this.share});
  final int star;
  final double share;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 14, child: Text('$star', style: context.text.bodySmall)),
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF5A524)),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: share),
                duration: G4MMotion.slow,
                curve: G4MMotion.curve,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: star >= 4 ? G4MColors.success : (star == 3 ? G4MColors.warning : G4MColors.danger),
                  backgroundColor: context.cardAlt,
                ),
              ),
            ),
          ),
        ]),
      );
}

class _ProductRail extends StatelessWidget {
  const _ProductRail({required this.title, required this.future, required this.scope});
  final String title;
  final Future<List<Product>> future;
  final String scope;
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
        future: future,
        builder: (context, snap) {
          final list = snap.data;
          if (list != null && list.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title),
            list == null ? const CarouselSkeleton() : ProductCarousel(products: list, scope: scope),
          ]);
        },
      );
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.images, required this.start});
  final List<String> images;
  final int start;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: PageView.builder(
          controller: PageController(initialPage: start),
          itemCount: images.length,
          itemBuilder: (_, i) => InteractiveViewer(maxScale: 4, child: Center(child: Img(images[i], fit: BoxFit.contain))),
        ),
      );
}

/// Star picker + comment -> `submitReview` callable.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key, required this.productId, required this.productName});
  final String productId, productName;
  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  int _rating = 0;
  final _ctl = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (_rating == 0) return context.toast('Tap a star to rate');
    setState(() => _busy = true);
    try {
      await G4MApi.instance.submitReview(widget.productId, _rating, _ctl.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
        globalToast('Thanks for your review!');
      }
    } catch (e) {
      if (mounted) {
        context.toast(
          isPermissionError(e) ? 'Reviews open after the product is delivered to you.' : friendlyError(e),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Rate ${widget.productName}', style: context.text.titleLarge, maxLines: 2),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  onPressed: () => setState(() => _rating = i),
                  icon: AnimatedScale(
                    scale: _rating >= i ? 1.15 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Icon(_rating >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: _rating >= i ? const Color(0xFFF5A524) : context.muted),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _ctl, maxLines: 4, decoration: const InputDecoration(hintText: 'What did you like or dislike?')),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Submitting…' : 'Submit review')),
          ]),
        ),
      );
}

/// Creates a `subscriptions/{id}` doc (scheduled function `runSubscriptions` places the orders).
class SubscribeSheet extends StatefulWidget {
  const SubscribeSheet({super.key, required this.product, required this.variantId});
  final Product product;
  final String variantId;
  @override
  State<SubscribeSheet> createState() => _SubscribeSheetState();
}

class _SubscribeSheetState extends State<SubscribeSheet> {
  int _qty = 1;
  String _freq = 'daily';
  Address? _addr;
  bool _busy = false;
  final _addrStream = ShopperRepo.instance.addresses();

  Future<void> _save() async {
    if (_addr == null) return context.toast('Choose a delivery address', error: true);
    setState(() => _busy = true);
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await Fs.subscriptions.add({
        'userId': Session.instance.uid,
        'productId': widget.product.id,
        'variantId': widget.variantId,
        'productName': widget.product.name,
        'image': widget.product.image,
        'price': widget.product.price,
        'qty': _qty,
        'frequency': _freq,
        'nextRunAt': Timestamp.fromDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7)),
        'status': 'active',
        'addressId': _addr!.id,
        'createdAt': Fs.now,
        'updatedAt': Fs.now,
      });
      if (mounted) {
        Navigator.of(context).pop(true);
        globalToast('Subscription started. First delivery tomorrow morning.');
      }
    } catch (e) {
      if (mounted) context.toast(isPermissionError(e) ? 'Subscriptions are not enabled for your account yet.' : friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Subscribe', style: context.text.titleLarge),
            Text(widget.product.name, style: context.text.bodySmall),
            const SizedBox(height: 16),
            Text('How often?', style: context.text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ],
              selected: {_freq},
              onSelectionChanged: (s) => setState(() => _freq = s.first),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('Quantity each delivery', style: context.text.titleSmall)),
              IconButton.outlined(onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove_rounded)),
              SizedBox(width: 36, child: Text('$_qty', textAlign: TextAlign.center, style: context.text.titleMedium)),
              IconButton.outlined(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add_rounded)),
            ]),
            const SizedBox(height: 16),
            StreamBuilder<List<Address>>(
              stream: _addrStream,
              builder: (context, snap) {
                final list = snap.data ?? const <Address>[];
                _addr ??= list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
                return AppCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () async {
                    final a = await pickAddress(context, selectedId: _addr?.id);
                    if (a != null) setState(() => _addr = a);
                  },
                  child: Row(children: [
                    const Icon(Icons.home_outlined, color: G4MColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_addr?.oneLine ?? 'Add a delivery address', maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                );
              },
            ),
            const SizedBox(height: 8),
            Text('Est. ${Fmt.money(widget.product.price * _qty)} per delivery · charged when each order is placed',
                style: context.text.bodySmall),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Start subscription')),
          ]),
        ),
      );
}
