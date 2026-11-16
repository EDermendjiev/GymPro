// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:io';

import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymmane/coach/model/coach_data.dart';
import 'package:gymmane/coach/model/coach_profile.dart';

Map<String, dynamic> _full() =>
    (jsonDecode(File('test/coach/data/coach_full.json').readAsStringSync()) as Map).cast<String, dynamic>();

Object? _roundTrip(Map<String, dynamic> json) => jsonDecode(jsonEncode(CoachData.fromJson(json).toJson()));

void main() {
  group('empty', () {
    test('no data is the empty, all-off state', () {
      final c = CoachData.fromJson(null);
      expect(c.isEmpty, isTrue);
      for (final m in CoachModule.values) {
        expect(c.isOn(m), isFalse, reason: m.name);
      }
      expect(c.profile, isNull);
      expect(c.block, isNull);
    });

    test('an empty map is empty too', () {
      expect(CoachData.fromJson(const {}).isEmpty, isTrue);
      expect(CoachData.empty().isEmpty, isTrue);
    });

    test('switching a module on makes it non-empty, switching it back off makes it empty again', () {
      final on = CoachData.empty().withModule(CoachModule.nutrition, true);
      expect(on.isEmpty, isFalse);
      expect(on.withModule(CoachModule.nutrition, false).isEmpty, isTrue);
    });
  });

  group('round trip', () {
    test('every key of the persisted shape survives fromJson and toJson unchanged', () {
      final json = _full();
      expect(_roundTrip(json), json);
    });

    test('the typed parts are read', () {
      final c = CoachData.fromJson(_full());
      expect(c.version, 1);
      expect([for (final m in CoachModule.values) c.isOn(m)], [true, true, true, false]);
      expect(c.profile!.goal, ck.Goal.leanGain);
      expect(c.profile!.status, ck.Status.intermediate);
      expect(c.profile!.days, [1, 2, 4, 5]);
      expect(c.profile!.minutes, 60);
      expect(c.profile!.priority, ck.Priority.lifting);
      expect(c.profile!.lifestyle, ck.Lifestyle.lightlyActive);
      expect(c.profile!.maxLiftDays, isNull);
      expect(c.block!.splitKey, isNotEmpty);
      expect(c.sports.single.sportId, 'football');
      expect(c.injuries.single.muscleId, ck.MuscleId.hamstrings);
      expect(c.disliked, ['abc123']);
      expect(c.routineIds, isNotEmpty);
      expect(c.proposals, hasLength(1));
      expect(c.proposals.single['kind'], 'standard_deload');
    });

    test('keys this version does not know are kept and written back, at every level it owns', () {
      final json = _full()
        ..['futureThing'] = {'a': 1, 'b': [1, 2, 3]}
        ..['v'] = 3;
      (json['on'] as Map)['mobility'] = true;
      (json['profile'] as Map)['sleepHours'] = 7.5;
      expect(_roundTrip(json), json);
    });

    test('a value it cannot read is kept as it was, and the rest still loads', () {
      final json = _full()
        ..['block'] = {'kind': 'not-a-kind'}
        ..['sports'] = 'nonsense';
      final c = CoachData.fromJson(json);
      expect(c.block, isNull);
      expect(c.sports, isEmpty);
      expect(c.isOn(CoachModule.plan), isTrue);
      expect(_roundTrip(json), json);
    });

    test('replacing an unreadable value drops the old one', () {
      final json = _full()..['block'] = {'kind': 'not-a-kind'};
      final block = CoachData.fromJson(_full()).block!;
      final fixed = CoachData.fromJson(json).copyWith(block: block);
      expect(fixed.toJson()['block'], _full()['block']);
    });

    test('maps that went through a JSON decode with dynamic keys and values still load', () {
      final loose = jsonDecode(jsonEncode(_full())) as Map;
      expect(CoachData.fromJson(Map<String, dynamic>.from(loose)).block, isNotNull);
    });
  });

  group('never throws', () {
    for (final (name, raw) in [
      ('a string', 'nope'),
      ('a list', [1, 2]),
      ('a number', 4),
      ('switches that are not a map', {'on': 'all'}),
      ('a switch that is not a bool', {'on': {'plan': 'yes'}}),
      ('a profile with a wrong goal', {'profile': {'goal': 'giant', 'status': 'novice'}}),
      ('a profile that is a list', {'profile': []}),
      ('a version that is text', {'v': 'one'}),
      ('nested nulls', {'block': null, 'profile': null, 'proposals': null, 'on': null}),
      ('proposals with junk in them', {'proposals': [1, 'x', null, {'id': 'p1'}]}),
      ('routine ids that are not text', {'routineIds': {'a': 1}}),
    ]) {
      test(name, () {
        late CoachData c;
        expect(() => c = CoachData.fromJson(raw is Map ? raw.cast<String, dynamic>() : null), returnsNormally);
        expect(() => jsonEncode(c.toJson()), returnsNormally);
      });
    }

    test('a switch that is not a bool counts as off', () {
      expect(CoachData.fromJson({'on': {'plan': 'yes', 'progression': true}}).isOn(CoachModule.plan), isFalse);
    });

    test('proposals keep only the entries that are maps', () {
      final c = CoachData.fromJson({'proposals': [1, 'x', null, {'id': 'p1'}]});
      expect(c.proposals, [
        {'id': 'p1'},
      ]);
    });
  });

  group('switches', () {
    CoachData all() {
      var c = CoachData.empty();
      for (final m in CoachModule.values) {
        c = c.withModule(m, true);
      }
      return c;
    }

    test('the prerequisites are the documented ones', () {
      expect(CoachModule.progression.needs, isNull);
      expect(CoachModule.plan.needs, CoachModule.progression);
      expect(CoachModule.recovery.needs, CoachModule.plan);
      expect(CoachModule.nutrition.needs, isNull);
    });

    test('a module cannot be switched on while its prerequisite is off', () {
      final c = CoachData.empty();
      expect(c.withModule(CoachModule.plan, true).isOn(CoachModule.plan), isFalse);
      expect(c.withModule(CoachModule.recovery, true).isOn(CoachModule.recovery), isFalse);
      expect(c.canSwitchOn(CoachModule.plan), isFalse);
      expect(c.withModule(CoachModule.progression, true).canSwitchOn(CoachModule.plan), isTrue);
    });

    test('turning progression off turns plan and recovery off, and leaves nutrition alone', () {
      final c = all().withModule(CoachModule.progression, false);
      expect([for (final m in CoachModule.values) c.isOn(m)], [false, false, false, true]);
    });

    test('turning plan off turns recovery off', () {
      final c = all().withModule(CoachModule.plan, false);
      expect([for (final m in CoachModule.values) c.isOn(m)], [true, false, false, true]);
    });

    test('a stored state that breaks the rule is read as if the rule held', () {
      final c = CoachData.fromJson({
        'on': {'progression': false, 'plan': true, 'recovery': true, 'nutrition': false},
      });
      expect([for (final m in CoachModule.values) c.isOn(m)], [false, false, false, false]);
    });

    test('the switches are written as one bool per module', () {
      final json = CoachData.empty().withModule(CoachModule.progression, true).toJson();
      expect(json['v'], 1);
      expect(json['on'], {'progression': true, 'plan': false, 'recovery': false, 'nutrition': false});
    });
  });

  group('profile', () {
    test('round trips on its own and through the data', () {
      final p = CoachProfile(
        goal: ck.Goal.strength,
        status: ck.Status.novice,
        days: const [1, 3, 5],
        minutes: 45,
        priority: ck.Priority.balanced,
        lifestyle: ck.Lifestyle.active,
        maxLiftDays: 3,
      );
      expect(CoachProfile.fromJson(p.toJson()).toJson(), p.toJson());
      final c = CoachData.empty().copyWith(profile: p);
      expect(CoachData.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>).profile!.toJson(),
          p.toJson());
    });
  });
}
