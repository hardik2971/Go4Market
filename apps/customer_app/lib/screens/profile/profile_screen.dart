import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import '../../core/data.dart';
import '../../core/nav.dart';
import '../../core/prefs.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/ui.dart';
import '../auth/auth_screens.dart';
import '../shell/main_shell.dart';
import '../wallet/wallet_screen.dart';
import '../wishlist/wishlist_screen.dart';
import 'addresses_screen.dart';
import 'help_screen.dart';
import 'info_screens.dart';
import 'notifications_screen.dart';
import '../../core/validators.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: Session.instance.epoch,
      builder: (context, _, _) {
        final guest = Session.instance.isGuest;
        return Scaffold(
          body: ValueListenableBuilder<AppUser?>(
            valueListenable: Session.instance.profile,
            builder: (context, u, _) {
              var i = 0;
              Widget s(Widget w) => w.stagger(i++);
              return CustomScrollView(slivers: [
                SliverAppBar(title: Text(l.account), pinned: true),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, kNavPad),
                  sliver: SliverList.list(children: [
                    s(guest ? _GuestCard(l: l) : _ProfileHeader(user: u)),
                    const SizedBox(height: 14),
                    if (!guest)
                      s(Row(children: [
                        _QuickTile(icon: Icons.receipt_long_rounded, label: l.orders, onTap: () => shellTab.value = 3),
                        _QuickTile(
                          icon: Icons.account_balance_wallet_rounded,
                          label: Fmt.money(u?.walletBalance ?? 0),
                          sub: l.wallet,
                          onTap: () => context.push(const WalletScreen()),
                        ),
                        _QuickTile(icon: Icons.favorite_rounded, label: l.wishlist, onTap: () => context.push(const WishlistScreen())),
                        _QuickTile(icon: Icons.location_on_rounded, label: 'Addresses', onTap: () => context.push(const AddressesScreen())),
                      ])),
                    if (!guest) ...[
                      const SizedBox(height: 18),
                      s(_Group(children: [
                        _Item(Icons.notifications_none_rounded, l.notifications, () => context.push(const NotificationsScreen())),
                        _Item(Icons.card_giftcard_rounded, l.referEarn, () => context.push(const ReferScreen()), accent: true),
                        _Item(Icons.workspace_premium_outlined, l.membership, () => context.push(const MembershipScreen())),
                        _Item(Icons.autorenew_rounded, l.subscriptions, () => context.push(const SubscriptionsScreen())),
                        _Item(Icons.add_box_outlined, l.requestProduct, () => context.push(const ProductRequestScreen())),
                      ])),
                    ],
                    const SizedBox(height: 18),
                    s(_Label(l.preferences)),
                    s(_Group(children: [
                      _ThemeRow(l: l),
                      _Item(Icons.translate_rounded, l.language, () => _language(context), trailing: Text(AppPrefs.instance.locale.languageCode == 'hi' ? 'हिन्दी' : 'English')),
                    ])),
                    const SizedBox(height: 18),
                    s(_Label(l.information)),
                    s(_Group(children: [
                      _Item(Icons.help_outline_rounded, l.faqs, () => context.push(const FaqScreen())),
                      _Item(Icons.support_agent_rounded, l.help, () => context.push(const HelpScreen())),
                      for (final p in const [
                        ('about', 'About us', Icons.info_outline_rounded),
                        ('terms', 'Terms & conditions', Icons.description_outlined),
                        ('privacy', 'Privacy policy', Icons.privacy_tip_outlined),
                        ('refund', 'Refund policy', Icons.currency_rupee_rounded),
                        ('shipping', 'Shipping policy', Icons.local_shipping_outlined),
                        ('cancellation', 'Cancellation policy', Icons.event_busy_outlined),
                      ])
                        _Item(p.$3, p.$2, () => context.push(CmsPageScreen(slug: p.$1, title: p.$2))),
                    ])),
                    const SizedBox(height: 18),
                    if (Session.instance.signedIn)
                      s(OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: G4MColors.danger, side: BorderSide(color: G4MColors.danger.withValues(alpha: .35))),
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(guest ? 'Exit guest mode' : l.logout),
                      )),
                    const SizedBox(height: 18),
                    Center(child: Opacity(opacity: .7, child: G4MWordmark(size: 26, light: context.isDark))),
                    const SizedBox(height: 4),
                    Center(child: Text(AppConfig.platform.value.tagline, style: context.text.bodySmall)),
                  ]),
                ),
              ]);
            },
          ),
        );
      },
    );
  }

  Future<void> _language(BuildContext context) async {
    final code = await showAppSheet<String>(
      context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<String>(
          groupValue: AppPrefs.instance.locale.languageCode,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            RadioListTile<String>(value: 'en', title: Text('English'), subtitle: Text('English')),
            RadioListTile<String>(value: 'hi', title: Text('हिन्दी'), subtitle: Text('Hindi')),
            SizedBox(height: 12),
          ]),
        ),
      ),
    );
    if (code != null) AppPrefs.instance.setLocale(Locale(code));
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your cart stays saved on this account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await Session.instance.signOut();
    if (context.mounted) context.replaceAll(const LoginScreen(root: true));
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.l});
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(24), boxShadow: G4MShadows.lifted),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.person_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 10),
          Text(l.signInPrompt, style: context.text.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Your guest cart moves with you when you log in.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: G4MColors.accent),
            onPressed: () => requireAccount(context),
            child: Text('${l.login} / ${l.signup}'),
          ),
        ]),
      );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final AppUser? user;
  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = u?.name ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Shopper';
    final member = u != null && u.membership.isNotEmpty && asDate(u.membership['expiresAt'])?.isAfter(DateTime.now()) == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: G4MColors.heroGradient, borderRadius: BorderRadius.circular(24), boxShadow: G4MShadows.lifted),
      child: Row(children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: Colors.white24,
          backgroundImage: (u?.photoUrl ?? '').isNotEmpty ? NetworkImage(u!.photoUrl) : null,
          child: (u?.photoUrl ?? '').isNotEmpty
              ? null
              : Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: context.text.titleLarge?.copyWith(color: Colors.white)),
            Text(u?.email ?? FirebaseAuth.instance.currentUser?.email ?? '', style: const TextStyle(color: Colors.white70)),
            if (member) ...[
              const SizedBox(height: 6),
              const Tag('MEMBER', icon: Icons.workspace_premium_rounded),
            ],
          ]),
        ),
        IconButton(
          onPressed: () => context.push(const EditProfileScreen()),
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
      ]),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, required this.onTap, this.sub});
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            onTap: onTap,
            child: Column(children: [
              Icon(icon, color: G4MColors.primary),
              const SizedBox(height: 6),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (sub != null) Text(sub!, style: context.text.bodySmall?.copyWith(fontSize: 10.5)),
            ]),
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 8),
        child: Text(text.toUpperCase(), style: context.text.labelSmall?.copyWith(letterSpacing: 1.1, color: context.muted, fontWeight: FontWeight.w800)),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: context.line),
            children[i],
          ],
        ]),
      );
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.onTap, {this.trailing, this.accent = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool accent;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: accent ? context.softAccent : context.softPrimary, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: accent ? G4MColors.accent : G4MColors.primary),
        ),
        title: Text(label, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (trailing != null) DefaultTextStyle(style: context.text.bodySmall!, child: trailing!),
          const Icon(Icons.chevron_right_rounded),
        ]),
      );
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.l});
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: context.softPrimary, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.dark_mode_outlined, size: 20, color: G4MColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(l.theme, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 18)),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded, size: 18)),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 18)),
            ],
            selected: {AppPrefs.instance.themeMode},
            onSelectionChanged: (s) => AppPrefs.instance.setTheme(s.first),
          ),
        ]),
      );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final u = Session.instance.profile.value;
  late final _name = TextEditingController(text: u?.name ?? '');
  late final _phone = TextEditingController(text: Validators.localIndian(u?.phone));
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().length < 2) return context.toast('Enter your name', error: true);
    setState(() => _busy = true);
    try {
      await ShopperRepoX.updateProfile(name: _name.text.trim(), phone: _phone.text.trim());
      if (mounted) {
        context.toast('Profile updated');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) context.toast(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined), prefixText: '+91 '),
          ),
          const SizedBox(height: 12),
          TextField(
            enabled: false,
            controller: TextEditingController(text: u?.email ?? FirebaseAuth.instance.currentUser?.email ?? ''),
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final email = FirebaseAuth.instance.currentUser?.email;
              if (email == null) return;
              await AuthRepo.instance.resetPassword(email);
              if (context.mounted) context.toast('Password reset link sent to $email');
            },
            child: const Text('Change password'),
          ),
        ]),
      );
}

/// Profile write helpers not present in g4m_core.
abstract final class ShopperRepoX {
  static Future<void> updateProfile({required String name, String? phone}) async {
    final user = FirebaseAuth.instance.currentUser!;
    await user.updateDisplayName(name);
    await Fs.user(user.uid).set({'name': name, 'phone': ?phone, 'updatedAt': Fs.now}, SetOptions(merge: true));
  }
}
