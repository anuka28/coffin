// Feature: graveyard-core, Property 4: Name normalisation is idempotent and well formed
// Validates: Requirements 2.12
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/name_rules.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 4: Name normalisation is idempotent and well formed', () {
    Glados(anyProjectName, ExploreConfig(numRuns: numRuns)).test(
      'normalising twice equals once, with no edge or doubled whitespace',
      (String raw) {
        _counter.increment();
        final String once = NameRules.normalize(raw);
        expect(NameRules.normalize(once), once);
        expect(once, once.trim());
        expect(RegExp(r'\s\s').hasMatch(once), isFalse);
        expect(RegExp(r'[^\S ]').hasMatch(once), isFalse);
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
