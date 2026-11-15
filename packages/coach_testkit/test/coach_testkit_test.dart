// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';
import 'dart:io';

import 'package:coach_testkit/coach_testkit.dart';
import 'package:test/test.dart';

void main() {
  group('loadFixture', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('coach_testkit_'));
    tearDown(() => dir.deleteSync(recursive: true));

    void write(String file, Object? json) =>
        File('${dir.path}/$file').writeAsBytesSync(utf8.encode(jsonEncode(json)));

    Matcher throwsNaming<T extends Object>(String file, [String detail = '']) => throwsA(
      isA<T>().having((e) => '$e', 'message', allOf(contains('${dir.path}/$file'), contains(detail))),
    );

    test('returns the cases in file order', () {
      write('ok.json', {
        'fn': 'add',
        'cases': [
          {
            'name': 'b',
            'input': {'x': 1},
            'output': {'y': 2},
          },
          {
            'name': 'a',
            'input': {'x': 2.5, 'list': <Object?>[]},
            'output': [1, null],
          },
        ],
      });

      final cases = loadFixture('ok.json', root: dir.path);

      expect(cases.map((c) => c.name), ['b', 'a']);
      expect(cases[0].input, {'x': 1});
      expect(cases[0].output, {'y': 2});
      expect(cases[1].input, {'x': 2.5, 'list': <Object?>[]});
      expect(cases[1].output, [1, null]);
    });

    test('decodes the file as UTF-8', () {
      const text = '3 × 5 · 60 − 2.5 “quoted” it’s';
      write('utf8.json', {
        'fn': 'f',
        'cases': [
          {
            'name': text,
            'input': {'s': text},
            'output': text,
          },
        ],
      });
      // The file must hold the characters themselves, not \u escapes, for this to prove anything.
      expect(File('${dir.path}/utf8.json').readAsBytesSync(), containsAllInOrder(utf8.encode('×')));

      final c = loadFixture('utf8.json', root: dir.path).single;

      expect(c.name, text);
      expect(c.input['s'], text);
      expect(c.output, text);
    });

    test('a case without an output key has a null output', () {
      write('void.json', {
        'fn': 'f',
        'cases': [
          {'name': 'n', 'input': <String, Object?>{}},
        ],
      });

      expect(loadFixture('void.json', root: dir.path).single.output, isNull);
    });

    test('looks in test/fixtures by default and names a missing file', () {
      expect(
        () => loadFixture('no_such_fixture.json'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('test/fixtures/no_such_fixture.json'),
          ),
        ),
      );
      expect(() => loadFixture('absent.json', root: dir.path), throwsNaming<StateError>('absent.json'));
    });

    test('names the file when it is not valid JSON', () {
      File('${dir.path}/broken.json').writeAsStringSync('{"fn": "f", "cases": [');

      expect(() => loadFixture('broken.json', root: dir.path), throwsNaming<FormatException>('broken.json'));
    });

    test('names the file when it is not valid UTF-8', () {
      // 0xD7 is "×" in Latin-1 and an incomplete sequence in UTF-8.
      File(
        '${dir.path}/latin1.json',
      ).writeAsBytesSync([...ascii.encode('{"fn": "'), 0xD7, ...ascii.encode('"}')]);

      expect(() => loadFixture('latin1.json', root: dir.path), throwsNaming<FormatException>('latin1.json'));
    });

    final okCase = {'name': 'n', 'input': <String, Object?>{}, 'output': 1};
    final wrongShapes = <String, Object?>{
      'top level is a list': [okCase],
      'fn is missing': {
        'cases': [okCase],
      },
      'fn is not a string': {
        'fn': 1,
        'cases': [okCase],
      },
      'cases is missing': {'fn': 'f'},
      'cases is not a list': {'fn': 'f', 'cases': okCase},
      'cases is empty': {'fn': 'f', 'cases': <Object?>[]},
      'a case is not an object': {
        'fn': 'f',
        'cases': [okCase, 'x'],
      },
      'a case has no name': {
        'fn': 'f',
        'cases': [
          {'input': <String, Object?>{}, 'output': 1},
        ],
      },
      'a case name is not a string': {
        'fn': 'f',
        'cases': [
          {'name': 1, 'input': <String, Object?>{}, 'output': 1},
        ],
      },
      'a case has no input': {
        'fn': 'f',
        'cases': [
          {'name': 'n', 'output': 1},
        ],
      },
      'a case input is not an object': {
        'fn': 'f',
        'cases': [
          {
            'name': 'n',
            'input': [1],
            'output': 1,
          },
        ],
      },
    };
    for (final MapEntry(key: why, value: json) in wrongShapes.entries) {
      test('names the file when $why', () {
        write('shape.json', json);

        expect(() => loadFixture('shape.json', root: dir.path), throwsNaming<FormatException>('shape.json'));
      });
    }

    test('names the file and the name when two cases share a name', () {
      write('twice.json', {
        'fn': 'f',
        'cases': [
          okCase,
          {...okCase, 'name': 'other'},
          {...okCase, 'output': 2},
        ],
      });

      expect(
        () => loadFixture('twice.json', root: dir.path),
        throwsNaming<FormatException>('twice.json', '"n"'),
      );
    });
  });

  group('jsonDiff numbers', () {
    test('an int equals the same double', () {
      expect(jsonDiff(3, 3.0), isNull);
      expect(jsonDiff(3.0, 3), isNull);
    });

    test('values within 1e-9 are equal', () {
      expect(jsonDiff(0.1 + 0.2, 0.3), isNull);
      expect(jsonDiff(0.3, 0.1 + 0.2), isNull);
    });

    test('values further apart differ', () {
      expect(jsonDiff(1, 1.0000001), r'$: 1 != 1.0000001');
      expect(jsonDiff(1.0000001, 1), r'$: 1.0000001 != 1');
      expect(jsonDiff(2, 3), r'$: 2 != 3');
    });

    test('NaN never equals anything, itself included', () {
      expect(jsonDiff(double.nan, double.nan), r'$: NaN != NaN');
      expect(jsonDiff(double.nan, 0), r'$: NaN != 0');
      expect(jsonDiff(0, double.nan), r'$: 0 != NaN');
      expect(jsonDiff(double.nan, 1e-12), isNotNull);
      expect(jsonDiff(double.nan, double.infinity), isNotNull);
      expect(jsonDiff(double.nan, null), isNotNull);
      expect(jsonDiff(null, double.nan), isNotNull);
      expect(
        jsonDiff(
          {
            'a': [double.nan],
          },
          {
            'a': [double.nan],
          },
        ),
        startsWith(r'$.a[0]: '),
      );
    });

    test('an infinity equals only itself', () {
      expect(jsonDiff(double.infinity, double.infinity), isNull);
      expect(jsonDiff(double.negativeInfinity, double.negativeInfinity), isNull);
      expect(jsonDiff(double.infinity, double.negativeInfinity), isNotNull);
      expect(jsonDiff(double.negativeInfinity, double.infinity), isNotNull);
      expect(jsonDiff(double.infinity, double.maxFinite), isNotNull);
      expect(jsonDiff(double.maxFinite, double.infinity), isNotNull);
      expect(jsonDiff(double.negativeInfinity, 0), isNotNull);
    });

    test('negative zero equals zero', () {
      expect(jsonDiff(-0.0, 0), isNull);
      expect(jsonDiff(0, -0.0), isNull);
      expect(jsonDiff(-0.0, 0.0), isNull);
    });
  });

  group('jsonDiff maps', () {
    test('equal maps match whatever the key order', () {
      expect(jsonDiff({'a': 1, 'b': 'x'}, {'b': 'x', 'a': 1.0}), isNull);
    });

    test('a missing key equals an explicit null', () {
      expect(jsonDiff({'a': 1}, {'a': 1, 'b': null}), isNull);
      expect(jsonDiff({'a': 1, 'b': null}, {'a': 1}), isNull);
      expect(jsonDiff(<String, Object?>{}, {'b': null}), isNull);
    });

    test('a missing key differs from a value and the message names the path', () {
      expect(
        jsonDiff(
          {'a': <String, Object?>{}},
          {
            'a': {'b': 5},
          },
        ),
        r'$.a.b: null != 5',
      );
      expect(
        jsonDiff(
          {
            'a': {'b': 5},
          },
          {'a': <String, Object?>{}},
        ),
        r'$.a.b: 5 != null',
      );
      expect(jsonDiff({'a': 0}, <String, Object?>{}), r'$.a: 0 != null');
      expect(jsonDiff({'a': false}, <String, Object?>{}), r'$.a: false != null');
      expect(jsonDiff({'a': ''}, <String, Object?>{}), r'$.a: "" != null');
    });

    test('reports the first difference in the key order of expected, then the extra keys of actual', () {
      expect(jsonDiff({'z': 1, 'a': 1, 'extra': 9}, {'a': 2, 'z': 2}), r'$.a: 1 != 2');
      expect(jsonDiff({'extra': 9, 'a': 1, 'z': 1}, {'z': 2, 'a': 2}), r'$.z: 1 != 2');
      expect(jsonDiff({'extra2': 8, 'extra1': 9, 'a': 1}, {'a': 1}), r'$.extra2: 8 != null');
    });
  });

  group('jsonDiff lists', () {
    test('equal lists match', () {
      expect(jsonDiff([1, 'a', null, true], [1.0, 'a', null, true]), isNull);
      expect(jsonDiff(<Object?>[], <Object?>[]), isNull);
    });

    test('length is compared first', () {
      expect(jsonDiff([9, 2], [1, 2, 3]), r'$: length 2 != 3');
      expect(jsonDiff([1], <Object?>[]), r'$: length 1 != 0');
      expect(jsonDiff([null], <Object?>[]), r'$: length 1 != 0');
    });

    test('order is significant', () {
      expect(jsonDiff([1, 2], [2, 1]), r'$[0]: 1 != 2');
    });

    test('duplicates are significant', () {
      expect(jsonDiff([1, 1, 2], [1, 2, 2]), r'$[1]: 1 != 2');
      expect(jsonDiff([1, 1], [1]), r'$: length 2 != 1');
    });

    test('the path leads to the first difference in a nested value', () {
      final actual = {
        'a': [
          {'b': 1},
          {'b': 2, 'c': 3},
        ],
      };
      final expected = {
        'a': [
          {'b': 1},
          {'b': 2, 'c': 4},
        ],
      };

      expect(jsonDiff(actual, expected), r'$.a[1].c: 3 != 4');
    });
  });

  group('jsonDiff types', () {
    test('equal scalars match', () {
      expect(jsonDiff(null, null), isNull);
      expect(jsonDiff(true, true), isNull);
      expect(jsonDiff('×', '×'), isNull);
      expect(jsonDiff(<String, Object?>{}, <String, Object?>{}), isNull);
    });

    test('values of different types never match', () {
      expect(jsonDiff(true, 1), r'$: true != 1');
      expect(jsonDiff(1, true), r'$: 1 != true');
      expect(jsonDiff(false, 0), r'$: false != 0');
      expect(jsonDiff('1', 1), r'$: "1" != 1');
      expect(jsonDiff(1, '1'), r'$: 1 != "1"');
      expect(jsonDiff(null, 0), r'$: null != 0');
      expect(jsonDiff(0, null), r'$: 0 != null');
      expect(jsonDiff(null, ''), r'$: null != ""');
      expect(jsonDiff('', null), r'$: "" != null');
      expect(jsonDiff(null, false), r'$: null != false');
      expect(jsonDiff(<String, Object?>{}, <Object?>[]), r'$: {} != []');
      expect(jsonDiff(<Object?>[], <String, Object?>{}), r'$: [] != {}');
      expect(jsonDiff(null, <Object?>[]), r'$: null != []');
      expect(jsonDiff(<String, Object?>{}, null), r'$: {} != null');
    });

    test('strings and booleans compare exactly', () {
      expect(jsonDiff('a', 'A'), r'$: "a" != "A"');
      expect(jsonDiff('null', null), r'$: "null" != null');
      expect(jsonDiff(true, false), r'$: true != false');
    });
  });

  group('expandSeed', () {
    final seed = [
      {'id': 'squat'},
    ];

    test('replaces the marker at any depth', () {
      final input = {
        'exercises': '@seed',
        'nested': {
          'list': [
            1,
            '@seed',
            {'deep': '@seed'},
          ],
        },
        'n': 2.5,
        'none': null,
      };

      expect(expandSeed(input, seed), {
        'exercises': seed,
        'nested': {
          'list': [
            1,
            seed,
            {'deep': seed},
          ],
        },
        'n': 2.5,
        'none': null,
      });
      expect(expandSeed('@seed', seed), same(seed));
      expect(expandSeed(['@seed'], null), [null]);
    });

    test('leaves strings that merely contain the marker alone', () {
      final input = {
        'a': '@seed ',
        'b': 'x@seed',
        'c': '@seeds',
        'd': '@SEED',
        '@seed': 'key',
        'e': ['@seed@seed'],
      };

      expect(expandSeed(input, seed), input);
    });

    test('returns a deep copy and does not mutate the input', () {
      final inner = {'exercises': '@seed', 'n': 1};
      final list = <Object?>[inner, '@seed'];
      final input = <String, Object?>{'list': list, 'keep': 'x'};
      final before = jsonEncode(input);

      final out = expandSeed(input, seed) as Map;

      expect(jsonEncode(input), before);
      expect(out, isNot(same(input)));
      expect(out['list'], isNot(same(list)));
      expect((out['list'] as List)[0], isNot(same(inner)));

      // Changing the copy leaves the original alone.
      ((out['list'] as List)[0] as Map)['n'] = 99;
      (out['list'] as List).add('more');
      out['keep'] = 'changed';
      expect(jsonEncode(input), before);
    });

    test('a decoded JSON object stays usable as Map<String, dynamic>', () {
      final input = jsonDecode('{"exercises": "@seed", "plan": {"days": [{"x": "@seed"}]}}');

      final out = expandSeed(input, seed);

      expect(out, isA<Map<String, dynamic>>());
      expect((out as Map<String, dynamic>)['plan'], isA<Map<String, dynamic>>());
      expect(((out['plan'] as Map<String, dynamic>)['days'] as List)[0], isA<Map<String, dynamic>>());
    });
  });
}
