// SPDX-License-Identifier: GPL-3.0-only
// The plan decision built by the block generator: the block keeps the planner's days, split and volume, and its
// sessions fit the chosen length.
import 'dart:convert';

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_planner/coach_planner.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

late List<ExerciseDef> _exercises;

const _gym = [
  Equipment.barbell,
  Equipment.dumbbell,
  Equipment.machine,
  Equipment.cable,
  Equipment.bodyweight,
  Equipment.band,
];

List<int> _days(int n) => [for (var d = 1; d <= n; d++) d];

PlannerProfile _p(Goal goal, Status status, int days, int minutes, {List<TrackedMuscle> focus = const []}) =>
    PlannerProfile(
      goal: goal,
      answeredStatus: status,
      days: _days(days),
      minutes: minutes,
      focus: focus,
      equipment: _gym,
    );

BlockInput _input(PlannerProfile p, PlannerDecision d) => BlockInput(
  today: '2026-11-23',
  goal: p.goal,
  priority: p.priority,
  status: d.status.status,
  availableDays: p.days,
  sessionMinutes: p.minutes,
  maxLiftDays: d.liftDays,
  equipment: _gym,
  increments: const {},
  sports: const [],
  injuries: const [],
  exercises: _exercises,
  history: History(sets: const []),
  repVariation: d.repVariation,
  specialization: d.specialization,
  strengthLifts: d.strengthLifts,
);

List<PlannedSession> _week0(BlockPlan b) => b.sessions.where((s) => s.weekIndex == 0).toList();

bool _fits(BlockPlan b, int minutes) {
  final w = _week0(b);
  final avg = w.fold(0, (a, s) => a + s.estMinutes) / w.length;
  return avg <= minutes && w.every((s) => s.estMinutes <= minutes * 1.15);
}

void main() {
  setUpAll(() {
    final seed =
        loadFixture('exercises.json', root: '../coach_kernel/test/fixtures').single.output as List<Object?>;
    _exercises = [for (final x in seed) ExerciseDef.fromJson(x as Map<String, dynamic>)];
  });

  test('the design keeps the decision: split, days, templates, targets, explanations', () {
    final p = _p(Goal.leanGain, Status.intermediate, 4, 60);
    final d = decidePlan(p);
    final design = blockDesignFor(d);
    expect(design.split.key, d.split.key);
    expect(design.week, hasLength(d.liftDays));
    for (final key in d.split.templates) {
      expect(design.templateFor(key), isNotNull, reason: key);
    }
    final b = generateBlock(_input(p, d), design: design);
    expect(b.splitKey, d.split.key);
    expect(b.liftDays, d.liftDays);
    expect(_week0(b).map((s) => s.templateKey).toSet(), d.split.templates.toSet());
    expect(b.explanations.take(d.explanations.length).map((e) => e.text), d.explanations.map((e) => e.text));
    for (final t in b.targets) {
      expect(t.target, lessThanOrEqualTo(d.targets![t.muscle]!), reason: t.muscle.wire);
    }
  });

  test('the design survives JSON', () {
    final d = decidePlan(_p(Goal.fatLoss, Status.advanced, 5, 45, focus: [MuscleId.glutes]));
    final json = jsonEncode(blockDesignFor(d).toJson());
    expect(jsonEncode(BlockDesign.fromJson(jsonDecode(json) as Map<String, dynamic>).toJson()), json);
  });

  test('over a matrix of answers the block follows the plan and its sessions fit', () {
    var cases = 0;
    var fit = 0;
    var fitWithout = 0;
    var keptTargets = 0;
    final failures = <String>[];
    for (final goal in [Goal.leanGain, Goal.fatLoss, Goal.strength]) {
      for (final status in Status.values) {
        for (var days = 2; days <= 6; days++) {
          for (final minutes in [30, 45, 60, 90]) {
            final name = '${goal.wire}/${status.wire}/${days}d/${minutes}m';
            final p = _p(goal, status, days, minutes);
            final d = decidePlan(p);
            final input = _input(p, d);
            final b = generateBlock(input, design: blockDesignFor(d));
            cases++;
            if (b.splitKey != d.split.key || b.liftDays != d.liftDays) failures.add('$name: split or days');
            final warned = b.warnings.any((w) => w.code == WarningCode.timeTooShort);
            if (_fits(b, minutes)) {
              fit++;
            } else if (!warned) {
              failures.add('$name: overruns without a warning');
            }
            if (_fits(generateBlock(input), minutes)) fitWithout++;
            final targets = d.targets;
            if (targets == null || b.targets.every((t) => t.target == targets[t.muscle])) keptTargets++;
          }
        }
      }
    }
    expect(failures, isEmpty);
    // The planner's week is the starting point, so the generator rarely has to cut further.
    expect(keptTargets / cases, greaterThan(0.8), reason: '$keptTargets of $cases kept the planner targets');
    expect(fit, greaterThanOrEqualTo(fitWithout), reason: 'fit: $fit with the design, $fitWithout without');
  });
}
