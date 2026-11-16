// SPDX-License-Identifier: GPL-3.0-only
// The nutrition module's host values: the phase the user can pick, and the coach's daily targets.

/// Whether the coach's calorie target aims to gain, keep or lose weight. Stored as its name under
/// `coach.nutrition.phase`, which is also the coach packages' wire name.
enum CoachNutritionPhase {
  gain,
  maintain,
  loss;

  /// The stored name.
  String get wire => name;

  /// The phase stored as [wire], or null when [wire] is not one.
  static CoachNutritionPhase? fromWire(Object? wire) {
    for (final p in values) {
      if (p.name == wire) return p;
    }
    return null;
  }
}

/// The coach's daily calorie and macro targets, and what they rest on.
final class CoachNutritionTargets {
  CoachNutritionTargets({
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.phase,
    required this.phasePicked,
    required this.bodyweightKg,
    required this.maintenance,
    required this.delta,
    required List<String> warnings,
    required List<String> ruleIds,
  })  : warnings = List.unmodifiable(warnings),
        ruleIds = List.unmodifiable(ruleIds);

  final int kcal;
  final int proteinG;
  final int fatG;
  final int carbsG;

  /// The phase in force.
  final CoachNutritionPhase phase;

  /// True when the user picked [phase]; false when it follows from the coaching goal, or is the default.
  final bool phasePicked;

  /// The bodyweight the targets were worked out for.
  final double bodyweightKg;

  /// Calories a day to keep the current weight, sport included.
  final int maintenance;

  /// Calories a day added (positive) or taken away (negative) for the phase.
  final int delta;

  /// The coach's warnings about these targets, in English: the texts live in the coach packages.
  final List<String> warnings;

  /// The rules behind the targets, warnings included.
  final List<String> ruleIds;
}
