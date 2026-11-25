// SPDX-License-Identifier: GPL-3.0-only
// Weekly volume per muscle from the time the user has, their status, goal, age and focus. Rules: T-PLN-02,
// T-PLN-04, T-PLN-06, T-VOL-01…03, T-VOL-08, T-PRI-01, S-02, S-05, T-STR-02.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';

import 'constants.dart';
import 'profile.dart';

/// Hours of lifting a week: [liftDays] sessions of [minutes].
double weeklyHours(int liftDays, int minutes) => liftDays * minutes / 60;

/// The volume tier for [hours] of lifting a week.
VolumeTier volumeTier(double hours) => VOLUME_TIERS.firstWhere((t) => hours <= t.maxHours);

/// The result of [weeklyBudget].
class Budget implements RuleTagged {
  Budget({
    required this.hours,
    required this.tier,
    required this.base,
    required this.targets,
    required this.notes,
    required this.ruleIds,
  });

  final double hours;
  final VolumeTier tier;

  /// Sets per muscle per week before per-muscle changes.
  final double base;
  final Map<TrackedMuscle, double> targets;
  final List<String> notes;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'hours': hours,
    'tier': tier.name,
    'base': base,
    'targets': {for (final m in TRACKED_MUSCLES) m.wire: targets[m]},
    'notes': [...notes],
    'ruleIds': [...ruleIds],
  };
}

String _h(double hours) => jsNumber(jsRound(hours * 10) / 10);

/// Weekly sets per tracked muscle for [p] training [liftDays] days a week.
///
/// The base comes from the weekly time (T-PLN-02), placed in the tier by status and capped by it. A previous
/// block's median carries on instead, still within what the time and status allow. Age, the goal and the
/// sports then lower it; focus muscles, sport trims, accepted adjustments and the usual floor and caps apply
/// per muscle, as in the block generator.
Budget weeklyBudget(PlannerProfile p, int liftDays) {
  final status = p.status.status;
  final hours = weeklyHours(liftDays, p.minutes);
  final tier = volumeTier(hours);
  final cap = math.min(STATUS_CAP[status]!, tier.maxSets);
  final ruleIds = <String>['T-PLN-02', 'T-VOL-01', 'T-VOL-02'];
  final notes = <String>[];

  double base;
  final prev = p.previousMedianTarget;
  if (prev != null) {
    base = math.min(prev, cap);
    notes.add('Starts from your previous block: ${jsNumber(base)} sets per muscle a week.');
    final checks = p.recoveryChecks;
    final recent = checks.sublist(math.max(0, checks.length - FATIGUE_CARRY.weeks));
    final flagged = recent.where((yes) => yes >= DELOAD.yesThreshold).length;
    if (flagged >= FATIGUE_CARRY.flaggedWeeks) {
      base = math.max(VOLUME.minEffective, base - FATIGUE_CARRY.cut);
      ruleIds.add('T-PLN-09');
      notes.add(
        'Your weekly recovery check showed fatigue in $flagged of the last ${recent.length} weeks, so this block '
        'starts lower: ${jsNumber(base)} sets per muscle a week.',
      );
    }
  } else {
    base = math.min(
      cap,
      jsRound(tier.minSets + (tier.maxSets - tier.minSets) * TIER_POSITION[status]!).toDouble(),
    );
    notes.add(
      'About ${_h(hours)} h of lifting a week supports ${jsNumber(tier.minSets)}–${jsNumber(tier.maxSets)} '
      'sets per muscle; as ${status == Status.novice ? 'a' : 'an'} ${status.wire} lifter you start at '
      '${jsNumber(base)}.',
    );
  }

  final age = p.age;
  if (age != null && age >= AGE_VOLUME.olderFrom) {
    final cut = age >= AGE_VOLUME.oldFrom ? AGE_VOLUME.oldCut : AGE_VOLUME.olderCut;
    base = math.max(VOLUME.minEffective, base - cut);
    ruleIds.add('T-PLN-06');
    notes.add(
      'A little less to start with at $age: ${jsNumber(base)} sets. More is added once you recover well.',
    );
  }

  final hard = hardSportSessionsPerWeek(p.sports);
  if (p.sportPriority) {
    base = math.min(base, VOLUME.sportPriorityBase);
    ruleIds.add('T-PRI-01');
    notes.add('Your sport comes first, so lifting volume stays minimal.');
  } else if (p.priority == Priority.balanced && hard >= VOLUME.balancedSportThreshold) {
    base = math.max(VOLUME.minEffective, base - VOLUME.balancedSportPenalty);
    ruleIds.addAll(['T-PRI-01', 'S-01']);
    notes.add(
      '$hard hard sport sessions a week: ${jsNumber(VOLUME.balancedSportPenalty)} sets fewer per muscle.',
    );
  }
  if (p.goal == Goal.fatLoss && base > VOLUME.fatLossCap) {
    base = VOLUME.fatLossCap;
    notes.add(
      'Capped at ${jsNumber(VOLUME.fatLossCap)} sets while dieting, since recovery is worse in a deficit.',
    );
  }
  if (p.goal == Goal.strength) {
    base = clampNum(base, STRENGTH.volume.secondarySets[0], STRENGTH.volume.secondarySets[1]);
    ruleIds.add('T-STR-02');
  }

  final focus = status == Status.novice ? const <TrackedMuscle>[] : p.focus;
  final specialised = status == Status.advanced && focus.isNotEmpty;
  if (focus.isNotEmpty) {
    ruleIds.add(specialised ? 'T-VOL-08' : 'T-PLN-04');
    notes.add(
      specialised
          ? 'Specialisation: ${focus.map((m) => m.wire).join(' and ')} get about half as many sets again, the rest '
                'run lower for now.'
          : '${focus.map((m) => m.wire).join(' and ')} get ${jsNumber(FOCUS_EXTRA_INTERMEDIATE)} extra sets a week.',
    );
  } else if (p.focus.isNotEmpty) {
    ruleIds.add('T-PLN-04');
    notes.add(
      'As a novice everything grows: your focus muscles come first in the session instead of getting more sets.',
    );
  }

  final trims = sportTrims(p.sports);
  final floor = VOLUME.minEffective;
  final targets = <TrackedMuscle, double>{};
  for (final m in TRACKED_MUSCLES) {
    final trim = trims.total[m]!;
    final isFocus = focus.contains(m);
    double t;
    if (m == MuscleId.frontDelts && !isFocus) {
      // Presses train the front delts already, so their own target is half the base.
      t = math.max(floor, jsRound(base * VOLUME.frontDeltFactor) - trim);
    } else if (specialised) {
      t = jsRound(base * (isFocus ? VOLUME.specialization.up : VOLUME.specialization.others)) - trim;
    } else {
      t = base - trim + (isFocus ? FOCUS_EXTRA_INTERMEDIATE : 0);
    }
    if (trim > 0 && !ruleIds.contains('S-02')) ruleIds.add('S-02');
    t += p.targetAdjustments?[m] ?? 0;
    if (p.sportPriority && LOWER_MUSCLES.contains(m)) {
      t = math.min(t, VOLUME.sportPriorityLowerCap);
      if (!ruleIds.contains('S-05')) ruleIds.add('S-05');
    }
    targets[m] = clampNum(t, floor, specialised && isFocus ? VOLUME.ceiling : VOLUME.normalCap).toDouble();
  }
  return Budget(hours: hours, tier: tier, base: base, targets: targets, notes: notes, ruleIds: ruleIds);
}
