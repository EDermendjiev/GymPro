// SPDX-License-Identifier: GPL-3.0-only
// Helpers for reading stored JSON that may come from anywhere: an old backup, a newer app, a hand-edited file.

/// A deep copy of a JSON-shaped value in which every map is a `Map<String, dynamic>` and every list a
/// `List<dynamic>`, whatever the static types of the input were. Map keys that are not strings are turned into
/// strings. Values that JSON cannot hold are kept as they are.
Object? jsonCopy(Object? v) {
  if (v is Map) return <String, dynamic>{for (final e in v.entries) e.key.toString(): jsonCopy(e.value)};
  if (v is List) return <dynamic>[for (final x in v) jsonCopy(x)];
  return v;
}

/// [v] as a string-keyed map, or null when it is not a map.
Map<String, dynamic>? jsonMap(Object? v) => v is Map ? jsonCopy(v) as Map<String, dynamic> : null;
