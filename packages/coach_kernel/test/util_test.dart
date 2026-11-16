// SPDX-License-Identifier: GPL-3.0-only
import 'package:coach_kernel/coach_kernel.dart';
import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

void main() {
  for (final c in loadFixture('util_dates.json')) {
    test('dates ${c.name}', () {
      final iso = c.input['iso'] as String;
      final actual = {
        'plus1': addDays(iso, c.input['plus'] as int),
        'minus8': addDays(iso, -(c.input['minus'] as int)),
        'weekday': isoWeekday(iso),
        'monday': mondayOf(iso),
      };
      expect(jsonDiff(actual, c.output), isNull);
    });
  }

  for (final c in loadFixture('util_rounding.json')) {
    test('rounding ${c.name}', () {
      final x = c.input['x'] as num;
      final step = c.input['step'] as num;
      final actual = {
        'halfUp': roundHalfUp(x),
        'step25': roundToStep(x, step),
        'down25': roundDownToStep(x, step),
        'up25': roundUpToStep(x, step),
      };
      expect(jsonDiff(actual, c.output), isNull);
    });
  }

  for (final c in loadFixture('util_numbers.json')) {
    test('numbers ${c.name}', () {
      final xs = (c.input['xs'] as List).cast<num>();
      final actual = {
        'sum': sum(xs),
        'mean': mean(xs),
        'variance': variance(xs),
        'median': median(xs),
        'round': [for (final x in xs) jsRound(x)],
        'round1': [for (final x in xs) round1(x)],
        'round5': [for (final x in xs) round5(x)],
        'round10': [for (final x in xs) round10(x)],
        'clamp': [for (final x in xs) clampNum(x, c.input['lo'] as num, c.input['hi'] as num)],
        'lerp': [for (final x in xs) lerp(c.input['lo'] as num, c.input['hi'] as num, x)],
        'uniq': uniq(xs),
      };
      expect(jsonDiff(actual, c.output), isNull);
    });
  }

  for (final c in loadFixture('util_ranges.json')) {
    test('ranges ${c.name}', () {
      final from = c.input['from'] as String;
      final to = c.input['to'] as String;
      final actual = {
        'daysBetween': daysBetween(from, to),
        'weekend': isWeekend(from),
        'range': dateRange(from, c.input['days'] as int),
        'combinations': combinations((c.input['items'] as List).cast<String>(), c.input['k'] as int),
      };
      expect(jsonDiff(actual, c.output), isNull);
    });
  }

  test('stableSorted keeps input order for ties', () {
    final out = stableSorted([('b', 1), ('a', 1), ('c', 0)], (x, y) => x.$2.compareTo(y.$2));
    expect(out.map((e) => e.$1).join(), 'cba');
  });

  test('stableSorted leaves its input alone', () {
    final input = [3, 1, 2];
    expect(stableSorted(input, (a, b) => a.compareTo(b)), [1, 2, 3]);
    expect(input, [3, 1, 2]);
  });

  test('jsRound does not push values just below a half over it', () {
    expect(jsRound(0.49999999999999994), 0);
    expect(jsRound(-0.5), 0);
    expect(jsRound(-0.5000000000000001), -1);
  });

  test('jsNumber writes numbers the way the reference interpolates them', () {
    expect(jsNumber(1), '1');
    expect(jsNumber(1.0), '1');
    expect(jsNumber(-0.0), '0');
    expect(jsNumber(0.5), '0.5');
    expect(jsNumber(82.4), '82.4');
    expect(jsNumber(-2.5), '-2.5');
  });
}
