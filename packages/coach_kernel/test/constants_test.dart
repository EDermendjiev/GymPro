// SPDX-License-Identifier: GPL-3.0-only
// ignore_for_file: unnecessary_lambdas
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

/// A map keyed by an enum, as the reference writes it: keyed by the wire strings.
Map<String, Object?> _byWire<K extends Enum>(Map<K, Object?> map, String Function(K) wire) => {
  for (final e in map.entries) wire(e.key): e.value,
};

/// Each exported constant of the reference, rebuilt from the Dart constants in the reference's JSON shape.
final _constants = <String, Object? Function()>{
  'ENGINE_VERSION': () => ENGINE_VERSION,
  'VOLUME': () => {
    'minEffective': VOLUME.minEffective,
    'practical': VOLUME.practical,
    'ceiling': VOLUME.ceiling,
    'baseByStatus': _byWire(VOLUME.baseByStatus, (Status k) => k.wire),
    'sportPriorityBase': VOLUME.sportPriorityBase,
    'balancedSportPenalty': VOLUME.balancedSportPenalty,
    'balancedSportThreshold': VOLUME.balancedSportThreshold,
    'fatLossCap': VOLUME.fatLossCap,
    'frontDeltFactor': VOLUME.frontDeltFactor,
    'normalCap': VOLUME.normalCap,
    'specialization': {
      'up': VOLUME.specialization.up,
      'others': VOLUME.specialization.others,
      'weeks': VOLUME.specialization.weeks,
    },
    'countingMinReps': VOLUME.countingMinReps,
    'countingMaxRir': VOLUME.countingMaxRir,
    'fractional': {'primary': VOLUME.fractional.primary, 'secondary': VOLUME.fractional.secondary},
    'sportPriorityLowerCap': VOLUME.sportPriorityLowerCap,
    'plateauAddSets': VOLUME.plateauAddSets,
  },
  'FREQUENCY': () => {
    'maxSetsPerMusclePerSession': FREQUENCY.maxSetsPerMusclePerSession,
    'byWeeklySets': [
      for (final b in FREQUENCY.byWeeklySets) {'max': b.max, 'freq': b.freq},
    ],
    'liftDays': {
      'min': FREQUENCY.liftDays.min,
      'typical': FREQUENCY.liftDays.typical,
      'max': FREQUENCY.liftDays.max,
    },
  },
  'INTENSITY': () => {
    for (final e in INTENSITY.byCategory.entries) e.key.wire: {'reps': e.value.reps, 'rir': e.value.rir},
    'sportPriorityRirBump': INTENSITY.sportPriorityRirBump,
  },
  'SUB_RANGES': () => _byWire(SUB_RANGES, (Category k) => k.wire),
  'REST_SECONDS': () => {
    'strengthMain': REST_SECONDS.strengthMain,
    'lowerFreeCompound': REST_SECONDS.lowerFreeCompound,
    'compound': REST_SECONDS.compound,
    'isolation': REST_SECONDS.isolation,
    'minimumHypertrophy': REST_SECONDS.minimumHypertrophy,
  },
  'SESSION_TIME': () => {
    'workSecondsCompound': SESSION_TIME.workSecondsCompound,
    'workSecondsIsolation': SESSION_TIME.workSecondsIsolation,
    'warmupMinutes': SESSION_TIME.warmupMinutes,
    'minSetsPerExercise': SESSION_TIME.minSetsPerExercise,
    'maxSetsPerExercise': SESSION_TIME.maxSetsPerExercise,
    'startSetsCompound': SESSION_TIME.startSetsCompound,
    'startSetsIsolation': SESSION_TIME.startSetsIsolation,
    'maxExercisesPerSession': SESSION_TIME.maxExercisesPerSession,
  },
  'PROGRESSION': () => {
    'loadAdjustPerRep': PROGRESSION.loadAdjustPerRep,
    'heavyLowerJumpThresholdKg': PROGRESSION.heavyLowerJumpThresholdKg,
    'heavyLowerJumpKg': PROGRESSION.heavyLowerJumpKg,
  },
  'DELOAD': () => {
    'setCutDefault': DELOAD.setCutDefault,
    'setCutRange': DELOAD.setCutRange,
    'yesThreshold': DELOAD.yesThreshold,
  },
  'TARGETED_DELOAD': () => {'reduceSetsPct': TARGETED_DELOAD.reduceSetsPct},
  'INTRO_WEEK': () => {
    'setPct': INTRO_WEEK.setPct,
    'rirBump': INTRO_WEEK.rirBump,
    'volumeJumpTrigger': INTRO_WEEK.volumeJumpTrigger,
    'weeksOffTrigger': INTRO_WEEK.weeksOffTrigger,
  },
  'HIGHER_REP_WEEK': () => _byWire(HIGHER_REP_WEEK, (Category k) => k.wire),
  'RIR_DRIFT': () => {
    'minBelowFloor': RIR_DRIFT.minBelowFloor,
    'similarLoadPct': RIR_DRIFT.similarLoadPct,
    'consecutiveExposures': RIR_DRIFT.consecutiveExposures,
    'exercises': RIR_DRIFT.exercises,
  },
  'REVIEW_PLAN': () => {
    'volumeCutSets': REVIEW_PLAN.volumeCutSets,
    'volumeCutMinTarget': REVIEW_PLAN.volumeCutMinTarget,
    'painDaysForInjury': REVIEW_PLAN.painDaysForInjury,
    'painLookbackDays': REVIEW_PLAN.painLookbackDays,
  },
  'PLATEAU_WINDOW': () => {
    'novice': {'exposures': PLATEAU_WINDOW.novice.exposures},
    'intermediate': {'weeks': PLATEAU_WINDOW.intermediate.weeks},
    'advanced': {'weeks': PLATEAU_WINDOW.advanced.weeks},
  },
  'SPORT_TRIM_PER_SESSION': () => {for (final e in SPORT_TRIM_PER_SESSION.entries) '${e.key}': e.value},
  'SPORT_TRIM_MAX': () => SPORT_TRIM_MAX,
  'STRENGTH': () => {
    'volume': {
      'weeks': STRENGTH.volume.weeks,
      'defaultWeeks': STRENGTH.volume.defaultWeeks,
      'singlesPerWeek': STRENGTH.volume.singlesPerWeek,
      'rpe': STRENGTH.volume.rpe,
      'secondarySets': STRENGTH.volume.secondarySets,
    },
    'load': {
      'weeks': STRENGTH.load.weeks,
      'defaultWeeks': STRENGTH.load.defaultWeeks,
      'singlesPerWeek': STRENGTH.load.singlesPerWeek,
      'rpe': STRENGTH.load.rpe,
      'backoffSets': STRENGTH.load.backoffSets,
      'backoffRpe': STRENGTH.load.backoffRpe,
      'backoffReps': STRENGTH.load.backoffReps,
      'secondarySets': STRENGTH.load.secondarySets,
    },
    'peak': {
      'singlesPerWeek': STRENGTH.peak.singlesPerWeek,
      'rpe': STRENGTH.peak.rpe,
      'backoffSets': STRENGTH.peak.backoffSets,
      'backoffRpe': STRENGTH.peak.backoffRpe,
      'reps': STRENGTH.peak.reps,
      'secondarySets': STRENGTH.peak.secondarySets,
    },
    'secondaryTargetVolume': STRENGTH.secondaryTargetVolume,
    'secondaryTargetLoad': STRENGTH.secondaryTargetLoad,
    'secondaryTargetPeak': STRENGTH.secondaryTargetPeak,
  },
  'BLOCK_WEEKS': () => _byWire(BLOCK_WEEKS, (BlockKind k) => k.wire),
  'NUTRITION': () => {
    'bmrPerKg': NUTRITION.bmrPerKg,
    'multipliers': _byWire(NUTRITION.multipliers, (Lifestyle k) => k.wire),
    'multiplierDefault': _byWire(NUTRITION.multiplierDefault, (Lifestyle k) => k.wire),
    'kcalPerKgWeeklyChange': NUTRITION.kcalPerKgWeeklyChange,
    'lossRatePctPerWeek': {
      'min': NUTRITION.lossRatePctPerWeek.min,
      'max': NUTRITION.lossRatePctPerWeek.max,
      'default': NUTRITION.lossRatePctPerWeek.defaultPct,
      'lean': NUTRITION.lossRatePctPerWeek.lean,
      'tolerance': NUTRITION.lossRatePctPerWeek.tolerance,
    },
    'lossRateOptions': NUTRITION.lossRateOptions,
    'leanBodyFat': _byWire(NUTRITION.leanBodyFat, (Sex k) => k.wire),
    'gainRatePctPerMonth': _byWire(NUTRITION.gainRatePctPerMonth, (Status k) => k.wire),
    'gainDefault': _byWire(NUTRITION.gainDefault, (Status k) => k.wire),
    'gainRateOptions': NUTRITION.gainRateOptions,
    'bigDeficitWarn': NUTRITION.bigDeficitWarn,
    'cardioKcalPerKgPer10Min': {
      'light': NUTRITION.cardioKcalPerKgPer10Min.light,
      'moderate': NUTRITION.cardioKcalPerKgPer10Min.moderate,
      'vigorous': NUTRITION.cardioKcalPerKgPer10Min.vigorous,
    },
    'sportCalibration': {
      'minLoggedSessions': NUTRITION.sportCalibration.minLoggedSessions,
      'lookbackDays': NUTRITION.sportCalibration.lookbackDays,
    },
    'recomputeOnBodyweightKg': NUTRITION.recomputeOnBodyweightKg,
    'protein': {
      'base': NUTRITION.protein.base,
      'leanDeficit': NUTRITION.protein.leanDeficit,
      'leanThresholdBf': _byWire(NUTRITION.protein.leanThresholdBf, (Sex k) => k.wire),
    },
    'fatMin': {
      'lightKg': NUTRITION.fatMin.lightKg,
      'heavyKg': NUTRITION.fatMin.heavyKg,
      'low': NUTRITION.fatMin.low,
      'high': NUTRITION.fatMin.high,
    },
    'fatShareOfMaintenance': NUTRITION.fatShareOfMaintenance,
    'carbMin': {'surplusOrMaint': NUTRITION.carbMin.surplusOrMaint, 'deficit': NUTRITION.carbMin.deficit},
    'kcalBand': NUTRITION.kcalBand,
    'adjust': {
      'initialMultiplierStep': NUTRITION.adjust.initialMultiplierStep,
      'under3000': NUTRITION.adjust.under3000,
      'over3000': NUTRITION.adjust.over3000,
      'defaultUnder': NUTRITION.adjust.defaultUnder,
      'defaultOver': NUTRITION.adjust.defaultOver,
      'minDaysBetween': NUTRITION.adjust.minDaysBetween,
      'maintainDriftPctPerWeek': NUTRITION.adjust.maintainDriftPctPerWeek,
      'maintainStep': NUTRITION.adjust.maintainStep,
    },
    'weighIns': {
      'minPerWeek': NUTRITION.weighIns.minPerWeek,
      'needsWeekendDay': NUTRITION.weighIns.needsWeekendDay,
      'runningAvgDays': NUTRITION.weighIns.runningAvgDays,
    },
    'gainToCutRatio': NUTRITION.gainToCutRatio,
    'safety': {
      'minKcalVsBmr': NUTRITION.safety.minKcalVsBmr,
      'maxLossPctPerWeek': NUTRITION.safety.maxLossPctPerWeek,
    },
  },
  'REVIEW': () => {
    'energyDreadThreshold': REVIEW.energyDreadThreshold,
    'skippedDreadThreshold': REVIEW.skippedDreadThreshold,
    'sleepDropHours': REVIEW.sleepDropHours,
    'sleepNoBaseline': REVIEW.sleepNoBaseline,
    'stressRise': REVIEW.stressRise,
    'soreAboveAverage': REVIEW.soreAboveAverage,
    'perfDropExercises': REVIEW.perfDropExercises,
    'e1rmDropPct': REVIEW.e1rmDropPct,
    'proposalExpiryDays': REVIEW.proposalExpiryDays,
    'lowReadinessScore': REVIEW.lowReadinessScore,
  },
  'STATUS_INFERENCE': () => {
    'minWeeks': STATUS_INFERENCE.minWeeks,
    'novice': STATUS_INFERENCE.novice,
    'advanced': STATUS_INFERENCE.advanced,
    'consecutiveReviews': STATUS_INFERENCE.consecutiveReviews,
  },
  'DEFAULT_INCREMENTS': () => DEFAULT_INCREMENTS,
};

void main() {
  final cases = loadFixture('constants.json');

  for (final c in cases) {
    test(c.name, () {
      final build = _constants[c.name];
      if (build == null) fail('No Dart constant registered for ${c.name}');
      expect(jsonDiff(build(), c.output), isNull);
    });
  }

  test('every Dart constant is in the fixture', () {
    expect(_constants.keys.toSet(), {for (final c in cases) c.name});
  });

  test('block lengths follow the strength phases', () {
    expect(BLOCK_WEEKS[BlockKind.strengthVolume], STRENGTH.volume.defaultWeeks);
    expect(BLOCK_WEEKS[BlockKind.strengthLoad], STRENGTH.load.defaultWeeks);
    expect(BLOCK_WEEKS.containsKey(BlockKind.strengthPeak), isFalse);
  });
}
