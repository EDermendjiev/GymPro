// SPDX-License-Identifier: GPL-3.0-only
// Task 7.3, the upgrade path: a backup written by upstream GymMane v2.3.0 restores in the fork with every coach
// module off, gives the same stock suggestions upstream gives, and the coach then works on it.
//
// test/coach/data/upstream_backup_v2.3.0.{json,zip} were written by a throwaway test run in a worktree of upstream
// v2.3.0 (e774a04): eight weeks of logs, three routines with a group and a weekly plan, a progression rule of each
// stock kind, bodyweight entries, nutrition goals set by hand, notes (one with a photo), places and measures, exported
// with `exportJson()` and `buildBackupZip()`. upstream_backup_v2.3.0.expected.json holds what upstream computed from
// the same data: counts, the next targets, the suggested and active nutrition goals and the calendar deload.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/progression.dart';
import 'package:gymmane/services/backup_zip.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/services/media_store.dart';
import 'package:gymmane/services/progress_reminder.dart';
import 'package:gymmane/services/train_reminder.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dir = 'test/coach/data';
final String _backup = File('$_dir/upstream_backup_v2.3.0.json').readAsStringSync();
final Map<String, dynamic> _expected =
    (jsonDecode(File('$_dir/upstream_backup_v2.3.0.expected.json').readAsStringSync()) as Map).cast<String, dynamic>();

/// What the app writes to a backup, as plain JSON.
Map<String, dynamic> _export() => (jsonDecode(fit.exportJson()) as Map).cast<String, dynamic>();

String _id(String name) => fit.allExercises.firstWhere((e) => e.name == name).id;

Map<String, Object?>? _target(String id) {
  final t = fit.nextTarget(id);
  if (t == null) return null;
  return {
    'weightKg': t.weightKg,
    'reps': t.reps,
    'up': t.up,
    'deload': t.deload,
    'move': t.move.name,
    'sets': t.sets,
    'perSet': t.perSet,
    'label': fit.nextTargetLabel(id),
    'why': fit.nextWhy(id),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory media;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    media = await Directory.systemTemp.createTemp('gympro_upgrade');
    MediaStore.directory = media.path;
    ProgressReminder.instance.enabled = false;
    TrainReminder.instance.enabled = false;
    fit.resetAllData();
  });

  tearDown(() async {
    MediaStore.directory = null;
    if (media.existsSync()) await media.delete(recursive: true);
  });

  group('an upstream v2.3.0 JSON backup', () {
    setUp(() => expect(fit.importJson(_backup), isTrue));

    test('restores every piece of data', () {
      final counts = (_expected['counts'] as Map).cast<String, dynamic>();
      expect({
        'sessions': fit.sessions.length,
        'routines': fit.routines.length,
        'weeklyPlan': fit.weeklyPlan.length,
        'progressRules': fit.progressRules.length,
        'bodyweight': fit.bodyweight.length,
        'notes': fit.notes.length,
        'places': fit.places.length,
      }, counts);

      expect(fit.profile.name, 'Upgrade');
      expect(fit.profile.activity, 1.55);
      expect({for (final r in fit.routines) r.name: r.group},
          {'Upper': 'Upper / Lower', 'Lower': 'Upper / Lower', 'Pull day': ''});
      expect({for (final e in fit.weeklyPlan.entries) e.key: fit.routineById(e.value)!.name},
          {1: 'Upper', 3: 'Lower', 5: 'Upper', 6: 'Pull day'});
      expect({for (final e in fit.progressRules.entries) fit.exerciseById(e.key)!.name: e.value.kind}, {
        'Barbell Bench Press': ProgressKind.linear,
        'Barbell Full Squat': ProgressKind.double,
        'Barbell Bent Over Row': ProgressKind.volume,
        'Seated Dumbbell Shoulder Press': ProgressKind.amrap,
        'Dumbbell Biceps Curl': ProgressKind.manual,
        'Leg Press': ProgressKind.linear,
        'Cable Pulldown': ProgressKind.double,
      });
      expect(fit.progressRules[_id('Barbell Bent Over Row')]!.maxSets, 5);
      expect(fit.isRepsOnly(_id('Pull-up')), isFalse, reason: 'its reps-only default was switched off');
      expect(fit.bodyweight.first.kg, 84.0);
      expect({for (final n in fit.notes) n.text}, {'Felt strong, elbows tucked', 'Depth check next time'});
      expect({for (final p in fit.places) p.name}, {'Main gym', 'Home'});
      expect(fit.nutritionGoalsSet, isTrue);
      expect(fit.weightGoalKg, 80);
      expect(fit.deloadEvery, _expected['deloadEvery']);

      // Every key of the backup comes back out of the fork unchanged.
      final upstream = (jsonDecode(_backup) as Map).cast<String, dynamic>();
      final mine = _export();
      // Upstream v2.4.0 added the minerals tracker; like upstream itself, the fork lists it among the known
      // trackers after reading an older backup. Every other part of the nutrition key must be unchanged.
      final known = (mine['nutrition'] as Map)['trkKnown'] as List;
      final knownBefore = ((upstream['nutrition'] as Map)['trkKnown'] as List).toSet();
      expect(known.where((n) => !knownBefore.contains(n)), ['minerals']);
      expect(known.toSet().containsAll(knownBefore), isTrue);
      (mine['nutrition'] as Map)['trkKnown'] = (upstream['nutrition'] as Map)['trkKnown'];
      final differs = [
        for (final k in upstream.keys)
          if (jsonEncode(mine[k]) != jsonEncode(upstream[k])) k,
      ];
      expect(differs, isEmpty, reason: 'keys that changed in a round trip through the fork');
      expect(mine.keys.toSet().difference(upstream.keys.toSet()), isEmpty);
    });

    test('leaves every coach module off and writes no coach key', () {
      for (final m in CoachModule.values) {
        expect(fit.coach.isOn(m), isFalse, reason: m.name);
      }
      expect(_export().containsKey('coach'), isFalse);

      fit.setCoachModule(CoachModule.nutrition, true);
      expect(_export().containsKey('coach'), isTrue);
      fit.setCoachModule(CoachModule.nutrition, false);
      expect(_export().containsKey('coach'), isFalse);
    });

    test('gives the stock suggestions upstream gives for the same data', () {
      final targets = (_expected['nextTargets'] as Map).cast<String, dynamic>();
      for (final e in targets.entries) {
        expect(jsonEncode(_target(e.key)), jsonEncode(e.value), reason: fit.exerciseById(e.key)!.name);
      }
      expect(fit.suggestedGoals.toJson(), _expected['suggestedGoals']);
      expect(fit.activeGoals.toJson(), _expected['activeGoals']);

      // The calendar deload, moved by its start date (the app reads the clock).
      final from = fit.deloadFrom;
      final deload = (_expected['deloadByWeeksSinceStart'] as Map).cast<String, dynamic>();
      for (final e in deload.entries) {
        fit.deloadFrom = DateTime.now().subtract(Duration(days: int.parse(e.key) * 7));
        expect({'deloadWeek': fit.deloadWeek, 'weeksToDeload': fit.weeksToDeload}, e.value, reason: 'week ${e.key}');
      }
      fit.deloadFrom = from;
    });

    test('the coach works on it once switched on', () {
      final bench = _id('Barbell Bench Press');
      fit.setCoachModule(CoachModule.progression, true);
      fit.setProgressRule(bench, fit.coachAutoRule(bench, fit.progressRule(bench)));
      expect(fit.progressRule(bench).kind, ProgressKind.auto);
      expect(fit.nextTarget(bench), isNotNull);
      expect(fit.coachTargetLabel(bench), isNotNull);
      expect(fit.coachWhy(bench), isNotNull);

      final own = {for (final r in fit.routines) r.id: r.name};
      fit.coach = fit.coach.copyWith(
        profile: CoachProfile.answered(
            goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: const [1, 3, 5], minutes: 60, activity: 1.55),
      );
      fit.setCoachModule(CoachModule.plan, true);
      fit.coachBuildPlan();
      expect(fit.coach.block, isNotNull);
      expect(fit.coach.routineIds, isNotEmpty);
      for (final id in fit.coach.routineIds.values) {
        expect(fit.routineById(id)!.group, 'Coach');
      }
      for (final e in own.entries) {
        expect(fit.routineById(e.key)?.name, e.value, reason: 'the user\'s own routines stay');
      }

      fit.setCoachModule(CoachModule.recovery, true);
      fit.setCoachModule(CoachModule.nutrition, true);
      fit.coachTick();
      expect(fit.activeGoals.toJson(), _expected['activeGoals'], reason: 'goals set by hand always win');
      expect(fit.suggestedGoals.toJson(), isNot(_expected['suggestedGoals']));
      expect(_export()['coach'], isA<Map>());
    });
  });

  test('an upstream v2.3.0 ZIP backup restores, its photo included', () async {
    final ok = await restoreBackupZip(File('$_dir/upstream_backup_v2.3.0.zip').readAsBytesSync());
    expect(ok, isTrue);
    expect(fit.sessions.length, (_expected['counts'] as Map)['sessions']);
    expect(fit.routines.length, (_expected['counts'] as Map)['routines']);
    final withPhoto = fit.notes.where((n) => n.media.isNotEmpty).toList();
    expect(withPhoto, hasLength(1));
    expect(await MediaStore.readBytes(withPhoto.single.media.single), hasLength(8));
    for (final m in CoachModule.values) {
      expect(fit.coach.isOn(m), isFalse, reason: m.name);
    }
    expect(_export().containsKey('coach'), isFalse);
  });
}
