// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_planner/coach_planner.dart';
import 'package:test/test.dart';

Map<TrackedMuscle, double> _all(double n) => {for (final m in TRACKED_MUSCLES) m: n};

void main() {
  test('frequency by weekly sets', () {
    expect(frequencyFor(4), (least: 1, preferred: 2));
    expect(frequencyFor(10), (least: 1, preferred: 2));
    expect(frequencyFor(11), (least: 2, preferred: 2));
    expect(frequencyFor(20), (least: 2, preferred: 2));
    expect(frequencyFor(24), (least: 3, preferred: 3));
  });

  test('every target is reached, without much over it', () {
    final cases = {
      'FB2': [6.0],
      'FB3': [6.0, 10.0],
      'UL4': [6.0, 10.0, 14.0],
      'LPP3': [6.0, 10.0],
      'BP5': [6.0, 10.0],
      'ALT4': [6.0, 10.0, 14.0],
      'PPL6': [6.0, 10.0, 14.0],
    };
    for (final MapEntry(:key, value: ns) in cases.entries) {
      final split = splitByKey(key)!;
      for (final n in ns) {
        final est = estimateWeek(split, _all(n), strength: false);
        expect(est.unmet, isEmpty, reason: '$key $n');
        for (final e in est.weekly.entries) {
          expect(e.value, greaterThanOrEqualTo(n), reason: '$key $n ${e.key.wire}');
        }
        expect(est.sessions, hasLength(split.days));
      }
    }
  });

  test('a split without room for the volume leaves it unmet', () {
    // Two full-body days hold at most 8 exercises each.
    expect(estimateWeek(splitByKey('FB2')!, _all(14), strength: false).unmet, isNotEmpty);
  });

  test('lower targets give shorter sessions', () {
    final split = splitByKey('UL4')!;
    final low = estimateWeek(split, _all(4), strength: false);
    final high = estimateWeek(split, _all(16), strength: false);
    expect(low.avgMinutes, lessThan(high.avgMinutes));
    for (final s in low.sessions) {
      for (final slot in s.slots) {
        expect(slot.sets, greaterThanOrEqualTo(2));
        expect(slot.sets, lessThanOrEqualTo(5));
      }
    }
  });

  test('main lifts count only for a strength plan and its lifts', () {
    final split = splitByKey('UL4')!;
    bool hasMain(WeekEstimate e) => e.sessions.any((s) => s.slots.any((x) => x.main));
    expect(hasMain(estimateWeek(split, _all(10), strength: false)), isFalse);
    final str = estimateWeek(split, _all(10), strength: true);
    expect(hasMain(str), isTrue);
    expect(str.sessions.expand((s) => s.slots).where((x) => x.main && x.sets != MAIN_LIFT_SETS), isEmpty);
    final benchOnly = estimateWeek(split, _all(10), strength: true, lifts: [MainLift.bench]);
    expect(benchOnly.sessions.expand((s) => s.slots).where((x) => x.main).map((x) => x.tag).toSet(), {
      SlotTag.pressFlat,
    });
  });

  test('slots the equipment cannot fill are counted and never used', () {
    final tags = {for (final t in SlotTag.values) t}
      ..removeAll([SlotTag.legExt, SlotTag.legCurl, SlotTag.legCurlSeated]);
    final est = estimateWeek(splitByKey('UL4')!, _all(10), strength: false, availableTags: tags);
    expect(est.missingSlots, greaterThan(0));
    expect(est.missingShare, greaterThan(0));
    for (final s in est.sessions) {
      for (final slot in s.slots) {
        expect(tags.contains(slot.tag), isTrue, reason: slot.key);
      }
    }
    expect(est.unmet, isEmpty); // the hinge and hip extension still cover the hamstrings
  });

  test('a muscle no slot or extra can train is unmet', () {
    final est = estimateWeek(
      splitByKey('UL4')!,
      _all(10),
      strength: false,
      availableTags: {for (final t in SlotTag.values) t}..remove(SlotTag.calf),
    );
    expect(est.unmet, [MuscleId.calves]);
  });

  test('JSON lists each session and its slots', () {
    final json = estimateWeek(splitByKey('FB2')!, _all(8), strength: false).toJson();
    expect((json['sessions'] as List), hasLength(2));
    expect(json['unmet'], isEmpty);
  });
}
