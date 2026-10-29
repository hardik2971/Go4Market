// Browser-only helpers: SEO meta tags, storage, geolocation, sharing, redirects and the
// Razorpay checkout.js bridge. The website is web-only, so package:web is used directly.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../l10n/l10n.dart';

const kSiteUrl = 'https://go4market.web.app';
const kDefaultTitle = 'Go4Market: groceries, pharmacy, food and more, delivered fast';
const kDefaultDescription =
    'Shop groceries, medicines, food and everyday essentials from trusted local sellers on Go4Market. '
    '15 and 30 minute quick delivery, scheduled slots, wallet, COD and secure online payments.';

abstract final class WebBridge {
  /// Updates document.title, the meta description, canonical and OG tags for the current route.
  /// Defaults follow the active language [l] (title and description are translated per route by callers).
  static void setMeta({String? title, String? description, String? path, String? image, L? l}) {
    final c = (l ?? L.current).common;
    final t = (title == null || title.isEmpty) ? c.seoDefaultTitle : '$title | Go4Market';
    final d = _clip((description == null || description.trim().isEmpty) ? c.seoDefaultDescription : description.trim(), 158);
    web.document.title = t;
    _meta('name', 'description', d);
    _meta('property', 'og:title', t);
    _meta('property', 'og:description', d);
    _meta('name', 'twitter:title', t);
    _meta('name', 'twitter:description', d);
    if (image != null && image.startsWith('http')) {
      _meta('property', 'og:image', image);
      _meta('name', 'twitter:image', image);
    }
    final p = path ?? web.window.location.pathname;
    final url = '$kSiteUrl${p == '/' ? '/' : p}';
    _meta('property', 'og:url', url);
    final canonical = web.document.querySelector('link[rel="canonical"]');
    canonical?.setAttribute('href', url);
  }

  /// Adds/replaces (or removes with null) a JSON-LD block, e.g. Product schema on product pages.
  static void setJsonLd(String id, Map<String, Object?>? data) {
    final elId = 'ld-$id';
    web.document.getElementById(elId)?.remove();
    if (data == null) return;
    final s = web.HTMLScriptElement()
      ..id = elId
      ..type = 'application/ld+json'
      ..text = jsonEncode(data);
    web.document.head?.append(s);
  }

  static String _clip(String s, int n) {
    final flat = s.replaceAll(RegExp(r'[#*_>`\[\]]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= n ? flat : '${flat.substring(0, n - 1).trimRight()}…';
  }

  static void _meta(String attr, String key, String content) {
    var el = web.document.querySelector('meta[$attr="$key"]');
    if (el == null) {
      el = web.document.createElement('meta');
      el.setAttribute(attr, key);
      web.document.head?.append(el);
    }
    el.setAttribute('content', content);
  }

  /// Removes the static pre-render fallback once Flutter has painted (index.html also does this).
  static void hideFallback() {
    web.document.getElementById('seo-fallback')?.setAttribute('hidden', '');
    web.document.getElementById('splash')?.remove();
  }

  // ---------- storage ----------
  static String? session(String k) {
    try {
      return web.window.sessionStorage.getItem(k);
    } catch (_) {
      return null;
    }
  }

  static void setSession(String k, String? v) {
    try {
      v == null ? web.window.sessionStorage.removeItem(k) : web.window.sessionStorage.setItem(k, v);
    } catch (_) {}
  }

  static String? local(String k) {
    try {
      return web.window.localStorage.getItem(k);
    } catch (_) {
      return null;
    }
  }

  static void setLocal(String k, String? v) {
    try {
      v == null ? web.window.localStorage.removeItem(k) : web.window.localStorage.setItem(k, v);
    } catch (_) {}
  }

  // ---------- navigation ----------
  static void redirect(String url) => web.window.location.assign(url);
  static void openTab(String url) => web.window.open(url, '_blank', 'noopener');
  static String get origin => web.window.location.origin;
  static void print() => web.window.print();

  // ---------- sharing ----------
  static Future<bool> share({required String title, required String text, required String url}) async {
    final nav = web.window.navigator;
    if (!nav.has('share')) return false;
    try {
      await nav.share(web.ShareData(title: title, text: text, url: url)).toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- geolocation ----------
  static Future<({double lat, double lng})?> locate() {
    final c = Completer<({double lat, double lng})?>();
    try {
      web.window.navigator.geolocation.getCurrentPosition(
        ((web.GeolocationPosition p) {
          if (!c.isCompleted) c.complete((lat: p.coords.latitude.toDouble(), lng: p.coords.longitude.toDouble()));
        }).toJS,
        ((web.GeolocationPositionError e) {
          if (!c.isCompleted) c.complete(null);
        }).toJS,
        web.PositionOptions(enableHighAccuracy: true, timeout: 12000),
      );
    } catch (_) {
      if (!c.isCompleted) c.complete(null);
    }
    return c.future.timeout(const Duration(seconds: 15), onTimeout: () => null);
  }

  // ---------- scripts ----------
  static final _loaded = <String, Future<void>>{};
  static Future<void> loadScript(String src) => _loaded.putIfAbsent(src, () {
        final c = Completer<void>();
        final s = web.HTMLScriptElement()
          ..src = src
          ..async = true;
        s.onload = ((web.Event _) => c.complete()).toJS;
        s.onerror = ((web.Event _) {
          _loaded.remove(src);
          c.completeError(Exception('Could not load $src'));
        }).toJS;
        web.document.head!.append(s);
        return c.future;
      });
}

// ---------- Razorpay checkout.js ----------
@JS('Razorpay')
extension type _RazorpayJS._(JSObject _) implements JSObject {
  external factory _RazorpayJS(JSObject options);
  external void open();
  external void on(String event, JSFunction cb);
}

class RazorpayResult {
  RazorpayResult(this.paymentId, this.orderId, this.signature);
  final String paymentId, orderId, signature;
}

/// Opens Razorpay Checkout. Completes with the payment result, or null if the shopper dismissed it.
Future<RazorpayResult?> openRazorpay({
  required String keyId,
  required String razorpayOrderId,
  required num amountPaise,
  String currency = 'INR',
  String name = 'Go4Market',
  String description = 'Order payment',
  Map<String, dynamic> prefill = const {},
}) async {
  await WebBridge.loadScript('https://checkout.razorpay.com/v1/checkout.js');
  final c = Completer<RazorpayResult?>();
  final options = <String, Object?>{
    'key': keyId,
    'order_id': razorpayOrderId,
    'amount': amountPaise,
    'currency': currency,
    'name': name,
    'description': description,
    'image': '${WebBridge.origin}/icons/Icon-192.png',
    'prefill': prefill.map((k, v) => MapEntry(k, '$v')),
    'theme': {'color': '#0B8A4F'},
  }.jsify() as JSObject;
  options['handler'] = ((JSObject r) {
    String f(String k) => (r[k] as JSString?)?.toDart ?? '';
    if (!c.isCompleted) c.complete(RazorpayResult(f('razorpay_payment_id'), f('razorpay_order_id'), f('razorpay_signature')));
  }).toJS;
  options['modal'] = <String, Object?>{}.jsify() as JSObject
    ..['ondismiss'] = (() {
      if (!c.isCompleted) c.complete(null);
    }).toJS;
  final rz = _RazorpayJS(options);
  rz.on('payment.failed', ((JSObject _) {
    if (!c.isCompleted) c.completeError(Exception(L.current.common.paymentFailed));
  }).toJS);
  rz.open();
  return c.future;
}
