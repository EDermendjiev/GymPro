// SPDX-License-Identifier: GPL-3.0-only
// Nutrition adjustments from the bodyweight trend. Rules: N-ADJ-01…06, N-WGT-02/04.
import 'package:coach_kernel/coach_kernel.dart';

import 'js_number.dart';
import 'trend.dart';

class WeighInState {
  WeighInState({
    required this.today,
    required this.phase,
    required this.phaseStartedOn,
    this.lastAdjustedOn,
    required this.kcal,
    required this.multiplier,
    required this.bodyweightKg,
    required this.status,
    required this.targetRatePct,
    required this.weighIns,
    this.initialAdjustDone,
  });

  factory WeighInState.fromJson(Map<String, dynamic> json) => WeighInState(
    today: json['today'] as String,
    phase: NutritionPhase.fromWire(json['phase'] as String),
    phaseStartedOn: json['phaseStartedOn'] as String,
    lastAdjustedOn: json['lastAdjustedOn'] == null ? null : json['lastAdjustedOn'] as String,
    kcal: json['kcal'] as int,
    multiplier: (json['multiplier'] as num).toDouble(),
    bodyweightKg: (json['bodyweightKg'] as num).toDouble(),
    status: Status.fromWire(json['status'] as String),
    targetRatePct: (json['targetRatePct'] as num).toDouble(),
    weighIns: [for (final w in json['weighIns'] as List) WeighIn.fromJson(w as Map<String, dynamic>)],
    initialAdjustDone: json['initialAdjustDone'] == null ? null : json['initialAdjustDone'] as bool,
  );

  final String today;
  final NutritionPhase phase;
  final String phaseStartedOn;
  final String? lastAdjustedOn;
  final int kcal;
  final double multiplier;
  final double bodyweightKg;
  final Status status;

  /// loss: %/week; gain: %/month.
  final double targetRatePct;
  final List<WeighIn> weighIns;
  final bool? initialAdjustDone;

  Map<String, dynamic> toJson() => {
    'today': today,
    'phase': phase.wire,
    'phaseStartedOn': phaseStartedOn,
    'lastAdjustedOn': ?lastAdjustedOn,
    'kcal': kcal,
    'multiplier': multiplier,
    'bodyweightKg': bodyweightKg,
    'status': status.wire,
    'targetRatePct': targetRatePct,
    'weighIns': [for (final w in weighIns) w.toJson()],
    'initialAdjustDone': ?initialAdjustDone,
  };
}

/// The result of [nutritionReview].
class NutritionReviewResult {
  NutritionReviewResult({required this.proposals, required this.weeks, required this.notes});

  factory NutritionReviewResult.fromJson(Map<String, dynamic> json) => NutritionReviewResult(
    proposals: [for (final p in json['proposals'] as List) Proposal.fromJson(p as Map<String, dynamic>)],
    weeks: [for (final w in json['weeks'] as List) WeekAverage.fromJson(w as Map<String, dynamic>)],
    notes: [for (final n in json['notes'] as List) n as String],
  );

  final List<Proposal> proposals;
  final List<WeekAverage> weeks;
  final List<String> notes;

  Map<String, dynamic> toJson() => {
    'proposals': [for (final p in proposals) p.toJson()],
    'weeks': [for (final w in weeks) w.toJson()],
    'notes': [...notes],
  };
}

int _stepFor(int kcal) => kcal >= 3000 ? NUTRITION.adjust.defaultOver : NUTRITION.adjust.defaultUnder;

Proposal _calorieProposal(
  WeighInState state,
  int change,
  String reason,
  List<String> ruleIds, [
  String? extra,
]) {
  final toKcal = state.kcal + change;
  final dir = change < 0 ? 'Lower' : 'Raise';
  // An empty extra counts as none, like the reference's truthiness check.
  final hasExtra = extra != null && extra.isNotEmpty;
  return Proposal(
    kind: ProposalKind.calorieAdjust,
    title: '$dir calories by ${change.abs()} kcal (to $toKcal)',
    rationale:
        '$reason${change < 0 ? ' The cut comes from carbs and fat; protein stays the same.' : ''}'
        '${hasExtra ? ' $extra' : ''}',
    ruleIds: [...ruleIds, 'N-ADJ-03', if (change < 0) 'N-ADJ-04'],
    payload: {'fromKcal': state.kcal, 'toKcal': toKcal, 'reason': reason},
    appliesFrom: addDays(mondayOf(state.today), 7),
    expiresOn: addDays(state.today, 7),
  );
}

/// Returns proposals (0 or 1) after a week closes. Pure.
NutritionReviewResult nutritionReview(WeighInState state) {
  final notes = <String>[];
  final thisMonday = mondayOf(state.today);
  final weeks = [
    for (final w in weeklyAverages(state.weighIns))
      if (w.weekStart.compareTo(thisMonday) < 0) w,
  ]; // completed weeks only
  if (weeks.isEmpty) {
    return NutritionReviewResult(proposals: [], weeks: weeks, notes: ['No completed weigh-in weeks yet.']);
  }
  final last = weeks[weeks.length - 1];
  if (last.lowData) {
    notes.add(
      'Last week had fewer than 3 weigh-ins or no weekend weigh-in, so no adjustment is made (N-WGT-02).',
    );
    return NutritionReviewResult(proposals: [], weeks: weeks, notes: notes);
  }
  final lastAdjustedOn = state.lastAdjustedOn;
  if (lastAdjustedOn != null &&
      lastAdjustedOn.isNotEmpty &&
      daysBetween(lastAdjustedOn, state.today) < NUTRITION.adjust.minDaysBetween) {
    notes.add('Calories changed less than 2 weeks ago, so waiting before judging again (N-ADJ-03).');
    return NutritionReviewResult(proposals: [], weeks: weeks, notes: notes);
  }
  final reliable = [
    for (final w in weeks)
      if (!w.lowData) w,
  ];
  final phaseWeek1 = mondayOf(state.phaseStartedOn);
  WeekAverage? findWeek(String weekStart) {
    for (final w in reliable) {
      if (w.weekStart == weekStart) return w;
    }
    return null;
  }

  // ---------- N-ADJ-01: initial adjustment ----------
  if (!(state.initialAdjustDone ?? false) && state.phase != NutritionPhase.maintain) {
    final w1 = findWeek(phaseWeek1);
    final prior = findWeek(addDays(phaseWeek1, -7));
    final w2 = findWeek(addDays(phaseWeek1, 7));
    // Compare phase week 1 with the week before; with no prior week, compare week 2 with week 1.
    final (WeekAverage, WeekAverage)? pair = w1 != null && prior != null && last.weekStart == w1.weekStart
        ? (prior, w1)
        : prior == null && w1 != null && w2 != null && last.weekStart == w2.weekStart
        ? (w1, w2)
        : null;
    if (pair != null) {
      final (a, b) = pair;
      final wrong = state.phase == NutritionPhase.gain ? b.avg <= a.avg : b.avg >= a.avg;
      if (wrong) {
        final step = NUTRITION.adjust.initialMultiplierStep * (state.phase == NutritionPhase.gain ? 1 : -1);
        final to = jsRound((state.multiplier + step) * 100) / 100;
        final moved = b.avg > a.avg
            ? 'up'
            : b.avg < a.avg
            ? 'down'
            : 'nowhere';
        return NutritionReviewResult(
          proposals: [
            Proposal(
              kind: ProposalKind.multiplierAdjust,
              title:
                  'Adjust activity factor ${state.multiplier.toStringAsFixed(2)} → ${to.toStringAsFixed(2)}',
              rationale:
                  'In the first week of your ${state.phase.wire} phase your average weight went $moved '
                  '(${jsNumber(a.avg)} → ${jsNumber(b.avg)} kg). Your maintenance estimate is probably '
                  '${state.phase == NutritionPhase.gain ? 'too low' : 'too high'}.',
              ruleIds: ['N-ADJ-01', 'N-MNT-03'],
              payload: {'from': state.multiplier, 'to': to, 'reason': 'initial week check'},
              appliesFrom: addDays(thisMonday, 0),
              expiresOn: addDays(state.today, 7),
            ),
          ],
          weeks: weeks,
          notes: notes,
        );
      }
      notes.add('First-week check passed: weight moved in the right direction.');
    }
  }

  // ---------- Ongoing adjustments (ignore the phase's first week, N-WGT-04) ----------
  final usable = [
    for (final w in reliable)
      if (w.weekStart.compareTo(phaseWeek1) > 0) w,
  ];
  final window = state.phase == NutritionPhase.loss ? (state.bodyweightKg < 60 ? 3 : 2) : 3;
  if (usable.length < 2) {
    return NutritionReviewResult(
      proposals: [],
      weeks: weeks,
      notes: [...notes, 'Not enough reliable weeks yet for a trend.'],
    );
  }
  final end = usable[usable.length - 1];
  final startCandidates = [
    for (final w in usable)
      if (daysBetween(w.weekStart, end.weekStart) >= window * 7) w,
  ];
  if (startCandidates.isEmpty) {
    return NutritionReviewResult(
      proposals: [],
      weeks: weeks,
      notes: [...notes, 'Waiting for $window weeks of trend data.'],
    );
  }
  final start = startCandidates[startCandidates.length - 1];
  final rate = ratePctPerWeek(start, end); // % per week, signed
  final step = _stepFor(state.kcal);

  if (state.phase == NutritionPhase.loss) {
    final target = state.targetRatePct;
    final lo = target - NUTRITION.lossRatePctPerWeek.tolerance;
    final hi = target + NUTRITION.lossRatePctPerWeek.tolerance;
    final loss = -rate;
    if (loss < lo) {
      return NutritionReviewResult(
        proposals: [
          _calorieProposal(
            state,
            -step,
            "You're losing ${jsNumber(round1(loss))}% of bodyweight per week over $window weeks, below your "
                '${jsNumber(target)}% target (${jsNumber(lo)}–${jsNumber(hi)}%).',
            ['N-ADJ-02'],
            'Alternative: add about 2,500 steps a day (~100 kcal) or up to three 30-minute moderate cardio '
                'sessions a week, kept apart from lifting (N-ADJ-05).',
          ),
        ],
        weeks: weeks,
        notes: notes,
      );
    }
    if (loss > hi) {
      return NutritionReviewResult(
        proposals: [
          _calorieProposal(
            state,
            step,
            "You're losing ${jsNumber(round1(loss))}% per week, faster than your ${jsNumber(target)}% target. "
            'Slower loss protects muscle.',
            ['N-ADJ-02', 'N-RAT-01'],
          ),
        ],
        weeks: weeks,
        notes: notes,
      );
    }
  } else if (state.phase == NutritionPhase.gain) {
    final monthly = rate * 4;
    final [lo, hi] = NUTRITION.gainRatePctPerMonth[state.status]!;
    if (monthly < lo) {
      return NutritionReviewResult(
        proposals: [
          _calorieProposal(
            state,
            step,
            "You're gaining ${jsNumber(round1(monthly))}% per month, below the ${jsNumber(lo)}–${jsNumber(hi)}% "
            'range for a ${state.status.wire} lifter.',
            ['N-ADJ-02', 'N-RAT-02'],
          ),
        ],
        weeks: weeks,
        notes: notes,
      );
    }
    if (monthly > hi) {
      return NutritionReviewResult(
        proposals: [
          _calorieProposal(
            state,
            -step,
            "You're gaining ${jsNumber(round1(monthly))}% per month, above the ${jsNumber(lo)}–${jsNumber(hi)}% "
            'range, so most extra weight would be fat.',
            ['N-ADJ-02', 'N-RAT-02'],
          ),
        ],
        weeks: weeks,
        notes: notes,
      );
    }
  } else {
    final drift = NUTRITION.adjust.maintainDriftPctPerWeek;
    if (rate.abs() > drift) {
      final change = rate > 0 ? -NUTRITION.adjust.maintainStep : NUTRITION.adjust.maintainStep;
      return NutritionReviewResult(
        proposals: [
          _calorieProposal(
            state,
            change,
            'At maintenance your weight drifted ${jsNumber(round1(rate))}% per week over 3 weeks.',
            ['N-ADJ-06'],
          ),
        ],
        weeks: weeks,
        notes: notes,
      );
    }
  }
  notes.add('Your weight trend is on target. No change.');
  return NutritionReviewResult(proposals: [], weeks: weeks, notes: notes);
}
