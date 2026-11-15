// SPDX-License-Identifier: GPL-3.0-only

/// Guards for the `lib` directory of a coach package. Each coach package has a short test that calls
/// the three of them on `Directory('lib')` and expects no finding.
///
/// The guards read whole lines, comments and strings included, so a finding in a comment is fixed
/// by rewording the comment. Each guard also reports a missing `lib`, a `lib` without any Dart file,
/// and every file that is not a `.dart` file, so that none of them can pass by having nothing to read.
library;

import 'dart:io';

/// The first line of every source file.
const licenceLine = '// SPDX-License-Identifier: GPL-3.0-only';

/// Anything that makes a result depend on the platform, the clock, the local time zone or chance, or
/// that writes to the console.
final _impure = [
  // Of the SDK, only these five libraries.
  RegExp(r'\bdart:(?!(?:core|math|convert|collection|typed_data)\b)\w*'),
  // Of the packages, only the sibling coach packages, the testkit excluded.
  RegExp(r'\bpackage:(?!coach_(?!testkit\b)\w+)[\w./]*'),
  RegExp(r'\bDateTime\.(?:now|timestamp)\b'),
  RegExp(r'\b(?:Stopwatch|Random)\b'),
  RegExp(r'\bPlatform\.'),
  RegExp(r'\b(?:stdout|stderr)\b'),
  RegExp(r'\bprint\b'),
  // Without an argument, shuffle draws from a new random source.
  RegExp(r'\.shuffle\(\s*\)'),
  // Local time: the unnamed constructor (DateTime.utc is the one to use) and the zone accessors.
  RegExp(r'\bDateTime(?:\(|\.new\b)'),
  RegExp(r'\.toLocal\('),
  RegExp(r'\b(?:timeZoneOffset|timeZoneName)\b'),
];

/// References to where a rule comes from.
final _cited = [
  RegExp(r'pyramid', caseSensitive: false),
  RegExp(r'\bMSP-', caseSensitive: false),
  RegExp(r'\bappendi(?:x|ces)\b', caseSensitive: false),
  RegExp(r'\b(?:section|chapter)\s+\d+', caseSensitive: false),
  RegExp(r'\b(?:sect|ch|pg|pp?)\.\s*\d+', caseSensitive: false),
  RegExp(r'\bpages?\s+\d+', caseSensitive: false),
  RegExp(r'§'),
  RegExp(r'\bdecisions\.md\b', caseSensitive: false),
  // Upper case only: the ordinary word is fine.
  RegExp(r'\bDECISIONS\b'),
];

/// Uses of the platform, the clock, the local time zone, chance or the console under [lib], each as
/// `path:line: matched text`.
///
/// Allowed imports are relative ones, `dart:core`, `dart:math`, `dart:convert`, `dart:collection`,
/// `dart:typed_data`, and `package:coach_*` other than `package:coach_testkit`.
List<String> impurities(Directory lib) => _matches(lib, _impure);

/// References to the origin of a rule under [lib], each as `path:line: matched text`.
List<String> citations(Directory lib) => _matches(lib, _cited);

/// The Dart files under [lib] whose first line is not [licenceLine], each as `path:1: first line`.
List<String> unlicensed(Directory lib) {
  final (:sources, :findings) = _read(lib);
  for (final MapEntry(key: path, value: lines) in sources.entries) {
    if (lines.firstOrNull == licenceLine) continue;
    final first = lines.firstOrNull;
    findings.add('$path:1: ${first == null ? '(empty file)' : (first.isEmpty ? '(blank line)' : first)}');
  }
  return findings;
}

/// Every match of [banned] under [lib].
List<String> _matches(Directory lib, List<RegExp> banned) {
  final (:sources, :findings) = _read(lib);
  for (final MapEntry(key: path, value: lines) in sources.entries) {
    for (final (i, line) in lines.indexed) {
      for (final pattern in banned) {
        for (final m in pattern.allMatches(line)) {
          findings.add('$path:${i + 1}: ${m[0]}');
        }
      }
    }
  }
  return findings;
}

/// The lines of each Dart file under [lib], in path order, and what is wrong with the directory
/// itself. Paths are written with forward slashes on every platform.
({Map<String, List<String>> sources, List<String> findings}) _read(Directory lib) {
  String slashed(String path) => path.replaceAll(r'\', '/');

  if (!lib.existsSync()) return (sources: {}, findings: ['${slashed(lib.path)}: directory not found']);
  final files = lib.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => slashed(a.path).compareTo(slashed(b.path)));
  final sources = <String, List<String>>{};
  final findings = <String>[];
  for (final f in files) {
    if (f.path.endsWith('.dart')) {
      sources[slashed(f.path)] = f.readAsLinesSync();
    } else {
      findings.add('${slashed(f.path)}: not a Dart file');
    }
  }
  if (sources.isEmpty) findings.add('${slashed(lib.path)}: no Dart file to check');
  return (sources: sources, findings: findings);
}
