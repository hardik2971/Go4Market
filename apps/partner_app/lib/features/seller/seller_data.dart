import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/live.dart';

/// Seller-side Firestore queries. All list queries degrade gracefully
/// (indexed attempt first, then a no-orderBy fallback sorted client-side).
abstract final class SellerData {
  static Stream<Seller?> me() =>
      Fs.sellers.doc(myUid).snapshots().map((d) => d.exists ? Seller.fromDoc(d) : null);

  static Stream<double> balance() => me().map((s) => s?.balance ?? 0);

  static Stream<List<ShopOrder>> orders({int limit = 200}) => resilientQuery<ShopOrder>(
        [
          () => Fs.orders.where('sellerIds', arrayContains: myUid).orderBy('createdAt', descending: true).limit(limit),
          () => Fs.orders.where('sellerIds', arrayContains: myUid).limit(limit),
        ],
        ShopOrder.fromDoc,
        sort: (a, b) => newestFirst(a.createdAt, b.createdAt),
      );

  static Stream<ShopOrder?> order(String id) =>
      Fs.orders.doc(id).snapshots().map((d) => d.exists ? ShopOrder.fromDoc(d) : null);

  static Stream<List<Product>> products() => resilientQuery<Product>(
        [() => Fs.products.where('sellerId', isEqualTo: myUid).limit(500)],
        Product.fromDoc,
        sort: (a, b) => newestFirst(a.createdAt, b.createdAt),
      );

  static Stream<List<DeliveryPartner>> riders() => resilientQuery<DeliveryPartner>(
        [
          () => Fs.deliveryPartners.where('sellerId', isEqualTo: myUid).limit(100),
          () => Fs.deliveryPartners.where('sellerId', isEqualTo: myUid).where('status', isEqualTo: 'approved').limit(100),
        ],
        DeliveryPartner.fromDoc,
        sort: (a, b) => (b.online ? 1 : 0).compareTo(a.online ? 1 : 0),
      );

  static Stream<List<Coupon>> coupons() => resilientQuery<Coupon>(
        [
          () => Fs.coupons.where('sellerId', isEqualTo: myUid),
          () => Fs.coupons.where('sellerId', isEqualTo: myUid).where('active', isEqualTo: true),
        ],
        Coupon.fromDoc,
        sort: (a, b) => newestFirst(_created(a.data), _created(b.data)),
      );

  static DateTime? _created(Json d) {
    final v = d['createdAt'];
    return v is Timestamp ? v.toDate() : null;
  }

  /// Items in an order that belong to this seller.
  static List<OrderItem> myItems(ShopOrder o) {
    final mine = o.items.where((i) => i.sellerId == myUid).toList();
    // Single-seller orders or items missing sellerId: treat all as ours.
    return mine.isEmpty && (o.sellerIds.length <= 1) ? o.items : mine;
  }

  static double myRevenue(ShopOrder o) => myItems(o).fold<double>(0, (a, i) => a + i.lineTotal);

  static bool isLowStock(Product p) {
    if (p.variants.isNotEmpty) return p.variants.any((v) => v.stock <= p.lowStockAt);
    return p.stock <= p.lowStockAt;
  }

  static int totalStock(Product p) =>
      p.variants.isEmpty ? p.stock : p.variants.fold<int>(0, (a, v) => a + v.stock);
}

/// Order-status groups used by tabs and dashboard chips.
abstract final class SellerTabs {
  static const inTransit = {
    OrderStatus.assigned,
    OrderStatus.pickedUp,
    OrderStatus.outForDelivery,
    OrderStatus.readyForPickup,
  };
  static const closed = {OrderStatus.cancelled, OrderStatus.returned};

  static bool isNew(ShopOrder o) =>
      o.status == OrderStatus.placed &&
      o.createdAt != null &&
      DateTime.now().difference(o.createdAt!) < const Duration(minutes: 30);
}
