// SPDX-License-Identifier: GPL-3.0-only
// Shared builders for the planner tests.
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';

/// A sport from the catalog on [weekdays] at [intensity].
UserSport sport(String id, List<int> weekdays, [SportIntensity intensity = SportIntensity.hard]) {
  final s = SPORT_SEEDS.firstWhere((x) => x.id == id);
  return UserSport(
    sportId: s.id,
    name: s.name,
    lowerBodyLoad: s.lower,
    upperBodyLoad: s.upper,
    eccentricImpact: s.impact,
    conditioning: s.conditioning,
    musclesStressed: s.muscles,
    weekdays: weekdays,
    intensity: intensity,
    minutes: s.defaultMinutes,
  );
}

/// The block generator's input with the fields that volume targets read.
BlockInput blockInput({
  required Goal goal,
  required Status status,
  Priority priority = Priority.lifting,
  List<UserSport> sports = const [],
  List<TrackedMuscle> specialization = const [],
}) => BlockInput(
  today: '2026-11-23',
  goal: goal,
  priority: priority,
  status: status,
  availableDays: const [1, 2, 4, 5],
  sessionMinutes: 60,
  equipment: const [],
  increments: const {},
  sports: sports,
  injuries: const [],
  exercises: const [],
  history: History(sets: const []),
  repVariation: RepVariation.withinSession,
  specialization: specialization,
);
