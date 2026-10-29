import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';

import '../core/push.dart';
import '../core/shop.dart';
import '../l10n/l10n.dart';
import '../ui/kit.dart';
import '../ui/shell.dart';

String _authError(Object e) {
  final s = L.current.auth;
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-login-credentials' => s.errBadCredentials,
      'email-already-in-use' => s.errEmailInUse,
      'weak-password' => s.errWeakPassword,
      'invalid-email' => s.errInvalidEmail,
      'too-many-requests' => s.errTooMany,
      'network-request-failed' => s.errNetwork,
      // Phone sign-in is not switched on in the Firebase project yet.
      'operation-not-allowed' || 'admin-restricted-operation' => s.errProviderOff,
      'invalid-phone-number' || 'missing-phone-number' => s.errInvalidPhone,
      'invalid-verification-code' || 'missing-verification-code' => s.errBadCode,
      'code-expired' || 'session-expired' => s.errCodeExpired,
      'captcha-check-failed' || 'invalid-app-credential' || 'missing-app-credential' => s.errCaptcha,
      'quota-exceeded' => s.errQuota,
      'popup-closed-by-user' || 'cancelled-popup-request' || 'user-cancelled' => s.errPopupClosed,
      'account-exists-with-different-credential' || 'credential-already-in-use' => s.errOtherAccount,
      _ => e.message ?? s.errGeneric,
    };
  }
  return friendlyError(e);
}

/// Phone-specific: an `operation-not-allowed` here means the provider is still off.
String _phoneError(Object e) =>
    e is FirebaseAuthException && (e.code == 'operation-not-allowed' || e.code == 'admin-restricted-operation') ? L.current.auth.errPhoneSoon : _authError(e);

/// Wraps a phone number / email in a left-to-right isolate so it reads correctly inside Arabic text.
String _ltr(String s) => '${String.fromCharCode(0x2066)}$s${String.fromCharCode(0x2069)}';

String _safeNext(String? n) => n != null && n.startsWith('/') && !n.startsWith('//') ? n : '/';

/// Where to go after a successful sign-in; offers order-update notifications once there.
void _goNext(BuildContext context, String? next) {
  context.go(_safeNext(next));
  unawaited(Push.instance.offer());
}

/// Two-pane auth layout: brand story on the start side (desktop), form on the end side.
class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, required this.subtitle, required this.child});
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final s = context.l.auth;
    final form = Padding(
      padding: EdgeInsets.all(context.isPhone ? 20 : 44),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Heading(title, style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 15.5)),
        const SizedBox(height: 26),
        child,
      ]),
    );
    return PageScroll(children: [
      Contained(
        vertical: 32,
        maxWidth: 1040,
        child: Reveal(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: G4MColors.line), boxShadow: G4MShadows.soft),
            child: context.isDesktop
                ? IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(gradient: G4MColors.heroGradient),
                          padding: const EdgeInsets.all(44),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const G4MWordmark(size: 40, light: true),
                            const Spacer(),
                            Text(s.heroLine, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -.8)),
                            const SizedBox(height: 22),
                            _Benefit(icon: Icons.bolt_rounded, text: s.benefitQuick),
                            _Benefit(icon: Icons.location_on_outlined, text: s.benefitTracking),
                            _Benefit(icon: Icons.account_balance_wallet_outlined, text: s.benefitWallet),
                            _Benefit(icon: Icons.storefront_outlined, text: s.benefitSellers),
                          ]),
                        ),
                      ),
                      Expanded(child: form),
                    ]),
                  )
                : form,
          ),
        ),
      ),
    ]);
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: G4MColors.accent, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFE2F1E8), fontWeight: FontWeight.w600, fontSize: 15))),
        ]),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.error_outline_rounded, size: 18, color: G4MColors.danger)),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(color: G4MColors.danger, fontWeight: FontWeight.w600))),
          ]),
        ),
      );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, this.onSubmit, this.autofill = AutofillHints.password});
  final TextEditingController controller;
  final VoidCallback? onSubmit;
  final String autofill;
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    final s = context.l.auth;
    return TextFormField(
      controller: widget.controller,
      obscureText: !_show,
      autofillHints: [widget.autofill],
      onFieldSubmitted: (_) => widget.onSubmit?.call(),
      validator: (v) => (v ?? '').length < 6 ? s.atLeast6 : null,
      decoration: InputDecoration(
        labelText: s.password,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _show ? s.hidePassword : s.showPassword,
          onPressed: () => setState(() => _show = !_show),
          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Google + method tabs

/// Multi-colour Google "G", drawn so no image asset or network font is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  const _GPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * .2;
    final rect = Rect.fromCircle(center: Offset(w / 2, w / 2), radius: (w - stroke) / 2);
    Paint p(int c) => Paint()
      ..color = Color(c)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const d = math.pi / 180;
    canvas.drawArc(rect, -40 * d, -95 * d, false, p(0xFFEA4335)); // red (top)
    canvas.drawArc(rect, -135 * d, -90 * d, false, p(0xFFFBBC05)); // yellow (left)
    canvas.drawArc(rect, 135 * d, -90 * d, false, p(0xFF34A853)); // green (bottom)
    canvas.drawArc(rect, 45 * d, -45 * d, false, p(0xFF4285F4)); // blue (right)
    canvas.drawRect(Rect.fromLTWH(w / 2, w / 2 - stroke / 2, w / 2 - stroke / 4, stroke), Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(_GPainter old) => false;
}

/// Google button, an "or" divider and an animated Email / Phone switch.
class _AuthMethods extends StatefulWidget {
  const _AuthMethods({required this.emailForm, required this.onSignedIn});
  final Widget emailForm;
  final ValueChanged<SocialOutcome> onSignedIn;
  @override
  State<_AuthMethods> createState() => _AuthMethodsState();
}

class _AuthMethodsState extends State<_AuthMethods> {
  int _tab = 0;
  bool _google = false;
  String? _err;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _google = true;
      _err = null;
    });
    try {
      final r = await Shop.instance.signInWithGoogle();
      if (r != null && mounted) widget.onSignedIn(r);
    } catch (e) {
      if (mounted) setState(() => _err = _authError(e));
    }
    if (mounted) setState(() => _google = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l.auth;
    final reduce = context.reduceMotion;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: _google ? null : _signInWithGoogle,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: G4MColors.ink,
            side: const BorderSide(color: Color(0xFFD5E2DA), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_google) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)) else const _GoogleMark(),
            const SizedBox(width: 12),
            Flexible(child: Text(_google ? s.openingGoogle : s.continueGoogle, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
      if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: _ErrorText(_err!)),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          const Expanded(child: Divider(color: G4MColors.line)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(s.or, style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600))),
          const Expanded(child: Divider(color: G4MColors.line)),
        ]),
      ),
      _MethodTabs(
        index: _tab,
        labels: [s.tabEmail, s.tabPhone],
        icons: const [Icons.mail_outline_rounded, Icons.smartphone_rounded],
        semanticLabel: s.signInWith,
        onChanged: (i) => setState(() => _tab = i),
      ),
      const SizedBox(height: 20),
      AnimatedSize(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
          transitionBuilder: (child, a) {
            // Slide in from the side of the tab that was picked (mirrored in RTL).
            final fromEnd = (child.key == const ValueKey(1)) ^ context.l.rtl;
            return FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: Offset(fromEnd ? .08 : -.08, 0), end: Offset.zero).animate(a), child: child),
            );
          },
          child: _tab == 0
              ? KeyedSubtree(key: const ValueKey(0), child: widget.emailForm)
              : KeyedSubtree(key: const ValueKey(1), child: _PhoneForm(onDone: widget.onSignedIn)),
        ),
      ),
    ]);
  }
}

/// Pill segmented control with a sliding thumb.
class _MethodTabs extends StatelessWidget {
  const _MethodTabs({required this.index, required this.labels, required this.icons, required this.onChanged, required this.semanticLabel});
  final int index;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: semanticLabel,
        child: Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFFF0F6F2), borderRadius: BorderRadius.circular(G4MRadius.pill)),
          child: Stack(children: [
            AnimatedAlign(
              duration: context.reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: index == 0 ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
              child: FractionallySizedBox(
                widthFactor: 1 / labels.length,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(G4MRadius.pill),
                    boxShadow: const [BoxShadow(color: Color(0x1A0A4A33), blurRadius: 10, offset: Offset(0, 3))],
                  ),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: labels[i],
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(G4MRadius.pill),
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: i == index ? G4MColors.primaryDeep : G4MColors.inkMuted,
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(icons[i], size: 18, color: i == index ? G4MColors.primary : G4MColors.inkMuted),
                            const SizedBox(width: 8),
                            Text(labels[i]),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ phone OTP

class _PhoneForm extends StatefulWidget {
  const _PhoneForm({required this.onDone});
  final ValueChanged<SocialOutcome> onDone;
  @override
  State<_PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends State<_PhoneForm> {
  static const _resendAfter = 30;
  final _cc = TextEditingController(text: '+91');
  final _num = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  PhoneSignIn? _pending;
  String _sentTo = '';
  bool _busy = false;
  String? _err;
  int _left = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_cc, _num, _code]) {
      c.dispose();
    }
    _codeFocus.dispose();
    super.dispose();
  }

  String? get _e164 {
    final cc = '+${_cc.text.replaceAll(RegExp(r'\D'), '')}';
    var n = _num.text.replaceAll(RegExp(r'\D'), '');
    if (cc == '+91' && n.length == 11 && n.startsWith('0')) n = n.substring(1);
    if (cc.length < 2 || cc.length > 4) return null;
    if (cc == '+91' ? n.length != 10 : (n.length < 6 || n.length > 14)) return null;
    return '$cc$n';
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _left = math.max(0, _left - 1));
      if (_left == 0) t.cancel();
    });
  }

  Future<void> _send({bool resend = false}) async {
    final phone = _e164;
    if (phone == null) return setState(() => _err = context.l.auth.errInvalidPhone);
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final p = await Shop.instance.startPhoneSignIn(phone);
      if (!mounted) return;
      setState(() {
        _pending = p;
        _sentTo = phone;
        _code.clear();
      });
      _startTimer();
      if (resend) toast(context, context.l.auth.codeResent);
      WidgetsBinding.instance.addPostFrameCallback((_) => _codeFocus.requestFocus());
    } catch (e) {
      if (mounted) setState(() => _err = _phoneError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) return setState(() => _err = context.l.auth.otpInvalid);
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await _pending!.confirm(code);
      if (mounted) widget.onDone(r);
    } catch (e) {
      if (mounted) setState(() => _err = _phoneError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l.auth;
    final reduce = context.reduceMotion;
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SizeTransition(sizeFactor: a, axisAlignment: -1, child: c)),
      child: _pending == null ? _numberStep(s) : _codeStep(s),
    );
  }

  Widget _numberStep(AuthStrings s) => Column(key: const ValueKey('num'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 118,
            child: TextField(
              controller: _cc,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+\d]')), LengthLimitingTextInputFormatter(4)],
              decoration: InputDecoration(labelText: s.countryCode),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _num,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(16)],
              onSubmitted: (_) => _busy ? null : _send(),
              decoration: InputDecoration(labelText: s.mobileNumber, prefixIcon: const Icon(Icons.smartphone_rounded)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(s.otpHint, style: const TextStyle(color: G4MColors.inkMuted, fontSize: 13.5)),
        const SizedBox(height: 14),
        if (_err != null) _ErrorText(_err!),
        SizedBox(height: 52, child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? s.sendingOtp : s.sendOtp))),
      ]);

  Widget _codeStep(AuthStrings s) => Column(key: const ValueKey('code'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.otpSentTo(_ltr(_sentTo)), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          focusNode: _codeFocus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 14),
          onChanged: (v) {
            if (v.length == 6 && !_busy) _verify();
          },
          onSubmitted: (_) => _busy ? null : _verify(),
          decoration: InputDecoration(labelText: s.otpLabel, counterText: '', hintText: '••••••'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _pending = null;
                      _err = null;
                      _timer?.cancel();
                    }),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(s.changeNumber),
          ),
          const Spacer(),
          if (_left > 0)
            Semantics(liveRegion: false, child: Text(s.resendIn(_left), style: const TextStyle(color: G4MColors.inkMuted, fontWeight: FontWeight.w600)))
          else
            TextButton(onPressed: _busy ? null : () => _send(resend: true), child: Text(s.resend)),
        ]),
        const SizedBox(height: 6),
        if (_err != null) _ErrorText(_err!),
        SizedBox(height: 52, child: FilledButton(onPressed: _busy ? null : _verify, child: Text(_busy ? s.verifying : s.verify))),
      ]);
}

// ------------------------------------------------------------------ complete profile

class _CompleteProfile extends StatefulWidget {
  const _CompleteProfile({required this.user, required this.onDone, this.referral});
  final User user;
  final String? referral;
  final VoidCallback onDone;
  @override
  State<_CompleteProfile> createState() => _CompleteProfileState();
}

class _CompleteProfileState extends State<_CompleteProfile> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName ?? '');
  final _email = TextEditingController();
  final _phone = TextEditingController();
  late final _ref = TextEditingController(text: widget.referral?.toUpperCase());
  late final bool _askEmail = (widget.user.email ?? '').isEmpty;
  late final bool _askPhone = (widget.user.phoneNumber ?? '').isEmpty;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _ref]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Shop.instance.completeProfile(
        name: _name.text,
        email: _askEmail ? _email.text : null,
        phone: _askPhone ? _phone.text : null,
        referralCode: _ref.text,
      );
      if (mounted) {
        toast(context, context.l.auth.welcome(_name.text.trim().split(' ').first));
        widget.onDone();
      }
    } catch (e) {
      if (mounted) setState(() => _err = friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l.auth;
    final who = (widget.user.email ?? '').isNotEmpty ? widget.user.email! : (widget.user.phoneNumber ?? '');
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (who.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: G4MColors.primarySoft, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.verified_user_outlined, color: G4MColors.primaryDeep, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(s.signedInAs(_ltr(who)), style: const TextStyle(fontWeight: FontWeight.w700, color: G4MColors.primaryDeep))),
            ]),
          ),
        TextFormField(
          controller: _name,
          autofocus: true,
          autofillHints: const [AutofillHints.name],
          validator: (v) => (v ?? '').trim().length < 2 ? s.enterName : null,
          decoration: InputDecoration(labelText: s.fullName, prefixIcon: const Icon(Icons.person_outline_rounded)),
        ),
        if (_askEmail) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim()) ? null : s.enterValidEmail,
            decoration: InputDecoration(labelText: s.emailOptional, prefixIcon: const Icon(Icons.mail_outline_rounded)),
          ),
        ],
        if (_askPhone) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: (v) => (v ?? '').isEmpty || (v ?? '').replaceAll(RegExp(r'\D'), '').length >= 10 ? null : s.enterValidPhone,
            decoration: InputDecoration(labelText: s.mobileOptional, prefixIcon: const Icon(Icons.phone_outlined)),
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          controller: _ref,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: s.referralOptional, prefixIcon: const Icon(Icons.card_giftcard_rounded)),
        ),
        const SizedBox(height: 18),
        if (_err != null) _ErrorText(_err!),
        SizedBox(height: 52, child: FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? s.saving : s.saveAndContinue))),
      ]),
    );
  }
}

/// Shared behaviour for the login and signup pages: social sign-in outcome, redirect result
/// and the complete-profile step.
mixin _SocialFlow<T extends StatefulWidget> on State<T> {
  String? get next;
  User? profileFor;

  @override
  void initState() {
    super.initState();
    Shop.instance.redirectOutcome.addListener(_onRedirect);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRedirect());
  }

  @override
  void dispose() {
    Shop.instance.redirectOutcome.removeListener(_onRedirect);
    super.dispose();
  }

  void _onRedirect() {
    final r = Shop.instance.redirectOutcome.value;
    if (r == null || !mounted) return;
    Shop.instance.redirectOutcome.value = null;
    if (r.error != null) {
      toast(context, _authError(r.error!), error: true);
      return;
    }
    onSocial(r);
  }

  void onSocial(SocialOutcome r) {
    if (r.user == null) return;
    if (r.needsProfile) {
      setState(() => profileFor = r.user);
    } else {
      _goNext(context, next);
    }
  }
}

// ------------------------------------------------------------------ login

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.next});
  final String? next;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with _SocialFlow<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  String? get next => widget.next;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Shop.instance.signIn(_email.text, _pass.text);
      if (mounted) _goNext(context, widget.next);
    } catch (e) {
      setState(() => _err = _authError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l.auth;
    final c = context.l.common;
    if (profileFor != null) {
      return SeoMeta(
        title: s.completeTitle,
        child: _AuthFrame(
          title: s.completeTitle,
          subtitle: s.completeSubtitle,
          child: _CompleteProfile(user: profileFor!, onDone: () => _goNext(context, widget.next)),
        ),
      );
    }
    final emailForm = AutofillGroup(
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => (v ?? '').contains('@') ? null : s.enterEmail,
            decoration: InputDecoration(labelText: s.email, prefixIcon: const Icon(Icons.mail_outline_rounded)),
          ),
          const SizedBox(height: 14),
          _PasswordField(controller: _pass, onSubmit: _submit),
          Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: () => context.go('/forgot-password'), child: Text(s.forgotPassword))),
          if (_err != null) _ErrorText(_err!),
          SizedBox(height: 52, child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? s.signingIn : c.signIn))),
        ]),
      ),
    );
    return SeoMeta(
      title: s.loginSeoTitle,
      description: s.loginSeoDesc,
      child: _AuthFrame(
        title: s.welcomeBack,
        subtitle: s.loginSubtitle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _AuthMethods(emailForm: emailForm, onSignedIn: onSocial),
          const SizedBox(height: 16),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(s.newHere),
            TextButton(
              onPressed: () => context.go('/signup${widget.next == null ? '' : '?next=${Uri.encodeQueryComponent(widget.next!)}'}'),
              child: Text(s.createAnAccount),
            ),
          ]),
          ListenableBuilder(
            listenable: Shop.instance,
            builder: (context, _) {
              if (Shop.instance.settings.data['demoMode'] != true) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: G4MColors.accentSoft, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.science_outlined, color: kAccentInk),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.demoMode('customer@go4market.com'), style: const TextStyle(fontWeight: FontWeight.w700, color: kAccentInk))),
                  TextButton(
                    onPressed: () {
                      _email.text = 'customer@go4market.com';
                      _pass.text = 'Go4Market@123';
                    },
                    child: Text(s.fill),
                  ),
                ]),
              );
            },
          ),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ signup

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, this.next, this.referral});
  final String? next;
  final String? referral;
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with _SocialFlow<SignupPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  late final _ref = TextEditingController(text: widget.referral?.toUpperCase());
  bool _agree = true, _busy = false;
  String? _err;

  @override
  String? get next => widget.next;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _pass, _ref]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final s = context.l.auth;
    if (!_form.currentState!.validate()) return;
    if (!_agree) return setState(() => _err = s.acceptTerms);
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await Shop.instance.signUp(name: _name.text.trim(), email: _email.text, password: _pass.text, phone: _phone.text.trim(), referralCode: _ref.text.trim());
      if (mounted) {
        toast(context, s.welcome(_name.text.trim().split(' ').first));
        _goNext(context, widget.next);
      }
    } catch (e) {
      setState(() => _err = _authError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l.auth;
    final c = context.l.common;
    if (profileFor != null) {
      return SeoMeta(
        title: s.completeTitle,
        child: _AuthFrame(
          title: s.completeTitle,
          subtitle: s.completeSubtitle,
          child: _CompleteProfile(user: profileFor!, referral: _ref.text, onDone: () => _goNext(context, widget.next)),
        ),
      );
    }
    const link = TextStyle(color: G4MColors.primary, fontWeight: FontWeight.w700);
    final emailForm = AutofillGroup(
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _name,
            autofillHints: const [AutofillHints.name],
            validator: (v) => (v ?? '').trim().length < 2 ? s.enterName : null,
            decoration: InputDecoration(labelText: s.fullName, prefixIcon: const Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : s.enterValidEmail,
            decoration: InputDecoration(labelText: s.email, prefixIcon: const Icon(Icons.mail_outline_rounded)),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: (v) => (v ?? '').isEmpty || (v ?? '').replaceAll(RegExp(r'\D'), '').length >= 10 ? null : s.enterValidPhone,
            decoration: InputDecoration(labelText: s.mobileOptional, prefixIcon: const Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 14),
          _PasswordField(controller: _pass, autofill: AutofillHints.newPassword, onSubmit: _submit),
          const SizedBox(height: 14),
          TextFormField(
            controller: _ref,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: s.referralOptional, prefixIcon: const Icon(Icons.card_giftcard_rounded)),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            title: Wrap(children: [
              Text(s.iAgree),
              TextLink(s.termsWord, to: '/page/terms', style: link),
              Text(s.and),
              TextLink(s.privacyWord, to: '/page/privacy', style: link),
              if (s.agreeSuffix.isNotEmpty) Text(s.agreeSuffix),
            ]),
          ),
          if (_err != null) _ErrorText(_err!),
          SizedBox(height: 52, child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? s.creatingAccount : c.createAccount))),
        ]),
      ),
    );
    return SeoMeta(
      title: s.signupSeoTitle,
      description: s.signupSeoDesc,
      child: _AuthFrame(
        title: s.signupTitle,
        subtitle: s.signupSubtitle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _AuthMethods(emailForm: emailForm, onSignedIn: onSocial),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(s.haveAccount),
            TextButton(
              onPressed: () => context.go('/login${widget.next == null ? '' : '?next=${Uri.encodeQueryComponent(widget.next!)}'}'),
              child: Text(c.signIn),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ forgot

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _busy = false, _sent = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l.auth;
    return SeoMeta(
      title: s.resetSeoTitle,
      description: s.resetSeoDesc,
      child: _AuthFrame(
        title: _sent ? s.checkInbox : s.forgotPassword,
        subtitle: _sent ? s.sentResetTo(_email.text.trim()) : s.resetSubtitle,
        child: _sent
            ? FilledButton(onPressed: () => context.go('/login'), child: Text(s.backToSignIn))
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: s.email, prefixIcon: const Icon(Icons.mail_outline_rounded)),
                ),
                if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: _ErrorText(_err!)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() {
                              _busy = true;
                              _err = null;
                            });
                            try {
                              await AuthRepo.instance.resetPassword(_email.text);
                              setState(() => _sent = true);
                            } catch (e) {
                              setState(() => _err = _authError(e));
                            }
                            if (mounted) setState(() => _busy = false);
                          },
                    child: Text(_busy ? s.sending : s.sendResetLink),
                  ),
                ),
                TextButton(onPressed: () => context.go('/login'), child: Text(s.backToSignIn)),
              ]),
      ),
    );
  }
}
