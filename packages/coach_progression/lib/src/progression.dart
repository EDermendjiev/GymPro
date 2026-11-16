// SPDX-License-Identifier: GPL-3.0-only
// Autoregulated double progression. Rules: T-PRG-01…06.
// ignore_for_file: constant_identifier_names
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

import 'prescription.dart' show jsNum;

/// Called after each logged set: what should the next set look like?
SetSuggestion suggestNextSet(SetContext ctx) {
  final SetContext(:rx, :setIndex, :load, :reps, :increment) = ctx;
  if (setIndex == 0) {
    if (reps >= rx.repMin && reps <= rx.repMax) {
      return SetSuggestion(load: load, repsTarget: reps, ruleIds: ['T-PRG-02']);
    }
    if (load == null) {
      return SetSuggestion(load: load, repsTarget: reps < rx.repMin ? rx.repMin : rx.repMin + 1, ruleIds: ['T-PRG-03']);
    }
    if (reps < rx.repMin) {
      final next = roundDownToStep(load * (1 - PROGRESSION.loadAdjustPerRep * (rx.repMin - reps)), increment);
      return SetSuggestion(load: math.max(0, next).toDouble(), repsTarget: rx.repMin, ruleIds: ['T-PRG-03']);
    }
    final next = roundUpToStep(load * (1 + PROGRESSION.loadAdjustPerRep * (reps - rx.repMax)), increment);
    return SetSuggestion(load: next, repsTarget: rx.repMin + 1, ruleIds: ['T-PRG-03']);
  }
  // Later sets keep the load and aim for the reps just achieved; dropping below the range is fine.
  return SetSuggestion(load: load, repsTarget: math.max(rx.repMin - 1, reps), ruleIds: ['T-PRG-02']);
}

/// Builds the next exposure of an exercise from its history. The reference takes
/// `Pick<Prescription, 'repMin' | 'repMax' | 'rirMin' | 'rirMax'>`, which is [SetRx].
SessionSuggestion suggestNextSession(ExerciseHistory history, SetRx rx) {
  final last = history.exposures.isEmpty ? null : history.exposures.last;
  final first = last == null || last.sets.isEmpty ? null : last.sets[0];
  final firstLoad = first?.load;
  if (first == null || firstLoad == null) {
    final e1rm = history.e1rm;
    // The reference tests `if (history.e1rm)`: zero counts as no estimate.
    if (e1rm != null && e1rm != 0 && !e1rm.isNaN) {
      final repMid = jsRound((rx.repMin + rx.repMax) / 2);
      return SessionSuggestion(
        load: e1rmToLoad(e1rm, repMid + rx.rirMax, history.increment),
        repsTarget: repMid,
        ruleIds: ['T-PRG-01'],
      );
    }
    final repMid = jsRound((rx.repMin + rx.repMax) / 2);
    return SessionSuggestion(
      load: null,
      repsTarget: repMid,
      ruleIds: ['T-PRG-01'],
      hint:
          'Pick a weight you could lift about ${jsNum(repMid + rx.rirMax)} times, stopping with ${jsNum(rx.rirMax)} reps in the tank.',
    );
  }
  final rir = first.rir ?? rx.rirMax;
  if (first.reps >= rx.repMax && rir >= rx.rirMax) {
    var inc = history.increment;
    // Heuristic: heavy barbell lower-body compounds may jump 5 kg after two consecutive top-of-range sessions.
    if (history.heavyLowerBarbell == true &&
        firstLoad >= PROGRESSION.heavyLowerJumpThresholdKg &&
        history.exposures.length >= 2) {
      final prevSets = history.exposures[history.exposures.length - 2].sets;
      final prevFirst = prevSets.isEmpty ? null : prevSets[0];
      if (prevFirst != null && prevFirst.reps >= rx.repMax && (prevFirst.rir ?? rx.rirMax) >= rx.rirMax) {
        inc = math.max(inc, PROGRESSION.heavyLowerJumpKg);
      }
    }
    return SessionSuggestion(
      load: roundToStep(firstLoad + inc, history.increment),
      repsTarget: rx.repMin + 1,
      ruleIds: ['T-PRG-04'],
    );
  }
  final keep = SessionSuggestion(
    load: firstLoad,
    repsTarget: math.min(rx.repMax, first.reps + 1),
    ruleIds: ['T-PRG-02'],
  );
  final status = history.status;
  final pace = status != null ? loadPace(history.exposures, status) : null;
  if (pace != null && pace.stalled) {
    return SessionSuggestion(
      load: keep.load,
      repsTarget: keep.repsTarget,
      ruleIds: [...keep.ruleIds, 'T-PRG-06'],
      hint:
          '${pace.sessions} sessions at this load. ${_STATUS_LABEL[status]} lifters usually add load about every ${jsNum(pace.expected)} sessions: make sure set 1 really reaches ${rx.repMax} reps at ${jsNum(rx.rirMax)} RIR.',
    );
  }
  return keep;
}

/// T-PRG-05: “Feeling strong +1 step” / “Feeling flat −1 step”. [dir] is 1 or -1.
double? nudgeLoad(num? load, num increment, int dir) {
  if (load == null) return null;
  return math.max(0, roundToStep(load + dir * increment, increment)).toDouble();
}

/// T-PRG-06 expected sessions between load increases.
const Map<Status, double> EXPECTED_SESSIONS_PER_LOAD_JUMP = {
  Status.novice: 2.5,
  Status.intermediate: 5,
  Status.advanced: 10,
};

/// Heuristic: flag a slow stretch only at twice the typical pace; single flat sessions are normal (T-PRG-05).
const LOAD_PACE_STALL_FACTOR = 2;

const Map<Status, String> _STATUS_LABEL = {
  Status.novice: 'Novice',
  Status.intermediate: 'Intermediate',
  Status.advanced: 'Advanced',
};

/// Exposures in a row, newest backwards, at the current first-set load (since the load last went up).
int sessionsAtLoad(List<Exposure> exposures) {
  double? firstLoad(int i) {
    if (i < 0 || i >= exposures.length) return null;
    final sets = exposures[i].sets;
    return sets.isEmpty ? null : sets[0].load;
  }

  var n = 0;
  for (var i = exposures.length - 1; i >= 0; i--) {
    final cur = firstLoad(i);
    if (cur == null) break;
    n++;
    final prev = firstLoad(i - 1);
    if (prev == null || cur > prev) break;
  }
  return n;
}

/// The result of [loadPace].
class LoadPace {
  LoadPace({required this.sessions, required this.expected, required this.stalled});

  factory LoadPace.fromJson(Map<String, dynamic> json) => LoadPace(
    sessions: json['sessions'] as int,
    expected: (json['expected'] as num).toDouble(),
    stalled: json['stalled'] as bool,
  );

  final int sessions;
  final double expected;
  final bool stalled;

  Map<String, dynamic> toJson() => {'sessions': sessions, 'expected': expected, 'stalled': stalled};
}

/// T-PRG-06: is this exercise's load rising at roughly the pace expected for the lifter's status?
LoadPace loadPace(List<Exposure> exposures, Status status) {
  final expected = EXPECTED_SESSIONS_PER_LOAD_JUMP[status]!;
  final sessions = sessionsAtLoad(exposures);
  return LoadPace(
    sessions: sessions,
    expected: expected,
    stalled: sessions >= (expected * LOAD_PACE_STALL_FACTOR).ceil(),
  );
}
