// SPDX-License-Identifier: GPL-3.0-only
// Phase 6, the nutrition module, driven through the app's state.
import 'dart:convert';
import 'dart:io';

import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/adapters/nutrition_adapter.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/nutrition.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The `nutritionTargets` fixture case whose name starts with [prefix].
Map<String, dynamic> _case(String prefix) {
  final json = jsonDecode(File('packages/coach_nutrition/test/fixtures/nutrition_targets.json').readAsStringSync());
  return [
    for (final c in (json as Map)['cases'] as List)
      if (((c as Map)['name'] as String).startsWith(prefix)) c.cast<String, dynamic>(),
  ].single;
}

/// The app's activity choice that maps onto each coach activity band, by rank.
const _activity = {'sedentary': 1.2, 'lightly_active': 1.375, 'active': 1.55, 'very_active': 1.725};

/// The activity multipliers the app's profile screen offers, read from its source.
List<double> _screenChoices() => [
      for (final m in RegExp(r"_act\(gc, t\.activityName\('\w+'\), ([\d.]+)\)")
          .allMatches(File('lib/screens/settings_screen.dart').readAsStringSync()))
        double.parse(m.group(1)!),
    ];

/// A sport as `coach.sports` stores it, with the fields the calorie calculation reads taken from [s].
Map<String, dynamic> _sport(Map s, int i) => {
      'sportId': 'sport$i',
      'name': 'Sport $i',
      'lowerBodyLoad': 2,
      'upperBodyLoad': 1,
      'eccentricImpact': 2,
      'conditioning': 2,
      'musclesStressed': <String>[],
      'weekdays': s['weekdays'],
      'intensity': s['intensity'],
      'minutes': s['minutes'],
    };

const _goalFor = {'gain': 'lean_gain', 'maintain': 'recomp', 'loss': 'fat_loss'};

/// Sets the app and the coach up so that the coach's input equals fixture [input], with the nutrition module on:
/// the weight as the latest weigh-in, the sex and activity in the app profile, the status and goal in a coaching
/// profile, and the sports.
void _arrange(Map<String, dynamic> input) {
  fit.profile.sex = input['sex'] as String;
  fit.profile.activity = _activity[input['lifestyle']]!;
  fit.bodyweight.add(BodyweightEntry(DateTime(2026, 11, 1, 8), (input['bodyweightKg'] as num).toDouble()));
  fit.coach = CoachData.fromJson({
    'on': {'nutrition': true},
    'profile': {
      'goal': _goalFor[input['phase']],
      'status': input['status'],
      'days': [1, 3, 5],
      'minutes': 60,
      'priority': 'lifting',
      'lifestyle': input['lifestyle'],
    },
    'sports': [
      for (final (i, s) in (input['sports'] as List).indexed) _sport(s as Map, i),
    ],
  });
}

void _expectMacros(NutritionGoals g, Map<String, dynamic> out, {String? reason}) {
  expect(
    [g.kcal, g.protein, g.fat, g.carbs],
    [out['kcal'], (out['proteinG'] as num).round(), (out['fatG'] as num).round(), (out['carbsG'] as num).round()],
    reason: reason,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  group('6.1 coach goals', () {
    test('golden profile G1 through fit.suggestedGoals', () {
      final g1 = _case('G1:');
      _arrange(g1['input'] as Map<String, dynamic>);
      _expectMacros(fit.suggestedGoals, g1['output'] as Map<String, dynamic>);
      final c = fit.coachNutritionTargets!;
      expect(c.phase, CoachNutritionPhase.gain);
      expect(c.phasePicked, isFalse);
      expect(c.maintenance, g1['output']['maintenance']);
      expect(c.delta, g1['output']['delta']);
      expect(c.ruleIds, g1['output']['ruleIds']);
    });

    test('the latest weigh-in wins over the profile weight, and the profile weight is the fallback', () {
      final g1 = _case('G1:');
      final input = g1['input'] as Map<String, dynamic>;
      _arrange(input);
      fit.bodyweight.clear();
      fit.profile.weightKg = (input['bodyweightKg'] as num).toDouble();
      _expectMacros(fit.suggestedGoals, g1['output'] as Map<String, dynamic>);
      fit.bodyweight.add(BodyweightEntry(DateTime(2026, 10, 1), 90));
      fit.bodyweight.add(BodyweightEntry(DateTime(2026, 11, 2), 72));
      fit.profile.weightKg = 90;
      _expectMacros(fit.suggestedGoals, g1['output'] as Map<String, dynamic>);
    });

    test('with only the switch on: maintain, novice, and no sports', () {
      final m = _case('matrix/maintain/novice/male');
      final input = m['input'] as Map<String, dynamic>;
      fit.profile.sex = 'male';
      fit.profile.activity = 1.2; // the app's Sedentary
      fit.bodyweight.add(BodyweightEntry(DateTime(2026, 11, 1), (input['bodyweightKg'] as num).toDouble()));
      fit.setCoachModule(CoachModule.nutrition, true);
      expect(fit.coach.profile, isNull);
      _expectMacros(fit.suggestedGoals, m['output'] as Map<String, dynamic>);
      expect(fit.coachNutritionTargets!.phase, CoachNutritionPhase.maintain);
    });

    test('the phase follows the coaching goal when the user has not picked one', () {
      for (final (goal, phase) in [
        ('lean_gain', CoachNutritionPhase.gain),
        ('fat_loss', CoachNutritionPhase.loss),
        ('recomp', CoachNutritionPhase.maintain),
        ('strength', CoachNutritionPhase.maintain),
      ]) {
        fit.coach = CoachData.fromJson({
          'on': {'nutrition': true},
          'profile': {
            'goal': goal,
            'status': 'novice',
            'days': [1, 3, 5],
            'minutes': 60,
            'priority': 'lifting',
            'lifestyle': 'sedentary',
          },
        });
        expect(fit.coachNutritionTargets!.phase, phase, reason: goal);
      }
    });

    test('module off: the suggested goals are the app\'s own, whatever the coach holds', () {
      expect(fit.coachNutritionTargets, isNull, reason: 'off by default');
      _arrange(_case('G1:')['input'] as Map<String, dynamic>);
      final on = fit.suggestedGoals.toJson();
      fit.setCoachModule(CoachModule.nutrition, false);
      expect(fit.coachNutritionTargets, isNull);
      final off = fit.suggestedGoals.toJson();
      expect(off, isNot(on), reason: 'the coach supplied the goals while on');
      // The same app inputs without any coach data give exactly the same goals.
      fit.coach = CoachData.empty();
      expect(fit.suggestedGoals.toJson(), off);
      // And they are the app's own formula: protein 1.8 g/kg without a weight goal.
      expect(fit.suggestedGoals.protein, (72 * 1.8).round());
    });

    test('water, fibre, sugar, sodium and glass size keep the app\'s formulas', () {
      _arrange(_case('G1:')['input'] as Map<String, dynamic>);
      final on = fit.suggestedGoals;
      fit.setCoachModule(CoachModule.nutrition, false);
      final off = fit.suggestedGoals;
      expect([on.waterMl, on.fiber, on.sugar, on.sodium, on.glassMl],
          [off.waterMl, off.fiber, off.sugar, off.sodium, off.glassMl]);
      expect(on.kcal, isNot(off.kcal));
    });

    test('manually set goals win over the coach', () {
      _arrange(_case('G1:')['input'] as Map<String, dynamic>);
      const own = NutritionGoals(kcal: 2000, protein: 150, carbs: 200, fat: 60);
      expect(fit.activeGoals.kcal, 3100);
      fit.setNutritionGoals(own);
      expect(fit.activeGoals.toJson(), own.toJson());
      expect(fit.goalsFor(DateTime(2026, 11, 3)).kcal, 2000);
      expect(fit.suggestedGoals.kcal, 3100, reason: 'the suggestion is still the coach\'s');
      fit.persistNow();
      fit.loadFromStore();
      expect(fit.activeGoals.toJson(), own.toJson());
    });

    test("the app's activity choices are the ones the profile screen offers", () {
      expect(_screenChoices(), [1.2, 1.375, 1.55, 1.725]);
      expect(coachActivityChoices, _screenChoices());
    });

    test('each app activity choice maps to a coach band by rank', () {
      expect(coachLifestyleFor(1.2), ck.Lifestyle.sedentary, reason: 'Sedentary');
      expect(coachLifestyleFor(1.375), ck.Lifestyle.lightlyActive, reason: 'Light');
      expect(coachLifestyleFor(1.55), ck.Lifestyle.active, reason: 'Moderate');
      expect(coachLifestyleFor(1.725), ck.Lifestyle.veryActive, reason: 'Active');
    });

    test('values off the choices take the band of the nearer choice', () {
      expect(coachLifestyleFor(0), ck.Lifestyle.sedentary, reason: 'below the first choice');
      expect(coachLifestyleFor(1.1), ck.Lifestyle.sedentary, reason: 'below the first choice');
      expect(coachLifestyleFor(1.9), ck.Lifestyle.veryActive, reason: 'above the last choice');
      expect(coachLifestyleFor(3), ck.Lifestyle.veryActive, reason: 'above the last choice');
      expect(coachLifestyleFor(1.25), ck.Lifestyle.sedentary);
      expect(coachLifestyleFor(1.33), ck.Lifestyle.lightlyActive);
      expect(coachLifestyleFor(1.5), ck.Lifestyle.active);
      expect(coachLifestyleFor(1.65), ck.Lifestyle.veryActive);
      expect(coachLifestyleFor(1.6375), ck.Lifestyle.veryActive, reason: 'a tie goes to the more active band');
    });

    test('the activity band reaches the targets through fit', () {
      final g1 = _case('G1:');
      _arrange(g1['input'] as Map<String, dynamic>);
      int kcalAt(double activity) {
        fit.profile.activity = activity;
        return fit.suggestedGoals.kcal;
      }

      // G1 is lightly active: the app's Light.
      expect(kcalAt(1.375), g1['output']['kcal']);
      final byChoice = [for (final a in [1.2, 1.375, 1.55, 1.725]) kcalAt(a)];
      expect(byChoice, [...byChoice]..sort(), reason: 'more active, more calories');
      expect(byChoice.toSet(), hasLength(4));
    });
  });

  group('6.3 the phase picker', () {
    test('a picked phase replaces the goal\'s phase and survives a restart', () {
      final g1 = _case('G1:');
      _arrange(g1['input'] as Map<String, dynamic>);
      expect(fit.coachNutritionTargets!.phase, CoachNutritionPhase.gain);
      fit.setCoachNutritionPhase(CoachNutritionPhase.loss);
      var c = fit.coachNutritionTargets!;
      expect((c.phase, c.phasePicked), (CoachNutritionPhase.loss, true));
      expect(c.delta, lessThan(0));
      final lossKcal = fit.suggestedGoals.kcal;
      expect(lossKcal, lessThan(g1['output']['kcal'] as int));

      fit.persistNow();
      fit.coach = CoachData.empty();
      fit.loadFromStore();
      expect(fit.coach.nutrition['phase'], 'loss');
      c = fit.coachNutritionTargets!;
      expect((c.phase, c.phasePicked), (CoachNutritionPhase.loss, true));
      expect(fit.suggestedGoals.kcal, lossKcal);
      expect(fit.coach.toJson()['nutrition'], {'phase': 'loss'});
    });

    test('a picked phase works without a coaching profile', () {
      fit.setCoachModule(CoachModule.nutrition, true);
      fit.setCoachNutritionPhase(CoachNutritionPhase.gain);
      expect(fit.coachNutritionTargets!.phase, CoachNutritionPhase.gain);
      expect(fit.coachNutritionTargets!.delta, greaterThan(0));
    });

    test('the coach sets the goals only while the module is on and no goals of the user\'s own are set', () {
      expect(fit.coachSetsGoals, isFalse);
      fit.setCoachModule(CoachModule.nutrition, true);
      expect(fit.coachSetsGoals, isTrue);
      expect(fit.coachNutritionRules(), isNotEmpty);
      fit.useSuggestedGoals();
      expect(fit.coachSetsGoals, isFalse);
    });

    test("\"use coach's goals\" drops the user's own goals, and that survives a restart", () {
      _arrange(_case('G1:')['input'] as Map<String, dynamic>);
      // A reload first, so the app's own calculators follow the profile set above, as they do in use: the stock
      // part of the goals (fibre) depends on them.
      fit.persistNow();
      fit.loadFromStore();
      final coachGoals = fit.activeGoals.toJson();
      expect(fit.coachCanRestoreGoals, isFalse, reason: 'nothing to restore yet');
      fit.setNutritionGoals(const NutritionGoals(kcal: 2000, protein: 150, waterMl: 4000, sodium: 1500));
      expect(fit.coachCanRestoreGoals, isTrue);
      expect(fit.activeGoals.kcal, 2000);

      fit.useCoachGoals();
      expect(fit.nutritionGoalsSet, isFalse);
      expect(fit.nutritionGoals.toJson(), const NutritionGoals().toJson(), reason: 'as on a fresh install');
      expect(fit.activeGoals.toJson(), coachGoals);
      expect(fit.coachSetsGoals, isTrue);
      expect(fit.coachCanRestoreGoals, isFalse);

      fit.persistNow();
      fit.setNutritionGoals(const NutritionGoals(kcal: 1));
      fit.loadFromStore();
      expect(fit.nutritionGoalsSet, isFalse);
      expect(fit.activeGoals.toJson(), coachGoals);
    });

    test("\"use coach's goals\" does nothing while the module is off", () {
      fit.setNutritionGoals(const NutritionGoals(kcal: 2000));
      expect(fit.coachCanRestoreGoals, isFalse);
      fit.useCoachGoals();
      expect(fit.nutritionGoalsSet, isTrue);
      expect(fit.activeGoals.kcal, 2000);
    });
  });
}
