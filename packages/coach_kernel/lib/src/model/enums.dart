// SPDX-License-Identifier: GPL-3.0-only
// String unions of the reference, as enums. Each value carries the string the reference uses (`wire`), which is also
// what is written to JSON. Value names are the wire string in lowerCamelCase.
// ignore_for_file: constant_identifier_names

/// Every muscle group the engine knows. Only the tracked ones ([MuscleId.tracked]) have weekly set targets.
enum MuscleId {
  chest('chest'),
  back('back'),
  frontDelts('front_delts'),
  sideDelts('side_delts'),
  rearDelts('rear_delts'),
  biceps('biceps'),
  triceps('triceps'),
  quads('quads'),
  hamstrings('hamstrings'),
  glutes('glutes'),
  calves('calves'),
  abs('abs'),
  forearms('forearms'),
  traps('traps'),
  erectors('erectors'),
  adductors('adductors');

  const MuscleId(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, MuscleId> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static MuscleId fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown MuscleId: "$wire"'));

  /// Whether the muscle has a weekly set target of its own.
  bool get tracked => index < TRACKED_MUSCLES.length;

  /// Like [fromWire], but also throws a [FormatException] for a muscle that is not tracked.
  static TrackedMuscle trackedFromWire(String wire) {
    final m = fromWire(wire);
    if (!m.tracked) throw FormatException('Not a tracked muscle: "$wire"');
    return m;
  }
}

/// A [MuscleId] that is one of [TRACKED_MUSCLES]. The reference has a narrower type for these; Dart enums cannot be
/// narrowed, so this is only a name. JSON parsing still rejects untracked muscles where the reference expects a tracked one.
typedef TrackedMuscle = MuscleId;

const List<TrackedMuscle> TRACKED_MUSCLES = [
  MuscleId.chest,
  MuscleId.back,
  MuscleId.frontDelts,
  MuscleId.sideDelts,
  MuscleId.rearDelts,
  MuscleId.biceps,
  MuscleId.triceps,
  MuscleId.quads,
  MuscleId.hamstrings,
  MuscleId.glutes,
  MuscleId.calves,
];

const List<MuscleId> UNTRACKED_MUSCLES = [
  MuscleId.abs,
  MuscleId.forearms,
  MuscleId.traps,
  MuscleId.erectors,
  MuscleId.adductors,
];

const List<MuscleId> ALL_MUSCLES = [...TRACKED_MUSCLES, ...UNTRACKED_MUSCLES];

const List<MuscleId> LOWER_MUSCLES = [
  MuscleId.quads,
  MuscleId.hamstrings,
  MuscleId.glutes,
  MuscleId.calves,
  MuscleId.adductors,
];

const List<MuscleId> UPPER_MUSCLES = [
  MuscleId.chest,
  MuscleId.back,
  MuscleId.frontDelts,
  MuscleId.sideDelts,
  MuscleId.rearDelts,
  MuscleId.biceps,
  MuscleId.triceps,
  MuscleId.forearms,
  MuscleId.traps,
];

enum Goal {
  leanGain('lean_gain'),
  recomp('recomp'),
  strength('strength'),
  fatLoss('fat_loss'),
  sportSupport('sport_support');

  const Goal(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Goal> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Goal fromWire(String wire) => _byWire[wire] ?? (throw FormatException('Unknown Goal: "$wire"'));
}

enum Priority {
  lifting('lifting'),
  balanced('balanced'),
  sport('sport');

  const Priority(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Priority> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Priority fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown Priority: "$wire"'));
}

enum Status {
  novice('novice'),
  intermediate('intermediate'),
  advanced('advanced');

  const Status(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Status> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Status fromWire(String wire) => _byWire[wire] ?? (throw FormatException('Unknown Status: "$wire"'));
}

/// Exercise category: decides rep range, effort range and rest.
enum Category {
  lowerFreeCompound('lower_free_compound'),
  lowerMachineCompound('lower_machine_compound'),
  upperFreePress('upper_free_press'),
  upperMachinePress('upper_machine_press'),
  pullingCompound('pulling_compound'),
  isolation('isolation');

  const Category(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Category> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Category fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown Category: "$wire"'));
}

/// `Pattern` in the reference. Renamed because `dart:core` already has a `Pattern`.
enum MovementPattern {
  squat('squat'),
  hinge('hinge'),
  verticalPull('vertical_pull'),
  verticalPush('vertical_push'),
  horizontalPull('horizontal_pull'),
  horizontalPush('horizontal_push'),
  hipExtension('hip_extension'),
  pullover('pullover'),
  uprightRow('upright_row'),
  fly('fly'),
  isolation('isolation'),
  carry('carry'),
  core('core');

  const MovementPattern(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, MovementPattern> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static MovementPattern fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown MovementPattern: "$wire"'));
}

enum Equipment {
  barbell('barbell'),
  dumbbell('dumbbell'),
  machine('machine'),
  cable('cable'),
  bodyweight('bodyweight'),
  band('band'),
  sled('sled');

  const Equipment(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Equipment> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Equipment fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown Equipment: "$wire"'));
}

enum MainLift {
  squat('squat'),
  bench('bench'),
  deadlift('deadlift'),
  ohp('ohp');

  const MainLift(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, MainLift> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static MainLift fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown MainLift: "$wire"'));
}

enum RepVariation {
  withinSession('within_session'),
  betweenSession('between_session'),
  alternatingWeek('alternating_week');

  const RepVariation(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, RepVariation> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static RepVariation fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown RepVariation: "$wire"'));
}

/// The wire value `default` is a reserved word in Dart, so that value is called [defaultStyle].
enum SplitStyle {
  defaultStyle('default'),
  alternative('alternative');

  const SplitStyle(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, SplitStyle> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SplitStyle fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SplitStyle: "$wire"'));
}

enum SportIntensity {
  light('light'),
  moderate('moderate'),
  hard('hard'),
  match('match');

  const SportIntensity(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, SportIntensity> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SportIntensity fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SportIntensity: "$wire"'));
}

enum TimeOfDay {
  morning('morning'),
  midday('midday'),
  evening('evening');

  const TimeOfDay(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, TimeOfDay> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static TimeOfDay fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown TimeOfDay: "$wire"'));
}

enum BlockKind {
  hypertrophy('hypertrophy'),
  strengthVolume('strength_volume'),
  strengthLoad('strength_load'),
  strengthPeak('strength_peak'),
  sportSupport('sport_support');

  const BlockKind(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, BlockKind> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static BlockKind fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown BlockKind: "$wire"'));
}

enum Lifestyle {
  sedentary('sedentary'),
  lightlyActive('lightly_active'),
  active('active'),
  veryActive('very_active');

  const Lifestyle(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Lifestyle> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Lifestyle fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown Lifestyle: "$wire"'));
}

enum Sex {
  male('male'),
  female('female'),
  unspecified('unspecified');

  const Sex(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Sex> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Sex fromWire(String wire) => _byWire[wire] ?? (throw FormatException('Unknown Sex: "$wire"'));
}

enum NutritionPhase {
  gain('gain'),
  maintain('maintain'),
  loss('loss');

  const NutritionPhase(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, NutritionPhase> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static NutritionPhase fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown NutritionPhase: "$wire"'));
}

enum SorenessLevel {
  sore('sore'),
  pain('pain');

  const SorenessLevel(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, SorenessLevel> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SorenessLevel fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SorenessLevel: "$wire"'));
}

/// Slot tags describe what job an exercise can do inside a session template.
///
/// Only custom exercises carry `front_raise`, `forearms`, `erectors`, `adductors` and `carry` today; no template slot asks
/// for them yet.
enum SlotTag {
  squatFree('squat_free'),
  squatMachine('squat_machine'),
  splitSquat('split_squat'),
  hingeRdl('hinge_rdl'),
  hingeDeadlift('hinge_deadlift'),
  hipExt('hip_ext'),
  legCurl('leg_curl'),
  legCurlSeated('leg_curl_seated'),
  legExt('leg_ext'),
  calf('calf'),
  pressIncline('press_incline'),
  pressFlat('press_flat'),
  pressMachine('press_machine'),
  pressVertical('press_vertical'),
  chestIso('chest_iso'),
  pullVertical('pull_vertical'),
  rowFlared('row_flared'),
  rowExtension('row_extension'),
  pullover('pullover'),
  latRaise('lat_raise'),
  rearDelt('rear_delt'),
  bicepsIso('biceps_iso'),
  tricepsIso('triceps_iso'),
  abs('abs'),
  traps('traps'),
  frontRaise('front_raise'),
  forearms('forearms'),
  erectors('erectors'),
  adductors('adductors'),
  carry('carry');

  const SlotTag(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, SlotTag> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SlotTag fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SlotTag: "$wire"'));
}

/// How an exercise trains a muscle (`ExerciseMuscle.role` in the reference).
enum MuscleRole {
  primary('primary'),
  secondary('secondary');

  const MuscleRole(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, MuscleRole> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static MuscleRole fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown MuscleRole: "$wire"'));
}

/// `Injury.severity` in the reference.
enum InjurySeverity {
  niggle('niggle'),
  pain('pain'),
  injury('injury');

  const InjurySeverity(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, InjurySeverity> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static InjurySeverity fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown InjurySeverity: "$wire"'));
}

/// `Injury.status` in the reference.
enum InjuryStatus {
  active('active'),
  rehab('rehab'),
  resolved('resolved');

  const InjuryStatus(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, InjuryStatus> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static InjuryStatus fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown InjuryStatus: "$wire"'));
}

/// `PlannedSession.kind` in the reference.
enum SessionKind {
  lift('lift'),
  deload('deload'),
  intro('intro'),
  generated('generated');

  const SessionKind(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, SessionKind> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SessionKind fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SessionKind: "$wire"'));
}

/// `PlannedSession.status` in the reference.
enum PlannedSessionStatus {
  planned('planned'),
  skipped('skipped');

  const PlannedSessionStatus(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, PlannedSessionStatus> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static PlannedSessionStatus fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown PlannedSessionStatus: "$wire"'));
}

/// `PlannedSessionState.status` in the reference.
enum SessionStateStatus {
  planned('planned'),
  inProgress('in_progress'),
  done('done'),
  skipped('skipped'),
  moved('moved');

  const SessionStateStatus(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, SessionStateStatus> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SessionStateStatus fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SessionStateStatus: "$wire"'));
}

/// `Warning.code` in the reference.
enum WarningCode {
  timeTooShort('TIME_TOO_SHORT'),
  noRestDay('NO_REST_DAY'),
  scheduleConflict('SCHEDULE_CONFLICT'),
  injuryRedFlag('INJURY_RED_FLAG'),
  noExerciseForSlot('NO_EXERCISE_FOR_SLOT'),
  lowFrequency('LOW_FREQUENCY');

  const WarningCode(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, WarningCode> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static WarningCode fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown WarningCode: "$wire"'));
}

enum ReviewKey {
  dreadingGym('dreading_gym'),
  sleepWorse('sleep_worse'),
  performanceDown('performance_down'),
  stressWorse('stress_worse'),
  achesWorse('aches_worse');

  const ReviewKey(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, ReviewKey> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static ReviewKey fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown ReviewKey: "$wire"'));
}

enum ProposalKind {
  standardDeload('standard_deload'),
  targetedDeload('targeted_deload'),
  introWeek('intro_week'),
  volumeChange('volume_change'),
  exerciseSwap('exercise_swap'),
  blockTransition('block_transition'),
  planRegenerate('plan_regenerate'),
  calorieAdjust('calorie_adjust'),
  multiplierAdjust('multiplier_adjust'),
  statusChange('status_change'),
  plateauAction('plateau_action'),
  injuryAdjust('injury_adjust');

  const ProposalKind(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, ProposalKind> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static ProposalKind fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown ProposalKind: "$wire"'));
}
