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
}
