// SPDX-License-Identifier: GPL-3.0-only
// Goal extras for fat loss and recomposition: the daily step target (N-ACT-01) and the days for optional
// low-impact cardio (N-ACT-02).
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';

import 'constants.dart';

/// Whether [goal] gets the step target and the cardio days.
bool hasGoalExtras(Goal goal) => goal == Goal.fatLoss || goal == Goal.recomp;

/// A daily step target.
class StepTarget {
  StepTarget({required this.steps, required this.baseline, required this.capped});

  /// Steps a day to aim for.
  final int steps;

  /// The user's usual daily steps, or null when too few days were logged.
  final int? baseline;

  /// Whether the target was held at half again the usual count rather than the full goal.
  final bool capped;

  Map<String, dynamic> toJson() => {'steps': steps, 'baseline': baseline, 'capped': capped};
}

/// The daily step target for [goal] (N-ACT-01), or null for a goal without one. [baseline] is the user's usual daily
/// count. Fat loss aims for about 2,500 more than usual (about 100 kcal), recomposition for the usual count; both at
/// least 7,000 a day, and never more than half again the usual count at once.
StepTarget? dailyStepTarget(Goal goal, {double? baseline}) {
  if (!hasGoalExtras(goal)) return null;
  final round = STEPS.roundTo;
  int rounded(double x) => (jsRound(x / round) * round).toInt();
  if (baseline == null || baseline <= 0) {
    return StepTarget(steps: STEPS.minimum, baseline: null, capped: false);
  }
  final want = math.max<double>(STEPS.minimum.toDouble(), goal == Goal.fatLoss ? baseline + STEPS.per100Kcal : baseline);
  final cap = baseline * (1 + STEPS.maxRaise);
  final capped = want > cap;
  final target = math.max(rounded(capped ? cap : want), rounded(baseline));
  return StepTarget(steps: target, baseline: jsRound(baseline).toInt(), capped: capped);
}

/// The weekdays (1 = Monday … 7 = Sunday) for [sessions] low-impact cardio sessions a week (N-ACT-02), sorted.
///
/// [lifting] gives the region of each lifting day. Cardio goes only on days without lifting and without a hard
/// sport session, never the day before a lower-body day (or a hard leg-loading sport day), and preferably not the
/// day before a full-body day. One day of the week stays fully free. The days are spread over the week.
List<int> placeCardio(int sessions, {required Map<int, Region> lifting, List<UserSport> sports = const []}) {
  final n = sessions.clamp(0, CARDIO.maxSessions);
  if (n == 0) return const [];
  final hardSport = {
    for (final s in sports)
      if (isHardIntensity(s.intensity)) ...s.weekdays,
  };
  final legSport = {
    for (final s in sports)
      if (isHardIntensity(s.intensity) && s.lowerBodyLoad >= 2) ...s.weekdays,
  };
  final free = [
    for (var d = 1; d <= 7; d++)
      if (!lifting.containsKey(d) && !hardSport.contains(d)) d,
  ];
  // 0: fine, 1: before a full-body day, 2: before a leg day (not used).
  int tier(int d) {
    final next = d % 7 + 1;
    if (lifting[next] == Region.lower || legSport.contains(next)) return 2;
    return lifting[next] == Region.full ? 1 : 0;
  }

  final pool = [
    for (final d in free)
      if (tier(d) < 2) d,
  ];
  final count = math.min(n, math.min(pool.length, free.length - 1));
  final chosen = <int>[];
  int gap(int d) {
    var best = 7;
    for (final c in chosen) {
      final diff = (d - c).abs();
      best = math.min(best, math.min(diff, 7 - diff));
    }
    return best;
  }

  while (chosen.length < count) {
    int? pick;
    for (final d in pool) {
      if (chosen.contains(d)) continue;
      if (pick == null) {
        pick = d;
        continue;
      }
      final byTier = tier(d).compareTo(tier(pick));
      if (byTier < 0 || (byTier == 0 && gap(d) > gap(pick))) pick = d;
    }
    chosen.add(pick!);
  }
  return chosen..sort();
}
