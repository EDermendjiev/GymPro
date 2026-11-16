// SPDX-License-Identifier: GPL-3.0-only
// The coach packages know 16 muscles, the app knows 14. This file translates in both directions.
// The tables are documented in docs/coach/ARCHITECTURE.md.
import 'package:coach_kernel/coach_kernel.dart';

const Map<String, MuscleId> _toCoach = {
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

const String _shoulders = 'shoulders';

/// The coach muscle for one of the app's muscle ids, or null when the id is not a muscle of the app.
///
/// The app has one `shoulders` muscle where the coach has three, so for shoulders the answer depends on the
/// exercise: a press trains the front, anything named rear, reverse or face pull trains the rear, and everything
/// else counts as the side. An exercise with its own coaching attributes is resolved from those before this
/// function is asked.
MuscleId? coachMuscle(String muscleId, {String exerciseName = ''}) {
  if (muscleId != _shoulders) return _toCoach[muscleId];
  final name = exerciseName.toLowerCase();
  if (name.contains('press')) return MuscleId.frontDelts;
  if (name.contains('rear') || name.contains('reverse') || name.contains('face pull')) return MuscleId.rearDelts;
  return MuscleId.sideDelts;
}

/// The app's muscle id for a coach muscle. Null for the adductors, which the app does not show.
String? hostMuscle(MuscleId m) => switch (m) {
  MuscleId.chest => 'chest',
  MuscleId.back => 'back',
  MuscleId.frontDelts || MuscleId.sideDelts || MuscleId.rearDelts => _shoulders,
  MuscleId.biceps => 'biceps',
  MuscleId.triceps => 'triceps',
  MuscleId.quads => 'quads',
  MuscleId.hamstrings => 'hamstrings',
  MuscleId.glutes => 'glutes',
  MuscleId.calves => 'calves',
  MuscleId.abs => 'abdomen',
  MuscleId.forearms => 'forearm',
  MuscleId.traps => 'trapezius',
  MuscleId.erectors => 'lowerback',
  MuscleId.adductors => null,
};
