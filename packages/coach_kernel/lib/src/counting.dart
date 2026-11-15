// SPDX-License-Identifier: GPL-3.0-only
// Fractional set counting (T-VOL-05) and the "does this set count" rule (T-VOL-06).
import 'constants.dart';
import 'model/enums.dart';
import 'model/exercise.dart';
import 'model/history.dart';
import 'util.dart';

double muscleWeight(HasMuscles ex, MuscleId m) {
  final em = ex.muscles.where((x) => x.muscle == m).firstOrNull;
  if (em == null) return 0;
  return em.role == MuscleRole.primary ? VOLUME.fractional.primary : VOLUME.fractional.secondary;
}

/// Fractional sets per muscle for `sets` sets of an exercise.
Map<MuscleId, double> fractionalSets(HasMuscles ex, num sets) {
  final out = <MuscleId, double>{};
  for (final em in ex.muscles) {
    out[em.muscle] =
        (out[em.muscle] ?? 0) +
        sets * (em.role == MuscleRole.primary ? VOLUME.fractional.primary : VOLUME.fractional.secondary);
  }
  return out;
}

/// T-VOL-06: ≥4 reps, ≤4 RIR, not a warm-up.
///
/// The reference takes any object with these three fields; here they are named arguments, so a [LoggedSet] is passed
/// as `setCounts(reps: s.reps, rir: s.rir, isWarmup: s.isWarmup)`.
bool setCounts({required int reps, required num? rir, required bool isWarmup}) {
  if (isWarmup) return false;
  if (reps < VOLUME.countingMinReps) return false;
  if (rir != null && rir > VOLUME.countingMaxRir) return false;
  return true;
}

Map<MuscleId, double> emptyMuscleMap() => {for (final m in ALL_MUSCLES) m: 0};

/// Logged fractional sets per muscle between [from, from+days).
Map<MuscleId, double> loggedMuscleSets(
  List<LoggedSet> sets,
  Map<String, HasMuscles> exercises,
  String from, [
  int days = 7,
]) {
  final to = addDays(from, days);
  final out = emptyMuscleMap();
  for (final s in sets) {
    if (s.performedOn.compareTo(from) < 0 || s.performedOn.compareTo(to) >= 0) continue;
    if (!setCounts(reps: s.reps, rir: s.rir, isWarmup: s.isWarmup)) continue;
    final ex = exercises[s.exerciseId];
    if (ex == null) continue;
    for (final em in ex.muscles) {
      out[em.muscle] = out[em.muscle]! + muscleWeight(ex, em.muscle);
    }
  }
  return out;
}
