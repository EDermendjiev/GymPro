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
}
