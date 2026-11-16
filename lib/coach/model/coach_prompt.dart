// SPDX-License-Identifier: GPL-3.0-only
// One-shot requests from the coach's state to the workout screen. The state has no widget context, so it queues
// these and the session screen takes them (see coachSessionPrompts in lib/coach/ui/session_prompts.dart).

/// Something the workout screen should show once.
sealed class CoachPrompt {
  const CoachPrompt();
}

/// The coach changed the remaining sets after the first working set: show [title] and [subtitle] with an Undo
/// action.
final class CoachCorrectionPrompt extends CoachPrompt {
  const CoachCorrectionPrompt({required this.title, required this.subtitle, required this.exerciseIndex});

  final String title;
  final String subtitle;
  final int exerciseIndex;
}

/// Ask once for the effort of the set just logged.
final class CoachEffortPrompt extends CoachPrompt {
  const CoachEffortPrompt({required this.exerciseIndex, required this.setIndex});

  final int exerciseIndex;
  final int setIndex;
}
