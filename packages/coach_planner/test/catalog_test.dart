// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_planner/coach_planner.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

/// Tracked muscles a split trains as a primary muscle on at least one day. In a plan without main lifts, the
/// main-lift slots are skipped.
Set<TrackedMuscle> _covered(PlannerSplit split, {required bool strength}) => {
  for (final k in split.templates)
    for (final slot in templateFor(k)!.slots)
      if (slot.mainLift == null || strength) ...slotInfo(slot).primary,
};

void main() {
  test('every slot tag has its info', () {
    expect(TAG_INFO.keys.toSet(), SlotTag.values.toSet());
  });

  test('planner template keys are new and their slot keys are unique per template', () {
    for (final t in PLANNER_TEMPLATES.values) {
      expect(TEMPLATES.containsKey(t.key), isFalse, reason: t.key);
      expect(t.slots.map((s) => s.key).toSet().length, t.slots.length, reason: t.key);
      expect(t.slots, isNotEmpty);
    }
  });

  test('split keys are unique and every template resolves', () {
    expect(PLANNER_SPLITS.map((s) => s.key).toSet().length, PLANNER_SPLITS.length);
    for (final s in PLANNER_SPLITS) {
      for (final k in s.templates) {
        expect(templateFor(k), isNotNull, reason: '${s.key}: $k');
      }
      expect(splitByKey(s.key), same(s));
      expect(s.def.templates, s.templates);
    }
    expect(splitByKey('nope'), isNull);
  });

  test('several options for each of 2 to 6 days', () {
    expect(splitsFor(1).map((s) => s.key), ['FB1']);
    for (var d = 2; d <= 6; d++) {
      final general = splitsFor(d).where((s) => !s.strengthOnly).toList();
      expect(general.length, greaterThanOrEqualTo(3), reason: '$d days');
      expect(splitsFor(d).where((s) => s.strengthOnly), hasLength(1), reason: '$d days');
      expect(general.map((s) => s.family).toSet().length, greaterThanOrEqualTo(3), reason: '$d days');
    }
  });

  test('every split trains every tracked muscle directly', () {
    // One day a week is for keeping what you have; its single session can't train every muscle directly.
    for (final s in PLANNER_SPLITS.where((s) => s.days > 1)) {
      expect(_covered(s, strength: s.strengthOnly), TRACKED_MUSCLES.toSet(), reason: s.key);
    }
  });

  test('strength splits train each main lift at least twice a week, counting related lifts as half', () {
    for (final s in PLANNER_SPLITS.where((s) => s.strengthOnly)) {
      final f = mainLiftFrequency(s);
      for (final l in [MainLift.squat, MainLift.bench, MainLift.deadlift]) {
        expect(f[l], greaterThanOrEqualTo(2), reason: '${s.key} ${l.wire}');
      }
      expect(s.hasMainLifts, isTrue);
    }
    expect(mainLiftFrequency(splitByKey('UL4')!)[MainLift.bench], 1.5); // bench 1, OHP day 0.5
    expect(mainLiftFrequency(splitByKey('UL4')!)[MainLift.squat], 1.5);
    expect(splitByKey('FPP6')!.hasMainLifts, isFalse);
    expect(splitByKey('PPL6')!.hasMainLifts, isTrue); // its lower day has the squat
  });

  test('muscle-group splits are for advanced lifters only', () {
    for (final s in PLANNER_SPLITS.where((s) => s.family == SplitFamily.bodyPart)) {
      expect(s.minStatus, Status.advanced, reason: s.key);
    }
  });

  test('a main-lift slot counts as its lift', () {
    final slot = templateFor('str_sbd_a')!.slots.first;
    expect(slot.mainLift, MainLift.squat);
    expect(slotInfo(slot).primary, [MuscleId.quads, MuscleId.glutes]);
  });

  test('family wires round trip', () {
    for (final f in SplitFamily.values) {
      expect(SplitFamily.fromWire(f.wire), f);
    }
    expect(() => SplitFamily.fromWire('x'), throwsFormatException);
    expect(splitByKey('UL4')!.toJson()['family'], 'upper_lower');
  });
}
