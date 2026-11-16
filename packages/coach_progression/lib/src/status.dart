// SPDX-License-Identifier: GPL-3.0-only
// Training status inference. Rules: T-STA-01…03.
import 'package:coach_kernel/coach_kernel.dart';

/// T-STA-02: status from onboarding answers when the user is unsure. Years alone never give advanced (T-STA-01: rate of
/// progress decides); 5+ years plus heavy lifts that barely move month to month does.
Status statusFromYears(num years, [bool heavyLiftsStalled = false]) {
  if (years < 1) return Status.novice;
  return years >= 5 && heavyLiftsStalled ? Status.advanced : Status.intermediate;
}

/// The argument of [inferTrainingStatus].
class TrainingStatusInput {
  TrainingStatusInput({required this.sets, required this.today, required this.anchorExerciseIds});

  factory TrainingStatusInput.fromJson(Map<String, dynamic> json) => TrainingStatusInput(
    sets: [for (final x in json['sets'] as List) LoggedSet.fromJson(x as Map<String, dynamic>)],
    today: json['today'] as String,
    anchorExerciseIds: [for (final x in json['anchorExerciseIds'] as List) x as String],
  );

  final List<LoggedSet> sets;

  /// ISO date.
  final String today;
  final List<String> anchorExerciseIds;

  Map<String, dynamic> toJson() => {
    'sets': [for (final x in sets) x.toJson()],
    'today': today,
    'anchorExerciseIds': [...anchorExerciseIds],
  };
}

StatusInference inferTrainingStatus(TrainingStatusInput h) {
  final working = [
    for (final s in h.sets)
      if (!s.isWarmup) s,
  ];
  if (working.isEmpty) {
    return StatusInference(status: null, share: null, evidence: 'No training logged yet.', ruleIds: ['T-STA-03']);
  }
  final first = working.fold(
    working[0].performedOn,
    (a, s) => s.performedOn.compareTo(a) < 0 ? s.performedOn : a,
  );
  final weeks = daysBetween(first, h.today) / 7;
  if (weeks < STATUS_INFERENCE.minWeeks) {
    return StatusInference(
      status: null,
      share: null,
      evidence: 'Only ${weeks.floor()} weeks of logs (need ${STATUS_INFERENCE.minWeeks}).',
      ruleIds: ['T-STA-03'],
    );
  }
  var improved = 0;
  var total = 0;
  for (final id in h.anchorExerciseIds) {
    final byDay = <String, LoggedSet>{};
    final ofExercise = stableSorted([
      for (final x in working)
        if (x.exerciseId == id) x,
    ], (a, b) => a.setIndex - b.setIndex);
    for (final s in ofExercise) {
      byDay.putIfAbsent(s.performedOn, () => s);
    }
    final exps = [
      for (final e in stableSorted(byDay.entries, (a, b) => a.key.compareTo(b.key) < 0 ? -1 : 1)) e.value,
    ];
    for (var i = 1; i < exps.length; i++) {
      total++;
      final a = exps[i - 1];
      final b = exps[i];
      if ((b.loadKg ?? 0) > (a.loadKg ?? 0) || ((b.loadKg ?? 0) == (a.loadKg ?? 0) && b.reps > a.reps)) improved++;
    }
  }
  if (total < 6) {
    return StatusInference(
      status: null,
      share: null,
      evidence: 'Not enough repeated anchor-lift sessions yet.',
      ruleIds: ['T-STA-03'],
    );
  }
  final share = improved / total;
  final status = share >= STATUS_INFERENCE.novice
      ? Status.novice
      : share >= STATUS_INFERENCE.advanced
      ? Status.intermediate
      : Status.advanced;
  return StatusInference(
    status: status,
    share: share,
    evidence: 'Your anchor lifts improved in ${jsRound(share * 100)}% of sessions over ${weeks.floor()} weeks.',
    ruleIds: ['T-STA-01', 'T-STA-03'],
  );
}
