// SPDX-License-Identifier: GPL-3.0-only
// Estimated 1RM and load-at-RPE. Brzycki on effective reps.
import 'dart:math' as math;

import 'model/history.dart';
import 'util.dart';

/// e1RM from a set; effective reps r = reps + RIR. No estimate above 12 effective reps.
double? e1rm(num? load, num reps, [num? rir]) {
  if (load == null || load <= 0 || reps <= 0) return null;
  final r = reps + (rir ?? 0);
  if (r > 12) return null;
  return (load * 36) / (37 - r);
}

/// Load for `reps` at a target RPE: pct = (37 − (reps + (10 − rpe))) / 36.
double loadAtRpe(num e1rmKg, num reps, num rpe, num increment) {
  final pct = (37 - (reps + (10 - rpe))) / 36;
  return roundToStep(e1rmKg * pct, increment);
}

/// Load you could lift for `targetEffectiveReps` (reps + RIR) given an e1RM (no history case).
double e1rmToLoad(num e1rmKg, num targetEffectiveReps, num increment) {
  final r = math.min(12, math.max(1, targetEffectiveReps));
  return roundToStep((e1rmKg * (37 - r)) / 36, increment);
}

/// Best e1RM over the last `n` exposures (dates) of an exercise.
double? bestRecentE1rm(List<LoggedSet> sets, String exerciseId, [int n = 3]) {
  final working = [
    for (final s in sets)
      if (s.exerciseId == exerciseId && !s.isWarmup) s,
  ];
  // Distinct dates, so the order of equal elements cannot matter.
  final sorted = uniq([for (final s in working) s.performedOn])..sort();
  // The reference takes `slice(-n)`: the last n dates, every date when n is 0, and all but the first -n when n is negative.
  final start = -n;
  final dates = sorted.sublist(
    start < 0 ? math.max(sorted.length + start, 0) : math.min(start, sorted.length),
  );
  double? best;
  for (final s in working) {
    if (!dates.contains(s.performedOn)) continue;
    final v = e1rm(s.loadKg, s.reps, s.rir);
    if (v != null && (best == null || v > best)) best = v;
  }
  return best;
}

/// `round1` in the reference's e1rm file. Renamed because the helpers already have a `round1`, for non-null numbers.
double? round1OrNull(num? x) => x == null ? null : jsRound(x * 10) / 10;
