// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only places in the app that may import a coach package.
bool _mayImportPackages(String path) =>
    path.startsWith('lib/coach/adapters/') || path.startsWith('lib/coach/model/') || path == 'lib/coach/facade.dart';

Iterable<(String, String)> _dartFiles(String dir) sync* {
  for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
    final path = f.path.replaceAll('\\', '/');
    if (path.endsWith('.dart')) yield (path, f.readAsStringSync());
  }
}

void main() {
  test('only the coach layer imports the coach packages', () {
    final offenders = <String>[];
    for (final (path, source) in _dartFiles('lib')) {
      if (path.startsWith('lib/coach/')) continue;
      if (source.contains('package:coach_')) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });

  test('inside the coach layer only the adapters, the models and the facade import the packages', () {
    final offenders = <String>[];
    for (final (path, source) in _dartFiles('lib/coach')) {
      if (_mayImportPackages(path)) continue;
      if (source.contains('package:coach_')) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });

  test('the coach layer does not reach into screens', () {
    for (final (path, source) in _dartFiles('lib/coach')) {
      if (path.startsWith('lib/coach/ui/')) continue;
      expect(source.contains("'../../screens/"), isFalse, reason: path);
    }
  });

  test('the barrel exports only Coach-prefixed host symbols', () {
    final barrel = File('lib/coach/coach.dart').readAsStringSync();
    expect(barrel.contains('package:coach_'), isFalse);
    for (final m in RegExp(r"export '[^']+'([^;]*);").allMatches(barrel)) {
      final clause = m.group(1)!.trim();
      expect(clause, startsWith('show '), reason: 'every export needs a show list: ${m.group(0)}');
      for (final name in clause.substring(5).split(',').map((s) => s.trim())) {
        expect(name.toLowerCase(), startsWith('coach'), reason: name);
      }
    }
  });

  test('the rest of the app reaches the coach layer through the barrel only', () {
    final offenders = <String>[];
    final deepImport = RegExp(r"""import\s+['"][^'"]*coach/(?!coach\.dart)[^'"]*['"]""");
    for (final (path, source) in _dartFiles('lib')) {
      if (path.startsWith('lib/coach/')) continue;
      if (deepImport.hasMatch(source)) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });
}
