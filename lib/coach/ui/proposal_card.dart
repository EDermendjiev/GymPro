// SPDX-License-Identifier: GPL-3.0-only
// The coach's place on the Home screen (Task 5.5): the proposals waiting for the user (Apply, Not now), the ones the
// coach applied by itself in the last seven days (Undo), and the soreness row. Draws nothing when there is nothing
// to show. Titles and reasons come from the coach packages, in English.
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../l10n/l10n.dart';
import '../../state/fit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/liquid_notch.dart';
import '../../widgets/ui_kit.dart';
import '../model/coach_data.dart';
import '../model/coach_recovery.dart';
import 'soreness_sheet.dart';

/// The coach's slot on the Home screen, under the day's card.
class CoachHomeSlot extends StatelessWidget {
  const CoachHomeSlot({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: fit, builder: (context, _) => _slot(context));

  Widget _slot(BuildContext context) {
    final recovery = fit.coach.isOn(CoachModule.recovery);
    final proposals = fit.coachCardProposals;
    if (proposals.isEmpty && !recovery) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final p in proposals) Padding(padding: const EdgeInsets.only(bottom: 10), child: CoachProposalCard(p)),
        if (recovery) const CoachSorenessRow(),
      ]),
    );
  }
}

/// One proposal: what the coach suggests and why, with Apply and Not now, or what it changed, with Undo.
class CoachProposalCard extends StatefulWidget {
  const CoachProposalCard(this.proposal, {super.key});

  final CoachProposal proposal;

  @override
  State<CoachProposalCard> createState() => _CoachProposalCardState();
}

class _CoachProposalCardState extends State<CoachProposalCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final gc = context.gc;
    final p = widget.proposal;
    final applied = p.state == CoachProposalState.applied;
    Widget button(String key, String label, VoidCallback onTap, {bool primary = false}) => Pill(
          key: ValueKey('coach-proposal-$key-${p.id}'),
          label: label,
          bg: primary ? gc.ember : gc.bgRaised2,
          fg: primary ? gc.onEmber : gc.textSecondary,
          onTap: onTap,
          hPad: 14,
          vPad: 7,
          fontSize: 12.5,
        );
    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(applied ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.lightbulb, size: 14, color: gc.brass),
          const SizedBox(width: 7),
          Flexible(
            child: Text((applied ? t.coachProposalApplied : t.coachProposalSuggests).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(10.5, weight: FontWeight.w700, color: gc.textTertiary, letterSpacing: 1.2)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(p.title, style: AppTheme.f(15, weight: FontWeight.w700, color: gc.text, height: 1.3)),
        if (p.rationale.isNotEmpty) ...[
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Text(p.rationale,
                maxLines: _open ? null : 3,
                overflow: _open ? null : TextOverflow.ellipsis,
                style: AppTheme.f(12.5, weight: FontWeight.w500, color: gc.textSecondary, height: 1.4)),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (applied)
            button('undo', t.undo, () => fit.undoCoachProposal(p.id))
          else ...[
            button('apply', t.coachProposalApply, () {
              if (!fit.applyCoachProposal(p.id)) {
                showNotchToast(context, t.coachProposalInvalid,
                    icon: PhosphorIconsFill.warningCircle, accent: context.gc.danger);
              }
            }, primary: true),
            button('later', t.coachProposalNotNow, () => fit.dismissCoachProposal(p.id)),
          ],
        ]),
      ]),
    );
  }
}
