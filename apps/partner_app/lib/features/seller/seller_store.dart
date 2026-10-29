import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:g4m_core/g4m_core.dart';

import 'seller_data.dart';

/// Live, shared seller state (one Firestore listener per collection for the whole shell
/// and any screens pushed from it).
class SellerStore {
  SellerStore._();
  static final instance = SellerStore._();

  final seller = ValueNotifier<Seller?>(null);
  final orders = ValueNotifier<List<ShopOrder>?>(null);
  final products = ValueNotifier<List<Product>?>(null);
  final ordersError = ValueNotifier<Object?>(null);
  final productsError = ValueNotifier<Object?>(null);

  /// Emits orders that just arrived in `placed` status (after the first snapshot).
  final newOrders = StreamController<ShopOrder>.broadcast();

  final _subs = <StreamSubscription<dynamic>>[];
  Set<String>? _known;
  int _users = 0;

  void start() {
    _users++;
    if (_subs.isNotEmpty) return;
    _subs.add(SellerData.me().listen((s) => seller.value = s, onError: (_) {}));
    _subs.add(SellerData.orders().listen((list) {
      ordersError.value = null;
      final ids = list.map((o) => o.id).toSet();
      if (_known != null) {
        for (final o in list) {
          if (!_known!.contains(o.id) && o.status == OrderStatus.placed) newOrders.add(o);
        }
      }
      _known = ids;
      orders.value = list;
    }, onError: (Object e) => ordersError.value = e));
    _subs.add(SellerData.products().listen((list) {
      productsError.value = null;
      products.value = list;
    }, onError: (Object e) => productsError.value = e));
  }

  void stop() {
    _users--;
    if (_users > 0) return;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _known = null;
    seller.value = null;
    orders.value = null;
    products.value = null;
  }

  Product? productById(String id) => products.value?.where((p) => p.id == id).firstOrNull;
}
