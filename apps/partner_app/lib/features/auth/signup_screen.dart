import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/l10n.dart';
import '../../core/live.dart';
import '../../core/partner_theme.dart';
import '../../core/ui.dart';

/// Creates a Firebase Auth account. `onUserCreated` sets the `customer` claim; the
/// RootGate then shows the role chooser, and registration upgrades the claim.
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
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthRepo.instance.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _pass.text,
        phone: _phone.text.trim(),
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      toast(
        context,
        s.contains('email-already-in-use')
            ? context.tr('This email is already registered. Please log in.', 'यह ईमेल पहले से पंजीकृत है। लॉग इन करें।')
            : s.contains('weak-password')
                ? context.tr('Choose a stronger password.', 'मज़बूत पासवर्ड चुनें।')
                : describeError(e),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      TextFormField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: context.s.fullName, prefixIcon: const Icon(Icons.person_outline_rounded)),
        validator: (v) => (v ?? '').trim().length >= 2 ? null : context.tr('Enter your name', 'अपना नाम दर्ज करें'),
      ),
      TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: context.s.email, prefixIcon: const Icon(Icons.alternate_email_rounded)),
        validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : context.tr('Enter a valid email', 'सही ईमेल दर्ज करें'),
      ),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(labelText: context.s.phone, prefixText: '+91 ', prefixIcon: const Icon(Icons.phone_outlined)),
        validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch((v ?? '').replaceAll(' ', ''))
            ? null
            : context.tr('Enter a 10-digit mobile number', '10 अंकों का मोबाइल नंबर दर्ज करें'),
      ),
      TextFormField(
        controller: _pass,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: context.s.password,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: (v) => (v ?? '').length >= 8 ? null : context.tr('At least 8 characters', 'कम से कम 8 अक्षर'),
      ),
    ];
    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
          Text(context.s.createAccount, style: context.tt.headlineMedium).animate().fadeIn().slideY(begin: .2),
          const SizedBox(height: 6),
          Text(
            context.tr('One account to sell or deliver with Go4Market. You will choose your role next.',
                'Go4Market पर बेचने या डिलीवरी के लिए एक खाता। अगले चरण में अपनी भूमिका चुनें।'),
            style: context.tt.bodyMedium?.copyWith(color: context.rc.muted),
          ).animate().fadeIn(delay: 80.ms),
          const SizedBox(height: 24),
          for (var i = 0; i < fields.length; i++) Padding(padding: const EdgeInsets.only(bottom: 14), child: fields[i].stagger(i + 1)),
          const SizedBox(height: 8),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                  : Text(context.s.continueBtn),
            ),
          ).stagger(6),
        ]),
      ),
    );
  }
}

extension on Widget {
  Widget stagger(int i) => animate(delay: (i * 50).ms).fadeIn(duration: 350.ms).slideY(begin: .15, curve: Curves.easeOutCubic);
}
