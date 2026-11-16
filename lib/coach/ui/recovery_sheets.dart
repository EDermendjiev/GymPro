// SPDX-License-Identifier: GPL-3.0-only
// Sports and injuries (Task 5.6): the two sheets, reachable from Settings › Coach and from the dismissible hint in
// the Home slot. A change generates the plan again while the plan module is on. Sport names come from the coach
// packages, in English.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_kit.dart';
import '../model/coach_recovery.dart';
import 'soreness_sheet.dart';

String _intensityLabel(CoachSportIntensity i) => switch (i) {
      CoachSportIntensity.light => t.coachIntensityLight,
      CoachSportIntensity.moderate => t.coachIntensityModerate,
      CoachSportIntensity.hard => t.coachIntensityHard,
      CoachSportIntensity.match => t.coachIntensityMatch,
    };

String _severityLabel(CoachInjurySeverity s) => switch (s) {
      CoachInjurySeverity.niggle => t.coachSeverityNiggle,
      CoachInjurySeverity.pain => t.coachSeverityPain,
      CoachInjurySeverity.injury => t.coachSeverityInjury,
    };

const List<int> _sportLengths = [30, 45, 60, 90, 120];

Widget _sheet(BuildContext sheet, List<Widget> children) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.88),
      child: Container(
        decoration: sheetDecoration(sheet.gc),
        child: SingleChildScrollView(
          padding: sheetPad(sheet),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const SheetHandle(), const SizedBox(height: 16), ...children],
          ),
        ),
      ),
    );

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text.toUpperCase(),
          style: AppTheme.f(10.5, weight: FontWeight.w700, color: context.gc.textTertiary, letterSpacing: 1.2)),
    );

Widget _row(BuildContext context, String title, String subtitle, String action, VoidCallback onTap, Key key) {
  final gc = context.gc;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTheme.f(14, weight: FontWeight.w600, color: gc.text)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary)),
        ]),
      ),
      const SizedBox(width: 8),
      Pill(key: key, label: action, bg: gc.bgRaised2, fg: gc.textSecondary, onTap: onTap, hPad: 12, vPad: 6, fontSize: 12),
    ]),
  );
}

/// The sports sheet: the user's sports, each removable, and a form to add one (sport, days, how hard, length).
void coachShowSportsSheet(BuildContext context) {
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SportsSheet(),
  );
}

class _SportsSheet extends StatefulWidget {
  const _SportsSheet();

  @override
  State<_SportsSheet> createState() => _SportsSheetState();
}

class _SportsSheetState extends State<_SportsSheet> {
  String? _sport;
  final Set<int> _days = {};
  CoachSportIntensity _intensity = CoachSportIntensity.moderate;
  int _minutes = 60;

  @override
  Widget build(BuildContext context) {
    final choices = fit.coachSportChoices;
    final names = {for (final c in choices) c.id: c.name};
    final mine = fit.coachSports;
    final gc = context.gc;
    String days(List<int> d) => d.map(t.weekdayShort).join(' ');
    return _sheet(context, [
      SheetTitle(t.coachSports, subtitle: t.coachSportsHint),
      const SizedBox(height: 8),
      if (mine.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t.coachSportsNone, style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary)),
        ),
      for (final (i, s) in mine.indexed)
        _row(
          context,
          names[s.sportId] ?? s.sportId,
          [days(s.weekdays), _intensityLabel(s.intensity), t.coachMinutes(s.minutes)].join(' · '),
          t.coachRemove,
          () => setState(() => fit.setCoachSports([...mine]..removeAt(i))),
          ValueKey('coach-sport-remove-${s.sportId}'),
        ),
      _label(context, t.coachSportAdd),
      coachChoiceRow<String>(
        context,
        keyPrefix: 'coach-sport',
        values: [for (final c in choices) c.id],
        selected: _sport,
        label: (id) => names[id]!,
        onTap: (id) => setState(() {
          _sport = id;
          _minutes = choices.firstWhere((c) => c.id == id).defaultMinutes;
        }),
      ),
      _label(context, t.coachSportDays),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var d = 1; d <= 7; d++)
          Pill(
            key: ValueKey('coach-sport-day-$d'),
            label: t.weekdayShort(d),
            bg: _days.contains(d) ? gc.ember : gc.bgRaised2,
            fg: _days.contains(d) ? gc.onEmber : gc.textSecondary,
            onTap: () => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
            hPad: 10,
            vPad: 6,
            fontSize: 12,
          ),
      ]),
      _label(context, t.coachSportIntensity),
      coachChoiceRow<CoachSportIntensity>(
        context,
        keyPrefix: 'coach-sport-intensity',
        values: CoachSportIntensity.values,
        selected: _intensity,
        label: _intensityLabel,
        onTap: (i) => setState(() => _intensity = i),
      ),
      _label(context, t.coachSportLength),
      coachChoiceRow<int>(
        context,
        keyPrefix: 'coach-sport-minutes',
        values: {..._sportLengths, _minutes}.toList()..sort(),
        selected: _minutes,
        label: t.coachMinutes,
        onTap: (m) => setState(() => _minutes = m),
      ),
      const SizedBox(height: 18),
      Opacity(
        opacity: _sport != null && _days.isNotEmpty ? 1 : 0.4,
        child: PrimaryButton(
          key: const ValueKey('coach-sport-add'),
          label: t.coachSportAdd,
          height: 48,
          onTap: _sport == null || _days.isEmpty
              ? null
              : () => setState(() {
                    fit.setCoachSports([
                      ...fit.coachSports.where((s) => s.sportId != _sport),
                      CoachSportEntry(sportId: _sport!, weekdays: [..._days]..sort(), intensity: _intensity, minutes: _minutes),
                    ]);
                    _sport = null;
                    _days.clear();
                  }),
        ),
      ),
    ]);
  }
}

/// The injury sheet: the active injuries, each with "Healed", and a form to add one (where, how bad).
void coachShowInjurySheet(BuildContext context) {
  showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _InjurySheet(),
  );
}

class _InjurySheet extends StatefulWidget {
  const _InjurySheet();

  @override
  State<_InjurySheet> createState() => _InjurySheetState();
}

class _InjurySheetState extends State<_InjurySheet> {
  CoachArea? _area;
  CoachInjurySeverity _severity = CoachInjurySeverity.niggle;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final active = [for (final i in fit.coachInjuries) if (i.active) i];
    return _sheet(context, [
      SheetTitle(t.coachInjuries, subtitle: t.coachInjuriesHint),
      const SizedBox(height: 8),
      if (active.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(t.coachInjuriesNone, style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary)),
        ),
      for (final i in active)
        _row(
          context,
          i.area == null ? i.label : coachAreaLabel(i.area!),
          _severityLabel(i.severity),
          t.coachInjuryHealed,
          () => setState(() => fit.healCoachInjury(i.id)),
          ValueKey('coach-injury-heal-${i.id}'),
        ),
      _label(context, t.coachInjuryAdd),
      _label(context, t.coachInjuryArea),
      coachChoiceRow<CoachArea>(
        context,
        keyPrefix: 'coach-injury-area',
        values: CoachArea.values,
        selected: _area,
        label: coachAreaLabel,
        onTap: (a) => setState(() => _area = a),
      ),
      _label(context, t.coachInjurySeverity),
      coachChoiceRow<CoachInjurySeverity>(
        context,
        keyPrefix: 'coach-injury-severity',
        values: CoachInjurySeverity.values,
        selected: _severity,
        label: _severityLabel,
        onTap: (s) => setState(() => _severity = s),
      ),
      const SizedBox(height: 18),
      Opacity(
        opacity: _area != null ? 1 : 0.4,
        child: PrimaryButton(
          key: const ValueKey('coach-injury-add'),
          label: t.coachInjuryAdd,
          height: 48,
          onTap: _area == null
              ? null
              : () => setState(() {
                    fit.addCoachInjury(_area!, _severity);
                    _area = null;
                  }),
        ),
      ),
    ]);
  }
}

/// The one-time hint in the Home slot: sports and injuries, with a way to each sheet and a way to dismiss it.
class CoachHomeHint extends StatelessWidget {
  const CoachHomeHint({super.key});

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    Widget pill(String key, String label, VoidCallback onTap) => Pill(
        key: ValueKey(key), label: label, bg: gc.bgRaised2, fg: gc.textSecondary, onTap: onTap, hPad: 12, vPad: 6, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(PhosphorIconsRegular.soccerBall, size: 17, color: gc.brass)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.coachHomeHint,
                  style: AppTheme.f(13, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                pill('coach-hint-sports', t.coachSports, () => coachShowSportsSheet(context)),
                pill('coach-hint-injuries', t.coachInjuries, () => coachShowInjurySheet(context)),
              ]),
            ]),
          ),
          Semantics(
            button: true,
            label: t.coachHomeHintDismiss,
            child: GestureDetector(
              key: const ValueKey('coach-hint-dismiss'),
              behavior: HitTestBehavior.opaque,
              onTap: fit.dismissCoachHomeHint,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(PhosphorIconsBold.x, size: 14, color: gc.textTertiary),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
