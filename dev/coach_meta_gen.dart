// SPDX-License-Identifier: GPL-3.0-only
// Regenerates lib/coach/data/coach_meta.dart: the coaching attributes of the app's exercises.
//
// Run from the repository root:  dart run dev/coach_meta_gen.dart
//
// Sources:
//  - the kernel's exercise fixture (packages/coach_kernel/test/fixtures/exercises.json): the coach's exercise
//    annotations, one entry per exercise the coach knows (pattern, category, muscles, slot tags, ...);
//  - the app's catalog (lib/catalog/exercise_catalog.dart) and its alias table (lib/catalog/exercise_aliases.dart).
//    Both are read as source text: the catalog's model imports Flutter, which a plain `dart run` cannot load.
//
// Each annotated exercise is matched to an app exercise in this order:
//  1. the manual table below (`_manual`), which also drops exercises the app has no equivalent for;
//  2. exact: the normalised names are equal;
//  3. close: the names are equal as word sets once parentheses, plural endings and the equipment word are
//     accounted for, or the annotated name is one of the app exercise's aliases.
// When several annotated exercises land on one app exercise, one wins (the one with a main-lift key, then the most
// common one); the others only redirect substitutions to the winner.
//
// The app also gets a few annotations of its own (`_host`): app exercises without an annotated counterpart that a
// template slot needs when the equipment is only dumbbells, or only bodyweight and bands. Each copies the
// attributes of an annotated exercise ("like") and is ranked after every annotated one.
//
// The equipment is not stored: the adapter takes it from the app's own exercise.
import 'dart:convert';
import 'dart:io';

const _fixturePath = 'packages/coach_kernel/test/fixtures/exercises.json';
const _catalogPath = 'lib/catalog/exercise_catalog.dart';
const _aliasesPath = 'lib/catalog/exercise_aliases.dart';
const _outPath = 'lib/coach/data/coach_meta.dart';

/// Annotated exercise id -> app exercise id, or null to drop it. Checked against the catalog on every run.
const Map<String, String?> _manual = {
  'back-squat': 'qXTaZnJ', // Barbell Full Squat
  'hack-squat': 'hack-squat-machine', // Hack Squat (the alias table points at the Smith version)
  'low-bar-squat': 'qXTaZnJ',
  'safety-bar-squat': 'qXTaZnJ',
  'conventional-deadlift': 'ila4NZS', // Barbell Deadlift
  'walking-lunge': 'RRWFUcw', // Dumbbell Lunge
  'dip': '9WTm7dq', // Chest Dip
  'chest-supported-t-bar-row': 'aaXr7ld', // T-Bar Row
  'cable-pullover': '9XjtHvS', // Dumbbell Pullover
  'cable-rear-delt-fly': 'aqvSOQE', // Cable Reverse Fly
  'dumbbell-rear-delt-fly': 'v1qBec9', // Dumbbell Rear Lateral Raise
  'reverse-pec-deck': 'myfUsKf', // Machine Reverse Fly
  'skull-crusher': 'iZop9xO', // Barbell Lying Triceps Extension (alias Skullcrusher)
  'shrug': 'NJzBsGJ', // Dumbbell Shrug
  'back-extension-45': '8urJS9b', // Back Extension
  'glute-bridge-machine': 'glute-bridge', // Glute Bridge: the app has no machine bridge
  'seated-calf-raise': 'ktsFQAZ', // Barbell Seated Calf Raise: the app has no seated calf machine
  'incline-barbell-press': '3TZduzM', // Barbell Incline Bench Press
  'incline-dumbbell-press': 'ns0SIbU', // Dumbbell Incline Bench Press
  'flat-dumbbell-press': 'SpYC0Kp', // Dumbbell Bench Press
  'incline-machine-press': 'incline-chest-press-machine', // Incline Chest Press Machine
  'cable-fly': '0CXGHya', // Cable Crossover
  'pull-up': 'lBDjFxJ', // Pull-up (close matching would pick Weighted Pull-up)
  'single-arm-cable-pulldown': 'RVwzP10', // Cable Pulldown: no single-arm pulldown in the app
  'machine-row': '7I6LNUG', // Machine Seated Row
  'inverted-row': 'mExgrF9', // Bench Pull-ups (an inverted row)
  'barbell-curl': '25GPyDY', // Barbell Curl
  'preacher-curl': 'qOgPVf6', // Barbell Preacher Curl
  'backwards-sled-drag': null, // no sled in the app, and no template slot needs it
  'tibialis-raise': null, // no equivalent, and no template slot needs it
};

/// App exercise id -> (annotated exercise it is like, overrides). Only for slots the annotated exercises leave
/// empty with dumbbells or with bodyweight and bands.
const Map<String, (String, Map<String, Object>)> _host = {
  'xdYPUtE': ('leg-extension', {}), // Sissy Squat: leg extension without a machine
  'band-upright-row': ('cable-upright-row', {}), // lateral raise with bands
  'pike-push-up': ('seated-dumbbell-shoulder-press', {'longLengthBias': false}), // vertical press, bodyweight
  'band-chest-fly': ('cable-fly', {}), // chest isolation with bands
  'band-biceps-curl': ('barbell-curl', {}), // biceps isolation with bands
  'rNG4tri': ('skull-crusher', {}), // Ring Triceps Extension: triceps isolation, bodyweight
  'bodyweight-single-leg-deadlift': ('single-leg-rdl', {}), // hinge, bodyweight
  'dumbbell-hip-thrust': ('barbell-hip-thrust', {}), // hip extension with a dumbbell
  '0jp9Rlz': ('single-leg-dumbbell-calf-raise', {}), // One Leg Floor Calf Raise: calves, bodyweight
  // Pull and push days have two rows, two biceps or two triceps slots: a second bodyweight or band option each.
  'banded-row': ('seated-cable-row', {}), // elbows-in row with bands
  'rNG9cur': ('barbell-curl', {}), // Ring Biceps Curl
  'RrLske5': ('triceps-pushdown', {}), // Bench Dip (Knees Bent): triceps, bodyweight
};

/// Popularity of the app's own annotations: after every annotated exercise.
const _hostPopularityBase = 100;

final _stringLit = RegExp(
  r"'((?:[^'\\]|\\.)*)'"
  '|'
  r'"((?:[^"\\]|\\.)*)"',
);

String _lit(Match m) => (m.group(1) ?? m.group(2)!).replaceAll(r"\'", "'").replaceAll(r'\"', '"');

class _AppExercise {
  _AppExercise(this.id, this.name, this.equipment);
  final String id;
  final String name;
  final String equipment;
  final List<String> aliases = [];
}

List<_AppExercise> _readCatalog() {
  final src = File(_catalogPath).readAsStringSync();
  final field = RegExp(
    r"""^\s{4}(id|name|equipment): ('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"),$""",
    multiLine: true,
  );
  final out = <_AppExercise>[];
  String? id, name;
  for (final m in field.allMatches(src)) {
    final value = _lit(_stringLit.firstMatch(m.group(2)!)!);
    switch (m.group(1)) {
      case 'id':
        id = value;
        name = null;
      case 'name':
        name = value;
      case 'equipment':
        out.add(_AppExercise(id!, name!, value));
        id = null;
    }
  }
  final aliasLine = RegExp(
    r"^\s{2}('(?:[^'\\]|\\.)*'|"
    r'"(?:[^"\\]|\\.)*"'
    r'): \[(.*)\],$',
    multiLine: true,
  );
  final byName = {for (final e in out) e.name: e};
  for (final m in aliasLine.allMatches(File(_aliasesPath).readAsStringSync())) {
    final canonical = byName[_lit(_stringLit.firstMatch(m.group(1)!)!)];
    if (canonical == null) continue;
    canonical.aliases.addAll(_stringLit.allMatches(m.group(2)!).map(_lit));
  }
  return out;
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim().replaceAll(RegExp(r'\s+'), ' ');

const _stop = {'the', 'a', 'with', 'of', 'and', 'on'};

/// The word set of a name without its parentheses, with plural endings dropped, plus [equipment] when given.
Set<String> _words(String name, [String? equipment]) {
  final bare = name.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  final words = {
    for (final w in _norm(bare).split(' '))
      if (w.isNotEmpty && !_stop.contains(w))
        w.length > 3 && w.endsWith('s') && !w.endsWith('ss') ? w.substring(0, w.length - 1) : w,
  };
  if (equipment != null) words.add(equipment);
  return words;
}

bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

const _appEquipmentWord = {
  'Barbell': 'barbell',
  'Dumbbell': 'dumbbell',
  'Kettlebell': 'kettlebell',
  'Machine': 'machine',
  'Cable': 'cable',
  'Bodyweight': 'bodyweight',
  'Weighted': 'bodyweight',
  'Rings': 'bodyweight',
  'Band': 'band',
};

String _dartString(String s) => "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

String _list(List<String> xs) => '[${xs.map(_dartString).join(', ')}]';

void main() {
  final fixture = jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;
  final annotated = [
    for (final x in ((fixture['cases'] as List).first as Map<String, dynamic>)['output'] as List)
      x as Map<String, dynamic>,
  ];
  final byRef = {for (final a in annotated) a['id'] as String: a};
  final app = _readCatalog();
  final appById = {for (final e in app) e.id: e};
  if (app.length != 466) stderr.writeln('note: the catalog has ${app.length} exercises');

  for (final MapEntry(:key, :value) in _manual.entries) {
    if (!byRef.containsKey(key)) throw StateError('manual table: no annotated exercise "$key"');
    if (value != null && !appById.containsKey(value)) {
      throw StateError('manual table: no app exercise "$value"');
    }
  }
  for (final MapEntry(:key, :value) in _host.entries) {
    if (!appById.containsKey(key)) throw StateError('host table: no app exercise "$key"');
    if (!byRef.containsKey(value.$1)) throw StateError('host table: no annotated exercise "${value.$1}"');
  }

  // ---- match ----
  final target = <String, String>{}; // annotated id -> app id
  final how = <String, String>{};
  final dropped = <String>[];
  for (final a in annotated) {
    final ref = a['id'] as String;
    final name = a['name'] as String;
    if (_manual.containsKey(ref)) {
      final to = _manual[ref];
      if (to == null) {
        dropped.add(ref);
      } else {
        target[ref] = to;
        how[ref] = 'manual';
      }
      continue;
    }
    final exact = app.where((e) => _norm(e.name) == _norm(name)).toList();
    if (exact.isNotEmpty) {
      target[ref] = exact.first.id;
      how[ref] = 'exact';
      continue;
    }
    final refEquipment = (a['equipment'] as List).cast<String>();
    final refWords = _words(name, refEquipment.isEmpty ? null : refEquipment.first);
    final close = app.where((e) {
      final eq = _appEquipmentWord[e.equipment];
      if (_sameSet(_words(e.name, eq), refWords)) return true;
      return e.aliases.any((al) => _norm(al) == _norm(name) || _sameSet(_words(al, eq), refWords));
    }).toList();
    if (close.isNotEmpty) {
      if (close.length > 1) stderr.writeln('note: $ref matches ${close.map((e) => e.name).join(' / ')}');
      target[ref] = close.first.id;
      how[ref] = 'close';
      continue;
    }
    throw StateError('no app exercise for "$ref" ($name): add it to the manual table');
  }

  // ---- one winner per app exercise ----
  final winner = <String, String>{}; // app id -> annotated id
  for (final a in annotated) {
    final ref = a['id'] as String;
    final to = target[ref];
    if (to == null) continue;
    final cur = winner[to];
    if (cur == null) {
      winner[to] = ref;
      continue;
    }
    final c = byRef[cur]!;
    final keyA = a['mainLiftKey'] != null ? 0 : 1, keyC = c['mainLiftKey'] != null ? 0 : 1;
    if (keyA < keyC || (keyA == keyC && (a['popularity'] as int) < (c['popularity'] as int))) {
      winner[to] = ref;
    }
  }
  final merged = [
    for (final MapEntry(:key, :value) in target.entries)
      if (winner[value] != key) key,
  ];

  List<String> subsOf(Map<String, dynamic> a, String self) {
    final out = <String>[];
    for (final s in (a['substitutions'] as List).cast<String>()) {
      final to = target[s];
      if (to == null || to == self || out.contains(to)) continue;
      out.add(to);
    }
    return out;
  }

  // ---- write ----
  final entries = <String, String>{};
  // An app annotation ([host]) takes no main-lift key (the main lifts stay the annotated ones) and no load step.
  void entry(
    String appId,
    Map<String, dynamic> a,
    String comment, {
    bool host = false,
    Map<String, Object> over = const {},
    int? popularity,
    List<String>? subs,
  }) {
    final muscles = (a['muscles'] as List).cast<Map<String, dynamic>>();
    final primary = [
      for (final m in muscles)
        if (m['role'] == 'primary') m['muscle'] as String,
    ];
    final secondary = [
      for (final m in muscles)
        if (m['role'] == 'secondary') m['muscle'] as String,
    ];
    Object f(String k) => over[k] ?? a[k] as Object;
    final inc = host ? null : a['defaultIncrementKg'] as num?;
    final b = StringBuffer()
      ..writeln('  // $comment')
      ..writeln('  ${_dartString(appId)}: CoachMeta(')
      ..writeln('    slug: ${_dartString(over['slug'] as String? ?? a['slug'] as String)},')
      ..writeln("    pattern: '${a['pattern']}',")
      ..writeln("    category: '${a['category']}',")
      ..writeln('    primary: ${_list(primary)},')
      ..writeln('    secondary: ${_list(secondary)},')
      ..writeln('    slotTags: ${_list((a['slotTags'] as List).cast<String>())},')
      ..writeln('    longLengthBias: ${f('longLengthBias')},')
      ..writeln('    unilateral: ${f('unilateral')},')
      ..writeln('    axialLoad: ${f('axialLoad')},')
      ..writeln('    impactLowerBody: ${f('impactLowerBody')},');
    if (!host && a['mainLiftKey'] != null) {
      b.writeln("    mainLiftKey: '${a['mainLiftKey']}',");
    }
    if (inc != null) b.writeln('    defaultIncrementKg: ${inc.toDouble()},');
    b
      ..writeln('    substitutions: ${_list(subs ?? subsOf(a, appId))},')
      ..writeln('    popularity: ${popularity ?? a['popularity']},')
      ..writeln('  ),');
    entries[appId] = b.toString();
  }

  for (final MapEntry(key: appId, value: ref) in winner.entries) {
    final a = byRef[ref]!;
    final also = [
      for (final m in merged)
        if (target[m] == appId) m,
    ];
    entry(
      appId,
      a,
      '${appById[appId]!.name} <- ${a['name']} (${how[ref]})${also.isEmpty ? '' : '; also ${also.join(', ')}'}',
    );
  }
  var n = 0;
  for (final MapEntry(key: appId, value: (like, over)) in _host.entries) {
    if (entries.containsKey(appId)) throw StateError('host table: "$appId" is already annotated');
    final a = byRef[like]!;
    final likeApp = target[like];
    entry(
      appId,
      a,
      '${appById[appId]!.name}: like ${a['name']} (app annotation)',
      host: true,
      over: {'slug': appId, ...over},
      popularity: _hostPopularityBase + n++,
      subs: [?likeApp, ...subsOf(a, appId)].where((s) => s != appId).toSet().toList(),
    );
  }

  final keys = entries.keys.toList()
    ..sort((x, y) => (app.indexWhere((e) => e.id == x)).compareTo(app.indexWhere((e) => e.id == y)));
  final count = {
    for (final k in ['exact', 'close', 'manual']) k: winner.values.where((r) => how[r] == k).length,
  };
  final out = StringBuffer()
    ..writeln('// SPDX-License-Identifier: GPL-3.0-only')
    ..writeln(
      '// Generated by dev/coach_meta_gen.dart, do not edit. Regenerate with: dart run dev/coach_meta_gen.dart',
    )
    ..writeln('//')
    ..writeln("// The coaching attributes of the app's exercises, keyed by the app's exercise id.")
    ..writeln("// ${winner.length} come from the coach's exercise annotations:")
    ..writeln(
      '// ${count['exact']} exact name matches, ${count['close']} close, ${count['manual']} from the manual table.',
    )
    ..writeln("// ${_host.length} are annotations of the app's own, each like an annotated exercise.")
    ..writeln('// Merged into another entry: ${merged.join(', ')}.')
    ..writeln('// Dropped (no app equivalent): ${dropped.join(', ')}.')
    ..writeln('//')
    ..writeln(
      "// Values are wire strings; lib/coach/adapters/catalog_adapter.dart turns them into the coach's types.",
    )
    ..writeln()
    ..writeln(
      '/// Coaching attributes of one app exercise. Equipment and the display name come from the exercise itself.',
    )
    ..writeln('class CoachMeta {')
    ..writeln('  const CoachMeta({')
    ..writeln('    required this.slug,')
    ..writeln('    required this.pattern,')
    ..writeln('    required this.category,')
    ..writeln('    required this.primary,')
    ..writeln('    required this.secondary,')
    ..writeln('    required this.slotTags,')
    ..writeln('    required this.longLengthBias,')
    ..writeln('    required this.unilateral,')
    ..writeln('    required this.axialLoad,')
    ..writeln('    required this.impactLowerBody,')
    ..writeln('    this.mainLiftKey,')
    ..writeln('    this.defaultIncrementKg,')
    ..writeln('    required this.substitutions,')
    ..writeln('    required this.popularity,')
    ..writeln('  });')
    ..writeln()
    ..writeln(
      "  /// The annotation's slug, or the app id for an annotation of the app's own. Main lifts are found by slug.",
    )
    ..writeln('  final String slug;')
    ..writeln('  final String pattern;')
    ..writeln('  final String category;')
    ..writeln('  final List<String> primary;')
    ..writeln('  final List<String> secondary;')
    ..writeln('  final List<String> slotTags;')
    ..writeln('  final bool longLengthBias;')
    ..writeln('  final bool unilateral;')
    ..writeln('  final bool axialLoad;')
    ..writeln('  final bool impactLowerBody;')
    ..writeln('  final String? mainLiftKey;')
    ..writeln('  final double? defaultIncrementKg;')
    ..writeln()
    ..writeln('  /// App exercise ids.')
    ..writeln('  final List<String> substitutions;')
    ..writeln()
    ..writeln('  /// Lower = more common.')
    ..writeln('  final int popularity;')
    ..writeln('}')
    ..writeln()
    ..writeln('const Map<String, CoachMeta> kCoachMeta = {');
  for (final k in keys) {
    out.write(entries[k]);
  }
  out.writeln('};');
  File(_outPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(out.toString());

  stdout.writeln('annotated exercises: ${annotated.length}');
  for (final a in annotated) {
    final ref = a['id'] as String;
    final to = target[ref];
    stdout.writeln(
      '  ${how[ref] ?? 'dropped'}\t$ref -> ${to == null ? '-' : '$to (${appById[to]!.name})'}${merged.contains(ref) ? ' [merged]' : ''}',
    );
  }
  stdout.writeln(
    'matched ${target.length} (exact ${how.values.where((h) => h == 'exact').length}, '
    'close ${how.values.where((h) => h == 'close').length}, manual ${how.values.where((h) => h == 'manual').length}); '
    'merged ${merged.length}; dropped ${dropped.length}; entries ${entries.length} (${_host.length} app annotations)',
  );
}
