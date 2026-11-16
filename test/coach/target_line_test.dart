// SPDX-License-Identifier: GPL-3.0-only
// 3.5: the coach's target and reason in the workout screen, for an Auto exercise only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/progression.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/screens/session_screen.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bench Press with one logged session of 3 × 12 at 50 kg, on [rule], and a workout of it in progress.
String _setUp(ProgressRule rule) {
  final id = fit.allExercises.firstWhere((e) => e.name == 'Barbell Bench Press').id;
  fit.setCoachModule(CoachModule.progression, true);
  fit.setProgressRule(id, rule);
  fit.progressStep[id] = 2.5;
  fit.sessions.add(LoggedSession(DateTime(2026, 9, 1, 18), 1200, [
    LoggedExercise(id, 'Barbell Bench Press', 'chest', [LoggedSet(12, 50), LoggedSet(12, 50), LoggedSet(12, 50)]),
  ]));
  final r = fit.createRoutine('Coach');
  fit.toggleRoutineExercise(r, id);
  fit.startRoutine(fit.routines.firstWhere((x) => x.id == r));
  return id;
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: AnimatedBuilder(animation: fit, builder: (_, _) => const SessionScreen())),
  ));
  await tester.pump();
}

Future<void> _end(WidgetTester tester) async {
  fit.saveAndExit();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  testWidgets('an Auto exercise shows the coach target and reason, and the reason opens the why-sheet',
      (tester) async {
    final id = _setUp(const ProgressRule(kind: ProgressKind.auto, low: 8, high: 12));
    await _pump(tester);
    expect(find.text(t.coachTargetLabel('8–12', '1–4')), findsOneWidget);
    expect(find.textContaining(t.coachWhyUp), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('coach-why-$id')));
    await tester.pumpAndSettle();
    expect(find.text(t.coachWhyTitle), findsWidgets);
    expect(fit.coachWhyDetails(id), isNotEmpty);
    for (final line in fit.coachWhyDetails(id)) {
      expect(find.text(line), findsOneWidget, reason: line);
    }
    await _end(tester);
  });

  testWidgets('a Linear exercise shows neither', (tester) async {
    _setUp(const ProgressRule(kind: ProgressKind.linear, low: 8, high: 12));
    await _pump(tester);
    expect(find.textContaining('in reserve'), findsNothing);
    expect(find.textContaining('coach:'), findsNothing);
    expect(find.text(t.nextTime), findsWidgets); // the stock NEXT line is there
    await _end(tester);
  });
}
