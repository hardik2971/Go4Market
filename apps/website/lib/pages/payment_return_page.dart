import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/payment_flow.dart';
import '../core/push.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/shell.dart';

/// Landing page for Stripe / PayPal redirects: `/payment/return?provider=stripe&orderId=…`.
class PaymentReturnPage extends StatefulWidget {
  const PaymentReturnPage({super.key, required this.params});
  final Map<String, String> params;
  @override
  State<PaymentReturnPage> createState() => _PaymentReturnPageState();
}

class _PaymentReturnPageState extends State<PaymentReturnPage> {
  String _state = 'working'; // working | ok | cancelled | error
  String _message = '';
  String? _id;
  bool _topup = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final p = widget.params;
    final pending = takePendingPayment() ?? const {};
    final provider = p['provider'] ?? '${pending['provider'] ?? ''}';
    _topup = p['kind'] == 'topup' || p['type'] == 'topup' || p.containsKey('topupId') || pending['kind'] == 'topup';
    _id = p['orderId'] ?? p['topupId'] ?? pending['id'] as String?;
    if (_id == null || provider.isEmpty) {
      setState(() {
        _state = 'error';
        _message = L.current.cart.noPaymentDetails;
      });
      return;
    }
    if (p['cancelled'] == '1' || p['canceled'] == 'true' || p['status'] == 'cancel' || p['cancel'] == '1') {
      clearPendingPayment();
      setState(() => _state = 'cancelled');
      return;
    }
    try {
      // Wait for Firebase to restore the shopper's session after the redirect.
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null).timeout(const Duration(seconds: 12));
      }
      final body = <String, dynamic>{
        'orderId': _id,
        if (_topup) 'topupId': _id,
        'provider': provider,
        if (provider == 'stripe') 'sessionId': p['session_id'] ?? p['sessionId'] ?? pending['sessionId'],
        if (provider == 'paypal') 'paypalOrderId': p['token'] ?? p['paypalOrderId'] ?? pending['paypalOrderId'],
      };
      final r = _topup ? await G4MApi.instance.confirmWalletTopup(body) : await G4MApi.instance.confirmPayment(body);
      clearPendingPayment();
      final ok = r['ok'] != false && r['status'] != 'failed';
      setState(() {
        _state = ok ? 'ok' : 'error';
        _message = ok ? '' : L.current.cart.providerStatus('${r['status']}');
      });
      if (ok && !_topup) unawaited(Push.instance.offer());
    } on TimeoutException {
      setState(() {
        _state = 'error';
        _message = L.current.cart.signInAgainToConfirm;
      });
    } catch (e) {
      setState(() {
        _state = 'error';
        _message = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l.cart;
    final target = _topup ? '/wallet' : (_id == null ? '/orders' : '/orders/$_id');
    final (icon, color, title, msg) = switch (_state) {
      'ok' => (Icons.check_circle_rounded, G4MColors.success, _topup ? t.walletToppedUp : t.paymentSuccessful, _topup ? t.balanceReady : t.orderConfirmed),
      'cancelled' => (Icons.info_outline_rounded, G4MColors.warning, t.paymentCancelled, t.noMoneyTaken),
      'error' => (Icons.error_outline_rounded, G4MColors.danger, t.couldNotConfirm, _message.isEmpty ? t.autoReconciled : _message),
      _ => (Icons.hourglass_top_rounded, G4MColors.primary, t.confirmingPayment, t.keepPageOpen),
    };
    return SeoMeta(
      title: t.paymentSeoTitle,
      child: PageScroll(children: [
        Contained(
          vertical: 64,
          maxWidth: 560,
          child: Panel(
            padding: const EdgeInsets.all(36),
            child: Column(children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(_state),
                tween: Tween(begin: context.reduceMotion ? 1 : .4, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, s, c) => Transform.scale(scale: s, child: c),
                child: _state == 'working'
                    ? const SizedBox(width: 72, height: 72, child: CircularProgressIndicator(strokeWidth: 5))
                    : Icon(icon, size: 84, color: color),
              ),
              const SizedBox(height: 18),
              Heading(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 16, height: 1.5)),
              if (_state != 'working') ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.go(target), child: Text(_topup ? t.goToWallet : t.viewOrder)),
                const SizedBox(height: 8),
                TextButton(onPressed: () => context.go('/'), child: Text(t.continueShopping)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
