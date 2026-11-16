// SPDX-License-Identifier: GPL-3.0-only
// Proposal payload validators + applyProposal. Pure: returns a diff the server applies in one go.
//
// The reference checks payloads with a schema library; here every payload kind has a class whose `fromJson` checks
// the same rules by hand and throws a FormatException where the schema would reject the payload. Like the schema,
// a validator ignores keys it does not know, and an optional key may be absent but not null.
// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_training/coach_training.dart';

import 'fatigue.dart';

// ---------- Payload validation ----------

/// Reads one payload object and throws a [FormatException] naming the kind and key on the first mismatch.
class _Reader {
  _Reader(this.kind, this.json);

  final ProposalKind kind;
  final Map<String, dynamic> json;

  Never _fail(String key, String expected) => throw FormatException(
    'Invalid ${kind.wire} payload: "$key" must be $expected, got ${json.containsKey(key) ? _show(json[key]) : 'nothing'}',
  );

  static String _show(Object? v) {
    try {
      return jsonEncode(v);
    } on JsonUnsupportedObjectError {
      return '$v';
    }
  }

  bool has(String key) => json.containsKey(key);

  Object? _required(String key, String expected) {
    if (!json.containsKey(key)) _fail(key, expected);
    return json[key];
  }

  String string(String key) => switch (_required(key, 'a string')) {
    final String s => s,
    _ => _fail(key, 'a string'),
  };

  String? nullableString(String key) => switch (_required(key, 'a string or null')) {
    null => null,
    final String s => s,
    _ => _fail(key, 'a string or null'),
  };

  String? optionalString(String key) => has(key) ? string(key) : null;

  double number(String key, {num? min, num? max}) {
    final expected = min != null && max != null ? 'a number from $min to $max' : 'a number';
    final v = _required(key, expected);
    if (v is! num || !v.isFinite || (min != null && v < min) || (max != null && v > max)) _fail(key, expected);
    return v.toDouble();
  }

  /// A number kept as the input wrote it (whole numbers stay `int`), for values the engine only passes on.
  num rawNumber(String key) {
    final v = _required(key, 'a number');
    if (v is! num || !v.isFinite) _fail(key, 'a number');
    return v;
  }

  double literal(String key, num value) {
    final v = _required(key, '$value');
    if (v is! num || v != value) _fail(key, '$value');
    return v.toDouble();
  }

  T wire<T>(String key, T Function(String) fromWire, String what) {
    final v = _required(key, what);
    if (v is! String) _fail(key, what);
    try {
      return fromWire(v);
    } on FormatException {
      _fail(key, what);
    }
  }

  T? optionalWire<T>(String key, T Function(String) fromWire, String what) =>
      has(key) ? wire(key, fromWire, what) : null;

  List<Object?> _list(String key, String expected) => switch (_required(key, expected)) {
    final List<Object?> l => l,
    _ => _fail(key, expected),
  };

  List<String> strings(String key) => [
    for (final x in _list(key, 'a list of strings'))
      if (x is String) x else _fail(key, 'a list of strings'),
  ];

  List<T> wires<T>(String key, T Function(String) fromWire, String what) {
    final out = <T>[];
    for (final x in _list(key, 'a list of $what')) {
      if (x is! String) _fail(key, 'a list of $what');
      try {
        out.add(fromWire(x));
      } on FormatException {
        _fail(key, 'a list of $what');
      }
    }
    return out;
  }

  List<MuscleChange> changes(String key) => [
    for (final x in _list(key, 'a list of muscle changes'))
      if (x is Map<String, dynamic>) MuscleChange._read(_Reader(kind, x)) else _fail(key, 'a list of muscle changes'),
  ];

  List<MuscleChange>? optionalChanges(String key) => has(key) ? changes(key) : null;
}

/// A weekly set change for one tracked muscle (`volume_change` and `plateau_action` payloads).
class MuscleChange {
  MuscleChange({required this.muscle, required this.from, required this.to});

  factory MuscleChange._read(_Reader r) => MuscleChange(
    muscle: r.wire('muscle', MuscleId.trackedFromWire, 'a tracked muscle'),
    from: r.number('from'),
    to: r.number('to'),
  );

  final TrackedMuscle muscle;
  final double from;
  final double to;

  Map<String, dynamic> toJson() => {'muscle': muscle.wire, 'from': from, 'to': to};
}

/// `standard_deload` payload mode.
enum DeloadMode {
  sets('sets'),
  fewerSessions('fewer_sessions');

  const DeloadMode(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, DeloadMode> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static DeloadMode fromWire(String wire) => _byWire[wire] ?? (throw FormatException('Unknown DeloadMode: "$wire"'));
}

/// `targeted_deload` payload mode. 'higher_reps' = T-FAT-05: keep sets, move the area's exercises to a higher rep
/// range for the week.
enum TargetedDeloadMode {
  deload('deload'),
  higherReps('higher_reps');

  const TargetedDeloadMode(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, TargetedDeloadMode> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static TargetedDeloadMode fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown TargetedDeloadMode: "$wire"'));
}

/// `plateau_action` payload step.
enum PlateauStep {
  fixBasics('fix_basics'),
  deload('deload'),
  addVolume('add_volume');

  const PlateauStep(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, PlateauStep> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static PlateauStep fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown PlateauStep: "$wire"'));
}

/// A validated proposal payload. [parse] is the reference's `PAYLOAD_SCHEMAS[kind].parse(payload)`.
sealed class ProposalPayload {
  const ProposalPayload();

  /// Checks [map] against the rules for [kind] and returns the typed payload. Unknown keys are ignored.
  /// Throws a [FormatException] when the payload does not match.
  static ProposalPayload parse(ProposalKind kind, Map<String, dynamic> map) {
    final r = _Reader(kind, map);
    return switch (kind) {
      ProposalKind.standardDeload => StandardDeloadPayload._read(r),
      ProposalKind.targetedDeload => TargetedDeloadPayload._read(r),
      ProposalKind.introWeek => IntroWeekPayload._read(r),
      ProposalKind.volumeChange => VolumeChangePayload._read(r),
      ProposalKind.exerciseSwap => ExerciseSwapPayload._read(r),
      ProposalKind.blockTransition => BlockTransitionPayload._read(r),
      ProposalKind.planRegenerate => PlanRegeneratePayload._read(r),
      ProposalKind.statusChange => StatusChangePayload._read(r),
      ProposalKind.plateauAction => PlateauActionPayload._read(r),
      ProposalKind.injuryAdjust => InjuryAdjustPayload._read(r),
      ProposalKind.calorieAdjust => CalorieAdjustPayload._read(r),
      ProposalKind.multiplierAdjust => MultiplierAdjustPayload._read(r),
    };
  }

  ProposalKind get kind;

  /// The payload as validated: known keys only, absent optional keys left out.
  Map<String, dynamic> toJson();
}

class StandardDeloadPayload extends ProposalPayload {
  const StandardDeloadPayload({required this.weekStart, required this.setCutPct, required this.mode});

  factory StandardDeloadPayload._read(_Reader r) => StandardDeloadPayload(
    weekStart: r.string('weekStart'),
    setCutPct: r.number('setCutPct', min: 0.3, max: 0.5),
    mode: r.wire('mode', DeloadMode.fromWire, '"sets" or "fewer_sessions"'),
  );

  final String weekStart;
  final double setCutPct;
  final DeloadMode mode;

  @override
  ProposalKind get kind => ProposalKind.standardDeload;

  @override
  Map<String, dynamic> toJson() => {'weekStart': weekStart, 'setCutPct': setCutPct, 'mode': mode.wire};
}

class TargetedDeloadPayload extends ProposalPayload {
  const TargetedDeloadPayload({
    required this.weekStart,
    required this.muscles,
    required this.removeExerciseIds,
    required this.reduceSetsPct,
    this.mode,
  });

  factory TargetedDeloadPayload._read(_Reader r) => TargetedDeloadPayload(
    weekStart: r.string('weekStart'),
    muscles: r.wires('muscles', MuscleId.fromWire, 'muscles'),
    removeExerciseIds: r.strings('removeExerciseIds'),
    reduceSetsPct: r.number('reduceSetsPct', min: 0, max: 1),
    mode: r.optionalWire('mode', TargetedDeloadMode.fromWire, '"deload" or "higher_reps"'),
  );

  final String weekStart;
  final List<MuscleId> muscles;
  final List<String> removeExerciseIds;
  final double reduceSetsPct;
  final TargetedDeloadMode? mode;

  @override
  ProposalKind get kind => ProposalKind.targetedDeload;

  @override
  Map<String, dynamic> toJson() => {
    'weekStart': weekStart,
    'muscles': [for (final m in muscles) m.wire],
    'removeExerciseIds': [...removeExerciseIds],
    'reduceSetsPct': reduceSetsPct,
    if (mode case final mode?) 'mode': mode.wire,
  };
}

class IntroWeekPayload extends ProposalPayload {
  const IntroWeekPayload({required this.blockId, required this.setPct, required this.rirBump});

  factory IntroWeekPayload._read(_Reader r) => IntroWeekPayload(
    blockId: r.string('blockId'),
    setPct: r.literal('setPct', 0.75),
    rirBump: r.literal('rirBump', 1),
  );

  final String blockId;

  /// Always 0.75.
  final double setPct;

  /// Always 1.
  final double rirBump;

  @override
  ProposalKind get kind => ProposalKind.introWeek;

  @override
  Map<String, dynamic> toJson() => {'blockId': blockId, 'setPct': setPct, 'rirBump': rirBump};
}

class VolumeChangePayload extends ProposalPayload {
  const VolumeChangePayload({required this.changes});

  factory VolumeChangePayload._read(_Reader r) => VolumeChangePayload(changes: r.changes('changes'));

  final List<MuscleChange> changes;

  @override
  ProposalKind get kind => ProposalKind.volumeChange;

  @override
  Map<String, dynamic> toJson() => {
    'changes': [for (final c in changes) c.toJson()],
  };
}

class ExerciseSwapPayload extends ProposalPayload {
  const ExerciseSwapPayload({
    required this.plannedExerciseIds,
    required this.fromExerciseId,
    required this.toExerciseId,
    required this.reason,
  });

  factory ExerciseSwapPayload._read(_Reader r) => ExerciseSwapPayload(
    plannedExerciseIds: r.strings('plannedExerciseIds'),
    fromExerciseId: r.string('fromExerciseId'),
    toExerciseId: r.string('toExerciseId'),
    reason: r.string('reason'),
  );

  final List<String> plannedExerciseIds;
  final String fromExerciseId;
  final String toExerciseId;
  final String reason;

  @override
  ProposalKind get kind => ProposalKind.exerciseSwap;

  @override
  Map<String, dynamic> toJson() => {
    'plannedExerciseIds': [...plannedExerciseIds],
    'fromExerciseId': fromExerciseId,
    'toExerciseId': toExerciseId,
    'reason': reason,
  };
}

class BlockTransitionPayload extends ProposalPayload {
  const BlockTransitionPayload({required this.fromKind, required this.toKind, required this.startsOn});

  factory BlockTransitionPayload._read(_Reader r) => BlockTransitionPayload(
    fromKind: r.string('fromKind'),
    toKind: r.string('toKind'),
    startsOn: r.string('startsOn'),
  );

  /// Block kinds as strings: the reference's schema accepts any string here.
  final String fromKind;
  final String toKind;
  final String startsOn;

  @override
  ProposalKind get kind => ProposalKind.blockTransition;

  @override
  Map<String, dynamic> toJson() => {'fromKind': fromKind, 'toKind': toKind, 'startsOn': startsOn};
}

class PlanRegeneratePayload extends ProposalPayload {
  const PlanRegeneratePayload({required this.reason});

  factory PlanRegeneratePayload._read(_Reader r) => PlanRegeneratePayload(reason: r.string('reason'));

  final String reason;

  @override
  ProposalKind get kind => ProposalKind.planRegenerate;

  @override
  Map<String, dynamic> toJson() => {'reason': reason};
}

class StatusChangePayload extends ProposalPayload {
  const StatusChangePayload({required this.from, required this.to, required this.evidence});

  factory StatusChangePayload._read(_Reader r) => StatusChangePayload(
    from: r.wire('from', Status.fromWire, 'a training status'),
    to: r.wire('to', Status.fromWire, 'a training status'),
    evidence: r.string('evidence'),
  );

  final Status from;
  final Status to;
  final String evidence;

  @override
  ProposalKind get kind => ProposalKind.statusChange;

  @override
  Map<String, dynamic> toJson() => {'from': from.wire, 'to': to.wire, 'evidence': evidence};
}

class PlateauActionPayload extends ProposalPayload {
  const PlateauActionPayload({required this.exerciseId, required this.step, required this.details, this.changes});

  factory PlateauActionPayload._read(_Reader r) => PlateauActionPayload(
    exerciseId: r.string('exerciseId'),
    step: r.wire('step', PlateauStep.fromWire, '"fix_basics", "deload" or "add_volume"'),
    details: r.string('details'),
    changes: r.optionalChanges('changes'),
  );

  final String exerciseId;
  final PlateauStep step;
  final String details;
  final List<MuscleChange>? changes;

  @override
  ProposalKind get kind => ProposalKind.plateauAction;

  @override
  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'step': step.wire,
    'details': details,
    if (changes case final changes?) 'changes': [for (final c in changes) c.toJson()],
  };
}

class InjuryAdjustPayload extends ProposalPayload {
  const InjuryAdjustPayload({
    required this.injuryId,
    required this.removeExerciseIds,
    required this.addExerciseIds,
    this.muscle,
    this.severity,
    this.label,
  });

  factory InjuryAdjustPayload._read(_Reader r) => InjuryAdjustPayload(
    injuryId: r.nullableString('injuryId'),
    removeExerciseIds: r.strings('removeExerciseIds'),
    addExerciseIds: r.strings('addExerciseIds'),
    muscle: r.optionalWire('muscle', MuscleId.fromWire, 'a muscle'),
    severity: r.optionalWire('severity', InjurySeverity.fromWire, '"niggle", "pain" or "injury"'),
    label: r.optionalString('label'),
  );

  /// null = no injury logged yet: accepting records one from recurring check-in pain.
  final String? injuryId;
  final List<String> removeExerciseIds;
  final List<String> addExerciseIds;
  final MuscleId? muscle;
  final InjurySeverity? severity;
  final String? label;

  @override
  ProposalKind get kind => ProposalKind.injuryAdjust;

  @override
  Map<String, dynamic> toJson() => {
    'injuryId': injuryId,
    'removeExerciseIds': [...removeExerciseIds],
    'addExerciseIds': [...addExerciseIds],
    if (muscle case final muscle?) 'muscle': muscle.wire,
    if (severity case final severity?) 'severity': severity.wire,
    'label': ?label,
  };
}

class CalorieAdjustPayload extends ProposalPayload {
  const CalorieAdjustPayload({required this.fromKcal, required this.toKcal, required this.reason});

  factory CalorieAdjustPayload._read(_Reader r) =>
      CalorieAdjustPayload(fromKcal: r.rawNumber('fromKcal'), toKcal: r.rawNumber('toKcal'), reason: r.string('reason'));

  /// Any number: the schema does not require whole kcal.
  final num fromKcal;
  final num toKcal;
  final String reason;

  @override
  ProposalKind get kind => ProposalKind.calorieAdjust;

  @override
  Map<String, dynamic> toJson() => {'fromKcal': fromKcal, 'toKcal': toKcal, 'reason': reason};
}

class MultiplierAdjustPayload extends ProposalPayload {
  const MultiplierAdjustPayload({required this.from, required this.to, required this.reason});

  factory MultiplierAdjustPayload._read(_Reader r) =>
      MultiplierAdjustPayload(from: r.number('from'), to: r.number('to'), reason: r.string('reason'));

  final double from;
  final double to;
  final String reason;

  @override
  ProposalKind get kind => ProposalKind.multiplierAdjust;

  @override
  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'reason': reason};
}

/// Throws a [FormatException] when the proposal's payload does not match its kind; returns the proposal unchanged.
Proposal validateProposal(Proposal p) {
  ProposalPayload.parse(p.kind, p.payload);
  return p;
}

// ---------- Duplicate checks ----------

/// A value as the reference's string interpolation writes it. [present] is false for a key that is missing, which
/// the reference writes as "undefined".
String _jsString(Object? v, {bool present = true}) => switch (v) {
  _ when !present => 'undefined',
  null => 'null',
  final String s => s,
  final num n => jsNumber(n),
  final bool b => '$b',
  final List<Object?> l => l.map((x) => x == null ? '' : _jsString(x)).join(','),
  _ => '[object Object]',
};

/// Identity of a proposal for duplicate checks: same kind and same target (exercise, mode, injury or muscle).
String proposalKey(String kind, Object? payload) {
  final p = payload is Map ? payload : const <Object?, Object?>{};
  String field(String k) => _jsString(p[k], present: p.containsKey(k));
  if (kind == 'plateau_action') return '$kind:${field('exerciseId')}';
  if (kind == 'targeted_deload') return '$kind:${p['mode'] == null ? 'deload' : field('mode')}';
  if (kind == 'exercise_swap') return '$kind:${field('fromExerciseId')}';
  if (kind == 'injury_adjust') return '$kind:${p['injuryId'] == null ? field('muscle') : field('injuryId')}';
  return kind;
}

/// Key-order-independent JSON, so payloads that differ only in key order compare equal.
String stableJson(Object? x) {
  if (x is List) return '[${x.map(stableJson).join(',')}]';
  if (x is Map) {
    final keys = stableSorted([for (final k in x.keys) k as String], (a, b) => a.compareTo(b));
    return '{${keys.map((k) => '${jsonEncode(k)}:${stableJson(x[k])}').join(',')}}';
  }
  if (x is num) return x.isFinite ? jsNumber(x) : 'null';
  return jsonEncode(x);
}

// ---------- Applying a proposal ----------

/// The stored plan a proposal is applied to.
class StoredPlan {
  StoredPlan({required this.sessions, required this.exercises, required this.today});

  factory StoredPlan.fromJson(Map<String, dynamic> json) => StoredPlan(
    sessions: [for (final x in json['sessions'] as List) PlannedSessionState.fromJson(x as Map<String, dynamic>)],
    exercises: [for (final x in json['exercises'] as List) ExerciseDef.fromJson(x as Map<String, dynamic>)],
    today: json['today'] as String,
  );

  final List<PlannedSessionState> sessions;
  final List<ExerciseDef> exercises;
  final String today;

  Map<String, dynamic> toJson() => {
    'sessions': [for (final s in sessions) s.toJson()],
    'exercises': [for (final e in exercises) e.toJson()],
    'today': today,
  };
}

/// `PlanDiff.exerciseUpdates` entry: the fields of one planned exercise to overwrite.
class ExerciseUpdate {
  ExerciseUpdate({required this.id, this.sets, this.rirMin, this.rirMax, this.repMin, this.repMax, this.exerciseId});

  factory ExerciseUpdate.fromJson(Map<String, dynamic> json) => ExerciseUpdate(
    id: json['id'] as String,
    sets: json['sets'] as int?,
    rirMin: (json['rirMin'] as num?)?.toDouble(),
    rirMax: (json['rirMax'] as num?)?.toDouble(),
    repMin: json['repMin'] as int?,
    repMax: json['repMax'] as int?,
    exerciseId: json['exerciseId'] as String?,
  );

  final String id;
  final int? sets;
  final double? rirMin;
  final double? rirMax;
  final int? repMin;
  final int? repMax;
  final String? exerciseId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sets': ?sets,
    'rirMin': ?rirMin,
    'rirMax': ?rirMax,
    'repMin': ?repMin,
    'repMax': ?repMax,
    'exerciseId': ?exerciseId,
  };
}

/// `PlanDiff.sessionUpdates` entry. The engine only ever sets `status: skipped` or `kind: deload | intro`.
class SessionUpdate {
  SessionUpdate({required this.id, this.status, this.kind});

  factory SessionUpdate.fromJson(Map<String, dynamic> json) => SessionUpdate(
    id: json['id'] as String,
    status: json['status'] == null ? null : SessionStateStatus.fromWire(json['status'] as String),
    kind: json['kind'] == null ? null : SessionKind.fromWire(json['kind'] as String),
  );

  final String id;
  final SessionStateStatus? status;
  final SessionKind? kind;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (status case final status?) 'status': status.wire,
    if (kind case final kind?) 'kind': kind.wire,
  };
}

/// `PlanDiff.regenerate`: rebuild the plan from today, with these changes.
class RegenerateRequest {
  RegenerateRequest({required this.reason, this.blockKind, this.startsOn, this.fromHeavyPhase, this.targetAdjustments});

  factory RegenerateRequest.fromJson(Map<String, dynamic> json) => RegenerateRequest(
    reason: json['reason'] as String,
    blockKind: json['blockKind'] == null ? null : BlockKind.fromWire(json['blockKind'] as String),
    startsOn: json['startsOn'] as String?,
    fromHeavyPhase: json['fromHeavyPhase'] as bool?,
    targetAdjustments: json['targetAdjustments'] == null
        ? null
        : {
            for (final e in (json['targetAdjustments'] as Map<String, dynamic>).entries)
              MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
          },
  );

  final String reason;
  final BlockKind? blockKind;
  final String? startsOn;
  final bool? fromHeavyPhase;
  final Map<TrackedMuscle, double>? targetAdjustments;

  Map<String, dynamic> toJson() => {
    'reason': reason,
    if (blockKind case final blockKind?) 'blockKind': blockKind.wire,
    'startsOn': ?startsOn,
    'fromHeavyPhase': ?fromHeavyPhase,
    if (targetAdjustments case final adj?) 'targetAdjustments': {for (final e in adj.entries) e.key.wire: e.value},
  };
}

/// `PlanDiff.settings`.
class SettingsUpdate {
  SettingsUpdate({this.trainingStatus});

  factory SettingsUpdate.fromJson(Map<String, dynamic> json) => SettingsUpdate(
    trainingStatus: json['trainingStatus'] == null ? null : Status.fromWire(json['trainingStatus'] as String),
  );

  final Status? trainingStatus;

  Map<String, dynamic> toJson() => {if (trainingStatus case final s?) 'trainingStatus': s.wire};
}

/// `PlanDiff.injury`: create (id null) or update an injury before the plan is regenerated (T-SEL-08).
class InjuryUpdate {
  InjuryUpdate({required this.id, this.muscleId, this.label, this.severity, required this.addAvoidIds});

  factory InjuryUpdate.fromJson(Map<String, dynamic> json) => InjuryUpdate(
    id: json['id'] as String?,
    muscleId: json['muscleId'] == null ? null : MuscleId.fromWire(json['muscleId'] as String),
    label: json['label'] as String?,
    severity: json['severity'] == null ? null : InjurySeverity.fromWire(json['severity'] as String),
    addAvoidIds: [for (final x in json['addAvoidIds'] as List) x as String],
  );

  final String? id;
  final MuscleId? muscleId;
  final String? label;
  final InjurySeverity? severity;
  final List<String> addAvoidIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (muscleId case final m?) 'muscleId': m.wire,
    'label': ?label,
    if (severity case final s?) 'severity': s.wire,
    'addAvoidIds': [...addAvoidIds],
  };
}

/// `PlanDiff.nutrition`.
class NutritionUpdate {
  NutritionUpdate({this.kcal, this.multiplier});

  factory NutritionUpdate.fromJson(Map<String, dynamic> json) =>
      NutritionUpdate(kcal: json['kcal'] as num?, multiplier: (json['multiplier'] as num?)?.toDouble());

  final num? kcal;
  final double? multiplier;

  Map<String, dynamic> toJson() => {'kcal': ?kcal, 'multiplier': ?multiplier};
}

/// What accepting a proposal changes. Plain data that round-trips through JSON, so it can be stored as an undo record.
class PlanDiff {
  PlanDiff({
    required this.exerciseUpdates,
    required this.exerciseDeletes,
    required this.sessionUpdates,
    this.regenerate,
    this.settings,
    this.injury,
    this.nutrition,
    required this.summary,
  });

  factory PlanDiff.fromJson(Map<String, dynamic> json) => PlanDiff(
    exerciseUpdates: [
      for (final x in json['exerciseUpdates'] as List) ExerciseUpdate.fromJson(x as Map<String, dynamic>),
    ],
    exerciseDeletes: [for (final x in json['exerciseDeletes'] as List) x as String],
    sessionUpdates: [for (final x in json['sessionUpdates'] as List) SessionUpdate.fromJson(x as Map<String, dynamic>)],
    regenerate: json['regenerate'] == null
        ? null
        : RegenerateRequest.fromJson(json['regenerate'] as Map<String, dynamic>),
    settings: json['settings'] == null ? null : SettingsUpdate.fromJson(json['settings'] as Map<String, dynamic>),
    injury: json['injury'] == null ? null : InjuryUpdate.fromJson(json['injury'] as Map<String, dynamic>),
    nutrition: json['nutrition'] == null ? null : NutritionUpdate.fromJson(json['nutrition'] as Map<String, dynamic>),
    summary: [for (final x in json['summary'] as List) x as String],
  );

  /// The diff with no changes.
  factory PlanDiff.empty() => PlanDiff(exerciseUpdates: [], exerciseDeletes: [], sessionUpdates: [], summary: []);

  final List<ExerciseUpdate> exerciseUpdates;
  final List<String> exerciseDeletes;
  final List<SessionUpdate> sessionUpdates;
  final RegenerateRequest? regenerate;
  final SettingsUpdate? settings;

  /// injury_adjust: create (id null) or update an injury before the plan is regenerated (T-SEL-08).
  final InjuryUpdate? injury;
  final NutritionUpdate? nutrition;
  final List<String> summary;

  Map<String, dynamic> toJson() => {
    'exerciseUpdates': [for (final x in exerciseUpdates) x.toJson()],
    'exerciseDeletes': [...exerciseDeletes],
    'sessionUpdates': [for (final x in sessionUpdates) x.toJson()],
    if (regenerate case final regenerate?) 'regenerate': regenerate.toJson(),
    if (settings case final settings?) 'settings': settings.toJson(),
    if (injury case final injury?) 'injury': injury.toJson(),
    if (nutrition case final nutrition?) 'nutrition': nutrition.toJson(),
    'summary': [...summary],
  };
}

bool _inWeek(PlannedSessionState s, String weekStart) =>
    s.date.compareTo(weekStart) >= 0 &&
    s.date.compareTo(addDays(weekStart, 7)) < 0 &&
    s.status == SessionStateStatus.planned;

List<PlannedSessionState> _byDate(Iterable<PlannedSessionState> xs) => stableSorted(xs, (a, b) => a.date.compareTo(b.date));

/// Standard deload: cut sets on every exercise, keep loads/RIR/sessions (T-FAT-03).
PlanDiff deloadDiff(StoredPlan plan, String weekStart, num cutPct, DeloadMode mode) {
  final d = PlanDiff.empty();
  final week = _byDate(plan.sessions.where((s) => _inWeek(s, weekStart)));
  if (mode == DeloadMode.fewerSessions) {
    for (final s in week.skip(2)) {
      d.sessionUpdates.add(SessionUpdate(id: s.id, status: SessionStateStatus.skipped));
    }
    for (final s in week.take(2)) {
      d.sessionUpdates.add(SessionUpdate(id: s.id, kind: SessionKind.deload));
    }
    d.summary.add('Keep 2 sessions in the week of $weekStart; skip ${math.max(0, week.length - 2)}.');
    return d;
  }
  for (final s in week) {
    d.sessionUpdates.add(SessionUpdate(id: s.id, kind: SessionKind.deload));
    for (final e in s.exercises) {
      final sets = _atLeastOne(roundHalfUp(e.sets * (1 - cutPct)));
      if (sets != e.sets) d.exerciseUpdates.add(ExerciseUpdate(id: e.id, sets: sets));
    }
  }
  d.summary.add(
    'Week of $weekStart: sets × ${(1 - cutPct).toStringAsFixed(1)} on ${week.length} sessions; loads and RIR unchanged.',
  );
  return d;
}

int _atLeastOne(int sets) => math.max(1, sets);

/// `{ ...empty(), ...fields }` in the reference: no exercise or session changes.
PlanDiff _diff({
  RegenerateRequest? regenerate,
  SettingsUpdate? settings,
  InjuryUpdate? injury,
  NutritionUpdate? nutrition,
  required List<String> summary,
}) => PlanDiff(
  exerciseUpdates: [],
  exerciseDeletes: [],
  sessionUpdates: [],
  regenerate: regenerate,
  settings: settings,
  injury: injury,
  nutrition: nutrition,
  summary: summary,
);

Map<TrackedMuscle, double> _adjustments(List<MuscleChange> changes) {
  final adj = <TrackedMuscle, double>{};
  for (final c in changes) {
    adj[c.muscle] = (adj[c.muscle] ?? 0) + (c.to - c.from);
  }
  return adj;
}

PlanDiff applyProposal(StoredPlan plan, Proposal p) {
  final exMap = {for (final e in plan.exercises) e.id: e};
  switch (p.kind) {
    case ProposalKind.standardDeload:
      final pl = StandardDeloadPayload._read(_Reader(p.kind, p.payload));
      return deloadDiff(plan, pl.weekStart, pl.setCutPct, pl.mode);
    case ProposalKind.targetedDeload:
      final pl = TargetedDeloadPayload._read(_Reader(p.kind, p.payload));
      final d = PlanDiff.empty();
      final muscles = pl.muscles.map((m) => m.wire).join(', ');
      if (pl.mode == TargetedDeloadMode.higherReps) {
        // T-FAT-05: same exercises and sets; the ones working the area move to a higher rep range (lighter loads follow).
        for (final s in plan.sessions.where((x) => _inWeek(x, pl.weekStart))) {
          for (final e in s.exercises) {
            final ex = exMap[e.exerciseId];
            if (ex == null || !pl.muscles.any((m) => isPrimary(ex, m) || (m == MuscleId.erectors && ex.axialLoad))) {
              continue;
            }
            final [repMin, repMax] = HIGHER_REP_WEEK[ex.category]!;
            if (e.repMin != null && e.repMin! >= repMin) continue;
            d.exerciseUpdates.add(ExerciseUpdate(id: e.id, repMin: repMin, repMax: repMax));
          }
        }
        d.summary.add(
          'Higher-rep week of ${pl.weekStart} on ${d.exerciseUpdates.length} exercises for $muscles; sets unchanged.',
        );
        return d;
      }
      for (final s in plan.sessions.where((x) => _inWeek(x, pl.weekStart))) {
        for (final e in s.exercises) {
          if (pl.removeExerciseIds.contains(e.exerciseId)) {
            d.exerciseDeletes.add(e.id);
            continue;
          }
          final ex = exMap[e.exerciseId];
          if (ex != null &&
              pl.muscles.any(
                (m) => exercisesLoadingArea(ex, m) == AreaLoading.reduce || (m != MuscleId.erectors && isPrimary(ex, m)),
              )) {
            final sets = _atLeastOne(roundHalfUp(e.sets * (1 - pl.reduceSetsPct)));
            if (sets != e.sets) d.exerciseUpdates.add(ExerciseUpdate(id: e.id, sets: sets));
          }
        }
      }
      d.summary.add(
        'Removed ${d.exerciseDeletes.length} exercises and reduced ${d.exerciseUpdates.length} for $muscles.',
      );
      return d;
    case ProposalKind.introWeek:
      final d = PlanDiff.empty();
      final planned = _byDate(plan.sessions.where((s) => s.status == SessionStateStatus.planned));
      if (planned.isEmpty) return d;
      final ws = addDays(planned.first.date, 0);
      for (final s in plan.sessions) {
        if (s.date.compareTo(ws) < 0 ||
            s.date.compareTo(addDays(ws, 7)) >= 0 ||
            s.status != SessionStateStatus.planned) {
          continue;
        }
        d.sessionUpdates.add(SessionUpdate(id: s.id, kind: SessionKind.intro));
        for (final e in s.exercises) {
          d.exerciseUpdates.add(
            ExerciseUpdate(
              id: e.id,
              sets: _atLeastOne(roundHalfUp(e.sets * INTRO_WEEK.setPct)),
              rirMin: e.rirMin + INTRO_WEEK.rirBump,
              rirMax: e.rirMax + INTRO_WEEK.rirBump,
            ),
          );
        }
      }
      d.summary.add('Intro week: 75% of sets, +1 RIR.');
      return d;
    case ProposalKind.volumeChange:
      final pl = VolumeChangePayload._read(_Reader(p.kind, p.payload));
      return _diff(
        regenerate: RegenerateRequest(reason: 'volume_change', targetAdjustments: _adjustments(pl.changes)),
        summary: [for (final c in pl.changes) '${c.muscle.wire}: ${jsNumber(c.from)} → ${jsNumber(c.to)} sets/week'],
      );
    case ProposalKind.plateauAction:
      final pl = PlateauActionPayload._read(_Reader(p.kind, p.payload));
      if (pl.step == PlateauStep.deload) {
        final next = addDays(plan.today, 8 - _isoWd(plan.today));
        return deloadDiff(plan, next, 0.4, DeloadMode.sets);
      }
      final changes = pl.changes;
      if (pl.step == PlateauStep.addVolume && changes != null && changes.isNotEmpty) {
        return _diff(
          regenerate: RegenerateRequest(reason: 'plateau_add_volume', targetAdjustments: _adjustments(changes)),
          summary: [for (final c in changes) '${c.muscle.wire}: +${jsNumber(c.to - c.from)} sets/week'],
        );
      }
      // Nothing in the plan changes: the accepted proposal itself is the record, and Today shows its checklist for a week.
      return _diff(summary: ['Basics checklist pinned to Today for the next 7 days. Reassess after another block.']);
    case ProposalKind.exerciseSwap:
      final pl = ExerciseSwapPayload._read(_Reader(p.kind, p.payload));
      final d = PlanDiff.empty();
      for (final s in plan.sessions.where((x) => x.status == SessionStateStatus.planned)) {
        for (final e in s.exercises) {
          if (pl.plannedExerciseIds.contains(e.id) || e.exerciseId == pl.fromExerciseId) {
            d.exerciseUpdates.add(ExerciseUpdate(id: e.id, exerciseId: pl.toExerciseId));
          }
        }
      }
      d.summary.add('Swapped ${d.exerciseUpdates.length} planned exercises.');
      return d;
    case ProposalKind.blockTransition:
      final pl = BlockTransitionPayload._read(_Reader(p.kind, p.payload));
      final heavy = pl.fromKind == 'strength_load' || pl.fromKind == 'strength_peak';
      return _diff(
        regenerate: RegenerateRequest(
          reason: 'block_transition',
          blockKind: BlockKind.fromWire(pl.toKind),
          startsOn: pl.startsOn,
          fromHeavyPhase: heavy,
        ),
        summary: ['New ${pl.toKind} block from ${pl.startsOn}.'],
      );
    case ProposalKind.planRegenerate:
      return _diff(regenerate: RegenerateRequest(reason: p.kind.wire), summary: ['Plan regenerated from today.']);
    case ProposalKind.injuryAdjust:
      final pl = InjuryAdjustPayload._read(_Reader(p.kind, p.payload));
      final hasId = pl.injuryId != null && pl.injuryId!.isNotEmpty;
      final injury = hasId || pl.muscle != null
          ? InjuryUpdate(
              id: pl.injuryId,
              muscleId: pl.muscle,
              label: pl.label,
              severity: pl.severity,
              addAvoidIds: pl.removeExerciseIds,
            )
          : null;
      final names = [for (final id in pl.removeExerciseIds) exMap[id]?.name ?? id];
      return _diff(
        injury: injury,
        regenerate: RegenerateRequest(reason: p.kind.wire),
        summary: [
          '${hasId ? 'Injury updated' : 'Injury logged'}${names.isNotEmpty ? '; avoiding ${names.join(', ')}' : ''}. Plan regenerated from today.',
        ],
      );
    case ProposalKind.statusChange:
      final pl = StatusChangePayload._read(_Reader(p.kind, p.payload));
      return _diff(
        settings: SettingsUpdate(trainingStatus: pl.to),
        regenerate: RegenerateRequest(reason: 'status_change'),
        summary: ['Status ${pl.from.wire} → ${pl.to.wire}.'],
      );
    case ProposalKind.calorieAdjust:
      final pl = CalorieAdjustPayload._read(_Reader(p.kind, p.payload));
      return _diff(
        nutrition: NutritionUpdate(kcal: pl.toKcal),
        summary: ['Calories ${jsNumber(pl.fromKcal)} → ${jsNumber(pl.toKcal)}.'],
      );
    case ProposalKind.multiplierAdjust:
      final pl = MultiplierAdjustPayload._read(_Reader(p.kind, p.payload));
      return _diff(
        nutrition: NutritionUpdate(multiplier: pl.to),
        summary: ['Activity factor ${jsNumber(pl.from)} → ${jsNumber(pl.to)}.'],
      );
  }
}

int _isoWd(String iso) => isoWeekday(iso);
