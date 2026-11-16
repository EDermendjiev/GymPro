// SPDX-License-Identifier: GPL-3.0-only
// Task 6.2: the weigh-in review in coachTick. Fixtures G10–G12 of the nutrition package, seeded into the app's
// weigh-ins and the coach's nutrition state, give the same proposals through fit; applying one moves the coach's
// goals.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _case(String prefix) {
  final json = jsonDecode(File('packages/coach_nutrition/test/fixtures/nutrition_review.json').readAsStringSync());
  return [
    for (final c in (json as Map)['cases'] as List)
      if (((c as Map)['name'] as String).startsWith(prefix)) c.cast<String, dynamic>(),
  ].single;
}

const _goalFor = {'gain': 'lean_gain', 'maintain': 'recomp', 'loss': 'fat_loss'};

/// Seeds fit so that the weigh-in review's input equals fixture [input]: the weigh-ins as the app's, the phase,
/// its start, the activity factor, the target rate and the cadence in `coach.nutrition`, and a calorie offset that
/// brings the coach's target to the fixture's.
void _arrange(Map<String, dynamic> input) {
  fit.coachClock = () => DateTime.parse(input['today'] as String).add(const Duration(hours: 9));
  fit.profile.sex = 'male';
  fit.profile.activity = 1.55;
  for (final w in input['weighIns'] as List) {
    fit.bodyweight.add(BodyweightEntry(DateTime.parse(w['day'] as String).add(const Duration(hours: 7)), (w['kg'] as num).toDouble()));
  }
  if (fit.bodyweight.isEmpty) fit.profile.weightKg = (input['bodyweightKg'] as num).toDouble();
  final phase = input['phase'] as String;
  final nutrition = {
    'phase': phase,
    'phaseFor': phase,
    'phaseStartedOn': input['phaseStartedOn'],
    'multiplier': input['multiplier'],
    'targetRatePct': input['targetRatePct'],
    'initialAdjustDone': input['initialAdjustDone'] ?? false,
    'lastAdjustOn': ?input['lastAdjustedOn'],
  };
  fit.coach = CoachData.fromJson({
    'on': {'nutrition': true},
    'profile': {
      'goal': _goalFor[phase],
      'status': input['status'],
      'days': [1, 3, 5],
      'minutes': 60,
      'priority': 'lifting',
      'lifestyle': 'active',
    },
    'nutrition': nutrition,
    'review': {'askFirst': true},
  });
  final base = fit.coachNutritionTargets!.kcal;
  fit.coach = fit.coach.copyWith(nutrition: {...nutrition, 'kcalOffset': (input['kcal'] as int) - base});
  expect(fit.coachNutritionTargets!.kcal, input['kcal']);
}

List<Map<String, dynamic>> _got() => [
      for (final p in fit.coachProposals) {'kind': p.kind.wire, 'title': p.title, 'payload': p.payload},
    ];

List<Map<String, dynamic>> _want(Map<String, dynamic> c) => [
      for (final p in c['output']['proposals'] as List) {'kind': p['kind'], 'title': p['title'], 'payload': p['payload']},
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  tearDown(() => fit.coachClock = DateTime.now);

  test('G10: two weigh-ins last week: nothing is proposed, and the card says why', () {
    final c = _case('G10');
    _arrange(c['input'] as Map<String, dynamic>);
    fit.coachTick();
    expect(_got(), isEmpty);
    expect(fit.coachNutritionNote, (c['output']['notes'] as List).first);
  });

  test('G11: a gain phase whose first week went down proposes a higher activity factor; applying it moves the goals',
      () {
    final c = _case('G11');
    _arrange(c['input'] as Map<String, dynamic>);
    final before = fit.coachNutritionTargets!.kcal;
    fit.coachTick();
    expect(jsonEncode(_got()), jsonEncode(_want(c)));
    final p = fit.coachProposals.single;
    expect(coachTierFor(p.kind), CoachAutonomyTier.ask);
    expect(p.state, CoachProposalState.pending);
    expect(fit.coachNutritionNote, isNull);
    fit.applyCoachProposal(p.id);
    expect(fit.coach.nutrition['multiplier'], 1.85);
    expect(fit.coach.nutrition['initialAdjustDone'], isTrue);
    expect(fit.coach.nutrition['lastAdjustOn'], '2026-10-19');
    expect(fit.coachNutritionTargets!.kcal, greaterThan(before));
    expect(fit.suggestedGoals.kcal, fit.coachNutritionTargets!.kcal);
  });

  test('G12: a cut losing too slowly proposes 150 kcal less; applying it takes the goals there', () {
    final c = _case('G12');
    _arrange(c['input'] as Map<String, dynamic>);
    fit.coachTick();
    expect(jsonEncode(_got()), jsonEncode(_want(c)));
    fit.applyCoachProposal(fit.coachProposals.single.id);
    expect(fit.coachNutritionTargets!.kcal, 2050);
    expect(fit.suggestedGoals.kcal, 2050);
    // Undo puts the calories back.
    fit.undoCoachProposal(fit.coachProposals.single.id);
    expect(fit.coachNutritionTargets!.kcal, 2200);
  });

  test('the review runs once a week, and not while the user\'s own goals are set', () {
    final c = _case('G12');
    _arrange(c['input'] as Map<String, dynamic>);
    fit.nutritionGoalsSet = true;
    fit.coachTick();
    expect(_got(), isEmpty);
    fit.nutritionGoalsSet = false;
    fit.coachTick();
    expect(_got(), hasLength(1));
    fit.dismissCoachProposal(fit.coachProposals.single.id);
    fit.coachTick();
    expect(_got(), hasLength(1));
  });

  test('a new phase starts the cadence over', () {
    final c = _case('G12');
    _arrange(c['input'] as Map<String, dynamic>);
    fit.setCoachNutritionPhase(CoachNutritionPhase.maintain);
    fit.coachTick();
    expect(fit.coach.nutrition['phaseStartedOn'], '2026-10-26');
    expect(fit.coach.nutrition['initialAdjustDone'], isFalse);
  });
}
