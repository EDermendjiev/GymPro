// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_nutrition/coach_nutrition.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

Map<String, dynamic> _map(Object? json) => json as Map<String, dynamic>;
List<T> _list<T>(Object? json, T Function(Map<String, dynamic>) parse) => [
  for (final x in json as List) parse(x as Map<String, dynamic>),
];
Sex? _sex(Object? json) => json == null ? null : Sex.fromWire(json as String);
NutritionPhase _phase(Object? json) => NutritionPhase.fromWire(json as String);
Status _status(Object? json) => Status.fromWire(json as String);

Object? _call(Map<String, dynamic> i) => switch (i['call'] as String) {
  'phaseForGoal' => phaseForGoal(Goal.fromWire(i['goal'] as String)).wire,
  'defaultMultiplier' => defaultMultiplier(Lifestyle.fromWire(i['lifestyle'] as String)),
  'sportFactor' => sportFactor(SportIntensity.fromWire(i['intensity'] as String)),
  'sessionKcalFromRpe' => sessionKcalFromRpe(i['minutes'] as num, i['rpe'] as num, i['kg'] as num),
  'sportKcalPerDay' =>
    i['logs'] == null
        ? sportKcalPerDay(_list(i['sports'], SportForKcal.fromJson), i['kg'] as num)
        : sportKcalPerDay(
            _list(i['sports'], SportForKcal.fromJson),
            i['kg'] as num,
            _list(i['logs'], SportLogForKcal.fromJson),
          ),
  'defaultRatePct' => defaultRatePct(
    _phase(i['phase']),
    _status(i['status']),
    _sex(i['sex']),
    i['bf'] as num?,
  ),
  'isAboveFatThreshold' => isAboveFatThreshold(_sex(i['sex']), i['bf'] as num?),
  'applyKcalChange' => applyKcalChange(MacroTargets.fromJson(_map(i['t'])), i['newKcal'] as int).toJson(),
  'allowedRatePcts' => allowedRatePcts(_phase(i['phase']), _status(i['status'])),
  'rateError' => rateError(_phase(i['phase']), _status(i['status']), i['ratePct'] as num?),
  'buildCutDays' => buildCutDays(_list(i['history'], PhaseSpan.fromJson), i['today'] as String).toJson(),
  'cutRatioWarning' => cutRatioWarning(_list(i['history'], PhaseSpan.fromJson), i['today'] as String),
  'nextAdjustState' => nextAdjustState(
    i['prev'] == null ? null : AdjustState.fromJson(_map(i['prev'])),
    AdjustChange.fromJson(_map(i['change'])),
    i['today'] as String,
  ).toJson(),
  'bodyweightChangedEnough' => bodyweightChangedEnough(i['usedKg'] as num?, i['currentKg'] as num?),
  final other => throw StateError('No case for $other'),
};

void main() {
  for (final c in loadFixture('nutrition_helpers.json', fn: 'nutrition')) {
    test(c.name, () => expect(jsonDiff(_call(c.input), c.output), isNull));
  }

  for (final c in loadFixture('nutrition_targets.json', fn: 'nutritionTargets')) {
    test('nutritionTargets/${c.name}', () {
      final input = NutritionInput.fromJson(c.input);
      expect(jsonDiff(nutritionTargets(input).toJson(), c.output), isNull);
    });
  }

  test('targets and their input survive a JSON round trip', () {
    for (final c in loadFixture('nutrition_targets.json')) {
      final input = NutritionInput.fromJson(c.input);
      expect(jsonDiff(NutritionInput.fromJson(input.toJson()).toJson(), input.toJson()), isNull);
      final t = NutritionTargets.fromJson(c.output as Map<String, dynamic>);
      expect(jsonDiff(t.toJson(), c.output), isNull);
    }
  });

  test('a user sport keeps the fields that set its calories', () {
    final s = SportForKcal.fromUserSport(
      UserSport(
        sportId: 'football',
        name: 'Football',
        lowerBodyLoad: 3,
        upperBodyLoad: 1,
        eccentricImpact: 2,
        conditioning: 3,
        musclesStressed: const [],
        weekdays: const [2, 6],
        intensity: SportIntensity.hard,
        minutes: 90,
      ),
    );
    expect(s.toJson(), {
      'weekdays': [2, 6],
      'minutes': 90,
      'intensity': 'hard',
      'sportId': 'football',
    });
  });
}
