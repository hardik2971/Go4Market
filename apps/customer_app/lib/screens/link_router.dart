import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/nav.dart';
import '../core/prefs.dart';
import '../widgets/product_card.dart';
import 'orders/order_detail_screen.dart';
import 'product/product_list_screen.dart';
import 'product/seller_screen.dart';
import 'search/search_screen.dart';
import 'shell/main_shell.dart';

/// Opens admin-configured links from sliders/offers/popups/notifications.
///
/// Accepted shapes (defensive, the panels may write any of them):
///   https://...                          -> in-app browser (or internal path on go4market.web.app)
///   /product/{id|slug}  /p/{id}          -> product detail
///   /category/{id}  /c/{id}              -> product list for category
///   /search?q=milk                       -> search
///   /module/{id}  module:{id}            -> switch module on home
///   /seller/{id}  /store/{id}            -> seller store
///   /orders/{id}  /order/{id}            -> order detail
///   /offers /coupons /wallet /cart       -> tabs/screens
Future<void> openLink(BuildContext context, String link) async {
  var l = link.trim();
  if (l.isEmpty) return;
  if (l.startsWith('module:')) {
    AppPrefs.instance.setModule(l.substring(7));
    shellTab.value = 0;
    return;
  }
  Uri? uri = Uri.tryParse(l);
  if (uri == null) return;
  if (uri.hasScheme && uri.host.isNotEmpty) {
    if (uri.host.startsWith('go4market.web.app')) {
      l = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
      uri = Uri.parse(l);
    } else {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      return;
    }
  }
  final seg = uri.pathSegments.where((e) => e.isNotEmpty).toList();
  if (seg.isEmpty) return;
  final head = seg.first.toLowerCase();
  final arg = seg.length > 1 ? seg[1] : '';
  switch (head) {
    case 'product' || 'p' || 'products' when arg.isNotEmpty:
      final p = await CatalogRepo.instance.productBySlug(arg);
      if (p != null && context.mounted) openProduct(context, p, scope: 'link');
    case 'category' || 'c' || 'categories' when arg.isNotEmpty:
      final d = await Fs.categories.doc(arg).get();
      final name = d.exists ? Category.fromDoc(d).name : 'Products';
      if (context.mounted) context.push(ProductListScreen(title: name, categoryId: arg));
    case 'search':
      if (context.mounted) context.push(SearchScreen(initial: uri.queryParameters['q'] ?? arg));
    case 'module' when arg.isNotEmpty:
      AppPrefs.instance.setModule(arg);
      shellTab.value = 0;
    case 'seller' || 'store' || 'sellers' when arg.isNotEmpty:
      if (context.mounted) context.push(SellerScreen(sellerId: arg));
    case 'order' || 'orders' when arg.isNotEmpty:
      if (context.mounted) context.push(OrderDetailScreen(orderId: arg));
    case 'cart' || 'checkout':
      shellTab.value = 2;
    case 'orders':
      shellTab.value = 3;
    case 'offers' || 'deals':
      if (context.mounted) context.push(const ProductListScreen(title: 'Top deals', initialSort: 'discount'));
    default:
      break;
  }
}

/// Notification payload (FCM data or inbox `data{}`) -> screen.
void openNotificationData(BuildContext context, Map<String, dynamic> d) {
  final orderId = '${d['orderId'] ?? d['order_id'] ?? (d['type'] == 'order' ? d['refId'] ?? '' : '')}';
  if (orderId.isNotEmpty && orderId != 'null') {
    context.push(OrderDetailScreen(orderId: orderId));
    return;
  }
  final link = '${d['link'] ?? d['url'] ?? ''}';
  if (link.isNotEmpty && link != 'null') openLink(context, link);
}
