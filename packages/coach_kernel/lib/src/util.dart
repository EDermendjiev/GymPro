// SPDX-License-Identifier: GPL-3.0-only
// Pure helpers. Dates are ISO 'YYYY-MM-DD' strings handled in UTC so results never depend on the host clock.
import 'dart:math' as math;

/// Rounds like the fixture generator: to the nearest integer, halves toward +infinity (also for negatives:
/// -2.5 becomes -2). Dart's `num.round()` rounds halves away from zero, so it must not be used in ported code.
///
/// The fraction is taken by subtraction, which is exact, so values just below a half (0.49999999999999994)
/// are not pushed over it the way `(x + 0.5).floor()` would.
int jsRound(num x) {
  final f = x.floorToDouble();
  return (x - f >= 0.5 ? f + 1 : f).toInt();
}

/// `clamp` in the reference. Renamed because `num.clamp` already exists in Dart with another argument order.
double clampNum(num x, num lo, num hi) => math.min(hi, math.max(lo, x)).toDouble();
double lerp(num a, num b, num t) => (a + (b - a) * t).toDouble();
double round1(num x) => jsRound(x * 10) / 10;
int round5(num x) => jsRound(x / 5) * 5;
int round10(num x) => jsRound(x / 10) * 10;

/// Round half up with a small tolerance for float noise (2.4999999999 becomes 3, like 2.5). Used for deload set cuts.
int roundHalfUp(num x) => (x + 0.5 + 1e-9).floor();

double _fix(num x) => jsRound(x * 1000) / 1000;
double roundToStep(num x, num step) => _fix(jsRound(x / step) * step);
double roundDownToStep(num x, num step) => _fix((x / step + 1e-9).floor() * step);
double roundUpToStep(num x, num step) => _fix((x / step - 1e-9).ceil() * step);

double sum(Iterable<num> xs) {
  var total = 0.0;
  for (final x in xs) {
    total += x;
  }
  return total;
}

double mean(List<num> xs) => xs.isEmpty ? 0 : sum(xs) / xs.length;

double variance(List<num> xs) {
  if (xs.isEmpty) return 0;
  final m = mean(xs);
  return mean([for (final x in xs) (x - m) * (x - m)]);
}

double median(List<num> xs) {
  if (xs.isEmpty) return 0;
  // Equal numbers are interchangeable, so an unstable sort is safe here.
  final s = [...xs]..sort((a, b) => a.compareTo(b));
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid].toDouble() : (s[mid - 1] + s[mid]) / 2;
}

/// `List.sort` is not guaranteed stable in Dart; the reference relies on a stable sort for tie-breaks.
/// Returns a new list; [xs] is left as it was.
List<T> stableSorted<T>(Iterable<T> xs, int Function(T a, T b) compare) {
  final indexed = xs.toList().asMap().entries.toList()
    ..sort((a, b) {
      final c = compare(a.value, b.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

// ---------- Dates ----------
DateTime _toUtc(String iso) => DateTime.utc(
  int.parse(iso.substring(0, 4)),
  int.parse(iso.substring(5, 7)),
  int.parse(iso.substring(8, 10)),
);

String _two(int n) => n.toString().padLeft(2, '0');
String _fromUtc(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

String addDays(String iso, int n) {
  final d = _toUtc(iso);
  return _fromUtc(DateTime.utc(d.year, d.month, d.day + n));
}

/// ISO weekday: Monday = 1 … Sunday = 7.
int isoWeekday(String iso) => _toUtc(iso).weekday;
String mondayOf(String iso) => addDays(iso, 1 - isoWeekday(iso));
int daysBetween(String a, String b) => _toUtc(b).difference(_toUtc(a)).inDays;
bool isWeekend(String iso) => isoWeekday(iso) >= 6;
List<String> dateRange(String start, int days) => [for (var i = 0; i < days; i++) addDays(start, i)];

List<List<T>> combinations<T>(List<T> items, int k) {
  final out = <List<T>>[];
  void rec(int start, List<T> acc) {
    if (acc.length == k) {
      out.add([...acc]);
      return;
    }
    for (var i = start; i < items.length; i++) {
      acc.add(items[i]);
      rec(i + 1, acc);
      acc.removeLast();
    }
  }

  rec(0, []);
  return out;
}

/// Distinct values in first-seen order.
List<T> uniq<T>(Iterable<T> xs) => {...xs}.toList();
