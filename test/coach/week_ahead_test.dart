// SPDX-License-Identifier: GPL-3.0-only
// The week ahead on Home: once the day's session is done, the rest of the week's plan stays in view.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/desktop.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/screens/home_screen.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, {bool desktop = false}) async {
  tester.view.physicalSize = desktop ? const Size(1440, 1000) : const Size(1080, 2340);
  tester.view.devicePixelRatio = desktop ? 1 : 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: DesktopScope(wide: desktop, child: const Scaffold(body: HomeScreen())),
  ));
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> ids;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    setAppLanguage('en');
    ids = fit.allExercises.take(4).map((e) => e.id).toList();
  });

  String routine(String name, int exercises) {
    final r = fit.createRoutine(name);
    for (final id in ids.take(exercises)) {
      fit.toggleRoutineExercise(r, id);
    }
    return r;
  }

  void doneToday(String routineId) => fit.sessions.add(LoggedSession(
        today.copyWith(hour: 12),
        1800,
        [LoggedExercise(ids[0], 'x', 'chest', [LoggedSet(8, 60)])],
        routineId: routineId,
      ));

  test('nothing is planned: no rows', () {
    expect(coachWeekAheadRows(), isEmpty);
  });

  test('only today is planned: no rows, the day card covers it', () {
    fit.assignRoutineToDay(today.weekday, routine('Push', 2));
    expect(coachWeekAheadRows(), isEmpty);
  });

  test('a fixed week lists the next six days, rest days included', () {
    final push = routine('Push', 2);
    final legs = routine('Legs', 3);
    fit.assignRoutineToDay(today.weekday, push);
    fit.assignRoutineToDay(shiftDays(today, 2).weekday, legs);
    final rows = coachWeekAheadRows();
    expect(rows, hasLength(6));
    expect(rows[0].day, t.tomorrow);
    expect(rows[0].routine, isNull);
    expect(rows[1].day, t.weekdayShort(shiftDays(today, 2).weekday));
    expect(rows[1].routine?.id, legs);
    expect(rows.skip(2).every((r) => r.routine == null), isTrue);
  });

  test('a rotation lists the steps after today, once round', () {
    final a = routine('A', 1);
    final b = routine('B', 1);
    final c = routine('C', 1);
    fit.setRotation(true);
    fit.toggleRotationRoutine(a);
    fit.toggleRotationRoutine(b);
    fit.toggleRotationRoutine(c);
    fit.setRotationNext(a);
    expect(coachWeekAheadRows().map((r) => r.routine?.id), [b, c]);

    doneToday(a);
    fit.setRotationNext(b); // what saving A's workout does
    final rows = coachWeekAheadRows();
    expect(rows.map((r) => r.routine?.id), [b, c, a]);
    expect(rows.first.day, t.liveNext);
  });

  for (final desktop in [false, true]) {
    final layout = desktop ? 'desktop' : 'phone';

    testWidgets('$layout: after the day\'s session the week ahead is on Home and opens a routine', (tester) async {
      final push = routine('Push', 2);
      final legs = routine('Legs', 3);
      fit.assignRoutineToDay(today.weekday, push);
      fit.assignRoutineToDay(shiftDays(today, 2).weekday, legs);
      doneToday(push);
      await _pump(tester, desktop: desktop);

      expect(find.text(t.routineDoneToday), findsOneWidget);
      final card = find.byKey(const ValueKey('coach-week-ahead'));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Legs')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(t.tomorrow)), findsOneWidget);

      final row = find.descendant(of: card, matching: find.text('Legs'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      expect(fit.activeRoutineId, legs);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$layout: no card without a plan', (tester) async {
      await _pump(tester, desktop: desktop);
      expect(find.byKey(const ValueKey('coach-week-ahead')), findsNothing);
    });
  }
}
