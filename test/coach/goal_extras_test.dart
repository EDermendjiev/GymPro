// SPDX-License-Identifier: GPL-3.0-only
// Goal extras in the app: the daily step target and the cardio days for fat loss and recomposition, and the weekly
// recovery checks carried into the next block's volume.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_planner/coach_planner.dart' as cpl;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Monday, so a block built on it starts on it.
final DateTime _monday = DateTime(2026, 11, 16, 9);

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void _apply({CoachGoal goal = CoachGoal.fatLoss, int cardio = 0, List<int> days = const [1, 2, 4, 5]}) =>
    fit.coachApplyAnswers(CoachAnswers(
      goal: goal,
      status: CoachStatus.intermediate,
      days: days,
      minutes: 60,
      cardio: cardio,
    ));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    setAppLanguage('en');
    fit.coachClock = () => _monday;
  });

  group('the cardio answer', () {
    test('is stored on the profile, written only when set, and prefilled', () {
      _apply(cardio: 2);
      expect(fit.coach.profile!.cardio, 2);
      expect(fit.coach.profile!.toJson()['cardio'], 2);
      expect(CoachProfile.fromJson(fit.coach.profile!.toJson()).cardio, 2);
      _apply(cardio: 0);
      expect(fit.coach.profile!.toJson().containsKey('cardio'), isFalse);
      expect(CoachProfile.fromJson({...fit.coach.profile!.toJson(), 'cardio': 'x'}).cardio, 0);
    });

    test('places cardio on rest days, never on lifting days or the day before a leg day', () {
      _apply(cardio: 2);
      final days = fit.coachCardioDays;
      expect(days, hasLength(2));
      final lifting = {for (final p in fit.coach.block!.schedule.placements) p.weekday: p.templateKey};
      for (final d in days) {
        expect(lifting.containsKey(d), isFalse, reason: 'day $d');
        final next = lifting[d % 7 + 1];
        if (next != null) expect(cpl.templateFor(next)!.region.wire, isNot('lower'), reason: 'day $d');
      }
    });

    test('only fat loss and recomposition get cardio, and only with the plan module on', () {
      _apply(goal: CoachGoal.leanGain, cardio: 2);
      expect(fit.coachCardioDays, isEmpty);
      _apply(goal: CoachGoal.recomp, cardio: 1);
      expect(fit.coachCardioDays, hasLength(1));
      fit.setCoachModule(CoachModule.plan, false);
      expect(fit.coachCardioDays, isEmpty);
    });

    test('the preview shows the cardio days', () {
      final pv = fit.coachPreview(CoachAnswers(
        goal: CoachGoal.fatLoss,
        status: CoachStatus.intermediate,
        days: [1, 2, 4, 5],
        cardio: 2,
      ))!;
      expect(pv.cardioDays, hasLength(2));
      expect(pv.cardioDays.any(pv.week.containsKey), isFalse);
    });
  });

  testWidgets('the cardio question and the preview fit a 360-point phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2220);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Widget frame(int step, String title, String why, Widget child) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title), Text(why), child]),
        );
    fit.coachDraft = CoachAnswers(goal: CoachGoal.fatLoss, status: CoachStatus.intermediate, days: [1, 2, 4, 5]);
    final pages = coachOnboardingPages(first: 7, frame: frame, skip: () {});
    var asked = false;
    for (final page in pages) {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: Scaffold(body: page)));
      await tester.pumpAndSettle();
      final pill = find.byKey(const ValueKey('coach-cardio-2'));
      if (pill.evaluate().isNotEmpty) {
        await tester.ensureVisible(pill);
        await tester.pumpAndSettle();
        await tester.tap(pill);
        await tester.pumpAndSettle();
        asked = true;
      }
    }
    expect(asked, isTrue);
    expect(fit.coachDraft.cardio, 2);
    expect(find.byKey(const ValueKey('coach-preview-split')), findsOneWidget);
    expect(find.textContaining(t.coachCardioDay(CoachFacade.cardioMinutes)), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  group('the daily step target', () {
    test('7,000 without step history; follows the usual count once a week is logged', () {
      _apply();
      expect(fit.coachStepTarget, 7000);
      for (var d = 1; d <= 7; d++) {
        fit.stepsByDay[_iso(_monday.subtract(Duration(days: d)))] = 8000;
      }
      expect(fit.coachStepTarget, 10500);
    });

    test('none for other goals', () {
      _apply(goal: CoachGoal.strength);
      expect(fit.coachStepTarget, isNull);
    });

    test('the usual count needs seven days with steps in the last two weeks', () {
      final byDay = {for (var d = 1; d <= 6; d++) _iso(_monday.subtract(Duration(days: d))): 9000};
      expect(CoachFacade.stepBaseline(byDay, _monday), isNull);
      byDay[_iso(_monday.subtract(const Duration(days: 13)))] = 2000;
      expect(CoachFacade.stepBaseline(byDay, _monday), 8000);
    });
  });

  group('the week ahead', () {
    testWidgets('shows the step target and easy cardio on its rest days', (tester) async {
      final now = DateTime.now();
      fit.coachClock = () => DateTime(now.year, now.month, now.day, 9);
      // Two cardio days: the next six days miss only today's weekday, so at least one of them shows.
      _apply(cardio: 2);
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SingleChildScrollView(child: CoachWeekAhead())),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('coach-week-ahead-steps')), findsOneWidget);
      expect(find.text(t.coachStepsTarget('7,000')), findsOneWidget);
      final rows = coachWeekAheadRows();
      final cardio = fit.coachCardioDays;
      expect(cardio, hasLength(2));
      final shown = rows.where((r) => r.cardio).length;
      expect(shown, inInclusiveRange(1, 2));
      expect(find.text(t.coachCardioDay(CoachFacade.cardioMinutes)), findsNWidgets(shown));
      expect(rows.where((r) => r.cardio).every((r) => r.routine == null), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('weekly recovery checks', () {
    test('each review keeps its yes count by week', () {
      _apply();
      fit.setCoachModule(CoachModule.recovery, true);
      fit.coach = fit.coach.copyWith(review: {...fit.coach.review, 'lastWeekStart': '2026-11-09'});
      fit.coachClock = () => DateTime(2026, 11, 23, 9);
      fit.coachTick();
      final checks = fit.coach.review['checks'] as Map;
      expect(checks.keys, ['2026-11-16']);
      expect(checks['2026-11-16'], isA<int>());
    });

    test('repeated fatigue in the ending block starts the next one lower', () {
      _apply(goal: CoachGoal.leanGain);
      final start = fit.coach.block!.startsOn;
      double medianOf(ck.BlockPlan b) =>
          ck.median([for (final t in b.targets) if (t.muscle != ck.MuscleId.frontDelts) t.base]);
      final before = medianOf(fit.coach.block!);
      String transition() {
        fit.coach = fit.coach.copyWith(proposals: [
          {
            'id': 'p-next',
            'kind': 'block_transition',
            'state': 'pending',
            'createdOn': start,
            'title': 't',
            'payload': {'fromKind': 'hypertrophy', 'toKind': 'hypertrophy', 'startsOn': '2026-12-14'},
          },
        ]);
        expect(fit.applyCoachProposal('p-next'), isTrue);
        return fit.coach.block!.explanations.map((e) => e.text).join('\n');
      }

      // Clear checks: the next block carries the volume on.
      fit.coach = fit.coach.copyWith(review: {
        ...fit.coach.review,
        'checks': {'2026-11-16': 0, '2026-11-23': 1, '2026-11-30': 0},
      });
      final snapshot = fit.coach;
      transition();
      final clear = medianOf(fit.coach.block!);
      expect(clear, before);

      // Two flagged weeks of the block: two sets lower.
      fit.coach = snapshot.copyWith(review: {
        ...snapshot.review,
        'checks': {'2026-11-09': 3, '2026-11-16': 2, '2026-11-23': 1, '2026-11-30': 3},
      });
      final why = transition();
      expect(medianOf(fit.coach.block!), before - 2);
      expect(why, contains('fatigue in 2 of the last 3 weeks'));
    });
  });
}
