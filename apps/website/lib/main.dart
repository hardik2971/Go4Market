import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:g4m_core/g4m_core.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app/router.dart';
import 'core/shop.dart';
import 'core/push.dart';
import 'core/web_bridge.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  // Plus Jakarta Sans is bundled (assets/fonts) so every weight is real and nothing is fetched at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  GoRouter.optionURLReflectsImperativeAPIs = true;
  VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 60);
  // Accessible semantics DOM: real links (<a href>) and headings for assistive tech.
  SemanticsBinding.instance.ensureSemantics();
  await initG4MFirebase(G4MClient.website);
  LangController.instance.init();
  Shop.instance.init();
  Push.navigate = appRouter.go;
  Push.overlay = () => appRouter.routerDelegate.navigatorKey.currentState?.overlay;
  Push.instance.init();
  runApp(const G4MWebsite());
  WidgetsBinding.instance.addPostFrameCallback((_) => WebBridge.hideFallback());
}

class G4MWebsite extends StatelessWidget {
  const G4MWebsite({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: LangController.instance, builder: (context, _) => _app());

  Widget _app() {
    final base = _withBundledFont(G4MTheme.light());
    final lang = LangController.instance;
    return MaterialApp.router(
      title: 'Go4Market',
      scaffoldMessengerKey: Push.messengerKey,
      locale: lang.locale,
      supportedLocales: lang.supportedLocales,
      localizationsDelegates: const [
        LDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: base.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        }),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(color: G4MColors.primaryDeep, borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
          waitDuration: const Duration(milliseconds: 400),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(G4MColors.primaryDeep.withValues(alpha: .25)),
          radius: const Radius.circular(8),
          thickness: const WidgetStatePropertyAll(6),
        ),
      ),
      builder: (context, child) => MediaQuery(
        // Keep text scaling sensible across browsers while honouring user zoom.
        data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6)),
        // Pages and the shell are re-keyed per language in app/router.dart. Directionality follows the locale.
        child: child!,
      ),
    );
  }
}

const kFont = 'PlusJakartaSans';

/// Re-points every text style in the shared theme at the bundled font family.
ThemeData _withBundledFont(ThemeData t) {
  final tt = t.textTheme.apply(fontFamily: kFont);
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamily: kFont);
  ButtonStyle? b(ButtonStyle? s) => s?.copyWith(textStyle: WidgetStatePropertyAll(tt.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)));
  return t.copyWith(
    textTheme: tt,
    primaryTextTheme: t.primaryTextTheme.apply(fontFamily: kFont),
    appBarTheme: t.appBarTheme.copyWith(titleTextStyle: f(t.appBarTheme.titleTextStyle)),
    filledButtonTheme: FilledButtonThemeData(style: b(t.filledButtonTheme.style)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: b(t.outlinedButtonTheme.style)),
    textButtonTheme: TextButtonThemeData(style: b(t.textButtonTheme.style)),
    chipTheme: t.chipTheme.copyWith(labelStyle: f(t.chipTheme.labelStyle)),
    snackBarTheme: t.snackBarTheme.copyWith(contentTextStyle: f(t.snackBarTheme.contentTextStyle)),
    navigationBarTheme: t.navigationBarTheme.copyWith(labelTextStyle: WidgetStatePropertyAll(tt.labelSmall?.copyWith(fontWeight: FontWeight.w700))),
    inputDecorationTheme: t.inputDecorationTheme.copyWith(hintStyle: f(t.inputDecorationTheme.hintStyle)),
  );
}
