// SPDX-License-Identifier: GPL-3.0-only

// Guards shared by every coach package. The file is the same in each of them: it checks the `lib`
// directory of whichever package it runs in, and scans whole lines, comments and strings included.
import 'dart:io';

import 'package:test/test.dart';

const _licence = '// SPDX-License-Identifier: GPL-3.0-only';

/// Anything that makes a result depend on the platform, the time or chance, or that writes to the console.
final _impure = [
  // Only these core libraries are allowed.
  RegExp(r'\bdart:(?!(core|math|convert|collection|typed_data)\b)\w+'),
  RegExp(r'\bpackage:flutter\w*'),
  RegExp(r'\bDateTime\.(now|timestamp)\b'),
  RegExp(r'\b(Stopwatch|Random)\b'),
  RegExp(r'\bPlatform\.'),
  RegExp(r'\b(stdout|stderr)\b'),
  RegExp(r'\bprint\('),
];

final _citations = [
  RegExp(
    r'pyramid|\bMSP-|\bappendi(x|ces)\b|\b(section|chapter) \d|\bpp?\.\s?\d|\bpages? \d|\bdecisions\.md\b',
    caseSensitive: false,
  ),
  // Upper case only: the ordinary word is fine.
  RegExp(r'\bDECISIONS\b'),
];

/// The Dart files under `lib`. Fails when there is none, so that no guard passes on an empty package.
List<File> _sources() {
  final lib = Directory('lib');
  final files = lib.existsSync()
      ? lib.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
      : <File>[];
  if (files.isEmpty) fail('No Dart file under ${lib.absolute.path}: there is nothing to check.');
  return files..sort((a, b) => a.path.compareTo(b.path));
}

/// Every match of [banned] in the sources, as `path:line: matched text`.
List<String> _matches(List<RegExp> banned) => [
  for (final f in _sources())
    for (final (i, line) in f.readAsLinesSync().indexed)
      for (final pattern in banned)
        for (final m in pattern.allMatches(line)) '${f.path}:${i + 1}: ${m[0]}',
];

void main() {
  test('lib has no platform, clock, randomness or console dependency', () {
    expect(_matches(_impure), isEmpty);
  });

  test('lib carries no source citations', () {
    expect(_matches(_citations), isEmpty);
  });

  test('every source file declares the licence', () {
    final missing = [
      for (final f in _sources())
        if (f.readAsLinesSync().firstOrNull != _licence) f.path,
    ];
    expect(missing, isEmpty, reason: 'The first line must be exactly "$_licence".');
  });
}
