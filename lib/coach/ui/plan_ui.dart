// SPDX-License-Identifier: GPL-3.0-only
// The plan module on the Home card and the train screen: the block's name, "Why this plan", and the quick-workout
// length chips.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../models/workout.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_kit.dart';
import '../model/coach_choices.dart';
import '../model/coach_data.dart';

/// The block kind's name.
String coachBlockKindLabel(CoachBlockKind kind) => switch (kind) {
      CoachBlockKind.hypertrophy => t.coachBlockHypertrophy,
      CoachBlockKind.strengthVolume => t.coachBlockStrengthVolume,
      CoachBlockKind.strengthLoad => t.coachBlockStrengthLoad,
      CoachBlockKind.strengthPeak => t.coachBlockStrengthPeak,
      CoachBlockKind.sportSupport => t.coachBlockSportSupport,
    };

/// "Why this plan" under a coach routine on the Home card. Draws nothing for any other routine, or while the
/// plan module is off.
class CoachPlanWhy extends StatelessWidget {
  const CoachPlanWhy({super.key, required this.routine});

  final Routine? routine;

  @override
  Widget build(BuildContext context) {
    final r = routine;
    if (r == null || fit.coachBlockLabel(r) == null) return const SizedBox.shrink();
    final gc = context.gc;
    return Semantics(
      button: true,
      label: t.coachPlanWhy,
      child: GestureDetector(
        key: const ValueKey('coach-plan-why'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showCoachPlanWhySheet(context),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(PhosphorIconsRegular.info, size: 13, color: gc.brass),
            const SizedBox(width: 6),
            Flexible(
              child: Text(t.coachPlanWhy,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The sheet that explains the block: its kind and week, why it looks the way it does, the coach's warnings and
/// the plain-words summary of every rule behind it.
void showCoachPlanWhySheet(BuildContext context) {
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) {
      final gc = sheet.gc;
      final s = fit.coachPlanSummary;
      Widget line(String text, IconData icon) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 3), child: Icon(icon, size: 14, color: gc.brass)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
              ),
            ]),
          );
      Widget label(String text) => Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(text, style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textTertiary)),
          );
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
        child: Container(
          decoration: sheetDecoration(gc),
          child: SingleChildScrollView(
            padding: sheetPad(sheet),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                SheetTitle(t.coachPlanWhy),
                if (s != null) ...[
                  const SizedBox(height: 6),
                  Text(t.coachBlockWeek(coachBlockKindLabel(s.kind), s.week, s.weeks),
                      style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.text, height: 1.35)),
                  const SizedBox(height: 14),
                  label(t.coachPlanWhyNote),
                  for (final e in s.explanations) line(e, PhosphorIconsRegular.lightbulb),
                  if (s.warnings.isNotEmpty) ...[
                    label(t.coachPlanWarnings),
                    for (final w in s.warnings) line(w, PhosphorIconsRegular.warning),
                  ],
                  for (final r in s.rules) line(r, PhosphorIconsRegular.bookOpen),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The length chips of a quick workout on the train screen (20, 30, 45, 60 minutes). Draws nothing while the
/// plan module is off, and for a warm-up or cardio session.
class CoachQuickMinutes extends StatelessWidget {
  const CoachQuickMinutes({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: fit, builder: (context, _) => _chips(context));

  Widget _chips(BuildContext context) {
    if (!fit.coach.isOn(CoachModule.plan) || fit.trainKind != null) return const SizedBox.shrink();
    final gc = context.gc;
    final picked = fit.coachQuickMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Text(t.coachQuickLength.toUpperCase(),
            style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.2)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in CoachState.coachQuickLengths)
              Pill(
                key: ValueKey('coach-quick-$m'),
                label: t.coachMinutes(m),
                bg: m == picked ? gc.ember : gc.bgRaised2,
                fg: m == picked ? gc.onEmber : gc.textSecondary,
                onTap: () => fit.setCoachQuickMinutes(m),
                hPad: 12,
                vPad: 6,
                fontSize: 12,
              ),
          ]),
        ),
      ]),
    );
  }
}
