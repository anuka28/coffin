// Feature: graveyard-resurrection, Property 7: A malformed risen value is rejected with FormatException
// Validates: Requirements 3.5, 3.6
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/grave.dart';

import '../domain/support/grave_generators.dart';

final RunCounter _counter = RunCounter();

/// Malformed `risen` values: a wrong type, a wrong format, a month of 13 and
/// a day that does not exist. [choice] picks one, [n] varies the numbers.
Object? _malformed(int choice, int n) {
  switch (choice) {
    case 0:
      return n; // number
    case 1:
      return n + 0.5; // fractional number
    case 2:
      return n.isEven; // boolean
    case 3:
      return <Object?>['2024-01-01', n]; // list
    case 4:
      return <String, Object?>{'risen': n}; // map
    case 5:
      return '24-01-01'; // wrong format
    case 6:
      return ''; // empty string
    case 7:
      return '2024-01-01T10:20:30Z'; // time part
    case 8:
      return '2024-01-01T00:00:00'; // time part, no zone
    case 9:
      return '2024-13-01'; // month 13
    case 10:
      return '2024-02-30'; // 30th of February
    case 11:
      return '2023-02-29'; // leap day in a common year
    case 12:
      return '2024-1-1'; // no zero padding
    default:
      return '2024-00-10'; // month 0
  }
}

void main() {
  group(
    'Property 7: A malformed risen value is rejected with FormatException',
    () {
      const GraveCodec codec = GraveCodec();

      Glados2(
        anyGraveWithRisen,
        any.combine2(
          anyIntBetween(0, 14),
          anyIntBetween(0, 1000000),
          (int a, int b) => <int>[a, b],
        ),
        ExploreConfig(numRuns: numRuns),
      ).test('decode throws FormatException and nothing else', (
        Grave grave,
        List<int> pick,
      ) {
        _counter.increment();
        final Map<String, Object?> encoded = Map<String, Object?>.of(
          codec.encode(grave),
        );
        encoded['risen'] = _malformed(pick[0], pick[1]);

        expect(() => codec.decode(encoded), throwsFormatException);
      });

      test('ran the configured number of times', () {
        _counter.expectRuns(numRuns);
      });
    },
  );
}
