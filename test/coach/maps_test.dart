// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/catalog/exercise_catalog.dart';
import 'package:gymmane/coach/adapters/equipment_map.dart';
import 'package:gymmane/coach/adapters/muscle_map.dart';
import 'package:gymmane/models/exercise.dart';

void main() {
  group('muscles', () {
    final hostIds = {for (final m in kMuscles) m.id};

    test('every muscle of the app maps to a coach muscle', () {
      for (final id in hostIds) {
        expect(coachMuscle(id), isNotNull, reason: id);
      }
    });

    test('the app-to-coach table', () {
      const expected = {
        'chest': MuscleId.chest,
        'back': MuscleId.back,
        'biceps': MuscleId.biceps,
        'triceps': MuscleId.triceps,
        'quads': MuscleId.quads,
        'hamstrings': MuscleId.hamstrings,
        'glutes': MuscleId.glutes,
        'calves': MuscleId.calves,
        'abdomen': MuscleId.abs,
        'obliques': MuscleId.abs,
        'forearm': MuscleId.forearms,
        'trapezius': MuscleId.traps,
        'lowerback': MuscleId.erectors,
      };
      expect({...expected.keys, 'shoulders'}, hostIds, reason: 'the table covers every muscle of the app');
      for (final e in expected.entries) {
        expect(coachMuscle(e.key), e.value, reason: e.key);
        expect(coachMuscle(e.key, exerciseName: 'Barbell Overhead Press'), e.value,
            reason: 'the name only matters for shoulders');
      }
    });

    test('every coach muscle maps back to a muscle of the app, except the one the app does not show', () {
      for (final m in MuscleId.values) {
        final id = hostMuscle(m);
        if (m == MuscleId.adductors) {
          expect(id, isNull);
        } else {
          expect(hostIds, contains(id), reason: m.wire);
        }
      }
    });

    test('the coach-to-app table', () {
      expect({for (final m in MuscleId.values) m.wire: hostMuscle(m)}, {
        'chest': 'chest',
        'back': 'back',
        'front_delts': 'shoulders',
        'side_delts': 'shoulders',
        'rear_delts': 'shoulders',
        'biceps': 'biceps',
        'triceps': 'triceps',
        'quads': 'quads',
        'hamstrings': 'hamstrings',
        'glutes': 'glutes',
        'calves': 'calves',
        'abs': 'abdomen',
        'forearms': 'forearm',
        'traps': 'trapezius',
        'erectors': 'lowerback',
        'adductors': null,
      });
    });

    test('there and back again lands on the same coach muscle', () {
      const delts = {MuscleId.frontDelts, MuscleId.sideDelts, MuscleId.rearDelts};
      for (final m in MuscleId.values) {
        final id = hostMuscle(m);
        if (id == null) continue;
        final back = coachMuscle(id);
        expect(back, delts.contains(m) ? isIn(delts) : m, reason: m.wire);
      }
    });

    test('shoulders are resolved by the name of the exercise', () {
      MuscleId? of(String name) => coachMuscle('shoulders', exerciseName: name);
      expect(of('Barbell Overhead Press'), MuscleId.frontDelts);
      expect(of('Dumbbell Arnold Press'), MuscleId.frontDelts);
      expect(of('Dumbbell Lateral Raise'), MuscleId.sideDelts);
      expect(of('Cable Upright Row'), MuscleId.sideDelts);
      expect(of('Face Pull'), MuscleId.rearDelts);
      expect(of('Cable Face Pull'), MuscleId.rearDelts);
      expect(of('Dumbbell Rear Delt Fly'), MuscleId.rearDelts);
      expect(of('Dumbbell Reverse Fly'), MuscleId.rearDelts);
      expect(of('DUMBBELL REVERSE FLY'), MuscleId.rearDelts, reason: 'case does not matter');
      expect(of(''), MuscleId.sideDelts);
      expect(coachMuscle('shoulders'), MuscleId.sideDelts);
    });

    test('an unknown muscle id maps to nothing', () {
      expect(coachMuscle('neck'), isNull);
      expect(coachMuscle(''), isNull);
    });
  });

  group('equipment', () {
    test('every piece of equipment of the app maps or is listed as unsupported', () {
      for (final e in kEquipment) {
        final mapped = coachEquipmentOf(e) != null;
        expect(mapped != kCoachUnsupportedEquipment.contains(e), isTrue,
            reason: '$e must either map or be listed as unsupported, not both and not neither');
      }
      expect(kEquipment, containsAll(kCoachUnsupportedEquipment), reason: 'no stale entries');
    });

    test('the table', () {
      expect({for (final e in kEquipment) e: coachEquipmentOf(e)}, {
        'Barbell': Equipment.barbell,
        'Dumbbell': Equipment.dumbbell,
        'Kettlebell': Equipment.dumbbell,
        'Machine': Equipment.machine,
        'Cable': Equipment.cable,
        'Bodyweight': Equipment.bodyweight,
        'Weighted': Equipment.bodyweight,
        'Rings': Equipment.bodyweight,
        'Band': Equipment.band,
        'Other': null,
      });
    });

    test('a place is the set of what its equipment maps to', () {
      expect(coachEquipment(kEquipment), {
        Equipment.barbell,
        Equipment.dumbbell,
        Equipment.machine,
        Equipment.cable,
        Equipment.bodyweight,
        Equipment.band,
      });
      expect(coachEquipment(['Kettlebell', 'Rings', 'Other']), {Equipment.dumbbell, Equipment.bodyweight});
      expect(coachEquipment(const <String>[]), isEmpty);
    });

    test('equipment the user added by hand maps to nothing', () {
      expect(coachEquipmentOf('Landmine'), isNull);
      expect(coachEquipment(['Landmine', 'Barbell']), {Equipment.barbell});
    });

    test('nothing in the app maps to the sled', () {
      expect(coachEquipment(kEquipment), isNot(contains(Equipment.sled)));
    });
  });
}
