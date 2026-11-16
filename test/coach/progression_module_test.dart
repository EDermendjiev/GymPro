// SPDX-License-Identifier: GPL-3.0-only
// Phase 3, the progression module, driven through the app's state the way test/progression_test.dart does it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/live_session.dart';
import 'package:gymmane/models/progression.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _id(String name) => fit.allExercises.firstWhere((e) => e.name == name).id;

/// Turns the progression module on and sets [name] to Auto with the given rep range and load step.
String _auto(String name, {int low = 8, int high = 12, double step = 2.5}) {
  final id = _id(name);
  fit.setCoachModule(CoachModule.progression, true);
  fit.setProgressRule(id, ProgressRule(kind: ProgressKind.auto, low: low, high: high));
  fit.progressStep[id] = step;
  return id;
}

/// Logs one session of [id] on [day] (an ISO date); [n] orders sessions that share a day.
void _log(String id, String day, List<LoggedSet> sets, {int n = 0, bool deload = false}) {
  final ex = fit.exerciseById(id)!;
  fit.sessions.add(LoggedSession(
    DateTime.parse(day).add(Duration(hours: 12, minutes: n)),
    1200,
    [LoggedExercise(id, ex.name, ex.primary, sets)],
    deload: deload,
  ));
}

List<Map<String, dynamic>> _fixture(String file, String call) {
  final json = jsonDecode(File('packages/coach_progression/test/fixtures/$file').readAsStringSync()) as Map;
  return [
    for (final c in json['cases'] as List)
      if ((c as Map)['input']['call'] == call) c.cast<String, dynamic>(),
  ];
}

const _profile = {
  'goal': 'lean_gain',
  'days': [1, 3, 5],
  'minutes': 60,
  'priority': 'lifting',
  'lifestyle': 'lightly_active',
};

/// Starts a routine holding only [id].
void _start(String id) {
  final r = fit.createRoutine('Coach');
  fit.toggleRoutineExercise(r, id);
  fit.startRoutine(fit.routines.single);
}

List<SessionSet> _working(int exIdx) =>
    fit.session!.exercises[exIdx].sets.where((s) => s.kind != SetKind.warmup).toList();

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

  group('3.2 next-session target', () {
    // The app's exercise each fixture case is replayed on. The coach takes the effort range from the exercise's
    // category, so the exercise is picked by the case's highest RIR, and by the heavy-barbell flag.
    String? exerciseFor(Map history, Map rx) {
      if (history['heavyLowerBarbell'] == true) return rx['rirMax'] == 4 ? 'Barbell Full Squat' : null;
      return switch (rx['rirMax']) {
        4 => 'Leg Press', // lower-body machine compound: RIR 1–4, never a barbell
        3 => 'Cable Pulldown', // pulling compound: RIR 0–3
        2 => 'Dumbbell Lateral Raise', // isolation: RIR 0–2
        _ => null,
      };
    }

    // Why a case cannot be replayed through the app, or null when it can.
    String? skipReason(Map history, Map rx) {
      final exposures = history['exposures'] as List;
      if (exposures.isEmpty) return 'no logged session: the app asks for a target only once the exercise is logged';
      if (exposures.any((e) => (e['sets'] as List).isEmpty)) return 'the app cannot log an exercise without sets';
      if (exposures.any((e) => (e['sets'] as List).any((s) => s['load'] == null))) {
        return 'unloaded sets: Auto leaves body-weight exercises to the stock rules';
      }
      if (history['e1rm'] != null) return 'the app passes no strength estimate';
      if (exerciseFor(history, rx) == null) return 'no exercise category has this effort range';
      return null;
    }

    final cases = _fixture('progression.json', 'suggestNextSession');
    final covered = [
      for (final c in cases)
        if (skipReason(c['input']['history'] as Map, c['input']['rx'] as Map) == null) c,
    ];

    test('the fixture gives at least ten cases the app can replay', () {
      expect(covered.length, greaterThanOrEqualTo(10));
    });

    for (final c in covered) {
      test('parity: ${c['name']}', () {
        final history = c['input']['history'] as Map;
        final rx = c['input']['rx'] as Map;
        final out = c['output'] as Map;
        final id = _auto(
          exerciseFor(history, rx)!,
          low: rx['repMin'] as int,
          high: rx['repMax'] as int,
          step: (history['increment'] as num).toDouble(),
        );
        if (history['status'] case final String status) {
          fit.coach = fit.coach.copyWith(profile: CoachProfile.fromJson({..._profile, 'status': status}));
        }
        final exposures = history['exposures'] as List;
        for (var i = 0; i < exposures.length; i++) {
          final e = exposures[i] as Map;
          _log(id, e['date'] as String, [
            for (final s in e['sets'] as List)
              LoggedSet(s['reps'] as int, (s['load'] as num).toDouble(),
                  rpe: s['rir'] == null ? null : 10 - (s['rir'] as num).toDouble()),
          ], n: i);
        }
        final next = fit.nextTarget(id)!;
        expect(next.weightKg, (out['load'] as num).toDouble());
        expect(next.reps, out['repsTarget']);
      });
    }

    test('the target is a load step up and feeds the opening sets of a routine', () {
      final id = _auto('Cable Pulldown', low: 6, high: 10);
      _log(id, '2026-09-01', [LoggedSet(10, 50, rpe: 7), LoggedSet(9, 50), LoggedSet(8, 50)]);
      final next = fit.nextTarget(id)!;
      expect((next.weightKg, next.reps, next.move, next.up), (52.5, 7, NextMove.up, true));
      _start(id);
      expect([for (final s in _working(0)) (s.weight, s.reps)], [(52.5, 7), (52.5, 7), (52.5, 7)]);
      fit.saveAndExit();
    });

    test('a kept load reads as one more rep', () {
      final id = _auto('Cable Pulldown', low: 6, high: 10);
      _log(id, '2026-09-01', [LoggedSet(8, 50, rpe: 8), LoggedSet(8, 50)]);
      final next = fit.nextTarget(id)!;
      expect((next.weightKg, next.reps, next.move, next.sets), (50.0, 9, NextMove.reps, 2));
    });

    test('a deload session is ignored, as the stock progression ignores it', () {
      final id = _auto('Cable Pulldown', low: 6, high: 10);
      _log(id, '2026-09-01', [LoggedSet(8, 50, rpe: 8)]);
      _log(id, '2026-09-03', [LoggedSet(10, 40, rpe: 5)], deload: true);
      expect(fit.nextTarget(id)!.weightKg, 50);
    });

    test('with the module off an Auto exercise gets the stock Linear target', () {
      final id = _auto('Cable Pulldown', low: 6, high: 10);
      _log(id, '2026-09-01', [LoggedSet(8, 50, rpe: 8), LoggedSet(8, 50)]);
      fit.setCoachModule(CoachModule.progression, false);
      final auto = fit.nextTarget(id)!;
      fit.setProgressRule(id, const ProgressRule(kind: ProgressKind.linear, low: 6, high: 10));
      expect('$auto', '${fit.nextTarget(id)}'); // the record holds a list, so it is compared as text
      expect((auto.weightKg, auto.reps), (52.5, 8));
    });

    test('an exercise on another kind is untouched while the module is on', () {
      final id = _id('Cable Pulldown');
      fit.progressStep[id] = 2.5;
      fit.setProgressRule(id, const ProgressRule(kind: ProgressKind.double, low: 6, high: 10));
      _log(id, '2026-09-01', [LoggedSet(8, 50, rpe: 8), LoggedSet(7, 50)]);
      final off = fit.nextTarget(id);
      fit.setCoachModule(CoachModule.progression, true);
      expect('${fit.nextTarget(id)}', '$off');
    });

    test('body-weight-only, timed and assisted exercises stay on the stock rules', () {
      for (final (name, kg, sec) in [('Push-up', 0.0, null), ('Plank', 0.0, 30), ('Assisted Pull-up', 20.0, null)]) {
        final id = _auto(name, low: 6, high: 10);
        _log(id, '2026-09-01', [LoggedSet(8, kg, sec: sec)]);
        expect(fit.coachNextPlan(id), isNull, reason: name);
      }
    });
  });
}
