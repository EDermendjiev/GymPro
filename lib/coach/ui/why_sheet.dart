// SPDX-License-Identifier: GPL-3.0-only
// The coach's target line under an Auto exercise in the workout, and the sheet that explains its numbers.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_kit.dart';

/// The coach's rep and effort range for [exerciseId], with a tap that opens the why-sheet. Draws nothing when
/// the coach does not drive the exercise.
class CoachTargetLine extends StatelessWidget {
  const CoachTargetLine({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final label = fit.coachTargetLabel(exerciseId);
    if (label == null) return const SizedBox.shrink();
    final gc = context.gc;
    return Semantics(
      button: true,
      label: t.coachWhyTitle,
      child: GestureDetector(
        key: ValueKey('coach-why-$exerciseId'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showCoachWhySheet(context, exerciseId),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(PhosphorIconsRegular.target, size: 13, color: gc.brass),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            Icon(PhosphorIconsRegular.info, size: 13, color: gc.textTertiary),
          ]),
        ),
      ),
    );
  }
}

/// Opens the sheet that explains the coach's numbers for [exerciseId]: the reason line, then each rule behind it
/// in plain words.
void showCoachWhySheet(BuildContext context, String exerciseId) {
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) {
      final gc = sheet.gc;
      final why = fit.nextWhy(exerciseId);
      final details = fit.coachWhyDetails(exerciseId);
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
                SheetTitle(t.coachWhyTitle),
                const SizedBox(height: 6),
                Text(
                  [?fit.coachTargetLabel(exerciseId), ?why].join(' · '),
                  style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.text, height: 1.35),
                ),
                const SizedBox(height: 14),
                Text(t.coachWhyNote, style: AppTheme.f(11.5, weight: FontWeight.w600, color: gc.textTertiary)),
                const SizedBox(height: 8),
                for (final line in details)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(PhosphorIconsRegular.lightbulb, size: 14, color: gc.brass),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(line,
                            style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
