// SPDX-License-Identifier: GPL-3.0-only
// The coaching answers the app's screens can name: the goal, the training status, the block kind. Each has the
// coach packages' wire name, so the model layer maps them to the packages' own enums and screens never see those.
import 'coach_recovery.dart';

/// What the user trains for. Stored under `coach.profile.goal` by its [wire] name.
enum CoachGoal {
  leanGain('lean_gain'),
  recomp('recomp'),
  strength('strength'),
  fatLoss('fat_loss'),
  sportSupport('sport_support');

  const CoachGoal(this.wire);

  /// The coach packages' name, which is also the stored one.
  final String wire;

  /// The goal stored as [wire], or null when [wire] is not one.
  static CoachGoal? fromWire(Object? wire) {
    for (final g in values) {
      if (g.wire == wire) return g;
    }
    return null;
  }
}

/// How trained the user is. Stored under `coach.profile.status` by its [wire] name.
enum CoachStatus {
  novice('novice'),
  intermediate('intermediate'),
  advanced('advanced');

  const CoachStatus(this.wire);

  final String wire;

  static CoachStatus? fromWire(Object? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// The kind of the generated block.
enum CoachBlockKind {
  hypertrophy('hypertrophy'),
  strengthVolume('strength_volume'),
  strengthLoad('strength_load'),
  strengthPeak('strength_peak'),
  sportSupport('sport_support');

  const CoachBlockKind(this.wire);

  final String wire;

  static CoachBlockKind? fromWire(Object? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

/// The session lengths, in minutes, the coach's questions offer.
const List<int> coachSessionLengths = [30, 45, 60, 75, 90];

T? _byWire<T extends Enum>(List<T> values, String Function(T) wire, Object? w) {
  for (final v in values) {
    if (wire(v) == w) return v;
  }
  return null;
}

/// The training style the user prefers. [auto] leaves it to the coach. Stored under `coach.profile.style`.
enum CoachStyle {
  auto('auto'),
  fullBody('full_body'),
  upperLower('upper_lower'),
  pushPullLegs('push_pull_legs'),
  bodyPart('body_part');

  const CoachStyle(this.wire);

  final String wire;

  static CoachStyle? fromWire(Object? wire) => _byWire(values, (v) => v.wire, wire);
}

/// Fewer, longer sessions or more, shorter ones. [auto] trains on every picked day. Stored under
/// `coach.profile.sessionPref`.
enum CoachSessionPref {
  auto('auto'),
  fewerLonger('fewer_longer'),
  moreShorter('more_shorter');

  const CoachSessionPref(this.wire);

  final String wire;

  static CoachSessionPref? fromWire(Object? wire) => _byWire(values, (v) => v.wire, wire);
}

/// Years of consistent training. Stored under `coach.profile.years`.
enum CoachYears {
  underOne('under_one'),
  oneToThree('one_to_three'),
  threeToFive('three_to_five'),
  fivePlus('five_plus');

  const CoachYears(this.wire);

  final String wire;

  static CoachYears? fromWire(Object? wire) => _byWire(values, (v) => v.wire, wire);
}

/// A main lift a strength plan can put first.
enum CoachLift {
  squat('squat'),
  bench('bench'),
  deadlift('deadlift'),
  ohp('ohp');

  const CoachLift(this.wire);

  final String wire;

  static CoachLift? fromWire(Object? wire) => _byWire(values, (v) => v.wire, wire);
}

/// The answers that lead to a plan, while they are being given (in onboarding, or in Settings › Coach). Nothing
/// here is stored until the plan is built.
class CoachAnswers {
  CoachAnswers({
    this.goal,
    this.status,
    this.minutes = 60,
    this.days,
    this.style = CoachStyle.auto,
    this.sessionPref = CoachSessionPref.auto,
    this.years,
    List<CoachArea>? focus,
    this.lifts,
    Map<CoachLift, double>? knownLifts,
    this.pain,
    this.splitKey,
    this.cardio = 0,
  })  : focus = focus ?? [],
        knownLifts = knownLifts ?? {};

  /// Null until a goal is picked; a plan is built only once there is one.
  CoachGoal? goal;
  CoachStatus? status;
  int minutes;

  /// The weekdays (1 = Monday … 7 = Sunday) the user can train, or null to take them from the weekly goal.
  List<int>? days;

  /// Whether the status was worked out from the logs rather than picked.
  bool statusFromLogs = false;

  CoachStyle style;
  CoachSessionPref sessionPref;
  CoachYears? years;

  /// Up to two muscles to bring up.
  List<CoachArea> focus;

  /// The main lifts a strength plan puts first, or null for squat, bench and deadlift.
  List<CoachLift>? lifts;

  /// Estimated one-rep maxes in kilograms the user entered, by lift.
  Map<CoachLift, double> knownLifts;

  /// The areas that hurt now, or null to leave the recorded injuries as they are. When set, building the plan
  /// records a niggle for each new area and marks the active injuries of areas left out as healed.
  List<CoachArea>? pain;

  /// The split the user picked among the plan's other options, or null for the coach's choice.
  String? splitKey;

  /// Low-impact cardio sessions a week (0–3), asked for fat loss and recomposition.
  int cardio;
}
