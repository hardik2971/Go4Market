import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/nav.dart';
import 'core/prefs.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';

class Go4MarketApp extends StatelessWidget {
  const Go4MarketApp({super.key});
  static final _light = appTheme(Brightness.light);
  static final _dark = appTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    final prefs = AppPrefs.instance;
    return ListenableBuilder(
      listenable: prefs,
      builder: (context, _) => MaterialApp(
        title: 'Go4Market',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: messengerKey,
        theme: _light,
        darkTheme: _dark,
        themeMode: prefs.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 380),
        themeAnimationCurve: Curves.easeOutCubic,
        locale: prefs.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
