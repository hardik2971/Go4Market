import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:g4m_core/g4m_core.dart';

/// A loosely-typed Firestore document used by the generic tables/forms.
class Doc {
  Doc(this.id, this.data, [this.ref]);
  factory Doc.fromSnap(DocumentSnapshot<Json> s) => Doc(s.id, s.data() ?? <String, dynamic>{}, s.reference);
  final String id;
  final Json data;
  final DocumentReference<Json>? ref;

  dynamic operator [](String key) => getPath(data, key);
  String s(String key, [String f = '']) {
    final v = this[key];
    return v == null ? f : '$v';
  }

  double n(String key, [double f = 0]) {
    final v = this[key];
    return v is num ? v.toDouble() : double.tryParse('$v') ?? f;
  }

  int i(String key, [int f = 0]) => n(key, f.toDouble()).toInt();
  bool b(String key, [bool f = false]) {
    final v = this[key];
    return v is bool ? v : f;
  }

  DateTime? dt(String key) => toDate(this[key]);
  List<String> list(String key) {
    final v = this[key];
    return v is List ? v.map((e) => '$e').toList() : const [];
  }

  DateTime? get createdAt => dt('createdAt');
}

DateTime? toDate(dynamic v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      String s => DateTime.tryParse(s),
      _ => null,
    };

double toNum(dynamic v, [double f = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? f;

/// Reads `a.b.c` from nested maps.
dynamic getPath(Map<String, dynamic> m, String path) {
  if (!path.contains('.')) return m[path];
  dynamic cur = m;
  for (final p in path.split('.')) {
    if (cur is Map) {
      cur = cur[p];
    } else {
      return null;
    }
  }
  return cur;
}

/// Writes `a.b.c` into nested maps (creating intermediate maps).
void setPath(Map<String, dynamic> m, String path, dynamic value) {
  final parts = path.split('.');
  Map<String, dynamic> cur = m;
  for (var i = 0; i < parts.length - 1; i++) {
    final next = cur[parts[i]];
    if (next is Map<String, dynamic>) {
      cur = next;
    } else if (next is Map) {
      cur = cur[parts[i]] = Map<String, dynamic>.from(next);
    } else {
      cur = cur[parts[i]] = <String, dynamic>{};
    }
  }
  cur[parts.last] = value;
}

Map<String, dynamic> deepCopy(Map<String, dynamic> m) => m.map((k, v) => MapEntry(
      k,
      v is Map ? deepCopy(Map<String, dynamic>.from(v)) : v is List ? List.of(v) : v,
    ));
