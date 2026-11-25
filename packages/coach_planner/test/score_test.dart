// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_planner/coach_planner.dart';
import 'package:test/test.dart';

import 'support.dart';

PlannerProfile _p({
  Goal goal = Goal.leanGain,
  List<int> days = const [1, 2, 4, 5],
  int minutes = 60,
  StylePref style = StylePref.auto,
  int? age,
  String? previous,
  List<UserSport> sports = const [],
}) => PlannerProfile(
  goal: goal,
  answeredStatus: Status.intermediate,
  days: days,
  minutes: minutes,
  style: style,
  age: age,
  previousSplitKey: previous,
  sports: sports,
);

Map<TrackedMuscle, double> _all(double n) => {for (final m in TRACKED_MUSCLES) m: n};

void main() {
  test('days a split falls on', () {
    expect(placeDays([1, 2, 4, 5], 4), [1, 2, 4, 5]);
    expect(placeDays([1, 2, 3, 4, 5, 6], 3), [1, 3, 5]);
    expect(placeDays([1, 3, 5, 7], 2), [1, 5]);
  });

  test('status, goal and main-lift failures', () {
    expect(
      scoreSplit(splitByKey('BP4')!, _p(), Status.intermediate, _all(11)).failures,
      contains(Failure.status),
    );
    expect(
      scoreSplit(splitByKey('STR4')!, _p(), Status.intermediate, _all(11)).failures,
      contains(Failure.goal),
    );
    expect(
      scoreSplit(splitByKey('PPL6')!, _p(goal: Goal.strength), Status.intermediate, _all(11)).failures,
      contains(Failure.mainLifts),
    );
    expect(
      scoreSplit(splitByKey('FPP4')!, _p(goal: Goal.strength), Status.intermediate, _all(11)).failures,
      contains(Failure.goal),
    );
  });

  test('time and session-volume failures', () {
    final tight = scoreSplit(
      splitByKey('FB2')!,
      _p(days: [1, 4], minutes: 30),
      Status.intermediate,
      _all(12),
    );
    expect(tight.failures, contains(Failure.time));
    final ok = scoreSplit(splitByKey('UL4')!, _p(minutes: 75), Status.intermediate, _all(11));
    expect(ok.feasible, isTrue, reason: '${ok.failures}');
    final heavy = scoreSplit(
      splitByKey('FB2')!,
      _p(days: [1, 4], minutes: 300),
      Status.intermediate,
      _all(20),
    );
    expect(heavy.failures, contains(Failure.sessionVolume));
  });

  test('a style match outweighs the rest', () {
    final ul = scoreSplit(splitByKey('UL4')!, _p(style: StylePref.upperLower), Status.intermediate, _all(11));
    final fb = scoreSplit(splitByKey('FB4')!, _p(style: StylePref.upperLower), Status.intermediate, _all(11));
    expect(ul.terms['style'], SCORE.styleMatch);
    expect(fb.terms.containsKey('style'), isFalse);
    expect(ul.score, greaterThan(fb.score));
    final near = scoreSplit(
      splitByKey('LPPF4')!,
      _p(style: StylePref.upperLower),
      Status.intermediate,
      _all(11),
    );
    expect(near.terms['style'], SCORE.styleNear);
  });

  test('keeping the current split counts', () {
    final c = scoreSplit(splitByKey('UL4')!, _p(previous: 'UL4'), Status.intermediate, _all(11));
    expect(c.terms['keep'], SCORE.keepSplit);
  });

  test('hard leg days back to back cost more from 50, and next to a hard sport day', () {
    // Lower / Push / Pull / Full Body on Mon, Tue, Wed, Thu: the Monday legs and the Thursday full body don't touch,
    // but a lower day on Mon and Tue would.
    final split = splitByKey('UL4')!; // Upper Mon, Lower Tue, Upper Wed, Lower Thu
    final apart = scoreSplit(split, _p(days: [1, 2, 3, 4]), Status.intermediate, _all(11));
    expect(apart.terms.containsKey('legs'), isFalse);
    final fb = splitByKey('FB4')!;
    final young = scoreSplit(fb, _p(days: [1, 2, 3, 4]), Status.intermediate, _all(11));
    final older = scoreSplit(fb, _p(days: [1, 2, 3, 4], age: 60), Status.intermediate, _all(11));
    expect(young.terms['legs'], lessThan(0));
    expect(older.terms['legs'], lessThan(young.terms['legs']!));
    final nextToSport = scoreSplit(
      split,
      _p(
        days: [1, 2, 3, 4],
        sports: [
          sport('football', [3]),
        ],
      ),
      Status.intermediate,
      _all(11),
    );
    expect(nextToSport.terms['legs'], lessThan(0));
  });

  test('JSON names failures and terms', () {
    final json = scoreSplit(splitByKey('BP4')!, _p(), Status.novice, _all(10)).toJson();
    expect(json['feasible'], isFalse);
    expect(json['failures'], contains('status'));
    expect(json['terms'], isA<Map<String, dynamic>>());
  });
}
