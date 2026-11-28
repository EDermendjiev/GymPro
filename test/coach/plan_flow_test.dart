// SPDX-License-Identifier: GPL-3.0-only
// Phase 4 exit: a fresh install, onboarding with the four choices (goal, experience, days and length, place), the
// plan questions and the plan preview, Home shows today's generated session, and starting it opens the block's sets. Also: "Just log workouts", the Home
// card's "Why this plan", the train screen's length chips and Settings › Coach › "Build me a plan".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/app/gymmane_app.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:gymmane/widgets/ui_kit.dart' show titleCase;
import 'package:shared_preferences/shared_preferences.dart';

/// A large phone (480 × 960 points). In the test font, whose glyphs are wider than the app's, the stock units
/// page's big "100 kg" runs past a narrower screen.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Walks onboarding from the welcome page to the coach's goal page.
Future<void> _toCoachGoal(WidgetTester tester) async {
  await tester.pumpWidget(const GymManeApp());
  await tester.pumpAndSettle();
  await _tap(tester, find.text(titleCase(t.next))); // welcome
  await _tap(tester, find.text(titleCase(t.next))); // name
  await _tap(tester, find.text(titleCase(t.onbPhotoLater))); // photo
  await _tap(tester, find.text(titleCase(t.next))); // units
  await _tap(tester, find.text(titleCase(t.next))); // body
  // Days per week: the weekly-goal page.
  await _tap(tester, find.text('3').hitTestable().last);
  await _tap(tester, find.text(titleCase(t.next)));
  // Place: the gym.
  await _tap(tester, find.text(t.placePresetName('gym')));
  await _tap(tester, find.text(titleCase(t.next)));
  expect(find.text(t.coachOnbGoalTitle), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = false;
    fit.coachDraft = CoachAnswers();
    setAppLanguage('en');
  });

  tearDown(() {
    if (fit.session != null) fit.saveAndExit();
    fit.onboarded = true;
    fit.persistNow();
  });

  testWidgets('fresh install: four choices, Home shows today\'s generated session, starting it opens its sets',
      (tester) async {
    _phone(tester);
    await _toCoachGoal(tester);
    await _tap(tester, find.byKey(const ValueKey('coach-goal-lean_gain')));
    await _tap(tester, find.text(titleCase(t.next)));
    expect(find.text(t.coachOnbLevelTitle), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('coach-level-novice')));
    await _tap(tester, find.byKey(const ValueKey('coach-years-under_one')));
    await _tap(tester, find.byKey(const ValueKey('coach-length-45')));
    await _tap(tester, find.text(titleCase(t.next)));
    expect(find.text(t.coachOnbShapeTitle), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('coach-focus-glutes')));
    await _tap(tester, find.text(titleCase(t.next)));
    expect(find.text(t.coachOnbPreviewTitle), findsOneWidget);
    final shown = fit.coachPreview(fit.coachDraft)!;
    expect(find.text(shown.splitName), findsOneWidget);
    await _tap(tester, find.text(titleCase(t.welcomeStart)));

    expect(fit.onboarded, isTrue);
    expect([for (final m in CoachModule.values) fit.coach.isOn(m)], [true, true, false, false]);
    final p = fit.coach.profile!;
    expect((p.coachGoal, p.coachStatus, p.minutes), (CoachGoal.leanGain, CoachStatus.novice, 45));
    expect(p.days, [1, 3, 5]);
    expect(p.smartPlan, isTrue);
    expect(p.years, CoachYears.underOne);
    expect(p.focus, [CoachArea.glutes]);
    expect(fit.coach.block!.splitKey, shown.splitKey);
    final coachRoutines = [for (final id in fit.coach.routineIds.values) fit.routineById(id)!];
    expect(coachRoutines, isNotEmpty);
    expect(coachRoutines.every((r) => r.group == t.coachRoutineGroup), isTrue);

    // Home: today's routine is a coach routine on a training day; on any other day the card names the next one.
    final today = fit.todayRoutine;
    final Routine routine;
    if (today != null) {
      expect(fit.isCoachRoutine(today.id), isTrue);
      expect(find.text(fit.routineTitle(today)), findsWidgets);
      expect(find.textContaining(fit.coachBlockLabel(today)!), findsOneWidget);
      expect(find.text(t.coachPlanWhy), findsOneWidget);
      routine = today;
      await tester.tap(find.text(titleCase(t.startWorkout)).hitTestable().first);
      await tester.pump(const Duration(milliseconds: 600));
    } else {
      final next = fit.nextPlannedAfter(DateTime.now())!.routine;
      expect(fit.isCoachRoutine(next.id), isTrue);
      expect(find.textContaining(fit.routineTitle(next)), findsWidgets);
      routine = next;
      fit.startRoutine(next);
      // The open workout animates without end (its clock), so it never settles: pump a fixed time, as above.
      await tester.pump(const Duration(milliseconds: 600));
    }

    // The workout opens with the block's sets for this week.
    final s = fit.session!;
    expect(s.routineId, routine.id);
    final key = fit.coach.routineIds.entries.firstWhere((e) => e.value == routine.id).key;
    for (final e in s.exercises) {
      final want = CoachFacade.openingSets(
        coach: fit.coach,
        templateKey: key,
        exercise: fit.exerciseById(e.id)!,
        today: DateTime.now(),
        sessions: fit.sessions,
        incrementKg: fit.progressStep[e.id] ?? fit.fromDisplayWeight(fit.weightStep),
      )!;
      final working = e.sets.where((x) => x.kind != SetKind.warmup).toList();
      expect(working, hasLength(want.length), reason: e.id);
      // Reps are the coach's for the exercises it drives; body-weight-only ones keep the stock reps.
      if (fit.coachTargetLabel(e.id) == null) continue;
      for (final (i, x) in working.indexed) {
        expect(x.reps, want[i].reps, reason: '${e.id} set $i');
      }
    }
    fit.saveAndExit();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('"Just log workouts" ends onboarding with every coach module off', (tester) async {
    _phone(tester);
    await _toCoachGoal(tester);
    await _tap(tester, find.byKey(const ValueKey('coach-goal-strength')));
    await _tap(tester, find.byKey(const ValueKey('coach-just-log')));
    expect(fit.onboarded, isTrue);
    expect(fit.coach.isEmpty, isTrue);
    expect(fit.routines, isEmpty);
  });

  testWidgets('the Home card names the block and its week, and "Why this plan" explains it', (tester) async {
    _phone(tester);
    fit.onboarded = true;
    fit.coachApplyAnswers(CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: [1, 3, 5]));
    final r = fit.routineById(fit.coach.routineIds.values.first)!;
    fit.assignRoutineToDay(DateTime.now().weekday, r.id);
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();
    expect(find.textContaining(fit.coachBlockLabel(r)!), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('coach-plan-why')));
    expect(find.text(fit.coachPlanSummary!.explanations.first), findsOneWidget);
  });

  testWidgets('Settings › Coach › "Build me a plan" builds the plan from the prefilled questions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    fit.onboarded = true;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const Scaffold(body: CoachSettings())));
    await _tap(tester, find.byKey(const ValueKey('coach-build-plan-row')));
    expect(find.text(t.coachOnbGoalTitle.toUpperCase()), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('coach-goal-fat_loss')));
    await _tap(tester, find.byKey(const ValueKey('coach-style-full_body')));
    await _tap(tester, find.byKey(const ValueKey('coach-see-plan')));
    expect(find.byKey(const ValueKey('coach-preview-split')), findsOneWidget);
    // Back to the questions and forward again keeps the answers.
    await _tap(tester, find.byKey(const ValueKey('coach-change-answers')));
    expect(find.byKey(const ValueKey('coach-see-plan')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('coach-see-plan')));
    await _tap(tester, find.byKey(const ValueKey('coach-build-plan')));
    expect(fit.coach.profile!.coachGoal, CoachGoal.fatLoss);
    expect(fit.coach.profile!.style, CoachStyle.fullBody);
    expect(fit.coach.isOn(CoachModule.plan), isTrue);
    expect(fit.coach.routineIds, isNotEmpty);
  });

  testWidgets('the train screen shows the length chips only while the plan module is on', (tester) async {
    _phone(tester);
    fit.onboarded = true;
    await tester.pumpWidget(const GymManeApp());
    await tester.pumpAndSettle();
    fit.startWorkout(const ['chest']);
    fit.trainContinue();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coach-quick-30')), findsNothing);
    fit.closeTrain();

    fit.coachApplyAnswers(CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.novice, days: [1, 3, 5]));
    fit.startWorkout(const ['chest', 'back']);
    fit.trainContinue();
    await tester.pumpAndSettle();
    final before = fit.sessionPicks.length;
    await _tap(tester, find.byKey(const ValueKey('coach-quick-20')));
    expect(fit.coachQuickMinutes, 20);
    expect(fit.sessionPicks.length, lessThanOrEqualTo(before));
    expect(fit.sessionPicks, isNotEmpty);
  });

  testWidgets('the coach pages and the plan sheet fit a 360-point phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    fit.onboarded = true;
    Widget frame(int step, String title, String why, Widget child) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title), Text(why), child]),
        );
    // Every optional question shows: the strength goal's lifts and maxes, and muscle-group days for advanced.
    fit.coachDraft = CoachAnswers(goal: CoachGoal.strength, status: CoachStatus.advanced, focus: [CoachArea.sideDelts]);
    for (final page in coachOnboardingPages(first: 7, frame: frame, skip: () {})) {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: Scaffold(body: page)));
      await tester.pumpAndSettle();
    }
    // The preview, with its other options opened when it has any.
    expect(find.byKey(const ValueKey('coach-preview-split')), findsOneWidget);
    final options = find.byKey(const ValueKey('coach-preview-options'));
    if (options.evaluate().isNotEmpty) await _tap(tester, options);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const Scaffold(body: CoachSettings())));
    await _tap(tester, find.byKey(const ValueKey('coach-build-plan-row')));
    await _tap(tester, find.byKey(const ValueKey('coach-length-90')));
    await _tap(tester, find.byKey(const ValueKey('coach-level-advanced')));
    await _tap(tester, find.byKey(const ValueKey('coach-goal-strength')));
    expect(find.byKey(const ValueKey('coach-style-body_part')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('coach-known-squat-kg')), '140');
    await tester.enterText(find.byKey(const ValueKey('coach-known-squat-reps')), '5');
    await _tap(tester, find.byKey(const ValueKey('coach-see-plan')));
    expect(find.byKey(const ValueKey('coach-preview-split')), findsOneWidget);
    if (options.evaluate().isNotEmpty) await _tap(tester, options);
    expect(tester.takeException(), isNull);
  });

  test('a logged session keeps its routine id, so carry-over can tell a done session', () {
    // Guards the assumption the regeneration relies on.
    final s = LoggedSession(DateTime(2026, 11, 16, 12), 60, const [], routineId: 'r1');
    expect(LoggedSession.fromJson(s.toJson()).routineId, 'r1');
  });
}
