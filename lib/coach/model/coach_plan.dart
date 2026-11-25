// SPDX-License-Identifier: GPL-3.0-only
// What the plan module hands back and forth with the app's state, in the app's own terms. CoachFacade builds the
// answers from the coach packages' block; the app's state never sees a package type.
import '../../models/exercise.dart';
import '../../models/workout.dart';
import 'coach_choices.dart';
import 'coach_data.dart';
import 'coach_recovery.dart';

bool _never(String _) => false;

/// Everything the coach needs to know about the app to build a plan or a quick workout.
class CoachPlanInputs {
  CoachPlanInputs({
    required this.today,
    required this.coach,
    required this.exercises,
    required this.archived,
    required this.sessions,
    required this.equipment,
    required this.barbellStepKg,
    required this.weeklyGoal,
    this.skip = _never,
    this.bodyweight = _never,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.activity,
  });

  final DateTime today;
  final CoachData coach;

  /// Every exercise of the app, the user's own included.
  final List<Exercise> exercises;
  final Set<String> archived;
  final List<LoggedSession> sessions;

  /// The equipment of the place the user trains at, as the app names it.
  final Set<String> equipment;

  /// The app's weight step, in kilograms: the smallest jump on a barbell.
  final double barbellStepKg;

  /// The app's weekly goal (sessions per week), for the training days when the profile has none.
  final int weeklyGoal;

  /// Exercises whose logs are not strength sets (cardio, timed, stretches).
  final bool Function(String exerciseId) skip;

  /// Exercises done with the body alone.
  final bool Function(String exerciseId) bodyweight;

  /// The app profile's body data, for the plan design; null when unknown. [sex] as the app names it.
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;

  /// The app profile's activity multiplier, or null when unknown.
  final double? activity;

  /// The same inputs with [coach] in place of the coach's data.
  CoachPlanInputs withCoach(CoachData coach) => CoachPlanInputs(
        today: today,
        coach: coach,
        exercises: exercises,
        archived: archived,
        sessions: sessions,
        equipment: equipment,
        barbellStepKg: barbellStepKg,
        weeklyGoal: weeklyGoal,
        skip: skip,
        bodyweight: bodyweight,
        age: age,
        sex: sex,
        heightCm: heightCm,
        weightKg: weightKg,
        activity: activity,
      );
}

/// One exercise of a coach routine: the sets the block's first session of the routine prescribes.
class CoachRoutineExercise {
  CoachRoutineExercise({
    required this.exerciseId,
    required List<PlannedSet> sets,
    required this.restSeconds,
    required this.repMin,
    required this.repMax,
    this.chainToNext = false,
  }) : sets = List.unmodifiable(sets);

  final String exerciseId;
  final List<PlannedSet> sets;
  final int restSeconds;

  /// The rep range of the exercise's working sets, for its Auto progression rule.
  final int repMin;
  final int repMax;

  /// Done as a superset with the next exercise of the routine: chained to it.
  final bool chainToNext;
}

/// One routine of the plan: one per session template of the block.
class CoachRoutinePlan {
  CoachRoutinePlan({required this.templateKey, required this.title, required List<CoachRoutineExercise> exercises})
      : exercises = List.unmodifiable(exercises);

  final String templateKey;

  /// The template's name, in English: it comes from the coach packages.
  final String title;
  final List<CoachRoutineExercise> exercises;
}

/// A built plan: the coach's data with the new block in it, the routines to write and the week to plan.
class CoachBuiltPlan {
  CoachBuiltPlan({required this.data, required List<CoachRoutinePlan> routines, required Map<int, String> week})
      : routines = List.unmodifiable(routines),
        week = Map.unmodifiable(week);

  final CoachData data;
  final List<CoachRoutinePlan> routines;

  /// Template key by weekday (1 = Monday … 7 = Sunday).
  final Map<int, String> week;
}

/// One set the coach opens a session with. A null [loadKg] means the coach has no load to suggest yet.
class CoachOpeningSet {
  const CoachOpeningSet({required this.reps, required this.loadKg});

  final int reps;
  final double? loadKg;
}

/// Where the block stands today, for the Home card and the reason sheet.
class CoachBlockSummary {
  CoachBlockSummary({
    required this.kind,
    required this.week,
    required this.weeks,
    required List<String> explanations,
    required List<String> rules,
    required List<String> warnings,
  })  : explanations = List.unmodifiable(explanations),
        rules = List.unmodifiable(rules),
        warnings = List.unmodifiable(warnings);

  final CoachBlockKind kind;

  /// The current week, from 1.
  final int week;
  final int weeks;

  /// Why the block looks the way it does, in English: the texts come from the coach packages.
  final List<String> explanations;

  /// The plain-words summary of every rule behind the block, in English.
  final List<String> rules;

  /// The coach's warnings about the block, in English.
  final List<String> warnings;
}

/// A quick workout: the exercises the coach picks, and what each of them opens with.
class CoachQuickSession {
  CoachQuickSession({required List<String> exerciseIds, required Map<String, List<CoachOpeningSet>> sets,
      required List<String> muscles})
      : exerciseIds = List.unmodifiable(exerciseIds),
        sets = Map.unmodifiable(sets),
        muscles = List.unmodifiable(muscles);

  final List<String> exerciseIds;
  final Map<String, List<CoachOpeningSet>> sets;

  /// The app's muscles the session trains, in the order the coach picked them.
  final List<String> muscles;
}

/// Another split the plan preview offers.
class CoachPlanOption {
  CoachPlanOption({required this.splitKey, required this.name, required this.summary, required this.recommended});

  final String splitKey;

  /// The split's name, in English: it comes from the coach packages.
  final String name;

  /// One line on what it gives, in English; null for the coach's own pick (the screen says so in its own words).
  final String? summary;

  /// The coach's own pick for the answers.
  final bool recommended;
}

/// The plan the answers would build, without building it: what the plan preview shows.
class CoachPlanPreview {
  CoachPlanPreview({
    required this.splitKey,
    required this.splitName,
    required this.liftDays,
    required this.minutes,
    required Map<int, String> week,
    required Map<CoachArea, int> weeklySets,
    required List<String> reasons,
    List<int> cardioDays = const [],
    required List<String> warnings,
    required List<CoachPlanOption> options,
  })  : week = Map.unmodifiable(week),
        cardioDays = List.unmodifiable(cardioDays),
        weeklySets = Map.unmodifiable(weeklySets),
        reasons = List.unmodifiable(reasons),
        warnings = List.unmodifiable(warnings),
        options = List.unmodifiable(options);

  final String splitKey;

  /// In English: it comes from the coach packages.
  final String splitName;
  final int liftDays;

  /// About how long a session takes.
  final int minutes;

  /// Session title by weekday (1 = Monday … 7 = Sunday), in English.
  final Map<int, String> week;

  /// Weekly sets per muscle the plan gives, in the coach's muscle order.
  final Map<CoachArea, int> weeklySets;

  /// The main reasons for the plan, in English, most important first.
  final List<String> reasons;

  /// Weekdays for low-impact cardio (fat loss and recomposition with cardio sessions asked for), sorted.
  final List<int> cardioDays;
  final List<String> warnings;

  /// The other splits that fit the answers, the coach's own pick among them when the user chose another.
  final List<CoachPlanOption> options;
}
