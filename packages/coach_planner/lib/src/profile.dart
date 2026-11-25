// SPDX-License-Identifier: GPL-3.0-only
// Everything the planner knows about the user, from the onboarding answers, the app's profile and the logs.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';

/// The training style the user asked for. [auto] leaves the choice to the planner.
enum StylePref {
  auto('auto'),
  fullBody('full_body'),
  upperLower('upper_lower'),
  pushPullLegs('push_pull_legs'),
  bodyPart('body_part');

  const StylePref(this.wire);

  final String wire;

  static final Map<String, StylePref> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static StylePref fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown StylePref: "$wire"'));
}

/// Fewer, longer sessions or more, shorter ones. [auto] trains on every day the user picked.
enum SessionPref {
  auto('auto'),
  fewerLonger('fewer_longer'),
  moreShorter('more_shorter');

  const SessionPref(this.wire);

  final String wire;

  static final Map<String, SessionPref> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static SessionPref fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown SessionPref: "$wire"'));
}

/// Years of consistent training, as the onboarding chips ask it.
enum YearsTraining {
  underOne('under_one', 0.5),
  oneToThree('one_to_three', 2),
  threeToFive('three_to_five', 4),
  fivePlus('five_plus', 6);

  const YearsTraining(this.wire, this.years);

  final String wire;

  /// A representative number of years for the band.
  final double years;

  static final Map<String, YearsTraining> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static YearsTraining fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown YearsTraining: "$wire"'));
}

/// Where the training status came from.
enum StatusSource {
  logs('logs'),
  answer('answer'),
  years('years'),
  fallback('fallback');

  const StatusSource(this.wire);

  final String wire;

  static final Map<String, StatusSource> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static StatusSource fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown StatusSource: "$wire"'));
}

/// The training status the planner uses, and why.
class ResolvedStatus implements RuleTagged {
  ResolvedStatus({required this.status, required this.source, required this.note, required this.ruleIds});

  factory ResolvedStatus.fromJson(Map<String, dynamic> json) => ResolvedStatus(
    status: Status.fromWire(json['status'] as String),
    source: StatusSource.fromWire(json['source'] as String),
    note: json['note'] as String,
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final Status status;
  final StatusSource source;
  final String note;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'status': status.wire,
    'source': source.wire,
    'note': note,
    'ruleIds': [...ruleIds],
  };
}

/// Fewest years of consistent training before a self-reported "advanced" is taken at its word (heuristic).
const int ADVANCED_MIN_YEARS = 3;

/// The status the planner works with.
///
/// The logs win when they show a status: the rate of progress is what defines it. Otherwise the user's answer
/// counts, except that "advanced" with fewer than [ADVANCED_MIN_YEARS] years of training is read as intermediate.
/// Without an answer the years decide (under one year: novice, otherwise intermediate), and with nothing at all
/// the user is treated as a novice.
ResolvedStatus resolveStatus({Status? fromLogs, Status? answered, YearsTraining? years}) {
  if (fromLogs != null) {
    return ResolvedStatus(
      status: fromLogs,
      source: StatusSource.logs,
      note: 'Your logs show how fast you progress, so they set your level: ${fromLogs.wire}.',
      ruleIds: ['T-STA-01', 'T-STA-03'],
    );
  }
  if (answered != null) {
    if (answered == Status.advanced && years != null && years.years < ADVANCED_MIN_YEARS) {
      return ResolvedStatus(
        status: Status.intermediate,
        source: StatusSource.answer,
        note: 'Planned as intermediate: advanced usually takes several years of steady training.',
        ruleIds: ['T-STA-01'],
      );
    }
    return ResolvedStatus(
      status: answered,
      source: StatusSource.answer,
      note: 'Planned for the level you picked: ${answered.wire}.',
      ruleIds: ['T-STA-02'],
    );
  }
  if (years != null) {
    final s = statusFromYears(years.years);
    return ResolvedStatus(
      status: s,
      source: StatusSource.years,
      note: 'Planned as ${s.wire} from your years of training.',
      ruleIds: ['T-STA-02'],
    );
  }
  return ResolvedStatus(
    status: Status.novice,
    source: StatusSource.fallback,
    note: 'No level given yet, so the plan starts as for a novice.',
    ruleIds: ['T-STA-02'],
  );
}

List<T> _list<T>(Object? json, T Function(Object? x) f) =>
    json == null ? <T>[] : [for (final x in json as List) f(x)];

/// Everything the planner reads.
class PlannerProfile {
  PlannerProfile({
    required this.goal,
    this.priority = Priority.lifting,
    this.answeredStatus,
    this.logStatus,
    this.years,
    this.age,
    this.sex = Sex.unspecified,
    this.bodyweightKg,
    this.heightCm,
    this.lifestyle = Lifestyle.lightlyActive,
    required List<int> days,
    required this.minutes,
    this.style = StylePref.auto,
    this.sessionPref = SessionPref.auto,
    List<TrackedMuscle> focus = const [],
    List<Equipment> equipment = const [],
    Set<SlotTag>? availableTags,
    List<Injury> injuries = const [],
    List<UserSport> sports = const [],
    this.strengthLifts,
    Map<String, double> knownLifts = const {},
    Map<TrackedMuscle, double>? targetAdjustments,
    this.previousMedianTarget,
    this.previousSplitKey,
    List<int> recoveryChecks = const [],
  }) : recoveryChecks = List.unmodifiable(recoveryChecks),
       days = List.unmodifiable(
         {
           for (final d in days)
             if (d >= 1 && d <= 7) d,
         }.toList()..sort(),
       ),
       focus = List.unmodifiable(focus.toSet().take(2)),
       equipment = List.unmodifiable(equipment),
       availableTags = availableTags == null ? null : Set.unmodifiable(availableTags),
       injuries = List.unmodifiable(injuries),
       sports = List.unmodifiable(sports),
       knownLifts = Map.unmodifiable(knownLifts),
       targetAdjustments = targetAdjustments == null ? null : Map.unmodifiable(targetAdjustments);

  factory PlannerProfile.fromJson(Map<String, dynamic> json) => PlannerProfile(
    goal: Goal.fromWire(json['goal'] as String),
    priority: json['priority'] == null ? Priority.lifting : Priority.fromWire(json['priority'] as String),
    answeredStatus: json['answeredStatus'] == null ? null : Status.fromWire(json['answeredStatus'] as String),
    logStatus: json['logStatus'] == null ? null : Status.fromWire(json['logStatus'] as String),
    years: json['years'] == null ? null : YearsTraining.fromWire(json['years'] as String),
    age: json['age'] as int?,
    sex: json['sex'] == null ? Sex.unspecified : Sex.fromWire(json['sex'] as String),
    bodyweightKg: (json['bodyweightKg'] as num?)?.toDouble(),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    lifestyle: json['lifestyle'] == null
        ? Lifestyle.lightlyActive
        : Lifestyle.fromWire(json['lifestyle'] as String),
    days: _list(json['days'], (x) => x as int),
    minutes: json['minutes'] as int,
    style: json['style'] == null ? StylePref.auto : StylePref.fromWire(json['style'] as String),
    sessionPref: json['sessionPref'] == null
        ? SessionPref.auto
        : SessionPref.fromWire(json['sessionPref'] as String),
    focus: _list(json['focus'], (x) => MuscleId.trackedFromWire(x as String)),
    equipment: _list(json['equipment'], (x) => Equipment.fromWire(x as String)),
    availableTags: json['availableTags'] == null
        ? null
        : {for (final x in json['availableTags'] as List) SlotTag.fromWire(x as String)},
    injuries: _list(json['injuries'], (x) => Injury.fromJson(x as Map<String, dynamic>)),
    sports: _list(json['sports'], (x) => UserSport.fromJson(x as Map<String, dynamic>)),
    strengthLifts: json['strengthLifts'] == null
        ? null
        : [for (final x in json['strengthLifts'] as List) MainLift.fromWire(x as String)],
    knownLifts: {
      for (final e in ((json['knownLifts'] as Map<String, dynamic>?) ?? const {}).entries)
        e.key: (e.value as num).toDouble(),
    },
    targetAdjustments: json['targetAdjustments'] == null
        ? null
        : {
            for (final e in (json['targetAdjustments'] as Map<String, dynamic>).entries)
              MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
          },
    previousMedianTarget: (json['previousMedianTarget'] as num?)?.toDouble(),
    previousSplitKey: json['previousSplitKey'] as String?,
    recoveryChecks: _list(json['recoveryChecks'], (x) => x as int),
  );

  final Goal goal;
  final Priority priority;

  /// The level the user picked, or null when they didn't.
  final Status? answeredStatus;

  /// The level the logs show (eight weeks or more of them), or null.
  final Status? logStatus;
  final YearsTraining? years;

  /// Years of age, or null when unknown.
  final int? age;
  final Sex sex;
  final double? bodyweightKg;
  final double? heightCm;
  final Lifestyle lifestyle;

  /// Weekdays the user can train (1 = Monday … 7 = Sunday), sorted, without repeats.
  final List<int> days;

  /// Minutes per session.
  final int minutes;
  final StylePref style;
  final SessionPref sessionPref;

  /// Up to two muscles the user wants to bring up.
  final List<TrackedMuscle> focus;

  /// The equipment at the user's place.
  final List<Equipment> equipment;

  /// The slot tags the user's exercises and equipment can fill, or null when every tag can be filled.
  final Set<SlotTag>? availableTags;
  final List<Injury> injuries;
  final List<UserSport> sports;

  /// The main lifts a strength plan trains, or null for squat, bench and deadlift.
  final List<MainLift>? strengthLifts;

  /// Estimated one-rep maxes the user entered, by main-lift key.
  final Map<String, double> knownLifts;

  /// Extra weekly sets per muscle from accepted proposals, or null.
  final Map<TrackedMuscle, double>? targetAdjustments;

  /// The previous block's median target before sport trims, or null for a first block.
  final double? previousMedianTarget;

  /// The split of the current block, or null; a rebuild prefers to keep it.
  final String? previousSplitKey;

  /// The "yes" counts of the weekly recovery checks during the previous block, oldest first; empty when unknown.
  final List<int> recoveryChecks;

  /// The training status the planner works with.
  ResolvedStatus get status => resolveStatus(fromLogs: logStatus, answered: answeredStatus, years: years);

  /// Body-mass index, or null when weight or height is unknown.
  double? get bmi {
    final w = bodyweightKg;
    final h = heightCm;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  /// Whether the user's sport comes before lifting.
  bool get sportPriority => goal == Goal.sportSupport || priority == Priority.sport;

  Map<String, dynamic> toJson() => {
    'goal': goal.wire,
    'priority': priority.wire,
    if (answeredStatus case final s?) 'answeredStatus': s.wire,
    if (logStatus case final s?) 'logStatus': s.wire,
    if (years case final y?) 'years': y.wire,
    'age': ?age,
    'sex': sex.wire,
    'bodyweightKg': ?bodyweightKg,
    'heightCm': ?heightCm,
    'lifestyle': lifestyle.wire,
    'days': [...days],
    'minutes': minutes,
    'style': style.wire,
    'sessionPref': sessionPref.wire,
    'focus': [for (final m in focus) m.wire],
    'equipment': [for (final e in equipment) e.wire],
    if (availableTags case final tags?)
      'availableTags': [
        for (final t in SlotTag.values)
          if (tags.contains(t)) t.wire,
      ],
    'injuries': [for (final i in injuries) i.toJson()],
    'sports': [for (final s in sports) s.toJson()],
    if (strengthLifts case final l?) 'strengthLifts': [for (final x in l) x.wire],
    'knownLifts': {...knownLifts},
    if (targetAdjustments case final t?)
      'targetAdjustments': {for (final e in t.entries) e.key.wire: e.value},
    'previousMedianTarget': ?previousMedianTarget,
    'previousSplitKey': ?previousSplitKey,
    if (recoveryChecks.isNotEmpty) 'recoveryChecks': [...recoveryChecks],
  };
}
