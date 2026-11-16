// SPDX-License-Identifier: GPL-3.0-only
// Task 5.4: a need-based deload from the coach. In its week every exercise keeps its loads and drops to sets × 0.6
// rounded half up (the standard deload of fixture G6); the calendar's deloads are superseded while the recovery
// module is on, and work as before while it is off.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/live_session.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime _monday = DateTime(2026, 11, 16, 9);

void _plan() {
  fit.coach = fit.coach.copyWith(
    profile: CoachProfile.answered(
        goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: const [1, 3, 5], minutes: 60, activity: 1.375),
  );
  fit.setCoachModule(CoachModule.progression, true);
  fit.setCoachModule(CoachModule.plan, true);
  fit.setCoachModule(CoachModule.recovery, true);
  fit.setCoachAskFirst(true);
  fit.coachBuildPlan();
}

String _id(String name) => fit.allExercises.firstWhere((e) => e.name == name).id;

void _propose(String kind, Map<String, dynamic> payload) {
  fit.coach = fit.coach.copyWith(proposals: [
    ...fit.coach.proposals,
    {'id': 'p-$kind', 'kind': kind, 'state': 'pending', 'createdOn': '2026-11-16', 'payload': payload},
  ]);
}

List<SessionSet> _working(String exerciseId) => fit.session!.exercises
    .firstWhere((e) => e.id == exerciseId)
    .sets
    .where((s) => s.kind != SetKind.warmup)
    .toList();

/// The working sets of every exercise of [r] when it starts [on], by exercise id.
Map<String, List<(int, double)>> _start(Routine r, DateTime on) {
  fit.coachClock = () => on;
  fit.startRoutine(r);
  final out = {
    for (final e in fit.session!.exercises) e.id: [for (final s in _working(e.id)) (s.reps, s.weight)],
  };
  fit.saveAndExit();
  return out;
}

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

  test('a coach routine in the deload week opens with sets × 0.6 rounded half up, at the same loads', () {
    _plan();
    final week2 = fit.coach.block!.sessions.firstWhere((s) => s.weekIndex == 1);
    final day = DateTime.parse(week2.date).add(const Duration(hours: 9));
    final r = fit.routineById(fit.coach.routineIds[week2.templateKey]!)!;
    final before = _start(r, day);

    _propose('standard_deload', {'weekStart': ck.mondayOf(week2.date), 'setCutPct': 0.4, 'mode': 'sets'});
    fit.coachClock = () => _monday;
    expect(fit.applyCoachProposal('p-standard_deload'), isTrue);
    expect(fit.deloadWeek, isFalse); // week 1: not the deload week

    final after = _start(r, day);
    fit.coachClock = () => day;
    expect(fit.deloadWeek, isTrue);
    for (final e in before.entries) {
      final n = e.value.length;
      expect(after[e.key], hasLength(ck.roundHalfUp(n * 0.6) < 1 ? 1 : ck.roundHalfUp(n * 0.6)), reason: e.key);
      for (final (i, s) in after[e.key]!.indexed) {
        expect(s.$2, e.value[i].$2, reason: '${e.key}: the load stays');
      }
    }
    expect(before.values.any((v) => v.length != ck.roundHalfUp(v.length * 0.6)), isTrue, reason: 'something is cut');
  });

  test('a routine of the user\'s own in that week: 5 sets become 3, loads unchanged', () {
    _plan();
    final mine = fit.createRoutine('Mine');
    final bench = _id('Barbell Bench Press');
    fit.toggleRoutineExercise(mine, bench);
    fit.bumpRoutineSets(mine, bench, 5 - fit.routineSets(fit.routineById(mine)!, bench));
    fit.sessions.add(LoggedSession(DateTime(2026, 11, 10, 12), 3600, [
      LoggedExercise(bench, 'Barbell Bench Press', 'chest', [for (var i = 0; i < 5; i++) LoggedSet(8, 60)]),
    ]));
    final r = fit.routineById(mine)!;
    final next = DateTime(2026, 11, 24, 9);
    final before = _start(r, next)[bench]!;
    _propose('standard_deload', {'weekStart': '2026-11-23', 'setCutPct': 0.4, 'mode': 'sets'});
    fit.coachClock = () => _monday;
    fit.applyCoachProposal('p-standard_deload');
    final after = _start(r, next)[bench]!;
    expect(before, hasLength(5));
    expect(after, hasLength(3));
    expect([for (final s in after) s.$2], [for (final s in before.take(3)) s.$2]);
  });

  test('while the recovery module is on the calendar\'s deload is superseded; while it is off it works as before', () {
    fit.setDeloadEvery(4);
    fit.deloadFrom = DateTime.now().subtract(const Duration(days: 21));
    expect(fit.deloadWeek, isTrue);
    _plan();
    expect(fit.deloadWeek, isFalse);
    fit.setCoachModule(CoachModule.recovery, false);
    expect(fit.deloadWeek, isTrue);
  });
}
