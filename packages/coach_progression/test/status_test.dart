// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_progression/coach_progression.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

Object? _call(Map<String, dynamic> i) {
  switch (i['call'] as String) {
    case 'statusFromYears':
      final stalled = i['heavyLiftsStalled'] as bool?;
      final years = i['years'] as num;
      return (stalled == null ? statusFromYears(years) : statusFromYears(years, stalled)).wire;
    case 'inferTrainingStatus':
      return inferTrainingStatus(TrainingStatusInput.fromJson(i['h'] as Map<String, dynamic>)).toJson();
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  for (final c in loadFixture('status.json', fn: 'status')) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }
}
