// SPDX-License-Identifier: GPL-3.0-only
// The app's profile fields that the nutrition module reads, in the coach's terms.
import 'package:coach_kernel/coach_kernel.dart' as ck;

/// The activity multipliers the app's profile screen offers (Sedentary, Light, Moderate, Active), lowest first.
/// They are written out in `lib/screens/settings_screen.dart`; a test checks that the two lists agree.
const List<double> coachActivityChoices = [1.2, 1.375, 1.55, 1.725];

/// The coach's activity band for the app's activity multiplier [activity], by rank: the app's choices, lowest
/// first, map in order to sedentary, lightly active, active and very active.
///
/// The two scales are not comparable number for number (the app multiplies a resting rate that depends on age and
/// height, the coach one that depends on bodyweight only), so only the order is used. A value that is not one of
/// the choices takes the band of the nearer choice, a tie going to the more active one; so anything below the first
/// choice is sedentary and anything above the last is very active.
ck.Lifestyle coachLifestyleFor(double activity) {
  final bands = ck.Lifestyle.values;
  var best = 0;
  var bestGap = double.infinity;
  for (var i = 0; i < coachActivityChoices.length && i < bands.length; i++) {
    // Rounded so that the float error in a difference cannot break a tie.
    final gap = ((coachActivityChoices[i] - activity).abs() * 1e6).round() / 1e6;
    if (gap <= bestGap) {
      best = i;
      bestGap = gap;
    }
  }
  return bands[best];
}

/// The coach's sex for the app profile's `sex` value.
ck.Sex coachSexFor(String sex) => switch (sex) {
      'male' => ck.Sex.male,
      'female' => ck.Sex.female,
      _ => ck.Sex.unspecified,
    };
