// SPDX-License-Identifier: GPL-3.0-only
// The plan designer's input, built from the app's state.
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _monday = DateTime(2026, 11, 16, 9);

void _answered(CoachAnswers a, {List<int> days = const [1, 2, 4, 5], int minutes = 60}) {
  fit.coach = fit.coach.copyWith(
    profile: CoachProfile.answered(
      goal: a.goal!,
      status: a.status ?? CoachStatus.intermediate,
      days: days,
      minutes: minutes,
      activity: 1.725,
      answers: a,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.coachClock = () => _monday;
  });

  test('the answers, the body data and the place reach the planner', () {
    fit.profile
      ..age = 57
      ..sex = 'female'
      ..heightCm = 165;
    _answered(CoachAnswers(
      goal: CoachGoal.strength,
      status: CoachStatus.advanced,
      style: CoachStyle.upperLower,
      sessionPref: CoachSessionPref.fewerLonger,
      years: CoachYears.threeToFive,
      focus: [CoachArea.glutes, CoachArea.forearms],
      lifts: [CoachLift.squat, CoachLift.bench],
      knownLifts: {CoachLift.squat: 120},
    ));
    final p = fit.coachPlannerInput();
    expect(p['goal'], 'strength');
    expect(p['answeredStatus'], 'advanced');
    expect(p['years'], 'three_to_five');
    expect(p['age'], 57);
    expect(p['sex'], 'female');
    expect(p['heightCm'], 165);
    expect(p['bodyweightKg'], fit.nutritionWeightKg);
    expect(p['lifestyle'], 'very_active');
    expect(p['days'], [1, 2, 4, 5]);
    expect(p['minutes'], 60);
    expect(p['style'], 'upper_lower');
    expect(p['sessionPref'], 'fewer_longer');
    expect(p['focus'], ['glutes'], reason: 'forearms are not a muscle the plan tracks');
    expect(p['strengthLifts'], ['squat', 'bench']);
    expect(p['knownLifts'], {'squat': 120.0});
    expect(p.containsKey('logStatus'), isFalse, reason: 'no logs yet');
  });

  test('the slot tags follow the equipment and the dislikes', () {
    _answered(CoachAnswers(goal: CoachGoal.leanGain));
    final gym = {...fit.coachPlannerInput()['availableTags'] as List};
    expect(gym, containsAll(['squat_free', 'press_flat', 'pull_vertical', 'leg_curl']));
    final home = fit.addPlace('Home', equipment: {'Dumbbell', 'Band'});
    fit.setActivePlace(home);
    final p = fit.coachPlannerInput();
    expect({...p['equipment'] as List}, {'dumbbell', 'band', 'bodyweight'});
    final dumbbells = {...p['availableTags'] as List};
    expect(gym.containsAll(dumbbells), isTrue);
    expect(dumbbells.length, lessThan(gym.length));
  });

  test('accepted volume changes reach the planner', () {
    _answered(CoachAnswers(goal: CoachGoal.leanGain));
    fit.coach = fit.coach.copyWith(review: {
      'targetAdjustments': {'chest': 2},
    });
    expect(fit.coachPlannerInput()['targetAdjustments'], {'chest': 2.0});
  });

  test('without a profile the planner gets the coach\'s defaults and the weekly goal\'s days', () {
    final p = fit.coachPlannerInput();
    expect(p['goal'], 'lean_gain');
    expect(p['minutes'], 60);
    expect(p['days'], fit.coachSpreadDays(fit.profile.weeklyGoal));
    expect(p['style'], 'auto');
  });

  test('eight weeks of logs give the planner a status', () {
    _answered(CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.novice));
    final squat = fit.allExercises.firstWhere((e) => e.name == 'Barbell Full Squat');
    for (var w = 12; w >= 1; w--) {
      for (final d in [0, 3]) {
        final day = _monday.subtract(Duration(days: w * 7 - d));
        fit.sessions.add(LoggedSession(day, 3600, [
          LoggedExercise(squat.id, squat.name, squat.primary, [
            for (var s = 0; s < 3; s++) LoggedSet(6, 100 + (12 - w) * 2.5),
          ]),
        ]));
      }
    }
    expect(fit.coachPlannerInput()['logStatus'], isNotNull);
  });
}
