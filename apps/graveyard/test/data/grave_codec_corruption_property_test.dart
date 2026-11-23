// Feature: graveyard-core, Property 25: Corrupt records are rejected
// Validates: Requirements 10.6
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/grave.dart';

import '../domain/support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 25: Corrupt records are rejected', () {
    const GraveCodec codec = GraveCodec();

    Glados2<Grave, int>(
      anyGrave,
      anyIntBetween(0, anyCorruption.length),
      ExploreConfig(numRuns: numRuns),
    ).test('decode throws FormatException for any corruption', (
      Grave grave,
      int index,
    ) {
      _counter.increment();
      final Corruption corruption = anyCorruption[index];
      final Map<String, Object?> encoded = codec.encode(grave);
      final Map<String, Object?> corrupted = corruption.apply(encoded);

      expect(
        () => codec.decode(corrupted),
        throwsFormatException,
        reason: '${corruption.name} on ${grave.id}',
      );
    });

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
