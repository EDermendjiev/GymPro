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

/// The app activity multiplier that maps onto each coach activity band: the band's own multiplier.
const _activity = {'sedentary': 1.45, 'lightly_active': 1.65, 'active': 1.85, 'very_active': 2.05};

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

    test('the activity band is the one nearest to the app\'s activity multiplier', () {
      expect(coachLifestyleFor(1.2), ck.Lifestyle.sedentary);
      expect(coachLifestyleFor(1.375), ck.Lifestyle.sedentary);
      expect(coachLifestyleFor(1.55), ck.Lifestyle.lightlyActive, reason: 'a tie goes to the more active band');
      expect(coachLifestyleFor(1.725), ck.Lifestyle.lightlyActive);
      expect(coachLifestyleFor(1.9), ck.Lifestyle.active);
      expect(coachLifestyleFor(1.95), ck.Lifestyle.veryActive, reason: 'a tie goes to the more active band');
      expect(coachLifestyleFor(3), ck.Lifestyle.veryActive);
      expect(coachLifestyleFor(0), ck.Lifestyle.sedentary);
      for (final l in ck.Lifestyle.values) {
        expect(coachLifestyleFor(_activity[l.wire]!), l);
      }
    });

    test('the activity band reaches the targets through fit', () {
      final g1 = _case('G1:');
      _arrange(g1['input'] as Map<String, dynamic>);
      int kcalAt(double activity) {
        fit.profile.activity = activity;
        return fit.suggestedGoals.kcal;
      }

      // The app's Moderate and Active fall in G1's band, lightly active.
      expect(kcalAt(1.55), g1['output']['kcal']);
      expect(kcalAt(1.725), g1['output']['kcal']);
      // Its Sedentary and Light fall in the sedentary band: less.
      expect(kcalAt(1.2), kcalAt(1.375));
      expect(kcalAt(1.2), lessThan(g1['output']['kcal'] as int));
    });
  });
}
