import 'package:cloud_firestore/cloud_firestore.dart';

// Firestore <-> Dart models. Field names follow docs/ARCHITECTURE.md exactly.
// Every model keeps the raw map in `data` so screens can reach fields not modelled here.

typedef Json = Map<String, dynamic>;

double _d(dynamic v, [double f = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? f;
int _i(dynamic v, [int f = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? f;
String _s(dynamic v, [String f = '']) => v == null ? f : '$v';
bool _b(dynamic v, [bool f = false]) => v is bool ? v : f;
List<String> _ls(dynamic v) => v is List ? v.map((e) => '$e').toList() : const [];
DateTime? _dt(dynamic v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      String s => DateTime.tryParse(s),
      _ => null,
    };
Json _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

abstract final class Roles {
  static const customer = 'customer';
  static const seller = 'seller';
  static const delivery = 'delivery';
  static const admin = 'admin';
}

class AppUser {
  AppUser(this.id, this.data);
  factory AppUser.fromDoc(DocumentSnapshot d) => AppUser(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get name => _s(data['name'], 'Guest');
  String get email => _s(data['email']);
  String get phone => _s(data['phone']);
  String get photoUrl => _s(data['photoUrl']);
  String get role => _s(data['role'], Roles.customer);
  String get status => _s(data['status'], 'active');
  double get walletBalance => _d(data['walletBalance']);
  String get referralCode => _s(data['referralCode']);
  List<String> get recentlyViewed => _ls(data['recentlyViewed']);
  Json get membership => _m(data['membership']);
  DateTime? get createdAt => _dt(data['createdAt']);
}

class Address {
  Address(this.id, this.data);
  factory Address.fromDoc(DocumentSnapshot d) => Address(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get label => _s(data['label'], 'Home');
  String get name => _s(data['name']);
  String get phone => _s(data['phone']);
  String get line1 => _s(data['line1']);
  String get line2 => _s(data['line2']);
  String get landmark => _s(data['landmark']);
  String get city => _s(data['city']);
  String get state => _s(data['state']);
  String get pincode => _s(data['pincode']);
  double? get lat => data['lat'] == null ? null : _d(data['lat']);
  double? get lng => data['lng'] == null ? null : _d(data['lng']);
  bool get isDefault => _b(data['isDefault']);
  String get oneLine => [line1, line2, landmark, city, state, pincode].where((e) => e.isNotEmpty).join(', ');
}

class Variant {
  Variant(this.data);
  final Json data;
  String get id => _s(data['id'], 'default');
  String get name => _s(data['name']);
  double get price => _d(data['price']);
  double get mrp => _d(data['mrp'], price);
  int get stock => _i(data['stock']);
  String get sku => _s(data['sku']);
}

class Product {
  Product(this.id, this.data);
  factory Product.fromDoc(DocumentSnapshot d) => Product(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get name => _s(data['name']);
  String get slug => _s(data['slug'], id);
  String get shortDescription => _s(data['shortDescription']);
  String get description => _s(data['description']);
  String get moduleId => _s(data['moduleId'], 'ecommerce');
  String get categoryId => _s(data['categoryId']);
  List<String> get categoryPath => _ls(data['categoryPath']);
  String get brandId => _s(data['brandId']);
  String get brandName => _s(data['brandName']);
  String get sellerId => _s(data['sellerId']);
  String get sellerName => _s(data['sellerName']);
  List<String> get images => _ls(data['images']);
  String get image => images.isEmpty ? '' : images.first;
  double get price => _d(data['price']);
  double get mrp => _d(data['mrp'], price);
  int get stock => _i(data['stock']);
  int get lowStockAt => _i(data['lowStockAt'], 5);
  String get unit => _s(data['unit']);
  List<Variant> get variants =>
      (data['variants'] is List ? data['variants'] as List : const []).map((e) => Variant(_m(e))).toList();
  List<String> get tags => _ls(data['tags']);
  bool? get isVeg => data['isVeg'] is bool ? data['isVeg'] as bool : null;
  Json get customFields => _m(data['customFields']);
  double get rating => _d(data['rating']);
  int get ratingCount => _i(data['ratingCount']);
  int get soldCount => _i(data['soldCount']);
  bool get featured => _b(data['featured']);
  String get status => _s(data['status'], 'active');
  String get barcode => _s(data['barcode']);
  int get deliveryMinutes => _i(data['deliveryMinutes'], 30);
  int get discountPct => mrp > price && mrp > 0 ? (((mrp - price) / mrp) * 100).round() : 0;
  bool get inStock => variants.isEmpty ? stock > 0 : variants.any((v) => v.stock > 0);
  DateTime? get createdAt => _dt(data['createdAt']);
}

class Category {
  Category(this.id, this.data);
  factory Category.fromDoc(DocumentSnapshot d) => Category(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get name => _s(data['name']);
  String get slug => _s(data['slug'], id);
  String get image => _s(data['image']);
  String get moduleId => _s(data['moduleId'], 'ecommerce');
  String? get parentId => data['parentId'] as String?;
  List<String> get path => _ls(data['path']);
  int get depth => _i(data['depth']);
  int get order => _i(data['order']);
  bool get active => _b(data['active'], true);
  int get productCount => _i(data['productCount']);
}

class MarketModule {
  MarketModule(this.id, this.data);
  factory MarketModule.fromDoc(DocumentSnapshot d) => MarketModule(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get name => _s(data['name']);
  String get tagline => _s(data['tagline']);
  String get icon => _s(data['icon']);
  String get themeColor => _s(data['themeColor'], '#0B8A4F');
  bool get enabled => _b(data['enabled'], true);
  int get order => _i(data['order']);
}

class Seller {
  Seller(this.id, this.data);
  factory Seller.fromDoc(DocumentSnapshot d) => Seller(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get storeName => _s(data['storeName']);
  String get slug => _s(data['slug'], id);
  String get logo => _s(data['logo']);
  String get banner => _s(data['banner']);
  String get description => _s(data['description']);
  String get ownerName => _s(data['ownerName']);
  String get email => _s(data['email']);
  String get phone => _s(data['phone']);
  String get status => _s(data['status'], 'pending');
  double get commissionPct => _d(data['commissionPct'], 10);
  String get city => _s(data['city']);
  String get address => _s(data['address']);
  double get rating => _d(data['rating']);
  double get balance => _d(data['balance']);
  double get totalSales => _d(data['totalSales']);
  int get productCount => _i(data['productCount']);
}

class DeliveryPartner {
  DeliveryPartner(this.id, this.data);
  factory DeliveryPartner.fromDoc(DocumentSnapshot d) => DeliveryPartner(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get name => _s(data['name']);
  String get email => _s(data['email']);
  String get phone => _s(data['phone']);
  String get photoUrl => _s(data['photoUrl']);
  String get vehicleType => _s(data['vehicleType'], 'bike');
  String get vehicleNo => _s(data['vehicleNo']);
  List<String> get cities => _ls(data['cities']);
  String get ownerType => _s(data['ownerType'], 'admin');
  String get sellerId => _s(data['sellerId']);
  String get status => _s(data['status'], 'pending');
  bool get online => _b(data['online']);
  double? get lat => data['lat'] == null ? null : _d(data['lat']);
  double? get lng => data['lng'] == null ? null : _d(data['lng']);
  DateTime? get locationUpdatedAt => _dt(data['locationUpdatedAt']);
  double get cashInHand => _d(data['cashInHand']);
  double get balance => _d(data['balance']);
  double get rating => _d(data['rating']);
  int get completedCount => _i(data['completedCount']);
}

class OrderItem {
  OrderItem(this.data);
  final Json data;
  String get productId => _s(data['productId']);
  String get variantId => _s(data['variantId'], 'default');
  String get name => _s(data['name']);
  String get variantName => _s(data['variantName']);
  String get image => _s(data['image']);
  double get price => _d(data['price']);
  double get mrp => _d(data['mrp'], price);
  int get qty => _i(data['qty'], 1);
  String get sellerId => _s(data['sellerId']);
  String get sellerName => _s(data['sellerName']);
  double get lineTotal => price * qty;
}

class TimelineEntry {
  TimelineEntry(this.data);
  final Json data;
  String get status => _s(data['status']);
  DateTime? get at => _dt(data['at']);
  String get by => _s(data['by']);
  String get note => _s(data['note']);
}

class ShopOrder {
  ShopOrder(this.id, this.data);
  factory ShopOrder.fromDoc(DocumentSnapshot d) => ShopOrder(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get orderNo => _s(data['orderNo'], id.substring(0, 6).toUpperCase());
  String get userId => _s(data['userId']);
  Json get customer => _m(data['customer']);
  String get customerName => _s(customer['name'], 'Customer');
  String get customerPhone => _s(customer['phone']);
  String get channel => _s(data['channel'], 'app');
  List<OrderItem> get items =>
      (data['items'] is List ? data['items'] as List : const []).map((e) => OrderItem(_m(e))).toList();
  List<String> get sellerIds => _ls(data['sellerIds']);
  double get subtotal => _d(data['subtotal']);
  double get deliveryFee => _d(data['deliveryFee']);
  double get discount => _d(data['discount']);
  String get couponCode => _s(data['couponCode']);
  double get walletUsed => _d(data['walletUsed']);
  double get tax => _d(data['tax']);
  double get total => _d(data['total']);
  double get payable => _d(data['payable'], total);
  String get paymentMethod => _s(data['paymentMethod'], 'cod');
  String get paymentStatus => _s(data['paymentStatus'], 'pending');
  String get status => _s(data['status'], 'placed');
  String get deliveryType => _s(data['deliveryType'], 'home');
  String get speed => _s(data['speed'], 'standard');
  Json get scheduledSlot => _m(data['scheduledSlot']);
  Json get address => _m(data['address']);
  double get distanceKm => _d(data['distanceKm']);
  DateTime? get etaAt => _dt(data['etaAt']);
  String get deliveryPartnerId => _s(data['deliveryPartnerId']);
  String get deliveryPartnerName => _s(data['deliveryPartnerName']);
  String get deliveryOtp => _s(data['deliveryOtp']);
  List<TimelineEntry> get timeline =>
      (data['timeline'] is List ? data['timeline'] as List : const []).map((e) => TimelineEntry(_m(e))).toList();
  String get cancelReason => _s(data['cancelReason']);
  DateTime? get createdAt => _dt(data['createdAt']);
  int get itemCount => items.fold(0, (a, b) => a + b.qty);
  bool get isActive => !OrderStatus.terminal.contains(status);
}

class Coupon {
  Coupon(this.id, this.data);
  factory Coupon.fromDoc(DocumentSnapshot d) => Coupon(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get code => id;
  String get message => _s(data['message']);
  String get discountType => _s(data['discountType'], 'percent');
  double get value => _d(data['value']);
  double get maxDiscount => _d(data['maxDiscount']);
  double get minOrder => _d(data['minOrder']);
  DateTime? get startAt => _dt(data['startAt']);
  DateTime? get endAt => _dt(data['endAt']);
  int get usageLimit => _i(data['usageLimit']);
  int get usedCount => _i(data['usedCount']);
  bool get active => _b(data['active'], true);
  String get label => discountType == 'percent' ? '${value.toStringAsFixed(0)}% OFF' : '₹${value.toStringAsFixed(0)} OFF';
}

/// Used for `sliders`, `offers` and `popups`.
class PromoBanner {
  PromoBanner(this.id, this.data);
  factory PromoBanner.fromDoc(DocumentSnapshot d) => PromoBanner(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get title => _s(data['title']);
  String get subtitle => _s(data['subtitle']);
  String get image => _s(data['image']);
  String get ctaText => _s(data['ctaText'], 'Shop now');
  String get link => _s(data['link']);
  String get moduleId => _s(data['moduleId']);
  String get position => _s(data['position']);
  String get bgColor => _s(data['bgColor']);
  int get order => _i(data['order']);
  bool get active => _b(data['active'], true);
}

class FeaturedSection {
  FeaturedSection(this.id, this.data);
  factory FeaturedSection.fromDoc(DocumentSnapshot d) => FeaturedSection(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get title => _s(data['title']);
  String get subtitle => _s(data['subtitle']);
  String get moduleId => _s(data['moduleId']);
  String get type => _s(data['type'], 'manual');
  List<String> get productIds => _ls(data['productIds']);
  String get categoryId => _s(data['categoryId']);
  String get style => _s(data['style'], 'carousel');
  String get bannerImage => _s(data['bannerImage']);
  String get bgColor => _s(data['bgColor']);
  int get order => _i(data['order']);
  bool get active => _b(data['active'], true);
}

class PlatformSettings {
  PlatformSettings(this.data);
  final Json data;
  String get appName => _s(data['appName'], 'Go4Market');
  String get tagline => _s(data['tagline'], 'Everything you need, delivered fast');
  String get currencySymbol => _s(data['currencySymbol'], '₹');
  String get contactEmail => _s(data['contactEmail']);
  String get contactPhone => _s(data['contactPhone']);
  String get address => _s(data['address']);
  Json get social => _m(data['social']);
  double get deliveryFee => _d(data['deliveryFee'], 30);
  double get freeDeliveryAbove => _d(data['freeDeliveryAbove'], 499);
  double get quickDeliveryFee => _d(data['quickDeliveryFee'], 25);
  double get minOrder => _d(data['minOrder']);
  double get taxPct => _d(data['taxPct']);
  bool get codEnabled => _b(data['codEnabled'], true);
  bool get walletEnabled => _b(data['walletEnabled'], true);
  bool get pickupEnabled => _b(data['pickupEnabled'], true);
  bool get scheduledEnabled => _b(data['scheduledEnabled'], true);
  bool get quick15Enabled => _b(data['quick15Enabled'], true);
  bool get quick30Enabled => _b(data['quick30Enabled'], true);
  double get referralReward => _d(data['referralReward'], 50);
  List<Json> get slots => (data['slots'] is List ? data['slots'] as List : const []).map(_m).toList();
  Json get seo => _m(data['seo']);
  Json get appVersions => _m(data['appVersions']);
  bool get maintenance => _b(data['maintenance']);
}

class PaymentSettings {
  PaymentSettings(this.data);
  final Json data;
  Json get razorpay => _m(data['razorpay']);
  Json get stripe => _m(data['stripe']);
  Json get paypal => _m(data['paypal']);
  bool get razorpayEnabled => _b(razorpay['enabled']);
  bool get stripeEnabled => _b(stripe['enabled']);
  bool get paypalEnabled => _b(paypal['enabled']);
  bool get codEnabled => _b(_m(data['cod'])['enabled'], true);
  String get razorpayKeyId => _s(razorpay['keyId']);
  String get stripePublishableKey => _s(stripe['publishableKey']);
}

class CartItem {
  CartItem(this.id, this.data);
  factory CartItem.fromDoc(DocumentSnapshot d) => CartItem(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get productId => _s(data['productId']);
  String get variantId => _s(data['variantId'], 'default');
  int get qty => _i(data['qty'], 1);
  String get sellerId => _s(data['sellerId']);
  DateTime? get addedAt => _dt(data['addedAt']);
}

class Review {
  Review(this.id, this.data);
  factory Review.fromDoc(DocumentSnapshot d) => Review(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get userName => _s(data['userName'], 'Customer');
  int get rating => _i(data['rating'], 5);
  String get comment => _s(data['comment']);
  DateTime? get createdAt => _dt(data['createdAt']);
}

class WalletTxn {
  WalletTxn(this.id, this.data);
  factory WalletTxn.fromDoc(DocumentSnapshot d) => WalletTxn(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get userId => _s(data['userId']);
  String get type => _s(data['type'], 'credit');
  double get amount => _d(data['amount']);
  String get reason => _s(data['reason']);
  String get refId => _s(data['refId']);
  double get balanceAfter => _d(data['balanceAfter']);
  bool get isCredit => type == 'credit';
  DateTime? get createdAt => _dt(data['createdAt']);
}

class Withdrawal {
  Withdrawal(this.id, this.data);
  factory Withdrawal.fromDoc(DocumentSnapshot d) => Withdrawal(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get userId => _s(data['userId']);
  String get role => _s(data['role']);
  double get amount => _d(data['amount']);
  String get method => _s(data['method']);
  String get status => _s(data['status'], 'pending');
  String get note => _s(data['note']);
  DateTime? get createdAt => _dt(data['createdAt']);
}

class Blog {
  Blog(this.id, this.data);
  factory Blog.fromDoc(DocumentSnapshot d) => Blog(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get title => _s(data['title']);
  String get slug => _s(data['slug'], id);
  String get excerpt => _s(data['excerpt']);
  String get content => _s(data['content']);
  String get cover => _s(data['cover']);
  List<String> get tags => _ls(data['tags']);
  bool get published => _b(data['published']);
  String get author => _s(data['author'], 'Go4Market');
  DateTime? get publishedAt => _dt(data['publishedAt']) ?? _dt(data['createdAt']);
}

class Faq {
  Faq(this.id, this.data);
  factory Faq.fromDoc(DocumentSnapshot d) => Faq(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get question => _s(data['question']);
  String get answer => _s(data['answer']);
  String get category => _s(data['category'], 'General');
  int get order => _i(data['order']);
}

class CmsPage {
  CmsPage(this.id, this.data);
  factory CmsPage.fromDoc(DocumentSnapshot d) => CmsPage(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get title => _s(data['title']);
  String get content => _s(data['content']);
}

class AppNotification {
  AppNotification(this.id, this.data);
  factory AppNotification.fromDoc(DocumentSnapshot d) => AppNotification(d.id, _m(d.data()));
  final String id;
  final Json data;
  String get title => _s(data['title']);
  String get body => _s(data['body']);
  String get type => _s(data['type']);
  Json get payload => _m(data['data']);
  bool get read => _b(data['read']);
  DateTime? get createdAt => _dt(data['createdAt']);
}

abstract final class OrderStatus {
  static const pending = 'pending';
  static const placed = 'placed';
  static const confirmed = 'confirmed';
  static const packed = 'packed';
  static const assigned = 'assigned';
  static const pickedUp = 'picked_up';
  static const outForDelivery = 'out_for_delivery';
  static const readyForPickup = 'ready_for_pickup';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';
  static const returned = 'returned';

  static const homeFlow = [placed, confirmed, packed, assigned, pickedUp, outForDelivery, delivered];
  static const pickupFlow = [placed, confirmed, packed, readyForPickup, delivered];
  static const terminal = {delivered, cancelled, returned};

  static String label(String s) => switch (s) {
        pending => 'Awaiting payment',
        placed => 'Order placed',
        confirmed => 'Confirmed',
        packed => 'Packed',
        assigned => 'Rider assigned',
        pickedUp => 'Picked up',
        outForDelivery => 'Out for delivery',
        readyForPickup => 'Ready for pickup',
        delivered => 'Delivered',
        cancelled => 'Cancelled',
        returned => 'Returned',
        _ => s,
      };
}
