// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_nutrition/coach_nutrition.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

List<WeighIn> _weighIns(Object? json) => [
  for (final w in json as List) WeighIn.fromJson(w as Map<String, dynamic>),
];
List<WeekAverage> _weeks(Object? json) => [
  for (final w in json as List) WeekAverage.fromJson(w as Map<String, dynamic>),
];
WeekAverage _week(Object? json) => WeekAverage.fromJson(json as Map<String, dynamic>);

Object? _call(Map<String, dynamic> i) => switch (i['call'] as String) {
  'weeklyAverages' => [for (final w in weeklyAverages(_weighIns(i['weighIns']))) w.toJson()],
  'runningAverage' => [
    for (final p in runningAverage(_weighIns(i['weighIns']), i['days'] as int?)) p.toJson(),
  ],
  'ratePctPerWeek' => ratePctPerWeek(_week(i['from']), _week(i['to'])),
  'trendDirection' => trendDirection(_weeks(i['weeks'])).wire,
  final other => throw StateError('No case for $other'),
};

void main() {
  for (final c in loadFixture('trend.json', fn: 'trend')) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }

  test('a trend direction reads back from its wire value', () {
    for (final d in TrendDirection.values) {
      expect(TrendDirection.fromWire(d.wire), d);
    }
    expect(() => TrendDirection.fromWire('sideways'), throwsFormatException);
  });
}
