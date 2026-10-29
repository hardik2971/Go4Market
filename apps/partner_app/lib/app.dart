import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/partner_theme.dart';
import 'core/push.dart';
import 'features/common/version_gate.dart';
import 'features/splash/splash_screen.dart';

class PartnerApp extends StatelessWidget {
  const PartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'Go4Market Partner',
        debugShowCheckedModeBanner: false,
        navigatorKey: navKey,
        theme: PartnerTheme.build(app.roleTint, Brightness.light),
        darkTheme: PartnerTheme.build(app.roleTint, Brightness.dark),
        themeMode: app.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 420),
        themeAnimationCurve: Curves.easeOutCubic,
        // Material widgets stay in English (see core/l10n.dart); app strings follow AppState.lang.
        locale: const Locale('en', 'IN'),
        builder: (context, child) => VersionGate(child: child ?? const SizedBox.shrink()),
        home: const SplashScreen(),
      ),
    );
  }
}
