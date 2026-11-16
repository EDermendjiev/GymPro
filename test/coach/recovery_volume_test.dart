// SPDX-License-Identifier: GPL-3.0-only
// Task 5.7: with the recovery module on, the muscle map's weekly view measures against the block's targets for the
// current week, counting sets the coach's way.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/state/fit_state.dart' as fs show StatsState;
import 'package:shared_preferences/shared_preferences.dart';

String _id(String name) => fit.allExercises.firstWhere((e) => e.name == name).id;

double _target(String muscle) {
  final block = fit.coach.block!;
  final now = DateTime.now();
  final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final week = ((ck.daysBetween(block.startsOn, ck.mondayOf(today))) / 7).floor().clamp(0, block.weeks - 1);
  final mine = {
    'chest': {ck.MuscleId.chest},
    'shoulders': {ck.MuscleId.frontDelts, ck.MuscleId.sideDelts, ck.MuscleId.rearDelts},
  }[muscle]!;
  return block.weeklyTargets
      .where((t) => t.weekIndex == week && mine.contains(t.muscle))
      .fold(0.0, (a, t) => a + t.targetSets);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.coachClock = DateTime.now;
    final bench = _id('Barbell Bench Press');
    fit.sessions.add(LoggedSession(DateTime.now(), 3600, [
      LoggedExercise(bench, 'Barbell Bench Press', 'chest', [for (var i = 0; i < 4; i++) LoggedSet(8, 60, rpe: 8)]),
    ]));
  });

  test('module off: the stock target and the stock count', () {
    final heat = fit.muscleHeatThisWeek;
    expect(heat['chest'], closeTo(4 / fs.StatsState.weeklySetTarget, 1e-9));
  });

  test('module on: the block\'s target for this week, per muscle, with the shoulders\' three delts added up', () {
    fit.coachApplyAnswers(CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: [1, 3, 5]));
    fit.setCoachModule(CoachModule.recovery, true);
    final chest = _target('chest');
    expect(fit.coachWeeklySetTarget('chest'), chest);
    expect(fit.coachWeeklySetTarget('shoulders'), _target('shoulders'));
    expect(fit.coachWeeklySetTarget('obliques'), isNull);
    final sets = fit.muscleSetsThisWeek;
    expect(sets['chest'], greaterThan(0));
    expect(fit.muscleHeatThisWeek['chest'], closeTo((sets['chest']! / chest).clamp(0.0, 1.0), 1e-9));
    fit.setCoachModule(CoachModule.recovery, false);
    expect(fit.coachWeeklySetTarget('chest'), isNull);
  });
}
