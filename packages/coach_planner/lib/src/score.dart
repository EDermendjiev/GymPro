// SPDX-License-Identifier: GPL-3.0-only
// Whether a split can work for the user, and how well it fits them. Rules: T-PLN-03, T-PLN-04, T-PLN-06,
// T-PLN-07, T-SPL-01, T-SPL-02, T-FRQ-01, T-FRQ-02, T-FRQ-03, T-SCH-04.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';

import 'catalog.dart';
import 'estimate.dart';
import 'profile.dart';

/// The weights of the fit score. All heuristic; tune them here.
const SCORE = (
  styleMatch: 30.0,
  styleNear: 10.0,
  frequencyPerMuscle: 1.0,
  focusThrice: 6.0,
  focusTwice: 3.0,
  emptySession: 10.0, // per share of the session below 60% use
  unevenSessions: 8.0, // per session length of spread between the longest and the shortest day
  legsBackToBack: 4.0,
  legsNextToSport: 3.0,
  varietyPerTemplate: 1.0,
  sameEveryDay: 5.0,
  keepSplit: 12.0,
  missingSlots: 20.0, // per share of slots that cannot be filled
  noviceTemplatesOver3: 2.0,
  olderFullBody: 4.0,
  sportFullBody: 10.0,
  mainLiftTwice: 3.0,
  dedicatedStrength: 2.0,
);

/// Most of the template slots that may be unfillable before a split is ruled out.
const double MAX_MISSING_SHARE = 0.3;

/// Fractional lower-body sets that make a session a hard leg day (heuristic).
const double HARD_LEG_DAY_SETS = 6;

/// Fit for the user's status, by split family. Heuristic: simpler splits for novices, the less traditional ones,
/// which spread high volume best, for advanced lifters.
const Map<Status, Map<SplitFamily, double>> STATUS_FIT = {
  Status.novice: {SplitFamily.fullBody: 8, SplitFamily.upperLower: 6, SplitFamily.hybrid: 3},
  Status.intermediate: {
    SplitFamily.upperLower: 4,
    SplitFamily.hybrid: 4,
    SplitFamily.fullBody: 3,
    SplitFamily.pushPullLegs: 3,
    SplitFamily.fullPushPull: 3,
    SplitFamily.alternating: 2,
  },
  Status.advanced: {
    SplitFamily.fullPushPull: 6,
    SplitFamily.alternating: 6,
    SplitFamily.pushPullLegs: 4,
    SplitFamily.hybrid: 3,
    SplitFamily.bodyPart: 2,
    SplitFamily.upperLower: 2,
    SplitFamily.fullBody: 2,
  },
};

/// The families each style preference asks for, and those close to it.
const Map<StylePref, ({Set<SplitFamily> match, Set<SplitFamily> near})> STYLE_FAMILIES = {
  StylePref.fullBody: (match: {SplitFamily.fullBody}, near: {SplitFamily.fullPushPull}),
  StylePref.upperLower: (match: {SplitFamily.upperLower}, near: {SplitFamily.hybrid}),
  StylePref.pushPullLegs: (match: {SplitFamily.pushPullLegs}, near: {SplitFamily.hybrid}),
  StylePref.bodyPart: (match: {SplitFamily.bodyPart}, near: {SplitFamily.alternating}),
};

/// Why a split was ruled out.
enum Failure {
  status('status'),
  goal('goal'),
  mainLifts('main_lifts'),
  equipment('equipment'),
  unmet('unmet'),
  frequency('frequency'),
  sessionVolume('session_volume'),
  time('time');

  const Failure(this.wire);

  final String wire;
}

/// One scored split.
class Candidate {
  Candidate({
    required this.split,
    required this.estimate,
    required this.failures,
    required this.terms,
    required this.targets,
  });

  final PlannerSplit split;
  final WeekEstimate estimate;
  final Set<Failure> failures;

  /// The parts of the score, by name.
  final Map<String, double> terms;

  /// The weekly targets the split was scored for.
  final Map<TrackedMuscle, double> targets;

  bool get feasible => failures.isEmpty;

  double get score => terms.values.fold(0.0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
    'split': split.key,
    'feasible': feasible,
    'failures': [
      for (final f in Failure.values)
        if (failures.contains(f)) f.wire,
    ],
    'score': score,
    'terms': {...terms},
  };
}

/// The weekdays a split's sessions fall on: the picked [days] when the split uses them all, else as evenly spread
/// over them as the count allows.
List<int> placeDays(List<int> days, int count) {
  if (count >= days.length) return days.take(count).toList();
  return [for (var i = 0; i < count; i++) days[(i * days.length / count).floor()]];
}

bool _isHardLegDay(EstSession s) {
  final m = s.muscleSets;
  return LOWER_MUSCLES.fold(0.0, (a, x) => a + (m[x] ?? 0)) >= HARD_LEG_DAY_SETS;
}

/// Scores [split] for [p] at weekly [targets].
///
/// Ruled out (T-PLN-03) when the split is for a higher status, doesn't fit the goal (main lifts for strength),
/// trains a selected main lift less than 1.5 times a week, needs too many slots the equipment can't fill, leaves a
/// target unmet, trains a muscle less often than its volume needs, puts more than about 11 sets of one muscle in a
/// session, or doesn't fit the session length (average within it, no day more than 15% over).
Candidate scoreSplit(
  PlannerSplit split,
  PlannerProfile p,
  Status status,
  Map<TrackedMuscle, double> targets,
) {
  final strength = p.goal == Goal.strength;
  final lifts = p.strengthLifts ?? const [MainLift.squat, MainLift.bench, MainLift.deadlift];
  final est = estimateWeek(split, targets, strength: strength, lifts: lifts, availableTags: p.availableTags);
  final failures = <Failure>{};
  final terms = <String, double>{};

  if (status.index < split.minStatus.index) failures.add(Failure.status);
  if (strength ? !split.hasMainLifts : split.strengthOnly) failures.add(Failure.goal);
  final liftFreq = mainLiftFrequency(split);
  if (strength && split.days >= 2 && lifts.any((l) => liftFreq[l]! < 1.5)) failures.add(Failure.mainLifts);
  if (est.missingShare > MAX_MISSING_SHARE) failures.add(Failure.equipment);
  if (est.unmet.isNotEmpty) failures.add(Failure.unmet);
  final freq = est.frequency;
  if (split.days > 1 && TRACKED_MUSCLES.any((m) => freq[m]! < frequencyFor(targets[m]!).least)) {
    failures.add(Failure.frequency);
  }
  if (est.maxSessionMuscleSets > FREQUENCY.maxSetsPerMusclePerSession) failures.add(Failure.sessionVolume);
  if (est.avgMinutes > p.minutes || est.maxMinutes > p.minutes * SESSION_OVERRUN_TOLERANCE) {
    failures.add(Failure.time);
  }

  // Style.
  final style = STYLE_FAMILIES[p.style];
  if (style != null) {
    if (style.match.contains(split.family)) {
      terms['style'] = SCORE.styleMatch;
    } else if (style.near.contains(split.family)) {
      terms['style'] = SCORE.styleNear;
    }
  }

  // Status.
  terms['status'] = STATUS_FIT[status]![split.family] ?? 0;
  final distinct = split.templates.toSet().length;
  if (status == Status.novice && distinct > 3) {
    terms['status'] = terms['status']! - SCORE.noviceTemplatesOver3 * (distinct - 3);
  }

  // Frequency: muscles trained as often as their volume prefers.
  terms['frequency'] =
      SCORE.frequencyPerMuscle *
      TRACKED_MUSCLES.where((m) => freq[m]! >= frequencyFor(targets[m]!).preferred).length;

  // Focus muscles: more often is better.
  var focus = 0.0;
  for (final m in p.focus) {
    if (freq[m]! >= 3) {
      focus += SCORE.focusThrice;
    } else if (freq[m]! >= 2) {
      focus += SCORE.focusTwice;
    }
  }
  if (focus > 0) terms['focus'] = focus;

  // Session length: no half-empty days, no very uneven ones.
  final use = est.avgMinutes / p.minutes;
  terms['time'] =
      -SCORE.emptySession * (use < 0.6 ? 0.6 - use : 0) -
      SCORE.unevenSessions * (est.maxMinutes - est.minMinutes) / p.minutes;

  // Recovery between hard leg days, and around hard sport days (T-SPL-02, T-SCH-04).
  final placed = placeDays(p.days, split.days);
  final hardLegs = {
    for (final (i, s) in est.sessions.indexed)
      if (_isHardLegDay(s)) placed[i],
  };
  final older = (p.age ?? 0) >= 50;
  var legs = 0.0;
  for (final d in hardLegs) {
    if (hardLegs.contains(d % 7 + 1)) legs -= SCORE.legsBackToBack * (older ? 2 : 1);
  }
  final sportDays = {
    for (final s in p.sports)
      if (isHardIntensity(s.intensity) && s.lowerBodyLoad >= 2) ...s.weekdays,
  };
  for (final d in hardLegs) {
    if (sportDays.contains(d) || sportDays.contains(d % 7 + 1) || sportDays.contains((d + 5) % 7 + 1)) {
      legs -= SCORE.legsNextToSport;
    }
  }
  if (legs != 0) terms['legs'] = legs;

  // Variety.
  terms['variety'] = SCORE.varietyPerTemplate * (distinct > 4 ? 4 : distinct);
  if (distinct == 1 && split.days >= 3) terms['variety'] = terms['variety']! - SCORE.sameEveryDay;

  if (p.previousSplitKey == split.key) terms['keep'] = SCORE.keepSplit;
  if (est.missingShare > 0) terms['equipment'] = -SCORE.missingSlots * est.missingShare;
  if ((p.age ?? 0) >= 65 && split.family == SplitFamily.fullBody) terms['older'] = SCORE.olderFullBody;
  if (p.sportPriority && split.family == SplitFamily.fullBody) terms['sport'] = SCORE.sportFullBody;
  if (strength) {
    terms['mainLifts'] =
        SCORE.mainLiftTwice * lifts.where((l) => liftFreq[l]! >= 2).length +
        (split.strengthOnly ? SCORE.dedicatedStrength : 0);
  }

  return Candidate(split: split, estimate: est, failures: failures, terms: terms, targets: targets);
}
