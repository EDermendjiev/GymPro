// SPDX-License-Identifier: GPL-3.0-only
// Everything the coach keeps, stored under one key ("coach") in the app's state. The shape is documented in
// docs/coach/ARCHITECTURE.md.
//
// Two promises hold for every input:
//  - fromJson never throws. Whatever is stored, the backup loads; the coach parts it cannot read count as absent.
//  - Nothing is lost. Keys this version does not know, and values of known keys it cannot read, are kept as they
//    were and written back unchanged until the app replaces them.
import 'package:coach_kernel/coach_kernel.dart' as ck;

import 'coach_profile.dart';
import 'json_util.dart';

/// The coach modules, each with its own switch.
enum CoachModule {
  progression,
  plan,
  recovery,
  nutrition;

  /// The module that must be on before this one can be, or null.
  CoachModule? get needs => switch (this) {
        CoachModule.plan => CoachModule.progression,
        CoachModule.recovery => CoachModule.plan,
        _ => null,
      };
}

final class CoachData {
  CoachData._({
    required this.version,
    required Set<CoachModule> on,
    required this.profile,
    required List<ck.UserSport> sports,
    required List<ck.Injury> injuries,
    required List<String> disliked,
    required Map<String, dynamic> soreness,
    required this.block,
    required Map<String, String> routineIds,
    required List<Map<String, dynamic>> proposals,
    required Map<String, dynamic> review,
    required Map<String, dynamic> nutrition,
    required Map<String, dynamic> onExtra,
    required Map<String, dynamic> extra,
  })  : _on = Set.unmodifiable(on),
        sports = List.unmodifiable(sports),
        injuries = List.unmodifiable(injuries),
        disliked = List.unmodifiable(disliked),
        soreness = Map.unmodifiable(soreness),
        routineIds = Map.unmodifiable(routineIds),
        proposals = List.unmodifiable(proposals),
        review = Map.unmodifiable(review),
        nutrition = Map.unmodifiable(nutrition),
        _onExtra = Map.unmodifiable(onExtra),
        _extra = Map.unmodifiable(extra);

  /// The state of every existing backup: no coach data, every module off.
  factory CoachData.empty() => CoachData._(
        version: currentVersion,
        on: const {},
        profile: null,
        sports: const [],
        injuries: const [],
        disliked: const [],
        soreness: const {},
        block: null,
        routineIds: const {},
        proposals: const [],
        review: const {},
        nutrition: const {},
        onExtra: const {},
        extra: const {},
      );

  /// Reads the stored `coach` value. Null, or anything that is not a coach map, gives [CoachData.empty].
  factory CoachData.fromJson(Map<String, dynamic>? raw) {
    final json = jsonMap(raw);
    if (json == null) return CoachData.empty();
    final extra = <String, dynamic>{};

    // A kernel-typed value is read whole or not at all; when it cannot be read, the stored value is kept as is.
    T? typed<T>(String key, T Function(Object value) read) {
      final v = json[key];
      if (v == null) return null;
      try {
        return read(v);
      } catch (_) {
        extra[key] = v;
        return null;
      }
    }

    final onJson = jsonMap(json['on']) ?? const <String, dynamic>{};
    final names = {for (final m in CoachModule.values) m.name};
    for (final e in json.entries) {
      if (!_known.contains(e.key)) extra[e.key] = e.value;
    }
    return CoachData._(
      version: json['v'] is int ? json['v'] as int : currentVersion,
      on: {
        for (final m in CoachModule.values)
          if (onJson[m.name] == true) m,
      },
      profile: typed('profile', (v) => CoachProfile.fromJson(v as Map<String, dynamic>)),
      sports: typed('sports', (v) => [for (final x in v as List) ck.UserSport.fromJson(x as Map<String, dynamic>)]) ??
          const [],
      injuries:
          typed('injuries', (v) => [for (final x in v as List) ck.Injury.fromJson(x as Map<String, dynamic>)]) ??
              const [],
      disliked: typed('disliked', (v) => [for (final x in v as List) x as String]) ?? const [],
      soreness: typed('soreness', (v) => v as Map<String, dynamic>) ?? const {},
      block: typed('block', (v) => ck.BlockPlan.fromJson(v as Map<String, dynamic>)),
      // The loosely typed parts are read entry by entry: what does not fit is dropped.
      routineIds: {
        for (final e in (jsonMap(json['routineIds']) ?? const <String, dynamic>{}).entries)
          if (e.value is String) e.key: e.value as String,
      },
      proposals: [
        if (json['proposals'] is List)
          for (final p in json['proposals'] as List)
            if (p is Map<String, dynamic>) p,
      ],
      review: jsonMap(json['review']) ?? const {},
      nutrition: jsonMap(json['nutrition']) ?? const {},
      onExtra: {
        for (final e in onJson.entries)
          if (!names.contains(e.key)) e.key: e.value,
      },
      extra: extra,
    );
  }

  /// The version of the stored shape this code writes.
  static const int currentVersion = 1;

  static const _known = {
    'v',
    'on',
    'profile',
    'sports',
    'injuries',
    'disliked',
    'soreness',
    'block',
    'routineIds',
    'proposals',
    'review',
    'nutrition',
  };

  /// The stored version: [currentVersion] unless the data came from a newer app.
  final int version;
  final Set<CoachModule> _on;
  final CoachProfile? profile;
  final List<ck.UserSport> sports;
  final List<ck.Injury> injuries;

  /// Exercise ids the user does not want the plan to pick.
  final List<String> disliked;

  /// Soreness reports by date and muscle. Shaped by the recovery module.
  final Map<String, dynamic> soreness;

  /// The current generated block.
  final ck.BlockPlan? block;

  /// The app routine each block session was written to, by session key.
  final Map<String, String> routineIds;

  /// Proposals with their state and undo data. Shaped by the recovery and nutrition modules.
  final List<Map<String, dynamic>> proposals;

  /// Weekly review bookkeeping. Shaped by the recovery module.
  final Map<String, dynamic> review;

  /// Current nutrition phase and targets. Shaped by the nutrition module.
  final Map<String, dynamic> nutrition;

  final Map<String, dynamic> _onExtra;
  final Map<String, dynamic> _extra;

  /// Whether [m] is on. A module whose prerequisite is off counts as off, whatever was stored.
  bool isOn(CoachModule m) => _on.contains(m) && (m.needs == null || isOn(m.needs!));

  /// Whether [m] may be switched on now: its prerequisite, if any, is on.
  bool canSwitchOn(CoachModule m) => m.needs == null || isOn(m.needs!);

  /// True when there is nothing to store: no module on and no coach data at all.
  bool get isEmpty =>
      !CoachModule.values.any(isOn) &&
      profile == null &&
      sports.isEmpty &&
      injuries.isEmpty &&
      disliked.isEmpty &&
      soreness.isEmpty &&
      block == null &&
      routineIds.isEmpty &&
      proposals.isEmpty &&
      review.isEmpty &&
      nutrition.isEmpty &&
      _onExtra.isEmpty &&
      _extra.isEmpty;

  /// [m] switched [on] or off.
  ///
  /// Switching a module on while its prerequisite is off changes nothing. Switching a module off also switches off
  /// every module that needs it, directly or through another.
  CoachData withModule(CoachModule m, bool on) {
    if (on && !canSwitchOn(m)) return this;
    final next = {for (final x in CoachModule.values) if (isOn(x)) x};
    if (on) {
      next.add(m);
    } else {
      next.remove(m);
      for (final x in CoachModule.values) {
        if (!_needsChainContains(x, m)) continue;
        next.remove(x);
      }
    }
    return _copy(on: next);
  }

  static bool _needsChainContains(CoachModule x, CoachModule m) {
    for (var n = x.needs; n != null; n = n.needs) {
      if (n == m) return true;
    }
    return false;
  }

  /// A copy with the given parts replaced. A null argument keeps the part. Replacing a part that was stored in a
  /// form this version could not read drops that stored form.
  CoachData copyWith({
    CoachProfile? profile,
    List<ck.UserSport>? sports,
    List<ck.Injury>? injuries,
    List<String>? disliked,
    Map<String, dynamic>? soreness,
    ck.BlockPlan? block,
    Map<String, String>? routineIds,
    List<Map<String, dynamic>>? proposals,
    Map<String, dynamic>? review,
    Map<String, dynamic>? nutrition,
  }) {
    final replaced = {
      if (profile != null) 'profile',
      if (sports != null) 'sports',
      if (injuries != null) 'injuries',
      if (disliked != null) 'disliked',
      if (soreness != null) 'soreness',
      if (block != null) 'block',
    };
    return _copy(
      profile: profile,
      sports: sports,
      injuries: injuries,
      disliked: disliked,
      soreness: soreness,
      block: block,
      routineIds: routineIds,
      proposals: proposals,
      review: review,
      nutrition: nutrition,
      extra: {
        for (final e in _extra.entries)
          if (!replaced.contains(e.key)) e.key: e.value,
      },
    );
  }

  CoachData _copy({
    Set<CoachModule>? on,
    CoachProfile? profile,
    List<ck.UserSport>? sports,
    List<ck.Injury>? injuries,
    List<String>? disliked,
    Map<String, dynamic>? soreness,
    ck.BlockPlan? block,
    Map<String, String>? routineIds,
    List<Map<String, dynamic>>? proposals,
    Map<String, dynamic>? review,
    Map<String, dynamic>? nutrition,
    Map<String, dynamic>? extra,
  }) =>
      CoachData._(
        version: version,
        on: on ?? _on,
        profile: profile ?? this.profile,
        sports: sports ?? this.sports,
        injuries: injuries ?? this.injuries,
        disliked: disliked ?? this.disliked,
        soreness: soreness ?? this.soreness,
        block: block ?? this.block,
        routineIds: routineIds ?? this.routineIds,
        proposals: proposals ?? this.proposals,
        review: review ?? this.review,
        nutrition: nutrition ?? this.nutrition,
        onExtra: _onExtra,
        extra: extra ?? _extra,
      );

  Map<String, dynamic> toJson() => {
        'v': version,
        'on': {
          for (final m in CoachModule.values) m.name: isOn(m),
          for (final e in _onExtra.entries) e.key: jsonCopy(e.value),
        },
        if (profile != null) 'profile': profile!.toJson(),
        if (sports.isNotEmpty) 'sports': [for (final s in sports) s.toJson()],
        if (injuries.isNotEmpty) 'injuries': [for (final i in injuries) i.toJson()],
        if (disliked.isNotEmpty) 'disliked': [...disliked],
        if (soreness.isNotEmpty) 'soreness': jsonCopy(soreness),
        if (block != null) 'block': block!.toJson(),
        if (routineIds.isNotEmpty) 'routineIds': {...routineIds},
        if (proposals.isNotEmpty) 'proposals': jsonCopy(proposals),
        if (review.isNotEmpty) 'review': jsonCopy(review),
        if (nutrition.isNotEmpty) 'nutrition': jsonCopy(nutrition),
        for (final e in _extra.entries) e.key: jsonCopy(e.value),
      };
}
