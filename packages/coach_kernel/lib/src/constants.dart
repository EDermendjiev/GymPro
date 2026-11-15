// SPDX-License-Identifier: GPL-3.0-only
// All numeric constants used by the rules engine. Every value carries the rule ID it implements.
// Values marked "heuristic" are product heuristics that fill in a detail the rules leave open.
//
// The names and the nesting are the reference's, so `VOLUME.fractional.primary` reads the same in both. Objects with
// fixed keys are records; objects indexed by a variable are maps keyed by the matching enum. Number types: weekly set
// targets, loads, RIR, RPE, hours, grams, factors and percentages are doubles; reps, set counts of one exercise, weeks,
// days, seconds, session counts and kcal are ints.
// ignore_for_file: constant_identifier_names
import 'model/enums.dart';

const ENGINE_VERSION = '1.0.0';

const VOLUME = (
  minEffective: 4.0, // T-VOL-01
  practical: [10.0, 20.0], // T-VOL-02
  ceiling: 30.0, // T-VOL-03
  baseByStatus: {Status.novice: 10.0, Status.intermediate: 12.0, Status.advanced: 14.0}, // heuristic
  sportPriorityBase: 6.0, // heuristic from T-PRI-01
  balancedSportPenalty: 2.0, // heuristic: when ≥2 hard sport sessions
  balancedSportThreshold: 2, // heuristic
  fatLossCap: 14.0, // heuristic
  frontDeltFactor: 0.5, // heuristic
  normalCap: 20.0, // T-VOL-02
  specialization: (up: 1.5, others: 0.6, weeks: [8, 12]), // T-VOL-08
  countingMinReps: 4, // T-VOL-06
  countingMaxRir: 4.0, // T-VOL-06
  fractional: (primary: 1.0, secondary: 0.5), // T-VOL-05
  sportPriorityLowerCap: 8.0, // S-05
  plateauAddSets: 2.0, // T-VOL-07 / plateau flowchart
);

const FREQUENCY = (
  maxSetsPerMusclePerSession: 11.0, // T-FRQ-01
  // T-FRQ-02
  byWeeklySets: [
    (max: 10.0, freq: [1, 2]),
    (max: 20.0, freq: [2, 3]),
    (max: 30.0, freq: [3, 6]),
  ],
  liftDays: (min: 2, typical: [3, 5], max: 6), // T-FRQ-04
);

/// A rep range, `[lowest, highest]`.
typedef RepRange = List<int>;

/// A RIR range, `[lowest, highest]`. The reference uses its rep-range type for these too; RIR can be a half.
typedef RirRange = List<double>;

/// `INTENSITY[category]` in the reference is `INTENSITY.byCategory[category]` here: a record cannot be indexed.
const INTENSITY = (
  // T-INT-03: rep range and RIR range per exercise category
  byCategory: {
    Category.lowerFreeCompound: (reps: <int>[4, 8], rir: <double>[2, 4]),
    Category.lowerMachineCompound: (reps: <int>[4, 12], rir: <double>[1, 4]),
    Category.upperFreePress: (reps: <int>[4, 12], rir: <double>[1, 4]),
    Category.upperMachinePress: (reps: <int>[6, 15], rir: <double>[0, 3]),
    Category.pullingCompound: (reps: <int>[6, 15], rir: <double>[0, 3]),
    Category.isolation: (reps: <int>[8, 20], rir: <double>[0, 2]),
  },
  sportPriorityRirBump: 1.0, // T-INT-05
);

// Heuristic from T-INT-04: concrete sub-ranges for rep-range variation. The inner keys are 'low', 'mid' and, for
// isolation only, 'high'.
const Map<Category, Map<String, RepRange>> SUB_RANGES = {
  Category.lowerFreeCompound: {
    'low': [4, 6],
    'mid': [6, 8],
  },
  Category.lowerMachineCompound: {
    'low': [5, 8],
    'mid': [8, 12],
  },
  Category.upperFreePress: {
    'low': [5, 8],
    'mid': [8, 12],
  },
  Category.upperMachinePress: {
    'low': [6, 10],
    'mid': [10, 15],
  },
  Category.pullingCompound: {
    'low': [6, 10],
    'mid': [10, 15],
  },
  Category.isolation: {
    'low': [10, 15],
    'mid': [10, 15],
    'high': [15, 20],
  },
};

const REST_SECONDS = (
  strengthMain: 180, // T-RST-01
  lowerFreeCompound: 180, // T-RST-02
  compound: 150, // T-RST-02
  isolation: 90, // T-RST-02
  minimumHypertrophy: 90, // T-RST-02
);

const SESSION_TIME = (
  workSecondsCompound: 50, // heuristic
  workSecondsIsolation: 40, // heuristic
  warmupMinutes: 8, // heuristic
  minSetsPerExercise: 2,
  maxSetsPerExercise: 5,
  startSetsCompound: 3,
  startSetsIsolation: 2, // heuristic
  maxExercisesPerSession: 8,
);

const PROGRESSION = (
  loadAdjustPerRep: 0.04, // T-PRG-03
  heavyLowerJumpThresholdKg: 100.0, // heuristic
  heavyLowerJumpKg: 5.0, // heuristic
);

const DELOAD = (setCutDefault: 0.4, setCutRange: [0.3, 0.5], yesThreshold: 2); // T-FAT-01/03
const TARGETED_DELOAD = (reduceSetsPct: 0.5); // heuristic from T-FAT-04
const INTRO_WEEK = (setPct: 0.75, rirBump: 1.0, volumeJumpTrigger: 0.2, weeksOffTrigger: 2); // T-FAT-06

// T-FAT-05: a week of higher reps on the exercises that load an aching area. Heuristic: concrete ranges per category,
// above each category's normal range (T-INT-03) but inside the 4–30 rep hypertrophy range (T-INT-01).
const Map<Category, RepRange> HIGHER_REP_WEEK = {
  Category.lowerFreeCompound: [10, 15],
  Category.lowerMachineCompound: [12, 20],
  Category.upperFreePress: [12, 15],
  Category.upperMachinePress: [12, 20],
  Category.pullingCompound: [12, 20],
  Category.isolation: [15, 25],
};

// Heuristic from T-RIR-01 / T-FAT-01: logged RIR below the prescribed floor at a similar load, on consecutive exposures.
const RIR_DRIFT = (
  // A set counts as "harder than planned" when RIR ≤ rirMin − 1 (people already underestimate by ~1, T-RIR-01).
  minBelowFloor: 1.0,
  similarLoadPct: 0.025, // load within +2.5% of the previous exposure counts as "the same load"
  consecutiveExposures: 2,
  exercises: 2, // like REVIEW.perfDropExercises
);

// Heuristics for the weekly review's plan proposals (T-VOL-02/07, T-FAT-03, T-SEL-08).
const REVIEW_PLAN = (
  volumeCutSets: 2.0, // repeated recovery flags → −2 weekly sets on muscles at ≥ volumeCutMinTarget
  volumeCutMinTarget: 10.0, // T-VOL-02 practical floor: only trim muscles at or above it
  painDaysForInjury: 2, // pain tags on ≥ 2 days in the last 14 → treat as a recurring injury (T-SEL-08)
  painLookbackDays: 14,
);

// Heuristic from T-PRG-06.
const PLATEAU_WINDOW = (novice: (exposures: 3), intermediate: (weeks: 4), advanced: (weeks: 8));

const Map<int, double> SPORT_TRIM_PER_SESSION = {0: 0, 1: 0.5, 2: 1, 3: 1.5}; // S-02
const SPORT_TRIM_MAX = 4.0; // S-02

const STRENGTH = (
  volume: (
    weeks: [6, 12],
    defaultWeeks: 8,
    singlesPerWeek: [1, 3],
    rpe: <double>[5, 8],
    secondarySets: <double>[10, 20],
  ),
  load: (
    weeks: [4, 8],
    defaultWeeks: 6,
    singlesPerWeek: [2, 4],
    rpe: <double>[6, 9],
    backoffSets: 2,
    backoffRpe: 7.0,
    backoffReps: [5, 3],
    secondarySets: <double>[5, 10],
  ),
  peak: (
    singlesPerWeek: [2, 5],
    rpe: <double>[7, 10],
    backoffSets: [0, 3],
    backoffRpe: 7.0,
    reps: [4, 2],
    secondarySets: <double>[0, 4],
  ),
  secondaryTargetVolume: 12.0, // heuristic: inside 10–20 (T-STR-02)
  secondaryTargetLoad: 8.0, // heuristic: inside 5–10 (T-STR-03)
  secondaryTargetPeak: 4.0, // heuristic: inside 0–4 (T-STR-04)
);

/// Has no entry for [BlockKind.strengthPeak], as in the reference.
const Map<BlockKind, int> BLOCK_WEEKS = {
  BlockKind.hypertrophy: 6, // heuristic
  BlockKind.sportSupport: 6, // heuristic
  BlockKind.strengthVolume: 8, // STRENGTH.volume.defaultWeeks; a record field is not a constant expression
  BlockKind.strengthLoad: 6, // STRENGTH.load.defaultWeeks
};

const NUTRITION = (
  bmrPerKg: 22, // N-MNT-01
  // N-MNT-02
  multipliers: {
    Lifestyle.sedentary: [1.3, 1.6],
    Lifestyle.lightlyActive: [1.5, 1.8],
    Lifestyle.active: [1.7, 2.0],
    Lifestyle.veryActive: [1.9, 2.2],
  },
  multiplierDefault: {
    Lifestyle.sedentary: 1.45,
    Lifestyle.lightlyActive: 1.65,
    Lifestyle.active: 1.85,
    Lifestyle.veryActive: 2.05,
  },
  kcalPerKgWeeklyChange: 1100, // N-RAT-03
  // N-RAT-01. `defaultPct` is `default` in the reference, a reserved word in Dart.
  lossRatePctPerWeek: (min: 0.5, max: 1.0, defaultPct: 0.75, lean: 0.5, tolerance: 0.25),
  lossRateOptions: [0.5, 0.75, 1.0], // N-RAT-01 choices offered in the app
  leanBodyFat: {Sex.male: 15.0, Sex.female: 23.0, Sex.unspecified: 15.0}, // heuristic thresholds for N-RAT-01
  // N-RAT-02
  gainRatePctPerMonth: {
    Status.novice: [1.0, 2.0],
    Status.intermediate: [0.5, 1.5],
    Status.advanced: [0.0, 0.5],
  },
  gainDefault: {Status.novice: 1.5, Status.intermediate: 1.0, Status.advanced: 0.5},
  gainRateOptions: [0.25, 0.5, 1.0, 1.5, 2.0], // N-RAT-02 choices, filtered to the status range
  bigDeficitWarn: 750, // N-RAT-04
  cardioKcalPerKgPer10Min: (light: 0.44, moderate: 0.99, vigorous: 1.54), // N-SPT-01
  // Heuristic: logged session RPE replaces declared intensity.
  sportCalibration: (minLoggedSessions: 3, lookbackDays: 28),
  recomputeOnBodyweightKg:
      0.5, // heuristic: a weigh-in refreshes targets when the averaged weight moves this much
  // N-PRO-01/02
  protein: (
    base: 1.6,
    leanDeficit: 2.0,
    leanThresholdBf: {Sex.male: 19.0, Sex.female: 27.0, Sex.unspecified: 19.0},
  ),
  fatMin: (lightKg: 60.0, heavyKg: 90.0, low: 40.0, high: 60.0), // N-FAT-01
  fatShareOfMaintenance: 0.25, // N-FAT-01
  carbMin: (surplusOrMaint: 2.0, deficit: 1.0), // N-CHO-01
  kcalBand: 100,
  // N-ADJ
  adjust: (
    initialMultiplierStep: 0.2,
    under3000: [100, 200],
    over3000: [150, 200],
    defaultUnder: 150,
    defaultOver: 175,
    minDaysBetween: 14,
    maintainDriftPctPerWeek: 0.25,
    maintainStep: 125,
  ),
  weighIns: (minPerWeek: 3, needsWeekendDay: true, runningAvgDays: [14, 21]), // N-WGT
  gainToCutRatio: 4, // N-PHS-02
  safety: (minKcalVsBmr: 1.1, maxLossPctPerWeek: 1.0),
);

const REVIEW = (
  energyDreadThreshold: 2.0, // avg energy ≤ 2
  skippedDreadThreshold: 2,
  sleepDropHours: 0.5,
  sleepNoBaseline: 7.0,
  stressRise: 1.0,
  soreAboveAverage: 2.0,
  perfDropExercises: 2,
  e1rmDropPct: 0.03,
  proposalExpiryDays: 7,
  // Heuristic from T-FAT-08: readiness score at or below this suggests the lightest session.
  lowReadinessScore: 1.0,
);

const STATUS_INFERENCE = (minWeeks: 8, novice: 0.6, advanced: 0.15, consecutiveReviews: 2);

const Map<String, double> DEFAULT_INCREMENTS = {'barbell': 2.5, 'dumbbell': 2, 'machine': 5, 'cable': 2.5};
