// SPDX-License-Identifier: GPL-3.0-only
// Settings › Coach: "Build me a plan", and one switch per coach module.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../model/coach_data.dart';
import 'onboarding_pages.dart';
import 'soreness_sheet.dart';

/// Builds one settings row: icon, label, the switch, and a one-line hint. The settings screen passes its own, so
/// the coach rows look and behave like their neighbours.
typedef CoachSettingsRow = Widget Function(IconData icon, String label, Widget control, String hint);

/// The icon of the Coach section in the settings list.
const IconData coachSettingsIcon = PhosphorIconsRegular.clipboardText;

/// The rows the settings search finds in the Coach section.
List<(String, IconData)> coachSettingsSearchRows() => [
      (t.coachBuildPlan, PhosphorIconsRegular.magicWand),
      for (final m in CoachModule.values) (_label(m), _icon(m)),
      (t.coachAskFirst, PhosphorIconsRegular.handPalm),
    ];

/// The four module switches. A switch whose prerequisite is off is shown dimmed and does nothing when tapped;
/// switching a prerequisite off switches off what needs it.
class CoachSettings extends StatelessWidget {
  const CoachSettings({super.key, this.row});

  /// The row builder to use. Without one, rows are drawn in the same style as the settings screen's own.
  final CoachSettingsRow? row;

  @override
  Widget build(BuildContext context) {
    final build = row ?? _defaultRow(context.gc);
    return ListenableBuilder(
      listenable: fit,
      builder: (context, _) => Column(children: [
        GestureDetector(
          key: const ValueKey('coach-build-plan-row'),
          behavior: HitTestBehavior.opaque,
          onTap: () => showCoachPlanSheet(context),
          child: build(
            PhosphorIconsRegular.magicWand,
            t.coachBuildPlan,
            Icon(PhosphorIconsBold.caretRight, size: 13, color: context.gc.textTertiary),
            t.coachBuildPlanHint,
          ),
        ),
        for (final m in CoachModule.values)
          GestureDetector(
            key: ValueKey('coach-module-${m.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final on = fit.coach.isOn(m);
              if (!on && !fit.coach.canSwitchOn(m)) return;
              fit.setCoachModule(m, !on);
            },
            child: Opacity(
              opacity: fit.coach.canSwitchOn(m) ? 1 : 0.4,
              child: build(_icon(m), _label(m), TinySwitch(on: fit.coach.isOn(m)), _hint(m)),
            ),
          ),
        if (fit.coach.isOn(CoachModule.recovery))
          GestureDetector(
            key: const ValueKey('coach-ask-first'),
            behavior: HitTestBehavior.opaque,
            onTap: () => fit.setCoachAskFirst(!fit.coachAskFirst),
            child: build(PhosphorIconsRegular.handPalm, t.coachAskFirst, TinySwitch(on: fit.coachAskFirst),
                t.coachAskFirstHint),
          ),
        if (fit.coach.isOn(CoachModule.recovery))
          _open(context, build, 'coach-soreness', PhosphorIconsRegular.bandaids, t.coachSorenessTitle,
              t.coachSorenessRowHint, () => coachShowSorenessSheet(context)),
      ]),
    );
  }
}

/// A row that opens a sheet.
Widget _open(BuildContext context, CoachSettingsRow build, String key, IconData icon, String label, String hint,
        VoidCallback onTap) =>
    GestureDetector(
      key: ValueKey('$key-row'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: build(icon, label, Icon(PhosphorIconsBold.caretRight, size: 13, color: context.gc.textTertiary), hint),
    );

String _label(CoachModule m) => switch (m) {
      CoachModule.progression => t.coachProgression,
      CoachModule.plan => t.coachPlan,
      CoachModule.recovery => t.coachRecovery,
      CoachModule.nutrition => t.coachNutrition,
    };

String _hint(CoachModule m) => switch (m) {
      CoachModule.progression => t.coachProgressionHint,
      CoachModule.plan => t.coachPlanHint,
      CoachModule.recovery => t.coachRecoveryHint,
      CoachModule.nutrition => t.coachNutritionHint,
    };

IconData _icon(CoachModule m) => switch (m) {
      CoachModule.progression => PhosphorIconsRegular.trendUp,
      CoachModule.plan => PhosphorIconsRegular.calendarCheck,
      CoachModule.recovery => PhosphorIconsRegular.batteryCharging,
      CoachModule.nutrition => PhosphorIconsRegular.forkKnife,
    };

/// The settings screen's row style: a round icon, the label over its hint, and the control on the right.
CoachSettingsRow _defaultRow(GymColors gc) => (icon, label, control, hint) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: gc.text.withValues(alpha: 0.09), shape: BoxShape.circle),
              child: Icon(icon, size: 17, color: gc.text),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTheme.f(14.5, weight: FontWeight.w500, color: gc.text)),
              const SizedBox(height: 3),
              Text(hint, style: AppTheme.f(11.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.3)),
            ]),
          ),
          const SizedBox(width: 12),
          control,
        ]),
      ),
    );
