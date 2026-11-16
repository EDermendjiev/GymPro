// SPDX-License-Identifier: GPL-3.0-only
// Package-internal: not exported from the barrel.

/// A number as the reference's string interpolation writes it: whole values without a fraction (`1`, not
/// Dart's `1.0`), negative zero as `0`, everything else as the shortest round-trip form, which Dart and the
/// reference share for the magnitudes these messages use.
String jsNumber(num x) {
  if (x is int) return x.toString();
  final d = x.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e21) return d.toInt().toString();
  return d.toString();
}
