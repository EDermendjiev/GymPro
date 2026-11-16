// SPDX-License-Identifier: GPL-3.0-only
// The one door between the app's state and the coach packages: the app's own types go in, the app's own types
// or `Coach*` values come out. Package types never leave this layer by name.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_progression/coach_progression.dart' as cp;

import '../models/exercise.dart';
import '../models/workout.dart';
import 'adapters/category_adapter.dart';
import 'adapters/exposure_adapter.dart';
import 'model/coach_profile.dart';
import 'model/coach_targets.dart';

/// Entry points are added as the modules land. It holds no state.
abstract final class CoachFacade {
  // ---------- Progression ----------

  /// The rep range, effort range and rest the coach prescribes for [exercise] when nothing else is known about
  /// the session: the middle of the category's range, without a sport priority.
  static CoachRx rxFor(Exercise exercise) {
    final category = coachCategoryFor(exercise);
    final lower = category == ck.Category.lowerFreeCompound || category == ck.Category.lowerMachineCompound;
    final rx = cp.prescribe(
      category,
      cp.RxOptions(level: cp.RangeLevel.mid, sportPriority: false, isLowerCompound: lower),
    );
    return CoachRx(
      repMin: rx.repMin,
      repMax: rx.repMax,
      rirMin: rx.rirMin,
      rirMax: rx.rirMax,
      restSeconds: rx.restSeconds,
      ruleIds: rx.ruleIds,
    );
  }

  /// Whether the coach treats [exercise] as a compound lift.
  static bool isCompound(Exercise exercise) => cp.isCompound(coachCategoryFor(exercise));

  /// The load and reps for the first working set the next time [exercise] is done, from its logged [sessions].
  ///
  /// [rx] is the prescription in force (its rep range is the one stored on the exercise's rule), [incrementKg]
  /// the exercise's load step. The lifter's training status, when the coach knows it from [profile], turns on the
  /// check for a load that has stood still for too long.
  static CoachSessionTarget nextSession({
    required List<LoggedSession> sessions,
    required Exercise exercise,
    required CoachRx rx,
    required double incrementKg,
    CoachProfile? profile,
  }) {
    final history = coachExerciseHistory(
      sessions,
      exercise.id,
      increment: incrementKg,
      heavyLowerBarbell: coachHeavyLowerBarbell(exercise),
      status: profile?.status,
    );
    final s = cp.suggestNextSession(history, _setRx(rx));
    return CoachSessionTarget(loadKg: s.load, reps: s.repsTarget, ruleIds: s.ruleIds, hint: s.hint);
  }

  static ck.SetRx _setRx(CoachRx rx) =>
      ck.SetRx(repMin: rx.repMin, repMax: rx.repMax, rirMin: rx.rirMin, rirMax: rx.rirMax);
}
