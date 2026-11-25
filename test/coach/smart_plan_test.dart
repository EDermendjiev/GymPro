// SPDX-License-Identifier: GPL-3.0-only
// The plan designer in the app: answers build a designed plan, older profiles keep the generator's own choice until
// the plan is built again, a running block keeps its split, and supersets become chained exercises.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_planner/coach_planner.dart' as cpl;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Monday, so a block built on it starts on it.
final DateTime _monday = DateTime(2026, 11, 16, 9);

ck.BlockPlan get _block => fit.coach.block!;

cpl.PlannerDecision _decision() => cpl.decidePlan(cpl.PlannerProfile.fromJson(fit.coachPlannerInput()));

void _apply(CoachAnswers a) => fit.coachApplyAnswers(a);

CoachAnswers _answers({
  CoachGoal goal = CoachGoal.leanGain,
  CoachStatus status = CoachStatus.intermediate,
  List<int> days = const [1, 2, 4, 5],
  int minutes = 60,
  CoachStyle style = CoachStyle.auto,
  Map<CoachLift, double>? knownLifts,
}) =>
    CoachAnswers(
      goal: goal,
      status: status,
      days: days,
      minutes: minutes,
      style: style,
      knownLifts: knownLifts,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.coachClock = () => _monday;
  });

  test('answers build the designed plan: its split, every picked day and its reasons', () {
    _apply(_answers());
    expect(fit.coach.profile!.smartPlan, isTrue);
    final d = _decision();
    expect(_block.splitKey, d.split.key);
    expect(_block.liftDays, 4);
    expect(_block.explanations.first.text, '4 lifting days: the days you picked.');
    expect(fit.coach.routineIds.keys.toSet(), d.split.templates.toSet());
    for (final e in fit.coach.routineIds.entries) {
      expect(fit.routineById(e.value)!.name, cpl.templateFor(e.key)!.title);
    }
  });

  test('the answers change the plan', () {
    _apply(_answers(style: CoachStyle.fullBody));
    final fullBody = _block.splitKey;
    _apply(_answers(style: CoachStyle.upperLower));
    final upperLower = _block.splitKey;
    expect(fullBody, isNot(upperLower));
    _apply(_answers(status: CoachStatus.novice, days: const [1, 3, 5], minutes: 45));
    expect(_block.liftDays, 3);
  });

  test('a profile from before the planner keeps the generator\'s choice until the plan is built again', () {
    fit.coach = fit.coach.copyWith(
      profile: CoachProfile.answered(
          goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: const [1, 2, 4, 5], minutes: 60,
          activity: 1.375),
    );
    fit.setCoachModule(CoachModule.progression, true);
    fit.setCoachModule(CoachModule.plan, true);
    fit.coachBuildPlan();
    final old = _block.splitKey;
    expect(_block.explanations.any((e) => e.text.contains('the fewest that keep')), isTrue);
    fit.coachRegenerate('test');
    expect(_block.splitKey, old);
    expect(_block.explanations.any((e) => e.text.contains('the fewest that keep')), isTrue);
    // "Build me a plan" with the answers: now the designer decides.
    _apply(fit.coachPrefill());
    expect(fit.coach.profile!.smartPlan, isTrue);
    expect(_block.explanations.any((e) => e.text.contains('the fewest that keep')), isFalse);
  });

  test('regenerating a running block keeps its split', () {
    _apply(_answers(style: CoachStyle.upperLower));
    final split = _block.splitKey;
    // The style changes without a rebuild (as an older build might leave it); the running block keeps its split.
    final p = fit.coach.profile!;
    fit.coach = fit.coach.copyWith(
      profile: CoachProfile.answered(
        goal: p.coachGoal,
        status: p.coachStatus,
        days: p.days,
        minutes: p.minutes,
        activity: 1.375,
        keep: p,
        answers: _answers(style: CoachStyle.fullBody),
      ),
    );
    fit.coachRegenerate('test');
    expect(_block.splitKey, split);
    // Built again, the new style wins.
    fit.coachBuildPlan();
    expect(_block.splitKey, isNot(split));
  });

  test('short sessions chain supersets in the routines', () {
    _apply(_answers(days: const [1, 3, 5], minutes: 45));
    final chained = [
      for (final id in fit.coach.routineIds.values)
        for (final ex in fit.routineById(id)!.exerciseIds)
          if (fit.chainsToNext(fit.routineById(id)!, ex)) ex,
    ];
    expect(chained, isNotEmpty);
    final paired = [
      for (final s in _block.sessions.where((s) => s.weekIndex == 0))
        for (final e in s.exercises)
          if (e.supersetWithNext == true) e.exerciseId,
    ];
    expect(paired.toSet(), containsAll(chained.toSet()));
  });

  test('known maxes seed a strength plan\'s first loads', () {
    _apply(_answers(goal: CoachGoal.strength, days: const [1, 3, 5], minutes: 90,
        knownLifts: {CoachLift.squat: 140, CoachLift.bench: 100}));
    final input = fit.coachBlockInput();
    expect((input['history'] as Map)['e1rmSeeds'], {'squat': 140.0, 'bench': 100.0});
    final singles = [
      for (final s in _block.sessions.where((s) => s.weekIndex == 0))
        for (final e in s.exercises)
          if (e.isMainLiftSingle == true) e,
    ];
    expect(singles, isNotEmpty);
    expect(singles.where((e) => e.suggestedLoadKg != null), isNotEmpty);
  });

  group('preview', () {
    test('nothing to preview without a goal', () {
      expect(fit.coachPreview(CoachAnswers()), isNull);
    });

    test('the preview is the plan the answers build, without building it', () {
      final a = _answers();
      final pv = fit.coachPreview(a)!;
      expect(fit.coach.block, isNull);
      expect(pv.liftDays, 4);
      expect(pv.week.keys.toSet(), {1, 2, 4, 5});
      expect(pv.weeklySets, hasLength(ck.TRACKED_MUSCLES.length));
      expect(pv.weeklySets.values.every((n) => n >= 4), isTrue);
      expect(pv.reasons, isNotEmpty);
      expect(pv.reasons.length, lessThanOrEqualTo(3));
      expect(pv.reasons.first, startsWith('${pv.splitName}:'));
      expect(pv.options, isNotEmpty);
      expect(pv.options.any((o) => o.recommended), isFalse);
      _apply(a);
      expect(_block.splitKey, pv.splitKey);
    });

    test('picking another option builds that split, and later builds keep it', () {
      final a = _answers();
      final first = fit.coachPreview(a)!;
      final other = first.options.first;
      a.splitKey = other.splitKey;
      final pv = fit.coachPreview(a)!;
      expect(pv.splitKey, other.splitKey);
      expect(pv.options.first.recommended, isTrue);
      expect(pv.options.first.splitKey, first.splitKey);
      _apply(a);
      expect(_block.splitKey, other.splitKey);
      expect(fit.coach.profile!.splitKey, other.splitKey);
      fit.coachBuildPlan();
      expect(_block.splitKey, other.splitKey);
      expect(fit.coachPrefill().splitKey, other.splitKey);
    });
  });

  test('pain areas become niggles, and areas left out heal', () {
    final a = _answers()..pain = [CoachArea.quads, CoachArea.biceps];
    _apply(a);
    Set<CoachArea?> active() => {for (final i in fit.coachInjuries) if (i.active) i.area};
    expect(active(), {CoachArea.quads, CoachArea.biceps});
    expect(fit.coachInjuries.every((i) => i.severity == CoachInjurySeverity.niggle), isTrue);
    final again = fit.coachPrefill();
    expect(again.pain!.toSet(), {CoachArea.quads, CoachArea.biceps});
    again.pain = [CoachArea.quads];
    _apply(again);
    expect(active(), {CoachArea.quads});
    expect(fit.coachInjuries, hasLength(2), reason: 'healed, not deleted');
  });

  test('a set gives an estimated max', () {
    expect(CoachFacade.e1rm(100, 5), closeTo(112.5, 0.01));
    expect(CoachFacade.e1rm(100, 15), isNull);
    expect(CoachFacade.e1rm(0, 5), isNull);
  });
}
