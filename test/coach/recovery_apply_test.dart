// SPDX-License-Identifier: GPL-3.0-only
// Task 5.5: the autonomy tiers, and apply then undo for every proposal kind restoring exactly what was there.
import 'dart:convert';

import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/adapters/catalog_adapter.dart';
import 'package:gymmane/coach/coach.dart';
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
  fit.setCoachModule(CoachModule.nutrition, true);
  fit.setCoachAskFirst(true);
  fit.coachBuildPlan();
}

void _propose(String kind, Map<String, dynamic> payload) {
  fit.coach = fit.coach.copyWith(proposals: [
    ...fit.coach.proposals,
    {'id': 'p-$kind', 'kind': kind, 'state': 'pending', 'createdOn': '2026-11-16', 'title': 't', 'payload': payload},
  ]);
}

/// Everything an apply may change and an undo must put back.
String _state() => jsonEncode({
      'coach': fit.coach.toJson(),
      'routines': [for (final r in fit.routines) r.toJson()],
      'week': {for (final e in fit.weeklyPlan.entries) '${e.key}': e.value},
      'rules': {for (final e in fit.progressRules.entries) e.key: e.value.toJson()},
    });

/// A valid payload of every kind, for the plan [_plan] builds.
Map<String, Map<String, dynamic>> _payloads() {
  final block = fit.coach.block!;
  final first = block.sessions.first.exercises.first.exerciseId;
  final library = coachPlanLibrary(fit.allExercises, archived: const {});
  final def = library.firstWhere((e) => e.id == first);
  final planned = {for (final s in block.sessions) for (final e in s.exercises) e.exerciseId};
  final swapTo = library.firstWhere((e) => !planned.contains(e.id) && e.category == def.category);
  final kcal = fit.coachNutritionTargets!.kcal;
  return {
    'standard_deload': {'weekStart': '2026-11-23', 'setCutPct': 0.4, 'mode': 'sets'},
    'targeted_deload': {
      'weekStart': '2026-11-23',
      'muscles': ['chest'],
      'removeExerciseIds': [first],
      'reduceSetsPct': 0.5,
      'mode': 'deload',
    },
    'intro_week': {'blockId': 'block-${block.startsOn}', 'setPct': 0.75, 'rirBump': 1},
    'volume_change': {
      'changes': [
        {'muscle': 'chest', 'from': 12, 'to': 10},
      ],
    },
    'exercise_swap': {'plannedExerciseIds': <String>[], 'fromExerciseId': first, 'toExerciseId': swapTo.id, 'reason': 'disliked'},
    'block_transition': {'fromKind': 'hypertrophy', 'toKind': 'hypertrophy', 'startsOn': '2026-11-23'},
    'plan_regenerate': {'reason': 'days changed'},
    'calorie_adjust': {'fromKcal': kcal, 'toKcal': kcal - 150, 'reason': 'slow'},
    'multiplier_adjust': {'from': 1.55, 'to': 1.75, 'reason': 'initial week check'},
    'status_change': {'from': 'intermediate', 'to': 'advanced', 'evidence': 'flat'},
    'plateau_action': {
      'exerciseId': first,
      'step': 'add_volume',
      'details': '+2 sets/week',
      'changes': [
        {'muscle': 'chest', 'from': 12, 'to': 14},
      ],
    },
    'injury_adjust': {
      'injuryId': null,
      'muscle': 'erectors',
      'severity': 'pain',
      'label': 'Lower back pain (from check-ins)',
      'removeExerciseIds': <String>[],
      'addExerciseIds': <String>[],
    },
  };
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

  tearDown(() => fit.coachClock = DateTime.now);

  group('autonomy tiers', () {
    test('the table: six kinds apply with undo, six ask first', () {
      const undo = {'intro_week', 'standard_deload', 'targeted_deload', 'exercise_swap', 'plan_regenerate', 'block_transition'};
      for (final k in CoachProposalKind.values) {
        expect(coachTierFor(k), undo.contains(k.wire) ? CoachAutonomyTier.applyWithUndo : CoachAutonomyTier.ask,
            reason: k.wire);
      }
      expect(CoachProposalKind.values, hasLength(12));
    });

    test('"Ask me before any change" moves every kind to ask', () {
      for (final k in CoachProposalKind.values) {
        expect(coachTierFor(k, askFirst: true), CoachAutonomyTier.ask, reason: k.wire);
      }
    });

    test('the tick applies the middle tier by itself and leaves the rest pending', () {
      _plan();
      fit.setCoachAskFirst(false);
      // A long break: the review proposes an intro week, which the coach applies with Undo.
      fit.coach = fit.coach.copyWith(review: {'lastWeekStart': '2026-11-02'});
      fit.coachClock = () => DateTime(2026, 12, 6, 9);
      fit.coachTick();
      final intro = fit.coachProposals.firstWhere((p) => p.kind == CoachProposalKind.introWeek);
      expect(intro.state, CoachProposalState.applied);
      expect(fit.coachCardProposals.map((p) => p.id), contains(intro.id));
      expect(fit.canUndoCoachProposal(intro.id), isTrue);
    });
  });

  group('apply then undo restores exactly what was there', () {
    for (final kind in CoachProposalKind.values) {
      test(kind.wire, () {
        _plan();
        final payload = _payloads()[kind.wire]!;
        _propose(kind.wire, payload);
        final before = _state();
        expect(fit.applyCoachProposal('p-${kind.wire}'), isTrue);
        final applied = fit.coachProposals.firstWhere((p) => p.id == 'p-${kind.wire}');
        expect(applied.state, CoachProposalState.applied);
        expect(_state(), isNot(before));
        fit.undoCoachProposal('p-${kind.wire}');
        expect(_state(), before);
        expect(fit.coachProposals.firstWhere((p) => p.id == 'p-${kind.wire}').state, CoachProposalState.pending);
      });
    }
  });

  group('what applying does', () {
    test('an invalid payload is put aside, never applied', () {
      _plan();
      _propose('standard_deload', {'weekStart': '2026-11-23', 'setCutPct': 0.9, 'mode': 'sets'});
      final block = jsonEncode(fit.coach.block!.toJson());
      expect(fit.applyCoachProposal('p-standard_deload'), isFalse);
      expect(fit.coachProposals.single.state, CoachProposalState.dismissed);
      expect(jsonEncode(fit.coach.block!.toJson()), block);
    });

    test('a status change sets the profile\'s status and rebuilds the plan', () {
      _plan();
      _propose('status_change', _payloads()['status_change']!);
      fit.applyCoachProposal('p-status_change');
      expect(fit.coach.profile!.coachStatus, CoachStatus.advanced);
    });

    test('an injury from check-ins is recorded, and a calorie change moves the coach\'s target', () {
      _plan();
      final kcal = fit.coachNutritionTargets!.kcal;
      _propose('injury_adjust', _payloads()['injury_adjust']!);
      _propose('calorie_adjust', _payloads()['calorie_adjust']!);
      fit.applyCoachProposal('p-injury_adjust');
      fit.applyCoachProposal('p-calorie_adjust');
      expect(fit.coach.injuries.single.muscleId, ck.MuscleId.erectors);
      expect(fit.coachNutritionTargets!.kcal, kcal - 150);
      expect(fit.coach.nutrition['lastAdjustOn'], '2026-11-16');
    });

    test('a swap changes the coach routine\'s exercise', () {
      _plan();
      final p = _payloads()['exercise_swap']!;
      _propose('exercise_swap', p);
      fit.applyCoachProposal('p-exercise_swap');
      final ids = [for (final id in fit.coach.routineIds.values) ...fit.routineById(id)!.exerciseIds];
      expect(ids, contains(p['toExerciseId']));
      expect(ids, isNot(contains(p['fromExerciseId'])));
    });

    test('"Not now" puts a proposal aside, and the switch is stored', () {
      _plan();
      _propose('plan_regenerate', _payloads()['plan_regenerate']!);
      fit.dismissCoachProposal('p-plan_regenerate');
      expect(fit.coachProposals.single.state, CoachProposalState.dismissed);
      expect(fit.coachCardProposals, isEmpty);
      expect(fit.coachAskFirst, isTrue);
      fit.setCoachAskFirst(false);
      expect(fit.coach.review.containsKey('askFirst'), isFalse);
    });
  });
}
