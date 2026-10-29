import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:g4m_core/g4m_core.dart';

/// Streams that degrade gracefully while the backend is still being seeded:
/// each attempt is tried in order; if one errors (missing composite index ->
/// `failed-precondition`, rules mismatch -> `permission-denied`), the next is used.
/// Typical use: [indexed query with orderBy, same query without orderBy + client sort].
Stream<List<T>> resilientQuery<T>(
  List<Query<Json> Function()> attempts,
  T Function(DocumentSnapshot<Json>) map, {
  int Function(T a, T b)? sort,
}) {
  late StreamController<List<T>> ctrl;
  StreamSubscription<QuerySnapshot<Json>>? sub;
  var i = 0;

  void listen() {
    sub?.cancel();
    sub = attempts[i]().snapshots().listen(
      (s) {
        final list = s.docs.map(map).toList();
        if (sort != null) list.sort(sort);
        ctrl.add(list);
      },
      onError: (Object e, StackTrace st) {
        if (i < attempts.length - 1) {
          i++;
          listen();
        } else {
          ctrl.addError(e, st);
        }
      },
    );
  }

  ctrl = StreamController<List<T>>(
    onListen: listen,
    onCancel: () => sub?.cancel(),
  );
  return ctrl.stream;
}

/// One-shot variant of [resilientQuery].
Future<List<T>> resilientGet<T>(List<Query<Json> Function()> attempts, T Function(DocumentSnapshot<Json>) map) async {
  Object? last;
  for (final a in attempts) {
    try {
      final s = await a().get();
      return s.docs.map(map).toList();
    } catch (e) {
      last = e;
    }
  }
  throw last ?? StateError('No query attempts');
}

/// Newest-first comparator for any model exposing createdAt.
int newestFirst(DateTime? a, DateTime? b) => (b ?? DateTime(2000)).compareTo(a ?? DateTime(2000));

String get myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

/// Human message for Firestore / Functions errors, including "index still building".
String describeError(Object e) {
  final s = e.toString();
  if (s.contains('failed-precondition') && s.contains('index')) {
    return 'Data is still being indexed on the server. Please try again in a few minutes.';
  }
  if (s.contains('permission-denied') || s.contains('PERMISSION_DENIED')) {
    return 'You do not have access to this data yet.';
  }
  if (s.contains('unavailable') || s.contains('network')) {
    return 'You seem to be offline. Check your connection.';
  }
  if (s.contains('not-found') && s.contains('functions')) {
    return 'This service is not available yet. Please try again later.';
  }
  return friendlyError(e);
}

bool isToday(DateTime? d) {
  if (d == null) return false;
  final n = DateTime.now();
  return d.year == n.year && d.month == n.month && d.day == n.day;
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
