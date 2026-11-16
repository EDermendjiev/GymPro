// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_training/coach_training.dart' as ct;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/catalog/exercise_catalog.dart';
import 'package:gymmane/coach/adapters/catalog_adapter.dart';
import 'package:gymmane/coach/data/coach_meta.dart';
import 'package:gymmane/models/exercise.dart';

/// Lifting days per week -> the weekdays offered.
const Map<int, List<int>> _days = {
  2: [1, 4],
  3: [1, 3, 5],
  4: [1, 2, 4, 5],
  5: [1, 2, 3, 4, 5],
  6: [1, 2, 3, 4, 5, 6],
};

ck.BlockInput _input(
  List<ck.ExerciseDef> library, {
  required ct.EquipmentPreset preset,
  required int days,
  ck.Goal goal = ck.Goal.leanGain,
  ck.Status status = ck.Status.intermediate,
  ck.SplitStyle? style,
}) => ck.BlockInput(
  today: '2026-10-26',
  goal: goal,
  priority: ck.Priority.lifting,
  status: status,
  availableDays: _days[days]!,
  // Six lifting days are only planned for sessions of 45 minutes or less.
  sessionMinutes: days == 6 ? 45 : 60,
  maxLiftDays: days,
  equipment: ct.EQUIPMENT_PRESETS[preset]!,
  increments: const {'barbell': 2.5, 'dumbbell': 2, 'machine': 5, 'cable': 2.5},
  sports: const [],
  injuries: const [],
  exercises: library,
  history: ck.History(sets: const []),
  repVariation: ck.RepVariation.withinSession,
  specialization: const [],
  splitStyle: style,
);

void main() {
  final planLibrary = coachPlanLibrary(kExercises, archived: const {});

  test('every key of coach_meta is an exercise of the catalog', () {
    final ids = {for (final e in kExercises) e.id};
    expect(kCoachMeta.keys.where((k) => !ids.contains(k)), isEmpty);
  });

  test('the number of annotated exercises', () {
    // 69 from the coach's exercise annotations (72 matched, 3 merged into another entry, 2 dropped) and 12 of the
    // app's own. A drop here means a name in the catalog or the annotations changed: rerun dev/coach_meta_gen.dart.
    expect(kCoachMeta.length, 81);
    expect(planLibrary, hasLength(81));
  });

  test('every annotation converts to the kernel types', () {
    for (final e in planLibrary) {
      expect(e.equipment, isNotEmpty, reason: e.id);
      expect(e.muscles.where((m) => m.role == ck.MuscleRole.primary), isNotEmpty, reason: e.id);
    }
    final mains = {
      for (final e in planLibrary)
        if (e.mainLiftKey != null) e.slug: e.mainLiftKey,
    };
    expect(mains, {
      'back-squat': ck.MainLift.squat,
      'conventional-deadlift': ck.MainLift.deadlift,
      'sumo-deadlift': ck.MainLift.deadlift,
      'bench-press': ck.MainLift.bench,
      'overhead-press': ck.MainLift.ohp,
    });
  });

  test('substitutions point at exercises the coach can find', () {
    final slugs = {for (final e in coachExercises(kExercises)) e.slug};
    for (final e in planLibrary) {
      for (final s in e.substitutions) {
        expect(slugs, contains(s), reason: '${e.id} -> $s');
      }
    }
    final squat = planLibrary.firstWhere((e) => e.slug == 'back-squat');
    final subs = ct.substitutionsFor(
      squat,
      ct.LibraryContext(
        exercises: planLibrary,
        equipment: ct.EQUIPMENT_PRESETS[ct.EquipmentPreset.full]!,
        injuries: const [],
        disliked: const [],
      ),
    );
    expect(subs.map((e) => e.id), contains('zG0zs85')); // Barbell Front Squat
  });

  group('the plan library', () {
    test('holds annotated exercises only, never archived or custom ones', () {
      const custom = Exercise(
        id: 'c1-0',
        name: 'Barbell Back Squat',
        primary: 'quads',
        secondary: [],
        equipment: 'Barbell',
        difficulty: 'Beginner',
        art: '',
        steps: [],
      );
      final lib = coachPlanLibrary([...kExercises, custom], archived: const {'qXTaZnJ'});
      expect(lib.every((e) => kCoachMeta.containsKey(e.id)), isTrue);
      expect(lib.map((e) => e.id), isNot(contains('qXTaZnJ')));
      expect(lib.map((e) => e.id), isNot(contains('c1-0')));
      expect(lib, hasLength(80));
    });

    test('every exercise is still there for counting and swaps', () {
      final all = coachExercises(kExercises);
      expect(all, hasLength(kExercises.length));
      final crunch = all.firstWhere((e) => e.id == 'TFqbd8t'); // Crunch Floor, not annotated
      expect(crunch.pattern, ck.MovementPattern.core);
      expect(crunch.slotTags, [ck.SlotTag.abs]);
      expect(crunch.impactLowerBody, isFalse);
      expect(crunch.custom, isFalse);
      final pulldown = all.firstWhere((e) => e.id == 'wide-grip-lat-pulldown');
      expect(pulldown.slotTags, contains(ck.SlotTag.pullVertical));
      expect(pulldown.equipment, [ck.Equipment.cable]);
    });
  });

  group('generateBlock over the plan library fills every slot', () {
    final cases = <(String, ck.Goal, ck.Status, ck.SplitStyle?)>[
      ('lean gain, intermediate', ck.Goal.leanGain, ck.Status.intermediate, null),
      (
        'lean gain, intermediate, alternative split',
        ck.Goal.leanGain,
        ck.Status.intermediate,
        ck.SplitStyle.alternative,
      ),
      ('strength, novice', ck.Goal.strength, ck.Status.novice, null),
      ('recomp, advanced, alternative split', ck.Goal.recomp, ck.Status.advanced, ck.SplitStyle.alternative),
    ];
    for (final preset in ct.EquipmentPreset.values.where((p) => p != ct.EquipmentPreset.custom)) {
      for (final (label, goal, status, style) in cases) {
        for (final days in _days.keys) {
          test('${preset.wire}, $label, $days days', () {
            final plan = ct.generateBlock(
              _input(planLibrary, preset: preset, days: days, goal: goal, status: status, style: style),
            );
            final missing = [
              for (final w in plan.warnings)
                if (w.code == ck.WarningCode.noExerciseForSlot) w.message,
            ];
            expect(missing, isEmpty);
            expect(plan.sessions, isNotEmpty);
          });
        }
      }
    }
  });

  test('generateBlock never picks an unannotated exercise', () {
    // The whole catalog is offered for logging and swaps, but only the plan library reaches the generator.
    for (final preset in [ct.EquipmentPreset.full, ct.EquipmentPreset.bodyweight]) {
      for (final days in _days.keys) {
        final plan = ct.generateBlock(_input(planLibrary, preset: preset, days: days));
        for (final s in plan.sessions) {
          for (final x in s.exercises) {
            expect(kCoachMeta.containsKey(x.exerciseId), isTrue, reason: x.exerciseId);
          }
        }
      }
    }
  });
}
