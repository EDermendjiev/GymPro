// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

List<UserSport> _sports(Object? json) => [
  for (final s in json as List) UserSport.fromJson(s as Map<String, dynamic>),
];
TimeOfDay? _time(Object? json) => json == null ? null : TimeOfDay.fromWire(json as String);

Object? _call(Map<String, dynamic> i) {
  switch (i['call'] as String) {
    case 'sportBeforeLifting':
      return sportBeforeLifting(_time(i['sportTime']), _time(i['liftingTime']))?.wire;
    case 'scorePlacement':
      final placements = [
        for (final p in i['placements'] as List) DayPlacement.fromJson(p as Map<String, dynamic>),
      ];
      return scorePlacement(
        placements,
        _sports(i['sports']),
        Goal.fromWire(i['goal'] as String),
        _time(i['liftingTime']),
      ).toJson();
    case 'placeSessions':
      final input = ScheduleInput.fromJson(i['input'] as Map<String, dynamic>);
      expect(jsonDiff(input.toJson(), i['input']), isNull);
      try {
        return placeSessions(input).toJson();
      } on ArgumentError catch (e) {
        return {'threw': e.message};
      }
    case 'moveWarnings':
      return moveWarnings(i['templateKey'] as String, i['weekday'] as int, _sports(i['sports']));
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  for (final c in loadFixture('schedule.json', fn: 'schedule')) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }

  test('SportOrder parses its wire strings', () {
    for (final o in SportOrder.values) {
      expect(SportOrder.fromWire(o.wire), o);
    }
    expect(() => SportOrder.fromWire('after'), throwsFormatException);
  });
}
