// Feature: graveyard-scene, Property 20: Description cleaner is idempotent
// Validates: Requirements 11.7
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/scene/description_cleaner.dart';

import '../support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 20: Description cleaner is idempotent', () {
    Glados(anyDescription, ExploreConfig(numRuns: numRuns)).test(
      'clean(clean(x)) == clean(x)',
      (String description) {
        _counter.increment();
        final String once = DescriptionCleaner.clean(description);
        final String twice = DescriptionCleaner.clean(once);
        expect(twice, once);
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
