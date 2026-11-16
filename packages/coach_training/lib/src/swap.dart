// SPDX-License-Identifier: GPL-3.0-only
// Logger swap choices. The page and swapExercise share this list, so the server only accepts what the UI offers.
// ignore_for_file: constant_identifier_names
import 'package:coach_kernel/coach_kernel.dart';

import 'selection.dart';

/// How many substitutes the swap dialog lists.
const SWAP_OPTION_LIMIT = 8;

List<ExerciseDef> swapOptions(ExerciseDef ex, LibraryContext ctx) =>
    substitutionsFor(ex, ctx).take(SWAP_OPTION_LIMIT).toList();

bool isValidSwap(ExerciseDef from, String toExerciseId, LibraryContext ctx) =>
    swapOptions(from, ctx).any((e) => e.id == toExerciseId);
