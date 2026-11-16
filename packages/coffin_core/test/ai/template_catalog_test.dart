import 'package:coffin_core/src/ai/ai_fact_keys.dart';
import 'package:coffin_core/src/ai/clean_facts.dart';
import 'package:coffin_core/src/ai/template.dart';
import 'package:coffin_core/src/ai/template_catalog.dart';
import 'package:coffin_core/src/ai/template_set.dart';
import 'package:coffin_core/src/ai/text_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_texts.dart';

const String _ghost = '\u{1F47B}';
const String _pumpkin = '\u{1F383}';

/// One filled text with the user name that was put into it, if any.
class _Fill {
  const _Fill(this.label, this.text, this.name);
  final String label;
  final String text;
  final String? name;
}

Map<String, Object?> _factsMap(int count, String? name) => <String, Object?>{
  AiFactKeys.streakCount: count,
  AiFactKeys.daysSinceLastCommit: count,
  AiFactKeys.ghostName: ?name,
  AiFactKeys.projectName: ?name,
};

List<_Fill> _fills(Template t) {
  final List<_Fill> out = <_Fill>[];
  void add(String label, CleanFacts facts, String? name, {bool names = true}) {
    if (!t.isEligible(facts)) return;
    out.add(_Fill(label, t.render(facts, useNames: names), name));
  }

  add('no facts', const CleanFacts(), null);
  final String w24 = 'W' * 24;
  final String emoji24 = '\u{1F383}' * 12;
  const String accents = 'Zo\u00EB \u00C9clair';
  final Map<String, String?> names = <String, String?>{
    '2-unit': 'Bo',
    'W24': w24,
    'emoji24': emoji24,
    'accents': accents,
  };
  for (final int count in <int>[0, 1, 2, 1000000]) {
    add('count $count', CleanFacts.from(_factsMap(count, null)), null);
    for (final MapEntry<String, String?> e in names.entries) {
      final CleanFacts f = CleanFacts.from(_factsMap(count, e.value));
      add('count $count, name ${e.key}', f, e.value);
      add('count $count, no-name ${e.key}', f, null, names: false);
    }
  }
  return out;
}

void _checkContent(String id, _Fill fill) {
  final String text = fill.text;
  final String why = '$id [${fill.label}] "$text"';
  expect(hasTestBannedWord(text), isFalse, reason: 'banned: $why');
  expect(hasTestInsultWord(text), isFalse, reason: 'insult: $why');
  expect(isTestBlank(text), isFalse, reason: 'blank: $why');
  expect(hasLoneSurrogate(text), isFalse, reason: 'surrogate: $why');
  expect(hasEdgeWhitespace(text), isFalse, reason: 'edge space: $why');
  // The emoji rule covers the copy. A user's own name is not copy.
  final String name = fill.name ?? '';
  final String copy = name.isEmpty ? text : text.replaceAll(name, '');
  expect(countEmoji(copy), lessThanOrEqualTo(1), reason: 'emoji: $why');
  expect(
    countEmoji(copy.replaceAll(_ghost, '').replaceAll(_pumpkin, '')),
    0,
    reason: 'emoji kind: $why',
  );
}

// id -> [no facts, small, extreme, no-name at extreme]; null is n/a.
const Map<String, List<int?>> _expected = <String, List<int?>>{
  'G1': [15, 15, 15, 15],
  'G2': [29, 29, 29, 29],
  'G3': [33, 33, 33, 33],
  'G4': [35, 27, 49, 35],
  'G5': [null, 40, 47, 47],
  'G6': [null, 43, 72, 58],
  'G7': [null, 28, 57, 43],
  'G8': [47, 39, 61, 47],
  'V1': [32, 32, 32, 32],
  'V2': [23, 23, 23, 23],
  'V3': [15, 15, 15, 15],
  'V4': [null, 48, 77, 65],
  'V5': [null, 44, 51, 51],
  'V6': [45, 35, 57, 45],
  'V7': [null, 49, 78, 66],
  'V8': [50, 50, 50, 50],
  'X1': [25, 25, 25, 25],
  'X2': [32, 32, 32, 32],
  'X3': [14, 14, 14, 14],
  'X4': [23, 23, 23, 23],
  'X5': [28, 14, 36, 28],
  'X6': [37, 31, 53, 37],
  'X7': [null, 32, 39, 39],
  'X8': [null, 39, 46, 46],
};

void main() {
  final TemplateCatalog catalog = TemplateCatalog.standard;
  final Map<String, TemplateSet> sets = <String, TemplateSet>{
    'G': catalog.ghostMoodLine,
    'V': catalog.seanceVerdict,
    'X': catalog.generic,
  };
  final Map<String, Template> byId = <String, Template>{
    for (final MapEntry<String, TemplateSet> s in sets.entries)
      for (int i = 0; i < s.value.templates.length; i++)
        '${s.key}${i + 1}': s.value.templates[i],
  };

  group('template structure', () {
    test('every set has at least 6 templates and 2 slot-free ones', () {
      for (final MapEntry<String, TemplateSet> s in sets.entries) {
        expect(
          s.value.templates.length,
          greaterThanOrEqualTo(6),
          reason: s.key,
        );
        final int slotFree = s.value.templates.where((Template t) {
          return t.usedFacts(CleanFacts.from(_factsMap(1, 'Bo'))) == 0;
        }).length;
        expect(slotFree, greaterThanOrEqualTo(2), reason: s.key);
      }
    });

    test('every set has a fact-free template of 16 units or fewer', () {
      for (final String id in <String>['G1', 'V3', 'X3']) {
        final Template t = byId[id]!;
        expect(t.isEligible(const CleanFacts()), isTrue, reason: id);
        expect(
          t.render(const CleanFacts()).length,
          lessThanOrEqualTo(16),
          reason: id,
        );
      }
    });

    test('the standard catalog has 24 templates, all parsed', () {
      expect(byId.length, 24);
      expect(_expected.keys.toSet(), byId.keys.toSet());
    });

    test('plural rule for 0, 1, 2 and 1000000', () {
      final Template t = Template('{streakCount:day/days} left');
      String fill(int n) =>
          t.render(CleanFacts.from(<String, Object?>{'streakCount': n}));
      expect(fill(0), '0 days left');
      expect(fill(1), '1 day left');
      expect(fill(2), '2 days left');
      expect(fill(1000000), '1000000 days left');
    });
  });

  group('content of every filled text', () {
    for (final MapEntry<String, Template> e in byId.entries) {
      test('${e.key} passes every content rule', () {
        final List<_Fill> fills = _fills(e.value);
        expect(fills, isNotEmpty);
        for (final _Fill f in fills) {
          _checkContent(e.key, f);
        }
      });
    }
  });

  group('length table of design.md', () {
    final String w24 = 'W' * 24;
    final CleanFacts none = const CleanFacts();
    final CleanFacts small = CleanFacts.from(_factsMap(1, 'Bo'));
    final CleanFacts extreme = CleanFacts.from(_factsMap(1000000, w24));

    test('the fills have the sizes the table defines', () {
      expect(small.ghostName!.length, 2);
      expect(extreme.ghostName!.length, 24);
      expect(extreme.streakCount, 1000000);
    });

    for (final MapEntry<String, List<int?>> row in _expected.entries) {
      test('${row.key} lengths', () {
        final Template t = byId[row.key]!;
        final List<int?> want = row.value;
        final List<int?> got = <int?>[
          t.isEligible(none) ? t.render(none).length : null,
          t.render(small).length,
          t.render(extreme).length,
          t.render(extreme, useNames: false).length,
        ];
        final List<String?> texts = <String?>[
          t.isEligible(none) ? t.render(none) : null,
          t.render(small),
          t.render(extreme),
          t.render(extreme, useNames: false),
        ];
        expect(got, want, reason: '${row.key} texts: $texts');
      });
    }

    test('the longest filled text is 78 units', () {
      int longest = 0;
      for (final Template t in byId.values) {
        for (final CleanFacts f in <CleanFacts>[none, small, extreme]) {
          if (!t.isEligible(f)) continue;
          final int n = t.render(f).length;
          if (n > longest) longest = n;
        }
      }
      expect(longest, 78);
    });
  });

  group('safe lines and exported lists', () {
    test('each Safe_Line has the exact length and clean words', () {
      final Map<String, int> lengths = <String, int>{'G': 16, 'V': 16, 'X': 11};
      for (final MapEntry<String, TemplateSet> s in sets.entries) {
        final String line = s.value.safeLine;
        expect(line.length, lengths[s.key], reason: s.key);
        expect(line.length, lessThanOrEqualTo(16));
        expect(hasTestBannedWord(line), isFalse, reason: line);
        expect(hasTestInsultWord(line), isFalse, reason: line);
      }
      expect(catalog.ghostMoodLine.safeLine, 'Boo. Still here.');
      expect(catalog.seanceVerdict.safeLine, 'Rest, then rise.');
      expect(catalog.generic.safeLine, 'Still here.');
    });

    test('TextRules lists hold every test-declared word', () {
      expect(testBannedWords, hasLength(20));
      expect(testInsultWords, hasLength(13));
      for (final String w in testBannedWords) {
        expect(TextRules.bannedWords, contains(w));
      }
      for (final String w in testInsultWords) {
        expect(TextRules.insultWords, contains(w));
      }
    });
  });
}
