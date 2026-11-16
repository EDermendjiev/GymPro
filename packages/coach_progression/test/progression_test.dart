// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

List<Exposure> _exposures(Object? json) => [
  for (final e in json as List) Exposure.fromJson(e as Map<String, dynamic>),
];

Object? _call(Map<String, dynamic> i) {
  switch (i['call'] as String) {
    case 'constants':
      return {
        'EXPECTED_SESSIONS_PER_LOAD_JUMP': {
          for (final e in EXPECTED_SESSIONS_PER_LOAD_JUMP.entries) e.key.wire: e.value,
        },
        'LOAD_PACE_STALL_FACTOR': LOAD_PACE_STALL_FACTOR,
      };
    case 'suggestNextSet':
      return suggestNextSet(SetContext.fromJson(i['ctx'] as Map<String, dynamic>)).toJson();
    case 'suggestNextSession':
      return suggestNextSession(
        ExerciseHistory.fromJson(i['history'] as Map<String, dynamic>),
        SetRx.fromJson(i['rx'] as Map<String, dynamic>),
      ).toJson();
    case 'nudgeLoad':
      return nudgeLoad(i['load'] as num?, i['increment'] as num, i['dir'] as int);
    case 'sessionsAtLoad':
      return sessionsAtLoad(_exposures(i['exposures']));
    case 'loadPace':
      return loadPace(_exposures(i['exposures']), Status.fromWire(i['status'] as String)).toJson();
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  for (final c in loadFixture('progression.json', fn: 'progression')) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }
}
