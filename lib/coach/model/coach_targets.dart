// SPDX-License-Identifier: GPL-3.0-only
// What the progression module answers, in the app's own terms. CoachFacade builds these from the packages'
// results; the app's state reads them and never sees a package type. Loads are in kilograms, like the app's own.

/// The rep and effort range the coach prescribes for one exercise.
final class CoachRx {
  const CoachRx({
    required this.repMin,
    required this.repMax,
    required this.rirMin,
    required this.rirMax,
    required this.restSeconds,
    required this.ruleIds,
  });

  final int repMin;
  final int repMax;

  /// Reps left in reserve at the end of a set, lowest and highest.
  final double rirMin;
  final double rirMax;
  final int restSeconds;

  /// The rules behind this prescription, for the why-sheet.
  final List<String> ruleIds;

  /// The same prescription with another rep range: the one stored on the exercise's progression rule.
  CoachRx withReps(int min, int max) =>
      CoachRx(repMin: min, repMax: max, rirMin: rirMin, rirMax: rirMax, restSeconds: restSeconds, ruleIds: ruleIds);
}

/// The coach's target for the next time an exercise is done: the load and the reps for its first working set.
final class CoachSessionTarget {
  const CoachSessionTarget({required this.loadKg, required this.reps, required this.ruleIds, this.hint});

  /// Null when the coach has no load to suggest.
  final double? loadKg;
  final int reps;
  final List<String> ruleIds;

  /// An extra remark in English, from the coach packages.
  final String? hint;
}

/// The coach's target for the sets that follow the one just logged.
final class CoachSetTarget {
  const CoachSetTarget({required this.loadKg, required this.reps, required this.ruleIds});

  final double? loadKg;
  final int reps;
  final List<String> ruleIds;
}

/// One set of a warm-up ramp.
final class CoachWarmupSet {
  const CoachWarmupSet({required this.loadKg, required this.reps});

  final double loadKg;
  final int reps;
}
