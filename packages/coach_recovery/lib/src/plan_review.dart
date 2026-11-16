// SPDX-License-Identifier: GPL-3.0-only
// Weekly review → plan proposals: the kinds that change the plan itself rather than one week.
// Rules: T-SEL-08 / T-SEL-04 (injury_adjust, exercise_swap), T-FAT-02/03 + T-VOL-07 (volume_change),
// T-SCH-01 / T-SEL-04 (plan_regenerate), T-FAT-06 (intro_week). Pure: plain objects in, proposals out.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';

import 'fatigue.dart';

/// Planned sessions still ahead of `today` in the reviewed week and the one after it.
List<PlannedSessionState> _upcomingSessions(WeeklyState state) => [
  for (final s in [...state.sessionsThisWeek, ...state.nextWeekSessions])
    if (s.status == SessionStateStatus.planned && s.date.compareTo(state.today) >= 0) s,
];

List<ExerciseDef> _plannedExercises(WeeklyState state) {
  final exMap = {for (final e in state.exercises) e.id: e};
  final ids = {
    for (final s in _upcomingSessions(state))
      for (final e in s.exercises) e.exerciseId,
  };
  return [for (final id in ids) ?exMap[id]];
}

String _names(List<ExerciseDef> xs) => xs.map((e) => e.name).join(', ');

List<String> _sortedIds(List<ExerciseDef> xs) => stableSorted([for (final e in xs) e.id], (a, b) => a.compareTo(b));

/// injury_adjust (T-SEL-08):
/// - a logged injury whose avoid list (or, for pain/injury severity, axial or impact work on the area) is still in the plan;
/// - pain tagged on the same area on ≥ 2 days in the last two reviewed weeks while the plan still loads it heavily.
///   With no injury logged for the area, accepting logs one; a logged niggle is raised to "pain".
/// Resolved injuries get no proposal: the plan already regenerates when an injury is resolved, and previously avoided
/// exercises come back at the next block, when T-SEL-06 allows exercise changes.
List<Proposal> injuryProposals(WeeklyState state) {
  final out = <Proposal>[];
  final expires = addDays(state.today, REVIEW.proposalExpiryDays);
  final planned = _plannedExercises(state);
  final active = [
    for (final i in state.injuries ?? const <Injury>[])
      if (i.status != InjuryStatus.resolved) i,
  ];
  final painful = painfulMuscles(active).toSet();

  for (final inj in active) {
    final conflicts = [
      for (final ex in planned)
        if (inj.avoidExerciseIds.contains(ex.id) ||
            (inj.muscleId != null &&
                painful.contains(inj.muscleId) &&
                isPrimary(ex, inj.muscleId!) &&
                (ex.axialLoad || ex.impactLowerBody)))
          ex,
    ];
    if (conflicts.isEmpty) continue;
    out.add(
      Proposal(
        kind: ProposalKind.injuryAdjust,
        title: 'Update your plan for ${inj.label}',
        rationale:
            'Your plan still includes ${_names(conflicts)}, which your ${inj.label} injury rules out. Rebuilding the plan from today swaps them for exercises that leave the area alone.',
        ruleIds: ['T-SEL-08', 'T-SEL-04'],
        payload: {'injuryId': inj.id, 'removeExerciseIds': _sortedIds(conflicts), 'addExerciseIds': <String>[]},
        expiresOn: expires,
      ),
    );
  }

  // Recurring pain from check-ins.
  final weekEnd = addDays(state.weekStart, 7);
  final from = addDays(weekEnd, -REVIEW_PLAN.painLookbackDays);
  final painDays = <MuscleId, int>{};
  for (final c in state.checkins) {
    if (c.day.compareTo(from) < 0 || c.day.compareTo(weekEnd) >= 0) continue;
    for (final MapEntry(key: m, value: lvl) in c.soreness.entries) {
      if (lvl == SorenessLevel.pain) painDays[m] = (painDays[m] ?? 0) + 1;
    }
  }
  for (final MapEntry(key: m, value: days)
      in stableSorted(painDays.entries, (a, b) => a.key.wire.compareTo(b.key.wire))) {
    if (days < REVIEW_PLAN.painDaysForInjury) continue;
    final logged = active.where((i) => i.muscleId == m).firstOrNull;
    // A pain/injury entry already restricts the area; the first loop catches a stale plan.
    if (logged != null && logged.severity != InjurySeverity.niggle) continue;
    final loading = [
      for (final ex in planned)
        if (exercisesLoadingArea(ex, m) == AreaLoading.remove) ex,
    ];
    if (loading.isEmpty) continue;
    final area = label(m);
    out.add(
      Proposal(
        kind: ProposalKind.injuryAdjust,
        title: logged != null ? 'Treat your $area niggle as pain' : 'Protect your $area: pain on $days days',
        rationale:
            'You tagged $area as painful on $days of the last ${REVIEW_PLAN.painLookbackDays} days. ${logged != null ? 'Raise "${logged.label}" to pain' : 'Log it as an injury (pain)'} and rebuild the plan without ${_names(loading)}; machines, isolation work and higher reps take their place. If the pain is sharp or keeps coming back, see a physio.',
        ruleIds: ['T-SEL-08', 'T-FAT-04'],
        payload: {
          'injuryId': logged?.id,
          'muscle': m.wire,
          'severity': 'pain',
          if (logged == null) 'label': '${area[0].toUpperCase()}${area.substring(1)} pain (from check-ins)',
          'removeExerciseIds': _sortedIds(loading),
          'addExerciseIds': <String>[],
        },
        expiresOn: expires,
      ),
    );
  }
  return out;
}

/// volume_change (T-FAT-02/03, T-VOL-07): two reviews in a row with a deload's worth of recovery flags means one deload
/// did not clear the fatigue, so cut 2 weekly sets for every muscle at or above the practical floor (never below 4).
/// More volume only ever follows a plateau with good recovery, which plateau_action (add_volume) already proposes.
List<Proposal> volumeProposals(WeeklyState state, int yesCount) {
  final targets = state.targets;
  if (yesCount < DELOAD.yesThreshold || (state.previousYesCount ?? 0) < DELOAD.yesThreshold || targets == null) {
    return [];
  }
  final changes = <Map<String, dynamic>>[];
  for (final m in TRACKED_MUSCLES) {
    final from = targets[m];
    if (from == null || from < REVIEW_PLAN.volumeCutMinTarget) continue;
    final to = math.max(VOLUME.minEffective, from - REVIEW_PLAN.volumeCutSets);
    if (to < from) changes.add({'muscle': m.wire, 'from': from, 'to': to});
  }
  if (changes.isEmpty) return [];
  final cut = jsNumber(REVIEW_PLAN.volumeCutSets);
  return [
    Proposal(
      kind: ProposalKind.volumeChange,
      title: 'Trim weekly volume by $cut sets',
      rationale:
          'Two weekly reviews in a row flagged poor recovery (${state.previousYesCount} then $yesCount of 5), so one deload is not enough. Train with $cut fewer weekly sets on your higher-volume muscles until recovery holds; add sets back only after a real plateau. This rebuilds the plan from today, so if you also want this week\'s deload, accept this first.',
      ruleIds: ['T-FAT-02', 'T-FAT-03', 'T-VOL-07'],
      payload: {'changes': changes},
      expiresOn: addDays(state.today, REVIEW.proposalExpiryDays),
    ),
  ];
}

/// exercise_swap (T-SEL-04): an exercise you marked as disliked is still planned; swap it for the closest feasible substitute.
List<Proposal> dislikeSwapProposals(WeeklyState state) {
  final disliked = state.dislikedExerciseIds ?? const <String>[];
  final equipment = state.equipment;
  if (disliked.isEmpty || equipment == null) return [];
  final ctx = LibraryContext(
    exercises: state.exercises,
    equipment: equipment,
    injuries: state.injuries ?? const [],
    disliked: disliked,
  );
  return [
    for (final ex in _plannedExercises(state))
      if (disliked.contains(ex.id))
        if (substitutionsFor(ex, ctx).firstOrNull case final to?)
          Proposal(
            kind: ProposalKind.exerciseSwap,
            title: 'Swap ${ex.name} for ${to.name}',
            rationale:
                "You marked ${ex.name} as an exercise you don't want, but it is still in your plan. ${to.name} trains the same muscles with your equipment.",
            ruleIds: ['T-SEL-04'],
            payload: {'plannedExerciseIds': <String>[], 'fromExerciseId': ex.id, 'toExerciseId': to.id, 'reason': 'disliked'},
            expiresOn: addDays(state.today, REVIEW.proposalExpiryDays),
          ),
  ];
}

/// plan_regenerate (T-SCH-01 / T-SEL-04): the stored plan no longer matches your settings, which happens when a settings
/// change saved but the automatic rebuild failed. Signals: 2+ sessions next week on days you are no longer available
/// (one could be a manual move), or a planned exercise that needs equipment you no longer have.
List<Proposal> stalePlanProposals(WeeklyState state) {
  final reasons = <String>[];
  final availableDays = state.availableDays;
  if (availableDays != null && availableDays.isNotEmpty) {
    final off = state.nextWeekSessions
        .where((s) => s.status == SessionStateStatus.planned && !availableDays.contains(isoWeekday(s.date)))
        .length;
    if (off >= 2) reasons.add('$off sessions next week fall on days you are not available');
  }
  if (state.equipment case final equipment?) {
    final missing = [
      for (final ex in _plannedExercises(state))
        if (!hasEquipment(ex, equipment)) ex,
    ];
    if (missing.isNotEmpty) {
      reasons.add('${_names(missing)} need${missing.length == 1 ? 's' : ''} equipment you no longer have');
    }
  }
  if (reasons.isEmpty) return [];
  return [
    Proposal(
      kind: ProposalKind.planRegenerate,
      title: 'Rebuild your plan to match your settings',
      rationale:
          'Your plan is out of date: ${reasons.join('; ')}. Rebuilding from today keeps your logged history and uses your current days, equipment and preferences.',
      ruleIds: ['T-SCH-01', 'T-SEL-04'],
      payload: {'reason': reasons.join('; ')},
      expiresOn: addDays(state.today, REVIEW.proposalExpiryDays),
    ),
  ];
}

/// intro_week (T-FAT-06): coming back after 2+ weeks without a logged working set, run the next week at 75% of the sets
/// and one rep further from failure. Skipped when the upcoming week is already an intro or deload week, and when there
/// is no evidence of a break (no logs at all and no plan older than the break window, e.g. a brand-new user).
List<Proposal> introWeekProposals(WeeklyState state) {
  final block = state.block;
  if (block == null) return [];
  final upcoming = _upcomingSessions(state);
  if (upcoming.isEmpty || upcoming.any((s) => s.kind == SessionKind.intro || s.kind == SessionKind.deload)) return [];
  final breakDays = INTRO_WEEK.weeksOffTrigger * 7;
  String? last;
  for (final s in state.sets) {
    if (s.isWarmup || s.performedOn.compareTo(state.today) >= 0) continue;
    if (last == null || s.performedOn.compareTo(last) > 0) last = s.performedOn;
  }
  final daysOff = last != null
      ? daysBetween(last, state.today)
      : block.startsOn.compareTo(addDays(state.today, -breakDays)) <= 0
      ? daysBetween(block.startsOn, state.today)
      : null;
  if (daysOff == null || daysOff < breakDays) return [];
  return [
    Proposal(
      kind: ProposalKind.introWeek,
      title: 'Ease back in with an intro week',
      rationale:
          '${last != null ? 'Your last logged set was $daysOff days ago' : 'Nothing has been logged for $daysOff days'}. After time off, run the first week back at about 75% of the sets and one rep further from failure, then return to the full plan.',
      ruleIds: ['T-FAT-06'],
      payload: {'blockId': block.id, 'setPct': INTRO_WEEK.setPct, 'rirBump': INTRO_WEEK.rirBump},
      expiresOn: addDays(state.today, REVIEW.proposalExpiryDays),
    ),
  ];
}

/// All plan-level proposals from the weekly review.
List<Proposal> planReview(WeeklyState state, int yesCount) => [
  ...injuryProposals(state),
  ...volumeProposals(state, yesCount),
  ...dislikeSwapProposals(state),
  ...stalePlanProposals(state),
  ...introWeekProposals(state),
];
