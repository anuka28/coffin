import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/composed_text.dart';
import 'package:coffin_core/src/ai/offline_engine.dart';
import 'package:flutter_test/flutter_test.dart' show expect, group, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'support/ai_generators.dart';
import 'support/legacy_catalog.dart';

const int _numRuns = 300;

// Pure test code: no dart:io, so it runs on the VM and in Chrome. Strings come
// from the fixed lists below, never from a glados string generator.

/// Values that are not a valid mood or event: near misses, wrong case, padded
/// strings, the empty string, `null` and values that are not strings.
final List<Object?> _invalidNewFacts = <Object?>[
  'fed',
  'rising',
  '',
  ' ',
  'Thriving',
  'THRIVING',
  'Dead',
  'AppOpened',
  'checkedoff',
  ' dead',
  'dead ',
  ' hungry ',
  'thriving\n',
  'unknown',
  null,
  0,
  1,
  -1,
  2.5,
  true,
  false,
  <Object?>['dead'],
  <String, Object?>{'dead': 1},
];

/// The invalid value for one key, or `null` when the key is left out.
Generator<({bool present, Object? value})> get _anyInvalidFact =>
    any.simple<({bool present, Object? value})>(
      generate: (math.Random random, int size) {
        if (random.nextInt(100) < 25) return (present: false, value: null);
        return (
          present: true,
          value: _invalidNewFacts[random.nextInt(_invalidNewFacts.length)],
        );
      },
      shrink: (({bool present, Object? value}) v) => v.present
          ? <({bool present, Object? value})>[(present: false, value: null)]
          : const <({bool present, Object? value})>[],
    );

/// Generates Legacy_Requests: any purpose, any legacy facts, any limit and
/// seed. The mood and event facts are either absent or invalid.
Generator<AiRequest> get _anyLegacyRequest =>
    any.combine5<
      AiPurpose,
      Map<String, Object?>,
      ({bool present, Object? value}),
      ({bool present, Object? value}),
      List<int>,
      AiRequest
    >(
      anyAiPurpose,
      anyFacts,
      _anyInvalidFact,
      _anyInvalidFact,
      any.combine2<int, int, List<int>>(
        anyMaxLength,
        anySeed,
        (int a, int b) => <int>[a, b],
      ),
      (
        AiPurpose purpose,
        Map<String, Object?> facts,
        ({bool present, Object? value}) mood,
        ({bool present, Object? value}) event,
        List<int> limitAndSeed,
      ) => AiRequest(
        purpose: purpose,
        facts: <String, Object?>{
          ...facts,
          if (mood.present) AiFactKeys.ghostMood: mood.value,
          if (event.present) AiFactKeys.ghostEvent: event.value,
        },
        maxLength: limitAndSeed[0],
        seed: limitAndSeed[1],
      ),
    );

final RunCounter _runs = RunCounter();

void main() {
  group('legacy equality property', () {
    // Feature: ghost-voice, Property 1: Legacy equality
    // Validates: Requirements 3.1, 3.2, 3.4, 12.2
    Glados(_anyLegacyRequest, ExploreConfig(numRuns: _numRuns)).test(
      'standard engine equals the frozen-catalog engine for legacy requests',
      (AiRequest request) {
        _runs.increment();

        final ComposedText got = OfflineEngine.standard.compose(request);
        final ComposedText want = frozenLegacyEngine.compose(request);

        expect(got.text, want.text, reason: '$request');
        expect(got.path, want.path, reason: '$request');
      },
    );

    test('the property ran 300 times', () {
      expect(_runs.runs, greaterThan(0));
      expect(_runs.runs, _numRuns);
    });
  });
}
