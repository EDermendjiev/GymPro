// SPDX-License-Identifier: GPL-3.0-only
// Plan generation: what goes in (BlockInput) and what comes out (BlockPlan), plus the per-set progression types.
import 'enums.dart';
import 'exercise.dart';
import 'history.dart';

abstract interface class RuleTagged {
  List<String> get ruleIds;
}

class UserSport {
  UserSport({
    required this.sportId,
    required this.name,
    required this.lowerBodyLoad,
    required this.upperBodyLoad,
    required this.eccentricImpact,
    required this.conditioning,
    required this.musclesStressed,
    required this.weekdays,
    required this.intensity,
    required this.minutes,
    this.timeOfDay,
  });

  factory UserSport.fromJson(Map<String, dynamic> json) => UserSport(
    sportId: json['sportId'] as String,
    name: json['name'] as String,
    lowerBodyLoad: json['lowerBodyLoad'] as int,
    upperBodyLoad: json['upperBodyLoad'] as int,
    eccentricImpact: json['eccentricImpact'] as int,
    conditioning: json['conditioning'] as int,
    musclesStressed: [for (final x in json['musclesStressed'] as List) MuscleId.fromWire(x as String)],
    weekdays: [for (final x in json['weekdays'] as List) x as int],
    intensity: SportIntensity.fromWire(json['intensity'] as String),
    minutes: json['minutes'] as int,
    timeOfDay: json['timeOfDay'] == null ? null : TimeOfDay.fromWire(json['timeOfDay'] as String),
  );

  final String sportId;
  final String name;

  /// 0..3
  final int lowerBodyLoad;
  final int upperBodyLoad;
  final int eccentricImpact;
  final int conditioning;
  final List<MuscleId> musclesStressed;

  /// ISO 1..7
  final List<int> weekdays;
  final SportIntensity intensity;
  final int minutes;
  final TimeOfDay? timeOfDay;

  Map<String, dynamic> toJson() => {
    'sportId': sportId,
    'name': name,
    'lowerBodyLoad': lowerBodyLoad,
    'upperBodyLoad': upperBodyLoad,
    'eccentricImpact': eccentricImpact,
    'conditioning': conditioning,
    'musclesStressed': [for (final x in musclesStressed) x.wire],
    'weekdays': [...weekdays],
    'intensity': intensity.wire,
    'minutes': minutes,
    if (timeOfDay case final timeOfDay?) 'timeOfDay': timeOfDay.wire,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  UserSport copyWith({
    String? sportId,
    String? name,
    int? lowerBodyLoad,
    int? upperBodyLoad,
    int? eccentricImpact,
    int? conditioning,
    List<MuscleId>? musclesStressed,
    List<int>? weekdays,
    SportIntensity? intensity,
    int? minutes,
    TimeOfDay? timeOfDay,
  }) => UserSport(
    sportId: sportId ?? this.sportId,
    name: name ?? this.name,
    lowerBodyLoad: lowerBodyLoad ?? this.lowerBodyLoad,
    upperBodyLoad: upperBodyLoad ?? this.upperBodyLoad,
    eccentricImpact: eccentricImpact ?? this.eccentricImpact,
    conditioning: conditioning ?? this.conditioning,
    musclesStressed: musclesStressed ?? this.musclesStressed,
    weekdays: weekdays ?? this.weekdays,
    intensity: intensity ?? this.intensity,
    minutes: minutes ?? this.minutes,
    timeOfDay: timeOfDay ?? this.timeOfDay,
  );
}

class Injury {
  Injury({
    required this.id,
    required this.muscleId,
    required this.label,
    required this.severity,
    required this.status,
    required this.avoidExerciseIds,
  });

  factory Injury.fromJson(Map<String, dynamic> json) => Injury(
    id: json['id'] as String,
    muscleId: json['muscleId'] == null ? null : MuscleId.fromWire(json['muscleId'] as String),
    label: json['label'] as String,
    severity: InjurySeverity.fromWire(json['severity'] as String),
    status: InjuryStatus.fromWire(json['status'] as String),
    avoidExerciseIds: [for (final x in json['avoidExerciseIds'] as List) x as String],
  );

  final String id;
  final MuscleId? muscleId;
  final String label;
  final InjurySeverity severity;
  final InjuryStatus status;
  final List<String> avoidExerciseIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'muscleId': muscleId?.wire,
    'label': label,
    'severity': severity.wire,
    'status': status.wire,
    'avoidExerciseIds': [...avoidExerciseIds],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  Injury copyWith({
    String? id,
    MuscleId? muscleId,
    String? label,
    InjurySeverity? severity,
    InjuryStatus? status,
    List<String>? avoidExerciseIds,
  }) => Injury(
    id: id ?? this.id,
    muscleId: muscleId ?? this.muscleId,
    label: label ?? this.label,
    severity: severity ?? this.severity,
    status: status ?? this.status,
    avoidExerciseIds: avoidExerciseIds ?? this.avoidExerciseIds,
  );
}

class BlockInput {
  BlockInput({
    required this.today,
    required this.goal,
    required this.priority,
    required this.status,
    required this.availableDays,
    required this.sessionMinutes,
    this.maxLiftDays,
    required this.equipment,
    required this.increments,
    required this.sports,
    required this.injuries,
    required this.exercises,
    required this.history,
    required this.repVariation,
    required this.specialization,
    this.testDate,
    this.splitStyle,
    this.blockKind,
    this.startsOn,
    this.dislikedExerciseIds,
    this.strengthLifts,
    this.targetAdjustments,
    this.fromHeavyPhase,
    this.liftingTime,
    this.materialiseFrom,
  });

  factory BlockInput.fromJson(Map<String, dynamic> json) => BlockInput(
    today: json['today'] as String,
    goal: Goal.fromWire(json['goal'] as String),
    priority: Priority.fromWire(json['priority'] as String),
    status: Status.fromWire(json['status'] as String),
    availableDays: [for (final x in json['availableDays'] as List) x as int],
    sessionMinutes: json['sessionMinutes'] as int,
    maxLiftDays: json['maxLiftDays'] == null ? null : json['maxLiftDays'] as int,
    equipment: [for (final x in json['equipment'] as List) Equipment.fromWire(x as String)],
    increments: {
      for (final e in (json['increments'] as Map<String, dynamic>).entries)
        e.key: (e.value as num).toDouble(),
    },
    sports: [for (final x in json['sports'] as List) UserSport.fromJson(x as Map<String, dynamic>)],
    injuries: [for (final x in json['injuries'] as List) Injury.fromJson(x as Map<String, dynamic>)],
    exercises: [for (final x in json['exercises'] as List) ExerciseDef.fromJson(x as Map<String, dynamic>)],
    history: History.fromJson(json['history'] as Map<String, dynamic>),
    repVariation: RepVariation.fromWire(json['repVariation'] as String),
    specialization: [for (final x in json['specialization'] as List) MuscleId.trackedFromWire(x as String)],
    testDate: json['testDate'] == null ? null : json['testDate'] as String,
    splitStyle: json['splitStyle'] == null ? null : SplitStyle.fromWire(json['splitStyle'] as String),
    blockKind: json['blockKind'] == null ? null : BlockKind.fromWire(json['blockKind'] as String),
    startsOn: json['startsOn'] == null ? null : json['startsOn'] as String,
    dislikedExerciseIds: json['dislikedExerciseIds'] == null
        ? null
        : [for (final x in json['dislikedExerciseIds'] as List) x as String],
    strengthLifts: json['strengthLifts'] == null
        ? null
        : [for (final x in json['strengthLifts'] as List) MainLift.fromWire(x as String)],
    targetAdjustments: json['targetAdjustments'] == null
        ? null
        : {
            for (final e in (json['targetAdjustments'] as Map<String, dynamic>).entries)
              MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
          },
    fromHeavyPhase: json['fromHeavyPhase'] == null ? null : json['fromHeavyPhase'] as bool,
    liftingTime: json['liftingTime'] == null ? null : TimeOfDay.fromWire(json['liftingTime'] as String),
    materialiseFrom: json['materialiseFrom'] == null ? null : json['materialiseFrom'] as String,
  );

  final String today;
  final Goal goal;
  final Priority priority;
  final Status status;
  final List<int> availableDays;
  final int sessionMinutes;
  final int? maxLiftDays;
  final List<Equipment> equipment;
  final Map<String, double> increments;
  final List<UserSport> sports;
  final List<Injury> injuries;
  final List<ExerciseDef> exercises;
  final History history;
  final RepVariation repVariation;
  final List<TrackedMuscle> specialization;
  final String? testDate;
  final SplitStyle? splitStyle;

  /// Forced kind (block transitions).
  final BlockKind? blockKind;

  /// Forced start (a Monday).
  final String? startsOn;
  final List<String>? dislikedExerciseIds;
  final List<MainLift>? strengthLifts;

  /// Extra sets per muscle from accepted volume_change / plateau proposals.
  final Map<TrackedMuscle, double>? targetAdjustments;

  /// True when the block follows a Load/Peak phase (T-FAT-06).
  final bool? fromHeavyPhase;

  /// Usual lifting time of day; null = unknown (a morning sport is then assumed to come first).
  final TimeOfDay? liftingTime;

  /// Earliest date to materialise sessions for (default `today`). Regeneration passes this Monday so carry-over can match
  /// moved sessions.
  final String? materialiseFrom;

  Map<String, dynamic> toJson() => {
    'today': today,
    'goal': goal.wire,
    'priority': priority.wire,
    'status': status.wire,
    'availableDays': [...availableDays],
    'sessionMinutes': sessionMinutes,
    'maxLiftDays': ?maxLiftDays,
    'equipment': [for (final x in equipment) x.wire],
    'increments': {for (final e in increments.entries) e.key: e.value},
    'sports': [for (final x in sports) x.toJson()],
    'injuries': [for (final x in injuries) x.toJson()],
    'exercises': [for (final x in exercises) x.toJson()],
    'history': history.toJson(),
    'repVariation': repVariation.wire,
    'specialization': [for (final x in specialization) x.wire],
    'testDate': ?testDate,
    if (splitStyle case final splitStyle?) 'splitStyle': splitStyle.wire,
    if (blockKind case final blockKind?) 'blockKind': blockKind.wire,
    'startsOn': ?startsOn,
    if (dislikedExerciseIds case final dislikedExerciseIds?) 'dislikedExerciseIds': [...dislikedExerciseIds],
    if (strengthLifts case final strengthLifts?) 'strengthLifts': [for (final x in strengthLifts) x.wire],
    if (targetAdjustments case final targetAdjustments?)
      'targetAdjustments': {for (final e in targetAdjustments.entries) e.key.wire: e.value},
    'fromHeavyPhase': ?fromHeavyPhase,
    if (liftingTime case final liftingTime?) 'liftingTime': liftingTime.wire,
    'materialiseFrom': ?materialiseFrom,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  BlockInput copyWith({
    String? today,
    Goal? goal,
    Priority? priority,
    Status? status,
    List<int>? availableDays,
    int? sessionMinutes,
    int? maxLiftDays,
    List<Equipment>? equipment,
    Map<String, double>? increments,
    List<UserSport>? sports,
    List<Injury>? injuries,
    List<ExerciseDef>? exercises,
    History? history,
    RepVariation? repVariation,
    List<TrackedMuscle>? specialization,
    String? testDate,
    SplitStyle? splitStyle,
    BlockKind? blockKind,
    String? startsOn,
    List<String>? dislikedExerciseIds,
    List<MainLift>? strengthLifts,
    Map<TrackedMuscle, double>? targetAdjustments,
    bool? fromHeavyPhase,
    TimeOfDay? liftingTime,
    String? materialiseFrom,
  }) => BlockInput(
    today: today ?? this.today,
    goal: goal ?? this.goal,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    availableDays: availableDays ?? this.availableDays,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    maxLiftDays: maxLiftDays ?? this.maxLiftDays,
    equipment: equipment ?? this.equipment,
    increments: increments ?? this.increments,
    sports: sports ?? this.sports,
    injuries: injuries ?? this.injuries,
    exercises: exercises ?? this.exercises,
    history: history ?? this.history,
    repVariation: repVariation ?? this.repVariation,
    specialization: specialization ?? this.specialization,
    testDate: testDate ?? this.testDate,
    splitStyle: splitStyle ?? this.splitStyle,
    blockKind: blockKind ?? this.blockKind,
    startsOn: startsOn ?? this.startsOn,
    dislikedExerciseIds: dislikedExerciseIds ?? this.dislikedExerciseIds,
    strengthLifts: strengthLifts ?? this.strengthLifts,
    targetAdjustments: targetAdjustments ?? this.targetAdjustments,
    fromHeavyPhase: fromHeavyPhase ?? this.fromHeavyPhase,
    liftingTime: liftingTime ?? this.liftingTime,
    materialiseFrom: materialiseFrom ?? this.materialiseFrom,
  );
}

/// One entry of `MuscleTarget.trimBySport` in the reference.
class TrimBySport {
  TrimBySport({required this.sport, required this.sets});

  factory TrimBySport.fromJson(Map<String, dynamic> json) =>
      TrimBySport(sport: json['sport'] as String, sets: (json['sets'] as num).toDouble());

  final String sport;
  final double sets;

  Map<String, dynamic> toJson() => {'sport': sport, 'sets': sets};
}

class MuscleTarget implements RuleTagged {
  MuscleTarget({
    required this.muscle,
    required this.base,
    required this.sportTrim,
    required this.target,
    required this.trimBySport,
    required this.ruleIds,
  });

  factory MuscleTarget.fromJson(Map<String, dynamic> json) => MuscleTarget(
    muscle: MuscleId.trackedFromWire(json['muscle'] as String),
    base: (json['base'] as num).toDouble(),
    sportTrim: (json['sportTrim'] as num).toDouble(),
    target: (json['target'] as num).toDouble(),
    trimBySport: [
      for (final x in json['trimBySport'] as List) TrimBySport.fromJson(x as Map<String, dynamic>),
    ],
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final TrackedMuscle muscle;
  final double base;
  final double sportTrim;
  final double target;
  final List<TrimBySport> trimBySport;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'muscle': muscle.wire,
    'base': base,
    'sportTrim': sportTrim,
    'target': target,
    'trimBySport': [for (final x in trimBySport) x.toJson()],
    'ruleIds': [...ruleIds],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  MuscleTarget copyWith({
    TrackedMuscle? muscle,
    double? base,
    double? sportTrim,
    double? target,
    List<TrimBySport>? trimBySport,
    List<String>? ruleIds,
  }) => MuscleTarget(
    muscle: muscle ?? this.muscle,
    base: base ?? this.base,
    sportTrim: sportTrim ?? this.sportTrim,
    target: target ?? this.target,
    trimBySport: trimBySport ?? this.trimBySport,
    ruleIds: ruleIds ?? this.ruleIds,
  );
}

class Prescription implements RuleTagged {
  Prescription({
    required this.sets,
    required this.repMin,
    required this.repMax,
    required this.rirMin,
    required this.rirMax,
    required this.restSeconds,
    this.isMainLiftSingle,
    this.note,
    this.suggestedLoadKg,
    required this.ruleIds,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
    sets: json['sets'] as int,
    repMin: json['repMin'] as int,
    repMax: json['repMax'] as int,
    rirMin: (json['rirMin'] as num).toDouble(),
    rirMax: (json['rirMax'] as num).toDouble(),
    restSeconds: json['restSeconds'] as int,
    isMainLiftSingle: json['isMainLiftSingle'] == null ? null : json['isMainLiftSingle'] as bool,
    note: json['note'] == null ? null : json['note'] as String,
    suggestedLoadKg: json['suggestedLoadKg'] == null ? null : (json['suggestedLoadKg'] as num).toDouble(),
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  int sets;
  int repMin;
  int repMax;
  double rirMin;
  double rirMax;
  int restSeconds;
  bool? isMainLiftSingle;
  String? note;
  double? suggestedLoadKg;
  @override
  List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'sets': sets,
    'repMin': repMin,
    'repMax': repMax,
    'rirMin': rirMin,
    'rirMax': rirMax,
    'restSeconds': restSeconds,
    'isMainLiftSingle': ?isMainLiftSingle,
    'note': ?note,
    'suggestedLoadKg': ?suggestedLoadKg,
    'ruleIds': [...ruleIds],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  Prescription copyWith({
    int? sets,
    int? repMin,
    int? repMax,
    double? rirMin,
    double? rirMax,
    int? restSeconds,
    bool? isMainLiftSingle,
    String? note,
    double? suggestedLoadKg,
    List<String>? ruleIds,
  }) => Prescription(
    sets: sets ?? this.sets,
    repMin: repMin ?? this.repMin,
    repMax: repMax ?? this.repMax,
    rirMin: rirMin ?? this.rirMin,
    rirMax: rirMax ?? this.rirMax,
    restSeconds: restSeconds ?? this.restSeconds,
    isMainLiftSingle: isMainLiftSingle ?? this.isMainLiftSingle,
    note: note ?? this.note,
    suggestedLoadKg: suggestedLoadKg ?? this.suggestedLoadKg,
    ruleIds: ruleIds ?? this.ruleIds,
  );
}

class PlannedExercise extends Prescription {
  PlannedExercise({
    required this.exerciseId,
    required this.slotKey,
    required this.position,
    this.originalExerciseId,
    required super.sets,
    required super.repMin,
    required super.repMax,
    required super.rirMin,
    required super.rirMax,
    required super.restSeconds,
    super.isMainLiftSingle,
    super.note,
    super.suggestedLoadKg,
    required super.ruleIds,
  });

  factory PlannedExercise.fromJson(Map<String, dynamic> json) => PlannedExercise(
    exerciseId: json['exerciseId'] as String,
    slotKey: json['slotKey'] as String,
    position: json['position'] as int,
    originalExerciseId: json['originalExerciseId'] == null ? null : json['originalExerciseId'] as String,
    sets: json['sets'] as int,
    repMin: json['repMin'] as int,
    repMax: json['repMax'] as int,
    rirMin: (json['rirMin'] as num).toDouble(),
    rirMax: (json['rirMax'] as num).toDouble(),
    restSeconds: json['restSeconds'] as int,
    isMainLiftSingle: json['isMainLiftSingle'] == null ? null : json['isMainLiftSingle'] as bool,
    note: json['note'] == null ? null : json['note'] as String,
    suggestedLoadKg: json['suggestedLoadKg'] == null ? null : (json['suggestedLoadKg'] as num).toDouble(),
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  String exerciseId;
  String slotKey;
  int position;

  /// The engine's own choice when the user swapped this exercise for this session only (carry-over).
  String? originalExerciseId;

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    'exerciseId': exerciseId,
    'slotKey': slotKey,
    'position': position,
    'originalExerciseId': ?originalExerciseId,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  @override
  PlannedExercise copyWith({
    String? exerciseId,
    String? slotKey,
    int? position,
    String? originalExerciseId,
    int? sets,
    int? repMin,
    int? repMax,
    double? rirMin,
    double? rirMax,
    int? restSeconds,
    bool? isMainLiftSingle,
    String? note,
    double? suggestedLoadKg,
    List<String>? ruleIds,
  }) => PlannedExercise(
    exerciseId: exerciseId ?? this.exerciseId,
    slotKey: slotKey ?? this.slotKey,
    position: position ?? this.position,
    originalExerciseId: originalExerciseId ?? this.originalExerciseId,
    sets: sets ?? this.sets,
    repMin: repMin ?? this.repMin,
    repMax: repMax ?? this.repMax,
    rirMin: rirMin ?? this.rirMin,
    rirMax: rirMax ?? this.rirMax,
    restSeconds: restSeconds ?? this.restSeconds,
    isMainLiftSingle: isMainLiftSingle ?? this.isMainLiftSingle,
    note: note ?? this.note,
    suggestedLoadKg: suggestedLoadKg ?? this.suggestedLoadKg,
    ruleIds: ruleIds ?? this.ruleIds,
  );
}

class PlannedSession {
  PlannedSession({
    required this.date,
    required this.weekIndex,
    required this.templateKey,
    required this.title,
    required this.kind,
    required this.orderInWeek,
    required this.estMinutes,
    required this.exercises,
    this.planKey,
    this.plannedOn,
    this.status,
  });

  factory PlannedSession.fromJson(Map<String, dynamic> json) => PlannedSession(
    date: json['date'] as String,
    weekIndex: json['weekIndex'] as int,
    templateKey: json['templateKey'] as String,
    title: json['title'] as String,
    kind: SessionKind.fromWire(json['kind'] as String),
    orderInWeek: json['orderInWeek'] as int,
    estMinutes: json['estMinutes'] as int,
    exercises: [
      for (final x in json['exercises'] as List) PlannedExercise.fromJson(x as Map<String, dynamic>),
    ],
    planKey: json['planKey'] == null ? null : json['planKey'] as String,
    plannedOn: json['plannedOn'] == null ? null : json['plannedOn'] as String,
    status: json['status'] == null ? null : PlannedSessionStatus.fromWire(json['status'] as String),
  );

  String date;
  int weekIndex;
  String templateKey;
  String title;
  SessionKind kind;
  int orderInWeek;
  int estMinutes;
  List<PlannedExercise> exercises;

  /// Stable identity across regenerations: week Monday | template | occurrence in that week.
  String? planKey;

  /// The engine's date when the user moved the session (carry-over); `date` is then the user's date.
  String? plannedOn;

  /// 'skipped' when the user skipped this session before a regeneration (carry-over). Default 'planned'.
  PlannedSessionStatus? status;

  Map<String, dynamic> toJson() => {
    'date': date,
    'weekIndex': weekIndex,
    'templateKey': templateKey,
    'title': title,
    'kind': kind.wire,
    'orderInWeek': orderInWeek,
    'estMinutes': estMinutes,
    'exercises': [for (final x in exercises) x.toJson()],
    'planKey': ?planKey,
    'plannedOn': ?plannedOn,
    if (status case final status?) 'status': status.wire,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  PlannedSession copyWith({
    String? date,
    int? weekIndex,
    String? templateKey,
    String? title,
    SessionKind? kind,
    int? orderInWeek,
    int? estMinutes,
    List<PlannedExercise>? exercises,
    String? planKey,
    String? plannedOn,
    PlannedSessionStatus? status,
  }) => PlannedSession(
    date: date ?? this.date,
    weekIndex: weekIndex ?? this.weekIndex,
    templateKey: templateKey ?? this.templateKey,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    orderInWeek: orderInWeek ?? this.orderInWeek,
    estMinutes: estMinutes ?? this.estMinutes,
    exercises: exercises ?? this.exercises,
    planKey: planKey ?? this.planKey,
    plannedOn: plannedOn ?? this.plannedOn,
    status: status ?? this.status,
  );
}

class Warning implements RuleTagged {
  Warning({required this.code, required this.message, required this.ruleIds});

  factory Warning.fromJson(Map<String, dynamic> json) => Warning(
    code: WarningCode.fromWire(json['code'] as String),
    message: json['message'] as String,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final WarningCode code;
  final String message;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'code': code.wire,
    'message': message,
    'ruleIds': [...ruleIds],
  };
}

class DayPlacement {
  DayPlacement({required this.weekday, required this.templateKey});

  factory DayPlacement.fromJson(Map<String, dynamic> json) =>
      DayPlacement(weekday: json['weekday'] as int, templateKey: json['templateKey'] as String);

  /// ISO 1..7
  final int weekday;
  final String templateKey;

  Map<String, dynamic> toJson() => {'weekday': weekday, 'templateKey': templateKey};
}

/// One entry of `ScheduleResult.penalties` in the reference.
class SchedulePenalty {
  SchedulePenalty({required this.rule, required this.points, required this.detail});

  factory SchedulePenalty.fromJson(Map<String, dynamic> json) => SchedulePenalty(
    rule: json['rule'] as String,
    points: (json['points'] as num).toDouble(),
    detail: json['detail'] as String,
  );

  final String rule;
  final double points;
  final String detail;

  Map<String, dynamic> toJson() => {'rule': rule, 'points': points, 'detail': detail};
}

class ScheduleResult {
  ScheduleResult({required this.placements, required this.score, required this.penalties});

  factory ScheduleResult.fromJson(Map<String, dynamic> json) => ScheduleResult(
    placements: [
      for (final x in json['placements'] as List) DayPlacement.fromJson(x as Map<String, dynamic>),
    ],
    score: (json['score'] as num).toDouble(),
    penalties: [
      for (final x in json['penalties'] as List) SchedulePenalty.fromJson(x as Map<String, dynamic>),
    ],
  );

  final List<DayPlacement> placements;
  final double score;
  final List<SchedulePenalty> penalties;

  Map<String, dynamic> toJson() => {
    'placements': [for (final x in placements) x.toJson()],
    'score': score,
    'penalties': [for (final x in penalties) x.toJson()],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  ScheduleResult copyWith({
    List<DayPlacement>? placements,
    double? score,
    List<SchedulePenalty>? penalties,
  }) => ScheduleResult(
    placements: placements ?? this.placements,
    score: score ?? this.score,
    penalties: penalties ?? this.penalties,
  );
}

/// One entry of `BlockPlan.weeklyTargets` in the reference.
class WeeklyTarget {
  WeeklyTarget({
    required this.weekIndex,
    required this.muscle,
    required this.targetSets,
    required this.sportTrim,
  });

  factory WeeklyTarget.fromJson(Map<String, dynamic> json) => WeeklyTarget(
    weekIndex: json['weekIndex'] as int,
    muscle: MuscleId.trackedFromWire(json['muscle'] as String),
    targetSets: (json['targetSets'] as num).toDouble(),
    sportTrim: (json['sportTrim'] as num).toDouble(),
  );

  final int weekIndex;
  final TrackedMuscle muscle;
  final double targetSets;
  final double sportTrim;

  Map<String, dynamic> toJson() => {
    'weekIndex': weekIndex,
    'muscle': muscle.wire,
    'targetSets': targetSets,
    'sportTrim': sportTrim,
  };
}

/// One entry of `BlockPlan.explanations` in the reference.
class Explanation implements RuleTagged {
  Explanation({required this.text, required this.ruleIds});

  factory Explanation.fromJson(Map<String, dynamic> json) => Explanation(
    text: json['text'] as String,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final String text;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'text': text,
    'ruleIds': [...ruleIds],
  };
}

class BlockPlan {
  BlockPlan({
    required this.kind,
    required this.startsOn,
    required this.weeks,
    required this.introWeek,
    required this.splitKey,
    required this.liftDays,
    required this.engineVersion,
    required this.schedule,
    required this.targets,
    required this.weeklyTargets,
    required this.sessions,
    required this.selections,
    required this.warnings,
    required this.explanations,
    required this.hardSessionsPerWeek,
  });

  factory BlockPlan.fromJson(Map<String, dynamic> json) => BlockPlan(
    kind: BlockKind.fromWire(json['kind'] as String),
    startsOn: json['startsOn'] as String,
    weeks: json['weeks'] as int,
    introWeek: json['introWeek'] as bool,
    splitKey: json['splitKey'] as String,
    liftDays: json['liftDays'] as int,
    engineVersion: json['engineVersion'] as String,
    schedule: ScheduleResult.fromJson(json['schedule'] as Map<String, dynamic>),
    targets: [for (final x in json['targets'] as List) MuscleTarget.fromJson(x as Map<String, dynamic>)],
    weeklyTargets: [
      for (final x in json['weeklyTargets'] as List) WeeklyTarget.fromJson(x as Map<String, dynamic>),
    ],
    sessions: [for (final x in json['sessions'] as List) PlannedSession.fromJson(x as Map<String, dynamic>)],
    selections: {
      for (final e in (json['selections'] as Map<String, dynamic>).entries)
        e.key: {for (final f in (e.value as Map<String, dynamic>).entries) f.key: f.value as String},
    },
    warnings: [for (final x in json['warnings'] as List) Warning.fromJson(x as Map<String, dynamic>)],
    explanations: [
      for (final x in json['explanations'] as List) Explanation.fromJson(x as Map<String, dynamic>),
    ],
    hardSessionsPerWeek: json['hardSessionsPerWeek'] as int,
  );

  final BlockKind kind;
  final String startsOn;
  final int weeks;
  final bool introWeek;
  final String splitKey;
  final int liftDays;
  final String engineVersion;
  final ScheduleResult schedule;
  final List<MuscleTarget> targets;

  /// Weekly targets per week index (the strength load phase reduces over time).
  final List<WeeklyTarget> weeklyTargets;
  final List<PlannedSession> sessions;
  final Map<String, Map<String, String>> selections;
  final List<Warning> warnings;
  final List<Explanation> explanations;
  final int hardSessionsPerWeek;

  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'startsOn': startsOn,
    'weeks': weeks,
    'introWeek': introWeek,
    'splitKey': splitKey,
    'liftDays': liftDays,
    'engineVersion': engineVersion,
    'schedule': schedule.toJson(),
    'targets': [for (final x in targets) x.toJson()],
    'weeklyTargets': [for (final x in weeklyTargets) x.toJson()],
    'sessions': [for (final x in sessions) x.toJson()],
    'selections': {
      for (final e in selections.entries) e.key: {for (final f in e.value.entries) f.key: f.value},
    },
    'warnings': [for (final x in warnings) x.toJson()],
    'explanations': [for (final x in explanations) x.toJson()],
    'hardSessionsPerWeek': hardSessionsPerWeek,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  BlockPlan copyWith({
    BlockKind? kind,
    String? startsOn,
    int? weeks,
    bool? introWeek,
    String? splitKey,
    int? liftDays,
    String? engineVersion,
    ScheduleResult? schedule,
    List<MuscleTarget>? targets,
    List<WeeklyTarget>? weeklyTargets,
    List<PlannedSession>? sessions,
    Map<String, Map<String, String>>? selections,
    List<Warning>? warnings,
    List<Explanation>? explanations,
    int? hardSessionsPerWeek,
  }) => BlockPlan(
    kind: kind ?? this.kind,
    startsOn: startsOn ?? this.startsOn,
    weeks: weeks ?? this.weeks,
    introWeek: introWeek ?? this.introWeek,
    splitKey: splitKey ?? this.splitKey,
    liftDays: liftDays ?? this.liftDays,
    engineVersion: engineVersion ?? this.engineVersion,
    schedule: schedule ?? this.schedule,
    targets: targets ?? this.targets,
    weeklyTargets: weeklyTargets ?? this.weeklyTargets,
    sessions: sessions ?? this.sessions,
    selections: selections ?? this.selections,
    warnings: warnings ?? this.warnings,
    explanations: explanations ?? this.explanations,
    hardSessionsPerWeek: hardSessionsPerWeek ?? this.hardSessionsPerWeek,
  );
}

// ---------- Progression ----------

/// `SetContext.rx` in the reference: the rep and RIR range of the prescription.
class SetRx {
  SetRx({required this.repMin, required this.repMax, required this.rirMin, required this.rirMax});

  factory SetRx.fromJson(Map<String, dynamic> json) => SetRx(
    repMin: json['repMin'] as int,
    repMax: json['repMax'] as int,
    rirMin: (json['rirMin'] as num).toDouble(),
    rirMax: (json['rirMax'] as num).toDouble(),
  );

  final int repMin;
  final int repMax;
  final double rirMin;
  final double rirMax;

  Map<String, dynamic> toJson() => {'repMin': repMin, 'repMax': repMax, 'rirMin': rirMin, 'rirMax': rirMax};
}

class SetContext {
  SetContext({
    required this.rx,
    required this.setIndex,
    required this.load,
    required this.reps,
    required this.increment,
    this.previousReps,
  });

  factory SetContext.fromJson(Map<String, dynamic> json) => SetContext(
    rx: SetRx.fromJson(json['rx'] as Map<String, dynamic>),
    setIndex: json['setIndex'] as int,
    load: json['load'] == null ? null : (json['load'] as num).toDouble(),
    reps: json['reps'] as int,
    increment: (json['increment'] as num).toDouble(),
    previousReps: json['previousReps'] == null ? null : json['previousReps'] as int,
  );

  final SetRx rx;

  /// Index of the set just logged.
  final int setIndex;
  final double? load;
  final int reps;
  final double increment;
  final int? previousReps;

  Map<String, dynamic> toJson() => {
    'rx': rx.toJson(),
    'setIndex': setIndex,
    'load': load,
    'reps': reps,
    'increment': increment,
    'previousReps': ?previousReps,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  SetContext copyWith({
    SetRx? rx,
    int? setIndex,
    double? load,
    int? reps,
    double? increment,
    int? previousReps,
  }) => SetContext(
    rx: rx ?? this.rx,
    setIndex: setIndex ?? this.setIndex,
    load: load ?? this.load,
    reps: reps ?? this.reps,
    increment: increment ?? this.increment,
    previousReps: previousReps ?? this.previousReps,
  );
}

class SetSuggestion implements RuleTagged {
  SetSuggestion({required this.load, required this.repsTarget, required this.ruleIds});

  factory SetSuggestion.fromJson(Map<String, dynamic> json) => SetSuggestion(
    load: json['load'] == null ? null : (json['load'] as num).toDouble(),
    repsTarget: json['repsTarget'] as int,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final double? load;
  final int repsTarget;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'load': load,
    'repsTarget': repsTarget,
    'ruleIds': [...ruleIds],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  SetSuggestion copyWith({double? load, int? repsTarget, List<String>? ruleIds}) => SetSuggestion(
    load: load ?? this.load,
    repsTarget: repsTarget ?? this.repsTarget,
    ruleIds: ruleIds ?? this.ruleIds,
  );
}

class SessionSuggestion implements RuleTagged {
  SessionSuggestion({required this.load, required this.repsTarget, this.hint, required this.ruleIds});

  factory SessionSuggestion.fromJson(Map<String, dynamic> json) => SessionSuggestion(
    load: json['load'] == null ? null : (json['load'] as num).toDouble(),
    repsTarget: json['repsTarget'] as int,
    hint: json['hint'] == null ? null : json['hint'] as String,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final double? load;
  final int repsTarget;
  final String? hint;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'load': load,
    'repsTarget': repsTarget,
    'hint': ?hint,
    'ruleIds': [...ruleIds],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  SessionSuggestion copyWith({double? load, int? repsTarget, String? hint, List<String>? ruleIds}) =>
      SessionSuggestion(
        load: load ?? this.load,
        repsTarget: repsTarget ?? this.repsTarget,
        hint: hint ?? this.hint,
        ruleIds: ruleIds ?? this.ruleIds,
      );
}
