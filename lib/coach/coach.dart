// SPDX-License-Identifier: GPL-3.0-only
// The coach layer's public face. Screens, widgets and state import this file and nothing else under lib/coach/.
//
// Rules, enforced by test/coach/boundary_test.dart:
//  - every export has a `show` list;
//  - every exported name starts with `Coach` (or `coach` for functions), so nothing here can clash with the
//    app's own names;
//  - a coach package is never re-exported.
library;

export 'model/coach_choices.dart' show CoachAnswers, CoachBlockKind, CoachGoal, CoachLift, CoachSessionPref, CoachStatus, CoachStyle, CoachYears, coachSessionLengths;
export 'model/coach_data.dart' show CoachData, CoachModule;
export 'model/coach_nutrition.dart' show CoachNutritionPhase, CoachNutritionReview, CoachNutritionTargets;
export 'model/coach_plan.dart' show CoachBlockSummary, CoachBuiltPlan, CoachOpeningSet, CoachPlanInputs, CoachPlanOption, CoachPlanPreview, CoachQuickSession, CoachRoutineExercise, CoachRoutinePlan;
export 'model/coach_profile.dart' show CoachProfile;
export 'model/coach_recovery.dart' show CoachArea, CoachAutonomyTier, CoachCheckin, CoachInjuryEntry, CoachInjurySeverity, CoachProposal, CoachProposalKind, CoachProposalState, CoachReview, CoachSoreness, CoachSportChoice, CoachSportEntry, CoachSportIntensity;
export 'model/coach_prompt.dart' show CoachCorrectionPrompt, CoachEffortPrompt, CoachPrompt;
export 'model/coach_targets.dart' show CoachRx, CoachSessionTarget, CoachSetTarget, CoachWarmupSet;
export 'facade.dart' show CoachFacade;
export 'policy/autonomy.dart' show coachTierFor;
export 'ui/session_prompts.dart' show CoachAskEffort, coachSessionPrompts;
export 'ui/why_sheet.dart' show CoachTargetLine;
export 'ui/nutrition_goals_card.dart' show CoachGoalsCard;
export 'ui/coach_settings.dart' show CoachSettings, CoachSettingsRow, coachSettingsIcon, coachSettingsSearchRows;
export 'ui/onboarding_pages.dart' show CoachGoalChoices, CoachLengthChips, CoachLevelChoices, CoachPageFrame, coachOnboardingPageCount, coachOnboardingPages;
export 'ui/proposal_card.dart' show CoachHomeSlot, CoachProposalCard;
export 'ui/recovery_sheets.dart' show CoachHomeHint, coachShowInjurySheet, coachShowSportsSheet;
export 'ui/soreness_sheet.dart' show CoachSorenessRow, coachAreaLabel, coachShowSorenessSheet;
export 'ui/plan_ui.dart' show CoachPlanWhy, CoachQuickMinutes, coachBlockKindLabel;
export 'ui/week_ahead.dart' show CoachWeekAhead, CoachWeekAheadRow, coachWeekAheadRows;
