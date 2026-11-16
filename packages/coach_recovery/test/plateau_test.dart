// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_recovery/coach_recovery.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

import 'seed.dart';

List<LoggedSet> _sets(Object? json) => [for (final s in json as List) LoggedSet.fromJson(s as Map<String, dynamic>)];
List<Point> _points(Object? json) => [for (final p in json as List) Point.fromJson(p as Map<String, dynamic>)];

Object? _call(Map<String, dynamic> i) {
  switch (i['call'] as String) {
    case 'isPlateaued':
      return isPlateaued(
        [for (final p in i['series'] as List) SeriesPoint.fromJson(p as Map<String, dynamic>)],
        Status.fromWire(i['status'] as String),
        i['today'] as String,
      );
    case 'detectPlateaus':
      final state = ProgressState.fromJson(expandSeed(i['state'], seedJson) as Map<String, dynamic>);
      return [for (final p in detectPlateaus(state)) p.toJson()];
    case 'parseRange':
      return parseRange(i['value']).wire;
    case 'constants':
      return {
        'PROGRESS_RANGES': [for (final r in PROGRESS_RANGES) r.wire],
        'DEFAULT_RANGE': DEFAULT_RANGE.wire,
      };
    case 'rangeStart':
      return rangeStart(i['today'] as String, ProgressRange.fromWire(i['range'] as String));
    case 'mainLiftSeries':
      final keys = {
        for (final e in (i['liftKeys'] as Map<String, dynamic>).entries)
          e.key: e.value == null ? null : MainLift.fromWire(e.value as String),
      };
      return [for (final p in mainLiftSeries(_sets(i['sets']), keys, MainLift.fromWire(i['lift'] as String))) p.toJson()];
    case 'exerciseTrend':
      return exerciseTrend(_sets(i['sets'])).toJson();
    case 'adherenceBuckets':
      return [
        for (final b in adherenceBuckets(
          [for (final s in i['sessions'] as List) AdherenceSession.fromJson(s as Map<String, dynamic>)],
          i['from'] as String,
          i['today'] as String,
          AdherenceBucketSize.fromWire(i['bucket'] as String),
        ))
          b.toJson(),
      ];
    case 'liftStallFlags':
      final series = {
        for (final e in (i['series'] as Map<String, dynamic>).entries) MainLift.fromWire(e.key): _points(e.value),
      };
      return [
        for (final f in liftStallFlags(series, Status.fromWire(i['status'] as String), i['today'] as String)) f.toJson(),
      ];
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  final cases = loadFixture('plateau.json', fn: 'plateau');
  for (final c in cases) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }

  test('ProgressState and the result types round-trip through JSON', () {
    for (final c in cases) {
      final out = c.output;
      switch (c.input['call']) {
        case 'detectPlateaus':
          final json = expandSeed(c.input['state'], seedJson) as Map<String, dynamic>;
          expect(jsonDiff(ProgressState.fromJson(json).toJson(), json), isNull);
        case 'exerciseTrend':
          expect(jsonDiff(ExerciseTrend.fromJson(out as Map<String, dynamic>).toJson(), out), isNull);
        case 'adherenceBuckets':
          for (final b in out as List) {
            expect(jsonDiff(AdherenceBucket.fromJson(b as Map<String, dynamic>).toJson(), b), isNull);
          }
          for (final s in c.input['sessions'] as List) {
            expect(jsonDiff(AdherenceSession.fromJson(s as Map<String, dynamic>).toJson(), s), isNull);
          }
        case 'liftStallFlags':
          for (final f in out as List) {
            expect(jsonDiff(StallFlag.fromJson(f as Map<String, dynamic>).toJson(), f), isNull);
          }
        case 'isPlateaued':
          for (final p in c.input['series'] as List) {
            expect(jsonDiff(SeriesPoint.fromJson(p as Map<String, dynamic>).toJson(), p), isNull);
          }
      }
    }
    expect(() => ProgressRange.fromWire('2y'), throwsFormatException);
    expect(() => TrendMetric.fromWire('load'), throwsFormatException);
    expect(() => AdherenceBucketSize.fromWire('day'), throwsFormatException);
  });
}
