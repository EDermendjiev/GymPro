// SPDX-License-Identifier: GPL-3.0-only
// The one door between the app's state and the coach packages: the app's own types go in, the app's own types
// or `Coach*` values come out. Package types never leave this layer by name.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_nutrition/coach_nutrition.dart' as cn;
import 'package:coach_progression/coach_progression.dart' as cp;

import '../models/exercise.dart';
import '../models/workout.dart';
import 'adapters/category_adapter.dart';
import 'adapters/exposure_adapter.dart';
import 'adapters/nutrition_adapter.dart';
import 'model/coach_data.dart';
import 'model/coach_nutrition.dart';
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

  /// What the sets after the first working set should look like, now that it was done with [reps] reps at
  /// [loadKg]: missing the rep range moves the load by about 4 % per rep, onto the [incrementKg] grid.
  static CoachSetTarget nextSet({
    required CoachRx rx,
    required double? loadKg,
    required int reps,
    required double incrementKg,
    int setIndex = 0,
  }) {
    final s = cp.suggestNextSet(
      ck.SetContext(rx: _setRx(rx), setIndex: setIndex, load: loadKg, reps: reps, increment: incrementKg),
    );
    return CoachSetTarget(loadKg: s.load, reps: s.repsTarget, ruleIds: s.ruleIds);
  }

  /// The plain-words summary of each known rule in [ruleIds], in order, each once. English: the rule texts live in
  /// the coach packages.
  static List<String> ruleSummaries(Iterable<String> ruleIds) => [
        for (final id in {...ruleIds})
          if (ck.RULES[id] case final rule?) rule.summary,
      ];

  /// The warm-up ramp before a compound worked at [workingKg], on the [incrementKg] grid. Empty under 40 kg.
  static List<CoachWarmupSet> warmup(double workingKg, double incrementKg) => [
        for (final w in cp.warmupRamp(workingKg, incrementKg)) CoachWarmupSet(loadKg: w.load, reps: w.reps),
      ];

  // ---------- Nutrition ----------

  /// The coach's daily calorie and macro targets for someone weighing [bodyweightKg], of app sex [sex] and app
  /// activity multiplier [activity], with what [coach] knows: training status and goal from its profile, the
  /// sports, and the phase the user picked under `nutrition.phase`.
  ///
  /// Without a picked phase the phase follows the coaching goal, and without a coaching profile it is maintain;
  /// without a profile the status is novice. The activity band is the one nearest to [activity]. Everything else
  /// the calculation can take (body fat, target rate, logged sport efforts, calorie override) is left at the
  /// coach's defaults.
  static CoachNutritionTargets nutritionTargets({
    required double bodyweightKg,
    required String sex,
    required double activity,
    required CoachData coach,
  }) {
    final profile = coach.profile;
    final picked = CoachNutritionPhase.fromWire(coach.nutrition['phase']);
    final phase = picked != null
        ? ck.NutritionPhase.fromWire(picked.wire)
        : profile != null
            ? cn.phaseForGoal(profile.goal)
            : ck.NutritionPhase.maintain;
    final t = cn.nutritionTargets(cn.NutritionInput(
      bodyweightKg: bodyweightKg,
      sex: coachSexFor(sex),
      status: profile?.status ?? ck.Status.novice,
      phase: phase,
      lifestyle: coachLifestyleFor(activity),
      sports: [for (final s in coach.sports) cn.SportForKcal.fromUserSport(s)],
    ));
    return CoachNutritionTargets(
      kcal: t.kcal,
      proteinG: t.proteinG.round(),
      fatG: t.fatG.round(),
      carbsG: t.carbsG.round(),
      phase: CoachNutritionPhase.fromWire(t.phase.wire)!,
      phasePicked: picked != null,
      bodyweightKg: bodyweightKg,
      maintenance: t.maintenance,
      delta: t.delta,
      warnings: [for (final w in t.warnings) w.message],
      ruleIds: [...t.ruleIds, for (final w in t.warnings) ...w.ruleIds],
    );
  }

  static ck.SetRx _setRx(CoachRx rx) =>
      ck.SetRx(repMin: rx.repMin, repMax: rx.repMax, rirMin: rx.rirMin, rirMax: rx.rirMax);
}
