// SPDX-License-Identifier: GPL-3.0-only
// The coach's place in the app's state. Thin by design: it reads the app's state, asks CoachFacade, stores the
// answer in [coach] and notifies. The coaching rules live in the coach packages, never here.
part of 'fit_state.dart';

mixin CoachState
    on FitCore, LibraryState, SettingsState, PlacesState, StatsState, HealthState, NutritionState, RoutinesState {
  /// Everything the coach keeps. Stored under the `coach` key, and left out entirely while it is empty.
  CoachData coach = CoachData.empty();

  void _loadCoach(Object? raw) => coach = CoachData.fromJson(raw is Map ? raw.cast<String, dynamic>() : null);

  /// Switches module [m] on or off. Switching on is ignored while the module's prerequisite is off; switching off
  /// also switches off the modules that need [m].
  void setCoachModule(CoachModule m, bool on) {
    final next = coach.withModule(m, on);
    if (identical(next, coach)) return;
    coach = next;
    _persist();
    notifyListeners();
  }

  // ---------- Progression (Phase 3) ----------

  /// The progression kinds the progression sheet offers for an exercise whose kind is [current]: Auto only while
  /// the progression module is on, or when it is already the exercise's kind.
  List<ProgressKind> coachProgressKinds(ProgressKind current) => [
        for (final k in ProgressKind.values)
          if (k != ProgressKind.auto || k == current || coach.isOn(CoachModule.progression)) k,
      ];

  /// The rule to store when the user picks Auto for [exerciseId]: [from] with the kind set to Auto and the rep
  /// range the coach prescribes for the exercise.
  ProgressRule coachAutoRule(String exerciseId, ProgressRule from) {
    final ex = exerciseById(exerciseId);
    if (ex == null) return from.copyWith(kind: ProgressKind.auto);
    final rx = CoachFacade.rxFor(ex);
    return from.copyWith(kind: ProgressKind.auto, low: rx.repMin, high: rx.repMax);
  }

  /// The prescription in force for [exerciseId], or null when the coach does not drive it: the progression module
  /// is off, the exercise's kind is not Auto, its progression is switched off, or it is an exercise the coach
  /// leaves to the stock rules (timed, cardio, body weight only, assisted).
  CoachRx? _coachRx(String exerciseId) {
    if (!coach.isOn(CoachModule.progression)) return null;
    final rule = progressRule(exerciseId);
    if (rule.kind != ProgressKind.auto || !hasProgress(exerciseId)) return null;
    if (modeOf(exerciseId).isNotEmpty || isRepsOnly(exerciseId) || isAssisted(exerciseId)) return null;
    final ex = exerciseById(exerciseId);
    if (ex == null) return null;
    return CoachFacade.rxFor(ex).withReps(rule.low, rule.high);
  }

  /// The exercise's load step in kilograms, as the stock progression reads it.
  double _coachIncrement(String exerciseId) => progressStep[exerciseId] ?? fromDisplayWeight(weightStep);

  /// [kg] moved onto what the exercise can be loaded with: its weight stack when it has one (the nearest plate,
  /// or the nearest one in direction [dir]), otherwise the grid of its load step.
  double _coachSnap(String exerciseId, double kg, {int dir = 0}) {
    if (stackFor(exerciseId) != null) {
      if (dir < 0) return floorToStack(exerciseId, kg);
      if (dir > 0) return snapToStack(exerciseId, kg - 0.002, dir: 1);
      return snapToStack(exerciseId, kg);
    }
    final step = _coachIncrement(exerciseId);
    return step > 0 ? _round3(_roundTo(kg, step)) : _round3(kg);
  }

  CoachSessionTarget _coachNextSession(String exerciseId, CoachRx rx) {
    final ex = exerciseById(exerciseId)!;
    final step = _coachIncrement(exerciseId);
    return _remember(
      ('coachNextSession', exerciseId),
      () => CoachFacade.nextSession(sessions: sessions, exercise: ex, rx: rx, incrementKg: step, profile: coach.profile),
      (rx.repMin, rx.repMax, rx.rirMax, step, identityHashCode(coach), ex.equipment, ex.primary, ex.name),
    );
  }

  @override
  ({List<SessionSet> sets, double weightKg, int reps, NextMove move})? coachNextPlan(String exerciseId) {
    final rx = _coachRx(exerciseId);
    if (rx == null) return null;
    final last = lastSetsFor(exerciseId).where((l) => l.counts).toList();
    if (last.isEmpty) return null;
    final target = _coachNextSession(exerciseId, rx);
    final load = target.loadKg;
    if (load == null) return null;
    final was = last.first.weight;
    // A load the coach keeps stays exactly as logged; a new one is put on what the exercise can be loaded with.
    final kg = (load - was).abs() < 0.001 ? was : _coachSnap(exerciseId, load);
    final NextMove move;
    if (kg > was + 0.001) {
      move = NextMove.up;
    } else if (kg > was - 0.001 && target.reps > last.first.reps) {
      move = NextMove.reps;
    } else {
      move = NextMove.hold;
    }
    return (
      sets: [for (var i = 0; i < last.length; i++) SessionSet(target.reps, kg, false)],
      weightKg: kg,
      reps: target.reps,
      move: move,
    );
  }

  /// The coach's rep and effort range for an Auto exercise, for example "8–12 reps · 1–4 in reserve". Null when
  /// the coach does not drive [exerciseId].
  @override
  String? coachTargetLabel(String exerciseId) {
    final rx = _coachRx(exerciseId);
    if (rx == null) return null;
    String range(num a, num b) => a == b ? fmt(a) : '${fmt(a)}–${fmt(b)}';
    return t.coachTargetLabel(range(rx.repMin, rx.repMax), range(rx.rirMin, rx.rirMax));
  }

  /// The reason line for the coach's next target, in place of the stock one.
  @override
  String? coachWhy(String exerciseId) {
    final plan = coachNextPlan(exerciseId);
    if (plan == null) return null;
    final target = _coachNextSession(exerciseId, _coachRx(exerciseId)!);
    if (target.ruleIds.contains('T-PRG-06')) return t.coachWhyStalled;
    return switch (plan.move) {
      NextMove.up => t.coachWhyUp,
      NextMove.reps => t.coachWhyReps,
      _ => t.coachWhyHold,
    };
  }

  /// Everything behind the coach's numbers for [exerciseId], for the why-sheet: the coach's own remark first, when
  /// it has one, then the summary of every rule behind the prescription and the next target. Empty when the coach
  /// does not drive the exercise. The texts are in English.
  List<String> coachWhyDetails(String exerciseId) {
    final rx = _coachRx(exerciseId);
    if (rx == null) return const [];
    final hasHistory = lastSetsFor(exerciseId).any((l) => l.counts);
    final target = hasHistory ? _coachNextSession(exerciseId, rx) : null;
    return [
      ?target?.hint,
      ...CoachFacade.ruleSummaries([...?target?.ruleIds, if (hasHistory) 'T-PRG-03', ...rx.ruleIds]),
    ];
  }

  /// The coach's warm-up ramp for a compound Auto exercise, in place of the stock one, wherever the app adds
  /// warm-ups (the exercise's warm-up switch, or Add warm-up in the workout). Null, so the stock ramp is used, for
  /// anything else and when the coach has no ramp (a working load under 40 kg).
  @override
  List<SessionSet>? coachWarmupSets(String? exerciseId, List<SessionSet> working) {
    if (exerciseId == null || working.isEmpty || _coachRx(exerciseId) == null) return null;
    final ex = exerciseById(exerciseId);
    if (ex == null || !CoachFacade.isCompound(ex)) return null;
    final load = working.map((s) => s.weight).reduce(math.max);
    final ramp = CoachFacade.warmup(load, _coachIncrement(exerciseId));
    if (ramp.isEmpty) return null;
    return [
      for (final w in ramp)
        SessionSet(w.reps, stackFor(exerciseId) == null ? w.loadKg : _coachSnap(exerciseId, w.loadKg), false,
            kind: SetKind.warmup),
    ];
  }

  /// The workout in progress. WorkoutState, which comes after this mixin, holds it.
  WorkoutSession? get session;

  /// Requests for the workout screen, oldest first. The screen takes them with [takeCoachPrompts].
  final List<CoachPrompt> _coachPrompts = [];

  /// The session exercises whose first working set the coach has already looked at, so it looks once only.
  final Set<SessionExercise> _coachSeen = Set.identity();
  WorkoutSession? _coachSeenIn;

  /// The sets the last first-set correction rewrote, with what they held before.
  List<(SessionSet, double, int, int?)> _coachUndo = const [];

  /// Whether a request for the workout screen is waiting. Requests belong to the workout they were made in.
  bool get hasCoachPrompts => _coachPrompts.isNotEmpty && identical(_coachSeenIn, session);

  /// Hands over the waiting requests for the workout screen, oldest first, and forgets them.
  List<CoachPrompt> takeCoachPrompts() {
    final out = hasCoachPrompts ? List<CoachPrompt>.of(_coachPrompts) : const <CoachPrompt>[];
    _coachPrompts.clear();
    return out;
  }

  /// Called when set [setIdx] of exercise [exIdx] is ticked, before the change is saved. On the first working set
  /// of an Auto exercise, and only once per exercise of the session, the coach checks the reps against the range:
  /// a miss moves the load of the remaining sets (about 4 % per rep), and the workout screen is asked to say so
  /// with an Undo. When that set has no effort yet, the workout screen is also asked to open its effort picker.
  @override
  void coachSetLogged(int exIdx, int setIdx) {
    final s = session;
    if (s == null || s.manual || exIdx < 0 || exIdx >= s.exercises.length) return;
    final ex = s.exercises[exIdx];
    final rx = _coachRx(ex.id);
    if (rx == null) return;
    final sets = ex.sets;
    if (setIdx < 0 || setIdx >= sets.length || setIdx != sets.indexWhere((x) => x.counts)) return;
    if (!identical(_coachSeenIn, s)) {
      _coachSeen.clear();
      _coachPrompts.clear();
      _coachUndo = const [];
      _coachSeenIn = s;
    }
    if (!_coachSeen.add(ex)) return;
    final st = sets[setIdx];
    _coachCorrect(exIdx, ex, rx, setIdx);
    // One effort question per exercise, on its first working set. Skipping it leaves the effort empty, which the
    // coach reads as "on target".
    if (st.rpe == null) _coachPrompts.add(CoachEffortPrompt(exerciseIndex: exIdx, setIndex: setIdx));
  }

  void _coachCorrect(int exIdx, SessionExercise ex, CoachRx rx, int setIdx) {
    final sets = ex.sets;
    final st = sets[setIdx];
    final target = CoachFacade.nextSet(
      rx: rx,
      loadKg: st.weight,
      reps: st.weakReps,
      incrementKg: _coachIncrement(ex.id),
    );
    final load = target.loadKg;
    if (load == null || (load - st.weight).abs() < 0.001) return;
    final kg = _coachSnap(ex.id, load, dir: load < st.weight ? -1 : 1);
    if ((kg - st.weight).abs() < 0.001) return;
    final rest = [
      for (final x in sets.skip(setIdx + 1))
        if (!x.done && (x.kind == SetKind.normal || x.kind == SetKind.failure)) x,
    ];
    if (rest.isEmpty) return;
    _coachUndo = [for (final x in rest) (x, x.weight, x.reps, x.repsR)];
    for (final x in rest) {
      x.weight = kg;
      x.reps = target.reps;
      if (x.repsR != null) x.repsR = target.reps;
    }
    _coachPrompts.add(CoachCorrectionPrompt(
      title: kg < st.weight ? t.coachSetLighter(weightLabel(kg)) : t.coachSetHeavier(weightLabel(kg)),
      subtitle: t.coachSetAim(target.reps),
      exerciseIndex: exIdx,
    ));
  }

  /// Puts back the sets the last first-set correction rewrote. Sets ticked since then are left as they are.
  void undoCoachCorrection() {
    if (_coachUndo.isEmpty || !identical(_coachSeenIn, session)) return;
    for (final (x, weight, reps, repsR) in _coachUndo) {
      if (x.done) continue;
      x.weight = weight;
      x.reps = reps;
      x.repsR = repsR;
    }
    _coachUndo = const [];
    _persist();
    notifyListeners();
  }

  // ---------- Plan (Phase 4) ----------

  /// The clock the plan module reads. Tests replace it.
  DateTime Function() coachClock = DateTime.now;

  /// The answers given so far in onboarding. Nothing is stored until onboarding ends.
  CoachAnswers coachDraft = CoachAnswers();

  CoachPlanInputs _coachInputs() => CoachPlanInputs(
        today: coachClock(),
        coach: coach,
        exercises: allExercises,
        archived: archived,
        sessions: sessions,
        equipment: gearHere,
        barbellStepKg: fromDisplayWeight(weightStep),
        weeklyGoal: profile.weeklyGoal,
        skip: (id) => modeOf(id).isNotEmpty,
        bodyweight: (id) => exerciseById(id)?.equipment == 'Bodyweight',
      );

  /// What the block generator gets for the current state, as JSON. For checks and tests.
  Map<String, dynamic> coachBlockInput() => CoachFacade.blockInputJson(_coachInputs());

  /// Training days for a weekly goal of [n] sessions, spread over the week (1 = Monday … 7 = Sunday).
  List<int> coachSpreadDays(int n) => CoachFacade.spreadDays(n);

  /// Ends onboarding for the coach: with a goal picked, stores the answers as the coaching profile, switches on
  /// the progression and plan modules and builds the plan. Without one ("Just log workouts") nothing changes.
  void coachFinishOnboarding() {
    final a = coachDraft;
    coachDraft = CoachAnswers();
    coachApplyAnswers(a);
  }

  /// Stores [a] as the coaching profile, switches on the progression and plan modules and builds the plan. Does
  /// nothing while no goal is picked. Training days default to the weekly goal spread over the week.
  void coachApplyAnswers(CoachAnswers a) {
    final goal = a.goal;
    if (goal == null) return;
    final days = a.days;
    coach = coach
        .copyWith(
          profile: CoachProfile.answered(
            goal: goal,
            status: a.status ?? CoachStatus.novice,
            days: days == null || days.isEmpty ? coachSpreadDays(profile.weeklyGoal) : days,
            minutes: a.minutes,
            activity: profile.activity,
            keep: coach.profile,
          ),
        )
        .withModule(CoachModule.progression, true)
        .withModule(CoachModule.plan, true);
    coachBuildPlan();
  }

  /// Builds a new block from the coaching profile and writes it as routines in the "Coach" group with a weekly
  /// schedule (see [_coachWritePlan]).
  void coachBuildPlan() => _coachWritePlan(CoachFacade.buildPlan(_coachInputs()));

  /// Generates the current block again, keeping the user's edits of the coach routines: a swapped exercise stays,
  /// a removed one is not picked again. [reason] says what asked for it.
  void coachRegenerate(String reason) {
    if (coach.block == null) return;
    final now = {
      for (final e in coach.routineIds.entries)
        if (routineById(e.value) case final r?) e.key: [...r.exerciseIds],
    };
    _coachWritePlan(CoachFacade.regeneratePlan(_coachInputs(), routineExercises: now));
  }

  /// Writes [built] into the app: one routine per template in the "Coach" group (the same routines as last time
  /// when they still exist), every exercise of them on Auto progression with the block's rep range, and the
  /// weekly plan from the block's day placement. The user's own routines and saved plans are never changed: a
  /// weekly plan holding any routine of the user's own is first saved as a plan of its own.
  void _coachWritePlan(CoachBuiltPlan built) {
    final old = coach.routineIds;
    final ids = <String, String>{};
    for (final r in built.routines) {
      final known = old[r.templateKey];
      final id = known != null && routineById(known) != null ? known : createRoutine(r.title);
      final routine = routineById(id)!;
      routine.name = r.title;
      routine.archived = false;
      for (final ex in [...routine.exerciseIds]) {
        toggleRoutineExercise(id, ex);
      }
      for (final e in r.exercises) {
        toggleRoutineExercise(id, e.exerciseId);
        setPlannedSets(id, e.exerciseId, e.sets);
        setRoutineRest(id, e.exerciseId, e.restSeconds);
        setProgressRule(
          e.exerciseId,
          progressRule(e.exerciseId).copyWith(kind: ProgressKind.auto, low: e.repMin, high: e.repMax),
        );
      }
      setRoutineGroup(id, t.coachRoutineGroup);
      ids[r.templateKey] = id;
    }
    for (final e in old.entries) {
      if (!ids.containsKey(e.key) && routineById(e.value) != null) deleteRoutine(e.value);
    }
    final coachIds = {...old.values, ...ids.values};
    final mine = [...weeklyPlan.values, for (final x in planExtras.values) ...x].any((id) => !coachIds.contains(id));
    if (mine) {
      savePlanAs(t.coachPlanName, empty: true);
    } else {
      weeklyPlan.clear();
      planExtras.clear();
    }
    if (rotation) setRotation(false);
    for (final e in built.week.entries) {
      if (ids[e.value] case final id?) weeklyPlan[e.key] = id;
    }
    coach = built.data.copyWith(routineIds: ids);
    _planChanged();
  }

  /// The template of the coach routine whose planned sets for [exerciseId] are [planned], or of [routineId].
  String? _coachTemplateOf(String exerciseId, String? routineId, List<PlannedSet> planned) {
    for (final e in coach.routineIds.entries) {
      if (routineId != null) {
        if (e.value == routineId) return e.key;
        continue;
      }
      final r = routineById(e.value);
      if (r != null && identical(r.plan[exerciseId], planned)) return e.key;
    }
    return null;
  }

  /// WorkoutState, which comes after this mixin, holds these.
  List<SessionSet> _workingOpeners(String id, {int? count});
  List<SessionSet> _warmupFor(List<SessionSet> sets, [String? id]);
  void resetDefaultPicks();

  /// The sets an exercise opens with in a coach routine while the plan module is on: the set count and reps of the
  /// block's session for this week (intro weeks, rep variation and strength phases included), with the coach's
  /// loads worked out now. In a quick workout the coach picked, the generated session's sets. Null, so the stock
  /// opening sets are used, for anything else. Exercises the coach leaves to the stock rules (body weight only,
  /// assisted, or with their progression switched off) keep the stock reps and loads with the block's set count.
  @override
  List<SessionSet>? coachOpeningSets(String exerciseId, {String? routineId, List<PlannedSet>? planned}) {
    if (!coach.isOn(CoachModule.plan) || modeOf(exerciseId).isNotEmpty) return null;
    final ex = exerciseById(exerciseId);
    if (ex == null) return null;
    final List<CoachOpeningSet>? plan;
    if (planned != null) {
      final key = _coachTemplateOf(exerciseId, routineId, planned);
      if (key == null) return null;
      plan = CoachFacade.openingSets(
        coach: coach,
        templateKey: key,
        exercise: ex,
        today: coachClock(),
        sessions: sessions,
        incrementKg: _coachIncrement(exerciseId),
      );
    } else {
      plan = route == 'train' ? _coachQuick?.sets[exerciseId] : null;
    }
    if (plan == null || plan.isEmpty) return null;
    final drives = _coachRx(exerciseId) != null;
    final stock = _workingOpeners(exerciseId, count: plan.length);
    final sets = [
      for (final (i, p) in plan.indexed)
        () {
          final s = stock[math.min(i, stock.length - 1)];
          final load = p.loadKg;
          return SessionSet(
            drives ? p.reps : s.reps,
            drives && load != null ? _coachSnap(exerciseId, load) : s.weight,
            false,
          );
        }(),
    ];
    if (!warmsUp(exerciseId) || isRepsOnly(exerciseId)) return sets;
    return [..._warmupFor(sets, exerciseId), ...sets];
  }

  /// Where the block stands today, while the plan module is on.
  CoachBlockSummary? get coachPlanSummary =>
      coach.isOn(CoachModule.plan) ? CoachFacade.blockSummary(coach, coachClock()) : null;

  /// Whether [routineId] is one of the coach's routines.
  bool isCoachRoutine(String routineId) => coach.routineIds.containsValue(routineId);

  /// The block's kind and week for the Home card ("Hypertrophy · Week 2 of 6"), when [r] is a coach routine and
  /// the plan module is on; else null.
  String? coachBlockLabel(Routine r) {
    if (!isCoachRoutine(r.id)) return null;
    final s = coachPlanSummary;
    if (s == null) return null;
    return t.coachBlockWeek(coachBlockKindLabel(s.kind), s.week, s.weeks);
  }

  /// The answers to prefill the plan questions with, from the profile and the logs (Settings › Coach).
  CoachAnswers coachPrefill() => CoachFacade.prefill(_coachInputs());

  // Quick workout (Task 4.7).

  /// The session lengths the train screen offers for a quick workout.
  static const List<int> coachQuickLengths = [20, 30, 45, 60];

  int? _coachQuickMinutes;
  CoachQuickSession? _coachQuick;

  /// The length of a quick workout: the one picked on the train screen, else the one nearest the profile's.
  int get coachQuickMinutes {
    final picked = _coachQuickMinutes;
    if (picked != null) return picked;
    final want = coach.profile?.minutes ?? 45;
    return coachQuickLengths.reduce((a, b) => (b - want).abs() < (a - want).abs() ? b : a);
  }

  /// Picks the length of a quick workout and picks its exercises again.
  void setCoachQuickMinutes(int minutes) {
    if (minutes == coachQuickMinutes) return;
    _coachQuickMinutes = minutes;
    resetDefaultPicks();
  }

  /// The quick workout's exercises for [muscles] while the plan module is on: what the coach's session generator
  /// picks for them, deficit first. Null, so the stock picks are used, when the module is off or nothing fits.
  @override
  List<Exercise>? coachDefaultPicks(List<String> muscles) {
    _coachQuick = null;
    if (!coach.isOn(CoachModule.plan)) return null;
    final q = CoachFacade.quickSession(_coachInputs(), minutes: coachQuickMinutes, focus: muscles);
    if (q == null) return null;
    final picks = [
      for (final id in q.exerciseIds)
        if (!noSuggest.contains(id)) ?exerciseById(id),
    ];
    if (picks.isEmpty) return null;
    _coachQuick = q;
    return picks;
  }

  /// The muscles a quick workout starts from while the plan module is on: the ones furthest behind this week's
  /// targets. Null, so the stock focus is used, when the module is off or nothing fits.
  @override
  List<String>? coachFocusMuscles() {
    if (!coach.isOn(CoachModule.plan)) return null;
    final q = CoachFacade.quickSession(_coachInputs(), minutes: coachQuickMinutes);
    return q == null || q.muscles.isEmpty ? null : q.muscles;
  }

  // ---------- Recovery (Phase 5) ----------

  /// Health Connect's sleep, in minutes, by ISO day, from [from] to [to].
  Map<String, double> _coachSleep(DateTime from, DateTime to) {
    final out = <String, double>{};
    for (var d = DateTime(from.year, from.month, from.day); !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
      final v = healthOnDay(HealthMetric.sleep, d);
      if (v != null && v.isNotEmpty && v.first > 0) {
        out['${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'] =
            v.first;
      }
    }
    return out;
  }

  /// The coach's check-ins for the last [days] days up to today (Task 5.1), from what the app already has: sleep
  /// from Health Connect, the energy rating after a workout, the soreness sheet, the weigh-ins. Stress is not
  /// collected. A source with nothing for a day is null.
  List<CoachCheckin> coachCheckins({int days = 35}) {
    final today = coachClock();
    final from = DateTime(today.year, today.month, today.day - (days - 1));
    return CoachFacade.checkins(
      from: from,
      to: today,
      sleepMinutes: _coachSleep(from, today),
      sessions: sessions,
      bodyweight: bodyweight,
      coach: coach,
    );
  }

  /// How long a soreness report is kept.
  static const int coachSorenessDays = 28;

  /// The ISO day of [d].
  String _coachDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The areas reported sore or painful on [day] (today when null).
  Map<CoachArea, CoachSoreness> coachSorenessOn([DateTime? day]) {
    final v = coach.soreness[_coachDay(day ?? coachClock())];
    if (v is! Map) return const {};
    return {
      for (final e in v.entries)
        ?CoachArea.fromWire(e.key): ?CoachSoreness.fromWire(e.value),
    };
  }

  /// Reports [area] as [level] on [day] (today when null), or clears the report when [level] is null. Reports older
  /// than [coachSorenessDays] days are dropped.
  void setCoachSoreness(CoachArea area, CoachSoreness? level, {DateTime? day}) {
    final key = _coachDay(day ?? coachClock());
    final all = {
      for (final e in coach.soreness.entries) e.key: e.value is Map ? {...(e.value as Map).cast<String, dynamic>()} : e.value,
    };
    final today = {...?(all[key] as Map<String, dynamic>?)};
    if (level == null) {
      today.remove(area.wire);
    } else {
      today[area.wire] = level.name;
    }
    if (today.isEmpty) {
      all.remove(key);
    } else {
      all[key] = today;
    }
    _coachStoreSoreness(all);
  }

  /// Stores [all] as `coach.soreness`, without the reports older than [coachSorenessDays] days.
  void _coachStoreSoreness(Map<String, dynamic> all) {
    final now = coachClock();
    final oldest = _coachDay(DateTime(now.year, now.month, now.day - (coachSorenessDays - 1)));
    all.removeWhere((day, _) => day.compareTo(oldest) < 0);
    coach = coach.copyWith(soreness: all);
    _persist();
    notifyListeners();
  }

  // Weekly review (Task 5.3).

  /// How long a dismissed proposal keeps the same one from coming back.
  static const int coachDismissedDays = 28;

  /// The stored proposals the coach can read, in stored order.
  List<CoachProposal> get coachProposals => [
        for (final r in coach.proposals) ?CoachProposal.read(r),
      ];

  /// Runs the coach's periodic work, at the end of loading and after a workout is saved. No background service: it
  /// runs the next time the app opens.
  ///
  /// With the recovery module on and a block, once a week has passed since `coach.review.lastWeekStart`, the
  /// weekly review runs on the week the review looks at (the week before, or on a Sunday the week ending today) and
  /// its proposals are stored, one per kind and target: a proposal pending, or dismissed in the last
  /// [coachDismissedDays] days, is not made again. The first run only sets `lastWeekStart`. Pending proposals past
  /// their last day are put aside.
  ///
  /// With the nutrition module on, once per week the weigh-in review runs (Task 6.2): its calorie or
  /// activity-factor proposal joins the others (it always asks first); when last week had too few weigh-ins the
  /// review's note is kept for the Home card instead.
  @override
  void coachTick() {
    final recovery = coach.isOn(CoachModule.recovery);
    final nutrition = coach.isOn(CoachModule.nutrition);
    if (!recovery && !nutrition) return;
    final before = coach;
    _coachExpire();
    if (recovery && coach.block != null) _coachWeeklyReview();
    if (nutrition) _coachWeighInReview();
    if (identical(before, coach)) return;
    _persist();
    notifyListeners();
  }

  void _coachWeeklyReview() {
    final week = CoachFacade.reviewWeekFor(coachClock());
    final review = coach.review;
    final last = review['lastWeekStart'];
    if (last is String && week.compareTo(last) <= 0) return;
    if (last is! String) {
      coach = coach.copyWith(review: {...review, 'lastWeekStart': week});
      return;
    }
    final previous = review['previousYesCount'];
    final inference = review['lastInference'];
    final r = CoachFacade.weeklyReview(
      _coachInputs(),
      coachCheckins(),
      weekStart: week,
      previousYesCount: previous is int ? previous : null,
      lastInference: inference is String ? inference : null,
    );
    coach = coach.copyWith(review: {
      ...coach.review,
      'lastWeekStart': week,
      'previousYesCount': r.yesCount,
      'lastInference': r.inference,
    });
    _coachAddProposals(r.proposals);
  }

  void _coachWeighInReview() {
    final today = coachClock();
    final week = CoachFacade.mondayOf(today);
    var n = {...coach.nutrition};
    // A new phase (picked, or following a new goal) starts the adjustment cadence over.
    final phase = coachNutritionTargets?.phase.wire;
    if (n['phaseFor'] != phase) {
      n
        ..['phaseFor'] = phase
        ..['phaseStartedOn'] = _coachDay(today)
        ..['initialAdjustDone'] = false;
      coach = coach.copyWith(nutrition: n);
    }
    // Goals of the user's own win, so there is nothing to adjust.
    if (!coachSetsGoals || coach.review['nutritionWeek'] == week) return;
    final r = CoachFacade.nutritionReview(
      bodyweightKg: nutritionWeightKg,
      sex: profile.sex,
      activity: profile.activity,
      coach: coach,
      weighIns: bodyweight,
      today: today,
    );
    final review = {...coach.review, 'nutritionWeek': week}..remove('nutritionNote');
    if (r.lowData && r.notes.isNotEmpty) review['nutritionNote'] = r.notes.first;
    coach = coach.copyWith(review: review);
    _coachAddProposals(r.proposals);
  }

  /// The weigh-in review's note for the Home card, while the nutrition module is on and last week had too few
  /// weigh-ins to judge. In English: it comes from the coach packages.
  String? get coachNutritionNote {
    if (!coach.isOn(CoachModule.nutrition)) return null;
    final v = coach.review['nutritionNote'];
    return v is String ? v : null;
  }

  /// Stores [proposals] (the coach packages' JSON) as pending, leaving out those already pending or recently
  /// dismissed, then applies the ones the coach applies by itself.
  void _coachAddProposals(List<Map<String, dynamic>> proposals) {
    final today = _coachDay(coachClock());
    final since = _coachDay(DateTime.parse(today).subtract(const Duration(days: coachDismissedDays)));
    final blocked = {
      for (final p in coachProposals)
        if (p.state == CoachProposalState.pending ||
            (p.state == CoachProposalState.dismissed && (p.dismissedOn ?? p.createdOn).compareTo(since) >= 0))
          CoachFacade.proposalKey(p.kind.wire, p.payload),
    };
    final added = <String>[];
    final records = [...coach.proposals];
    for (final p in proposals) {
      final kind = CoachProposalKind.fromWire(p['kind']);
      if (kind == null) continue;
      final key = CoachFacade.proposalKey(kind.wire, p['payload']);
      if (!blocked.add(key)) continue;
      final id = 'p$today-${records.length}-${kind.wire}';
      records.add({
        'id': id,
        'kind': kind.wire,
        'state': CoachProposalState.pending.name,
        'createdOn': today,
        for (final k in const ['title', 'rationale', 'ruleIds', 'payload', 'appliesFrom', 'expiresOn'])
          if (p[k] != null) k: p[k],
      });
      added.add(id);
    }
    if (added.isEmpty) return;
    coach = coach.copyWith(proposals: records);
    for (final id in added) {
      final p = coachProposals.where((x) => x.id == id).firstOrNull;
      if (p != null && coachTierFor(p.kind, askFirst: coachAskFirst) == CoachAutonomyTier.applyWithUndo) {
        _coachApply(p);
      }
    }
  }

  /// Puts aside pending proposals past their last day, and forgets the undo data of proposals applied more than
  /// [coachUndoDays] days ago.
  void _coachExpire() {
    final today = _coachDay(coachClock());
    final undoSince = _coachDay(DateTime.parse(today).subtract(const Duration(days: coachUndoDays)));
    var changed = false;
    final records = [
      for (final r in coach.proposals)
        () {
          final p = CoachProposal.read(r);
          if (p == null) return r;
          final expires = p.expiresOn;
          if (p.state == CoachProposalState.pending && expires != null && expires.compareTo(today) < 0) {
            changed = true;
            return {...r, 'state': CoachProposalState.dismissed.name, 'dismissedOn': today};
          }
          if (p.state == CoachProposalState.applied &&
              r.containsKey('undo') &&
              (p.appliedOn ?? '').compareTo(undoSince) < 0) {
            changed = true;
            return {...r}..remove('undo');
          }
          return r;
        }(),
    ];
    if (changed) coach = coach.copyWith(proposals: records);
  }

  // Volume targets (Task 5.7).

  /// While the recovery module is on, the muscle map's weekly target of the app's [muscleId] is the block's for
  /// this week (the shoulders' is the three delts' added up). Null, so the app's own target is used, otherwise and
  /// for a muscle the block sets no target for.
  @override
  double? coachWeeklySetTarget(String muscleId) {
    if (!coach.isOn(CoachModule.recovery)) return null;
    final v = CoachFacade.weeklySetTarget(coach, muscleId, coachClock());
    return v == null || v <= 0 ? null : v;
  }

  /// While the recovery module is on and there is a block, this week's sets by muscle, counted the coach's way
  /// (fractional, Monday to today), so they compare with the block's targets. Null, so the app counts, otherwise.
  @override
  Map<String, double>? coachMuscleSetsThisWeek() {
    if (!coach.isOn(CoachModule.recovery) || coach.block == null) return null;
    return CoachFacade.muscleSetsThisWeek(_coachInputs());
  }

  // Sports and injuries (Task 5.6).

  /// The sports the coach knows.
  List<CoachSportChoice> get coachSportChoices => CoachFacade.sportChoices();

  /// The user's sports.
  List<CoachSportEntry> get coachSports => CoachFacade.sportEntries(coach);

  /// Stores [sports] as the user's sports, and generates the plan again while the plan module is on.
  void setCoachSports(List<CoachSportEntry> sports) {
    coach = CoachFacade.withSports(coach, sports);
    _coachAfterSettingsChange();
  }

  /// The user's injuries, healed ones included.
  List<CoachInjuryEntry> get coachInjuries => CoachFacade.injuryEntries(coach);

  /// Records a new injury of [area], and generates the plan again while the plan module is on.
  void addCoachInjury(CoachArea area, CoachInjurySeverity severity) {
    coach = CoachFacade.withNewInjury(coach, area, severity, _coachDay(coachClock()));
    _coachAfterSettingsChange();
  }

  /// Marks the injury [id] healed, and generates the plan again while the plan module is on.
  void healCoachInjury(String id) {
    coach = CoachFacade.withInjuryHealed(coach, id);
    _coachAfterSettingsChange();
  }

  void _coachAfterSettingsChange() {
    if (coach.isOn(CoachModule.plan) && coach.block != null) {
      coachRegenerate('settings');
      return;
    }
    _persist();
    notifyListeners();
  }

  /// Whether the Home slot shows the hint about sports and injuries: the plan module is on, none are entered, and
  /// the hint was not dismissed.
  bool get coachShowsHomeHint =>
      coach.isOn(CoachModule.plan) && coach.sports.isEmpty && coach.injuries.isEmpty && coach.review['hintDone'] != true;

  void dismissCoachHomeHint() {
    coach = coach.copyWith(review: {...coach.review, 'hintDone': true});
    _persist();
    notifyListeners();
  }

  // Need-based deloads (Task 5.4).

  /// The deload an applied proposal set up for this week (`weekStart`, `cutPct`, and for a targeted deload
  /// `targeted` and the exercises it removes), or null.
  Map<String, dynamic>? _coachDeloadNow({bool targeted = false}) {
    final monday = CoachFacade.mondayOf(coachClock());
    for (final p in coachProposals.reversed) {
      if (p.state != CoachProposalState.applied) continue;
      final d = p.record['deload'];
      if (d is Map && d['weekStart'] == monday && (d['targeted'] == true) == targeted) return d.cast<String, dynamic>();
    }
    return null;
  }

  /// While the recovery module is on, the coach decides the deload weeks and the calendar's are superseded: true in
  /// the week of an applied deload, false otherwise. Null (the calendar decides) while the module is off.
  @override
  bool? coachDeloadWeek() => coach.isOn(CoachModule.recovery) ? _coachDeloadNow() != null : null;

  /// A workout started in the week of the coach's deload: every exercise keeps its loads and drops to its sets ×
  /// (1 − the deload's cut), rounded half up. A coach routine whose block session today is a deload session already
  /// opens with the cut sets. False, so the stock deload is applied, for anything else.
  @override
  bool coachLighten(WorkoutSession s) {
    if (!coach.isOn(CoachModule.recovery)) return false;
    final d = _coachDeloadNow();
    if (d == null) return false;
    s.deload = true;
    s.lightened = true;
    final cut = d['cutPct'];
    if (cut is! num || cut <= 0) return true;
    final template = coach.routineIds.entries.where((e) => e.value == s.routineId).firstOrNull?.key;
    if (template != null &&
        coach.isOn(CoachModule.plan) &&
        CoachFacade.deloadInBlock(coach, template, coachClock())) {
      return true;
    }
    for (final e in s.exercises) {
      final working = e.sets.where((st) => st.kind != SetKind.warmup).toList();
      if (working.isEmpty) continue;
      final keep = CoachFacade.deloadSets(working.length, cut);
      final drop = working.sublist(keep).toSet();
      e.sets.removeWhere(drop.contains);
    }
    return true;
  }

  /// A coach routine started in the week of an applied targeted deload leaves out the exercises it removes.
  @override
  void coachShapeSession(WorkoutSession s) {
    if (!coach.isOn(CoachModule.recovery) || !coach.isOn(CoachModule.plan)) return;
    if (s.routineId == null || !isCoachRoutine(s.routineId!)) return;
    final remove = _coachDeloadNow(targeted: true)?['remove'];
    if (remove is! List || remove.isEmpty) return;
    s.exercises.removeWhere((e) => remove.contains(e.id));
  }

  // Autonomy, apply and undo (Task 5.5).

  /// How long an applied proposal can be undone, and shows on the Home card.
  static const int coachUndoDays = 7;

  /// "Ask me before any change": every proposal waits for the user. Kept under `coach.review.askFirst`.
  bool get coachAskFirst => coach.review['askFirst'] == true;

  void setCoachAskFirst(bool on) {
    if (on == coachAskFirst) return;
    coach = coach.copyWith(review: {...coach.review, 'askFirst': on}..removeWhere((k, v) => k == 'askFirst' && !on));
    _persist();
    notifyListeners();
  }

  /// The proposals for the Home card: the pending ones, and the ones applied in the last [coachUndoDays] days that
  /// can still be undone. Newest first.
  List<CoachProposal> get coachCardProposals {
    final since = _coachDay(coachClock().subtract(const Duration(days: coachUndoDays)));
    return [
      for (final p in coachProposals.reversed)
        if (p.state == CoachProposalState.pending ||
            (p.state == CoachProposalState.applied &&
                p.record.containsKey('undo') &&
                (p.appliedOn ?? '').compareTo(since) >= 0))
          p,
    ];
  }

  /// The tier of [p] under the current "Ask me before any change" setting.
  CoachAutonomyTier coachTierOf(CoachProposal p) => coachTierFor(p.kind, askFirst: coachAskFirst);

  CoachProposal? _coachProposal(String id) => coachProposals.where((p) => p.id == id).firstOrNull;

  void _coachReplaceRecord(String id, Map<String, dynamic> record) {
    coach = coach.copyWith(proposals: [
      for (final r in coach.proposals) r['id'] == id ? record : r,
    ]);
  }

  /// Applies the pending proposal [id]: its payload is checked first, and one that is not valid for its kind is
  /// put aside instead, never applied. Returns whether it was applied.
  bool applyCoachProposal(String id) {
    final p = _coachProposal(id);
    if (p == null || p.state != CoachProposalState.pending) return false;
    final ok = _coachApply(p);
    _planChanged();
    return ok;
  }

  /// Puts the pending proposal [id] aside ("Not now"). The same proposal is not made again for
  /// [coachDismissedDays] days.
  void dismissCoachProposal(String id) {
    final p = _coachProposal(id);
    if (p == null || p.state != CoachProposalState.pending) return;
    _coachReplaceRecord(id, {...p.record, 'state': CoachProposalState.dismissed.name, 'dismissedOn': _coachDay(coachClock())});
    _persist();
    notifyListeners();
  }

  bool _coachApply(CoachProposal p) {
    final today = _coachDay(coachClock());
    if (!CoachFacade.validProposal(p.kind, p.payload)) {
      _coachReplaceRecord(p.id, {
        ...p.record,
        'state': CoachProposalState.dismissed.name,
        'dismissedOn': today,
        'invalid': true,
      });
      return false;
    }
    final snapshot = _coachSnapshot(p.record);
    final diff = CoachFacade.proposalDiff(_coachInputs(), p.record);
    final deload = _coachApplyDiff(p, diff);
    _coachReplaceRecord(p.id, {
      ...p.record,
      'state': CoachProposalState.applied.name,
      'appliedOn': today,
      'summary': diff['summary'],
      'deload': ?deload,
      'undo': snapshot,
    });
    return true;
  }

  /// Applies [diff] (the coach packages' PlanDiff JSON) for [p]: a training status, an injury, nutrition, session
  /// edits, a regeneration. Returns the deload week it sets up, if any (`weekStart`, `cutPct`).
  Map<String, dynamic>? _coachApplyDiff(CoachProposal p, Map<String, dynamic> diff) {
    final today = _coachDay(coachClock());
    if (diff['settings'] case {'trainingStatus': final String status}) {
      final profile = coach.profile;
      if (profile != null) coach = coach.copyWith(profile: CoachProfile.fromJson({...profile.toJson(), 'status': status}));
    }
    if (diff['injury'] case final Map injury) {
      coach = CoachFacade.withInjury(coach, injury.cast<String, dynamic>(), today);
    }
    if (diff['nutrition'] case final Map n) {
      final kcal = n['kcal'];
      final multiplier = n['multiplier'];
      final current = coachNutritionTargets?.kcal;
      coach = CoachFacade.withNutritionAdjust(
        coach,
        kcalDelta: kcal is num && current != null ? (kcal - current).round() : null,
        multiplier: multiplier is num ? multiplier.toDouble() : null,
        today: today,
      );
    }
    final edits = [diff['exerciseUpdates'], diff['exerciseDeletes'], diff['sessionUpdates']]
        .any((x) => x is List && x.isNotEmpty);
    if (edits && coach.block != null) {
      final swaps = CoachFacade.diffSwaps(coach, diff);
      coach = CoachFacade.editBlock(coach, diff);
      for (final s in swaps) {
        final rid = coach.routineIds[s.templateKey];
        if (rid == null) continue;
        replaceRoutineExercise(rid, s.from, s.to);
        final from = progressRule(s.from);
        setProgressRule(s.to, progressRule(s.to).copyWith(kind: ProgressKind.auto, low: from.low, high: from.high));
      }
    }
    if (diff['regenerate'] case final Map regen) {
      if (regen['targetAdjustments'] case final Map adj) {
        final sum = <String, dynamic>{...?(coach.review['targetAdjustments'] as Map?)?.cast<String, dynamic>()};
        for (final e in adj.entries) {
          sum[e.key as String] = ((sum[e.key] as num?) ?? 0) + (e.value as num);
        }
        coach = coach.copyWith(review: {...coach.review, 'targetAdjustments': sum});
      }
      if (coach.isOn(CoachModule.plan) && coach.block != null) {
        _coachRegenerateWith(
          blockKind: regen['blockKind'] as String?,
          startsOn: regen['startsOn'] as String?,
          fromHeavyPhase: regen['fromHeavyPhase'] as bool?,
        );
      }
    }
    return switch (p.kind) {
      CoachProposalKind.standardDeload => {
          'weekStart': p.payload['weekStart'],
          'cutPct': p.payload['mode'] == 'sets' ? p.payload['setCutPct'] : 0,
        },
      CoachProposalKind.plateauAction when p.payload['step'] == 'deload' => {
          'weekStart': CoachFacade.nextMonday(coachClock()),
          'cutPct': 0.4,
        },
      CoachProposalKind.targetedDeload => {
          'weekStart': p.payload['weekStart'],
          'targeted': true,
          'remove': p.payload['mode'] == 'higher_reps' ? const [] : p.payload['removeExerciseIds'],
        },
      _ => null,
    };
  }

  /// Everything applying a proposal can change, for its undo: the coach's data (its proposals aside), the coach
  /// routines, the progression rules, the weekly plan and rotation, and the record itself as it was.
  Map<String, dynamic> _coachSnapshot(Map<String, dynamic> record) {
    final data = coach.toJson()..remove('proposals');
    final ids = coach.routineIds.values.toSet();
    final routineJson = <Map<String, dynamic>>[];
    for (final (i, r) in routines.indexed) {
      // A deep copy: a routine's JSON shares its lists with the routine.
      if (ids.contains(r.id)) routineJson.add({'index': i, 'routine': jsonDecode(jsonEncode(r.toJson()))});
    }
    return {
      'coach': data,
      'routines': routineJson,
      'rules': jsonDecode(jsonEncode({for (final e in progressRules.entries) e.key: e.value.toJson()})),
      'weeklyPlan': {for (final e in weeklyPlan.entries) '${e.key}': e.value},
      'planExtras': {for (final e in planExtras.entries) '${e.key}': [...e.value]},
      'rotation': rotation,
      'rotationIds': [...rotationIds],
      'rotationNext': rotationNextId,
      'record': record,
    };
  }

  /// Whether the applied proposal [id] can still be undone.
  bool canUndoCoachProposal(String id) {
    final p = _coachProposal(id);
    return p != null && p.state == CoachProposalState.applied && p.record['undo'] is Map;
  }

  /// Undoes the applied proposal [id]: the coach's data, the coach routines and their exercises' rules, the weekly
  /// plan and rotation go back exactly to how they were before it was applied, and the proposal is pending again.
  void undoCoachProposal(String id) {
    if (!canUndoCoachProposal(id)) return;
    final snap = (_coachProposal(id)!.record['undo'] as Map).cast<String, dynamic>();
    final keep = <String>{};
    final saved = [for (final x in snap['routines'] as List) (x as Map).cast<String, dynamic>()];
    for (final x in saved) {
      keep.add(((x['routine'] as Map)['id']) as String);
    }
    // Routines the proposal created go; the ones it changed or deleted come back where they were.
    routines.removeWhere((r) => coach.routineIds.containsValue(r.id) && !keep.contains(r.id));
    for (final x in saved) {
      final r = Routine.fromJson((x['routine'] as Map).cast<String, dynamic>());
      routines.removeWhere((o) => o.id == r.id);
      routines.insert(math.min(x['index'] as int, routines.length), r);
    }
    progressRules
      ..clear()
      ..addAll({
        for (final e in (snap['rules'] as Map).entries)
          e.key as String: ProgressRule.fromJson((e.value as Map).cast<String, dynamic>()),
      });
    weeklyPlan
      ..clear()
      ..addAll({for (final e in (snap['weeklyPlan'] as Map).entries) int.parse(e.key as String): e.value as String});
    planExtras
      ..clear()
      ..addAll({
        for (final e in (snap['planExtras'] as Map).entries)
          int.parse(e.key as String): [for (final x in e.value as List) x as String],
      });
    rotation = snap['rotation'] as bool;
    rotationIds
      ..clear()
      ..addAll([for (final x in snap['rotationIds'] as List) x as String]);
    rotationNextId = snap['rotationNext'] as String;
    final record = (snap['record'] as Map).cast<String, dynamic>();
    coach = CoachData.fromJson({
      ...(snap['coach'] as Map).cast<String, dynamic>(),
      'proposals': [
        for (final r in coach.proposals) r['id'] == id ? record : r,
      ],
    });
    _planChanged();
  }

  /// [coachRegenerate] with a block transition's new kind, start day and heavy-phase flag.
  void _coachRegenerateWith({String? blockKind, String? startsOn, bool? fromHeavyPhase}) {
    if (coach.block == null) return;
    final now = {
      for (final e in coach.routineIds.entries)
        if (routineById(e.value) case final r?) e.key: [...r.exerciseIds],
    };
    _coachWritePlan(CoachFacade.regeneratePlan(
      _coachInputs(),
      routineExercises: now,
      blockKind: blockKind,
      startsOn: startsOn,
      fromHeavyPhase: fromHeavyPhase,
    ));
  }

  // ---------- Nutrition (Phase 6) ----------

  /// The coach's calorie and macro targets, or null while the nutrition module is off. Worked out for the latest
  /// weigh-in (or the profile's weight), the profile's sex and activity, and what the coach knows. Needs no plan
  /// and no onboarding.
  CoachNutritionTargets? get coachNutritionTargets {
    if (!coach.isOn(CoachModule.nutrition)) return null;
    final kg = nutritionWeightKg, sex = profile.sex, activity = profile.activity;
    return _remember(
      'coachNutritionTargets',
      () => CoachFacade.nutritionTargets(bodyweightKg: kg, sex: sex, activity: activity, coach: coach),
      (kg, sex, activity, identityHashCode(coach)),
    );
  }

  /// Whether the goals in force are the coach's: the nutrition module is on and the user has not set their own.
  bool get coachSetsGoals => coach.isOn(CoachModule.nutrition) && !nutritionGoalsSet;

  /// Whether the user can go back to the coach's goals: the nutrition module is on and goals of their own are set.
  bool get coachCanRestoreGoals => coach.isOn(CoachModule.nutrition) && nutritionGoalsSet;

  /// Drops the user's own goals, every one of them (water, glass size, fibre, sugar and sodium included), so the
  /// coach's goals are in force again, rest days included. The goals go back to how a fresh install has them, and
  /// rest-day goals are dropped. Does nothing unless [coachCanRestoreGoals].
  void useCoachGoals() {
    if (!coachCanRestoreGoals) return;
    nutritionGoals = const NutritionGoals();
    nutritionGoalsSet = false;
    restGoals = null;
    _persist();
    notifyListeners();
  }

  /// Stores [phase] as the user's pick under `coach.nutrition.phase`, in place of the one that follows from the
  /// coaching goal.
  void setCoachNutritionPhase(CoachNutritionPhase phase) {
    if (coach.nutrition['phase'] == phase.wire) return;
    coach = coach.copyWith(nutrition: {...coach.nutrition, 'phase': phase.wire});
    _persist();
    notifyListeners();
  }

  /// The plain-words summary of every rule behind the coach's nutrition targets, for the reason sheet. Empty while
  /// the module is off. The texts are in English.
  List<String> coachNutritionRules() {
    final c = coachNutritionTargets;
    return c == null ? const [] : CoachFacade.ruleSummaries(c.ruleIds);
  }

  /// Set while the stock suggestion is worked out for [coachNutritionGoals], so the seam stays out of the way.
  bool _coachStockGoals = false;

  /// The suggested goals while the nutrition module is on: the coach's calories, protein, fat and carbs, with
  /// water, fibre, sugar, sodium and glass size as the app's own suggestion has them. Manually set goals still win,
  /// because [activeGoals] only asks for suggested goals when none are set.
  @override
  NutritionGoals? coachNutritionGoals() {
    if (_coachStockGoals) return null;
    final c = coachNutritionTargets;
    if (c == null) return null;
    final NutritionGoals stock;
    _coachStockGoals = true;
    try {
      stock = suggestedGoals;
    } finally {
      _coachStockGoals = false;
    }
    return stock.copyWith(kcal: c.kcal, protein: c.proteinG, fat: c.fatG, carbs: c.carbsG);
  }
}
