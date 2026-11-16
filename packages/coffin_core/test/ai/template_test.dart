import 'package:coffin_core/src/ai/clean_facts.dart';
import 'package:coffin_core/src/ai/template.dart';
import 'package:flutter_test/flutter_test.dart';

/// One row of design.md's "Initial template copy": the pattern and the
/// recorded filled lengths (`null` is `n/a`).
typedef _Row = ({
  String id,
  String pattern,
  int? noFacts,
  int small,
  int extreme,
  int noName,
});

const List<_Row> _rows = [
  (
    id: 'G1',
    pattern: 'Floating along.',
    noFacts: 15,
    small: 15,
    extreme: 15,
    noName: 15,
  ),
  (
    id: 'G2',
    pattern: 'Your ghost is getting hungry…',
    noFacts: 29,
    small: 29,
    extreme: 29,
    noName: 29,
  ),
  (
    id: 'G3',
    pattern: 'Mist, moonlight and good company.',
    noFacts: 33,
    small: 33,
    extreme: 33,
    noName: 33,
  ),
  (
    id: 'G4',
    pattern: '{ghostName|Your ghost} drifts by to say boo. 👻',
    noFacts: 35,
    small: 27,
    extreme: 49,
    noName: 35,
  ),
  (
    id: 'G5',
    pattern: 'Streak: {streakCount:day/days}. The mist is on your side.',
    noFacts: null,
    small: 40,
    extreme: 47,
    noName: 47,
  ),
  (
    id: 'G6',
    pattern: '{ghostName|Your ghost} has counted {streakCount:day/days} and is still floating.',
    noFacts: null,
    small: 43,
    extreme: 72,
    noName: 58,
  ),
  (
    id: 'G7',
    pattern:
        '{streakCount:day/days} so far. {ghostName|Your ghost} is humming.',
    noFacts: null,
    small: 28,
    extreme: 57,
    noName: 43,
  ),
  (
    id: 'G8',
    pattern: '{ghostName|Your ghost} waits by the window, glowing softly.',
    noFacts: 47,
    small: 39,
    extreme: 61,
    noName: 47,
  ),
  (
    id: 'V1',
    pattern: 'The spirits are still listening.',
    noFacts: 32,
    small: 32,
    extreme: 32,
    noName: 32,
  ),
  (
    id: 'V2',
    pattern: 'Not gone, just napping.',
    noFacts: 23,
    small: 23,
    extreme: 23,
    noName: 23,
  ),
  (
    id: 'V3',
    pattern: 'Not quite gone.',
    noFacts: 15,
    small: 15,
    extreme: 15,
    noName: 15,
  ),
  (
    id: 'V4',
    pattern: '{projectName|This project} has been dead for {daysSinceLastCommit:day/days}. Not forever, though.',
    noFacts: null,
    small: 48,
    extreme: 77,
    noName: 65,
  ),
  (
    id: 'V5',
    pattern:
        'Last commit: {daysSinceLastCommit:day/days} ago. The ghost remembers.',
    noFacts: null,
    small: 44,
    extreme: 51,
    noName: 51,
  ),
  (
    id: 'V6',
    pattern: '{projectName|This project} still glows faintly in the dark.',
    noFacts: 45,
    small: 35,
    extreme: 57,
    noName: 45,
  ),
  (
    id: 'V7',
    pattern: '{daysSinceLastCommit:day/days} of silence, and {projectName|this project} is still worth a séance.',
    noFacts: null,
    small: 49,
    extreme: 78,
    noName: 66,
  ),
  (
    id: 'V8',
    pattern: 'Every great haunting starts with one small commit.',
    noFacts: 50,
    small: 50,
    extreme: 50,
    noName: 50,
  ),
  (
    id: 'X1',
    pattern: 'Boo. Hello from the mist.',
    noFacts: 25,
    small: 25,
    extreme: 25,
    noName: 25,
  ),
  (
    id: 'X2',
    pattern: 'Something spooky this way comes.',
    noFacts: 32,
    small: 32,
    extreme: 32,
    noName: 32,
  ),
  (
    id: 'X3',
    pattern: 'Quiet in here.',
    noFacts: 14,
    small: 14,
    extreme: 14,
    noName: 14,
  ),
  (
    id: 'X4',
    pattern: 'The pumpkins say hi. 🎃',
    noFacts: 23,
    small: 23,
    extreme: 23,
    noName: 23,
  ),
  (
    id: 'X5',
    pattern: '{ghostName|A friendly ghost} says hello.',
    noFacts: 28,
    small: 14,
    extreme: 36,
    noName: 28,
  ),
  (
    id: 'X6',
    pattern: '{projectName|This one} is waiting in the moonlight.',
    noFacts: 37,
    small: 31,
    extreme: 53,
    noName: 37,
  ),
  (
    id: 'X7',
    pattern: '{streakCount:day/days} so far. The moon approves.',
    noFacts: null,
    small: 32,
    extreme: 39,
    noName: 39,
  ),
  (
    id: 'X8',
    pattern: '{daysSinceLastCommit:day/days} on the clock. The fog is patient.',
    noFacts: null,
    small: 39,
    extreme: 46,
    noName: 46,
  ),
];

CleanFacts _facts({int? streak, int? days, String? ghost, String? project}) =>
    CleanFacts(
      streakCount: streak,
      daysSinceLastCommit: days,
      ghostName: ghost,
      projectName: project,
    );

void main() {
  group('Template count slots', () {
    final template = Template('{streakCount:day/days} left');

    test('uses the singular only for 1', () {
      String at(int n) => template.render(_facts(streak: n));
      expect(at(0), '0 days left');
      expect(at(1), '1 day left');
      expect(at(2), '2 days left');
      expect(at(1000000), '1000000 days left');
    });

    test('daysSinceLastCommit reads its own fact', () {
      final t = Template('{daysSinceLastCommit:night/nights}');
      expect(t.render(_facts(days: 1, streak: 5)), '1 night');
      expect(t.render(_facts(days: 3, streak: 1)), '3 nights');
    });

    test('render throws StateError when the count is missing', () {
      expect(() => template.render(_facts()), throwsStateError);
    });
  });

  group('Template name slots', () {
    final template = Template('{ghostName|Your ghost} waves.');

    test('shows the name when present', () {
      expect(template.render(_facts(ghost: 'Casper')), 'Casper waves.');
    });

    test('shows the fallback without a name', () {
      expect(template.render(_facts()), 'Your ghost waves.');
    });

    test('useNames false shows the fallback', () {
      expect(
        template.render(_facts(ghost: 'Casper'), useNames: false),
        'Your ghost waves.',
      );
    });

    test('projectName reads the project name only', () {
      final t = Template('{projectName|This one} sleeps.');
      expect(t.render(_facts(ghost: 'G', project: 'Zed')), 'Zed sleeps.');
    });
  });

  group('Template eligibility and usage', () {
    final both = Template(
      '{ghostName|Your ghost} kept {streakCount:day/days}.',
    );

    test('isEligible needs every count fact, not names', () {
      expect(both.isEligible(_facts()), isFalse);
      expect(both.isEligible(_facts(streak: 0)), isTrue);
      expect(both.isEligible(_facts(days: 4, ghost: 'Bo')), isFalse);
    });

    test('a template with no count slot is always eligible', () {
      expect(Template('{ghostName|A ghost} hi').isEligible(_facts()), isTrue);
    });

    test('usedFacts counts slots filled from real facts', () {
      expect(both.usedFacts(_facts(streak: 3, ghost: 'Bo')), 2);
      expect(both.usedFacts(_facts(streak: 3)), 1);
      expect(both.usedFacts(_facts()), 0);
      expect(both.usedFacts(_facts(ghost: 'Bo')), 1);
    });

    test('usesRealName follows name presence, not counts', () {
      expect(both.usesRealName(_facts(streak: 3)), isFalse);
      expect(both.usesRealName(_facts(ghost: 'Bo')), isTrue);
      expect(both.usesRealName(_facts(project: 'P')), isFalse);
      expect(
        Template('{streakCount:day/days}').usesRealName(_facts(ghost: 'Bo')),
        isFalse,
      );
    });
  });

  group('Template with no slot', () {
    final template = Template('Floating along.');

    test('renders the literal and is always eligible', () {
      final facts = _facts(streak: 3, ghost: 'Bo');
      expect(template.isEligible(_facts()), isTrue);
      expect(template.render(facts), 'Floating along.');
      expect(template.render(facts, useNames: false), 'Floating along.');
      expect(template.usedFacts(facts), 0);
      expect(template.usesRealName(facts), isFalse);
    });

    test('an empty pattern renders as empty text', () {
      expect(Template('').render(_facts()), '');
    });
  });

  group('Template parse errors', () {
    final bad = <String, String>{
      'unknown key': '{nope|x}',
      'unknown key with count syntax': '{nope:a/b}',
      'empty slot': '{}',
      'count slot without nouns': '{streakCount}',
      'count slot with empty nouns': '{streakCount:}',
      'count slot without plural': '{streakCount:day}',
      'count slot with empty singular': '{streakCount:/days}',
      'count slot with empty plural': '{streakCount:day/}',
      'count slot with three nouns': '{streakCount:a/b/c}',
      'count slot with a bar': '{streakCount:day/days|x}',
      'count slot with only a bar': '{daysSinceLastCommit|x}',
      'name slot without fallback': '{ghostName}',
      'name slot with empty fallback': '{ghostName|}',
      'name slot with a colon': '{ghostName:a/b}',
      'name slot with colon and bar': '{projectName:a|b}',
      'stray close brace': 'a } b',
      'stray open brace': 'a { b',
      'nested open brace': '{ghostName|a{b}',
      'unclosed slot': '{ghostName|abc',
    };
    bad.forEach((name, pattern) {
      test(name, () {
        expect(() => Template(pattern), throwsStateError);
      });
    });
  });

  group('Template initial copy', () {
    const small = 'Bo';
    const big = 'abcdefghijklmnopqrstuvwx';
    final smallFacts = _facts(streak: 1, days: 1, ghost: small, project: small);
    final extremeFacts = _facts(
      streak: 1000000,
      days: 1000000,
      ghost: big,
      project: big,
    );

    test('has the 24 templates of design.md', () {
      expect(_rows, hasLength(24));
    });

    for (final row in _rows) {
      test('${row.id} parses and matches the recorded lengths', () {
        final t = Template(row.pattern);
        expect(t.render(smallFacts).length, row.small, reason: 'small');
        expect(t.render(extremeFacts).length, row.extreme, reason: 'extreme');
        expect(
          t.render(extremeFacts, useNames: false).length,
          row.noName,
          reason: 'no-name',
        );
        if (row.noFacts == null) {
          expect(t.isEligible(_facts()), isFalse);
        } else {
          expect(t.isEligible(_facts()), isTrue);
          expect(t.render(_facts()).length, row.noFacts, reason: 'no facts');
        }
      });
    }

    test('renders sample texts', () {
      final v4 = Template(_rows[11].pattern);
      expect(
        v4.render(_facts(days: 214, project: 'Moth')),
        'Moth has been dead for 214 days. Not forever, though.',
      );
      expect(
        v4.render(_facts(days: 1)),
        'This project has been dead for 1 day. Not forever, though.',
      );
      final g6 = Template(_rows[5].pattern);
      expect(
        g6.render(_facts(streak: 0, ghost: 'Bo')),
        'Bo has counted 0 days and is still floating.',
      );
      expect(
        Template(_rows[1].pattern).render(_facts()),
        'Your ghost is getting hungry…',
      );
    });
  });
}
