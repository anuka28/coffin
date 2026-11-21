import 'package:coffin_core/src/ai/clean_facts.dart';
import 'package:coffin_core/src/ai/mood_templates.dart';
import 'package:coffin_core/src/ai/template.dart';
import 'package:coffin_core/src/ai/template_set.dart';
import 'package:coffin_core/src/ai/text_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _shameAndGore = <String>[
  'failed',
  'lazy',
  'worthless',
  'abandoned',
  'neglected',
  'guilty',
  'shame',
  'gore',
  'blood',
  'corpse',
  'rotting',
];

/// The eight ghostMoodLine patterns of the original catalog.
const List<String> _oldPatterns = <String>[
  'Floating along.',
  'Your ghost is getting hungry\u2026',
  'Mist, moonlight and good company.',
  '{ghostName|Your ghost} drifts by to say boo. \u{1F47B}',
  'Streak: {streakCount:day/days}. The mist is on your side.',
  '{ghostName|Your ghost} has counted {streakCount:day/days} and is still floating.',
  '{streakCount:day/days} so far. {ghostName|Your ghost} is humming.',
  '{ghostName|Your ghost} waits by the window, glowing softly.',
];

final String _longName = List<String>.filled(40, 'n').join();
final CleanFacts _worst = CleanFacts(
  streakCount: 1000000,
  ghostName: _longName,
);

final List<String> _moods = CleanFacts.moods;
final List<String> _events = CleanFacts.events;
final MoodTemplates _std = MoodTemplates.standard;

/// Every set of the shipped copy with a readable label.
List<(String, TemplateSet)> _allSets() => <(String, TemplateSet)>[
  for (final e in _std.sets.entries) (e.key, e.value),
];

bool _hasCount(Template t) => !t.isEligible(const CleanFacts());
bool _hasName(Template t) => t.usesRealName(const CleanFacts(ghostName: 'x'));

bool _plain(String text) {
  for (final unit in text.codeUnits) {
    final ok = (unit >= 0x20 && unit <= 0x7E) || unit == 0x2026;
    if (!ok) return false;
  }
  return true;
}

/// Every rendering variant of a template that the tests inspect.
List<String> _renders(Template t) {
  final out = <String>[t.render(_worst)];
  if (!_hasCount(t)) out.add(t.render(const CleanFacts()));
  for (final streak in <int>[1, 2, 3, 10, 1000000]) {
    out.add(t.render(CleanFacts(streakCount: streak, ghostName: 'Moss')));
  }
  return out;
}

Template _t(String pattern) => Template(pattern);

void main() {
  group('coverage and sizes', () {
    test('all 5 base sets and 20 cells exist', () {
      for (final mood in _moods) {
        expect(_std.sets.containsKey(mood), isTrue, reason: mood);
        for (final event in _events) {
          expect(_std.sets.containsKey('$mood/$event'), isTrue);
        }
      }
      expect(_std.sets.length, 25);
    });

    test('minimum sizes', () {
      for (final mood in _moods) {
        final base = _std.sets[mood]!.templates;
        expect(
          base.where((t) => !_hasCount(t)).length,
          greaterThanOrEqualTo(3),
        );
        for (final event in _events) {
          final cell = _std.sets['$mood/$event']!.templates;
          expect(cell.length, greaterThanOrEqualTo(5), reason: '$mood/$event');
          expect(
            cell.where((t) => !_hasCount(t)).length,
            greaterThanOrEqualTo(3),
            reason: '$mood/$event',
          );
        }
      }
    });

    test('base safe lines are distinct and fit the 16 unit limit', () {
      final lines = <String>{for (final m in _moods) _std.sets[m]!.safeLine};
      expect(lines.length, 5);
      for (final (label, set) in _allSets()) {
        expect(set.safeLine, isNotEmpty, reason: label);
        expect(set.safeLine.length, lessThanOrEqualTo(16), reason: label);
      }
    });
  });

  group('copy rules', () {
    test('printable ASCII or ellipsis only', () {
      for (final (label, set) in _allSets()) {
        expect(_plain(set.safeLine), isTrue, reason: '$label safe line');
        for (final t in set.templates) {
          for (final line in _renders(t)) {
            expect(_plain(line), isTrue, reason: '$label: $line');
          }
        }
      }
    });

    test('one line, at most 80 characters in the worst case', () {
      for (final (label, set) in _allSets()) {
        expect(set.safeLine.contains('\n'), isFalse);
        for (final t in set.templates) {
          for (final line in _renders(t)) {
            expect(line.contains('\n'), isFalse, reason: '$label: $line');
            expect(line.trim(), isNotEmpty, reason: label);
          }
          final worst = t.render(_worst);
          expect(worst.length, lessThanOrEqualTo(80), reason: '$label: $worst');
        }
      }
    });

    test('no banned, shame or gore word', () {
      for (final (label, set) in _allSets()) {
        final lines = <String>[set.safeLine];
        for (final t in set.templates) {
          lines.addAll(_renders(t));
        }
        for (final line in lines) {
          final folded = TextRules.asciiLower(line);
          expect(TextRules.containsBanned(line), isFalse, reason: line);
          for (final w in <String>[
            ...TextRules.bannedWords,
            ...TextRules.insultWords,
            ..._shameAndGore,
          ]) {
            expect(folded.contains(w), isFalse, reason: '$label: $line ($w)');
          }
        }
      }
    });

    test('no time-of-day words in any template or safe line', () {
      final timeWord = RegExp(
        r'\b(tonight|night|evening|morning|today)\b',
        caseSensitive: false,
      );
      for (final (label, set) in _allSets()) {
        expect(timeWord.hasMatch(set.safeLine), isFalse, reason: label);
        for (final t in set.templates) {
          for (final line in _renders(t)) {
            expect(timeWord.hasMatch(line), isFalse, reason: '$label: $line');
          }
        }
      }
    });

    test('at most one name slot and the literal text budgets hold', () {
      for (final (label, set) in _allSets()) {
        for (final t in set.templates) {
          final two = t
              .render(const CleanFacts(ghostName: 'QQ', streakCount: 1))
              .length;
          final four = t
              .render(const CleanFacts(ghostName: 'QQQQ', streakCount: 1))
              .length;
          expect(four - two, lessThanOrEqualTo(2), reason: label);
          if (!_hasName(t)) continue;
          expect(four - two, 2, reason: label);
          final hasCount = _hasCount(t);
          final line = t.render(
            const CleanFacts(ghostName: 'a', streakCount: 1000000),
          );
          // Literal text = line minus the name (1) and the count (12).
          final literal = line.length - 1 - (hasCount ? 12 : 0);
          expect(literal, lessThanOrEqualTo(hasCount ? 28 : 40), reason: label);
        }
      }
    });
  });

  group('count slots', () {
    test('only in thriving and content, always {streakCount:day/days}', () {
      for (final (label, set) in _allSets()) {
        final mood = label.split('/').first;
        for (final t in set.templates) {
          if (!_hasCount(t)) continue;
          expect(
            mood == 'thriving' || mood == 'content',
            isTrue,
            reason: '$label has a count slot',
          );
          // Only the streak fact fills it, and exactly one digit run shows.
          expect(t.isEligible(const CleanFacts(streakCount: 5)), isTrue);
          final line = t.render(const CleanFacts(streakCount: 1000000));
          expect(RegExp(r'\d+').allMatches(line).length, 1, reason: label);
        }
      }
    });

    test('streak grammar for 1, 2, 3, 10 and 1000000', () {
      var checked = 0;
      for (final (label, set) in _allSets()) {
        for (final t in set.templates.where(_hasCount)) {
          for (final n in <int>[1, 2, 3, 10, 1000000]) {
            final line = t.render(
              CleanFacts(streakCount: n, ghostName: 'Moss'),
            );
            final runs = RegExp(r'\d+').allMatches(line).toList();
            expect(runs.length, 1, reason: '$label: $line');
            final rest = line.substring(runs.single.end);
            if (n == 1) {
              expect(rest.startsWith(' day'), isTrue, reason: line);
              expect(rest.startsWith(' days'), isFalse, reason: line);
            } else {
              expect(rest.startsWith(' days'), isTrue, reason: line);
            }
            expect(line.contains(RegExp(r'(?<!\d)1 days')), isFalse);
            expect(line.contains(RegExp(r'(?<!\d)2 day(?!s)')), isFalse);
            checked++;
          }
        }
      }
      expect(checked, greaterThan(0));
    });
  });

  group('MoodTemplates', () {
    test('constructor throws StateError when a mood base set is missing', () {
      for (final missing in _moods) {
        final sets = <String, TemplateSet>{
          for (final m in _moods.where((m) => m != missing))
            m: TemplateSet(const <String>['Hi.'], safeLine: 'Hi.'),
        };
        expect(() => MoodTemplates(sets), throwsStateError, reason: missing);
      }
    });

    test('setFor returns the cell and falls back to the base set', () {
      for (final mood in _moods) {
        for (final event in _events) {
          expect(_std.setFor(mood, event), same(_std.sets['$mood/$event']));
        }
        expect(_std.setFor(mood, 'unknownEvent'), same(_std.sets[mood]));
        expect(_std.setFor(mood, null), same(_std.sets[mood]));
      }
      expect(() => _std.setFor('unknownMood', null), throwsStateError);
    });

    test('old ghostMoodLine patterns are not in the standard copy', () {
      final variants = <CleanFacts>[
        const CleanFacts(),
        const CleanFacts(ghostName: 'Moss'),
        const CleanFacts(streakCount: 3),
        const CleanFacts(ghostName: 'Moss', streakCount: 3),
      ];
      final oldLines = <String>{
        for (final p in _oldPatterns)
          for (final f in variants)
            if (_t(p).isEligible(f)) _t(p).render(f),
      };
      for (final (label, set) in _allSets()) {
        expect(oldLines.contains(set.safeLine), isFalse, reason: label);
        expect(set.safeLine, isNot('Boo. Still here.'));
        for (final t in set.templates) {
          for (final f in variants.where(t.isEligible)) {
            expect(oldLines.contains(t.render(f)), isFalse, reason: label);
          }
        }
      }
    });
  });
}
