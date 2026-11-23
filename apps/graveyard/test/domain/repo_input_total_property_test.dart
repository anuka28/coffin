// Feature: graveyard-core, Property 9: The input parser is total and only returns valid references
// Validates: Requirements 3.4, 3.6, 3.10
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/repo_input_parser.dart';
import 'package:graveyard/src/domain/repo_parse_problem.dart';
import 'package:graveyard/src/domain/repo_parse_result.dart';
import 'package:graveyard/src/domain/repo_ref.dart';

import 'support/grave_generators.dart';

final RunCounter _totalCounter = RunCounter();
final RunCounter _hostCounter = RunCounter();

/// Hosts that are not GitHub, including look-alikes.
const List<String> _otherHosts = <String>[
  'gitlab.com',
  'example.com',
  'notgithub.com',
  'github.com.evil.io',
  'api.github.com',
  'gist.github.com',
  'bitbucket.org',
  'github.org',
  'raw.githubusercontent.com',
  'git.sr.ht',
];

/// Prefixes that put the host first: with and without a scheme.
const List<String> _prefixes = <String>[
  'https://',
  'http://',
  'HTTPS://',
  '',
  ' https://',
];

void main() {
  group('Property 9: The input parser is total and only returns valid '
      'references', () {
    Glados(anyUrlText, ExploreConfig(numRuns: numRuns)).test(
      'parse never throws and a parsed ref is valid',
      (String text) {
        _totalCounter.increment();
        final RepoParseResult result = RepoInputParser.parse(text);
        if (result is RepoParsed) {
          expect(RepoRef.isValidOwner(result.ref.owner), isTrue);
          expect(RepoRef.isValidRepo(result.ref.repo), isTrue);
        } else {
          expect(result, isA<RepoParseFailed>());
        }
      },
    );

    test('ran the configured number of times (totality)', () {
      _totalCounter.expectRuns(numRuns);
    });

    Glados2(
      anyIntBetween(0, _otherHosts.length * _prefixes.length),
      anyUrlText,
      ExploreConfig(numRuns: numRuns),
    ).test('a host that is not github.com gives notGitHub', (
      int pick,
      String tail,
    ) {
      _hostCounter.increment();
      final String host = _otherHosts[pick % _otherHosts.length];
      final String prefix = _prefixes[pick ~/ _otherHosts.length];
      // Keep the tail out of the host part: it starts after a slash and
      // carries no query or fragment that could cut the path short.
      final String path = tail.replaceAll(RegExp(r'[?#]'), '');
      final RepoParseResult result = RepoInputParser.parse(
        '$prefix$host/$path',
      );
      expect(result, isA<RepoParseFailed>());
      expect((result as RepoParseFailed).problem, RepoParseProblem.notGitHub);
    });

    test('ran the configured number of times (host)', () {
      _hostCounter.expectRuns(numRuns);
    });
  });
}
