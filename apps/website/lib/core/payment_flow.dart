import 'dart:convert';

import 'package:g4m_core/g4m_core.dart';

import '../l10n/l10n.dart';
import 'web_bridge.dart';

enum PayOutcome { paid, dismissed, redirected }

const _pendingKey = 'g4m_pending_payment';

/// Client half of the payment hand-off in docs/ARCHITECTURE.md, shared by orders and wallet top-ups.
/// [id] is the orderId (orders) or topupId (wallet top-ups).
Future<PayOutcome> runPayment(Json payment, {required String id, bool topup = false, Json prefill = const {}}) async {
  final provider = '${payment['provider'] ?? ''}';
  switch (provider) {
    case 'razorpay':
      final r = await openRazorpay(
        keyId: '${payment['keyId']}',
        razorpayOrderId: '${payment['razorpayOrderId']}',
        amountPaise: (payment['amount'] as num?) ?? 0,
        currency: '${payment['currency'] ?? 'INR'}',
        name: '${payment['name'] ?? 'Go4Market'}',
        description: topup ? L.current.cart.razorpayTopup : L.current.cart.razorpayOrder,
        prefill: payment['prefill'] is Map ? Map<String, dynamic>.from(payment['prefill'] as Map) : prefill,
      );
      if (r == null) return PayOutcome.dismissed;
      final body = {
        'orderId': id,
        if (topup) 'topupId': id,
        'provider': 'razorpay',
        'razorpayOrderId': r.orderId.isEmpty ? payment['razorpayOrderId'] : r.orderId,
        'razorpayPaymentId': r.paymentId,
        'razorpaySignature': r.signature,
      };
      topup ? await G4MApi.instance.confirmWalletTopup(body) : await G4MApi.instance.confirmPayment(body);
      return PayOutcome.paid;
    case 'stripe':
    case 'paypal':
      final url = '${payment['checkoutUrl'] ?? payment['approveUrl'] ?? payment['url'] ?? ''}';
      if (url.isEmpty) throw Exception(L.current.cart.noCheckoutLink);
      WebBridge.setSession(
          _pendingKey,
          jsonEncode({
            'kind': topup ? 'topup' : 'order',
            'id': id,
            'provider': provider,
            'sessionId': payment['sessionId'],
            'paypalOrderId': payment['paypalOrderId'],
          }));
      WebBridge.redirect(url);
      return PayOutcome.redirected;
    default:
      return PayOutcome.paid; // cod / wallet: nothing to do client-side
  }
}

/// Pending redirect payment saved before leaving for Stripe/PayPal.
Json? takePendingPayment() {
  final raw = WebBridge.session(_pendingKey);
  if (raw == null) return null;
  try {
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  } catch (_) {
    return null;
  }
}

void clearPendingPayment() => WebBridge.setSession(_pendingKey, null);
