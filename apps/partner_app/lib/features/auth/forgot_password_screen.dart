import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});
  final String email;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.email);
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_email.text.contains('@')) {
      toast(context, context.tr('Enter a valid email', 'सही ईमेल दर्ज करें'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthRepo.instance.resetPassword(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) toast(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: AnimatedSwitcher(
          duration: G4MMotion.emphasized,
          child: _sent ? _sentView(context) : _form(context),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) => Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: context.rc.brandSoft, borderRadius: BorderRadius.circular(22)),
            child: Icon(Icons.lock_reset_rounded, size: 36, color: context.rc.brand),
          ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
          const SizedBox(height: 24),
          Text(context.tr('Reset your password', 'पासवर्ड रीसेट करें'), style: context.tt.headlineMedium),
          const SizedBox(height: 8),
          Text(
            context.tr('We will email you a secure link to set a new password.', 'हम नया पासवर्ड सेट करने के लिए आपको एक सुरक्षित लिंक ईमेल करेंगे।'),
            style: context.tt.bodyMedium?.copyWith(color: context.rc.muted),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: context.s.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                  : Text(context.tr('Send reset link', 'रीसेट लिंक भेजें')),
            ),
          ),
        ],
      );

  Widget _sentView(BuildContext context) => Center(
        key: const ValueKey('sent'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(color: context.rc.brandSoft, shape: BoxShape.circle),
            child: Icon(Icons.mark_email_read_rounded, size: 52, color: context.rc.brand),
          ).animate().scale(begin: const Offset(.4, .4), curve: Curves.elasticOut, duration: 900.ms),
          const SizedBox(height: 24),
          Text(context.tr('Check your inbox', 'अपना इनबॉक्स देखें'), style: context.tt.headlineSmall).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            '${context.tr('We sent a reset link to', 'हमने रीसेट लिंक भेजा है')} ${_email.text.trim()}',
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: context.rc.muted),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 28),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Back to login', 'लॉगिन पर वापस'))),
        ]),
      );
}
