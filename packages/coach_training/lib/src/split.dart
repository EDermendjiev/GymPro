// SPDX-License-Identifier: GPL-3.0-only
// Split selection + session templates. Rules: T-SPL-01, T-SPL-02.
// ignore_for_file: constant_identifier_names, non_constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';

enum Region {
  upper('upper'),
  lower('lower'),
  full('full');

  const Region(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Region> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Region fromWire(String wire) => _byWire[wire] ?? (throw FormatException('Unknown Region: "$wire"'));
}

/// The fields of a [Slot] that exercise ranking reads (`Pick<Slot, 'tags' | 'prefer' | 'key'>` in the reference).
/// Callers that rank for a slot of their own (an extra exercise for one muscle) pass one of these.
class SlotQuery {
  const SlotQuery({required this.key, required this.tags, this.prefer});

  factory SlotQuery.fromJson(Map<String, dynamic> json) => SlotQuery(
    key: json['key'] as String,
    tags: [for (final x in json['tags'] as List) SlotTag.fromWire(x as String)],
    prefer: json['prefer'] == null ? null : [for (final x in json['prefer'] as List) Category.fromWire(x as String)],
  );

  final String key;

  /// Acceptable tags, in preference order.
  final List<SlotTag> tags;

  /// Category preference.
  final List<Category>? prefer;

  Map<String, dynamic> toJson() => {
    'key': key,
    'tags': [for (final t in tags) t.wire],
    if (prefer case final prefer?) 'prefer': [for (final c in prefer) c.wire],
  };
}

class Slot extends SlotQuery {
  const Slot({
    required super.key,
    required this.label,
    required super.tags,
    super.prefer,
    this.mainLift,
    this.replacedByMain,
  });

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
    key: json['key'] as String,
    label: json['label'] as String,
    tags: [for (final x in json['tags'] as List) SlotTag.fromWire(x as String)],
    prefer: json['prefer'] == null ? null : [for (final x in json['prefer'] as List) Category.fromWire(x as String)],
    mainLift: json['mainLift'] == null ? null : MainLift.fromWire(json['mainLift'] as String),
    replacedByMain: json['replacedByMain'] == null ? null : MainLift.fromWire(json['replacedByMain'] as String),
  );

  final String label;

  /// Strength-only main-lift slot (*).
  final MainLift? mainLift;

  /// In strength mode this slot is covered by the main lift's working sets and skipped.
  final MainLift? replacedByMain;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'label': label,
    if (mainLift case final mainLift?) 'mainLift': mainLift.wire,
    if (replacedByMain case final replacedByMain?) 'replacedByMain': replacedByMain.wire,
  };
}

class Template {
  const Template({required this.key, required this.title, required this.region, required this.slots});

  factory Template.fromJson(Map<String, dynamic> json) => Template(
    key: json['key'] as String,
    title: json['title'] as String,
    region: Region.fromWire(json['region'] as String),
    slots: [for (final x in json['slots'] as List) Slot.fromJson(x as Map<String, dynamic>)],
  );

  final String key;
  final String title;
  final Region region;
  final List<Slot> slots;

  Map<String, dynamic> toJson() => {
    'key': key,
    'title': title,
    'region': region.wire,
    'slots': [for (final s in slots) s.toJson()],
  };
}

Slot _s(String key, String label, List<SlotTag> tags, [List<Category>? prefer, MainLift? replacedByMain]) =>
    Slot(key: key, label: label, tags: tags, prefer: prefer, replacedByMain: replacedByMain);

const _UF = Category.upperFreePress;
const _UM = Category.upperMachinePress;
const _LF = Category.lowerFreeCompound;
const _LM = Category.lowerMachineCompound;

Slot _main(MainLift lift) => Slot(key: 'main_${lift.wire}', label: 'Main lift: ${lift.wire}', tags: [], mainLift: lift);

Slot _SQUAT_FREE([String key = 'squat']) =>
    _s(key, 'Squat', [SlotTag.squatFree, SlotTag.squatMachine, SlotTag.splitSquat], [_LF, _LM], MainLift.squat);
final _RDL = _s('hinge', 'Hip hinge (RDL)', [SlotTag.hingeRdl], [_LF, _LM]);
final _INCLINE = _s('incline_press', 'Incline press', [SlotTag.pressIncline, SlotTag.pressFlat], [_UF, _UM]);
final _VPULL = _s('vertical_pull', 'Vertical pull', [SlotTag.pullVertical, SlotTag.pullover]);
final _ROW_FLARED = _s('row_flared', 'Row (elbows wide)', [SlotTag.rowFlared, SlotTag.rowExtension]);
final _ROW_EXT = _s('row_extension', 'Row (elbows in)', [SlotTag.rowExtension, SlotTag.rowFlared]);
final _LEG_CURL = _s('leg_curl', 'Leg curl', [SlotTag.legCurl, SlotTag.legCurlSeated]);
final _LEG_CURL_SEATED = _s('leg_curl', 'Leg curl (seated)', [SlotTag.legCurlSeated, SlotTag.legCurl]);
final _LEG_EXT = _s('leg_ext', 'Leg extension', [SlotTag.legExt]);
final _CALF = _s('calf', 'Calf raise', [SlotTag.calf]);
final _LAT_RAISE = _s('lat_raise', 'Lateral raise', [SlotTag.latRaise]);
final _REAR = _s('rear_delt', 'Rear-delt isolation', [SlotTag.rearDelt]);
Slot _BI([String key = 'biceps']) => _s(key, 'Biceps isolation', [SlotTag.bicepsIso]);
Slot _TRI([String key = 'triceps']) => _s(key, 'Triceps isolation', [SlotTag.tricepsIso]);
final _HIP_EXT = _s('hip_ext', 'Hip extension', [SlotTag.hipExt]);

final Map<String, Template> TEMPLATES = {
  'full_a': Template(
    key: 'full_a',
    title: 'Full Body A',
    region: Region.full,
    slots: [_main(MainLift.squat), _SQUAT_FREE(), _INCLINE, _VPULL, _LEG_CURL, _LAT_RAISE, _CALF],
  ),
  'full_b': Template(
    key: 'full_b',
    title: 'Full Body B',
    region: Region.full,
    slots: [
      _main(MainLift.deadlift),
      _RDL,
      _s('press', 'Overhead or flat press', [SlotTag.pressVertical, SlotTag.pressFlat], [_UF, _UM]),
      _ROW_FLARED,
      _LEG_EXT,
      _TRI(),
      _BI(),
    ],
  ),
  'full_c': Template(
    key: 'full_c',
    title: 'Full Body C',
    region: Region.full,
    slots: [
      _main(MainLift.bench),
      _s('squat_machine', 'Squat (machine)', [SlotTag.squatMachine, SlotTag.splitSquat, SlotTag.squatFree], [_LM, _LF]),
      _s('machine_press', 'Machine press', [SlotTag.pressMachine, SlotTag.pressFlat], [_UM, _UF]),
      _ROW_EXT,
      _HIP_EXT,
      _REAR,
      _CALF,
    ],
  ),
  'upper_a': Template(
    key: 'upper_a',
    title: 'Upper A',
    region: Region.upper,
    slots: [_main(MainLift.bench), _INCLINE, _VPULL, _ROW_FLARED, _LAT_RAISE, _TRI(), _BI()],
  ),
  'upper_b': Template(
    key: 'upper_b',
    title: 'Upper B',
    region: Region.upper,
    slots: [
      _main(MainLift.ohp),
      _s('press', 'Flat press or OHP', [SlotTag.pressFlat, SlotTag.pressVertical], [_UF, _UM]),
      _ROW_EXT,
      _s('chest_iso', 'Chest machine or fly', [SlotTag.chestIso, SlotTag.pressMachine]),
      _s('pulldown', 'Pulldown or pullover', [SlotTag.pullVertical, SlotTag.pullover]),
      _REAR,
      _BI(),
      _TRI(),
    ],
  ),
  'lower_a': Template(
    key: 'lower_a',
    title: 'Lower A',
    region: Region.lower,
    slots: [_main(MainLift.squat), _SQUAT_FREE(), _RDL, _LEG_EXT, _LEG_CURL, _CALF],
  ),
  'lower_b': Template(
    key: 'lower_b',
    title: 'Lower B',
    region: Region.lower,
    slots: [
      _main(MainLift.deadlift),
      _s(
        'squat_machine',
        'Squat (machine or split squat)',
        [SlotTag.squatMachine, SlotTag.splitSquat, SlotTag.squatFree],
        [_LM, _LF],
      ),
      _HIP_EXT,
      _LEG_CURL_SEATED,
      _LEG_EXT,
      _CALF,
    ],
  ),
  'alt_cb_qc': Template(
    key: 'alt_cb_qc',
    title: 'Chest & Back + Quads & Calves',
    region: Region.full,
    slots: [
      _INCLINE,
      _ROW_FLARED,
      _s('flat_press', 'Flat or machine press', [SlotTag.pressFlat, SlotTag.pressMachine], [_UF, _UM]),
      _s('pulldown', 'Pulldown', [SlotTag.pullVertical]),
      _s('squat', 'Squat or leg press', [SlotTag.squatFree, SlotTag.squatMachine, SlotTag.splitSquat], [_LF, _LM]),
      _LEG_EXT,
      _CALF,
    ],
  ),
  'alt_arms_gh': Template(
    key: 'alt_arms_gh',
    title: 'Arms & Delts + Glutes & Hams',
    region: Region.full,
    slots: [_RDL, _HIP_EXT, _LEG_CURL, _LAT_RAISE, _REAR, _BI(), _TRI()],
  ),
  'upper_push': Template(
    key: 'upper_push',
    title: 'Upper Push',
    region: Region.upper,
    slots: [
      _INCLINE,
      _s('flat_press', 'Flat or machine press', [SlotTag.pressFlat, SlotTag.pressMachine], [_UF, _UM]),
      _s('ohp', 'Shoulder press', [SlotTag.pressVertical]),
      _LAT_RAISE,
      _TRI('triceps'),
      _TRI('triceps_2'),
    ],
  ),
  'upper_pull': Template(
    key: 'upper_pull',
    title: 'Upper Pull',
    region: Region.upper,
    slots: [_VPULL, _ROW_FLARED, _ROW_EXT, _REAR, _BI('biceps'), _BI('biceps_2')],
  ),
  'full_push': Template(
    key: 'full_push',
    title: 'Full Push',
    region: Region.full,
    slots: [
      _INCLINE,
      _s('flat_press', 'Flat or machine press', [SlotTag.pressFlat, SlotTag.pressMachine], [_UF, _UM]),
      _s('ohp', 'Shoulder press', [SlotTag.pressVertical]),
      _LAT_RAISE,
      _TRI(),
      _s('squat', 'Squat or leg press', [SlotTag.squatFree, SlotTag.squatMachine, SlotTag.splitSquat], [_LF, _LM]),
      _LEG_EXT,
      _CALF,
    ],
  ),
  'full_pull': Template(
    key: 'full_pull',
    title: 'Full Pull',
    region: Region.full,
    slots: [_VPULL, _ROW_FLARED, _ROW_EXT, _REAR, _BI(), _RDL, _LEG_CURL, _HIP_EXT],
  ),
};

class SplitDef {
  const SplitDef({required this.key, required this.name, required this.templates});

  factory SplitDef.fromJson(Map<String, dynamic> json) => SplitDef(
    key: json['key'] as String,
    name: json['name'] as String,
    templates: [for (final x in json['templates'] as List) x as String],
  );

  final String key;
  final String name;
  final List<String> templates;

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'templates': [...templates],
  };
}

const Map<String, SplitDef> SPLITS = {
  'FB2': SplitDef(key: 'FB2', name: 'Full Body ×2', templates: ['full_a', 'full_b']),
  'UL2': SplitDef(key: 'UL2', name: 'Upper / Lower', templates: ['upper_a', 'lower_a']),
  'FB3': SplitDef(key: 'FB3', name: 'Full Body ×3', templates: ['full_a', 'full_b', 'full_c']),
  'FPF3': SplitDef(
    key: 'FPF3',
    name: 'Full Push / Full Pull / Full Body',
    templates: ['full_push', 'full_pull', 'full_a'],
  ),
  'UL4': SplitDef(key: 'UL4', name: 'Upper / Lower ×2', templates: ['upper_a', 'lower_a', 'upper_b', 'lower_b']),
  'ALT4': SplitDef(
    key: 'ALT4',
    name: 'Alternating ×2',
    templates: ['alt_cb_qc', 'alt_arms_gh', 'alt_cb_qc', 'alt_arms_gh'],
  ),
  'UL5': SplitDef(
    key: 'UL5',
    name: 'Upper / Lower ×2 + Full Body',
    templates: ['upper_a', 'lower_a', 'upper_b', 'lower_b', 'full_c'],
  ),
  'LPP5': SplitDef(
    key: 'LPP5',
    name: 'Lower / Push / Pull / Full Push / Full Pull',
    templates: ['lower_a', 'upper_push', 'upper_pull', 'full_push', 'full_pull'],
  ),
  'ALT6': SplitDef(
    key: 'ALT6',
    name: 'Alternating ×3',
    templates: ['alt_cb_qc', 'alt_arms_gh', 'alt_cb_qc', 'alt_arms_gh', 'alt_cb_qc', 'alt_arms_gh'],
  ),
  'FPP6': SplitDef(
    key: 'FPP6',
    name: 'Full Push / Full Pull ×3',
    templates: ['full_push', 'full_pull', 'full_push', 'full_pull', 'full_push', 'full_pull'],
  ),
  // Strength 6-day: UL4 + two full-body days, so squat and bench get 2 main-lift exposures (T-FRQ-03, T-STR-05).
  'ULF6': SplitDef(
    key: 'ULF6',
    name: 'Upper / Lower ×2 + Full Body ×2',
    templates: ['upper_a', 'lower_a', 'full_c', 'upper_b', 'lower_b', 'full_a'],
  ),
};

/// The options of [chooseSplit].
class ChooseSplitOptions {
  ChooseSplitOptions({this.style, required this.goal, required this.lowerTargetAvg, required this.maxTarget});

  factory ChooseSplitOptions.fromJson(Map<String, dynamic> json) => ChooseSplitOptions(
    style: json['style'] == null ? null : SplitStyle.fromWire(json['style'] as String),
    goal: Goal.fromWire(json['goal'] as String),
    lowerTargetAvg: (json['lowerTargetAvg'] as num).toDouble(),
    maxTarget: (json['maxTarget'] as num).toDouble(),
  );

  final SplitStyle? style;
  final Goal goal;
  final double lowerTargetAvg;
  final double maxTarget;

  Map<String, dynamic> toJson() => {
    if (style case final style?) 'style': style.wire,
    'goal': goal.wire,
    'lowerTargetAvg': lowerTargetAvg,
    'maxTarget': maxTarget,
  };
}

/// The result of [chooseSplit].
class SplitChoice implements RuleTagged {
  SplitChoice({required this.split, required this.ruleIds});

  factory SplitChoice.fromJson(Map<String, dynamic> json) => SplitChoice(
    split: SplitDef.fromJson(json['split'] as Map<String, dynamic>),
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final SplitDef split;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'split': split.toJson(),
    'ruleIds': [...ruleIds],
  };
}

/// T-SPL-01/02: choose the split for k lift days.
/// Strength goal always uses the default splits because only they carry main-lift slots.
SplitChoice chooseSplit(int k, ChooseSplitOptions opts) {
  final alt = opts.style == SplitStyle.alternative && opts.goal != Goal.strength;
  final ruleIds = ['T-SPL-01'];
  String key;
  switch (k) {
    case 2:
      key = alt && opts.maxTarget <= 8 ? 'UL2' : 'FB2';
    case 3:
      if (alt) {
        key = 'FPF3';
      } else if (opts.goal != Goal.strength && opts.lowerTargetAvg >= 16) {
        key = 'FPF3';
        ruleIds.add('T-SPL-02');
      } else {
        key = 'FB3';
      }
    case 4:
      key = alt ? 'ALT4' : 'UL4';
    case 5:
      key = alt ? 'LPP5' : 'UL5';
    default:
      // Strength needs main-lift slots, which ALT6/FPP6 don't have (T-FRQ-03: spread the lifts over as many sessions as possible).
      key = opts.goal == Goal.strength
          ? 'ULF6'
          : alt
          ? 'FPP6'
          : 'ALT6';
  }
  return SplitChoice(split: SPLITS[key]!, ruleIds: ruleIds);
}

/// Occurrence label per template inside a week (first occurrence = 'A' day, later = 'B').
SessionVariant sessionVariant(List<String> templates, int index) {
  final key = templates[index];
  if (key.endsWith('_a')) return SessionVariant.a;
  if (key.endsWith('_b') || key.endsWith('_c')) return SessionVariant.b;
  final firstIdx = templates.indexOf(key);
  return firstIdx == index ? SessionVariant.a : SessionVariant.b;
}

/// Muscles a template is designed to load heavily (used by scheduling heuristics).
List<MuscleId> templateRegionMuscles(Region region) {
  if (region == Region.upper) {
    return [
      MuscleId.chest,
      MuscleId.back,
      MuscleId.frontDelts,
      MuscleId.sideDelts,
      MuscleId.rearDelts,
      MuscleId.biceps,
      MuscleId.triceps,
    ];
  }
  if (region == Region.lower) return [MuscleId.quads, MuscleId.hamstrings, MuscleId.glutes, MuscleId.calves];
  return [MuscleId.chest, MuscleId.back, MuscleId.quads, MuscleId.hamstrings, MuscleId.glutes];
}

bool regionsOverlap(Region a, Region b) => a == b || a == Region.full || b == Region.full;

bool loadsLower(Region r) => r == Region.lower || r == Region.full;
