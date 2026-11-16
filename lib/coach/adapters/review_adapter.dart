// SPDX-License-Identifier: GPL-3.0-only
// The app's state as the input of the weekly review (WeeklyState), the plateau check (ProgressState) and proposal
// application (StoredPlan), and a PlanDiff's session edits written back into the block.
//
// The block's sessions have no ids of their own, so the review numbers them: session `s<i>` is the block's i-th
// session, and `s<i>.e<j>` its j-th exercise. A diff is applied to the same block it was worked out from, so the
// numbers stay valid.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_recovery/coach_recovery.dart' as cr;
import 'package:coach_training/coach_training.dart' as ct;

import '../../models/workout.dart';
import '../model/coach_data.dart';
import '../model/coach_plan.dart';
import '../model/coach_recovery.dart';
import 'block_input_adapter.dart';
import 'catalog_adapter.dart';
import 'checkin_adapter.dart';
import 'equipment_map.dart';
import 'history_adapter.dart';

/// How far back the review reads the logs: status inference and the plateau window need months, not weeks.
const int _reviewDays = 182;

String _sessionId(int i) => 's$i';
String _exerciseId(int i, int j) => 's$i.e$j';

/// The block's id as the review names it. A block has no id of its own; its start day identifies it.
String coachBlockId(ck.BlockPlan block) => 'block-${block.startsOn}';

/// The ISO days on which a workout of each coach routine was logged, as `routineId|day`.
Set<String> _loggedRoutineDays(List<LoggedSession> sessions) => {
      for (final s in sessions)
        if (s.routineId case final id?) '$id|${coachIsoDay(s.date)}',
    };

/// The block's sessions as the review reads them, each with its status: done when a workout of its routine was
/// logged on its date, skipped when the block says so, planned otherwise.
List<ck.PlannedSessionState> coachSessionStates(CoachData coach, List<LoggedSession> sessions) {
  final block = coach.block;
  if (block == null) return const [];
  final logged = _loggedRoutineDays(sessions);
  return [
    for (final (i, s) in block.sessions.indexed)
      ck.PlannedSessionState(
        id: _sessionId(i),
        date: s.date,
        status: logged.contains('${coach.routineIds[s.templateKey]}|${s.date}')
            ? ck.SessionStateStatus.done
            : s.status == ck.PlannedSessionStatus.skipped
                ? ck.SessionStateStatus.skipped
                : ck.SessionStateStatus.planned,
        templateKey: s.templateKey,
        kind: s.kind,
        exercises: [
          for (final (j, e) in s.exercises.indexed)
            ck.PlannedExerciseState(
              id: _exerciseId(i, j),
              exerciseId: e.exerciseId,
              sets: e.sets,
              rirMin: e.rirMin,
              rirMax: e.rirMax,
              repMin: e.repMin,
              repMax: e.repMax,
            ),
        ],
      ),
  ];
}

/// The logged strength sets the review reads, each with the effort floor its day's block session planned for the
/// exercise (the kernel's `plannedRirMin`), so the review can see sets drifting closer to failure than planned.
List<ck.LoggedSet> coachReviewSets(CoachPlanInputs i) {
  final today = coachIsoDay(i.today);
  final sets = coachSets(i.sessions, since: ck.addDays(today, -_reviewDays), skip: i.skip, bodyweight: i.bodyweight);
  final block = i.coach.block;
  if (block == null) return sets;
  final floor = <String, double>{};
  for (final s in block.sessions) {
    for (final e in s.exercises) {
      final k = '${s.date}|${e.exerciseId}';
      final f = floor[k];
      if (f == null || e.rirMin < f) floor[k] = e.rirMin;
    }
  }
  return [
    for (final s in sets)
      if (floor['${s.performedOn}|${s.exerciseId}'] case final f?) s.copyWith(plannedRirMin: f) else s,
  ];
}

/// The block's weekly targets for the week of [today], by tracked muscle.
Map<ck.TrackedMuscle, double> coachWeekTargets(ck.BlockPlan block, String today) {
  final week = ct.blockWeekIndex(ck.mondayOf(today), block.startsOn, block.weeks);
  return {
    for (final t in block.weeklyTargets)
      if (t.weekIndex == week) t.muscle: t.targetSets,
  };
}

/// The nutrition phase the review assumes: the one the user picked, else the one that follows from the goal.
ck.NutritionPhase coachReviewPhase(CoachData coach) {
  final picked = coach.nutrition['phase'];
  for (final p in ck.NutritionPhase.values) {
    if (p.wire == picked) return p;
  }
  return switch (coach.profile?.goal) {
    ck.Goal.leanGain => ck.NutritionPhase.gain,
    ck.Goal.fatLoss => ck.NutritionPhase.loss,
    _ => ck.NutritionPhase.maintain,
  };
}

/// The weekly review's input for the week starting on [weekStart] (a Monday). [checkins] are the coach's check-ins
/// of the last five weeks; [previousYesCount] and [lastInference] come from the last review (`coach.review`).
ck.WeeklyState coachWeeklyState(
  CoachPlanInputs i,
  List<CoachCheckin> checkins, {
  required String weekStart,
  int? previousYesCount,
  String? lastInference,
}) {
  final today = coachIsoDay(i.today);
  final coach = i.coach;
  final block = coach.block;
  final profile = coach.profile;
  final states = coachSessionStates(coach, i.sessions);
  final next = ck.addDays(weekStart, 7);
  bool inWeek(ck.PlannedSessionState s, String from) =>
      s.date.compareTo(from) >= 0 && s.date.compareTo(ck.addDays(from, 7)) < 0;
  final exercises = coachExercises(i.exercises);
  ck.Status? last;
  for (final s in ck.Status.values) {
    if (s.wire == lastInference) last = s;
  }
  return ck.WeeklyState(
    today: today,
    weekStart: weekStart,
    checkins: [for (final c in checkins) coachKernelCheckin(c)],
    sessionsThisWeek: [for (final s in states) if (inWeek(s, weekStart)) s],
    nextWeekSessions: [for (final s in states) if (inWeek(s, next)) s],
    sets: coachReviewSets(i),
    exercises: exercises,
    mainLiftExerciseIds: [for (final e in exercises) if (e.isMainLift) e.id],
    block: block == null
        ? null
        : ck.WeeklyStateBlock(id: coachBlockId(block), kind: block.kind, startsOn: block.startsOn, weeks: block.weeks),
    status: profile?.status ?? ck.Status.novice,
    statusHistory: last == null ? null : [last],
    goal: profile?.goal ?? ck.Goal.leanGain,
    nutritionPhase: coachReviewPhase(coach),
    injuries: [...coach.injuries],
    targets: block == null ? null : coachWeekTargets(block, today),
    previousYesCount: previousYesCount,
    dislikedExerciseIds: [...coach.disliked],
    equipment: [...coachEquipment(i.equipment)],
    availableDays: profile == null || profile.days.isEmpty ? null : [...profile.days],
  );
}

/// The plateau check's input, from the weekly review's [w] and its [yesCount].
cr.ProgressState coachProgressState(CoachPlanInputs i, ck.WeeklyState w, int yesCount) {
  final block = i.coach.block;
  final today = w.today;
  final sleep = [
    for (final c in w.checkins)
      if (c.day.compareTo(ck.addDays(today, -7)) >= 0 && c.day.compareTo(today) < 0) ?c.sleepHours,
  ];
  final frequency = <String, double>{};
  if (block != null) {
    final monday = ck.mondayOf(today);
    for (final s in block.sessions) {
      if (s.date.compareTo(monday) < 0 || s.date.compareTo(ck.addDays(monday, 7)) >= 0) continue;
      for (final id in {for (final e in s.exercises) e.exerciseId}) {
        frequency[id] = (frequency[id] ?? 0) + 1;
      }
    }
  }
  return cr.ProgressState(
    today: today,
    status: w.status,
    goal: w.goal,
    sets: w.sets,
    exercises: w.exercises,
    anchorExerciseIds: cr.statusAnchorIds(w),
    mainLiftExerciseIds: w.mainLiftExerciseIds,
    sleepAvg7: sleep.isEmpty ? null : ck.mean(sleep),
    nutritionPhase: w.nutritionPhase ?? ck.NutritionPhase.maintain,
    lastReviewYesCount: yesCount,
    weeklyFrequency: frequency,
    targets: w.targets ?? const {},
    selection: cr.PlateauSelection(
      equipment: [...?w.equipment],
      injuries: [...?w.injuries],
      disliked: [...?w.dislikedExerciseIds],
    ),
  );
}

/// The plan a proposal is applied to: the block's sessions with their states, every exercise, today.
cr.StoredPlan coachStoredPlan(CoachPlanInputs i) => cr.StoredPlan(
      sessions: coachSessionStates(i.coach, i.sessions),
      exercises: coachExercises(i.exercises),
      today: coachIsoDay(i.today),
    );

/// The block's sessions with [diff]'s exercise updates, deletions and session updates written in.
ck.BlockPlan coachEditBlock(ck.BlockPlan block, cr.PlanDiff diff) {
  final updates = {for (final u in diff.exerciseUpdates) u.id: u};
  final deletes = diff.exerciseDeletes.toSet();
  final sessionUpdates = {for (final u in diff.sessionUpdates) u.id: u};
  return block.copyWith(sessions: [
    for (final (i, s) in block.sessions.indexed)
      () {
        final su = sessionUpdates[_sessionId(i)];
        final status = switch (su?.status) {
          ck.SessionStateStatus.skipped => ck.PlannedSessionStatus.skipped,
          _ => s.status,
        };
        return ck.PlannedSession(
          date: s.date,
          weekIndex: s.weekIndex,
          templateKey: s.templateKey,
          title: s.title,
          kind: su?.kind ?? s.kind,
          orderInWeek: s.orderInWeek,
          estMinutes: s.estMinutes,
          exercises: [
            for (final (j, e) in s.exercises.indexed)
              if (!deletes.contains(_exerciseId(i, j)))
                if (updates[_exerciseId(i, j)] case final u?)
                  e.copyWith(
                    sets: u.sets,
                    rirMin: u.rirMin,
                    rirMax: u.rirMax,
                    repMin: u.repMin,
                    repMax: u.repMax,
                    exerciseId: u.exerciseId,
                  )
                else
                  e,
          ],
          planKey: s.planKey,
          plannedOn: s.plannedOn,
          status: status,
        );
      }(),
  ]);
}

/// The exercise swaps [diff] makes, by template: for each, the exercise the block had and the one it has after.
List<({String templateKey, String from, String to})> coachDiffSwaps(ck.BlockPlan block, cr.PlanDiff diff) {
  final out = <({String templateKey, String from, String to})>[];
  final byId = {for (final u in diff.exerciseUpdates) if (u.exerciseId != null) u.id: u.exerciseId!};
  if (byId.isEmpty) return out;
  for (final (i, s) in block.sessions.indexed) {
    for (final (j, e) in s.exercises.indexed) {
      final to = byId[_exerciseId(i, j)];
      if (to == null || to == e.exerciseId) continue;
      final swap = (templateKey: s.templateKey, from: e.exerciseId, to: to);
      if (!out.contains(swap)) out.add(swap);
    }
  }
  return out;
}
