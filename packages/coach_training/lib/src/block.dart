// SPDX-License-Identifier: GPL-3.0-only
// generateBlock: the whole training block.
// ignore_for_file: constant_identifier_names
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';

import 'carryover.dart';
import 'distribute.dart';
import 'schedule.dart';
import 'selection.dart';
import 'split.dart';
import 'sports.dart';
import 'strength.dart';
import 'volume.dart';

/// Load step for an exercise. A custom exercise's own step wins (the user knows that machine). A catalog step is a
/// minimum progression jump, so it never goes below the user's step for that equipment (the smallest jump they can make).
///
/// The reference takes `Pick<ExerciseDef, 'equipment' | 'defaultIncrementKg' | 'custom'>`.
double incrementFor(ExerciseDef ex, List<Equipment> equipment, Map<String, double> increments) {
  final own = ex.defaultIncrementKg;
  if (ex.custom == true && own != null && own != 0 && !own.isNaN) return own;
  final eq = ex.equipment.where((e) => equipment.contains(e)).firstOrNull ?? ex.equipment.firstOrNull;
  // The reference reads `increments[undefined]` for an exercise without equipment, which falls through to 2.5.
  final forEquipment = eq == null ? 2.5 : increments[eq.wire] ?? DEFAULT_INCREMENTS[eq.wire] ?? 2.5;
  return math.max(own ?? 0, forEquipment);
}

/// Exposures (sessions) of an exercise from logged sets, oldest first, working sets only.
List<Exposure> exposuresFor(List<LoggedSet> sets, String exerciseId) {
  final byDate = <String, List<LoggedSet>>{};
  for (final s in sets) {
    if (s.exerciseId != exerciseId || s.isWarmup) continue;
    final sessionId = s.sessionId;
    final key = sessionId != null && sessionId.isNotEmpty ? '${s.performedOn}|$sessionId' : s.performedOn;
    byDate[key] = [...?byDate[key], s];
  }
  // The keys are distinct, so the order of equal elements cannot matter.
  final entries = byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return [
    for (final e in entries)
      Exposure(
        date: e.key.length > 10 ? e.key.substring(0, 10) : e.key,
        sets: [
          for (final s in stableSorted(e.value, (a, b) => a.setIndex - b.setIndex))
            ExposureSet(load: s.loadKg, reps: s.reps, rir: s.rir),
        ],
      ),
  ];
}

class _BuildCtx {
  _BuildCtx({
    required this.input,
    required this.kind,
    required this.strength,
    required this.sportPriority,
    required this.selCtx,
    required this.lifts,
    required this.warnings,
  });

  final BlockInput input;
  final BlockKind kind;
  final bool strength;
  final bool sportPriority;
  final SelectionContext Function(String templateKey) selCtx;
  final List<MainLift> lifts;
  final List<Warning> warnings;
}

List<WorkSession> _buildBaseWeek(SplitDef split, _BuildCtx ctx, int weekIndex, int weeks) {
  final selections = <String, List<WorkExercise>>{};
  final usedThisWeek = <String>{};
  for (final key in uniq(split.templates)) {
    final t = TEMPLATES[key]!;
    final base = ctx.selCtx(key);
    final sc = SelectionContext(
      exercises: base.exercises,
      equipment: base.equipment,
      injuries: base.injuries,
      disliked: base.disliked,
      previous: base.previous,
      sportPriority: base.sportPriority,
      usedThisWeek: usedThisWeek,
    );
    final used = <String>{};
    final list = <WorkExercise>[];
    final mainsHere = <MainLift>{};
    for (final slot in t.slots) {
      final mainLift = slot.mainLift;
      if (mainLift != null) {
        if (!ctx.strength || ctx.sportPriority || !ctx.lifts.contains(mainLift)) continue;
        final ex = selectMainLift(mainLift, sc);
        if (ex == null) continue;
        mainsHere.add(mainLift);
        used.add(ex.id);
        list.add(WorkExercise(ex: ex, slotKey: slot.key, sets: 1, kind: WorkKind.single, fixed: true, repsForCounting: 1));
        if (ctx.kind == BlockKind.strengthVolume) {
          list.add(
            WorkExercise(
              ex: ex,
              slotKey: '${slot.key}_work',
              sets: SESSION_TIME.startSetsCompound,
              kind: WorkKind.normal,
              fixed: false,
            ),
          );
        } else {
          final n = backoffSets(ctx.kind, weekIndex, weeks);
          if (n > 0) {
            list.add(
              WorkExercise(
                ex: ex,
                slotKey: '${slot.key}_backoff',
                sets: n,
                kind: WorkKind.backoff,
                fixed: true,
                repsForCounting: backoffReps(ctx.kind, weekIndex, weeks),
              ),
            );
          }
        }
        continue;
      }
      final replacedByMain = slot.replacedByMain;
      if (ctx.strength && replacedByMain != null && mainsHere.contains(replacedByMain)) continue;
      final ex = selectForSlot(slot, sc, used);
      if (ex == null) {
        ctx.warnings.add(
          Warning(
            code: WarningCode.noExerciseForSlot,
            message: 'No suitable exercise for “${slot.label}” in ${t.title} with your equipment and injuries.',
            ruleIds: ['T-SEL-04'],
          ),
        );
        continue;
      }
      used.add(ex.id);
      usedThisWeek.add(ex.id);
      list.add(
        WorkExercise(
          ex: ex,
          slotKey: slot.key,
          sets: isCompound(ex.category) ? SESSION_TIME.startSetsCompound : SESSION_TIME.startSetsIsolation,
          kind: WorkKind.normal,
          fixed: false,
        ),
      );
    }
    selections[key] = list;
  }
  return [
    for (final (i, key) in split.templates.indexed)
      () {
        final t = TEMPLATES[key]!;
        final dup = split.templates.where((x) => x == key).length > 1;
        final variant = sessionVariant(split.templates, i);
        return WorkSession(
          templateKey: key,
          title: dup ? '${t.title} · ${variant.wire}' : t.title,
          region: t.region,
          variant: variant,
          exercises: [for (final w in selections[key]!) w.copyWith()],
        );
      }(),
  ];
}

bool _frequencyOk(List<WorkSession> sessions, Map<TrackedMuscle, double> targets) {
  for (final m in TRACKED_MUSCLES) {
    final need = targets[m]! <= 10
        ? 1
        : targets[m]! <= 20
        ? 2
        : 3; // T-FRQ-02 (minimum frequency)
    final freq = sessions.where((s) => sessionMuscleSets(s, m) >= 1).length;
    if (freq < need) return false;
  }
  return true;
}

class _Week {
  _Week({
    required this.sessions,
    required this.unmet,
    required this.maxMinutes,
    required this.avgMinutes,
    required this.minutes,
  });

  final List<WorkSession> sessions;
  final List<TrackedMuscle> unmet;
  final int maxMinutes;
  final double avgMinutes;
  final List<int> minutes;
}

_Week _buildWeek(SplitDef split, Map<TrackedMuscle, double> targets, _BuildCtx ctx, int weekIndex, int weeks) {
  final base = _buildBaseWeek(split, ctx, weekIndex, weeks);
  final anyCtx = ctx.selCtx(split.templates[0]);
  final r = distribute(
    base,
    targets,
    SelectionContext(
      exercises: anyCtx.exercises,
      equipment: anyCtx.equipment,
      injuries: anyCtx.injuries,
      disliked: anyCtx.disliked,
      sportPriority: anyCtx.sportPriority,
      usedThisWeek: anyCtx.usedThisWeek,
    ),
  );
  final ordered = [for (final s in r.sessions) orderSession(s)];
  final minutes = [for (final s in ordered) estimateMinutes(s)];
  final avgMinutes = minutes.fold(0, (a, b) => a + b) / math.max(1, minutes.length);
  return _Week(
    sessions: ordered,
    unmet: r.unmet,
    maxMinutes: minutes.reduce(math.max),
    avgMinutes: avgMinutes,
    minutes: minutes,
  );
}

/// Time check (heuristic): the week's average session fits, and no single session runs more than 15% over.
const SESSION_OVERRUN_TOLERANCE = 1.15;
bool _fitsTime(_Week wk, int sessionMinutes) =>
    wk.avgMinutes <= sessionMinutes && wk.maxMinutes <= sessionMinutes * SESSION_OVERRUN_TOLERANCE;

bool _sameTargets(Map<TrackedMuscle, double> a, Map<TrackedMuscle, double> b) =>
    a.length == b.length && a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);

/// Throws an [ArgumentError] when no lifting day is available.
BlockPlan generateBlock(BlockInput input) {
  final kind = input.blockKind ?? defaultBlockKind(input.goal);
  final strength = isStrengthKind(kind);
  final weeks = blockWeeks(kind);
  final startsOn =
      input.startsOn ??
      (isoWeekday(input.today) <= 3 ? mondayOf(input.today) : addDays(mondayOf(input.today), 7));
  final sportPriority = input.goal == Goal.sportSupport || input.priority == Priority.sport;
  final warnings = <Warning>[];
  final explanations = <Explanation>[];

  final targetRes = computeTargets(input, kind);
  var targets = targetsMap(targetRes.targets);
  explanations.addAll([for (final text in targetRes.notes) Explanation(text: text, ruleIds: targetRes.ruleIds)]);

  final prevSel = input.history.previousBlock?.selections ?? const <String, Map<String, String>>{};
  SelectionContext selCtx(String templateKey) => SelectionContext(
    exercises: input.exercises,
    equipment: input.equipment,
    injuries: input.injuries,
    disliked: input.dislikedExerciseIds ?? [],
    previous: prevSel[templateKey],
    sportPriority: sportPriority,
  );
  final ctx = _BuildCtx(
    input: input,
    kind: kind,
    strength: strength,
    sportPriority: sportPriority,
    selCtx: selCtx,
    lifts: input.strengthLifts ?? [MainLift.squat, MainLift.bench, MainLift.deadlift],
    warnings: warnings,
  );

  // ---------- T-SCH-01: how many lift days ----------
  final avail = [
    for (final d in uniq(input.availableDays))
      if (d >= 1 && d <= 7) d,
  ]..sort();
  final userCap = input.maxLiftDays ?? 5;
  var kMax = [5, avail.length, userCap].reduce(math.min);
  // 6 days only when the user allows it and sessions are short. Strength uses ULF6, which keeps the main-lift slots (T-FRQ-03).
  if (input.sessionMinutes <= 45 && (input.maxLiftDays ?? 0) >= 6 && avail.length >= 6) kMax = 6;
  var kMin = math.min(FREQUENCY.liftDays.min, kMax);
  if (input.status != Status.novice && avail.length >= 3) kMin = math.min(3, kMax);
  if (kMax < 1) {
    throw ArgumentError('No available lifting days');
  }
  if (kMax < FREQUENCY.liftDays.min) {
    warnings.add(
      Warning(
        code: WarningCode.lowFrequency,
        message: 'With one lifting day per week, progress beyond maintenance is hard. Add a second day if you can.',
        ruleIds: ['T-FRQ-04'],
      ),
    );
  }

  final lowerTargetAvg =
      LOWER_MUSCLES.where((m) => TRACKED_MUSCLES.contains(m)).fold(0.0, (a, m) => a + targets[m]!) / 4;
  final maxTarget = TRACKED_MUSCLES.map((m) => targets[m]!).reduce(math.max);
  SplitChoice splitFor(int k) => k < 2
      ? SplitChoice(
          split: const SplitDef(key: 'FB1', name: 'Full Body ×1', templates: ['full_a']),
          ruleIds: ['T-SPL-01'],
        )
      : chooseSplit(
          k,
          ChooseSplitOptions(
            style: input.splitStyle,
            goal: input.goal,
            lowerTargetAvg: lowerTargetAvg,
            maxTarget: maxTarget,
          ),
        );

  var chosenK = kMax;
  _Week? chosen;
  var chosenSplit = splitFor(kMax);
  for (var k = kMin; k <= kMax; k++) {
    final sp = splitFor(k);
    final wk = _buildWeek(sp.split, targets, ctx, 0, weeks);
    if (_fitsTime(wk, input.sessionMinutes) && wk.unmet.isEmpty && _frequencyOk(wk.sessions, targets)) {
      chosenK = k;
      chosen = wk;
      chosenSplit = sp;
      break;
    }
  }
  if (chosen == null) {
    // Time check: at the most days allowed, lower every non-specialised target by 1 until sessions fit.
    chosenK = kMax;
    chosenSplit = splitFor(kMax);
    var wk = _buildWeek(chosenSplit.split, targets, ctx, 0, weeks);
    var guard = 0;
    while (!_fitsTime(wk, input.sessionMinutes) && guard++ < 20) {
      final next = {...targets};
      for (final m in TRACKED_MUSCLES) {
        if (input.specialization.contains(m)) continue;
        next[m] = math.max(VOLUME.minEffective, next[m]! - 1);
      }
      if (_sameTargets(next, targets)) break;
      targets = next;
      wk = _buildWeek(chosenSplit.split, targets, ctx, 0, weeks);
    }
    if (!_fitsTime(wk, input.sessionMinutes)) {
      warnings.add(
        Warning(
          code: WarningCode.timeTooShort,
          message:
              'Even at minimum volume, sessions need about ${wk.maxMinutes} min. Add more time per session or more days.',
          ruleIds: ['T-VOL-04', 'T-SCH-01'],
        ),
      );
    }
    chosen = wk;
  }
  explanations.add(
    Explanation(
      text:
          '$chosenK lifting day${chosenK == 1 ? '' : 's'} (${chosenSplit.split.name}): the fewest that keep every session within ${input.sessionMinutes} min and every muscle at a workable frequency.',
      ruleIds: ['T-SCH-01', 'T-FRQ-02', 'T-FRQ-04', ...chosenSplit.ruleIds],
    ),
  );

  // ---------- Day placement ----------
  final schedule = placeSessions(
    ScheduleInput(
      availableDays: avail,
      templates: chosenSplit.split.templates,
      sports: input.sports,
      goal: input.goal,
      liftingTime: input.liftingTime,
    ),
  );
  if (schedule.penalties.any((p) => p.rule == 'T-SCH-02')) {
    warnings.add(
      Warning(
        code: WarningCode.noRestDay,
        message: 'Your week has no full rest day. Consider freeing one day.',
        ruleIds: ['T-SCH-02'],
      ),
    );
  }
  if (schedule.penalties.any((p) => p.rule == 'T-SCH-04' && p.points >= 10)) {
    warnings.add(
      Warning(
        code: WarningCode.scheduleConflict,
        message: 'A leg session could not avoid the day before or after a hard sport session.',
        ruleIds: ['T-SCH-04'],
      ),
    );
  }
  if (input.sports.isNotEmpty) {
    explanations.add(
      Explanation(
        text: 'Sport days are fixed; lifting days were placed around them.',
        ruleIds: ['S-03', 'T-SCH-03', 'T-SCH-04'],
      ),
    );
  }

  // ---------- Intro week (T-FAT-06) ----------
  final avgTarget = median([
    for (final m in TRACKED_MUSCLES)
      if (m != MuscleId.frontDelts) targets[m]!,
  ]);
  final recent = input.history.recentAvgWeeklySets;
  var introWeek = false;
  if (!strength || kind == BlockKind.strengthVolume) {
    if (input.fromHeavyPhase == true) introWeek = true;
    if ((input.history.weeksOff ?? 0) >= INTRO_WEEK.weeksOffTrigger) introWeek = true;
    if (recent != null && recent > 0 && avgTarget > recent * (1 + INTRO_WEEK.volumeJumpTrigger)) introWeek = true;
  }
  if (introWeek) {
    explanations.add(
      Explanation(
        text: 'Week 1 is an intro week: about 75% of the sets and one more rep in reserve.',
        ruleIds: ['T-FAT-06'],
      ),
    );
  }

  if (painfulMuscles(input.injuries).isNotEmpty) {
    warnings.add(
      Warning(
        code: WarningCode.injuryRedFlag,
        message:
            'Exercises that load a painful area heavily were removed. If pain is persistent or reproducible, see a physio or sports doctor.',
        ruleIds: ['T-SEL-08'],
      ),
    );
  }

  // ---------- Materialise weeks ----------
  final rotation = [for (final p in schedule.placements) p.templateKey];
  // Placements are in weekday order; map each to the session built for that template occurrence.
  final occurrences = <String, int>{};
  final weekSessionsBase = chosen.sessions;
  final sessionForPlacement = [
    for (final key in rotation)
      () {
        final n = occurrences[key] ?? 0;
        occurrences[key] = n + 1;
        final idxs = [
          for (final (i, s) in weekSessionsBase.indexed)
            if (s.templateKey == key) i,
        ];
        return idxs[n % idxs.length];
      }(),
  ];

  final lastSel = <String, Map<String, String>>{};
  final suffix = RegExp(r'_(work|backoff)$');
  for (final s in weekSessionsBase) {
    final sel = lastSel.putIfAbsent(s.templateKey, () => {});
    for (final w in s.exercises) {
      if (!w.slotKey.startsWith('extra_')) sel[w.slotKey.replaceFirst(suffix, '')] = w.ex.id;
    }
  }

  final e1rmCache = <String, double?>{};
  double? e1rmFor(ExerciseDef ex) {
    if (!e1rmCache.containsKey(ex.id)) {
      final fromLogs = bestRecentE1rm(input.history.sets, ex.id);
      final mainLiftKey = ex.mainLiftKey;
      final seed = mainLiftKey != null ? (input.history.e1rmSeeds?[mainLiftKey]) : null;
      e1rmCache[ex.id] = fromLogs ?? seed;
    }
    return e1rmCache[ex.id];
  }

  final from = input.materialiseFrom;
  final materialiseFrom = from != null && from.isNotEmpty && from.compareTo(input.today) < 0 ? from : input.today;
  final sessions = <PlannedSession>[];
  final weeklyTargets = <WeeklyTarget>[];
  var weekCache = chosen;
  for (var w = 0; w < weeks; w++) {
    final tw = {for (final m in TRACKED_MUSCLES) m: weeklyTargetFor(kind, targets[m]!, w)};
    for (final m in TRACKED_MUSCLES) {
      final t = targetRes.targets.firstWhere((x) => x.muscle == m);
      weeklyTargets.add(WeeklyTarget(weekIndex: w, muscle: m, targetSets: tw[m]!, sportTrim: t.sportTrim));
    }
    if (w > 0 && (strength || !_sameTargets(tw, targets))) {
      weekCache = _buildWeek(chosenSplit.split, tw, ctx, w, weeks);
    } else if (w == 0) {
      weekCache = chosen;
    }
    final intro = introWeek && w == 0;
    for (final (order, pl) in schedule.placements.indexed) {
      final base = weekCache.sessions[sessionForPlacement[order]];
      final date = addDays(startsOn, w * 7 + (pl.weekday - 1));
      if (date.compareTo(materialiseFrom) < 0) continue;
      final occurrence = schedule.placements.take(order).where((x) => x.templateKey == pl.templateKey).length;
      sessions.add(
        _materialiseSession(
          base,
          date: date,
          weekIndex: w,
          orderInWeek: order,
          intro: intro,
          kind: kind,
          weeks: weeks,
          ctx: ctx,
          e1rmFor: e1rmFor,
        )..planKey = planKey(date, pl.templateKey, occurrence),
      );
    }
  }

  return BlockPlan(
    kind: kind,
    startsOn: startsOn,
    weeks: weeks,
    introWeek: introWeek,
    splitKey: chosenSplit.split.key,
    liftDays: chosenK,
    engineVersion: ENGINE_VERSION,
    schedule: schedule,
    targets: [for (final t in targetRes.targets) t.copyWith(target: targets[t.muscle])],
    weeklyTargets: weeklyTargets,
    sessions: sessions,
    selections: lastSel,
    warnings: _dedupeWarnings(warnings),
    explanations: explanations,
    hardSessionsPerWeek: hardSportSessionsPerWeek(input.sports),
  );
}

List<Warning> _dedupeWarnings(List<Warning> ws) {
  final seen = <String>{};
  return [
    for (final w in ws)
      if (seen.add(w.message)) w,
  ];
}

PlannedSession _materialiseSession(
  WorkSession s, {
  required String date,
  required int weekIndex,
  required int orderInWeek,
  required bool intro,
  required BlockKind kind,
  required int weeks,
  required _BuildCtx ctx,
  required double? Function(ExerciseDef ex) e1rmFor,
}) {
  final input = ctx.input;
  var compoundIdx = 0;
  var isoIdx = 0;
  final exercises = <PlannedExercise>[];
  for (final (position, w) in s.exercises.indexed) {
    final inc = incrementFor(w.ex, input.equipment, input.increments);
    final e1 = e1rmFor(w.ex);
    if (w.kind == WorkKind.single) {
      final rpe = singleRpe(kind, weekIndex, weeks);
      final rir = 10 - rpe;
      final load = singleLoad(e1, rpe, inc);
      exercises.add(
        PlannedExercise(
          exerciseId: w.ex.id,
          slotKey: w.slotKey,
          position: position,
          sets: 1,
          repMin: 1,
          repMax: 1,
          rirMin: rir,
          rirMax: rir,
          restSeconds: restFor(w.ex.category, strengthMain: true),
          isMainLiftSingle: true,
          note: load != null && load != 0
              ? 'Top single @ RPE ${jsNumber(rpe)}'
              : 'Top single @ RPE ${jsNumber(rpe)}. No estimate yet: work up to a weight you could do ~5 times',
          suggestedLoadKg: load,
          ruleIds: ['T-STR-02', 'T-STR-03', 'T-RST-01', 'T-FRQ-03'],
        ),
      );
      continue;
    }
    if (w.kind == WorkKind.backoff) {
      final reps = backoffReps(kind, weekIndex, weeks);
      const rpe = 7.0;
      exercises.add(
        PlannedExercise(
          exerciseId: w.ex.id,
          slotKey: w.slotKey,
          position: position,
          sets: w.sets,
          repMin: reps,
          repMax: reps,
          rirMin: 10 - rpe,
          rirMax: 10 - rpe,
          restSeconds: restFor(w.ex.category, strengthMain: true),
          note: 'Back-off sets @ RPE ${jsNumber(rpe)}',
          suggestedLoadKg: backoffLoad(e1, reps, rpe, inc),
          ruleIds: ['T-STR-03', 'T-RST-01'],
        ),
      );
      continue;
    }
    final compound = isCompound(w.ex.category);
    final level = rangeLevel(
      RangeLevelOptions(
        category: w.ex.category,
        compoundIndex: compound ? compoundIdx : -1,
        isolationIndex: compound ? -1 : isoIdx,
        variation: input.repVariation,
        variant: s.variant,
        weekIndex: weekIndex,
      ),
    );
    if (compound) {
      compoundIdx++;
    } else {
      isoIdx++;
    }
    final isLowerCompound =
        compound &&
        (w.ex.category == Category.lowerFreeCompound || w.ex.category == Category.lowerMachineCompound);
    final rx = prescribe(
      w.ex.category,
      RxOptions(level: level, sportPriority: ctx.sportPriority, isLowerCompound: isLowerCompound),
    );
    var sets = w.sets;
    var rirMin = rx.rirMin;
    var rirMax = rx.rirMax;
    final ruleIds = [...rx.ruleIds, 'T-PRG-01'];
    if (intro) {
      sets = math.max(1, roundHalfUp(sets * INTRO_WEEK.setPct));
      rirMin += INTRO_WEEK.rirBump;
      rirMax += INTRO_WEEK.rirBump;
      ruleIds.add('T-FAT-06');
    }
    final hist = ExerciseHistory(
      exposures: exposuresFor(input.history.sets, w.ex.id),
      increment: inc,
      e1rm: e1,
      heavyLowerBarbell: w.ex.category == Category.lowerFreeCompound && w.ex.equipment.contains(Equipment.barbell),
    );
    final sug = suggestNextSession(
      hist,
      SetRx(repMin: rx.repMin, repMax: rx.repMax, rirMin: rx.rirMin, rirMax: rx.rirMax),
    );
    final note = injuryNote(w.ex, input.injuries);
    if (note != null && note.isNotEmpty) ruleIds.add('T-SEL-08');
    exercises.add(
      PlannedExercise(
        exerciseId: w.ex.id,
        slotKey: w.slotKey,
        position: position,
        sets: sets,
        repMin: rx.repMin,
        repMax: rx.repMax,
        rirMin: rirMin,
        rirMax: rirMax,
        restSeconds: rx.restSeconds,
        note: note,
        suggestedLoadKg: sug.load,
        ruleIds: [...ruleIds, ...sug.ruleIds],
      ),
    );
  }
  final est = estimateMinutes(
    s.copyWith(exercises: [for (final (i, w) in s.exercises.indexed) w.copyWith(sets: exercises[i].sets)]),
  );
  return PlannedSession(
    date: date,
    weekIndex: weekIndex,
    templateKey: s.templateKey,
    title: s.title,
    kind: intro ? SessionKind.intro : SessionKind.lift,
    orderInWeek: orderInWeek,
    estMinutes: est,
    exercises: exercises,
  );
}
