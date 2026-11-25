// SPDX-License-Identifier: GPL-3.0-only
// The questions that shape a designed plan (years of training, style, sessions, focus muscles, pain areas, strength
// lifts and known maxes) and the plan preview. Onboarding and Settings › Coach › Build me a plan both use them.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../facade.dart';
import '../model/coach_choices.dart';
import '../model/coach_recovery.dart';
import 'soreness_sheet.dart';

/// A section label, as the coach's questions write it.
Widget coachQuestionLabel(GymColors gc, String text) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(text.toUpperCase(),
          style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
    );

Widget _hint(GymColors gc, String text) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, top: 4),
      child: Text(text, style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary, height: 1.3)),
    );

/// A wrap of choice pills, one per value.
Widget _pills<T>(
  GymColors gc, {
  required String keyPrefix,
  required List<T> values,
  required String Function(T) id,
  required String Function(T) label,
  required bool Function(T) on,
  required void Function(T) onTap,
}) =>
    Wrap(spacing: 8, runSpacing: 8, children: [
      for (final v in values)
        Pill(
          key: ValueKey('$keyPrefix-${id(v)}'),
          label: label(v),
          bg: on(v) ? gc.ember : gc.bgRaised,
          fg: on(v) ? gc.onEmber : gc.textSecondary,
          onTap: () => onTap(v),
          hPad: 13,
          vPad: 8,
          fontSize: 12.5,
        ),
    ]);

String _yearsLabel(CoachYears y) => switch (y) {
      CoachYears.underOne => t.coachYearsUnderOne,
      CoachYears.oneToThree => t.coachYearsOneToThree,
      CoachYears.threeToFive => t.coachYearsThreeToFive,
      CoachYears.fivePlus => t.coachYearsFivePlus,
    };

String _styleLabel(CoachStyle s) => switch (s) {
      CoachStyle.auto => t.coachPickForMe,
      CoachStyle.fullBody => t.coachStyleFullBody,
      CoachStyle.upperLower => t.coachStyleUpperLower,
      CoachStyle.pushPullLegs => t.coachStylePushPullLegs,
      CoachStyle.bodyPart => t.coachStyleBodyPart,
    };

String _sessionsLabel(CoachSessionPref s) => switch (s) {
      CoachSessionPref.auto => t.coachPickForMe,
      CoachSessionPref.fewerLonger => t.coachSessionsFewerLonger,
      CoachSessionPref.moreShorter => t.coachSessionsMoreShorter,
    };

String _liftLabel(CoachLift l) => switch (l) {
      CoachLift.squat => t.coachLiftSquat,
      CoachLift.bench => t.coachLiftBench,
      CoachLift.deadlift => t.coachLiftDeadlift,
      CoachLift.ohp => t.coachLiftOhp,
    };

/// The muscles a plan can bring up: the ones it counts sets for.
const List<CoachArea> _focusAreas = [
  CoachArea.chest,
  CoachArea.back,
  CoachArea.frontDelts,
  CoachArea.sideDelts,
  CoachArea.rearDelts,
  CoachArea.biceps,
  CoachArea.triceps,
  CoachArea.glutes,
  CoachArea.quads,
  CoachArea.hamstrings,
  CoachArea.calves,
];

const List<CoachLift> _defaultLifts = [CoachLift.squat, CoachLift.bench, CoachLift.deadlift];

/// The years-of-training chips. Tapping the picked one again clears it.
class CoachYearsChips extends StatelessWidget {
  const CoachYearsChips({super.key, required this.answers, required this.onChanged});

  final CoachAnswers answers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => _pills<CoachYears>(
        context.gc,
        keyPrefix: 'coach-years',
        values: CoachYears.values,
        id: (y) => y.wire,
        label: _yearsLabel,
        on: (y) => answers.years == y,
        onTap: (y) {
          answers.years = answers.years == y ? null : y;
          onChanged();
        },
      );
}

/// The questions that shape the plan. Everything is optional: style and sessions start on "Pick for me", and
/// muscle-group days are offered only to advanced lifters. The main lifts and known maxes show for the strength goal.
class CoachShapeQuestions extends StatelessWidget {
  const CoachShapeQuestions({super.key, required this.answers, required this.onChanged});

  final CoachAnswers answers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final a = answers;
    if (a.style == CoachStyle.bodyPart && a.status != CoachStatus.advanced) a.style = CoachStyle.auto;
    final styles = [
      for (final s in CoachStyle.values)
        if (s != CoachStyle.bodyPart || a.status == CoachStatus.advanced) s,
    ];
    final lifts = a.lifts ?? _defaultLifts;
    final pain = a.pain ?? const <CoachArea>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      coachQuestionLabel(gc, t.coachStyle),
      const SizedBox(height: 10),
      _pills<CoachStyle>(gc,
          keyPrefix: 'coach-style',
          values: styles,
          id: (s) => s.wire,
          label: _styleLabel,
          on: (s) => a.style == s,
          onTap: (s) {
            a.style = s;
            onChanged();
          }),
      const SizedBox(height: 18),
      coachQuestionLabel(gc, t.coachSessions),
      const SizedBox(height: 10),
      _pills<CoachSessionPref>(gc,
          keyPrefix: 'coach-sessions',
          values: CoachSessionPref.values,
          id: (s) => s.wire,
          label: _sessionsLabel,
          on: (s) => a.sessionPref == s,
          onTap: (s) {
            a.sessionPref = s;
            onChanged();
          }),
      const SizedBox(height: 18),
      coachQuestionLabel(gc, t.coachFocus),
      _hint(gc, t.coachFocusHint),
      const SizedBox(height: 10),
      _pills<CoachArea>(gc,
          keyPrefix: 'coach-focus',
          values: _focusAreas,
          id: (m) => m.wire,
          label: coachAreaLabel,
          on: a.focus.contains,
          onTap: (m) {
            if (!a.focus.remove(m)) {
              a.focus.add(m);
              if (a.focus.length > 2) a.focus.removeAt(0);
            }
            onChanged();
          }),
      const SizedBox(height: 18),
      coachQuestionLabel(gc, t.coachPain),
      _hint(gc, t.coachPainHint),
      const SizedBox(height: 10),
      _pills<CoachArea>(gc,
          keyPrefix: 'coach-pain',
          values: CoachArea.values,
          id: (m) => m.wire,
          label: coachAreaLabel,
          on: pain.contains,
          onTap: (m) {
            final next = [...pain];
            if (!next.remove(m)) next.add(m);
            a.pain = next;
            onChanged();
          }),
      if (a.goal == CoachGoal.fatLoss || a.goal == CoachGoal.recomp) ...[
        const SizedBox(height: 18),
        coachQuestionLabel(gc, t.coachCardio),
        _hint(gc, t.coachCardioHint),
        const SizedBox(height: 10),
        _pills<int>(gc,
            keyPrefix: 'coach-cardio',
            values: const [0, 1, 2, 3],
            id: (n) => '$n',
            label: (n) => n == 0 ? t.coachCardioNone : t.coachCardioPerWeek(n),
            on: (n) => a.cardio == n,
            onTap: (n) {
              a.cardio = n;
              onChanged();
            }),
      ],
      if (a.goal == CoachGoal.strength) ...[
        const SizedBox(height: 18),
        coachQuestionLabel(gc, t.coachLifts),
        const SizedBox(height: 10),
        _pills<CoachLift>(gc,
            keyPrefix: 'coach-lift',
            values: CoachLift.values,
            id: (l) => l.wire,
            label: _liftLabel,
            on: lifts.contains,
            onTap: (l) {
              final next = [...lifts];
              if (!next.remove(l)) next.add(l);
              if (next.isEmpty) return;
              a.lifts = [for (final x in CoachLift.values) if (next.contains(x)) x];
              a.knownLifts.removeWhere((k, _) => !a.lifts!.contains(k));
              onChanged();
            }),
        const SizedBox(height: 18),
        coachQuestionLabel(gc, t.coachKnownLifts),
        _hint(gc, t.coachKnownLiftsHint),
        const SizedBox(height: 10),
        for (final l in lifts) _KnownLift(key: ValueKey('coach-known-${l.wire}'), lift: l, answers: a, onChanged: onChanged),
      ],
    ]);
  }
}

/// One lift's recent set, weight × reps, turned into an estimated max as it is typed.
class _KnownLift extends StatefulWidget {
  const _KnownLift({super.key, required this.lift, required this.answers, required this.onChanged});

  final CoachLift lift;
  final CoachAnswers answers;
  final VoidCallback onChanged;

  @override
  State<_KnownLift> createState() => _KnownLiftState();
}

class _KnownLiftState extends State<_KnownLift> {
  late final TextEditingController _kg;
  late final TextEditingController _reps;

  @override
  void initState() {
    super.initState();
    // A known max is shown as a single at that weight.
    final max = widget.answers.knownLifts[widget.lift];
    _kg = TextEditingController(text: max == null ? '' : fmt(fit.toDisplayWeight(max)));
    _reps = TextEditingController(text: max == null ? '' : '1');
  }

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _update() {
    final shown = double.tryParse(_kg.text.replaceAll(',', '.'));
    final reps = int.tryParse(_reps.text);
    final max = shown == null || reps == null ? null : CoachFacade.e1rm(fit.fromDisplayWeight(shown), reps);
    if (max == null) {
      widget.answers.knownLifts.remove(widget.lift);
    } else {
      widget.answers.knownLifts[widget.lift] = max;
    }
    widget.onChanged();
  }

  Widget _field(GymColors gc, TextEditingController c, String hint, double width, String key, {bool decimal = false}) =>
      Container(
        width: width,
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(14)),
        child: TextField(
          key: ValueKey(key),
          controller: c,
          onChanged: (_) => _update(),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
          style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text),
          cursorColor: gc.accent,
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: AppTheme.f(13, weight: FontWeight.w500, color: gc.textTertiary),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final id = widget.lift.wire;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Text(_liftLabel(widget.lift),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(13.5, weight: FontWeight.w600, color: gc.text)),
          ),
        ),
        _field(gc, _kg, fit.units, 78, 'coach-known-$id-kg', decimal: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('×', style: AppTheme.f(14, weight: FontWeight.w700, color: gc.textSecondary)),
        ),
        _field(gc, _reps, t.coachRepsShort, 62, 'coach-known-$id-reps'),
      ]),
    );
  }
}

/// The plan the answers would build: the split, the week, the sets per muscle, the main reasons and the other
/// options. Tapping an option picks its split ([CoachAnswers.splitKey]); the coach's own pick clears it.
class CoachPlanPreviewView extends StatefulWidget {
  const CoachPlanPreviewView({super.key, required this.answers, required this.onChanged});

  final CoachAnswers answers;
  final VoidCallback onChanged;

  @override
  State<CoachPlanPreviewView> createState() => _CoachPlanPreviewViewState();
}

class _CoachPlanPreviewViewState extends State<CoachPlanPreviewView> {
  bool _options = false;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final pv = fit.coachPreview(widget.answers);
    if (pv == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(t.coachPreviewNoGoal, style: AppTheme.f(14, weight: FontWeight.w500, color: gc.textSecondary)),
      );
    }
    final most = pv.weeklySets.values.fold(1, (a, b) => b > a ? b : a);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(gc, [
        Text(pv.splitName,
            key: const ValueKey('coach-preview-split'),
            style: AppTheme.f(19, weight: FontWeight.w800, color: gc.text, height: 1.2)),
        const SizedBox(height: 4),
        Text(t.coachPreviewSession(pv.minutes),
            style: AppTheme.f(12.5, weight: FontWeight.w600, color: gc.textSecondary)),
        const SizedBox(height: 14),
        _WeekStrip(week: pv.week, cardio: pv.cardioDays),
        const SizedBox(height: 10),
        for (final e in (pv.week.entries.toList()..sort((a, b) => a.key - b.key)))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${t.weekdayShort(e.key)} · ${e.value}',
                style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary)),
          ),
        for (final d in pv.cardioDays)
          Padding(
            key: ValueKey('coach-preview-cardio-$d'),
            padding: const EdgeInsets.only(top: 4),
            child: Text('${t.weekdayShort(d)} · ${t.coachCardioDay(CoachFacade.cardioMinutes)}',
                style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.sage)),
          ),
      ]),
      const SizedBox(height: 14),
      coachQuestionLabel(gc, t.coachPreviewVolume),
      const SizedBox(height: 10),
      _card(gc, [
        for (final e in pv.weeklySets.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                width: 96,
                child: Text(coachAreaLabel(e.key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(12, weight: FontWeight.w600, color: gc.textSecondary)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value / most,
                    minHeight: 7,
                    backgroundColor: gc.bgRaised2,
                    color: widget.answers.focus.contains(e.key) ? gc.ember : gc.brass,
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text('${e.value}',
                    textAlign: TextAlign.end,
                    style: AppTheme.f(12, weight: FontWeight.w700, color: gc.text)),
              ),
            ]),
          ),
      ]),
      const SizedBox(height: 14),
      coachQuestionLabel(gc, t.coachPreviewWhy),
      const SizedBox(height: 10),
      _card(gc, [
        for (final r in pv.reasons) _line(gc, PhosphorIconsRegular.check, gc.ember, r),
        for (final w in pv.warnings) _line(gc, PhosphorIconsRegular.warning, gc.brass, w),
      ]),
      if (pv.options.isNotEmpty) ...[
        const SizedBox(height: 6),
        Center(
          child: GestureDetector(
            key: const ValueKey('coach-preview-options'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _options = !_options),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(_options ? t.coachPreviewHideOptions : t.coachPreviewOptions,
                  style: AppTheme.f(13, weight: FontWeight.w700, color: gc.accent)),
            ),
          ),
        ),
        if (_options)
          _card(gc, [
            for (final o in pv.options)
              Semantics(
                button: true,
                child: GestureDetector(
                  key: ValueKey('coach-option-${o.splitKey}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.answers.splitKey = o.recommended ? null : o.splitKey;
                    widget.onChanged();
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.name, style: AppTheme.f(14, weight: FontWeight.w700, color: gc.text)),
                          const SizedBox(height: 2),
                          Text(o.summary ?? t.coachPreviewRecommended,
                              style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary, height: 1.3)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Icon(PhosphorIconsBold.caretRight, size: 14, color: gc.textTertiary),
                    ]),
                  ),
                ),
              ),
          ]),
      ],
    ]);
  }
}

Widget _card(GymColors gc, List<Widget> children) => Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
    );

Widget _line(GymColors gc, IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.text, height: 1.35)),
        ),
      ]),
    );

/// Monday to Sunday, the lifting days filled, the cardio days tinted.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.week, this.cardio = const []});

  final Map<int, String> week;
  final List<int> cardio;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Row(children: [
      for (var d = 1; d <= 7; d++)
        Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: d < 7 ? 6 : 0),
            child: Container(
              key: ValueKey('coach-preview-day-$d'),
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: week.containsKey(d)
                    ? gc.ember
                    : cardio.contains(d)
                        ? gc.sage.withValues(alpha: 0.28)
                        : gc.bgRaised2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(t.weekdayShort(d),
                  maxLines: 1,
                  style: AppTheme.f(11,
                      weight: FontWeight.w700, color: week.containsKey(d) ? gc.onEmber : gc.textTertiary)),
            ),
          ),
        ),
    ]);
  }
}
