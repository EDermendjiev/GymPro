// SPDX-License-Identifier: GPL-3.0-only
// The coach's place in the app's state. Thin by design: it reads the app's state, asks CoachFacade, stores the
// answer in [coach] and notifies. The coaching rules live in the coach packages, never here.
part of 'fit_state.dart';

mixin CoachState on FitCore, LibraryState, SettingsState, PlacesState, StatsState, NutritionState, RoutinesState {
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
  /// coach's goals are in force again. The goals go back to how a fresh install has them; rest-day goals are kept.
  /// Does nothing unless [coachCanRestoreGoals].
  void useCoachGoals() {
    if (!coachCanRestoreGoals) return;
    nutritionGoals = const NutritionGoals();
    nutritionGoalsSet = false;
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
