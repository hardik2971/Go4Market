import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:g4m_core/g4m_core.dart';

/// App-side data helpers that sit on top of g4m_core.
///
/// The backend is seeded concurrently and composite indexes may still be building, so every
/// ordered query here retries without `orderBy` on `failed-precondition` and sorts client-side.

bool isIndexError(Object e) => e is FirebaseException && e.code == 'failed-precondition';
bool isPermissionError(Object e) => e is FirebaseException && e.code == 'permission-denied';
/// FirebaseFunctionsException extends FirebaseException; a callable that isn't deployed yet
/// surfaces as `not-found` / `unimplemented`.
bool isMissingFunction(Object e) => e is FirebaseException && (e.code == 'not-found' || e.code == 'unimplemented');

/// Streams [ordered]; if Firestore says the index is missing, falls back to [plain] + [sort].
/// Permission errors become an empty list so screens show their empty state instead of crashing.
Stream<List<T>> resilientQuery<T>(
  Query<Json> ordered,
  Query<Json> plain,
  T Function(DocumentSnapshot<Json>) map, {
  int Function(T a, T b)? sort,
}) async* {
  try {
    await for (final s in ordered.snapshots()) {
      yield s.docs.map(map).toList();
    }
  } catch (e) {
    if (isIndexError(e)) {
      debugPrint('[g4m] index missing, falling back: $e');
      try {
        await for (final s in plain.snapshots()) {
          final l = s.docs.map(map).toList();
          if (sort != null) l.sort(sort);
          yield l;
        }
      } catch (e2) {
        if (isPermissionError(e2)) {
          yield <T>[];
        } else {
          rethrow;
        }
      }
    } else if (isPermissionError(e)) {
      debugPrint('[g4m] permission denied: $e');
      yield <T>[];
    } else {
      rethrow;
    }
  }
}

int _byNewest(DateTime? a, DateTime? b) => (b ?? DateTime(2000)).compareTo(a ?? DateTime(2000));

/// Live platform/payment settings shared by the whole app.
class AppConfig {
  AppConfig._();
  static final platform = ValueNotifier<PlatformSettings>(PlatformSettings(const {}));
  static final payments = ValueNotifier<PaymentSettings>(PaymentSettings(const {}));
  static final modules = ValueNotifier<List<MarketModule>>(const []);
  static StreamSubscription? _a, _b, _c;

  static void start() {
    _a ??= SettingsRepo.instance.platform().listen((v) => platform.value = v, onError: (_) {});
    _b ??= SettingsRepo.instance.payments().listen((v) => payments.value = v, onError: (_) {});
    _c ??= CatalogRepo.instance.modules().listen((v) => modules.value = v, onError: (_) {});
  }

  static double get codMax => _num(platform.value.data['codMax'], 0);
  static double get maxDeliveryKm => _num(platform.value.data['maxDeliveryKm'], 0);
  static double _num(dynamic v, double f) => v is num ? v.toDouble() : f;
}

/// Catalogue access with index fallbacks.
class Catalog {
  Catalog._();

  static Query<Json> _plain({String? moduleId, String? categoryId, String? sellerId, bool? featured}) {
    Query<Json> q = Fs.products.where('status', isEqualTo: 'active');
    if (moduleId != null) q = q.where('moduleId', isEqualTo: moduleId);
    if (categoryId != null) q = q.where('categoryPath', arrayContains: categoryId);
    if (sellerId != null) q = q.where('sellerId', isEqualTo: sellerId);
    if (featured != null) q = q.where('featured', isEqualTo: featured);
    return q;
  }

  static void sortLocal(List<Product> l, String sort) {
    switch (sort) {
      case 'price_asc':
        l.sort((a, b) => a.price.compareTo(b.price));
      case 'price_desc':
        l.sort((a, b) => b.price.compareTo(a.price));
      case 'popular':
        l.sort((a, b) => b.soldCount.compareTo(a.soldCount));
      case 'rating':
        l.sort((a, b) => b.rating.compareTo(a.rating));
      case 'discount':
        l.sort((a, b) => b.discountPct.compareTo(a.discountPct));
      default:
        l.sort((a, b) => _byNewest(a.createdAt, b.createdAt));
    }
  }

  static Future<List<Product>> products({
    String? moduleId,
    String? categoryId,
    String? sellerId,
    bool? featured,
    String sort = 'newest',
    int limit = 40,
  }) async {
    final serverSort = sort == 'discount' ? 'newest' : sort;
    try {
      final s = await CatalogRepo.instance
          .productsQuery(moduleId: moduleId, categoryId: categoryId, sellerId: sellerId, featured: featured, sort: serverSort)
          .limit(limit)
          .get();
      final l = s.docs.map(Product.fromDoc).toList();
      if (sort == 'discount') sortLocal(l, sort);
      return l;
    } catch (e) {
      if (!isIndexError(e)) rethrow;
      final s = await _plain(moduleId: moduleId, categoryId: categoryId, sellerId: sellerId, featured: featured)
          .limit(math.max(limit, 60))
          .get();
      final l = s.docs.map(Product.fromDoc).toList();
      sortLocal(l, sort);
      return l.take(limit).toList();
    }
  }

  /// Resolves a featured section by `type` (manual/category/bestsellers/newest/top_rated/deals).
  static Future<List<Product>> section(FeaturedSection f, {int limit = 12}) async {
    final module = f.moduleId.isEmpty ? null : f.moduleId;
    switch (f.type) {
      case 'manual':
        return CatalogRepo.instance.productsByIds(f.productIds.take(30).toList());
      case 'category':
        return products(categoryId: f.categoryId.isEmpty ? null : f.categoryId, moduleId: f.categoryId.isEmpty ? module : null, limit: limit);
      case 'bestsellers':
        return products(moduleId: module, sort: 'popular', limit: limit);
      case 'top_rated':
        return products(moduleId: module, sort: 'rating', limit: limit);
      case 'deals':
        final l = await products(moduleId: module, limit: 60);
        final deals = l.where((p) => p.discountPct > 0).toList();
        sortLocal(deals, 'discount');
        return deals.take(limit).toList();
      default:
        return products(moduleId: module, limit: limit);
    }
  }

  static Future<List<Product>>? _pool;
  static DateTime? _poolAt;

  /// Keyword search with a name-contains fallback for docs that have no `keywords` yet.
  static Future<List<Product>> search(String text, {int limit = 40}) async {
    List<Product> out = [];
    try {
      out = await CatalogRepo.instance.search(text, limit: limit);
    } catch (e) {
      debugPrint('[g4m] keyword search failed: $e');
    }
    if (out.isNotEmpty) return out;
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return [];
    // One shared pool for the fallback so a multi-term voice search doesn't read 200 docs per term.
    if (_pool == null || DateTime.now().difference(_poolAt!).inMinutes > 5) {
      _poolAt = DateTime.now();
      _pool = products(limit: 200);
    }
    List<Product> pool;
    try {
      pool = await _pool!;
    } catch (_) {
      _pool = null;
      rethrow;
    }
    final tokens = t.split(RegExp(r'\s+')).where((e) => e.length > 1).toList();
    bool hit(Product p) {
      final hay = '${p.name} ${p.brandName} ${p.tags.join(' ')} ${p.shortDescription}'.toLowerCase();
      return hay.contains(t) || tokens.any(hay.contains);
    }

    return pool.where(hit).take(limit).toList();
  }

  /// Same category first, then same module, for out-of-stock replacements and "similar".
  static Future<List<Product>> similar(Product p, {int limit = 10}) async {
    List<Product> l = [];
    try {
      l = await CatalogRepo.instance.similar(p, limit: limit + 4);
    } catch (_) {}
    if (l.length < 3) {
      try {
        final more = await products(moduleId: p.moduleId, limit: 20);
        l = {...l, ...more.where((e) => e.id != p.id)}.toList();
      } catch (_) {}
    }
    return l.where((e) => e.inStock && e.id != p.id).take(limit).toList();
  }

  /// Cross-sell: popular items from the same module but a different category.
  static Future<List<Product>> crossSell(Product p, {int limit = 10}) async {
    try {
      final l = await products(moduleId: p.moduleId, sort: 'popular', limit: 30);
      return l.where((e) => e.id != p.id && e.categoryId != p.categoryId && e.inStock).take(limit).toList();
    } catch (_) {
      return [];
    }
  }
}

/// Customer-owned collections, with index fallbacks.
class MyData {
  MyData._();
  static String get uid => FirebaseAuth.instance.currentUser?.uid ?? '_';

  static Stream<List<ShopOrder>> orders() => resilientQuery(
        Fs.orders.where('userId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(100),
        Fs.orders.where('userId', isEqualTo: uid).limit(100),
        ShopOrder.fromDoc,
        sort: (a, b) => _byNewest(a.createdAt, b.createdAt),
      );

  static Stream<List<WalletTxn>> walletTxns() => resilientQuery(
        Fs.walletTransactions.where('userId', isEqualTo: uid).orderBy('createdAt', descending: true).limit(60),
        Fs.walletTransactions.where('userId', isEqualTo: uid).limit(60),
        WalletTxn.fromDoc,
        sort: (a, b) => _byNewest(a.createdAt, b.createdAt),
      );

  static Stream<List<AppNotification>> inbox() => resilientQuery(
        Fs.inbox(uid).orderBy('createdAt', descending: true).limit(60),
        Fs.inbox(uid).limit(60),
        AppNotification.fromDoc,
        sort: (a, b) => _byNewest(a.createdAt, b.createdAt),
      );

  static Stream<List<Json>> subscriptions() => resilientQuery(
        Fs.subscriptions.where('userId', isEqualTo: uid).orderBy('createdAt', descending: true),
        Fs.subscriptions.where('userId', isEqualTo: uid),
        (d) => {'id': d.id, ...?d.data()},
      );

  static Stream<List<Json>> returnsFor(String orderId) => resilientQuery(
        Fs.returns.where('userId', isEqualTo: uid).where('orderId', isEqualTo: orderId),
        Fs.returns.where('userId', isEqualTo: uid).where('orderId', isEqualTo: orderId),
        (d) => {'id': d.id, ...?d.data()},
      );

  /// True if the user has a delivered order containing [productId] (gate for "write review").
  static Future<bool> hasDelivered(String productId) async {
    try {
      final s = await Fs.orders.where('userId', isEqualTo: uid).where('status', isEqualTo: 'delivered').limit(50).get();
      return s.docs.map(ShopOrder.fromDoc).any((o) => o.items.any((i) => i.productId == productId));
    } catch (_) {
      return true; // let the server decide
    }
  }
}

/// Great-circle distance in km.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// "milk, bread and eggs" -> [milk, bread, eggs]. Handles English + Hindi connectors.
List<String> splitSearchTerms(String text) => text
    .toLowerCase()
    .split(RegExp(r'\s*(?:,|;|\+|&|\band\b|\bor\b|\bphir\b|\baur\b|और|\bplus\b|\bthen\b)\s*'))
    .map((e) => e.trim())
    .where((e) => e.length > 1)
    .toSet()
    .toList();

double jsonNum(dynamic v, [double f = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? f;

DateTime? asDate(dynamic v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      String s => DateTime.tryParse(s),
      _ => null,
    };

/// True when now is inside [startAt, endAt] (missing bounds are open).
bool inWindow(Json data) {
  final now = DateTime.now();
  final s = asDate(data['startAt']), e = asDate(data['endAt']);
  if (s != null && s.isAfter(now)) return false;
  if (e != null && e.isBefore(now)) return false;
  return true;
}
