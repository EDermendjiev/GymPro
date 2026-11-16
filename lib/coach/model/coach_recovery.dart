// SPDX-License-Identifier: GPL-3.0-only
// The recovery module's host values: proposals and how the coach treats them, check-ins, soreness, sports and
// injuries, as the app's screens and state can name them. Each enum carries the coach packages' wire name, so the
// model layer maps it to the packages' own enums and screens never see those.
import 'json_util.dart';

/// What a proposal changes. Stored under `coach.proposals[].kind` by its [wire] name.
enum CoachProposalKind {
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

  const CoachProposalKind(this.wire);

  final String wire;

  static CoachProposalKind? fromWire(Object? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

/// How the coach treats a proposal of a kind (see `lib/coach/policy/autonomy.dart`). Load and rep targets and the
/// first-set correction are silent changes; they never become proposals, so they have no tier here.
enum CoachAutonomyTier {
  /// Applied by the coach as soon as it is made, and shown with Undo for seven days.
  applyWithUndo,

  /// Shown with Apply and Not now; nothing changes until the user applies it.
  ask,
}

/// Where a stored proposal stands. Stored under `coach.proposals[].state` by its name.
enum CoachProposalState {
  pending,
  applied,
  dismissed;

  static CoachProposalState? fromWire(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return null;
  }
}

/// One stored proposal, read from its record in `coach.proposals`. The record is kept as it is; this is a view.
final class CoachProposal {
  CoachProposal._(this.record, this.kind, this.state);

  /// The proposal in [record], or null when the record has no known kind, state or id.
  static CoachProposal? read(Map<String, dynamic> record) {
    final kind = CoachProposalKind.fromWire(record['kind']);
    final state = CoachProposalState.fromWire(record['state']);
    if (kind == null || state == null || record['id'] is! String) return null;
    return CoachProposal._(record, kind, state);
  }

  /// The stored record.
  final Map<String, dynamic> record;
  final CoachProposalKind kind;
  final CoachProposalState state;

  String get id => record['id'] as String;

  /// The ISO day it was made.
  String get createdOn => _string('createdOn') ?? '';

  /// The ISO day it was applied, while it is applied.
  String? get appliedOn => _string('appliedOn');

  /// The ISO day it was dismissed (or ran out), while it is dismissed.
  String? get dismissedOn => _string('dismissedOn');

  /// The last ISO day it may still be applied, or null for no limit.
  String? get expiresOn => _string('expiresOn');

  /// The title and the reasoning, in English: they come from the coach packages.
  String get title => _string('title') ?? '';
  String get rationale => _string('rationale') ?? '';

  /// The proposal's payload: what it would change.
  Map<String, dynamic> get payload => jsonMap(record['payload']) ?? const {};

  String? _string(String key) => record[key] is String ? record[key] as String : null;
}

/// One day of recovery signals the coach reads (Task 5.1). A source the app has nothing for is null, never zero.
final class CoachCheckin {
  CoachCheckin({
    required this.day,
    required this.sleepHours,
    required this.energy,
    required this.stress,
    required Map<String, String> soreness,
    required this.bodyweightKg,
  }) : soreness = Map.unmodifiable(soreness);

  /// The ISO day.
  final String day;

  /// Hours slept that night, from Health Connect.
  final double? sleepHours;

  /// The energy rating (1–5) given after the day's last workout that has one.
  final int? energy;

  /// Not collected by the app: always null.
  final int? stress;

  /// Sore or painful areas that day, by the coach's muscle name ("sore" or "pain").
  final Map<String, String> soreness;

  /// The day's last weigh-in.
  final double? bodyweightKg;

  Map<String, dynamic> toJson() => {
        'day': day,
        'sleepHours': sleepHours,
        'energy': energy,
        'stress': stress,
        'soreness': {...soreness},
        'bodyweightKg': bodyweightKg,
      };
}

/// An area the soreness and injury sheets offer: the coach's muscles the app can show, with the three parts of the
/// shoulder apart. [muscle] is the app's muscle the area belongs to.
enum CoachArea {
  chest('chest', 'chest'),
  back('back', 'back'),
  frontDelts('front_delts', 'shoulders'),
  sideDelts('side_delts', 'shoulders'),
  rearDelts('rear_delts', 'shoulders'),
  biceps('biceps', 'biceps'),
  triceps('triceps', 'triceps'),
  forearms('forearms', 'forearm'),
  traps('traps', 'trapezius'),
  abs('abs', 'abdomen'),
  erectors('erectors', 'lowerback'),
  glutes('glutes', 'glutes'),
  quads('quads', 'quads'),
  hamstrings('hamstrings', 'hamstrings'),
  calves('calves', 'calves');

  const CoachArea(this.wire, this.muscle);

  /// The coach's muscle name, which is also the stored one.
  final String wire;

  /// The app's muscle id.
  final String muscle;

  static CoachArea? fromWire(Object? wire) {
    for (final a in values) {
      if (a.wire == wire) return a;
    }
    return null;
  }
}

/// How an area feels. Stored under `coach.soreness[day][area]` by its name.
enum CoachSoreness {
  sore,
  pain;

  static CoachSoreness? fromWire(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return null;
  }
}

/// How bad an injury is. Stored under `coach.injuries[].severity` by its name.
enum CoachInjurySeverity {
  niggle,
  pain,
  injury;

  static CoachInjurySeverity? fromWire(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return null;
  }
}

/// How hard a sport session usually is. Stored under `coach.sports[].intensity` by its name.
enum CoachSportIntensity {
  light,
  moderate,
  hard,
  match;

  static CoachSportIntensity? fromWire(Object? wire) {
    for (final s in values) {
      if (s.name == wire) return s;
    }
    return null;
  }
}

/// A sport the coach knows, for the sports sheet. [name] is in English: it comes from the coach packages.
final class CoachSportChoice {
  const CoachSportChoice({required this.id, required this.name, required this.defaultMinutes});

  final String id;
  final String name;
  final int defaultMinutes;
}

/// One sport the user plays, as the sports sheet edits it.
final class CoachSportEntry {
  CoachSportEntry({
    required this.sportId,
    required List<int> weekdays,
    required this.intensity,
    required this.minutes,
  }) : weekdays = List.unmodifiable(weekdays);

  final String sportId;

  /// Days of the week, 1 = Monday … 7 = Sunday.
  final List<int> weekdays;
  final CoachSportIntensity intensity;
  final int minutes;
}

/// One injury, as the injury sheet shows it.
final class CoachInjuryEntry {
  const CoachInjuryEntry({
    required this.id,
    required this.area,
    required this.label,
    required this.severity,
    required this.active,
  });

  final String id;

  /// Null for an injury the coach recorded without an area the sheets offer.
  final CoachArea? area;
  final String label;
  final CoachInjurySeverity severity;

  /// False once the injury is resolved.
  final bool active;
}
