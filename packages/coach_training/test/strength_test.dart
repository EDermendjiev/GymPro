// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

Object? _call(Map<String, dynamic> i) {
  BlockKind kind(String key) => BlockKind.fromWire(i[key] as String);
  switch (i['call'] as String) {
    case 'phase':
      final (k, w, n) = (kind('kind'), i['weekIndex'] as int, i['weeks'] as int);
      return {
        'singleRpe': singleRpe(k, w, n),
        'backoffReps': backoffReps(k, w, n),
        'backoffSets': backoffSets(k, w, n),
      };
    case 'peakWeeks':
      return peakWeeks(i['volumeLoadWeeks'] as int);
    case 'singleLoad':
      return singleLoad(i['e1rmKg'] as num?, i['rpe'] as num, i['increment'] as num);
    case 'backoffLoad':
      return backoffLoad(i['e1rmKg'] as num?, i['reps'] as int, i['rpe'] as num, i['increment'] as num);
    case 'nextStrengthKind':
      return nextStrengthKind(kind('current'), i['testDate'] as String?, i['today'] as String).wire;
    case 'defaultBlockKind':
      return defaultBlockKind(Goal.fromWire(i['goal'] as String)).wire;
    case 'blockWeeks':
      final opts = i['opts'] as Map<String, dynamic>?;
      return blockWeeks(kind('kind'), volumeLoadWeeks: opts?['volumeLoadWeeks'] as int?);
    case 'isStrengthKind':
      return isStrengthKind(kind('kind'));
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  for (final c in loadFixture('strength.json', fn: 'strength')) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }
}
