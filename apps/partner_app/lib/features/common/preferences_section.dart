import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_state.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/partner_theme.dart';
import '../../core/session.dart';
import '../../core/ui.dart';
import '../auth/root_gate.dart';
import 'help_screen.dart';
import 'notifications_screen.dart';

/// Shared preference rows for both role profiles: notifications, theme,
/// language, help, app version and logout.
class PreferencesSection extends StatelessWidget {
  const PreferencesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(context.s.settings),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            MenuTile(
              icon: Icons.notifications_none_rounded,
              title: context.s.notifications,
              onTap: () => Go.push(context, const NotificationsScreen()),
            ),
            MenuTile(
              icon: context.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              title: context.s.darkMode,
              onTap: () => app.setThemeMode(context.isDark ? ThemeMode.light : ThemeMode.dark),
              trailing: Switch(
                value: context.isDark,
                onChanged: (v) => app.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ),
            MenuTile(
              icon: Icons.translate_rounded,
              title: context.s.language,
              subtitle: app.lang == 'hi' ? 'हिन्दी' : 'English',
              onTap: () => _pickLanguage(context),
            ),
            MenuTile(
              icon: Icons.help_outline_rounded,
              title: context.s.helpFaq,
              onTap: () => Go.push(context, const HelpScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: MenuTile(
            icon: Icons.logout_rounded,
            title: context.s.logout,
            color: const Color(0xFFDC2626),
            trailing: const SizedBox.shrink(),
            onTap: () async {
              final ok = await confirmDialog(context,
                  title: context.tr('Log out?', 'लॉग आउट करें?'),
                  message: Session.instance.role == PartnerRole.delivery
                      ? context.tr('You will be set offline.', 'आप ऑफ़लाइन हो जाएंगे।')
                      : null,
                  confirmText: context.s.logout,
                  danger: true);
              if (!ok || !context.mounted) return;
              await runBusy(context, () => Session.instance.signOut());
              if (context.mounted) Go.root(context, const RootGate());
            },
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, s) => Text(
            'Go4Market Partner ${s.data == null ? '' : 'v${s.data!.version} (${s.data!.buildNumber})'}',
            textAlign: TextAlign.center,
            style: context.tt.bodySmall?.copyWith(color: context.rc.faint),
          ),
        ),
      ]),
    );
  }

  void _pickLanguage(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (code, name) in const [('en', 'English'), ('hi', 'हिन्दी (Hindi)')])
            ListTile(
              title: Text(name),
              trailing: AppState.instance.lang == code ? Icon(Icons.check_circle_rounded, color: c.rc.brand) : null,
              onTap: () {
                AppState.instance.setLang(code);
                Navigator.pop(c);
              },
            ),
        ]),
      ),
    );
  }
}
