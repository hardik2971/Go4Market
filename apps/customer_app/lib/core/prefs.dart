import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shopping location chosen by the user (city level + optional exact point).
class ShopLocation {
  const ShopLocation({required this.label, this.city = '', this.lat, this.lng, this.pincode = ''});
  final String label;
  final String city;
  final double? lat;
  final double? lng;
  final String pincode;

  bool get hasPoint => lat != null && lng != null;

  Map<String, dynamic> toJson() => {'label': label, 'city': city, 'lat': lat, 'lng': lng, 'pincode': pincode};
  factory ShopLocation.fromJson(Map<String, dynamic> j) => ShopLocation(
        label: '${j['label'] ?? ''}',
        city: '${j['city'] ?? ''}',
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        pincode: '${j['pincode'] ?? ''}',
      );
}

/// Device-local preferences: theme, language, onboarding, module, location, list layout.
class AppPrefs extends ChangeNotifier {
  AppPrefs._();
  static final instance = AppPrefs._();
  late SharedPreferences _p;

  ThemeMode themeMode = ThemeMode.light;
  Locale locale = const Locale('en');
  bool onboardingSeen = false;
  String moduleId = 'grocery';
  ShopLocation? location;
  bool gridView = true;
  List<String> recentSearches = [];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values.firstWhere((m) => m.name == _p.getString('theme'), orElse: () => ThemeMode.light);
    locale = Locale(_p.getString('locale') ?? 'en');
    onboardingSeen = _p.getBool('onboardingSeen') ?? false;
    moduleId = _p.getString('moduleId') ?? 'grocery';
    gridView = _p.getBool('gridView') ?? true;
    recentSearches = _p.getStringList('recentSearches') ?? [];
    final loc = _p.getString('location');
    if (loc != null) {
      try {
        location = ShopLocation.fromJson(jsonDecode(loc) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    _p.setString('theme', m.name);
    notifyListeners();
  }

  void setLocale(Locale l) {
    locale = l;
    _p.setString('locale', l.languageCode);
    notifyListeners();
  }

  void setOnboardingSeen() {
    onboardingSeen = true;
    _p.setBool('onboardingSeen', true);
  }

  void setModule(String id) {
    if (id == moduleId) return;
    moduleId = id;
    _p.setString('moduleId', id);
    notifyListeners();
  }

  void setLocation(ShopLocation l) {
    location = l;
    _p.setString('location', jsonEncode(l.toJson()));
    notifyListeners();
  }

  void setGridView(bool v) {
    gridView = v;
    _p.setBool('gridView', v);
    notifyListeners();
  }

  void addRecentSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    recentSearches = [t, ...recentSearches.where((e) => e.toLowerCase() != t.toLowerCase())].take(8).toList();
    _p.setStringList('recentSearches', recentSearches);
  }

  void clearRecentSearches() {
    recentSearches = [];
    _p.remove('recentSearches');
    notifyListeners();
  }

  /// Popups are shown at most once a day each.
  bool popupSeenToday(String id) => _p.getString('popup_$id') == _today();
  void markPopupSeen(String id) => _p.setString('popup_$id', _today());
  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}
