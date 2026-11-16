// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

List<UserSport> _sports(Object? json) => [
  for (final s in json as List) UserSport.fromJson(s as Map<String, dynamic>),
];

Object? _call(Map<String, dynamic> i, List<Object?> seed) {
  BlockInput input() => BlockInput.fromJson(expandSeed(i['input'], seed) as Map<String, dynamic>);
  BlockKind kind() => BlockKind.fromWire(i['kind'] as String);
  switch (i['call'] as String) {
    case 'constants':
      return {
        'SPORT_SEEDS': [for (final s in SPORT_SEEDS) s.toJson()],
      };
    case 'isHardIntensity':
      return isHardIntensity(SportIntensity.fromWire(i['intensity'] as String));
    case 'hardSportSessionsPerWeek':
      return hardSportSessionsPerWeek(_sports(i['sports']));
    case 'sportTrims':
      return sportTrims(_sports(i['sports'])).toJson();
    case 'sportsOnDay':
      return [for (final s in sportsOnDay(_sports(i['sports']), i['weekday'] as int)) s.toJson()];
    case 'isLegHeavyHard':
      return isLegHeavyHard(UserSport.fromJson(i['sport'] as Map<String, dynamic>));
    case 'baseVolume':
      return baseVolume(input(), kind()).toJson();
    case 'computeTargets':
      return computeTargets(input(), kind()).toJson();
    case 'targetsMap':
      final targets = [
        for (final t in i['targets'] as List) MuscleTarget.fromJson(t as Map<String, dynamic>),
      ];
      return {for (final e in targetsMap(targets).entries) e.key.wire: e.value};
    case 'weeklyTargetFor':
      return weeklyTargetFor(kind(), i['target'] as num, i['weekIndex'] as int);
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  final seed =
      loadFixture('exercises.json', root: '../coach_kernel/test/fixtures').single.output as List<Object?>;

  for (final c in loadFixture('volume.json', fn: 'volume')) {
    test(c.name, () => expect(jsonDiff(_call(c.input, seed), c.output), isNull));
  }

  test('SportSeed and the result types round-trip', () {
    for (final s in SPORT_SEEDS) {
      expect(jsonDiff(SportSeed.fromJson(s.toJson()).toJson(), s.toJson()), isNull);
    }
    final trim = sportTrims([
      UserSport.fromJson({
        'sportId': 'x',
        'name': 'X',
        'lowerBodyLoad': 3,
        'upperBodyLoad': 1,
        'eccentricImpact': 0,
        'conditioning': 0,
        'musclesStressed': ['quads', 'chest'],
        'weekdays': [1, 2],
        'intensity': 'hard',
        'minutes': 60,
      }),
    ]).toJson();
    expect(jsonDiff(SportTrim.fromJson(trim).toJson(), trim), isNull);
    final c = loadFixture('volume.json').firstWhere((c) => c.input['call'] == 'computeTargets');
    final result = c.output as Map<String, dynamic>;
    expect(jsonDiff(TargetResult.fromJson(result).toJson(), result), isNull);
    final b =
        loadFixture('volume.json').firstWhere((c) => c.input['call'] == 'baseVolume').output
            as Map<String, dynamic>;
    expect(jsonDiff(BaseVolume.fromJson(b).toJson(), b), isNull);
  });
}
