// SPDX-License-Identifier: GPL-3.0-only
// Prescription: reps, RIR, rest. Rules: T-INT-01…05, T-RST-01/02, T-RIR-01.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

/// Which sub-range of a category's rep range a session uses.
enum RangeLevel {
  low('low'),
  mid('mid'),
  high('high');

  const RangeLevel(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, RangeLevel> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static RangeLevel fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown RangeLevel: "$wire"'));
}

/// The session variant of the between-session rep variation (`'A' | 'B'` in the reference).
enum SessionVariant {
  a('A'),
  b('B');

  const SessionVariant(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, SessionVariant> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SessionVariant fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SessionVariant: "$wire"'));
}

bool isCompound(Category c) => c != Category.isolation;

/// The reference takes `Pick<ExerciseDef, 'category'>`; callers pass `ex.category`.
int restFor(Category category, {bool? strengthMain}) {
  if (strengthMain == true) return REST_SECONDS.strengthMain;
  if (category == Category.lowerFreeCompound) return REST_SECONDS.lowerFreeCompound;
  if (category == Category.isolation) return REST_SECONDS.isolation;
  return REST_SECONDS.compound;
}

RepRange subRange(Category category, RangeLevel level) {
  final sr = SUB_RANGES[category]!;
  if (category == Category.isolation) return level == RangeLevel.high ? sr['high']! : sr['mid']!;
  return level == RangeLevel.low ? sr['low']! : sr['mid']!;
}

/// The options of [rangeLevel].
class RangeLevelOptions {
  RangeLevelOptions({
    required this.category,
    required this.compoundIndex,
    required this.isolationIndex,
    required this.variation,
    required this.variant,
    required this.weekIndex,
  });

  factory RangeLevelOptions.fromJson(Map<String, dynamic> json) => RangeLevelOptions(
    category: Category.fromWire(json['category'] as String),
    compoundIndex: json['compoundIndex'] as int,
    isolationIndex: json['isolationIndex'] as int,
    variation: RepVariation.fromWire(json['variation'] as String),
    variant: SessionVariant.fromWire(json['variant'] as String),
    weekIndex: json['weekIndex'] as int,
  );

  final Category category;

  /// Index among compounds in the session (0-based), -1 for isolations.
  final int compoundIndex;

  /// Index among isolations, -1 for compounds.
  final int isolationIndex;
  final RepVariation variation;
  final SessionVariant variant;
  final int weekIndex;

  Map<String, dynamic> toJson() => {
    'category': category.wire,
    'compoundIndex': compoundIndex,
    'isolationIndex': isolationIndex,
    'variation': variation.wire,
    'variant': variant.wire,
    'weekIndex': weekIndex,
  };
}

/// Decide the range level for an exercise in a session (T-INT-04).
RangeLevel rangeLevel(RangeLevelOptions opts) {
  final RangeLevelOptions(:category, :compoundIndex, :isolationIndex, :variation, :variant, :weekIndex) = opts;
  if (variation == RepVariation.withinSession) {
    // `%` in the reference keeps the sign of the dividend; only "is it 0" is read, which both agree on.
    if (category == Category.isolation) return isolationIndex.remainder(2) == 0 ? RangeLevel.mid : RangeLevel.high;
    return compoundIndex == 0 ? RangeLevel.low : RangeLevel.mid;
  }
  final heavy = variation == RepVariation.betweenSession ? variant == SessionVariant.a : weekIndex.remainder(2) == 0;
  if (category == Category.isolation) return heavy ? RangeLevel.mid : RangeLevel.high;
  return heavy ? RangeLevel.low : RangeLevel.mid;
}

class RxOptions {
  RxOptions({required this.level, required this.sportPriority, required this.isLowerCompound});

  factory RxOptions.fromJson(Map<String, dynamic> json) => RxOptions(
    level: RangeLevel.fromWire(json['level'] as String),
    sportPriority: json['sportPriority'] as bool,
    isLowerCompound: json['isLowerCompound'] as bool,
  );

  final RangeLevel level;
  final bool sportPriority;
  final bool isLowerCompound;

  Map<String, dynamic> toJson() => {
    'level': level.wire,
    'sportPriority': sportPriority,
    'isLowerCompound': isLowerCompound,
  };
}

/// The result of [prescribe]: a prescription without its set count.
class RxBase implements RuleTagged {
  RxBase({
    required this.repMin,
    required this.repMax,
    required this.rirMin,
    required this.rirMax,
    required this.restSeconds,
    required this.ruleIds,
  });

  factory RxBase.fromJson(Map<String, dynamic> json) => RxBase(
    repMin: json['repMin'] as int,
    repMax: json['repMax'] as int,
    rirMin: (json['rirMin'] as num).toDouble(),
    rirMax: (json['rirMax'] as num).toDouble(),
    restSeconds: json['restSeconds'] as int,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final int repMin;
  final int repMax;
  final double rirMin;
  final double rirMax;
  final int restSeconds;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'repMin': repMin,
    'repMax': repMax,
    'rirMin': rirMin,
    'rirMax': rirMax,
    'restSeconds': restSeconds,
    'ruleIds': [...ruleIds],
  };
}

/// Rep range, RIR range and rest for one exercise. The reference takes `Pick<ExerciseDef, 'category'>`.
RxBase prescribe(Category category, RxOptions opts) {
  final ruleIds = ['T-INT-03', 'T-INT-04', 'T-RST-02'];
  var level = opts.level;
  if (opts.sportPriority && opts.isLowerCompound && level == RangeLevel.low) {
    level = RangeLevel.mid; // T-INT-05: drop the heaviest sub-range on leg compounds
  }
  final [repMin, repMax] = subRange(category, level);
  final base = INTENSITY.byCategory[category]!;
  var [rirMin, rirMax] = base.rir;
  if (opts.sportPriority) {
    rirMin += INTENSITY.sportPriorityRirBump;
    rirMax += INTENSITY.sportPriorityRirBump;
    ruleIds.add('T-INT-05');
  }
  return RxBase(
    repMin: repMin,
    repMax: repMax,
    rirMin: rirMin,
    rirMax: rirMax,
    restSeconds: restFor(category),
    ruleIds: ruleIds,
  );
}

/// Short human-readable prescription, e.g. "3 × 8–12 @ 2–0 RIR".
String formatRx({
  required int sets,
  required int repMin,
  required int repMax,
  required num rirMin,
  required num rirMax,
}) {
  final reps = repMin == repMax ? '$repMin' : '$repMin–$repMax';
  final rir = rirMin == rirMax ? jsNumber(rirMin) : '${jsNumber(rirMax)}–${jsNumber(rirMin)}';
  return '$sets × $reps @ $rir RIR';
}

/// RPE ↔ RIR (T-RIR-01).
double rpeToRir(num rpe) => math.max(0, 10 - rpe).toDouble();
double rirToRpe(num rir) => math.min(10, 10 - rir).toDouble();

/// T-RIR-01: show the underestimation hint on high-rep sets.
bool showRirHint(int repMax) => repMax > 12;

/// One set of a warm-up ramp.
class WarmupSet {
  WarmupSet({required this.load, required this.reps});

  factory WarmupSet.fromJson(Map<String, dynamic> json) =>
      WarmupSet(load: (json['load'] as num).toDouble(), reps: json['reps'] as int);

  final double load;
  final int reps;

  Map<String, dynamic> toJson() => {'load': load, 'reps': reps};
}

/// Warm-up ramp for compounds ≥ 40 kg (T-WUP-01).
List<WarmupSet> warmupRamp(num workingLoad, num increment) {
  if (workingLoad < 40) return [];
  double r(num x) => (jsRound((workingLoad * x) / increment) * increment).toDouble();
  return [
    WarmupSet(load: r(0.5), reps: 8),
    WarmupSet(load: r(0.7), reps: 4),
    WarmupSet(load: r(0.85), reps: 2),
  ];
}
