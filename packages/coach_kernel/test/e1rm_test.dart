// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

void main() {
  for (final c in loadFixture('e1rm.json')) {
    test('e1rm ${c.name}', () {
      final i = c.input;
      final increment = i['increment'] as num;
      final est = e1rm(i['load'] as num?, i['reps'] as num, i['rir'] as num?);
      final actual = {
        'e1rm': est,
        'rounded': round1OrNull(est),
        'single8': est != null
            ? loadAtRpe(est, i['singleReps'] as num, i['singleRpe'] as num, increment)
            : null,
        'for10': est != null ? e1rmToLoad(est, i['targetReps'] as num, increment) : null,
      };
      expect(jsonDiff(actual, c.output), isNull);
    });
  }

  for (final c in loadFixture('e1rm_recent.json')) {
    test('bestRecentE1rm ${c.name}', () {
      final sets = [for (final s in c.input['sets'] as List) LoggedSet.fromJson(s as Map<String, dynamic>)];
      final exerciseId = c.input['exerciseId'] as String;
      final n = c.input['n'] as int?;
      final best = n == null ? bestRecentE1rm(sets, exerciseId) : bestRecentE1rm(sets, exerciseId, n);
      expect(jsonDiff({'best': best}, c.output), isNull);
    });
  }

  test('the RIR argument can be left out', () {
    expect(e1rm(100, 5), e1rm(100, 5, 0));
    expect(e1rm(100, 5), closeTo(112.5, 1e-9));
  });
}
