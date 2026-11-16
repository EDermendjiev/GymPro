// SPDX-License-Identifier: GPL-3.0-only
// Pure helpers for the live session logger: set cap and finish summary. The reference's rest-timer persistence
// (browser storage) is not ported.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';

/// "Add set" cap per exercise. Every set of an exercise trains its primary muscle, and past ~11 sets for one
/// muscle in one session extra sets are mostly junk volume (T-FRQ-01), so one exercise can't go past that.
const MAX_SETS_PER_EXERCISE =
    11.0; // FREQUENCY.maxSetsPerMusclePerSession; a record field is not a constant expression

bool canAddSet(num current) => current < MAX_SETS_PER_EXERCISE;

class SummarySet {
  SummarySet({required this.load, required this.reps, required this.rir});

  factory SummarySet.fromJson(Map<String, dynamic> json) => SummarySet(
    load: (json['load'] as num?)?.toDouble(),
    reps: json['reps'] as int,
    rir: (json['rir'] as num?)?.toDouble(),
  );

  final double? load;
  final int reps;
  final double? rir;

  Map<String, dynamic> toJson() => {'load': load, 'reps': reps, 'rir': rir};
}

/// One exercise of the finished session: its muscles and the working sets logged
/// (`{ muscles: ExerciseMuscle[]; sets: SummarySet[] }` in the reference).
class SummaryItem implements HasMuscles {
  SummaryItem({required this.muscles, required this.sets});

  factory SummaryItem.fromJson(Map<String, dynamic> json) => SummaryItem(
    muscles: [for (final x in json['muscles'] as List) ExerciseMuscle.fromJson(x as Map<String, dynamic>)],
    sets: [for (final x in json['sets'] as List) SummarySet.fromJson(x as Map<String, dynamic>)],
  );

  @override
  final List<ExerciseMuscle> muscles;
  final List<SummarySet> sets;

  Map<String, dynamic> toJson() => {
    'muscles': [for (final m in muscles) m.toJson()],
    'sets': [for (final s in sets) s.toJson()],
  };
}

/// Fractional counted sets per muscle (T-VOL-05/06) for working sets logged in this session.
///
/// `sessionMuscleSets` in the reference's session file; renamed because the distributor has a function of that name.
Map<MuscleId, double> loggedSessionMuscleSets(List<SummaryItem> items) {
  final out = <MuscleId, double>{};
  for (final it in items) {
    for (final s in it.sets) {
      if (!setCounts(reps: s.reps, rir: s.rir, isWarmup: false)) continue;
      for (final m in it.muscles) {
        out[m.muscle] = (out[m.muscle] ?? 0) + muscleWeight(it, m.muscle);
      }
    }
  }
  return out;
}

/// One entry of [weekTotals].
class MuscleWeekTotal {
  MuscleWeekTotal({required this.muscle, required this.session, required this.week});

  factory MuscleWeekTotal.fromJson(Map<String, dynamic> json) => MuscleWeekTotal(
    muscle: MuscleId.fromWire(json['muscle'] as String),
    session: (json['session'] as num).toDouble(),
    week: (json['week'] as num).toDouble(),
  );

  final MuscleId muscle;
  final double session;
  final double week;

  Map<String, dynamic> toJson() => {'muscle': muscle.wire, 'session': session, 'week': week};
}

/// Week totals for the muscles trained today: sets logged earlier this week plus this session.
List<MuscleWeekTotal> weekTotals(Map<MuscleId, double> earlier, Map<MuscleId, double> session) => [
  for (final e in session.entries)
    MuscleWeekTotal(muscle: e.key, session: e.value, week: (earlier[e.key] ?? 0) + e.value),
];
