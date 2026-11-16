// SPDX-License-Identifier: GPL-3.0-only
// Task 5.1: the coach's check-ins come from what the app already has, and a missing source is null, not zero.
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/health_metrics.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _today = DateTime(2026, 11, 18, 20);

CoachCheckin? _on(String day) => fit.coachCheckins().where((c) => c.day == day).firstOrNull;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.coachClock = () => _today;
  });

  tearDown(() => fit.coachClock = DateTime.now);

  test('nothing logged: no check-ins at all', () {
    expect(fit.coachCheckins(), isEmpty);
  });

  test('sleep comes from Health Connect, in hours; the other sources stay null', () {
    fit.healthByDay[HealthMetric.sleep] = {'2026-11-17': [450]};
    final c = _on('2026-11-17')!;
    expect(c.sleepHours, 7.5);
    expect((c.energy, c.stress, c.bodyweightKg), (null, null, null));
    expect(c.soreness, isEmpty);
  });

  test('energy is the rating of the day\'s last rated workout; the sleep rating is not hours and is not used', () {
    fit.sessions.add(LoggedSession(DateTime(2026, 11, 16, 8), 600, [], energy: 2, sleep: 1));
    fit.sessions.add(LoggedSession(DateTime(2026, 11, 16, 18), 600, [], energy: 4, sleep: 5));
    fit.sessions.add(LoggedSession(DateTime(2026, 11, 16, 20), 600, []));
    final c = _on('2026-11-16')!;
    expect(c.energy, 4);
    expect(c.sleepHours, isNull);
  });

  test('bodyweight is the day\'s last weigh-in', () {
    fit.bodyweight.add(BodyweightEntry(DateTime(2026, 11, 15, 7), 80.2));
    fit.bodyweight.add(BodyweightEntry(DateTime(2026, 11, 15, 21), 80.9));
    expect(_on('2026-11-15')!.bodyweightKg, 80.9);
  });

  test('soreness comes from coach.soreness; unknown areas and levels are left out', () {
    fit.coach = CoachData.fromJson({
      'soreness': {
        '2026-11-14': {'hamstrings': 'sore', 'erectors': 'pain', 'elbow': 'sore', 'quads': 'tight'},
      },
    });
    expect(_on('2026-11-14')!.soreness, {'hamstrings': 'sore', 'erectors': 'pain'});
  });

  test('only the last 35 days are read', () {
    fit.healthByDay[HealthMetric.sleep] = {'2026-10-14': [480], '2026-10-15': [480]};
    expect([for (final c in fit.coachCheckins()) c.day], ['2026-10-15']);
  });
}
