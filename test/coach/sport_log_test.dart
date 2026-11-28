// SPDX-License-Identifier: GPL-3.0-only
// Sport sessions logged for one day: storage, the quick workout around them, and the sheet and its entry points.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/screens/start_sheet.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:gymmane/widgets/day_off_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _monday = DateTime(2026, 11, 16, 9);
final DateTime _sunday = DateTime(2026, 11, 15);

void _plan() {
  fit.coachApplyAnswers(
      CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: const [1, 2, 4, 5]));
}

Future<void> _pump(WidgetTester tester, void Function(BuildContext) open) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: Center(child: Builder(builder: (c) => TextButton(onPressed: () => open(c), child: const Text('go'))))),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
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

  tearDown(() => fit.coachClock = DateTime.now);

  test('a logged session is stored for its day, survives a reload, and can be removed', () {
    _plan();
    fit.logCoachSport(_sunday, 'football', CoachSportIntensity.match, 90);
    fit.logCoachSport(_sunday, 'running', CoachSportIntensity.light, 30);
    final logs = fit.coachSportLogsOn(_sunday);
    expect([for (final l in logs) (l.id, l.day, l.sportId, l.minutes)], [
      ('2026-11-15#1', '2026-11-15', 'football', 90),
      ('2026-11-15#2', '2026-11-15', 'running', 30),
    ]);
    expect(fit.coachSportLogsOn(_monday), isEmpty);

    final back = CoachData.fromJson(fit.coach.toJson());
    expect([for (final l in back.sportLogs) l.toJson()], [for (final l in logs) l.toJson()]);

    fit.removeCoachSportLog('2026-11-15#1');
    expect([for (final l in fit.coachSportLogsOn(_sunday)) l.sportId], ['running']);
    // The plan is not generated again: a one-day session does not change the block.
    expect(fit.coach.sports, isEmpty);
  });

  test('a stored entry that cannot be read is dropped, the others are kept', () {
    final c = CoachData.fromJson({
      'v': 1,
      'sportLogs': [
        {'id': 'a', 'day': '2026-11-15', 'sportId': 'football', 'intensity': 'match', 'minutes': 90},
        {'id': 'b', 'day': 'yesterday', 'sportId': 'football', 'intensity': 'match', 'minutes': 90},
        {'id': 'c', 'day': '2026-11-15', 'sportId': 'football', 'intensity': 'brutal', 'minutes': 90},
        'junk',
      ],
    });
    expect([for (final l in c.sportLogs) l.id], ['a']);
    expect(CoachData.fromJson({'v': 1}).isEmpty, isTrue);
  });

  test('nothing shows while every coach module is off', () {
    expect(fit.coachLogsSports, isFalse);
    expect(fit.coachSportLogsOn(_sunday), isEmpty);
  });

  test('a session the day before, the day itself or the day after puts its muscles last in a quick workout', () {
    _plan();
    List<String> near(DateTime d) => CoachFacade.sportMusclesNear(fit.coach, d);
    expect(near(_monday), isEmpty);
    fit.logCoachSport(_sunday, 'football', CoachSportIntensity.match, 90);
    expect(near(_monday), containsAll(['quads', 'hamstrings', 'glutes', 'calves']));
    expect(near(DateTime(2026, 11, 14)), containsAll(['quads', 'hamstrings']));
    expect(near(DateTime(2026, 11, 17)), isEmpty, reason: 'two days later it no longer counts');
    // A weekly sport on a near weekday still counts the same way.
    fit.removeCoachSportLog(fit.coachSportLogsOn(_sunday).single.id);
    fit.setCoachSports([
      CoachSportEntry(sportId: 'football', weekdays: const [7], intensity: CoachSportIntensity.match, minutes: 90),
    ]);
    expect(near(_monday), containsAll(['quads', 'hamstrings']));
  });

  test("a sport day counts once toward the weekly goal, once it has come, and leaves the day's plan alone", () {
    fit.coachClock = DateTime.now;
    _plan();
    final today = fit.dateForWeekday(fit.todayIndex);
    final before = fit.daysDoneThisWeek;
    final planDone = fit.todayPlanDone;
    fit.logCoachSport(today, 'football', CoachSportIntensity.match, 90);
    fit.logCoachSport(today, 'running', CoachSportIntensity.light, 30);
    expect(fit.daysDoneThisWeek, before + 1, reason: 'two sessions on one day are one day');
    expect(fit.coachSportDay(today), isTrue);
    expect(fit.todayPlanDone, planDone, reason: "today's routine still waits");
    fit.setCheckedIn(today, true);
    expect(fit.daysDoneThisWeek, before + 1, reason: 'a checked-in sport day is still one day');
    if (fit.todayIndex < 6) {
      final tomorrow = fit.dateForWeekday(fit.todayIndex + 1);
      fit.logCoachSport(tomorrow, 'football', CoachSportIntensity.match, 90);
      expect(fit.coachSportDay(tomorrow), isFalse);
      expect(fit.daysDoneThisWeek, before + 1, reason: 'a planned match counts once its day comes');
    }
  });

  testWidgets('"Log a sport session" in the start sheet logs one for today at phone width', (tester) async {
    _plan();
    fit.setCoachSports([
      CoachSportEntry(sportId: 'tennis', weekdays: const [3], intensity: CoachSportIntensity.hard, minutes: 60),
    ]);
    await _pump(tester, (c) => showStartSheet(c));
    await tester.ensureVisible(find.byKey(const ValueKey('coach-sport-log-option')));
    await tester.tap(find.byKey(const ValueKey('coach-sport-log-option')));
    await tester.pumpAndSettle();
    // The user's own sport comes first and is picked, with its usual intensity and length.
    await tester.tap(find.byKey(const ValueKey('coach-sport-log-football')));
    await tester.tap(find.byKey(const ValueKey('coach-sport-log-intensity-CoachSportIntensity.match')));
    await tester.tap(find.byKey(const ValueKey('coach-sport-log-minutes-90')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('coach-sport-log-save')));
    await tester.tap(find.byKey(const ValueKey('coach-sport-log-save')));
    await tester.pumpAndSettle();
    final l = fit.coachSportLogsOn(DateTime.now()).single;
    expect((l.sportId, l.intensity, l.minutes), ('football', CoachSportIntensity.match, 90));
    expect(find.byKey(const ValueKey('coach-sport-log-save')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the sport sheet starts from the user\'s own sport', (tester) async {
    _plan();
    fit.setCoachSports([
      CoachSportEntry(sportId: 'tennis', weekdays: const [3], intensity: CoachSportIntensity.hard, minutes: 60),
    ]);
    await _pump(tester, (c) => coachShowSportLogSheet(c, _sunday));
    await tester.ensureVisible(find.byKey(const ValueKey('coach-sport-log-save')));
    await tester.tap(find.byKey(const ValueKey('coach-sport-log-save')));
    await tester.pumpAndSettle();
    final l = fit.coachSportLogsOn(_sunday).single;
    expect((l.sportId, l.intensity, l.minutes), ('tennis', CoachSportIntensity.hard, 60));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a day of the week opens the sport sheet for that day, and removes from it', (tester) async {
    _plan();
    fit.logCoachSport(_sunday, 'football', CoachSportIntensity.match, 90);
    await _pump(tester, (c) => showDayOffSheet(c, _sunday));
    expect(find.text('Football (soccer)'), findsOneWidget, reason: 'the logged sport is named on the line');
    await tester.tap(find.text('Sport session'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coach-sport-log-remove-2026-11-15#1')));
    await tester.pumpAndSettle();
    expect(fit.coachSportLogsOn(_sunday), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('with every module off the start sheet looks as before', (tester) async {
    await _pump(tester, (c) => showStartSheet(c));
    expect(find.byType(StartSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('coach-sport-log-option')), findsNothing);
  });

  testWidgets('with every module off the day sheet looks as before', (tester) async {
    await _pump(tester, (c) => showDayOffSheet(c, _sunday));
    expect(find.text('Sport session'), findsNothing);
  });
}
