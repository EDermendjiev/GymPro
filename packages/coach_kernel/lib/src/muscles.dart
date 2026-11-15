// SPDX-License-Identifier: GPL-3.0-only
// Muscle groups (body map + volume counting) and movement patterns.
// ignore_for_file: constant_identifier_names, non_constant_identifier_names
import 'model/enums.dart';

/// `MuscleSeed.region` in the reference.
enum MuscleRegion {
  upper('upper'),
  lower('lower'),
  core('core');

  const MuscleRegion(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, MuscleRegion> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static MuscleRegion fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown MuscleRegion: "$wire"'));
}

/// One entry of `MuscleSeed.sides` in the reference.
enum BodySide {
  front('front'),
  back('back');

  const BodySide(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, BodySide> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static BodySide fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown BodySide: "$wire"'));
}

class MuscleSeed {
  const MuscleSeed({
    required this.id,
    required this.name,
    required this.region,
    required this.tracked,
    required this.sides,
  });

  factory MuscleSeed.fromJson(Map<String, dynamic> json) => MuscleSeed(
    id: MuscleId.fromWire(json['id'] as String),
    name: json['name'] as String,
    region: MuscleRegion.fromWire(json['region'] as String),
    tracked: json['tracked'] as bool,
    sides: [for (final x in json['sides'] as List) BodySide.fromWire(x as String)],
  );

  final MuscleId id;
  final String name;
  final MuscleRegion region;
  final bool tracked;
  final List<BodySide> sides;

  Map<String, dynamic> toJson() => {
    'id': id.wire,
    'name': name,
    'region': region.wire,
    'tracked': tracked,
    'sides': [for (final x in sides) x.wire],
  };
}

const _front = [BodySide.front];
const _back = [BodySide.back];
const _both = [BodySide.front, BodySide.back];

const List<MuscleSeed> MUSCLE_SEEDS = [
  MuscleSeed(id: MuscleId.chest, name: 'Chest', region: MuscleRegion.upper, tracked: true, sides: _front),
  MuscleSeed(
    id: MuscleId.back,
    name: 'Back (lats & upper back)',
    region: MuscleRegion.upper,
    tracked: true,
    sides: _back,
  ),
  MuscleSeed(
    id: MuscleId.frontDelts,
    name: 'Front delts',
    region: MuscleRegion.upper,
    tracked: true,
    sides: _front,
  ),
  MuscleSeed(
    id: MuscleId.sideDelts,
    name: 'Side delts',
    region: MuscleRegion.upper,
    tracked: true,
    sides: _both,
  ),
  MuscleSeed(
    id: MuscleId.rearDelts,
    name: 'Rear delts',
    region: MuscleRegion.upper,
    tracked: true,
    sides: _back,
  ),
  MuscleSeed(id: MuscleId.biceps, name: 'Biceps', region: MuscleRegion.upper, tracked: true, sides: _front),
  MuscleSeed(id: MuscleId.triceps, name: 'Triceps', region: MuscleRegion.upper, tracked: true, sides: _back),
  MuscleSeed(id: MuscleId.quads, name: 'Quads', region: MuscleRegion.lower, tracked: true, sides: _front),
  MuscleSeed(
    id: MuscleId.hamstrings,
    name: 'Hamstrings',
    region: MuscleRegion.lower,
    tracked: true,
    sides: _back,
  ),
  MuscleSeed(id: MuscleId.glutes, name: 'Glutes', region: MuscleRegion.lower, tracked: true, sides: _back),
  MuscleSeed(id: MuscleId.calves, name: 'Calves', region: MuscleRegion.lower, tracked: true, sides: _both),
  MuscleSeed(id: MuscleId.abs, name: 'Abs', region: MuscleRegion.core, tracked: false, sides: _front),
  MuscleSeed(
    id: MuscleId.forearms,
    name: 'Forearms',
    region: MuscleRegion.upper,
    tracked: false,
    sides: _both,
  ),
  MuscleSeed(id: MuscleId.traps, name: 'Traps', region: MuscleRegion.upper, tracked: false, sides: _both),
  MuscleSeed(
    id: MuscleId.erectors,
    name: 'Lower back (erectors)',
    region: MuscleRegion.core,
    tracked: false,
    sides: _back,
  ),
  MuscleSeed(
    id: MuscleId.adductors,
    name: 'Adductors',
    region: MuscleRegion.lower,
    tracked: false,
    sides: _front,
  ),
];

final Map<MuscleId, String> MUSCLE_NAME = {for (final m in MUSCLE_SEEDS) m.id: m.name};

const Map<MuscleId, String> MUSCLE_SHORT = {
  MuscleId.chest: 'Chest',
  MuscleId.back: 'Back',
  MuscleId.frontDelts: 'Front delts',
  MuscleId.sideDelts: 'Side delts',
  MuscleId.rearDelts: 'Rear delts',
  MuscleId.biceps: 'Biceps',
  MuscleId.triceps: 'Triceps',
  MuscleId.quads: 'Quads',
  MuscleId.hamstrings: 'Hamstrings',
  MuscleId.glutes: 'Glutes',
  MuscleId.calves: 'Calves',
  MuscleId.abs: 'Abs',
  MuscleId.forearms: 'Forearms',
  MuscleId.traps: 'Traps',
  MuscleId.erectors: 'Lower back',
  MuscleId.adductors: 'Adductors',
};

/// Untracked muscles have no weekly target of their own (T-VOL-05 counts only the tracked list). The body map points
/// each to the tracked group whose work trains it most, so the detail sheet can say where its volume comes from.
/// Abs: none.
const Map<MuscleId, ({MuscleId muscle, String how})> INDIRECT_VIA = {
  MuscleId.traps: (muscle: MuscleId.back, how: 'rows, pulls and deadlifts'),
  MuscleId.forearms: (muscle: MuscleId.biceps, how: 'curls, rows and pulls (grip)'),
  MuscleId.erectors: (muscle: MuscleId.hamstrings, how: 'hinges, squats and rows'),
  MuscleId.adductors: (muscle: MuscleId.quads, how: 'squats, lunges and deadlifts'),
};

const List<({MovementPattern id, String name})> PATTERN_SEEDS = [
  (id: MovementPattern.squat, name: 'Squat'),
  (id: MovementPattern.hinge, name: 'Hip hinge'),
  (id: MovementPattern.verticalPull, name: 'Vertical pull'),
  (id: MovementPattern.verticalPush, name: 'Vertical push'),
  (id: MovementPattern.horizontalPull, name: 'Horizontal pull'),
  (id: MovementPattern.horizontalPush, name: 'Horizontal push'),
  (id: MovementPattern.hipExtension, name: 'Hip extension'),
  (id: MovementPattern.pullover, name: 'Pullover'),
  (id: MovementPattern.uprightRow, name: 'Upright row'),
  (id: MovementPattern.fly, name: 'Fly'),
  (id: MovementPattern.isolation, name: 'Isolation'),
  (id: MovementPattern.carry, name: 'Carry / sled'),
  (id: MovementPattern.core, name: 'Core'),
];
