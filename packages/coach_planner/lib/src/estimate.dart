// SPDX-License-Identifier: GPL-3.0-only
// A quick model of the week a split gives for a set of weekly targets, without an exercise catalog: sets per slot,
// sets per muscle per session, frequency and minutes. The block generator builds the real week later; this is
// what lets the planner compare splits. Rules: T-VOL-05, T-FRQ-01, T-FRQ-02.
// ignore_for_file: constant_identifier_names
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';
import 'package:coach_training/coach_training.dart';

import 'catalog.dart';

/// Sets a main lift takes in the estimate: one top single and three working sets.
const int MAIN_LIFT_SETS = 4;

/// The tags an extra exercise for a muscle can use, in preference order.
const Map<TrackedMuscle, List<SlotTag>> EXTRA_TAGS = {
  MuscleId.chest: [SlotTag.chestIso, SlotTag.pressMachine, SlotTag.pressFlat],
  MuscleId.back: [SlotTag.pullVertical, SlotTag.rowExtension, SlotTag.pullover, SlotTag.rowFlared],
  MuscleId.frontDelts: [SlotTag.pressVertical, SlotTag.frontRaise],
  MuscleId.sideDelts: [SlotTag.latRaise],
  MuscleId.rearDelts: [SlotTag.rearDelt, SlotTag.rowFlared],
  MuscleId.biceps: [SlotTag.bicepsIso],
  MuscleId.triceps: [SlotTag.tricepsIso],
  MuscleId.quads: [SlotTag.legExt, SlotTag.squatMachine, SlotTag.splitSquat, SlotTag.squatFree],
  MuscleId.hamstrings: [SlotTag.legCurlSeated, SlotTag.legCurl, SlotTag.hingeRdl],
  MuscleId.glutes: [SlotTag.hipExt, SlotTag.splitSquat, SlotTag.squatMachine],
  MuscleId.calves: [SlotTag.calf],
};

/// One exercise of an estimated session.
class EstSlot {
  EstSlot({
    required this.key,
    required this.tag,
    required this.sets,
    required this.main,
    required this.extra,
    this.muscle,
  });

  final String key;

  /// The tag the slot is counted as.
  final SlotTag tag;
  int sets;

  /// A main lift's top single and working sets.
  final bool main;

  /// Added for a muscle the template's own slots could not cover.
  final bool extra;

  /// For an extra exercise: the muscle it was added for.
  final TrackedMuscle? muscle;

  /// Done as a superset with the next slot of the session (T-PLN-08).
  bool superset = false;

  TagInfo get info => TAG_INFO[tag]!;

  int get workSeconds =>
      isCompound(info.category) ? SESSION_TIME.workSecondsCompound : SESSION_TIME.workSecondsIsolation;

  int get restSeconds => restFor(info.category, strengthMain: main);

  int get seconds => sets * (workSeconds + restSeconds);

  Map<String, dynamic> toJson() => {
    'key': key,
    'tag': tag.wire,
    'sets': sets,
    'main': main,
    'extra': extra,
    if (superset) 'superset': true,
  };
}

/// One estimated session.
class EstSession {
  EstSession({required this.templateKey, required this.region, required this.slots});

  final String templateKey;
  final Region region;
  final List<EstSlot> slots;

  /// Fractional sets per tracked muscle: 1 per set for a primary muscle, 0.5 for a secondary one.
  Map<TrackedMuscle, double> get muscleSets {
    final out = {for (final m in TRACKED_MUSCLES) m: 0.0};
    for (final s in slots) {
      for (final m in s.info.primary) {
        out[m] = out[m]! + s.sets;
      }
      for (final m in s.info.secondary) {
        out[m] = out[m]! + s.sets * 0.5;
      }
    }
    return out;
  }

  /// Minutes, with a superset's paired rounds taking one rest, plus the warm-up.
  int get minutes {
    var secs = 0;
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s.superset && i + 1 < slots.length) {
        final n = slots[++i];
        secs += supersetSeconds(
          setsA: s.sets,
          workA: s.workSeconds,
          restA: s.restSeconds,
          setsB: n.sets,
          workB: n.workSeconds,
          restB: n.restSeconds,
        );
        continue;
      }
      secs += s.seconds;
    }
    return jsRound(secs / 60 + SESSION_TIME.warmupMinutes);
  }

  /// Whether any slot is done as a superset.
  bool get hasSupersets => slots.any((s) => s.superset);

  Map<String, dynamic> toJson() => {
    'templateKey': templateKey,
    'minutes': minutes,
    'slots': [for (final s in slots) s.toJson()],
  };
}

/// The estimated week of a split.
class WeekEstimate {
  WeekEstimate({
    required this.sessions,
    required this.unmet,
    required this.missingSlots,
    required this.slotCount,
  });

  final List<EstSession> sessions;

  /// Muscles whose target could not be reached.
  final List<TrackedMuscle> unmet;

  /// Template slots the user's equipment and exercises cannot fill.
  final int missingSlots;

  /// Template slots in the week, filled or not.
  final int slotCount;

  /// Share of the template slots that cannot be filled.
  double get missingShare => slotCount == 0 ? 0 : missingSlots / slotCount;

  /// Fractional sets per muscle over the week.
  Map<TrackedMuscle, double> get weekly {
    final out = {for (final m in TRACKED_MUSCLES) m: 0.0};
    for (final s in sessions) {
      for (final e in s.muscleSets.entries) {
        out[e.key] = out[e.key]! + e.value;
      }
    }
    return out;
  }

  /// Sessions a week that give a muscle at least one fractional set.
  Map<TrackedMuscle, int> get frequency => {
    for (final m in TRACKED_MUSCLES) m: sessions.where((s) => s.muscleSets[m]! >= 1).length,
  };

  /// The most fractional sets any muscle gets in one session.
  double get maxSessionMuscleSets =>
      sessions.fold(0.0, (a, s) => math.max(a, s.muscleSets.values.fold(0.0, math.max)));

  List<int> get minutes => [for (final s in sessions) s.minutes];

  double get avgMinutes => minutes.isEmpty ? 0 : minutes.fold(0, (a, b) => a + b) / minutes.length;

  int get maxMinutes => minutes.fold(0, math.max);

  int get minMinutes => minutes.isEmpty ? 0 : minutes.reduce(math.min);

  Map<String, dynamic> toJson() => {
    'sessions': [for (final s in sessions) s.toJson()],
    'unmet': [for (final m in unmet) m.wire],
    'missingSlots': missingSlots,
    'slotCount': slotCount,
  };
}

/// Sessions a week the muscle should get at [target] sets (T-FRQ-02): the least, and the preferred.
({int least, int preferred}) frequencyFor(double target) => target <= 10
    ? (least: 1, preferred: 2)
    : target <= 20
    ? (least: 2, preferred: 2)
    : (least: 3, preferred: 3);

bool _regionAllows(Region region, TrackedMuscle m) =>
    region == Region.full ||
    (region == Region.lower ? LOWER_MUSCLES.contains(m) : !LOWER_MUSCLES.contains(m));

/// The estimated week of [split] for weekly [targets].
///
/// Slots start at the block generator's starting sets (compounds 3, isolations 2, main lifts [MAIN_LIFT_SETS]).
/// Then, one set at a time, the muscle furthest below its target gets a set on its least-loaded slot (at most 5
/// sets per slot), or a new exercise on a day whose region allows it (at most 8 per session). A muscle that can
/// get neither is unmet. Main-lift slots count only when [strength] is set and their lift is in [lifts]; a slot
/// none of whose tags is in [availableTags] (when given) is left out and counted as missing. With [pairAbove], a
/// session over that many minutes pairs isolation slots as supersets until it fits (T-PLN-08), as the block
/// generator does.
WeekEstimate estimateWeek(
  PlannerSplit split,
  Map<TrackedMuscle, double> targets, {
  required bool strength,
  List<MainLift> lifts = const [MainLift.squat, MainLift.bench, MainLift.deadlift],
  Set<SlotTag>? availableTags,
  int? pairAbove,
}) {
  bool available(SlotTag t) => availableTags == null || availableTags.contains(t);
  var missing = 0;
  var slotCount = 0;
  final sessions = <EstSession>[];
  for (final key in split.templates) {
    final t = templateFor(key)!;
    final mains = {
      for (final s in t.slots)
        if (strength && s.mainLift != null && lifts.contains(s.mainLift)) s.mainLift!,
    };
    final slots = <EstSlot>[];
    for (final s in t.slots) {
      final main = s.mainLift;
      if (main != null) {
        if (!mains.contains(main)) continue;
        slotCount++;
        if (!available(MAIN_LIFT_TAG[main]!)) {
          missing++;
          continue;
        }
        slots.add(
          EstSlot(key: s.key, tag: MAIN_LIFT_TAG[main]!, sets: MAIN_LIFT_SETS, main: true, extra: false),
        );
        continue;
      }
      if (strength && s.replacedByMain != null && mains.contains(s.replacedByMain)) continue;
      slotCount++;
      final tag = s.tags.where(available).firstOrNull;
      if (tag == null) {
        missing++;
        continue;
      }
      final category = TAG_INFO[tag]!.category;
      slots.add(
        EstSlot(
          key: s.key,
          tag: tag,
          sets: isCompound(category) ? SESSION_TIME.startSetsCompound : SESSION_TIME.startSetsIsolation,
          main: false,
          extra: false,
        ),
      );
    }
    sessions.add(EstSession(templateKey: key, region: t.region, slots: slots));
  }

  final weekly = {for (final m in TRACKED_MUSCLES) m: 0.0};
  void count(EstSlot s, int sets) {
    for (final m in s.info.primary) {
      weekly[m] = weekly[m]! + sets;
    }
    for (final m in s.info.secondary) {
      weekly[m] = weekly[m]! + sets * 0.5;
    }
  }

  for (final s in sessions) {
    for (final slot in s.slots) {
      count(slot, slot.sets);
    }
  }

  final unmet = <TrackedMuscle>{};
  for (var guard = 0; guard < 400; guard++) {
    TrackedMuscle? worst;
    var worstGap = 0.0;
    for (final m in TRACKED_MUSCLES) {
      if (unmet.contains(m)) continue;
      final gap = targets[m]! - weekly[m]!;
      if (gap > worstGap) {
        worst = m;
        worstGap = gap;
      }
    }
    if (worst == null) break;
    final m = worst;

    // A set more on the slot of this muscle in the session that has the fewest sets of it.
    EstSlot? best;
    var bestLoad = double.infinity;
    for (final s in sessions) {
      final load = s.muscleSets[m]!;
      for (final slot in s.slots) {
        if (slot.main || !slot.info.primary.contains(m) || slot.sets >= SESSION_TIME.maxSetsPerExercise) {
          continue;
        }
        if (load < bestLoad) {
          best = slot;
          bestLoad = load;
        }
      }
    }
    if (best != null) {
      best.sets++;
      count(best, 1);
      continue;
    }

    // Otherwise a new exercise for it, on the allowed day with the fewest sets of it.
    final tag = EXTRA_TAGS[m]!.where(available).firstOrNull;
    EstSession? day;
    var dayLoad = double.infinity;
    if (tag != null) {
      for (final s in sessions) {
        if (!_regionAllows(s.region, m) || s.slots.length >= SESSION_TIME.maxExercisesPerSession) continue;
        final load = s.muscleSets[m]!;
        if (load < dayLoad) {
          day = s;
          dayLoad = load;
        }
      }
    }
    if (day == null) {
      unmet.add(m);
      continue;
    }
    final slot = EstSlot(
      key: 'extra_${m.wire}_${day.slots.length}',
      tag: tag!,
      sets: SESSION_TIME.minSetsPerExercise,
      main: false,
      extra: true,
      muscle: m,
    );
    day.slots.add(slot);
    count(slot, slot.sets);
  }

  // Trim what no muscle needs, longest session first: a set fewer where every muscle the slot trains stays at its
  // target, down to the fewest sets an exercise gets; then a whole exercise when its muscles keep their targets and
  // their frequency without it.
  bool keepsTargets(EstSlot slot, int sets) =>
      slot.info.primary.every((m) => weekly[m]! - sets >= targets[m]!) &&
      slot.info.secondary.every((m) => weekly[m]! - sets * 0.5 >= targets[m]! || unmet.contains(m));
  bool keepsFrequency(EstSession day, EstSlot slot) {
    final without = EstSession(
      templateKey: day.templateKey,
      region: day.region,
      slots: [
        for (final x in day.slots)
          if (!identical(x, slot)) x,
      ],
    ).muscleSets;
    return [...slot.info.primary, ...slot.info.secondary].every((m) {
      if (without[m]! >= 1) return true;
      final others = sessions.where((s) => !identical(s, day) && s.muscleSets[m]! >= 1).length;
      return others >= frequencyFor(targets[m]!).least;
    });
  }

  for (var guard = 0; guard < 400; guard++) {
    final byLength = [...sessions]..sort((a, b) => b.minutes - a.minutes);
    var changed = false;
    for (final day in byLength) {
      for (final slot in day.slots.reversed) {
        if (slot.main || slot.sets <= SESSION_TIME.minSetsPerExercise || !keepsTargets(slot, 1)) continue;
        slot.sets--;
        count(slot, -1);
        changed = true;
        break;
      }
      if (changed) break;
      for (final slot in day.slots.reversed) {
        if (slot.main || !keepsTargets(slot, slot.sets) || !keepsFrequency(day, slot)) continue;
        count(slot, -slot.sets);
        day.slots.remove(slot);
        changed = true;
        break;
      }
      if (changed) break;
    }
    if (!changed) break;
  }

  if (pairAbove != null) {
    for (final day in sessions) {
      final items = <SupersetItem>[
        for (final s in day.slots)
          (
            category: s.info.category,
            muscles: {...s.info.primary, ...s.info.secondary},
            sets: s.sets,
            free: !s.main,
          ),
      ];
      final original = [...day.slots];
      void apply(List<(int, int)> pairs) {
        day.slots
          ..clear()
          ..addAll([for (final (slot, sup) in applySupersets(original, pairs)) slot..superset = sup]);
      }

      final pairs = pickSupersets(items, (p) {
        apply(p);
        return day.minutes <= pairAbove;
      });
      apply(pairs);
    }
  }

  return WeekEstimate(
    sessions: sessions,
    unmet: [
      for (final m in TRACKED_MUSCLES)
        if (unmet.contains(m)) m,
    ],
    missingSlots: missing,
    slotCount: slotCount,
  );
}
