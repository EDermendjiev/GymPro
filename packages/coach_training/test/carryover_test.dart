// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

Object? _call(Map<String, dynamic> i) {
  switch (i['call'] as String) {
    case 'planKey':
      return planKey(i['engineDate'] as String, i['templateKey'] as String, i['occurrence'] as int);
    case 'carryOverEdits':
      final sessions = [
        for (final s in i['sessions'] as List) PlannedSession.fromJson(s as Map<String, dynamic>),
      ];
      final before = [for (final s in sessions) s.toJson()];
      final disallowed = [for (final d in i['disallowed'] as List) d as String];
      final prior = [for (final p in i['prior'] as List) PriorSession.fromJson(p as Map<String, dynamic>)];
      expect(jsonDiff([for (final p in prior) p.toJson()], i['prior']), isNull);
      final result = carryOverEdits(
        CarryOverInput(
          sessions: sessions,
          prior: prior,
          today: i['today'] as String,
          allowExercise: (id) => !disallowed.contains(id),
        ),
      );
      // The regenerated sessions are not changed in place.
      expect(jsonDiff([for (final s in sessions) s.toJson()], before), isNull);
      return result.toJson();
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  for (final c in loadFixture('carryover.json', fn: 'carryover')) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }

  test('the result type round-trips', () {
    for (final c in loadFixture('carryover.json').where((c) => c.input['call'] == 'carryOverEdits')) {
      final out = c.output as Map<String, dynamic>;
      expect(jsonDiff(CarryOverResult.fromJson(out).toJson(), out), isNull);
    }
    expect(() => PriorSessionStatus.fromWire('moved'), throwsFormatException);
  });
}
