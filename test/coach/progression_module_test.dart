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
  fit.startRoutine(fit.routines.firstWhere((x) => x.id == r));
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

  group('3.3 first-set correction', () {
    // Starts a session of Bench Press on Auto with [range], three working sets of [kg], and ticks the first one
    // after [reps] reps.
    void firstSet(double kg, int reps, {(int, int) range = (8, 12), double step = 2.5}) {
      final id = _auto('Barbell Bench Press', low: range.$1, high: range.$2, step: step);
      _start(id);
      final s = fit.session!;
      expect(_working(0).length, 3);
      final first = s.exercises[0].sets.indexWhere((x) => x.kind != SetKind.warmup);
      for (var j = first; j < s.exercises[0].sets.length; j++) {
        fit.setSessionWeight(0, j, kg);
        fit.setSessionReps(0, j, 10);
      }
      fit.setSessionReps(0, first, reps);
      fit.toggleSet(0, first);
    }

    List<double> rest() => [for (final x in _working(0).skip(1)) x.weight];

    test('fixture: 50 kg × 6 in an 8–12 range drops the rest to 45 kg, and undo puts them back', () {
      firstSet(50, 6);
      expect(rest(), [45, 45]);
      expect([for (final x in _working(0).skip(1)) x.reps], [8, 8]);
      final prompts = fit.takeCoachPrompts().whereType<CoachCorrectionPrompt>().toList();
      expect(prompts.length, 1);
      expect(prompts.single.title, contains('45'));
      fit.undoCoachCorrection();
      expect(rest(), [50, 50]);
      expect([for (final x in _working(0).skip(1)) x.reps], [6, 6]); // as typed: the reps of set 1 carried down
      fit.saveAndExit();
    });

    // Every first-set case of the fixture with a load and some reps, replayed through the workout.
    for (final c in _fixture('progression.json', 'suggestNextSet')) {
      final ctx = c['input']['ctx'] as Map;
      if (ctx['setIndex'] != 0 || ctx['load'] == null || ctx['reps'] == 0) continue;
      test('fixture: ${c['name']}', () {
        final rx = ctx['rx'] as Map;
        final kg = (ctx['load'] as num).toDouble();
        firstSet(kg, ctx['reps'] as int,
            range: (rx['repMin'] as int, rx['repMax'] as int), step: (ctx['increment'] as num).toDouble());
        final want = ((c['output'] as Map)['load'] as num).toDouble();
        expect(rest(), [want, want]);
        expect(fit.takeCoachPrompts().whereType<CoachCorrectionPrompt>().length, want == kg ? 0 : 1);
        fit.saveAndExit();
      });
    }

    test('it happens once: ticking the first set again changes nothing', () {
      firstSet(50, 6);
      fit.undoCoachCorrection();
      fit.toggleSet(0, 0);
      fit.toggleSet(0, 0);
      expect(rest(), [50, 50]);
      fit.saveAndExit();
    });

    test('later sets and sets already done are left alone', () {
      final id = _auto('Barbell Bench Press');
      _start(id);
      for (var j = 0; j < 3; j++) {
        fit.setSessionWeight(0, j, 50);
      }
      fit.setSessionReps(0, 1, 5);
      fit.toggleSet(0, 1); // a later set first: no correction
      expect(fit.hasCoachPrompts, isFalse);
      fit.setSessionReps(0, 0, 6);
      fit.toggleSet(0, 0);
      expect([for (final x in _working(0)) x.weight], [50, 50, 45]);
      fit.saveAndExit();
    });

    test('nothing happens with the module off or on another kind', () {
      firstSet(50, 6);
      fit.saveAndExit();
      fit.setCoachModule(CoachModule.progression, false);
      final id = _id('Barbell Bench Press');
      _start(id);
      for (var j = 0; j < 3; j++) {
        fit.setSessionWeight(0, j, 50);
      }
      fit.setSessionReps(0, 0, 6);
      fit.takeCoachPrompts();
      fit.toggleSet(0, 0);
      expect(rest(), [50, 50]);
      expect(fit.hasCoachPrompts, isFalse);
      fit.saveAndExit();
    });
  });

  group('3.4 one effort tap', () {
    List<CoachEffortPrompt> asks() => fit.takeCoachPrompts().whereType<CoachEffortPrompt>().toList();

    test('the picker is requested once per exercise, for its first working set', () {
      final id = _auto('Barbell Bench Press');
      _start(id);
      fit.toggleSet(0, 0);
      final first = asks();
      expect([for (final a in first) (a.exerciseIndex, a.setIndex)], [(0, 0)]);
      fit.toggleSet(0, 0); // untick
      fit.toggleSet(0, 0); // and tick again
      fit.toggleSet(0, 1);
      fit.toggleSet(0, 2);
      expect(asks(), isEmpty);
      fit.saveAndExit();
    });

    test('a set that already has an effort is not asked about', () {
      final id = _auto('Barbell Bench Press');
      _start(id);
      fit.setSessionRpe(0, 0, 8);
      fit.toggleSet(0, 0);
      expect(asks(), isEmpty);
      fit.saveAndExit();
    });

    test('skipping leaves the effort empty and the next target still computes, as on target', () {
      final id = _auto('Barbell Bench Press');
      _start(id);
      for (var j = 0; j < 3; j++) {
        fit.setSessionWeight(0, j, 50);
      }
      fit.setSessionReps(0, 0, 12);
      for (var j = 0; j < 3; j++) {
        fit.toggleSet(0, j);
      }
      expect(asks().length, 1);
      fit.finishSession();
      fit.saveAndExit();
      expect(fit.lastSetsFor(id).first.rpe, isNull);
      final next = fit.nextTarget(id)!;
      expect((next.weightKg, next.reps), (52.5, 9)); // top of 8–12, effort read as on target: one step up
    });

    test('no request with the module off or on another kind', () {
      final id = _id('Barbell Bench Press');
      fit.setProgressRule(id, const ProgressRule(kind: ProgressKind.double));
      fit.setCoachModule(CoachModule.progression, true);
      _start(id);
      fit.toggleSet(0, 0);
      expect(fit.hasCoachPrompts, isFalse);
      fit.saveAndExit();
    });
  });
}
