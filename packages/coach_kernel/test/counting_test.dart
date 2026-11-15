// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

/// The fixtures pass bare `{muscles: [...]}` objects where the functions only read the muscles.
class _Muscles implements HasMuscles {
  _Muscles(Object? json)
    : muscles = [for (final m in json as List) ExerciseMuscle.fromJson(m as Map<String, dynamic>)];

  @override
  final List<ExerciseMuscle> muscles;
}

Map<String, double> _byWire(Map<MuscleId, double> map) => {for (final e in map.entries) e.key.wire: e.value};

Object? _call(Map<String, dynamic> i, List<ExerciseDef> seed) {
  switch (i['call'] as String) {
    case 'setCounts':
      return setCounts(reps: i['reps'] as int, rir: i['rir'] as num?, isWarmup: i['isWarmup'] as bool);
    case 'muscleWeight':
      return muscleWeight(_Muscles(i['muscles']), MuscleId.fromWire(i['muscle'] as String));
    case 'fractionalSets':
      return _byWire(fractionalSets(_Muscles(i['muscles']), i['sets'] as num));
    case 'emptyMuscleMap':
      return _byWire(emptyMuscleMap());
    case 'loggedMuscleSets':
      expect(i['exercises'], '@seed');
      final exercises = <String, HasMuscles>{
        for (final e in seed) e.id: e,
        for (final e in (i['extraExercises'] as Map<String, dynamic>).entries)
          e.key: _Muscles((e.value as Map)['muscles']),
      };
      final sets = [for (final s in i['sets'] as List) LoggedSet.fromJson(s as Map<String, dynamic>)];
      final from = i['from'] as String;
      final days = i['days'] as int?;
      return _byWire(
        days == null
            ? loggedMuscleSets(sets, exercises, from)
            : loggedMuscleSets(sets, exercises, from, days),
      );
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  final seed = [
    for (final e in loadFixture('exercises.json').single.output as List)
      ExerciseDef.fromJson(e as Map<String, dynamic>),
  ];

  for (final c in loadFixture('counting.json')) {
    test(c.name, () => expect(jsonDiff(_call(c.input, seed), c.output), isNull));
  }

  test('a map of exercise definitions is accepted as it is', () {
    final byId = {for (final e in seed) e.id: e};
    final set = LoggedSet(
      exerciseId: 'bench-press',
      performedOn: '2026-10-20',
      setIndex: 0,
      loadKg: 80,
      reps: 8,
      rir: 2,
      isWarmup: false,
    );
    expect(loggedMuscleSets([set], byId, '2026-10-19')[MuscleId.chest], 1);
  });

  test('the empty map lists every muscle in order and is a new map each time', () {
    expect(emptyMuscleMap().keys, ALL_MUSCLES);
    expect(emptyMuscleMap(), isNot(same(emptyMuscleMap())));
  });
}
