import 'dart:async';

import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/data.dart';
import '../core/payment_flow.dart';
import '../core/push.dart';
import '../core/shop.dart';
import '../l10n/l10n.dart';
import '../ui/address_form.dart';
import '../ui/kit.dart';
import '../ui/product_widgets.dart';
import '../ui/shell.dart';

/// Single-screen cart + checkout (features 13, 14, 17, 20, 23-26, 29-32).
class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final shop = Shop.instance;
  final _products = <String, Product>{};
  final _missing = <String>{};
  String _sig = '';

  String _deliveryType = 'home';
  String? _addressId;
  String _speed = 'standard';
  DateTime? _slotDate;
  Json? _slot;
  String? _coupon;
  String? _couponMsg;
  bool _couponOk = false;
  final _couponCtl = TextEditingController();
  bool _useWallet = false;
  String? _payment;

  Json? _quote;
  Object? _quoteError;
  bool _quoting = false;
  Timer? _debounce;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    shop.addListener(_onShop);
    _onShop();
  }

  @override
  void dispose() {
    shop.removeListener(_onShop);
    _debounce?.cancel();
    _couponCtl.dispose();
    super.dispose();
  }

  void _onShop() {
    final ids = shop.cart.values.map((c) => c.productId).toSet();
    final need = ids.where((id) => !_products.containsKey(id) && !_missing.contains(id)).toList();
    if (need.isNotEmpty) {
      CatalogRepo.instance.productsByIds(need).then((l) {
        for (final p in l) {
          _products[p.id] = p;
        }
        _missing.addAll(need.where((id) => !l.any((p) => p.id == id)));
        if (mounted) setState(() {});
      }).catchError((Object _) {});
    }
    final sig = shop.cart.values.map((c) => '${c.id}:${c.qty}').join(',');
    if (sig != _sig) {
      _sig = sig;
      _requote();
    }
  }

  Json get _input => {
        'addressId': _deliveryType == 'home' ? _addressId : null,
        'couponCode': _coupon,
        'useWallet': _useWallet,
        'speed': _deliveryType == 'pickup' ? 'standard' : _speed,
        'deliveryType': _deliveryType,
        if (_deliveryType == 'home' && _speed == 'scheduled' && _slot != null) 'scheduledSlot': _slot,
      };

  void _requote() {
    _debounce?.cancel();
    if (shop.cart.isEmpty || shop.user == null) {
      setState(() => _quote = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _quoting = true);
      try {
        final q = await G4MApi.instance.checkoutQuote(_input);
        _quote = q;
        _quoteError = null;
        final ce = q['couponError'];
        if (_coupon != null && ce != null && '$ce'.isNotEmpty) {
          _couponMsg = '$ce';
          _couponOk = false;
        }
      } catch (e) {
        _quoteError = e;
      }
      if (mounted) setState(() => _quoting = false);
    });
  }

  double get _localSubtotal => shop.cart.values.fold(0.0, (a, c) {
        final p = _products[c.productId];
        if (p == null) return a;
        final v = p.variants.where((e) => e.id == c.variantId).firstOrNull;
        return a + (v?.price ?? p.price) * c.qty;
      });

  Set<String> get _unavailable {
    final out = <String>{};
    final u = _quote?['unavailable'];
    if (u is List) {
      for (final e in u) {
        if (e is Map) {
          if (e['itemId'] != null) out.add('${e['itemId']}');
          out.add('${e['productId']}_${e['variantId'] ?? 'default'}');
          out.add('${e['productId']}');
        } else {
          out.add('$e');
        }
      }
    }
    for (final c in shop.cart.values) {
      final p = _products[c.productId];
      if (p == null) continue;
      final v = p.variants.where((e) => e.id == c.variantId).firstOrNull;
      final stock = v?.stock ?? p.stock;
      if (stock < c.qty || p.status != 'active') out.add(c.id);
    }
    return out;
  }

  bool _isUnavailable(CartItem c) {
    final u = _unavailable;
    return u.contains(c.id) || u.contains(c.productId) || _missing.contains(c.productId);
  }

  Future<void> _applyCoupon(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return;
    _couponCtl.text = c;
    setState(() {
      _couponMsg = context.l.cart.checking;
      _couponOk = false;
    });
    try {
      final r = await G4MApi.instance.validateCoupon(c, (_quote?['subtotal'] as num?)?.toDouble() ?? _localSubtotal);
      final ok = r['valid'] == true;
      setState(() {
        _couponOk = ok;
        _couponMsg = ok
            ? '${context.l.cart.youSave(context.l.money((r['discount'] as num?) ?? 0))}${r['message'] != null ? ' · ${r['message']}' : ''}'
            : '${r['message'] ?? context.l.cart.couponInvalid}';
        _coupon = ok ? c : null;
      });
      _requote();
    } catch (e) {
      setState(() => _couponMsg = friendlyError(e));
    }
  }

  List<(String, String, IconData)> _payMethods(double payable) {
    final s = shop.settings, p = shop.payments, t = L.current.cart;
    final codMax = (s.data['codMax'] as num?)?.toDouble() ?? 0;
    return [
      if (payable <= 0) ('wallet', t.payFromWallet, Icons.account_balance_wallet_rounded),
      if (payable > 0 && p.razorpayEnabled) ('razorpay', t.payRazorpay, Icons.qr_code_2_rounded),
      if (payable > 0 && p.stripeEnabled) ('stripe', t.payStripe, Icons.credit_card_rounded),
      if (payable > 0 && p.paypalEnabled) ('paypal', t.payPaypal, Icons.account_balance_rounded),
      if (payable > 0 && s.codEnabled && p.codEnabled && (codMax <= 0 || payable <= codMax)) ('cod', t.payCod, Icons.payments_outlined),
    ];
  }

  Future<void> _place() async {
    final payable = (_quote?['payable'] as num?)?.toDouble() ?? _localSubtotal;
    final methods = _payMethods(payable);
    final method = methods.any((m) => m.$1 == _payment) ? _payment! : (methods.isEmpty ? null : methods.first.$1);
    if (method == null) return toast(context, context.l.cart.noPaymentMethod, error: true);
    if (_deliveryType == 'home' && _addressId == null) return toast(context, context.l.cart.addOrChooseAddress, error: true);
    if (_speed == 'scheduled' && _slot == null && _deliveryType == 'home') return toast(context, context.l.cart.pickDeliverySlot, error: true);
    if (shop.cart.values.any(_isUnavailable)) return toast(context, context.l.cart.removeUnavailableFirst, error: true);
    setState(() => _placing = true);
    try {
      final res = await G4MApi.instance.placeOrder({
        ..._input,
        'paymentMethod': method,
        if (_speed == 'scheduled' && _slot != null) 'scheduledSlot': _slot,
        'channel': 'web',
      });
      final orderId = '${res['orderId']}';
      final payment = res['payment'];
      if (payment is Map) {
        final me = shop.profile;
        final outcome = await runPayment(Map<String, dynamic>.from(payment), id: orderId, prefill: {'name': me?.name ?? '', 'email': me?.email ?? '', 'contact': me?.phone ?? ''});
        if (outcome == PayOutcome.redirected) return;
        if (!mounted) return;
        if (outcome == PayOutcome.dismissed) {
          toast(context, context.l.cart.paymentNotCompleted, error: true);
        }
      }
      unawaited(Push.instance.offer());
      if (mounted) context.go('/orders/$orderId?placed=1');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e), error: true);
    }
    if (mounted) setState(() => _placing = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: shop,
        builder: (context, _) {
          final items = shop.cart.values.toList()..sort((a, b) => a.id.compareTo(b.id));
          return SeoMeta(
            title: context.l.cart.title,
            description: context.l.cart.seoDescription,
            child: PageScroll(children: [
              Contained(
                vertical: 24,
                child: items.isEmpty ? _empty(context) : _body(context, items),
              ),
            ]),
          );
        },
      );

  Widget _empty(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Heading(context.l.cart.title),
        const SizedBox(height: 12),
        EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: context.l.cart.emptyTitle,
          message: context.l.cart.emptyMessage,
          action: FilledButton(onPressed: () => context.go('/'), child: Text(context.l.cart.startShopping)),
        ),
        const SizedBox(height: 24),
        ProductsFuture(
          load: () => Data.list(sort: 'popular', limit: 12),
          builder: (l) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(title: context.l.cart.popularNow),
            ProductCarousel(products: l),
          ]),
        ),
      ]);

  Widget _body(BuildContext context, List<CartItem> items) {
    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Heading(context.l.cart.title, style: TextStyle(fontSize: context.isPhone ? 26 : 32))),
        Text(context.l.cart.itemsCount(shop.cartCount), style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 16),
      for (var i = 0; i < items.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: Reveal(index: i % 5, child: _itemRow(context, items[i]))),
      if (_quote != null && (_quote!['distanceKm'] != null || _quote!['etaMinutes'] != null) && _deliveryType == 'home')
        Panel(
          color: G4MColors.primarySoft,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.route_rounded, color: G4MColors.primaryDeep),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                [
                  if (_quote!['distanceKm'] != null) context.l.cart.kmFromStore(context.l.number(double.parse((_quote!['distanceKm'] as num).toStringAsFixed(1)))),
                  if (_quote!['etaMinutes'] != null) context.l.cart.etaAbout(_quote!['etaMinutes'] is num ? context.l.number(_quote!['etaMinutes'] as num) : '${_quote!['etaMinutes']}'),
                ].join(' · '),
                style: const TextStyle(fontWeight: FontWeight.w700, color: G4MColors.primaryDeep),
              ),
            ),
          ]),
        ),
    ]);
    final right = _checkout(context);
    if (!context.isDesktop) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 24), right]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: left),
      const SizedBox(width: 28),
      SizedBox(width: 440, child: right),
    ]);
  }

  Widget _itemRow(BuildContext context, CartItem c) {
    final p = _products[c.productId];
    if (p == null) {
      return Panel(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: Text(_missing.contains(c.productId) ? context.l.cart.productGone : context.l.cart.loading, style: const TextStyle(color: G4MColors.inkMuted))),
          if (_missing.contains(c.productId)) TextButton(onPressed: () => shop.removeItem(c.id), child: Text(context.l.cart.remove)),
        ]),
      );
    }
    final v = p.variants.where((e) => e.id == c.variantId).firstOrNull;
    final addonIds = (c.data['addonIds'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final addons = (p.data['addons'] as List? ?? const []).whereType<Map>().where((a) => addonIds.contains('${a['id']}')).toList();
    final extra = addons.fold<double>(0, (s, a) => s + ((a['price'] as num?)?.toDouble() ?? 0));
    final price = (v?.price ?? p.price) + extra, mrp = (v?.mrp ?? p.mrp) + extra;
    final bad = _isUnavailable(c);
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppLink(
            to: '/p/${p.slug}',
            label: p.name,
            child: Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF4F8F5), borderRadius: BorderRadius.circular(14)),
              child: Opacity(opacity: bad ? .4 : 1, child: NetImage(p.image, fit: BoxFit.contain, semanticLabel: p.name)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text([if (v != null && v.name.isNotEmpty) v.name else if (p.unit.isNotEmpty) p.unit, if (p.sellerName.isNotEmpty) context.l.cart.soldBy(p.sellerName)].join(' · '),
                  style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted)),
              if (addons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('+ ${addons.map((a) => a['name']).join(', ')}', style: const TextStyle(fontSize: 12.5, color: G4MColors.primaryDeep, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 8),
              Price(price: price, mrp: mrp, size: 15),
              if (bad) ...[
                const SizedBox(height: 6),
                Pill(context.l.cart.outOfStock, bg: Color(0xFFFDECEC), fg: G4MColors.danger, icon: Icons.error_outline_rounded),
              ],
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(context.l.money(price * c.qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            if (addonIds.isEmpty)
              AddToCartButton(product: p, variantId: c.variantId)
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton.outlined(tooltip: context.l.cart.removeOne, onPressed: () => shop.setLineQty(c, c.qty - 1), icon: const Icon(Icons.remove_rounded, size: 18)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(context.l.number(c.qty), style: const TextStyle(fontWeight: FontWeight.w800))),
                IconButton.outlined(tooltip: context.l.cart.addOneMore, onPressed: () => shop.setLineQty(c, c.qty + 1), icon: const Icon(Icons.add_rounded, size: 18)),
              ]),
            TextButton.icon(
              onPressed: () => shop.removeItem(c.id),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(context.l.cart.remove),
              style: TextButton.styleFrom(foregroundColor: G4MColors.inkMuted),
            ),
          ]),
        ]),
        if (bad) _Replacements(product: p, onPick: (r) async {
          await shop.removeItem(c.id);
          await shop.setQty(r, c.qty.clamp(1, 99), variantId: defaultVariantId(r));
          if (context.mounted) toast(context, context.l.cart.replacedWith(r.name));
        }),
      ]),
    );
  }

  // ------------------------------------------------------------------ checkout column

  Widget _checkout(BuildContext context) {
    final s = shop.settings, t = context.l.cart;
    if (!shop.signedIn) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _billSummary(),
          const Divider(height: 32),
          Text(t.almostThere, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(t.signInToChoose, style: const TextStyle(color: G4MColors.inkMuted)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.go('/login?next=%2Fcart'), child: Text(t.signInToCheckout)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.go('/signup?next=%2Fcart'), child: Text(t.createAnAccount)),
        ]),
      );
    }
    final payable = (_quote?['payable'] as num?)?.toDouble() ?? _localSubtotal;
    final methods = _payMethods(payable);
    if (!methods.any((m) => m.$1 == _payment) && methods.isNotEmpty) _payment = methods.first.$1;
    final speeds = [
      ('standard', t.speedStandard, t.todayOrTomorrow, Icons.local_shipping_outlined),
      if (s.quick15Enabled) ('quick15', t.minutesShort(15), t.plusFee(context.l.money(s.quickDeliveryFee)), Icons.bolt_rounded),
      if (s.quick30Enabled) ('quick30', t.minutesShort(30), t.plusFee(context.l.money(s.quickDeliveryFee)), Icons.timer_outlined),
      if (s.scheduledEnabled) ('scheduled', t.speedScheduled, t.pickASlot, Icons.event_outlined),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (s.pickupEnabled)
        _Step(
          n: 1,
          title: t.howWouldYouLikeIt,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'home', icon: const Icon(Icons.home_outlined), label: Text(t.homeDelivery)),
              ButtonSegment(value: 'pickup', icon: const Icon(Icons.storefront_outlined), label: Text(t.selfPickup)),
            ],
            selected: {_deliveryType},
            onSelectionChanged: (v) {
              setState(() => _deliveryType = v.first);
              _requote();
            },
          ),
        ),
      if (_deliveryType == 'home') ...[
        _Step(n: s.pickupEnabled ? 2 : 1, title: t.deliveryAddress, child: _addresses(context)),
        _Step(
          n: s.pickupEnabled ? 3 : 2,
          title: t.deliverySpeed,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sp in speeds)
                _ChoiceCard(
                  selected: _speed == sp.$1,
                  icon: sp.$4,
                  title: sp.$2,
                  subtitle: sp.$3,
                  width: context.isPhone ? (context.w - 32 - 40 - 8) / 2 : 180,
                  onTap: () {
                    setState(() => _speed = sp.$1);
                    _requote();
                  },
                ),
            ]),
            if (_speed == 'scheduled') ...[const SizedBox(height: 14), _slotPicker(context)],
          ]),
        ),
      ] else
        _Step(
          n: 2,
          title: t.pickup,
          child: Text(
            t.pickupFrom(shop.cart.values.map((c) => _products[c.productId]?.sellerName).whereType<String>().where((e) => e.isNotEmpty).toSet().join(', ')),
            style: const TextStyle(height: 1.5),
          ),
        ),
      _Step(
        n: _deliveryType == 'home' ? (s.pickupEnabled ? 4 : 3) : 3,
        title: t.offersAndWallet,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _couponCtl,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: _applyCoupon,
                decoration: InputDecoration(
                  labelText: t.couponCode,
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                  suffixIcon: _coupon == null
                      ? null
                      : IconButton(
                          tooltip: t.removeCoupon,
                          onPressed: () {
                            setState(() {
                              _coupon = null;
                              _couponMsg = null;
                              _couponCtl.clear();
                            });
                            _requote();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(onPressed: () => _applyCoupon(_couponCtl.text), child: Text(t.apply)),
          ]),
          if (_couponMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_couponMsg!, style: TextStyle(color: _couponOk ? kDiscountInk : G4MColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          StreamBuilder<List<Coupon>>(
            stream: live('coupons', CatalogRepo.instance.activeCoupons),
            builder: (context, cs) {
              final l = (cs.data ?? const <Coupon>[]).where((c) => c.data['sellerId'] == null).take(6).toList();
              if (l.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in l)
                    Tooltip(
                      message: [c.message, if (c.minOrder > 0) t.minOrder(context.l.money(c.minOrder))].where((e) => e.isNotEmpty).join(' · '),
                      child: ActionChip(
                        avatar: const Icon(Icons.confirmation_number_outlined, size: 18, color: kAccentInk),
                        label: Text('${c.code} · ${t.couponOff(c.discountType, c.value)}'),
                        onPressed: () => _applyCoupon(c.code),
                      ),
                    ),
                ]),
              );
            },
          ),
          if (s.walletEnabled) ...[
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _useWallet,
              onChanged: shop.walletBalance <= 0
                  ? null
                  : (v) {
                      setState(() => _useWallet = v);
                      _requote();
                    },
              secondary: const Icon(Icons.account_balance_wallet_outlined, color: G4MColors.primary),
              title: Text(t.useWallet, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(t.walletAvailable(context.l.money(shop.walletBalance))),
            ),
          ],
        ]),
      ),
      _Step(
        n: _deliveryType == 'home' ? (s.pickupEnabled ? 5 : 4) : 4,
        title: t.payment,
        child: methods.isEmpty
            ? Text(t.paymentsSettingUp, style: const TextStyle(color: G4MColors.inkMuted))
            : RadioGroup<String>(
                groupValue: _payment,
                onChanged: (v) => setState(() => _payment = v),
                child: Column(children: [
                  for (final m in methods)
                    RadioListTile<String>(
                      value: m.$1,
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(m.$3, color: G4MColors.primaryDeep),
                      title: Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
      ),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _billSummary(),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _placing || _quoting ? null : _place,
              style: FilledButton.styleFrom(backgroundColor: G4MColors.primaryDeep, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(G4MRadius.md))),
              child: AnimatedSwitcher(
                duration: G4MMotion.standard,
                child: _placing
                    ? const SizedBox(key: ValueKey('p'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Row(key: const ValueKey('t'), mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(_payment == 'cod' || _payment == 'wallet' ? t.placeOrder : t.payAmount(context.l.money(payable)), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded),
                      ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline_rounded, size: 15, color: G4MColors.inkMuted),
            const SizedBox(width: 6),
            Flexible(child: Text(t.verifiedSecurely, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: G4MColors.inkMuted))),
          ]),
        ]),
      ),
    ]);
  }

  Widget _billSummary() {
    final q = _quote;
    final l = L.of(context), t = l.cart;
    double n(String k) => (q?[k] as num?)?.toDouble() ?? 0;
    Widget row(String l, String v, {Color? c, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 17 : 14.5))),
            Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: c, fontSize: bold ? 18 : 14.5)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(t.billSummary, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
        if (_quoting) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ]),
      const SizedBox(height: 8),
      if (q == null) ...[
        row(t.itemsTotal, l.money(_localSubtotal)),
        if (_quoteError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(t.quoteUnavailable(errorMessage(_quoteError!)), style: const TextStyle(color: G4MColors.inkMuted, fontSize: 12.5)),
          )
        else
          Text(t.calculatedAtCheckout, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 12.5)),
      ] else ...[
        row(t.itemsTotal, l.money(n('subtotal'))),
        row(t.deliveryFee, n('deliveryFee') == 0 ? t.free : l.money(n('deliveryFee')), c: n('deliveryFee') == 0 ? kDiscountInk : null),
        if (n('couponDiscount') > 0) row(t.couponDiscount, '− ${l.money(n('couponDiscount'))}', c: kDiscountInk),
        if (n('membershipDiscount') > 0) row(t.memberSavings, '− ${l.money(n('membershipDiscount'))}', c: kDiscountInk),
        if (n('discount') > 0 && n('couponDiscount') == 0 && n('membershipDiscount') == 0) row(t.discount, '− ${l.money(n('discount'))}', c: kDiscountInk),
        if (n('mrpTotal') > n('subtotal')) row(t.youSaveOnMrp, l.money(n('mrpTotal') - n('subtotal')), c: kDiscountInk),
        if (n('tax') > 0) row(t.taxes, l.money(n('tax'))),
        if (n('walletUsed') > 0) row(t.paidFromWallet, '− ${l.money(n('walletUsed'))}', c: kDiscountInk),
        const Divider(height: 20),
        row(t.toPay, l.money(n('payable') > 0 || n('walletUsed') > 0 ? n('payable') : n('total')), bold: true),
        if (n('deliveryFee') > 0 && shop.settings.freeDeliveryAbove > n('subtotal'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: G4MColors.accentSoft, borderRadius: BorderRadius.circular(10)),
              child: Text(t.addMoreForFreeDelivery(l.money(shop.settings.freeDeliveryAbove - n('subtotal'))), style: const TextStyle(color: kAccentInk, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
      ],
    ]);
  }

  Widget _addresses(BuildContext context) => StreamBuilder<List<Address>>(
        stream: live('addr_${shop.user!.uid}', ShopperRepo.instance.addresses),
        builder: (context, s) {
          final l = s.data ?? const <Address>[];
          if (_addressId == null && l.isNotEmpty) {
            final def = l.where((a) => a.isDefault).firstOrNull ?? l.first;
            _addressId = def.id;
            WidgetsBinding.instance.addPostFrameCallback((_) => _requote());
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final a in l)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  selected: _addressId == a.id,
                  button: true,
                  label: context.l.cart.addressSemantics(context.l.cart.addressLabel(a.label), a.oneLine),
                  child: Pressable(
                    onTap: () {
                      setState(() => _addressId = a.id);
                      _requote();
                    },
                    child: AnimatedContainer(
                      duration: G4MMotion.standard,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _addressId == a.id ? G4MColors.primarySoft : Colors.white,
                        borderRadius: BorderRadius.circular(G4MRadius.md),
                        border: Border.all(color: _addressId == a.id ? G4MColors.primary : G4MColors.line, width: _addressId == a.id ? 1.8 : 1),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(a.label == 'Work' ? Icons.work_outline : (a.label == 'Home' ? Icons.home_outlined : Icons.place_outlined), color: G4MColors.primaryDeep),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${context.l.cart.addressLabel(a.label)} · ${a.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(a.oneLine, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13, height: 1.4)),
                            if (a.lat == null) Text(context.l.cart.pinMissing, style: const TextStyle(color: kAccentInk, fontSize: 12.5, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        IconButton(tooltip: context.l.cart.editAddress, onPressed: () => showAddressForm(context, existing: a), icon: const Icon(Icons.edit_outlined, size: 20)),
                      ]),
                    ),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showAddressForm(context);
                if (ok == true) {
                  _addressId = null;
                  _requote();
                }
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l.isEmpty ? context.l.cart.addDeliveryAddress : context.l.cart.addNewAddress),
            ),
          ]);
        },
      );

  Widget _slotPicker(BuildContext context) {
    final slots = shop.settings.slots.isNotEmpty
        ? shop.settings.slots
        : const [
            {'from': '08:00', 'to': '11:00'},
            {'from': '11:00', 'to': '14:00'},
            {'from': '16:00', 'to': '19:00'},
            {'from': '19:00', 'to': '22:00'},
          ];
    final today = DateTime.now();
    final days = [for (var i = 0; i < 7; i++) DateTime(today.year, today.month, today.day + i)];
    _slotDate ??= days[1];
    String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    bool past(Json s) {
      if (ymd(_slotDate!) != ymd(today)) return false;
      final h = int.tryParse('${s['from']}'.split(':').first) ?? 0;
      return h <= today.hour + 1;
    }

    final lc = context.l;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 64,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _ChoiceCard(
                selected: ymd(d) == ymd(_slotDate!),
                title: d.day == today.day ? lc.cart.today : lc.weekday(d),
                subtitle: '${lc.number(d.day)}/${lc.number(d.month)}',
                width: 78,
                onTap: () => setState(() {
                  _slotDate = d;
                  _slot = null;
                }),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in slots)
          ChoiceChip(
            label: Text('${s['from']} – ${s['to']}'),
            selected: _slot != null && _slot!['from'] == s['from'] && _slot!['date'] == ymd(_slotDate!),
            onSelected: past(s)
                ? null
                : (_) {
                    setState(() => _slot = {'date': ymd(_slotDate!), 'from': s['from'], 'to': s['to']});
                    _requote();
                  },
          ),
      ]),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.child});
  final int n;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Panel(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              CircleAvatar(radius: 13, backgroundColor: G4MColors.primaryDeep, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Semantics(header: true, headingLevel: 2, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5))),
            ]),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.selected, required this.title, required this.subtitle, required this.onTap, this.icon, this.width = 160});
  final bool selected;
  final String title, subtitle;
  final IconData? icon;
  final VoidCallback onTap;
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: '$title, $subtitle',
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: G4MMotion.standard,
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? G4MColors.primarySoft : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? G4MColors.primary : G4MColors.line, width: selected ? 1.8 : 1),
            ),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, color: selected ? G4MColors.primaryDeep : G4MColors.inkMuted, size: 22), const SizedBox(width: 8)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: G4MColors.inkMuted)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// Similar in-stock products offered as one-tap replacements for an unavailable cart item.
class _Replacements extends StatelessWidget {
  const _Replacements({required this.product, required this.onPick});
  final Product product;
  final ValueChanged<Product> onPick;
  @override
  Widget build(BuildContext context) => ProductsFuture(
        key: ValueKey('rep${product.id}'),
        load: () async => (await Data.similar(product, limit: 8)).where((p) => p.inStock).take(6).toList(),
        skeleton: const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        builder: (l) => Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: G4MColors.accentSoft, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.swap_horiz_rounded, color: kAccentInk),
              const SizedBox(width: 6),
              Text(context.l.cart.similarInStock, style: const TextStyle(fontWeight: FontWeight.w800, color: kAccentInk)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: l.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Container(
                  width: 280,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    SizedBox(width: 60, height: 60, child: NetImage(l[i].image, fit: BoxFit.contain, semanticLabel: l[i].name)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(context.l.money(l[i].price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ]),
                    ),
                    TextButton(onPressed: () => onPick(l[i]), child: Text(context.l.cart.replace)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}
