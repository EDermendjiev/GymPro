// SPDX-License-Identifier: GPL-3.0-only
// Sport load model + volume trims. Rules: S-01, S-02, S-05.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

bool isHardIntensity(SportIntensity i) =>
    i == SportIntensity.moderate || i == SportIntensity.hard || i == SportIntensity.match;

/// S-01: every sport session at moderate or harder counts as one hard session.
int hardSportSessionsPerWeek(List<UserSport> sports) =>
    sports.where((s) => isHardIntensity(s.intensity)).fold(0, (n, s) => n + s.weekdays.length);

/// The result of [sportTrims]: sets trimmed per tracked muscle, in total (capped) and per sport.
class SportTrim {
  SportTrim({required this.total, required this.bySport});

  factory SportTrim.fromJson(Map<String, dynamic> json) => SportTrim(
    total: {
      for (final e in (json['total'] as Map<String, dynamic>).entries)
        MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
    },
    bySport: {
      for (final e in (json['bySport'] as Map<String, dynamic>).entries)
        MuscleId.trackedFromWire(e.key): [
          for (final x in e.value as List) TrimBySport.fromJson(x as Map<String, dynamic>),
        ],
    },
  );

  final Map<TrackedMuscle, double> total;
  final Map<TrackedMuscle, List<TrimBySport>> bySport;

  Map<String, dynamic> toJson() => {
    'total': {for (final e in total.entries) e.key.wire: e.value},
    'bySport': {
      for (final e in bySport.entries) e.key.wire: [for (final x in e.value) x.toJson()],
    },
  };
}

/// S-02: trim sets from each sport's stressed muscles, capped at 4 per muscle.
SportTrim sportTrims(List<UserSport> sports) {
  final total = <TrackedMuscle, double>{for (final m in TRACKED_MUSCLES) m: 0};
  final bySport = <TrackedMuscle, List<TrimBySport>>{for (final m in TRACKED_MUSCLES) m: []};
  for (final sp in sports) {
    if (!isHardIntensity(sp.intensity)) continue;
    final sessions = sp.weekdays.length;
    for (final m in sp.musclesStressed) {
      if (!TRACKED_MUSCLES.contains(m)) continue;
      final score = LOWER_MUSCLES.contains(m) ? sp.lowerBodyLoad : sp.upperBodyLoad;
      final perSession = SPORT_TRIM_PER_SESSION[math.max(0, math.min(3, score))] ?? 0;
      final sets = perSession * sessions;
      if (sets <= 0) continue;
      bySport[m]!.add(TrimBySport(sport: sp.name, sets: sets));
      total[m] = total[m]! + sets;
    }
  }
  for (final m in TRACKED_MUSCLES) {
    total[m] = math.min(SPORT_TRIM_MAX, total[m]!);
  }
  return SportTrim(total: total, bySport: bySport);
}

/// Sports that happen on a given ISO weekday.
List<UserSport> sportsOnDay(List<UserSport> sports, int weekday) => [
  for (final s in sports)
    if (s.weekdays.contains(weekday)) s,
];

/// A sport that is hard on the legs (T-SCH-04 trigger).
bool isLegHeavyHard(UserSport s) =>
    s.lowerBodyLoad >= 2 && (s.intensity == SportIntensity.hard || s.intensity == SportIntensity.match);
