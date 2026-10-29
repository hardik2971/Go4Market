import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

/// Panel theme: G4MTheme with the role / module colour as primary.
ThemeData panelTheme(Brightness b, Color accent) {
  final base = b == Brightness.dark ? G4MTheme.dark() : G4MTheme.light();
  final dark = b == Brightness.dark;
  final line = dark ? G4MColors.darkLine : G4MColors.line;
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(primary: accent, primaryContainer: accent.withValues(alpha: .14)),
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border(line),
      enabledBorder: border(line),
      focusedBorder: border(accent, 1.6),
      errorBorder: border(G4MColors.danger),
      focusedErrorBorder: border(G4MColors.danger, 1.6),
      floatingLabelStyle: TextStyle(color: accent, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(40, 42),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? const Color(0xFFE8F1EC) : G4MColors.ink,
        minimumSize: const Size(40, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: line),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : null),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : null),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: G4MColors.primaryDeep, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      waitDuration: const Duration(milliseconds: 400),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? G4MColors.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: line)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// Semantic colours that adapt to dark mode (core G4MColors are light-only).
class Pal {
  Pal(this.context);
  final BuildContext context;
  bool get dark => Theme.of(context).brightness == Brightness.dark;
  Color get bg => dark ? G4MColors.darkBackground : G4MColors.background;
  Color get surface => dark ? G4MColors.darkSurface : G4MColors.surface;
  Color get surfaceAlt => dark ? G4MColors.darkSurfaceAlt : G4MColors.surfaceAlt;
  Color get line => dark ? G4MColors.darkLine : G4MColors.line;
  Color get ink => dark ? const Color(0xFFE8F1EC) : G4MColors.ink;
  Color get muted => dark ? const Color(0xFF9DB0A5) : G4MColors.inkMuted;
  Color get faint => dark ? const Color(0xFF6F8378) : G4MColors.inkFaint;
  Color get accent => Theme.of(context).colorScheme.primary;
}

extension PalX on BuildContext {
  Pal get pal => Pal(this);
  TextTheme get tt => Theme.of(this).textTheme;
}
