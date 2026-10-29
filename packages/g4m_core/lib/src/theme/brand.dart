import 'package:flutter/material.dart';

/// Go4Market brand tokens, derived from the logo (green bag, deep-green arrow, orange chevrons).
abstract final class G4MColors {
  static const primary = Color(0xFF0B8A4F);
  static const primaryDeep = Color(0xFF0A4A33);
  static const primarySoft = Color(0xFFE6F4EC);
  static const accent = Color(0xFFF7860F);
  static const accentSoft = Color(0xFFFFF1E2);

  static const background = Color(0xFFF7FAF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F5F2);
  static const ink = Color(0xFF0F1A14);
  static const inkMuted = Color(0xFF5B6B62);
  static const inkFaint = Color(0xFF94A39A);
  static const line = Color(0xFFE3EBE6);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);

  // Dark mode surfaces (panels support dark mode).
  static const darkBackground = Color(0xFF0B1410);
  static const darkSurface = Color(0xFF121E18);
  static const darkSurfaceAlt = Color(0xFF1A2921);
  static const darkLine = Color(0xFF243A2E);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A4A33), Color(0xFF0B8A4F)],
  );
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9F2E), Color(0xFFF26B0F)],
  );

  /// Soft pastel tints for category tiles / section backgrounds.
  static const pastels = [
    Color(0xFFE8F6EE), Color(0xFFFFF3E3), Color(0xFFEAF1FF), Color(0xFFF6ECFF),
    Color(0xFFFFEDEF), Color(0xFFE9FAF7), Color(0xFFFFF9DB), Color(0xFFEFF3F1),
  ];

  static Color fromHex(String? hex, [Color fallback = primary]) {
    if (hex == null || hex.isEmpty) return fallback;
    final h = hex.replaceFirst('#', '');
    final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
    return v == null ? fallback : Color(v);
  }
}

abstract final class G4MRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const pill = 999.0;
}

abstract final class G4MMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
  static const emphasized = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 700);
  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

abstract final class G4MShadows {
  static const soft = [
    BoxShadow(color: Color(0x0F0A4A33), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x1A0A4A33), blurRadius: 32, offset: Offset(0, 14)),
  ];
  static const glowAccent = [
    BoxShadow(color: Color(0x40F7860F), blurRadius: 24, offset: Offset(0, 10)),
  ];
}
