// SPDX-License-Identifier: GPL-3.0-only
// The user's coaching profile, as stored under `coach.profile`.
import 'package:coach_kernel/coach_kernel.dart' as ck;

import 'json_util.dart';

/// Goal, training status, training days, session length, priority and lifestyle.
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
    Map<String, dynamic> extra = const {},
  })  : days = List.unmodifiable(days),
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
      extra: {
        for (final e in json.entries)
          if (!_known.contains(e.key)) e.key: e.value,
      },
    );
  }

  static const _known = {'goal', 'status', 'days', 'minutes', 'priority', 'lifestyle', 'maxLiftDays'};

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
        for (final e in extra.entries) e.key: jsonCopy(e.value),
      };
}
