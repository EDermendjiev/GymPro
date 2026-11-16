// SPDX-License-Identifier: GPL-3.0-only
// A generated block (BlockPlan) as the app's routines and weekly plan.
//
// One routine per session template of the block. Its exercises and planned sets are the ones of the template's first
// session in the block; what a given day actually opens with comes from that day's session of the block, worked out
// when the workout starts (CoachState.coachOpeningSets). A main lift that a strength session holds twice (the top
// single and its back-off or work sets) is one exercise of the routine, its sets in the block's order.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_training/coach_training.dart' as ct;

import '../../models/workout.dart';
import '../model/coach_plan.dart';

final RegExp _slotSuffix = RegExp(r'_(work|backoff)$');

/// The slot an exercise of a session fills, without the suffix of a main lift's work or back-off sets.
String coachSlotOf(ck.PlannedExercise e) => e.slotKey.replaceFirst(_slotSuffix, '');

/// The session templates of [block], in the order the week first meets them.
List<String> coachTemplates(ck.BlockPlan block) => ck.uniq([
      for (final p in block.schedule.placements) p.templateKey,
      for (final s in block.sessions) s.templateKey,
    ]);

/// The block's first session of [templateKey], or null when the block has none.
ck.PlannedSession? coachFirstSession(ck.BlockPlan block, String templateKey) {
  ck.PlannedSession? best;
  for (final s in block.sessions) {
    if (s.templateKey != templateKey) continue;
    if (best == null || s.date.compareTo(best.date) < 0) best = s;
  }
  return best;
}

/// The routines of [block], one per template.
List<CoachRoutinePlan> coachRoutinePlans(ck.BlockPlan block) => [
      for (final key in coachTemplates(block))
        if (coachFirstSession(block, key) case final s?)
          CoachRoutinePlan(templateKey: key, title: ct.TEMPLATES[key]?.title ?? s.title, exercises: _exercises(s)),
    ];

List<CoachRoutineExercise> _exercises(ck.PlannedSession s) {
  final order = <String>[];
  final byId = <String, List<ck.PlannedExercise>>{};
  for (final e in s.exercises) {
    if (!byId.containsKey(e.exerciseId)) order.add(e.exerciseId);
    byId.putIfAbsent(e.exerciseId, () => []).add(e);
  }
  return [
    for (final id in order)
      () {
        final entries = byId[id]!;
        final working = entries.lastWhere((e) => e.isMainLiftSingle != true, orElse: () => entries.last);
        return CoachRoutineExercise(
          exerciseId: id,
          sets: [
            for (final e in entries)
              for (var i = 0; i < e.sets; i++)
                PlannedSet(reps: e.repMin, repsMax: e.repMax > e.repMin ? e.repMax : null, weightKg: e.suggestedLoadKg),
          ],
          restSeconds: working.restSeconds,
          repMin: working.repMin,
          repMax: working.repMax,
        );
      }(),
  ];
}

/// Template key by weekday, from the block's day placement.
Map<int, String> coachWeek(ck.BlockPlan block) => {
      for (final p in block.schedule.placements) p.weekday: p.templateKey,
    };

/// The engine's exercise for each slot of the template's first session, by exercise id.
Map<String, String> coachSlotsById(ck.BlockPlan block, String templateKey) {
  final s = coachFirstSession(block, templateKey);
  if (s == null) return const {};
  return {for (final e in s.exercises) e.exerciseId: coachSlotOf(e)};
}

/// The user's edits of the coach routines as block-level changes, for a regeneration (Task 4.5).
///
/// [routineExercises] holds, by template key, the exercise ids the routine has now. Compared with the block: an
/// exercise the block chose that the routine no longer has, while the routine has one the block did not choose, is a
/// swap, and the new one takes the slot in the selections; one removed with nothing in its place goes to the
/// dislikes. Pairs are made in routine order.
({Map<String, Map<String, String>> selections, List<String> disliked}) coachUserEdits(
  ck.BlockPlan block,
  Map<String, List<String>> routineExercises,
) {
  final selections = {
    for (final e in block.selections.entries) e.key: {...e.value},
  };
  final disliked = <String>[];
  for (final e in routineExercises.entries) {
    final slots = coachSlotsById(block, e.key);
    if (slots.isEmpty) continue;
    final now = e.value;
    final removed = [for (final id in slots.keys) if (!now.contains(id)) id];
    final added = [for (final id in now) if (!slots.containsKey(id)) id];
    for (final (i, id) in removed.indexed) {
      final slot = slots[id]!;
      if (i < added.length && !slot.startsWith('extra_')) {
        selections.putIfAbsent(e.key, () => {})[slot] = added[i];
      } else {
        disliked.add(id);
      }
    }
  }
  return (selections: selections, disliked: disliked);
}

/// The previous block as the generator's history reads it: its selections (with the user's swaps) keep the
/// exercises stable, and its median target keeps the volume where it was.
ck.PreviousBlockSummary coachPreviousBlock(
  ck.BlockPlan block,
  Map<String, Map<String, String>> selections,
  String today,
) =>
    ck.PreviousBlockSummary(
      kind: block.kind,
      medianTargetBeforeTrims: ck.median([
        for (final t in block.targets)
          if (t.muscle != ck.MuscleId.frontDelts) t.base,
      ]),
      endedOn: today,
      selections: selections,
    );

/// The sessions of [block] as carry-over reads them. A session counts as done when [doneOn] says a workout of its
/// template was logged on its date.
List<ct.PriorSession> coachPriorSessions(ck.BlockPlan block, bool Function(String templateKey, String date) doneOn) => [
      for (final s in block.sessions)
        if (s.planKey case final key? when key.isNotEmpty)
          ct.PriorSession(
            planKey: key,
            plannedOn: s.plannedOn ?? s.date,
            scheduledOn: s.date,
            status: doneOn(s.templateKey, s.date)
                ? ct.PriorSessionStatus.done
                : s.status == ck.PlannedSessionStatus.skipped
                    ? ct.PriorSessionStatus.skipped
                    : ct.PriorSessionStatus.planned,
            swaps: const [],
          ),
    ];
