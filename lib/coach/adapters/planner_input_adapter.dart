// SPDX-License-Identifier: GPL-3.0-only
// The app's state as the plan designer's input (PlannerProfile): the coaching profile's answers, the app profile's
// body data, the place's equipment, sports, injuries, dislikes, accepted volume changes and the level the logs show.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_planner/coach_planner.dart' as cpl;
import 'package:coach_progression/coach_progression.dart' as cp;
import 'package:coach_training/coach_training.dart' as ct;

import '../model/coach_choices.dart';
import '../model/coach_plan.dart';
import 'block_input_adapter.dart';
import 'catalog_adapter.dart';
import 'equipment_map.dart';
import 'history_adapter.dart';

/// The training status the logs show (eight weeks or more of them), or null.
ck.Status? coachLogStatus(CoachPlanInputs i) {
  final sets = coachSets(i.sessions, since: '0000-01-01', skip: i.skip, bodyweight: i.bodyweight);
  final mains = {
    for (final e in coachPlanLibrary(i.exercises, archived: const {}))
      if (e.isMainLift) e.id,
  };
  final anchors = <String>{
    for (final s in sets)
      if (mains.contains(s.exerciseId)) s.exerciseId,
    for (final s in i.sessions)
      for (final e in s.exercises.where((e) => !i.skip(e.id)).take(1)) e.id,
  };
  return cp
      .inferTrainingStatus(cp.TrainingStatusInput(sets: sets, today: coachIsoDay(i.today), anchorExerciseIds: [...anchors]))
      .status;
}

/// The slot tags the place's equipment and the user's exercises can fill: the tags of every exercise the block
/// generator could pick (annotated, not archived, not disliked, possible with the equipment and the injuries).
Set<ck.SlotTag> coachAvailableTags(CoachPlanInputs i) {
  final feasibility = ct.FeasibilityContext(
    equipment: [...coachEquipment(i.equipment)],
    injuries: [...i.coach.injuries],
    disliked: [...i.coach.disliked],
  );
  return {
    for (final e in coachPlanLibrary(i.exercises, archived: i.archived))
      if (ct.isFeasible(e, feasibility)) ...e.slotTags,
  };
}

ck.Sex _sex(String? sex) => switch (sex) {
      'male' => ck.Sex.male,
      'female' => ck.Sex.female,
      _ => ck.Sex.unspecified,
    };

/// The plan designer's input for [i]. [previousSplitKey] and [previousMedianTarget] come from the current block when
/// there is one, so a new block prefers its split and starts from its volume.
cpl.PlannerProfile coachPlannerProfile(CoachPlanInputs i, {String? previousSplitKey, double? previousMedianTarget}) {
  final profile = i.coach.profile;
  final tracked = {for (final m in ck.TRACKED_MUSCLES) m.wire: m};
  return cpl.PlannerProfile(
    goal: profile?.goal ?? ck.Goal.leanGain,
    priority: profile?.priority ?? ck.Priority.lifting,
    answeredStatus: profile?.status,
    logStatus: coachLogStatus(i),
    years: profile?.years == null ? null : cpl.YearsTraining.fromWire(profile!.years!.wire),
    age: i.age,
    sex: _sex(i.sex),
    bodyweightKg: i.weightKg,
    heightCm: i.heightCm,
    lifestyle: profile?.lifestyle ?? ck.Lifestyle.lightlyActive,
    days: profile == null || profile.days.isEmpty ? coachSpreadDays(i.weeklyGoal) : [...profile.days],
    minutes: profile?.minutes ?? 60,
    style: cpl.StylePref.fromWire((profile?.style ?? CoachStyle.auto).wire),
    sessionPref: cpl.SessionPref.fromWire((profile?.sessionPref ?? CoachSessionPref.auto).wire),
    focus: [
      for (final a in profile?.focus ?? const []) ?tracked[a.wire],
    ],
    equipment: [...coachEquipment(i.equipment)],
    availableTags: coachAvailableTags(i),
    injuries: [...i.coach.injuries],
    sports: [...i.coach.sports],
    strengthLifts: profile?.strengthLifts == null
        ? null
        : [for (final l in profile!.strengthLifts!) ck.MainLift.fromWire(l.wire)],
    knownLifts: {for (final e in (profile?.knownLifts ?? const {}).entries) e.key.wire: e.value},
    targetAdjustments: coachTargetAdjustments(i.coach.review),
    previousMedianTarget: previousMedianTarget,
    previousSplitKey: previousSplitKey,
  );
}
