import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/clean_facts.dart';
import 'package:coffin_core/src/ai/mood_templates.dart';
import 'package:coffin_core/src/ai/offline_engine.dart';
import 'package:coffin_core/src/ai/template.dart';
import 'package:coffin_core/src/ai/template_set.dart';
import 'package:coffin_core/src/ai/text_rules.dart';
import 'package:flutter_test/flutter_test.dart'
    show expect, group, greaterThan, isNotEmpty, test;
import 'package:glados/glados.dart' hide expect, group, test;

import 'support/ai_generators.dart';
import 'support/mood_generators.dart';

const int _numRuns = 300;

// Pure test code: no dart:io, so it runs on the VM and in Chrome.

String _text(AiRequest request) => OfflineEngine.standard.compose(request).text;

bool _validMood(Object? v) => v is String && validMoodValues.contains(v);

bool _validEvent(Object? v) => v is String && validEventValues.contains(v);

/// The request without the mood and event facts that are not valid.
AiRequest _stripInvalid(AiRequest r) {
  final Map<String, Object?> facts = Map<String, Object?>.of(r.facts);
  if (!_validMood(facts[AiFactKeys.ghostMood])) {
    facts.remove(AiFactKeys.ghostMood);
  }
  if (!_validEvent(facts[AiFactKeys.ghostEvent])) {
    facts.remove(AiFactKeys.ghostEvent);
  }
  return AiRequest(
    purpose: r.purpose,
    facts: facts,
    maxLength: r.maxLength,
    seed: r.seed,
  );
}

/// Whether [text] is a line the set can give for [facts]: a rendered template
/// (with or without real names), the safe line, or a cut of a template ending
/// in an ellipsis.
bool _fits(String text, TemplateSet set, CleanFacts facts) {
  if (text == set.safeLine) return true;
  final bool cut = text.endsWith(TextRules.ellipsis);
  final String head = cut
      ? text.substring(0, text.length - TextRules.ellipsis.length)
      : text;
  for (final Template t in set.templates) {
    if (!t.isEligible(facts)) continue;
    for (final bool useNames in <bool>[true, false]) {
      final String line = t.render(facts, useNames: useNames);
      if (line == text) return true;
      if (cut && line.startsWith(head)) return true;
    }
  }
  return false;
}

final RunCounter _invalidRuns = RunCounter();
final RunCounter _formedRuns = RunCounter();
final RunCounter _determinismRuns = RunCounter();
final RunCounter _fitRuns = RunCounter();

void main() {
  group('mood engine properties', () {
    // Feature: ghost-voice, Property 2: Invalid facts are absent
    // Validates: Requirements 1.3, 12.2, 12.3
    Glados(anyMoodRequest, ExploreConfig(numRuns: _numRuns)).test(
      'an invalid mood or event gives the text of the request without it',
      (AiRequest request) {
        _invalidRuns.increment();
        expect(_text(request), _text(_stripInvalid(request)));
      },
    );

    test('Property 2 ran 300 times', () {
      expect(_invalidRuns.runs, greaterThan(0));
      expect(_invalidRuns.runs, _numRuns);
    });

    // Feature: ghost-voice, Property 3: Mood lines are well formed
    // Validates: Requirements 2.1, 2.6, 2.7, 12.2, 12.3
    Glados(anyMoodRequest, ExploreConfig(numRuns: _numRuns)).test(
      'a mood line is non-empty, within maxLength and on one line',
      (AiRequest request) {
        _formedRuns.increment();
        final String text = _text(request);
        expect(text, isNotEmpty);
        expect(text.length <= request.maxLength, true, reason: text);
        expect(text.contains('\n') || text.contains('\r'), false);
      },
    );

    test('Property 3 ran 300 times', () {
      expect(_formedRuns.runs, greaterThan(0));
      expect(_formedRuns.runs, _numRuns);
    });

    // Feature: ghost-voice, Property 4: Determinism
    // Validates: Requirements 2.8, 12.2, 12.3
    Glados(anyMoodRequest, ExploreConfig(numRuns: _numRuns)).test(
      'the same request gives the same text twice',
      (AiRequest request) {
        _determinismRuns.increment();
        expect(_text(request), _text(request));
      },
    );

    test('Property 4 ran 300 times', () {
      expect(_determinismRuns.runs, greaterThan(0));
      expect(_determinismRuns.runs, _numRuns);
    });

    // Feature: ghost-voice, Property 5: Mood fit
    // Validates: Requirements 2.1, 2.6, 2.7, 12.2, 12.3
    Glados(anyMoodRequest, ExploreConfig(numRuns: _numRuns)).test(
      'a valid mood gives a line from that mood or its safe line',
      (AiRequest request) {
        _fitRuns.increment();
        final Object? mood = request.facts[AiFactKeys.ghostMood];
        if (!_validMood(mood)) return;
        final Object? event = request.facts[AiFactKeys.ghostEvent];
        final CleanFacts facts = CleanFacts.from(request.facts);
        final TemplateSet set = MoodTemplates.standard.setFor(
          mood! as String,
          _validEvent(event) ? event as String : null,
        );
        final String text = _text(request);
        expect(_fits(text, set, facts), true, reason: '$mood/$event: $text');
      },
    );

    test('Property 5 ran 300 times', () {
      expect(_fitRuns.runs, greaterThan(0));
      expect(_fitRuns.runs, _numRuns);
    });
  });
}
