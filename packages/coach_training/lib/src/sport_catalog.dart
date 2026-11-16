// SPDX-License-Identifier: GPL-3.0-only
// Sport catalog seed. Scheduling notes in our own words.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';

class SportSeed {
  const SportSeed({
    required this.id,
    required this.name,
    required this.lower,
    required this.upper,
    required this.impact,
    required this.conditioning,
    required this.muscles,
    required this.defaultMinutes,
    required this.notes,
  });

  factory SportSeed.fromJson(Map<String, dynamic> json) => SportSeed(
    id: json['id'] as String,
    name: json['name'] as String,
    lower: json['lower'] as int,
    upper: json['upper'] as int,
    impact: json['impact'] as int,
    conditioning: json['conditioning'] as int,
    muscles: [for (final x in json['muscles'] as List) MuscleId.fromWire(x as String)],
    defaultMinutes: json['defaultMinutes'] as int,
    notes: json['notes'] as String,
  );

  final String id;
  final String name;
  final int lower;
  final int upper;
  final int impact;
  final int conditioning;
  final List<MuscleId> muscles;
  final int defaultMinutes;
  final String notes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lower': lower,
    'upper': upper,
    'impact': impact,
    'conditioning': conditioning,
    'muscles': [for (final m in muscles) m.wire],
    'defaultMinutes': defaultMinutes,
    'notes': notes,
  };
}

const List<SportSeed> SPORT_SEEDS = [
  SportSeed(
    id: 'football',
    name: 'Football (soccer)',
    lower: 3,
    upper: 0,
    impact: 3,
    conditioning: 3,
    muscles: [MuscleId.quads, MuscleId.hamstrings, MuscleId.glutes, MuscleId.calves, MuscleId.adductors],
    defaultMinutes: 90,
    notes:
        'Sprints, cuts and kicks load the legs hard; keep heavy leg work at least 24 h before a match or hard session and not the day after a match.',
  ),
  SportSeed(
    id: 'running',
    name: 'Running',
    lower: 2,
    upper: 0,
    impact: 2,
    conditioning: 3,
    muscles: [MuscleId.quads, MuscleId.calves, MuscleId.hamstrings],
    defaultMinutes: 45,
    notes:
        'Running interferes most with leg training; do easy runs after lifting or on other days and keep intervals away from leg day.',
  ),
  SportSeed(
    id: 'boxing',
    name: 'Boxing',
    lower: 1,
    upper: 2,
    impact: 1,
    conditioning: 3,
    muscles: [MuscleId.frontDelts, MuscleId.sideDelts, MuscleId.triceps, MuscleId.calves],
    defaultMinutes: 60,
    notes: 'Rounds tax shoulders, arms and footwork; avoid heavy pressing right before. Legs are mostly fine.',
  ),
  SportSeed(
    id: 'tennis',
    name: 'Tennis',
    lower: 2,
    upper: 2,
    impact: 2,
    conditioning: 2,
    muscles: [MuscleId.quads, MuscleId.calves, MuscleId.sideDelts, MuscleId.frontDelts, MuscleId.forearms],
    defaultMinutes: 90,
    notes: 'Lateral cuts and serves; treat it like a moderate leg and shoulder day.',
  ),
  SportSeed(
    id: 'swimming',
    name: 'Swimming',
    lower: 1,
    upper: 2,
    impact: 0,
    conditioning: 3,
    muscles: [MuscleId.back, MuscleId.frontDelts, MuscleId.sideDelts, MuscleId.triceps],
    defaultMinutes: 45,
    notes: 'Low impact and great conditioning; shoulders and lats get extra work.',
  ),
  SportSeed(
    id: 'cycling',
    name: 'Cycling',
    lower: 2,
    upper: 0,
    impact: 0,
    conditioning: 3,
    muscles: [MuscleId.quads, MuscleId.glutes, MuscleId.calves],
    defaultMinutes: 60,
    notes:
        'Little eccentric load, so it is the most lifting-friendly cardio, but hard intervals still tire the quads.',
  ),
  SportSeed(
    id: 'basketball',
    name: 'Basketball',
    lower: 3,
    upper: 1,
    impact: 3,
    conditioning: 3,
    muscles: [MuscleId.quads, MuscleId.calves, MuscleId.hamstrings, MuscleId.glutes],
    defaultMinutes: 90,
    notes: 'Jumps and landings are hard on knees and calves; schedule it like football.',
  ),
];
