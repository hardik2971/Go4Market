import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../firebase_options.dart';
import '../models/models.dart';

/// Typed collection references. Use these instead of string paths.
abstract final class Fs {
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static CollectionReference<Json> col(String path) => db.collection(path);

  static DocumentReference<Json> user(String uid) => db.doc('users/$uid');
  static CollectionReference<Json> addresses(String uid) => db.collection('users/$uid/addresses');
  static CollectionReference<Json> cart(String uid) => db.collection('users/$uid/cart');
  static CollectionReference<Json> wishlist(String uid) => db.collection('users/$uid/wishlist');
  static CollectionReference<Json> inbox(String uid) => db.collection('users/$uid/notifications');

  static CollectionReference<Json> get users => col('users');
  static CollectionReference<Json> get sellers => col('sellers');
  static CollectionReference<Json> get deliveryPartners => col('deliveryPartners');
  static CollectionReference<Json> get modules => col('modules');
  static CollectionReference<Json> get categories => col('categories');
  static CollectionReference<Json> get brands => col('brands');
  static CollectionReference<Json> get attributes => col('attributes');
  static CollectionReference<Json> get products => col('products');
  static CollectionReference<Json> reviews(String productId) => db.collection('products/$productId/reviews');
  static CollectionReference<Json> get sliders => col('sliders');
  static CollectionReference<Json> get offers => col('offers');
  static CollectionReference<Json> get featuredSections => col('featuredSections');
  static CollectionReference<Json> get coupons => col('coupons');
  static CollectionReference<Json> get orders => col('orders');
  static CollectionReference<Json> get returns => col('returns');
  static CollectionReference<Json> get walletTransactions => col('walletTransactions');
  static CollectionReference<Json> get withdrawals => col('withdrawals');
  static CollectionReference<Json> get fundTransfers => col('fundTransfers');
  static CollectionReference<Json> get cashCollections => col('cashCollections');
  static CollectionReference<Json> get productRequests => col('productRequests');
  static CollectionReference<Json> get subscriptions => col('subscriptions');
  static CollectionReference<Json> get membershipPlans => col('membershipPlans');
  static CollectionReference<Json> get blogs => col('blogs');
  static CollectionReference<Json> get blogCategories => col('blogCategories');
  static CollectionReference<Json> get faqs => col('faqs');
  static CollectionReference<Json> get pages => col('pages');
  static CollectionReference<Json> get popups => col('popups');
  static CollectionReference<Json> get campaigns => col('campaigns');
  static CollectionReference<Json> get emailTemplates => col('emailTemplates');
  static CollectionReference<Json> get cities => col('cities');
  static CollectionReference<Json> get languages => col('languages');
  static CollectionReference<Json> get staff => col('staff');
  static CollectionReference<Json> get adminRoles => col('adminRoles');
  static DocumentReference<Json> get platformSettings => db.doc('settings/platform');
  static DocumentReference<Json> get paymentSettings => db.doc('settings/payments');
  static DocumentReference<Json> get statsOverview => db.doc('stats/overview');
  static CollectionReference<Json> get stats => col('stats');

  static FieldValue get now => FieldValue.serverTimestamp();
}

/// Thin wrapper over the callable Cloud Functions in docs/ARCHITECTURE.md.
class G4MApi {
  G4MApi._();
  static final instance = G4MApi._();
  final _fns = FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  Future<Json> call(String name, [Json? input]) async {
    final res = await _fns.httpsCallable(name, options: HttpsCallableOptions(timeout: const Duration(seconds: 60)))
        .call<dynamic>(input ?? const {});
    final d = res.data;
    return d is Map ? Map<String, dynamic>.from(d) : {'result': d};
  }

  Future<Json> checkoutQuote(Json input) => call('getCheckoutQuote', input);
  Future<Json> placeOrder(Json input) => call('placeOrder', input);
  Future<Json> confirmPayment(Json input) => call('confirmPayment', input);
  Future<Json> validateCoupon(String code, double subtotal) =>
      call('validateCoupon', {'code': code, 'subtotal': subtotal});
  Future<Json> updateOrderStatus(String orderId, String status, {String? note, String? otp, double? cashCollected}) =>
      call('updateOrderStatus', {
        'orderId': orderId,
        'status': status,
        'note': ?note,
        'otp': ?otp,
        'cashCollected': ?cashCollected,
      });
  Future<Json> assignDeliveryPartner(String orderId, [String? partnerId]) =>
      call('assignDeliveryPartner', {'orderId': orderId, 'partnerId': partnerId});
  Future<Json> acceptDelivery(String orderId) => call('acceptDelivery', {'orderId': orderId});
  Future<Json> walletTopup(double amount, String provider) =>
      call('walletTopup', {'amount': amount, 'provider': provider});
  Future<Json> confirmWalletTopup(Json input) => call('confirmWalletTopup', input);
  Future<Json> requestReturn(Json input) => call('requestReturn', input);
  Future<Json> processReturn(Json input) => call('processReturn', input);
  Future<Json> registerSeller(Json input) => call('registerSeller', input);
  Future<Json> registerDeliveryPartner(Json input) => call('registerDeliveryPartner', input);
  Future<Json> reviewSeller(Json input) => call('reviewSeller', input);
  Future<Json> reviewDeliveryPartner(Json input) => call('reviewDeliveryPartner', input);
  Future<Json> setUserRole(String uid, String role) => call('setUserRole', {'uid': uid, 'role': role});
  Future<Json> createStaffUser(Json input) => call('createStaffUser', input);
  Future<Json> requestWithdrawal(double amount, String method) =>
      call('requestWithdrawal', {'amount': amount, 'method': method});
  Future<Json> processWithdrawal(String id, String status, [String? note]) =>
      call('processWithdrawal', {'id': id, 'status': status, 'note': note});
  Future<Json> transferFunds(Json input) => call('transferFunds', input);
  Future<Json> settleCash(String partnerId, double amount) =>
      call('settleCash', {'partnerId': partnerId, 'amount': amount});
  Future<Json> adjustWallet(Json input) => call('adjustWallet', input);
  Future<Json> sendCampaign(String campaignId) => call('sendCampaign', {'campaignId': campaignId});
  Future<Json> generateDescription(Json input) => call('generateDescription', input);
  Future<Json> posCheckout(Json input) => call('posCheckout', input);
  Future<Json> submitReview(String productId, int rating, String comment) =>
      call('submitReview', {'productId': productId, 'rating': rating, 'comment': comment});
}

class AuthRepo {
  AuthRepo._();
  static final instance = AuthRepo._();
  final auth = FirebaseAuth.instance;

  User? get user => auth.currentUser;
  Stream<User?> get changes => auth.idTokenChanges();

  Future<String> role({bool refresh = false}) async {
    final u = auth.currentUser;
    if (u == null || u.isAnonymous) return 'guest';
    final t = await u.getIdTokenResult(refresh);
    return (t.claims?['role'] as String?) ?? Roles.customer;
  }

  Future<UserCredential> signIn(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> signUp({required String name, required String email, required String password, String? phone, String? referralCode}) async {
    final cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user!.updateDisplayName(name);
    // onUserCreated creates the base doc; merge profile fields the client knows.
    await Fs.user(cred.user!.uid).set({
      'name': name,
      'email': email.trim(),
      'phone': ?phone,
      if (referralCode != null && referralCode.isNotEmpty) 'referredBy': referralCode.trim().toUpperCase(),
      'updatedAt': Fs.now,
    }, SetOptions(merge: true));
    return cred;
  }

  Future<void> resetPassword(String email) => auth.sendPasswordResetEmail(email: email.trim());
  Future<void> signOut() => auth.signOut();
  Future<UserCredential> guest() => auth.signInAnonymously();
}

class CatalogRepo {
  CatalogRepo._();
  static final instance = CatalogRepo._();

  Stream<List<MarketModule>> modules() => Fs.modules.orderBy('order').snapshots()
      .map((s) => s.docs.map(MarketModule.fromDoc).where((m) => m.enabled).toList());

  Stream<List<Category>> categories({String? moduleId, String? parentId, bool rootsOnly = false}) {
    Query<Json> q = Fs.categories.where('active', isEqualTo: true);
    if (moduleId != null) q = q.where('moduleId', isEqualTo: moduleId);
    if (rootsOnly) q = q.where('parentId', isNull: true);
    if (parentId != null) q = q.where('parentId', isEqualTo: parentId);
    return q.snapshots().map((s) => s.docs.map(Category.fromDoc).toList()..sort((a, b) => a.order.compareTo(b.order)));
  }

  Query<Json> productsQuery({
    String? moduleId,
    String? categoryId,
    String? sellerId,
    String? brandId,
    bool? featured,
    String sort = 'newest', // newest | price_asc | price_desc | popular | rating
    String status = 'active',
  }) {
    Query<Json> q = Fs.products.where('status', isEqualTo: status);
    if (moduleId != null) q = q.where('moduleId', isEqualTo: moduleId);
    if (categoryId != null) q = q.where('categoryPath', arrayContains: categoryId);
    if (sellerId != null) q = q.where('sellerId', isEqualTo: sellerId);
    if (brandId != null) q = q.where('brandId', isEqualTo: brandId);
    if (featured != null) q = q.where('featured', isEqualTo: featured);
    return switch (sort) {
      'price_asc' => q.orderBy('price'),
      'price_desc' => q.orderBy('price', descending: true),
      'popular' => q.orderBy('soldCount', descending: true),
      'rating' => q.orderBy('rating', descending: true),
      _ => q.orderBy('createdAt', descending: true),
    };
  }

  Stream<List<Product>> products({String? moduleId, String? categoryId, String? sellerId, bool? featured, String sort = 'newest', int limit = 20}) =>
      productsQuery(moduleId: moduleId, categoryId: categoryId, sellerId: sellerId, featured: featured, sort: sort)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(Product.fromDoc).toList());

  /// Token search over `keywords` (lowercase tokens written by onProductWritten).
  Future<List<Product>> search(String text, {int limit = 40}) async {
    final tokens = text.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.length > 1).take(10).toList();
    if (tokens.isEmpty) return [];
    final s = await Fs.products
        .where('status', isEqualTo: 'active')
        .where('keywords', arrayContainsAny: tokens)
        .limit(limit)
        .get();
    final list = s.docs.map(Product.fromDoc).toList();
    int score(Product p) => tokens.where((t) => p.name.toLowerCase().contains(t)).length;
    list.sort((a, b) => score(b).compareTo(score(a)));
    return list;
  }

  Future<Product?> product(String id) async {
    final d = await Fs.products.doc(id).get();
    return d.exists ? Product.fromDoc(d) : null;
  }

  Stream<Product?> watchProduct(String id) =>
      Fs.products.doc(id).snapshots().map((d) => d.exists ? Product.fromDoc(d) : null);

  Future<Product?> productBySlug(String slug) async {
    final s = await Fs.products.where('slug', isEqualTo: slug).limit(1).get();
    return s.docs.isEmpty ? product(slug) : Product.fromDoc(s.docs.first);
  }

  Future<List<Product>> productsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final out = <Product>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final s = await Fs.products.where(FieldPath.documentId, whereIn: chunk).get();
      out.addAll(s.docs.map(Product.fromDoc));
    }
    out.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return out;
  }

  /// Products sharing a category, excluding [p]. Powers "similar" and replacements.
  Future<List<Product>> similar(Product p, {int limit = 10}) async {
    final s = await Fs.products
        .where('status', isEqualTo: 'active')
        .where('categoryId', isEqualTo: p.categoryId)
        .limit(limit + 1)
        .get();
    return s.docs.map(Product.fromDoc).where((e) => e.id != p.id).take(limit).toList();
  }

  Stream<List<Review>> reviews(String productId) => Fs.reviews(productId)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map(Review.fromDoc).toList());

  Stream<List<PromoBanner>> sliders({String? moduleId}) => _banners(Fs.sliders, moduleId);
  Stream<List<PromoBanner>> offers({String? moduleId}) => _banners(Fs.offers, moduleId);
  Stream<List<PromoBanner>> popups() => _banners(Fs.popups, null);

  Stream<List<PromoBanner>> _banners(CollectionReference<Json> c, String? moduleId) =>
      c.where('active', isEqualTo: true).snapshots().map((s) {
        final l = s.docs.map(PromoBanner.fromDoc).where((b) => moduleId == null || b.moduleId.isEmpty || b.moduleId == moduleId).toList();
        l.sort((a, b) => a.order.compareTo(b.order));
        return l;
      });

  Stream<List<FeaturedSection>> featuredSections({String? moduleId}) =>
      Fs.featuredSections.where('active', isEqualTo: true).snapshots().map((s) {
        final l = s.docs.map(FeaturedSection.fromDoc).where((f) => moduleId == null || f.moduleId.isEmpty || f.moduleId == moduleId).toList();
        l.sort((a, b) => a.order.compareTo(b.order));
        return l;
      });

  /// Resolves a featured section to its products according to its `type`.
  Future<List<Product>> sectionProducts(FeaturedSection f, {int limit = 12}) async {
    switch (f.type) {
      case 'manual':
        return productsByIds(f.productIds);
      case 'category':
        return (await productsQuery(categoryId: f.categoryId).limit(limit).get()).docs.map(Product.fromDoc).toList();
      case 'bestsellers':
        return (await productsQuery(moduleId: f.moduleId.isEmpty ? null : f.moduleId, sort: 'popular').limit(limit).get()).docs.map(Product.fromDoc).toList();
      case 'top_rated':
        return (await productsQuery(moduleId: f.moduleId.isEmpty ? null : f.moduleId, sort: 'rating').limit(limit).get()).docs.map(Product.fromDoc).toList();
      default:
        return (await productsQuery(moduleId: f.moduleId.isEmpty ? null : f.moduleId).limit(limit).get()).docs.map(Product.fromDoc).toList();
    }
  }

  Stream<List<Seller>> sellers({int limit = 20}) => Fs.sellers
      .where('status', isEqualTo: 'approved')
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Seller.fromDoc).toList());

  Stream<List<Coupon>> activeCoupons() => Fs.coupons
      .where('active', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(Coupon.fromDoc).where((c) => c.endAt == null || c.endAt!.isAfter(DateTime.now())).toList());

  Stream<List<Blog>> blogs({int limit = 20}) => Fs.blogs
      .where('published', isEqualTo: true)
      .orderBy('publishedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Blog.fromDoc).toList());

  Stream<List<Faq>> faqs() => Fs.faqs.where('active', isEqualTo: true).snapshots()
      .map((s) => s.docs.map(Faq.fromDoc).toList()..sort((a, b) => a.order.compareTo(b.order)));

  Future<CmsPage?> page(String slug) async {
    final d = await Fs.pages.doc(slug).get();
    return d.exists ? CmsPage.fromDoc(d) : null;
  }
}

class SettingsRepo {
  SettingsRepo._();
  static final instance = SettingsRepo._();
  Stream<PlatformSettings> platform() =>
      Fs.platformSettings.snapshots().map((d) => PlatformSettings(d.data() ?? {}));
  Stream<PaymentSettings> payments() =>
      Fs.paymentSettings.snapshots().map((d) => PaymentSettings(d.data() ?? {}));
}

/// Customer-side cart/wishlist/profile helpers. All writes are owner-scoped per rules.
class ShopperRepo {
  ShopperRepo._();
  static final instance = ShopperRepo._();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<AppUser?> me() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return Stream.value(null);
    return Fs.user(u.uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);
  }

  Stream<List<CartItem>> cart() => Fs.cart(_uid).snapshots().map((s) => s.docs.map(CartItem.fromDoc).toList());

  Future<void> setCartQty(Product p, int qty, {String variantId = 'default'}) {
    final ref = Fs.cart(_uid).doc('${p.id}_$variantId');
    if (qty <= 0) return ref.delete();
    return ref.set({
      'productId': p.id,
      'variantId': variantId,
      'qty': qty,
      'sellerId': p.sellerId,
      'addedAt': Fs.now,
    }, SetOptions(merge: true));
  }

  Future<void> clearCart() async {
    final s = await Fs.cart(_uid).get();
    final b = Fs.db.batch();
    for (final d in s.docs) {
      b.delete(d.reference);
    }
    await b.commit();
  }

  Stream<Set<String>> wishlistIds() => Fs.wishlist(_uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());
  Future<void> toggleWishlist(String productId, bool on) =>
      on ? Fs.wishlist(_uid).doc(productId).set({'addedAt': Fs.now}) : Fs.wishlist(_uid).doc(productId).delete();

  Stream<List<Address>> addresses() =>
      Fs.addresses(_uid).snapshots().map((s) => s.docs.map(Address.fromDoc).toList());
  Future<void> saveAddress(Json data, [String? id]) => id == null
      ? Fs.addresses(_uid).add({...data, 'createdAt': Fs.now})
      : Fs.addresses(_uid).doc(id).set({...data, 'updatedAt': Fs.now}, SetOptions(merge: true));
  Future<void> deleteAddress(String id) => Fs.addresses(_uid).doc(id).delete();

  Future<void> markViewed(String productId) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final ref = Fs.user(u.uid);
    await Fs.db.runTransaction((tx) async {
      final d = await tx.get(ref);
      final list = List<String>.from((d.data()?['recentlyViewed'] as List?) ?? const [])
        ..remove(productId)
        ..insert(0, productId);
      tx.set(ref, {'recentlyViewed': list.take(20).toList()}, SetOptions(merge: true));
    });
  }

  Stream<List<ShopOrder>> myOrders() => Fs.orders
      .where('userId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ShopOrder.fromDoc).toList());

  Stream<ShopOrder?> order(String id) => Fs.orders.doc(id).snapshots().map((d) => d.exists ? ShopOrder.fromDoc(d) : null);

  Stream<List<WalletTxn>> walletTxns() => Fs.walletTransactions
      .where('userId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(WalletTxn.fromDoc).toList());

  Stream<List<AppNotification>> notifications() => Fs.inbox(_uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  Future<void> requestProduct(String name, String description) => Fs.productRequests.add({
        'userId': _uid,
        'name': name,
        'description': description,
        'status': 'open',
        'createdAt': Fs.now,
      });

  Future<void> saveFcmToken(String token) =>
      Fs.user(_uid).set({'fcmTokens': FieldValue.arrayUnion([token])}, SetOptions(merge: true));
}

class StorageRepo {
  StorageRepo._();
  static final instance = StorageRepo._();

  /// Uploads bytes and returns a public download URL. [folder] e.g. `products/{sellerId}`.
  Future<String> upload(String folder, String fileName, Uint8List bytes, {String contentType = 'image/jpeg'}) async {
    final safe = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = FirebaseStorage.instance.ref('$folder/${DateTime.now().millisecondsSinceEpoch}_$safe');
    await ref.putData(bytes, SettableMetadata(contentType: contentType, cacheControl: 'public,max-age=31536000'));
    return ref.getDownloadURL();
  }
}
