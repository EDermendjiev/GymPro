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
}
