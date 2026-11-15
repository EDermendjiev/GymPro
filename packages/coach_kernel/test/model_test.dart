// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

typedef _Json = Map<String, dynamic>;

/// What actually reaches a file: encoded and decoded again, so anything that is not plain JSON fails here.
Object? _wire(Object? value) => jsonDecode(jsonEncode(value));

/// Parse and write back, per type name used in `model_values.json`.
final _roundTrips = <String, _Json Function(_Json)>{
  'BlockInput': (j) => BlockInput.fromJson(j).toJson(),
  'BlockPlan': (j) => BlockPlan.fromJson(j).toJson(),
  'CheckinDay': (j) => CheckinDay.fromJson(j).toJson(),
  'DayPlacement': (j) => DayPlacement.fromJson(j).toJson(),
  'ExerciseDef': (j) => ExerciseDef.fromJson(j).toJson(),
  'ExerciseHistory': (j) => ExerciseHistory.fromJson(j).toJson(),
  'ExerciseMuscle': (j) => ExerciseMuscle.fromJson(j).toJson(),
  'ExposureSet': (j) => ExposureSet.fromJson(j).toJson(),
  'History': (j) => History.fromJson(j).toJson(),
  'Injury': (j) => Injury.fromJson(j).toJson(),
  'LoggedSet': (j) => LoggedSet.fromJson(j).toJson(),
  'MuscleTarget': (j) => MuscleTarget.fromJson(j).toJson(),
  'PlannedExercise': (j) => PlannedExercise.fromJson(j).toJson(),
  'PlannedSession': (j) => PlannedSession.fromJson(j).toJson(),
  'PlannedSessionState': (j) => PlannedSessionState.fromJson(j).toJson(),
  'Prescription': (j) => Prescription.fromJson(j).toJson(),
  'PreviousBlockSummary': (j) => PreviousBlockSummary.fromJson(j).toJson(),
  'Proposal': (j) => Proposal.fromJson(j).toJson(),
  'ReviewAutofill': (j) => ReviewAutofill.fromJson(j).toJson(),
  'ScheduleResult': (j) => ScheduleResult.fromJson(j).toJson(),
  'SessionSuggestion': (j) => SessionSuggestion.fromJson(j).toJson(),
  'SetContext': (j) => SetContext.fromJson(j).toJson(),
  'SetSuggestion': (j) => SetSuggestion.fromJson(j).toJson(),
  'StatusInference': (j) => StatusInference.fromJson(j).toJson(),
  'UserSport': (j) => UserSport.fromJson(j).toJson(),
  'Warning': (j) => Warning.fromJson(j).toJson(),
  'WeeklyState': (j) => WeeklyState.fromJson(j).toJson(),
};

/// The same through `copyWith()` with no argument, for the types that have one: the copy must lose nothing.
final _copies = <String, _Json Function(_Json)>{
  'BlockInput': (j) => BlockInput.fromJson(j).copyWith().toJson(),
  'BlockPlan': (j) => BlockPlan.fromJson(j).copyWith().toJson(),
  'CheckinDay': (j) => CheckinDay.fromJson(j).copyWith().toJson(),
  'ExerciseDef': (j) => ExerciseDef.fromJson(j).copyWith().toJson(),
  'ExerciseHistory': (j) => ExerciseHistory.fromJson(j).copyWith().toJson(),
  'History': (j) => History.fromJson(j).copyWith().toJson(),
  'Injury': (j) => Injury.fromJson(j).copyWith().toJson(),
  'LoggedSet': (j) => LoggedSet.fromJson(j).copyWith().toJson(),
  'MuscleTarget': (j) => MuscleTarget.fromJson(j).copyWith().toJson(),
  'PlannedExercise': (j) => PlannedExercise.fromJson(j).copyWith().toJson(),
  'PlannedSession': (j) => PlannedSession.fromJson(j).copyWith().toJson(),
  'PlannedSessionState': (j) => PlannedSessionState.fromJson(j).copyWith().toJson(),
  'Prescription': (j) => Prescription.fromJson(j).copyWith().toJson(),
  'PreviousBlockSummary': (j) => PreviousBlockSummary.fromJson(j).copyWith().toJson(),
  'Proposal': (j) => Proposal.fromJson(j).copyWith().toJson(),
  'ScheduleResult': (j) => ScheduleResult.fromJson(j).copyWith().toJson(),
  'SessionSuggestion': (j) => SessionSuggestion.fromJson(j).copyWith().toJson(),
  'SetContext': (j) => SetContext.fromJson(j).copyWith().toJson(),
  'SetSuggestion': (j) => SetSuggestion.fromJson(j).copyWith().toJson(),
  'UserSport': (j) => UserSport.fromJson(j).copyWith().toJson(),
  'WeeklyState': (j) => WeeklyState.fromJson(j).copyWith().toJson(),
};

void _expectRoundTrip(String type, Object? json) {
  final parse = _roundTrips[type];
  if (parse == null) fail('No round trip registered for the type $type');
  expect(jsonDiff(_wire(parse(json as _Json)), json), isNull);
  final copy = _copies[type];
  if (copy != null) expect(jsonDiff(_wire(copy(json)), json), isNull, reason: 'through copyWith()');
}

void main() {
  final seed = loadFixture('exercises.json').single.output as List;

  group('seed exercise', () {
    for (final e in seed.cast<_Json>()) {
      test(e['id'] as String, () => _expectRoundTrip('ExerciseDef', e));
    }
  });

  group('model value', () {
    final seen = <String>{};
    for (final c in loadFixture('model_values.json')) {
      final type = c.input['type'] as String;
      seen.add(type);
      test(c.name, () => _expectRoundTrip(type, expandSeed(c.output, seed)));
    }

    test('every registered type has a value in the fixture', () {
      // BlockPlan is covered by the plan fixtures below.
      expect(_roundTrips.keys.toSet().difference(seen), {'BlockPlan'});
    });
  });

  // The plan fixtures belong to the training package; here they only prove that the plan types lose nothing.
  for (final file in ['generate_block.json', 'generate_block_extra.json']) {
    group('plan fixture $file', () {
      for (final c in loadFixture(file, root: '../coach_training/test/fixtures')) {
        test('${c.name}, input', () => _expectRoundTrip('BlockInput', expandSeed(c.input, seed)));
        final output = c.output;
        if (output is Map && output.containsKey('threw')) continue;
        test('${c.name}, output', () => _expectRoundTrip('BlockPlan', output));
      }
    });
  }

  group('parsing is strict', () {
    final squat = seed.cast<_Json>().firstWhere((e) => e['id'] == 'back-squat');

    test('an unknown enum value is a FormatException', () {
      expect(() => ExerciseDef.fromJson({...squat, 'category': 'lower_free'}), throwsFormatException);
      expect(() => ExerciseDef.fromJson({...squat, 'mainLiftKey': 'snatch'}), throwsFormatException);
    });

    test('an untracked muscle is rejected where a tracked one is expected', () {
      final target = <String, dynamic>{
        'muscle': 'chest',
        'base': 12,
        'sportTrim': 0,
        'target': 12,
        'trimBySport': <dynamic>[],
        'ruleIds': <dynamic>[],
      };
      expect(MuscleTarget.fromJson(target).muscle, MuscleId.chest);
      expect(() => MuscleTarget.fromJson({...target, 'muscle': 'abs'}), throwsFormatException);
    });

    test('a fraction in a whole-number field is rejected', () {
      expect(() => ExerciseDef.fromJson({...squat, 'popularity': 1.5}), throwsA(isA<TypeError>()));
    });
  });

  group('copies and changes', () {
    test('copyWith replaces only the named fields and shares the rest', () {
      final squat = ExerciseDef.fromJson(seed.cast<_Json>().firstWhere((e) => e['id'] == 'back-squat'));
      final renamed = squat.copyWith(name: 'Squat', popularity: 99);
      expect([renamed.name, renamed.popularity, renamed.id], ['Squat', 99, squat.id]);
      expect(renamed.muscles, same(squat.muscles));
      expect(squat.name, isNot('Squat'));
    });

    test('a planned exercise can be changed in place, including back to null', () {
      final e = PlannedExercise(
        exerciseId: 'back-squat',
        slotKey: 'squat',
        position: 0,
        sets: 3,
        repMin: 4,
        repMax: 8,
        rirMin: 2,
        rirMax: 4,
        restSeconds: 180,
        suggestedLoadKg: 100,
        ruleIds: ['T-INT-03'],
      );
      final copy = e.copyWith(sets: 2);
      e
        ..originalExerciseId = e.exerciseId
        ..exerciseId = 'leg-press'
        ..suggestedLoadKg = null;
      expect(e.toJson(), containsPair('originalExerciseId', 'back-squat'));
      expect(e.toJson().containsKey('suggestedLoadKg'), isFalse);
      expect([copy.sets, copy.exerciseId, copy.suggestedLoadKg], [2, 'back-squat', 100.0]);
      expect(copy, isA<Prescription>());
    });
  });
}
