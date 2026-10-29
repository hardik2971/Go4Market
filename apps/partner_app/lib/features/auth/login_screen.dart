import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/session.dart';
import '../../core/social_auth.dart';
import '../../core/ui.dart';
import '../splash/doodle_painter.dart';
import 'auth_routing.dart';
import 'forgot_password_screen.dart';
import 'otp_input.dart';
import 'signup_screen.dart';

enum _Method { email, phone }

enum _Provider { phone, google }

/// Login with a Seller / Delivery role toggle and three methods: email/password,
/// phone OTP and Google. The toggle tints the app; the actual role always comes
/// from the `role` claim (resolved by RootGate, decided by [decidePostLogin]).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _resendSeconds = 30;

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;
  _Method _method = _Method.email;

  // Phone OTP state.
  final _cc = TextEditingController(text: '+91');
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  String? _verificationId;
  int? _resendToken;
  String? _sentTo;
  int _resendIn = 0;
  Timer? _ticker;
  bool _autoDetected = false;
  bool _finishing = false;

  PartnerRole get _role => AppState.instance.roleTint;
  bool get _codeStep => _verificationId != null;

  @override
  void dispose() {
    _ticker?.cancel();
    _email.dispose();
    _pass.dispose();
    _cc.dispose();
    _phone.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Email
  // ---------------------------------------------------------------------------

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthRepo.instance.signIn(_email.text, _pass.text);
      final claim = await AuthRepo.instance.role(refresh: true);
      final d = decidePostLogin(claim: claim, isNewUser: false, selected: _role);
      if (mounted && d.registeredAs != null) _registeredAsToast(d.registeredAs!);
      // RootGate reacts to the auth change and routes by claim.
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = _authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _registeredAsToast(PartnerRole actual) => toast(
        context,
        actual == PartnerRole.seller
            ? context.tr('This account is registered as a seller.', 'यह खाता विक्रेता के रूप में पंजीकृत है।')
            : context.tr('This account is registered as a delivery partner.', 'यह खाता डिलीवरी पार्टनर के रूप में पंजीकृत है।'),
        icon: Icons.info_outline_rounded,
      );

  String _authMessage(Object e) {
    final s = e.toString();
    if (s.contains('invalid-credential') || s.contains('wrong-password') || s.contains('user-not-found') || s.contains('INVALID_LOGIN')) {
      return context.tr('Incorrect email or password.', 'ईमेल या पासवर्ड गलत है।');
    }
    if (s.contains('too-many-requests')) return context.tr('Too many attempts. Try again later.', 'बहुत अधिक प्रयास। बाद में कोशिश करें।');
    if (s.contains('network')) return context.tr('No internet connection.', 'इंटरनेट कनेक्शन नहीं है।');
    return describeError(e);
  }

  void _demo(String email) {
    _email.text = email;
    _pass.text = 'Go4Market@123';
    AppState.instance.setRoleTint(email.startsWith('seller') ? PartnerRole.seller : PartnerRole.delivery);
    setState(() => _method = _Method.email);
  }

  void _setMethod(_Method m) {
    if (_method == m || _busy) return;
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _method = m;
      _error = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Phone OTP
  // ---------------------------------------------------------------------------

  Future<void> _sendCode({bool resend = false}) async {
    final e164 = toE164(_phone.text, countryCode: _cc.text);
    if (e164 == null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = context.tr('Enter a valid mobile number.', 'मान्य मोबाइल नंबर दर्ज करें।'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _autoDetected = false;
    });
    try {
      await SocialAuth.instance.sendCode(
        phoneE164: e164,
        resendToken: resend ? _resendToken : null,
        onCodeSent: (id, token) {
          if (!mounted) return;
          setState(() {
            _verificationId = id;
            _resendToken = token;
            _sentTo = e164;
            _busy = false;
            _otp.clear();
          });
          _startCountdown();
          if (resend) toast(context, context.tr('A new code is on its way.', 'नया कोड भेजा जा रहा है।'), icon: Icons.sms_outlined);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && !_finishing) _otpFocus.requestFocus();
          });
        },
        onFailed: (e) {
          HapticFeedback.heavyImpact();
          if (mounted) {
            setState(() {
              _busy = false;
              _error = _socialMessage(e, _Provider.phone);
            });
          }
        },
        onAutoVerified: (cred) {
          // Android read the SMS (or verified instantly): show the code and sign in.
          if (!mounted) return;
          setState(() {
            _autoDetected = true;
            if (cred.smsCode != null) _otp.text = cred.smsCode!;
          });
          _finish(() => SocialAuth.instance.signInWithCredential(cred), _Provider.phone);
        },
      );
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _socialMessage(e, _Provider.phone);
        });
      }
    }
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  void _changeNumber() {
    _ticker?.cancel();
    setState(() {
      _verificationId = null;
      _sentTo = null;
      _resendIn = 0;
      _error = null;
      _autoDetected = false;
      _otp.clear();
    });
  }

  Future<void> _verify([String? code]) async {
    final c = code ?? _otp.text;
    final id = _verificationId;
    if (id == null) return;
    if (c.length != 6) {
      HapticFeedback.heavyImpact();
      setState(() => _error = context.tr('Enter the 6-digit code.', '6 अंकों का कोड दर्ज करें।'));
      return;
    }
    await _finish(() => SocialAuth.instance.verifyCode(id, c), _Provider.phone);
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------

  Future<void> _google() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    await _finish(SocialAuth.instance.signInWithGoogle, _Provider.google);
  }

  // ---------------------------------------------------------------------------
  // Shared post-login flow (phone + Google)
  // ---------------------------------------------------------------------------

  /// Signs in, then decides where to go while RootGate is held on this screen.
  Future<void> _finish(Future<UserCredential> Function() signIn, _Provider provider) async {
    if (_finishing) return;
    _finishing = true;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _googleBusy = provider == _Provider.google;
      _error = null;
    });
    Session.instance.hold();
    try {
      final cred = await signIn();
      final user = cred.user ?? FirebaseAuth.instance.currentUser!;
      final claim = await Session.instance.resolveClaim();
      final d = decidePostLogin(
        claim: claim,
        isNewUser: cred.additionalUserInfo?.isNewUser ?? false,
        selected: _role,
      );
      Session.instance.prefill = PartnerPrefill(name: user.displayName, phone: user.phoneNumber, email: user.email);

      switch (d.route) {
        case PostLoginRoute.sellerHome:
        case PostLoginRoute.deliveryHome:
          if (mounted && d.registeredAs != null) _registeredAsToast(d.registeredAs!);
        case PostLoginRoute.admin:
          break;
        case PostLoginRoute.roleChooser:
          var name = (user.displayName ?? '').trim();
          if (name.isEmpty && mounted) name = (await _askName()) ?? '';
          Session.instance.prefill = PartnerPrefill(name: name, phone: user.phoneNumber, email: user.email);
          if (d.completeProfile) {
            await SocialAuth.instance.completeProfile(name: name, email: user.email, phone: user.phoneNumber);
          }
        case PostLoginRoute.customerMismatch:
          final proceed = mounted && await _customerMismatch();
          if (!proceed) {
            await Session.instance.signOut();
            if (mounted) _changeNumber();
          }
      }
    } on SignInCancelled {
      // Closed the Google picker: nothing to report.
    } catch (e) {
      HapticFeedback.heavyImpact();
      // A failure before sign-in completed leaves no user; one after it (e.g. claims) lets RootGate retry.
      if (mounted) {
        setState(() {
          _error = _socialMessage(e, provider);
          if (provider == _Provider.phone && authErrorCode(e) == 'invalid-verification-code') _otp.clear();
        });
      }
    } finally {
      _finishing = false;
      if (mounted) {
        setState(() {
          _busy = false;
          _googleBusy = false;
        });
      }
      Session.instance.release();
    }
  }

  /// Existing customer account: the role-mismatch message. They may still register
  /// this account as a partner, or switch accounts.
  Future<bool> _customerMismatch() async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.rc.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(G4MRadius.lg))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.rc.brand.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(Icons.person_outline_rounded, color: c.rc.brand, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              c.tr('This account is registered as a customer.', 'यह खाता ग्राहक के रूप में पंजीकृत है।'),
              textAlign: TextAlign.center,
              style: c.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              c.tr(
                'The Partner app is for sellers and delivery partners. Use a different account, or register this one as a partner.',
                'पार्टनर ऐप विक्रेताओं और डिलीवरी पार्टनर्स के लिए है। दूसरा खाता उपयोग करें या इसी खाते को पार्टनर के रूप में पंजीकृत करें।',
              ),
              textAlign: TextAlign.center,
              style: c.tt.bodyMedium?.copyWith(color: c.rc.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(c.tr('Use a different account', 'दूसरा खाता उपयोग करें')),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(c.tr('Register this account as a partner', 'इस खाते को पार्टनर के रूप में पंजीकृत करें')),
            ),
          ]),
        ),
      ),
    );
    return r ?? false;
  }

  /// Phone sign-ins carry no name; ask once so the profile and wizard are prefilled.
  Future<String?> _askName() {
    final ctrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.rc.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(G4MRadius.lg))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 24, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.tr('Welcome to Go4Market', 'Go4Market में स्वागत है'), style: c.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(c.tr('What should we call you?', 'हम आपको क्या कहें?'), style: TextStyle(color: c.rc.muted)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: c.s.fullName, prefixIcon: const Icon(Icons.badge_outlined)),
              onSubmitted: (v) => Navigator.pop(c, v.trim()),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 52, child: FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(c.s.continueBtn))),
            TextButton(onPressed: () => Navigator.pop(c, ''), child: Text(c.tr('Skip for now', 'अभी छोड़ें'))),
          ]),
        ),
      ),
    ).whenComplete(() => WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose()));
  }

  String _socialMessage(Object e, _Provider p) {
    if (e is GoogleSignInException) {
      return switch (e.code) {
        GoogleSignInExceptionCode.clientConfigurationError || GoogleSignInExceptionCode.providerConfigurationError => context.tr(
            'Google sign-in is not set up for this build of the app yet. Please use phone or email.',
            'इस ऐप बिल्ड के लिए Google साइन-इन अभी सेट नहीं है। कृपया फ़ोन या ईमेल उपयोग करें।'),
        GoogleSignInExceptionCode.uiUnavailable =>
          context.tr('Google sign-in is not available on this device.', 'इस डिवाइस पर Google साइन-इन उपलब्ध नहीं है।'),
        _ => context.tr('Google sign-in failed. Please try again.', 'Google साइन-इन विफल रहा। फिर से कोशिश करें।'),
      };
    }
    return switch (authErrorCode(e)) {
      'operation-not-allowed' => p == _Provider.phone
          ? context.tr('Phone sign-in is not enabled yet. Please log in with email or Google for now.',
              'फ़ोन साइन-इन अभी चालू नहीं है। अभी के लिए ईमेल या Google से लॉग इन करें।')
          : context.tr('Google sign-in is not enabled yet. Please log in with email or phone for now.',
              'Google साइन-इन अभी चालू नहीं है। अभी के लिए ईमेल या फ़ोन से लॉग इन करें।'),
      'invalid-phone-number' || 'missing-phone-number' =>
        context.tr('That mobile number doesn\'t look right. Check it and try again.', 'यह मोबाइल नंबर सही नहीं लगता। जांचें और फिर कोशिश करें।'),
      'invalid-verification-code' => context.tr('Incorrect code. Check the SMS and try again.', 'गलत कोड। SMS जांचें और फिर कोशिश करें।'),
      'session-expired' || 'code-expired' || 'invalid-verification-id' || 'missing-verification-id' =>
        context.tr('This code has expired. Tap "Resend code" to get a new one.', 'यह कोड समाप्त हो गया। नया कोड पाने के लिए "कोड फिर भेजें" दबाएं।'),
      'too-many-requests' || 'quota-exceeded' =>
        context.tr('Too many attempts. Please wait a few minutes and try again.', 'बहुत अधिक प्रयास। कुछ मिनट रुककर फिर कोशिश करें।'),
      'network-request-failed' => context.tr('No internet connection.', 'इंटरनेट कनेक्शन नहीं है।'),
      'user-disabled' => context.tr('This account has been blocked. Please contact Go4Market support.', 'यह खाता ब्लॉक है। कृपया Go4Market सहायता से संपर्क करें।'),
      'account-exists-with-different-credential' || 'credential-already-in-use' || 'email-already-in-use' => context.tr(
          'This email already has a Go4Market account. Log in with your email and password.',
          'इस ईमेल का Go4Market खाता पहले से है। अपने ईमेल और पासवर्ड से लॉग इन करें।'),
      'app-not-authorized' || 'missing-client-identifier' || 'captcha-check-failed' || 'invalid-app-credential' || 'missing-id-token' => context.tr(
          'We couldn\'t verify this app. Update Go4Market Partner or try again later.',
          'हम इस ऐप को सत्यापित नहीं कर सके। ऐप अपडेट करें या बाद में कोशिश करें।'),
      _ => describeError(e),
    };
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final seller = _role == PartnerRole.seller;
        final rc = context.rc;
        return Scaffold(
          body: Stack(children: [
            // Header band in role colours with the drifting doodle.
            AnimatedContainer(
              duration: G4MMotion.emphasized,
              curve: G4MMotion.curve,
              height: 300,
              decoration: BoxDecoration(gradient: rc.hero),
              child: const DoodleBackground(color: Colors.white, opacity: .08, period: Duration(seconds: 36)),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: const G4MLogo(size: 34),
                    ),
                    const SizedBox(width: 10),
                    const G4MWordmark(size: 34, light: true, showMark: false),
                  ]).animate().fadeIn(duration: 400.ms).slideX(begin: -.08),
                  const SizedBox(height: 26),
                  AnimatedSwitcher(
                    duration: G4MMotion.standard,
                    child: Text(
                      seller ? context.tr('Welcome back, partner', 'वापसी पर स्वागत है') : context.tr('Ready to ride?', 'डिलीवरी के लिए तैयार?'),
                      key: ValueKey(seller),
                      style: context.tt.headlineMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('Log in to manage your business on Go4Market.', 'Go4Market पर अपना काम संभालने के लिए लॉग इन करें।'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: rc.card,
                      borderRadius: BorderRadius.circular(G4MRadius.lg),
                      boxShadow: G4MShadows.lifted,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _RoleToggle(
                        value: _role,
                        onChanged: (r) {
                          HapticFeedback.selectionClick();
                          AppState.instance.setRoleTint(r);
                        },
                      ),
                      const SizedBox(height: 16),
                      _MethodSwitch(
                        phone: _method == _Method.phone,
                        tint: rc.brand,
                        onChanged: (phone) => _setMethod(phone ? _Method.phone : _Method.email),
                      ),
                      const SizedBox(height: 18),
                      AnimatedSize(
                        duration: G4MMotion.emphasized,
                        curve: G4MMotion.curve,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: G4MMotion.standard,
                          switchInCurve: G4MMotion.curve,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (c, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(a), child: c),
                          ),
                          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                          child: switch (_method) {
                            _Method.email => KeyedSubtree(key: const ValueKey('email'), child: _emailForm(context)),
                            _Method.phone => KeyedSubtree(key: ValueKey('phone-$_codeStep'), child: _codeStep ? _codeForm(context) : _phoneForm(context)),
                          },
                        ),
                      ),
                      _errorBox(),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _busy ? null : _primaryAction,
                          child: AnimatedSwitcher(
                            duration: G4MMotion.standard,
                            child: _busy && !_googleBusy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                                : Text(_primaryLabel(context), key: ValueKey(_primaryLabel(context))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: Divider(color: rc.line)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(context.tr('or', 'या'), style: context.tt.labelMedium?.copyWith(color: rc.muted)),
                        ),
                        Expanded(child: Divider(color: rc.line)),
                      ]),
                      const SizedBox(height: 14),
                      _GoogleButton(busy: _googleBusy, onPressed: _busy ? null : _google),
                    ]),
                  ).animate().fadeIn(duration: 450.ms, delay: 100.ms).slideY(begin: .08, curve: Curves.easeOutCubic),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(context.tr('New to Go4Market?', 'Go4Market पर नए हैं?'), style: TextStyle(color: rc.muted)),
                    TextButton(onPressed: () => Go.push(context, const SignupScreen()), child: Text(context.s.createAccount)),
                  ]).animate().fadeIn(delay: 250.ms),
                  StreamBuilder<PlatformSettings>(
                    stream: SettingsRepo.instance.platform(),
                    builder: (context, s) {
                      if (s.data?.data['demoMode'] != true) return const SizedBox.shrink();
                      return Column(children: [
                        const SizedBox(height: 8),
                        Text(context.tr('Demo accounts', 'डेमो खाते'), style: context.tt.labelMedium?.copyWith(color: rc.muted)),
                        const SizedBox(height: 8),
                        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                          ActionChip(
                            avatar: const Icon(Icons.storefront_rounded, size: 18),
                            label: Text(context.s.seller),
                            onPressed: () => _demo('seller@go4market.com'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.delivery_dining_rounded, size: 18),
                            label: Text(context.s.deliveryPartner),
                            onPressed: () => _demo('delivery@go4market.com'),
                          ),
                        ]),
                      ]).animate().fadeIn();
                    },
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _primaryAction() => switch (_method) {
        _Method.email => _login(),
        _Method.phone => _codeStep ? _verify() : _sendCode(),
      };

  String _primaryLabel(BuildContext context) => switch (_method) {
        _Method.email => context.s.login,
        _Method.phone => _codeStep ? context.tr('Verify & continue', 'सत्यापित करें') : context.tr('Send OTP', 'OTP भेजें'),
      };

  Widget _emailForm(BuildContext context) => Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: context.s.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
            validator: (v) => (v ?? '').contains('@') ? null : context.tr('Enter a valid email', 'सही ईमेल दर्ज करें'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pass,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: context.s.password,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v ?? '').length >= 6 ? null : context.tr('At least 6 characters', 'कम से कम 6 अक्षर'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Go.push(context, ForgotPasswordScreen(email: _email.text)),
              child: Text(context.s.forgotPassword),
            ),
          ),
        ]),
      );

  Widget _phoneForm(BuildContext context) {
    final rc = context.rc;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 84,
          child: TextField(
            key: const ValueKey('phone-cc'),
            controller: _cc,
            keyboardType: TextInputType.phone,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')), LengthLimitingTextInputFormatter(4)],
            style: const TextStyle(fontWeight: FontWeight.w700),
            decoration: InputDecoration(labelText: context.tr('Code', 'कोड')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            key: const ValueKey('phone-number'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')), LengthLimitingTextInputFormatter(16)],
            onSubmitted: (_) => _sendCode(),
            decoration: InputDecoration(
              labelText: context.tr('Mobile number', 'मोबाइल नंबर'),
              hintText: '98765 43210',
              prefixIcon: const Icon(Icons.phone_iphone_rounded),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Icon(Icons.sms_outlined, size: 16, color: rc.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.tr('We\'ll text you a 6-digit code. SMS rates may apply.', 'हम आपको 6 अंकों का कोड SMS करेंगे।'),
            style: context.tt.bodySmall?.copyWith(color: rc.muted),
          ),
        ),
      ]),
      const SizedBox(height: 16),
    ]);
  }

  Widget _codeForm(BuildContext context) {
    final rc = context.rc;
    final mm = (_resendIn ~/ 60).toString();
    final ss = (_resendIn % 60).toString().padLeft(2, '0');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: context.tr('Code sent to ', 'कोड भेजा गया ')),
              TextSpan(text: maskPhone(_sentTo ?? ''), style: TextStyle(fontWeight: FontWeight.w800, color: rc.ink)),
            ]),
            style: context.tt.bodyMedium?.copyWith(color: rc.muted),
          ),
        ),
        TextButton(onPressed: _busy ? null : _changeNumber, child: Text(context.tr('Change', 'बदलें'))),
      ]),
      const SizedBox(height: 10),
      OtpInput(
        controller: _otp,
        focusNode: _otpFocus,
        color: rc.brand,
        enabled: !_busy,
        hasError: _error != null,
        autofocus: false,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onCompleted: (c) => _verify(c),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 40,
        child: Row(children: [
          AnimatedSwitcher(
            duration: G4MMotion.standard,
            child: _autoDetected
                ? Row(key: const ValueKey('auto'), mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: rc.brand),
                    const SizedBox(width: 6),
                    Text(context.tr('Code detected automatically', 'कोड अपने आप पढ़ लिया गया'),
                        style: context.tt.bodySmall?.copyWith(color: rc.brand, fontWeight: FontWeight.w700)),
                  ])
                : const SizedBox.shrink(key: ValueKey('none')),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: G4MMotion.standard,
            child: _resendIn > 0
                ? Text(
                    context.tr('Resend code in $mm:$ss', '$mm:$ss में कोड फिर भेजें'),
                    key: const ValueKey('countdown'),
                    style: context.tt.bodySmall?.copyWith(color: rc.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                  )
                : TextButton.icon(
                    key: const ValueKey('resend'),
                    onPressed: _busy ? null : () => _sendCode(resend: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.tr('Resend code', 'कोड फिर भेजें')),
                  ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _errorBox() => AnimatedSize(
        duration: G4MMotion.standard,
        child: _error == null
            ? const SizedBox.shrink()
            : Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: G4MColors.danger.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(G4MRadius.sm),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: G4MColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: G4MColors.danger, fontWeight: FontWeight.w600))),
                ]),
              ).animate(key: ValueKey(_error)).shakeX(hz: 5, amount: 4, duration: 400.ms),
      );
}

/// Email | Phone switch with a sliding underline in the role tint.
class _MethodSwitch extends StatelessWidget {
  const _MethodSwitch({required this.phone, required this.tint, required this.onChanged});
  final bool phone;
  final Color tint;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    Widget tab(bool isPhone, IconData icon, String label) {
      final active = phone == isPhone;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(isPhone),
            child: SizedBox(
              height: 40,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: G4MMotion.standard,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: active ? tint : rc.muted),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedSwitcher(
                      duration: G4MMotion.standard,
                      child: Icon(icon, key: ValueKey('$isPhone$active'), size: 18, color: active ? tint : rc.muted),
                    ),
                    const SizedBox(width: 6),
                    Text(label),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(children: [
      Row(children: [
        tab(false, Icons.alternate_email_rounded, context.s.email),
        tab(true, Icons.phone_iphone_rounded, context.s.phone),
      ]),
      Stack(children: [
        Container(height: 2, color: rc.line),
        AnimatedAlign(
          alignment: phone ? Alignment.centerRight : Alignment.centerLeft,
          duration: G4MMotion.emphasized,
          curve: Curves.easeOutBack,
          child: FractionallySizedBox(
            widthFactor: .5,
            child: AnimatedContainer(
              duration: G4MMotion.emphasized,
              height: 3,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ]),
    ]);
  }
}

/// "Continue with Google" button with a multi-colour G mark.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onPressed});
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: rc.card,
          side: BorderSide(color: rc.line, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(G4MRadius.pill)),
        ),
        onPressed: onPressed,
        child: AnimatedSwitcher(
          duration: G4MMotion.standard,
          child: busy
              ? SizedBox(key: const ValueKey('busy'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: rc.brand))
              : Row(key: const ValueKey('idle'), mainAxisSize: MainAxisSize.min, children: [
                  ShaderMask(
                    shaderCallback: (r) => const SweepGradient(
                      colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFFEA4335)],
                      stops: [0, .25, .5, .75, 1],
                    ).createShader(r),
                    child: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                  ),
                  const SizedBox(width: 10),
                  Text(context.tr('Continue with Google', 'Google से जारी रखें'),
                      style: TextStyle(fontWeight: FontWeight.w700, color: rc.ink)),
                ]),
        ),
      ),
    );
  }
}

/// Sliding pill toggle between the two roles.
class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.value, required this.onChanged});
  final PartnerRole value;
  final ValueChanged<PartnerRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final seller = value == PartnerRole.seller;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: rc.cardAlt, borderRadius: BorderRadius.circular(G4MRadius.pill)),
      child: Stack(children: [
        AnimatedAlign(
          alignment: seller ? Alignment.centerLeft : Alignment.centerRight,
          duration: G4MMotion.emphasized,
          curve: Curves.easeOutBack,
          child: FractionallySizedBox(
            widthFactor: .5,
            child: AnimatedContainer(
              duration: G4MMotion.emphasized,
              decoration: BoxDecoration(
                gradient: seller ? G4MColors.heroGradient : G4MColors.accentGradient,
                borderRadius: BorderRadius.circular(G4MRadius.pill),
                boxShadow: [BoxShadow(color: (seller ? G4MColors.primary : G4MColors.accent).withValues(alpha: .3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
            ),
          ),
        ),
        Row(children: [
          _seg(context, PartnerRole.seller, Icons.storefront_rounded, context.s.seller, seller),
          _seg(context, PartnerRole.delivery, Icons.delivery_dining_rounded, context.tr('Delivery', 'डिलीवरी'), !seller),
        ]),
      ]),
    );
  }

  Widget _seg(BuildContext context, PartnerRole r, IconData icon, String label, bool active) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(r),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: G4MMotion.standard,
              style: TextStyle(fontWeight: FontWeight.w800, color: active ? Colors.white : context.rc.muted, fontSize: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: active ? Colors.white : context.rc.muted),
                const SizedBox(width: 6),
                Text(label),
              ]),
            ),
          ),
        ),
      );
}
