// SPDX-License-Identifier: GPL-3.0-only
// The coaching answers the app's screens can name: the goal, the training status, the block kind. Each has the
// coach packages' wire name, so the model layer maps them to the packages' own enums and screens never see those.

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

/// The answers that lead to a plan, while they are being given (in onboarding, or in Settings › Coach). Nothing
/// here is stored until the plan is built.
class CoachAnswers {
  CoachAnswers({this.goal, this.status, this.minutes = 60, this.days});

  /// Null until a goal is picked; a plan is built only once there is one.
  CoachGoal? goal;
  CoachStatus? status;
  int minutes;

  /// The weekdays (1 = Monday … 7 = Sunday) the user can train, or null to take them from the weekly goal.
  List<int>? days;

  /// Whether the status was worked out from the logs rather than picked.
  bool statusFromLogs = false;
}
