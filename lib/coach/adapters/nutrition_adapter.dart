// SPDX-License-Identifier: GPL-3.0-only
// The app's profile fields that the nutrition module reads, in the coach's terms.
import 'package:coach_kernel/coach_kernel.dart' as ck;
import 'package:coach_nutrition/coach_nutrition.dart' as cn;

/// The coach's activity band for the app's activity multiplier [activity]: the band whose default multiplier is
/// nearest. A tie goes to the more active band.
///
/// The two scales differ: the app multiplies a resting rate that depends on age and height, the coach one that
/// depends on bodyweight only, so equal labels do not mean equal numbers. The app's four choices give Sedentary
/// (1.2) and Light (1.375) → sedentary, Moderate (1.55, a tie) and Active (1.725) → lightly active.
ck.Lifestyle coachLifestyleFor(double activity) {
  var best = ck.Lifestyle.values.first;
  var bestGap = double.infinity;
  for (final l in ck.Lifestyle.values) {
    // Rounded so that the float error in a difference such as 1.55 − 1.45 cannot break a tie.
    final gap = ((cn.defaultMultiplier(l) - activity).abs() * 1e6).round() / 1e6;
    if (gap <= bestGap) {
      best = l;
      bestGap = gap;
    }
  }
  return best;
}

/// The coach's sex for the app profile's `sex` value.
ck.Sex coachSexFor(String sex) => switch (sex) {
      'male' => ck.Sex.male,
      'female' => ck.Sex.female,
      _ => ck.Sex.unspecified,
    };
