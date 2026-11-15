// SPDX-License-Identifier: GPL-3.0-only
// Weekly review and proposals.
import 'enums.dart';
import 'exercise.dart';
import 'history.dart';
import 'plan.dart';

class CheckinDay {
  CheckinDay({
    required this.day,
    required this.sleepHours,
    required this.energy,
    required this.stress,
    required this.soreness,
    required this.bodyweightKg,
  });

  factory CheckinDay.fromJson(Map<String, dynamic> json) => CheckinDay(
    day: json['day'] as String,
    sleepHours: json['sleepHours'] == null ? null : (json['sleepHours'] as num).toDouble(),
    energy: json['energy'] == null ? null : json['energy'] as int,
    stress: json['stress'] == null ? null : json['stress'] as int,
    soreness: {
      for (final e in (json['soreness'] as Map<String, dynamic>).entries)
        MuscleId.fromWire(e.key): SorenessLevel.fromWire(e.value as String),
    },
    bodyweightKg: json['bodyweightKg'] == null ? null : (json['bodyweightKg'] as num).toDouble(),
  );

  final String day;
  final double? sleepHours;
  final int? energy;
  final int? stress;
  final Map<MuscleId, SorenessLevel> soreness;
  final double? bodyweightKg;

  Map<String, dynamic> toJson() => {
    'day': day,
    'sleepHours': sleepHours,
    'energy': energy,
    'stress': stress,
    'soreness': {for (final e in soreness.entries) e.key.wire: e.value.wire},
    'bodyweightKg': bodyweightKg,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  CheckinDay copyWith({
    String? day,
    double? sleepHours,
    int? energy,
    int? stress,
    Map<MuscleId, SorenessLevel>? soreness,
    double? bodyweightKg,
  }) => CheckinDay(
    day: day ?? this.day,
    sleepHours: sleepHours ?? this.sleepHours,
    energy: energy ?? this.energy,
    stress: stress ?? this.stress,
    soreness: soreness ?? this.soreness,
    bodyweightKg: bodyweightKg ?? this.bodyweightKg,
  );
}

class ReviewAutofill {
  ReviewAutofill({required this.answers, required this.evidence});

  factory ReviewAutofill.fromJson(Map<String, dynamic> json) => ReviewAutofill(
    answers: {
      for (final e in (json['answers'] as Map<String, dynamic>).entries)
        ReviewKey.fromWire(e.key): e.value as bool,
    },
    evidence: {
      for (final e in (json['evidence'] as Map<String, dynamic>).entries)
        ReviewKey.fromWire(e.key): e.value as String,
    },
  );

  final Map<ReviewKey, bool> answers;
  final Map<ReviewKey, String> evidence;

  Map<String, dynamic> toJson() => {
    'answers': {for (final e in answers.entries) e.key.wire: e.value},
    'evidence': {for (final e in evidence.entries) e.key.wire: e.value},
  };
}

class Proposal implements RuleTagged {
  Proposal({
    required this.kind,
    required this.title,
    required this.rationale,
    required this.ruleIds,
    required this.payload,
    this.appliesFrom,
    this.expiresOn,
  });

  factory Proposal.fromJson(Map<String, dynamic> json) => Proposal(
    kind: ProposalKind.fromWire(json['kind'] as String),
    title: json['title'] as String,
    rationale: json['rationale'] as String,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
    payload: json['payload'] as Map<String, dynamic>,
    appliesFrom: json['appliesFrom'] == null ? null : json['appliesFrom'] as String,
    expiresOn: json['expiresOn'] == null ? null : json['expiresOn'] as String,
  );

  final ProposalKind kind;
  final String title;
  final String rationale;
  @override
  final List<String> ruleIds;
  final Map<String, dynamic> payload;
  final String? appliesFrom;
  final String? expiresOn;

  Map<String, dynamic> toJson() => {
    'kind': kind.wire,
    'title': title,
    'rationale': rationale,
    'ruleIds': [...ruleIds],
    'payload': payload,
    'appliesFrom': ?appliesFrom,
    'expiresOn': ?expiresOn,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  Proposal copyWith({
    ProposalKind? kind,
    String? title,
    String? rationale,
    List<String>? ruleIds,
    Map<String, dynamic>? payload,
    String? appliesFrom,
    String? expiresOn,
  }) => Proposal(
    kind: kind ?? this.kind,
    title: title ?? this.title,
    rationale: rationale ?? this.rationale,
    ruleIds: ruleIds ?? this.ruleIds,
    payload: payload ?? this.payload,
    appliesFrom: appliesFrom ?? this.appliesFrom,
    expiresOn: expiresOn ?? this.expiresOn,
  );
}

/// One entry of `PlannedSessionState.exercises` in the reference.
class PlannedExerciseState {
  PlannedExerciseState({
    required this.id,
    required this.exerciseId,
    required this.sets,
    required this.rirMin,
    required this.rirMax,
    this.repMin,
    this.repMax,
  });

  factory PlannedExerciseState.fromJson(Map<String, dynamic> json) => PlannedExerciseState(
    id: json['id'] as String,
    exerciseId: json['exerciseId'] as String,
    sets: json['sets'] as int,
    rirMin: (json['rirMin'] as num).toDouble(),
    rirMax: (json['rirMax'] as num).toDouble(),
    repMin: json['repMin'] == null ? null : json['repMin'] as int,
    repMax: json['repMax'] == null ? null : json['repMax'] as int,
  );

  final String id;
  final String exerciseId;
  final int sets;
  final double rirMin;
  final double rirMax;
  final int? repMin;
  final int? repMax;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'sets': sets,
    'rirMin': rirMin,
    'rirMax': rirMax,
    'repMin': ?repMin,
    'repMax': ?repMax,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  PlannedExerciseState copyWith({
    String? id,
    String? exerciseId,
    int? sets,
    double? rirMin,
    double? rirMax,
    int? repMin,
    int? repMax,
  }) => PlannedExerciseState(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    sets: sets ?? this.sets,
    rirMin: rirMin ?? this.rirMin,
    rirMax: rirMax ?? this.rirMax,
    repMin: repMin ?? this.repMin,
    repMax: repMax ?? this.repMax,
  );
}

class PlannedSessionState {
  PlannedSessionState({
    required this.id,
    required this.date,
    required this.status,
    required this.templateKey,
    this.kind,
    required this.exercises,
  });

  factory PlannedSessionState.fromJson(Map<String, dynamic> json) => PlannedSessionState(
    id: json['id'] as String,
    date: json['date'] as String,
    status: SessionStateStatus.fromWire(json['status'] as String),
    templateKey: json['templateKey'] as String,
    kind: json['kind'] == null ? null : SessionKind.fromWire(json['kind'] as String),
    exercises: [
      for (final x in json['exercises'] as List) PlannedExerciseState.fromJson(x as Map<String, dynamic>),
    ],
  );

  final String id;
  final String date;
  final SessionStateStatus status;
  final String templateKey;
  final SessionKind? kind;
  final List<PlannedExerciseState> exercises;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'status': status.wire,
    'templateKey': templateKey,
    if (kind case final kind?) 'kind': kind.wire,
    'exercises': [for (final x in exercises) x.toJson()],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  PlannedSessionState copyWith({
    String? id,
    String? date,
    SessionStateStatus? status,
    String? templateKey,
    SessionKind? kind,
    List<PlannedExerciseState>? exercises,
  }) => PlannedSessionState(
    id: id ?? this.id,
    date: date ?? this.date,
    status: status ?? this.status,
    templateKey: templateKey ?? this.templateKey,
    kind: kind ?? this.kind,
    exercises: exercises ?? this.exercises,
  );
}

/// `WeeklyState.block` in the reference.
class WeeklyStateBlock {
  WeeklyStateBlock({
    required this.id,
    required this.kind,
    required this.startsOn,
    required this.weeks,
    this.testDate,
  });

  factory WeeklyStateBlock.fromJson(Map<String, dynamic> json) => WeeklyStateBlock(
    id: json['id'] as String,
    kind: BlockKind.fromWire(json['kind'] as String),
    startsOn: json['startsOn'] as String,
    weeks: json['weeks'] as int,
    testDate: json['testDate'] == null ? null : json['testDate'] as String,
  );

  final String id;
  final BlockKind kind;
  final String startsOn;
  final int weeks;
  final String? testDate;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.wire,
    'startsOn': startsOn,
    'weeks': weeks,
    'testDate': ?testDate,
  };
}

class WeeklyState {
  WeeklyState({
    required this.today,
    required this.weekStart,
    required this.checkins,
    required this.sessionsThisWeek,
    required this.nextWeekSessions,
    required this.sets,
    required this.exercises,
    required this.mainLiftExerciseIds,
    this.overrides,
    this.block,
    required this.status,
    this.statusHistory,
    required this.goal,
    this.nutritionPhase,
    this.injuries,
    this.targets,
    this.specialization,
    this.previousYesCount,
    this.dislikedExerciseIds,
    this.equipment,
    this.availableDays,
  });

  factory WeeklyState.fromJson(Map<String, dynamic> json) => WeeklyState(
    today: json['today'] as String,
    weekStart: json['weekStart'] as String,
    checkins: [for (final x in json['checkins'] as List) CheckinDay.fromJson(x as Map<String, dynamic>)],
    sessionsThisWeek: [
      for (final x in json['sessionsThisWeek'] as List)
        PlannedSessionState.fromJson(x as Map<String, dynamic>),
    ],
    nextWeekSessions: [
      for (final x in json['nextWeekSessions'] as List)
        PlannedSessionState.fromJson(x as Map<String, dynamic>),
    ],
    sets: [for (final x in json['sets'] as List) LoggedSet.fromJson(x as Map<String, dynamic>)],
    exercises: [for (final x in json['exercises'] as List) ExerciseDef.fromJson(x as Map<String, dynamic>)],
    mainLiftExerciseIds: [for (final x in json['mainLiftExerciseIds'] as List) x as String],
    overrides: json['overrides'] == null
        ? null
        : {
            for (final e in (json['overrides'] as Map<String, dynamic>).entries)
              ReviewKey.fromWire(e.key): e.value as bool,
          },
    block: json['block'] == null ? null : WeeklyStateBlock.fromJson(json['block'] as Map<String, dynamic>),
    status: Status.fromWire(json['status'] as String),
    statusHistory: json['statusHistory'] == null
        ? null
        : [for (final x in json['statusHistory'] as List) Status.fromWire(x as String)],
    goal: Goal.fromWire(json['goal'] as String),
    nutritionPhase: json['nutritionPhase'] == null
        ? null
        : NutritionPhase.fromWire(json['nutritionPhase'] as String),
    injuries: json['injuries'] == null
        ? null
        : [for (final x in json['injuries'] as List) Injury.fromJson(x as Map<String, dynamic>)],
    targets: json['targets'] == null
        ? null
        : {
            for (final e in (json['targets'] as Map<String, dynamic>).entries)
              MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
          },
    specialization: json['specialization'] == null
        ? null
        : [for (final x in json['specialization'] as List) MuscleId.trackedFromWire(x as String)],
    previousYesCount: json['previousYesCount'] == null ? null : json['previousYesCount'] as int,
    dislikedExerciseIds: json['dislikedExerciseIds'] == null
        ? null
        : [for (final x in json['dislikedExerciseIds'] as List) x as String],
    equipment: json['equipment'] == null
        ? null
        : [for (final x in json['equipment'] as List) Equipment.fromWire(x as String)],
    availableDays: json['availableDays'] == null
        ? null
        : [for (final x in json['availableDays'] as List) x as int],
  );

  final String today;

  /// Monday of the reviewed week.
  final String weekStart;

  /// Last 28+ days.
  final List<CheckinDay> checkins;
  final List<PlannedSessionState> sessionsThisWeek;
  final List<PlannedSessionState> nextWeekSessions;

  /// Last 6 weeks.
  final List<LoggedSet> sets;
  final List<ExerciseDef> exercises;
  final List<String> mainLiftExerciseIds;
  final Map<ReviewKey, bool>? overrides;
  final WeeklyStateBlock? block;
  final Status status;

  /// Previous inferences (latest last).
  final List<Status>? statusHistory;
  final Goal goal;
  final NutritionPhase? nutritionPhase;

  /// Inputs for plan proposals (injury_adjust, volume_change, exercise_swap, plan_regenerate, intro_week). All optional.
  final List<Injury>? injuries;

  /// This week's weekly targets per tracked muscle.
  final Map<TrackedMuscle, double>? targets;
  final List<TrackedMuscle>? specialization;

  /// Yes-count of the review of the week before the reviewed one (null = none).
  final int? previousYesCount;
  final List<String>? dislikedExerciseIds;
  final List<Equipment>? equipment;
  final List<int>? availableDays;

  Map<String, dynamic> toJson() => {
    'today': today,
    'weekStart': weekStart,
    'checkins': [for (final x in checkins) x.toJson()],
    'sessionsThisWeek': [for (final x in sessionsThisWeek) x.toJson()],
    'nextWeekSessions': [for (final x in nextWeekSessions) x.toJson()],
    'sets': [for (final x in sets) x.toJson()],
    'exercises': [for (final x in exercises) x.toJson()],
    'mainLiftExerciseIds': [...mainLiftExerciseIds],
    if (overrides case final overrides?)
      'overrides': {for (final e in overrides.entries) e.key.wire: e.value},
    if (block case final block?) 'block': block.toJson(),
    'status': status.wire,
    if (statusHistory case final statusHistory?) 'statusHistory': [for (final x in statusHistory) x.wire],
    'goal': goal.wire,
    if (nutritionPhase case final nutritionPhase?) 'nutritionPhase': nutritionPhase.wire,
    if (injuries case final injuries?) 'injuries': [for (final x in injuries) x.toJson()],
    if (targets case final targets?) 'targets': {for (final e in targets.entries) e.key.wire: e.value},
    if (specialization case final specialization?) 'specialization': [for (final x in specialization) x.wire],
    'previousYesCount': ?previousYesCount,
    if (dislikedExerciseIds case final dislikedExerciseIds?) 'dislikedExerciseIds': [...dislikedExerciseIds],
    if (equipment case final equipment?) 'equipment': [for (final x in equipment) x.wire],
    if (availableDays case final availableDays?) 'availableDays': [...availableDays],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  WeeklyState copyWith({
    String? today,
    String? weekStart,
    List<CheckinDay>? checkins,
    List<PlannedSessionState>? sessionsThisWeek,
    List<PlannedSessionState>? nextWeekSessions,
    List<LoggedSet>? sets,
    List<ExerciseDef>? exercises,
    List<String>? mainLiftExerciseIds,
    Map<ReviewKey, bool>? overrides,
    WeeklyStateBlock? block,
    Status? status,
    List<Status>? statusHistory,
    Goal? goal,
    NutritionPhase? nutritionPhase,
    List<Injury>? injuries,
    Map<TrackedMuscle, double>? targets,
    List<TrackedMuscle>? specialization,
    int? previousYesCount,
    List<String>? dislikedExerciseIds,
    List<Equipment>? equipment,
    List<int>? availableDays,
  }) => WeeklyState(
    today: today ?? this.today,
    weekStart: weekStart ?? this.weekStart,
    checkins: checkins ?? this.checkins,
    sessionsThisWeek: sessionsThisWeek ?? this.sessionsThisWeek,
    nextWeekSessions: nextWeekSessions ?? this.nextWeekSessions,
    sets: sets ?? this.sets,
    exercises: exercises ?? this.exercises,
    mainLiftExerciseIds: mainLiftExerciseIds ?? this.mainLiftExerciseIds,
    overrides: overrides ?? this.overrides,
    block: block ?? this.block,
    status: status ?? this.status,
    statusHistory: statusHistory ?? this.statusHistory,
    goal: goal ?? this.goal,
    nutritionPhase: nutritionPhase ?? this.nutritionPhase,
    injuries: injuries ?? this.injuries,
    targets: targets ?? this.targets,
    specialization: specialization ?? this.specialization,
    previousYesCount: previousYesCount ?? this.previousYesCount,
    dislikedExerciseIds: dislikedExerciseIds ?? this.dislikedExerciseIds,
    equipment: equipment ?? this.equipment,
    availableDays: availableDays ?? this.availableDays,
  );
}

class StatusInference implements RuleTagged {
  StatusInference({required this.status, required this.share, required this.evidence, required this.ruleIds});

  factory StatusInference.fromJson(Map<String, dynamic> json) => StatusInference(
    status: json['status'] == null ? null : Status.fromWire(json['status'] as String),
    share: json['share'] == null ? null : (json['share'] as num).toDouble(),
    evidence: json['evidence'] as String,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final Status? status;
  final double? share;
  final String evidence;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'status': status?.wire,
    'share': share,
    'evidence': evidence,
    'ruleIds': [...ruleIds],
  };
}
