// Feature: graveyard-core, Property 8: Optional URL parts do not change the reference
// Validates: Requirements 3.2, 3.3, 3.9, 3.12
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/repo_input_parser.dart';
import 'package:graveyard/src/domain/repo_parse_result.dart';
import 'package:graveyard/src/domain/repo_ref.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 8: Optional URL parts do not change the reference', () {
    Glados2(anyRepoRef, anyUrlDecoration, ExploreConfig(numRuns: numRuns)).test(
      'a decorated reference parses back to the same reference',
      (RepoRef ref, UrlDecoration decoration) {
        _counter.increment();
        final String text = decoration.render(ref);
        expect(
          RepoInputParser.parse(text),
          RepoParsed(ref),
          reason:
              'input: ${text.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}',
        );
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
