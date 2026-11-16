// SPDX-License-Identifier: GPL-3.0-only
// Exercise selection. Rules: T-SEL-02…08, T-SEL-07.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';

import 'split.dart';

/// What makes an exercise feasible (`Pick<SelectionContext, 'equipment' | 'injuries' | 'disliked'>` in the reference).
class FeasibilityContext {
  FeasibilityContext({required this.equipment, required this.injuries, required this.disliked});

  final List<Equipment> equipment;
  final List<Injury> injuries;
  final List<String> disliked;
}

/// The library plus feasibility (`Pick<SelectionContext, 'exercises' | 'equipment' | 'injuries' | 'disliked'>`).
class LibraryContext extends FeasibilityContext {
  LibraryContext({required this.exercises, required super.equipment, required super.injuries, required super.disliked});

  final List<ExerciseDef> exercises;
}

class SelectionContext extends LibraryContext {
  SelectionContext({
    required super.exercises,
    required super.equipment,
    required super.injuries,
    required super.disliked,
    this.previous,
    this.sportPriority,
    this.usedThisWeek,
  });

  /// slotKey → exerciseId (stability, T-SEL-06).
  final Map<String, String>? previous;
  final bool? sportPriority;

  /// Exercises already used elsewhere this week, mildly deprioritised for variety (1–3 per pattern, T-SEL-01).
  final Set<String>? usedThisWeek;
}

const Map<MainLift, List<String>> _MAIN_DEFAULT = {
  MainLift.squat: ['back-squat', 'low-bar-squat', 'safety-bar-squat'],
  MainLift.bench: ['bench-press'],
  MainLift.deadlift: ['conventional-deadlift', 'sumo-deadlift'],
  MainLift.ohp: ['overhead-press'],
};

/// Muscles with pain/injury severity that restrict exercise choice (T-SEL-08).
List<MuscleId> painfulMuscles(List<Injury> injuries) => [
  for (final i in injuries)
    if (i.status != InjuryStatus.resolved &&
        (i.severity == InjurySeverity.pain || i.severity == InjurySeverity.injury) &&
        i.muscleId != null)
      i.muscleId!,
];

bool isPrimary(ExerciseDef ex, MuscleId m) => ex.muscles.any((x) => x.muscle == m && x.role == MuscleRole.primary);

/// T-SEL-08 beyond selection: a cue on exercises that mainly train an area in rehab (lighter loads, higher reps, short of
/// pain) or with a logged niggle (keep it pain-free). Rehab wins over niggle; resolved injuries add nothing.
String? injuryNote(ExerciseDef ex, List<Injury> injuries) {
  final hit = [
    for (final i in injuries)
      if (i.status != InjuryStatus.resolved && i.muscleId != null && isPrimary(ex, i.muscleId!)) i,
  ];
  if (hit.any((i) => i.status == InjuryStatus.rehab)) {
    return 'Rehab area: lighter load and higher reps (12–20), stop well short of pain';
  }
  if (hit.any((i) => i.severity == InjurySeverity.niggle)) {
    return 'Niggle here: keep every rep pain-free; swap or skip it if it hurts';
  }
  return null;
}

bool hasEquipment(ExerciseDef ex, List<Equipment> equipment) => ex.equipment.any((e) => equipment.contains(e));

/// T-SEL-04 / T-SEL-08 feasibility.
bool isFeasible(ExerciseDef ex, FeasibilityContext ctx) {
  if (!hasEquipment(ex, ctx.equipment)) return false;
  if (ctx.disliked.contains(ex.id)) return false;
  for (final inj in ctx.injuries) {
    if (inj.status == InjuryStatus.resolved) continue;
    if (inj.avoidExerciseIds.contains(ex.id)) return false;
  }
  for (final m in painfulMuscles(ctx.injuries)) {
    if (isPrimary(ex, m) && (ex.axialLoad || ex.impactLowerBody)) return false;
  }
  return true;
}

/// Index of the best-matching tag, or infinity when the exercise has none of [tags].
num _tagRank(ExerciseDef ex, List<SlotTag> tags) {
  num best = double.infinity;
  for (final t in ex.slotTags) {
    final i = tags.indexOf(t);
    if (i >= 0 && i < best) best = i;
  }
  return best;
}

/// Deterministic candidate ordering for a slot.
List<ExerciseDef> rankCandidates(SlotQuery slot, SelectionContext ctx, Set<String> exclude) {
  final pain = painfulMuscles(ctx.injuries);
  final prevId = ctx.previous?[slot.key];
  final candidates = [
    for (final ex in ctx.exercises)
      if (!exclude.contains(ex.id) && _tagRank(ex, slot.tags) < double.infinity && isFeasible(ex, ctx)) ex,
  ];
  List<Comparable<Object?>> key(ExerciseDef ex) {
    final painArea = pain.any((m) => isPrimary(ex, m));
    // T-SEL-08: near a painful area prefer isolation, then machines, then free weights.
    final painRank = !painArea
        ? 0
        : ex.category == Category.isolation
        ? 0
        : ex.category == Category.lowerMachineCompound || ex.category == Category.upperMachinePress
        ? 1
        : 2;
    final prefer = slot.prefer;
    return [
      ex.id == prevId && !painArea ? 0 : 1, // T-SEL-06 stability
      painRank,
      _tagRank(ex, slot.tags),
      ctx.sportPriority == true && ex.axialLoad ? 1 : 0, // T-PRI-01 / S-05 lower-risk choices
      prefer != null ? (!prefer.contains(ex.category) ? 99 : prefer.indexOf(ex.category)) : 0,
      ctx.usedThisWeek?.contains(ex.id) == true ? 1 : 0,
      ex.longLengthBias ? 0 : 1, // T-SEL-03
      ex.custom == true ? 1 : 0,
      ex.popularity,
      ex.slug,
    ];
  }

  final keyed = [for (final ex in candidates) (ex: ex, k: key(ex))];
  return [
    for (final x in stableSorted(keyed, (a, b) {
      for (var i = 0; i < a.k.length; i++) {
        final c = a.k[i].compareTo(b.k[i]);
        if (c != 0) return c < 0 ? -1 : 1;
      }
      return 0;
    }))
      x.ex,
  ];
}

ExerciseDef? selectForSlot(SlotQuery slot, SelectionContext ctx, Set<String> exclude) {
  final ranked = rankCandidates(slot, ctx, exclude);
  return ranked.isEmpty ? null : ranked[0];
}

/// T-SEL-07: the main lift itself (or the closest feasible variation).
ExerciseDef? selectMainLift(MainLift lift, SelectionContext ctx) {
  final prevId = ctx.previous?['main_${lift.wire}'];
  final pool = [
    for (final e in ctx.exercises)
      if (e.mainLiftKey == lift && isFeasible(e, ctx)) e,
  ];
  if (prevId != null && prevId.isNotEmpty) {
    for (final e in pool) {
      if (e.id == prevId) return e;
    }
  }
  for (final slug in _MAIN_DEFAULT[lift]!) {
    for (final x in pool) {
      if (x.slug == slug) return x;
    }
  }
  final sorted = stableSorted(pool, (a, b) => a.popularity - b.popularity);
  return sorted.isEmpty ? null : sorted[0];
}

/// Isolation tag used when the distributor needs to add an exercise for a muscle.
const Map<MuscleId, List<SlotTag>> ISOLATION_TAG_FOR = {
  MuscleId.chest: [SlotTag.chestIso],
  MuscleId.back: [SlotTag.pullover, SlotTag.pullVertical],
  MuscleId.sideDelts: [SlotTag.latRaise],
  MuscleId.rearDelts: [SlotTag.rearDelt],
  MuscleId.biceps: [SlotTag.bicepsIso],
  MuscleId.triceps: [SlotTag.tricepsIso],
  MuscleId.quads: [SlotTag.legExt, SlotTag.squatMachine],
  MuscleId.hamstrings: [SlotTag.legCurl, SlotTag.legCurlSeated],
  MuscleId.glutes: [SlotTag.hipExt],
  MuscleId.calves: [SlotTag.calf],
};

/// Slot tags a custom exercise gets from its pattern. Isolation, carry and core also take a tag per primary muscle.
const Map<MovementPattern, List<SlotTag>> _PATTERN_TAGS = {
  MovementPattern.squat: [SlotTag.squatMachine],
  MovementPattern.hinge: [SlotTag.hingeRdl],
  MovementPattern.verticalPull: [SlotTag.pullVertical],
  MovementPattern.verticalPush: [SlotTag.pressVertical],
  MovementPattern.horizontalPull: [SlotTag.rowExtension, SlotTag.rowFlared],
  MovementPattern.horizontalPush: [SlotTag.pressFlat],
  MovementPattern.hipExtension: [SlotTag.hipExt],
  MovementPattern.pullover: [SlotTag.pullover],
  MovementPattern.uprightRow: [SlotTag.latRaise],
  MovementPattern.fly: [SlotTag.chestIso],
  MovementPattern.isolation: [],
  MovementPattern.carry: [SlotTag.carry],
  MovementPattern.core: [SlotTag.abs],
};

/// Isolation slot per primary muscle. Back isolation (straight-arm work) does the pullover job.
const Map<MuscleId, SlotTag> _MUSCLE_ISO_TAG = {
  MuscleId.chest: SlotTag.chestIso,
  MuscleId.back: SlotTag.pullover,
  MuscleId.frontDelts: SlotTag.frontRaise,
  MuscleId.sideDelts: SlotTag.latRaise,
  MuscleId.rearDelts: SlotTag.rearDelt,
  MuscleId.biceps: SlotTag.bicepsIso,
  MuscleId.triceps: SlotTag.tricepsIso,
  MuscleId.quads: SlotTag.legExt,
  MuscleId.hamstrings: SlotTag.legCurl,
  MuscleId.glutes: SlotTag.hipExt,
  MuscleId.calves: SlotTag.calf,
  MuscleId.abs: SlotTag.abs,
  MuscleId.forearms: SlotTag.forearms,
  MuscleId.traps: SlotTag.traps,
  MuscleId.erectors: SlotTag.erectors,
  MuscleId.adductors: SlotTag.adductors,
};

/// Slot tags for a user-made exercise, so the planner and generator can pick it like a seeded one.
List<SlotTag> deriveSlotTags(MovementPattern pattern, List<MuscleId> primary) {
  final perMuscle =
      pattern == MovementPattern.isolation || pattern == MovementPattern.carry || pattern == MovementPattern.core
      ? [for (final m in primary) _MUSCLE_ISO_TAG[m]!]
      : <SlotTag>[];
  return uniq([..._PATTERN_TAGS[pattern]!, ...perMuscle]);
}

/// Substitutions for the logger's Swap exercise: same primary muscle, feasible.
List<ExerciseDef> substitutionsFor(ExerciseDef ex, LibraryContext ctx) {
  final primaries = [
    for (final m in ex.muscles)
      if (m.role == MuscleRole.primary) m.muscle,
  ];
  final listed = <ExerciseDef>[];
  for (final slug in ex.substitutions) {
    for (final e in ctx.exercises) {
      if (e.slug == slug) {
        listed.add(e);
        break;
      }
    }
  }
  final sameSlot = [
    for (final e in ctx.exercises)
      if (e.id != ex.id && e.slotTags.any((t) => ex.slotTags.contains(t))) e,
  ];
  final out = <ExerciseDef>[];
  for (final e in [...listed, ...sameSlot]) {
    if (e.id == ex.id || out.any((o) => o.id == e.id)) continue;
    if (!isFeasible(e, ctx)) continue;
    if (!primaries.any((m) => isPrimary(e, m))) continue;
    out.add(e);
  }
  return out;
}
