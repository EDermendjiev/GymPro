// SPDX-License-Identifier: GPL-3.0-only
// 6.3: the coach's card in the nutrition goals sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/nutrition.dart';
import 'package:gymmane/screens/nutrition_screen.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps a page with one button that opens the app's nutrition goals sheet, and opens it.
Future<void> _openGoalsSheet(WidgetTester tester) async {
  // Wide enough for the stock sheet's buttons in the test font.
  tester.view.physicalSize = const Size(2400, 2700);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(onPressed: () => showGoalsSheet(context), child: const Text('open')),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  testWidgets('module off: the goals sheet has no coach card', (tester) async {
    await _openGoalsSheet(tester);
    expect(find.text('Daily goals'), findsOneWidget);
    expect(find.text('Set by coach'), findsNothing);
    expect(find.text('Gain'), findsNothing);
  });

  testWidgets('module on: "Set by coach", the phase, and the picker stores the phase', (tester) async {
    fit.coach = CoachData.fromJson({
      'on': {'nutrition': true},
      'profile': {
        'goal': 'lean_gain',
        'status': 'intermediate',
        'days': [1, 3, 5],
        'minutes': 60,
        'priority': 'lifting',
        'lifestyle': 'lightly_active',
      },
    });
    await _openGoalsSheet(tester);
    expect(find.text('Set by coach'), findsOneWidget);
    for (final label in ['Gain', 'Maintain', 'Lose']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(fit.coachNutritionTargets!.phase, CoachNutritionPhase.gain);
    final gainKcal = fit.activeGoals.kcal;

    await tester.tap(find.text('Lose'));
    await tester.pumpAndSettle();
    expect(fit.coach.nutrition['phase'], 'loss');
    expect(fit.coachNutritionTargets!.phase, CoachNutritionPhase.loss);
    expect(fit.activeGoals.kcal, lessThan(gainKcal));
    expect(find.text('Set by coach'), findsOneWidget, reason: 'picking a phase keeps the goals the coach\'s');
  });

  testWidgets('the reason opens a sheet with the phase, the basis and the rules', (tester) async {
    fit.setCoachModule(CoachModule.nutrition, true);
    await _openGoalsSheet(tester);
    await tester.tap(find.byKey(const ValueKey('coach-goals-why')));
    await tester.pumpAndSettle();
    expect(find.text('Why these goals'), findsWidgets);
    expect(find.textContaining('Maintain · '), findsOneWidget);
    expect(find.textContaining('a day keeps your weight'), findsOneWidget);
    expect(find.text("The coach's reasoning, in its own words"), findsOneWidget);
    for (final rule in fit.coachNutritionRules()) {
      expect(find.text(rule), findsOneWidget);
    }
  });

  testWidgets('goals of the user\'s own hide the card', (tester) async {
    fit.setCoachModule(CoachModule.nutrition, true);
    fit.setNutritionGoals(const NutritionGoals(kcal: 2000));
    await _openGoalsSheet(tester);
    expect(find.text('Set by coach'), findsNothing);
  });
}
