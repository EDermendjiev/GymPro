// SPDX-License-Identifier: GPL-3.0-only
// The user's coaching profile, as stored under `coach.profile`.
import 'package:coach_kernel/coach_kernel.dart' as ck;

import '../adapters/nutrition_adapter.dart';
import 'coach_choices.dart';
import 'coach_recovery.dart';
import 'json_util.dart';

/// Goal, training status, training days, session length, priority and lifestyle, and the answers that shape a
/// designed plan (style, session preference, years of training, focus muscles, strength lifts and known maxes).
///
/// Keys this version does not know are kept in [extra] and written back unchanged, so a profile written by a
/// newer version of the app survives a round trip through an older one.
final class CoachProfile {
  CoachProfile({
    required this.goal,
    required this.status,
    required List<int> days,
    required this.minutes,
    required this.priority,
    required this.lifestyle,
    this.maxLiftDays,
    this.smartPlan = false,
    this.style = CoachStyle.auto,
    this.sessionPref = CoachSessionPref.auto,
    this.years,
    List<CoachArea> focus = const [],
    List<CoachLift>? strengthLifts,
    Map<CoachLift, double> knownLifts = const {},
    this.splitKey,
    Map<String, dynamic> extra = const {},
  })  : days = List.unmodifiable(days),
        focus = List.unmodifiable(focus.toSet().take(2)),
        strengthLifts = strengthLifts == null ? null : List.unmodifiable(strengthLifts),
        knownLifts = Map.unmodifiable(knownLifts),
        extra = Map.unmodifiable(extra);

  /// Throws a [FormatException] when [json] is not a profile. [CoachData] catches it, so a bad profile never stops
  /// a backup from loading.
  factory CoachProfile.fromJson(Map<String, dynamic> json) {
    T need<T>(String key) {
      final v = json[key];
      if (v is T) return v;
      throw FormatException('coach profile: "$key" is ${v.runtimeType}');
    }

    final days = need<List<dynamic>>('days');
    final maxLiftDays = json['maxLiftDays'];
    if (maxLiftDays != null && maxLiftDays is! int) throw const FormatException('coach profile: maxLiftDays');
    return CoachProfile(
      goal: ck.Goal.fromWire(need<String>('goal')),
      status: ck.Status.fromWire(need<String>('status')),
      days: [
        for (final d in days)
          if (d is int) d else throw const FormatException('coach profile: days'),
      ],
      minutes: need<int>('minutes'),
      priority: ck.Priority.fromWire(need<String>('priority')),
      lifestyle: ck.Lifestyle.fromWire(need<String>('lifestyle')),
      maxLiftDays: maxLiftDays as int?,
      // The plan-design answers are optional: a value this version can't read falls back to its default.
      smartPlan: json['smartPlan'] == true,
      style: CoachStyle.fromWire(json['style']) ?? CoachStyle.auto,
      sessionPref: CoachSessionPref.fromWire(json['sessionPref']) ?? CoachSessionPref.auto,
      years: CoachYears.fromWire(json['years']),
      focus: [
        if (json['focus'] case final List<dynamic> f)
          for (final x in f) ?CoachArea.fromWire(x),
      ],
      strengthLifts: switch (json['strengthLifts']) {
        final List<dynamic> l => [
            for (final x in l) ?CoachLift.fromWire(x),
          ],
        _ => null,
      },
      knownLifts: {
        if (json['knownLifts'] case final Map<dynamic, dynamic> m)
          for (final e in m.entries)
            if ((CoachLift.fromWire(e.key), e.value) case (final lift?, final num kg)) lift: kg.toDouble(),
      },
      splitKey: json['splitKey'] is String ? json['splitKey'] as String : null,
      extra: {
        for (final e in json.entries)
          if (!_known.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// A profile from the answers the app's screens can give, with the coach's defaults for the rest: lifting
  /// priority, and no limit on lifting days. The activity band follows from the app's activity multiplier
  /// [activity] (see `coachLifestyleFor`). Priority, the lifting-day limit and unknown keys come from [keep].
  /// With [answers], the plan-design answers come from them and the profile is a [smartPlan] one.
  factory CoachProfile.answered({
    required CoachGoal goal,
    required CoachStatus status,
    required List<int> days,
    required int minutes,
    required double activity,
    CoachProfile? keep,
    CoachAnswers? answers,
  }) =>
      CoachProfile(
        goal: ck.Goal.fromWire(goal.wire),
        status: ck.Status.fromWire(status.wire),
        days: days,
        minutes: minutes,
        priority: keep?.priority ?? ck.Priority.lifting,
        lifestyle: coachLifestyleFor(activity),
        maxLiftDays: keep?.maxLiftDays,
        smartPlan: answers != null,
        style: answers?.style ?? CoachStyle.auto,
        sessionPref: answers?.sessionPref ?? CoachSessionPref.auto,
        years: answers?.years,
        focus: answers?.focus ?? const [],
        strengthLifts: answers?.lifts,
        knownLifts: answers?.knownLifts ?? const {},
        splitKey: answers?.splitKey,
        extra: keep?.extra ?? const {},
      );

  /// The goal, as the app's screens name it.
  CoachGoal get coachGoal => CoachGoal.fromWire(goal.wire)!;

  /// The training status, as the app's screens name it.
  CoachStatus get coachStatus => CoachStatus.fromWire(status.wire)!;

  static const _known = {
    'goal',
    'status',
    'days',
    'minutes',
    'priority',
    'lifestyle',
    'maxLiftDays',
    'smartPlan',
    'style',
    'sessionPref',
    'years',
    'focus',
    'strengthLifts',
    'knownLifts',
    'splitKey',
  };

  final ck.Goal goal;
  final ck.Status status;

  /// Weekdays the user can train, in the coach packages' numbering.
  final List<int> days;

  /// Minutes per session.
  final int minutes;
  final ck.Priority priority;
  final ck.Lifestyle lifestyle;

  /// An upper bound on lifting days per week, or null for none.
  final int? maxLiftDays;

  /// Whether the plan is designed from all the answers (the smart planner). Profiles from before it keep the
  /// generator's own split choice until the user builds the plan again.
  final bool smartPlan;
  final CoachStyle style;
  final CoachSessionPref sessionPref;

  /// Years of consistent training, or null when not asked.
  final CoachYears? years;

  /// Up to two muscles to bring up.
  final List<CoachArea> focus;

  /// The main lifts a strength plan puts first, or null for squat, bench and deadlift.
  final List<CoachLift>? strengthLifts;

  /// Estimated one-rep maxes in kilograms, by lift.
  final Map<CoachLift, double> knownLifts;

  /// The split the user picked among the plan's options, or null for the coach's choice. A build keeps it while it
  /// fits the answers.
  final String? splitKey;

  /// Keys this version does not know, kept as they were read.
  final Map<String, dynamic> extra;

  Map<String, dynamic> toJson() => {
        'goal': goal.wire,
        'status': status.wire,
        'days': [...days],
        'minutes': minutes,
        'priority': priority.wire,
        'lifestyle': lifestyle.wire,
        'maxLiftDays': maxLiftDays,
        // Written only when set, so a profile from before the planner reads and writes back unchanged.
        if (smartPlan) 'smartPlan': true,
        if (style != CoachStyle.auto) 'style': style.wire,
        if (sessionPref != CoachSessionPref.auto) 'sessionPref': sessionPref.wire,
        if (years case final y?) 'years': y.wire,
        if (focus.isNotEmpty) 'focus': [for (final a in focus) a.wire],
        if (strengthLifts case final l?) 'strengthLifts': [for (final x in l) x.wire],
        if (knownLifts.isNotEmpty) 'knownLifts': {for (final e in knownLifts.entries) e.key.wire: e.value},
        'splitKey': ?splitKey,
        for (final e in extra.entries) e.key: jsonCopy(e.value),
      };
}
