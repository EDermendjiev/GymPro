// SPDX-License-Identifier: GPL-3.0-only
// Progress page series: history range, e1RM trends with a high-rep fallback, adherence buckets and
// read-only stall flags. Rules: T-EST-01 (e1RM), T-PRG-06 (plateau window). Pure: no DB, no units.
// ignore_for_file: constant_identifier_names
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

import 'plateau.dart';

/// `ProgressRange` in the reference. The wire strings start with a digit, so the value names spell them out.
enum ProgressRange {
  threeMonths('3m'),
  sixMonths('6m'),
  oneYear('1y'),
  all('all');

  const ProgressRange(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, ProgressRange> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static ProgressRange fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown ProgressRange: "$wire"'));
}

const List<ProgressRange> PROGRESS_RANGES = ProgressRange.values;
const ProgressRange DEFAULT_RANGE = ProgressRange.sixMonths;
const Map<ProgressRange, int> _RANGE_DAYS = {
  ProgressRange.threeMonths: 91,
  ProgressRange.sixMonths: 182,
  ProgressRange.oneYear: 365,
};

ProgressRange parseRange(Object? v) => v is String ? (ProgressRange._byWire[v] ?? DEFAULT_RANGE) : DEFAULT_RANGE;

/// First day shown for a range; null = everything.
String? rangeStart(String today, ProgressRange range) =>
    range == ProgressRange.all ? null : addDays(today, -_RANGE_DAYS[range]!);

class Point {
  Point({required this.x, required this.y});

  factory Point.fromJson(Map<String, dynamic> json) => Point(x: json['x'] as String, y: (json['y'] as num).toDouble());

  final String x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

/// Best e1RM per day across every variation of a main lift (kg, unrounded).
///
/// [mainLiftKeys] maps an exercise id to its main-lift key (the reference takes the exercise objects themselves and
/// reads only that field); an id missing from the map counts as no main lift.
List<Point> mainLiftSeries(List<LoggedSet> sets, Map<String, MainLift?> mainLiftKeys, MainLift lift) {
  final byDay = <String, double>{};
  for (final s in sets) {
    if (s.isWarmup || mainLiftKeys[s.exerciseId] != lift) continue;
    final v = e1rm(s.loadKg, s.reps, s.rir);
    if (v != null) byDay[s.performedOn] = math.max(byDay[s.performedOn] ?? 0, v);
  }
  return [
    for (final e in stableSorted(byDay.entries, (a, b) => a.key.compareTo(b.key))) Point(x: e.key, y: e.value),
  ];
}

enum TrendMetric {
  e1rm('e1rm'),
  volumeLoad('volume_load'),
  reps('reps');

  const TrendMetric(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, TrendMetric> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static TrendMetric fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown TrendMetric: "$wire"'));
}

/// `exerciseTrend`'s result.
class ExerciseTrend {
  ExerciseTrend({required this.metric, required this.points});

  factory ExerciseTrend.fromJson(Map<String, dynamic> json) => ExerciseTrend(
    metric: TrendMetric.fromWire(json['metric'] as String),
    points: [for (final x in json['points'] as List) Point.fromJson(x as Map<String, dynamic>)],
  );

  final TrendMetric metric;
  final List<Point> points;

  Map<String, dynamic> toJson() => {
    'metric': metric.wire,
    'points': [for (final p in points) p.toJson()],
  };
}

/// Trend for one exercise's working sets, one point per day. First-set e1RM when at least half the days have one
/// (T-EST-01 skips sets above 12 effective reps); otherwise volume load (Σ load × reps) for loaded work, or total
/// reps for bodyweight work, so high-rep exercises still get a trend.
ExerciseTrend exerciseTrend(List<LoggedSet> sets) {
  final byDay = <String, List<LoggedSet>>{};
  for (final s in sets) {
    if (!s.isWarmup) byDay[s.performedOn] = [...?byDay[s.performedOn], s];
  }
  final days = [
    for (final e in stableSorted(byDay.entries, (a, b) => a.key.compareTo(b.key)))
      (e.key, stableSorted<LoggedSet>(e.value, (a, b) => a.setIndex - b.setIndex)),
  ];
  final withE1rm = [
    for (final (x, ss) in days)
      if (e1rm(ss[0].loadKg, ss[0].reps, ss[0].rir) case final y?) Point(x: x, y: y),
  ];
  if (days.isNotEmpty && withE1rm.length * 2 >= days.length) {
    return ExerciseTrend(metric: TrendMetric.e1rm, points: withE1rm);
  }
  final loaded = sets.any((s) => !s.isWarmup && (s.loadKg ?? 0) > 0);
  return ExerciseTrend(
    metric: loaded ? TrendMetric.volumeLoad : TrendMetric.reps,
    points: [
      for (final (x, ss) in days)
        Point(x: x, y: ss.fold<double>(0, (a, s) => a + (loaded ? (s.loadKg ?? 0) * s.reps : s.reps))),
    ],
  );
}

class AdherenceBucket {
  AdherenceBucket({required this.week, required this.done, required this.planned});

  factory AdherenceBucket.fromJson(Map<String, dynamic> json) =>
      AdherenceBucket(week: json['week'] as String, done: json['done'] as int, planned: json['planned'] as int);

  /// Bucket start (Monday or 1st of month).
  final String week;
  int done;
  int planned;

  Map<String, dynamic> toJson() => {'week': week, 'done': done, 'planned': planned};
}

/// One entry of `adherenceBuckets`' sessions: a scheduled day and its status (the database row's field names).
class AdherenceSession {
  AdherenceSession({required this.scheduledOn, required this.status});

  factory AdherenceSession.fromJson(Map<String, dynamic> json) =>
      AdherenceSession(scheduledOn: json['scheduled_on'] as String, status: json['status'] as String);

  final String scheduledOn;
  final String status;

  Map<String, dynamic> toJson() => {'scheduled_on': scheduledOn, 'status': status};
}

/// `adherenceBuckets`' bucket size.
enum AdherenceBucketSize {
  week('week'),
  month('month');

  const AdherenceBucketSize(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, AdherenceBucketSize> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static AdherenceBucketSize fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown AdherenceBucketSize: "$wire"'));
}

/// Sessions done vs planned per week (short ranges) or per month (long ranges), from `from` up to this week.
List<AdherenceBucket> adherenceBuckets(
  List<AdherenceSession> sessions,
  String from,
  String today,
  AdherenceBucketSize bucket,
) {
  String keyOf(String d) => bucket == AdherenceBucketSize.week ? mondayOf(d) : '${d.substring(0, 7)}-01';
  final out = <String, AdherenceBucket>{};
  for (var k = keyOf(from);
      k.compareTo(keyOf(today)) <= 0;
      k = bucket == AdherenceBucketSize.week ? addDays(k, 7) : _nextMonth(k)) {
    out[k] = AdherenceBucket(week: k, done: 0, planned: 0);
  }
  for (final s in sessions) {
    final b = out[keyOf(s.scheduledOn)];
    if (b == null) continue;
    b.planned++;
    if (s.status == 'done') b.done++;
  }
  return [...out.values];
}

String _nextMonth(String firstOfMonth) {
  final [y, m, ...] = [for (final p in firstOfMonth.split('-')) int.parse(p)];
  return m == 12 ? '${y + 1}-01-01' : '$y-${'${m + 1}'.padLeft(2, '0')}-01';
}

class StallFlag {
  StallFlag({required this.lift, required this.stalled, required this.exposures, required this.lastPrOn});

  factory StallFlag.fromJson(Map<String, dynamic> json) => StallFlag(
    lift: MainLift.fromWire(json['lift'] as String),
    stalled: json['stalled'] as bool,
    exposures: json['exposures'] as int,
    lastPrOn: json['lastPrOn'] as String?,
  );

  final MainLift lift;
  final bool stalled;
  final int exposures;
  final String? lastPrOn;

  Map<String, dynamic> toJson() => {'lift': lift.wire, 'stalled': stalled, 'exposures': exposures, 'lastPrOn': lastPrOn};
}

/// Read-only stall flag per main lift with the weekly review's plateau test (isPlateaued, T-PRG-06) on the pooled
/// best-e1RM series. The weekly review still owns the follow-up proposals.
List<StallFlag> liftStallFlags(Map<MainLift, List<Point>> series, Status status, String today) => [
  for (final MapEntry(key: lift, value: pts) in series.entries)
    if (pts.isNotEmpty) _stallFlag(lift, pts, status, today),
];

StallFlag _stallFlag(MainLift lift, List<Point> pts, Status status, String today) {
  var best = double.negativeInfinity;
  String? lastPrOn;
  for (final p in pts) {
    if (p.y > best + 1e-9) (best, lastPrOn) = (p.y, p.x);
  }
  return StallFlag(
    lift: lift,
    stalled: isPlateaued([for (final p in pts) SeriesPoint(date: p.x, v: p.y)], status, today),
    exposures: pts.length,
    lastPrOn: lastPrOn,
  );
}
