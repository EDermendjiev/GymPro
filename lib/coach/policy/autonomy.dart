// SPDX-License-Identifier: GPL-3.0-only
// Which proposals the coach applies by itself (with Undo) and which wait for the user. Pure: the table of the
// autonomy tiers in docs/coach/ARCHITECTURE.md.
//
// Load and rep targets, the first-set correction and moving a missed session are silent changes: they are never
// proposals, so they do not appear here.
import '../model/coach_recovery.dart';

/// The tier of a proposal of [kind]. With [askFirst] ("Ask me before any change") every proposal asks first.
CoachAutonomyTier coachTierFor(CoachProposalKind kind, {bool askFirst = false}) {
  if (askFirst) return CoachAutonomyTier.ask;
  return switch (kind) {
    CoachProposalKind.introWeek ||
    CoachProposalKind.standardDeload ||
    CoachProposalKind.targetedDeload ||
    CoachProposalKind.exerciseSwap ||
    CoachProposalKind.planRegenerate ||
    CoachProposalKind.blockTransition =>
      CoachAutonomyTier.applyWithUndo,
    CoachProposalKind.volumeChange ||
    CoachProposalKind.plateauAction ||
    CoachProposalKind.statusChange ||
    CoachProposalKind.injuryAdjust ||
    CoachProposalKind.calorieAdjust ||
    CoachProposalKind.multiplierAdjust =>
      CoachAutonomyTier.ask,
  };
}
