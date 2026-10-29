import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:g4m_core/g4m_core.dart';

/// Website-side queries. Ordered queries need composite indexes that may still be building,
/// so every ordered read falls back to an unordered read plus a client-side sort on
/// `failed-precondition`.
abstract final class Data {
  static bool isIndexError(Object e) => e is FirebaseException && e.code == 'failed-precondition';

  static Query<Json> products({String? moduleId, String? categoryId, String? sellerId, String sort = 'newest', bool ordered = true}) {
    if (ordered) return CatalogRepo.instance.productsQuery(moduleId: moduleId, categoryId: categoryId, sellerId: sellerId, sort: sort);
    Query<Json> q = Fs.products.where('status', isEqualTo: 'active');
    if (moduleId != null) q = q.where('moduleId', isEqualTo: moduleId);
    if (categoryId != null) q = q.where('categoryPath', arrayContains: categoryId);
    if (sellerId != null) q = q.where('sellerId', isEqualTo: sellerId);
    return q;
  }

  static List<Product> sortProducts(List<Product> l, String sort) {
    int cmpDate(Product a, Product b) =>
        (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000));
    final out = [...l];
    switch (sort) {
      case 'price_asc':
        out.sort((a, b) => a.price.compareTo(b.price));
      case 'price_desc':
        out.sort((a, b) => b.price.compareTo(a.price));
      case 'popular':
        out.sort((a, b) => b.soldCount.compareTo(a.soldCount));
      case 'rating':
        out.sort((a, b) => b.rating.compareTo(a.rating));
      case 'discount':
        out.sort((a, b) => b.discountPct.compareTo(a.discountPct));
      default:
        out.sort(cmpDate);
    }
    return out;
  }

  /// One page of products; `after` continues from the previous page (ordered mode only).
  static Future<({List<Product> items, DocumentSnapshot? last, bool more})> productPage({
    String? moduleId,
    String? categoryId,
    String? sellerId,
    String sort = 'newest',
    int limit = 24,
    DocumentSnapshot? after,
  }) async {
    try {
      var q = products(moduleId: moduleId, categoryId: categoryId, sellerId: sellerId, sort: sort).limit(limit);
      if (after != null) q = q.startAfterDocument(after);
      final s = await q.get();
      return (items: s.docs.map(Product.fromDoc).toList(), last: s.docs.isEmpty ? after : s.docs.last, more: s.docs.length == limit);
    } catch (e) {
      if (!isIndexError(e)) rethrow;
      if (after != null) return (items: <Product>[], last: after, more: false);
      final s = await products(moduleId: moduleId, categoryId: categoryId, sellerId: sellerId, ordered: false).limit(200).get();
      return (items: sortProducts(s.docs.map(Product.fromDoc).toList(), sort), last: null, more: false);
    }
  }

  static Future<List<Product>> list({String? moduleId, String? categoryId, String? sellerId, String sort = 'newest', int limit = 12}) async =>
      (await productPage(moduleId: moduleId, categoryId: categoryId, sellerId: sellerId, sort: sort, limit: limit)).items.take(limit).toList();

  /// Biggest discounts first: popular products filtered to those with an MRP above price.
  static Future<List<Product>> deals({String? moduleId, int limit = 12}) async {
    final l = await list(moduleId: moduleId, sort: 'popular', limit: 60);
    final d = l.where((p) => p.discountPct > 0).toList()..sort((a, b) => b.discountPct.compareTo(a.discountPct));
    return d.take(limit).toList();
  }

  static Future<List<Product>> section(FeaturedSection f, {int limit = 12}) async {
    final mod = f.moduleId.isEmpty ? null : f.moduleId;
    try {
      if (f.type == 'deals') return deals(moduleId: mod, limit: limit);
      if (f.type == 'manual') return CatalogRepo.instance.productsByIds(f.productIds);
      return await CatalogRepo.instance.sectionProducts(f, limit: limit);
    } catch (e) {
      if (!isIndexError(e)) rethrow;
      final sort = switch (f.type) { 'bestsellers' => 'popular', 'top_rated' => 'rating', _ => 'newest' };
      return list(moduleId: mod, categoryId: f.type == 'category' ? f.categoryId : null, sort: sort, limit: limit);
    }
  }

  /// Frequently-bought-together style picks: popular items from the same module, other categories.
  static Future<List<Product>> crossSell(Product p, {int limit = 10}) async {
    final l = await list(moduleId: p.moduleId, sort: 'popular', limit: 40);
    return l.where((e) => e.id != p.id && e.categoryId != p.categoryId).take(limit).toList();
  }

  static Future<List<Product>> similar(Product p, {int limit = 10}) async {
    try {
      final l = await CatalogRepo.instance.similar(p, limit: limit);
      if (l.isNotEmpty) return l;
    } catch (_) {}
    final l = await list(moduleId: p.moduleId, sort: 'popular', limit: limit + 1);
    return l.where((e) => e.id != p.id).take(limit).toList();
  }

  // -------- search --------
  /// Token search (keywords) merged with a name-prefix search so partial words still match.
  static Future<List<Product>> search(String text, {int limit = 40}) async {
    final t = text.trim();
    if (t.isEmpty) return const [];
    final results = <String, Product>{};
    try {
      for (final p in await CatalogRepo.instance.search(t, limit: limit)) {
        results[p.id] = p;
      }
    } catch (_) {}
    if (results.length < 6) {
      final cap = t[0].toUpperCase() + t.substring(1).toLowerCase();
      for (final variant in {t, cap}) {
        try {
          final s = await Fs.products.orderBy('name').startAt([variant]).endAt(['$variant']).limit(20).get();
          for (final d in s.docs) {
            final p = Product.fromDoc(d);
            if (p.status == 'active') results[p.id] = p;
          }
        } catch (_) {}
      }
    }
    final tokens = t.toLowerCase().split(RegExp(r'\s+'));
    int score(Product p) {
      final n = p.name.toLowerCase();
      return tokens.where(n.contains).length * 10 + (n.startsWith(tokens.first) ? 5 : 0) + (p.inStock ? 2 : 0);
    }

    return results.values.toList()..sort((a, b) => score(b).compareTo(score(a)));
  }

  /// "milk, bread and eggs" -> [milk, bread, eggs].
  static List<String> splitTerms(String q) => q
      .toLowerCase()
      .split(RegExp(r'\s*(?:,|;|\+|&|\band\b|\bplus\b|\balso\b|\bwith\b)\s*'))
      .map((e) => e.replaceAll(RegExp(r'^(some|a|an|the|i need|i want|buy|get|order)\s+'), '').trim())
      .where((e) => e.length > 1)
      .toSet()
      .toList();

  // -------- misc collections --------
  static Future<Seller?> sellerBySlug(String slug) async {
    final s = await Fs.sellers.where('slug', isEqualTo: slug).limit(1).get();
    if (s.docs.isNotEmpty) return Seller.fromDoc(s.docs.first);
    final d = await Fs.sellers.doc(slug).get();
    return d.exists ? Seller.fromDoc(d) : null;
  }

  static Future<Seller?> seller(String id) async {
    if (id.isEmpty) return null;
    try {
      final d = await Fs.sellers.doc(id).get();
      return d.exists ? Seller.fromDoc(d) : null;
    } catch (_) {
      return null;
    }
  }

  static Stream<List<Json>> cities() => Fs.cities.where('active', isEqualTo: true).snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  static Stream<List<Json>> membershipPlans() => Fs.membershipPlans.where('active', isEqualTo: true).snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()..sort((a, b) => ((a['price'] as num?) ?? 0).compareTo((b['price'] as num?) ?? 0)));

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Stream<List<Json>> mySubscriptions() => Fs.subscriptions.where('userId', isEqualTo: _uid).snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  static Stream<List<Json>> myReturns() => Fs.returns.where('userId', isEqualTo: _uid).snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  static Stream<List<Json>> myProductRequests() => Fs.productRequests.where('userId', isEqualTo: _uid).snapshots().map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());

  /// Live orders, newest first; falls back to an unordered query while the index builds.
  static Stream<List<ShopOrder>> myOrders() {
    final c = StreamController<List<ShopOrder>>();
    StreamSubscription? sub;
    void fallback() {
      sub = Fs.orders.where('userId', isEqualTo: _uid).snapshots().listen((s) {
        final l = s.docs.map(ShopOrder.fromDoc).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        c.add(l);
      }, onError: c.addError);
    }

    sub = ShopperRepo.instance.myOrders().listen(c.add, onError: (Object e) {
      sub?.cancel();
      isIndexError(e) ? fallback() : c.addError(e);
    });
    c.onCancel = () => sub?.cancel();
    return c.stream;
  }

  static Stream<List<WalletTxn>> walletTxns() {
    final c = StreamController<List<WalletTxn>>();
    StreamSubscription? sub;
    sub = ShopperRepo.instance.walletTxns().listen(c.add, onError: (Object e) {
      sub?.cancel();
      if (!isIndexError(e)) return c.addError(e);
      sub = Fs.walletTransactions.where('userId', isEqualTo: _uid).limit(100).snapshots().listen((s) {
        c.add(s.docs.map(WalletTxn.fromDoc).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000))));
      }, onError: c.addError);
    });
    c.onCancel = () => sub?.cancel();
    return c.stream;
  }

  static Stream<List<Blog>> blogs({int limit = 20}) {
    final c = StreamController<List<Blog>>();
    StreamSubscription? sub;
    sub = CatalogRepo.instance.blogs(limit: limit).listen(c.add, onError: (Object e) {
      sub?.cancel();
      if (!isIndexError(e)) return c.addError(e);
      sub = Fs.blogs.where('published', isEqualTo: true).limit(limit).snapshots().listen((s) {
        c.add(s.docs.map(Blog.fromDoc).toList()
          ..sort((a, b) => (b.publishedAt ?? DateTime(2000)).compareTo(a.publishedAt ?? DateTime(2000))));
      }, onError: c.addError);
    });
    c.onCancel = () => sub?.cancel();
    return c.stream;
  }

  static Future<Blog?> blogBySlug(String slug) async {
    final s = await Fs.blogs.where('slug', isEqualTo: slug).limit(1).get();
    if (s.docs.isNotEmpty) return Blog.fromDoc(s.docs.first);
    final d = await Fs.blogs.doc(slug).get();
    return d.exists ? Blog.fromDoc(d) : null;
  }

  /// Active popups for the web, inside their schedule window.
  static Stream<List<PromoBanner>> webPopups() => CatalogRepo.instance.popups().map((l) => l.where((p) {
        final on = '${p.data['showOn'] ?? 'both'}';
        final now = DateTime.now();
        DateTime? dt(Object? v) => v is Timestamp ? v.toDate() : null;
        final s = dt(p.data['startAt']), e = dt(p.data['endAt']);
        return (on == 'web' || on == 'both') && (s == null || s.isBefore(now)) && (e == null || e.isAfter(now));
      }).toList());

  /// Offers inside their schedule window for a position.
  static Stream<List<PromoBanner>> offers(String position, {String? moduleId}) => CatalogRepo.instance.offers(moduleId: moduleId).map((l) => l.where((p) {
        final now = DateTime.now();
        DateTime? dt(Object? v) => v is Timestamp ? v.toDate() : null;
        final s = dt(p.data['startAt']), e = dt(p.data['endAt']);
        return (p.position.isEmpty || p.position == position) && (s == null || s.isBefore(now)) && (e == null || e.isAfter(now));
      }).toList());
}

// ---------------------------------------------------------------- live stream cache

class _Live {
  Object? last;
  bool has = false;
  Object? error;
  late final Stream<dynamic> stream;
}

final _live = <String, _Live>{};

/// Returns a stable, replaying stream for [key] so widgets can call this inside build()
/// without resubscribing to Firestore on every rebuild. New listeners get the latest value at once.
Stream<T> live<T>(String key, Stream<T> Function() create) {
  final e = _live.putIfAbsent(key, () {
    final l = _Live();
    final hub = StreamController<T>.broadcast();
    create().listen((v) {
      l.last = v;
      l.has = true;
      l.error = null;
      hub.add(v);
    }, onError: (Object err) {
      l.error = err;
      hub.addError(err);
    });
    l.stream = Stream<T>.multi((m) {
      if (l.has) {
        m.add(l.last as T);
      } else if (l.error != null) {
        m.addError(l.error!);
      }
      final s = hub.stream.listen(m.add, onError: m.addError);
      m.onCancel = s.cancel;
    }, isBroadcast: true);
    return l;
  });
  return e.stream as Stream<T>;
}
