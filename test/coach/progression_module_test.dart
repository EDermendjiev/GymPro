// SPDX-License-Identifier: GPL-3.0-only
// Phase 3, the progression module, driven through the app's state the way test/progression_test.dart does it.
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/progression.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _id(String name) => fit.allExercises.firstWhere((e) => e.name == name).id;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  group('3.1 the Auto kind', () {
    test('rules saved with the five stock kinds load unchanged', () {
      for (var k = 0; k <= 4; k++) {
        final r = ProgressRule.fromJson({'k': k, 'lo': 6, 'hi': 10, 's': 3, 'ms': 5, 'f': 2, 'd': 15});
        expect(r.kind, ProgressKind.values[k]);
        expect(r.toJson(), {'k': k, 'lo': 6, 'hi': 10, 's': 3, 'ms': 5, 'f': 2, 'd': 15});
      }
      expect(ProgressKind.auto.index, 5);
    });

    test('auto round-trips through JSON and through a save', () {
      final r = ProgressRule.fromJson(const ProgressRule(kind: ProgressKind.auto, low: 8, high: 12).toJson());
      expect((r.kind, r.low, r.high), (ProgressKind.auto, 8, 12));

      final id = _id('Barbell Bench Press');
      fit.setProgressRule(id, const ProgressRule(kind: ProgressKind.auto, low: 8, high: 12));
      fit.persistNow();
      fit.progressRules.clear();
      fit.loadFromStore();
      expect(fit.progressRule(id).kind, ProgressKind.auto);
    });

    test('choosing Auto stores the rep range the coach prescribes for the exercise', () {
      for (final (name, low, high) in [
        ('Barbell Bench Press', 8, 12), // free press
        ('Machine Chest Press', 10, 15), // machine press
        ('Barbell Full Squat', 6, 8), // free lower-body compound
        ('Leg Press', 8, 12), // machine lower-body compound
        ('Cable Pulldown', 10, 15), // pulling compound
        ('Dumbbell Lateral Raise', 10, 15), // isolation
      ]) {
        final id = _id(name);
        fit.setProgressRule(id, fit.coachAutoRule(id, fit.progressRule(id)));
        final r = fit.progressRule(id);
        expect((r.kind, r.low, r.high), (ProgressKind.auto, low, high), reason: name);
        expect(fit.hasProgress(id), isTrue, reason: name);
      }
    });

    test('the sheet offers Auto only while the progression module is on, or once it is chosen', () {
      expect(fit.coachProgressKinds(ProgressKind.linear), isNot(contains(ProgressKind.auto)));
      expect(fit.coachProgressKinds(ProgressKind.auto), ProgressKind.values);
      fit.setCoachModule(CoachModule.progression, true);
      expect(fit.coachProgressKinds(ProgressKind.linear), ProgressKind.values);
    });
  });
}
