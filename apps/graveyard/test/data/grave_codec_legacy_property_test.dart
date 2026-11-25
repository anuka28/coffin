// Feature: graveyard-resurrection, Property 6: Legacy records decode as not risen
// Validates: Requirements 3.4
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/grave.dart';

import '../domain/support/grave_generators.dart';

final RunCounter _counter = RunCounter();
int _risen = 0;

void main() {
  group('Property 6: Legacy records decode as not risen', () {
    const GraveCodec codec = GraveCodec();

    Glados(anyGraveWithRisen, ExploreConfig(numRuns: numRuns)).test(
      'a record without the risen key decodes as not Risen',
      (Grave grave) {
        _counter.increment();
        if (grave.risenOn != null) {
          _risen++;
        }

        // Strip the risen key, leaving a record as written before the feature.
        final Map<String, Object?> legacy = Map<String, Object?>.of(
          codec.encode(grave),
        )..remove('risen');
        expect(legacy.containsKey('risen'), isFalse);

        final Grave decoded = codec.decode(legacy);
        expect(decoded.risenOn, isNull);
        expect(decoded.id, grave.id);
        expect(decoded.name, grave.name);
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('covered Risen encodings whose key was removed', () {
      expect(_risen, greaterThan(0));
    });
  });
}
