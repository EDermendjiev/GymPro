// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';

import 'package:coach_testkit/purity.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late Directory lib;

  setUp(() {
    root = Directory.systemTemp.createTempSync('coach_purity_');
    lib = Directory('${root.path}/lib')..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  /// Writes `lib/<name>`: the licence line, then [lines]. So the first of [lines] is line 2.
  void source(String name, List<String> lines, {String firstLine = licenceLine}) {
    File('${lib.path}/$name')
      ..createSync(recursive: true)
      ..writeAsStringSync([firstLine, ...lines, ''].join('\n'));
  }

  /// [findings] without the path of the temporary `lib` directory.
  List<String> short(List<String> findings) {
    final prefix = '${lib.path.replaceAll(r'\', '/')}/';
    return [for (final f in findings) f.startsWith(prefix) ? f.substring(prefix.length) : f];
  }

  /// What [guard] finds in a source file made of the licence line and [line].
  List<String> found(List<String> Function(Directory) guard, String line) {
    source('sample.dart', [line]);
    return short(guard(lib));
  }

  group('impurities flags', () {
    // Source line -> the matched texts.
    const samples = <String, List<String>>{
      // Libraries of the SDK other than the five allowed ones.
      "import 'dart:io';": ['dart:io'],
      "import 'dart:async';": ['dart:async'],
      "import 'dart:ui' as ui;": ['dart:ui'],
      "import 'dart:isolate' show Isolate;": ['dart:isolate'],
      "import 'dart:mathematics';": ['dart:mathematics'],
      "import 'dart:core_patch';": ['dart:core_patch'],
      "import 'dart:_internal';": ['dart:_internal'],
      "final uri = 'dart:' + name;": ['dart:'],
      // Packages other than the sibling coach packages.
      "import 'package:flutter/material.dart';": ['package:flutter/material.dart'],
      "import 'package:flutter_test/flutter_test.dart';": ['package:flutter_test/flutter_test.dart'],
      "import 'package:collection/collection.dart';": ['package:collection/collection.dart'],
      "import 'package:test/test.dart';": ['package:test/test.dart'],
      "import 'package:sync/sync.dart';": ['package:sync/sync.dart'],
      "import 'package:coachella/coachella.dart';": ['package:coachella/coachella.dart'],
      "import 'package:coach_testkit/coach_testkit.dart';": ['package:coach_testkit/coach_testkit.dart'],
      "export 'package:coach_testkit/purity.dart';": ['package:coach_testkit/purity.dart'],
      "final uri = 'package:' + name;": ['package:'],
      '// Not package:coach_testkit, which is for tests.': ['package:coach_testkit'],
      // Clock.
      'final t = DateTime.now();': ['DateTime.now'],
      'final t = DateTime.timestamp();': ['DateTime.timestamp'],
      'final clock = DateTime.now;': ['DateTime.now'],
      'final s = Stopwatch()..start();': ['Stopwatch'],
      // Chance.
      'final r = Random(1);': ['Random'],
      'int pick(Random source) => 0;': ['Random'],
      'items.shuffle();': ['.shuffle()'],
      'items.shuffle( );': ['.shuffle( )'],
      // Platform and console.
      'if (Platform.isWindows) return;': ['Platform.'],
      "stdout.writeln('x');": ['stdout'],
      "stderr.writeln('x');": ['stderr'],
      "print('x');": ['print'],
      'items.forEach(print);': ['print'],
      "print ('x');": ['print'],
      // Local time.
      'final d = DateTime(2026, 1, 2);': ['DateTime('],
      'final make = DateTime.new;': ['DateTime.new'],
      'final l = d.toLocal();': ['.toLocal('],
      'final o = d.timeZoneOffset;': ['timeZoneOffset'],
      'final n = d.timeZoneName;': ['timeZoneName'],
      // Comments and strings are scanned too.
      '// Never call DateTime.now() here.': ['DateTime.now'],
      '/// Unlike [Random], this is repeatable.': ['Random'],
      "const hint = 'print the plan';": ['print'],
      // Every match on a line is reported, in the order of the rules.
      'final r = Random(DateTime.now().millisecond); print(r);': ['DateTime.now', 'Random', 'print'],
    };
    for (final MapEntry(key: line, value: matches) in samples.entries) {
      test(line, () {
        expect(found(impurities, line), [for (final m in matches) 'sample.dart:2: $m']);
      });
    }
  });

  group('impurities allows', () {
    const samples = [
      "import 'dart:core';",
      "import 'dart:math' as math;",
      "import 'dart:math';",
      "import 'dart:convert' show jsonEncode;",
      "import 'dart:collection';",
      "import 'dart:typed_data';",
      "import 'package:coach_kernel/coach_kernel.dart';",
      "import 'package:coach_progression/src/load.dart';",
      "export 'package:coach_training/coach_training.dart' show generateBlock;",
      "import 'package:coach_testkit_data/data.dart';",
      '// Built on package:coach_kernel.',
      "import 'src/dates.dart';",
      "import '../rules.dart';",
      'final d = DateTime.utc(2026, 1, 2);',
      'final d = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);',
      'final u = d.toUtc();',
      'final d = UtcDateTime(2026);',
      'final zone = timeZone;',
      'final blueprint = fingerprint(printed);',
      'reprint();',
      'items.shuffle(source);',
      'final shuffled = shuffle(items, seed);',
      'final randomized = randomOrder;',
      'final platform = Platforms.all;',
      'final stdoutput = stderrors;',
      'final stopwatches = 2;',
      '// Dates are plain calendar days in UTC.',
    ];
    for (final line in samples) {
      test(line, () => expect(found(impurities, line), isEmpty));
    }
  });

  group('citations flags', () {
    const samples = <String, List<String>>{
      '// The pyramid model.': ['pyramid'],
      '// Pyramid levels.': ['Pyramid'],
      '// PYRAMID': ['PYRAMID'],
      'final pyramidal = 1;': ['pyramid'],
      "const source = 'three-pyramids';": ['pyramid'],
      '// Rule MSP-12.': ['MSP-'],
      '// See the appendix.': ['appendix'],
      '// See the Appendices.': ['Appendices'],
      '// From section 2.': ['section 2'],
      '// From Section  12.': ['Section  12'],
      '// From chapter 3.': ['chapter 3'],
      '// From Chapter\t4.': ['Chapter\t4'],
      '// From sect. 4.': ['sect. 4'],
      '// From sect.4.': ['sect.4'],
      '// From ch. 5.': ['ch. 5'],
      '// From Ch.5.': ['Ch.5'],
      '// From pg. 7.': ['pg. 7'],
      '// From pg.7.': ['pg.7'],
      '// From p. 180.': ['p. 180'],
      '// From p.180.': ['p.180'],
      '// From pp. 12-14.': ['pp. 12'],
      '// From pp.12.': ['pp.12'],
      '// From P.  9.': ['P.  9'],
      '// From page 3.': ['page 3'],
      '// From pages  10 to 12.': ['pages  10'],
      '// From § 2.1.': ['§'],
      '// From §3.': ['§'],
      '// Recorded in decisions.md.': ['decisions.md'],
      '// Recorded in Decisions.MD.': ['Decisions.MD'],
      '// Recorded in DECISIONS.': ['DECISIONS'],
      // Strings are scanned too, and every match on a line is reported.
      "const note = 'chapter 2, page 31';": ['chapter 2', 'page 31'],
    };
    for (final MapEntry(key: line, value: matches) in samples.entries) {
      test(line, () {
        expect(found(citations, line), [for (final m in matches) 'sample.dart:2: $m']);
      });
    }
  });

  group('citations allows', () {
    const samples = [
      '// The decisions taken by the planner.',
      '// Decisions are final.',
      'final decisions = <String>[];',
      '// The section below handles deloads.',
      '// Split the week into sections.',
      '// One chapter per block.',
      'final page = pages[2];',
      '// Two pages of results.',
      '// Append the warm-up sets.',
      '// e.g. 3 sets of 5.',
      '// One set per step. 2 sets follow.',
      '// Bench. 3 sets.',
      '// Warm-up. 3 sets.',
      'final n = p.length + pp.first + ch.index + pg.count + sect.size;',
      'final p = 0.5;',
      '// 3 sets of 5 at RPE 8.',
      'final msp = 1;',
    ];
    for (final line in samples) {
      test(line, () => expect(found(citations, line), isEmpty));
    }
  });

  group('unlicensed', () {
    test('accepts a file whose first line is the licence line', () {
      source('ok.dart', ['library;']);

      expect(unlicensed(lib), isEmpty);
    });

    test('the licence line is the one every coach source file starts with', () {
      expect(licenceLine, '// SPDX-License-Identifier: GPL-3.0-only');
    });

    const wrongFirstLines = <String, String>{
      'library;': 'library;',
      '': '(blank line)',
      '// SPDX-License-Identifier: GPL-3.0-only ': '// SPDX-License-Identifier: GPL-3.0-only ',
      ' // SPDX-License-Identifier: GPL-3.0-only': ' // SPDX-License-Identifier: GPL-3.0-only',
      '// SPDX-License-Identifier: GPL-3.0-or-later': '// SPDX-License-Identifier: GPL-3.0-or-later',
      '// SPDX-License-Identifier: MIT': '// SPDX-License-Identifier: MIT',
      '/* SPDX-License-Identifier: GPL-3.0-only */': '/* SPDX-License-Identifier: GPL-3.0-only */',
      '# SPDX-License-Identifier: GPL-3.0-only': '# SPDX-License-Identifier: GPL-3.0-only',
    };
    for (final MapEntry(key: first, value: shown) in wrongFirstLines.entries) {
      test('flags a file that starts with "$first"', () {
        source('bad.dart', [licenceLine, 'library;'], firstLine: first);

        expect(short(unlicensed(lib)), ['bad.dart:1: $shown']);
      });
    }

    test('flags an empty file', () {
      File('${lib.path}/empty.dart').writeAsStringSync('');

      expect(short(unlicensed(lib)), ['empty.dart:1: (empty file)']);
    });

    test('accepts Windows line endings', () {
      File('${lib.path}/crlf.dart').writeAsStringSync('$licenceLine\r\nlibrary;\r\n');

      expect(unlicensed(lib), isEmpty);
    });

    test('the testkit itself declares the licence', () {
      expect(unlicensed(Directory('lib')), isEmpty);
    });
  });

  group('every guard', () {
    final guards = {'impurities': impurities, 'citations': citations, 'unlicensed': unlicensed};

    test('finds nothing in a clean package', () {
      source('clean.dart', ['library;', '', "import 'dart:math';", '', 'int twice(int x) => 2 * x;']);
      source('src/more.dart', ['const one = 1;']);

      for (final guard in guards.values) {
        expect(guard(lib), isEmpty);
      }
    });

    test('scans sub-directories and reports path:line in path order', () {
      source('b.dart', ['', '', '// A pyramid, then print.']);
      source('a/deep/c.dart', ['// print, then a pyramid.'], firstLine: '');
      source('a.dart', ['library;']);

      expect(short(impurities(lib)), ['a/deep/c.dart:2: print', 'b.dart:4: print']);
      expect(short(citations(lib)), ['a/deep/c.dart:2: pyramid', 'b.dart:4: pyramid']);
      expect(short(unlicensed(lib)), ['a/deep/c.dart:1: (blank line)']);
    });

    test('writes paths with forward slashes, relative paths included', () {
      source('src/x.dart', ['print(1);']);
      final relative = Directory('${lib.path}/../lib');

      final finding = impurities(relative).single;

      expect(finding, endsWith('/lib/src/x.dart:2: print'));
      expect(finding, isNot(contains(r'\')));
    });

    for (final MapEntry(key: name, value: guard) in guards.entries) {
      test('$name reports a missing lib directory', () {
        final missing = Directory('${root.path}/nowhere');

        expect(guard(missing), ['${missing.path.replaceAll(r'\', '/')}: directory not found']);
      });

      test('$name reports a lib directory without any Dart file', () {
        expect(short(guard(lib)), [endsWith('/lib: no Dart file to check')]);

        Directory('${lib.path}/src').createSync();
        expect(short(guard(lib)), [endsWith('/lib: no Dart file to check')]);
      });

      test('$name reports a file that is not a Dart file', () {
        source('ok.dart', ['library;']);
        File('${lib.path}/notes.md').writeAsStringSync('notes\n');
        File('${lib.path}/src/data.json')
          ..createSync(recursive: true)
          ..writeAsStringSync('{}\n');
        File('${lib.path}/src/dart').writeAsStringSync('$licenceLine\n');

        expect(short(guard(lib)), [
          'notes.md: not a Dart file',
          'src/dart: not a Dart file',
          'src/data.json: not a Dart file',
        ]);
      });

      test('$name reports both when the only file is not a Dart file', () {
        File('${lib.path}/notes.md').writeAsStringSync('notes\n');

        expect(short(guard(lib)), ['notes.md: not a Dart file', endsWith('/lib: no Dart file to check')]);
      });
    }
  });
}
