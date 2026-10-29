import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:intl/intl.dart';

import '../../core/addons.dart';
import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/payments.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/product_card.dart';
import '../../widgets/ui.dart';
import '../auth/auth_screens.dart';
import '../home/home_screen.dart' show CouponTicket;
import '../profile/addresses_screen.dart';
import '../shell/main_shell.dart';
import 'order_success_screen.dart';

/// Single-screen cart + checkout (feature #13): items, replacements, delivery type/speed/slot,
/// coupon, wallet, payment method, live server quote and place order, all on one page.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.standalone = false});
  final bool standalone;
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _s = Session.instance;
  Map<String, Product> _products = {};
  Set<String> _loadedIds = {};
  bool _loadingProducts = true;

  String _deliveryType = 'home';
  String _speed = 'standard';
  DateTime? _slotDate;
  Json? _slot;
  String? _coupon;
  bool _useWallet = false;
  String _method = 'cod';
  Address? _address;
  bool _addressTouched = false;

  Json? _quote;
  bool _quoting = false, _estimate = false;
  int _quoteSeq = 0;
  Timer? _debounce;
  bool _placing = false;
  final _replacements = <String, Future<List<Product>>>{};

  @override
  void initState() {
    super.initState();
    _s.cart.addListener(_onCart);
    _s.epoch.addListener(_onAuth);
    AppConfig.platform.addListener(_requote);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onCart());
  }

  @override
  void dispose() {
    _s.cart.removeListener(_onCart);
    _s.epoch.removeListener(_onAuth);
    AppConfig.platform.removeListener(_requote);
    _debounce?.cancel();
    super.dispose();
  }

  Stream<List<Address>>? _addrStream;
  String? _addrUid;
  Stream<List<Address>> get _addresses {
    if (_addrStream == null || _addrUid != _s.uid) {
      _addrUid = _s.uid;
      _addrStream = ShopperRepo.instance.addresses();
    }
    return _addrStream!;
  }

  void _onAuth() {
    _address = null;
    _addressTouched = false;
    _onCart();
  }

  Future<void> _onCart() async {
    final ids = _s.cart.value.values.map((c) => c.productId).toSet();
    if (!ids.every(_loadedIds.contains)) {
      setState(() => _loadingProducts = _products.isEmpty);
      final m = await _s.ensureProducts(ids, refresh: _loadedIds.isEmpty);
      if (!mounted) return;
      _products = {..._products, ...m};
      _loadedIds = {..._loadedIds, ...ids};
    }
    if (mounted) setState(() => _loadingProducts = false);
    _requote();
  }

  // ------------------------------------------------------------------ pricing

  List<CartItem> get _items {
    final l = _s.cart.value.values.toList();
    l.sort((a, b) => (b.addedAt ?? DateTime(2100)).compareTo(a.addedAt ?? DateTime(2100)));
    return l;
  }

  Variant? _variantOf(Product p, String vid) {
    for (final v in p.variants) {
      if (v.id == vid) return v;
    }
    return null;
  }

  /// Base (variant) price + add-ons, exactly as the order engine prices the line.
  double _unitPrice(CartItem c) {
    final p = _products[c.productId];
    if (p == null) return 0;
    return unitPriceWithAddons(p, c.variantId, c.addonIds);
  }

  /// True when the line asks for an add-on the product no longer offers (the engine rejects it).
  bool _addonMissing(CartItem c) {
    final p = _products[c.productId];
    if (p == null || c.addonIds.isEmpty) return false;
    return selectedAddons(p, c.addonIds).length != c.addonIds.length;
  }

  /// Add-on share of the item total: from the server quote when it has `items[]`, else local.
  double get _addonsAmount {
    final raw = _quote?['items'];
    if (raw is List && raw.isNotEmpty) {
      var sum = 0.0;
      for (final it in raw.whereType<Map>()) {
        final addons = it['addons'];
        if (addons is! List) continue;
        final per = addons.whereType<Map>().fold<double>(0, (s, a) => s + jsonNum(a['price']));
        sum += per * jsonNum(it['qty'], 1);
      }
      return sum;
    }
    return _items.where((c) => !_isOos(c)).fold(0.0, (s, c) {
      final p = _products[c.productId];
      return p == null ? s : s + addonTotal(addonsOf(p), c.addonIds) * c.qty;
    });
  }

  int _stockOf(CartItem c) {
    final p = _products[c.productId];
    if (p == null) return 0;
    final v = _variantOf(p, c.variantId);
    return v?.stock ?? p.stock;
  }

  Set<String> get _unavailable {
    final out = <String>{};
    final raw = _quote?['unavailable'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          out.add('${e['itemId'] ?? ''}');
          out.add('${e['productId'] ?? ''}');
        } else {
          out.add('$e');
        }
      }
    }
    return out..remove('');
  }

  bool _isOos(CartItem c) {
    final p = _products[c.productId];
    if (p == null && !_loadingProducts) return true;
    if (p == null) return false;
    final u = _unavailable;
    return _stockOf(c) <= 0 || u.contains(c.id) || u.contains(c.productId) || p.status != 'active' || _addonMissing(c);
  }

  double get _localSubtotal => _items.where((c) => !_isOos(c)).fold(0.0, (a, c) => a + _unitPrice(c) * c.qty);

  /// Client-side estimate used until (or if) the getCheckoutQuote callable answers.
  Json _estimateQuote() {
    final st = AppConfig.platform.value;
    final sub = _localSubtotal;
    var fee = _deliveryType == 'pickup' ? 0.0 : (sub >= st.freeDeliveryAbove && st.freeDeliveryAbove > 0 ? 0.0 : st.deliveryFee);
    if (_deliveryType == 'home' && (_speed == 'quick15' || _speed == 'quick30')) fee += st.quickDeliveryFee;
    final tax = (sub * st.taxPct / 100);
    final total = sub + fee + tax;
    final bal = _s.profile.value?.walletBalance ?? 0;
    final wallet = _useWallet ? math.min(bal, total) : 0.0;
    return {
      'subtotal': sub,
      'deliveryFee': fee,
      'discount': 0,
      'tax': double.parse(tax.toStringAsFixed(2)),
      'total': total,
      'walletUsed': wallet,
      'payable': total - wallet,
      'etaMinutes': _speed == 'quick15' ? 15 : (_speed == 'quick30' ? 30 : null),
    };
  }

  Json get _q => _quote ?? _estimateQuote();
  double _qn(String k) => jsonNum(_q[k]);

  Json _quoteInput() => {
        if (_deliveryType == 'home' && _address != null) 'addressId': _address!.id,
        if (_coupon != null) 'couponCode': _coupon,
        'useWallet': _useWallet,
        'speed': _deliveryType == 'pickup' ? 'standard' : _speed,
        'deliveryType': _deliveryType,
      };

  void _requote() {
    _debounce?.cancel();
    if (!mounted) return;
    if (_s.cart.value.isEmpty) {
      setState(() => _quote = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final seq = ++_quoteSeq;
      setState(() => _quoting = true);
      try {
        final r = await G4MApi.instance.checkoutQuote(_quoteInput());
        if (!mounted || seq != _quoteSeq) return;
        setState(() {
          _quote = r;
          _estimate = false;
        });
      } catch (e) {
        debugPrint('[g4m] quote: $e');
        if (!mounted || seq != _quoteSeq) return;
        setState(() {
          _quote = null;
          _estimate = true;
        });
      } finally {
        if (mounted && seq == _quoteSeq) setState(() => _quoting = false);
      }
    });
  }

  // ------------------------------------------------------------------ actions

  void _set(VoidCallback f) {
    setState(f);
    _requote();
  }

  Future<void> _swap(CartItem old, Product np) async {
    HapticFeedback.mediumImpact();
    await _s.removeItem(old.id);
    final vid = np.variants.isEmpty ? 'default' : np.variants.firstWhere((v) => v.stock > 0, orElse: () => np.variants.first).id;
    await _s.setQty(np, old.qty, variantId: vid);
    if (mounted) context.toast('Replaced with ${np.name}');
  }

  Future<void> _openCoupons() async {
    final code = await showAppSheet<String>(context, builder: (_) => _CouponSheet(subtotal: _qn('subtotal')));
    if (code == null) return;
    _set(() => _coupon = code.isEmpty ? null : code.toUpperCase());
  }

  List<(String, String, IconData)> _methods(double payableBeforeWallet) {
    final st = AppConfig.platform.value;
    final pay = AppConfig.payments.value;
    final bal = _s.profile.value?.walletBalance ?? 0;
    final codMax = AppConfig.codMax;
    final l = AppLocalizations.of(context);
    return [
      if (pay.razorpayEnabled) ('razorpay', 'UPI, cards & netbanking', Icons.account_balance_rounded),
      if (pay.stripeEnabled) ('stripe', 'Credit / debit card (Stripe)', Icons.credit_card_rounded),
      if (pay.paypalEnabled) ('paypal', 'PayPal', Icons.paypal_rounded),
      if (st.walletEnabled && bal >= payableBeforeWallet && payableBeforeWallet > 0) ('wallet', '${l.wallet} (${Fmt.money(bal)})', Icons.account_balance_wallet_rounded),
      if (st.codEnabled && pay.codEnabled && (codMax <= 0 || payableBeforeWallet <= codMax)) ('cod', l.cod, Icons.payments_outlined),
    ];
  }

  Future<void> _place() async {
    if (!await requireAccount(context)) return;
    if (!mounted) return;
    final items = _items;
    if (items.isEmpty) return;
    final oos = items.where(_isOos).toList();
    if (oos.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Some items are unavailable'),
          content: Text('${oos.length} item(s) are out of stock. Remove them and continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Review')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove & continue')),
          ],
        ),
      );
      if (ok != true) return;
      for (final c in oos) {
        await _s.removeItem(c.id);
      }
      if (_s.cart.value.isEmpty) return;
    }
    if (_deliveryType == 'home' && _address == null) {
      if (mounted) context.toast('Add a delivery address', error: true);
      return _changeAddress();
    }
    if (_deliveryType == 'home' && _speed == 'scheduled' && _slot == null) {
      if (mounted) context.toast('Pick a delivery slot', error: true);
      return;
    }
    final minOrder = AppConfig.platform.value.minOrder;
    if (minOrder > 0 && _qn('subtotal') < minOrder) {
      if (mounted) context.toast('Minimum order is ${Fmt.money(minOrder)}', error: true);
      return;
    }
    final payable = _qn('payable');
    final method = payable <= 0 ? 'wallet' : _method;
    setState(() => _placing = true);
    try {
      final res = await G4MApi.instance.placeOrder({
        ..._quoteInput(),
        if (method == 'wallet') 'useWallet': true,
        'paymentMethod': method,
        if (_deliveryType == 'home' && _speed == 'scheduled' && _slot != null) 'scheduledSlot': _slot,
        'channel': 'app',
      });
      final orderId = '${res['orderId'] ?? res['id'] ?? ''}';
      final orderNo = '${res['orderNo'] ?? ''}';
      if (orderId.isEmpty) throw Exception('Order could not be created');
      var paid = true;
      var note = '';
      if (method == 'razorpay' || method == 'stripe' || method == 'paypal') {
        final payment = PaymentFlow.payloadOf(res, method);
        if (payment == null) {
          paid = false;
          note = 'Payment could not be started. You can retry from the order page.';
        } else if (mounted) {
          final u = _s.profile.value;
          final r = await PaymentFlow.run(
            context,
            refId: orderId,
            payment: payment,
            amount: jsonNum(res['payable'], payable),
            prefill: {'name': u?.name ?? '', 'email': u?.email ?? '', 'phone': u?.phone ?? ''},
          );
          paid = r.ok;
          note = r.message;
        }
      }
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // Server clears the cart; mirror it locally so the badge resets instantly.
      _s.cart.value = {};
      setState(() {
        _coupon = null;
        _useWallet = false;
        _quote = null;
      });
      await Navigator.of(context).push(appRoute(
        OrderSuccessScreen(orderId: orderId, orderNo: orderNo, paid: paid, note: note, method: method),
        style: RouteStyle.sharedZ,
      ));
    } catch (e) {
      if (mounted) {
        final msg = isMissingFunction(e) ? 'Checkout is not available right now. Please try again shortly.' : friendlyError(e);
        context.toast(msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _changeAddress() async {
    if (!await requireAccount(context)) return;
    if (!mounted) return;
    final a = await pickAddress(context, selectedId: _address?.id);
    if (a != null) {
      _addressTouched = true;
      _set(() => _address = a);
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: _s.cart,
      builder: (context, cart, _) {
        final items = _items;
        final navSpace = widget.standalone ? 0.0 : 80.0 + math.max(MediaQuery.paddingOf(context).bottom, 12.0);
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: widget.standalone,
            title: Row(children: [
              Text(l.cart),
              const SizedBox(width: 8),
              if (items.isNotEmpty) Tag(l.items(_s.cartCount), color: G4MColors.primary, filled: false),
            ]),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Clear cart',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear cart?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (ok == true) _s.clearCart();
                  },
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: items.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: navSpace),
                  child: EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: l.cartEmpty,
                    message: l.cartEmptyMsg,
                    action: FilledButton(onPressed: () => goHomeTab(context), child: Text(l.startShopping)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _freeDeliveryBar(context).stagger(0),
                    for (final (i, c) in items.indexed) _itemRow(context, c).stagger(i + 1),
                    const SizedBox(height: 8),
                    _deliveryBlock(context, l).stagger(3),
                    const SizedBox(height: 12),
                    _couponBlock(context, l).stagger(4),
                    const SizedBox(height: 12),
                    _walletBlock(context, l).stagger(5),
                    const SizedBox(height: 12),
                    _paymentBlock(context, l).stagger(6),
                    const SizedBox(height: 12),
                    _billBlock(context, l).stagger(7),
                    const SizedBox(height: 12),
                    Text(
                      'By placing the order you agree to Go4Market terms. Cancellation is free until the order is packed.',
                      style: context.text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
          bottomNavigationBar: items.isEmpty ? null : Padding(padding: EdgeInsets.only(bottom: navSpace), child: _checkoutBar(context, l)),
        );
      },
    );
  }

  Widget _freeDeliveryBar(BuildContext context) {
    final st = AppConfig.platform.value;
    final sub = _qn('subtotal');
    if (_deliveryType == 'pickup' || st.freeDeliveryAbove <= 0) return const SizedBox.shrink();
    final left = st.freeDeliveryAbove - sub;
    final done = left <= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        color: done ? context.softPrimary : context.softAccent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(done ? Icons.celebration_rounded : Icons.local_shipping_outlined, size: 18, color: done ? G4MColors.primary : G4MColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(done ? 'Yay! You get FREE delivery' : 'Add ${Fmt.money(left)} more for FREE delivery',
                  style: context.text.titleSmall?.copyWith(fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (sub / st.freeDeliveryAbove).clamp(0.0, 1.0)),
              duration: G4MMotion.slow,
              curve: G4MMotion.curve,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: done ? G4MColors.primary : G4MColors.accent,
                backgroundColor: context.card,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _itemRow(BuildContext context, CartItem c) {
    final p = _products[c.productId];
    if (p == null) {
      return _loadingProducts
          ? const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 96, radius: 16))
          : Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: G4MColors.danger),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('This product is no longer available')),
                  TextButton(onPressed: () => _s.removeItem(c.id), child: const Text('Remove')),
                ]),
              ),
            );
    }
    final v = _variantOf(p, c.variantId);
    final oos = _isOos(c);
    final addons = selectedAddons(p, c.addonIds);
    final extra = addonTotal(addons, c.addonIds);
    final price = (v?.price ?? p.price) + extra;
    final mrp = (v?.mrp ?? p.mrp) + extra;
    final addonGone = _addonMissing(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('cart-${c.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          _s.removeItem(c.id);
          context.toast('${p.name} removed');
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(color: G4MColors.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline_rounded, color: G4MColors.danger),
        ),
        child: AppCard(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Row(children: [
              Pressable(
                onTap: () => openProduct(context, p, scope: 'cart-${c.id}'),
                child: Opacity(
                  opacity: oos ? .45 : 1,
                  child: Hero(tag: heroTagFor('cart-${c.id}', p.id), child: Img(p.image, width: 72, height: 72, radius: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                  Text([if (v != null && v.name.isNotEmpty) v.name else p.unit, if (p.sellerName.isNotEmpty) p.sellerName].where((e) => e.isNotEmpty).join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                  if (addons.isNotEmpty) _AddonChips(addons: addons),
                  const SizedBox(height: 6),
                  oos
                      ? Tag(addonGone ? 'Add-on unavailable' : 'Out of stock', color: G4MColors.danger, filled: false, icon: Icons.block_rounded)
                      : Price(price: price * c.qty, mrp: mrp * c.qty, size: 14, showOff: false),
                ]),
              ),
              const SizedBox(width: 8),
              oos
                  ? IconButton(onPressed: () => _s.removeItem(c.id), icon: const Icon(Icons.delete_outline_rounded, color: G4MColors.danger))
                  : _CartStepper(product: p, line: c),
            ]),
            if (oos) _replacementRow(context, c, p),
          ]),
        ),
      ),
    );
  }

  Widget _replacementRow(BuildContext context, CartItem c, Product p) {
    final fut = _replacements.putIfAbsent(p.id, () => Catalog.similar(p, limit: 8));
    return FutureBuilder<List<Product>>(
      future: fut,
      builder: (context, snap) {
        final list = snap.data;
        if (list != null && list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.swap_horiz_rounded, size: 18, color: G4MColors.primary),
            const SizedBox(width: 6),
            Text('Similar items in stock', style: context.text.labelLarge),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 74,
            child: list == null
                ? const Shimmer(height: 74, radius: 12)
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final r = list[i];
                      return Container(
                        width: 220,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: context.cardAlt, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          Img(r.image, width: 60, height: 60, radius: 10),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge),
                              Text(Fmt.money(r.price), style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          TextButton(onPressed: () => _swap(c, r), child: const Text('Swap')),
                        ]),
                      ).stagger(i, dy: 0);
                    },
                  ),
          ),
        ]);
      },
    );
  }

  Widget _deliveryBlock(BuildContext context, AppLocalizations l) {
    final st = AppConfig.platform.value;
    final speeds = [
      ('standard', l.standard, Icons.local_shipping_outlined, true),
      ('quick15', l.quick15, Icons.bolt_rounded, st.quick15Enabled),
      ('quick30', l.quick30, Icons.timer_outlined, st.quick30Enabled),
      ('scheduled', l.scheduled, Icons.event_rounded, st.scheduledEnabled),
    ].where((e) => e.$4).toList();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (st.pickupEnabled) ...[
          Text(l.deliveryType, style: context.text.titleSmall),
          const SizedBox(height: 10),
          _Segmented(
            options: [('home', l.homeDelivery, Icons.home_rounded), ('pickup', l.selfPickup, Icons.storefront_rounded)],
            value: _deliveryType,
            onChanged: (v) => _set(() => _deliveryType = v),
          ),
          const SizedBox(height: 16),
        ],
        AnimatedSize(
          duration: G4MMotion.emphasized,
          curve: G4MMotion.curve,
          alignment: Alignment.topCenter,
          child: _deliveryType == 'pickup'
              ? Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: G4MColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Pick up from the seller once your order is ready. We will notify you.', style: context.text.bodySmall),
                  ),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _addressRow(context, l),
                  const SizedBox(height: 16),
                  Text(l.deliverySpeed, style: context.text.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in speeds)
                      ChoiceChip(
                        avatar: Icon(s.$3, size: 16, color: _speed == s.$1 ? G4MColors.primary : (s.$1.startsWith('quick') ? G4MColors.accent : context.muted)),
                        label: Text(s.$2),
                        selected: _speed == s.$1,
                        onSelected: (_) => _set(() => _speed = s.$1),
                      ),
                  ]),
                  if (_speed == 'quick15' || _speed == 'quick30')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Express fee ${Fmt.money(st.quickDeliveryFee)} · subject to rider availability', style: context.text.bodySmall),
                    ),
                  AnimatedSize(
                    duration: G4MMotion.emphasized,
                    curve: G4MMotion.curve,
                    child: _speed == 'scheduled' ? _slotPicker(context, l) : const SizedBox(width: double.infinity),
                  ),
                ]),
        ),
        if (_qn('etaMinutes') > 0 || _qn('distanceKm') > 0) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.schedule_rounded, size: 16, color: G4MColors.primary),
            const SizedBox(width: 6),
            Text(
              [
                if (_qn('etaMinutes') > 0) 'Arrives in ~${_qn('etaMinutes').round()} min',
                if (_qn('distanceKm') > 0) '${_qn('distanceKm').toStringAsFixed(1)} km',
              ].join(' · '),
              style: context.text.labelLarge?.copyWith(color: G4MColors.primary),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _addressRow(BuildContext context, AppLocalizations l) {
    if (_s.isGuest) {
      return Row(children: [
        const Icon(Icons.location_on_outlined, color: G4MColors.primary),
        const SizedBox(width: 10),
        Expanded(child: Text('Log in to choose a delivery address', style: context.text.bodyMedium)),
        TextButton(onPressed: () => requireAccount(context), child: Text(l.login)),
      ]);
    }
    return StreamBuilder<List<Address>>(
      key: ValueKey(_s.uid),
      stream: _addresses,
      builder: (context, snap) {
        final list = snap.data ?? const <Address>[];
        if (!_addressTouched && list.isNotEmpty) {
          final def = list.where((a) => a.isDefault).firstOrNull ?? list.first;
          if (_address?.id != def.id && (_address == null || !list.any((a) => a.id == _address!.id))) {
            _address = def;
            WidgetsBinding.instance.addPostFrameCallback((_) => _requote());
          }
        }
        final a = _address;
        return Pressable(
          onTap: _changeAddress,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.softPrimary, borderRadius: BorderRadius.circular(12)),
              child: Icon(a?.label == 'Work' ? Icons.work_outline_rounded : Icons.home_outlined, color: G4MColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: a == null
                  ? Text(snap.hasData ? l.addAddress : 'Loading addresses…', style: context.text.titleSmall?.copyWith(color: G4MColors.primary))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a.label} · ${a.name}', style: context.text.titleSmall),
                      Text(a.oneLine, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                    ]),
            ),
            Text(a == null ? '' : l.changeAddress, style: context.text.labelLarge?.copyWith(color: G4MColors.primary)),
          ]),
        );
      },
    );
  }

  Widget _slotPicker(BuildContext context, AppLocalizations l) {
    final st = AppConfig.platform.value;
    final raw = st.slots.isNotEmpty
        ? st.slots
        : const [
            {'from': '08:00', 'to': '11:00'},
            {'from': '11:00', 'to': '14:00'},
            {'from': '14:00', 'to': '17:00'},
            {'from': '17:00', 'to': '20:00'},
          ];
    final today = DateTime.now();
    final days = List.generate(5, (i) => DateTime(today.year, today.month, today.day + i));
    _slotDate ??= days.first;
    int hourOf(String hhmm) => int.tryParse(hhmm.split(':').first) ?? 0;
    final isToday = _slotDate!.day == today.day && _slotDate!.month == today.month;
    final slots = raw.where((s) => !isToday || hourOf('${s['from']}') > today.hour + 1).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.pickSlot, style: context.text.titleSmall),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = days[i];
              final on = d == _slotDate;
              return Pressable(
                onTap: () => _set(() {
                  _slotDate = d;
                  _slot = null;
                }),
                child: AnimatedContainer(
                  duration: G4MMotion.standard,
                  width: 58,
                  decoration: BoxDecoration(
                    color: on ? G4MColors.primary : context.cardAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(i == 0 ? 'Today' : DateFormat('EEE').format(d),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? Colors.white70 : context.muted)),
                    Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: on ? Colors.white : context.ink)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (slots.isEmpty)
          Text('No slots left today. Pick another day.', style: context.text.bodySmall)
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in slots)
              ChoiceChip(
                label: Text('${s['from']} – ${s['to']}'),
                selected: _slot != null && _slot!['from'] == s['from'] && _slot!['date'] == DateFormat('yyyy-MM-dd').format(_slotDate!),
                onSelected: (_) => _set(() => _slot = {
                      'date': DateFormat('yyyy-MM-dd').format(_slotDate!),
                      'from': '${s['from']}',
                      'to': '${s['to']}',
                    }),
              ),
          ]),
      ]),
    );
  }

  Widget _couponBlock(BuildContext context, AppLocalizations l) {
    final err = '${_quote?['couponError'] ?? ''}';
    final applied = _coupon != null && err.isEmpty && err != 'null';
    final discount = _qn('discount');
    return AppCard(
      onTap: _openCoupons,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: context.softAccent, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.local_offer_rounded, color: G4MColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: G4MMotion.standard,
            child: _coupon == null
                ? Column(key: const ValueKey('none'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.applyCoupon, style: context.text.titleSmall),
                    Text(l.viewOffers, style: context.text.bodySmall),
                  ])
                : Column(key: ValueKey(_coupon), crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('"$_coupon" ${applied ? 'applied' : ''}', style: context.text.titleSmall),
                    Text(
                      err.isNotEmpty && err != 'null'
                          ? err
                          : (discount > 0 ? 'You save ${Fmt.money(discount)}' : (_quoting ? 'Checking…' : 'Saving applied at checkout')),
                      style: context.text.bodySmall?.copyWith(color: err.isNotEmpty && err != 'null' ? G4MColors.danger : G4MColors.success, fontWeight: FontWeight.w700),
                    ),
                  ]),
          ),
        ),
        if (_coupon != null)
          IconButton(onPressed: () => _set(() => _coupon = null), icon: const Icon(Icons.close_rounded))
        else
          const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }

  Widget _walletBlock(BuildContext context, AppLocalizations l) {
    if (!AppConfig.platform.value.walletEnabled || _s.isGuest) return const SizedBox.shrink();
    return ValueListenableBuilder<AppUser?>(
      valueListenable: _s.profile,
      builder: (context, u, _) {
        final bal = u?.walletBalance ?? 0;
        return AppCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.softPrimary, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_wallet_rounded, color: G4MColors.primary, size: 20),
            ),
            title: Text(l.useWallet, style: context.text.titleSmall),
            subtitle: Text('Balance ${Fmt.money(bal)}${_useWallet && _qn('walletUsed') > 0 ? ' · using ${Fmt.money(_qn('walletUsed'))}' : ''}'),
            value: _useWallet && bal > 0,
            onChanged: bal <= 0 ? null : (v) => _set(() => _useWallet = v),
          ),
        );
      },
    );
  }

  Widget _paymentBlock(BuildContext context, AppLocalizations l) {
    final payable = _qn('payable');
    if (payable <= 0 && _qn('total') > 0) {
      return AppCard(
        color: context.softPrimary,
        child: Row(children: [
          const Icon(Icons.verified_rounded, color: G4MColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text('Fully paid from your wallet', style: context.text.titleSmall)),
        ]),
      );
    }
    final opts = _methods(_useWallet ? payable : _qn('total'));
    if (opts.isNotEmpty && !opts.any((o) => o.$1 == _method)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _method = opts.first.$1);
      });
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.paymentMethod, style: context.text.titleSmall),
        const SizedBox(height: 6),
        if (opts.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('No payment methods are enabled.', style: context.text.bodySmall)),
        RadioGroup<String>(
          groupValue: _method,
          onChanged: (v) => setState(() => _method = v ?? _method),
          child: Column(children: [
            for (final o in opts)
              RadioListTile<String>(
                value: o.$1,
                contentPadding: EdgeInsets.zero,
                dense: true,
                secondary: Icon(o.$3, color: _method == o.$1 ? G4MColors.primary : context.muted),
                title: Text(o.$2, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _billBlock(BuildContext context, AppLocalizations l) {
    Widget row(String label, double v, {bool minus = false, bool bold = false, Color? color, String? zeroText}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: bold ? context.text.titleMedium : context.text.bodyMedium)),
            if (v == 0 && zeroText != null)
              Text(zeroText, style: const TextStyle(color: G4MColors.success, fontWeight: FontWeight.w800))
            else
              MoneyText(minus ? -v : v,
                  style: (bold ? context.text.titleMedium : context.text.bodyMedium)?.copyWith(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ]),
        );
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l.billDetails, style: context.text.titleSmall),
          const Spacer(),
          if (_quoting) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          if (!_quoting && _estimate) Tag('Estimate', color: G4MColors.warning, filled: false),
        ]),
        const SizedBox(height: 8),
        row(l.itemTotal, _qn('subtotal')),
        if (_addonsAmount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 2),
            child: Row(children: [
              const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: G4MColors.primary),
              const SizedBox(width: 4),
              Expanded(child: Text('Includes add-ons', style: context.text.bodySmall)),
              MoneyText(_addonsAmount, style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
        row(l.deliveryFee, _qn('deliveryFee'), zeroText: l.free),
        if (_qn('discount') > 0) row(l.discount, _qn('discount'), minus: true, color: G4MColors.success),
        if (_qn('tax') > 0) row(l.tax, _qn('tax')),
        if (_qn('walletUsed') > 0) row(l.walletUsed, _qn('walletUsed'), minus: true, color: G4MColors.success),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Divider(color: context.line)),
        row(l.toPay, _qn('payable'), bold: true),
        if (_qn('discount') > 0)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: G4MColors.success.withValues(alpha: .1), borderRadius: BorderRadius.circular(8)),
            child: Text('You are saving ${Fmt.money(_qn('discount'))} on this order',
                style: const TextStyle(color: G4MColors.success, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
      ]),
    );
  }

  Widget _checkoutBar(BuildContext context, AppLocalizations l) {
    final guest = _s.isGuest;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (widget.standalone ? MediaQuery.paddingOf(context).bottom : 0)),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: widget.standalone ? null : BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x1A0A4A33), blurRadius: 24, offset: Offset(0, -4))],
      ),
      margin: widget.standalone ? null : const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(children: [
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          MoneyText(_qn('payable'), style: context.text.titleLarge),
          Text(_estimate ? 'estimated total' : l.toPay, style: context.text.bodySmall),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _placing ? null : _place,
            child: AnimatedSwitcher(
              duration: G4MMotion.standard,
              child: _placing
                  ? const SizedBox(key: ValueKey('p'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Row(key: ValueKey(guest), mainAxisSize: MainAxisSize.min, children: [
                      Text(guest ? l.loginToCheckout : l.placeOrder),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// "+ Extra cheese · Olives" under a customised cart line.
class _AddonChips extends StatelessWidget {
  const _AddonChips({required this.addons});
  final List<ProductAddon> addons;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (final a in addons)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: context.softPrimary, borderRadius: BorderRadius.circular(G4MRadius.pill)),
              child: Text('+ ${a.name}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: G4MColors.primary)),
            ),
        ]),
      );
}

class _CartStepper extends StatelessWidget {
  const _CartStepper({required this.product, required this.line});
  final Product product;
  final CartItem line;
  @override
  Widget build(BuildContext context) {
    final s = Session.instance;
    final variantId = line.variantId;
    final q = s.cart.value[line.id]?.qty ?? line.qty;
    void set(int n) => s.setLineQty(s.cart.value[line.id] ?? line, n).catchError((Object e) {
          if (context.mounted) context.toast(friendlyError(e), error: true);
        });
    Widget btn(IconData i, VoidCallback f) => InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            f();
          },
          radius: 20,
          child: Padding(padding: const EdgeInsets.all(6), child: Icon(i, size: 18, color: G4MColors.primary)),
        );
    final v = product.variants.where((e) => e.id == variantId).firstOrNull;
    final stock = v?.stock ?? product.stock;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: G4MColors.primary.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(q <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, () => set(q - 1)),
        SizedBox(
          width: 24,
          child: AnimatedSwitcher(
            duration: G4MMotion.standard,
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text('$q', key: ValueKey(q), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        btn(Icons.add_rounded, () {
          // Stock is shared by every add-on combination of the same variant.
          if (stock > 0 && s.qtyVariantAll(product.id, variantId) >= stock) {
            context.toast('Only $stock available');
            return;
          }
          set(q + 1);
        }),
      ]),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.value, required this.onChanged});
  final List<(String, String, IconData)> options;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: context.cardAlt, borderRadius: BorderRadius.circular(14)),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth / options.length;
          final idx = options.indexWhere((o) => o.$1 == value);
          return Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: idx * w,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(
                decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(11), boxShadow: context.softShadow),
              ),
            ),
            Row(children: [
              for (final o in options)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => onChanged(o.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(o.$3, size: 18, color: o.$1 == value ? G4MColors.primary : context.muted),
                        const SizedBox(width: 6),
                        Text(o.$2, style: TextStyle(fontWeight: FontWeight.w700, color: o.$1 == value ? context.ink : context.muted)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ]);
        }),
      );
}

/// Available coupons + manual code. Pops with the chosen code ('' clears).
class _CouponSheet extends StatefulWidget {
  const _CouponSheet({required this.subtotal});
  final double subtotal;
  @override
  State<_CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends State<_CouponSheet> {
  final _ctl = TextEditingController();
  bool _busy = false;
  String? _msg;

  Future<void> _apply(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await G4MApi.instance.validateCoupon(c, widget.subtotal);
      if (r['valid'] == false) {
        setState(() => _msg = '${r['message'] ?? 'This coupon cannot be applied'}');
        return;
      }
      if (mounted) Navigator.of(context).pop(c);
    } catch (e) {
      // Validation service unavailable: let the checkout quote decide.
      if (isMissingFunction(e) || e.toString().contains('internal') || e.toString().contains('unavailable')) {
        if (mounted) Navigator.of(context).pop(c);
      } else {
        setState(() => _msg = friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(hintText: 'Enter coupon code', errorText: _msg, prefixIcon: const Icon(Icons.confirmation_number_outlined)),
                  onSubmitted: _apply,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _busy ? null : () => _apply(_ctl.text), child: const Text('Apply')),
            ]),
          ),
          Expanded(
            child: StreamBuilder<List<Coupon>>(
              stream: CatalogRepo.instance.activeCoupons(),
              builder: (context, snap) {
                final list = snap.data;
                if (list == null) return const ListSkeleton(count: 4, height: 92);
                if (list.isEmpty) return const EmptyState(icon: Icons.local_offer_outlined, title: 'No offers right now');
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    final ok = c.minOrder <= 0 || widget.subtotal >= c.minOrder;
                    return Opacity(
                      opacity: ok ? 1 : .55,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(height: 92, child: CouponTicket(coupon: c, width: double.infinity, onTap: () => _apply(c.code))),
                        if (!ok)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Text('Add ${Fmt.money(c.minOrder - widget.subtotal)} more to use this', style: context.text.bodySmall),
                          ),
                      ]),
                    ).stagger(i);
                  },
                );
              },
            ),
          ),
        ]),
      );
}
