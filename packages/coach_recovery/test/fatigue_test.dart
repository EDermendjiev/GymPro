// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_recovery/coach_recovery.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

import 'seed.dart';

Object? _call(Map<String, dynamic> i, List<ExerciseDef> seed) {
  WeeklyState state() => WeeklyState.fromJson(expandSeed(i['state'], seedJson) as Map<String, dynamic>);
  List<LoggedSet> sets() => [for (final s in i['sets'] as List) LoggedSet.fromJson(s as Map<String, dynamic>)];

  switch (i['call'] as String) {
    case 'label':
      return label(MuscleId.fromWire(i['muscle'] as String));
    case 'kindLabel':
      return kindLabel(i['kind'] as String);
    case 'reviewWeekFor':
      return reviewWeekFor(i['today'] as String, i['weekday'] as int);
    case 'daysSince':
      return daysSince(i['a'] as String, i['b'] as String);
    case 'exercisesLoadingArea':
      final ex = seed.firstWhere((e) => e.id == i['exerciseId']);
      return exercisesLoadingArea(ex, MuscleId.fromWire(i['muscle'] as String)).wire;
    case 'lighterSessionFor':
      final today = i['todaySession'] as Map<String, dynamic>?;
      return lighterSessionFor(
        i['readinessScore'] as num?,
        today == null ? null : TodaySession.fromJson(today),
        [for (final o in i['others'] as List) OtherSession.fromJson(o as Map<String, dynamic>)],
        i['today'] as String,
      )?.toJson();
    case 'rirDrift':
      return rirDrift(sets(), i['weekStart'] as String).toJson();
    case 'weeklyReview':
      return weeklyReview(state()).toJson();
    case 'autofillReview':
      return autofillReview(state()).toJson();
    case 'localSoreMuscles':
      return [for (final m in localSoreMuscles(state())) m.wire];
    case 'statusAnchorIds':
      return statusAnchorIds(state());
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  final seed = seedExercises();
  for (final c in loadFixture('weekly_review.json', fn: 'fatigue')) {
    test(c.name, () => expect(jsonDiff(_call(c.input, seed), c.output), isNull));
  }

  test('WeeklyReview and the helper types round-trip through JSON', () {
    for (final c in loadFixture('weekly_review.json', fn: 'fatigue')) {
      final out = c.output;
      switch (c.input['call']) {
        case 'weeklyReview':
          expect(jsonDiff(WeeklyReview.fromJson(out as Map<String, dynamic>).toJson(), out), isNull);
        case 'rirDrift':
          expect(jsonDiff(RirDrift.fromJson(out as Map<String, dynamic>).toJson(), out), isNull);
        case 'lighterSessionFor' when out != null:
          expect(jsonDiff(LighterSession.fromJson(out as Map<String, dynamic>).toJson(), out), isNull);
          for (final o in c.input['others'] as List) {
            expect(jsonDiff(OtherSession.fromJson(o as Map<String, dynamic>).toJson(), o), isNull);
          }
          final t = c.input['todaySession'] as Map<String, dynamic>;
          expect(jsonDiff(TodaySession.fromJson(t).toJson(), t), isNull);
        case 'exercisesLoadingArea':
          expect(AreaLoading.fromWire(out as String).wire, out);
      }
    }
    expect(() => AreaLoading.fromWire('drop'), throwsFormatException);
  });
}
