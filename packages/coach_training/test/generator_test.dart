// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

List<LoggedSet> _sets(Object? json) => [
  for (final s in json as List) LoggedSet.fromJson(s as Map<String, dynamic>),
];

Object? _call(Map<String, dynamic> i, List<Object?> seedJson, Map<String, HasMuscles> byId) {
  switch (i['call'] as String) {
    case 'constants':
      return {
        'EQUIPMENT_PRESETS': {
          for (final e in EQUIPMENT_PRESETS.entries) e.key.wire: [for (final q in e.value) q.wire],
        },
      };
    case 'generateSession':
      final json = expandSeed(i['input'], seedJson) as Map<String, dynamic>;
      final input = GeneratorInput.fromJson(json);
      expect(jsonDiff(input.toJson(), json), isNull);
      return generateSession(input).toJson();
    case 'setsInLast48h':
      return [
        for (final s in setsInLast48h(
          _sets(i['sets']),
          DateTime.parse(i['now'] as String),
          i['today'] as String,
        ))
          s.toJson(),
      ];
    case 'trainedLast48h':
      expect(i['exercises'], '@seed');
      final r = trainedLast48h(
        _sets(i['sets']),
        byId,
        DateTime.parse(i['now'] as String),
        i['today'] as String,
      );
      return {for (final e in r.entries) e.key.wire: e.value};
    case 'checkinSoreness':
      final checkins = [
        for (final c in i['checkins'] as List) SorenessCheckin.fromJson(c as Map<String, dynamic>),
      ];
      expect(jsonDiff([for (final c in checkins) c.toJson()], i['checkins']), isNull);
      return checkinSoreness(checkins, i['today'] as String).toJson();
    case 'blockWeekIndex':
      return blockWeekIndex(i['weekStart'] as String, i['blockStart'] as String, i['weeks'] as int);
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  final seedJson =
      loadFixture('exercises.json', root: '../coach_kernel/test/fixtures').single.output as List<Object?>;
  final byId = <String, HasMuscles>{
    for (final e in seedJson) (e as Map<String, dynamic>)['id'] as String: ExerciseDef.fromJson(e),
  };

  for (final c in loadFixture('generate_session.json', fn: 'generator')) {
    test(c.name, () => expect(jsonDiff(_call(c.input, seedJson, byId), c.output), isNull));
  }

  test('the result types round-trip', () {
    for (final c in loadFixture('generate_session.json').where((c) => c.input['call'] == 'generateSession')) {
      final out = c.output as Map<String, dynamic>;
      expect(jsonDiff(GeneratedSession.fromJson(out).toJson(), out), isNull);
    }
    final soreness = CheckinSoreness(pain: [MuscleId.chest], sore: [MuscleId.quads]).toJson();
    expect(jsonDiff(CheckinSoreness.fromJson(soreness).toJson(), soreness), isNull);
    expect(() => Focus.fromJson('legs'), throwsFormatException);
    expect(() => Readiness.fromWire('fresh'), throwsFormatException);
    expect(() => EquipmentPreset.fromWire('home'), throwsFormatException);
  });

  test('the 48 h window reads a timestamp without a zone as UTC', () {
    LoggedSet set(String loggedAt) => LoggedSet(
      exerciseId: 'bench-press',
      performedOn: '2026-10-27',
      setIndex: 0,
      loadKg: 60,
      reps: 8,
      rir: 2,
      isWarmup: false,
      loggedAt: loggedAt,
    );
    final now = DateTime.utc(2026, 10, 28, 18);
    final sets = [
      set('2026-10-26T18:00:00'),
      set('2026-10-26T17:59:59'),
      set('2026-10-27'),
      set('not a date'),
    ];
    expect(
      [for (final s in setsInLast48h(sets, now, '2026-10-28')) s.loggedAt],
      ['2026-10-26T18:00:00', '2026-10-27'],
    );
  });
}
