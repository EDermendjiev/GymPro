// SPDX-License-Identifier: GPL-3.0-only
// The app's state as the input of the block generator (BlockInput) and of the quick-workout generator.
//
// Four things come from the user's answers (goal, status, training days, session length); everything else is what
// the app already knows (the place's equipment, the logs, the weight step) or the coach's defaults (no sports unless
// set, lifting priority, rep variation within the session). The history summary the generator wants (weeks off,
// recent weekly volume) has no helper in the packages, so it is worked out here from the kernel's set counting.
import 'package:coach_kernel/coach_kernel.dart' as ck;

import '../model/coach_plan.dart';
import 'catalog_adapter.dart';
import 'equipment_map.dart';
import 'history_adapter.dart';

/// How far back the generator reads the logs: loads and estimates only need the recent ones.
const int _historyDays = 182;

/// The ISO date of [d], as the packages write dates.
String coachIsoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Training days for a weekly goal of [n] sessions, spread over the week (1 = Monday).
List<int> coachSpreadDays(int n) => switch (n.clamp(1, 7)) {
      1 => const [1],
      2 => const [1, 4],
      3 => const [1, 3, 5],
      4 => const [1, 2, 4, 5],
      5 => const [1, 2, 3, 4, 5],
      6 => const [1, 2, 3, 4, 5, 6],
      _ => const [1, 2, 3, 4, 5, 6, 7],
    };

/// Load steps by coach equipment: the coach's defaults, with the app's weight step for the barbell.
Map<String, double> coachIncrements(double barbellStepKg) => {
      ...ck.DEFAULT_INCREMENTS,
      if (barbellStepKg > 0) ck.Equipment.barbell.wire: barbellStepKg,
    };

/// The logged strength sets the generators read.
List<ck.LoggedSet> coachLoggedSets(CoachPlanInputs i) => coachSets(
      i.sessions,
      since: ck.addDays(coachIsoDay(i.today), -_historyDays),
      skip: i.skip,
      bodyweight: i.bodyweight,
    );

/// The exercises by id, for counting logged sets per muscle.
Map<String, ck.HasMuscles> coachMuscleIndex(CoachPlanInputs i) => {
      for (final e in coachExercises(i.exercises)) e.id: e,
    };

/// The input of the block generator.
///
/// [previous], [blockKind], [startsOn] and [materialiseFrom] are set when a block is regenerated: the previous
/// selections keep the exercises stable, and the block keeps its kind and its weeks.
ck.BlockInput coachBlockInput(
  CoachPlanInputs i, {
  ck.PreviousBlockSummary? previous,
  ck.BlockKind? blockKind,
  String? startsOn,
  String? materialiseFrom,
}) {
  final today = coachIsoDay(i.today);
  final profile = i.coach.profile;
  final sets = coachLoggedSets(i);
  final days = profile == null || profile.days.isEmpty ? coachSpreadDays(i.weeklyGoal) : profile.days;
  return ck.BlockInput(
    today: today,
    goal: profile?.goal ?? ck.Goal.leanGain,
    priority: profile?.priority ?? ck.Priority.lifting,
    status: profile?.status ?? ck.Status.novice,
    availableDays: [...days],
    sessionMinutes: profile?.minutes ?? 60,
    maxLiftDays: profile?.maxLiftDays,
    equipment: [...coachEquipment(i.equipment)],
    increments: coachIncrements(i.barbellStepKg),
    sports: [...i.coach.sports],
    injuries: [...i.coach.injuries],
    exercises: coachPlanLibrary(i.exercises, archived: i.archived),
    history: ck.History(
      sets: sets,
      previousBlock: previous,
      recentAvgWeeklySets: _recentAvgWeeklySets(sets, coachMuscleIndex(i), today),
      weeksOff: _weeksOff(i, today),
    ),
    repVariation: ck.RepVariation.withinSession,
    specialization: const [],
    blockKind: blockKind,
    startsOn: startsOn,
    dislikedExerciseIds: i.coach.disliked.isEmpty ? null : [...i.coach.disliked],
    materialiseFrom: materialiseFrom,
  );
}

/// Whole weeks since the last logged session, or null when nothing is logged.
int? _weeksOff(CoachPlanInputs i, String today) {
  DateTime? last;
  for (final s in i.sessions) {
    if (last == null || s.date.isAfter(last)) last = s.date;
  }
  if (last == null) return null;
  final days = ck.daysBetween(coachIsoDay(last), today);
  return days < 0 ? 0 : days ~/ 7;
}

/// Average weekly fractional sets per tracked muscle (front delts left out, as the generator's median leaves them
/// out) over the last four weeks, or null when nothing was logged in them.
double? _recentAvgWeeklySets(List<ck.LoggedSet> sets, Map<String, ck.HasMuscles> index, String today) {
  final from = ck.addDays(today, -28);
  if (!sets.any((s) => s.performedOn.compareTo(from) >= 0)) return null;
  final counted = ck.loggedMuscleSets(sets, index, from, 28);
  final muscles = [for (final m in ck.TRACKED_MUSCLES) if (m != ck.MuscleId.frontDelts) m];
  return ck.mean([for (final m in muscles) counted[m]! / 4]);
}
