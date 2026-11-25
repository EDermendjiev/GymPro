// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_planner/coach_planner.dart';
import 'package:test/test.dart';

List<int> _days(int n) => [for (var d = 1; d <= n; d++) d];

PlannerProfile _p({
  Goal goal = Goal.leanGain,
  Status status = Status.intermediate,
  int days = 4,
  int minutes = 60,
  StylePref style = StylePref.auto,
  SessionPref sessionPref = SessionPref.auto,
  List<TrackedMuscle> focus = const [],
  int? age,
  Set<SlotTag>? tags,
}) => PlannerProfile(
  goal: goal,
  answeredStatus: status,
  years: YearsTraining.fivePlus,
  days: _days(days),
  minutes: minutes,
  style: style,
  sessionPref: sessionPref,
  focus: focus,
  age: age,
  availableTags: tags,
);

String _json(PlannerDecision d) => jsonEncode(d.toJson());

void main() {
  test('no training day picked', () {
    expect(() => decidePlan(PlannerProfile(goal: Goal.leanGain, days: [], minutes: 60)), throwsArgumentError);
  });

  test('every picked day is a lifting day, up to six', () {
    for (var d = 1; d <= 6; d++) {
      final r = decidePlan(_p(days: d));
      expect(r.liftDays, d, reason: '$d days');
      expect(r.split.days, d);
      expect(r.explanations.first.text, startsWith('$d lifting day'));
    }
    final seven = decidePlan(_p(days: 7));
    expect(seven.liftDays, 6);
    expect(seven.explanations.first.ruleIds, contains('T-SCH-02'));
  });

  test('fewer, longer sessions may leave out up to two picked days', () {
    final r = decidePlan(_p(days: 6, minutes: 90, sessionPref: SessionPref.fewerLonger));
    expect(r.liftDays, inInclusiveRange(4, 6));
    if (r.liftDays < 6) expect(r.explanations.first.text, contains('fewer, longer'));
    expect(decidePlan(_p(days: 6, sessionPref: SessionPref.moreShorter)).liftDays, 6);
  });

  test('the style asked for is honoured when it fits', () {
    expect(decidePlan(_p(style: StylePref.upperLower)).split.family, SplitFamily.upperLower);
    expect(decidePlan(_p(style: StylePref.fullBody)).split.family, SplitFamily.fullBody);
    // Three days of push/pull/legs train each muscle once a week, which suits low volume only.
    expect(
      decidePlan(_p(days: 3, minutes: 45, style: StylePref.pushPullLegs)).split.family,
      SplitFamily.pushPullLegs,
    );
    // At 60 min it takes a set less per muscle, so that once a week is enough.
    final trimmed = decidePlan(_p(days: 3, style: StylePref.pushPullLegs));
    expect(trimmed.split.family, SplitFamily.pushPullLegs);
    expect(trimmed.targets!.values.every((t) => t <= 10), isTrue);
    expect(trimmed.explanations.map((e) => e.text), contains(startsWith('Volume was trimmed')));
    expect(decidePlan(_p(days: 6, minutes: 45, style: StylePref.pushPullLegs)).split.key, 'PPL6');
    // Muscle-group days fit only at low volume. At five days of 45 min, supersets let push/pull/legs keep about
    // 9 sets per muscle, which beats muscle-group days cut to about 5.
    expect(
      decidePlan(_p(status: Status.advanced, days: 4, minutes: 45, style: StylePref.bodyPart)).split.family,
      SplitFamily.bodyPart,
    );
    expect(
      decidePlan(_p(status: Status.advanced, days: 5, minutes: 45, style: StylePref.bodyPart)).split.family,
      SplitFamily.pushPullLegs,
    );
    // Muscle-group days are not for novices, whatever the style asked for.
    expect(
      decidePlan(_p(status: Status.novice, days: 5, style: StylePref.bodyPart)).split.family,
      isNot(SplitFamily.bodyPart),
    );
  });

  test('strength: main lifts at least 1.5 times a week, volume left to the strength phases', () {
    for (var d = 2; d <= 6; d++) {
      final r = decidePlan(_p(goal: Goal.strength, days: d, minutes: 90));
      expect(r.split.hasMainLifts, isTrue, reason: '$d days');
      final f = mainLiftFrequency(r.split);
      for (final l in [MainLift.squat, MainLift.bench, MainLift.deadlift]) {
        expect(f[l], greaterThanOrEqualTo(1.5), reason: '$d days ${l.wire}');
      }
      expect(r.targets, isNull);
      expect(r.strengthLifts, [MainLift.squat, MainLift.bench, MainLift.deadlift]);
    }
    expect(decidePlan(_p()).strengthLifts, isNull);
  });

  test('targets come from the budget, trimmed only when no split fits the time', () {
    final roomy = decidePlan(_p(days: 3, minutes: 90));
    expect(roomy.targets, roomy.budget.targets);
    final tight = decidePlan(_p());
    for (final m in TRACKED_MUSCLES) {
      expect(tight.targets![m], lessThanOrEqualTo(tight.budget.targets[m]!));
    }
    if (tight.targets.toString() != tight.budget.targets.toString()) {
      expect(tight.explanations.map((e) => e.text), contains(startsWith('Volume was trimmed')));
    }
  });

  test('rep variation by status', () {
    expect(decidePlan(_p(status: Status.novice)).repVariation, RepVariation.withinSession);
    expect(decidePlan(_p(status: Status.advanced)).repVariation, RepVariation.alternatingWeek);
    expect(decidePlan(_p(style: StylePref.upperLower)).repVariation, RepVariation.betweenSession);
  });

  test('focus muscles: trained at least twice, and specialised for advanced lifters', () {
    final i = decidePlan(_p(focus: [MuscleId.glutes]));
    expect(i.estimate.frequency[MuscleId.glutes], greaterThanOrEqualTo(2));
    expect(i.specialization, isEmpty);
    expect(i.focus, [MuscleId.glutes]);
    expect(i.explanations.any((e) => e.text.contains('glutes')), isTrue);
    final a = decidePlan(_p(status: Status.advanced, days: 5, focus: [MuscleId.sideDelts]));
    expect(a.specialization, [MuscleId.sideDelts]);
  });

  test('warnings for few days and too little time', () {
    expect(decidePlan(_p(days: 1)).warnings.map((w) => w.code), contains(WarningCode.lowFrequency));
    expect(decidePlan(_p(days: 2)).warnings.map((w) => w.code), contains(WarningCode.lowFrequency));
    expect(decidePlan(_p(status: Status.novice, days: 2)).warnings, isEmpty);
    final tight = decidePlan(_p(status: Status.advanced, days: 2, minutes: 30));
    expect(tight.warnings.map((w) => w.code), contains(WarningCode.timeTooShort));
  });

  test('older lifters: lower start and a note on leg days', () {
    final r = decidePlan(_p(age: 58));
    expect(r.budget.ruleIds, contains('T-PLN-06'));
    expect(r.explanations.expand((e) => e.ruleIds), contains('T-PLN-06'));
  });

  test('every rule cited is in the registry', () {
    for (final p in [
      _p(),
      _p(goal: Goal.strength),
      _p(goal: Goal.fatLoss, age: 70, focus: [MuscleId.back]),
      _p(goal: Goal.sportSupport, days: 1),
      _p(status: Status.advanced, days: 2, minutes: 30),
    ]) {
      final r = decidePlan(p);
      final ids = [...r.explanations.expand((e) => e.ruleIds), ...r.warnings.expand((w) => w.ruleIds)];
      for (final id in ids) {
        expect(RULES.containsKey(id), isTrue, reason: id);
      }
    }
  });

  test('alternatives are other feasible splits, best first', () {
    final r = decidePlan(_p(days: 4, minutes: 75));
    expect(r.alternatives.map((a) => a.split.key), isNot(contains(r.split.key)));
    expect(r.alternatives.length, lessThanOrEqualTo(3));
    for (var i = 1; i < r.alternatives.length; i++) {
      expect(r.alternatives[i - 1].score, greaterThanOrEqualTo(r.alternatives[i].score));
    }
    expect(r.alternatives, isNotEmpty);
    expect(r.alternatives.first.summary, contains('min a session'));
  });

  test('the same answers give the same plan', () {
    expect(_json(decidePlan(_p(focus: [MuscleId.back]))), _json(decidePlan(_p(focus: [MuscleId.back]))));
  });

  test('changing any one answer changes the plan', () {
    final base = _p(goal: Goal.leanGain, status: Status.intermediate, days: 4, minutes: 60);
    final changed = <String, PlannerProfile>{
      'goal': _p(goal: Goal.strength),
      'status': _p(status: Status.novice),
      'days': _p(days: 3),
      'minutes': _p(minutes: 90),
      'style': _p(style: StylePref.fullBody),
      'focus': _p(focus: [MuscleId.glutes]),
      'age': _p(age: 60),
      'equipment': _p(
        tags: {for (final t in SlotTag.values) t}..removeAll([SlotTag.legExt, SlotTag.chestIso]),
      ),
      'sessions': _p(days: 6, sessionPref: SessionPref.fewerLonger),
    };
    final b = _json(decidePlan(base));
    for (final e in changed.entries) {
      expect(_json(decidePlan(e.value)), isNot(b), reason: e.key);
    }
  });

  test('many different splits over a matrix of answers, none dominant', () {
    final count = <String, int>{};
    var upperLower = 0;
    var n = 0;
    for (final goal in Goal.values) {
      for (final status in Status.values) {
        for (var d = 2; d <= 6; d++) {
          for (final m in [30, 45, 60, 90]) {
            final r = decidePlan(_p(goal: goal, status: status, days: d, minutes: m));
            count[r.split.key] = (count[r.split.key] ?? 0) + 1;
            if (r.split.family == SplitFamily.upperLower) upperLower++;
            n++;
          }
        }
      }
    }
    expect(count.length, greaterThanOrEqualTo(12), reason: '$count');
    expect(count.values.reduce((a, b) => a > b ? a : b) / n, lessThanOrEqualTo(0.3), reason: '$count');
    expect(upperLower / n, lessThanOrEqualTo(0.4), reason: '$count');
  });

  test('JSON of the decision', () {
    final json = decidePlan(_p()).toJson();
    expect(
      json.keys,
      containsAll(['split', 'liftDays', 'targets', 'repVariation', 'explanations', 'alternatives']),
    );
    expect(jsonDecode(jsonEncode(json)), json);
  });

  test('a pinned split is kept when it fits, and ignored when it does not', () {
    final free = decidePlan(_p());
    final other = free.alternatives.first.split.key;
    final kept = decidePlan(_p(), splitKey: other);
    expect(kept.split.key, other);
    expect(kept.alternatives, isEmpty);
    // A split for another day count, or one that doesn't exist, leaves the choice free.
    expect(decidePlan(_p(), splitKey: 'PPL6').split.key, free.split.key);
    expect(decidePlan(_p(), splitKey: 'nope').split.key, free.split.key);
    // Muscle-group days are never kept for a novice.
    final novice = decidePlan(_p(status: Status.novice, days: 5), splitKey: 'BP5');
    expect(novice.split.key, isNot('BP5'));
  });
}
