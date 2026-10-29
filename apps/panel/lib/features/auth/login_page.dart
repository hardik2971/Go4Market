import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';
import 'package:panel/l10n/overrides.dart';

import '../../core/session.dart';
import '../../l10n/lang_picker.dart';
import '../../ui/kit.dart';

/// Split-screen hero used by login / onboarding / pending screens.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.child, this.heroTitle, this.heroText, this.maxWidth = 440});
  final Widget child;
  final String? heroTitle;
  final String? heroText;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 980;
    final accent = session.accent;
    final (title, text, points) = switch (session.panel) {
      PanelRole.admin => (
          'Run the whole marketplace from one place.',
          'Orders, sellers, riders, catalog and growth — across eCommerce, Grocery, Pharmacy and Food.',
          ['Live orders & rider map', 'Multi-module catalog', 'Finance, payouts & reports'],
        ),
      PanelRole.seller => (
          'Grow your store on Go4Market.',
          'List products, accept orders, run in-store POS and get paid — all from your Seller Hub.',
          ['Reach customers across your city', 'POS with barcode scanning', 'Fast weekly payouts'],
        ),
      PanelRole.delivery => (
          'Deliver with Go4Market. Earn on your schedule.',
          'Go online, pick orders near you, navigate and get paid per delivery.',
          ['Flexible hours', 'Live route map', 'Instant earnings view'],
        ),
    };
    final en = L10n.instance.code == 'en';
    final hero = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [const Color(0xFF062A1C), Color.lerp(const Color(0xFF0A4A33), accent, .35)!],
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(fit: StackFit.expand, children: [
        PositionedDirectional(
          end: -120,
          bottom: -120,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .16)),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(.92, .92), end: const Offset(1.05, 1.05), duration: 5.seconds),
        ),
        PositionedDirectional(
          end: 80,
          top: 120,
          child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: G4MColors.accent.withValues(alpha: .12))),
        ),
        Padding(padding: const EdgeInsets.all(56), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const G4MWordmark(size: 40, light: true),
          const Spacer(),
          Text(tr(heroTitle ?? title),
                  style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: en ? 1.1 : 1.35, letterSpacing: en ? -1.2 : 0))
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: .1),
          const SizedBox(height: 16),
          Text(tr(heroText ?? text), style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 16, height: 1.5))
              .animate(delay: 120.ms)
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 28),
          for (var i = 0; i < points.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: G4MColors.accent.withValues(alpha: .25), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 12),
                Text(tr(points[i]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ).animate(delay: (220 + i * 90).ms).fadeIn().slideX(begin: en ? -.05 : .05),
          const Spacer(),
          Text('© ${DateTime.now().year} Go4Market · ${tr(session.panel.title)}', style: TextStyle(color: Colors.white.withValues(alpha: .45), fontSize: 12)),
        ])),
      ]),
    );
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child.animate().fadeIn(duration: 380.ms).slideY(begin: .03, curve: Curves.easeOutCubic),
        ),
      ),
    );
    // The picker floats in the corner so it never shifts the form fields.
    final formSide = Stack(children: [
      Positioned.fill(child: form),
      const PositionedDirectional(top: 16, end: 16, child: LanguagePicker()),
    ]);
    return Scaffold(
      backgroundColor: context.pal.bg,
      body: wide ? Row(children: [Expanded(flex: 5, child: hero), Expanded(flex: 6, child: formSide)]) : formSide,
    );
  }
}

enum _Mode { email, phone }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  _Mode _mode = _Mode.email;
  ConfirmationResult? _confirm;
  String _sentTo = '';

  /// Google + phone OTP are partner-only. Admin stays email/password.
  bool get _partner => session.panel != PanelRole.admin;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  String _authError(FirebaseAuthException e) => switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' => S.incorrectCreds,
        'too-many-requests' => S.tooMany,
        'user-disabled' => S.accountDisabled,
        'operation-not-allowed' || 'admin-restricted-operation' => _mode == _Mode.phone ? S.phoneNotEnabled : (e.message ?? e.code),
        'invalid-phone-number' || 'missing-phone-number' => S.invalidPhone,
        'invalid-verification-code' || 'missing-verification-code' || 'code-expired' => S.invalidOtp,
        'popup-closed-by-user' || 'cancelled-popup-request' => S.popupClosed,
        'popup-blocked' => S.popupBlocked,
        _ => e.message ?? e.code,
      };

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _authError(e));
    } catch (e) {
      final s = '$e';
      if (mounted) {
        setState(() => _error = s.contains('operation-not-allowed') ? S.phoneNotEnabled : friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      await AuthRepo.instance.signIn(_email.text, _pass.text);
      await session.refreshClaims();
    });
  }

  /// New Google / phone users land on /register (router: profileState none) → registerSeller / registerDeliveryPartner.
  Future<void> _google() => _run(() async {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}));
        await session.refreshClaims();
      });

  String get _e164 {
    final raw = _phone.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (raw.startsWith('+')) return raw;
    final digits = raw.replaceFirst(RegExp(r'^0+'), '');
    return '+91$digits';
  }

  Future<void> _sendOtp() async {
    final p = _e164;
    if (!RegExp(r'^\+\d{8,15}$').hasMatch(p) || (p.startsWith('+91') && p.length != 13)) {
      setState(() => _error = S.invalidPhone);
      return;
    }
    await _run(() async {
      // No verifier passed → FlutterFire creates an invisible reCAPTCHA.
      final c = await FirebaseAuth.instance.signInWithPhoneNumber(p);
      if (mounted) {
        setState(() {
          _confirm = c;
          _sentTo = p;
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otp.text.trim();
    if (code.length != 6 || _confirm == null) {
      setState(() => _error = S.invalidOtp);
      return;
    }
    await _run(() async {
      await _confirm!.confirm(code);
      await session.refreshClaims();
    });
  }

  Future<void> _forgot() async {
    final email = await promptText(context, S.resetPassword, label: S.email, initial: _email.text, required: true, confirmLabel: S.sendLink);
    if (email == null) return;
    await runToast(() => AuthRepo.instance.resetPassword(email), success: S.resetSent(email));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.signedIn && !session.authorized && session.panel == PanelRole.admin) {
          return AuthFrame(child: _wrongRole(context));
        }
        if (session.signedIn && session.role == Roles.admin && session.panel != PanelRole.admin) {
          return AuthFrame(child: _wrongRole(context));
        }
        return AuthFrame(
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (MediaQuery.sizeOf(context).width <= 980) ...[const Center(child: G4MWordmark(size: 40)), const SizedBox(height: 32)],
                // Partner panels add Google / phone below the form. Pad the top by the same amount so the email and
                // password fields sit at the same screen position in all three panels (QA automation clicks them).
                if (_partner && _mode == _Mode.email && MediaQuery.sizeOf(context).width > 980) const SizedBox(height: 156),
                Text(S.welcomeBack, style: context.tt.headlineMedium),
                const SizedBox(height: 6),
                Text(S.signInTo(session.panel.title), style: TextStyle(color: context.pal.muted)),
                const SizedBox(height: 28),
                if (_mode == _Mode.email) ..._emailFields(context) else ..._phoneFields(context),
                _errorBox(),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : _mode == _Mode.email
                            ? _submit
                            : _confirm == null
                                ? _sendOtp
                                : _verifyOtp,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(_mode == _Mode.email ? S.signIn : _confirm == null ? S.sendOtp : S.verify),
                  ),
                ),
                if (_partner) ..._partnerOptions(context),
                if (_partner) ...[
                  const SizedBox(height: 20),
                  Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(session.panel == PanelRole.seller ? S.newToG4m : S.wantToDeliver, style: TextStyle(color: context.pal.muted)),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: Text(session.panel == PanelRole.seller ? S.becomeSeller : S.joinPartner),
                    ),
                  ]),
                ],
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.verified_user_outlined, size: 14, color: context.pal.faint),
                  const SizedBox(width: 6),
                  Text(S.securedBy, style: TextStyle(fontSize: 12, color: context.pal.faint)),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _emailFields(BuildContext context) => [
        TextFormField(
          controller: _email,
          autofillHints: const [AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: S.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
          validator: (v) => v == null || !v.contains('@') ? S.enterEmail : null,
          onFieldSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _pass,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: S.password,
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) => v == null || v.length < 6 ? S.atLeast6 : null,
          onFieldSubmitted: (_) => _submit(),
        ),
        Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: _forgot, child: Text(S.forgotPassword))),
      ];

  List<Widget> _phoneFields(BuildContext context) => [
        TextFormField(
          controller: _phone,
          enabled: _confirm == null,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textDirection: TextDirection.ltr,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]'))],
          decoration: InputDecoration(
            labelText: S.mobileNumber,
            prefixIcon: const Icon(Icons.phone_iphone_rounded),
            prefixText: _phone.text.trim().startsWith('+') ? null : '+91 ',
            hintText: '98765 43210',
          ),
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: (_) => _sendOtp(),
        ),
        if (_confirm != null) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _otp,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textDirection: TextDirection.ltr,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: S.otp, prefixIcon: const Icon(Icons.password_rounded), helperText: S.otpSentTo(_sentTo)),
            onFieldSubmitted: (_) => _verifyOtp(),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _confirm = null;
                        _otp.clear();
                      }),
              child: Text(S.changeNumber),
            ),
          ),
        ] else
          const SizedBox(height: 14),
      ];

  Widget _errorBox() => AnimatedSize(
        duration: G4MMotion.standard,
        child: _error == null
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: G4MColors.danger.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: G4MColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: G4MColors.danger, fontWeight: FontWeight.w600))),
                ]),
              ).animate().shakeX(hz: 4, amount: 4),
      );

  List<Widget> _partnerOptions(BuildContext context) => [
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Divider(color: context.pal.line)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(S.orContinueWith, style: TextStyle(fontSize: 12, color: context.pal.muted))),
          Expanded(child: Divider(color: context.pal.line)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: const _GoogleMark(),
                label: Text('Google', style: TextStyle(color: context.pal.ink, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _mode = _mode == _Mode.email ? _Mode.phone : _Mode.email;
                          _confirm = null;
                          _error = null;
                        }),
                icon: Icon(_mode == _Mode.email ? Icons.sms_outlined : Icons.alternate_email_rounded, size: 18),
                label: Text(_mode == _Mode.email ? tr('Phone OTP') : S.email, style: TextStyle(color: context.pal.ink, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ];

  Widget _wrongRole(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.gpp_maybe_outlined, size: 56, color: G4MColors.warning),
        const SizedBox(height: 16),
        Text(S.noAccessPanel, textAlign: TextAlign.center, style: context.tt.headlineSmall),
        const SizedBox(height: 8),
        Text(
          S.wrongRole(session.user?.email ?? session.user?.phoneNumber ?? '', session.role, session.panel.claim),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pal.muted),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: session.signOut, icon: const Icon(Icons.logout_rounded), label: Text(S.signOutSwitch)),
      ]);
}

/// Four-colour "G" drawn with text (no image asset needed).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => const SweepGradient(
          colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFFEA4335)],
          stops: [0, .25, .5, .75, 1],
        ).createShader(r),
        child: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
      );
}
