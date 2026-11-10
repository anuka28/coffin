import 'package:coffin_core/src/storage/json_safety.dart';
import 'package:flutter_test/flutter_test.dart';

/// A map nested [levels] deep: level 1 is `{}`, level 2 is `{'a': {}}`, ...
Map<String, Object?> nested(int levels) {
  var current = <String, Object?>{};
  for (var i = 1; i < levels; i++) {
    current = <String, Object?>{'a': current};
  }
  return current;
}

void main() {
  // Literals (not 1 << 53 or pow) so the values are exact on the VM and in JS.
  // On the web, 9007199254740993 cannot be represented, so it is not tested.
  const safeMax = 9007199254740991;
  const tooBig = 9007199254740992;

  group('limits', () {
    test('constants', () {
      expect(JsonSafety.maxSafeInt, safeMax);
      expect(JsonSafety.maxDepth, 64);
    });

    test('2^53 - 1 is safe, 2^53 is unsafe, both signs', () {
      expect(JsonSafety.isSafe(safeMax), isTrue);
      expect(JsonSafety.isSafe(-safeMax), isTrue);
      expect(JsonSafety.isSafe(tooBig), isFalse);
      expect(JsonSafety.isSafe(-tooBig), isFalse);
      expect(() => JsonSafety.check({'n': safeMax}), returnsNormally);
      expect(() => JsonSafety.check({'n': tooBig}), throwsArgumentError);
    });

    test('depth 64 is safe, depth 65 is unsafe', () {
      expect(JsonSafety.isSafe(nested(64)), isTrue);
      expect(JsonSafety.isSafe(nested(65)), isFalse);
      expect(() => JsonSafety.check(nested(64)), returnsNormally);
      expect(() => JsonSafety.check(nested(65)), throwsArgumentError);
    });

    test('lists count toward depth', () {
      Object? list = <Object?>[];
      for (var i = 0; i < 63; i++) {
        list = <Object?>[list];
      }
      // Map (1) + 64 lists = depth 65.
      expect(JsonSafety.isSafe({'l': list}), isFalse);
      expect(JsonSafety.isSafe({'l': (list! as List)[0]}), isTrue);
    });
  });

  group('safe values', () {
    test('accepts every JSON-safe kind', () {
      final map = <String, Object?>{
        'null': null,
        'bool': true,
        'int': 0,
        'double': 1.5,
        'string': 'hi',
        'list': <Object?>[1, 'a', null, <Object?>[]],
        'map': <String, Object?>{'k': <String, Object?>{}},
      };
      expect(JsonSafety.isSafe(map), isTrue);
      expect(() => JsonSafety.check(map), returnsNormally);
    });
  });

  group('unsafe values', () {
    final unsafe = <String, Object?>{
      'NaN': double.nan,
      'infinity': double.infinity,
      'negative infinity': double.negativeInfinity,
      'big int': tooBig,
      'DateTime': DateTime(2020),
      'Object': Object(),
      'Set': <Object?>{1},
      'non-String map key': <Object?, Object?>{1: 'x'},
      'function': () {},
    };
    unsafe.forEach((name, value) {
      test('$name is unsafe', () {
        expect(JsonSafety.isSafe(value), isFalse);
        expect(() => JsonSafety.check({'v': value}), throwsArgumentError);
        expect(() => JsonSafety.deepCopy({'v': value}), throwsArgumentError);
      });
    });

    test('cyclic map is unsafe', () {
      final map = <String, Object?>{};
      map['self'] = map;
      expect(JsonSafety.isSafe(map), isFalse);
      expect(() => JsonSafety.check(map), throwsArgumentError);
    });

    test('cyclic list is unsafe', () {
      final list = <Object?>[];
      list.add(list);
      expect(JsonSafety.isSafe(list), isFalse);
      expect(() => JsonSafety.check({'l': list}), throwsArgumentError);
    });
  });

  group('check error message', () {
    String messageOf(Map<String, Object?> map) {
      try {
        JsonSafety.check(map);
      } on ArgumentError catch (e) {
        return e.toString();
      }
      fail('expected ArgumentError');
    }

    test('names the path and never the value', () {
      final message = messageOf({
        'a': <Object?>[
          1,
          <String, Object?>{'b': 'ok', 'c': double.nan},
        ],
      });
      expect(message, contains(r'$.a[1].c'));

      final stringy = messageOf({'secret-field': DateTime(1999, 12, 31)});
      expect(stringy, contains(r'$.secret-field'));
      expect(stringy, isNot(contains('1999')));

      final big = messageOf({'n': tooBig});
      expect(big, isNot(contains('$tooBig')));
    });
  });

  group('deepCopy', () {
    test('returns an equal map sharing no instance', () {
      final innerMap = <String, Object?>{'x': 1};
      final innerList = <Object?>[
        1,
        <String, Object?>{'y': 2},
      ];
      final original = <String, Object?>{'m': innerMap, 'l': innerList};
      final copy = JsonSafety.deepCopy(original);

      expect(copy, equals(original));
      expect(identical(copy, original), isFalse);
      expect(identical(copy['m'], innerMap), isFalse);
      expect(identical(copy['l'], innerList), isFalse);
      expect(identical((copy['l']! as List)[1], innerList[1]), isFalse);

      innerMap['x'] = 99;
      (innerList[1]! as Map)['y'] = 99;
      expect((copy['m']! as Map)['x'], 1);
      expect(((copy['l']! as List)[1]! as Map)['y'], 2);
    });

    test('copy has the declared runtime types', () {
      final copy = JsonSafety.deepCopy({
        'm': <Object?, Object?>{'k': 1},
        'l': <int>[1, 2],
      });
      expect(copy, isA<Map<String, Object?>>());
      expect(copy['m'], isA<Map<String, Object?>>());
      expect(copy['l'], isA<List<Object?>>());
    });
  });
}
