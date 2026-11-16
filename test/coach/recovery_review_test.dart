// SPDX-License-Identifier: GPL-3.0-only
// Task 5.3: the weekly review's fixture histories, seeded into the app's state, give the same proposal kinds and
// payloads through `coachTick` as the recovery package gives for the fixture's own input.
//
// The app holds the history as its own records (logged workouts, Health Connect sleep, energy ratings, soreness
// reports, the coach's block and routines), so a fixture case is translated into those. Cases the app cannot hold
// are left out, each for a stated reason: stress that changes the answer (the app collects no stress), answer
// overrides (the app has no daily form), planned effort on logged sets (the app takes it from its own block),
// session states the app has no record for, and exercises the app's catalog has no annotation for.
import 'dart:convert';
import 'dart:io';

import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/coach.dart';
import 'package:gymmane/coach/data/coach_meta.dart';
import 'package:gymmane/models/workout.dart';
import 'package:gymmane/services/health_metrics.dart';
import 'package:gymmane/services/local_store.dart';
import 'package:gymmane/state/fit_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App exercise id by the coach's slug.
final Map<String, String> _bySlug = {for (final e in kCoachMeta.entries) e.value.slug: e.key};
final Map<String, String> _toSlug = {for (final e in kCoachMeta.entries) e.key: e.value.slug};

const _weeklyKinds = {'standard_deload', 'targeted_deload', 'block_transition', 'status_change'};

List<Map<String, dynamic>> _cases(String file, String call) {
  final json = jsonDecode(File('packages/coach_recovery/test/fixtures/$file').readAsStringSync()) as Map;
  return [
    for (final c in json['cases'] as List)
      if ((c as Map)['input']['call'] == call) c.cast<String, dynamic>(),
  ];
}

/// Why the app cannot hold [s], or null when it can.
String? _unfit(Map<String, dynamic> s, Map<String, dynamic> out) {
  if (s['overrides'] != null) return 'answer overrides';
  if ((s['block'] as Map?)?['testDate'] != null) return 'a strength test date: the block the app keeps has none';
  final answers = (out['answers'] as Map?) ?? const {};
  final stressLogged = (s['checkins'] as List).any((c) => c['stress'] != null);
  if (stressLogged && answers['stress_worse'] == true) return 'stress changes the answer';
  final sessions = [...s['sessionsThisWeek'] as List, ...s['nextWeekSessions'] as List];
  for (final x in sessions) {
    if (!const {'planned', 'done', 'skipped'}.contains(x['status'])) return 'session state ${x['status']}';
    for (final e in x['exercises'] as List) {
      if (!_bySlug.containsKey(e['exerciseId'])) return 'exercise ${e['exerciseId']}';
    }
  }
  for (final x in s['sets'] as List) {
    if (!_bySlug.containsKey(x['exerciseId'])) return 'exercise ${x['exerciseId']}';
    final bw = fit.exerciseById(_bySlug[x['exerciseId']]!)!.equipment == 'Bodyweight';
    if ((x['loadKg'] == null) != bw || (bw && x['loadKg'] != null)) return 'load of a body-weight set';
  }
  final weekStart = s['weekStart'] as String;
  final planned = _plannedFloors(s);
  if (planned == null) return 'planned effort on logged sets in the reviewed weeks';
  for (final x in sessions) {
    for (final e in x['exercises'] as List) {
      if (planned.containsKey('${x['date']}|${e['exerciseId']}')) return 'planned effort on a planned day';
    }
  }
  if (planned.keys.any((k) => k.compareTo(ck.addDays(weekStart, 14)) >= 0)) return 'planned effort ahead';
  for (final id in s['mainLiftExerciseIds'] as List) {
    if (!_bySlug.containsKey(id)) return 'exercise $id';
  }
  return null;
}

/// The planned effort floors of the logged sets, by `day|slug`; null when one day and exercise has two, or when a
/// set in the reviewed or the next week has one (the app would see an extra planned session there).
Map<String, num>? _plannedFloors(Map<String, dynamic> s) {
  final weekStart = s['weekStart'] as String;
  final out = <String, num>{};
  for (final x in s['sets'] as List) {
    final f = x['plannedRirMin'];
    if (f == null) continue;
    final day = x['performedOn'] as String;
    if (day.compareTo(weekStart) >= 0 && day.compareTo(ck.addDays(weekStart, 14)) < 0) return null;
    final k = '$day|${x['exerciseId']}';
    if (out[k] != null && out[k] != f) return null;
    out[k] = f as num;
  }
  return out;
}

/// Seeds the app's state with fixture WeeklyState [s].
void _seed(Map<String, dynamic> s) {
  final today = s['today'] as String;
  final weekStart = s['weekStart'] as String;
  fit.coachClock = () => DateTime.parse(today).add(const Duration(hours: 12));
  final block = s['block'] as Map?;
  final startsOn = block?['startsOn'] as String? ?? ck.addDays(weekStart, -14);
  final weeks = block?['weeks'] as int? ?? 8;
  final reviewed = [...s['sessionsThisWeek'] as List, ...s['nextWeekSessions'] as List];
  // A logged set with a planned effort was a planned session of the block: one per day, done.
  final floors = _plannedFloors(s) ?? const {};
  final byDay = <String, List<MapEntry<String, num>>>{};
  for (final e in floors.entries) {
    byDay.putIfAbsent(e.key.split('|').first, () => []).add(MapEntry(e.key.split('|').last, e.value));
  }
  final sessions = [
    for (final e in byDay.entries)
      {
        'date': e.key,
        'status': 'done',
        'templateKey': 'history',
        'exercises': [
          for (final x in e.value) {'exerciseId': x.key, 'sets': 3, 'rirMin': x.value, 'rirMax': x.value + 2},
        ],
      },
    ...reviewed,
  ];
  final templates = {for (final x in sessions) x['templateKey'] as String};
  final routineIds = {for (final k in templates) k: fit.createRoutine(k)};
  final targets = (s['targets'] as Map?) ?? const {};
  fit.coach = CoachData.fromJson({
    'on': {'progression': true, 'plan': true, 'recovery': true},
    'profile': {
      'goal': s['goal'],
      'status': s['status'],
      'days': s['availableDays'] ?? [1, 3, 5],
      'minutes': 60,
      'priority': 'lifting',
      'lifestyle': 'lightly_active',
    },
    'injuries': [
      for (final i in (s['injuries'] as List?) ?? const [])
        {...i, 'avoidExerciseIds': [for (final x in i['avoidExerciseIds'] as List) _bySlug[x] ?? x]},
    ],
    'disliked': [for (final x in (s['dislikedExerciseIds'] as List?) ?? const []) _bySlug[x] ?? x],
    'soreness': {
      for (final c in s['checkins'] as List)
        if ((c['soreness'] as Map).isNotEmpty) c['day']: c['soreness'],
    },
    'block': {
      'kind': block?['kind'] ?? 'hypertrophy',
      'startsOn': startsOn,
      'weeks': weeks,
      'introWeek': false,
      'splitKey': 'test',
      'liftDays': templates.length,
      'engineVersion': 'test',
      'schedule': {'placements': [], 'score': 0, 'penalties': []},
      'targets': [],
      'weeklyTargets': [
        for (var w = 0; w < weeks; w++)
          for (final e in targets.entries) {'weekIndex': w, 'muscle': e.key, 'targetSets': e.value, 'sportTrim': 0},
      ],
      'sessions': [
        for (final (i, x) in sessions.indexed)
          {
            'date': x['date'],
            'weekIndex': 0,
            'templateKey': x['templateKey'],
            'title': x['templateKey'],
            'kind': x['kind'] ?? 'lift',
            'orderInWeek': i,
            'estMinutes': 60,
            'exercises': [
              for (final (j, e) in (x['exercises'] as List).indexed)
                {
                  'exerciseId': _bySlug[e['exerciseId']],
                  'slotKey': 'slot$j',
                  'position': j,
                  'sets': e['sets'],
                  'repMin': e['repMin'] ?? 8,
                  'repMax': e['repMax'] ?? 12,
                  'rirMin': e['rirMin'],
                  'rirMax': e['rirMax'],
                  'restSeconds': 90,
                  'ruleIds': [],
                },
            ],
            if (x['status'] == 'skipped') 'status': 'skipped',
          },
      ],
      'selections': {},
      'warnings': [],
      'explanations': [],
      'hardSessionsPerWeek': 0,
    },
    'routineIds': routineIds,
    'review': {
      'lastWeekStart': ck.addDays(weekStart, -7),
      'askFirst': true,
      'previousYesCount': ?s['previousYesCount'],
      if (s['statusHistory'] case final List h when h.isNotEmpty) 'lastInference': h.last,
    },
  });
  // Done sessions: a workout of the routine on the day.
  for (final x in sessions) {
    if (x['status'] == 'done') {
      fit.sessions.add(LoggedSession(DateTime.parse(x['date'] as String).add(const Duration(hours: 18)), 3600, [],
          routineId: routineIds[x['templateKey']]));
    }
  }
  // Logged sets, one workout per day and session id.
  final byWorkout = <String, List<Map>>{};
  for (final x in s['sets'] as List) {
    byWorkout.putIfAbsent('${x['performedOn']}|${x['sessionId']}', () => []).add(x as Map);
  }
  var hour = 6;
  for (final e in byWorkout.entries) {
    final day = e.key.split('|').first;
    final byEx = <String, List<Map>>{};
    for (final x in e.value) {
      byEx.putIfAbsent(x['exerciseId'] as String, () => []).add(x);
    }
    fit.sessions.add(LoggedSession(DateTime.parse(day).add(Duration(hours: hour++ % 12 + 6)), 3600, [
      for (final x in byEx.entries)
        () {
          final id = _bySlug[x.key]!;
          final ex = fit.exerciseById(id)!;
          final sets = [...x.value]..sort((a, b) => (a['setIndex'] as int) - (b['setIndex'] as int));
          return LoggedExercise(id, ex.name, ex.primary, [
            for (final st in sets)
              LoggedSet(st['reps'] as int, (st['loadKg'] as num?)?.toDouble() ?? 0,
                  kind: st['isWarmup'] == true ? SetKind.warmup : SetKind.normal,
                  rpe: st['rir'] == null ? null : 10 - (st['rir'] as num).toDouble()),
          ]);
        }(),
    ]));
  }
  // Check-ins: sleep from Health Connect, energy from a rated workout.
  final sleep = <String, List<double>>{};
  for (final c in s['checkins'] as List) {
    final day = c['day'] as String;
    if (c['sleepHours'] case final num h) sleep[HealthMetrics.dayKey(DateTime.parse(day))] = [h * 60.0];
    if (c['energy'] case final int e) {
      fit.sessions.add(LoggedSession(DateTime.parse(day).add(const Duration(hours: 22)), 0, [], energy: e));
    }
  }
  fit.healthByDay[HealthMetric.sleep] = sleep;
  fit.sessions.sort((a, b) => a.date.compareTo(b.date));
}

/// [v] with the app's exercise ids turned back into the coach's slugs, and the block's id into [blockId].
Object? _slugs(Object? v, String? blockId) => switch (v) {
      final Map m => {for (final e in m.entries) e.key: _slugs(e.value, blockId)},
      final List l => [for (final x in l) _slugs(x, blockId)],
      final String s when _toSlug.containsKey(s) => _toSlug[s],
      final String s when blockId != null && s.startsWith('block-') => blockId,
      _ => v,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.init();
    fit.resetAllData();
    fit.onboarded = true;
  });

  tearDown(() => fit.coachClock = DateTime.now);

  group('weekly review fixtures through fit', () {
    final ran = <String>[];
    final left = <String, String>{};
    for (final c in _cases('weekly_review.json', 'weeklyReview')) {
      test(c['name'], () {
        final state = expandSeedless(c['input']['state'] as Map<String, dynamic>);
        final out = c['output'] as Map<String, dynamic>;
        final why = _unfit(state, out);
        if (why != null) {
          left[c['name'] as String] = why;
          return;
        }
        if (CoachFacade.reviewWeekFor(DateTime.parse(state['today'] as String)) != state['weekStart']) {
          left[c['name'] as String] = 'the app reviews another week on that day';
          return;
        }
        _seed(state);
        fit.coachTick();
        final got = [
          for (final p in fit.coachProposals)
            if (_weeklyKinds.contains(p.kind.wire))
              {'kind': p.kind.wire, 'payload': _slugs(p.payload, (state['block'] as Map?)?['id'] as String?),
                'appliesFrom': p.record['appliesFrom'], 'expiresOn': p.expiresOn},
        ];
        final want = [
          for (final p in out['proposals'] as List)
            {'kind': p['kind'], 'payload': p['payload'], 'appliesFrom': p['appliesFrom'], 'expiresOn': p['expiresOn']},
        ];
        expect(jsonEncode(got), jsonEncode(want));
        expect(fit.coach.review['previousYesCount'], out['yesCount']);
        expect(fit.coach.review['lastInference'], (out['inference'] as Map)['status']);
        ran.add(c['name'] as String);
      });
    }
    test('most cases ran', () {
      // ignore: avoid_print
      print('ran ${ran.length}, left out ${left.length}: $left');
      expect(ran.length, greaterThanOrEqualTo(30));
    });
  });

  group('the tick', () {
    void arrange() {
      _seed({
        'today': '2026-10-25',
        'weekStart': '2026-10-19',
        'checkins': [],
        'sessionsThisWeek': [],
        'nextWeekSessions': [
          {
            'id': 's0',
            'date': '2026-10-26',
            'status': 'planned',
            'templateKey': 'upper_a',
            'exercises': [
              {'id': 'e', 'exerciseId': 'bench-press', 'sets': 4, 'rirMin': 1, 'rirMax': 3},
            ],
          },
        ],
        'sets': [],
        'mainLiftExerciseIds': [],
        'status': 'intermediate',
        'goal': 'lean_gain',
      });
    }

    test('the first run only sets the week; a second run in the same week does nothing', () {
      arrange();
      fit.coach = fit.coach.copyWith(review: {'askFirst': true});
      fit.coachTick();
      expect(fit.coach.review['lastWeekStart'], '2026-10-19');
      expect(fit.coach.proposals, isEmpty);
      final json = jsonEncode(fit.coach.toJson());
      fit.coachTick();
      expect(jsonEncode(fit.coach.toJson()), json);
    });

    test('a pending or recently dismissed proposal is not made again', () {
      arrange();
      for (var d = 19; d < 26; d++) {
        fit.setCoachSoreness(CoachArea.chest, CoachSoreness.pain, day: DateTime(2026, 10, d));
      }
      fit.coachTick();
      final first = fit.coachProposals.where((p) => p.kind == CoachProposalKind.targetedDeload).toList();
      expect(first, isNotEmpty);
      fit.coach = fit.coach.copyWith(review: {...fit.coach.review, 'lastWeekStart': '2026-10-12'});
      fit.coachTick();
      expect(fit.coachProposals.where((p) => p.kind == CoachProposalKind.targetedDeload), hasLength(first.length));
      for (final p in first) {
        fit.dismissCoachProposal(p.id);
      }
      fit.coach = fit.coach.copyWith(review: {...fit.coach.review, 'lastWeekStart': '2026-10-12'});
      fit.coachTick();
      expect(fit.coachProposals.where((p) => p.kind == CoachProposalKind.targetedDeload), hasLength(first.length));
    });

    test('runs at the end of loading, and does nothing while the recovery module is off', () {
      arrange();
      fit.setCoachModule(CoachModule.recovery, false);
      fit.coach = fit.coach.copyWith(review: {'askFirst': true});
      fit.persistNow();
      fit.loadFromStore();
      expect(fit.coach.review.containsKey('lastWeekStart'), isFalse);
      fit.setCoachModule(CoachModule.recovery, true);
      fit.persistNow();
      fit.loadFromStore();
      expect(fit.coach.review['lastWeekStart'], '2026-10-19');
    });

    test('a pending proposal past its last day is put aside', () {
      arrange();
      fit.coach = fit.coach.copyWith(proposals: [
        {'id': 'p1', 'kind': 'plan_regenerate', 'state': 'pending', 'createdOn': '2026-10-10',
          'expiresOn': '2026-10-17', 'payload': {'reason': 'x'}},
      ]);
      fit.coachTick();
      expect(fit.coachProposals.firstWhere((p) => p.id == 'p1').state, CoachProposalState.dismissed);
    });
  });
}

/// The fixture state with the seed library marker left as it is: the app brings its own exercises.
Map<String, dynamic> expandSeedless(Map<String, dynamic> s) => s;
