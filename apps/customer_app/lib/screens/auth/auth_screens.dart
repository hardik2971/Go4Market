import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/nav.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/doodle.dart';
import '../../widgets/ui.dart';
import '../../core/social_auth.dart';
import '../shell/main_shell.dart';
import 'complete_profile_screen.dart';
import 'phone_auth_screen.dart';

String authError(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' || 'INVALID_LOGIN_CREDENTIALS' => 'Email or password is incorrect.',
      'email-already-in-use' => 'An account already exists for this email.',
      'weak-password' => 'Use at least 6 characters for your password.',
      'invalid-email' => 'That email address looks wrong.',
      'too-many-requests' => 'Too many attempts. Please wait a moment.',
      'network-request-failed' => 'No internet connection.',
      'operation-not-allowed' => 'This sign-in method is not enabled yet.',
      _ => e.message ?? e.code,
    };
  }
  return friendlyError(e);
}

/// Shared scaffold: doodle header with the logo, then a rounded form sheet.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.showBack = true});
  final String title, subtitle;
  final List<Widget> children;
  final bool showBack;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 280,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: context.isDark ? const [Color(0xFF0F2219), Color(0xFF0B1410)] : const [Color(0xFFE3F5EA), Color(0xFFF7FAF8)],
              ),
            ),
            child: const DoodleBackground(opacity: .06, cell: 58),
          ),
        ),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              SizedBox(
                height: 48,
                child: Row(children: [
                  if (showBack && Navigator.of(context).canPop())
                    IconButton.filledTonal(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
                ]),
              ),
              const SizedBox(height: 12),
              Center(child: Image.asset('assets/brand/logo.png', width: 84, height: 84).animate().scale(begin: const Offset(.6, .6), curve: Curves.elasticOut, duration: 900.ms)),
              const SizedBox(height: 8),
              Center(child: G4MWordmark(size: 34, showMark: false, light: context.isDark)).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 28),
              _SwapText(title, style: context.text.headlineSmall).stagger(1),
              const SizedBox(height: 6),
              _SwapText(subtitle, style: context.text.bodyMedium?.copyWith(color: context.muted)).stagger(2),
              const SizedBox(height: 22),
              for (var i = 0; i < children.length; i++) children[i].stagger(i + 3, stepMs: 35),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Text that cross-fades and slides when it changes (step titles in multi-step flows).
class _SwapText extends StatelessWidget {
  const _SwapText(this.text, {this.style});
  final String text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: G4MMotion.standard,
        layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
        transitionBuilder: (c, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(.06, 0), end: Offset.zero).animate(a), child: c),
        ),
        child: Text(text, key: ValueKey(text), style: style),
      );
}

/// "or" divider + Google and phone buttons. Runs the whole flow, including the
/// "Complete your profile" step after a first sign-in, then calls [onDone].
class SocialAuthButtons extends StatefulWidget {
  const SocialAuthButtons({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends State<SocialAuthButtons> {
  bool _google = false;

  Future<void> _signInGoogle() async {
    setState(() => _google = true);
    try {
      final r = await SocialAuth.google();
      if (r != null) await _after(r);
    } catch (e) {
      if (mounted) context.toast(socialAuthError(e), error: true);
    } finally {
      if (mounted) setState(() => _google = false);
    }
  }

  Future<void> _signInPhone() async {
    final r = await context.push<SocialSignIn>(const PhoneAuthScreen(), style: RouteStyle.sharedY);
    if (r != null) await _after(r);
  }

  Future<void> _after(SocialSignIn r) async {
    if (!mounted) return;
    if (r.needsProfile) {
      await context.push<bool>(const CompleteProfileScreen(), style: RouteStyle.sharedY);
      if (!mounted) return;
    } else {
      final name = (Session.instance.profile.value?.name ?? r.user.displayName ?? '').trim().split(' ').first;
      context.toast(name.isEmpty || name == 'Guest' ? 'Welcome back!' : 'Welcome back, $name!');
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Divider(color: context.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with', style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Divider(color: context.line)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: _SocialButton(
            key: const ValueKey('google-btn'),
            onTap: _google ? null : _signInGoogle,
            busy: _google,
            icon: const _GoogleMark(),
            label: 'Google',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            key: const ValueKey('phone-btn'),
            onTap: _signInPhone,
            icon: const Icon(Icons.phone_iphone_rounded, size: 20, color: G4MColors.primary),
            label: 'Phone',
          ),
        ),
      ]),
    ]);
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({super.key, required this.onTap, required this.icon, required this.label, this.busy = false});
  final VoidCallback? onTap;
  final Widget icon;
  final String label;
  final bool busy;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: G4MMotion.standard,
          height: 52,
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: busy ? G4MColors.primary : context.line, width: busy ? 1.6 : 1),
            boxShadow: context.softShadow,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedSwitcher(
              duration: G4MMotion.standard,
              child: busy ? const AuthSpinner(key: ValueKey('b'), dark: true) : KeyedSubtree(key: const ValueKey('i'), child: icon),
            ),
            const SizedBox(width: 10),
            Text(label, style: context.text.titleSmall),
          ]),
        ),
      );
}

/// Four-colour "G" drawn with a sweep gradient (no bitmap asset needed).
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => const SweepGradient(
          colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFF4285F4), Color(0xFFEA4335)],
          stops: [0, .25, .5, .62, .9, 1],
          transform: GradientRotation(-1.2),
        ).createShader(r),
        child: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.root = false});

  /// When true this is the app entry point (replace stack on success); otherwise pop(true).
  final bool root;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _guestBusy = false, _obscure = true;

  void _success() {
    if (!mounted) return;
    if (widget.root) {
      context.replaceAll(const MainShell());
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Session.instance.signIn(_email.text, _pass.text);
      _success();
    } catch (e) {
      if (mounted) context.toast(authError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guest() async {
    setState(() => _guestBusy = true);
    try {
      await Session.instance.continueAsGuest();
      _success();
    } catch (e) {
      if (mounted) context.toast(authError(e), error: true);
    } finally {
      if (mounted) setState(() => _guestBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.welcomeBack,
      subtitle: l.loginSubtitle,
      showBack: !widget.root,
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Icons.mail_outline_rounded)),
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: l.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) => (v ?? '').length >= 6 ? null : 'At least 6 characters',
            ),
          ]),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () => context.push(const ForgotPasswordScreen()), child: Text(l.forgotPassword)),
        ),
        const SizedBox(height: 4),
        FilledButton(
          onPressed: _busy ? null : _login,
          child: _busy ? const AuthSpinner() : Text(l.login),
        ),
        const SizedBox(height: 20),
        SocialAuthButtons(onDone: _success),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _guestBusy || Session.instance.signedIn && !widget.root ? null : _guest,
          icon: _guestBusy ? const AuthSpinner(dark: true) : const Icon(Icons.person_outline_rounded),
          label: Text(l.continueAsGuest),
        ),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(l.noAccount, style: context.text.bodyMedium),
          TextButton(
            onPressed: () async {
              final ok = await context.push<bool>(const SignupScreen());
              if (ok == true) _success();
            },
            child: Text(l.createAccount),
          ),
        ]),
        Center(
          child: TextButton.icon(
            onPressed: () {
              _email.text = 'customer@go4market.com';
              _pass.text = 'Go4Market@123';
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Fill demo account'),
            style: TextButton.styleFrom(foregroundColor: context.muted),
          ),
        ),
      ],
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _ref = TextEditingController();
  bool _busy = false, _obscure = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Session.instance.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _pass.text,
        phone: _phone.text.trim(),
        referral: _ref.text.trim(),
      );
      if (mounted) {
        context.toast('Welcome to Go4Market, ${_name.text.trim().split(' ').first}!');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) context.toast(authError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.createAccount,
      subtitle: l.signupSubtitle,
      children: [
        Form(
          key: _form,
          child: Column(children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l.name, prefixIcon: const Icon(Icons.person_outline_rounded)),
              validator: (v) => (v ?? '').trim().length >= 2 ? null : 'Enter your name',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Icons.mail_outline_rounded)),
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l.phone, prefixIcon: const Icon(Icons.phone_outlined), prefixText: '+91 '),
              validator: (v) => (v ?? '').isEmpty || RegExp(r'^\d{10}$').hasMatch(v!.trim()) ? null : 'Enter a 10-digit number',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) => (v ?? '').length >= 6 ? null : 'At least 6 characters',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ref,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.referralCodeOptional,
                prefixIcon: const Icon(Icons.card_giftcard_rounded, color: G4MColors.accent),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const AuthSpinner() : Text(l.createAccount)),
        const SizedBox(height: 20),
        SocialAuthButtons(
          onDone: () {
            if (mounted) Navigator.of(context).pop(true);
          },
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(l.haveAccount),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.login)),
        ]),
      ],
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false, _sent = false;

  Future<void> _send() async {
    if (!_email.text.contains('@')) return context.toast('Enter a valid email', error: true);
    setState(() => _busy = true);
    try {
      await AuthRepo.instance.resetPassword(_email.text);
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) context.toast(authError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.forgotPassword,
      subtitle: 'We will email you a link to reset it.',
      children: [
        AnimatedSwitcher(
          duration: G4MMotion.emphasized,
          child: _sent
              ? AppCard(
                  key: const ValueKey('sent'),
                  color: context.softPrimary,
                  child: Row(children: [
                    const Icon(Icons.mark_email_read_rounded, color: G4MColors.primary, size: 32),
                    const SizedBox(width: 14),
                    Expanded(child: Text(l.resetLinkSent, style: context.text.titleSmall)),
                  ]),
                )
              : TextField(
                  key: const ValueKey('form'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Icons.mail_outline_rounded)),
                ),
        ),
        const SizedBox(height: 20),
        if (!_sent) FilledButton(onPressed: _busy ? null : _send, child: _busy ? const AuthSpinner() : Text(l.sendResetLink)),
        if (_sent) OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.login)),
      ],
    );
  }
}

class AuthSpinner extends StatelessWidget {
  const AuthSpinner({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: dark ? G4MColors.primary : Colors.white),
      );
}

/// Pushes the login screen; resolves true once the user is signed in with an account.
Future<bool> requireAccount(BuildContext context) async {
  if (!Session.instance.isGuest) return true;
  final ok = await context.push<bool>(const LoginScreen(), style: RouteStyle.sharedY);
  return ok == true && !Session.instance.isGuest;
}
