// SPDX-License-Identifier: GPL-3.0-only
// The app's exercises as the coach packages see them (ExerciseDef).
//
// An exercise is either annotated (it has an entry in lib/coach/data/coach_meta.dart, generated from the coach's
// exercise annotations) or not. Annotated exercises carry their full coaching attributes. All others, the user's
// own exercises included, get attributes derived from what the app knows: the equipment, the primary and
// secondary muscles and the name.
//
// Only annotated exercises may be put into a generated plan. The kernel's ExerciseDef has no flag for that, so the
// adapter has two entry points instead of one:
//  - coachPlanLibrary: the annotated, not archived exercises. This is the library handed to generateBlock and
//    generateSession, so the generator can only pick annotated exercises.
//  - coachExercises: every exercise. This is the library for everything else: reading logged sets, counting weekly
//    volume, and offering swaps.
// The choice is documented in docs/coach/ARCHITECTURE.md ("Exercise attributes").
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_training/coach_training.dart' as ct;

import '../../catalog/exercise_catalog.dart';
import '../../models/exercise.dart';
import '../data/coach_meta.dart';
import 'category_adapter.dart';
import 'equipment_map.dart';
import 'muscle_map.dart';

/// Popularity of an exercise without annotations: after every annotated one.
const int _unannotatedPopularity = 1000;

final Set<String> _builtInIds = {for (final e in kExercises) e.id};

/// Whether the exercise with [id] has coaching attributes of its own and may be put into a generated plan.
bool coachAnnotated(String id) => kCoachMeta.containsKey(id);

/// The coach's slug for an exercise id. The coach looks substitutions and main-lift defaults up by slug.
String _slugOf(String id) => kCoachMeta[id]?.slug ?? id;

/// Every exercise of [all] as the coach sees it, archived ones included: for logged sets, weekly volume and swaps.
/// A caller that offers swaps leaves out the archived exercises itself.
List<ck.ExerciseDef> coachExercises(List<Exercise> all) => [for (final e in all) coachExerciseDef(e)];

/// The exercises a generated plan may use: the annotated ones of [all] that are not [archived].
List<ck.ExerciseDef> coachPlanLibrary(List<Exercise> all, {required Set<String> archived}) => [
  for (final e in all)
    if (coachAnnotated(e.id) && !archived.contains(e.id)) coachExerciseDef(e),
];

/// One exercise as the coach sees it.
ck.ExerciseDef coachExerciseDef(Exercise e) {
  final meta = kCoachMeta[e.id];
  return meta == null ? _derived(e) : _annotated(e, meta);
}

List<ck.Equipment> _equipmentOf(Exercise e) => [?coachEquipmentOf(e.equipment)];

ck.ExerciseDef _annotated(Exercise e, CoachMeta m) {
  final mainLift = m.mainLiftKey == null ? null : ck.MainLift.fromWire(m.mainLiftKey!);
  return ck.ExerciseDef(
    id: e.id,
    slug: m.slug,
    name: e.name,
    pattern: ck.MovementPattern.fromWire(m.pattern),
    category: ck.Category.fromWire(m.category),
    equipment: _equipmentOf(e),
    isMainLift: mainLift != null,
    mainLiftKey: mainLift,
    longLengthBias: m.longLengthBias,
    unilateral: m.unilateral,
    axialLoad: m.axialLoad,
    impactLowerBody: m.impactLowerBody,
    defaultIncrementKg: m.defaultIncrementKg,
    muscles: [
      for (final x in m.primary)
        ck.ExerciseMuscle(muscle: ck.MuscleId.fromWire(x), role: ck.MuscleRole.primary),
      for (final x in m.secondary)
        ck.ExerciseMuscle(muscle: ck.MuscleId.fromWire(x), role: ck.MuscleRole.secondary),
    ],
    substitutions: [for (final id in m.substitutions) _slugOf(id)],
    slotTags: [for (final t in m.slotTags) ck.SlotTag.fromWire(t)],
    popularity: m.popularity,
    custom: false,
  );
}

ck.ExerciseDef _derived(Exercise e) {
  final primary = coachMuscle(e.primary, exerciseName: e.name);
  final muscles = <ck.ExerciseMuscle>[
    if (primary != null) ck.ExerciseMuscle(muscle: primary, role: ck.MuscleRole.primary),
  ];
  for (final s in e.secondary) {
    final m = coachMuscle(s, exerciseName: e.name);
    if (m == null || muscles.any((x) => x.muscle == m)) continue;
    muscles.add(ck.ExerciseMuscle(muscle: m, role: ck.MuscleRole.secondary));
  }
  final category = coachCategoryFor(e);
  final pattern = _patternFor(e, category);
  final name = e.name.toLowerCase();
  return ck.ExerciseDef(
    id: e.id,
    slug: e.id,
    name: e.name,
    pattern: pattern,
    category: category,
    equipment: _equipmentOf(e),
    isMainLift: false,
    longLengthBias: false,
    unilateral: _hasAny(name, _unilateralWords),
    axialLoad:
        e.equipment == 'Barbell' && category == ck.Category.lowerFreeCompound && pattern != _hipExtension,
    impactLowerBody: _impact.hasMatch(name),
    muscles: muscles,
    substitutions: const [],
    slotTags: ct.deriveSlotTags(pattern, [?primary]),
    popularity: _unannotatedPopularity,
    custom: !_builtInIds.contains(e.id),
  );
}

const ck.MovementPattern _hipExtension = ck.MovementPattern.hipExtension;

bool _hasAny(String name, List<String> words) => words.any(name.contains);

const List<String> _unilateralWords = [
  'single',
  'one arm',
  'one-arm',
  'one leg',
  'one-leg',
  'alternat',
  'split squat',
  'lunge',
  'step-up',
  'step up',
  'pistol',
  'archer',
];
final RegExp _impact = RegExp(r'\b(jump|hop|burpee|run|sprint|skip|jack|plyo|high knees|bound)');

/// The movement pattern of an exercise without annotations, guessed from its name, category and primary muscle.
ck.MovementPattern _patternFor(Exercise e, ck.Category category) {
  final name = e.name.toLowerCase();
  bool has(List<String> words) => _hasAny(name, words);
  if (has(['carry', 'farmer'])) return ck.MovementPattern.carry;
  if (has(['upright row'])) return ck.MovementPattern.uprightRow;
  if (has(['pullover', 'pull-over'])) return ck.MovementPattern.pullover;
  if (has(['hip thrust', 'bridge', 'kickback', 'pull through', 'hip extension'])) return _hipExtension;
  switch (category) {
    case ck.Category.lowerFreeCompound || ck.Category.lowerMachineCompound:
      return has(['deadlift', 'good morning', 'rack pull', 'swing'])
          ? ck.MovementPattern.hinge
          : ck.MovementPattern.squat;
    case ck.Category.upperFreePress || ck.Category.upperMachinePress:
      final vertical =
          e.primary == 'shoulders' || has(['overhead', 'military', 'shoulder press', 'pike', 'handstand']);
      return vertical ? ck.MovementPattern.verticalPush : ck.MovementPattern.horizontalPush;
    case ck.Category.pullingCompound:
      return has(['pull-up', 'pull up', 'pullup', 'chin', 'pulldown', 'muscle-up'])
          ? ck.MovementPattern.verticalPull
          : ck.MovementPattern.horizontalPull;
    case ck.Category.isolation:
      if (has(['fly', 'crossover', 'pec deck'])) return ck.MovementPattern.fly;
      if (e.primary == 'abdomen' || e.primary == 'obliques') return ck.MovementPattern.core;
      if (has(['romanian', 'deadlift', 'good morning'])) return ck.MovementPattern.hinge;
      return ck.MovementPattern.isolation;
  }
}
