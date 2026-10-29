import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result of a reverse-geocode (OpenStreetMap Nominatim).
class GeoAddress {
  const GeoAddress({this.line1 = '', this.area = '', this.city = '', this.state = '', this.pincode = '', this.display = ''});
  final String line1, area, city, state, pincode, display;
  String get short => [area, city].where((e) => e.isNotEmpty).join(', ');
}

class LocationService {
  LocationService._();

  static const _ua = {'User-Agent': 'Go4Market/1.0 (com.go4market.customer)', 'Accept-Language': 'en'};

  /// Default map centre when nothing else is known (New Delhi).
  static final fallback = const LatLng(28.6139, 77.2090);

  /// Asks for permission when needed. Returns null when unavailable or denied.
  static Future<LatLng?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (e) {
      debugPrint('[g4m] location: $e');
      try {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : LatLng(last.latitude, last.longitude);
      } catch (_) {
        return null;
      }
    }
  }

  static Future<GeoAddress?> reverse(LatLng p) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '${p.latitude}',
        'lon': '${p.longitude}',
        'addressdetails': '1',
      });
      final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final a = Map<String, dynamic>.from((j['address'] as Map?) ?? {});
      String f(List<String> keys) => keys.map((k) => '${a[k] ?? ''}').firstWhere((v) => v.isNotEmpty, orElse: () => '');
      return GeoAddress(
        line1: [f(['house_number']), f(['road', 'pedestrian', 'street'])].where((e) => e.isNotEmpty).join(' '),
        area: f(['suburb', 'neighbourhood', 'quarter', 'village', 'hamlet']),
        city: f(['city', 'town', 'county', 'state_district', 'municipality']),
        state: f(['state']),
        pincode: f(['postcode']),
        display: '${j['display_name'] ?? ''}',
      );
    } catch (e) {
      debugPrint('[g4m] reverse geocode: $e');
      return null;
    }
  }

  static Future<List<(String, LatLng)>> search(String q) async {
    if (q.trim().length < 3) return [];
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {'format': 'jsonv2', 'q': q, 'limit': '6', 'countrycodes': 'in'});
      final r = await http.get(uri, headers: _ua).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final l = jsonDecode(r.body) as List;
      return l
          .map((e) => ('${e['display_name']}', LatLng(double.parse('${e['lat']}'), double.parse('${e['lon']}'))))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
