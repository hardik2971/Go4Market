import 'package:flutter/material.dart';
import 'package:g4m_core/g4m_core.dart';

import 'app_state.dart';
import 'motion.dart';

/// Role-specific palette exposed as a ThemeExtension: `context.rc.brand` etc.
///
/// Seller  -> deep green brand, green highlights.
/// Delivery -> deep green buttons/headings with orange highlights (indicators, toggles, hero cards).
@immutable
class RoleColors extends ThemeExtension<RoleColors> {
  const RoleColors({
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.highlight,
    required this.highlightSoft,
    required this.hero,
    required this.onHero,
    required this.card,
    required this.cardAlt,
    required this.muted,
    required this.faint,
    required this.line,
    required this.ink,
    required this.skeletonBase,
    required this.skeletonShine,
  });

  final Color brand, brandDeep, brandSoft, highlight, highlightSoft, onHero;
  final Gradient hero;
  final Color card, cardAlt, muted, faint, line, ink, skeletonBase, skeletonShine;

  static RoleColors of(PartnerRole role, Brightness b) {
    final dark = b == Brightness.dark;
    final seller = role == PartnerRole.seller;
    return RoleColors(
      brand: seller ? G4MColors.primary : G4MColors.accent,
      brandDeep: G4MColors.primaryDeep,
      brandSoft: seller
          ? (dark ? const Color(0xFF15372A) : G4MColors.primarySoft)
          : (dark ? const Color(0xFF3A2A16) : G4MColors.accentSoft),
      highlight: seller ? G4MColors.primary : G4MColors.accent,
      highlightSoft: seller
          ? (dark ? const Color(0xFF15372A) : G4MColors.primarySoft)
          : (dark ? const Color(0xFF3A2A16) : G4MColors.accentSoft),
      hero: seller
          ? G4MColors.heroGradient
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A4A33), Color(0xFF0E5F3F), Color(0xFFB4610C)],
              stops: [0, .55, 1.2],
            ),
      onHero: Colors.white,
      card: dark ? G4MColors.darkSurface : G4MColors.surface,
      cardAlt: dark ? G4MColors.darkSurfaceAlt : G4MColors.surfaceAlt,
      muted: dark ? const Color(0xFF9DB0A5) : G4MColors.inkMuted,
      faint: dark ? const Color(0xFF6E8277) : G4MColors.inkFaint,
      line: dark ? G4MColors.darkLine : G4MColors.line,
      ink: dark ? const Color(0xFFE8F1EC) : G4MColors.ink,
      skeletonBase: dark ? const Color(0xFF1A2921) : const Color(0xFFEDF2EF),
      skeletonShine: dark ? const Color(0xFF243A2E) : const Color(0xFFF7FAF8),
    );
  }

  @override
  RoleColors copyWith() => this;

  @override
  RoleColors lerp(ThemeExtension<RoleColors>? other, double t) {
    if (other is! RoleColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return RoleColors(
      brand: l(brand, other.brand),
      brandDeep: l(brandDeep, other.brandDeep),
      brandSoft: l(brandSoft, other.brandSoft),
      highlight: l(highlight, other.highlight),
      highlightSoft: l(highlightSoft, other.highlightSoft),
      hero: Gradient.lerp(hero, other.hero, t)!,
      onHero: l(onHero, other.onHero),
      card: l(card, other.card),
      cardAlt: l(cardAlt, other.cardAlt),
      muted: l(muted, other.muted),
      faint: l(faint, other.faint),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      skeletonBase: l(skeletonBase, other.skeletonBase),
      skeletonShine: l(skeletonShine, other.skeletonShine),
    );
  }
}

extension RoleColorsX on BuildContext {
  RoleColors get rc => Theme.of(this).extension<RoleColors>()!;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

abstract final class PartnerTheme {
  static ThemeData build(PartnerRole role, Brightness b) {
    final base = b == Brightness.dark ? G4MTheme.dark() : G4MTheme.light();
    final rc = RoleColors.of(role, b);
    final seller = role == PartnerRole.seller;
    final buttonBg = seller ? G4MColors.primary : G4MColors.primaryDeep;
    final dark = b == Brightness.dark;
    return base.copyWith(
      extensions: [rc],
      colorScheme: base.colorScheme.copyWith(
        primary: dark && !seller ? const Color(0xFF2FAF74) : (seller ? G4MColors.primary : G4MColors.primaryDeep),
        secondary: rc.highlight,
        primaryContainer: rc.brandSoft,
        onPrimaryContainer: dark ? Colors.white : G4MColors.primaryDeep,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? rc.line : buttonBg,
          ),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: rc.highlightSoft,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? (seller ? G4MColors.primary : G4MColors.accent) : rc.muted,
            )),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? rc.highlight : null),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: rc.highlight),
      tabBarTheme: TabBarThemeData(
        labelColor: rc.ink,
        unselectedLabelColor: rc.muted,
        indicatorColor: rc.highlight,
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.start,
        labelStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonBg,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(G4MRadius.md)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: G4MPageTransitionsBuilder(),
        TargetPlatform.iOS: G4MPageTransitionsBuilder(),
      }),
    );
  }
}
