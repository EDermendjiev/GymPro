// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

/// The fixtures store each work exercise by id; the seed library is shipped once in exercises.json.
WorkSession _work(Object? json, Map<String, ExerciseDef> byId) {
  final s = Map<String, dynamic>.of(json as Map<String, dynamic>);
  final exercises = [for (final w in s['exercises'] as List) Map<String, dynamic>.of(w as Map<String, dynamic>)];
  final ids = [for (final w in exercises) w['ex'] as String];
  s['exercises'] = [for (final w in exercises) w..['ex'] = byId[w['ex']]!.toJson()];
  final session = WorkSession.fromJson(s);
  // The same objects as the library, as in the reference.
  session.exercises = [
    for (final (i, w) in session.exercises.indexed) w.copyWith(ex: byId[ids[i]]),
  ];
  return session;
}

Map<String, dynamic> _stored(WorkSession s) {
  final json = s.toJson();
  json['exercises'] = [
    for (final (i, w) in (json['exercises'] as List).indexed) (w as Map<String, dynamic>)..['ex'] = s.exercises[i].ex.id,
  ];
  return json;
}

SelectionContext _ctx(Object? json, List<ExerciseDef> seed) {
  final c = json as Map<String, dynamic>;
  expect(c['exercises'], '@seed');
  final previous = c['previous'] as Map<String, dynamic>?;
  return SelectionContext(
    exercises: seed,
    equipment: [for (final e in c['equipment'] as List) Equipment.fromWire(e as String)],
    injuries: [for (final i in c['injuries'] as List) Injury.fromJson(i as Map<String, dynamic>)],
    disliked: [for (final d in c['disliked'] as List) d as String],
    previous: previous == null ? null : {for (final e in previous.entries) e.key: e.value as String},
    sportPriority: c['sportPriority'] as bool?,
  );
}

Map<MuscleId, double> _muscleMap(Object? json) => {
  for (final e in (json as Map<String, dynamic>).entries) MuscleId.fromWire(e.key): (e.value as num).toDouble(),
};

Object? _call(Map<String, dynamic> i, List<ExerciseDef> seed, Map<String, ExerciseDef> byId) {
  WorkSession session() => _work(i['session'], byId);
  switch (i['call'] as String) {
    case 'distribute':
      final sessions = [for (final s in i['sessions'] as List) _work(s, byId)];
      final r = distribute(sessions, _muscleMap(i['targets']), _ctx(i['ctx'], seed));
      expect(identical(r.sessions, sessions), isTrue);
      return {
        'sessions': [for (final s in r.sessions) _stored(s)],
        'unmet': [for (final m in r.unmet) m.wire],
      };
    case 'estimateMinutes':
      return estimateMinutes(session());
    case 'orderSession':
      return _stored(orderSession(session()));
    case 'sessionMuscleSets':
      return sessionMuscleSets(session(), MuscleId.fromWire(i['muscle'] as String));
    case 'weeklyMuscleSets':
      return weeklyMuscleSets([
        for (final s in i['sessions'] as List) _work(s, byId),
      ], MuscleId.fromWire(i['muscle'] as String));
    case 'constants':
      return {'MAX_SETS_PER_EXERCISE': MAX_SETS_PER_EXERCISE};
    case 'canAddSet':
      return canAddSet(i['current'] as num);
    case 'summaryMuscleSets':
      final items = [for (final x in i['items'] as List) SummaryItem.fromJson(x as Map<String, dynamic>)];
      return {for (final e in loggedSessionMuscleSets(items).entries) e.key.wire: e.value};
    case 'weekTotals':
      return [for (final t in weekTotals(_muscleMap(i['earlier']), _muscleMap(i['session']))) t.toJson()];
    default:
      fail('Unknown call ${i['call']}');
  }
}

void main() {
  final seed = [
    for (final e in loadFixture('exercises.json', root: '../coach_kernel/test/fixtures').single.output as List)
      ExerciseDef.fromJson(e as Map<String, dynamic>),
  ];
  final byId = {for (final e in seed) e.id: e};

  for (final c in loadFixture('distribute.json', fn: 'distribute')) {
    test(c.name, () => expect(jsonDiff(_call(c.input, seed, byId), c.output), isNull));
  }

  test('the work and summary types round-trip', () {
    final c = loadFixture('distribute.json').firstWhere((c) => c.input['call'] == 'orderSession');
    final s = _work(c.input['session'], byId);
    final json = s.toJson();
    expect(jsonDiff(WorkSession.fromJson(json).toJson(), json), isNull);
    final item = loadFixture('distribute.json').lastWhere((c) => c.input['call'] == 'summaryMuscleSets').input['items'] as List;
    for (final x in item) {
      expect(jsonDiff(SummaryItem.fromJson(x as Map<String, dynamic>).toJson(), x), isNull);
    }
    final total = MuscleWeekTotal(muscle: MuscleId.chest, session: 3, week: 9);
    expect(jsonDiff(MuscleWeekTotal.fromJson(total.toJson()).toJson(), total.toJson()), isNull);
    for (final k in WorkKind.values) {
      expect(WorkKind.fromWire(k.wire), k);
    }
    expect(() => WorkKind.fromWire('heavy'), throwsFormatException);
  });
}
