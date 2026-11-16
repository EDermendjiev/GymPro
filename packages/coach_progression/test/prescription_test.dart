// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

Category _category(Map<String, dynamic> i) => Category.fromWire(i['category'] as String);

Object? _call(Map<String, dynamic> i) {
  switch (i['call'] as String) {
    case 'isCompound':
      return isCompound(_category(i));
    case 'restFor':
      final opts = i['opts'] as Map<String, dynamic>?;
      return restFor(_category(i), strengthMain: opts?['strengthMain'] as bool?);
    case 'subRange':
      return subRange(_category(i), RangeLevel.fromWire(i['level'] as String));
    case 'rangeLevel':
      return rangeLevel(RangeLevelOptions.fromJson(i['opts'] as Map<String, dynamic>)).wire;
    case 'prescribe':
      return prescribe(_category(i), RxOptions.fromJson(i['opts'] as Map<String, dynamic>)).toJson();
    case 'formatRx':
      final rx = i['rx'] as Map<String, dynamic>;
      return formatRx(
        sets: rx['sets'] as int,
        repMin: rx['repMin'] as int,
        repMax: rx['repMax'] as int,
        rirMin: rx['rirMin'] as num,
        rirMax: rx['rirMax'] as num,
      );
    case 'rpeToRir':
      return rpeToRir(i['rpe'] as num);
    case 'rirToRpe':
      return rirToRpe(i['rir'] as num);
    case 'showRirHint':
      return showRirHint(i['repMax'] as int);
    case 'warmupRamp':
      return [for (final s in warmupRamp(i['workingLoad'] as num, i['increment'] as num)) s.toJson()];
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  for (final c in loadFixture('prescription.json', fn: 'prescription')) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }
}
