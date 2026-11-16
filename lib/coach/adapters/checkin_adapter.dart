// SPDX-License-Identifier: GPL-3.0-only
// The recovery signals the app already has, as the coach's daily check-ins (Task 5.1). No daily form is added: sleep
// comes from Health Connect, energy from the rating after a workout, soreness from the soreness sheet, bodyweight from
// the weigh-ins. Stress is not collected. A source with nothing for a day is null, never zero.
//
// The rating "sleep" after a workout is a 1–5 quality score, not hours; the coach reads hours only, so that rating is
// not used.
import 'package:coach_kernel/coach_kernel.dart' as ck;

import '../../models/workout.dart';
import '../model/coach_recovery.dart';
import 'block_input_adapter.dart';

/// The check-ins from [from] to [to] (ISO days, both included), oldest first; a day with no signal at all is left
/// out. [sleepMinutes] holds Health Connect's sleep by ISO day; [soreness] is `coach.soreness`.
List<CoachCheckin> coachCheckinDays({
  required String from,
  required String to,
  required Map<String, double> sleepMinutes,
  required List<LoggedSession> sessions,
  required List<BodyweightEntry> bodyweight,
  required Map<String, dynamic> soreness,
}) {
  bool inRange(String d) => d.compareTo(from) >= 0 && d.compareTo(to) <= 0;
  // The last rating and weigh-in of each day win.
  final energy = <String, (DateTime, int)>{};
  for (final s in sessions) {
    final e = s.energy;
    if (e == null) continue;
    final d = coachIsoDay(s.date);
    if (!inRange(d)) continue;
    final prev = energy[d];
    if (prev == null || !s.date.isBefore(prev.$1)) energy[d] = (s.date, e);
  }
  final weight = <String, (DateTime, double)>{};
  for (final b in bodyweight) {
    final d = coachIsoDay(b.date);
    if (!inRange(d)) continue;
    final prev = weight[d];
    if (prev == null || !b.date.isBefore(prev.$1)) weight[d] = (b.date, b.kg);
  }
  final sore = <String, Map<String, String>>{};
  for (final e in soreness.entries) {
    if (!inRange(e.key) || e.value is! Map) continue;
    final day = <String, String>{
      for (final x in (e.value as Map).entries)
        if (CoachArea.fromWire(x.key) != null || x.key == 'adductors')
          if (CoachSoreness.fromWire(x.value) case final l?) x.key as String: l.name,
    };
    if (day.isNotEmpty) sore[e.key] = day;
  }
  final days = <String>{
    for (final d in sleepMinutes.keys)
      if (inRange(d)) d,
    ...energy.keys,
    ...weight.keys,
    ...sore.keys,
  }.toList()
    ..sort();
  return [
    for (final d in days)
      CoachCheckin(
        day: d,
        sleepHours: sleepMinutes[d] == null ? null : sleepMinutes[d]! / 60,
        energy: energy[d]?.$2,
        stress: null,
        soreness: sore[d] ?? const {},
        bodyweightKg: weight[d]?.$2,
      ),
  ];
}

/// [c] as the kernel's check-in.
ck.CheckinDay coachKernelCheckin(CoachCheckin c) => ck.CheckinDay(
      day: c.day,
      sleepHours: c.sleepHours,
      energy: c.energy,
      stress: c.stress,
      soreness: {
        for (final e in c.soreness.entries) ck.MuscleId.fromWire(e.key): ck.SorenessLevel.fromWire(e.value),
      },
      bodyweightKg: c.bodyweightKg,
    );
