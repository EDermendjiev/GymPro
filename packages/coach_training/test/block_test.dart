// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

const _files = ['generate_block.json', 'generate_block_extra.json'];

Object? _run(Map<String, dynamic> input, List<Object?> seed) {
  final parsed = BlockInput.fromJson(expandSeed(input, seed) as Map<String, dynamic>);
  try {
    return generateBlock(parsed).toJson();
  } on ArgumentError catch (e) {
    return {'threw': e.message};
  }
}

void main() {
  final seed = loadFixture('exercises.json', root: '../coach_kernel/test/fixtures').single.output as List<Object?>;

  for (final file in _files) {
    group(file, () {
      for (final c in loadFixture(file, fn: 'generateBlock')) {
        test(c.name, () => expect(jsonDiff(_run(c.input, seed), c.output), isNull));
      }
    });
  }

  test('one generateBlock call on the largest fixture input takes under 200 ms', () {
    final all = [for (final file in _files) ...loadFixture(file, fn: 'generateBlock')];
    final largest = all.reduce((a, b) => jsonEncode(a.input).length >= jsonEncode(b.input).length ? a : b);
    final input = BlockInput.fromJson(expandSeed(largest.input, seed) as Map<String, dynamic>);
    generateBlock(input); // warm-up, so the measurement is not the compiler's
    final watch = Stopwatch()..start();
    generateBlock(input);
    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(200));
  });

  test('incrementFor', () {
    ExerciseDef ex(List<Equipment> equipment, {double? step, bool? custom}) => ExerciseDef(
      id: 'x',
      slug: 'x',
      name: 'x',
      pattern: MovementPattern.isolation,
      category: Category.isolation,
      equipment: equipment,
      isMainLift: false,
      longLengthBias: false,
      unilateral: false,
      axialLoad: false,
      impactLowerBody: false,
      defaultIncrementKg: step,
      muscles: [],
      substitutions: [],
      slotTags: [],
      popularity: 1,
      custom: custom,
    );
    expect(incrementFor(ex([Equipment.machine], step: 1.25, custom: true), [Equipment.machine], {'machine': 5}), 1.25);
    expect(incrementFor(ex([Equipment.machine], step: 0, custom: true), [Equipment.machine], {'machine': 5}), 5);
    expect(incrementFor(ex([Equipment.machine], step: 10), [Equipment.machine], {'machine': 5}), 10);
    expect(incrementFor(ex([Equipment.band, Equipment.cable]), [Equipment.cable], {}), 2.5);
    expect(incrementFor(ex([Equipment.dumbbell]), [Equipment.barbell], {}), 2);
    expect(incrementFor(ex([Equipment.sled]), [], {}), 2.5);
    expect(incrementFor(ex([]), [], {'barbell': 10}), 2.5);
  });
}
