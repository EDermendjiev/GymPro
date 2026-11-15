// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

typedef _Values = List<(String name, String wire)>;

/// Per union name in `enums.json`: the Dart values with their wire strings, and the parser.
final _enums = <String, (_Values, Enum Function(String))>{
  'MuscleId': ([for (final v in MuscleId.values) (v.name, v.wire)], MuscleId.fromWire),
  'Goal': ([for (final v in Goal.values) (v.name, v.wire)], Goal.fromWire),
  'Priority': ([for (final v in Priority.values) (v.name, v.wire)], Priority.fromWire),
  'Status': ([for (final v in Status.values) (v.name, v.wire)], Status.fromWire),
  'Category': ([for (final v in Category.values) (v.name, v.wire)], Category.fromWire),
  'MovementPattern': ([for (final v in MovementPattern.values) (v.name, v.wire)], MovementPattern.fromWire),
  'Equipment': ([for (final v in Equipment.values) (v.name, v.wire)], Equipment.fromWire),
  'MainLift': ([for (final v in MainLift.values) (v.name, v.wire)], MainLift.fromWire),
  'RepVariation': ([for (final v in RepVariation.values) (v.name, v.wire)], RepVariation.fromWire),
  'SplitStyle': ([for (final v in SplitStyle.values) (v.name, v.wire)], SplitStyle.fromWire),
  'SportIntensity': ([for (final v in SportIntensity.values) (v.name, v.wire)], SportIntensity.fromWire),
  'TimeOfDay': ([for (final v in TimeOfDay.values) (v.name, v.wire)], TimeOfDay.fromWire),
  'BlockKind': ([for (final v in BlockKind.values) (v.name, v.wire)], BlockKind.fromWire),
  'Lifestyle': ([for (final v in Lifestyle.values) (v.name, v.wire)], Lifestyle.fromWire),
  'Sex': ([for (final v in Sex.values) (v.name, v.wire)], Sex.fromWire),
  'NutritionPhase': ([for (final v in NutritionPhase.values) (v.name, v.wire)], NutritionPhase.fromWire),
  'SorenessLevel': ([for (final v in SorenessLevel.values) (v.name, v.wire)], SorenessLevel.fromWire),
  'SlotTag': ([for (final v in SlotTag.values) (v.name, v.wire)], SlotTag.fromWire),
  'MuscleRole': ([for (final v in MuscleRole.values) (v.name, v.wire)], MuscleRole.fromWire),
  'InjurySeverity': ([for (final v in InjurySeverity.values) (v.name, v.wire)], InjurySeverity.fromWire),
  'InjuryStatus': ([for (final v in InjuryStatus.values) (v.name, v.wire)], InjuryStatus.fromWire),
  'SessionKind': ([for (final v in SessionKind.values) (v.name, v.wire)], SessionKind.fromWire),
  'PlannedSessionStatus': (
    [for (final v in PlannedSessionStatus.values) (v.name, v.wire)],
    PlannedSessionStatus.fromWire,
  ),
  'SessionStateStatus': (
    [for (final v in SessionStateStatus.values) (v.name, v.wire)],
    SessionStateStatus.fromWire,
  ),
  'WarningCode': ([for (final v in WarningCode.values) (v.name, v.wire)], WarningCode.fromWire),
  'ReviewKey': ([for (final v in ReviewKey.values) (v.name, v.wire)], ReviewKey.fromWire),
  'ProposalKind': ([for (final v in ProposalKind.values) (v.name, v.wire)], ProposalKind.fromWire),
};

/// `lean_gain` and `TIME_TOO_SHORT` become `leanGain` and `timeTooShort`.
String _camel(String wire) {
  final parts = wire.toLowerCase().split('_');
  return parts.first + [for (final p in parts.skip(1)) p[0].toUpperCase() + p.substring(1)].join();
}

/// Wire strings that are reserved words in Dart, and the value name used instead.
const _renamed = {'default': 'defaultStyle'};

/// Unions that belong to tables ported later.
const _later = {'RuleBasis', 'MuscleRegion', 'BodySide'};

void main() {
  final cases = loadFixture('enums.json');

  for (final c in cases) {
    if (_later.contains(c.name)) continue;
    test(c.name, () {
      final entry = _enums[c.name];
      if (entry == null) fail('No Dart enum registered for ${c.name}');
      final (values, fromWire) = entry;
      // Same values, same order, as plain strings.
      expect(jsonDiff([for (final v in values) v.$2], c.output), isNull);
      for (final (index, (name, wire)) in values.indexed) {
        expect(name, _renamed[wire] ?? _camel(wire));
        final parsed = fromWire(wire);
        expect([parsed.index, parsed.name], [index, name]);
      }
      expect(() => fromWire('no such value'), throwsFormatException);
      expect(() => fromWire(''), throwsFormatException);
    });
  }

  test('every Dart enum is in the fixture', () {
    expect({..._enums.keys, ..._later}, {for (final c in cases) c.name});
  });

  test('tracked muscles come first and are the only ones accepted as tracked', () {
    expect(MuscleId.values.where((m) => m.tracked), TRACKED_MUSCLES);
    expect(MuscleId.values.where((m) => !m.tracked), UNTRACKED_MUSCLES);
    expect(MuscleId.trackedFromWire('side_delts'), MuscleId.sideDelts);
    expect(() => MuscleId.trackedFromWire('forearms'), throwsFormatException);
    expect(() => MuscleId.trackedFromWire('neck'), throwsFormatException);
  });
}
