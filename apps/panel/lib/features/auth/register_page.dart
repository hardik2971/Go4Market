import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:g4m_core/g4m_core.dart' hide Fmt;
import 'package:go_router/go_router.dart';

import '../../core/doc.dart';
import '../../core/session.dart';
import '../../ui/form_kit.dart';
import '../../ui/kit.dart';
import 'login_page.dart';
import 'package:panel/l10n/overrides.dart';

/// Seller onboarding / delivery partner registration wizard.
/// Step 0 (account) is skipped when already signed in.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _values = <String, dynamic>{};
  final _account = <String, dynamic>{};
  final _formKeys = [GlobalKey<EntityFormState>(), GlobalKey<EntityFormState>(), GlobalKey<EntityFormState>()];
  int _step = 0;
  bool _busy = false;
  bool _accepted = false;

  bool get _seller => session.panel == PanelRole.seller;

  @override
  void initState() {
    super.initState();
    if (session.signedIn) {
      _step = 1;
      _values['ownerName'] = _values['name'] = session.user?.displayName ?? session.userDoc?.s('name') ?? '';
      _values['phone'] = session.userDoc?.s('phone') ?? '';
    }
  }

  List<String> get _steps => _seller
      ? ['Account', 'Store details', 'Payout & policies', 'Review']
      : ['Account', 'Personal & vehicle', 'Service area', 'Review'];

  List<F> get _accountFields => const [
        F('name', 'Full name', FT.text, required: true, wide: true),
        F('email', 'Email', FT.email, required: true, wide: true),
        F('phone', 'Mobile number', FT.text, required: true, hint: '+91 98xxxxxx'),
        F('password', 'Password', FT.password, required: true, help: 'At least 8 characters'),
      ];

  List<F> get _step1 => _seller
      ? [
          const F('storeName', 'Store name', FT.text, required: true),
          const F('ownerName', 'Owner name', FT.text, required: true),
          const F('phone', 'Business phone', FT.text, required: true),
          F('city', 'City', FT.select, required: true, optionsStream: () => optionsOf(Fs.cities, 'name', label: (d) => d.s('name')).map((m) => {for (final v in m.values) v: v})),
          const F('address', 'Store address', FT.multiline, required: true),
          const F('gstin', 'GSTIN (optional)', FT.text, uppercase: true),
          const F('moduleIds', 'What do you sell?', FT.multiselect, options: moduleOptions, required: true),
          const F('description', 'About your store', FT.multiline),
        ]
      : [
          const F('name', 'Full name', FT.text, required: true),
          const F('phone', 'Mobile number', FT.text, required: true),
          const F('vehicleType', 'Vehicle type', FT.select, required: true, options: {'bike': 'Motorbike', 'scooter': 'Scooter', 'bicycle': 'Bicycle', 'ev': 'Electric', 'car': 'Car / Van'}),
          const F('vehicleNo', 'Vehicle number', FT.text, uppercase: true, hint: 'MH12AB1234'),
          const F('licenseNo', 'Driving licence no.', FT.text, uppercase: true),
          const F('dob', 'Date of birth', FT.date),
        ];

  List<F> get _step2 => _seller
      ? const [
          F.section('Bank account for payouts', help: 'Earnings are paid to this account after admin approval of withdrawals.'),
          F('bank.holder', 'Account holder', FT.text, required: true),
          F('bank.account', 'Account number', FT.text, required: true),
          F('bank.ifsc', 'IFSC', FT.text, required: true, uppercase: true),
          F('bank.upi', 'UPI ID (optional)', FT.text),
        ]
      : [
          F('cities', 'Cities you can serve', FT.multiselect, required: true, optionsStream: () => optionsOf(Fs.cities, 'name').map((m) => {for (final v in m.values) v: v})),
          const F.section('Payout details'),
          const F('bank.holder', 'Account holder', FT.text),
          const F('bank.account', 'Account number', FT.text),
          const F('bank.ifsc', 'IFSC', FT.text, uppercase: true),
          const F('bank.upi', 'UPI ID', FT.text),
        ];

  Future<void> _next() async {
    if (_step == 0) {
      if (!(_formKeys[0].currentState?.validate() ?? false)) return;
      if ('${_account['password']}'.length < 8) {
        toast(tr('Password must be at least 8 characters'), kind: ToastKind.error);
        return;
      }
      setState(() => _busy = true);
      try {
        await AuthRepo.instance.signUp(
          name: '${_account['name']}'.trim(),
          email: '${_account['email']}'.trim(),
          password: '${_account['password']}',
          phone: '${_account['phone'] ?? ''}'.trim(),
        );
        _values['name'] = _values['ownerName'] = _account['name'];
        _values['phone'] = _account['phone'];
        setState(() => _step = 1);
      } on FirebaseAuthException catch (e) {
        toast(e.code == 'email-already-in-use' ? tr('That email already has an account — sign in instead.') : (e.message ?? e.code), kind: ToastKind.error);
      } catch (e) {
        toastError(e);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    if (_step < 3) {
      if (!(_formKeys[_step].currentState?.validate() ?? false)) return;
      if (_step == 2 && _seller && !_accepted) {
        toast(tr('Please accept the seller policies'), kind: ToastKind.error);
        return;
      }
      setState(() => _step++);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final v = cleanValues(_values);
      if (_seller) {
        await G4MApi.instance.registerSeller({...v, 'email': session.user?.email, 'policiesAccepted': true});
      } else {
        final dob = toDate(v['dob']);
        await G4MApi.instance.registerDeliveryPartner({...v, 'dob': dob?.toIso8601String(), 'email': session.user?.email});
      }
      await session.refreshClaims();
      toast(tr('Application submitted — we will review it shortly'));
    } catch (e) {
      toastError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFrame(
      maxWidth: 600,
      heroTitle: _seller ? 'Open your store in minutes.' : 'Become a Go4Market delivery partner.',
      heroText: _seller
          ? 'Tell us about your business. Our team verifies every seller — most applications are approved within 24 hours.'
          : 'Share your details and the cities you can serve. Once approved you can go online and start earning.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr(_seller ? 'Seller registration' : 'Partner registration'), style: context.tt.headlineSmall),
        const SizedBox(height: 20),
        _stepper(context),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: Offset(L10n.instance.rtl ? -.04 : .04, 0), end: Offset.zero).animate(a), child: c),
          ),
          child: KeyedSubtree(key: ValueKey(_step), child: _body(context)),
        ),
        const SizedBox(height: 24),
        Row(children: [
          if (_step > (session.signedIn && _step >= 1 ? 1 : 0))
            OutlinedButton.icon(onPressed: _busy ? null : () => setState(() => _step--), icon: const Icon(Icons.arrow_back_rounded, size: 18), label: Text(S.back)),
          const Spacer(),
          FilledButton.icon(
            onPressed: _busy ? null : _next,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_step == 3 ? Icons.send_rounded : Icons.arrow_forward_rounded, size: 18),
            label: Text(tr(_step == 0 ? 'Create account' : _step == 3 ? 'Submit application' : 'Continue')),
          ),
        ]),
        const SizedBox(height: 16),
        if (!session.signedIn)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(tr('Already registered? '), style: TextStyle(color: context.pal.muted)),
            TextButton(onPressed: () => context.go('/login'), child: Text(S.signIn)),
          ])
        else
          Center(
            child: TextButton.icon(
              onPressed: session.signOut,
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: Text('${trf('Signed in as {who}', {'who': session.user?.email ?? session.user?.phoneNumber ?? ''})} · ${S.signOut}'),
            ),
          ),
      ]),
    );
  }

  Widget _stepper(BuildContext context) => Row(children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(children: [
              AnimatedContainer(
                duration: G4MMotion.standard,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _step ? G4MColors.success : i == _step ? context.pal.accent : context.pal.surfaceAlt,
                ),
                alignment: Alignment.center,
                child: i < _step
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                    : Text('${i + 1}', style: TextStyle(color: i == _step ? Colors.white : context.pal.muted, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Text(tr(_steps[i]),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, fontWeight: i == _step ? FontWeight.w800 : FontWeight.w500, color: i == _step ? context.pal.ink : context.pal.muted)),
            ]),
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 22),
                height: 2,
                color: i < _step ? G4MColors.success : context.pal.line,
              ),
            ),
        ],
      ]);

  Widget _body(BuildContext context) {
    switch (_step) {
      case 0:
        return EntityForm(key: _formKeys[0], fields: _accountFields, values: _account);
      case 1:
        return EntityForm(key: _formKeys[1], fields: _step1, values: _values);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          EntityForm(key: _formKeys[2], fields: _step2, values: _values),
          if (_seller) ...[
            const SizedBox(height: 20),
            SectionCard(
              title: 'Seller policies',
              icon: Icons.policy_outlined,
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: 180,
                  child: FutureBuilder<CmsPage?>(
                    future: CatalogRepo.instance.page('seller-policy'),
                    builder: (context, s) => SingleChildScrollView(
                      child: MarkdownBody(
                        data: s.data?.content.isNotEmpty == true
                            ? s.data!.content
                            : '- List only genuine products you are licensed to sell.\n- Ship orders within the promised time.\n- Commission is deducted on every delivered order.\n- Payouts are processed via withdrawal requests.',
                      ),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  title: Text(tr('I have read and accept the seller policies and commission terms')),
                ),
              ]),
            ),
          ],
        ]);
      default:
        final v = _values;
        final rows = _seller
            ? [
                ('Store', '${v['storeName'] ?? ''}'),
                ('Owner', '${v['ownerName'] ?? ''}'),
                ('Phone', '${v['phone'] ?? ''}'),
                ('City', '${v['city'] ?? ''}'),
                ('Address', '${v['address'] ?? ''}'),
                ('Modules', (v['moduleIds'] as List?)?.map((e) => moduleOptions[e] ?? e).join(', ') ?? ''),
                ('GSTIN', '${v['gstin'] ?? ''}'),
                ('Bank', '${getPath(v, 'bank.holder') ?? ''} · ${getPath(v, 'bank.account') ?? ''} · ${getPath(v, 'bank.ifsc') ?? ''}'),
              ]
            : [
                ('Name', '${v['name'] ?? ''}'),
                ('Phone', '${v['phone'] ?? ''}'),
                ('Vehicle', '${v['vehicleType'] ?? ''} ${v['vehicleNo'] ?? ''}'),
                ('Licence', '${v['licenseNo'] ?? ''}'),
                ('Cities', (v['cities'] as List?)?.join(', ') ?? ''),
              ];
        return SectionCard(
          title: 'Review your application',
          icon: Icons.fact_check_outlined,
          child: Column(children: [for (final r in rows) InfoRow(r.$1, r.$2)]),
        ).animate().fadeIn();
    }
  }
}

/// Shown while the seller / partner application is pending, rejected or suspended.
class PendingPage extends StatelessWidget {
  const PendingPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final st = session.profileState;
          final (icon, color, title, text) = switch (st) {
            ProfileState.rejected => (
                Icons.cancel_outlined,
                G4MColors.danger,
                tr('Application not approved'),
                '${tr('Unfortunately your application was not approved.')} ${session.profile?.s('reviewNote') ?? ''}\n${tr('Contact support if you think this is a mistake.')}',
              ),
            ProfileState.suspended => (
                Icons.block_rounded,
                G4MColors.danger,
                tr('Account suspended'),
                tr('Your account is currently suspended. Please contact Go4Market support.'),
              ),
            _ => (
                Icons.hourglass_top_rounded,
                G4MColors.warning,
                tr('Application under review'),
                tr('Thanks for applying! Our team is verifying your details. This page updates automatically as soon as you are approved.'),
              ),
          };
          return AuthFrame(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 44),
                ).animate(onPlay: (c) => st == ProfileState.pending ? c.repeat(reverse: true) : null).scale(begin: const Offset(.94, .94), duration: 1200.ms),
              ),
              const SizedBox(height: 24),
              Text(title, textAlign: TextAlign.center, style: context.tt.headlineSmall),
              const SizedBox(height: 10),
              Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted, height: 1.5)),
              const SizedBox(height: 24),
              if (session.profile != null)
                SectionCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow(session.panel == PanelRole.seller ? 'Store' : 'Name', session.displayName),
                    InfoRow('Email', session.user?.email ?? ''),
                    InfoRow('Submitted', Fmt.dateTime(session.profile!.createdAt)),
                    InfoRow('Status', '', valueWidget: Align(alignment: AlignmentDirectional.centerStart, child: statusPill(session.profile!.s('status', 'pending')))),
                  ]),
                ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => runToast(session.refreshClaims, success: tr('Status refreshed')),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(S.refresh),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(onPressed: session.signOut, icon: const Icon(Icons.logout_rounded), label: Text(S.signOut))),
              ]),
            ]),
          );
        },
      );
}
