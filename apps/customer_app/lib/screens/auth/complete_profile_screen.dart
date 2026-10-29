import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/nav.dart';
import '../../core/session.dart';
import '../../core/social_auth.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/ui.dart';
import 'auth_screens.dart';

/// What the profile step collected. [phone] is E.164 (e.g. +919876543210).
class ProfileInput {
  const ProfileInput({required this.name, this.email, this.phone, this.referralCode});
  final String name;
  final String? email, phone, referralCode;
}

/// "Complete your profile" after a first phone or Google sign-in.
/// Calls `completeProfile` (falls back to merging into `users/{uid}` if it isn't deployed yet).
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});
  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  bool _saved = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _submit(ProfileInput p) async {
    await SocialAuth.completeProfile(name: p.name, email: p.email, phone: p.phone, referralCode: p.referralCode);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _saved = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    context.toast('Welcome to Go4Market, ${p.name.split(' ').first}!');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final profile = Session.instance.profile.value;
    final name = (u?.displayName ?? '').trim().isNotEmpty ? u!.displayName!.trim() : (profile?.data['name'] ?? '').toString().trim();
    final hasEmail = (u?.email ?? '').isNotEmpty || (profile?.email ?? '').isNotEmpty;
    final hasPhone = (u?.phoneNumber ?? '').isNotEmpty || (profile?.phone ?? '').isNotEmpty;
    return PopScope(
      canPop: name.isNotEmpty || _saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.toast('Add your name to finish setting up');
      },
      child: AuthScaffold(
        title: _saved ? 'You\'re all set' : 'Complete your profile',
        subtitle: _saved ? 'Taking you to the store…' : 'A couple of details so riders and sellers know who you are.',
        showBack: false,
        children: [
          AnimatedSwitcher(
            duration: G4MMotion.emphasized,
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(a), child: c)),
            child: _saved
                ? const _SuccessBadge(key: ValueKey('ok'))
                : CompleteProfileForm(
                    key: const ValueKey('form'),
                    initialName: name,
                    askEmail: !hasEmail,
                    askPhone: !hasPhone,
                    onSubmit: _submit,
                    onSkip: name.isEmpty ? null : () => Navigator.of(context).pop(false),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The form itself, free of Firebase so it can be widget-tested.
class CompleteProfileForm extends StatefulWidget {
  const CompleteProfileForm({
    super.key,
    this.initialName = '',
    this.askEmail = false,
    this.askPhone = false,
    required this.onSubmit,
    this.onSkip,
  });
  final String initialName;
  final bool askEmail, askPhone;
  final Future<void> Function(ProfileInput input) onSubmit;
  final VoidCallback? onSkip;

  @override
  State<CompleteProfileForm> createState() => _CompleteProfileFormState();
}

class _CompleteProfileFormState extends State<CompleteProfileForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _ref = TextEditingController();
  bool _busy = false, _showRef = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(ProfileInput(
        name: _name.text.trim(),
        email: widget.askEmail && _email.text.trim().isNotEmpty ? _email.text.trim() : null,
        phone: widget.askPhone && _phone.text.trim().isNotEmpty ? Validators.toE164('+91', _phone.text) : null,
        referralCode: _ref.text.trim().isEmpty ? null : _ref.text.trim().toUpperCase(),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = socialAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    Widget step(Widget w) => w.animate().fadeIn(delay: (60 * i++).ms, duration: 320.ms).slideX(begin: .06, end: 0, curve: Curves.easeOutCubic);
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        step(TextFormField(
          key: const ValueKey('profile-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
          validator: Validators.name,
        )),
        if (widget.askEmail) ...[
          const SizedBox(height: 14),
          step(TextFormField(
            key: const ValueKey('profile-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              helperText: 'For order receipts',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) => Validators.email(v),
          )),
        ],
        if (widget.askPhone) ...[
          const SizedBox(height: 14),
          step(TextFormField(
            key: const ValueKey('profile-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(12)],
            decoration: const InputDecoration(
              labelText: 'Mobile number (optional)',
              helperText: 'Riders call this number at delivery',
              prefixIcon: Icon(Icons.phone_iphone_rounded),
              prefixText: '+91 ',
            ),
            validator: (v) => Validators.phone(v),
          )),
        ],
        const SizedBox(height: 10),
        step(AnimatedSize(
          duration: G4MMotion.standard,
          curve: G4MMotion.curve,
          alignment: Alignment.topCenter,
          child: _showRef
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextFormField(
                    key: const ValueKey('profile-ref'),
                    controller: _ref,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(16)],
                    decoration: const InputDecoration(
                      labelText: 'Referral code (optional)',
                      prefixIcon: Icon(Icons.card_giftcard_rounded, color: G4MColors.accent),
                    ),
                    validator: Validators.referral,
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('profile-ref-toggle'),
                    onPressed: () => setState(() => _showRef = true),
                    icon: const Icon(Icons.card_giftcard_rounded, size: 18, color: G4MColors.accent),
                    label: const Text('Have a referral code?'),
                  ),
                ),
        )),
        AnimatedSize(
          duration: G4MMotion.standard,
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: const TextStyle(color: G4MColors.danger, fontWeight: FontWeight.w600)),
                ),
        ),
        const SizedBox(height: 18),
        step(FilledButton(
          key: const ValueKey('profile-submit'),
          onPressed: _busy ? null : _submit,
          child: AnimatedSwitcher(
            duration: G4MMotion.standard,
            child: _busy ? const AuthSpinner(key: ValueKey('b')) : const Text('Save & continue', key: ValueKey('t')),
          ),
        )),
        if (widget.onSkip != null) ...[
          const SizedBox(height: 6),
          Center(child: TextButton(onPressed: _busy ? null : widget.onSkip, child: const Text('Skip for now'))),
        ],
      ]),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({super.key});
  @override
  Widget build(BuildContext context) => AppCard(
        color: context.softPrimary,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: G4MColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
          ).animate().scale(begin: const Offset(.3, .3), curve: Curves.elasticOut, duration: 800.ms),
          const SizedBox(height: 14),
          Text('Profile saved', style: context.text.titleMedium).animate().fadeIn(delay: 200.ms),
        ]),
      );
}
