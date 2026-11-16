// SPDX-License-Identifier: GPL-3.0-only
// Carry the user's own edits (moves, skips, session-only swaps) from a replaced plan into the regenerated one.
// Sessions are matched by a stable key, not by row id or date: week Monday | template | occurrence.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

/// Stable identity of a planned session: which week, which template, which occurrence of it in that week (0-based).
String planKey(String engineDate, String templateKey, int occurrence) =>
    '${mondayOf(engineDate)}|$templateKey|$occurrence';

/// `PriorSession.status` in the reference.
enum PriorSessionStatus {
  planned('planned'),
  skipped('skipped'),
  done('done');

  const PriorSessionStatus(this.wire);

  /// The string the reference uses for this value.
  final String wire;

  static final Map<String, PriorSessionStatus> _byWire = {for (final v in values) v.wire: v};

  /// Throws a [FormatException] when [wire] is not one of the values.
  static PriorSessionStatus fromWire(String wire) =>
      _byWire[wire] ?? (throw FormatException('Unknown PriorSessionStatus: "$wire"'));
}

/// A session-only swap: the engine chose [fromExerciseId] for the slot and the user trains [toExerciseId].
class SessionSwap {
  SessionSwap({required this.slotKey, required this.fromExerciseId, required this.toExerciseId});

  factory SessionSwap.fromJson(Map<String, dynamic> json) => SessionSwap(
    slotKey: json['slotKey'] as String,
    fromExerciseId: json['fromExerciseId'] as String,
    toExerciseId: json['toExerciseId'] as String,
  );

  final String slotKey;
  final String fromExerciseId;
  final String toExerciseId;

  Map<String, dynamic> toJson() => {
    'slotKey': slotKey,
    'fromExerciseId': fromExerciseId,
    'toExerciseId': toExerciseId,
  };
}

/// An accepted deload that changed a session: sets per remaining slot (slots it removed are absent).
class SessionDeload {
  SessionDeload({required this.setsBySlot});

  factory SessionDeload.fromJson(Map<String, dynamic> json) => SessionDeload(
    setsBySlot: {for (final e in (json['setsBySlot'] as Map<String, dynamic>).entries) e.key: e.value as int},
  );

  final Map<String, int> setsBySlot;

  Map<String, dynamic> toJson() => {
    'setsBySlot': {for (final e in setsBySlot.entries) e.key: e.value},
  };
}

/// A session of the plan being replaced, as stored.
class PriorSession {
  PriorSession({
    required this.planKey,
    required this.plannedOn,
    required this.scheduledOn,
    required this.status,
    required this.swaps,
    this.deload,
  });

  factory PriorSession.fromJson(Map<String, dynamic> json) => PriorSession(
    planKey: json['planKey'] as String,
    plannedOn: json['plannedOn'] as String,
    scheduledOn: json['scheduledOn'] as String,
    status: PriorSessionStatus.fromWire(json['status'] as String),
    swaps: [for (final x in json['swaps'] as List) SessionSwap.fromJson(x as Map<String, dynamic>)],
    deload: json['deload'] == null ? null : SessionDeload.fromJson(json['deload'] as Map<String, dynamic>),
  );

  final String planKey;

  /// The engine's date.
  final String plannedOn;

  /// The user's date (differs from plannedOn after a move).
  final String scheduledOn;

  /// 'done' covers in-progress and finished sessions: the regenerated copy is dropped so it isn't trained twice.
  final PriorSessionStatus status;

  /// Session-only swaps.
  final List<SessionSwap> swaps;

  /// Set when an accepted deload changed this session.
  final SessionDeload? deload;

  Map<String, dynamic> toJson() => {
    'planKey': planKey,
    'plannedOn': plannedOn,
    'scheduledOn': scheduledOn,
    'status': status.wire,
    'swaps': [for (final s in swaps) s.toJson()],
    if (deload case final deload?) 'deload': deload.toJson(),
  };
}

class CarryOverInput {
  CarryOverInput({required this.sessions, required this.prior, required this.today, required this.allowExercise});

  /// The regenerated sessions (materialised from this Monday, so sessions moved off a past day can still match).
  final List<PlannedSession> sessions;
  final List<PriorSession> prior;
  final String today;

  /// Swapped-in exercises must still be allowed (equipment, dislikes, injuries); otherwise the engine's choice stands.
  final bool Function(String exerciseId) allowExercise;
}

/// `CarryOverResult.kept` in the reference.
class CarryOverKept {
  CarryOverKept({this.moves = 0, this.skips = 0, this.swaps = 0, this.deloads = 0});

  factory CarryOverKept.fromJson(Map<String, dynamic> json) => CarryOverKept(
    moves: json['moves'] as int,
    skips: json['skips'] as int,
    swaps: json['swaps'] as int,
    deloads: json['deloads'] as int,
  );

  int moves;
  int skips;
  int swaps;
  int deloads;

  Map<String, dynamic> toJson() => {'moves': moves, 'skips': skips, 'swaps': swaps, 'deloads': deloads};
}

/// `CarryOverResult.dropped` in the reference.
class CarryOverDropped {
  CarryOverDropped({this.moves = 0, this.swaps = 0});

  factory CarryOverDropped.fromJson(Map<String, dynamic> json) =>
      CarryOverDropped(moves: json['moves'] as int, swaps: json['swaps'] as int);

  int moves;
  int swaps;

  Map<String, dynamic> toJson() => {'moves': moves, 'swaps': swaps};
}

class CarryOverResult {
  CarryOverResult({required this.sessions, required this.kept, required this.dropped});

  factory CarryOverResult.fromJson(Map<String, dynamic> json) => CarryOverResult(
    sessions: [for (final x in json['sessions'] as List) PlannedSession.fromJson(x as Map<String, dynamic>)],
    kept: CarryOverKept.fromJson(json['kept'] as Map<String, dynamic>),
    dropped: CarryOverDropped.fromJson(json['dropped'] as Map<String, dynamic>),
  );

  final List<PlannedSession> sessions;
  final CarryOverKept kept;
  final CarryOverDropped dropped;

  Map<String, dynamic> toJson() => {
    'sessions': [for (final s in sessions) s.toJson()],
    'kept': kept.toJson(),
    'dropped': dropped.toJson(),
  };
}

class _Work {
  _Work(this.s, this.engineDate, this.moveTo);

  final PlannedSession s;
  final String engineDate;
  final String? moveTo;
}

/// Re-applies the user's edits to matching regenerated sessions:
/// - skip: the session stays skipped;
/// - move: the session goes to the user's date, unless that date is in the past or now holds another session
///   (the engine's dates win; a move that would collide falls back to the engine's date);
/// - session-only swap: re-applied when the engine picked the same exercise for that slot again and the swapped-in
///   exercise is still allowed. If the engine now picks something else, the new choice reflects new settings and stands;
/// - deload: an accepted deload's set cuts and removed exercises are re-applied;
/// - done / in progress: the regenerated copy is dropped.
/// New sessions before today that no move carries forward are dropped (they were never trained or were missed).
CarryOverResult carryOverEdits(CarryOverInput input) {
  final today = input.today;
  final byKey = {for (final p in input.prior) p.planKey: p};
  final kept = CarryOverKept();
  final dropped = CarryOverDropped();

  final work = <_Work>[];
  for (final s in input.sessions) {
    final key = s.planKey;
    final p = key != null && key.isNotEmpty ? byKey[key] : null;
    if (p?.status == PriorSessionStatus.done) continue;
    final next = s.copyWith(exercises: [for (final e in s.exercises) e.copyWith()]);
    if (p?.status == PriorSessionStatus.skipped) {
      next.status = PlannedSessionStatus.skipped;
      kept.skips++;
    }
    if (p?.deload case final deload?) {
      // Re-apply an accepted deload (T-FAT-01/04): never more sets than the deloaded session had, removed slots stay removed.
      final by = deload.setsBySlot;
      next.exercises = [
        for (final (position, e) in next.exercises.where((e) => by.containsKey(e.slotKey)).indexed)
          e.copyWith(position: position, sets: math.min(e.sets, by[e.slotKey]!)),
      ];
      next.kind = SessionKind.deload;
      kept.deloads++;
    }
    if (p != null) {
      final usedIds = {for (final e in next.exercises) e.exerciseId};
      for (final sw in p.swaps) {
        final e = next.exercises.where((x) => x.slotKey == sw.slotKey).firstOrNull;
        if (e != null &&
            e.exerciseId == sw.fromExerciseId &&
            !usedIds.contains(sw.toExerciseId) &&
            input.allowExercise(sw.toExerciseId)) {
          e.originalExerciseId = e.exerciseId;
          e.exerciseId = sw.toExerciseId;
          e.suggestedLoadKg = null;
          usedIds.add(sw.toExerciseId);
          kept.swaps++;
        } else {
          dropped.swaps++;
        }
      }
    }
    final moveTo = p != null && p.scheduledOn != p.plannedOn && p.scheduledOn.compareTo(today) >= 0
        ? p.scheduledOn
        : null;
    work.add(_Work(next, s.date, moveTo));
  }

  // Accept every move, then revert moves that collide with another (non-skipped) session until none do.
  // Reverting only returns sessions to engine dates, which never collide with each other, so this terminates.
  final accepted = {...work.where((w) => w.moveTo != null)};
  String dateOf(_Work w) => accepted.contains(w) ? w.moveTo! : w.engineDate;
  for (var changed = true; changed;) {
    changed = false;
    final byDate = <String, List<_Work>>{};
    for (final w in work) {
      if (w.s.status != PlannedSessionStatus.skipped) byDate.putIfAbsent(dateOf(w), () => []).add(w);
    }
    for (final group in byDate.values) {
      if (group.length < 2) continue;
      for (final w in group) {
        if (accepted.remove(w)) changed = true;
      }
    }
  }

  final out = <PlannedSession>[];
  for (final w in work) {
    if (w.moveTo != null) {
      if (accepted.contains(w)) {
        kept.moves++;
      } else {
        dropped.moves++;
      }
    }
    final date = dateOf(w);
    if (date.compareTo(today) < 0) continue;
    out.add(date == w.engineDate ? w.s : w.s.copyWith(date: date, plannedOn: w.engineDate));
  }
  final sorted = stableSorted(out, (a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.orderInWeek - b.orderInWeek;
  });
  return CarryOverResult(sessions: sorted, kept: kept, dropped: dropped);
}
