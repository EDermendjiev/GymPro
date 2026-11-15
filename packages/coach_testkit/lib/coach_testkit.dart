// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

class FixtureCase {
  FixtureCase(this.name, this.input, this.output);
  final String name;
  final Map<String, dynamic> input;
  final Object? output;
}

/// Reads `<root>/<file>`, by default `test/fixtures/<file>` relative to the package under test.
///
/// The file is UTF-8 JSON shaped `{ "fn": string, "cases": [{ "name", "input", "output" }] }`. Every
/// case must have all three keys; an `output` of null is allowed. Pass [fn] to check that the file
/// was generated from the function under test.
///
/// Throws a [StateError] when the file is missing and a [FormatException] when it has another shape,
/// no case at all, two cases with the same name, or an `fn` other than [fn].
///
/// Convention: give each case its own test, so that a failure names the case:
///
/// ```dart
/// for (final c in loadFixture('add.json', fn: 'add')) {
///   test(c.name, () => expect(jsonDiff(add(c.input), c.output), isNull));
/// }
/// ```
List<FixtureCase> loadFixture(String file, {String root = 'test/fixtures', String? fn}) {
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
  if (raw is! Map<String, dynamic>) bad('must be an object with a string "fn"');
  final actualFn = raw['fn'];
  if (actualFn is! String) bad('must be an object with a string "fn"');
  if (fn != null && actualFn != fn) bad('is for "$actualFn", not for "$fn"');
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
    if (!c.containsKey('output')) bad('case "$name" must have an "output" key (its value may be null)');
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

/// First difference between [actual] and the decoded JSON value [expected], or null when they match.
///
/// The message starts with the JSON path of the difference, followed by `actual != expected`. A map
/// key that is not a plain identifier is written `["key"]`, so that `$["a.b"]` and `$.a.b` stay
/// apart. Map keys are visited in the order of [expected], then the extra keys of [actual]. When two
/// lists differ in length, the message adds their first difference. A printed value is cut after
/// 120 characters.
///
/// Only JSON values match: null, booleans, numbers, strings, lists, and maps with string keys.
/// Anything else in [actual] (an enum value, a `DateTime`, a `Set`, any other object) is a
/// difference whatever its `==` says, and is printed with its runtime type. Convert such values to
/// JSON before comparing.
///
/// A missing key equals null, because the fixture generator drops undefined keys when it serialises.
///
/// Two ints compare exactly. Any other pair of numbers matches when the two are at most 1e-9 apart,
/// so 3 equals 3.0. That tolerance is absolute, which gives it two limits:
///
/// * Below about 1e-9 it hides everything: 4e-10 matches 0, and it matches 8e-10 too.
/// * From 2^23 (about 8.4 million) up, neighbouring doubles are further apart than 1e-9, so the
///   comparison is exact there and a result that is off by one rounding step is a difference.
///
/// Both are fine for values of ordinary size (loads, repetitions, calories, grams).
/// NaN never matches anything, itself included, and an infinity matches only itself.
String? jsonDiff(Object? actual, Object? expected, [String path = r'$']) {
  if (actual is num && expected is num) {
    return _sameNumber(actual, expected) ? null : '$path: ${_show(actual)} != ${_show(expected)}';
  }
  if (actual is Map && expected is Map) {
    for (final k in {...expected.keys, ...actual.keys}) {
      if (k is! String) return '$path: key ${_show(k, typed: true)} is not a string';
      final d = jsonDiff(
        actual[k],
        expected[k],
        _plainKey.hasMatch(k) ? '$path.$k' : '$path[${jsonEncode(k)}]',
      );
      if (d != null) return d;
    }
    return null;
  }
  if (actual is List && expected is List) {
    final shared = math.min(actual.length, expected.length);
    String? first;
    for (var i = 0; i < shared && first == null; i++) {
      first = jsonDiff(actual[i], expected[i], '$path[$i]');
    }
    if (actual.length == expected.length) return first;
    first ??= actual.length > shared
        ? '$path[$shared]: ${_show(actual[shared])} != nothing'
        : '$path[$shared]: nothing != ${_show(expected[shared])}';
    return '$path: length ${actual.length} != ${expected.length}; first difference at $first';
  }
  // The == of [actual] is not trusted: only these three kinds of leaf can be equal.
  final same =
      (actual == null && expected == null) ||
      (actual is String && expected is String && actual == expected) ||
      (actual is bool && expected is bool && actual == expected);
  if (same) return null;
  final a = _show(actual);
  final e = _show(expected);
  final message = '$path: $a != $e';
  // Only a cut value is longer than the limit. Two cut strings can look the same in the message.
  if (actual is String && expected is String && (a.length > _maxShown || e.length > _maxShown)) {
    var i = 0;
    while (i < actual.length && i < expected.length && actual[i] == expected[i]) {
      i++;
    }
    return '$message (the strings differ from character $i)';
  }
  return message;
}

const _maxShown = 120;
final _plainKey = RegExp(r'^[A-Za-z_]\w*$');

bool _sameNumber(num a, num b) {
  // Exact, because the difference of two ints can wrap around.
  if (a is int && b is int) return a == b;
  if (a.isNaN || b.isNaN) return false;
  if (a.isInfinite || b.isInfinite) return a == b;
  return (a - b).abs() <= 1e-9;
}

/// Strings are quoted so that `"1"` and `1` look different in a message, a value that is not JSON
/// is followed by its runtime type, and a long value is cut.
String _show(Object? value, {bool typed = false}) {
  final isJson =
      value == null || value is bool || value is num || value is String || value is List || value is Map;
  final text = value is String ? jsonEncode(value) : '$value';
  final shown = text.length > _maxShown ? '${text.substring(0, _maxShown)}…' : text;
  return isJson && !typed ? shown : '$shown (${value.runtimeType})';
}
