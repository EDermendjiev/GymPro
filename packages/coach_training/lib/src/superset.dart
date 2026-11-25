// SPDX-License-Identifier: GPL-3.0-only
// Superset pairing when a session runs long: two isolation exercises for different muscles share one rest.
// Rule: T-PLN-08.
import 'dart:math' as math;

import 'package:coach_kernel/coach_kernel.dart';

/// Seconds for [setsA] sets of one exercise and [setsB] of another done as a superset. Each paired round takes one
/// rest, the longer of the two; the sets left over rest as usual.
int supersetSeconds({
  required int setsA,
  required int workA,
  required int restA,
  required int setsB,
  required int workB,
  required int restB,
}) {
  final rounds = math.min(setsA, setsB);
  return setsA * workA +
      setsB * workB +
      (setsA - rounds) * restA +
      (setsB - rounds) * restB +
      rounds * math.max(restA, restB);
}

/// One exercise of a session as superset pairing sees it. [free]: it may be paired (not main-lift work).
typedef SupersetItem = ({Category category, Set<MuscleId> muscles, int sets, bool free});

/// The pairs that may be supersets, best first: two free isolation exercises that share no muscle. More paired
/// rounds (more rest saved) come first, then earlier positions. Each pair is (earlier, later).
List<(int, int)> supersetCandidates(List<SupersetItem> items) {
  final out = <(int, int, int)>[];
  for (var a = 0; a < items.length; a++) {
    final x = items[a];
    if (!x.free || x.category != Category.isolation) continue;
    for (var b = a + 1; b < items.length; b++) {
      final y = items[b];
      if (!y.free || y.category != Category.isolation) continue;
      if (x.muscles.any(y.muscles.contains)) continue;
      out.add((a, b, math.min(x.sets, y.sets)));
    }
  }
  out.sort((p, q) {
    if (p.$3 != q.$3) return q.$3 - p.$3;
    if (p.$1 != q.$1) return p.$1 - q.$1;
    return p.$2 - q.$2;
  });
  return [for (final p in out) (p.$1, p.$2)];
}

/// Supersets for a session that runs long: pairs from [supersetCandidates], each exercise in at most one pair, added
/// one at a time until [fits] accepts the pairs so far. Empty when the session already fits.
List<(int, int)> pickSupersets(List<SupersetItem> items, bool Function(List<(int, int)> pairs) fits) {
  final chosen = <(int, int)>[];
  if (fits(chosen)) return chosen;
  final taken = <int>{};
  for (final (a, b) in supersetCandidates(items)) {
    if (taken.contains(a) || taken.contains(b)) continue;
    chosen.add((a, b));
    taken.addAll([a, b]);
    if (fits(chosen)) break;
  }
  return chosen;
}

/// [list] with each pair's later item moved to right after its earlier one. Returns the new order and, per new
/// position, whether that item is done as a superset with the next one.
List<(T, bool)> applySupersets<T>(List<T> list, List<(int, int)> pairs) {
  final partner = {for (final (a, b) in pairs) a: b};
  final moved = {for (final (_, b) in pairs) b};
  return [
    for (final (i, x) in list.indexed)
      if (!moved.contains(i)) ...[
        (x, partner.containsKey(i)),
        if (partner[i] case final b?) (list[b], false),
      ],
  ];
}
