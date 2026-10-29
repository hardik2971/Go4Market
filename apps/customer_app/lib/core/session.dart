import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:g4m_core/g4m_core.dart';

import 'addons.dart';
import 'social_auth.dart';

/// Signed-in shopper state: auth user, profile doc, cart, wishlist.
///
/// Cart writes are optimistic: the local map changes first so steppers feel instant,
/// then Firestore catches up and the snapshot listener reconciles.
class Session {
  Session._();
  static final instance = Session._();

  final authUser = ValueNotifier<User?>(null);
  final profile = ValueNotifier<AppUser?>(null);
  final cart = ValueNotifier<Map<String, CartItem>>({});
  final wishlist = ValueNotifier<Set<String>>({});

  /// Bumped after every auth change so screens holding user-scoped streams can rebuild.
  final epoch = ValueNotifier<int>(0);

  final _products = <String, Product>{};
  StreamSubscription? _authSub, _userSub, _cartSub, _wishSub;
  final _pending = <String, int>{};

  bool get signedIn => FirebaseAuth.instance.currentUser != null;
  bool get isGuest => FirebaseAuth.instance.currentUser?.isAnonymous ?? true;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  int get cartCount => cart.value.values.fold(0, (a, b) => a + b.qty);

  void start() {
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  void _onAuth(User? u) {
    authUser.value = u;
    _userSub?.cancel();
    _cartSub?.cancel();
    _wishSub?.cancel();
    profile.value = null;
    cart.value = {};
    wishlist.value = {};
    if (u != null) {
      _userSub = Fs.user(u.uid).snapshots().listen(
            (d) => profile.value = d.exists ? AppUser.fromDoc(d) : null,
            onError: (e) => debugPrint('[g4m] profile: $e'),
          );
      _cartSub = Fs.cart(u.uid).snapshots().listen((s) {
        final m = {for (final d in s.docs) d.id: CartItem.fromDoc(d)};
        // Keep optimistic quantities that the server hasn't confirmed yet.
        _pending.forEach((id, qty) {
          if (m[id]?.qty == qty || (qty == 0 && !m.containsKey(id))) return;
          if (qty == 0) {
            m.remove(id);
          } else if (m[id] != null) {
            m[id] = CartItem(id, {...m[id]!.data, 'qty': qty});
          } else if (cart.value[id] != null) {
            // A line added optimistically that the server hasn't echoed yet.
            m[id] = CartItem(id, {...cart.value[id]!.data, 'qty': qty});
          }
        });
        cart.value = m;
      }, onError: (e) => debugPrint('[g4m] cart: $e'));
      _wishSub = Fs.wishlist(u.uid).snapshots().listen(
            (s) => wishlist.value = s.docs.map((d) => d.id).toSet(),
            onError: (e) => debugPrint('[g4m] wishlist: $e'),
          );
    }
    epoch.value++;
  }

  // ---------------------------------------------------------------- auth

  Future<void> continueAsGuest() async {
    if (FirebaseAuth.instance.currentUser == null) await AuthRepo.instance.guest();
  }

  Future<void> _ensureUser() async {
    if (FirebaseAuth.instance.currentUser == null) await AuthRepo.instance.guest();
  }

  /// Captures a guest cart so it can be merged into the account that signs in.
  Future<List<Json>> _guestCart() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || !u.isAnonymous) return [];
    try {
      final s = await Fs.cart(u.uid).get();
      return s.docs.map((d) => {'_id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _mergeCart(List<Json> items) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || items.isEmpty) return;
    final b = Fs.db.batch();
    for (final it in items) {
      final id = it.remove('_id') as String;
      final qty = (it['qty'] as num?)?.toInt() ?? 1;
      b.set(Fs.cart(u.uid).doc(id), {...it, 'qty': FieldValue.increment(qty), 'addedAt': Fs.now}, SetOptions(merge: true));
    }
    try {
      await b.commit();
    } catch (e) {
      debugPrint('[g4m] cart merge failed: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    final guest = await _guestCart();
    await AuthRepo.instance.signIn(email, password);
    await _mergeCart(guest);
  }

  Future<void> signUp({required String name, required String email, required String password, String? phone, String? referral}) async {
    final guest = await _guestCart();
    await AuthRepo.instance.signUp(
      name: name,
      email: email,
      password: password,
      phone: (phone ?? '').isEmpty ? null : phone,
      referralCode: referral,
    );
    await _mergeCart(guest);
  }

  /// Phone / Google sign-in. Like the email flow, a guest cart is merged into the account.
  /// (We sign in rather than link the anonymous user, so `onUserCreated` provisions the account.)
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    final guest = await _guestCart();
    final cred = await FirebaseAuth.instance.signInWithCredential(credential);
    await _mergeCart(guest);
    return cred;
  }

  Future<void> signOut() async {
    await SocialAuth.signOutGoogle();
    await AuthRepo.instance.signOut();
  }

  // ---------------------------------------------------------------- cart

  String itemId(String productId, String variantId) => '${productId}_$variantId';

  /// Total quantity of a product + variant across all its add-on combinations.
  int qtyVariantAll(String productId, String variantId) =>
      cart.value.values.where((c) => c.productId == productId && c.variantId == variantId).fold(0, (a, b) => a + b.qty);

  /// Adds [qty] of a customised line. Different add-on sets are separate lines, stored exactly like
  /// the website's cart docs: `{productId, variantId, qty, sellerId, addonIds (sorted), addedAt}`.
  Future<void> addLine(Product p, String variantId, Iterable<String> addonIds, {int qty = 1}) async {
    final ids = normalizeAddonIds(addonIds);
    if (ids.isEmpty) return setQty(p, qtyOf(p.id, variantId) + qty, variantId: variantId);
    _products[p.id] = p;
    final id = cartLineId(p.id, variantId, ids);
    final next = (cart.value[id]?.qty ?? 0) + qty;
    final data = <String, dynamic>{'productId': p.id, 'variantId': variantId, 'qty': next, 'sellerId': p.sellerId, 'addonIds': ids};
    cart.value = {...cart.value, id: CartItem(id, data)};
    _pending[id] = next;
    try {
      await _ensureUser();
      await Fs.cart(uid!).doc(id).set({...data, 'addedAt': Fs.now}, SetOptions(merge: true));
    } finally {
      if (_pending[id] == next) _pending.remove(id);
    }
  }

  /// Sets the quantity of an existing line by its doc id, keeping its add-ons.
  Future<void> setLineQty(CartItem c, int qty) async {
    final p = _products[c.productId];
    if (p != null && c.addonIds.isEmpty && c.id == itemId(c.productId, c.variantId)) {
      return setQty(p, qty, variantId: c.variantId);
    }
    final next = Map<String, CartItem>.from(cart.value);
    if (qty <= 0) {
      next.remove(c.id);
    } else {
      next[c.id] = CartItem(c.id, {...c.data, 'qty': qty});
    }
    cart.value = next;
    _pending[c.id] = qty;
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      final ref = Fs.cart(u.uid).doc(c.id);
      if (qty <= 0) {
        await ref.delete();
      } else {
        await ref.set({
          'productId': c.productId,
          'variantId': c.variantId,
          'sellerId': c.sellerId,
          if (c.addonIds.isNotEmpty) 'addonIds': c.addonIds,
          'qty': qty,
        }, SetOptions(merge: true));
      }
    } finally {
      if (_pending[c.id] == qty) _pending.remove(c.id);
    }
  }

  int qtyOf(String productId, [String variantId = 'default']) =>
      cart.value[itemId(productId, variantId)]?.qty ?? 0;

  /// Total quantity of a product across all its variants.
  int qtyAll(String productId) =>
      cart.value.values.where((c) => c.productId == productId).fold(0, (a, b) => a + b.qty);

  Future<void> setQty(Product p, int qty, {String variantId = 'default'}) async {
    _products[p.id] = p;
    final id = itemId(p.id, variantId);
    final next = Map<String, CartItem>.from(cart.value);
    if (qty <= 0) {
      next.remove(id);
    } else {
      next[id] = CartItem(id, {'productId': p.id, 'variantId': variantId, 'qty': qty, 'sellerId': p.sellerId});
    }
    cart.value = next;
    _pending[id] = qty;
    try {
      await _ensureUser();
      await ShopperRepo.instance.setCartQty(p, qty, variantId: variantId);
    } finally {
      if (_pending[id] == qty) _pending.remove(id);
    }
  }

  Future<void> removeItem(String id) async {
    final next = Map<String, CartItem>.from(cart.value)..remove(id);
    cart.value = next;
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) await Fs.cart(u.uid).doc(id).delete();
  }

  Future<void> clearCart() async {
    cart.value = {};
    if (FirebaseAuth.instance.currentUser != null) await ShopperRepo.instance.clearCart();
  }

  // ---------------------------------------------------------------- wishlist

  Future<void> toggleWishlist(String productId) async {
    await _ensureUser();
    final on = !wishlist.value.contains(productId);
    wishlist.value = on ? {...wishlist.value, productId} : ({...wishlist.value}..remove(productId));
    await ShopperRepo.instance.toggleWishlist(productId, on);
  }

  // ---------------------------------------------------------------- product cache

  Product? cached(String id) => _products[id];
  void remember(Iterable<Product> list) {
    for (final p in list) {
      _products[p.id] = p;
    }
  }

  Future<Map<String, Product>> ensureProducts(Iterable<String> ids, {bool refresh = false}) async {
    final want = ids.toSet().where((id) => refresh || !_products.containsKey(id)).toList();
    if (want.isNotEmpty) {
      try {
        remember(await CatalogRepo.instance.productsByIds(want));
      } catch (e) {
        debugPrint('[g4m] products: $e');
      }
    }
    return {for (final id in ids) if (_products[id] != null) id: _products[id]!};
  }
}
