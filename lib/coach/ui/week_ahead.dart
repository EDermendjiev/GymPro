// SPDX-License-Identifier: GPL-3.0-only
// The week ahead on the Home screen, under the day's card: the routines planned for the next six days (a fixed
// week), or the steps that follow in the rotation. Once the day's session is done, the day's card only says so;
// this card keeps the rest of the plan in view. Tapping a routine opens it, "See all" opens the weekly plan.
// Draws nothing when no routine is planned ahead.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../models/workout.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/day_off_sheet.dart';
import '../../widgets/svg_icon.dart';
import '../../widgets/ui_kit.dart';

/// One line of the card: a day (or a rotation step) and what is planned for it. [routine] is null on a rest day.
typedef CoachWeekAheadRow = ({String day, String? date, Routine? routine, String? dayOff});

/// The lines the card shows, in order. Empty when nothing is planned ahead, which hides the card.
List<CoachWeekAheadRow> coachWeekAheadRows() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  if (fit.rotating) return _rotationRows(start);
  final rows = <CoachWeekAheadRow>[];
  for (var d = 1; d <= 6; d++) {
    final day = shiftDays(start, d);
    final planned = fit.routinesOn(day);
    final label = d == 1 ? t.tomorrow : t.weekdayShort(day.weekday);
    final date = t.shortDate(day);
    final off = fit.dayOffOn(day);
    if (planned.isEmpty) {
      rows.add((day: label, date: date, routine: null, dayOff: off));
    } else {
      for (final (i, r) in planned.indexed) {
        rows.add((day: i == 0 ? label : '', date: i == 0 ? date : null, routine: r, dayOff: i == 0 ? off : null));
      }
    }
  }
  return rows.any((r) => r.routine != null) ? rows : const [];
}

/// A rotation has no dates: the steps after the one the day's card shows, once round the rotation.
List<CoachWeekAheadRow> _rotationRows(DateTime today) {
  final steps = fit.rotationSteps;
  if (steps.isEmpty || fit.rotationRoutines.isEmpty) return const [];
  // While the day's routine is still to do, the day's card shows it; once it is done the rotation has moved on.
  final doneToday = fit.routinesOn(today).isNotEmpty && fit.pendingRoutinesOn(today).isEmpty;
  final first = fit.rotationStep + (doneToday ? 0 : 1);
  final rows = <CoachWeekAheadRow>[];
  for (var k = 0; k < steps.length - (doneToday ? 0 : 1); k++) {
    final id = steps[(first + k) % steps.length];
    final label = k == 0 ? t.liveNext : '${k + 1}';
    if (RoutinesState.isRestStep(id)) {
      rows.add((day: label, date: null, routine: null, dayOff: null));
    } else if (fit.routineById(id) case final r?) {
      rows.add((day: label, date: null, routine: r, dayOff: null));
    }
  }
  return rows.any((r) => r.routine != null) ? rows : const [];
}

/// The week-ahead card on the Home screen.
class CoachWeekAhead extends StatelessWidget {
  const CoachWeekAhead({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: fit, builder: (context, _) => _card(context));

  Widget _card(BuildContext context) {
    final rows = coachWeekAheadRows();
    if (rows.isEmpty) return const SizedBox.shrink();
    final gc = context.gc;
    return Padding(
      key: const ValueKey('coach-week-ahead'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading(gc),
        const SizedBox(height: 10),
        SoftCard(
          radius: 22,
          borderColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(children: [for (final r in rows) _row(gc, r)]),
        ),
      ]),
    );
  }

  Widget _heading(GymColors gc) => Semantics(
        button: true,
        label: titleCase(fit.rotating ? t.rotationTitle : t.weeklyPlan),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: fit.goRoutines,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: SizedBox(
              height: 30,
              child: Row(children: [
                Expanded(
                  child: Text(titleCase(fit.rotating ? t.rotationTitle : t.weeklyPlan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(13, weight: FontWeight.w700, color: gc.textTertiary)),
                ),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(14)),
                  child: Text(t.healthSeeAll, style: AppTheme.f(12, weight: FontWeight.w700, color: gc.text)),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _row(GymColors gc, CoachWeekAheadRow row) {
    final r = row.routine;
    final rest = r == null;
    final off = row.dayOff;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: rest ? 7 : 11),
      child: Row(children: [
        SizedBox(
          width: 78,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(row.day,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(13.5, weight: FontWeight.w700, color: rest ? gc.textTertiary : gc.text)),
            if (row.date != null)
              Text(row.date!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(11, weight: FontWeight.w500, color: gc.textTertiary)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(rest ? t.restDayShort : fit.routineTitle(r),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(14.5,
                    weight: rest ? FontWeight.w500 : FontWeight.w600, color: rest ? gc.textTertiary : gc.text)),
            if (!rest)
              // The coach's block and week are the same all week; the day's card already names them.
              Text(t.exerciseCount(r.exerciseIds.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
          ]),
        ),
        if (off != null) ...[
          const SizedBox(width: 8),
          Icon(dayOffIcon(off), size: 15, color: gc.textSecondary),
        ] else if (rest) ...[
          const SizedBox(width: 8),
          Icon(PhosphorIconsFill.bed, size: 14, color: gc.sage),
        ],
        if (!rest) ...[
          const SizedBox(width: 8),
          SvgPathIcon(Ic.chevronRight, size: 14, color: gc.textTertiary),
        ],
      ]),
    );
    if (rest) return content;
    return Semantics(
      button: true,
      child: Pressable(
        key: ValueKey('coach-week-ahead-${row.date ?? row.day}-${r.id}'),
        scale: 0.98,
        onTap: () => fit.openRoutine(r.id),
        child: content,
      ),
    );
  }
}
