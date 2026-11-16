// SPDX-License-Identifier: GPL-3.0-only
// One exercise's history, in the shape the progression package reads: one exposure per session that has it.
import 'package:coach_kernel/coach_kernel.dart' as ck;

import '../../models/workout.dart';
import 'history_adapter.dart';

/// The working sets of [exerciseId], one exposure per logged session, oldest first.
///
/// Sessions marked as deload sessions are left out, as the app's own progression leaves them out: a light day
/// says nothing about what the lifter can do. Warm-ups and the continuations of drop, rest-pause and cluster
/// sets are left out by [coachSets]. [increment] is the exercise's load step in kilograms.
ck.ExerciseHistory coachExerciseHistory(
  List<LoggedSession> sessions,
  String exerciseId, {
  required double increment,
  bool heavyLowerBarbell = false,
  ck.Status? status,
}) {
  final relevant = [
    for (final s in sessions)
      if (!s.deload && s.exercises.any((e) => e.id == exerciseId)) s,
  ];
  final sets = coachSets(relevant, since: '0000-01-01', skip: (id) => id != exerciseId);
  final order = <String>[];
  final dates = <String, String>{};
  final bySession = <String, List<ck.ExposureSet>>{};
  for (final s in sets) {
    if (s.isWarmup) continue;
    final key = s.sessionId ?? s.performedOn;
    if (!bySession.containsKey(key)) {
      order.add(key);
      dates[key] = s.performedOn;
      bySession[key] = [];
    }
    bySession[key]!.add(ck.ExposureSet(load: s.loadKg, reps: s.reps, rir: s.rir));
  }
  return ck.ExerciseHistory(
    exposures: [for (final k in order) ck.Exposure(date: dates[k]!, sets: bySession[k]!)],
    increment: increment,
    heavyLowerBarbell: heavyLowerBarbell,
    status: status,
  );
}
