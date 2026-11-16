// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_nutrition/coach_nutrition.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

void main() {
  for (final c in loadFixture('nutrition_review.json', fn: 'nutritionReview')) {
    test(c.name, () {
      final state = WeighInState.fromJson(c.input);
      expect(jsonDiff(nutritionReview(state).toJson(), c.output), isNull);
    });
  }

  test('the state and the result survive a JSON round trip', () {
    for (final c in loadFixture('nutrition_review.json')) {
      final state = WeighInState.fromJson(c.input);
      expect(jsonDiff(WeighInState.fromJson(state.toJson()).toJson(), c.input), isNull);
      final result = NutritionReviewResult.fromJson(c.output as Map<String, dynamic>);
      expect(jsonDiff(result.toJson(), c.output), isNull);
    }
  });
}
