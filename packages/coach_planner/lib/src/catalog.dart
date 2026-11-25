// SPDX-License-Identifier: GPL-3.0-only
// The splits the planner chooses from, the session templates they need beyond the block generator's own, and
// what each slot tag trains. Rules: T-PLN-03, T-SPL-01, T-FRQ-03.
// ignore_for_file: constant_identifier_names, non_constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';

/// What a slot tag trains: its exercise category, the muscles it counts fully for, and those it counts half for.
typedef TagInfo = ({Category category, List<TrackedMuscle> primary, List<TrackedMuscle> secondary});

const _LFC = Category.lowerFreeCompound;
const _LMC = Category.lowerMachineCompound;
const _UFP = Category.upperFreePress;
const _UMP = Category.upperMachinePress;
const _PUL = Category.pullingCompound;
const _ISO = Category.isolation;

/// What each slot tag trains, by the movement it stands for. Tags for untracked muscles train no tracked one.
const Map<SlotTag, TagInfo> TAG_INFO = {
  SlotTag.squatFree: (category: _LFC, primary: [MuscleId.quads, MuscleId.glutes], secondary: []),
  SlotTag.squatMachine: (category: _LMC, primary: [MuscleId.quads, MuscleId.glutes], secondary: []),
  SlotTag.splitSquat: (category: _LFC, primary: [MuscleId.quads, MuscleId.glutes], secondary: []),
  SlotTag.hingeRdl: (category: _LFC, primary: [MuscleId.hamstrings, MuscleId.glutes], secondary: []),
  SlotTag.hingeDeadlift: (
    category: _LFC,
    primary: [MuscleId.glutes, MuscleId.hamstrings],
    secondary: [MuscleId.quads, MuscleId.back],
  ),
  SlotTag.hipExt: (category: _LMC, primary: [MuscleId.glutes], secondary: [MuscleId.hamstrings]),
  SlotTag.legCurl: (category: _ISO, primary: [MuscleId.hamstrings], secondary: []),
  SlotTag.legCurlSeated: (category: _ISO, primary: [MuscleId.hamstrings], secondary: []),
  SlotTag.legExt: (category: _ISO, primary: [MuscleId.quads], secondary: []),
  SlotTag.calf: (category: _ISO, primary: [MuscleId.calves], secondary: []),
  SlotTag.pressIncline: (
    category: _UFP,
    primary: [MuscleId.chest, MuscleId.frontDelts],
    secondary: [MuscleId.triceps, MuscleId.sideDelts],
  ),
  SlotTag.pressFlat: (
    category: _UFP,
    primary: [MuscleId.chest, MuscleId.frontDelts],
    secondary: [MuscleId.triceps],
  ),
  SlotTag.pressMachine: (
    category: _UMP,
    primary: [MuscleId.chest, MuscleId.frontDelts],
    secondary: [MuscleId.triceps],
  ),
  SlotTag.pressVertical: (
    category: _UFP,
    primary: [MuscleId.frontDelts],
    secondary: [MuscleId.triceps, MuscleId.sideDelts],
  ),
  SlotTag.chestIso: (category: _ISO, primary: [MuscleId.chest], secondary: [MuscleId.frontDelts]),
  SlotTag.pullVertical: (
    category: _PUL,
    primary: [MuscleId.back],
    secondary: [MuscleId.biceps, MuscleId.rearDelts],
  ),
  SlotTag.rowFlared: (
    category: _PUL,
    primary: [MuscleId.back, MuscleId.rearDelts],
    secondary: [MuscleId.biceps],
  ),
  SlotTag.rowExtension: (
    category: _PUL,
    primary: [MuscleId.back],
    secondary: [MuscleId.biceps, MuscleId.rearDelts],
  ),
  SlotTag.pullover: (category: _ISO, primary: [MuscleId.back], secondary: [MuscleId.chest, MuscleId.triceps]),
  SlotTag.latRaise: (category: _ISO, primary: [MuscleId.sideDelts], secondary: []),
  SlotTag.rearDelt: (category: _ISO, primary: [MuscleId.rearDelts], secondary: []),
  SlotTag.bicepsIso: (category: _ISO, primary: [MuscleId.biceps], secondary: []),
  SlotTag.tricepsIso: (category: _ISO, primary: [MuscleId.triceps], secondary: []),
  SlotTag.frontRaise: (category: _ISO, primary: [MuscleId.frontDelts], secondary: []),
  SlotTag.abs: (category: _ISO, primary: [], secondary: []),
  SlotTag.traps: (category: _ISO, primary: [], secondary: []),
  SlotTag.forearms: (category: _ISO, primary: [], secondary: []),
  SlotTag.erectors: (category: _ISO, primary: [], secondary: []),
  SlotTag.adductors: (category: _ISO, primary: [], secondary: []),
  SlotTag.carry: (category: _ISO, primary: [], secondary: []),
};

/// The tag a main-lift slot stands for.
const Map<MainLift, SlotTag> MAIN_LIFT_TAG = {
  MainLift.squat: SlotTag.squatFree,
  MainLift.bench: SlotTag.pressFlat,
  MainLift.deadlift: SlotTag.hingeDeadlift,
  MainLift.ohp: SlotTag.pressVertical,
};

/// The main lift that trains the same muscles as each one and so adds half to its weekly frequency.
const Map<MainLift, MainLift> RELATED_LIFT = {
  MainLift.squat: MainLift.deadlift,
  MainLift.deadlift: MainLift.squat,
  MainLift.bench: MainLift.ohp,
  MainLift.ohp: MainLift.bench,
};

/// What a slot trains: the info of its first tag, or of its main lift's tag.
TagInfo slotInfo(Slot slot) {
  final main = slot.mainLift;
  return TAG_INFO[main != null ? MAIN_LIFT_TAG[main]! : slot.tags.first]!;
}

// ---------- Templates ----------

Slot _s(String key, String label, List<SlotTag> tags, [List<Category>? prefer, MainLift? replacedByMain]) =>
    Slot(key: key, label: label, tags: tags, prefer: prefer, replacedByMain: replacedByMain);

Slot _main(MainLift lift) =>
    Slot(key: 'main_${lift.wire}', label: 'Main lift: ${lift.wire}', tags: [], mainLift: lift);

Slot _squat([String key = 'squat']) => _s(
  key,
  'Squat or leg press',
  [SlotTag.squatFree, SlotTag.squatMachine, SlotTag.splitSquat],
  [_LFC, _LMC],
  MainLift.squat,
);
Slot _squatMachine([String key = 'squat_machine']) => _s(
  key,
  'Squat (machine or split squat)',
  [SlotTag.squatMachine, SlotTag.splitSquat, SlotTag.squatFree],
  [_LMC, _LFC],
);
Slot _rdl([String key = 'hinge']) => _s(key, 'Hip hinge (RDL)', [SlotTag.hingeRdl], [_LFC, _LMC]);
Slot _incline([String key = 'incline_press']) =>
    _s(key, 'Incline press', [SlotTag.pressIncline, SlotTag.pressFlat], [_UFP, _UMP]);
Slot _flat([String key = 'flat_press']) =>
    _s(key, 'Flat or machine press', [SlotTag.pressFlat, SlotTag.pressMachine], [_UFP, _UMP]);
Slot _ohp([String key = 'ohp']) => _s(key, 'Shoulder press', [SlotTag.pressVertical], [_UFP, _UMP]);
Slot _chestIso([String key = 'chest_iso']) =>
    _s(key, 'Chest machine or fly', [SlotTag.chestIso, SlotTag.pressMachine]);
Slot _vpull([String key = 'vertical_pull']) =>
    _s(key, 'Vertical pull', [SlotTag.pullVertical, SlotTag.pullover]);
Slot _rowFlared([String key = 'row_flared']) =>
    _s(key, 'Row (elbows wide)', [SlotTag.rowFlared, SlotTag.rowExtension]);
Slot _rowExt([String key = 'row_extension']) =>
    _s(key, 'Row (elbows in)', [SlotTag.rowExtension, SlotTag.rowFlared]);
Slot _pullover([String key = 'pullover']) => _s(key, 'Pullover', [SlotTag.pullover, SlotTag.pullVertical]);
Slot _legCurl([String key = 'leg_curl']) => _s(key, 'Leg curl', [SlotTag.legCurl, SlotTag.legCurlSeated]);
Slot _legCurlSeated([String key = 'leg_curl']) =>
    _s(key, 'Leg curl (seated)', [SlotTag.legCurlSeated, SlotTag.legCurl]);
Slot _legExt([String key = 'leg_ext']) => _s(key, 'Leg extension', [SlotTag.legExt]);
Slot _hipExt([String key = 'hip_ext']) => _s(key, 'Hip extension', [SlotTag.hipExt]);
Slot _calf([String key = 'calf']) => _s(key, 'Calf raise', [SlotTag.calf]);
Slot _latRaise([String key = 'lat_raise']) => _s(key, 'Lateral raise', [SlotTag.latRaise]);
Slot _rear([String key = 'rear_delt']) => _s(key, 'Rear-delt isolation', [SlotTag.rearDelt]);
Slot _bi([String key = 'biceps']) => _s(key, 'Biceps isolation', [SlotTag.bicepsIso]);
Slot _tri([String key = 'triceps']) => _s(key, 'Triceps isolation', [SlotTag.tricepsIso]);

Template _t(String key, String title, Region region, List<Slot> slots) =>
    Template(key: key, title: title, region: region, slots: slots);

/// The session templates the planner adds to the block generator's [TEMPLATES]. Keys never repeat one of those.
final Map<String, Template> PLANNER_TEMPLATES = {
  for (final t in [
    // More full-body days, for four to six full-body sessions a week.
    _t('full_d', 'Full Body D', Region.full, [
      _squatMachine(),
      _flat(),
      _vpull(),
      _legCurlSeated(),
      _rear(),
      _bi(),
      _calf(),
    ]),
    _t('full_e', 'Full Body E', Region.full, [
      _rdl(),
      _incline(),
      _rowExt(),
      _legExt(),
      _latRaise(),
      _tri(),
      _hipExt(),
    ]),
    // Second push and pull days, for push/pull/legs twice a week.
    _t('push_b', 'Upper Push B', Region.upper, [
      _flat(),
      _ohp(),
      _chestIso(),
      _latRaise(),
      _tri(),
      _tri('triceps_2'),
    ]),
    _t('pull_b', 'Upper Pull B', Region.upper, [
      _rowExt(),
      _vpull('pulldown'),
      _rowFlared(),
      _rear(),
      _bi(),
      _bi('biceps_2'),
    ]),
    // Muscle-group days.
    _t('chest_tris', 'Chest & Triceps', Region.upper, [
      _incline(),
      _flat(),
      _chestIso(),
      _tri(),
      _tri('triceps_2'),
    ]),
    _t('back_bis', 'Back & Biceps', Region.upper, [
      _vpull(),
      _rowFlared(),
      _rowExt(),
      _bi(),
      _bi('biceps_2'),
    ]),
    _t('shoulders_arms', 'Shoulders & Arms', Region.upper, [
      _ohp(),
      _latRaise(),
      _rear(),
      _bi(),
      _tri(),
      _latRaise('lat_raise_2'),
    ]),
    _t('chest', 'Chest', Region.upper, [_incline(), _flat(), _chestIso(), _incline('incline_press_2')]),
    _t('back', 'Back', Region.upper, [_vpull(), _rowFlared(), _rowExt(), _pullover()]),
    _t('shoulders', 'Shoulders', Region.upper, [_ohp(), _latRaise(), _rear(), _latRaise('lat_raise_2')]),
    _t('arms', 'Arms', Region.upper, [_bi(), _tri(), _bi('biceps_2'), _tri('triceps_2')]),
    _t('quads_calves', 'Quads & Calves', Region.lower, [_squat(), _squatMachine(), _legExt(), _calf()]),
    _t('glutes_hams', 'Glutes & Hamstrings', Region.lower, [
      _rdl(),
      _hipExt(),
      _legCurl(),
      _legCurlSeated('leg_curl_2'),
    ]),
    // Strength days with two or three main lifts each.
    _t('str_sbd_a', 'Squat, Bench & Deadlift A', Region.full, [
      _main(MainLift.squat),
      _main(MainLift.bench),
      _main(MainLift.deadlift),
      _vpull(),
      _rowFlared(),
      _latRaise(),
      _calf(),
    ]),
    _t('str_sbd_b', 'Squat, Bench & Deadlift B', Region.full, [
      _main(MainLift.squat),
      _main(MainLift.bench),
      _main(MainLift.deadlift),
      _rowExt(),
      _legCurl(),
      _tri(),
      _bi(),
    ]),
    _t('str_sb_a', 'Squat & Bench A', Region.full, [
      _main(MainLift.squat),
      _main(MainLift.bench),
      _incline(),
      _vpull(),
      _legCurl(),
      _latRaise(),
      _calf(),
    ]),
    _t('str_sb_b', 'Squat & Bench B', Region.full, [
      _main(MainLift.squat),
      _main(MainLift.bench),
      _squatMachine(),
      _rowFlared(),
      _tri(),
      _calf(),
    ]),
    _t('str_bd_a', 'Bench & Deadlift A', Region.full, [
      _main(MainLift.bench),
      _main(MainLift.deadlift),
      _incline(),
      _rowExt(),
      _legExt(),
      _rear(),
      _bi(),
    ]),
    _t('str_bd_b', 'Bench & Deadlift B', Region.full, [
      _main(MainLift.bench),
      _main(MainLift.deadlift),
      _hipExt(),
      _vpull('pulldown'),
      _tri(),
      _latRaise(),
    ]),
  ])
    t.key: t,
};

/// The template for [key]: the planner's own or the block generator's.
Template? templateFor(String key) => PLANNER_TEMPLATES[key] ?? TEMPLATES[key];

// ---------- Splits ----------

/// The kind of split, for the user's style preference and the status fit.
enum SplitFamily {
  fullBody('full_body'),
  upperLower('upper_lower'),
  pushPullLegs('push_pull_legs'),
  fullPushPull('full_push_pull'),
  alternating('alternating'),
  bodyPart('body_part'),
  hybrid('hybrid'),
  strength('strength');

  const SplitFamily(this.wire);

  final String wire;

  static final Map<String, SplitFamily> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SplitFamily fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SplitFamily: "$wire"'));
}

/// One split the planner can choose.
class PlannerSplit {
  const PlannerSplit({
    required this.key,
    required this.name,
    required this.family,
    required this.templates,
    this.minStatus = Status.novice,
    this.strengthOnly = false,
  });

  final String key;
  final String name;
  final SplitFamily family;

  /// Template keys, one per lifting day, in the order of the week.
  final List<String> templates;

  /// The least training status the split suits.
  final Status minStatus;

  /// Built around main lifts: only offered for a strength goal.
  final bool strengthOnly;

  int get days => templates.length;

  /// The split as the block generator names it.
  SplitDef get def => SplitDef(key: key, name: name, templates: [...templates]);

  /// Whether any of the split's days has a main-lift slot.
  bool get hasMainLifts => templates.any((k) => templateFor(k)!.slots.any((s) => s.mainLift != null));

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'family': family.wire,
    'templates': [...templates],
    'minStatus': minStatus.wire,
    'strengthOnly': strengthOnly,
  };
}

const _fb = SplitFamily.fullBody;
const _ul = SplitFamily.upperLower;
const _ppl = SplitFamily.pushPullLegs;
const _fpp = SplitFamily.fullPushPull;
const _alt = SplitFamily.alternating;
const _bp = SplitFamily.bodyPart;
const _hy = SplitFamily.hybrid;
const _str = SplitFamily.strength;
const _adv = Status.advanced;
const _int = Status.intermediate;

/// Every split the planner chooses from, by number of lifting days.
const List<PlannerSplit> PLANNER_SPLITS = [
  // 1 day
  PlannerSplit(key: 'FB1', name: 'Full Body ×1', family: _fb, templates: ['full_a']),
  // 2 days
  PlannerSplit(key: 'FB2', name: 'Full Body ×2', family: _fb, templates: ['full_a', 'full_b']),
  PlannerSplit(key: 'UL2', name: 'Upper / Lower', family: _ul, templates: ['upper_a', 'lower_a']),
  PlannerSplit(
    key: 'FPP2',
    name: 'Full Push / Full Pull',
    family: _fpp,
    templates: ['full_push', 'full_pull'],
  ),
  PlannerSplit(
    key: 'STR2',
    name: 'Squat, Bench & Deadlift ×2',
    family: _str,
    templates: ['str_sbd_a', 'str_sbd_b'],
    strengthOnly: true,
  ),
  // 3 days
  PlannerSplit(key: 'FB3', name: 'Full Body ×3', family: _fb, templates: ['full_a', 'full_b', 'full_c']),
  PlannerSplit(
    key: 'FPF3',
    name: 'Full Push / Full Pull / Full Body',
    family: _fpp,
    templates: ['full_push', 'full_pull', 'full_a'],
  ),
  PlannerSplit(
    key: 'LPP3',
    name: 'Lower / Push / Pull',
    family: _ppl,
    templates: ['lower_a', 'upper_push', 'upper_pull'],
  ),
  PlannerSplit(
    key: 'ULF3',
    name: 'Upper / Lower / Full Body',
    family: _hy,
    templates: ['upper_a', 'lower_a', 'full_c'],
  ),
  PlannerSplit(
    key: 'STR3',
    name: 'Squat & Bench / Bench & Deadlift / Squat & Bench',
    family: _str,
    templates: ['str_sb_a', 'str_bd_a', 'str_sb_b'],
    strengthOnly: true,
  ),
  // 4 days
  PlannerSplit(
    key: 'UL4',
    name: 'Upper / Lower ×2',
    family: _ul,
    templates: ['upper_a', 'lower_a', 'upper_b', 'lower_b'],
  ),
  PlannerSplit(
    key: 'FB4',
    name: 'Full Body ×4',
    family: _fb,
    templates: ['full_a', 'full_b', 'full_c', 'full_d'],
  ),
  PlannerSplit(
    key: 'LPPF4',
    name: 'Lower / Push / Pull / Full Body',
    family: _hy,
    templates: ['lower_a', 'upper_push', 'upper_pull', 'full_a'],
  ),
  PlannerSplit(
    key: 'FPP4',
    name: 'Full Push / Full Pull ×2',
    family: _fpp,
    templates: ['full_push', 'full_pull', 'full_push', 'full_pull'],
    minStatus: _int,
  ),
  PlannerSplit(
    key: 'ALT4',
    name: 'Alternating ×2',
    family: _alt,
    templates: ['alt_cb_qc', 'alt_arms_gh', 'alt_cb_qc', 'alt_arms_gh'],
    minStatus: _int,
  ),
  PlannerSplit(
    key: 'BP4',
    name: 'Chest & Triceps / Back & Biceps / Shoulders & Arms / Lower',
    family: _bp,
    templates: ['chest_tris', 'back_bis', 'shoulders_arms', 'lower_a'],
    minStatus: _adv,
  ),
  PlannerSplit(
    key: 'STR4',
    name: 'Squat & Bench / Bench & Deadlift ×2',
    family: _str,
    templates: ['str_sb_a', 'str_bd_a', 'str_sb_b', 'str_bd_b'],
    strengthOnly: true,
  ),
  // 5 days
  PlannerSplit(
    key: 'UL5',
    name: 'Upper / Lower ×2 + Full Body',
    family: _ul,
    templates: ['upper_a', 'lower_a', 'upper_b', 'lower_b', 'full_c'],
  ),
  PlannerSplit(
    key: 'FB5',
    name: 'Full Body ×5',
    family: _fb,
    templates: ['full_a', 'full_b', 'full_c', 'full_d', 'full_e'],
    minStatus: _int,
  ),
  PlannerSplit(
    key: 'LPP5',
    name: 'Lower / Push / Pull / Full Push / Full Pull',
    family: _ppl,
    templates: ['lower_a', 'upper_push', 'upper_pull', 'full_push', 'full_pull'],
  ),
  PlannerSplit(
    key: 'BP5',
    name: 'Chest / Back / Lower / Shoulders / Arms',
    family: _bp,
    templates: ['chest', 'back', 'lower_a', 'shoulders', 'arms'],
    minStatus: _adv,
  ),
  PlannerSplit(
    key: 'STR5',
    name: 'Squat & Bench / Bench & Deadlift ×2 + Squat, Bench & Deadlift',
    family: _str,
    templates: ['str_sb_a', 'str_bd_a', 'str_sb_b', 'str_bd_b', 'str_sbd_a'],
    strengthOnly: true,
  ),
  // 6 days
  PlannerSplit(
    key: 'PPL6',
    name: 'Legs / Push / Pull ×2',
    family: _ppl,
    templates: ['lower_a', 'upper_push', 'upper_pull', 'lower_b', 'push_b', 'pull_b'],
    minStatus: _int,
  ),
  PlannerSplit(
    key: 'UL6',
    name: 'Upper / Lower ×3',
    family: _ul,
    templates: ['upper_a', 'lower_a', 'upper_b', 'lower_b', 'upper_a', 'lower_a'],
    minStatus: _int,
  ),
  PlannerSplit(
    key: 'FB6',
    name: 'Full Body ×6',
    family: _fb,
    templates: ['full_a', 'full_b', 'full_c', 'full_d', 'full_e', 'full_a'],
    minStatus: _int,
  ),
  PlannerSplit(
    key: 'FPP6',
    name: 'Full Push / Full Pull ×3',
    family: _fpp,
    templates: ['full_push', 'full_pull', 'full_push', 'full_pull', 'full_push', 'full_pull'],
    minStatus: _int,
  ),
  PlannerSplit(
    key: 'ALT6',
    name: 'Alternating ×3',
    family: _alt,
    templates: ['alt_cb_qc', 'alt_arms_gh', 'alt_cb_qc', 'alt_arms_gh', 'alt_cb_qc', 'alt_arms_gh'],
    minStatus: _int,
  ),
  PlannerSplit(
    key: 'BP6',
    name: 'Chest / Back / Quads / Shoulders / Arms / Glutes & Hamstrings',
    family: _bp,
    templates: ['chest', 'back', 'quads_calves', 'shoulders', 'arms', 'glutes_hams'],
    minStatus: _adv,
  ),
  PlannerSplit(
    key: 'ULF6',
    name: 'Upper / Lower ×2 + Full Body ×2',
    family: _hy,
    templates: ['upper_a', 'lower_a', 'full_c', 'upper_b', 'lower_b', 'full_a'],
  ),
  PlannerSplit(
    key: 'STR6',
    name: 'Squat & Bench / Bench & Deadlift ×3',
    family: _str,
    templates: ['str_sb_a', 'str_bd_a', 'str_sb_b', 'str_bd_b', 'str_sb_a', 'str_bd_a'],
    strengthOnly: true,
  ),
];

/// The split with [key], or null.
PlannerSplit? splitByKey(String key) => PLANNER_SPLITS.where((s) => s.key == key).firstOrNull;

/// The splits for [days] lifting days.
List<PlannerSplit> splitsFor(int days) => [
  for (final s in PLANNER_SPLITS)
    if (s.days == days) s,
];

/// Weekly frequency of each main lift in [split]: 1 per session that trains it, plus half per session that trains
/// its related lift (T-FRQ-03).
Map<MainLift, double> mainLiftFrequency(PlannerSplit split) {
  final count = {for (final l in MainLift.values) l: 0};
  for (final k in split.templates) {
    for (final l in {for (final s in templateFor(k)!.slots) ?s.mainLift}) {
      count[l] = count[l]! + 1;
    }
  }
  return {for (final l in MainLift.values) l: count[l]! + 0.5 * count[RELATED_LIFT[l]]!};
}
