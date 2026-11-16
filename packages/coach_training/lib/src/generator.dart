// SPDX-License-Identifier: GPL-3.0-only
// On-demand workout generation.
// ignore_for_file: constant_identifier_names
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';

import 'block.dart';
import 'distribute.dart';
import 'selection.dart';
import 'split.dart';

enum EquipmentPreset {
  full('full'),
  dumbbells('dumbbells'),
  bodyweight('bodyweight'),
  custom('custom');

  const EquipmentPreset(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, EquipmentPreset> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static EquipmentPreset fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown EquipmentPreset: "$wire"'));
}

/// The named focus areas of [Focus] (`'auto' | 'upper' | 'lower' | 'full'` in the reference).
enum FocusArea {
  auto('auto'),
  upper('upper'),
  lower('lower'),
  full('full');

  const FocusArea(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, FocusArea> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static FocusArea fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown FocusArea: "$wire"'));
}

/// What a generated session trains: a named area, or a list of muscles (`FocusArea | TrackedMuscle[]` in the reference).
/// Exactly one of [area] and [muscles] is set. JSON is the area's string or the list of muscle strings.
class Focus {
  const Focus.area(FocusArea this.area) : muscles = null;
  const Focus.muscles(List<TrackedMuscle> this.muscles) : area = null;

  factory Focus.fromJson(Object json) => json is List
      ? Focus.muscles([for (final m in json) MuscleId.trackedFromWire(m as String)])
      : Focus.area(FocusArea.fromWire(json as String));

  final FocusArea? area;
  final List<TrackedMuscle>? muscles;

  Object toJson() => muscles != null ? [for (final m in muscles!) m.wire] : area!.wire;
}

enum Readiness {
  normal('normal'),
  tired('tired');

  const Readiness(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, Readiness> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static Readiness fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown Readiness: "$wire"'));
}

/// Has no entry for [EquipmentPreset.custom], as in the reference.
const Map<EquipmentPreset, List<Equipment>> EQUIPMENT_PRESETS = {
  EquipmentPreset.full: [
    Equipment.barbell,
    Equipment.dumbbell,
    Equipment.machine,
    Equipment.cable,
    Equipment.bodyweight,
    Equipment.band,
    Equipment.sled,
  ],
  EquipmentPreset.dumbbells: [Equipment.dumbbell, Equipment.bodyweight],
  EquipmentPreset.bodyweight: [Equipment.bodyweight, Equipment.band],
};

Map<MuscleId, double> _muscleMap(Object? json) => {
  for (final e in (json as Map<String, dynamic>).entries)
    MuscleId.fromWire(e.key): (e.value as num).toDouble(),
};
List<MuscleId> _muscles(Object? json) => [for (final m in json as List) MuscleId.fromWire(m as String)];
Map<String, double> _wireMap(Map<MuscleId, double> m) => {for (final e in m.entries) e.key.wire: e.value};

class GeneratorInput {
  GeneratorInput({
    required this.today,
    required this.minutes,
    required this.equipmentPreset,
    this.equipment,
    required this.focus,
    required this.readiness,
    required this.exercises,
    required this.injuries,
    required this.increments,
    required this.targets,
    required this.loggedThisWeek,
    required this.recentPain,
    this.recentSore,
    required this.trainedLast48h,
    required this.sportStressed,
    required this.sets,
    this.sportPriority,
    this.disliked,
  });

  factory GeneratorInput.fromJson(Map<String, dynamic> json) => GeneratorInput(
    today: json['today'] as String,
    minutes: json['minutes'] as int,
    equipmentPreset: EquipmentPreset.fromWire(json['equipmentPreset'] as String),
    equipment: json['equipment'] == null
        ? null
        : [for (final x in json['equipment'] as List) Equipment.fromWire(x as String)],
    focus: Focus.fromJson(json['focus'] as Object),
    readiness: Readiness.fromWire(json['readiness'] as String),
    exercises: [for (final x in json['exercises'] as List) ExerciseDef.fromJson(x as Map<String, dynamic>)],
    injuries: [for (final x in json['injuries'] as List) Injury.fromJson(x as Map<String, dynamic>)],
    increments: {
      for (final e in (json['increments'] as Map<String, dynamic>).entries)
        e.key: (e.value as num).toDouble(),
    },
    targets: {
      for (final e in (json['targets'] as Map<String, dynamic>).entries)
        MuscleId.trackedFromWire(e.key): (e.value as num).toDouble(),
    },
    loggedThisWeek: _muscleMap(json['loggedThisWeek']),
    recentPain: _muscles(json['recentPain']),
    recentSore: json['recentSore'] == null ? null : _muscles(json['recentSore']),
    trainedLast48h: _muscleMap(json['trainedLast48h']),
    sportStressed: _muscles(json['sportStressed']),
    sets: [for (final x in json['sets'] as List) LoggedSet.fromJson(x as Map<String, dynamic>)],
    sportPriority: json['sportPriority'] as bool?,
    disliked: json['disliked'] == null ? null : [for (final x in json['disliked'] as List) x as String],
  );

  final String today;
  final int minutes;
  final EquipmentPreset equipmentPreset;
  final List<Equipment>? equipment;
  final Focus focus;
  final Readiness readiness;
  final List<ExerciseDef> exercises;
  final List<Injury> injuries;
  final Map<String, double> increments;
  final Map<TrackedMuscle, double> targets;
  final Map<MuscleId, double> loggedThisWeek;

  /// Pain in the last 3 check-ins.
  final List<MuscleId> recentPain;

  /// Rated sore (not pain) in a check-in within 48 h: skipped unless nothing else would be left.
  final List<MuscleId>? recentSore;
  final Map<MuscleId, double> trainedLast48h;

  /// Sport within 24 h before or after.
  final List<MuscleId> sportStressed;
  final List<LoggedSet> sets;
  final bool? sportPriority;
  final List<String>? disliked;

  Map<String, dynamic> toJson() => {
    'today': today,
    'minutes': minutes,
    'equipmentPreset': equipmentPreset.wire,
    if (equipment case final equipment?) 'equipment': [for (final e in equipment) e.wire],
    'focus': focus.toJson(),
    'readiness': readiness.wire,
    'exercises': [for (final e in exercises) e.toJson()],
    'injuries': [for (final i in injuries) i.toJson()],
    'increments': {...increments},
    'targets': _wireMap(targets),
    'loggedThisWeek': _wireMap(loggedThisWeek),
    'recentPain': [for (final m in recentPain) m.wire],
    if (recentSore case final recentSore?) 'recentSore': [for (final m in recentSore) m.wire],
    'trainedLast48h': _wireMap(trainedLast48h),
    'sportStressed': [for (final m in sportStressed) m.wire],
    'sets': [for (final s in sets) s.toJson()],
    'sportPriority': ?sportPriority,
    if (disliked case final disliked?) 'disliked': [...disliked],
  };
}

const _HOURS_48 = 48 * 3600 * 1000;

final _zone = RegExp(r'(?:Z|[+-]\d\d(?::?\d\d)?)$', caseSensitive: false);

/// Milliseconds since the epoch of an ISO timestamp, or null when it does not parse. A timestamp without a zone is
/// read as UTC (the reference reads a date-time without a zone as local time), so the result never depends on the host.
int? _epochMs(String iso) {
  final t = iso.trim();
  final withZone = _zone.hasMatch(t) && t.length > 10
      ? t
      : t.length == 10
      ? '${t}T00:00:00Z'
      : '${t}Z';
  return DateTime.tryParse(withZone)?.millisecondsSinceEpoch;
}

/// Sets logged in the 48 h before [now]. Uses the log timestamp when there is one, so a set
/// back-filled today for last week doesn't count; without a timestamp, today and yesterday count.
List<LoggedSet> setsInLast48h(List<LoggedSet> sets, DateTime now, String today) {
  final since = now.millisecondsSinceEpoch - _HOURS_48;
  return [
    for (final s in sets)
      if (_inWindow(s, since, today)) s,
  ];
}

bool _inWindow(LoggedSet s, int since, String today) {
  if (s.performedOn.compareTo(addDays(today, -2)) < 0 || s.performedOn.compareTo(today) > 0) return false;
  final loggedAt = s.loggedAt;
  if (loggedAt != null && loggedAt.isNotEmpty) {
    final ms = _epochMs(loggedAt);
    return ms != null && ms >= since;
  }
  return s.performedOn.compareTo(addDays(today, -1)) >= 0;
}

/// Fractional sets per muscle in the last 48 h (same counting as the weekly volume, T-VOL-05/06).
Map<MuscleId, double> trainedLast48h(
  List<LoggedSet> sets,
  Map<String, HasMuscles> exercises,
  DateTime now,
  String today,
) => loggedMuscleSets(setsInLast48h(sets, now, today), exercises, addDays(today, -2), 3);

/// One check-in as [checkinSoreness] reads it (`{ day: string; soreness: Record<string, string> | null }`).
class SorenessCheckin {
  SorenessCheckin({required this.day, required this.soreness});

  factory SorenessCheckin.fromJson(Map<String, dynamic> json) => SorenessCheckin(
    day: json['day'] as String,
    soreness: json['soreness'] == null
        ? null
        : {for (final e in (json['soreness'] as Map<String, dynamic>).entries) e.key: e.value as String},
  );

  final String day;

  /// Muscle → 'sore' or 'pain'; other values are ignored.
  final Map<String, String>? soreness;

  Map<String, dynamic> toJson() => {
    'day': day,
    'soreness': soreness == null ? null : {...soreness!},
  };
}

/// The result of [checkinSoreness].
class CheckinSoreness {
  CheckinSoreness({required this.pain, required this.sore});

  factory CheckinSoreness.fromJson(Map<String, dynamic> json) =>
      CheckinSoreness(pain: _muscles(json['pain']), sore: _muscles(json['sore']));

  final List<MuscleId> pain;
  final List<MuscleId> sore;

  Map<String, dynamic> toJson() => {
    'pain': [for (final m in pain) m.wire],
    'sore': [for (final m in sore) m.wire],
  };
}

/// Soreness from check-ins (newest first). Pain counts from any of the given check-ins;
/// plain soreness only from today's and yesterday's (a check-in is per day, so that is the 48 h window).
CheckinSoreness checkinSoreness(List<SorenessCheckin> checkins, String today) {
  final pain = <MuscleId>{};
  final sore = <MuscleId>{};
  for (final c in checkins) {
    for (final e in (c.soreness ?? const <String, String>{}).entries) {
      if (e.value == 'pain') {
        pain.add(MuscleId.fromWire(e.key));
      } else if (e.value == 'sore' &&
          c.day.compareTo(addDays(today, -1)) >= 0 &&
          c.day.compareTo(today) <= 0) {
        sore.add(MuscleId.fromWire(e.key));
      }
    }
  }
  return CheckinSoreness(
    pain: pain.toList(),
    sore: [
      for (final m in sore)
        if (!pain.contains(m)) m,
    ],
  );
}

/// Week of the block that [weekStart] falls in, clamped to the block (past its end, the last week's targets apply).
int blockWeekIndex(String weekStart, String blockStart, int weeks) {
  final idx = (daysBetween(blockStart, weekStart) / 7).floor();
  return math.min(math.max(0, idx), math.max(0, weeks - 1));
}

class GeneratedSession implements RuleTagged {
  GeneratedSession({
    required this.title,
    required this.estMinutes,
    required this.exercises,
    required this.muscles,
    required this.notes,
    required this.ruleIds,
  });

  factory GeneratedSession.fromJson(Map<String, dynamic> json) => GeneratedSession(
    title: json['title'] as String,
    estMinutes: json['estMinutes'] as int,
    exercises: [
      for (final x in json['exercises'] as List) PlannedExercise.fromJson(x as Map<String, dynamic>),
    ],
    muscles: [for (final x in json['muscles'] as List) MuscleId.trackedFromWire(x as String)],
    notes: [for (final x in json['notes'] as List) x as String],
    ruleIds: [for (final x in json['ruleIds'] as List) x as String],
  );

  final String title;
  final int estMinutes;
  final List<PlannedExercise> exercises;
  final List<TrackedMuscle> muscles;
  final List<String> notes;
  @override
  final List<String> ruleIds;

  Map<String, dynamic> toJson() => {
    'title': title,
    'estMinutes': estMinutes,
    'exercises': [for (final e in exercises) e.toJson()],
    'muscles': [for (final m in muscles) m.wire],
    'notes': [...notes],
    'ruleIds': [...ruleIds],
  };
}

const Map<TrackedMuscle, List<SlotTag>> _TAGS_FOR = {
  MuscleId.chest: [SlotTag.pressIncline, SlotTag.pressFlat, SlotTag.pressMachine, SlotTag.chestIso],
  MuscleId.back: [SlotTag.pullVertical, SlotTag.rowFlared, SlotTag.rowExtension, SlotTag.pullover],
  MuscleId.frontDelts: [SlotTag.pressVertical, SlotTag.frontRaise],
  MuscleId.sideDelts: [SlotTag.latRaise],
  MuscleId.rearDelts: [SlotTag.rearDelt],
  MuscleId.biceps: [SlotTag.bicepsIso],
  MuscleId.triceps: [SlotTag.tricepsIso],
  MuscleId.quads: [SlotTag.squatMachine, SlotTag.squatFree, SlotTag.splitSquat, SlotTag.legExt],
  MuscleId.hamstrings: [SlotTag.legCurlSeated, SlotTag.legCurl, SlotTag.hingeRdl],
  MuscleId.glutes: [SlotTag.hipExt, SlotTag.splitSquat, SlotTag.squatMachine],
  MuscleId.calves: [SlotTag.calf],
};

int _sign(num x) => x < 0
    ? -1
    : x > 0
    ? 1
    : 0;

GeneratedSession generateSession(GeneratorInput input) {
  final notes = <String>[];
  var equipment = input.equipmentPreset == EquipmentPreset.custom
      ? (input.equipment ?? EQUIPMENT_PRESETS[EquipmentPreset.full]!)
      : EQUIPMENT_PRESETS[input.equipmentPreset]!;
  if (equipment.isEmpty) {
    // The form requires at least one item; this keeps a direct call from silently returning nothing.
    equipment = EQUIPMENT_PRESETS[EquipmentPreset.bodyweight]!;
    notes.add('No equipment picked, so this uses bodyweight and bands.');
  }
  final excluded = <MuscleId>{...painfulMuscles(input.injuries), ...input.recentPain};
  if (excluded.isNotEmpty) notes.add('Skipping ${excluded.map((m) => m.wire).join(', ')} (pain or injury).');

  final focusMuscles = input.focus.muscles;
  final focusArea = input.focus.area;
  var pool = [
    for (final m in TRACKED_MUSCLES)
      if (m != MuscleId.frontDelts || (focusMuscles != null && focusMuscles.contains(m))) m,
  ];
  if (focusArea == FocusArea.upper) {
    pool = [
      for (final m in pool)
        if (!LOWER_MUSCLES.contains(m)) m,
    ];
  } else if (focusArea == FocusArea.lower) {
    pool = [
      for (final m in pool)
        if (LOWER_MUSCLES.contains(m)) m,
    ];
  } else if (focusMuscles != null) {
    pool = [
      for (final m in pool)
        if (focusMuscles.contains(m)) m,
    ];
  }
  pool = [
    for (final m in pool)
      if (!excluded.contains(m)) m,
  ];
  // Sore muscles sit out too, unless that would leave nothing to train.
  final sore = [
    for (final m in pool)
      if (input.recentSore?.contains(m) == true) m,
  ];
  if (sore.isNotEmpty && sore.length < pool.length) {
    pool = [
      for (final m in pool)
        if (!sore.contains(m)) m,
    ];
    notes.add('Skipping ${sore.map((m) => m.wire).join(', ')} (sore in the last 48 h).');
  } else if (sore.isNotEmpty) {
    notes.add(
      '${sore.map((m) => m.wire).join(', ')} still sore; kept because nothing else was left. Go lighter if it hurts.',
    );
  }

  double deficit(TrackedMuscle m) => (input.targets[m] ?? 0) - (input.loggedThisWeek[m] ?? 0);
  bool deprioritised(TrackedMuscle m) =>
      (input.trainedLast48h[m] ?? 0) >= 6 || input.sportStressed.contains(m);
  final ordered = stableSorted(pool, (a, b) {
    final d = (deprioritised(a) ? 1 : 0) - (deprioritised(b) ? 1 : 0);
    if (d != 0) return d;
    final f = _sign(deficit(b) - deficit(a));
    if (f != 0) return f;
    return TRACKED_MUSCLES.indexOf(a) - TRACKED_MUSCLES.indexOf(b);
  });
  if (ordered.any(deprioritised)) {
    notes.add('Muscles trained hard in the last 48 h or stressed by a sport are last in line.');
  }

  final selCtx = SelectionContext(
    exercises: input.exercises,
    equipment: equipment,
    injuries: input.injuries,
    disliked: input.disliked ?? [],
    sportPriority: input.sportPriority,
  );
  final session = WorkSession(
    templateKey: 'generated',
    title: 'Generated workout',
    region: Region.full,
    variant: SessionVariant.a,
    exercises: [],
  );
  final used = <String>{};
  final covered = <TrackedMuscle>[];
  final tired = input.readiness == Readiness.tired;
  final maxExercises = input.minutes <= 30 ? 5 : SESSION_TIME.maxExercisesPerSession;

  for (final m in ordered) {
    if (session.exercises.length >= maxExercises) break;
    if (focusArea == FocusArea.auto && deficit(m) <= 0 && covered.length >= 2) continue;
    final already = session.exercises.fold(0, (a, w) => a + (isPrimary(w.ex, m) ? w.sets : 0));
    if (already >= 3) continue;
    ExerciseDef? pick;
    for (final t in _TAGS_FOR[m]!) {
      final ranked = rankCandidates(SlotQuery(key: 'gen_${m.wire}', tags: [t]), selCtx, used);
      final e = ranked.isEmpty ? null : ranked[0];
      if (e != null && isPrimary(e, m)) {
        pick = e;
        break;
      }
    }
    if (pick == null) continue;
    final base = math.min(4, math.max(2, (math.max(deficit(m), 2) / 2).ceil()));
    final sets = math.max(SESSION_TIME.minSetsPerExercise, base - (tired ? 1 : 0));
    final trial = session.copyWith(
      exercises: [
        ...session.exercises,
        WorkExercise(ex: pick, slotKey: 'gen_${m.wire}', sets: sets, kind: WorkKind.normal, fixed: false),
      ],
    );
    if (estimateMinutes(trial) > input.minutes) {
      // Try a shorter version (2 sets) before giving up on this muscle.
      final short = session.copyWith(
        exercises: [
          ...session.exercises,
          WorkExercise(ex: pick, slotKey: 'gen_${m.wire}', sets: 2, kind: WorkKind.normal, fixed: false),
        ],
      );
      if (estimateMinutes(short) > input.minutes) continue;
      session.exercises = short.exercises;
    } else {
      session.exercises = trial.exercises;
    }
    used.add(pick.id);
    covered.add(m);
  }

  final ordered2 = orderSession(session);
  var ci = 0;
  var ii = 0;
  final exercises = <PlannedExercise>[];
  for (final (position, w) in ordered2.exercises.indexed) {
    final compound = isCompound(w.ex.category);
    final level = rangeLevel(
      RangeLevelOptions(
        category: w.ex.category,
        compoundIndex: compound ? ci : -1,
        isolationIndex: compound ? -1 : ii,
        variation: RepVariation.withinSession,
        variant: SessionVariant.a,
        weekIndex: 0,
      ),
    );
    if (compound) {
      ci++;
    } else {
      ii++;
    }
    final rx = prescribe(
      w.ex.category,
      RxOptions(
        level: level,
        sportPriority: input.sportPriority == true,
        isLowerCompound: compound && LOWER_MUSCLES.any((m) => isPrimary(w.ex, m)),
      ),
    );
    final rirMin = rx.rirMin + (tired ? 1 : 0);
    final rirMax = rx.rirMax + (tired ? 1 : 0);
    final inc = incrementFor(w.ex, equipment, input.increments);
    final sug = suggestNextSession(
      ExerciseHistory(
        exposures: exposuresFor(input.sets, w.ex.id),
        increment: inc,
        e1rm: bestRecentE1rm(input.sets, w.ex.id),
      ),
      SetRx(repMin: rx.repMin, repMax: rx.repMax, rirMin: rx.rirMin, rirMax: rx.rirMax),
    );
    exercises.add(
      PlannedExercise(
        exerciseId: w.ex.id,
        slotKey: w.slotKey,
        position: position,
        sets: w.sets,
        repMin: rx.repMin,
        repMax: rx.repMax,
        rirMin: rirMin,
        rirMax: rirMax,
        restSeconds: rx.restSeconds,
        suggestedLoadKg: sug.load,
        note: sug.hint,
        ruleIds: [...rx.ruleIds, ...sug.ruleIds],
      ),
    );
  }
  if (tired) notes.add('Tired today: one set fewer per exercise and one more rep in reserve.');
  final focusLabel = focusMuscles != null
      ? focusMuscles.map((m) => m.wire).join(' + ')
      : focusArea == FocusArea.auto
      ? 'catch-up'
      : focusArea!.wire;
  return GeneratedSession(
    title: 'Generated · $focusLabel',
    estMinutes: estimateMinutes(ordered2),
    exercises: exercises,
    muscles: covered,
    notes: notes,
    ruleIds: ['T-SEL-05', 'T-INT-03', 'T-VOL-05'],
  );
}
