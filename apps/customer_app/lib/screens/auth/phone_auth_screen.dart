import 'dart:async';

import 'package:animations/animations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/nav.dart';
import '../../core/social_auth.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/otp_input.dart';
import 'auth_screens.dart';

/// Phone OTP sign-in (FEATURES #47). Pops with a [SocialSignIn] once signed in.
///
/// Android: Firebase verifies the app with Play Integrity and falls back to a reCAPTCHA page in
/// a Custom Tab when needed; SMS codes are retrieved automatically when possible.
class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  static const _resendAfter = 30;

  final _form = GlobalKey<FormState>();
  final _dial = TextEditingController(text: '+91');
  final _number = TextEditingController();
  final _otp = TextEditingController();

  int _step = 0; // 0 = number, 1 = code
  bool _sending = false, _verifying = false, _otpError = false, _done = false, _autoFilled = false;
  String? _error;
  String _e164 = '';
  String? _verificationId;
  int? _resendToken;
  int _left = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _dial.dispose();
    _number.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _left = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left = (_left - 1).clamp(0, _resendAfter));
      if (_left == 0) t.cancel();
    });
  }

  Future<void> _send({bool resend = false}) async {
    if (!resend && !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final e164 = resend ? _e164 : Validators.toE164(_dial.text.trim(), _number.text);
    setState(() {
      _sending = true;
      _error = null;
      _otpError = false;
      _e164 = e164;
    });
    try {
      await SocialAuth.sendCode(
        phoneE164: e164,
        resendToken: resend ? _resendToken : null,
        onCodeSent: (id, token) {
          if (!mounted) return;
          setState(() {
            _verificationId = id;
            _resendToken = token;
            _sending = false;
            _step = 1;
            if (resend) _otp.clear();
          });
          _startCountdown();
          context.toast(resend ? 'A new code is on its way' : 'Code sent to ${Validators.prettyPhone(e164)}');
        },
        onAutoVerified: (cred) {
          if (!mounted || _done) return;
          // Android auto-retrieval / instant verification: fill the boxes for feedback, then sign in.
          final code = cred.smsCode;
          if (code != null && code.isNotEmpty) {
            _autoFilled = true;
            _otp.text = code;
          }
          _signIn(() => SocialAuth.signInWithPhone(cred));
        },
        onFailed: (e) {
          if (!mounted) return;
          setState(() {
            _sending = false;
            _error = phoneAuthError(e);
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = phoneAuthError(e);
      });
    }
  }

  Future<void> _verify([String? code]) async {
    final c = code ?? _otp.text;
    if (_autoFilled || _verificationId == null || c.length != 6) return;
    await _signIn(() => SocialAuth.verifyCode(_verificationId!, c));
  }

  Future<void> _signIn(Future<SocialSignIn> Function() run) async {
    if (_done || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
      _otpError = false;
    });
    try {
      final r = await run();
      _done = true;
      _timer?.cancel();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(r);
    } catch (e) {
      if (!mounted) return;
      _autoFilled = false;
      final wrongCode = e is FirebaseAuthException && e.code == 'invalid-verification-code';
      setState(() {
        _otpError = true;
        _error = phoneAuthError(e);
      });
      if (wrongCode) {
        Future.delayed(const Duration(milliseconds: 650), () {
          if (mounted) _otp.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _editNumber() {
    _timer?.cancel();
    setState(() {
      _step = 0;
      _error = null;
      _otpError = false;
      _otp.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _editNumber();
      },
      child: AuthScaffold(
        title: _step == 0 ? 'Continue with phone' : 'Verify your number',
        subtitle: _step == 0 ? 'We\'ll text you a 6-digit code. No password needed.' : 'Enter the code sent to ${Validators.prettyPhone(_e164)}',
        children: [
          PageTransitionSwitcher(
            duration: G4MMotion.emphasized,
            reverse: _step == 0,
            transitionBuilder: (child, a, s) => SharedAxisTransition(
              animation: a,
              secondaryAnimation: s,
              transitionType: SharedAxisTransitionType.horizontal,
              fillColor: Colors.transparent,
              child: child,
            ),
            child: _step == 0 ? _numberStep(context) : _codeStep(context),
          ),
          AnimatedSize(
            duration: G4MMotion.standard,
            curve: G4MMotion.curve,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      key: ValueKey(_error),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: G4MColors.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.error_outline_rounded, color: G4MColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!, style: const TextStyle(color: G4MColors.danger, fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _numberStep(BuildContext context) => Form(
        key: _form,
        child: Column(key: const ValueKey('number'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 86,
              child: TextFormField(
                controller: _dial,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+\d]')), LengthLimitingTextInputFormatter(5)],
                decoration: const InputDecoration(labelText: 'Code'),
                validator: Validators.dialCode,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _number,
                autofocus: true,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(15)],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _send(),
                decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                validator: (v) => Validators.phone(v, dial: _dial.text.trim(), required: true),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sending ? null : _send,
            child: AnimatedSwitcher(
              duration: G4MMotion.standard,
              child: _sending ? const AuthSpinner(key: ValueKey('s')) : const Text('Send code', key: ValueKey('t')),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: context.muted),
            const SizedBox(width: 6),
            Flexible(child: Text('Standard SMS rates may apply.', style: context.text.bodySmall)),
          ]),
        ]),
      );

  Widget _codeStep(BuildContext context) => Column(key: const ValueKey('code'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OtpInput(
          controller: _otp,
          hasError: _otpError,
          enabled: !_verifying,
          onChanged: (t) => setState(() {
            // Typing again clears the error; the automatic clear after a wrong code keeps it visible.
            if (t.isNotEmpty) {
              _otpError = false;
              _error = null;
            }
          }),
          onCompleted: _verify,
        ),
        const SizedBox(height: 10),
        Row(children: [
          TextButton.icon(
            onPressed: _verifying ? null : _editNumber,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Change number'),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: G4MMotion.standard,
            child: _left > 0
                ? Text('Resend in 0:${_left.toString().padLeft(2, '0')}',
                    key: const ValueKey('wait'), style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700))
                : TextButton(
                    key: const ValueKey('resend'),
                    onPressed: _sending || _verifying ? null : () => _send(resend: true),
                    child: Text(_sending ? 'Sending…' : 'Resend code'),
                  ),
          ),
        ]),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _verifying || _otp.text.length != 6 ? null : _verify,
          child: AnimatedSwitcher(
            duration: G4MMotion.standard,
            child: _verifying ? const AuthSpinner(key: ValueKey('v')) : const Text('Verify & continue', key: ValueKey('t')),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.sms_outlined, size: 14, color: context.muted),
          const SizedBox(width: 6),
          Flexible(child: Text('We\'ll fill the code in automatically if we can.', style: context.text.bodySmall)),
        ]),
      ]);
}
