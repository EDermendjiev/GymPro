// SPDX-License-Identifier: GPL-3.0-only
// Shows what the coach's state asked the workout screen to show: the first-set correction, with the app's own
// toast and its Undo, and the one effort question, with the screen's own effort picker.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../models/live_session.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/liquid_notch.dart';
import '../model/coach_prompt.dart';

/// Opens the workout screen's effort picker for one set, as the screen does when its effort cell is tapped.
typedef CoachAskEffort = Future<void> Function(BuildContext context, int exIdx, int setIdx, double? rpe);

/// Called by the workout screen each time it builds. Takes the waiting coach requests, if any, and shows them
/// once the frame is drawn. Cheap when nothing waits.
void coachSessionPrompts(BuildContext context, CoachAskEffort askEffort) {
  if (!fit.hasCoachPrompts) return;
  final prompts = fit.takeCoachPrompts();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    for (final p in prompts) {
      if (!context.mounted) return;
      switch (p) {
        case CoachCorrectionPrompt():
          showNotchToast(
            context,
            p.title,
            subtitle: p.subtitle,
            icon: PhosphorIconsFill.target,
            accent: context.gc.accent,
            action: t.undo,
            onTap: fit.undoCoachCorrection,
            duration: const Duration(milliseconds: 4200),
          );
        case CoachEffortPrompt(:final exerciseIndex, :final setIndex):
          final st = _set(exerciseIndex, setIndex);
          if (st == null || !st.done || st.rpe != null) continue;
          await askEffort(context, exerciseIndex, setIndex, null);
      }
    }
  });
}

SessionSet? _set(int exIdx, int setIdx) {
  final s = fit.session;
  if (s == null || exIdx < 0 || exIdx >= s.exercises.length) return null;
  final sets = s.exercises[exIdx].sets;
  return setIdx < 0 || setIdx >= sets.length ? null : sets[setIdx];
}
