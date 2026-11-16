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
}
