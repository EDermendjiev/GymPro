// SPDX-License-Identifier: GPL-3.0-only
// Logged training history, as the engine reads it.
import 'enums.dart';

class LoggedSet {
  LoggedSet({
    required this.exerciseId,
    required this.performedOn,
    required this.setIndex,
    required this.loadKg,
    required this.reps,
    required this.rir,
    required this.isWarmup,
    this.sessionId,
    this.plannedRirMin,
    this.loggedAt,
  });

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    exerciseId: json['exerciseId'] as String,
    performedOn: json['performedOn'] as String,
    setIndex: json['setIndex'] as int,
    loadKg: json['loadKg'] == null ? null : (json['loadKg'] as num).toDouble(),
    reps: json['reps'] as int,
    rir: json['rir'] == null ? null : (json['rir'] as num).toDouble(),
    isWarmup: json['isWarmup'] as bool,
    sessionId: json['sessionId'] == null ? null : json['sessionId'] as String,
    plannedRirMin: json['plannedRirMin'] == null ? null : (json['plannedRirMin'] as num).toDouble(),
    loggedAt: json['loggedAt'] == null ? null : json['loggedAt'] as String,
  );

  final String exerciseId;

  /// ISO date.
  final String performedOn;
  final int setIndex;
  final double? loadKg;
  final int reps;
  final double? rir;
  final bool isWarmup;
  final String? sessionId;

  /// Prescribed RIR floor of the planned exercise this set was logged against (RIR drift, T-RIR-01).
  final double? plannedRirMin;

  /// When the set was logged (an ISO timestamp); used for the generator's real 48 h window.
  final String? loggedAt;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'performedOn': performedOn,
    'setIndex': setIndex,
    'loadKg': loadKg,
    'reps': reps,
    'rir': rir,
    'isWarmup': isWarmup,
    'sessionId': ?sessionId,
    'plannedRirMin': ?plannedRirMin,
    'loggedAt': ?loggedAt,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  LoggedSet copyWith({
    String? exerciseId,
    String? performedOn,
    int? setIndex,
    double? loadKg,
    int? reps,
    double? rir,
    bool? isWarmup,
    String? sessionId,
    double? plannedRirMin,
    String? loggedAt,
  }) => LoggedSet(
    exerciseId: exerciseId ?? this.exerciseId,
    performedOn: performedOn ?? this.performedOn,
    setIndex: setIndex ?? this.setIndex,
    loadKg: loadKg ?? this.loadKg,
    reps: reps ?? this.reps,
    rir: rir ?? this.rir,
    isWarmup: isWarmup ?? this.isWarmup,
    sessionId: sessionId ?? this.sessionId,
    plannedRirMin: plannedRirMin ?? this.plannedRirMin,
    loggedAt: loggedAt ?? this.loggedAt,
  );
}

class PreviousBlockSummary {
  PreviousBlockSummary({
    required this.kind,
    required this.medianTargetBeforeTrims,
    required this.endedOn,
    required this.selections,
    this.targetAdjustments,
  });

  factory PreviousBlockSummary.fromJson(Map<String, dynamic> json) => PreviousBlockSummary(
    kind: BlockKind.fromWire(json['kind'] as String),
    medianTargetBeforeTrims: (json['medianTargetBeforeTrims'] as num).toDouble(),
    endedOn: json['endedOn'] as String,
    selections: {
      for (final e in (json['selections'] as Map<String, dynamic>).entries)
        e.key: {for (final f in (e.value as Map<String, dynamic>).entries) f.key: f.value as String},
    },
    targetAdjustments: json['targetAdjustments'] == null
        ? null
        : {
            for (final e in (json['targetAdjustments'] as Map<String, dynamic>).entries)
              MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
          },
  );

  final BlockKind kind;
  final double medianTargetBeforeTrims;
  final String endedOn;

  /// templateKey -> slotKey -> exerciseId for stability (T-SEL-06).
  final Map<String, Map<String, String>> selections;
  final Map<TrackedMuscle, double>? targetAdjustments;

  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'medianTargetBeforeTrims': medianTargetBeforeTrims,
    'endedOn': endedOn,
    'selections': {
      for (final e in selections.entries) e.key: {for (final f in e.value.entries) f.key: f.value},
    },
    if (targetAdjustments case final targetAdjustments?)
      'targetAdjustments': {for (final e in targetAdjustments.entries) e.key.wire: e.value},
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  PreviousBlockSummary copyWith({
    BlockKind? kind,
    double? medianTargetBeforeTrims,
    String? endedOn,
    Map<String, Map<String, String>>? selections,
    Map<TrackedMuscle, double>? targetAdjustments,
  }) => PreviousBlockSummary(
    kind: kind ?? this.kind,
    medianTargetBeforeTrims: medianTargetBeforeTrims ?? this.medianTargetBeforeTrims,
    endedOn: endedOn ?? this.endedOn,
    selections: selections ?? this.selections,
    targetAdjustments: targetAdjustments ?? this.targetAdjustments,
  );
}

class History {
  History({required this.sets, this.previousBlock, this.recentAvgWeeklySets, this.weeksOff, this.e1rmSeeds});

  factory History.fromJson(Map<String, dynamic> json) => History(
    sets: [for (final x in json['sets'] as List) LoggedSet.fromJson(x as Map<String, dynamic>)],
    previousBlock: json['previousBlock'] == null
        ? null
        : PreviousBlockSummary.fromJson(json['previousBlock'] as Map<String, dynamic>),
    recentAvgWeeklySets: json['recentAvgWeeklySets'] == null
        ? null
        : (json['recentAvgWeeklySets'] as num).toDouble(),
    weeksOff: json['weeksOff'] == null ? null : json['weeksOff'] as int,
    e1rmSeeds: json['e1rmSeeds'] == null
        ? null
        : {
            for (final e in (json['e1rmSeeds'] as Map<String, dynamic>).entries)
              MainLift.fromWire(e.key): (e.value as num).toDouble(),
          },
  );

  final List<LoggedSet> sets;
  final PreviousBlockSummary? previousBlock;

  /// Average weekly fractional sets per tracked muscle over the last 4 weeks (from logs).
  final double? recentAvgWeeklySets;

  /// Weeks since the user last trained. null = unknown.
  final int? weeksOff;
  final Map<MainLift, double>? e1rmSeeds;

  Map<String, dynamic> toJson() => {
    'sets': [for (final x in sets) x.toJson()],
    if (previousBlock case final previousBlock?) 'previousBlock': previousBlock.toJson(),
    'recentAvgWeeklySets': ?recentAvgWeeklySets,
    'weeksOff': ?weeksOff,
    if (e1rmSeeds case final e1rmSeeds?)
      'e1rmSeeds': {for (final e in e1rmSeeds.entries) e.key.wire: e.value},
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  History copyWith({
    List<LoggedSet>? sets,
    PreviousBlockSummary? previousBlock,
    double? recentAvgWeeklySets,
    int? weeksOff,
    Map<MainLift, double>? e1rmSeeds,
  }) => History(
    sets: sets ?? this.sets,
    previousBlock: previousBlock ?? this.previousBlock,
    recentAvgWeeklySets: recentAvgWeeklySets ?? this.recentAvgWeeklySets,
    weeksOff: weeksOff ?? this.weeksOff,
    e1rmSeeds: e1rmSeeds ?? this.e1rmSeeds,
  );
}

class ExposureSet {
  ExposureSet({required this.load, required this.reps, required this.rir});

  factory ExposureSet.fromJson(Map<String, dynamic> json) => ExposureSet(
    load: json['load'] == null ? null : (json['load'] as num).toDouble(),
    reps: json['reps'] as int,
    rir: json['rir'] == null ? null : (json['rir'] as num).toDouble(),
  );

  final double? load;
  final int reps;
  final double? rir;

  Map<String, dynamic> toJson() => {'load': load, 'reps': reps, 'rir': rir};
}

/// One entry of `ExerciseHistory.exposures` in the reference: the sets of one exercise in one session.
class Exposure {
  Exposure({required this.date, required this.sets});

  factory Exposure.fromJson(Map<String, dynamic> json) => Exposure(
    date: json['date'] as String,
    sets: [for (final x in json['sets'] as List) ExposureSet.fromJson(x as Map<String, dynamic>)],
  );

  final String date;
  final List<ExposureSet> sets;

  Map<String, dynamic> toJson() => {
    'date': date,
    'sets': [for (final x in sets) x.toJson()],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  Exposure copyWith({String? date, List<ExposureSet>? sets}) =>
      Exposure(date: date ?? this.date, sets: sets ?? this.sets);
}

class ExerciseHistory {
  ExerciseHistory({
    required this.exposures,
    required this.increment,
    this.e1rm,
    this.heavyLowerBarbell,
    this.status,
  });

  factory ExerciseHistory.fromJson(Map<String, dynamic> json) => ExerciseHistory(
    exposures: [for (final x in json['exposures'] as List) Exposure.fromJson(x as Map<String, dynamic>)],
    increment: (json['increment'] as num).toDouble(),
    e1rm: json['e1rm'] == null ? null : (json['e1rm'] as num).toDouble(),
    heavyLowerBarbell: json['heavyLowerBarbell'] == null ? null : json['heavyLowerBarbell'] as bool,
    status: json['status'] == null ? null : Status.fromWire(json['status'] as String),
  );

  /// Newest last.
  final List<Exposure> exposures;
  final double increment;
  final double? e1rm;
  final bool? heavyLowerBarbell;

  /// Training status, for the T-PRG-06 pace check. Omitted = no pace check.
  final Status? status;

  Map<String, dynamic> toJson() => {
    'exposures': [for (final x in exposures) x.toJson()],
    'increment': increment,
    'e1rm': ?e1rm,
    'heavyLowerBarbell': ?heavyLowerBarbell,
    if (status case final status?) 'status': status.wire,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  ExerciseHistory copyWith({
    List<Exposure>? exposures,
    double? increment,
    double? e1rm,
    bool? heavyLowerBarbell,
    Status? status,
  }) => ExerciseHistory(
    exposures: exposures ?? this.exposures,
    increment: increment ?? this.increment,
    e1rm: e1rm ?? this.e1rm,
    heavyLowerBarbell: heavyLowerBarbell ?? this.heavyLowerBarbell,
    status: status ?? this.status,
  );
}
