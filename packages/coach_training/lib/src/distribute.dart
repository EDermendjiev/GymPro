// SPDX-License-Identifier: GPL-3.0-only
// Distributing weekly sets across sessions. Rules: T-FRQ-01, T-VOL-05, T-SEL-05.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_progression/coach_progression.dart';

import 'selection.dart';
import 'split.dart';

enum WorkKind {
  normal('normal'),
  single('single'),
  backoff('backoff');

  const WorkKind(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, WorkKind> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static WorkKind fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown WorkKind: "$wire"'));
}

/// One exercise of a session being built. The distributor changes [sets] in place.
class WorkExercise {
  WorkExercise({
    required this.ex,
    required this.slotKey,
    required this.sets,
    required this.kind,
    required this.fixed,
    this.repsForCounting,
  });

  factory WorkExercise.fromJson(Map<String, dynamic> json) => WorkExercise(
    ex: ExerciseDef.fromJson(json['ex'] as Map<String, dynamic>),
    slotKey: json['slotKey'] as String,
    sets: json['sets'] as int,
    kind: WorkKind.fromWire(json['kind'] as String),
    fixed: json['fixed'] as bool,
    repsForCounting: json['repsForCounting'] as int?,
  );

  final ExerciseDef ex;
  final String slotKey;
  int sets;
  final WorkKind kind;

  /// Not adjustable by the distributor.
  final bool fixed;

  /// Fixed sets: only count if ≥ 4 reps.
  final int? repsForCounting;

  Map<String, dynamic> toJson() => {
    'ex': ex.toJson(),
    'slotKey': slotKey,
    'sets': sets,
    'kind': kind.wire,
    'fixed': fixed,
    'repsForCounting': ?repsForCounting,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  WorkExercise copyWith({
    ExerciseDef? ex,
    String? slotKey,
    int? sets,
    WorkKind? kind,
    bool? fixed,
    int? repsForCounting,
  }) => WorkExercise(
    ex: ex ?? this.ex,
    slotKey: slotKey ?? this.slotKey,
    sets: sets ?? this.sets,
    kind: kind ?? this.kind,
    fixed: fixed ?? this.fixed,
    repsForCounting: repsForCounting ?? this.repsForCounting,
  );
}

/// A session being built. The distributor adds exercises to [exercises] in place.
class WorkSession {
  WorkSession({
    required this.templateKey,
    required this.title,
    required this.region,
    required this.variant,
    required this.exercises,
  });

  factory WorkSession.fromJson(Map<String, dynamic> json) => WorkSession(
    templateKey: json['templateKey'] as String,
    title: json['title'] as String,
    region: Region.fromWire(json['region'] as String),
    variant: SessionVariant.fromWire(json['variant'] as String),
    exercises: [for (final x in json['exercises'] as List) WorkExercise.fromJson(x as Map<String, dynamic>)],
  );

  final String templateKey;
  final String title;
  final Region region;
  final SessionVariant variant;
  List<WorkExercise> exercises;

  Map<String, dynamic> toJson() => {
    'templateKey': templateKey,
    'title': title,
    'region': region.wire,
    'variant': variant.wire,
    'exercises': [for (final w in exercises) w.toJson()],
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  WorkSession copyWith({
    String? templateKey,
    String? title,
    Region? region,
    SessionVariant? variant,
    List<WorkExercise>? exercises,
  }) => WorkSession(
    templateKey: templateKey ?? this.templateKey,
    title: title ?? this.title,
    region: region ?? this.region,
    variant: variant ?? this.variant,
    exercises: exercises ?? this.exercises,
  );
}

bool _counts(WorkExercise w) => w.kind == WorkKind.normal || (w.repsForCounting ?? 0) >= 4;

double sessionMuscleSets(WorkSession s, MuscleId m) {
  var total = 0.0;
  for (final w in s.exercises) {
    if (_counts(w)) total += w.sets * muscleWeight(w.ex, m);
  }
  return total;
}

double weeklyMuscleSets(List<WorkSession> sessions, MuscleId m) =>
    sessions.fold(0.0, (a, s) => a + sessionMuscleSets(s, m));

int estimateMinutes(WorkSession s) {
  var secs = 0;
  for (final w in s.exercises) {
    final work = isCompound(w.ex.category)
        ? SESSION_TIME.workSecondsCompound
        : SESSION_TIME.workSecondsIsolation;
    final rest = restFor(w.ex.category, strengthMain: w.kind != WorkKind.normal);
    secs += w.sets * (work + rest);
  }
  return jsRound(secs / 60 + SESSION_TIME.warmupMinutes);
}

bool _regionAllows(Region region, TrackedMuscle m) =>
    region == Region.full ||
    (region == Region.lower ? LOWER_MUSCLES.contains(m) : !LOWER_MUSCLES.contains(m));

/// The result of [distribute].
class DistributeResult {
  DistributeResult({required this.sessions, required this.unmet});

  final List<WorkSession> sessions;
  final List<TrackedMuscle> unmet;

  Map<String, dynamic> toJson() => {
    'sessions': [for (final s in sessions) s.toJson()],
    'unmet': [for (final m in unmet) m.wire],
  };
}

int _sign(num x) => x < 0
    ? -1
    : x > 0
    ? 1
    : 0;

/// Adjusts set counts so each tracked muscle lands within target −0.5 … target +1
/// without exceeding ~11 sets per muscle per session (T-FRQ-01) or 2–5 sets per exercise.
///
/// Changes [sessions] in place and returns them.
DistributeResult distribute(
  List<WorkSession> sessions,
  Map<TrackedMuscle, double> targets,
  SelectionContext selCtx,
) {
  final maxPerSession = FREQUENCY.maxSetsPerMusclePerSession;
  final order = stableSorted(
    TRACKED_MUSCLES,
    (a, b) => _sign(targets[b]! - targets[a]!) != 0
        ? _sign(targets[b]! - targets[a]!)
        : TRACKED_MUSCLES.indexOf(a) - TRACKED_MUSCLES.indexOf(b),
  );

  for (var pass = 0; pass < 6; pass++) {
    var changed = false;
    // ---- add sets ----
    for (final m in order) {
      var guard = 0;
      while (weeklyMuscleSets(sessions, m) < targets[m]! - 0.5 && guard++ < 60) {
        // 1) add a set to an exercise below the soft cap; 2) spread to a session that doesn't train m yet;
        // 3) go up to the hard cap of 5 sets; 4) add an isolation anywhere it fits.
        if (_addSetToExercise(sessions, m, _SOFT_CAP, maxPerSession) ||
            _addIsolation(sessions, m, selCtx, maxPerSession, true) ||
            _addSetToExercise(sessions, m, SESSION_TIME.maxSetsPerExercise, maxPerSession) ||
            _addIsolation(sessions, m, selCtx, maxPerSession, false)) {
          changed = true;
          continue;
        }
        break;
      }
    }
    // ---- remove sets ----
    for (final m in order) {
      if (m == MuscleId.frontDelts) continue; // pressing covers front delts; never trimmed for being "over"
      var guard = 0;
      while (weeklyMuscleSets(sessions, m) > targets[m]! + 1 && guard++ < 60) {
        ({int si, int ei, List<num> key})? best;
        for (var si = 0; si < sessions.length; si++) {
          final s = sessions[si];
          exercises:
          for (var ei = 0; ei < s.exercises.length; ei++) {
            final w = s.exercises[ei];
            if (w.fixed || !isPrimary(w.ex, m) || w.sets <= SESSION_TIME.minSetsPerExercise) continue;
            // Don't push another primary muscle of this exercise below its target.
            for (final em in w.ex.muscles) {
              if (em.role != MuscleRole.primary || em.muscle == m || em.muscle == MuscleId.frontDelts) {
                continue;
              }
              if (!TRACKED_MUSCLES.contains(em.muscle)) continue;
              final p = em.muscle;
              if (weeklyMuscleSets(sessions, p) - 1 < targets[p]! - 0.5) continue exercises;
            }
            final key = <num>[-w.sets, -si, -ei];
            if (best == null || _lexLess(key, best.key)) best = (si: si, ei: ei, key: key);
          }
        }
        if (best == null) break;
        sessions[best.si].exercises[best.ei].sets -= 1;
        changed = true;
      }
    }
    if (!changed) break;
  }

  final unmet = [
    for (final m in TRACKED_MUSCLES)
      if (weeklyMuscleSets(sessions, m) < targets[m]! - 0.5) m,
  ];
  return DistributeResult(sessions: sessions, unmet: unmet);
}

const _SOFT_CAP = 4; // heuristic: spread volume to another session before taking an exercise to 5 sets

bool _addSetToExercise(List<WorkSession> sessions, TrackedMuscle m, int cap, double maxPerSession) {
  ({int si, int ei, List<num> key})? best;
  for (var si = 0; si < sessions.length; si++) {
    final s = sessions[si];
    final cur = sessionMuscleSets(s, m);
    final mins = estimateMinutes(s);
    for (var ei = 0; ei < s.exercises.length; ei++) {
      final w = s.exercises[ei];
      if (w.fixed || !isPrimary(w.ex, m) || w.sets >= cap) continue;
      if (cur + muscleWeight(w.ex, m) > maxPerSession) continue;
      final solePrimary = w.ex.muscles.where((x) => x.role == MuscleRole.primary).length == 1 ? 0 : 1;
      final key = <num>[cur, mins, w.sets, solePrimary, si, ei];
      if (best == null || _lexLess(key, best.key)) best = (si: si, ei: ei, key: key);
    }
  }
  if (best == null) return false;
  sessions[best.si].exercises[best.ei].sets += 1;
  return true;
}

bool _addIsolation(
  List<WorkSession> sessions,
  TrackedMuscle m,
  SelectionContext selCtx,
  double maxPerSession,
  bool onlyUntrained,
) {
  final tags = ISOLATION_TAG_FOR[m];
  if (tags == null) return false;
  final cands = stableSorted(
    [
      for (var si = 0; si < sessions.length; si++)
        (
          s: sessions[si],
          si: si,
          cur: sessionMuscleSets(sessions[si], m),
          mins: estimateMinutes(sessions[si]),
        ),
    ].where(
      (c) =>
          _regionAllows(c.s.region, m) &&
          c.s.exercises.length < SESSION_TIME.maxExercisesPerSession &&
          c.cur + 2 <= maxPerSession &&
          (!onlyUntrained || !c.s.exercises.any((w) => isPrimary(w.ex, m))),
    ),
    (a, b) => _sign(a.cur - b.cur) != 0
        ? _sign(a.cur - b.cur)
        : a.mins != b.mins
        ? a.mins - b.mins
        : a.si - b.si,
  );
  for (final c in cands) {
    final exclude = {for (final w in c.s.exercises) w.ex.id};
    final pick = rankCandidates(
      SlotQuery(key: 'extra_${m.wire}', tags: tags),
      selCtx,
      exclude,
    ).where((e) => isPrimary(e, m)).firstOrNull;
    if (pick == null) continue;
    c.s.exercises.add(
      WorkExercise(
        ex: pick,
        slotKey: 'extra_${m.wire}',
        sets: SESSION_TIME.minSetsPerExercise,
        kind: WorkKind.normal,
        fixed: false,
      ),
    );
    return true;
  }
  return false;
}

bool _lexLess(List<num> a, List<num> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] < b[i]) return true;
    if (a[i] > b[i]) return false;
  }
  return false;
}

/// T-SEL-05: main-lift singles first, then free-weight compounds, machines, isolation.
WorkSession orderSession(WorkSession s) {
  int tier(WorkExercise w) {
    if (w.kind == WorkKind.single) return 0;
    if (w.kind == WorkKind.backoff) return 1;
    final c = w.ex.category;
    if (c == Category.lowerFreeCompound || c == Category.upperFreePress) return 1;
    if (c == Category.pullingCompound &&
        w.ex.equipment.any((e) => e == Equipment.barbell || e == Equipment.bodyweight)) {
      return 1;
    }
    if (c == Category.isolation) return 3;
    return 2;
  }

  return s.copyWith(exercises: stableSorted(s.exercises, (a, b) => tier(a) - tier(b)));
}
