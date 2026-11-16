// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_training/coach_training.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

Region _region(Object? wire) => Region.fromWire(wire as String);

Object? _call(Map<String, dynamic> i) {
  switch (i['call'] as String) {
    case 'constants':
      return {
        'TEMPLATES': {for (final e in TEMPLATES.entries) e.key: e.value.toJson()},
        'SPLITS': {for (final e in SPLITS.entries) e.key: e.value.toJson()},
      };
    case 'chooseSplit':
      return chooseSplit(i['k'] as int, ChooseSplitOptions.fromJson(i['opts'] as Map<String, dynamic>)).toJson();
    case 'sessionVariant':
      return sessionVariant([for (final t in i['templates'] as List) t as String], i['index'] as int).wire;
    case 'templateRegionMuscles':
      return [for (final m in templateRegionMuscles(_region(i['region']))) m.wire];
    case 'loadsLower':
      return loadsLower(_region(i['region']));
    case 'regionsOverlap':
      return regionsOverlap(_region(i['a']), _region(i['b']));
    default:
      fail('Unknown call ${i['call']}');
  }
}

/// The types are persisted by the app: their JSON form must read back unchanged.
String? _roundTrip(Map<String, dynamic> i, Object? output) {
  Map<String, dynamic> m(Object? x) => x as Map<String, dynamic>;
  return switch (i['call']) {
    'constants' => jsonDiff({
      for (final e in m(m(output)['TEMPLATES']).entries) e.key: Template.fromJson(m(e.value)).toJson(),
    }, m(output)['TEMPLATES']),
    'chooseSplit' =>
      jsonDiff(ChooseSplitOptions.fromJson(m(i['opts'])).toJson(), i['opts']) ??
          jsonDiff(SplitChoice.fromJson(m(output)).toJson(), output),
    _ => null,
  };
}

void main() {
  for (final c in loadFixture('split.json', fn: 'split')) {
    test(c.name, () {
      expect(jsonDiff(_call(c.input), c.output), isNull);
      expect(_roundTrip(c.input, c.output), isNull);
    });
  }
}
