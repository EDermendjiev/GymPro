// SPDX-License-Identifier: GPL-3.0-only
// Phase 4, the plan module, driven through the app's state the way the other coach tests do it.
import 'dart:convert';
import 'dart:io';

import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/catalog/exercise_catalog.dart';
import 'package:gymmane/coach/adapters/catalog_adapter.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/live_session.dart';
import 'package:gymmane/models/progression.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Monday, so a block built on it starts on it.
final DateTime _monday = DateTime(2026, 11, 16, 9);

ck.BlockPlan get _block => fit.coach.block!;

void _profile({CoachGoal goal = CoachGoal.leanGain, CoachStatus status = CoachStatus.intermediate,
    List<int> days = const [1, 3, 5], int minutes = 60}) {
  fit.coach = fit.coach.copyWith(
    profile: CoachProfile.answered(goal: goal, status: status, days: days, minutes: minutes, activity: 1.375),
  );
  fit.setCoachModule(CoachModule.progression, true);
  fit.setCoachModule(CoachModule.plan, true);
}

String _id(String name) => fit.allExercises.firstWhere((e) => e.name == name).id;

void _log(String day, Map<String, List<LoggedSet>> work, {String? routineId}) {
  fit.sessions.add(LoggedSession(DateTime.parse(day).add(const Duration(hours: 12)), 3600, [
    for (final e in work.entries)
      LoggedExercise(e.key, fit.exerciseById(e.key)!.name, fit.exerciseById(e.key)!.primary, e.value),
  ], routineId: routineId));
}

List<SessionSet> _working(String exerciseId) => fit.session!.exercises
    .firstWhere((e) => e.id == exerciseId)
    .sets
    .where((s) => s.kind != SetKind.warmup)
    .toList();

/// The coach routine of [templateKey].
Routine _routine(String templateKey) => fit.routineById(fit.coach.routineIds[templateKey]!)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
    fit.coachClock = () => _monday;
  });

  tearDown(() {
    if (fit.session != null) fit.saveAndExit();
    fit.coachClock = DateTime.now;
  });

  group('4.1 coach profile and defaults', () {
    test('the block input for a fresh profile equals a fixture input field by field', () {
      final fixture = jsonDecode(File('packages/coach_training/test/fixtures/generate_block_extra.json').readAsStringSync());
      final want = ((fixture['cases'] as List).firstWhere((c) => c['name'] == 'extra/days-tue-thu-sat')['input'] as Map)
          .cast<String, dynamic>();
      fit.coachClock = () => DateTime.parse(want['today'] as String);
      _profile();
      fit.coach = fit.coach.copyWith(profile: CoachProfile.fromJson({
        'goal': want['goal'],
        'status': want['status'],
        'days': want['availableDays'],
        'minutes': want['sessionMinutes'],
        'priority': want['priority'],
        'lifestyle': 'lightly_active',
      }));
      final got = fit.coachBlockInput();
      for (final key in [
        'today', 'goal', 'priority', 'status', 'availableDays', 'sessionMinutes', 'increments', 'sports',
        'injuries', 'repVariation', 'specialization', 'history',
      ]) {
        expect(got[key], want[key], reason: key);
      }
      expect(got['maxLiftDays'], want['maxLiftDays']);
      // The equipment is the place's: the app has no sled.
      expect({...got['equipment'] as List}, {...want['equipment'] as List}..remove('sled'));
      // The library is the app's annotated exercises.
      expect([for (final e in got['exercises'] as List) e['id']],
          [for (final e in coachPlanLibrary(kExercises, archived: const {})) e.id]);
    });

    test('without an answer for the days, the weekly goal is spread over the week', () {
      fit.profile.weeklyGoal = 3;
      fit.coach = fit.coach.copyWith(profile: CoachProfile.answered(
          goal: CoachGoal.leanGain, status: CoachStatus.novice, days: const [], minutes: 45, activity: 1.2));
      expect(fit.coachBlockInput()['availableDays'], [1, 3, 5]);
    });

    test('the place\'s equipment and the weight step reach the input', () {
      final home = fit.addPlace('Home', equipment: {'Dumbbell', 'Band'});
      fit.setActivePlace(home);
      _profile();
      final input = fit.coachBlockInput();
      expect({...input['equipment'] as List}, {'dumbbell', 'band', 'bodyweight'});
      expect((input['increments'] as Map)['barbell'], fit.fromDisplayWeight(fit.weightStep));
    });

    test('a profile built from the screens\' answers maps to the coach\'s names and back', () {
      final p = CoachProfile.answered(
          goal: CoachGoal.fatLoss, status: CoachStatus.advanced, days: const [1, 2], minutes: 45, activity: 1.725);
      expect(p.toJson()['goal'], 'fat_loss');
      expect(p.toJson()['status'], 'advanced');
      expect(p.toJson()['lifestyle'], 'very_active');
      expect((p.coachGoal, p.coachStatus), (CoachGoal.fatLoss, CoachStatus.advanced));
    });
  });

  group('4.3 plan writer', () {
    test('one routine per template in the Coach group, matching the block, with the week planned', () {
      _profile();
      fit.coachBuildPlan();
      final templates = {for (final s in _block.sessions) s.templateKey};
      expect(fit.coach.routineIds.keys.toSet(), templates);
      for (final key in templates) {
        final r = _routine(key);
        expect(r.group, 'Coach');
        final first = (_block.sessions.where((s) => s.templateKey == key).toList()
              ..sort((a, b) => a.date.compareTo(b.date)))
            .first;
        expect(r.exerciseIds, ck.uniq([for (final e in first.exercises) e.exerciseId]), reason: key);
        for (final id in r.exerciseIds) {
          final sets = first.exercises.where((e) => e.exerciseId == id).fold(0, (n, e) => n + e.sets);
          expect(fit.plannedSets(r, id), hasLength(sets), reason: '$key $id');
          expect(fit.progressRule(id).kind, ProgressKind.auto, reason: id);
        }
      }
      for (final p in _block.schedule.placements) {
        expect(fit.weeklyPlan[p.weekday], fit.coach.routineIds[p.templateKey]);
      }
    });

    test('a second build updates the same routines, and the user\'s own routines and plans stay as they were', () {
      final mine = fit.createRoutine('Mine');
      final bench = _id('Barbell Bench Press');
      fit.toggleRoutineExercise(mine, bench);
      fit.assignRoutineToDay(7, mine);
      final before = jsonEncode(fit.routineById(mine)!.toJson());

      _profile();
      fit.coachBuildPlan();
      final ids = {...fit.coach.routineIds};
      final plans = fit.savedPlans.length;
      // The user's week was kept as a saved plan.
      expect(fit.savedPlansLive.any((p) => p.week[7] == mine), isTrue);
      expect(fit.weeklyPlan.values, isNot(contains(mine)));

      fit.coachBuildPlan();
      expect(fit.coach.routineIds, ids);
      expect(fit.routines.where((r) => r.group == 'Coach'), hasLength(ids.length));
      expect(jsonEncode(fit.routineById(mine)!.toJson()), before);
      expect(fit.savedPlans, hasLength(plans)); // a week of coach routines only is replaced, not saved again
    });

    test('the coach routines and the block survive a save and a reload', () {
      _profile();
      fit.coachBuildPlan();
      final json = jsonEncode(fit.coach.toJson());
      fit.persistNow();
      fit.coach = CoachData.empty();
      fit.loadFromStore();
      expect(jsonEncode(fit.coach.toJson()), json);
    });
  });

  group('4.4 week-aware opening sets', () {
    test('week 1 of an intro block opens with 75% of the sets, week 2 with the full count', () {
      // Three weeks off make the block start with an intro week.
      final squat = _id('Barbell Full Squat');
      _log('2026-10-20', {squat: [LoggedSet(8, 80), LoggedSet(8, 80)]});
      _profile();
      fit.coachBuildPlan();
      expect(_block.introWeek, isTrue);

      final s0 = _block.sessions.firstWhere((s) => s.weekIndex == 0);
      final s1 = _block.sessions.firstWhere((s) => s.weekIndex == 1 && s.templateKey == s0.templateKey);
      final e = s0.exercises.firstWhere((x) => x.isMainLiftSingle != true);
      final week1 = s0.exercises.where((x) => x.exerciseId == e.exerciseId).fold(0, (n, x) => n + x.sets);
      final week2 = s1.exercises.where((x) => x.exerciseId == e.exerciseId).fold(0, (n, x) => n + x.sets);
      expect(week1, lessThan(week2));
      final all0 = s0.exercises.fold(0, (n, x) => n + x.sets);
      final all1 = s1.exercises.fold(0, (n, x) => n + x.sets);
      expect(all0 / all1, closeTo(0.75, 0.1));

      final r = _routine(s0.templateKey);
      fit.coachClock = () => DateTime.parse(s0.date).add(const Duration(hours: 9));
      fit.startRoutine(r);
      expect(_working(e.exerciseId), hasLength(week1));
      fit.saveAndExit();
      fit.sessions.clear();

      fit.coachClock = () => DateTime.parse(s1.date).add(const Duration(hours: 9));
      fit.startRoutine(r);
      expect(_working(e.exerciseId), hasLength(week2));
    });

    test('the block\'s reps win over the routine\'s planned reps, with the coach\'s load worked out at the start', () {
      _profile();
      fit.coachBuildPlan();
      final s0 = _block.sessions.first;
      final e = s0.exercises.firstWhere((x) => x.isMainLiftSingle != true && !x.slotKey.endsWith('_backoff'));
      final ex = fit.exerciseById(e.exerciseId)!;
      final r = _routine(s0.templateKey);
      // A session logged after the plan was built: the load is worked out when the workout starts.
      final mid = ((e.repMin + e.repMax) / 2).round();
      _log('2026-11-10', {ex.id: [LoggedSet(mid, 40, rpe: 8), LoggedSet(mid, 40), LoggedSet(mid, 40)]});
      fit.coachClock = () => DateTime.parse(s0.date).add(const Duration(hours: 9));
      final target = fit.nextTarget(ex.id);
      fit.startRoutine(r);
      final sets = _working(ex.id);
      expect(sets, hasLength(e.sets));
      expect(sets.every((s) => s.weight > 0), isTrue);
      // The exercise's Auto rule has the range of the routine's first session, this one, so the targets agree.
      expect(target, isNotNull);
      expect(sets.first.weight, target!.weightKg);
      // Every set aims inside the session's range.
      expect(sets.every((s) => s.reps >= e.repMin && s.reps <= e.repMax), isTrue);
    });

    test('with the plan module off, a coach routine opens like any routine', () {
      _profile();
      fit.coachBuildPlan();
      final s0 = _block.sessions.first;
      final r = _routine(s0.templateKey);
      fit.setCoachModule(CoachModule.plan, false);
      fit.startRoutine(r);
      for (final id in r.exerciseIds) {
        expect(_working(id), hasLength(fit.routineSets(r, id)), reason: id);
      }
    });
  });

  group('4.5 user edits survive', () {
    test('a swap in the routine editor stays after a regeneration; a removal becomes a dislike', () {
      _profile();
      fit.coachBuildPlan();
      final key = fit.coach.routineIds.keys.first;
      final r = _routine(key);
      final library = {for (final e in coachPlanLibrary(fit.allExercises, archived: const {})) e.id: e};
      // Swap the first exercise for one of its substitutions the plan may use.
      final from = r.exerciseIds.first;
      final to = library.values.firstWhere((e) =>
          e.id != from &&
          !r.exerciseIds.contains(e.id) &&
          library[from]!.slotTags.any(e.slotTags.contains) &&
          e.category == library[from]!.category);
      fit.replaceRoutineExercise(r.id, from, to.id);
      // Remove the last one.
      final removed = r.exerciseIds.last;
      fit.toggleRoutineExercise(r.id, removed);

      fit.coachRegenerate('test');
      final after = _routine(key);
      expect(after.id, r.id);
      expect(after.exerciseIds, contains(to.id));
      expect(after.exerciseIds, isNot(contains(from)));
      expect(fit.coach.disliked, contains(removed));
      expect(_block.sessions.any((s) => s.exercises.any((e) => e.exerciseId == removed)), isFalse);
    });
  });

  group('4.6 Home card label', () {
    test('a coach routine shows the block kind and week; any other routine shows nothing', () {
      _profile();
      fit.coachBuildPlan();
      final r = _routine(fit.coach.routineIds.keys.first);
      expect(fit.coachBlockLabel(r), 'Muscle building · Week 1 of ${_block.weeks}');
      fit.coachClock = () => _monday.add(const Duration(days: 8));
      expect(fit.coachBlockLabel(r), 'Muscle building · Week 2 of ${_block.weeks}');
      final mine = fit.createRoutine('Mine');
      expect(fit.coachBlockLabel(fit.routineById(mine)!), isNull);
      expect(fit.coachPlanSummary!.explanations, isNotEmpty);
      fit.setCoachModule(CoachModule.plan, false);
      expect(fit.coachBlockLabel(r), isNull);
    });
  });

  group('4.7 quick workout', () {
    test('the picks go to the muscles furthest behind this week\'s targets', () {
      _profile();
      fit.coachBuildPlan();
      // A big chest and back day this week (Monday): those muscles are no longer behind.
      final bench = _id('Barbell Bench Press');
      final row = _id('Barbell Bent Over Row');
      fit.coachClock = () => _monday.add(const Duration(days: 3, hours: 9));
      _log('2026-11-16', {
        bench: [for (var i = 0; i < 12; i++) LoggedSet(8, 60, rpe: 8)],
        row: [for (var i = 0; i < 12; i++) LoggedSet(8, 60, rpe: 8)],
      });
      final focus = fit.coachFocusMuscles()!;
      expect(focus, isNot(contains('chest')));
      expect(focus, isNot(contains('back')));

      fit.startWorkout(focus);
      fit.trainContinue();
      expect(fit.sessionPicks, isNotEmpty);
      final library = {for (final e in coachExercises(fit.allExercises)) e.id: e};
      for (final id in fit.sessionPicks) {
        expect(coachAnnotated(id), isTrue, reason: id);
        expect(library[id]!.muscles.any((m) => m.muscle == ck.MuscleId.chest && m.role == ck.MuscleRole.primary),
            isFalse, reason: id);
      }
    });

    test('a shorter workout picks fewer exercises, and the session opens with the generated sets', () {
      _profile();
      fit.coachBuildPlan();
      fit.startWorkout(const ['chest', 'back', 'quads', 'hamstrings', 'shoulders']);
      fit.trainContinue();
      fit.setCoachQuickMinutes(60);
      final long = fit.sessionPicks.length;
      fit.setCoachQuickMinutes(20);
      final short = fit.sessionPicks.length;
      expect(short, lessThan(long));
      fit.startSession();
      for (final e in fit.session!.exercises) {
        expect(e.sets.where((s) => s.kind != SetKind.warmup).length, inInclusiveRange(2, 4), reason: e.id);
      }
    });

    test('with the plan module off, the body-map flow picks as upstream does', () {
      fit.startWorkout(const ['chest']);
      fit.trainContinue();
      final stock = {...fit.sessionPicks};
      _profile();
      fit.coachBuildPlan();
      fit.setCoachModule(CoachModule.plan, false);
      fit.startWorkout(const ['chest']);
      fit.trainContinue();
      expect(fit.sessionPicks, stock);
    });
  });

  group('4.8 existing users', () {
    test('eight weeks of logs prefill the status and the days trained on most', () {
      final squat = _id('Barbell Full Squat');
      final bench = _id('Barbell Bench Press');
      // Ten weeks, Monday and Thursday, every session a little heavier: a novice's pace.
      for (var w = 0; w < 10; w++) {
        final mon = _monday.subtract(Duration(days: 7 * (10 - w)));
        final thu = mon.add(const Duration(days: 3));
        final kg = 60.0 + w * 2.5;
        _log(ck.addDays(mon.toIso8601String().substring(0, 10), 0), {
          squat: [LoggedSet(5, kg), LoggedSet(5, kg)],
          bench: [LoggedSet(5, kg - 10), LoggedSet(5, kg - 10)],
        });
        _log(thu.toIso8601String().substring(0, 10), {
          squat: [LoggedSet(5, kg + 1), LoggedSet(5, kg + 1)],
          bench: [LoggedSet(5, kg - 9), LoggedSet(5, kg - 9)],
        });
      }
      final a = fit.coachPrefill();
      expect(a.days, [1, 4]);
      expect(a.status, CoachStatus.novice);
      expect(a.statusFromLogs, isTrue);
      expect(a.goal, isNull);
    });

    test('without logs nothing is prefilled from them', () {
      final a = fit.coachPrefill();
      expect(a.days, isNull);
      expect(a.statusFromLogs, isFalse);
    });

    test('answering builds the plan and switches on progression and plan only', () {
      fit.coachApplyAnswers(CoachAnswers(goal: CoachGoal.strength, status: CoachStatus.intermediate, days: [1, 3, 5]));
      expect([for (final m in CoachModule.values) fit.coach.isOn(m)], [true, true, false, false]);
      expect(fit.coach.block, isNotNull);
      expect(fit.coach.routineIds, isNotEmpty);
    });
  });

  group('performance', () {
    test('coachBuildPlan end to end on a seeded state stays under 250 ms', () {
      // A year of logs, four sessions a week.
      final ids = [
        for (final n in ['Barbell Full Squat', 'Barbell Bench Press', 'Barbell Bent Over Row', 'Leg Press',
          'Cable Pulldown', 'Dumbbell Lateral Raise'])
          _id(n),
      ];
      for (var d = 365; d > 0; d--) {
        if (d % 7 == 0 || d % 7 == 2 || d % 7 == 4 || d % 7 == 5) {
          final day = _monday.subtract(Duration(days: d)).toIso8601String().substring(0, 10);
          _log(day, {for (final id in ids) id: [LoggedSet(8, 50), LoggedSet(8, 50), LoggedSet(7, 50)]});
        }
      }
      _profile(days: const [1, 2, 4, 5]);
      fit.coachBuildPlan(); // warm up
      final sw = Stopwatch()..start();
      const runs = 5;
      for (var i = 0; i < runs; i++) {
        fit.coachBuildPlan();
      }
      sw.stop();
      final ms = sw.elapsedMilliseconds / runs;
      // ignore: avoid_print
      print('coachBuildPlan: ${ms.toStringAsFixed(1)} ms per build');
      expect(ms, lessThan(250));
    });
  });
}
