// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:io';

class FixtureCase {
  FixtureCase(this.name, this.input, this.output);
  final String name;
  final Map<String, dynamic> input;
  final Object? output;
}

/// Reads `<root>/<file>`, by default `test/fixtures/<file>` relative to the package under test.
///
/// The file is UTF-8 JSON shaped `{ "fn": string, "cases": [{ "name", "input", "output" }] }`. A case
/// without an `output` key has a null output, because the original implementation drops undefined
/// keys when it serialises. Throws a [StateError] when the file is missing and a [FormatException]
/// when it has another shape, no case at all, or two cases with the same name.
List<FixtureCase> loadFixture(String file, {String root = 'test/fixtures'}) {
  final path = '$root/$file';
  Never bad(String what) => throw FormatException('Fixture $path $what');

  final source = File(path);
  if (!source.existsSync()) {
    throw StateError('Fixture $path not found (working directory: ${Directory.current.path})');
  }
  final Object? raw;
  try {
    raw = jsonDecode(utf8.decode(source.readAsBytesSync()));
  } on FormatException catch (e) {
    bad('is not UTF-8 encoded JSON: ${e.message}');
  }
  if (raw is! Map<String, dynamic> || raw['fn'] is! String) bad('must be an object with a string "fn"');
  final cases = raw['cases'];
  if (cases is! List || cases.isEmpty) bad('must have a non-empty "cases" list');

  final names = <String>{};
  final result = <FixtureCase>[];
  for (final (i, c) in cases.indexed) {
    if (c is! Map<String, dynamic>) bad('case $i must be an object');
    final name = c['name'];
    final input = c['input'];
    if (name is! String) bad('case $i must have a string "name"');
    if (input is! Map<String, dynamic>) bad('case "$name" must have an object "input"');
    if (!names.add(name)) bad('has two cases named "$name"');
    result.add(FixtureCase(name, input, c['output']));
  }
  return result;
}

/// Deep copy of [input] in which every string value exactly equal to `'@seed'` is replaced by [seed].
///
/// Fixture inputs carry this marker in place of the shared exercise library. [seed] itself is not
/// copied: every marker is replaced by the same object.
Object? expandSeed(Object? input, Object? seed) {
  if (input == '@seed') return seed;
  if (input is Map<String, dynamic>) {
    return <String, dynamic>{for (final e in input.entries) e.key: expandSeed(e.value, seed)};
  }
  if (input is Map) return {for (final e in input.entries) e.key: expandSeed(e.value, seed)};
  if (input is List) return [for (final v in input) expandSeed(v, seed)];
  return input;
}

/// First difference between two decoded JSON values, or null when they match.
///
/// The message starts with the JSON path of the difference, followed by `actual != expected`. Map
/// keys are visited in the order of [expected], then the extra keys of [actual].
///
/// Numbers compare with a tolerance (3 equals 3.0) and a missing key equals null,
/// because the original implementation drops undefined keys when it serialises.
/// NaN never matches anything, itself included, and an infinity matches only itself.
String? jsonDiff(Object? actual, Object? expected, [String path = r'$']) {
  if (actual is num && expected is num) {
    return _sameNumber(actual, expected) ? null : '$path: $actual != $expected';
  }
  if (actual is Map && expected is Map) {
    for (final k in {...expected.keys, ...actual.keys}) {
      final d = jsonDiff(actual[k], expected[k], '$path.$k');
      if (d != null) return d;
    }
    return null;
  }
  if (actual is List && expected is List) {
    if (actual.length != expected.length) return '$path: length ${actual.length} != ${expected.length}';
    for (var i = 0; i < actual.length; i++) {
      final d = jsonDiff(actual[i], expected[i], '$path[$i]');
      if (d != null) return d;
    }
    return null;
  }
  return actual == expected ? null : '$path: ${_show(actual)} != ${_show(expected)}';
}

bool _sameNumber(num a, num b) {
  if (a.isNaN || b.isNaN) return false;
  if (a.isInfinite || b.isInfinite) return a == b;
  return (a - b).abs() <= 1e-9;
}

/// Strings are quoted so that `"1"` and `1` look different in a message.
String _show(Object? value) => value is String ? jsonEncode(value) : '$value';
