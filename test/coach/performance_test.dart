// SPDX-License-Identifier: GPL-3.0-only
// Task 7.2: what the coach costs on a three-year history. The bounds are generous on purpose, so slower CI runners
// do not flake; the numbers this prints on the development machine are recorded in docs/coach/BASELINE.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Monday, the day every measurement happens on.
final DateTime _monday = DateTime(2026, 11, 16, 9);

String _id(String name) => fit.allExercises.firstWhere((e) => e.name == name).id;

/// Three years of logs, four sessions a week (Monday, Tuesday, Thursday, Friday) of six exercises, slowly getting
/// heavier, with a weigh-in every other day.
void _seedThreeYears() {
  final ids = [
    for (final n in ['Barbell Full Squat', 'Barbell Bench Press', 'Barbell Bent Over Row', 'Leg Press',
      'Cable Pulldown', 'Dumbbell Lateral Raise'])
      _id(n),
  ];
  for (var d = 3 * 364; d > 0; d--) {
    final day = DateTime(_monday.year, _monday.month, _monday.day - d, 18);
    if (d.isEven) fit.bodyweight.add(BodyweightEntry(day.subtract(const Duration(hours: 11)), 80 + (d % 30) / 10));
    if (!const {DateTime.monday, DateTime.tuesday, DateTime.thursday, DateTime.friday}.contains(day.weekday)) continue;
    final load = 40.0 + (3 * 364 - d) ~/ 28 * 2.5;
    fit.sessions.add(LoggedSession(day, 3600, [
      for (final id in ids)
        LoggedExercise(id, fit.exerciseById(id)!.name, fit.exerciseById(id)!.primary,
            [LoggedSet(8, load, rpe: 8), LoggedSet(8, load, rpe: 8.5), LoggedSet(7, load, rpe: 9)]),
    ]));
  }
}

void _coachOn() {
  fit.coach = fit.coach.copyWith(
    profile: CoachProfile.answered(
        goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: const [1, 2, 4, 5], minutes: 60, activity: 1.55),
  );
  for (final m in CoachModule.values) {
    fit.setCoachModule(m, true);
  }
  fit.coachBuildPlan();
}

/// Mean milliseconds of [runs] calls of [f], after one call to warm up.
double _ms(void Function() f, {int runs = 5, void Function()? before}) {
  before?.call();
  f();
  var us = 0;
  for (var i = 0; i < runs; i++) {
    before?.call();
    final sw = Stopwatch()..start();
    f();
    sw.stop();
    us += sw.elapsedMicroseconds;
  }
  return us / runs / 1000;
}

void _report(String what, double ms) {
  // ignore: avoid_print
  print('perf: $what: ${ms.toStringAsFixed(ms < 1 ? 4 : 1)} ms');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.coachClock = () => _monday;
    _seedThreeYears();
  });

  tearDown(() => fit.coachClock = DateTime.now);

  test('block generation on a three-year history stays under 250 ms', () {
    _coachOn();
    final ms = _ms(fit.coachBuildPlan);
    _report('coachBuildPlan, ${fit.sessions.length} sessions', ms);
    expect(fit.coach.block, isNotNull);
    expect(ms, lessThan(250));
  });

  test('the weekly review on a three-year history stays under 500 ms', () {
    _coachOn();
    // Due: last reviewed two weeks ago. Each run starts from the same coach data.
    final due = fit.coach.copyWith(review: {...fit.coach.review, 'lastWeekStart': '2026-11-02'});
    final ms = _ms(fit.coachTick, before: () => fit.coach = due);
    _report('coachTick with the weekly and weigh-in reviews due', ms);
    expect(fit.coach.review['lastWeekStart'], isNot('2026-11-02'), reason: 'the review ran');
    expect(ms, lessThan(500));
  });

  test('loading a three-year history: the coach adds next to nothing while it is off', () async {
    // Store keeps the SharedPreferences instance of the first test, so the stored state is read and written
    // through Store.
    Map<String, dynamic> snapshot() {
      fit.persistNow();
      return Store.instance.load();
    }

    final states = <String, Map<String, dynamic>>{'off': snapshot()};
    _coachOn();
    fit.coachTick(); // the first run only notes the week, so nothing is due afterwards
    states['on'] = snapshot();
    // The same app data (the plan's routines, weekly plan and Auto rules) without the coach key: what upstream
    // would load for it.
    states['planNoCoach'] = {...states['on']!}..remove('coach');
    fit.coach = fit.coach.copyWith(review: {...fit.coach.review, 'lastWeekStart': '2026-11-02'});
    states['due'] = snapshot();

    // The stored states take turns, so warm-up and drift hit them alike.
    final total = {for (final k in states.keys) k: 0};
    const rounds = 10;
    for (var r = -2; r < rounds; r++) {
      for (final e in states.entries) {
        await Store.instance.save(e.value);
        final sw = Stopwatch()..start();
        fit.loadFromStore();
        sw.stop();
        if (r >= 0) total[e.key] = total[e.key]! + sw.elapsedMicroseconds;
        if (e.key == 'due') expect(fit.coach.review['lastWeekStart'], isNot('2026-11-02'), reason: 'the review ran');
        if (e.key == 'off' || e.key == 'planNoCoach') expect(fit.coach.isOn(CoachModule.progression), isFalse);
      }
    }
    double ms(String k) => total[k]! / rounds / 1000;

    await Store.instance.save(states['off']!);
    fit.loadFromStore();
    final tickOff = _ms(fit.coachTick, runs: 10000);
    await Store.instance.save(states['on']!);
    fit.loadFromStore();
    final tickOn = _ms(fit.coachTick, runs: 20);
    final raw = (states['on']!['coach'] as Map).cast<String, dynamic>();
    final parse = _ms(() => CoachData.fromJson(raw), runs: 20);

    // ignore: avoid_print
    print('perf: coachTick, every module off: ${(tickOff * 1000).toStringAsFixed(3)} us');
    _report('coachTick, every module on, no review due', tickOn);
    _report('reading the coach key (CoachData.fromJson)', parse);
    _report('loadFromStore, every module off', ms('off'));
    _report('loadFromStore, the plan data without the coach key', ms('planNoCoach'));
    _report('loadFromStore, every module on, no review due', ms('on'));
    _report('loadFromStore, every module on, weekly review due', ms('due'));
    final ratio = ms('off') / (ms('off') - tickOff);
    // ignore: avoid_print
    print('perf: loadFromStore off / without the coach tick: ${ratio.toStringAsFixed(6)}; '
        'on / same data without the coach: ${(ms('on') / ms('planNoCoach')).toStringAsFixed(3)}; '
        'review due / same data without the coach: ${(ms('due') / ms('planNoCoach')).toStringAsFixed(3)}');
    expect(ratio, lessThan(1.05));
    expect(ms('on'), lessThan(ms('planNoCoach') + 100));
    expect(ms('due'), lessThan(ms('planNoCoach') + 500));
  });
}
