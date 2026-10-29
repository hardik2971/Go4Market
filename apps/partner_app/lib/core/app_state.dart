import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two partner roles this app serves. Mirrors the `role` custom claim.
enum PartnerRole { seller, delivery }

extension PartnerRoleX on PartnerRole {
  String get claim => this == PartnerRole.seller ? 'seller' : 'delivery';
  String get topic => this == PartnerRole.seller ? 'sellers' : 'delivery';
  static PartnerRole? fromClaim(String? c) => switch (c) {
        'seller' => PartnerRole.seller,
        'delivery' => PartnerRole.delivery,
        _ => null,
      };
}

/// App-wide preferences (theme, language, onboarding, preferred role tint).
/// A single [ChangeNotifier] keeps the app free of extra state packages.
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  late SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.light;
  String lang = 'en'; // 'en' | 'hi'
  bool onboardingSeen = false;

  /// Tint used before the role claim is known (login screen toggle, chooser).
  PartnerRole roleTint = PartnerRole.seller;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode = switch (_prefs.getString('themeMode')) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    lang = _prefs.getString('lang') ?? 'en';
    onboardingSeen = _prefs.getBool('onboardingSeen') ?? false;
    roleTint = _prefs.getString('roleTint') == 'delivery' ? PartnerRole.delivery : PartnerRole.seller;
  }

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _prefs.setString('themeMode', m.name);
    notifyListeners();
  }

  void setLang(String l) {
    lang = l;
    _prefs.setString('lang', l);
    notifyListeners();
  }

  void setOnboardingSeen() {
    onboardingSeen = true;
    _prefs.setBool('onboardingSeen', true);
  }

  void setRoleTint(PartnerRole r) {
    if (roleTint == r) return;
    roleTint = r;
    _prefs.setString('roleTint', r.claim);
    notifyListeners();
  }

  /// Generic small persisted values for features (e.g. last seen order ids).
  String? getString(String k) => _prefs.getString(k);
  Future<void> setString(String k, String v) => _prefs.setString(k, v);
}
