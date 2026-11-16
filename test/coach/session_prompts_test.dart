// SPDX-License-Identifier: GPL-3.0-only
// The workout screen's side of the progression module: the coach's requests reach the screen once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/l10n/l10n.dart';
import 'package:gymmane/models/progression.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:gymmane/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  testWidgets('the correction shows as a toast with Undo, and the effort picker opens once', (tester) async {
    final id = fit.allExercises.firstWhere((e) => e.name == 'Barbell Bench Press').id;
    fit.setCoachModule(CoachModule.progression, true);
    fit.setProgressRule(id, const ProgressRule(kind: ProgressKind.auto, low: 8, high: 12));
    fit.progressStep[id] = 2.5;
    final r = fit.createRoutine('Coach');
    fit.toggleRoutineExercise(r, id);
    fit.startRoutine(fit.routines.firstWhere((x) => x.id == r));
    for (var j = 0; j < 3; j++) {
      fit.setSessionWeight(0, j, 50);
    }
    fit.setSessionReps(0, 0, 6);
    fit.toggleSet(0, 0);

    final asked = <(int, int)>[];
    Future<void> ask(BuildContext _, int exIdx, int setIdx, double? rpe) async => asked.add((exIdx, setIdx));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: AnimatedBuilder(
          animation: fit,
          builder: (context, _) {
            coachSessionPrompts(context, ask);
            return const SizedBox.expand();
          },
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(asked, [(0, 0)]);
    expect(find.textContaining('45'), findsOneWidget);
    expect(fit.session!.exercises[0].sets[1].weight, 45);

    await tester.tap(find.text(t.undo));
    await tester.pump();
    expect(fit.session!.exercises[0].sets[1].weight, 50);

    fit.notifyListeners(); // a rebuild asks for nothing more
    await tester.pump();
    expect(asked.length, 1);

    fit.saveAndExit();
    await tester.pump(const Duration(seconds: 6));
  });
}
