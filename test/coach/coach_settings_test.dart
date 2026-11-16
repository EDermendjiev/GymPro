// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/screens/settings_screen.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<bool> _switches() => [for (final m in CoachModule.values) fit.coach.isOn(m)];

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SingleChildScrollView(child: CoachSettings())),
      ),
    );

Future<void> _tap(WidgetTester tester, CoachModule m) async {
  await tester.tap(find.byKey(ValueKey('coach-module-${m.name}')));
  await tester.pump();
  fit.persistNow(); // saves now instead of leaving the delayed save pending when the test ends
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  testWidgets('shows the four switches with their hints, all off', (tester) async {
    await _pump(tester);
    for (final text in [
      t.coachProgression,
      t.coachProgressionHint,
      t.coachPlan,
      t.coachPlanHint,
      t.coachRecovery,
      t.coachRecoveryHint,
      t.coachNutrition,
      t.coachNutritionHint,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(_switches(), [false, false, false, false]);
  });

  testWidgets('toggling Plan while Progression is off does nothing', (tester) async {
    await _pump(tester);
    await _tap(tester, CoachModule.plan);
    await _tap(tester, CoachModule.recovery);
    expect(_switches(), [false, false, false, false]);
  });

  testWidgets('each switch turns its module on once the one it needs is on', (tester) async {
    await _pump(tester);
    for (final m in CoachModule.values) {
      await _tap(tester, m);
    }
    expect(_switches(), [true, true, true, true]);
  });

  testWidgets('toggling Progression off flips Plan and Recovery off, and Nutrition stays', (tester) async {
    await _pump(tester);
    for (final m in CoachModule.values) {
      await _tap(tester, m);
    }
    await _tap(tester, CoachModule.progression);
    expect(_switches(), [false, false, false, true]);
  });

  testWidgets('a dependent switch looks disabled while the one it needs is off', (tester) async {
    await _pump(tester);
    double opacityOf(CoachModule m) => tester
        .widget<Opacity>(find.descendant(
            of: find.byKey(ValueKey('coach-module-${m.name}')), matching: find.byType(Opacity)))
        .opacity;
    expect(opacityOf(CoachModule.progression), 1);
    expect(opacityOf(CoachModule.plan), lessThan(1));
    expect(opacityOf(CoachModule.nutrition), 1);
    await _tap(tester, CoachModule.progression);
    expect(opacityOf(CoachModule.plan), 1);
    expect(opacityOf(CoachModule.recovery), lessThan(1));
  });

  test('settings has a Coach section', () {
    expect(SettingsScreen.sectionTitleOf('coach'), t.sectionCoach);
  });
}
