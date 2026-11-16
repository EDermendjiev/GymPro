// SPDX-License-Identifier: GPL-3.0-only
// The coach's part of the nutrition goals sheet: who set the goals, why, and the phase they aim for.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_kit.dart';
import '../model/coach_nutrition.dart';

/// While the coach supplies the goals in force: "Set by coach" with a tap that opens the reason sheet, and the
/// phase picker. While the nutrition module is on but the user has set goals of their own: a way back to the
/// coach's goals. Nothing while the module is off.
class CoachGoalsCard extends StatelessWidget {
  const CoachGoalsCard({super.key});

  // It listens itself: placed as a const widget, it is not rebuilt with its parent.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: fit, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    if (fit.coachCanRestoreGoals) return const _RestoreCard();
    final c = fit.coachNutritionTargets;
    if (!fit.coachSetsGoals || c == null) return const SizedBox.shrink();
    final gc = context.gc;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(_goalsIcon, size: 16, color: gc.brass),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.coachGoalsSetBy, style: AppTheme.f(14, weight: FontWeight.w800, color: gc.text)),
            ),
            Semantics(
              button: true,
              child: GestureDetector(
                key: const ValueKey('coach-goals-why'),
                behavior: HitTestBehavior.opaque,
                onTap: () => showCoachGoalsSheet(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(t.coachGoalsWhy, style: AppTheme.f(12, weight: FontWeight.w700, color: gc.textSecondary)),
                    const SizedBox(width: 4),
                    Icon(PhosphorIconsRegular.info, size: 13, color: gc.textTertiary),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(t.coachGoalsPhase.toUpperCase(),
                  style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
            ),
            SegToggle([
              for (final p in CoachNutritionPhase.values)
                SegOption(_phaseLabel(p), c.phase == p, () => fit.setCoachNutritionPhase(p)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

/// The user's own goals are in force: says so, and offers the coach's goals instead, with what that replaces.
class _RestoreCard extends StatelessWidget {
  const _RestoreCard();

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(_goalsIcon, size: 16, color: gc.textTertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.coachGoalsOwn, style: AppTheme.f(14, weight: FontWeight.w800, color: gc.text)),
            ),
          ]),
          const SizedBox(height: 12),
          GhostButton(label: t.coachGoalsUseCoach, icon: PhosphorIconsBold.arrowCounterClockwise, onTap: fit.useCoachGoals),
          const SizedBox(height: 8),
          Text(t.coachGoalsUseCoachNote,
              textAlign: TextAlign.center, style: AppTheme.s(11.5, color: gc.textTertiary, height: 1.4)),
        ]),
      ),
    );
  }
}

/// The icon the coach's nutrition goals carry.
const IconData _goalsIcon = PhosphorIconsRegular.clipboardText;

/// The name of [phase] as the picker shows it.
String _phaseLabel(CoachNutritionPhase phase) => switch (phase) {
      CoachNutritionPhase.gain => t.coachPhaseGain,
      CoachNutritionPhase.maintain => t.coachPhaseMaintain,
      CoachNutritionPhase.loss => t.coachPhaseLoss,
    };

/// Opens the sheet that explains the coach's nutrition goals: what they rest on, the coach's warnings, and each
/// rule behind them in plain words.
void showCoachGoalsSheet(BuildContext context) {
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => ListenableBuilder(
      listenable: fit,
      builder: (sheet, _) {
        final gc = sheet.gc;
        final c = fit.coachNutritionTargets;
        String energy(int kcal) => '${fit.energyOf(kcal)} ${fit.energyUnit}';
        Widget line(IconData icon, Color color, String text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 3), child: Icon(icon, size: 14, color: color)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text,
                      style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
                ),
              ]),
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
                  SheetTitle(t.coachGoalsWhy),
                  if (c != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        '${_phaseLabel(c.phase)} · ${energy(c.kcal)}',
                        t.coachGoalsBasis(fit.weightLabel(c.bodyweightKg), energy(c.maintenance)),
                        if (c.delta > 0) t.coachGoalsGain(energy(c.delta)),
                        if (c.delta < 0) t.coachGoalsLoss(energy(-c.delta)),
                      ].join('\n'),
                      style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.text, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    for (final w in c.warnings) line(PhosphorIconsRegular.warning, gc.warn, w),
                    Text(t.coachWhyNote, style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textTertiary)),
                    const SizedBox(height: 8),
                    for (final rule in fit.coachNutritionRules()) line(PhosphorIconsRegular.lightbulb, gc.brass, rule),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
