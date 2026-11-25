// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_planner/coach_planner.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

import 'support.dart';

PlannerProfile _p({
  Goal goal = Goal.leanGain,
  Status status = Status.intermediate,
  int days = 4,
  int minutes = 60,
  int? age,
  Priority priority = Priority.lifting,
  List<TrackedMuscle> focus = const [],
  List<UserSport> sports = const [],
  double? previous,
  Map<TrackedMuscle, double>? adjustments,
}) => PlannerProfile(
  goal: goal,
  priority: priority,
  answeredStatus: status,
  years: YearsTraining.fivePlus,
  age: age,
  days: [for (var d = 1; d <= days; d++) d],
  minutes: minutes,
  focus: focus,
  sports: sports,
  previousMedianTarget: previous,
  targetAdjustments: adjustments,
);

double _base(Status s, int days, int minutes) =>
    weeklyBudget(_p(status: s, days: days, minutes: minutes), days).base;

void main() {
  test('tiers by weekly hours', () {
    expect(volumeTier(1.5).name, 'minimal');
    expect(volumeTier(2.75).name, 'minimal');
    expect(volumeTier(3).name, 'low');
    expect(volumeTier(4.5).name, 'low');
    expect(volumeTier(5).name, 'medium');
    expect(volumeTier(6.5).name, 'medium');
    expect(volumeTier(7.5).name, 'high');
    expect(volumeTier(12).name, 'high');
    expect(weeklyHours(4, 45), 3);
  });

  test('base by time and status', () {
    expect(_base(Status.novice, 2, 45), 5); // 1.5 h: minimal
    expect(_base(Status.intermediate, 2, 45), 6);
    expect(_base(Status.advanced, 2, 45), 8);
    expect(_base(Status.novice, 4, 60), 10); // 4 h: low
    expect(_base(Status.intermediate, 4, 60), 11);
    expect(_base(Status.advanced, 4, 60), 12);
    expect(_base(Status.novice, 6, 60), 12); // 6 h: medium, novice cap
    expect(_base(Status.intermediate, 6, 60), 15);
    expect(_base(Status.advanced, 6, 60), 16);
    expect(_base(Status.advanced, 6, 90), 20); // 9 h: high
    expect(_base(Status.intermediate, 6, 90), 16); // status cap
  });

  test('fewer lift days than picked shrink the budget', () {
    final p = _p(days: 6);
    expect(weeklyBudget(p, 6).base, greaterThan(weeklyBudget(p, 3).base));
  });

  test('a previous block carries on within the cap', () {
    expect(weeklyBudget(_p(previous: 13), 4).base, 12); // the low tier tops out at 12
    expect(weeklyBudget(_p(previous: 9), 4).base, 9);
  });

  test('age lowers the start', () {
    expect(weeklyBudget(_p(age: 49), 4).base, 11);
    final older = weeklyBudget(_p(age: 55), 4);
    expect(older.base, 9);
    expect(older.ruleIds, contains('T-PLN-06'));
    expect(weeklyBudget(_p(age: 70), 4).base, 8);
    expect(
      weeklyBudget(_p(status: Status.novice, days: 2, minutes: 30, age: 70), 2).base,
      VOLUME.minEffective,
    );
  });

  test('goal and sport priority', () {
    expect(weeklyBudget(_p(goal: Goal.sportSupport), 4).base, VOLUME.sportPriorityBase);
    expect(weeklyBudget(_p(priority: Priority.sport), 4).base, VOLUME.sportPriorityBase);
    expect(
      weeklyBudget(_p(goal: Goal.fatLoss, status: Status.advanced, days: 6, minutes: 90), 6).base,
      VOLUME.fatLossCap,
    );
    expect(weeklyBudget(_p(goal: Goal.fatLoss), 4).base, 11);
    expect(weeklyBudget(_p(goal: Goal.strength, status: Status.novice, days: 2, minutes: 45), 2).base, 10);
    final balanced = weeklyBudget(
      _p(
        priority: Priority.balanced,
        sports: [
          sport('football', [2, 6]),
        ],
      ),
      4,
    );
    expect(balanced.base, 9);
  });

  test('focus: intermediate +3, advanced specialises, novice only orders', () {
    final i = weeklyBudget(_p(focus: [MuscleId.glutes]), 4);
    expect(i.targets[MuscleId.glutes], 14);
    expect(i.targets[MuscleId.chest], 11);
    final a = weeklyBudget(_p(status: Status.advanced, focus: [MuscleId.glutes]), 4);
    expect(a.targets[MuscleId.glutes], 18); // 12 × 1.5
    expect(a.targets[MuscleId.chest], 7); // 12 × 0.6
    expect(a.ruleIds, contains('T-VOL-08'));
    final n = weeklyBudget(_p(status: Status.novice, focus: [MuscleId.glutes]), 4);
    expect(n.targets[MuscleId.glutes], n.targets[MuscleId.chest]);
    expect(n.ruleIds, contains('T-PLN-04'));
  });

  test('front delts get half, adjustments add, floors and caps hold', () {
    final b = weeklyBudget(_p(adjustments: {MuscleId.back: 2, MuscleId.calves: -20}), 4);
    expect(b.targets[MuscleId.frontDelts], 6); // round(11 × 0.5)
    expect(b.targets[MuscleId.back], 13);
    expect(b.targets[MuscleId.calves], VOLUME.minEffective);
    final big = weeklyBudget(_p(adjustments: {MuscleId.back: 30}), 4);
    expect(big.targets[MuscleId.back], VOLUME.normalCap);
  });

  test('targets match the block generator when the base is the same', () {
    // A novice at 4 × 60 min starts at 10, the generator's novice base.
    final cases = <(Goal, List<UserSport>)>[
      (Goal.leanGain, const []),
      (
        Goal.leanGain,
        [
          sport('football', [3]),
        ],
      ),
      (
        Goal.sportSupport,
        [
          sport('running', [2, 6]),
        ],
      ),
    ];
    for (final (goal, sports) in cases) {
      final planner = weeklyBudget(
        PlannerProfile(
          goal: goal,
          answeredStatus: Status.novice,
          days: [1, 2, 4, 5],
          minutes: 60,
          sports: sports,
        ),
        4,
      );
      final engine = computeTargets(
        blockInput(goal: goal, status: Status.novice, sports: sports),
        defaultBlockKind(goal),
      );
      expect(planner.targets, {for (final t in engine.targets) t.muscle: t.target}, reason: '$goal');
    }
  });

  test('JSON of the result names every tracked muscle', () {
    final json = weeklyBudget(_p(), 4).toJson();
    expect((json['targets'] as Map).keys, [for (final m in TRACKED_MUSCLES) m.wire]);
    expect(json['tier'], 'low');
  });
}
