// SPDX-License-Identifier: GPL-3.0-only
// The planner's numbers. Each one is marked as evidence-based (with its rule ID) or as a product heuristic.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';

/// One volume tier: sets per muscle per week that a weekly lifting time supports.
typedef VolumeTier = ({String name, double maxHours, double minSets, double maxSets});

/// T-PLN-02. The upper hour bounds sit halfway between the tiers' time ranges.
const List<VolumeTier> VOLUME_TIERS = [
  (name: 'minimal', maxHours: 2.75, minSets: 4, maxSets: 8),
  (name: 'low', maxHours: 4.75, minSets: 9, maxSets: 12),
  (name: 'medium', maxHours: 6.75, minSets: 13, maxSets: 16),
  (name: 'high', maxHours: double.infinity, minSets: 17, maxSets: 20),
];

/// Where in its tier each status starts (0 = bottom, 1 = top). Heuristic.
const Map<Status, double> TIER_POSITION = {
  Status.novice: 0.25,
  Status.intermediate: 0.5,
  Status.advanced: 1.0,
};

/// Highest starting volume per status, whatever the time allows. Heuristic within T-VOL-02 and T-VOL-07.
const Map<Status, double> STATUS_CAP = {Status.novice: 12, Status.intermediate: 16, Status.advanced: 20};

/// T-PLN-06 (heuristic): starting volume removed with age.
const AGE_VOLUME = (olderFrom: 50, olderCut: 2.0, oldFrom: 65, oldCut: 3.0);

/// T-PLN-04: extra weekly sets for an intermediate's focus muscle (heuristic within the practical range).
const double FOCUS_EXTRA_INTERMEDIATE = 3;

/// Most lifting days a plan uses; a seventh day is always a rest day (T-SCH-02).
const int MAX_LIFT_DAYS = 6;

/// T-PLN-09 (heuristic): fatigue flagged by the weekly check in [flaggedWeeks] of the last [weeks] weeks starts the
/// next block [cut] sets per muscle lower.
const FATIGUE_CARRY = (weeks: 4, flaggedWeeks: 2, cut: 2.0);

/// N-ACT-01: the daily step minimum, the extra steps for about 100 kcal, the largest raise over the user's usual
/// count, the rounding of a target and the logged days a usual count needs.
const STEPS = (minimum: 7000, per100Kcal: 2500, maxRaise: 0.5, roundTo: 500, baselineDays: 7);

/// N-ACT-02: most cardio sessions a week, and the minutes of one (heuristic).
const CARDIO = (maxSessions: 3, minutes: 30);
