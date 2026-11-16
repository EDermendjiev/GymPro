// SPDX-License-Identifier: GPL-3.0-only
// Strength phases for main lifts. Rules: T-STR-01…05, T-FRQ-03.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

double _halfStep(num x) => jsRound(x * 2) / 2;

double _progress(int weekIndex, int weeks) => weeks <= 1 ? 1 : weekIndex / (weeks - 1);

/// RPE of the top single for a week of a phase.
double singleRpe(BlockKind kind, int weekIndex, int weeks) {
  final t = _progress(weekIndex, weeks);
  if (kind == BlockKind.strengthLoad) {
    return _halfStep(STRENGTH.load.rpe[0] + (STRENGTH.load.rpe[1] - STRENGTH.load.rpe[0]) * t);
  }
  if (kind == BlockKind.strengthPeak) {
    return _halfStep(STRENGTH.peak.rpe[0] + (STRENGTH.peak.rpe[1] - STRENGTH.peak.rpe[0]) * t);
  }
  return _halfStep(STRENGTH.volume.rpe[0] + (STRENGTH.volume.rpe[1] - STRENGTH.volume.rpe[0]) * t);
}

/// Back-off reps for Load (5 → 3) and Peak (4 → 2) phases.
int backoffReps(BlockKind kind, int weekIndex, int weeks) {
  final t = _progress(weekIndex, weeks);
  final [a, b] = kind == BlockKind.strengthPeak ? STRENGTH.peak.reps : STRENGTH.load.backoffReps;
  return jsRound(a + (b - a) * t);
}

int backoffSets(BlockKind kind, int weekIndex, int weeks) {
  if (kind == BlockKind.strengthLoad) return STRENGTH.load.backoffSets;
  if (kind == BlockKind.strengthPeak) return math.max(0, jsRound(2 - 2 * _progress(weekIndex, weeks)));
  return 0;
}

/// Peak length: 2 weeks if Volume+Load lasted 10–12 weeks, 3 if 13–15, 4 if 16+.
int peakWeeks(int volumeLoadWeeks) {
  if (volumeLoadWeeks >= 16) return 4;
  if (volumeLoadWeeks >= 13) return 3;
  return 2;
}

/// The reference tests `if (!e1rmKg)`: null, zero and NaN all mean no estimate.
bool _noEstimate(num? e1rmKg) => e1rmKg == null || e1rmKg == 0 || e1rmKg.isNaN;

double? singleLoad(num? e1rmKg, num rpe, num increment) {
  if (_noEstimate(e1rmKg)) return null;
  return loadAtRpe(e1rmKg!, 1, rpe, increment);
}

double? backoffLoad(num? e1rmKg, int reps, num rpe, num increment) {
  if (_noEstimate(e1rmKg)) return null;
  return loadAtRpe(e1rmKg!, reps, rpe, increment);
}

/// Which block kind comes next (T-STR-01). [testDate] and [today] are ISO dates.
BlockKind nextStrengthKind(BlockKind current, String? testDate, String today) {
  if (current == BlockKind.strengthVolume) return BlockKind.strengthLoad;
  if (current == BlockKind.strengthLoad) {
    if (testDate != null &&
        testDate.isNotEmpty &&
        daysBetween(today, testDate) > 0 &&
        daysBetween(today, testDate) <= 5 * 7) {
      return BlockKind.strengthPeak;
    }
    return BlockKind.strengthVolume;
  }
  return BlockKind.strengthVolume;
}

BlockKind defaultBlockKind(Goal goal) {
  if (goal == Goal.strength) return BlockKind.strengthVolume;
  if (goal == Goal.sportSupport) return BlockKind.sportSupport;
  return BlockKind.hypertrophy;
}

/// `opts?.volumeLoadWeeks` in the reference is the named [volumeLoadWeeks].
int blockWeeks(BlockKind kind, {int? volumeLoadWeeks}) {
  if (kind == BlockKind.strengthPeak) {
    return peakWeeks(volumeLoadWeeks ?? STRENGTH.volume.defaultWeeks + STRENGTH.load.defaultWeeks);
  }
  return BLOCK_WEEKS[kind]!;
}

bool isStrengthKind(BlockKind k) =>
    k == BlockKind.strengthVolume || k == BlockKind.strengthLoad || k == BlockKind.strengthPeak;
