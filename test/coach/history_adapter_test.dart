// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/adapters/history_adapter.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/merged_ids.dart';

LoggedSession _session(DateTime end, List<LoggedExercise> exercises, {int durationSec = 3600}) =>
    LoggedSession(end, durationSec, exercises);

LoggedExercise _ex(String id, List<LoggedSet> sets) => LoggedExercise(id, id, 'chest', sets);

List<ck.LoggedSet> _convert(List<LoggedSet> sets, {String id = 'bench'}) =>
    coachSets([_session(DateTime(2026, 11, 10, 19), [_ex(id, sets)])], since: '2000-01-01');

void main() {
  group('one row of the mapping table at a time', () {
    test('exerciseId is the logged exercise id', () {
      final out = _convert([LoggedSet(8, 80)], id: 'abc123');
      expect(out.single.exerciseId, 'abc123');
    });

    test('exerciseId is the merged id once the stored data went through the merge', () {
      final merged = withMergedExercises({
        'sessions': [
          _session(DateTime(2026, 11, 10, 19), [
            _ex('0S75mYG', [LoggedSet(8, 80)]),
          ]).toJson(),
        ],
      });
      final sessions = [
        for (final s in merged['sessions'] as List) LoggedSession.fromJson((s as Map).cast<String, dynamic>()),
      ];
      expect(coachSets(sessions, since: '2000-01-01').single.exerciseId, 'ktsFQAZ');
    });

    test('performedOn is the local calendar day the session started on', () {
      // Ended at 00:30 after 90 minutes, so it started the evening before.
      final s = _session(DateTime(2026, 11, 11, 0, 30), [
        _ex('bench', [LoggedSet(8, 80)]),
      ], durationSec: 5400);
      expect(coachSets([s], since: '2000-01-01').single.performedOn, '2026-11-10');
    });

    test('performedOn pads months and days', () {
      final s = _session(DateTime(2026, 3, 5, 9), [
        _ex('bench', [LoggedSet(8, 80)]),
      ]);
      expect(coachSets([s], since: '2000-01-01').single.performedOn, '2026-03-05');
    });

    test('loggedAt is the ISO string of the session date', () {
      final end = DateTime(2026, 11, 10, 19, 5, 7);
      final s = _session(end, [
        _ex('bench', [LoggedSet(8, 80)]),
      ]);
      expect(coachSets([s], since: '2000-01-01').single.loggedAt, end.toIso8601String());
    });

    test('loadKg is the logged weight', () {
      expect(_convert([LoggedSet(8, 82.5)]).single.loadKg, 82.5);
    });

    test('loadKg is null for an unloaded set of a bodyweight exercise, and only then', () {
      final s = _session(DateTime(2026, 11, 10, 19), [
        _ex('pullup', [LoggedSet(8, 0), LoggedSet(6, 10)]),
        _ex('bench', [LoggedSet(8, 0)]),
      ]);
      final out = coachSets([s], since: '2000-01-01', bodyweight: (id) => id == 'pullup');
      expect([for (final x in out) (x.exerciseId, x.loadKg)], [('pullup', null), ('pullup', 10.0), ('bench', 0.0)]);
    });

    test('reps are the logged reps', () {
      expect(_convert([LoggedSet(11, 60)]).single.reps, 11);
    });

    test('a sided set counts the weaker side', () {
      expect(_convert([LoggedSet(10, 20, left: 10, right: 8)]).single.reps, 8);
      expect(_convert([LoggedSet(9, 20, left: 7, right: 9)]).single.reps, 7);
    });

    test('rir is ten minus the RPE, and null without one', () {
      final out = _convert([LoggedSet(8, 80, rpe: 8), LoggedSet(8, 80, rpe: 9.5), LoggedSet(8, 80)]);
      expect([for (final x in out) x.rir], [2.0, 0.5, null]);
    });

    test('a warm-up is marked as one', () {
      final out = _convert([LoggedSet(10, 40, kind: SetKind.warmup), LoggedSet(8, 80)]);
      expect([for (final x in out) x.isWarmup], [true, false]);
    });

    test('a set taken to failure is an ordinary working set', () {
      final out = _convert([LoggedSet(8, 80, kind: SetKind.failure)]);
      expect(out.single.isWarmup, isFalse);
      expect(out.single.reps, 8);
    });

    test('drop, rest-pause and cluster sets after a working set are part of it', () {
      for (final kind in [SetKind.drop, SetKind.restPause, SetKind.cluster]) {
        final out = _convert([
          LoggedSet(8, 80),
          LoggedSet(5, 60, kind: kind),
          LoggedSet(4, 40, kind: kind),
          LoggedSet(8, 80),
          LoggedSet(3, 60, kind: kind),
        ]);
        expect([for (final x in out) (x.setIndex, x.loadKg, x.reps)], [(0, 80.0, 8), (1, 80.0, 8)], reason: kind.name);
      }
    });

    test('a group with no working set before it counts once, by its first set', () {
      final out = _convert([
        LoggedSet(10, 40, kind: SetKind.warmup),
        LoggedSet(6, 70, kind: SetKind.cluster),
        LoggedSet(6, 70, kind: SetKind.cluster),
        LoggedSet(5, 70, kind: SetKind.cluster),
        LoggedSet(8, 60),
      ]);
      expect(
        [for (final x in out) (x.isWarmup, x.setIndex, x.loadKg, x.reps)],
        [(true, 0, 40.0, 10), (false, 0, 70.0, 6), (false, 1, 60.0, 8)],
      );
    });

    test('cardio, timed and stretch exercises are skipped', () {
      final s = _session(DateTime(2026, 11, 10, 19), [
        _ex('running', [LoggedSet(0, 0, km: 5, sec: 1500)]),
        _ex('plank', [LoggedSet(0, 0, sec: 60)]),
        _ex('quad-stretch', [LoggedSet(1, 0)]),
        _ex('bench', [LoggedSet(8, 80)]),
      ]);
      final out = coachSets([s], since: '2000-01-01', skip: (id) => id == 'quad-stretch');
      expect([for (final x in out) x.exerciseId], ['bench']);
    });

    test('an exercise logged with distance or as a hold is skipped even when nobody says so', () {
      final s = _session(DateTime(2026, 11, 10, 19), [
        _ex('custom-run', [LoggedSet(0, 0, km: 3)]),
        _ex('custom-hold', [LoggedSet(0, 20, sec: 45)]),
        _ex('bench', [LoggedSet(8, 80)]),
      ]);
      expect([for (final x in coachSets([s], since: '2000-01-01')) x.exerciseId], ['bench']);
    });

    test('a row with no reps is not a set', () {
      final out = _convert([LoggedSet(0, 80), LoggedSet(8, 80)]);
      expect([for (final x in out) (x.setIndex, x.reps)], [(0, 8)]);
    });

    test('sessionId is the same for the same session date and differs between sessions', () {
      List<ck.LoggedSet> of(DateTime end, {int durationSec = 3600}) => coachSets([
        _session(end, [
          _ex('bench', [LoggedSet(8, 80), LoggedSet(8, 80)]),
          _ex('row', [LoggedSet(8, 60)]),
        ], durationSec: durationSec),
      ], since: '2000-01-01');

      final a = of(DateTime(2026, 11, 10, 19));
      expect({for (final x in a) x.sessionId}, hasLength(1), reason: 'one id for the whole session');
      expect(a.first.sessionId, isNotEmpty);
      expect(of(DateTime(2026, 11, 10, 19), durationSec: 60).first.sessionId, a.first.sessionId,
          reason: 'only the date goes into the id');
      expect(of(DateTime(2026, 11, 10, 19, 0, 1)).first.sessionId, isNot(a.first.sessionId));
    });

    test('sessionId does not change between runs, platforms or time zones', () {
      // Pinned: the id is derived from the stored text of the date and nothing else.
      expect(coachSessionId('2026-11-10T19:00:00.000'), 'd8d2b8deffa92992');
      expect(coachSessionId(''), '811c9dc5811c9dc5');
      // The published 32-bit FNV-1a value for "a", in both halves.
      expect(coachSessionId('a'), 'e40c292ce40c292c');
    });
  });

  group('set numbering', () {
    test('working sets and warm-ups are numbered from zero, each on their own', () {
      final out = _convert([
        LoggedSet(10, 40, kind: SetKind.warmup),
        LoggedSet(5, 60, kind: SetKind.warmup),
        LoggedSet(8, 80),
        LoggedSet(7, 80),
      ]);
      expect([for (final x in out) (x.isWarmup, x.setIndex)], [(true, 0), (true, 1), (false, 0), (false, 1)]);
    });

    test('an exercise that appears twice in a session keeps counting', () {
      final s = _session(DateTime(2026, 11, 10, 19), [
        _ex('bench', [LoggedSet(8, 80), LoggedSet(8, 80)]),
        _ex('row', [LoggedSet(8, 60)]),
        _ex('bench', [LoggedSet(6, 80)]),
      ]);
      final out = coachSets([s], since: '2000-01-01');
      expect(
        [for (final x in out) (x.exerciseId, x.setIndex)],
        [('bench', 0), ('bench', 1), ('row', 0), ('bench', 2)],
      );
    });
  });

  group('which sessions', () {
    final sessions = [
      _session(DateTime(2026, 11, 12, 19), [
        _ex('bench', [LoggedSet(8, 82.5)]),
      ]),
      _session(DateTime(2026, 11, 3, 19), [
        _ex('bench', [LoggedSet(8, 77.5)]),
      ]),
      _session(DateTime(2026, 11, 10, 19), [
        _ex('bench', [LoggedSet(8, 80)]),
      ]),
    ];

    test('since keeps that day and everything after it', () {
      expect([for (final x in coachSets(sessions, since: '2026-11-10')) x.performedOn], ['2026-11-10', '2026-11-12']);
      expect(coachSets(sessions, since: '2026-11-13'), isEmpty);
    });

    test('the result runs from the oldest session to the newest, whatever order they are stored in', () {
      expect([for (final x in coachSets(sessions, since: '2000-01-01')) x.loadKg], [77.5, 80.0, 82.5]);
    });

    test('the sessions themselves are left as they were', () {
      final before = [for (final s in sessions) s.date];
      coachSets(sessions, since: '2000-01-01');
      expect([for (final s in sessions) s.date], before);
    });

    test('no sessions, no sets', () {
      expect(coachSets(const [], since: '2000-01-01'), isEmpty);
    });
  });

  test('two thousand sessions convert in under 50 ms, each with its own id', () {
    final start = DateTime(2020, 1, 1, 18);
    final sessions = [
      for (var i = 0; i < 2000; i++)
        _session(start.add(Duration(days: i, minutes: i % 50)), [
          for (var e = 0; e < 6; e++)
            _ex('ex${(i + e) % 40}', [
              LoggedSet(10, 40, kind: SetKind.warmup),
              LoggedSet(8, 80, rpe: 8),
              LoggedSet(8, 80, rpe: 8.5),
              LoggedSet(7, 80, rpe: 9),
              LoggedSet(5, 60, kind: SetKind.drop),
            ]),
        ]),
    ];
    bool bodyweight(String id) => id == 'ex3';
    bool skip(String id) => id == 'ex7';

    var out = coachSets(sessions, since: '2000-01-01', bodyweight: bodyweight, skip: skip); // warm up the code
    var best = const Duration(days: 1);
    for (var run = 0; run < 5; run++) {
      final watch = Stopwatch()..start();
      out = coachSets(sessions, since: '2000-01-01', bodyweight: bodyweight, skip: skip);
      watch.stop();
      if (watch.elapsed < best) best = watch.elapsed;
    }

    expect(out.length, greaterThan(40000));
    expect({for (final x in out) x.sessionId}, hasLength(2000));
    expect(best.inMicroseconds, lessThan(50000), reason: 'took ${best.inMicroseconds / 1000} ms');
  });
}
