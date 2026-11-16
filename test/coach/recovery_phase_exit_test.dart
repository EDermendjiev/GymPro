// SPDX-License-Identifier: GPL-3.0-only
// Phase 5 exit: eight seeded weeks of logs (after four of history), reviewed week by week through coachTick, produce a status suggestion, a
// plateau proposal and a deload proposal, each at the week the logs call for it; and every proposal made can be
// applied and undone exactly.
import 'dart:convert';

import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/health_metrics.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The block starts on this Monday; the reviews run on the eight Mondays after it.
const String _start = '2026-09-21';

DateTime _day(String iso, [int hour = 9]) => DateTime.parse(iso).add(Duration(hours: hour));

String _state() => jsonEncode({
      'coach': fit.coach.toJson(),
      'routines': [for (final r in fit.routines) r.toJson()],
      'week': {for (final e in fit.weeklyPlan.entries) '${e.key}': e.value},
    });

/// Logs week [w] (0 is the block's first; earlier weeks come before it): every session of the block's first week on the same weekday, at the same loads and reps
/// as always (no progress), with the night's sleep and the energy rating. Week 6 sleeps badly and has no energy.
void _logWeek(int w, Map<String, List<ck.PlannedExercise>> templates, Map<String, int> weekday) {
  final bad = w == 6;
  for (var d = 0; d < 7; d++) {
    final day = ck.addDays(_start, w * 7 + d);
    fit.healthByDay.putIfAbsent(HealthMetric.sleep, () => {})[HealthMetrics.dayKey(DateTime.parse(day))] = [
      bad ? 300 : 480,
    ];
  }
  for (final e in templates.entries) {
    final day = ck.addDays(_start, w * 7 + weekday[e.key]! - 1);
    fit.sessions.add(LoggedSession(_day(day, 18), 3600, [
      for (final x in e.value)
        LoggedExercise(x.exerciseId, fit.exerciseById(x.exerciseId)!.name, fit.exerciseById(x.exerciseId)!.primary, [
          for (var i = 0; i < x.sets; i++) LoggedSet(x.repMin, 40, rpe: 8),
        ]),
    ], routineId: fit.coach.routineIds[e.key], energy: bad ? 1 : 4));
  }
  fit.sessions.sort((a, b) => a.date.compareTo(b.date));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  tearDown(() => fit.coachClock = DateTime.now);

  test('eight weeks: the status suggestion, the plateau and the deload arrive when the logs call for them', () {
    fit.coachClock = () => _day(_start);
    fit.coachApplyAnswers(CoachAnswers(goal: CoachGoal.leanGain, status: CoachStatus.intermediate, days: [1, 3, 5]));
    fit.setCoachModule(CoachModule.recovery, true);
    fit.setCoachAskFirst(true); // keep the block as it is, so every week logs the same
    fit.coachTick(); // the first run only sets the week
    final block = fit.coach.block!;
    final templates = <String, List<ck.PlannedExercise>>{};
    final weekday = <String, int>{};
    for (final s in block.sessions.where((s) => s.weekIndex == 0)) {
      templates[s.templateKey] = [for (final e in s.exercises) if (e.isMainLiftSingle != true) e];
      weekday[s.templateKey] = ck.isoWeekday(s.date);
    }

    // Four weeks of the same work before the block: the history the status inference needs (eight weeks).
    for (var w = -4; w < 0; w++) {
      _logWeek(w, templates, weekday);
    }
    final firstSeen = <String, int>{};
    for (var w = 0; w < 8; w++) {
      _logWeek(w, templates, weekday);
      fit.coachClock = () => _day(ck.addDays(_start, (w + 1) * 7));
      fit.coachTick();
      for (final p in fit.coachProposals) {
        firstSeen.putIfAbsent(p.kind.wire, () => w);
      }
    }
    // ignore: avoid_print
    print('first seen, by reviewed week: $firstSeen');
    // Flat logs: from the eighth week of logs (the review after week 3) the inference reads an advanced lifter's
    // pace, and the second review in a row suggests the change.
    expect(firstSeen['status_change'], 4);
    // No progress on the anchors for longer than an intermediate's window (four weeks): already at the first review.
    expect(firstSeen['plateau_action'], 0);
    // The block's last week is reviewed: a new block is proposed.
    expect(firstSeen['block_transition'], block.weeks - 1);
    // Week 6 (the seventh): short sleep and no energy, two recovery flags.
    expect(firstSeen['standard_deload'], 6);

    // Every proposal made can be applied and undone exactly.
    for (final p in fit.coachProposals.where((p) => p.state == CoachProposalState.pending).toList()) {
      final before = _state();
      expect(fit.applyCoachProposal(p.id), isTrue, reason: p.kind.wire);
      fit.undoCoachProposal(p.id);
      expect(_state(), before, reason: p.kind.wire);
    }
  });
}
