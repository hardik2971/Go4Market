import 'dart:async';

import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data.dart';

class PayResult {
  const PayResult(this.ok, {this.cancelled = false, this.message = ''});
  final bool ok;
  final bool cancelled;
  final String message;
}

/// Client side of the payment hand-off in docs/ARCHITECTURE.md (same for orders and wallet top-ups).
///
/// * razorpay  -> native checkout sheet, then confirmPayment with the signature.
/// * stripe / paypal -> hosted page in an in-app browser; when the app resumes (or the user taps
///   "I've paid") we call confirmPayment. For orders we also watch the order doc so a webhook
///   that marks it paid finishes the flow on its own.
class PaymentFlow {
  PaymentFlow._();

  /// Pulls the payment payload out of a placeOrder/walletTopup response, accepting either
  /// `{payment: {...}}` or a flat response that carries the provider fields.
  static Json? payloadOf(Json res, String method) {
    final p = res['payment'];
    if (p is Map) return {'provider': method, ...Map<String, dynamic>.from(p)};
    const keys = ['razorpayOrderId', 'checkoutUrl', 'approveUrl', 'paypalOrderId', 'sessionId', 'url'];
    if (keys.any(res.containsKey)) return {'provider': method, ...res};
    return null;
  }

  static Future<PayResult> run(
    BuildContext context, {
    required String refId,
    required Json payment,
    bool topup = false,
    double amount = 0,
    Json prefill = const {},
  }) async {
    final provider = '${payment['provider'] ?? ''}';
    switch (provider) {
      case 'razorpay':
        return _razorpay(refId, payment, topup, amount, prefill);
      case 'stripe':
      case 'paypal':
        return _hosted(context, refId, provider, payment, topup);
      default:
        return const PayResult(true);
    }
  }

  static Future<Json> _confirm(bool topup, Json body) =>
      topup ? G4MApi.instance.confirmWalletTopup({...body, 'topupId': body['orderId']}) : G4MApi.instance.confirmPayment(body);

  static bool _confirmedOk(Json r) =>
      r['ok'] == true || r['status'] == 'paid' || r['paymentStatus'] == 'paid' || r.containsKey('balance') || r['success'] == true;

  static Future<PayResult> _razorpay(String refId, Json p, bool topup, double amount, Json prefill) async {
    final rz = Razorpay();
    final done = Completer<PayResult>();
    rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) async {
      try {
        final res = await _confirm(topup, {
          'orderId': refId,
          'provider': 'razorpay',
          'razorpayOrderId': r.orderId ?? p['razorpayOrderId'],
          'razorpayPaymentId': r.paymentId,
          'razorpaySignature': r.signature,
        });
        if (!done.isCompleted) done.complete(PayResult(_confirmedOk(res), message: _confirmedOk(res) ? '' : 'Payment is being verified'));
      } catch (e) {
        if (!done.isCompleted) done.complete(PayResult(false, message: friendlyError(e)));
      }
    });
    rz.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!done.isCompleted) {
        done.complete(PayResult(false, cancelled: r.code == Razorpay.PAYMENT_CANCELLED, message: r.message ?? 'Payment failed'));
      }
    });
    rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
    final pre = Map<String, dynamic>.from((p['prefill'] as Map?) ?? prefill);
    try {
      rz.open({
        'key': '${p['keyId'] ?? p['key'] ?? AppConfig.payments.value.razorpayKeyId}',
        'order_id': p['razorpayOrderId'] ?? p['orderId'],
        'amount': p['amount'] ?? (amount * 100).round(),
        'currency': p['currency'] ?? 'INR',
        'name': p['name'] ?? 'Go4Market',
        'description': topup ? 'Wallet top-up' : 'Order payment',
        'prefill': {
          'name': pre['name'] ?? '',
          'email': pre['email'] ?? '',
          'contact': pre['phone'] ?? pre['contact'] ?? '',
        },
        'theme': {'color': '#0B8A4F'},
        'retry': {'enabled': true, 'max_count': 2},
      }..removeWhere((k, v) => v == null));
    } catch (e) {
      if (!done.isCompleted) done.complete(PayResult(false, message: friendlyError(e)));
    }
    final res = await done.future;
    rz.clear();
    return res;
  }

  static Future<PayResult> _hosted(BuildContext context, String refId, String provider, Json p, bool topup) async {
    final url = '${p['checkoutUrl'] ?? p['approveUrl'] ?? p['url'] ?? ''}';
    if (url.isEmpty) return const PayResult(false, message: 'Payment link missing. Try another method.');
    final body = <String, dynamic>{
      'orderId': refId,
      'provider': provider,
      if (provider == 'stripe') 'sessionId': p['sessionId'],
      if (provider == 'stripe' && p['paymentIntentId'] != null) 'paymentIntentId': p['paymentIntentId'],
      if (provider == 'paypal') 'paypalOrderId': p['paypalOrderId'],
    };
    final uri = Uri.parse(url);
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened) return const PayResult(false, message: 'Could not open the payment page');
    if (!context.mounted) return const PayResult(false, message: 'Payment interrupted');
    final r = await showModalBottomSheet<PayResult>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (_) => _HostedWait(
        provider: provider,
        url: uri,
        check: () async => _confirmedOk(await _confirm(topup, body)),
        orderId: topup ? null : refId,
      ),
    );
    return r ?? const PayResult(false, cancelled: true, message: 'Payment cancelled');
  }
}

class _HostedWait extends StatefulWidget {
  const _HostedWait({required this.provider, required this.url, required this.check, this.orderId});
  final String provider;
  final Uri url;
  final Future<bool> Function() check;
  final String? orderId;
  @override
  State<_HostedWait> createState() => _HostedWaitState();
}

class _HostedWaitState extends State<_HostedWait> {
  late final AppLifecycleListener _life;
  StreamSubscription? _orderSub;
  bool _checking = false;
  String _msg = 'Complete the payment in the browser. We will confirm it as soon as you return.';

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: _verify);
    if (widget.orderId != null) {
      _orderSub = ShopperRepo.instance.order(widget.orderId!).listen((o) {
        if (o != null && (o.paymentStatus == 'paid' || (o.status != OrderStatus.pending && o.paymentStatus != 'failed'))) {
          _finish(const PayResult(true));
        }
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _orderSub?.cancel();
    super.dispose();
  }

  void _finish(PayResult r) {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop(r);
  }

  Future<void> _verify() async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    try {
      final ok = await widget.check();
      if (ok) return _finish(const PayResult(true));
      if (mounted) setState(() => _msg = 'We could not confirm the payment yet. If you paid, tap "Check again" in a moment.');
    } catch (e) {
      if (mounted) setState(() => _msg = isMissingFunction(e) ? 'Payment confirmation service is unavailable.' : friendlyError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = widget.provider == 'paypal' ? 'PayPal' : 'Stripe';
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 56,
              height: 56,
              child: _checking
                  ? const CircularProgressIndicator(strokeWidth: 3)
                  : const Icon(Icons.lock_clock_rounded, size: 48, color: G4MColors.primary),
            ),
            const SizedBox(height: 16),
            Text('Paying with $name', style: t.titleLarge),
            const SizedBox(height: 8),
            Text(_msg, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _checking ? null : _verify,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text("I've paid · Check again"),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => launchUrl(widget.url, mode: LaunchMode.inAppBrowserView),
                  child: const Text('Reopen payment page'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _finish(const PayResult(false, cancelled: true, message: 'Payment not completed')),
                  style: TextButton.styleFrom(foregroundColor: G4MColors.danger),
                  child: const Text('Cancel'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
