// SPDX-License-Identifier: GPL-3.0-only
// Weigh-in averages and trend. Rules: N-WGT-01…04.
import 'package:coach_kernel/coach_kernel.dart';

class WeighIn {
  WeighIn({required this.day, required this.kg});

  factory WeighIn.fromJson(Map<String, dynamic> json) =>
      WeighIn(day: json['day'] as String, kg: (json['kg'] as num).toDouble());

  final String day;
  final double kg;

  Map<String, dynamic> toJson() => {'day': day, 'kg': kg};
}

class WeekAverage {
  WeekAverage({
    required this.weekStart,
    required this.avg,
    required this.n,
    required this.hasWeekend,
    required this.lowData,
  });

  factory WeekAverage.fromJson(Map<String, dynamic> json) => WeekAverage(
    weekStart: json['weekStart'] as String,
    avg: (json['avg'] as num).toDouble(),
    n: json['n'] as int,
    hasWeekend: json['hasWeekend'] as bool,
    lowData: json['lowData'] as bool,
  );

  final String weekStart;
  final double avg;
  final int n;
  final bool hasWeekend;
  final bool lowData;

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart,
    'avg': avg,
    'n': n,
    'hasWeekend': hasWeekend,
    'lowData': lowData,
  };
}

/// One point of [runningAverage]: the average of the window that ends on [day].
class DayAverage {
  DayAverage({required this.day, required this.avg});

  factory DayAverage.fromJson(Map<String, dynamic> json) =>
      DayAverage(day: json['day'] as String, avg: (json['avg'] as num).toDouble());

  final String day;
  final double avg;

  Map<String, dynamic> toJson() => {'day': day, 'avg': avg};
}

/// The result of [trendDirection].
enum TrendDirection {
  up('up'),
  down('down'),
  flat('flat'),
  unknown('unknown');

  const TrendDirection(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, TrendDirection> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static TrendDirection fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown TrendDirection: "$wire"'));
}

/// N-WGT-02: weekly averages; a week is reliable with ≥3 weigh-ins including a weekend day.
List<WeekAverage> weeklyAverages(List<WeighIn> weighIns) {
  final byWeek = <String, List<WeighIn>>{};
  for (final w in weighIns) {
    final k = mondayOf(w.day);
    byWeek[k] = [...(byWeek[k] ?? const <WeighIn>[]), w];
  }
  // Week keys are distinct, so the order has no ties.
  return [
    for (final MapEntry(key: weekStart, value: ws) in stableSorted(
      byWeek.entries,
      (a, b) => a.key.compareTo(b.key),
    ))
      () {
        final hasWeekend = ws.any((w) => isWeekend(w.day));
        final lowData =
            ws.length < NUTRITION.weighIns.minPerWeek || (NUTRITION.weighIns.needsWeekendDay && !hasWeekend);
        return WeekAverage(
          weekStart: weekStart,
          avg: jsRound(mean([for (final w in ws) w.kg]) * 100) / 100,
          n: ws.length,
          hasWeekend: hasWeekend,
          lowData: lowData,
        );
      }(),
  ];
}

/// N-WGT-03: running average over the previous [days] days, one point per weigh-in day.
List<DayAverage> runningAverage(List<WeighIn> weighIns, [int? days]) {
  final d = days ?? NUTRITION.weighIns.runningAvgDays[0];
  final sorted = stableSorted(weighIns, (a, b) => a.day.compareTo(b.day));
  return [
    for (final w in sorted)
      () {
        final from = addDays(w.day, -(d - 1));
        final window = [
          for (final x in sorted)
            if (x.day.compareTo(from) >= 0 && x.day.compareTo(w.day) <= 0) x,
        ];
        return DayAverage(day: w.day, avg: jsRound(mean([for (final x in window) x.kg]) * 100) / 100);
      }(),
  ];
}

/// % bodyweight change per week between two weekly averages.
double ratePctPerWeek(WeekAverage from, WeekAverage to) {
  final weeks = daysBetween(from.weekStart, to.weekStart) / 7;
  if (weeks <= 0 || from.avg <= 0) return 0;
  return ((to.avg - from.avg) / from.avg / weeks) * 100;
}

/// Simple trend direction for "hide bodyweight numbers" mode.
TrendDirection trendDirection(List<WeekAverage> weeks) {
  final reliable = [
    for (final w in weeks)
      if (!w.lowData) w,
  ];
  if (reliable.length < 2) return TrendDirection.unknown;
  final r = ratePctPerWeek(reliable[reliable.length - 2], reliable[reliable.length - 1]);
  if (r > 0.15) return TrendDirection.up;
  if (r < -0.15) return TrendDirection.down;
  return TrendDirection.flat;
}
