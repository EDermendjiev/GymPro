// SPDX-License-Identifier: GPL-3.0-only
// Plateau detection and flowchart. Rules: T-PRG-06, T-VOL-07, T-FAT-01, T-SEL-06.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';

/// `ProgressState.selection`: lets a stall that can't take more volume propose a variation swap (T-SEL-06).
class PlateauSelection {
  PlateauSelection({required this.equipment, required this.injuries, required this.disliked});

  factory PlateauSelection.fromJson(Map<String, dynamic> json) => PlateauSelection(
    equipment: [for (final x in json['equipment'] as List) Equipment.fromWire(x as String)],
    injuries: [for (final x in json['injuries'] as List) Injury.fromJson(x as Map<String, dynamic>)],
    disliked: [for (final x in json['disliked'] as List) x as String],
  );

  final List<Equipment> equipment;
  final List<Injury> injuries;
  final List<String> disliked;

  Map<String, dynamic> toJson() => {
    'equipment': [for (final x in equipment) x.wire],
    'injuries': [for (final x in injuries) x.toJson()],
    'disliked': [...disliked],
  };
}

class ProgressState {
  ProgressState({
    required this.today,
    required this.status,
    required this.goal,
    required this.sets,
    required this.exercises,
    required this.anchorExerciseIds,
    required this.mainLiftExerciseIds,
    required this.sleepAvg7,
    required this.nutritionPhase,
    required this.lastReviewYesCount,
    required this.weeklyFrequency,
    required this.targets,
    this.selection,
  });

  factory ProgressState.fromJson(Map<String, dynamic> json) => ProgressState(
    today: json['today'] as String,
    status: Status.fromWire(json['status'] as String),
    goal: Goal.fromWire(json['goal'] as String),
    sets: [for (final x in json['sets'] as List) LoggedSet.fromJson(x as Map<String, dynamic>)],
    exercises: [for (final x in json['exercises'] as List) ExerciseDef.fromJson(x as Map<String, dynamic>)],
    anchorExerciseIds: [for (final x in json['anchorExerciseIds'] as List) x as String],
    mainLiftExerciseIds: [for (final x in json['mainLiftExerciseIds'] as List) x as String],
    sleepAvg7: json['sleepAvg7'] == null ? null : (json['sleepAvg7'] as num).toDouble(),
    nutritionPhase: NutritionPhase.fromWire(json['nutritionPhase'] as String),
    lastReviewYesCount: json['lastReviewYesCount'] == null ? null : json['lastReviewYesCount'] as int,
    weeklyFrequency: {
      for (final e in (json['weeklyFrequency'] as Map<String, dynamic>).entries) e.key: (e.value as num).toDouble(),
    },
    targets: {
      for (final e in (json['targets'] as Map<String, dynamic>).entries)
        MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
    },
    selection: json['selection'] == null
        ? null
        : PlateauSelection.fromJson(json['selection'] as Map<String, dynamic>),
  );

  final String today;
  final Status status;
  final Goal goal;
  final List<LoggedSet> sets;
  final List<ExerciseDef> exercises;
  final List<String> anchorExerciseIds;
  final List<String> mainLiftExerciseIds;
  final double? sleepAvg7;
  final NutritionPhase nutritionPhase;
  final int? lastReviewYesCount;

  /// Exposures per week of each exercise in the current plan.
  final Map<String, double> weeklyFrequency;

  /// The current block week's targets (not week 0).
  final Map<TrackedMuscle, double> targets;

  /// Optional: lets a stall that can't take more volume propose a variation swap (T-SEL-06).
  final PlateauSelection? selection;

  Map<String, dynamic> toJson() => {
    'today': today,
    'status': status.wire,
    'goal': goal.wire,
    'sets': [for (final x in sets) x.toJson()],
    'exercises': [for (final x in exercises) x.toJson()],
    'anchorExerciseIds': [...anchorExerciseIds],
    'mainLiftExerciseIds': [...mainLiftExerciseIds],
    'sleepAvg7': sleepAvg7,
    'nutritionPhase': nutritionPhase.wire,
    'lastReviewYesCount': lastReviewYesCount,
    'weeklyFrequency': {...weeklyFrequency},
    'targets': {for (final e in targets.entries) e.key.wire: e.value},
    if (selection case final selection?) 'selection': selection.toJson(),
  };
}

/// One point of a plateau series: an exposure's date and its metric.
class SeriesPoint {
  SeriesPoint({required this.date, required this.v});

  factory SeriesPoint.fromJson(Map<String, dynamic> json) =>
      SeriesPoint(date: json['date'] as String, v: (json['v'] as num).toDouble());

  final String date;
  final double v;

  Map<String, dynamic> toJson() => {'date': date, 'v': v};
}

/// Anchor metric per exposure: best e1RM for main lifts, first-set e1RM for everything else.
List<SeriesPoint> _metricSeries(List<LoggedSet> sets, String exId, bool main) {
  final byDay = <String, List<LoggedSet>>{};
  for (final s in sets) {
    if (s.exerciseId != exId || s.isWarmup) continue;
    byDay[s.performedOn] = [...?byDay[s.performedOn], s];
  }
  final out = <SeriesPoint>[];
  for (final MapEntry(key: date, value: ss) in stableSorted(byDay.entries, (a, b) => a.key.compareTo(b.key))) {
    final sorted = stableSorted<LoggedSet>(ss, (a, b) => a.setIndex - b.setIndex);
    final vals = [for (final s in (main ? sorted : sorted.take(1))) ?e1rm(s.loadKg, s.reps, s.rir)];
    if (vals.isNotEmpty) out.add(SeriesPoint(date: date, v: vals.reduce(math.max)));
  }
  return out;
}

bool isPlateaued(List<SeriesPoint> series, Status status, String today) {
  if (status == Status.novice) {
    final n = PLATEAU_WINDOW.novice.exposures;
    if (series.length < n + 1) return false;
    final before = series.sublist(0, series.length - n).map((x) => x.v).reduce(math.max);
    return series.sublist(series.length - n).every((x) => x.v <= before + 1e-9);
  }
  final weeks = status == Status.advanced ? PLATEAU_WINDOW.advanced.weeks : PLATEAU_WINDOW.intermediate.weeks;
  final cutoff = addDays(today, -weeks * 7);
  final before = [
    for (final x in series)
      if (x.date.compareTo(cutoff) < 0) x.v,
  ];
  final recent = [
    for (final x in series)
      if (x.date.compareTo(cutoff) >= 0) x.v,
  ];
  if (before.isEmpty || recent.length < 2) return false;
  return recent.reduce(math.max) <= before.reduce(math.max) + 1e-9;
}

List<Proposal> detectPlateaus(ProgressState state) {
  final exMap = {for (final e in state.exercises) e.id: e};
  final proposals = <Proposal>[];
  final expires = addDays(state.today, 7);
  for (final id in state.anchorExerciseIds) {
    final ex = exMap[id];
    if (ex == null) continue;
    final series = _metricSeries(state.sets, id, state.mainLiftExerciseIds.contains(id));
    if (!isPlateaued(series, state.status, state.today)) continue;

    // Step 1: basics checklist.
    final fixes = <String>[];
    if (state.sleepAvg7 case final sleep? when sleep < 7) {
      fixes.add("you're sleeping ${sleep.toStringAsFixed(1)} h (aim for 7+)");
    }
    if (state.nutritionPhase == NutritionPhase.loss) fixes.add("you're in a calorie deficit, which slows strength gains");
    if (state.goal == Goal.strength && ex.isMainLift && (state.weeklyFrequency[id] ?? 0) < 2) {
      fixes.add('train this lift at least twice a week');
    }
    const questions =
        'Also check: protein ≥1.6 g/kg most days, honest RIR ratings, and the same range of motion and tempo each session.';
    if (fixes.isNotEmpty) {
      proposals.add(
        Proposal(
          kind: ProposalKind.plateauAction,
          title: '${ex.name} has stalled: fix the basics first',
          rationale:
              'No progress on ${ex.name} for longer than expected for a ${state.status.wire} lifter. Before changing the program: ${fixes.join('; ')}. $questions',
          ruleIds: ['T-PRG-06'],
          payload: {'exerciseId': id, 'step': 'fix_basics', 'details': fixes.join('; ')},
          expiresOn: expires,
        ),
      );
      continue;
    }
    // Step 2: recovering?
    if ((state.lastReviewYesCount ?? 0) >= 2) {
      proposals.add(
        Proposal(
          kind: ProposalKind.plateauAction,
          title: '${ex.name} has stalled: deload first',
          rationale:
              'Your basics look fine but recovery flags are up. Deload for a week; if fatigue returns quickly, reduce or reorganise volume. $questions',
          ruleIds: ['T-PRG-06', 'T-FAT-01', 'T-FAT-03'],
          payload: {'exerciseId': id, 'step': 'deload', 'details': 'recovery flags ≥ 2'},
          expiresOn: expires,
        ),
      );
      continue;
    }
    final muscles = [
      for (final m in ex.muscles)
        if (m.role == MuscleRole.primary &&
            TRACKED_MUSCLES.contains(m.muscle) &&
            (state.targets[m.muscle] ?? 0) + VOLUME.plateauAddSets <= VOLUME.normalCap)
          m.muscle,
    ];
    if (muscles.isEmpty) {
      // Step 4: volume is already at the cap, so change the stimulus instead: swap in a close variation (T-SEL-06).
      final sel = state.selection;
      final to = sel == null
          ? null
          : substitutionsFor(
              ex,
              LibraryContext(
                exercises: state.exercises,
                equipment: sel.equipment,
                injuries: sel.injuries,
                disliked: sel.disliked,
              ),
            ).where((e) => state.goal != Goal.strength || !ex.isMainLift || e.mainLiftKey == ex.mainLiftKey).firstOrNull;
      if (to == null) continue;
      proposals.add(
        Proposal(
          kind: ProposalKind.exerciseSwap,
          title: '${ex.name} has stalled: switch to ${to.name}',
          rationale:
              "Sleep, nutrition and recovery look good and the muscles it trains are already at ${jsNumber(VOLUME.normalCap)} weekly sets, so more volume isn't the answer. A close variation gives a fresh stimulus; keep it for the rest of the block so progress stays measurable. $questions",
          ruleIds: ['T-PRG-06', 'T-SEL-06', 'T-VOL-02'],
          payload: {'plannedExerciseIds': <String>[], 'fromExerciseId': id, 'toExerciseId': to.id, 'reason': 'plateau'},
          expiresOn: expires,
        ),
      );
      continue;
    }
    final list = muscles.map((m) => m.wire).join(', ');
    proposals.add(
      Proposal(
        kind: ProposalKind.plateauAction,
        title: '${ex.name} has stalled: add 2 sets/week for $list',
        rationale:
            'Sleep, nutrition and recovery look good, so the next step is a bit more volume: +2 weekly sets for $list. $questions',
        ruleIds: ['T-PRG-06', 'T-VOL-07'],
        payload: {
          'exerciseId': id,
          'step': 'add_volume',
          'details': '+${jsNumber(VOLUME.plateauAddSets)} sets/week',
          'changes': [
            for (final m in muscles)
              {
                'muscle': m.wire,
                'from': state.targets[m] ?? 0,
                'to': (state.targets[m] ?? 0) + VOLUME.plateauAddSets,
              },
          ],
        },
        expiresOn: expires,
      ),
    );
  }
  return proposals;
}
