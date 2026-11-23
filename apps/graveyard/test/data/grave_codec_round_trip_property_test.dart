// Feature: graveyard-core, Property 23: Grave codec round trip
// Validates: Requirements 10.2, 10.3
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/grave.dart';

import '../domain/support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 23: Grave codec round trip', () {
    const GraveCodec codec = GraveCodec();

    Glados(anyGraveList, ExploreConfig(numRuns: numRuns)).test(
      'decode(encode(g)) equals g, also through jsonEncode and jsonDecode',
      (List<Grave> graves) {
        _counter.increment();
        for (final Grave g in graves) {
          expect(codec.decode(codec.encode(g)), g);

          final Object? viaJson = jsonDecode(jsonEncode(codec.encode(g)));
          expect(viaJson, isA<Map<String, Object?>>());
          expect(codec.decode(viaJson! as Map<String, Object?>), g);
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
