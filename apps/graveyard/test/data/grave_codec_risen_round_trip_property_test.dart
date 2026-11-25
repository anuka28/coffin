// Feature: graveyard-resurrection, Property 5: Codec round trip, with and without Risen_On
// Validates: Requirements 3.3
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/grave.dart';

import '../domain/support/grave_generators.dart';

final RunCounter _counter = RunCounter();
int _risen = 0;
int _notRisen = 0;

void main() {
  group('Property 5: Codec round trip, with and without Risen_On', () {
    const GraveCodec codec = GraveCodec();

    Glados(anyGraveWithRisen, ExploreConfig(numRuns: numRuns)).test(
      'decode(encode(g)) equals g, also through jsonEncode and jsonDecode',
      (Grave grave) {
        _counter.increment();
        if (grave.risenOn == null) {
          _notRisen++;
        } else {
          _risen++;
        }

        final Grave decoded = codec.decode(codec.encode(grave));
        expect(decoded, grave);
        expect(decoded.risenOn, grave.risenOn);

        final Object? viaJson = jsonDecode(jsonEncode(codec.encode(grave)));
        expect(viaJson, isA<Map<String, Object?>>());
        expect(codec.decode(viaJson! as Map<String, Object?>), grave);
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });

    test('covered Graves both with and without Risen_On', () {
      expect(_risen, greaterThan(0));
      expect(_notRisen, greaterThan(0));
    });
  });
}
