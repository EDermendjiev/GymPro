// SPDX-License-Identifier: GPL-3.0-only
// Task 5.2: soreness and pain reports are stored by date, persisted, and dropped after 28 days.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _now = DateTime(2026, 11, 18, 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    _now = DateTime(2026, 11, 18, 20);
    fit.coachClock = () => _now;
  });

  tearDown(() => fit.coachClock = DateTime.now);

  test('a report is stored under its day by the coach\'s muscle name, and cleared again', () {
    fit.setCoachSoreness(CoachArea.hamstrings, CoachSoreness.sore);
    fit.setCoachSoreness(CoachArea.erectors, CoachSoreness.pain);
    expect(fit.coach.toJson()['soreness'], {
      '2026-11-18': {'hamstrings': 'sore', 'erectors': 'pain'},
    });
    expect(fit.coachSorenessOn(), {CoachArea.hamstrings: CoachSoreness.sore, CoachArea.erectors: CoachSoreness.pain});
    fit.setCoachSoreness(CoachArea.hamstrings, null);
    fit.setCoachSoreness(CoachArea.erectors, null);
    expect(fit.coach.toJson().containsKey('soreness'), isFalse);
  });

  test('reports survive a save and a reload, and reach the check-ins', () {
    fit.setCoachSoreness(CoachArea.quads, CoachSoreness.pain, day: DateTime(2026, 11, 16));
    fit.persistNow();
    fit.coach = CoachData.empty();
    fit.loadFromStore();
    expect(jsonEncode(fit.coach.toJson()['soreness']), '{"2026-11-16":{"quads":"pain"}}');
    expect(fit.coachCheckins().single.soreness, {'quads': 'pain'});
  });

  test('a report older than 28 days is dropped at the next change', () {
    fit.setCoachSoreness(CoachArea.chest, CoachSoreness.sore, day: DateTime(2026, 10, 22));
    fit.setCoachSoreness(CoachArea.back, CoachSoreness.sore, day: DateTime(2026, 10, 21));
    expect((fit.coach.toJson()['soreness'] as Map).keys, ['2026-10-22']);
    _now = DateTime(2026, 11, 19, 8);
    fit.setCoachSoreness(CoachArea.calves, CoachSoreness.sore);
    expect((fit.coach.toJson()['soreness'] as Map).keys, ['2026-11-19']);
  });

  testWidgets('the summary row opens the sheet, and tapping a level stores it', (tester) async {
    fit.coach = CoachData.empty()
        .withModule(CoachModule.progression, true)
        .withModule(CoachModule.plan, true)
        .withModule(CoachModule.recovery, true);
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const Scaffold(body: CoachSorenessRow())));
    await tester.tap(find.byKey(const ValueKey('coach-soreness-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coach-sore-chest-CoachSoreness.pain')));
    await tester.pumpAndSettle();
    expect(fit.coachSorenessOn(), {CoachArea.chest: CoachSoreness.pain});
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1)); // the debounced save
  });

  testWidgets('the row draws nothing while the recovery module is off', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const Scaffold(body: CoachSorenessRow())));
    expect(find.byKey(const ValueKey('coach-soreness-row')), findsNothing);
  });
}
