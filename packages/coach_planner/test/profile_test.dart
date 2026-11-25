// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_planner/coach_planner.dart';
import 'package:test/test.dart';

void main() {
  group('resolveStatus', () {
    test('the logs win over the answer and the years', () {
      final r = resolveStatus(
        fromLogs: Status.novice,
        answered: Status.advanced,
        years: YearsTraining.fivePlus,
      );
      expect(r.status, Status.novice);
      expect(r.source, StatusSource.logs);
    });
    test('the answer counts without logs', () {
      final r = resolveStatus(answered: Status.intermediate, years: YearsTraining.underOne);
      expect(r.status, Status.intermediate);
      expect(r.source, StatusSource.answer);
    });
    test('advanced with fewer than three years is planned as intermediate', () {
      expect(
        resolveStatus(answered: Status.advanced, years: YearsTraining.oneToThree).status,
        Status.intermediate,
      );
      expect(
        resolveStatus(answered: Status.advanced, years: YearsTraining.threeToFive).status,
        Status.advanced,
      );
      expect(resolveStatus(answered: Status.advanced).status, Status.advanced);
    });
    test('the years decide without an answer', () {
      expect(resolveStatus(years: YearsTraining.underOne).status, Status.novice);
      expect(resolveStatus(years: YearsTraining.oneToThree).status, Status.intermediate);
      expect(resolveStatus(years: YearsTraining.fivePlus).status, Status.intermediate);
    });
    test('nothing known: novice', () {
      final r = resolveStatus();
      expect(r.status, Status.novice);
      expect(r.source, StatusSource.fallback);
    });
  });

  group('PlannerProfile', () {
    test('days are sorted, deduplicated and kept to weekdays; focus keeps at most two', () {
      final p = PlannerProfile(
        goal: Goal.leanGain,
        days: [5, 1, 3, 3, 0, 8],
        minutes: 60,
        focus: [MuscleId.glutes, MuscleId.glutes, MuscleId.sideDelts, MuscleId.chest],
      );
      expect(p.days, [1, 3, 5]);
      expect(p.focus, [MuscleId.glutes, MuscleId.sideDelts]);
    });

    test('bmi and sport priority', () {
      final p = PlannerProfile(
        goal: Goal.sportSupport,
        days: [1],
        minutes: 45,
        bodyweightKg: 81,
        heightCm: 180,
      );
      expect(p.bmi, closeTo(25, 0.01));
      expect(p.sportPriority, isTrue);
      expect(PlannerProfile(goal: Goal.leanGain, days: [1], minutes: 45).bmi, isNull);
      expect(
        PlannerProfile(goal: Goal.leanGain, priority: Priority.sport, days: [1], minutes: 45).sportPriority,
        isTrue,
      );
    });

    test('JSON round trip', () {
      final p = PlannerProfile(
        goal: Goal.strength,
        priority: Priority.balanced,
        answeredStatus: Status.intermediate,
        logStatus: Status.advanced,
        years: YearsTraining.threeToFive,
        age: 52,
        sex: Sex.female,
        bodyweightKg: 64.5,
        heightCm: 168,
        lifestyle: Lifestyle.active,
        days: [1, 3, 5, 6],
        minutes: 75,
        style: StylePref.upperLower,
        sessionPref: SessionPref.fewerLonger,
        focus: [MuscleId.back],
        equipment: [Equipment.barbell, Equipment.dumbbell],
        availableTags: {SlotTag.squatFree, SlotTag.pressFlat},
        strengthLifts: [MainLift.squat, MainLift.bench],
        knownLifts: {'squat': 100, 'bench': 70},
        targetAdjustments: {MuscleId.chest: 2},
        previousMedianTarget: 12,
        previousSplitKey: 'UL4',
      );
      final json = p.toJson();
      expect(PlannerProfile.fromJson(json).toJson(), json);
      final minimal = PlannerProfile(goal: Goal.leanGain, days: [1, 4], minutes: 45);
      expect(PlannerProfile.fromJson(minimal.toJson()).toJson(), minimal.toJson());
      expect(
        PlannerProfile.fromJson({
          'goal': 'lean_gain',
          'days': [2],
          'minutes': 30,
        }).style,
        StylePref.auto,
      );
    });

    test('enum wires round trip and reject unknown values', () {
      for (final v in StylePref.values) {
        expect(StylePref.fromWire(v.wire), v);
      }
      for (final v in SessionPref.values) {
        expect(SessionPref.fromWire(v.wire), v);
      }
      for (final v in YearsTraining.values) {
        expect(YearsTraining.fromWire(v.wire), v);
      }
      for (final v in StatusSource.values) {
        expect(StatusSource.fromWire(v.wire), v);
      }
      expect(() => StylePref.fromWire('x'), throwsFormatException);
      expect(() => SessionPref.fromWire('x'), throwsFormatException);
      expect(() => YearsTraining.fromWire('x'), throwsFormatException);
      expect(() => StatusSource.fromWire('x'), throwsFormatException);
    });

    test('ResolvedStatus JSON round trip', () {
      final r = resolveStatus(answered: Status.novice);
      expect(ResolvedStatus.fromJson(r.toJson()).toJson(), r.toJson());
    });
  });
}
