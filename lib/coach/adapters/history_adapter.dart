// SPDX-License-Identifier: GPL-3.0-only
// The app's workout log, in the shape the coach packages read.
//
// Both sides have a type called LoggedSet, so the kernel is imported with a prefix here.
import 'package:coach_kernel/coach_kernel.dart' as ck;

import '../../models/workout.dart';

bool _never(String _) => false;

/// Every strength set logged on or after [since] (an ISO date), oldest session first.
///
/// What is left out:
///  - exercises for which [skip] answers true. The caller passes its cardio, timed and stretch exercises, since
///    only the app's state knows which those are;
///  - exercises that were logged with a distance or as a hold, whatever [skip] says;
///  - rows with no reps;
///  - the continuation of a drop, rest-pause or cluster set. Such a group counts once, by its first set: the
///    working set it follows, or its own first row when no working set comes before it.
///
/// [bodyweight] says which exercises are done with the body alone. An unloaded set of one of those has no load
/// at all (null), where an unloaded set of anything else has a load of zero.
///
/// Sets are numbered from zero per exercise within a session, working sets and warm-ups each on their own.
List<ck.LoggedSet> coachSets(
  List<LoggedSession> sessions, {
  required String since,
  bool Function(String exerciseId) skip = _never,
  bool Function(String exerciseId) bodyweight = _never,
}) {
  final kept = <(LoggedSession, String)>[];
  for (final s in sessions) {
    final day = _isoDay(s.day);
    if (day.compareTo(since) >= 0) kept.add((s, day));
  }
  // The log is stored in no guaranteed order. Ties keep their stored order.
  final order = List<int>.generate(kept.length, (i) => i)
    ..sort((a, b) {
      final c = kept[a].$1.date.compareTo(kept[b].$1.date);
      return c != 0 ? c : a.compareTo(b);
    });

  final out = <ck.LoggedSet>[];
  for (final i in order) {
    final (session, day) = kept[i];
    final loggedAt = session.date.toIso8601String();
    final sessionId = coachSessionId(loggedAt);
    final working = <String, int>{};
    final warmups = <String, int>{};
    for (final e in session.exercises) {
      if (skip(e.id) || _cardioOrHold(e)) continue;
      final unloadedIsNull = bodyweight(e.id);
      var inGroup = false; // a working set has been seen since the last warm-up
      for (final s in e.sets) {
        final warmup = s.kind == SetKind.warmup;
        if (warmup) {
          inGroup = false;
        } else {
          final continuation = inGroup && _continues(s.kind);
          inGroup = true;
          if (continuation) continue;
        }
        final reps = s.sided ? (s.left! < s.right! ? s.left! : s.right!) : s.reps;
        if (reps <= 0) continue;
        final counter = warmup ? warmups : working;
        final index = counter[e.id] ?? 0;
        counter[e.id] = index + 1;
        final rpe = s.rpe;
        out.add(
          ck.LoggedSet(
            exerciseId: e.id,
            performedOn: day,
            setIndex: index,
            loadKg: s.weight == 0 && unloadedIsNull ? null : s.weight,
            reps: reps,
            rir: rpe == null ? null : (rpe >= 10 ? 0 : 10 - rpe),
            isWarmup: warmup,
            sessionId: sessionId,
            loggedAt: loggedAt,
          ),
        );
      }
    }
  }
  return out;
}

/// A short id for a session, derived from the stored text of its date and from nothing else, so it is the same
/// on every run, on every platform and in every time zone.
String coachSessionId(String isoDate) {
  var forward = _fnvBasis;
  var backward = _fnvBasis;
  final n = isoDate.length;
  for (var i = 0; i < n; i++) {
    forward = _fnvStep(forward, isoDate.codeUnitAt(i));
    backward = _fnvStep(backward, isoDate.codeUnitAt(n - 1 - i));
  }
  return _hex8(forward) + _hex8(backward);
}

bool _continues(SetKind k) => k == SetKind.drop || k == SetKind.restPause || k == SetKind.cluster;

bool _cardioOrHold(LoggedExercise e) {
  for (final s in e.sets) {
    if ((s.km ?? 0) > 0) return true;
    if (s.sec != null && s.reps <= 0) return true;
  }
  return false;
}

String _isoDay(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month < 10 ? '0${d.month}' : '${d.month}';
  final day = d.day < 10 ? '0${d.day}' : '${d.day}';
  return '$y-$m-$day';
}

// 32-bit FNV-1a, run once in each direction. The multiplication is done in two halves so every intermediate
// value stays an exact integer on the web as well.
const int _fnvBasis = 0x811c9dc5;
const int _fnvPrime = 0x01000193;

int _fnvStep(int hash, int codeUnit) {
  final x = (hash ^ codeUnit) & 0xffffffff;
  final low = (x & 0xffff) * _fnvPrime;
  final high = (((x >> 16) & 0xffff) * _fnvPrime) & 0xffff;
  return (low + high * 0x10000) & 0xffffffff;
}

String _hex8(int v) => v.toRadixString(16).padLeft(8, '0');
