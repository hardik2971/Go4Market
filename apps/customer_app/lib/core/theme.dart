import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

/// App themes = G4MTheme + shared-axis page transitions + a few mobile refinements.
ThemeData appTheme(Brightness b) {
  final base = b == Brightness.dark ? G4MTheme.dark() : G4MTheme.light();
  final dark = b == Brightness.dark;
  return base.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: SharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.horizontal),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: dark ? G4MColors.darkSurface : G4MColors.surface,
      modalBackgroundColor: dark ? G4MColors.darkSurface : G4MColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: base.dialogTheme.copyWith(surfaceTintColor: Colors.transparent),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: G4MColors.primary),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? G4MColors.primary : null),
    ),
  );
}

/// Theme-aware helpers for the few colours g4m_core hardcodes for light mode.
extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get ink => Theme.of(this).colorScheme.onSurface;
  Color get muted => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get card => isDark ? G4MColors.darkSurface : G4MColors.surface;
  Color get cardAlt => isDark ? G4MColors.darkSurfaceAlt : G4MColors.surfaceAlt;
  Color get line => isDark ? G4MColors.darkLine : G4MColors.line;
  Color get softPrimary => isDark ? const Color(0xFF15372A) : G4MColors.primarySoft;
  Color get softAccent => isDark ? const Color(0xFF3A2711) : G4MColors.accentSoft;
  List<BoxShadow> get softShadow => isDark ? const [] : G4MShadows.soft;
}
