// SPDX-License-Identifier: GPL-3.0-only
// A plan designed outside the block generator: the split, the templates it needs, the starting week and the
// weekly targets. When [generateBlock] gets one, it builds that plan instead of choosing the day count and split
// itself. Rules: T-SPL-01, T-FRQ-01, T-VOL-05.
import 'package:coach_kernel/coach_kernel.dart';

import 'split.dart';

/// One exercise of a designed session: a template slot with its starting sets, or an extra exercise for a muscle
/// the template's own slots don't cover enough.
class DesignSlot {
  const DesignSlot({required this.key, required this.sets, this.muscle, this.tags});

  factory DesignSlot.fromJson(Map<String, dynamic> json) => DesignSlot(
    key: json['key'] as String,
    sets: json['sets'] as int,
    muscle: json['muscle'] == null ? null : MuscleId.trackedFromWire(json['muscle'] as String),
    tags: json['tags'] == null ? null : [for (final x in json['tags'] as List) SlotTag.fromWire(x as String)],
  );

  /// The template slot's key. For an extra exercise, any key; the block uses `extra_<muscle>`.
  final String key;

  /// Starting sets. Main-lift slots ignore it: their sets come from the block kind.
  final int sets;

  /// For an extra exercise: the muscle it is for. Null for a template slot.
  final TrackedMuscle? muscle;

  /// For an extra exercise: the tags to pick it by, in preference order.
  final List<SlotTag>? tags;

  bool get isExtra => muscle != null;

  Map<String, dynamic> toJson() => {
    'key': key,
    'sets': sets,
    if (muscle case final m?) 'muscle': m.wire,
    if (tags case final t?) 'tags': [for (final x in t) x.wire],
  };
}

/// One designed session: which template slots it keeps, with what sets, and its extra exercises.
class DesignSession {
  const DesignSession({required this.templateKey, required this.slots});

  factory DesignSession.fromJson(Map<String, dynamic> json) => DesignSession(
    templateKey: json['templateKey'] as String,
    slots: [for (final x in json['slots'] as List) DesignSlot.fromJson(x as Map<String, dynamic>)],
  );

  final String templateKey;

  /// Template slots not listed here are left out. Main-lift slots are always kept when the block trains them.
  final List<DesignSlot> slots;

  Map<String, dynamic> toJson() => {
    'templateKey': templateKey,
    'slots': [for (final s in slots) s.toJson()],
  };
}

/// A plan designed outside the generator.
///
/// The generator then trains on [split]'s days (one per template), starts each session from [week] (when given),
/// distributes sets towards [targets] (when given, in place of its own volume rules) and uses [explanations] in
/// place of its own notes on volume and the split. Everything else (exercise choice, day placement, intro week,
/// prescription, progression, strength phases) works as without a design.
class BlockDesign {
  const BlockDesign({
    required this.split,
    this.templates = const {},
    this.week,
    this.targets,
    this.focus = const [],
    this.explanations = const [],
    this.warnings = const [],
    this.supersets = false,
  });

  factory BlockDesign.fromJson(Map<String, dynamic> json) => BlockDesign(
    split: SplitDef.fromJson(json['split'] as Map<String, dynamic>),
    templates: {
      for (final e in ((json['templates'] as Map<String, dynamic>?) ?? const {}).entries)
        e.key: Template.fromJson(e.value as Map<String, dynamic>),
    },
    week: json['week'] == null
        ? null
        : [for (final x in json['week'] as List) DesignSession.fromJson(x as Map<String, dynamic>)],
    targets: json['targets'] == null
        ? null
        : {
            for (final e in (json['targets'] as Map<String, dynamic>).entries)
              MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
          },
    focus: [for (final x in (json['focus'] as List?) ?? const []) MuscleId.trackedFromWire(x as String)],
    explanations: [
      for (final x in (json['explanations'] as List?) ?? const [])
        Explanation.fromJson(x as Map<String, dynamic>),
    ],
    warnings: [
      for (final x in (json['warnings'] as List?) ?? const []) Warning.fromJson(x as Map<String, dynamic>),
    ],
    supersets: json['supersets'] as bool? ?? false,
  );

  /// The split, one template per lifting day in the order of the week.
  final SplitDef split;

  /// Templates the split uses beyond [TEMPLATES].
  final Map<String, Template> templates;

  /// One starting session per entry of `split.templates`, in the same order. Null: every template slot at the
  /// usual starting sets.
  final List<DesignSession>? week;

  /// Weekly sets per tracked muscle. Null: the generator's own volume rules.
  final Map<TrackedMuscle, double>? targets;

  /// Muscles whose exercises go first in their sessions, right after main-lift work.
  final List<TrackedMuscle> focus;

  /// Shown in place of the generator's notes on volume and on the split.
  final List<Explanation> explanations;

  /// Added to the block's warnings.
  final List<Warning> warnings;

  /// Sessions that run long pair isolation exercises as supersets before any sets are cut (T-PLN-08).
  final bool supersets;

  /// The template for [key]: this design's own, or the generator's. Null when neither has it.
  Template? templateFor(String key) => templates[key] ?? TEMPLATES[key];

  Map<String, dynamic> toJson() => {
    'split': split.toJson(),
    'templates': {for (final e in templates.entries) e.key: e.value.toJson()},
    if (week case final w?) 'week': [for (final s in w) s.toJson()],
    if (targets case final t?) 'targets': {for (final m in TRACKED_MUSCLES) m.wire: t[m]},
    'focus': [for (final m in focus) m.wire],
    'explanations': [for (final e in explanations) e.toJson()],
    'warnings': [for (final w in warnings) w.toJson()],
    if (supersets) 'supersets': true,
  };
}
