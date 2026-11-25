// SPDX-License-Identifier: GPL-3.0-only
// The plan decision as the block generator's design: the split, the planner's own templates, the estimated week
// as the starting week, and the targets, explanations and warnings. Rules: T-PLN-03, T-VOL-05.
import 'package:coach_training/coach_training.dart';

import 'catalog.dart';
import 'decide.dart';
import 'estimate.dart';

/// The block design for decision [d].
///
/// The estimated week is the generator's starting week: the same slots at the same sets, and the extra exercises it
/// added. So the generator doesn't rebuild the week from the templates' starting sets, which overruns short sessions.
/// Main-lift slots are left to the generator, which sets their sets by the block kind.
BlockDesign blockDesignFor(PlannerDecision d) {
  final split = d.split;
  return BlockDesign(
    split: SplitDef(key: split.key, name: split.name, templates: [...split.templates]),
    templates: {for (final key in split.templates.toSet()) key: ?PLANNER_TEMPLATES[key]},
    week: [
      for (final s in d.estimate.sessions)
        DesignSession(
          templateKey: s.templateKey,
          slots: [
            for (final slot in s.slots)
              if (!slot.main) _slot(slot),
          ],
        ),
    ],
    targets: d.targets == null ? null : {...d.targets!},
    focus: [...d.focus],
    explanations: [...d.explanations],
    warnings: [...d.warnings],
  );
}

DesignSlot _slot(EstSlot slot) {
  final m = slot.muscle;
  if (!slot.extra || m == null) return DesignSlot(key: slot.key, sets: slot.sets);
  return DesignSlot(
    key: slot.key,
    sets: slot.sets,
    muscle: m,
    tags: [
      slot.tag,
      for (final t in EXTRA_TAGS[m] ?? const [])
        if (t != slot.tag) t,
    ],
  );
}
