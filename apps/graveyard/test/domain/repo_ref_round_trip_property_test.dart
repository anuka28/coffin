// Feature: graveyard-core, Property 7: Repo reference round trip
// Validates: Requirements 3.1, 3.9, 3.11
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/repo_input_parser.dart';
import 'package:graveyard/src/domain/repo_parse_result.dart';
import 'package:graveyard/src/domain/repo_ref.dart';

import 'support/grave_generators.dart';

final RunCounter _counter = RunCounter();

void main() {
  group('Property 7: Repo reference round trip', () {
    Glados(anyRepoRef, ExploreConfig(numRuns: numRuns)).test(
      'parse(ref.toString()) returns a reference equal to ref',
      (RepoRef ref) {
        _counter.increment();
        final RepoParseResult result = RepoInputParser.parse(ref.toString());
        expect(result, isA<RepoParsed>());
        final RepoRef parsed = (result as RepoParsed).ref;
        expect(parsed, ref);
        expect(parsed.owner, ref.owner, reason: 'letter case is kept');
        expect(parsed.repo, ref.repo, reason: 'letter case is kept');
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
