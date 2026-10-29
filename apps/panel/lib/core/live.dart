import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:g4m_core/g4m_core.dart';

import 'doc.dart';

/// Records every `failed-precondition` (missing / building composite index) seen
/// at runtime so the System page can list them.
class IndexLog extends ChangeNotifier {
  IndexLog._();
  static final instance = IndexLog._();
  final Map<String, String> entries = {}; // label -> message (contains console link)
  void report(String label, String? message) {
    if (entries.containsKey(label)) return;
    entries[label] = message ?? 'Index required';
    debugPrint('[G4M index] $label → $message');
    scheduleMicrotask(notifyListeners);
  }
}

bool isIndexError(Object e) => e is FirebaseException && e.code == 'failed-precondition';

/// Live query that transparently falls back to [fallback] (usually the same query
/// without `orderBy`) while a composite index is missing or still building.
/// Results of the fallback are sorted client-side with [sortFallback].
Stream<List<T>> liveQuery<T>(
  Query<Json> primary,
  T Function(DocumentSnapshot<Json>) map, {
  Query<Json>? fallback,
  int Function(T a, T b)? sortFallback,
  String label = 'query',
  ValueChanged<bool>? onFallback,
}) {
  late StreamController<List<T>> c;
  StreamSubscription? sub;
  void listen(Query<Json> q, bool isFallback) {
    sub = q.snapshots().listen(
      (s) {
        final list = s.docs.map(map).toList();
        if (isFallback && sortFallback != null) list.sort(sortFallback);
        c.add(list);
      },
      onError: (Object e, StackTrace st) {
        if (!isFallback && fallback != null && isIndexError(e)) {
          IndexLog.instance.report(label, (e as FirebaseException).message);
          onFallback?.call(true);
          sub?.cancel();
          listen(fallback, true);
        } else {
          if (isIndexError(e)) IndexLog.instance.report(label, (e as FirebaseException).message);
          c.addError(e, st);
        }
      },
    );
  }

  c = StreamController<List<T>>(
    onListen: () => listen(primary, false),
    onCancel: () => sub?.cancel(),
  );
  return c.stream;
}

Stream<List<Doc>> liveDocs(Query<Json> primary,
        {Query<Json>? fallback, String sortField = 'createdAt', bool desc = true, String label = 'query'}) =>
    liveQuery<Doc>(primary, Doc.fromSnap,
        fallback: fallback,
        label: label,
        sortFallback: (a, b) {
          final x = a[sortField], y = b[sortField];
          final r = _cmp(x, y);
          return desc ? -r : r;
        });

int _cmp(dynamic x, dynamic y) {
  if (x == null && y == null) return 0;
  if (x == null) return -1;
  if (y == null) return 1;
  if (x is Timestamp && y is Timestamp) return x.compareTo(y);
  if (x is num && y is num) return x.compareTo(y);
  return '$x'.compareTo('$y');
}

/// One-shot fetch with the same fallback semantics.
Future<List<Doc>> fetchDocs(Query<Json> primary, {Query<Json>? fallback, String label = 'query'}) async {
  try {
    return (await primary.get()).docs.map(Doc.fromSnap).toList();
  } catch (e) {
    if (fallback != null && isIndexError(e)) {
      IndexLog.instance.report(label, (e as FirebaseException).message);
      return (await fallback.get()).docs.map(Doc.fromSnap).toList();
    }
    rethrow;
  }
}

Stream<Doc?> liveDoc(DocumentReference<Json> ref) =>
    ref.snapshots().map((d) => d.exists ? Doc.fromSnap(d) : null);

/// Live count capped at [cap] (cheap enough for sidebar badges).
Stream<int> liveCount(Query<Json> q, {int cap = 99}) =>
    q.limit(cap).snapshots().map((s) => s.size).handleError((_) {});
