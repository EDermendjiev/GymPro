// SPDX-License-Identifier: GPL-3.0-only
// The coach's questions: the goal, then the experience and the session length. Onboarding shows them as two pages
// of its own (the weekly-goal page before them already gave the days per week); Settings › Coach shows them in one
// sheet, prefilled from the logs, with the training days as well.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass.dart';
import '../../widgets/ui_kit.dart';
import '../model/coach_choices.dart';

/// How many pages [coachOnboardingPages] adds to onboarding.
const int coachOnboardingPageCount = 2;

/// Draws one onboarding page in onboarding's own style: its step label, title, reason and content.
typedef CoachPageFrame = Widget Function(int step, String title, String why, Widget child);

/// The coach's two onboarding pages, numbered from [first]. The answers go to `fit.coachDraft` and are used when
/// onboarding ends. "Just log workouts" on the goal page clears the goal and ends onboarding at once with [skip],
/// so no coach module is switched on.
List<Widget> coachOnboardingPages({required int first, required CoachPageFrame frame, required VoidCallback skip}) => [
      _GoalPage(step: first, frame: frame, skip: skip),
      _LevelPage(step: first + 1, frame: frame),
    ];

/// The goals the questions offer. Sport support waits until sports can be entered.
const List<CoachGoal> _goals = [CoachGoal.leanGain, CoachGoal.recomp, CoachGoal.strength, CoachGoal.fatLoss];

String _goalLabel(CoachGoal g) => switch (g) {
      CoachGoal.leanGain => t.coachGoalLeanGain,
      CoachGoal.recomp => t.coachGoalRecomp,
      CoachGoal.strength => t.coachGoalStrength,
      CoachGoal.fatLoss => t.coachGoalFatLoss,
      CoachGoal.sportSupport => t.coachGoalSportSupport,
    };

String _goalHint(CoachGoal g) => switch (g) {
      CoachGoal.leanGain => t.coachGoalLeanGainHint,
      CoachGoal.recomp => t.coachGoalRecompHint,
      CoachGoal.strength => t.coachGoalStrengthHint,
      CoachGoal.fatLoss => t.coachGoalFatLossHint,
      CoachGoal.sportSupport => t.coachGoalSportSupportHint,
    };

IconData _goalIcon(CoachGoal g) => switch (g) {
      CoachGoal.leanGain => PhosphorIconsRegular.barbell,
      CoachGoal.recomp => PhosphorIconsRegular.arrowsClockwise,
      CoachGoal.strength => PhosphorIconsRegular.lightning,
      CoachGoal.fatLoss => PhosphorIconsRegular.flame,
      CoachGoal.sportSupport => PhosphorIconsRegular.soccerBall,
    };

String _levelLabel(CoachStatus s) => switch (s) {
      CoachStatus.novice => t.coachLevelNovice,
      CoachStatus.intermediate => t.coachLevelIntermediate,
      CoachStatus.advanced => t.coachLevelAdvanced,
    };

String _levelHint(CoachStatus s) => switch (s) {
      CoachStatus.novice => t.coachLevelNoviceHint,
      CoachStatus.intermediate => t.coachLevelIntermediateHint,
      CoachStatus.advanced => t.coachLevelAdvancedHint,
    };

IconData _levelIcon(CoachStatus s) => switch (s) {
      CoachStatus.novice => PhosphorIconsRegular.plant,
      CoachStatus.intermediate => PhosphorIconsRegular.trendUp,
      CoachStatus.advanced => PhosphorIconsRegular.mountains,
    };

class _GoalPage extends StatefulWidget {
  const _GoalPage({required this.step, required this.frame, required this.skip});

  final int step;
  final CoachPageFrame frame;
  final VoidCallback skip;

  @override
  State<_GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<_GoalPage> {
  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final a = fit.coachDraft;
    return widget.frame(
      widget.step,
      t.coachOnbGoalTitle,
      t.coachOnbGoalWhy,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CoachGoalChoices(answers: a, onChanged: () => setState(() {})),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            key: const ValueKey('coach-just-log'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              a.goal = null;
              widget.skip();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(t.coachJustLog,
                  style: AppTheme.f(13, weight: FontWeight.w700, color: gc.textSecondary)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LevelPage extends StatefulWidget {
  const _LevelPage({required this.step, required this.frame});

  final int step;
  final CoachPageFrame frame;

  @override
  State<_LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<_LevelPage> {
  @override
  Widget build(BuildContext context) {
    final a = fit.coachDraft;
    void changed() => setState(() {});
    return widget.frame(
      widget.step,
      t.coachOnbLevelTitle,
      t.coachOnbLevelWhy,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CoachLevelChoices(answers: a, onChanged: changed),
        const SizedBox(height: 20),
        _label(context.gc, t.coachSessionLength),
        const SizedBox(height: 10),
        CoachLengthChips(answers: a, onChanged: changed),
      ]),
    );
  }
}

Widget _label(GymColors gc, String text) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(text.toUpperCase(),
          style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.4)),
    );

Widget _group(GymColors gc, List<Widget> rows) => Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: gc.bgRaised, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: gc.border.withValues(alpha: 0.6)),
          rows[i],
        ],
      ]),
    );

Widget _choice(GymColors gc,
        {required Key key, required IconData icon, required String title, required String hint, required bool on,
        required VoidCallback onTap}) =>
    Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: SizedBox(width: 22, child: Icon(icon, size: 19, color: on ? gc.ember : gc.textSecondary)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: AppTheme.f(14.5, weight: on ? FontWeight.w800 : FontWeight.w600, color: on ? gc.ember : gc.text)),
                const SizedBox(height: 2),
                Text(hint, style: AppTheme.f(12, weight: FontWeight.w500, color: gc.textSecondary, height: 1.3)),
              ]),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: on ? 1 : 0,
              child: Icon(PhosphorIconsFill.checkCircle, size: 18, color: gc.ember),
            ),
          ]),
        ),
      ),
    );

/// The goal question.
class CoachGoalChoices extends StatelessWidget {
  const CoachGoalChoices({super.key, required this.answers, required this.onChanged});

  final CoachAnswers answers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return _group(gc, [
      for (final g in _goals)
        _choice(gc,
            key: ValueKey('coach-goal-${g.wire}'),
            icon: _goalIcon(g),
            title: _goalLabel(g),
            hint: _goalHint(g),
            on: answers.goal == g, onTap: () {
          answers.goal = g;
          onChanged();
        }),
    ]);
  }
}

/// The experience question.
class CoachLevelChoices extends StatelessWidget {
  const CoachLevelChoices({super.key, required this.answers, required this.onChanged});

  final CoachAnswers answers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return _group(gc, [
      for (final s in CoachStatus.values)
        _choice(gc,
            key: ValueKey('coach-level-${s.wire}'),
            icon: _levelIcon(s),
            title: _levelLabel(s),
            hint: answers.statusFromLogs && answers.status == s ? t.coachLevelFromLogs : _levelHint(s),
            on: answers.status == s, onTap: () {
          answers
            ..status = s
            ..statusFromLogs = false;
          onChanged();
        }),
    ]);
  }
}

/// The session-length chips.
class CoachLengthChips extends StatelessWidget {
  const CoachLengthChips({super.key, required this.answers, required this.onChanged});

  final CoachAnswers answers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final m in coachSessionLengths)
        Pill(
          key: ValueKey('coach-length-$m'),
          label: t.coachMinutes(m),
          bg: answers.minutes == m ? gc.ember : gc.bgRaised,
          fg: answers.minutes == m ? gc.onEmber : gc.textSecondary,
          onTap: () {
            answers.minutes = m;
            onChanged();
          },
          hPad: 14,
          vPad: 8,
          fontSize: 12.5,
        ),
    ]);
  }
}

/// The training-day chips, Monday first.
class _DayChips extends StatelessWidget {
  const _DayChips({required this.answers, required this.onChanged});

  final CoachAnswers answers;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final days = answers.days ?? const <int>[];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (var d = 1; d <= 7; d++)
        Pill(
          key: ValueKey('coach-day-$d'),
          label: t.weekdayShort(d),
          bg: days.contains(d) ? gc.ember : gc.bgRaised,
          fg: days.contains(d) ? gc.onEmber : gc.textSecondary,
          onTap: () {
            final next = {...days};
            if (!next.remove(d)) next.add(d);
            answers.days = next.toList()..sort();
            onChanged();
          },
          hPad: 12,
          vPad: 8,
          fontSize: 12.5,
        ),
    ]);
  }
}

/// "Build me a plan" from Settings › Coach: the same questions in one sheet, prefilled from the profile and the
/// logs (the status the logs show once there are eight weeks of them, the weekdays trained on most), with the
/// training days. Building switches on the progression and plan modules.
Future<void> showCoachPlanSheet(BuildContext context) {
  final a = fit.coachPrefill();
  a.days ??= fit.coachSpreadDays(fit.profile.weeklyGoal);
  return showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, setSheet) {
        final gc = context.gc;
        void changed() => setSheet(() {});
        final ready = a.goal != null && (a.days?.isNotEmpty ?? false);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Container(
            decoration: sheetDecoration(gc),
            child: SingleChildScrollView(
              padding: sheetPad(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 16),
                  SheetTitle(t.coachBuildPlan),
                  const SizedBox(height: 14),
                  _label(gc, t.coachOnbGoalTitle),
                  const SizedBox(height: 10),
                  CoachGoalChoices(answers: a, onChanged: changed),
                  const SizedBox(height: 18),
                  _label(gc, t.coachOnbLevelTitle),
                  const SizedBox(height: 10),
                  CoachLevelChoices(answers: a, onChanged: changed),
                  const SizedBox(height: 18),
                  _label(gc, t.coachTrainingDays),
                  const SizedBox(height: 10),
                  _DayChips(answers: a, onChanged: changed),
                  const SizedBox(height: 18),
                  _label(gc, t.coachSessionLength),
                  const SizedBox(height: 10),
                  CoachLengthChips(answers: a, onChanged: changed),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    key: const ValueKey('coach-build-plan'),
                    label: t.coachBuildPlanGo,
                    bg: ready ? null : gc.bgRaised2,
                    fg: ready ? null : gc.textTertiary,
                    onTap: () {
                      if (!ready) return;
                      fit.coachApplyAnswers(a);
                      Navigator.of(sheet).pop();
                    },
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
