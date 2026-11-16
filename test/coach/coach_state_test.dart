// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _full() =>
    (jsonDecode(File('test/coach/data/coach_full.json').readAsStringSync()) as Map).cast<String, dynamic>();

List<bool> _switches() => [for (final m in CoachModule.values) fit.coach.isOn(m)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  test('a fresh state is stored without a coach key', () {
    expect(fit.coach.isEmpty, isTrue);
    expect(fit.toJson().containsKey('coach'), isFalse);
  });

  test('a switch survives a save and a reload', () {
    fit.setCoachModule(CoachModule.progression, true);
    fit.persistNow();
    fit.coach = CoachData.empty();
    fit.loadFromStore();
    expect(_switches(), [true, false, false, false]);
  });

  test('export, reset and import bring back the whole coach value', () {
    fit.coach = CoachData.fromJson(_full());
    final backup = fit.exportJson();
    fit.resetAllData();
    expect(fit.coach.isEmpty, isTrue);
    expect(fit.toJson().containsKey('coach'), isFalse);
    expect(fit.importJson(backup), isTrue);
    expect(jsonDecode(jsonEncode(fit.toJson()['coach'])), _full());
  });

  test('a backup without a coach key leaves every module off', () {
    fit.setCoachModule(CoachModule.progression, true);
    fit.setCoachModule(CoachModule.nutrition, true);
    final backup = jsonDecode(fit.exportJson()) as Map<String, dynamic>;
    backup.remove('coach');
    expect(fit.importJson(jsonEncode(backup)), isTrue);
    expect(_switches(), [false, false, false, false]);
    expect(fit.toJson().containsKey('coach'), isFalse);
  });

  test('a backup with a coach value nobody can read still imports, and the value is kept', () {
    final backup = jsonDecode(fit.exportJson()) as Map<String, dynamic>;
    backup['coach'] = {'on': 'everything', 'block': 42};
    expect(fit.importJson(jsonEncode(backup)), isTrue);
    expect(_switches(), [false, false, false, false]);
    expect(fit.toJson()['coach']['block'], 42);
  });

  test('turning progression off turns plan and recovery off', () {
    for (final m in CoachModule.values) {
      fit.setCoachModule(m, true);
    }
    expect(_switches(), [true, true, true, true]);
    fit.setCoachModule(CoachModule.progression, false);
    expect(_switches(), [false, false, false, true]);
  });

  test('a switch change notifies and is saved', () {
    var calls = 0;
    void listener() => calls++;
    fit.addListener(listener);
    addTearDown(() => fit.removeListener(listener));
    fit.setCoachModule(CoachModule.nutrition, true);
    expect(calls, 1);
    fit.persistNow();
    expect(Store.instance.load()['coach']['on']['nutrition'], isTrue);
  });

  test('reset clears the coach', () {
    fit.coach = CoachData.fromJson(_full());
    fit.resetAllData();
    expect(fit.coach.isEmpty, isTrue);
  });

  test('with every switch off the seams give no answer', () {
    fit.coach = CoachData.fromJson(_full()).withModule(CoachModule.progression, false);
    expect(fit.coachNextPlan('x'), isNull);
    expect(fit.coachOpeningSets('x'), isNull);
    expect(fit.coachTargetLabel('x'), isNull);
    expect(fit.coachWhy('x'), isNull);
    expect(fit.coachWeeklySetTarget('chest'), isNull);
    expect(fit.coachDeloadWeek(), isNull);
    expect(fit.coachNutritionGoals(), isNull);
    expect(() => fit.coachSetLogged(0, 0), returnsNormally);
  });
}
