// SPDX-License-Identifier: GPL-3.0-only
// Exercise definitions.
import 'enums.dart';

/// Anything that lists the muscles it trains. Stands in for `Pick<ExerciseDef, 'muscles'>` in the reference.
abstract interface class HasMuscles {
  List<ExerciseMuscle> get muscles;
}

class ExerciseMuscle {
  ExerciseMuscle({required this.muscle, required this.role});

  factory ExerciseMuscle.fromJson(Map<String, dynamic> json) => ExerciseMuscle(
    muscle: MuscleId.fromWire(json['muscle'] as String),
    role: MuscleRole.fromWire(json['role'] as String),
  );

  final MuscleId muscle;
  final MuscleRole role;

  Map<String, dynamic> toJson() => {'muscle': muscle.wire, 'role': role.wire};
}

class ExerciseDef implements HasMuscles {
  ExerciseDef({
    required this.id,
    required this.slug,
    required this.name,
    required this.pattern,
    required this.category,
    required this.equipment,
    required this.isMainLift,
    this.mainLiftKey,
    required this.longLengthBias,
    required this.unilateral,
    required this.axialLoad,
    required this.impactLowerBody,
    this.defaultIncrementKg,
    required this.muscles,
    required this.substitutions,
    required this.slotTags,
    required this.popularity,
    this.custom,
  });

  factory ExerciseDef.fromJson(Map<String, dynamic> json) => ExerciseDef(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
    pattern: MovementPattern.fromWire(json['pattern'] as String),
    category: Category.fromWire(json['category'] as String),
    equipment: [for (final x in json['equipment'] as List) Equipment.fromWire(x as String)],
    isMainLift: json['isMainLift'] as bool,
    mainLiftKey: json['mainLiftKey'] == null ? null : MainLift.fromWire(json['mainLiftKey'] as String),
    longLengthBias: json['longLengthBias'] as bool,
    unilateral: json['unilateral'] as bool,
    axialLoad: json['axialLoad'] as bool,
    impactLowerBody: json['impactLowerBody'] as bool,
    defaultIncrementKg: json['defaultIncrementKg'] == null
        ? null
        : (json['defaultIncrementKg'] as num).toDouble(),
    muscles: [for (final x in json['muscles'] as List) ExerciseMuscle.fromJson(x as Map<String, dynamic>)],
    substitutions: [for (final x in json['substitutions'] as List) x as String],
    slotTags: [for (final x in json['slotTags'] as List) SlotTag.fromWire(x as String)],
    popularity: json['popularity'] as int,
    custom: json['custom'] == null ? null : json['custom'] as bool,
  );

  final String id;
  final String slug;
  final String name;
  final MovementPattern pattern;
  final Category category;
  final List<Equipment> equipment;
  final bool isMainLift;
  final MainLift? mainLiftKey;
  final bool longLengthBias;
  final bool unilateral;
  final bool axialLoad;
  final bool impactLowerBody;
  final double? defaultIncrementKg;
  @override
  final List<ExerciseMuscle> muscles;
  final List<String> substitutions;
  final List<SlotTag> slotTags;

  /// Lower = more common.
  final int popularity;
  final bool? custom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name': name,
    'pattern': pattern.wire,
    'category': category.wire,
    'equipment': [for (final x in equipment) x.wire],
    'isMainLift': isMainLift,
    if (mainLiftKey case final mainLiftKey?) 'mainLiftKey': mainLiftKey.wire,
    'longLengthBias': longLengthBias,
    'unilateral': unilateral,
    'axialLoad': axialLoad,
    'impactLowerBody': impactLowerBody,
    'defaultIncrementKg': ?defaultIncrementKg,
    'muscles': [for (final x in muscles) x.toJson()],
    'substitutions': [...substitutions],
    'slotTags': [for (final x in slotTags) x.wire],
    'popularity': popularity,
    'custom': ?custom,
  };

  /// A shallow copy with the given fields replaced, like an object spread. A null argument keeps the field.
  ExerciseDef copyWith({
    String? id,
    String? slug,
    String? name,
    MovementPattern? pattern,
    Category? category,
    List<Equipment>? equipment,
    bool? isMainLift,
    MainLift? mainLiftKey,
    bool? longLengthBias,
    bool? unilateral,
    bool? axialLoad,
    bool? impactLowerBody,
    double? defaultIncrementKg,
    List<ExerciseMuscle>? muscles,
    List<String>? substitutions,
    List<SlotTag>? slotTags,
    int? popularity,
    bool? custom,
  }) => ExerciseDef(
    id: id ?? this.id,
    slug: slug ?? this.slug,
    name: name ?? this.name,
    pattern: pattern ?? this.pattern,
    category: category ?? this.category,
    equipment: equipment ?? this.equipment,
    isMainLift: isMainLift ?? this.isMainLift,
    mainLiftKey: mainLiftKey ?? this.mainLiftKey,
    longLengthBias: longLengthBias ?? this.longLengthBias,
    unilateral: unilateral ?? this.unilateral,
    axialLoad: axialLoad ?? this.axialLoad,
    impactLowerBody: impactLowerBody ?? this.impactLowerBody,
    defaultIncrementKg: defaultIncrementKg ?? this.defaultIncrementKg,
    muscles: muscles ?? this.muscles,
    substitutions: substitutions ?? this.substitutions,
    slotTags: slotTags ?? this.slotTags,
    popularity: popularity ?? this.popularity,
    custom: custom ?? this.custom,
  );
}
