// SPDX-License-Identifier: GPL-3.0-only
// The plan decision: how many days, which split, how much volume, which rep variation, and why.
// Rules: T-PLN-01…07, T-FRQ-04, T-SCH-02, T-VOL-04.
// ignore_for_file: constant_identifier_names
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';
import 'package:coach_training/coach_training.dart';

import 'budget.dart';
import 'catalog.dart';
import 'constants.dart';
import 'estimate.dart';
import 'profile.dart';
import 'score.dart';

/// Bonus per picked day left out when the user prefers fewer, longer sessions (heuristic).
const double FEWER_DAYS_BONUS = 4;

/// Score cost per round of one set less for every muscle (heuristic).
const double TRIM_PENALTY = 3;

/// Rounds of trimming tried past the first one where any split fits (heuristic).
const int EXTRA_TRIM_ROUNDS = 3;

/// Most rounds of trimming.
const int MAX_TRIM_ROUNDS = 20;

/// Another split the user can switch to.
class PlannerAlternative {
  PlannerAlternative({required this.split, required this.score, required this.summary});

  final PlannerSplit split;
  final double score;

  /// One line on what the split gives.
  final String summary;

  Map<String, dynamic> toJson() => {'split': split.key, 'score': score, 'summary': summary};
}

/// What the planner decided.
class PlannerDecision {
  PlannerDecision({
    required this.split,
    required this.liftDays,
    required this.status,
    required this.budget,
    required this.targets,
    required this.repVariation,
    required this.specialization,
    required this.strengthLifts,
    required this.e1rmSeeds,
    required this.focus,
    required this.estimate,
    required this.explanations,
    required this.warnings,
    required this.alternatives,
  });

  final PlannerSplit split;
  final int liftDays;
  final ResolvedStatus status;
  final Budget budget;

  /// Weekly sets per muscle for the block generator, or null for a strength goal (its phases set the volume).
  final Map<TrackedMuscle, double>? targets;
  final RepVariation repVariation;
  final List<TrackedMuscle> specialization;
  final List<MainLift>? strengthLifts;
  final Map<String, double> e1rmSeeds;

  /// The focus muscles, to put first in their sessions.
  final List<TrackedMuscle> focus;
  final WeekEstimate estimate;
  final List<Explanation> explanations;
  final List<Warning> warnings;

  /// Up to three other splits that also work, best first.
  final List<PlannerAlternative> alternatives;

  Map<String, dynamic> toJson() => {
    'split': split.toJson(),
    'liftDays': liftDays,
    'status': status.toJson(),
    'budget': budget.toJson(),
    'targets': targets == null ? null : {for (final m in TRACKED_MUSCLES) m.wire: targets![m]},
    'repVariation': repVariation.wire,
    'specialization': [for (final m in specialization) m.wire],
    'strengthLifts': strengthLifts == null ? null : [for (final l in strengthLifts!) l.wire],
    'e1rmSeeds': {...e1rmSeeds},
    'focus': [for (final m in focus) m.wire],
    'estimate': estimate.toJson(),
    'explanations': [for (final e in explanations) e.toJson()],
    'warnings': [for (final w in warnings) w.toJson()],
    'alternatives': [for (final a in alternatives) a.toJson()],
  };
}

String _name(TrackedMuscle m) => (MUSCLE_NAME[m] ?? m.wire).toLowerCase();

String _list(Iterable<String> xs) {
  final l = xs.toList();
  if (l.length <= 1) return l.join();
  return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
}

/// The range of weekly frequencies over the tracked muscles, as "2" or "2–3".
String _freqRange(WeekEstimate est) {
  final f = est.frequency.values;
  final lo = f.reduce(math.min);
  final hi = f.reduce(math.max);
  return lo == hi ? '$lo' : '$lo–$hi';
}

String _summary(Candidate c) =>
    '${c.split.name}: about ${jsRound(c.estimate.avgMinutes)} min a session, each muscle ${_freqRange(c.estimate)}× a week.';

/// Rep variation by status (T-PLN-05). Variation between sessions needs most muscles on both a heavier (A) and a
/// lighter (B) day; without that, an intermediate varies within the session.
RepVariation repVariationFor(Status status, PlannerSplit split, WeekEstimate est) {
  if (status == Status.novice) return RepVariation.withinSession;
  if (status == Status.advanced) return RepVariation.alternatingWeek;
  final onA = <TrackedMuscle>{};
  final onB = <TrackedMuscle>{};
  for (final (i, s) in est.sessions.indexed) {
    final variant = sessionVariant(split.templates, i);
    for (final e in s.muscleSets.entries) {
      if (e.value < 1) continue;
      (variant == SessionVariant.a ? onA : onB).add(e.key);
    }
  }
  final both = TRACKED_MUSCLES.where((m) => onA.contains(m) && onB.contains(m)).length;
  return both * 2 > TRACKED_MUSCLES.length ? RepVariation.betweenSession : RepVariation.withinSession;
}

int _rank(Candidate a, Candidate b) {
  final d = b.score.compareTo(a.score);
  return d != 0 ? d : PLANNER_SPLITS.indexOf(a.split) - PLANNER_SPLITS.indexOf(b.split);
}

/// Lowers every target that isn't a focus muscle by one set, not below the floor.
Map<TrackedMuscle, double> _lower(Map<TrackedMuscle, double> t, List<TrackedMuscle> keep) => {
  for (final e in t.entries)
    e.key: keep.contains(e.key) ? e.value : math.max(VOLUME.minEffective, e.value - 1),
};

/// Decides the plan for [p]. Throws an [ArgumentError] when no training day is picked.
///
/// The plan trains on every picked day (at most [MAX_LIFT_DAYS]); a user who prefers fewer, longer sessions may
/// get up to two days fewer. For each day count the budget sets the targets and every split for that count is
/// scored. When a split doesn't fit the session length, all targets except the focus muscles drop one set at a
/// time and the splits are scored again, each round of trimming costing [TRIM_PENALTY], for up to
/// [EXTRA_TRIM_ROUNDS] rounds past the first one where any split fits; so a split the user prefers can still win at
/// a set less. The best feasible candidate wins. If none ever fits, the best split that fails only on time is used
/// with a warning.
PlannerDecision decidePlan(PlannerProfile p) {
  if (p.days.isEmpty) throw ArgumentError('No training day picked');
  final st = p.status;
  final status = st.status;
  final picked = p.days.length;
  final kMax = math.min(picked, MAX_LIFT_DAYS);
  final ks = p.sessionPref == SessionPref.fewerLonger
      ? [for (var k = kMax; k >= math.max(math.min(2, kMax), kMax - 2); k--) k]
      : [kMax];
  final keep = status == Status.novice ? const <TrackedMuscle>[] : p.focus;

  final budgets = <int, Budget>{};
  final rounds = <Candidate, int>{};
  final all = <Candidate>[];
  List<Candidate> last = [];
  for (final k in ks) {
    final b = weeklyBudget(p, k);
    budgets[k] = b;
    var targets = b.targets;
    int? firstFit;
    for (var round = 0; round <= MAX_TRIM_ROUNDS; round++) {
      if (round > 0) {
        final next = _lower(targets, keep);
        if (next.entries.every((e) => targets[e.key] == e.value)) break;
        targets = next;
      }
      final scored = [for (final s in splitsFor(k)) scoreSplit(s, p, status, targets)];
      for (final c in scored) {
        if (k < kMax) c.terms['fewerDays'] = FEWER_DAYS_BONUS * (kMax - k);
        if (round > 0) c.terms['trim'] = -TRIM_PENALTY * round;
        rounds[c] = round;
      }
      all.addAll(scored);
      if (k == kMax) last = scored;
      if (firstFit == null && scored.any((c) => c.feasible)) firstFit = round;
      if (firstFit != null && round >= firstFit + EXTRA_TRIM_ROUNDS) break;
    }
  }

  final warnings = <Warning>[];
  final feasible = all.where((c) => c.feasible).toList()..sort(_rank);
  Candidate chosen;
  if (feasible.isNotEmpty) {
    chosen = feasible.first;
  } else {
    // Nothing fits even at minimum volume: the best split that fails only on time, or failing that, the best one
    // the user's status and goal allow.
    final pool = last.isEmpty ? all : last;
    final timeOnly = pool.where((c) => c.failures.length == 1 && c.failures.contains(Failure.time)).toList()
      ..sort(_rank);
    final usable =
        pool.where((c) => !c.failures.contains(Failure.status) && !c.failures.contains(Failure.goal)).toList()
          ..sort(_rank);
    chosen = timeOnly.isNotEmpty
        ? timeOnly.first
        : (usable.isNotEmpty ? usable.first : (pool..sort(_rank)).first);
    warnings.add(
      Warning(
        code: WarningCode.timeTooShort,
        message:
            'Even at minimum volume, sessions need about ${chosen.estimate.maxMinutes} min. Add more time per session or more days.',
        ruleIds: ['T-VOL-04', 'T-PLN-02'],
      ),
    );
  }
  final relaxed = (rounds[chosen] ?? 0) > 0;

  final k = chosen.split.days;
  final budget = budgets[k]!;
  final est = chosen.estimate;
  final strength = p.goal == Goal.strength;
  final repVariation = repVariationFor(status, chosen.split, est);
  final specialization = status == Status.advanced ? [...p.focus] : <TrackedMuscle>[];

  // ---------- Warnings ----------
  if (kMax < FREQUENCY.liftDays.min) {
    warnings.add(
      Warning(
        code: WarningCode.lowFrequency,
        message:
            'With one lifting day per week, progress beyond maintenance is hard. Add a second day if you can.',
        ruleIds: ['T-FRQ-04'],
      ),
    );
  } else if (kMax == 2 && status == Status.advanced) {
    warnings.add(
      Warning(
        code: WarningCode.lowFrequency,
        message: 'At your level two sessions a week get very long. A third day would spread the work.',
        ruleIds: ['T-PLN-01', 'T-FRQ-04'],
      ),
    );
  } else if (kMax == 2 && status == Status.intermediate) {
    warnings.add(
      Warning(
        code: WarningCode.lowFrequency,
        message: 'Two days a week keep you progressing slowly; a third day makes steady progress easier.',
        ruleIds: ['T-PLN-01', 'T-FRQ-04'],
      ),
    );
  }

  // ---------- Explanations ----------
  final explanations = <Explanation>[];
  if (k == picked) {
    explanations.add(
      Explanation(text: '$k lifting day${k == 1 ? '' : 's'}: the days you picked.', ruleIds: ['T-PLN-01']),
    );
  } else if (picked > MAX_LIFT_DAYS && k == MAX_LIFT_DAYS) {
    explanations.add(
      Explanation(
        text:
            '$k lifting days: one of the days you picked stays free, because the body needs a full rest day.',
        ruleIds: ['T-PLN-01', 'T-SCH-02'],
      ),
    );
  } else {
    explanations.add(
      Explanation(
        text: '$k of your $picked days: you prefer fewer, longer sessions, and $k days fit your week best.',
        ruleIds: ['T-PLN-01'],
      ),
    );
  }
  explanations.add(Explanation(text: st.note, ruleIds: st.ruleIds));
  if (strength) {
    explanations.add(
      Explanation(
        text:
            'Your main lifts come first; supporting work keeps about ${jsNumber(budget.base)} sets per muscle a week.',
        ruleIds: ['T-STR-02', 'T-PLN-02'],
      ),
    );
  } else {
    explanations.add(Explanation(text: budget.notes.join(' '), ruleIds: budget.ruleIds));
  }
  if (est.sessions.any((s) => s.hasSupersets)) {
    explanations.add(Explanation(text: supersetExplanation(p.minutes), ruleIds: ['T-PLN-08']));
  }
  if (!strength) {
    if (relaxed && warnings.every((w) => w.code != WarningCode.timeTooShort)) {
      explanations.add(
        Explanation(
          text: 'Volume was trimmed a little so every session fits in ${p.minutes} min.',
          ruleIds: ['T-VOL-04', 'T-PLN-02'],
        ),
      );
    }
  }

  final reasons = <String>[];
  final ruleIds = ['T-PLN-03', 'T-SPL-01'];
  if ((chosen.terms['style'] ?? 0) >= SCORE.styleMatch) {
    reasons.add('the style you asked for');
    ruleIds.add('T-PLN-07');
  } else if ((chosen.terms['style'] ?? 0) > 0) {
    reasons.add('close to the style you asked for');
    ruleIds.add('T-PLN-07');
  }
  if ((chosen.terms['keep'] ?? 0) > 0) {
    reasons.add('it keeps your current split');
    ruleIds.add('T-PLN-07');
  }
  final freq = est.frequency;
  reasons.add('each muscle ${_freqRange(est)}× a week');
  final trainedFocus = [
    for (final m in p.focus)
      if (freq[m]! >= 2) m,
  ];
  if (trainedFocus.isNotEmpty) {
    reasons.add(
      '${_list(trainedFocus.map(_name))} ${trainedFocus.map((m) => freq[m]!).reduce(math.min)}× or more',
    );
    ruleIds.add('T-PLN-04');
  }
  if (!chosen.terms.containsKey('legs') && est.sessions.length >= 3) {
    reasons.add('no hard leg days back to back');
  }
  reasons.add('sessions of about ${jsRound(est.avgMinutes)} min');
  explanations.add(Explanation(text: '${chosen.split.name}: ${_list(reasons)}.', ruleIds: ruleIds));
  if ((p.age ?? 0) >= 50) {
    explanations.add(
      Explanation(
        text: 'Hard leg days are kept apart where your days allow, so you recover between them.',
        ruleIds: ['T-PLN-06'],
      ),
    );
  }
  explanations.add(
    Explanation(
      text: switch (repVariation) {
        RepVariation.withinSession => 'Heavier and lighter rep ranges mix within each session.',
        RepVariation.betweenSession => 'A days use heavier, lower-rep sets; B days lighter, higher-rep ones.',
        RepVariation.alternatingWeek => 'Heavier and lighter weeks alternate.',
      },
      ruleIds: ['T-PLN-05', 'T-INT-04'],
    ),
  );

  final alternatives = [
    for (final c in feasible.where((c) => c.split.key != chosen.split.key).take(3))
      PlannerAlternative(split: c.split, score: c.score, summary: _summary(c)),
  ];

  return PlannerDecision(
    split: chosen.split,
    liftDays: k,
    status: st,
    budget: budget,
    targets: strength ? null : chosen.targets,
    repVariation: repVariation,
    specialization: specialization,
    strengthLifts: strength
        ? (p.strengthLifts ?? const [MainLift.squat, MainLift.bench, MainLift.deadlift])
        : null,
    e1rmSeeds: {...p.knownLifts},
    focus: [...p.focus],
    estimate: est,
    explanations: explanations,
    warnings: warnings,
    alternatives: alternatives,
  );
}
