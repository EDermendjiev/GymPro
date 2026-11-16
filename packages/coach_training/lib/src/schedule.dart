// SPDX-License-Identifier: GPL-3.0-only
// Day placement around sports. Rules: T-SCH-02…05, S-03.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';

import 'split.dart';
import 'sports.dart';

int _prevDay(int d) => d == 1 ? 7 : d - 1;
int _nextDay(int d) => d == 7 ? 1 : d + 1;

class ScheduleInput {
  ScheduleInput({
    required this.availableDays,
    required this.templates,
    required this.sports,
    required this.goal,
    this.liftingTime,
  });

  factory ScheduleInput.fromJson(Map<String, dynamic> json) => ScheduleInput(
    availableDays: [for (final x in json['availableDays'] as List) x as int],
    templates: [for (final x in json['templates'] as List) x as String],
    sports: [for (final x in json['sports'] as List) UserSport.fromJson(x as Map<String, dynamic>)],
    goal: Goal.fromWire(json['goal'] as String),
    liftingTime: json['liftingTime'] == null ? null : TimeOfDay.fromWire(json['liftingTime'] as String),
  );

  final List<int> availableDays;

  /// Split session order.
  final List<String> templates;
  final List<UserSport> sports;
  final Goal goal;

  /// Usual lifting time; null = unknown.
  final TimeOfDay? liftingTime;

  Map<String, dynamic> toJson() => {
    'availableDays': [...availableDays],
    'templates': [...templates],
    'sports': [for (final s in sports) s.toJson()],
    'goal': goal.wire,
    if (liftingTime case final liftingTime?) 'liftingTime': liftingTime.wire,
  };
}

const Map<TimeOfDay, int> _TIME_RANK = {TimeOfDay.morning: 0, TimeOfDay.midday: 1, TimeOfDay.evening: 2};

/// The result of [sportBeforeLifting] (`'before' | 'close'` in the reference; null is "fine").
enum SportOrder {
  before('before'),
  close('close');

  const SportOrder(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, SportOrder> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SportOrder fromWire(String wire) => _byWire[wire] ?? (throw FormatException('Unknown SportOrder: "$wire"'));
}

/// T-SCH-03: is a same-day sport session done before (or too close to) lifting?
/// With the lifting time unknown, only a morning sport counts as "before".
/// With both known: an earlier slot is before lifting; the same slot is too close to keep 3 h apart; a later slot is fine.
SportOrder? sportBeforeLifting(TimeOfDay? sportTime, TimeOfDay? liftingTime) {
  if (sportTime == null) return null;
  if (liftingTime == null) return sportTime == TimeOfDay.morning ? SportOrder.before : null;
  final d = _TIME_RANK[sportTime]! - _TIME_RANK[liftingTime]!;
  return d < 0
      ? SportOrder.before
      : d == 0
      ? SportOrder.close
      : null;
}

/// Score one candidate placement. Lower is better.
ScheduleResult scorePlacement(List<DayPlacement> placements, List<UserSport> sports, Goal goal, [TimeOfDay? liftingTime]) {
  final penalties = <SchedulePenalty>[];
  void add(String rule, num points, String detail) =>
      penalties.add(SchedulePenalty(rule: rule, points: points.toDouble(), detail: detail));
  final byDay = {for (final p in placements) p.weekday: p};
  Region region(DayPlacement p) => TEMPLATES[p.templateKey]!.region;

  for (final p in placements) {
    final r = region(p);
    final today = sportsOnDay(sports, p.weekday);
    if (loadsLower(r)) {
      for (final s in sportsOnDay(sports, _nextDay(p.weekday))) {
        if (isLegHeavyHard(s)) add('T-SCH-04', 10, 'Leg session the day before ${s.name}');
      }
      for (final s in sportsOnDay(sports, _prevDay(p.weekday))) {
        if (isLegHeavyHard(s) && s.intensity == SportIntensity.match) {
          add('T-SCH-04', 10, 'Leg session the day after a ${s.name} match');
        }
      }
      for (final s in today) {
        // Heuristic: legs on the same day as a leg-heavy hard sport session is discouraged (not a hard violation).
        if (isLegHeavyHard(s)) add('T-SCH-04', 1, 'Leg session on the same day as ${s.name}');
      }
    }
    for (final s in today) {
      if (s.intensity == SportIntensity.hard || s.intensity == SportIntensity.match) {
        add('T-SCH-03', 4, 'Lifting on the same day as hard ${s.name}');
      } else if (s.intensity == SportIntensity.moderate) {
        add('T-SCH-03', 2, 'Lifting on the same day as ${s.name}');
      }
      final order = sportBeforeLifting(s.timeOfDay, liftingTime);
      if (order == SportOrder.before) {
        add(
          'T-SCH-03',
          3,
          liftingTime != null
              ? '${s.name} is in the ${s.timeOfDay?.wire}, before your ${liftingTime.wire} lifting'
              : '${s.name} is in the morning, before lifting',
        );
      } else if (order == SportOrder.close) {
        add('T-SCH-03', 3, '${s.name} is in the ${s.timeOfDay?.wire}, within a few hours of lifting');
      }
    }
    final prev = byDay[_prevDay(p.weekday)];
    if (prev != null) {
      final same = regionsOverlap(region(prev), r);
      add('T-SCH-06', same ? 3 : 1, same ? 'Back-to-back sessions for the same body region' : 'Back-to-back lifting days');
      if (goal == Goal.strength) {
        final t = TEMPLATES[p.templateKey]!;
        final mainHere = t.slots.where((s) => s.mainLift != null).firstOrNull?.mainLift;
        final prevT = TEMPLATES[prev.templateKey]!;
        final prevMain = prevT.slots.where((s) => s.mainLift != null).firstOrNull?.mainLift;
        if (mainHere != null && same && prevMain != mainHere) {
          add('T-SCH-05', 3, 'Heavy work for the same muscles the day before ${mainHere.wire}');
        }
      }
    }
  }

  // T-SCH-02: at least one full rest day (no lifting, no sport at moderate or harder).
  var restDays = 0;
  for (var d = 1; d <= 7; d++) {
    if (byDay.containsKey(d)) continue;
    if (sportsOnDay(sports, d).any((s) => isHardIntensity(s.intensity))) continue;
    restDays++;
  }
  if (restDays == 0) add('T-SCH-02', 8, 'No full rest day this week');

  // Even spacing between lift days (cyclic week). Equal weekdays are interchangeable, so a plain sort is safe.
  final days = [for (final p in placements) p.weekday]..sort();
  if (days.length > 1) {
    final gaps = [
      for (var i = 0; i < days.length; i++) i == days.length - 1 ? days[0] + 7 - days[i] : days[i + 1] - days[i],
    ];
    final v = variance(gaps);
    if (v > 0) add('SPACING', 0.5 * v, 'Uneven spacing between lifting days');
  }

  final score = jsRound(penalties.fold<double>(0, (a, p) => a + p.points) * 1000) / 1000;
  return ScheduleResult(placements: placements, score: score, penalties: penalties);
}

/// Enumerate every k-combination of available days × every rotation of the split; pick the lowest score.
///
/// Throws an [ArgumentError] when there are fewer distinct available days than sessions.
ScheduleResult placeSessions(ScheduleInput input) {
  final k = input.templates.length;
  final days = uniq(input.availableDays)..sort();
  if (days.length < k) {
    throw ArgumentError('Need $k available days, got ${days.length}');
  }
  ScheduleResult? best;
  List<int> bestTie = const [];
  for (final combo in combinations(days, k)) {
    for (var rot = 0; rot < k; rot++) {
      final order = [...input.templates.sublist(rot), ...input.templates.sublist(0, rot)];
      final placements = [
        for (var i = 0; i < combo.length; i++) DayPlacement(weekday: combo[i], templateKey: order[i]),
      ];
      final res = scorePlacement(placements, input.sports, input.goal, input.liftingTime);
      final tie = [...combo, rot];
      if (best == null ||
          res.score < best.score - 1e-9 ||
          ((res.score - best.score).abs() < 1e-9 && _lexLess(tie, bestTie))) {
        best = res;
        bestTie = tie;
      }
    }
  }
  return best!;
}

bool _lexLess(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return a.length < b.length;
}

/// Warnings when the user moves a session manually (Week view).
List<String> moveWarnings(String templateKey, int weekday, List<UserSport> sports) {
  final region = TEMPLATES[templateKey]?.region ?? Region.full;
  final out = <String>[];
  if (!loadsLower(region)) return out;
  for (final s in sportsOnDay(sports, _nextDay(weekday))) {
    if (isLegHeavyHard(s)) out.add('Legs the day before ${s.name}');
  }
  for (final s in sportsOnDay(sports, _prevDay(weekday))) {
    if (isLegHeavyHard(s) && s.intensity == SportIntensity.match) out.add('Legs the day after a ${s.name} match');
  }
  for (final s in sportsOnDay(sports, weekday)) {
    if (isLegHeavyHard(s)) out.add('Legs on the same day as ${s.name}');
  }
  return out;
}
