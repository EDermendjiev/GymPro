// SPDX-License-Identifier: GPL-3.0-only
// Sport sessions on any day: a game someone invited the user to on a rest day, a match moved to another day. The
// weekly sports (Settings › Coach › Sports) are fixed weekdays; these are logged for one date. One sheet logs and
// removes them. It opens from the start sheet ("Train anyway", and "Log a workout" on a past day), from the day
// sheet of the week strip, and from the day summary. Everything here draws nothing while no coach module is on.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_kit.dart';
import '../model/coach_recovery.dart';
import 'recovery_sheets.dart';
import 'soreness_sheet.dart';

String _name(String sportId) => fit.coachSportChoices.where((c) => c.id == sportId).firstOrNull?.name ?? sportId;

String _detail(CoachSportLog l) => [coachIntensityLabel(l.intensity), t.coachMinutes(l.minutes)].join(' · ');

/// The sport sheet for [day]: the sessions logged that day, each removable, and a form to log one.
void coachShowSportLogSheet(BuildContext context, DateTime day) {
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SportLogSheet(day: DateTime(day.year, day.month, day.day)),
  );
}

class _SportLogSheet extends StatefulWidget {
  const _SportLogSheet({required this.day});

  final DateTime day;

  @override
  State<_SportLogSheet> createState() => _SportLogSheetState();
}

class _SportLogSheetState extends State<_SportLogSheet> {
  String? _sport;
  CoachSportIntensity _intensity = CoachSportIntensity.moderate;
  int _minutes = 60;

  @override
  void initState() {
    super.initState();
    final mine = fit.coachSports;
    if (mine.isNotEmpty) _pick(mine.first.sportId);
  }

  /// Picks [id], with how hard and how long the user usually plays it, else the sport's usual length.
  void _pick(String id) {
    _sport = id;
    final mine = fit.coachSports.where((s) => s.sportId == id).firstOrNull;
    if (mine != null) {
      _intensity = mine.intensity;
      _minutes = mine.minutes;
    } else if (fit.coachSportChoices.where((c) => c.id == id).firstOrNull case final c?) {
      _minutes = c.defaultMinutes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final choices = fit.coachSportChoices;
    final mine = [for (final s in fit.coachSports) if (choices.any((c) => c.id == s.sportId)) s.sportId];
    final ids = [...mine, for (final c in choices) if (!mine.contains(c.id)) c.id];
    final logged = fit.coachSportLogsOn(widget.day);
    return coachSheet(context, [
      SheetTitle(t.coachSportSession, subtitle: t.longDate(widget.day)),
      const SizedBox(height: 6),
      Text(t.coachSportSessionHint,
          style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textTertiary, height: 1.4)),
      if (logged.isNotEmpty) ...[
        coachSheetLabel(context, t.coachSportSessionLogged),
        for (final l in logged)
          coachSheetRow(
            context,
            _name(l.sportId),
            _detail(l),
            t.coachRemove,
            () => setState(() => fit.removeCoachSportLog(l.id)),
            ValueKey('coach-sport-log-remove-${l.id}'),
          ),
      ],
      coachSheetLabel(context, t.coachSportSessionWhich),
      coachChoiceRow<String>(
        context,
        keyPrefix: 'coach-sport-log',
        values: ids,
        selected: _sport,
        label: _name,
        onTap: (id) => setState(() => _pick(id)),
      ),
      coachSheetLabel(context, t.coachSportIntensity),
      coachChoiceRow<CoachSportIntensity>(
        context,
        keyPrefix: 'coach-sport-log-intensity',
        values: CoachSportIntensity.values,
        selected: _intensity,
        label: coachIntensityLabel,
        onTap: (i) => setState(() => _intensity = i),
      ),
      coachSheetLabel(context, t.coachSportLength),
      coachChoiceRow<int>(
        context,
        keyPrefix: 'coach-sport-log-minutes',
        values: {...coachSportLengths, _minutes}.toList()..sort(),
        selected: _minutes,
        label: t.coachMinutes,
        onTap: (m) => setState(() => _minutes = m),
      ),
      const SizedBox(height: 18),
      Opacity(
        opacity: _sport != null ? 1 : 0.4,
        child: PrimaryButton(
          key: const ValueKey('coach-sport-log-save'),
          label: t.coachSportSessionSave,
          height: 48,
          onTap: _sport == null
              ? null
              : () {
                  fit.logCoachSport(widget.day, _sport!, _intensity, _minutes);
                  Navigator.of(context).pop();
                },
        ),
      ),
    ]);
  }
}

/// The start sheet's "Log a sport session" option, for [day] (today when null). It closes the start sheet and
/// opens the sport sheet.
class CoachLogSportOption extends StatelessWidget {
  const CoachLogSportOption({super.key, this.day});

  final DateTime? day;

  @override
  Widget build(BuildContext context) {
    if (!fit.coachLogsSports) return const SizedBox.shrink();
    final gc = context.gc;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        key: const ValueKey('coach-sport-log-option'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).pop();
          coachShowSportLogSheet(context, day ?? DateTime.now());
        },
        child: SoftCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Icon(PhosphorIconsRegular.soccerBall, size: 19, color: gc.textSecondary),
            const SizedBox(width: 13),
            Expanded(
                child: Text(t.coachSportSessionLog,
                    style: AppTheme.f(14.5, weight: FontWeight.w600, color: gc.text))),
          ]),
        ),
      ),
    );
  }
}

/// The day sheet's sport line for [day]: what was logged, and the way to the sport sheet. None while no coach
/// module is on.
List<OptionItem> coachDayOffSportItems(BuildContext sheet, DateTime day) {
  if (!fit.coachLogsSports) return const [];
  final logged = fit.coachSportLogsOn(day);
  return [
    OptionItem(
      t.coachSportSession,
      icon: PhosphorIconsRegular.soccerBall,
      detail: logged.isEmpty ? null : logged.map((l) => _name(l.sportId)).join(', '),
      selected: logged.isNotEmpty,
      onTap: () {
        Navigator.of(sheet).pop();
        coachShowSportLogSheet(sheet, day);
      },
    ),
  ];
}

/// The sport sessions logged on [date], in the day summary. Tapping one opens the sport sheet for that day.
class CoachDaySports extends StatelessWidget {
  const CoachDaySports({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final logged = fit.coachSportLogsOn(date);
    if (logged.isEmpty) return const SizedBox.shrink();
    final gc = context.gc;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final l in logged)
          GestureDetector(
            key: ValueKey('coach-day-sport-${l.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => coachShowSportLogSheet(context, date),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(PhosphorIconsRegular.soccerBall, size: 18, color: gc.brass),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_name(l.sportId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.f(14, weight: FontWeight.w600, color: gc.text)),
                    const SizedBox(height: 2),
                    Text(_detail(l), style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
