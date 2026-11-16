// SPDX-License-Identifier: GPL-3.0-only
// Weekly volume targets per muscle. Rules: T-VOL-01…08, T-PRI-01, S-02, S-05, T-STR-02…04.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

import 'sports.dart';

/// The result of [baseVolume].
class BaseVolume implements RuleTagged {
  BaseVolume({required this.base, required this.ruleIds, required this.notes});

  factory BaseVolume.fromJson(Map<String, dynamic> json) => BaseVolume(
    base: (json['base'] as num).toDouble(),
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
    notes: [for (final x in json['notes'] as List) x as String],
  );

  final double base;
  @override
  final List<String> ruleIds;
  final List<String> notes;

  Map<String, dynamic> toJson() => {
    'base': base,
    'ruleIds': [...ruleIds],
    'notes': [...notes],
  };
}

/// The result of [computeTargets].
class TargetResult implements RuleTagged {
  TargetResult({required this.base, required this.targets, required this.ruleIds, required this.notes});

  factory TargetResult.fromJson(Map<String, dynamic> json) => TargetResult(
    base: (json['base'] as num).toDouble(),
    targets: [for (final x in json['targets'] as List) MuscleTarget.fromJson(x as Map<String, dynamic>)],
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
    notes: [for (final x in json['notes'] as List) x as String],
  );

  final double base;
  final List<MuscleTarget> targets;
  @override
  final List<String> ruleIds;
  final List<String> notes;

  Map<String, dynamic> toJson() => {
    'base': base,
    'targets': [for (final t in targets) t.toJson()],
    'ruleIds': [...ruleIds],
    'notes': [...notes],
  };
}

/// The reference takes `Pick<BlockInput, 'status' | 'goal' | 'priority' | 'sports' | 'history'>`.
BaseVolume baseVolume(BlockInput input, BlockKind kind) {
  final ruleIds = ['T-VOL-01', 'T-VOL-02', 'T-VOL-07'];
  final notes = <String>[];
  final prev = input.history.previousBlock;
  var base = prev?.medianTargetBeforeTrims ?? VOLUME.baseByStatus[input.status]!;
  if (prev != null) {
    notes.add("Starts from your previous block's ${jsNumber(base)} sets per muscle.");
  } else {
    final article = input.status == Status.intermediate || input.status == Status.advanced ? 'an' : 'a';
    notes.add('Starting volume for $article ${input.status.wire} lifter: ${jsNumber(base)} sets per muscle per week.');
  }

  final hard = hardSportSessionsPerWeek(input.sports);
  if (input.goal == Goal.sportSupport || input.priority == Priority.sport) {
    base = math.min(base, VOLUME.sportPriorityBase);
    ruleIds.add('T-PRI-01');
    notes.add('Your sport comes first, so lifting volume stays minimal.');
  } else if (input.priority == Priority.balanced && hard >= VOLUME.balancedSportThreshold) {
    base -= VOLUME.balancedSportPenalty;
    ruleIds.addAll(['T-PRI-01', 'S-01']);
    notes.add('$hard hard sport sessions a week: base volume −${jsNumber(VOLUME.balancedSportPenalty)}.');
  }
  if (input.goal == Goal.fatLoss && base > VOLUME.fatLossCap) {
    base = VOLUME.fatLossCap;
    notes.add('Capped at 14 sets while dieting, since recovery is worse in a deficit.');
  }
  if (input.goal == Goal.strength) {
    ruleIds.add('T-STR-02');
    if (kind == BlockKind.strengthLoad) {
      base = STRENGTH.secondaryTargetLoad + 2;
    } else if (kind == BlockKind.strengthPeak) {
      base = STRENGTH.secondaryTargetPeak;
    } else {
      base = clampNum(base, STRENGTH.volume.secondarySets[0], STRENGTH.volume.secondarySets[1]);
    }
  }
  return BaseVolume(base: base, ruleIds: ruleIds, notes: notes);
}

TargetResult computeTargets(BlockInput input, BlockKind kind) {
  final BaseVolume(:base, :ruleIds, :notes) = baseVolume(input, kind);
  final trims = sportTrims(input.sports);
  final spec = input.status == Status.advanced ? input.specialization.take(2).toList() : <TrackedMuscle>[];
  final specActive = spec.isNotEmpty;
  if (specActive) ruleIds.add('T-VOL-08');
  final sportPriority = input.goal == Goal.sportSupport || input.priority == Priority.sport;
  final floor = kind == BlockKind.strengthPeak ? 2.0 : VOLUME.minEffective;

  final targets = [
    for (final m in TRACKED_MUSCLES) _target(m, input, base, trims, spec, specActive, sportPriority, floor),
  ];

  return TargetResult(base: base, targets: targets, ruleIds: ruleIds, notes: notes);
}

MuscleTarget _target(
  TrackedMuscle m,
  BlockInput input,
  double base,
  SportTrim trims,
  List<TrackedMuscle> spec,
  bool specActive,
  bool sportPriority,
  double floor,
) {
  final mRules = ['T-VOL-01', 'T-VOL-02'];
  final trim = trims.total[m]!;
  double t;
  if (m == MuscleId.frontDelts) {
    t = math.max(VOLUME.minEffective, jsRound(base * VOLUME.frontDeltFactor) - trim);
    if (spec.contains(m)) t = jsRound(base * VOLUME.specialization.up).toDouble();
  } else if (specActive) {
    t = (spec.contains(m)
            ? jsRound(base * VOLUME.specialization.up)
            : jsRound(base * VOLUME.specialization.others))
        .toDouble();
    t -= trim;
    mRules.add('T-VOL-08');
  } else {
    t = base - trim;
  }
  if (trim > 0) mRules.add('S-02');
  final adj = input.targetAdjustments?[m] ?? 0;
  t += adj;
  if (sportPriority && LOWER_MUSCLES.contains(m)) {
    t = math.min(t, VOLUME.sportPriorityLowerCap);
    mRules.add('S-05');
  }
  final cap = spec.contains(m) ? VOLUME.ceiling : VOLUME.normalCap;
  t = clampNum(t, floor, cap);
  return MuscleTarget(
    muscle: m,
    base: base,
    sportTrim: trim,
    target: t,
    trimBySport: trims.bySport[m]!,
    ruleIds: mRules,
  );
}

/// Strength Load phase: supporting volume is cut by about one set per week (T-STR-03).
double weeklyTargetFor(BlockKind kind, num target, int weekIndex) {
  if (kind == BlockKind.strengthLoad) return math.max(STRENGTH.load.secondarySets[0], target - weekIndex).toDouble();
  return target.toDouble();
}

Map<TrackedMuscle, double> targetsMap(List<MuscleTarget> targets) => {for (final t in targets) t.muscle: t.target};
