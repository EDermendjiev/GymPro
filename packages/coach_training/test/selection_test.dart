// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

/// The fixtures store the seed library as '@seed', with any extra exercises beside it, and the week's exercises as a list.
SelectionContext _ctx(Object? json, List<ExerciseDef> seed) {
  final c = json as Map<String, dynamic>;
  expect(c['exercises'], '@seed');
  final previous = c['previous'] as Map<String, dynamic>?;
  final used = c['usedThisWeek'] as List?;
  return SelectionContext(
    exercises: [
      ...seed,
      for (final e in (c['extraExercises'] as List?) ?? const []) ExerciseDef.fromJson(e as Map<String, dynamic>),
    ],
    equipment: [for (final e in c['equipment'] as List) Equipment.fromWire(e as String)],
    injuries: [for (final i in c['injuries'] as List) Injury.fromJson(i as Map<String, dynamic>)],
    disliked: [for (final d in c['disliked'] as List) d as String],
    previous: previous == null ? null : {for (final e in previous.entries) e.key: e.value as String},
    sportPriority: c['sportPriority'] as bool?,
    usedThisWeek: used == null ? null : {for (final u in used) u as String},
  );
}

List<String> _ids(List<ExerciseDef> xs) => [for (final e in xs) e.id];

Object? _call(Map<String, dynamic> i, List<ExerciseDef> seed) {
  List<Injury> injuries() => [for (final x in i['injuries'] as List) Injury.fromJson(x as Map<String, dynamic>)];
  ExerciseDef seeded() {
    if (i.containsKey('exercises')) expect(i['exercises'], '@seed');
    return seed.firstWhere((e) => e.id == i['exerciseId']);
  }

  Set<String> exclude() => {for (final x in i['exclude'] as List) x as String};
  SlotQuery slot() => SlotQuery.fromJson(i['slot'] as Map<String, dynamic>);

  switch (i['call'] as String) {
    case 'painfulMuscles':
      return [for (final m in painfulMuscles(injuries())) m.wire];
    case 'injuryNote':
      return injuryNote(seeded(), injuries());
    case 'isFeasible':
      return isFeasible(seeded(), _ctx(i['ctx'], seed));
    case 'hasEquipment':
      return hasEquipment(seeded(), [for (final e in i['equipment'] as List) Equipment.fromWire(e as String)]);
    case 'rankCandidates':
      return _ids(rankCandidates(slot(), _ctx(i['ctx'], seed), exclude()));
    case 'selectForSlot':
      return selectForSlot(slot(), _ctx(i['ctx'], seed), exclude())?.id;
    case 'selectMainLift':
      return selectMainLift(MainLift.fromWire(i['lift'] as String), _ctx(i['ctx'], seed))?.id;
    case 'constants':
      return {
        'ISOLATION_TAG_FOR': {
          for (final e in ISOLATION_TAG_FOR.entries) e.key.wire: [for (final t in e.value) t.wire],
        },
        'SWAP_OPTION_LIMIT': SWAP_OPTION_LIMIT,
      };
    case 'deriveSlotTags':
      final tags = deriveSlotTags(MovementPattern.fromWire(i['pattern'] as String), [
        for (final m in i['primary'] as List) MuscleId.fromWire(m as String),
      ]);
      return [for (final t in tags) t.wire];
    case 'substitutionsFor' || 'swapOptions':
      final ctx = _ctx(i['ctx'], seed);
      final ex = ctx.exercises.firstWhere((e) => e.id == i['exerciseId']);
      return _ids(i['call'] == 'swapOptions' ? swapOptions(ex, ctx) : substitutionsFor(ex, ctx));
    case 'isValidSwap':
      return isValidSwap(seeded(), i['to'] as String, _ctx(i['ctx'], seed));
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  final seed = [
    for (final e in loadFixture('exercises.json', root: '../coach_kernel/test/fixtures').single.output as List)
      ExerciseDef.fromJson(e as Map<String, dynamic>),
  ];

  for (final c in loadFixture('selection.json', fn: 'selection')) {
    test(c.name, () {
      expect(jsonDiff(_call(c.input, seed), c.output), isNull);
      if (c.input['slot'] case final Map<String, dynamic> slot) {
        // The full template slots carry a label; the query keeps only what ranking reads.
        final query = SlotQuery.fromJson(slot).toJson();
        expect(jsonDiff(query, {for (final k in query.keys) k: slot[k]}), isNull);
        if (slot.containsKey('label')) expect(jsonDiff(Slot.fromJson(slot).toJson(), slot), isNull);
      }
    });
  }
}
