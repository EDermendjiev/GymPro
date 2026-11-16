// SPDX-License-Identifier: GPL-3.0-only
// The seed exercise library, shipped once in the kernel's exercises.json; recovery fixtures store it as '@seed'.
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';

final Object? seedJson = loadFixture('exercises.json', root: '../coach_kernel/test/fixtures').single.output;

List<ExerciseDef> seedExercises() => [
  for (final e in seedJson as List) ExerciseDef.fromJson(e as Map<String, dynamic>),
];
