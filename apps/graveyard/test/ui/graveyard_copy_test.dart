import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/rate_limit_wait.dart';
import 'package:graveyard/src/domain/seance/revival_band.dart';
import 'package:graveyard/src/domain/seance/revival_step_kind.dart';
import 'package:graveyard/src/domain/repo_parse_problem.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

void main() {
  final now = DateTime.utc(2026, 11, 23, 12);

  List<String> allMessages() => [
    for (final p in RepoParseProblem.values) GraveyardCopy.parseProblem(p),
    for (final k in ImportFailureKind.values)
      GraveyardCopy.importFailure(ImportFailure(k), now: now),
    GraveyardCopy.importFailure(
      ImportFailure(
        ImportFailureKind.rateLimited,
        resetAt: now.add(const Duration(minutes: 5)),
      ),
      now: now,
    ),
    for (final r in GraveRejection.values) GraveyardCopy.rejection(r),
    GraveyardCopy.saveError,
    GraveyardCopy.loadError,
    GraveyardCopy.memoryNotice,
    GraveyardCopy.emptyBody,
    GraveyardCopy.emptyTitle,
    GraveyardCopy.deleteBody,
    GraveyardCopy.epitaph,
    GraveyardCopy.dateLine(CalendarDate(2023, 1, 3)),
  ];

  test('no message uses banned words or a raw status code', () {
    for (final m in allMessages()) {
      final lower = m.toLowerCase();
      expect(lower, isNot(contains('failed')), reason: m);
      expect(lower, isNot(contains('invalid')), reason: m);
      expect(lower, isNot(contains('your fault')), reason: m);
      expect(lower, isNot(contains('exception')), reason: m);
      expect(RegExp(r'\b[45]\d\d\b').hasMatch(m), isFalse, reason: m);
    }
  });

  test('every string is printable ASCII, except the ellipsis and en dash', () {
    final strings = <String>[
      ...allMessages(),
      GraveyardCopy.duplicate,
      for (final m in [1, 12]) ...[
        GraveyardCopy.stars(m, archived: false),
        GraveyardCopy.stars(m, archived: true),
      ],
      GraveyardCopy.buriedByHand,
      GraveyardCopy.manualGraveLabel(name: 'Ghost', deadForText: 'Died today'),
      for (final s in [1, 12])
        for (final a in [false, true]) ...[
          GraveyardCopy.githubGraveLabel(
            name: 'Ghost',
            deadForText: 'Dead for 3 weeks',
            fullName: 'a/b',
            stars: s,
            archived: a,
          ),
          GraveyardCopy.githubGraveLabel(
            name: 'Ghost',
            deadForText: 'Dead for 3 weeks',
            fullName: 'a/b',
            stars: s,
            archived: a,
            description: 'A tiny repo',
          ),
        ],
      GraveyardCopy.deleteLabel('Ghost'),
      GraveyardCopy.loadingCaption,
      GraveyardCopy.loadingLabel,
      GraveyardCopy.addButton,
      GraveyardCopy.screenTitle,
      GraveyardCopy.tryAgain,
      GraveyardCopy.sheetTitle,
      GraveyardCopy.buryByHand,
      GraveyardCopy.importFromGitHub,
      GraveyardCopy.closeSheet,
      GraveyardCopy.nameLabel,
      GraveyardCopy.nameHint,
      GraveyardCopy.dateLabel,
      GraveyardCopy.dateHint,
      GraveyardCopy.buryButton,
      GraveyardCopy.repoLabel,
      GraveyardCopy.repoHint,
      GraveyardCopy.digUpButton,
      GraveyardCopy.importingCaption,
      GraveyardCopy.deleteTitle('Ghost'),
      GraveyardCopy.keepIt,
      GraveyardCopy.delete,
      for (var month = 1; month <= 12; month++)
        GraveyardCopy.date(CalendarDate(2023, month, 1)),
      GraveyardCopy.importFailure(
        ImportFailure(
          ImportFailureKind.rateLimited,
          resetAt: now.add(const Duration(minutes: 1)),
        ),
        now: now,
      ),
      GraveyardCopy.importFailure(
        ImportFailure(ImportFailureKind.rateLimited),
        now: now,
      ),
    ];
    for (final s in strings) {
      final lower = s.toLowerCase();
      for (final banned in ['failed', 'invalid', 'your fault']) {
        expect(lower, isNot(contains(banned)), reason: s);
      }
      for (final rune in s.runes) {
        final ok =
            (rune >= 0x20 && rune <= 0x7E) || rune == 0x2026 || rune == 0x2013;
        if (!ok) {
          fail(
            'Disallowed character U+'
            '${rune.toRadixString(16).toUpperCase().padLeft(4, '0')} '
            'in string: "$s"',
          );
        }
      }
    }
  });

  test('star text has no glyph and the label says N stars', () {
    expect(GraveyardCopy.stars(12, archived: false), '12');
    expect(GraveyardCopy.stars(12, archived: true), '12, Archived');
    String label(int n) => GraveyardCopy.githubGraveLabel(
      name: 'G',
      deadForText: 'Died today',
      fullName: 'a/b',
      stars: n,
      archived: false,
    );
    expect(label(1), contains('1 star.'));
    expect(label(12), contains('12 stars'));
  });

  test('the epitaph is R.I.P. and has no dead-for text', () {
    expect(GraveyardCopy.epitaph, 'R.I.P.');
    expect(GraveyardCopy.epitaph, isNot(contains('Dead for')));
    expect(GraveyardCopy.epitaph, isNot(contains('Died')));
  });

  test('star line and label use thousands separators', () {
    expect(GraveyardCopy.stars(60681, archived: false), '60,681');
    expect(GraveyardCopy.stars(60681, archived: true), '60,681, Archived');
    final label = GraveyardCopy.githubGraveLabel(
      name: 'Atom',
      deadForText: 'Dead for 3 years',
      fullName: 'atom/atom',
      stars: 60681,
      archived: false,
      description: 'The :hammer: hackable text editor',
    );
    expect(label, contains('60,681 stars'));
    expect(label, isNot(contains('60681')));
    expect(label, contains('The hackable text editor'));
    expect(label, isNot(contains(':hammer:')));
  });

  test('every import failure has a distinct message', () {
    final messages = {
      for (final k in ImportFailureKind.values)
        GraveyardCopy.importFailure(ImportFailure(k), now: now),
    };
    expect(messages.length, ImportFailureKind.values.length);
  });

  test('rate limit gives rounded minutes, at least one', () {
    String msg(Duration d) => GraveyardCopy.importFailure(
      ImportFailure(ImportFailureKind.rateLimited, resetAt: now.add(d)),
      now: now,
    );
    expect(msg(Duration.zero), contains('about 1 minute.'));
    expect(msg(const Duration(minutes: -10)), contains('about 1 minute.'));
    expect(msg(const Duration(seconds: 61)), contains('about 2 minutes.'));
    for (final minutes in [1, 2, 7, 59, 120]) {
      final wait = RateLimitWait.minutes(
        resetAt: now.add(Duration(minutes: minutes)),
        now: now,
      );
      expect(wait, minutes);
      expect(msg(Duration(minutes: minutes)), contains('about $wait minute'));
    }
  });

  test('rate limit without a reset moment shows no number', () {
    final m = GraveyardCopy.importFailure(
      ImportFailure(ImportFailureKind.rateLimited),
      now: now,
    );
    expect(RegExp(r'\d').hasMatch(m), isFalse, reason: m);
  });

  test('import messages show no exception text or status code', () {
    for (final k in ImportFailureKind.values) {
      final m = GraveyardCopy.importFailure(ImportFailure(k), now: now);
      expect(m, isNot(contains('Exception')), reason: m);
      expect(m, isNot(contains('Error')), reason: m);
      expect(m, isNot(contains('Instance of')), reason: m);
      expect(RegExp(r'\d{3}').hasMatch(m), isFalse, reason: m);
    }
  });

  test('date line uses English month names', () {
    expect(GraveyardCopy.dateLine(CalendarDate(2023, 1, 3)), 'Died 3 Jan 2023');
    expect(GraveyardCopy.date(CalendarDate(2026, 12, 31)), '31 Dec 2026');
  });

  group('Seance_Copy', () {
    const names = ['Ghost', 'Atom', 'A very long project name'];
    final steps = <String>[
      GraveyardCopy.stepForkRepository,
      GraveyardCopy.stepWriteDownPurpose,
      GraveyardCopy.stepUpdateDependencies,
      GraveyardCopy.stepSkimReadme,
      GraveyardCopy.stepFixOneThing,
      GraveyardCopy.stepAskAFriend,
      GraveyardCopy.stepAddOneTest,
    ];
    final seanceStrings = <String>[
      GraveyardCopy.seanceControlText,
      GraveyardCopy.closeSeanceLabel,
      GraveyardCopy.seanceThinkingCaption,
      GraveyardCopy.safeVerdictLine,
      ...steps,
      for (final k in RevivalStepKind.values) GraveyardCopy.revivalStepText(k),
      for (final b in RevivalBand.values) GraveyardCopy.revivalBandLabel(b),
      for (final n in names) ...[
        GraveyardCopy.seanceControlLabel(n),
        GraveyardCopy.seanceRouteName(n),
        for (final b in RevivalBand.values)
          for (final score in [0, 39, 40, 69, 70, 100])
            GraveyardCopy.revivalScoreLabel(score, b),
      ],
      for (var k = 1; k <= 3; k++)
        for (final kind in RevivalStepKind.values)
          GraveyardCopy.revivalStepLabel(
            k,
            3,
            GraveyardCopy.revivalStepText(kind),
          ),
    ];

    bool allowed(int r) => (r >= 0x20 && r <= 0x7E) || r == 0xE9 || r == 0x2026;

    void expectClean(String s) {
      for (final r in s.runes) {
        expect(
          allowed(r),
          isTrue,
          reason:
              'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')} in "$s"',
        );
      }
      final lower = s.toLowerCase();
      for (final word in [
        'morning',
        'afternoon',
        'evening',
        'night',
        'midnight',
        'dawn',
        'dusk',
        'failed',
        'invalid',
        'your fault',
        'exception',
        'error',
        'instance of',
      ]) {
        expect(lower, isNot(contains(word)), reason: s);
      }
      expect(RegExp(r'\b[45]\d\d\b').hasMatch(s), isFalse, reason: s);
    }

    test('every string uses only allowed characters and no banned words', () {
      for (final s in seanceStrings) {
        expect(s, isNotEmpty);
        expectClean(s);
      }
    });

    test('safeVerdictLine is one short sentence with no placeholder', () {
      final line = GraveyardCopy.safeVerdictLine;
      expect(line.length, lessThanOrEqualTo(140));
      expect(line, isNot(contains('{')));
      expect(line, isNot(contains('}')));
      expect(line, isNot(contains(r'$')));
      expect(line, isNot(contains('%')));
      expect(line.trim(), line);
      expect(RegExp(r'[.!?]').allMatches(line).length, 1);
      expect(line.endsWith('.'), isTrue);
    });

    test('every step constant has at most 48 characters', () {
      for (final s in steps) {
        expect(s.length, lessThanOrEqualTo(48), reason: s);
      }
    });

    test('revivalStepText is total, short and injective', () {
      final texts = <String>{};
      for (final kind in RevivalStepKind.values) {
        final text = GraveyardCopy.revivalStepText(kind);
        expect(text, isNotEmpty, reason: '$kind');
        expect(text.length, lessThanOrEqualTo(48), reason: text);
        expectClean(text);
        texts.add(text);
      }
      expect(texts.length, RevivalStepKind.values.length);
    });

    test('label forms are pinned', () {
      expect(
        GraveyardCopy.seanceControlLabel('Ghost'),
        'Hold a séance for Ghost',
      );
      expect(GraveyardCopy.seanceRouteName('Ghost'), 'Séance for Ghost');
      expect(
        GraveyardCopy.revivalScoreLabel(72, RevivalBand.readyToRise),
        'Revival score 72 out of 100, Ready to rise',
      );
      expect(
        GraveyardCopy.revivalScoreLabel(5, RevivalBand.restless),
        'Revival score 5 out of 100, Restless',
      );
      expect(
        GraveyardCopy.revivalScoreLabel(40, RevivalBand.stirring),
        'Revival score 40 out of 100, Stirring',
      );
      expect(
        GraveyardCopy.revivalStepLabel(2, 3, 'Do a thing'),
        'Step 2 of 3: Do a thing',
      );
    });
  });
}
