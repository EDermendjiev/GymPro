// SPDX-License-Identifier: GPL-3.0-only
// The one door between the app's state and the coach packages: the app's own types go in, the app's own types
// or `Coach*` values come out. Package types never leave this layer by name.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_nutrition/coach_nutrition.dart' as cn;
import 'package:coach_planner/coach_planner.dart' as cpl;
import 'package:coach_progression/coach_progression.dart' as cp;
import 'package:coach_recovery/coach_recovery.dart' as cr;
import 'package:coach_training/coach_training.dart' as ct;

import '../models/exercise.dart';
import '../models/workout.dart';
import 'adapters/block_input_adapter.dart';
import 'adapters/catalog_adapter.dart';
import 'adapters/category_adapter.dart';
import 'adapters/checkin_adapter.dart';
import 'adapters/equipment_map.dart';
import 'adapters/exposure_adapter.dart';
import 'adapters/history_adapter.dart';
import 'adapters/muscle_map.dart';
import 'adapters/nutrition_adapter.dart';
import 'adapters/plan_writer.dart';
import 'adapters/planner_input_adapter.dart';
import 'adapters/review_adapter.dart';
import 'model/coach_choices.dart';
import 'model/coach_data.dart';
import 'model/coach_nutrition.dart';
import 'model/coach_plan.dart';
import 'model/coach_profile.dart';
import 'model/coach_recovery.dart';
import 'model/coach_targets.dart';

/// Entry points are added as the modules land. It holds no state.
abstract final class CoachFacade {
  // ---------- Progression ----------

  /// The rep range, effort range and rest the coach prescribes for [exercise] when nothing else is known about
  /// the session: the middle of the category's range, without a sport priority.
  static CoachRx rxFor(Exercise exercise) {
    final category = coachCategory(exercise);
    final lower = category == ck.Category.lowerFreeCompound || category == ck.Category.lowerMachineCompound;
    final rx = cp.prescribe(
      category,
      cp.RxOptions(level: cp.RangeLevel.mid, sportPriority: false, isLowerCompound: lower),
    );
    return CoachRx(
      repMin: rx.repMin,
      repMax: rx.repMax,
      rirMin: rx.rirMin,
      rirMax: rx.rirMax,
      restSeconds: rx.restSeconds,
      ruleIds: rx.ruleIds,
    );
  }

  /// Whether the coach treats [exercise] as a compound lift.
  static bool isCompound(Exercise exercise) => cp.isCompound(coachCategory(exercise));

  /// The load and reps for the first working set the next time [exercise] is done, from its logged [sessions].
  ///
  /// [rx] is the prescription in force (its rep range is the one stored on the exercise's rule), [incrementKg]
  /// the exercise's load step. The lifter's training status, when the coach knows it from [profile], turns on the
  /// check for a load that has stood still for too long.
  static CoachSessionTarget nextSession({
    required List<LoggedSession> sessions,
    required Exercise exercise,
    required CoachRx rx,
    required double incrementKg,
    CoachProfile? profile,
  }) {
    final history = coachExerciseHistory(
      sessions,
      exercise.id,
      increment: incrementKg,
      heavyLowerBarbell: coachHeavyLowerBarbell(exercise),
      status: profile?.status,
    );
    final s = cp.suggestNextSession(history, _setRx(rx));
    return CoachSessionTarget(loadKg: s.load, reps: s.repsTarget, ruleIds: s.ruleIds, hint: s.hint);
  }

  /// What the sets after the first working set should look like, now that it was done with [reps] reps at
  /// [loadKg]: missing the rep range moves the load by about 4 % per rep, onto the [incrementKg] grid.
  static CoachSetTarget nextSet({
    required CoachRx rx,
    required double? loadKg,
    required int reps,
    required double incrementKg,
    int setIndex = 0,
  }) {
    final s = cp.suggestNextSet(
      ck.SetContext(rx: _setRx(rx), setIndex: setIndex, load: loadKg, reps: reps, increment: incrementKg),
    );
    return CoachSetTarget(loadKg: s.load, reps: s.repsTarget, ruleIds: s.ruleIds);
  }

  /// The plain-words summary of each known rule in [ruleIds], in order, each once. English: the rule texts live in
  /// the coach packages.
  static List<String> ruleSummaries(Iterable<String> ruleIds) => [
        for (final id in {...ruleIds})
          if (ck.RULES[id] case final rule?) rule.summary,
      ];

  /// The warm-up ramp before a compound worked at [workingKg], on the [incrementKg] grid. Empty under 40 kg.
  static List<CoachWarmupSet> warmup(double workingKg, double incrementKg) => [
        for (final w in cp.warmupRamp(workingKg, incrementKg)) CoachWarmupSet(loadKg: w.load, reps: w.reps),
      ];

  // ---------- Plan ----------

  /// The input the block generator gets for [i], as JSON (the kernel's `BlockInput.toJson`). For checks and tests.
  static Map<String, dynamic> blockInputJson(CoachPlanInputs i) =>
      coachBlockInput(i, decision: _decision(i, previousSplitKey: i.coach.block?.splitKey)).toJson();

  /// The input the plan designer gets for [i], as JSON (`PlannerProfile.toJson`). For checks and tests.
  static Map<String, dynamic> plannerInputJson(CoachPlanInputs i) => coachPlannerProfile(i).toJson();

  /// The plan designer's decision for [i] when the profile is a smart-plan one (built from the answers); null
  /// otherwise, so a profile from before the planner keeps the generator's own split choice. [keepSplit] keeps the
  /// running block's split when it still fits; [previousSplitKey] and [previousMedianTarget] are the current
  /// block's, for a new block.
  static cpl.PlannerDecision? _decision(
    CoachPlanInputs i, {
    String? keepSplit,
    String? previousSplitKey,
    double? previousMedianTarget,
  }) {
    if (i.coach.profile?.smartPlan != true) return null;
    final p = coachPlannerProfile(i, previousSplitKey: previousSplitKey, previousMedianTarget: previousMedianTarget);
    return cpl.decidePlan(p, splitKey: keepSplit);
  }

  static ck.BlockPlan _generate(ck.BlockInput input, cpl.PlannerDecision? decision) =>
      ct.generateBlock(input, design: decision == null ? null : cpl.blockDesignFor(decision));

  /// A new block for [i]: the coach's data with the block in it, its routines and its week. For a smart-plan
  /// profile the plan designer chooses the split and the volume, preferring the current block's split.
  static CoachBuiltPlan buildPlan(CoachPlanInputs i) {
    final decision = _decision(i, keepSplit: i.coach.profile?.splitKey, previousSplitKey: i.coach.block?.splitKey);
    final block = _generate(coachBlockInput(i, decision: decision), decision);
    return _built(i.coach.copyWith(block: block), block);
  }

  /// The current block generated again, keeping what the user changed (Task 4.5). [routineExercises] holds the
  /// exercise ids each coach routine has now, by template key; a swap becomes the block's selection for that slot, a
  /// removal a dislike. The block keeps its kind and its weeks, and the regenerated sessions go through carry-over,
  /// so a session already done (a workout of its routine logged on its date) is not planned again. Without a block
  /// this is [buildPlan].
  ///
  /// With [blockKind] (a block transition) a new block of that kind is generated from [startsOn], after a heavy
  /// phase when [fromHeavyPhase], with the old block's selections as the previous block's.
  ///
  /// For a smart-plan profile the plan designer decides again: a running block keeps its split (while it still
  /// fits the answers), a new one prefers it and starts from its volume.
  static CoachBuiltPlan regeneratePlan(
    CoachPlanInputs i, {
    required Map<String, List<String>> routineExercises,
    String? blockKind,
    String? startsOn,
    bool? fromHeavyPhase,
  }) {
    final old = i.coach.block;
    if (old == null) return buildPlan(i);
    final today = coachIsoDay(i.today);
    final logged = {
      for (final s in i.sessions)
        if (s.routineId case final id?) '$id|${coachIsoDay(s.date)}',
    };
    bool doneOn(String templateKey, String date) => logged.contains('${i.coach.routineIds[templateKey]}|$date');
    final edits = coachUserEdits(old, routineExercises);
    final coach = i.coach.copyWith(disliked: ck.uniq([...i.coach.disliked, ...edits.disliked]));
    // A new block (a block transition) starts on its own day with its own kind; anything else keeps the running
    // block's kind and weeks.
    final transition = blockKind != null;
    final running = !transition && ck.daysBetween(old.startsOn, today) < old.weeks * 7;
    final previous = coachPreviousBlock(old, edits.selections, today);
    final decision = _decision(
      i.withCoach(coach),
      keepSplit: running ? old.splitKey : i.coach.profile?.splitKey,
      previousSplitKey: old.splitKey,
      previousMedianTarget: running ? null : previous.medianTargetBeforeTrims,
    );
    final input = coachBlockInput(
      i.withCoach(coach),
      previous: previous,
      blockKind: transition ? ck.BlockKind.fromWire(blockKind) : running ? old.kind : null,
      startsOn: transition ? startsOn : running ? old.startsOn : null,
      materialiseFrom: transition ? null : ck.mondayOf(today),
      fromHeavyPhase: fromHeavyPhase,
      decision: decision,
    );
    final fresh = _generate(input, decision);
    if (transition) return _built(coach.copyWith(block: fresh), fresh);
    final allowed = {for (final e in input.exercises) e.id}..removeAll(coach.disliked);
    final carried = ct.carryOverEdits(ct.CarryOverInput(
      sessions: fresh.sessions,
      prior: coachPriorSessions(old, doneOn),
      today: today,
      allowExercise: allowed.contains,
    ));
    final block = fresh.copyWith(sessions: carried.sessions);
    return _built(coach.copyWith(block: block), block);
  }

  /// Training days for a weekly goal of [n] sessions, spread over the week (1 = Monday … 7 = Sunday).
  static List<int> spreadDays(int n) => coachSpreadDays(n);

  /// [i] with the answers [a] in place of the coaching profile (and its pain areas in place of the injuries), as
  /// building the plan would store them; null while no goal is picked.
  static CoachPlanInputs? _withAnswers(CoachPlanInputs i, CoachAnswers a) {
    final goal = a.goal;
    if (goal == null) return null;
    final days = a.days;
    var coach = i.coach.copyWith(
      profile: CoachProfile.answered(
        goal: goal,
        status: a.status ?? CoachStatus.novice,
        days: days == null || days.isEmpty ? coachSpreadDays(i.weeklyGoal) : days,
        minutes: a.minutes,
        activity: i.activity ?? 1.375,
        keep: i.coach.profile,
        answers: a,
      ),
    );
    if (a.pain case final pain?) coach = withPainAreas(coach, pain, coachIsoDay(i.today));
    return i.withCoach(coach);
  }

  /// The plan the answers [a] would build for [i], without building it (the plan preview); null while no goal is
  /// picked. With a split picked among the options, that split when it fits, and the coach's own pick among the
  /// options.
  static CoachPlanPreview? preview(CoachPlanInputs i, CoachAnswers a) {
    final draft = _withAnswers(i, a);
    if (draft == null) return null;
    final p = coachPlannerProfile(draft, previousSplitKey: i.coach.block?.splitKey);
    final free = cpl.decidePlan(p);
    final picked = a.splitKey;
    final chosen = picked == null || picked == free.split.key ? free : cpl.decidePlan(p, splitKey: picked);
    final schedule = ct.placeSessions(ct.ScheduleInput(
      availableDays: p.days,
      templates: chosen.split.templates,
      sports: p.sports,
      goal: p.goal,
      extraTemplates: cpl.blockDesignFor(chosen).templates,
    ));
    final weekly = chosen.estimate.weekly;
    final split = chosen.split;
    final reasons = ck.uniq([
      for (final e in chosen.explanations)
        if (e.text.startsWith('${split.name}:')) e.text,
      for (final e in chosen.explanations.take(2)) e.text,
    ]).take(3).toList();
    return CoachPlanPreview(
      splitKey: split.key,
      splitName: split.name,
      liftDays: chosen.liftDays,
      minutes: ck.jsRound(chosen.estimate.avgMinutes),
      week: {
        for (final pl in schedule.placements) pl.weekday: cpl.templateFor(pl.templateKey)?.title ?? pl.templateKey,
      },
      weeklySets: {
        for (final m in ck.TRACKED_MUSCLES)
          ?CoachArea.fromWire(m.wire): ck.jsRound(chosen.targets?[m] ?? weekly[m]!),
      },
      reasons: reasons,
      warnings: [for (final w in chosen.warnings) w.message],
      options: [
        if (chosen.split.key != free.split.key)
          CoachPlanOption(splitKey: free.split.key, name: free.split.name, summary: null, recommended: true),
        for (final alt in free.alternatives)
          if (alt.split.key != chosen.split.key)
            CoachPlanOption(splitKey: alt.split.key, name: alt.split.name, summary: alt.summary, recommended: false),
      ],
    );
  }

  /// An estimated one-rep max in kilograms from a set of [reps] at [kg], or null when the set says too little
  /// (no load, or more than 12 reps).
  static double? e1rm(double kg, int reps) => ck.e1rm(kg, reps);

  static CoachBuiltPlan _built(CoachData data, ck.BlockPlan block) =>
      CoachBuiltPlan(data: data, routines: coachRoutinePlans(block), week: coachWeek(block));

  /// The block's session for [templateKey] that applies [today]: today's own, else the nearest one of the block's
  /// current week, else the nearest one of the block.
  static ck.PlannedSession? _sessionFor(ck.BlockPlan block, String templateKey, String today) {
    final week = ct.blockWeekIndex(ck.mondayOf(today), block.startsOn, block.weeks);
    int rank(ck.PlannedSession s) =>
        (s.date == today ? 0 : s.weekIndex == week ? 1 : 2) * 10000 + ck.daysBetween(today, s.date).abs();
    ck.PlannedSession? best;
    for (final s in block.sessions) {
      if (s.templateKey != templateKey) continue;
      if (best == null || rank(s) < rank(best)) best = s;
    }
    return best;
  }

  /// The sets [exercise] opens with in the coach routine of [templateKey] [today]: the set count, reps and effort of
  /// the block's session for this week, with loads worked out now from the logged [sessions]. Null when the block
  /// has no such session or the session does not hold the exercise.
  static List<CoachOpeningSet>? openingSets({
    required CoachData coach,
    required String templateKey,
    required Exercise exercise,
    required DateTime today,
    required List<LoggedSession> sessions,
    required double incrementKg,
  }) {
    final block = coach.block;
    if (block == null) return null;
    final s = _sessionFor(block, templateKey, coachIsoDay(today));
    if (s == null) return null;
    final entries = [for (final e in s.exercises) if (e.exerciseId == exercise.id) e];
    if (entries.isEmpty) return null;
    return _opening(entries, exercise, sessions, incrementKg, coach.profile?.status);
  }

  static List<CoachOpeningSet> _opening(
    List<ck.PlannedExercise> entries,
    Exercise exercise,
    List<LoggedSession> sessions,
    double incrementKg,
    ck.Status? status,
  ) {
    final history = coachExerciseHistory(
      sessions,
      exercise.id,
      increment: incrementKg,
      heavyLowerBarbell: coachHeavyLowerBarbell(exercise),
      status: status,
    );
    final mine = [for (final s in sessions) if (s.exercises.any((e) => e.id == exercise.id)) s];
    final e1rm = ck.bestRecentE1rm(coachSets(mine, since: '0000-01-01'), exercise.id);
    final out = <CoachOpeningSet>[];
    for (final e in entries) {
      if (e.isMainLiftSingle == true) {
        final load = ct.singleLoad(e1rm, 10 - e.rirMin, incrementKg) ?? e.suggestedLoadKg;
        out.add(CoachOpeningSet(reps: 1, loadKg: load));
      } else if (e.slotKey.endsWith('_backoff')) {
        final load = ct.backoffLoad(e1rm, e.repMin, 10 - e.rirMin, incrementKg) ?? e.suggestedLoadKg;
        for (var n = 0; n < e.sets; n++) {
          out.add(CoachOpeningSet(reps: e.repMin, loadKg: load));
        }
      } else {
        final rx = ck.SetRx(repMin: e.repMin, repMax: e.repMax, rirMin: e.rirMin, rirMax: e.rirMax);
        final sug = cp.suggestNextSession(history.copyWith(e1rm: e1rm), rx);
        for (var n = 0; n < e.sets; n++) {
          out.add(CoachOpeningSet(reps: sug.repsTarget, loadKg: sug.load));
        }
      }
    }
    return out;
  }

  /// Where the block in [coach] stands [today], or null without a block.
  static CoachBlockSummary? blockSummary(CoachData coach, DateTime today) {
    final block = coach.block;
    if (block == null) return null;
    final week = ct.blockWeekIndex(ck.mondayOf(coachIsoDay(today)), block.startsOn, block.weeks);
    return CoachBlockSummary(
      kind: CoachBlockKind.fromWire(block.kind.wire)!,
      week: week + 1,
      weeks: block.weeks,
      explanations: [for (final e in block.explanations) e.text],
      rules: ruleSummaries([for (final e in block.explanations) ...e.ruleIds]),
      warnings: [for (final w in block.warnings) w.message],
    );
  }

  /// A quick workout of about [minutes] for [i], from the muscles furthest behind this week's targets of the
  /// block (skipping painful and sore muscles, and putting the ones trained hard in the last 48 hours last).
  /// [focus] limits it to some of the app's muscles. Null without a block.
  static CoachQuickSession? quickSession(CoachPlanInputs i, {required int minutes, List<String>? focus}) {
    final block = i.coach.block;
    if (block == null) return null;
    final today = coachIsoDay(i.today);
    final week = ct.blockWeekIndex(ck.mondayOf(today), block.startsOn, block.weeks);
    final focusMuscles = focus == null ? null : _trackedFor(focus);
    if (focusMuscles != null && focusMuscles.isEmpty) return null;
    final sets = coachLoggedSets(i);
    final index = coachMuscleIndex(i);
    final now = i.today;
    // The logs' timestamps carry no zone and the kernel reads them as UTC, so "now" is given the same way.
    final utcNow = DateTime.utc(now.year, now.month, now.day, now.hour, now.minute, now.second);
    final sore = ct.checkinSoreness(_checkins(i.coach).take(3).toList(), today);
    final near = {ck.isoWeekday(today), ck.isoWeekday(ck.addDays(today, -1)), ck.isoWeekday(ck.addDays(today, 1))};
    final equipment = [...coachEquipment(i.equipment)];
    final increments = coachIncrements(i.barbellStepKg);
    final g = ct.generateSession(ct.GeneratorInput(
      today: today,
      minutes: minutes,
      equipmentPreset: ct.EquipmentPreset.custom,
      equipment: equipment,
      focus: focusMuscles == null ? const ct.Focus.area(ct.FocusArea.auto) : ct.Focus.muscles(focusMuscles),
      readiness: ct.Readiness.normal,
      exercises: coachPlanLibrary(i.exercises, archived: i.archived),
      injuries: [...i.coach.injuries],
      increments: increments,
      targets: {
        for (final t in block.weeklyTargets)
          if (t.weekIndex == week) t.muscle: t.targetSets,
      },
      loggedThisWeek: ck.loggedMuscleSets(sets, index, ck.mondayOf(today)),
      recentPain: sore.pain,
      recentSore: sore.sore,
      trainedLast48h: ct.trainedLast48h(sets, index, utcNow, today),
      sportStressed: ck.uniq([
        for (final s in i.coach.sports)
          if (s.weekdays.any(near.contains)) ...s.musclesStressed,
      ]),
      sets: sets,
      disliked: [...i.coach.disliked],
    ));
    final byId = {for (final e in i.exercises) e.id: e};
    final ids = ck.uniq([
      for (final e in g.exercises)
        if (byId.containsKey(e.exerciseId)) e.exerciseId,
    ]);
    return CoachQuickSession(
      exerciseIds: ids,
      sets: {
        for (final id in ids)
          id: _opening(
            [for (final e in g.exercises) if (e.exerciseId == id) e],
            byId[id]!,
            i.sessions,
            ct.incrementFor(coachExerciseDef(byId[id]!), equipment, increments),
            i.coach.profile?.status,
          ),
      },
      muscles: ck.uniq([for (final m in g.muscles) ?hostMuscle(m)]),
    );
  }

  /// The coach's tracked muscles for the app's muscles [muscles]: the app's shoulders are all three delts.
  static List<ck.MuscleId> _trackedFor(List<String> muscles) => ck.uniq([
        for (final m in muscles)
          ...(m == 'shoulders'
              ? const [ck.MuscleId.frontDelts, ck.MuscleId.sideDelts, ck.MuscleId.rearDelts]
              : [?coachMuscle(m)]),
      ]).where((m) => m.tracked).toList();

  /// The soreness reports under `coach.soreness`, newest first. Entries the coach cannot read are left out.
  static List<ct.SorenessCheckin> _checkins(CoachData coach) {
    final known = {for (final m in ck.MuscleId.values) m.wire};
    final out = <ct.SorenessCheckin>[];
    for (final e in coach.soreness.entries) {
      final v = e.value;
      if (v is! Map) continue;
      out.add(ct.SorenessCheckin(day: e.key, soreness: {
        for (final x in v.entries)
          if (known.contains(x.key) && x.value is String) x.key as String: x.value as String,
      }));
    }
    return out..sort((a, b) => b.day.compareTo(a.day));
  }

  /// The answers to prefill the plan questions with for someone who already has logs (Task 4.8): the training
  /// status the logs show once there are eight weeks of them, else the profile's; the weekdays trained on most over
  /// the last eight weeks; the profile's goal, session length and plan-design answers.
  static CoachAnswers prefill(CoachPlanInputs i) {
    final profile = i.coach.profile;
    final fromLogs = coachLogStatus(i);
    return CoachAnswers(
      goal: profile?.coachGoal,
      status: fromLogs == null ? profile?.coachStatus : CoachStatus.fromWire(fromLogs.wire),
      minutes: profile?.minutes ?? 60,
      days: _daysFromLogs(i),
      style: profile?.style ?? CoachStyle.auto,
      sessionPref: profile?.sessionPref ?? CoachSessionPref.auto,
      years: profile?.years,
      focus: [...?profile?.focus],
      lifts: profile?.strengthLifts == null ? null : [...profile!.strengthLifts!],
      knownLifts: {...?profile?.knownLifts},
      pain: [
        for (final e in injuryEntries(i.coach))
          if (e.active && e.area != null) e.area!,
      ],
      splitKey: profile?.splitKey,
    )..statusFromLogs = fromLogs != null;
  }

  /// The weekdays trained on most over the last eight weeks, as many as the user trains a week on average; null
  /// without logs in that time.
  static List<int>? _daysFromLogs(CoachPlanInputs i) {
    final from = i.today.subtract(const Duration(days: 56));
    final count = <int, int>{};
    var total = 0;
    for (final s in i.sessions) {
      if (s.date.isBefore(from) || s.date.isAfter(i.today)) continue;
      count[s.date.weekday] = (count[s.date.weekday] ?? 0) + 1;
      total++;
    }
    if (total == 0) return null;
    final n = (total / 8).round().clamp(1, 6);
    final ranked = count.keys.toList()..sort((a, b) => count[b] != count[a] ? count[b]! - count[a]! : a - b);
    return ranked.take(n).toList()..sort();
  }

  // ---------- Recovery ----------

  /// The coach's daily check-ins from [from] to [to] (Task 5.1): sleep from [sleepMinutes] (Health Connect, by ISO
  /// day), energy from the rating after the day's last rated workout, soreness from `coach.soreness`, bodyweight
  /// from the day's last weigh-in. Stress is not collected. Missing sources are null.
  static List<CoachCheckin> checkins({
    required DateTime from,
    required DateTime to,
    required Map<String, double> sleepMinutes,
    required List<LoggedSession> sessions,
    required List<BodyweightEntry> bodyweight,
    required CoachData coach,
  }) =>
      coachCheckinDays(
        from: coachIsoDay(from),
        to: coachIsoDay(to),
        sleepMinutes: sleepMinutes,
        sessions: sessions,
        bodyweight: bodyweight,
        soreness: coach.soreness,
      );

  /// The Monday of the week the review looks at [today]: on a Sunday the week ending today, otherwise the week
  /// before.
  static String reviewWeekFor(DateTime today) {
    final day = coachIsoDay(today);
    return cr.reviewWeekFor(day, ck.isoWeekday(day));
  }

  /// The weekly review's input for the week starting on [weekStart], as JSON. For checks and tests.
  static Map<String, dynamic> weeklyStateJson(
    CoachPlanInputs i,
    List<CoachCheckin> checkins, {
    required String weekStart,
    int? previousYesCount,
    String? lastInference,
  }) =>
      coachWeeklyState(i, checkins,
              weekStart: weekStart, previousYesCount: previousYesCount, lastInference: lastInference)
          .toJson();

  /// The weekly review of the week starting on [weekStart] (Task 5.3): the recovery questions answered from the
  /// logs and [checkins] (`weeklyReview`), the plan-level checks (`planReview`) and the plateau check
  /// (`detectPlateaus`), in that order. [previousYesCount] and [lastInference] come from the last review.
  static CoachReview weeklyReview(
    CoachPlanInputs i,
    List<CoachCheckin> checkins, {
    required String weekStart,
    int? previousYesCount,
    String? lastInference,
  }) {
    final w = coachWeeklyState(i, checkins,
        weekStart: weekStart, previousYesCount: previousYesCount, lastInference: lastInference);
    final review = cr.weeklyReview(w);
    final proposals = [
      ...review.proposals,
      ...cr.planReview(w, review.yesCount),
      ...cr.detectPlateaus(coachProgressState(i, w, review.yesCount)),
    ];
    return CoachReview(
      weekStart: weekStart,
      proposals: [for (final p in proposals) p.toJson()],
      yesCount: review.yesCount,
      inference: review.inference.status?.wire,
    );
  }

  /// The identity of a proposal for duplicate checks: its kind and its target (exercise, mode, injury or muscle).
  static String proposalKey(String kind, Object? payload) => cr.proposalKey(kind, payload);

  /// Whether [payload] is a valid payload for a proposal of [kind].
  static bool validProposal(CoachProposalKind kind, Map<String, dynamic> payload) {
    try {
      cr.ProposalPayload.parse(ck.ProposalKind.fromWire(kind.wire), payload);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// What applying the stored proposal [record] changes, as the coach packages' `PlanDiff` JSON: session edits,
  /// a regeneration, a setting, an injury or nutrition. Throws a [FormatException] when the record's payload is
  /// not valid for its kind.
  static Map<String, dynamic> proposalDiff(CoachPlanInputs i, Map<String, dynamic> record) {
    final kind = ck.ProposalKind.fromWire(record['kind'] as String);
    final payload = (record['payload'] as Map).cast<String, dynamic>();
    cr.ProposalPayload.parse(kind, payload);
    final p = ck.Proposal(
      kind: kind,
      title: record['title'] as String? ?? '',
      rationale: record['rationale'] as String? ?? '',
      ruleIds: const [],
      payload: payload,
    );
    return cr.applyProposal(coachStoredPlan(i), p).toJson();
  }

  /// [coach] with [diff]'s session edits (exercise updates, deletions, session updates) written into the block.
  static CoachData editBlock(CoachData coach, Map<String, dynamic> diff) {
    final block = coach.block;
    if (block == null) return coach;
    return coach.copyWith(block: coachEditBlock(block, cr.PlanDiff.fromJson(diff)));
  }

  /// The exercise swaps [diff] makes in [coach]'s block, by template.
  static List<({String templateKey, String from, String to})> diffSwaps(CoachData coach, Map<String, dynamic> diff) {
    final block = coach.block;
    return block == null ? const [] : coachDiffSwaps(block, cr.PlanDiff.fromJson(diff));
  }

  /// The working sets a deload keeps of [sets]: sets × (1 − [cutPct]) rounded half up, at least one, as the
  /// recovery package's deload works it out.
  static int deloadSets(int sets, num cutPct) {
    final n = ck.roundHalfUp(sets * (1 - cutPct));
    return n < 1 ? 1 : n;
  }

  /// Whether the block's session of [templateKey] for [today] is a deload session, its sets already cut.
  static bool deloadInBlock(CoachData coach, String templateKey, DateTime today) {
    final block = coach.block;
    if (block == null) return false;
    return _sessionFor(block, templateKey, coachIsoDay(today))?.kind == ck.SessionKind.deload;
  }

  /// The Monday of the week of [today].
  static String mondayOf(DateTime today) => ck.mondayOf(coachIsoDay(today));

  /// The Monday after [today].
  static String nextMonday(DateTime today) {
    final day = coachIsoDay(today);
    return ck.addDays(day, 8 - ck.isoWeekday(day));
  }

  /// [coach] with the injury change of an applied proposal ([injury] is the coach packages' `InjuryUpdate` JSON):
  /// an injury with that id updated (its severity, more exercises to avoid), or a new active one recorded [today].
  static CoachData withInjury(CoachData coach, Map<String, dynamic> injury, String today) {
    final u = cr.InjuryUpdate.fromJson(injury);
    final list = [...coach.injuries];
    final at = u.id == null ? -1 : list.indexWhere((x) => x.id == u.id);
    if (at >= 0) {
      final old = list[at];
      list[at] = old.copyWith(
        severity: u.severity,
        avoidExerciseIds: ck.uniq([...old.avoidExerciseIds, ...u.addAvoidIds]),
      );
    } else {
      final muscle = u.muscleId;
      list.add(ck.Injury(
        id: u.id ?? 'inj-$today-${list.length}',
        muscleId: muscle,
        label: u.label ?? (muscle == null ? 'Injury' : cr.label(muscle)),
        severity: u.severity ?? ck.InjurySeverity.pain,
        status: ck.InjuryStatus.active,
        avoidExerciseIds: [...u.addAvoidIds],
      ));
    }
    return coach.copyWith(injuries: list);
  }

  /// [coach] after an accepted calorie or activity-factor change: the calorie offset moved by [kcalDelta], the
  /// activity factor set to [multiplier], and the adjustment cadence (`lastAdjustOn`, `initialAdjustDone`) moved on
  /// as the nutrition package's `nextAdjustState` says.
  static CoachData withNutritionAdjust(
    CoachData coach, {
    int? kcalDelta,
    double? multiplier,
    required String today,
  }) {
    final n = {...coach.nutrition};
    if (kcalDelta != null && kcalDelta != 0) n['kcalOffset'] = ((n['kcalOffset'] as num?) ?? 0).round() + kcalDelta;
    if (multiplier != null) n['multiplier'] = multiplier;
    final last = n['lastAdjustOn'];
    final next = cn.nextAdjustState(
      cn.AdjustState(lastAdjustedOn: last is String ? last : null, initialAdjustDone: n['initialAdjustDone'] == true),
      cn.AdjustChange(phaseChanged: false, kcalOffsetDelta: kcalDelta, multiplierAdjust: multiplier != null),
      today,
    );
    n['lastAdjustOn'] = next.lastAdjustedOn;
    n['initialAdjustDone'] = next.initialAdjustDone;
    return coach.copyWith(nutrition: n);
  }

  // Volume targets (Task 5.7).

  /// The block's weekly set target for the app's muscle [muscle] in the week of [today]: the coach's targets of
  /// the muscles it stands for added up (the shoulders are the three delts). Null without a block, or for a muscle
  /// with no target of the coach's.
  static double? weeklySetTarget(CoachData coach, String muscle, DateTime today) {
    final block = coach.block;
    if (block == null) return null;
    final targets = coachWeekTargets(block, coachIsoDay(today));
    double? sum;
    for (final e in targets.entries) {
      if (hostMuscle(e.key) == muscle) sum = (sum ?? 0) + e.value;
    }
    return sum;
  }

  /// This week's sets (Monday to [CoachPlanInputs.today]) by the app's muscle, counted with the kernel's
  /// fractional rule, as the block's targets count them.
  static Map<String, double> muscleSetsThisWeek(CoachPlanInputs i) {
    final counted = ck.loggedMuscleSets(coachLoggedSets(i), coachMuscleIndex(i), ck.mondayOf(coachIsoDay(i.today)));
    final out = <String, double>{};
    for (final e in counted.entries) {
      final m = hostMuscle(e.key);
      if (m == null || e.value <= 0) continue;
      out[m] = (out[m] ?? 0) + e.value;
    }
    return out;
  }

  // Sports and injuries (Task 5.6).

  /// The sports the coach knows, for the sports sheet.
  static List<CoachSportChoice> sportChoices() => [
        for (final s in ct.SPORT_SEEDS) CoachSportChoice(id: s.id, name: s.name, defaultMinutes: s.defaultMinutes),
      ];

  /// The sports in [coach], as the sports sheet edits them. Sports of unknown intensity are left out.
  static List<CoachSportEntry> sportEntries(CoachData coach) => [
        for (final s in coach.sports)
          if (CoachSportIntensity.fromWire(s.intensity.wire) case final i?)
            CoachSportEntry(sportId: s.sportId, weekdays: s.weekdays, intensity: i, minutes: s.minutes),
      ];

  /// [coach] with [sports] as its sports, each with the load figures of its sport from the coach's catalog. An
  /// entry of a sport the catalog does not know keeps the stored figures when there are any, else it is dropped.
  static CoachData withSports(CoachData coach, List<CoachSportEntry> sports) {
    final stored = {for (final s in coach.sports) s.sportId: s};
    final out = <ck.UserSport>[];
    for (final e in sports) {
      final seed = ct.SPORT_SEEDS.where((s) => s.id == e.sportId).firstOrNull;
      final known = stored[e.sportId];
      final intensity = ck.SportIntensity.fromWire(e.intensity.name);
      final days = [...{...e.weekdays}]..sort();
      if (seed != null) {
        out.add(ck.UserSport(
          sportId: seed.id,
          name: seed.name,
          lowerBodyLoad: seed.lower,
          upperBodyLoad: seed.upper,
          eccentricImpact: seed.impact,
          conditioning: seed.conditioning,
          musclesStressed: [...seed.muscles],
          weekdays: days,
          intensity: intensity,
          minutes: e.minutes,
        ));
      } else if (known != null) {
        out.add(known.copyWith(weekdays: days, intensity: intensity, minutes: e.minutes));
      }
    }
    return coach.copyWith(sports: out);
  }

  /// The injuries in [coach], as the injury sheet shows them.
  static List<CoachInjuryEntry> injuryEntries(CoachData coach) => [
        for (final i in coach.injuries)
          CoachInjuryEntry(
            id: i.id,
            area: CoachArea.fromWire(i.muscleId?.wire),
            label: i.label,
            severity: CoachInjurySeverity.fromWire(i.severity.wire)!,
            active: i.status != ck.InjuryStatus.resolved,
          ),
      ];

  /// [coach] with a new active injury of [area] at [severity], recorded [today].
  static CoachData withNewInjury(CoachData coach, CoachArea area, CoachInjurySeverity severity, String today) {
    final muscle = ck.MuscleId.fromWire(area.wire);
    var n = coach.injuries.length;
    while (coach.injuries.any((i) => i.id == 'inj-$today-$n')) {
      n++;
    }
    return coach.copyWith(injuries: [
      ...coach.injuries,
      ck.Injury(
        id: 'inj-$today-$n',
        muscleId: muscle,
        label: cr.label(muscle),
        severity: ck.InjurySeverity.fromWire(severity.name),
        status: ck.InjuryStatus.active,
        avoidExerciseIds: const [],
      ),
    ]);
  }

  /// [coach] with the injury [id] marked healed (resolved).
  static CoachData withInjuryHealed(CoachData coach, String id) => coach.copyWith(injuries: [
        for (final i in coach.injuries) i.id == id ? i.copyWith(status: ck.InjuryStatus.resolved) : i,
      ]);

  /// [coach] with exactly [areas] hurting: a niggle for each area without an active injury, and the active injuries
  /// of the areas left out healed. Injuries without an area are kept as they are.
  static CoachData withPainAreas(CoachData coach, List<CoachArea> areas, String today) {
    var out = coach;
    final active = [for (final e in injuryEntries(coach)) if (e.active && e.area != null) e];
    for (final e in active) {
      if (!areas.contains(e.area)) out = withInjuryHealed(out, e.id);
    }
    for (final a in areas.toSet()) {
      if (!active.any((e) => e.area == a)) out = withNewInjury(out, a, CoachInjurySeverity.niggle, today);
    }
    return out;
  }

  // ---------- Nutrition ----------

  /// The coach's daily calorie and macro targets for someone weighing [bodyweightKg], of app sex [sex] and app
  /// activity multiplier [activity], with what [coach] knows: training status and goal from its profile, the
  /// sports, and the phase the user picked under `nutrition.phase`.
  ///
  /// Without a picked phase the phase follows the coaching goal, and without a coaching profile it is maintain;
  /// without a profile the status is novice. The activity band follows from [activity] by rank among the app's
  /// choices (`coachLifestyleFor`). Accepted weigh-in proposals (Task 6.2) are read from `nutrition.multiplier`
  /// (the activity factor) and `nutrition.kcalOffset` (calories added to or taken from the coach's own target).
  /// Everything else the calculation can take (body fat, target rate, logged sport efforts) is left at the coach's
  /// defaults.
  static CoachNutritionTargets nutritionTargets({
    required double bodyweightKg,
    required String sex,
    required double activity,
    required CoachData coach,
  }) {
    final (t, picked) = _nutrition(bodyweightKg: bodyweightKg, sex: sex, activity: activity, coach: coach);
    return CoachNutritionTargets(
      kcal: t.kcal,
      proteinG: t.proteinG.round(),
      fatG: t.fatG.round(),
      carbsG: t.carbsG.round(),
      phase: CoachNutritionPhase.fromWire(t.phase.wire)!,
      phasePicked: picked,
      bodyweightKg: bodyweightKg,
      maintenance: t.maintenance,
      delta: t.delta,
      warnings: [for (final w in t.warnings) w.message],
      ruleIds: [...t.ruleIds, for (final w in t.warnings) ...w.ruleIds],
    );
  }

  /// The nutrition package's targets for [nutritionTargets], and whether the phase was picked.
  static (cn.NutritionTargets, bool) _nutrition({
    required double bodyweightKg,
    required String sex,
    required double activity,
    required CoachData coach,
  }) {
    final profile = coach.profile;
    final picked = CoachNutritionPhase.fromWire(coach.nutrition['phase']);
    final phase = picked != null
        ? ck.NutritionPhase.fromWire(picked.wire)
        : profile != null
            ? cn.phaseForGoal(profile.goal)
            : ck.NutritionPhase.maintain;
    final multiplier = coach.nutrition['multiplier'];
    final offset = coach.nutrition['kcalOffset'];
    final rate = coach.nutrition['targetRatePct'];
    cn.NutritionInput input({int? kcal}) => cn.NutritionInput(
          bodyweightKg: bodyweightKg,
          sex: coachSexFor(sex),
          status: profile?.status ?? ck.Status.novice,
          phase: phase,
          lifestyle: coachLifestyleFor(activity),
          multiplier: multiplier is num ? multiplier.toDouble() : null,
          sports: [for (final s in coach.sports) cn.SportForKcal.fromUserSport(s)],
          targetRatePct: rate is num ? rate.toDouble() : null,
          kcalOverride: kcal,
        );
    var t = cn.nutritionTargets(input());
    // An accepted calorie change is kept as an offset from the coach's own target, so the target still follows
    // the bodyweight; the package takes the result as its calorie override.
    if (offset is num && offset != 0) t = cn.nutritionTargets(input(kcal: t.kcal + offset.round()));
    return (t, picked != null);
  }

  /// The weigh-in review (Task 6.2): the nutrition package's `nutritionReview` over the weekly averages of
  /// [weighIns], for the targets in force (the same inputs as [nutritionTargets]). The phase started on
  /// `nutrition.phaseStartedOn` ([today] when unknown).
  static CoachNutritionReview nutritionReview({
    required double bodyweightKg,
    required String sex,
    required double activity,
    required CoachData coach,
    required List<BodyweightEntry> weighIns,
    required DateTime today,
  }) {
    final (t, _) = _nutrition(bodyweightKg: bodyweightKg, sex: sex, activity: activity, coach: coach);
    final n = coach.nutrition;
    final day = coachIsoDay(today);
    final started = n['phaseStartedOn'];
    final last = n['lastAdjustOn'];
    final state = cn.WeighInState(
      today: day,
      phase: t.phase,
      phaseStartedOn: started is String ? started : day,
      lastAdjustedOn: last is String ? last : null,
      kcal: t.kcal,
      multiplier: t.multiplier,
      bodyweightKg: bodyweightKg,
      status: coach.profile?.status ?? ck.Status.novice,
      targetRatePct: t.ratePct,
      weighIns: [for (final w in weighIns) cn.WeighIn(day: coachIsoDay(w.date), kg: w.kg)],
      initialAdjustDone: n['initialAdjustDone'] == true,
    );
    final r = cn.nutritionReview(state);
    final done = [for (final w in r.weeks) if (w.weekStart.compareTo(ck.mondayOf(day)) < 0) w];
    return CoachNutritionReview(
      proposals: [for (final p in r.proposals) p.toJson()],
      notes: r.notes,
      lowData: done.isNotEmpty && done.last.lowData,
      phase: CoachNutritionPhase.fromWire(t.phase.wire)!,
    );
  }

  static ck.SetRx _setRx(CoachRx rx) =>
      ck.SetRx(repMin: rx.repMin, repMax: rx.repMax, rirMin: rx.rirMin, rirMax: rx.rirMax);
}
