// SPDX-License-Identifier: GPL-3.0-only
// Weekly self-assessment, deloads, intro weeks. Rules: T-FAT-01…05, T-FAT-08, T-RIR-01, T-STR-01, T-STA-03.
// ignore_for_file: constant_identifier_names
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';
import 'package:coach_training/coach_training.dart';

const List<ReviewKey> _REVIEW_KEYS = [
  ReviewKey.dreadingGym,
  ReviewKey.sleepWorse,
  ReviewKey.performanceDown,
  ReviewKey.stressWorse,
  ReviewKey.achesWorse,
];

double? _avgOf(List<CheckinDay> days, num? Function(CheckinDay c) f) {
  final xs = [for (final c in days) ?f(c)];
  return xs.isNotEmpty ? mean(xs) : null;
}

ReviewAutofill autofillReview(WeeklyState state) {
  final weekEnd = addDays(state.weekStart, 7);
  final week = [
    for (final c in state.checkins)
      if (c.day.compareTo(state.weekStart) >= 0 && c.day.compareTo(weekEnd) < 0) c,
  ];
  final baselineFrom = addDays(state.weekStart, -28);
  final baseline = [
    for (final c in state.checkins)
      if (c.day.compareTo(baselineFrom) >= 0 && c.day.compareTo(state.weekStart) < 0) c,
  ];
  final answers = <ReviewKey, bool>{};
  final evidence = <ReviewKey, String>{};

  // Dreading the gym?
  final energy7 = _avgOf(week, (c) => c.energy);
  final skipped = state.sessionsThisWeek
      .where(
        (s) =>
            s.status == SessionStateStatus.skipped ||
            (s.status == SessionStateStatus.planned && s.date.compareTo(state.today) < 0),
      )
      .length;
  answers[ReviewKey.dreadingGym] =
      (energy7 != null && energy7 <= REVIEW.energyDreadThreshold) || skipped >= REVIEW.skippedDreadThreshold;
  evidence[ReviewKey.dreadingGym] =
      'Energy avg ${energy7 == null ? '-' : jsNumber(round1(energy7))}/5 · $skipped session${skipped == 1 ? '' : 's'} skipped';

  // Sleep worse than normal?
  final sleep7 = _avgOf(week, (c) => c.sleepHours);
  final sleepBase = baseline.where((c) => c.sleepHours != null).length >= 7
      ? _avgOf(baseline, (c) => c.sleepHours)
      : null;
  answers[ReviewKey.sleepWorse] =
      sleep7 != null &&
      (sleepBase != null ? sleep7 < sleepBase - REVIEW.sleepDropHours : sleep7 < REVIEW.sleepNoBaseline);
  evidence[ReviewKey.sleepWorse] = sleep7 == null
      ? 'No sleep logged'
      : sleepBase != null
      ? 'Sleep avg ${jsNumber(round1(sleep7))} h vs ${jsNumber(round1(sleepBase))} h normal'
      : 'Sleep avg ${jsNumber(round1(sleep7))} h (no baseline yet; flag below 7 h)';

  // Performance decreasing?
  final exMap = {for (final e in state.exercises) e.id: e};
  final weekSets = [
    for (final s in state.sets)
      if (s.performedOn.compareTo(state.weekStart) >= 0 && s.performedOn.compareTo(weekEnd) < 0 && !s.isWarmup) s,
  ];
  final declined = <String>[];
  for (final exId in {for (final s in weekSets) s.exerciseId}) {
    final exposures = [
      for (final x in _firstSets(state.sets, exId))
        if (x.date.compareTo(weekEnd) < 0) x,
    ];
    final iThis = exposures.indexWhere((x) => x.date.compareTo(state.weekStart) >= 0);
    if (iThis <= 0) continue;
    final cur = exposures[iThis];
    final prev = exposures[iThis - 1];
    if (cur.load != null && prev.load != null && cur.load == prev.load && cur.reps < prev.reps) {
      declined.add(exMap[exId]?.name ?? exId);
    }
  }
  String? mainDrop;
  for (final id in state.mainLiftExerciseIds) {
    final now = bestRecentE1rm(weekSets, id, 1);
    if (now == null) continue;
    final from = addDays(state.weekStart, -21);
    final before = [
      for (final s in state.sets)
        if (s.exerciseId == id &&
            s.performedOn.compareTo(from) >= 0 &&
            s.performedOn.compareTo(state.weekStart) < 0 &&
            !s.isWarmup)
          s,
    ];
    double? best;
    for (final s in before) {
      final v = e1rm(s.loadKg, s.reps, s.rir);
      if (v != null && (best == null || v > best)) best = v;
    }
    if (best != null && now < best * (1 - REVIEW.e1rmDropPct)) mainDrop = exMap[id]?.name ?? id;
  }
  final drift = rirDrift(state.sets, state.weekStart);
  final drifting = drift.exerciseIds.length >= RIR_DRIFT.exercises;
  answers[ReviewKey.performanceDown] =
      declined.length >= REVIEW.perfDropExercises || mainDrop != null || drifting;
  final driftNames = [for (final id in drift.exerciseIds.take(3)) exMap[id]?.name ?? id];
  evidence[ReviewKey.performanceDown] = mainDrop != null
      ? '$mainDrop e1RM fell more than 3% vs its 3-week best'
      : declined.length >= REVIEW.perfDropExercises
      ? 'Fewer reps at the same load on: ${declined.take(3).join(', ')}'
      : drifting
      ? 'Sets felt harder than planned (about ${jsNumber(round1(drift.avgBelow ?? 0))} reps closer to failure) at the same load on: ${driftNames.join(', ')}'
      : declined.isNotEmpty
      ? 'Fewer reps at the same load on: ${declined.take(3).join(', ')}'
      : 'No drops in first-set reps at the same load';

  // Stress worse?
  final stress7 = _avgOf(week, (c) => c.stress);
  final stressBase = _avgOf(baseline, (c) => c.stress);
  answers[ReviewKey.stressWorse] = stress7 != null && stressBase != null && stress7 >= stressBase + REVIEW.stressRise;
  evidence[ReviewKey.stressWorse] = stress7 == null
      ? 'No stress logged'
      : 'Stress avg ${jsNumber(round1(stress7))}/5${stressBase != null ? ' vs ${jsNumber(round1(stressBase))} normal' : ''}';

  // Aches and pains?
  final pain = week.any((c) => c.soreness.values.contains(SorenessLevel.pain));
  int sore(CheckinDay c) => c.soreness.values.where((v) => v == SorenessLevel.sore).length;
  final soreThisWeek = week.fold(0, (a, c) => a + sore(c));
  final soreBaseWeekly = baseline.fold(0, (a, c) => a + sore(c)) / 4;
  answers[ReviewKey.achesWorse] = pain || soreThisWeek > soreBaseWeekly + REVIEW.soreAboveAverage;
  evidence[ReviewKey.achesWorse] = pain
      ? 'Pain tagged this week'
      : '$soreThisWeek sore tags vs ~${jsNumber(round1(soreBaseWeekly))} per week normally';

  return ReviewAutofill(answers: answers, evidence: evidence);
}

typedef _FirstSet = ({String date, double? load, int reps, double? rir, double? plannedRirMin});

List<_FirstSet> _firstSets(List<LoggedSet> sets, String exId) {
  final byDay = <String, List<LoggedSet>>{};
  for (final s in sets) {
    if (s.exerciseId != exId || s.isWarmup) continue;
    byDay[s.performedOn] = [...?byDay[s.performedOn], s];
  }
  return [
    for (final MapEntry(key: date, value: ss) in stableSorted(byDay.entries, (a, b) => a.key.compareTo(b.key)))
      _firstSet(date, stableSorted<LoggedSet>(ss, (a, b) => a.setIndex - b.setIndex).first),
  ];
}

_FirstSet _firstSet(String date, LoggedSet f) =>
    (date: date, load: f.loadKg, reps: f.reps, rir: f.rir, plannedRirMin: f.plannedRirMin);

/// `rirDrift` result: exercises drifting below their RIR floor and the average gap.
class RirDrift {
  RirDrift({required this.exerciseIds, required this.avgBelow});

  factory RirDrift.fromJson(Map<String, dynamic> json) => RirDrift(
    exerciseIds: [for (final x in json['exerciseIds'] as List) x as String],
    avgBelow: json['avgBelow'] == null ? null : (json['avgBelow'] as num).toDouble(),
  );

  final List<String> exerciseIds;
  final double? avgBelow;

  Map<String, dynamic> toJson() => {'exerciseIds': [...exerciseIds], 'avgBelow': avgBelow};
}

/// RIR drift (heuristic from T-RIR-01 / T-FAT-01): exercises whose first working set ended closer to failure than the
/// prescribed RIR floor on the last `RIR_DRIFT.consecutiveExposures` exposures (the latest in the reviewed week),
/// without a load jump between them. The same load feeling harder session after session is accumulated fatigue,
/// the same signal as "fewer reps at the same load". Sets logged without a plan or without RIR are ignored.
RirDrift rirDrift(List<LoggedSet> sets, String weekStart) {
  final weekEnd = addDays(weekStart, 7);
  final ids = {
    for (final s in sets)
      if (s.performedOn.compareTo(weekStart) >= 0 && s.performedOn.compareTo(weekEnd) < 0 && !s.isWarmup) s.exerciseId,
  };
  final out = <String>[];
  final gaps = <double>[];
  final n = RIR_DRIFT.consecutiveExposures;
  for (final id in ids) {
    final all = [
      for (final x in _firstSets(sets, id))
        if (x.date.compareTo(weekEnd) < 0) x,
    ];
    final recent = all.sublist(math.max(0, all.length - n));
    if (recent.length < n || recent[n - 1].date.compareTo(weekStart) < 0) continue;
    final harder = recent.every(
      (x) => x.rir != null && x.plannedRirMin != null && x.rir! <= x.plannedRirMin! - RIR_DRIFT.minBelowFloor,
    );
    if (!harder) continue;
    // A heavier load explains a lower RIR; only count it at the same (or a similar) load.
    var similarLoad = true;
    for (var i = 1; i < recent.length; i++) {
      if (!((recent[i].load ?? 0) <= (recent[i - 1].load ?? 0) * (1 + RIR_DRIFT.similarLoadPct) + 1e-9)) {
        similarLoad = false;
        break;
      }
    }
    if (!similarLoad) continue;
    out.add(id);
    gaps.add(mean([for (final x in recent) x.plannedRirMin! - x.rir!]));
  }
  return RirDrift(
    exerciseIds: stableSorted(out, (a, b) => a.compareTo(b)),
    avgBelow: gaps.isNotEmpty ? mean(gaps) : null,
  );
}

/// `lighterSessionFor`'s view of today's session.
class TodaySession {
  TodaySession({required this.id, required this.status, required this.totalSets});

  factory TodaySession.fromJson(Map<String, dynamic> json) => TodaySession(
    id: json['id'] as String,
    status: json['status'] as String,
    totalSets: (json['totalSets'] as num).toDouble(),
  );

  final String id;
  final String status;
  final double totalSets;

  Map<String, dynamic> toJson() => {'id': id, 'status': status, 'totalSets': totalSets};
}

/// `lighterSessionFor`'s view of another planned session.
class OtherSession {
  OtherSession({required this.id, required this.title, required this.date, required this.status, required this.totalSets});

  factory OtherSession.fromJson(Map<String, dynamic> json) => OtherSession(
    id: json['id'] as String,
    title: json['title'] as String,
    date: json['date'] as String,
    status: json['status'] as String,
    totalSets: (json['totalSets'] as num).toDouble(),
  );

  final String id;
  final String title;
  final String date;
  final String status;
  final double totalSets;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'date': date, 'status': status, 'totalSets': totalSets};
}

/// The session `lighterSessionFor` suggests instead of today's.
class LighterSession {
  LighterSession({required this.id, required this.title, required this.date});

  factory LighterSession.fromJson(Map<String, dynamic> json) =>
      LighterSession(id: json['id'] as String, title: json['title'] as String, date: json['date'] as String);

  final String id;
  final String title;
  final String date;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'date': date};
}

/// T-FAT-08 prompted by a low readiness score (heuristic): the lightest other planned session left this week,
/// if it has fewer total sets than today's. Mirrors swapForLightest so the prompt only shows when the swap would work.
LighterSession? lighterSessionFor(
  num? readinessScore,
  TodaySession? todaySession,
  List<OtherSession> others,
  String today,
) {
  if (readinessScore == null || readinessScore > REVIEW.lowReadinessScore) return null;
  if (todaySession == null || todaySession.status != 'planned') return null;
  final weekEnd = addDays(mondayOf(today), 7);
  final pool = [
    for (final s in others)
      if (s.id != todaySession.id &&
          s.status == 'planned' &&
          s.date.compareTo(today) >= 0 &&
          s.date.compareTo(weekEnd) < 0)
        s,
  ];
  final sorted = stableSorted(pool, (a, b) {
    final c = a.totalSets.compareTo(b.totalSets);
    return c != 0 ? c : a.date.compareTo(b.date);
  });
  final lightest = sorted.isEmpty ? null : sorted.first;
  return lightest != null && lightest.totalSets < todaySession.totalSets
      ? LighterSession(id: lightest.id, title: lightest.title, date: lightest.date)
      : null;
}

/// Local soreness: muscles tagged pain at least once or sore on ≥2 days this week.
List<MuscleId> localSoreMuscles(WeeklyState state) {
  final weekEnd = addDays(state.weekStart, 7);
  final week = [
    for (final c in state.checkins)
      if (c.day.compareTo(state.weekStart) >= 0 && c.day.compareTo(weekEnd) < 0) c,
  ];
  final counts = <MuscleId, ({int sore, int pain})>{};
  for (final c in week) {
    for (final MapEntry(key: m, value: lvl) in c.soreness.entries) {
      final cur = counts[m] ?? (sore: 0, pain: 0);
      counts[m] = lvl == SorenessLevel.pain ? (sore: cur.sore, pain: cur.pain + 1) : (sore: cur.sore + 1, pain: cur.pain);
    }
  }
  return stableSorted([
    for (final MapEntry(key: m, value: v) in counts.entries)
      if (v.pain > 0 || v.sore >= 2) m,
  ], (a, b) => a.wire.compareTo(b.wire));
}

/// What a targeted deload does with an exercise for a sore or painful area (`exercisesLoadingArea`'s result).
enum AreaLoading {
  remove('remove'),
  reduce('reduce'),
  keep('keep');

  const AreaLoading(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, AreaLoading> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static AreaLoading fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown AreaLoading: "$wire"'));
}

/// T-FAT-04: which exercises a targeted deload removes for a sore/painful area.
AreaLoading exercisesLoadingArea(ExerciseDef ex, MuscleId m) {
  if (m == MuscleId.erectors) {
    return ex.axialLoad
        ? AreaLoading.remove
        : isPrimary(ex, m)
        ? AreaLoading.reduce
        : AreaLoading.keep;
  }
  if (!isPrimary(ex, m)) return AreaLoading.keep;
  if (ex.axialLoad ||
      ex.impactLowerBody ||
      ex.category == Category.lowerFreeCompound ||
      ex.category == Category.upperFreePress) {
    return AreaLoading.remove;
  }
  return AreaLoading.reduce;
}

/// `weeklyReview`'s result.
class WeeklyReview {
  WeeklyReview({
    required this.autofill,
    required this.answers,
    required this.yesCount,
    required this.proposals,
    required this.inference,
  });

  factory WeeklyReview.fromJson(Map<String, dynamic> json) => WeeklyReview(
    autofill: ReviewAutofill.fromJson(json['autofill'] as Map<String, dynamic>),
    answers: {
      for (final e in (json['answers'] as Map<String, dynamic>).entries) ReviewKey.fromWire(e.key): e.value as bool,
    },
    yesCount: json['yesCount'] as int,
    proposals: [for (final x in json['proposals'] as List) Proposal.fromJson(x as Map<String, dynamic>)],
    inference: StatusInference.fromJson(json['inference'] as Map<String, dynamic>),
  );

  final ReviewAutofill autofill;
  final Map<ReviewKey, bool> answers;
  final int yesCount;
  final List<Proposal> proposals;

  /// This week's status inference; the server stores it on the week's review row (one per week, T-STA-03).
  final StatusInference inference;

  Map<String, dynamic> toJson() => {
    'autofill': autofill.toJson(),
    'answers': {for (final e in answers.entries) e.key.wire: e.value},
    'yesCount': yesCount,
    'proposals': [for (final p in proposals) p.toJson()],
    'inference': inference.toJson(),
  };
}

WeeklyReview weeklyReview(WeeklyState state) {
  final autofill = autofillReview(state);
  final answers = {...autofill.answers, ...?state.overrides};
  final yesCount = _REVIEW_KEYS.where((k) => answers[k] ?? false).length;
  final nextWeek = addDays(state.weekStart, 7);
  final expires = addDays(state.today, REVIEW.proposalExpiryDays);
  final proposals = <Proposal>[];
  final exMap = {for (final e in state.exercises) e.id: e};

  if (yesCount >= DELOAD.yesThreshold) {
    proposals.add(
      Proposal(
        kind: ProposalKind.standardDeload,
        title: 'Deload next week ($yesCount of 5 recovery flags)',
        rationale:
            'You answered “yes” to $yesCount recovery questions. Next week every exercise drops about 40% of its sets while loads, effort and the number of sessions stay the same.',
        ruleIds: ['T-FAT-01', 'T-FAT-02', 'T-FAT-03'],
        payload: {'weekStart': nextWeek, 'setCutPct': DELOAD.setCutDefault, 'mode': 'sets'},
        appliesFrom: nextWeek,
        expiresOn: expires,
      ),
    );
  }
  if (answers[ReviewKey.achesWorse] ?? false) {
    final muscles = localSoreMuscles(state);
    if (muscles.isNotEmpty) {
      final removeIds = <String>{};
      for (final s in state.nextWeekSessions) {
        for (final pe in s.exercises) {
          final ex = exMap[pe.exerciseId];
          if (ex == null) continue;
          if (muscles.any((m) => exercisesLoadingArea(ex, m) == AreaLoading.remove)) removeIds.add(ex.id);
        }
      }
      final names = [for (final id in removeIds) exMap[id]?.name ?? id];
      final area = muscles.map(label).join(', ');
      proposals.add(
        Proposal(
          kind: ProposalKind.targetedDeload,
          title: 'Ease off $area next week',
          rationale:
              '$area ${muscles.length > 1 ? 'have' : 'has'} been sore or painful. ${names.isNotEmpty ? 'Remove ${names.join(', ')} for a week; ' : ''}other exercises for the area drop half their sets and everything else trains normally.',
          ruleIds: ['T-FAT-04'],
          payload: {
            'weekStart': nextWeek,
            'muscles': [for (final m in muscles) m.wire],
            'removeExerciseIds': stableSorted(removeIds, (a, b) => a.compareTo(b)),
            'reduceSetsPct': TARGETED_DELOAD.reduceSetsPct,
            'mode': 'deload',
          },
          appliesFrom: nextWeek,
          expiresOn: expires,
        ),
      );
      // T-FAT-05: the alternative when heavy loads are the problem. Only offered when next week loads the area heavily.
      final heavy = <String>{};
      for (final s in state.nextWeekSessions) {
        for (final pe in s.exercises) {
          final ex = exMap[pe.exerciseId];
          if (ex != null &&
              muscles.any((m) => isPrimary(ex, m) || (m == MuscleId.erectors && ex.axialLoad)) &&
              (ex.category != Category.isolation || (pe.repMax != null && pe.repMax! <= 10))) {
            heavy.add(ex.id);
          }
        }
      }
      if (heavy.isNotEmpty) {
        proposals.add(
          Proposal(
            kind: ProposalKind.targetedDeload,
            title: 'Or: a higher-rep week for $area',
            rationale:
                'If $area ache${muscles.length > 1 ? '' : 's'} with heavy loads but not with high reps, keep every exercise and set next week but switch the ones that work the area to higher reps with lighter loads. Pick this or the targeted deload, not both.',
            ruleIds: ['T-FAT-05', 'T-FAT-04'],
            payload: {
              'weekStart': nextWeek,
              'muscles': [for (final m in muscles) m.wire],
              'removeExerciseIds': <String>[],
              'reduceSetsPct': 0,
              'mode': 'higher_reps',
            },
            appliesFrom: nextWeek,
            expiresOn: expires,
          ),
        );
      }
    }
  }

  // Block end → transition proposal (T-STR-01).
  if (state.block case final block?) {
    final lastWeekStart = addDays(block.startsOn, (block.weeks - 1) * 7);
    if (state.weekStart.compareTo(lastWeekStart) >= 0) {
      final fromKind = block.kind;
      final toKind = isStrengthKind(fromKind) ? nextStrengthKind(fromKind, block.testDate, state.today) : fromKind;
      final heavyPhase = fromKind == BlockKind.strengthLoad || fromKind == BlockKind.strengthPeak;
      proposals.add(
        Proposal(
          kind: ProposalKind.blockTransition,
          title: 'Start a new ${kindLabel(toKind.wire)} block',
          rationale: fromKind == BlockKind.strengthVolume
              ? 'Your Volume phase is done. Next: a Load phase with heavier singles and fewer supporting sets.${yesCount >= 2 ? ' Take the deload first.' : ''}'
              : heavyPhase
              ? 'Heavy phase done. The next Volume phase starts with an intro week (75% sets, +1 RIR).'
              : 'Your block is complete. The next one keeps your exercises (swapping at most one or two) and carries your volume forward.',
          ruleIds: ['T-STR-01', 'T-SEL-06', if (heavyPhase) 'T-FAT-06'],
          payload: {'fromKind': fromKind.wire, 'toKind': toKind.wire, 'startsOn': nextWeek},
          appliesFrom: nextWeek,
          expiresOn: expires,
        ),
      );
    }
  }

  // Training status inference (T-STA-03).
  final inf = inferTrainingStatus(
    TrainingStatusInput(sets: state.sets, today: state.today, anchorExerciseIds: statusAnchorIds(state)),
  );
  final history = state.statusHistory;
  final prevInf = history == null || history.isEmpty ? null : history.last;
  if (inf.status case final status? when status != state.status && prevInf == status) {
    proposals.add(
      Proposal(
        kind: ProposalKind.statusChange,
        title: 'Update training status: ${state.status.wire} → ${status.wire}',
        rationale: '${inf.evidence} This matched ${status.wire} two reviews in a row.',
        ruleIds: ['T-STA-01', 'T-STA-03'],
        payload: {'from': state.status.wire, 'to': status.wire, 'evidence': inf.evidence},
        expiresOn: expires,
      ),
    );
  }
  return WeeklyReview(autofill: autofill, answers: answers, yesCount: yesCount, proposals: proposals, inference: inf);
}

/// Lifts that status inference looks at: main lifts plus each session's first exercise this week and next (T-STA-03).
List<String> statusAnchorIds(WeeklyState state) {
  final out = <String>{...state.mainLiftExerciseIds};
  for (final s in [...state.sessionsThisWeek, ...state.nextWeekSessions]) {
    if (s.exercises.isNotEmpty) out.add(s.exercises.first.exerciseId);
  }
  return [...out];
}

const Map<MuscleId, String> _LABELS = {
  MuscleId.erectors: 'lower back',
  MuscleId.frontDelts: 'front delts',
  MuscleId.sideDelts: 'side delts',
  MuscleId.rearDelts: 'rear delts',
};
String label(MuscleId m) => _LABELS[m] ?? m.wire;

String kindLabel(String k) =>
    const {
      'hypertrophy': 'hypertrophy',
      'strength_volume': 'strength Volume',
      'strength_load': 'strength Load',
      'strength_peak': 'strength Peak',
      'sport_support': 'sport-support',
    }[k] ??
    k;

/// Days until the weekly review is due (Sunday or first open after).
String reviewWeekFor(String today, int weekdayIso) {
  // On Sunday review the current week, otherwise the previous Mon–Sun week.
  final monday = addDays(today, 1 - weekdayIso);
  return weekdayIso == 7 ? monday : addDays(monday, -7);
}

int daysSince(String a, String b) => daysBetween(a, b);
