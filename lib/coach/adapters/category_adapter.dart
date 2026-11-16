// SPDX-License-Identifier: GPL-3.0-only
// The coach's exercise category for one of the app's exercises.
//
// This is a fallback. The app's exercises carry no coaching attributes yet, so the category is guessed from what
// the app does know: the equipment, the primary muscle and the name. The per-exercise attributes table
// (lib/coach/data/coach_meta.dart, still to come) will replace this guess with annotated data; until then this
// function is the only place that guesses.
import 'package:coach_kernel/coach_kernel.dart' as ck;

import '../../models/exercise.dart';

/// Equipment that moves freely in space. Everything else (machines, Smith machines, cables, bands) guides the
/// path and counts as a machine.
const Set<String> _freeEquipment = {'Barbell', 'Dumbbell', 'Kettlebell', 'Bodyweight', 'Weighted', 'Rings'};

const Set<String> _legs = {'quads', 'glutes', 'hamstrings'};
const Set<String> _pushers = {'chest', 'shoulders', 'triceps'};
const Set<String> _pullers = {'back', 'biceps'};

const List<String> _lowerWords = [
  'squat',
  'deadlift',
  'lunge',
  'leg press',
  'step-up',
  'step up',
  'hip thrust',
  'bridge',
  'good morning',
  'rack pull',
  'swing',
  'pull through',
];
const List<String> _pressWords = ['press', 'push-up', 'push up', 'pushup', 'dip'];
const List<String> _pullWords = ['row', 'pull-up', 'pull up', 'pullup', 'chin-up', 'chin up', 'pulldown', 'muscle-up'];

/// The coach category of [e], guessed from its equipment, primary muscle and English name:
///  - a squat, hinge, lunge or leg press for the legs is a lower-body compound, free or machine by equipment;
///  - a press, push-up or dip for the chest, shoulders or triceps is an upper-body press, free or machine;
///  - a row, pull-up, chin-up or pulldown for the back or biceps is a pulling compound;
///  - everything else, calf raises included, is an isolation.
ck.Category coachCategoryFor(Exercise e) {
  final name = e.name.toLowerCase();
  final free = _freeEquipment.contains(e.equipment) && !name.contains('smith');
  bool has(List<String> words) => words.any(name.contains);
  if (name.contains('calf')) return ck.Category.isolation;
  if (_legs.contains(e.primary) && has(_lowerWords)) {
    return free ? ck.Category.lowerFreeCompound : ck.Category.lowerMachineCompound;
  }
  if (_pushers.contains(e.primary) && has(_pressWords)) {
    return free ? ck.Category.upperFreePress : ck.Category.upperMachinePress;
  }
  if (_pullers.contains(e.primary) && has(_pullWords) && !name.contains('straight-arm')) {
    return ck.Category.pullingCompound;
  }
  return ck.Category.isolation;
}

/// Whether [e] is a barbell lift of the lower body, the only kind the coach may move up by a larger jump.
bool coachHeavyLowerBarbell(Exercise e) =>
    e.equipment == 'Barbell' && coachCategoryFor(e) == ck.Category.lowerFreeCompound;
