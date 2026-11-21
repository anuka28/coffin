import 'dart:math' as math;

import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:flutter_test/flutter_test.dart'
    show expect, group, isFalse, isTrue, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'mood_generators.dart';

const int _samples = 400;

List<T> _draw<T>(Generator<T> generator, int seed) {
  final math.Random random = math.Random(seed);
  return <T>[for (int i = 0; i < _samples; i++) generator(random, 10).value];
}

void main() {
  group('mood generators', () {
    test('mood values cover valid, invalid and non-string cases', () {
      final List<Object?> values = _draw(anyMoodValue, 1);
      expect(values.any(validMoodValues.contains), isTrue);
      expect(
        values.any((Object? v) => v is String && !validMoodValues.contains(v)),
        isTrue,
      );
      expect(values.any((Object? v) => v is! String), isTrue);
      for (final String mood in validMoodValues) {
        expect(values.contains(mood), isTrue, reason: mood);
      }
    });

    test('event values cover valid, invalid and non-string cases', () {
      final List<Object?> values = _draw(anyEventValue, 2);
      expect(values.any(validEventValues.contains), isTrue);
      expect(
        values.any((Object? v) => v is String && !validEventValues.contains(v)),
        isTrue,
      );
      expect(values.any((Object? v) => v is! String), isTrue);
      for (final String event in validEventValues) {
        expect(values.contains(event), isTrue, reason: event);
      }
    });

    test('streaks are absent or 1 to 1000000, with the edges', () {
      final List<int?> values = _draw(anyStreak, 3);
      expect(values.any((int? v) => v == null), isTrue);
      expect(values.any((int? v) => v != null), isTrue);
      for (final int? v in values) {
        expect(v == null || (v >= 1 && v <= maxStreak), isTrue, reason: '$v');
      }
      expect(values.contains(1), isTrue);
      expect(values.contains(maxStreak), isTrue);
      expect(
        values.any((int? v) => v != null && v > 2 && v < maxStreak),
        isTrue,
      );
    });

    test('names are absent or 1 to 40 alphabet characters, no digit', () {
      final List<String?> values = _draw(anyGhostName, 4);
      expect(values.any((String? v) => v == null), isTrue);
      expect(values.any((String? v) => v != null), isTrue);
      final RegExp digit = RegExp('[0-9]');
      for (final String? v in values) {
        if (v == null) continue;
        expect(v.isNotEmpty && v.length <= maxNameLength, isTrue);
        expect(digit.hasMatch(v), isFalse, reason: v);
        for (final String c in v.split('')) {
          expect(nameAlphabet.contains(c), isTrue, reason: c);
        }
      }
      expect(values.any((String? v) => v?.length == maxNameLength), isTrue);
    });

    test('mood requests stay in range and mix valid and invalid facts', () {
      final List<AiRequest> requests = _draw(anyMoodRequest, 5);
      for (final AiRequest r in requests) {
        expect(r.purpose, AiPurpose.ghostMoodLine);
        expect(r.maxLength >= 16 && r.maxLength <= 200, isTrue);
        expect(r.seed >= 0 && r.seed <= 4294967295, isTrue);
        expect(r.facts.containsKey(AiFactKeys.ghostMood), isTrue);
        expect(r.facts.containsKey(AiFactKeys.ghostEvent), isTrue);
      }
      expect(
        requests.any(
          (AiRequest r) => validMoodValues.contains(r.facts['ghostMood']),
        ),
        isTrue,
      );
      expect(
        requests.any(
          (AiRequest r) => !validMoodValues.contains(r.facts['ghostMood']),
        ),
        isTrue,
      );
      expect(
        requests.any((AiRequest r) => r.facts.containsKey('streakCount')),
        isTrue,
      );
      expect(
        requests.any((AiRequest r) => !r.facts.containsKey('streakCount')),
        isTrue,
      );
      expect(
        requests.any((AiRequest r) => r.facts.containsKey('ghostName')),
        isTrue,
      );
      expect(
        requests.any((AiRequest r) => !r.facts.containsKey('ghostName')),
        isTrue,
      );
      expect(requests.any((AiRequest r) => r.maxLength == 16), isTrue);
      expect(requests.any((AiRequest r) => r.seed > 65536), isTrue);
    });
  });
}
