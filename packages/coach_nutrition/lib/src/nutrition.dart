// SPDX-License-Identifier: GPL-3.0-only
// Nutrition engine. Rules: N-PHS-01, N-MNT-01…04, N-RAT-01…04, N-SPT-01…03, N-PRO-01/02, N-FAT-01, N-CHO-01, N-MAC-01.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

import 'js_number.dart';

NutritionPhase phaseForGoal(Goal goal) {
  if (goal == Goal.leanGain) return NutritionPhase.gain;
  if (goal == Goal.fatLoss) return NutritionPhase.loss;
  return NutritionPhase.maintain; // recomp, strength, sport_support (N-PHS-01)
}

double defaultMultiplier(Lifestyle l) => NUTRITION.multiplierDefault[l]!;

/// N-SPT-02: sport intensity → cardio factor (kcal per kg per 10 min).
double sportFactor(SportIntensity i) {
  final f = NUTRITION.cardioKcalPerKgPer10Min;
  if (i == SportIntensity.light) return f.light;
  if (i == SportIntensity.moderate) return f.moderate;
  if (i == SportIntensity.hard) return f.vigorous;
  return 0.5 * (f.moderate + f.vigorous);
}

/// N-SPT-01: session RPE (1–10) → cardio factor: ≤4 light, ≤7 moderate, else vigorous.
double _rpeFactor(num rpe) {
  final f = NUTRITION.cardioKcalPerKgPer10Min;
  return rpe <= 4
      ? f.light
      : rpe <= 7
      ? f.moderate
      : f.vigorous;
}

/// N-SPT-01: kcal for a single logged session from its session RPE (1–10).
int sessionKcalFromRpe(num minutes, num rpe, num kg) => jsRound((minutes / 10) * _rpeFactor(rpe) * kg);

/// The part of a user sport that sets its calories: `Pick<UserSport, 'weekdays' | 'minutes' | 'intensity'>`
/// with an optional sport id in the reference.
class SportForKcal {
  SportForKcal({required this.weekdays, required this.minutes, required this.intensity, this.sportId});

  factory SportForKcal.fromJson(Map<String, dynamic> json) => SportForKcal(
    weekdays: [for (final x in json['weekdays'] as List) x as int],
    minutes: json['minutes'] as int,
    intensity: SportIntensity.fromWire(json['intensity'] as String),
    sportId: json['sportId'] == null ? null : json['sportId'] as String,
  );

  /// The fields of a [UserSport] that [sportKcalPerDay] reads.
  factory SportForKcal.fromUserSport(UserSport s) =>
      SportForKcal(weekdays: s.weekdays, minutes: s.minutes, intensity: s.intensity, sportId: s.sportId);

  /// ISO 1..7
  final List<int> weekdays;
  final int minutes;
  final SportIntensity intensity;
  final String? sportId;

  Map<String, dynamic> toJson() => {
    'weekdays': [...weekdays],
    'minutes': minutes,
    'intensity': intensity.wire,
    'sportId': ?sportId,
  };
}

/// A logged sport session (sport_logs) as used for calorie calibration.
class SportLogForKcal {
  SportLogForKcal({required this.sportId, required this.minutes, required this.rpe});

  factory SportLogForKcal.fromJson(Map<String, dynamic> json) => SportLogForKcal(
    sportId: json['sportId'] as String,
    minutes: json['minutes'] as int,
    rpe: json['rpe'] == null ? null : (json['rpe'] as num).toDouble(),
  );

  final String sportId;
  final int minutes;
  final double? rpe;

  Map<String, dynamic> toJson() => {'sportId': sportId, 'minutes': minutes, 'rpe': rpe};
}

/// N-SPT-03: average daily sport energy. Frequency always comes from the weekly schedule; the energy of one
/// session comes from the declared minutes × intensity or, once a sport has at least
/// NUTRITION.sportCalibration.minLoggedSessions recent logs with a session RPE, from the mean of those logs (N-SPT-01).
int sportKcalPerDay(List<SportForKcal> sports, num kg, [List<SportLogForKcal> logs = const []]) {
  final weekly = sports.fold<double>(0, (a, s) {
    // An empty id counts as no id, like the reference's truthiness check.
    final id = s.sportId;
    final rated = id != null && id.isNotEmpty
        ? [
            for (final l in logs)
              if (l.sportId == id && l.rpe != null && l.minutes > 0) l,
          ]
        : const <SportLogForKcal>[];
    final perSession = rated.length >= NUTRITION.sportCalibration.minLoggedSessions
        ? rated.fold<double>(0, (b, l) => b + (l.minutes / 10) * _rpeFactor(l.rpe!) * kg) / rated.length
        : (s.minutes / 10) * sportFactor(s.intensity) * kg;
    return a + s.weekdays.length * perSession;
  });
  return jsRound(weekly / 7);
}

class NutritionInput {
  NutritionInput({
    required this.bodyweightKg,
    required this.sex,
    this.bodyFatPct,
    required this.status,
    required this.phase,
    required this.lifestyle,
    this.multiplier,
    required this.sports,
    this.sportLogs,
    this.targetRatePct,
    this.kcalOverride,
  });

  factory NutritionInput.fromJson(Map<String, dynamic> json) => NutritionInput(
    bodyweightKg: (json['bodyweightKg'] as num).toDouble(),
    sex: json['sex'] == null ? null : Sex.fromWire(json['sex'] as String),
    bodyFatPct: json['bodyFatPct'] == null ? null : (json['bodyFatPct'] as num).toDouble(),
    status: Status.fromWire(json['status'] as String),
    phase: NutritionPhase.fromWire(json['phase'] as String),
    lifestyle: Lifestyle.fromWire(json['lifestyle'] as String),
    multiplier: json['multiplier'] == null ? null : (json['multiplier'] as num).toDouble(),
    sports: [for (final s in json['sports'] as List) SportForKcal.fromJson(s as Map<String, dynamic>)],
    sportLogs: json['sportLogs'] == null
        ? null
        : [for (final l in json['sportLogs'] as List) SportLogForKcal.fromJson(l as Map<String, dynamic>)],
    targetRatePct: json['targetRatePct'] == null ? null : (json['targetRatePct'] as num).toDouble(),
    kcalOverride: json['kcalOverride'] == null ? null : json['kcalOverride'] as int,
  );

  final double bodyweightKg;
  final Sex? sex;
  final double? bodyFatPct;
  final Status status;
  final NutritionPhase phase;
  final Lifestyle lifestyle;
  final double? multiplier;
  final List<SportForKcal> sports;

  /// Recent sport_logs; sports with enough RPE-rated logs use them instead of the declared intensity.
  final List<SportLogForKcal>? sportLogs;

  /// loss: % bodyweight per week (positive); gain: % per month.
  final double? targetRatePct;

  /// After accepted calorie adjustments.
  final int? kcalOverride;

  Map<String, dynamic> toJson() => {
    'bodyweightKg': bodyweightKg,
    'sex': sex?.wire,
    'bodyFatPct': ?bodyFatPct,
    'status': status.wire,
    'phase': phase.wire,
    'lifestyle': lifestyle.wire,
    'multiplier': ?multiplier,
    'sports': [for (final s in sports) s.toJson()],
    'sportLogs': ?(sportLogs == null ? null : [for (final l in sportLogs!) l.toJson()]),
    'targetRatePct': ?targetRatePct,
    'kcalOverride': ?kcalOverride,
  };
}

/// One entry of `NutritionTargets.warnings` in the reference.
class NutritionWarning implements RuleTagged {
  NutritionWarning({required this.code, required this.message, required this.ruleIds});

  factory NutritionWarning.fromJson(Map<String, dynamic> json) => NutritionWarning(
    code: json['code'] as String,
    message: json['message'] as String,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final String code;
  final String message;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'ruleIds': [...ruleIds],
  };
}

/// The calorie and macro fields [applyKcalChange] reads: `Pick<NutritionTargets, 'kcal' | 'proteinG' | 'fatG' |
/// 'fatMinG' | 'carbsG' | 'carbsMinG'>` in the reference. [NutritionTargets] implements it.
class MacroTargets {
  MacroTargets({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.fatMinG,
    required this.carbsG,
    required this.carbsMinG,
  });

  factory MacroTargets.fromJson(Map<String, dynamic> json) => MacroTargets(
    kcal: json['kcal'] as int,
    proteinG: (json['proteinG'] as num).toDouble(),
    fatG: (json['fatG'] as num).toDouble(),
    fatMinG: (json['fatMinG'] as num).toDouble(),
    carbsG: (json['carbsG'] as num).toDouble(),
    carbsMinG: (json['carbsMinG'] as num).toDouble(),
  );

  final int kcal;
  final double proteinG;
  final double fatG;
  final double fatMinG;
  final double carbsG;
  final double carbsMinG;

  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'proteinG': proteinG,
    'fatG': fatG,
    'fatMinG': fatMinG,
    'carbsG': carbsG,
    'carbsMinG': carbsMinG,
  };
}

class NutritionTargets implements MacroTargets {
  NutritionTargets({
    required this.phase,
    required this.bmr,
    required this.multiplier,
    required this.maintenanceExSport,
    required this.sportKcalPerDay,
    required this.maintenance,
    required this.ratePct,
    required this.delta,
    required this.kcal,
    required this.kcalLow,
    required this.kcalHigh,
    required this.proteinG,
    required this.fatMinG,
    required this.fatG,
    required this.carbsMinG,
    required this.carbsG,
    required this.flexibleKcal,
    required this.warnings,
    required this.ruleIds,
  });

  factory NutritionTargets.fromJson(Map<String, dynamic> json) => NutritionTargets(
    phase: NutritionPhase.fromWire(json['phase'] as String),
    bmr: (json['bmr'] as num).toDouble(),
    multiplier: (json['multiplier'] as num).toDouble(),
    maintenanceExSport: json['maintenanceExSport'] as int,
    sportKcalPerDay: json['sportKcalPerDay'] as int,
    maintenance: json['maintenance'] as int,
    ratePct: (json['ratePct'] as num).toDouble(),
    delta: json['delta'] as int,
    kcal: json['kcal'] as int,
    kcalLow: json['kcalLow'] as int,
    kcalHigh: json['kcalHigh'] as int,
    proteinG: (json['proteinG'] as num).toDouble(),
    fatMinG: (json['fatMinG'] as num).toDouble(),
    fatG: (json['fatG'] as num).toDouble(),
    carbsMinG: (json['carbsMinG'] as num).toDouble(),
    carbsG: (json['carbsG'] as num).toDouble(),
    flexibleKcal: json['flexibleKcal'] as int,
    warnings: [
      for (final w in json['warnings'] as List) NutritionWarning.fromJson(w as Map<String, dynamic>),
    ],
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final NutritionPhase phase;
  final double bmr;
  final double multiplier;
  final int maintenanceExSport;
  final int sportKcalPerDay;
  final int maintenance;

  /// loss: %/week (positive); gain: %/month; maintain: 0.
  final double ratePct;
  final int delta;
  @override
  final int kcal;
  final int kcalLow;
  final int kcalHigh;
  @override
  final double proteinG;
  @override
  final double fatMinG;
  @override
  final double fatG;
  @override
  final double carbsMinG;
  @override
  final double carbsG;
  final int flexibleKcal;
  final List<NutritionWarning> warnings;
  final List<String> ruleIds;

  @override
  Map<String, dynamic> toJson() => {
    'phase': phase.wire,
    'bmr': bmr,
    'multiplier': multiplier,
    'maintenanceExSport': maintenanceExSport,
    'sportKcalPerDay': sportKcalPerDay,
    'maintenance': maintenance,
    'ratePct': ratePct,
    'delta': delta,
    'kcal': kcal,
    'kcalLow': kcalLow,
    'kcalHigh': kcalHigh,
    'proteinG': proteinG,
    'fatMinG': fatMinG,
    'fatG': fatG,
    'carbsMinG': carbsMinG,
    'carbsG': carbsG,
    'flexibleKcal': flexibleKcal,
    'warnings': [for (final w in warnings) w.toJson()],
    'ruleIds': [...ruleIds],
  };
}

double defaultRatePct(NutritionPhase phase, Status status, Sex? sex, [num? bf]) {
  if (phase == NutritionPhase.loss) {
    final lean = bf != null && bf <= NUTRITION.leanBodyFat[sex ?? Sex.unspecified]!;
    return lean ? NUTRITION.lossRatePctPerWeek.lean : NUTRITION.lossRatePctPerWeek.defaultPct;
  }
  if (phase == NutritionPhase.gain) return NUTRITION.gainDefault[status]!;
  return 0;
}

bool isAboveFatThreshold(Sex? sex, [num? bf]) {
  if (bf == null) return false;
  return bf > NUTRITION.protein.leanThresholdBf[sex ?? Sex.unspecified]!;
}

NutritionTargets nutritionTargets(NutritionInput input) {
  final kg = input.bodyweightKg;
  final ruleIds = [
    'N-MNT-01',
    'N-MNT-02',
    'N-MNT-04',
    'N-SPT-01',
    'N-SPT-02',
    'N-SPT-03',
    'N-PRO-01',
    'N-FAT-01',
    'N-CHO-01',
    'N-MAC-01',
  ];
  final warnings = <NutritionWarning>[];
  final multiplier = input.multiplier ?? defaultMultiplier(input.lifestyle);
  final bmr = NUTRITION.bmrPerKg * kg;
  final maintenanceExSport = jsRound(bmr * multiplier);
  final sportKcal = sportKcalPerDay(input.sports, kg, input.sportLogs ?? const []);
  final maintenance = maintenanceExSport + sportKcal;

  var ratePct = input.targetRatePct ?? defaultRatePct(input.phase, input.status, input.sex, input.bodyFatPct);
  var delta = 0.0;
  if (input.phase == NutritionPhase.loss) {
    ruleIds.addAll(['N-RAT-01', 'N-RAT-03']);
    if (ratePct > NUTRITION.safety.maxLossPctPerWeek) {
      warnings.add(
        NutritionWarning(
          code: 'RATE_TOO_FAST',
          message: 'Losing more than 1% of bodyweight per week is blocked; the rate was set to 1%.',
          ruleIds: ['N-RAT-01'],
        ),
      );
      ratePct = NUTRITION.safety.maxLossPctPerWeek;
    }
    delta = -kg * (ratePct / 100) * NUTRITION.kcalPerKgWeeklyChange;
    if (-delta > NUTRITION.bigDeficitWarn) {
      warnings.add(
        NutritionWarning(
          code: 'BIG_DEFICIT',
          message: 'A ${jsRound(-delta)} kcal/day deficit risks losing muscle. Consider a slower rate.',
          ruleIds: ['N-RAT-04'],
        ),
      );
    }
  } else if (input.phase == NutritionPhase.gain) {
    ruleIds.addAll(['N-RAT-02', 'N-RAT-03']);
    delta = ((kg * (ratePct / 100)) / 4) * NUTRITION.kcalPerKgWeeklyChange;
  }

  var kcal = input.kcalOverride ?? round10(maintenance + delta);
  final floor = (bmr * NUTRITION.safety.minKcalVsBmr).ceil();
  if (kcal < floor) {
    warnings.add(
      NutritionWarning(
        code: 'KCAL_TOO_LOW',
        message: 'Targets below ${round10(floor)} kcal (resting needs × 1.1) are blocked.',
        ruleIds: ['N-MNT-01'],
      ),
    );
    kcal = round10(floor + 5);
  }

  // Macros (N-MAC-01): protein → fat → carbs. Every gram value is a whole multiple of 5 here, so the
  // arithmetic stays in integers and the reference's results are exact.
  final leanDeficit = input.phase == NutritionPhase.loss && !isAboveFatThreshold(input.sex, input.bodyFatPct);
  if (leanDeficit) ruleIds.add('N-PRO-02');
  final proteinG = round5(kg * (leanDeficit ? NUTRITION.protein.leanDeficit : NUTRITION.protein.base));
  final fm = NUTRITION.fatMin;
  final fatMinG = round5(
    lerp(fm.low, fm.high, clampNum((kg - fm.lightKg) / (fm.heavyKg - fm.lightKg), 0, 1)),
  );
  var fatG = math.max(fatMinG, round5((NUTRITION.fatShareOfMaintenance * maintenanceExSport) / 9));
  final carbsMinG = round5(
    kg * (input.phase == NutritionPhase.loss ? NUTRITION.carbMin.deficit : NUTRITION.carbMin.surplusOrMaint),
  );
  var carbsG = round5((kcal - proteinG * 4 - fatG * 9) / 4);
  if (carbsG < carbsMinG) {
    fatG = math.max(fatMinG, fatG - (((carbsMinG - carbsG) * 4) / 9).ceil());
    carbsG = round5((kcal - proteinG * 4 - fatG * 9) / 4);
    if (carbsG < carbsMinG) {
      carbsG = carbsMinG;
      kcal = proteinG * 4 + fatG * 9 + carbsG * 4;
      warnings.add(
        NutritionWarning(
          code: 'TARGET_BELOW_MINIMUMS',
          message: 'Your calorie target is below the protein, fat and carb minimums. Try a slower rate.',
          ruleIds: ['N-MAC-01', 'N-CHO-01'],
        ),
      );
    }
  }
  final flexibleKcal = math.max(0, kcal - (proteinG * 4 + fatMinG * 9 + carbsMinG * 4));
  return NutritionTargets(
    phase: input.phase,
    bmr: bmr,
    multiplier: multiplier,
    maintenanceExSport: maintenanceExSport,
    sportKcalPerDay: sportKcal,
    maintenance: maintenance,
    ratePct: ratePct,
    delta: jsRound(delta),
    kcal: kcal,
    kcalLow: kcal - NUTRITION.kcalBand,
    kcalHigh: kcal + NUTRITION.kcalBand,
    proteinG: proteinG.toDouble(),
    fatMinG: fatMinG.toDouble(),
    fatG: fatG.toDouble(),
    carbsMinG: carbsMinG.toDouble(),
    carbsG: carbsG.toDouble(),
    flexibleKcal: flexibleKcal,
    warnings: warnings,
    ruleIds: ruleIds,
  );
}

/// The result of [applyKcalChange].
class MacroSplit {
  MacroSplit({required this.kcal, required this.proteinG, required this.fatG, required this.carbsG});

  factory MacroSplit.fromJson(Map<String, dynamic> json) => MacroSplit(
    kcal: json['kcal'] as int,
    proteinG: (json['proteinG'] as num).toDouble(),
    fatG: (json['fatG'] as num).toDouble(),
    carbsG: (json['carbsG'] as num).toDouble(),
  );

  final int kcal;
  final double proteinG;
  final double fatG;
  final double carbsG;

  Map<String, dynamic> toJson() => {'kcal': kcal, 'proteinG': proteinG, 'fatG': fatG, 'carbsG': carbsG};
}

/// N-ADJ-04: apply a calorie change keeping protein fixed and taking the change from fat and carbs
/// above their minimums (in proportion to how much each sits above its minimum).
MacroSplit applyKcalChange(MacroTargets t, int newKcal) {
  final change = newKcal - t.kcal;
  final fatAboveKcal = math.max(0.0, t.fatG - t.fatMinG) * 9;
  final carbAboveKcal = math.max(0.0, t.carbsG - t.carbsMinG) * 4;
  var fatG = t.fatG;
  if (change < 0) {
    final pool = fatAboveKcal + carbAboveKcal;
    final fatShare = pool > 0 ? fatAboveKcal / pool : 0;
    fatG = math.max(t.fatMinG, round5(t.fatG + (change * fatShare) / 9).toDouble());
  } else {
    // Increases go mostly to carbs; a quarter to fat.
    fatG = round5(t.fatG + (change * 0.25) / 9).toDouble();
  }
  var carbsG = round5((newKcal - t.proteinG * 4 - fatG * 9) / 4).toDouble();
  if (carbsG < t.carbsMinG) {
    carbsG = t.carbsMinG;
    fatG = math.max(t.fatMinG, ((newKcal - t.proteinG * 4 - carbsG * 4) / 9).floor().toDouble());
  }
  return MacroSplit(kcal: newKcal, proteinG: t.proteinG, fatG: fatG, carbsG: carbsG);
}

// ---------------------------------------------------------------------------
// Phase, rate and cadence helpers (shared by the server actions and the nutrition page)
// ---------------------------------------------------------------------------

/// Target rates the app offers and accepts. Loss: N-RAT-01 (0.5–1 %/week). Gain: N-RAT-02, the options inside the
/// status's monthly range (advanced, whose range starts at 0, gets 0.25 and 0.5).
List<double> allowedRatePcts(NutritionPhase phase, Status status) {
  if (phase == NutritionPhase.loss) return [...NUTRITION.lossRateOptions];
  if (phase == NutritionPhase.gain) {
    final [lo, hi] = NUTRITION.gainRatePctPerMonth[status]!;
    return [
      for (final x in NUTRITION.gainRateOptions)
        if (x >= lo && x <= hi) x,
    ];
  }
  return [];
}

/// Null when [ratePct] is allowed for the phase and status, otherwise a message naming the rule.
String? rateError(NutritionPhase phase, Status status, num? ratePct) {
  if (phase == NutritionPhase.maintain || ratePct == null) return null;
  if (phase == NutritionPhase.loss) {
    final min = NUTRITION.lossRatePctPerWeek.min;
    final max = NUTRITION.lossRatePctPerWeek.max;
    if (ratePct > max) return 'Losing more than 1% of bodyweight per week is blocked (N-RAT-01).';
    if (ratePct < min) {
      return 'Pick a loss rate between ${jsNumber(min)} and ${jsNumber(max)}% per week (N-RAT-01).';
    }
    return null;
  }
  final [lo, hi] = NUTRITION.gainRatePctPerMonth[status]!;
  final min = allowedRatePcts(NutritionPhase.gain, status).reduce(math.min);
  if (ratePct > hi || ratePct < min) {
    return 'For a ${status.wire} lifter the gain rate is ${jsNumber(lo)}–${jsNumber(hi)}% per month (N-RAT-02).';
  }
  return null;
}

class PhaseSpan {
  PhaseSpan({required this.phase, required this.from, required this.to});

  factory PhaseSpan.fromJson(Map<String, dynamic> json) => PhaseSpan(
    phase: json['phase'] as String,
    from: json['from'] as String,
    to: json['to'] == null ? null : json['to'] as String,
  );

  final String phase;
  final String from;
  final String? to;

  Map<String, dynamic> toJson() => {'phase': phase, 'from': from, 'to': to};
}

/// The result of [buildCutDays].
class BuildCutDays {
  BuildCutDays({required this.buildDays, required this.cutDays});

  factory BuildCutDays.fromJson(Map<String, dynamic> json) =>
      BuildCutDays(buildDays: json['buildDays'] as int, cutDays: json['cutDays'] as int);

  final int buildDays;
  final int cutDays;

  Map<String, dynamic> toJson() => {'buildDays': buildDays, 'cutDays': cutDays};
}

/// N-PHS-02: days spent building/maintaining vs cutting, from nutrition_settings.phase_history.
BuildCutDays buildCutDays(List<PhaseSpan> history, String today) {
  int days(PhaseSpan h) => math.max(0, daysBetween(h.from, h.to ?? today));
  final cutDays = history.where((h) => h.phase == 'loss').fold(0, (a, h) => a + days(h));
  final buildDays = history.where((h) => h.phase != 'loss').fold(0, (a, h) => a + days(h));
  return BuildCutDays(buildDays: buildDays, cutDays: cutDays);
}

/// N-PHS-02 is guidance, not a block: starting a cut early stays the user's call. Returns a warning when a new cut
/// (counted as at least one week) would leave less than 4× as much build/maintain time as total cut time.
String? cutRatioWarning(List<PhaseSpan> history, String today) {
  final BuildCutDays(:buildDays, :cutDays) = buildCutDays(history, today);
  final needed = NUTRITION.gainToCutRatio * (cutDays + 7);
  if (buildDays >= needed) return null;
  final weeks = ((needed - buildDays) / 7).ceil();
  return 'So far: ${jsRound(buildDays / 7)} weeks building or maintaining, ${jsRound(cutDays / 7)} cutting. '
      'The 4:1 guideline suggests about $weeks more weeks of building or maintaining before this cut (N-PHS-02).';
}

/// The cadence state [nextAdjustState] reads and returns.
class AdjustState {
  AdjustState({required this.lastAdjustedOn, required this.initialAdjustDone});

  factory AdjustState.fromJson(Map<String, dynamic> json) => AdjustState(
    lastAdjustedOn: json['lastAdjustedOn'] == null ? null : json['lastAdjustedOn'] as String,
    initialAdjustDone: json['initialAdjustDone'] as bool,
  );

  final String? lastAdjustedOn;
  final bool initialAdjustDone;

  Map<String, dynamic> toJson() => {'lastAdjustedOn': lastAdjustedOn, 'initialAdjustDone': initialAdjustDone};
}

/// What a recompute changed, as [nextAdjustState] reads it.
class AdjustChange {
  AdjustChange({required this.phaseChanged, this.kcalOffsetDelta, this.multiplierAdjust});

  factory AdjustChange.fromJson(Map<String, dynamic> json) => AdjustChange(
    phaseChanged: json['phaseChanged'] as bool,
    kcalOffsetDelta: json['kcalOffsetDelta'] == null ? null : json['kcalOffsetDelta'] as int,
    multiplierAdjust: json['multiplierAdjust'] == null ? null : json['multiplierAdjust'] as bool,
  );

  final bool phaseChanged;
  final int? kcalOffsetDelta;
  final bool? multiplierAdjust;

  Map<String, dynamic> toJson() => {
    'phaseChanged': phaseChanged,
    'kcalOffsetDelta': ?kcalOffsetDelta,
    'multiplierAdjust': ?multiplierAdjust,
  };
}

/// Cadence fields written by every recompute (N-ADJ-01, N-ADJ-03). Only trend adjustments (an accepted calorie or
/// activity-factor proposal) restart the 14-day wait, and only the factor proposal closes the first-week check.
/// Rebases (lifestyle change, new weigh-in, sports, manual recalculation) keep both, so they never use up the cadence.
AdjustState nextAdjustState(AdjustState? prev, AdjustChange change, String today) {
  // The reference tests truthiness: a kcal change of 0 is no change.
  final multiplierAdjust = change.multiplierAdjust ?? false;
  final adjusted = (change.kcalOffsetDelta ?? 0) != 0 || multiplierAdjust;
  return AdjustState(
    lastAdjustedOn: adjusted ? today : prev?.lastAdjustedOn,
    initialAdjustDone: change.phaseChanged
        ? false
        : multiplierAdjust
        ? true
        : (prev?.initialAdjustDone ?? false),
  );
}

/// Heuristic: a weigh-in refreshes the targets when the averaged bodyweight they use moved by at least
/// NUTRITION.recomputeOnBodyweightKg, or when the stored targets don't record one. Smaller moves change kcal by < ~20.
bool bodyweightChangedEnough(num? usedKg, num? currentKg) {
  if (currentKg == null) return false;
  if (usedKg == null) return true;
  return (currentKg - usedKg).abs() >= NUTRITION.recomputeOnBodyweightKg - 1e-9;
}
