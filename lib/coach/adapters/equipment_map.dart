// SPDX-License-Identifier: GPL-3.0-only
// The app names equipment with its own strings. This file translates them to the coach packages' equipment.
// The table is documented in docs/coach/ARCHITECTURE.md.
import 'package:coach_kernel/coach_kernel.dart';

const Map<String, Equipment> _toCoach = {
  'Barbell': Equipment.barbell,
  'Dumbbell': Equipment.dumbbell,
  'Kettlebell': Equipment.dumbbell,
  'Machine': Equipment.machine,
  'Cable': Equipment.cable,
  'Bodyweight': Equipment.bodyweight,
  'Weighted': Equipment.bodyweight,
  'Rings': Equipment.bodyweight,
  'Band': Equipment.band,
};

/// Equipment of the app that has no coach equivalent on purpose. An exercise that uses it can be logged but is
/// never picked for a generated plan.
const Set<String> kCoachUnsupportedEquipment = {'Other'};

/// The coach equipment for one of the app's equipment names. Null for the unsupported ones and for equipment
/// the user added by hand.
Equipment? coachEquipmentOf(String equipment) => _toCoach[equipment];

/// What a place offers, in coach terms. The sled is never in the result: the app has no name for it.
Set<Equipment> coachEquipment(Iterable<String> placeEquipment) => {
  for (final e in placeEquipment) ?_toCoach[e],
};
