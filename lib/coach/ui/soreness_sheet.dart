// SPDX-License-Identifier: GPL-3.0-only
// Soreness and pain (Task 5.2): a sheet to mark an area sore or painful for today, and the row on the workout
// summary that opens it.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_kit.dart';
import '../model/coach_data.dart';
import '../model/coach_recovery.dart';

/// The name of an area: the app's muscle name, with the three parts of the shoulder named apart.
String coachAreaLabel(CoachArea a) => switch (a) {
      CoachArea.frontDelts => t.coachAreaFrontDelts,
      CoachArea.sideDelts => t.coachAreaSideDelts,
      CoachArea.rearDelts => t.coachAreaRearDelts,
      _ => t.muscle(a.muscle),
    };

/// A row of choices drawn as the app's pills: [selected] is filled.
Widget coachChoiceRow<T>(
  BuildContext context, {
  required List<T> values,
  required T? selected,
  required String Function(T) label,
  required void Function(T) onTap,
  String keyPrefix = 'coach-choice',
}) {
  final gc = context.gc;
  return Wrap(spacing: 8, runSpacing: 8, children: [
    for (final v in values)
      Pill(
        key: ValueKey('$keyPrefix-$v'),
        label: label(v),
        bg: v == selected ? gc.ember : gc.bgRaised2,
        fg: v == selected ? gc.onEmber : gc.textSecondary,
        onTap: () => onTap(v),
        hPad: 12,
        vPad: 6,
        fontSize: 12,
      ),
  ]);
}

/// The soreness sheet: every area with "Sore" and "Pain" for today. Tapping the chosen level again clears it.
void coachShowSorenessSheet(BuildContext context) {
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => ListenableBuilder(
      listenable: fit,
      builder: (sheet, _) {
        final gc = sheet.gc;
        final now = fit.coachSorenessOn();
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
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
                  SheetTitle(t.coachSorenessTitle, subtitle: t.coachSorenessHint),
                  const SizedBox(height: 14),
                  for (final a in CoachArea.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(
                          child: Text(coachAreaLabel(a),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.f(14, weight: FontWeight.w600, color: gc.text)),
                        ),
                        const SizedBox(width: 8),
                        coachChoiceRow<CoachSoreness>(
                          sheet,
                          keyPrefix: 'coach-sore-${a.wire}',
                          values: CoachSoreness.values,
                          selected: now[a],
                          label: (l) => l == CoachSoreness.sore ? t.coachSorenessSore : t.coachSorenessPain,
                          onTap: (l) => fit.setCoachSoreness(a, now[a] == l ? null : l),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// "Anything sore or painful?" on the workout summary, while the recovery module is on. Opens the soreness sheet.
class CoachSorenessRow extends StatelessWidget {
  const CoachSorenessRow({super.key});

  @override
  Widget build(BuildContext context) {
    if (!fit.coach.isOn(CoachModule.recovery)) return const SizedBox.shrink();
    final gc = context.gc;
    final marked = fit.coachSorenessOn().length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        key: const ValueKey('coach-soreness-row'),
        behavior: HitTestBehavior.opaque,
        onTap: () => coachShowSorenessSheet(context),
        child: SoftCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            Icon(PhosphorIconsRegular.bandaids, size: 18, color: gc.brass),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.coachSorenessRow, style: AppTheme.f(14, weight: FontWeight.w600, color: gc.text)),
                const SizedBox(height: 2),
                Text(marked == 0 ? t.coachSorenessRowHint : fit.coachSorenessOn().keys.map(coachAreaLabel).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
              ]),
            ),
            Icon(PhosphorIconsBold.caretRight, size: 13, color: gc.textTertiary),
          ]),
        ),
      ),
    );
  }
}
