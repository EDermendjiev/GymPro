// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

/// Each table of `muscles.json`, rebuilt from the Dart tables in the reference's JSON shape.
final _tables = <String, Object? Function()>{
  'TRACKED_MUSCLES': () => [for (final m in TRACKED_MUSCLES) m.wire],
  'UNTRACKED_MUSCLES': () => [for (final m in UNTRACKED_MUSCLES) m.wire],
  'ALL_MUSCLES': () => [for (final m in ALL_MUSCLES) m.wire],
  'LOWER_MUSCLES': () => [for (final m in LOWER_MUSCLES) m.wire],
  'UPPER_MUSCLES': () => [for (final m in UPPER_MUSCLES) m.wire],
  'MUSCLE_SEEDS': () => [for (final m in MUSCLE_SEEDS) m.toJson()],
  'MUSCLE_NAME': () => {for (final e in MUSCLE_NAME.entries) e.key.wire: e.value},
  'MUSCLE_SHORT': () => {for (final e in MUSCLE_SHORT.entries) e.key.wire: e.value},
  'INDIRECT_VIA': () => {
    for (final e in INDIRECT_VIA.entries) e.key.wire: {'muscle': e.value.muscle.wire, 'how': e.value.how},
  },
  'PATTERN_SEEDS': () => [
    for (final p in PATTERN_SEEDS) {'id': p.id.wire, 'name': p.name},
  ],
};

void main() {
  group('rules', () {
    for (final c in loadFixture('rules.json')) {
      if (c.name == 'order') {
        test('order', () {
          final actual = {
            'ids': [for (final r in RULE_LIST) r.id],
            'bases': [for (final b in RuleBasis.values) b.wire],
          };
          expect(jsonDiff(actual, c.output), isNull);
          expect(RULES.keys, [for (final r in RULE_LIST) r.id], reason: 'no rule ID is listed twice');
        });
        continue;
      }
      test(c.name, () {
        final id = c.input['id'] as String;
        final actual = {'rule': RULES[id]?.toJson(), 'why': whyText(id)};
        expect(jsonDiff(actual, c.output), isNull);
        final rule = (c.output as Map)['rule'];
        if (rule != null) {
          expect(jsonDiff(RuleDef.fromJson(rule as Map<String, dynamic>).toJson(), rule), isNull);
        }
      });
    }
  });

  group('muscle tables', () {
    final cases = loadFixture('muscles.json');
    for (final c in cases) {
      test(c.name, () {
        final build = _tables[c.name];
        if (build == null) fail('No Dart table registered for ${c.name}');
        expect(jsonDiff(build(), c.output), isNull);
      });
    }

    test('every Dart table is in the fixture', () {
      expect(_tables.keys.toSet(), {for (final c in cases) c.name});
    });

    test('muscle seeds parse back and agree with the enum', () {
      for (final m in MUSCLE_SEEDS) {
        expect(jsonDiff(MuscleSeed.fromJson(m.toJson()).toJson(), m.toJson()), isNull);
        expect(m.tracked, m.id.tracked);
      }
      expect([for (final m in MUSCLE_SEEDS) m.id], MuscleId.values);
    });
  });
}
