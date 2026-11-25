// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

SupersetItem _iso(List<MuscleId> muscles, [int sets = 3]) =>
    (category: Category.isolation, muscles: muscles.toSet(), sets: sets, free: true);

void main() {
  test('a superset takes one rest per paired round, the longer one', () {
    // 3 + 3 sets: 6 × 40 s work and 3 rests of 90 s, against 6 rests apart.
    expect(supersetSeconds(setsA: 3, workA: 40, restA: 90, setsB: 3, workB: 40, restB: 90), 240 + 270);
    // 4 + 2 sets: 2 paired rounds, 2 sets of the first rest alone.
    expect(
      supersetSeconds(setsA: 4, workA: 40, restA: 90, setsB: 2, workB: 40, restB: 60),
      240 + 2 * 90 + 2 * 90,
    );
  });

  test('only free isolation exercises for different muscles pair, most sets first', () {
    final items = <SupersetItem>[
      (category: Category.upperFreePress, muscles: {MuscleId.chest}, sets: 3, free: true),
      _iso([MuscleId.biceps], 2),
      _iso([MuscleId.triceps], 3),
      _iso([MuscleId.biceps, MuscleId.forearms], 3),
      (category: Category.isolation, muscles: {MuscleId.calves}, sets: 3, free: false),
    ];
    expect(supersetCandidates(items), [(2, 3), (1, 2)]);
  });

  test('pairs are added only until the session fits, each exercise once', () {
    final items = [
      _iso([MuscleId.biceps]),
      _iso([MuscleId.triceps]),
      _iso([MuscleId.sideDelts]),
      _iso([MuscleId.calves]),
    ];
    expect(pickSupersets(items, (p) => true), isEmpty);
    expect(pickSupersets(items, (p) => p.isNotEmpty), [(0, 1)]);
    expect(pickSupersets(items, (p) => false), [(0, 1), (2, 3)]);
  });

  test('the later exercise of a pair moves to right after the earlier one', () {
    expect(applySupersets(['a', 'b', 'c', 'd'], [(0, 2)]), [
      ('a', true),
      ('c', false),
      ('b', false),
      ('d', false),
    ]);
    expect(applySupersets(['a', 'b'], const []), [('a', false), ('b', false)]);
  });
}
