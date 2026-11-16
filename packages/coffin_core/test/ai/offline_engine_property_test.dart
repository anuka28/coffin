import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/compose_path.dart';
import 'package:coffin_core/src/ai/composed_text.dart';
import 'package:coffin_core/src/ai/offline_engine.dart';
import 'package:coffin_core/src/ai/template_catalog.dart';
import 'package:coffin_core/src/ai/template_set.dart';
import 'package:flutter_test/flutter_test.dart'
    show TestFailure, expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'support/ai_generators.dart';
import 'support/test_texts.dart';

const int _numRuns = 500;

// Pure test code: no dart:io, so it runs on the VM and in Chrome. Strings come
// from the piece lists below, never from a glados string generator.

/// Safe, short lines for the catalog's Safe_Line (at most 16 units).
const List<String> _safeLines = <String>[
  'Boo. Still here.',
  'Still here.',
  'Rest, then rise.',
  'Quiet night.',
  'Boo.',
];

// Pattern pieces. Every one is a valid pattern under the grammar.
final List<String> _patternPieces = <String>[
  // Plain safe texts of various lengths.
  'Calm night.',
  'Mist drifts by.',
  'Floating along, humming softly to the moon.',
  'Mist, moonlight and good company on a quiet hill.',
  // 220 units: never fits any limit up to 200.
  'The moon hums a very long and very gentle tune. ' * 5,
  // 250 units, safe, never fits.
  'W' * 250,
  // Banned by their own text, in mixed case.
  'Gore galore',
  'A bloody mess {ghostName|x}',
  'A BLOODy night',
  'MuRdEr most fowl',
  'Kill the lights',
  'Stabbed by moonlight',
  'Quiet night. No Slaughter here.',
  // Banned only after the cut: the limit removes the banned word.
  'The moon is up and the fog rolls over the hills tonight, gore',
  // Fragments that become banned words together with a name.
  'Hush, a mur{ghostName|!}',
  'Hush, a mur{projectName|!}',
  'The cr{projectName|!}',
  'Not go{projectName|.}',
  'Not go{ghostName|.}',
  'A blo{ghostName|x}',
  'Near the blo{projectName|x}',
  // A fallback that is itself banned.
  'Hush, a mur{ghostName|der}',
  // Count templates.
  'Streak: {streakCount:day/days}.',
  '{streakCount:day/days} so far.',
  '{daysSinceLastCommit:day/days} on the clock.',
  '{daysSinceLastCommit:day/days} of silence, mist and quiet.',
  '{ghostName|Your ghost} counted {streakCount:day/days}.',
  '{projectName|This project} waited {daysSinceLastCommit:day/days}.',
  // Name templates with safe fallbacks.
  '{ghostName|Your ghost} says boo.',
  '{projectName|This project} still glows.',
  '{ghostName|A ghost} and {projectName|a crypt}.',
  'Hi {ghostName|there}',
  // Emoji, including emoji that land on a cut at 16.
  'The pumpkins say hi. \u{1F383}',
  '\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B}\u{1F47B} so spooky and bright',
  'abcdefghijklmn\u{1F47B}\u{1F47B}opqrst',
  'abcdefghijklm\u{1F47B}\u{1F47B}opqrstuv',
  'abcdefghijklmno\u{1F47B}pqrstuvwx',
  'abcdefghijkl\u{1F47B}\u{1F383}mnopqrst',
  '{ghostName|\u{1F47B}} drifts through the quiet night',
];

// Names for facts: fragments, safe names and emoji.
final List<String> _namePieces = <String>[
  'der',
  're',
  'od',
  'der',
  're',
  'od',
  'Bo',
  'Wisp',
  'Mist',
  '\u{1F47B}',
  '\u{1F383}\u{1F383}',
  'Todo Crypt',
  'W' * 30,
];

/// One generated template set: its patterns and its Safe_Line.
final class _SetSpec {
  const _SetSpec(this.patterns, this.safeLine);

  final List<String> patterns;
  final String safeLine;

  @override
  String toString() =>
      '_SetSpec(patterns: [${patterns.map(escapeForReport).join(', ')}], '
      'safeLine: ${escapeForReport(safeLine)})';
}

Generator<_SetSpec> get _anySetSpec {
  final Generator<List<int>> picks = anyListBetween<int>(
    1,
    7,
    anyIntBetween(0, _patternPieces.length),
  );
  final Generator<int> line = anyIntBetween(0, _safeLines.length);
  return any.combine2<List<int>, int, _SetSpec>(
    picks,
    line,
    (List<int> p, int l) => _SetSpec(<String>[
      for (final int i in p) _patternPieces[i],
    ], _safeLines[l]),
  );
}

/// Facts from [anyFacts], often overlaid with real names and counts so the
/// name-only bans and the count templates are reached.
Generator<Map<String, Object?>> get _anyEngineFacts {
  final Generator<Map<String, Object?>> base = anyFacts;
  return any.simple<Map<String, Object?>>(
    generate: (math.Random random, int size) {
      final Map<String, Object?> facts = <String, Object?>{
        ...base(random, size).value,
      };
      if (random.nextInt(100) < 70) {
        facts['ghostName'] = _namePieces[random.nextInt(_namePieces.length)];
      }
      if (random.nextInt(100) < 50) {
        facts['projectName'] = _namePieces[random.nextInt(_namePieces.length)];
      }
      if (random.nextInt(100) < 45) {
        facts['streakCount'] = random.nextInt(400);
      }
      if (random.nextInt(100) < 35) {
        facts['daysSinceLastCommit'] = random.nextInt(2000);
      }
      return facts;
    },
    shrink: (Map<String, Object?> facts) sync* {
      if (facts.isEmpty) return;
      yield <String, Object?>{};
      for (final String key in facts.keys) {
        yield <String, Object?>{...facts}..remove(key);
      }
    },
  );
}

final class _Case {
  const _Case(this.spec, this.request);

  final _SetSpec spec;
  final AiRequest request;
}

Generator<_Case> get _anyCase =>
    any.combine5<_SetSpec, AiPurpose, Map<String, Object?>, int, int, _Case>(
      _anySetSpec,
      anyAiPurpose,
      _anyEngineFacts,
      anyMaxLength,
      anySeed,
      (
        _SetSpec spec,
        AiPurpose purpose,
        Map<String, Object?> facts,
        int maxLength,
        int seed,
      ) => _Case(
        spec,
        AiRequest(
          purpose: purpose,
          facts: facts,
          maxLength: maxLength,
          seed: seed,
        ),
      ),
    );

final RunCounter _runs = RunCounter();
final Map<ComposePath, int> _paths = <ComposePath, int>{
  for (final ComposePath p in ComposePath.values) p: 0,
};

void main() {
  group('OfflineEngine property: Recovery', () {
    // Feature: coffin-ai, Property 12: Recovery never returns a banned word or an overlong text
    // Validates: Requirements 8.11, 8.12, 8.13
    Glados(_anyCase, ExploreConfig(numRuns: _numRuns)).test(
      'compose never returns a banned word, an overlong text or an empty text',
      (_Case c) {
        _runs.increment();
        final AiRequest request = c.request;
        final int max = request.maxLength;

        // The generated set fills every slot, so it is the one used.
        final TemplateSet set = TemplateSet(
          c.spec.patterns,
          safeLine: c.spec.safeLine,
        );
        final TemplateCatalog catalog = TemplateCatalog(
          ghostMoodLine: set,
          seanceVerdict: set,
          generic: set,
        );
        final OfflineEngine engine = OfflineEngine(catalog);

        final ComposedText first = engine.compose(request);
        final ComposedText second = engine.compose(request);
        _paths[first.path] = _paths[first.path]! + 1;

        final String why =
            '${describeRequest(request)}; '
            'patterns: [${c.spec.patterns.map(escapeForReport).join(', ')}]; '
            'safeLine: ${escapeForReport(c.spec.safeLine)}; '
            'text: ${escapeForReport(first.text)} '
            '(length ${first.text.length}); path: ${first.path}';

        try {
          // Guard the generator and the catalog contract.
          expect(
            identical(catalog.forPurpose(request.purpose), set),
            isTrue,
            reason: 'generated set not used',
          );
          expect(c.spec.safeLine.length, lessThanOrEqualTo(16));
          expect(hasTestBannedWord(c.spec.safeLine), isFalse);
          expect(max, greaterThanOrEqualTo(16));

          expect(first.text, isNotEmpty, reason: 'empty text');
          expect(first.text.length, lessThanOrEqualTo(max), reason: 'too long');
          expect(hasTestBannedWord(first.text), isFalse, reason: 'banned word');
          expect(second.text, first.text, reason: 'text changed on repeat');
          expect(second.path, first.path, reason: 'path changed on repeat');
        } on TestFailure catch (e) {
          throw TestFailure('${e.message}\n$why');
        }
      },
    );

    test('the property ran 500 times', () {
      expect(_runs.runs, greaterThan(0));
      expect(_runs.runs, _numRuns);
    });

    test('every compose path was reached at least once', () {
      for (final ComposePath p in ComposePath.values) {
        expect(
          _paths[p],
          greaterThan(0),
          reason: 'path $p never reached; counts: $_paths',
        );
      }
      // Visible in the test output.
      // ignore: avoid_print
      print('compose path counts over $_numRuns runs: $_paths');
    });
  });
}
