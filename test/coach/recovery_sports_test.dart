// SPDX-License-Identifier: GPL-3.0-only
// Task 5.6: sports and injuries regenerate the plan; the sheets and the Home hint.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/adapters/catalog_adapter.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _monday = DateTime(2026, 11, 16, 9);

void _plan(List<int> days) {
  fit.coachApplyAnswers(CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: days));
}

final _lower = {ck.MuscleId.quads, ck.MuscleId.hamstrings, ck.MuscleId.glutes};

/// How many lower-body primary exercises the block's first-week session on [weekday] holds.
int _legWork(int weekday) {
  final library = {for (final e in coachExercises(fit.allExercises)) e.id: e};
  final s = fit.coach.block!.sessions.where((s) => s.weekIndex == 0 && ck.isoWeekday(s.date) == weekday).firstOrNull;
  if (s == null) return 0;
  return s.exercises
      .where((e) => library[e.exerciseId]!.muscles.any((m) => m.role == ck.MuscleRole.primary && _lower.contains(m.muscle)))
      .length;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: Scaffold(body: Center(child: child))));
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

  test('football on Saturday moves the leg work away from Friday', () {
    _plan(const [1, 2, 4, 5]);
    final before = _legWork(5);
    expect(before, greaterThan(0), reason: 'Friday trains legs without a sport');
    fit.setCoachSports([
      CoachSportEntry(sportId: 'football', weekdays: const [6], intensity: CoachSportIntensity.match, minutes: 90),
    ]);
    expect(fit.coach.sports.single.name, 'Football (soccer)');
    expect(_legWork(5), lessThan(before));
    expect(fit.coachSports.single.weekdays, [6]);
  });

  test('a knee (quads) injury removes axial and impact lower-body picks', () {
    _plan(const [1, 3, 5]);
    final library = {for (final e in coachExercises(fit.allExercises)) e.id: e};
    bool loadsKnee(String id) {
      final e = library[id]!;
      return (e.axialLoad || e.impactLowerBody) &&
          e.muscles.any((m) => m.role == ck.MuscleRole.primary && m.muscle == ck.MuscleId.quads);
    }

    bool planned() => fit.coach.block!.sessions.any((s) => s.exercises.any((e) => loadsKnee(e.exerciseId)));
    expect(planned(), isTrue);
    fit.addCoachInjury(CoachArea.quads, CoachInjurySeverity.pain);
    expect(planned(), isFalse);
    final id = fit.coachInjuries.single.id;
    fit.healCoachInjury(id);
    expect(fit.coachInjuries.single.active, isFalse);
  });

  test('without a plan nothing is generated, and the change is still kept', () {
    fit.addCoachInjury(CoachArea.erectors, CoachInjurySeverity.niggle);
    expect(fit.coach.block, isNull);
    expect(fit.coach.toJson()['injuries'], hasLength(1));
  });

  testWidgets('the sports sheet adds a sport at phone width', (tester) async {
    await _pump(tester, Builder(builder: (c) => TextButton(onPressed: () => coachShowSportsSheet(c), child: const Text('go'))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coach-sport-running')));
    await tester.tap(find.byKey(const ValueKey('coach-sport-day-2')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('coach-sport-add')));
    await tester.tap(find.byKey(const ValueKey('coach-sport-add')));
    await tester.pumpAndSettle();
    expect(fit.coachSports.single.sportId, 'running');
    expect(fit.coachSports.single.minutes, 45);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the injury sheet adds an injury', (tester) async {
    await _pump(tester, Builder(builder: (c) => TextButton(onPressed: () => coachShowInjurySheet(c), child: const Text('go'))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coach-injury-area-CoachArea.rearDelts')));
    await tester.tap(find.byKey(const ValueKey('coach-injury-severity-CoachInjurySeverity.injury')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('coach-injury-add')));
    await tester.tap(find.byKey(const ValueKey('coach-injury-add')));
    await tester.pumpAndSettle();
    final i = fit.coachInjuries.single;
    expect((i.area, i.severity, i.active), (CoachArea.rearDelts, CoachInjurySeverity.injury, true));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the Home hint shows with a plan and no sports or injuries, and stays dismissed', (tester) async {
    fit.coach = CoachData.empty().withModule(CoachModule.progression, true).withModule(CoachModule.plan, true);
    await _pump(tester, const CoachHomeSlot());
    expect(find.byType(CoachHomeHint), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coach-hint-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byType(CoachHomeHint), findsNothing);
    expect(fit.coachShowsHomeHint, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });
}
