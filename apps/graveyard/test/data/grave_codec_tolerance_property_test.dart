// Feature: graveyard-core, Property 24: Grave codec ignores unknown fields and fills missing optional ones
// Validates: Requirements 10.4, 10.5
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';

import '../domain/support/grave_generators.dart';

final RunCounter _counter = RunCounter();

const List<String> _optionalRepoKeys = <String>[
  'html_url',
  'description',
  'archived',
  'stars',
  'full_name',
];

void main() {
  group('Property 24: Grave codec tolerates unknown and missing fields', () {
    const GraveCodec codec = GraveCodec();

    Glados2(anyGrave, anyJsonValue, ExploreConfig(numRuns: numRuns)).test(
      'unknown keys are ignored and removed optional repo fields get defaults',
      (Grave g, Object? extra) {
        _counter.increment();

        // Unknown keys at the top level and inside repo change nothing.
        final Map<String, Object?> withUnknown = Map<String, Object?>.of(
          codec.encode(g),
        );
        withUnknown['unknown_top'] = extra;
        withUnknown['extra'] = <String, Object?>{'nested': extra};
        final Object? repo = withUnknown['repo'];
        if (repo is Map<String, Object?>) {
          withUnknown['repo'] = <String, Object?>{
            ...repo,
            'unknown_repo': extra,
            'owner': <String, Object?>{'login': 'x'},
          };
        }
        expect(codec.decode(withUnknown), g);

        // Removing the optional repo fields fills the defaults.
        final RepoInfo? info = g.repo;
        if (info != null) {
          final Map<String, Object?> stripped = Map<String, Object?>.of(
            codec.encode(g),
          );
          final Map<String, Object?> bare = Map<String, Object?>.of(
            stripped['repo']! as Map<String, Object?>,
          );
          _optionalRepoKeys.forEach(bare.remove);
          stripped['repo'] = bare;
          final Grave decoded = codec.decode(stripped);
          expect(
            decoded,
            Grave.github(
              id: g.id,
              name: g.name,
              dateOfDeath: g.dateOfDeath,
              repo: RepoInfo(fullName: g.name),
            ),
          );
          expect(decoded.repo!.htmlUrl, isNull);
          expect(decoded.repo!.description, isNull);
          expect(decoded.repo!.archived, isFalse);
          expect(decoded.repo!.stars, 0);

          // A missing repo object behaves the same.
          final Map<String, Object?> noRepo = Map<String, Object?>.of(
            codec.encode(g),
          )..remove('repo');
          expect(codec.decode(noRepo).repo, RepoInfo(fullName: g.name));
        }
      },
    );

    test('ran the configured number of times', () {
      _counter.expectRuns(numRuns);
    });
  });
}
