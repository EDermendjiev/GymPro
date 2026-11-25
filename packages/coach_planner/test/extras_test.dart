// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_planner/coach_planner.dart';
import 'package:coach_training/coach_training.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('daily step target (N-ACT-01)', () {
    test('only fat loss and recomposition get one', () {
      expect(dailyStepTarget(Goal.leanGain, baseline: 5000), isNull);
      expect(dailyStepTarget(Goal.strength), isNull);
      expect(dailyStepTarget(Goal.sportSupport), isNull);
    });

    test('without a usual count: the 7,000 minimum', () {
      final t = dailyStepTarget(Goal.fatLoss)!;
      expect(t.steps, 7000);
      expect(t.baseline, isNull);
    });

    test('fat loss: about 2,500 over the usual count, at least 7,000', () {
      expect(dailyStepTarget(Goal.fatLoss, baseline: 8000)!.steps, 10500);
      expect(dailyStepTarget(Goal.fatLoss, baseline: 6100)!.steps, 8500);
    });

    test('never more than half again the usual count at once', () {
      final t = dailyStepTarget(Goal.fatLoss, baseline: 3000)!;
      expect(t.steps, 4500);
      expect(t.capped, isTrue);
    });

    test('recomposition: the usual count, at least 7,000', () {
      expect(dailyStepTarget(Goal.recomp, baseline: 9200)!.steps, 9000);
      expect(dailyStepTarget(Goal.recomp, baseline: 5200)!.steps, 7000);
      expect(dailyStepTarget(Goal.recomp, baseline: 12000)!.steps, 12000);
    });
  });

  group('cardio days (N-ACT-02)', () {
    // Upper/Lower on Mon, Tue, Thu, Fri.
    const ul = {1: Region.upper, 2: Region.lower, 4: Region.upper, 5: Region.lower};

    test('none asked, none placed', () {
      expect(placeCardio(0, lifting: ul), isEmpty);
    });

    test('only on days without lifting, never the day before a lower-body day', () {
      // Free: Wed, Sat, Sun. Wed is before Thu (upper), Sat and Sun are free of legs the next day except Sun → Mon upper.
      final days = placeCardio(2, lifting: ul);
      expect(days.length, 2);
      for (final d in days) {
        expect(ul.containsKey(d), isFalse);
        expect(ul[d % 7 + 1], isNot(Region.lower));
      }
    });

    test('one day of the week stays free', () {
      expect(placeCardio(3, lifting: ul).length, 2);
    });

    test('the days are spread', () {
      expect(placeCardio(2, lifting: const {1: Region.full, 3: Region.full, 5: Region.full}), [2, 6]);
    });

    test('a day before a full-body day is used only when nothing better is left', () {
      final days = placeCardio(2, lifting: const {1: Region.full, 3: Region.full, 5: Region.full});
      // Sat (before Sun, free) is preferred; Tue, Thu and Sun come before a full-body day.
      expect(days, contains(6));
    });

    test('hard sport days are kept apart, and so is the day before a leg-heavy one', () {
      final days = placeCardio(3,
          lifting: const {1: Region.upper, 3: Region.upper}, sports: [sport('football', [6])]);
      expect(days, isNot(contains(6)));
      expect(days, isNot(contains(5)));
    });

    test('the most sessions is three', () {
      expect(placeCardio(5, lifting: const {1: Region.upper}).length, 3);
    });
  });
}
