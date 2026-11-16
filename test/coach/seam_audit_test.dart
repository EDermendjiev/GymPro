// SPDX-License-Identifier: GPL-3.0-only
// Every edit the coach makes to a file that came from upstream carries the marker `coach-seam` (`// coach-seam` in
// Dart and Kotlin, `# coach-seam` in YAML, an XML comment in XML). This test counts the markers per file and
// compares them with the list below, so a touch point that is not on the list fails here, by file name.
//
// When a seam is added on purpose, add it to docs/coach/ARCHITECTURE.md and to this map in the same change.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Expected number of markers per file, for every file outside the coach's own folders.
const _expected = <String, int>{
  'android/app/build.gradle.kts': 1, // app identity
  'android/app/src/main/AndroidManifest.xml': 1, // app identity
  'lib/app/gymmane_app.dart': 1, // app identity
  'lib/screens/about_screen.dart': 3, // credit line and fork link
  'lib/state/fit_core.dart': 1, // block of no-op coach methods
  'lib/state/fit_state.dart': 7, // import, part, mixin, loadFromStore, toJson, applyBackup, resetAllData
  'packages/sync/lib/sync.dart': 1, // coach merges atomically
  'lib/screens/settings_screen.dart': 5, // import, Coach category, its title, its group, its section
  'pubspec.yaml': 1, // coach package dependencies
  'android/app/src/main/res/xml/shortcuts.xml': 1, // app identity
  'ios/Runner/Info.plist': 1, // app identity
  'lib/models/progression.dart': 1, // ProgressKind.auto appended
  'lib/widgets/progression_sheet.dart': 4, // Auto: its name, its hint, offered while the module is on, its rule
  // _nextPlan (asks first; Auto falls back to Linear), toggleSet, nextWhy, _warmupFor, _openingSetsRaw,
  // startFocusWorkout, _defaultPicks
  'lib/state/workout_state.dart': 8,
  'lib/screens/onboarding_screen.dart': 4, // import of the barrel, page count, the coach's pages, finish
  'lib/screens/home_screen.dart': 3, // import of the barrel, block and week in the subtitle, "Why this plan"
  'lib/screens/train_screen.dart': 2, // import of the barrel, quick-workout length chips
  'lib/screens/session_screen.dart': 4, // import of the barrel, the coach's requests taken in build, target line, soreness row
  'lib/state/nutrition_state.dart': 1, // suggestedGoals asks first
  'lib/screens/nutrition_screen.dart': 1, // import of the barrel, for its part nutrition/settings.dart
  'lib/screens/nutrition/settings.dart': 1, // the coach's card in the goals sheet
};

/// Seams in files that cannot carry a comment. They are not counted; each must exist.
const _exempt = <String>[
  'README.md',
  'lib/l10n/app_en.arb',
  'test/pending_translation_keys.txt',
  // App identity: Xcode rewrites the project file, and the store titles are plain text.
  'ios/Runner.xcodeproj/project.pbxproj',
  'fastlane/metadata/android/en-US/title.txt',
  'fastlane/metadata/android/es-ES/title.txt',
];

/// Generated from the ARB files, so never edited by hand and never marked.
final _generated = RegExp(r'^lib/l10n/app_localizations(_[a-z]+)?\.dart$');

/// The coach's own files: everything in them is coach code, so they need no markers.
const _ownPrefixes = ['lib/coach/', 'test/coach/', 'docs/coach/', 'packages/coach_', 'dev/'];
const _ownFiles = {'lib/state/coach_state.dart'};

const _marker = 'coach-seam';

/// Tracked files plus new files that git does not ignore, as forward-slash paths relative to the repository root.
List<String> _repoFiles() {
  final git = Process.runSync('git', ['ls-files', '--cached', '--others', '--exclude-standard', '-z']);
  if (git.exitCode == 0) {
    return [
      for (final p in (git.stdout as String).split('\x00'))
        if (p.isNotEmpty && File(p).existsSync()) p,
    ];
  }
  // No git (an exported source tree): walk the directory and skip what is never source.
  const skip = {'build', '.dart_tool', '.git', '.idea', 'node_modules', 'Pods', '.gradle'};
  final out = <String>[];
  void walk(Directory d) {
    for (final e in d.listSync(followLinks: false)) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (e is Directory) {
        if (!skip.contains(name)) walk(e);
      } else if (e is File) {
        out.add(e.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), ''));
      }
    }
  }

  walk(Directory('.'));
  return out;
}

bool _own(String path) => _ownFiles.contains(path) || _ownPrefixes.any(path.startsWith);

int _count(String path) {
  final text = latin1.decode(File(path).readAsBytesSync(), allowInvalid: true);
  return _marker.allMatches(text).length;
}

void main() {
  test('every coach-seam marker outside the coach folders is on the list, and every listed one is there', () {
    final found = <String, int>{};
    for (final path in _repoFiles()) {
      if (_own(path) || _exempt.contains(path) || _generated.hasMatch(path)) continue;
      final n = _count(path);
      if (n > 0) found[path] = n;
    }
    final problems = <String>[
      for (final e in found.entries)
        if (!_expected.containsKey(e.key)) '${e.key}: ${e.value} marker(s), but the file is not on the seam list',
      for (final e in _expected.entries)
        if ((found[e.key] ?? 0) != e.value) '${e.key}: expected ${e.value} marker(s), found ${found[e.key] ?? 0}',
    ];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('the files exempt from markers exist', () {
    for (final path in _exempt) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('the generated localization files carry no marker', () {
    for (final f in Directory('lib/l10n').listSync().whereType<File>()) {
      final path = f.path.replaceAll('\\', '/');
      if (_generated.hasMatch(path)) expect(_count(path), 0, reason: path);
    }
  });
}
