import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
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
    GraveyardCopy.epitaph('Dead for 3 weeks'),
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
    expect(msg(const Duration(seconds: 61)), contains('about 2 minutes.'));
  });

  test('date line uses English month names', () {
    expect(GraveyardCopy.dateLine(CalendarDate(2023, 1, 3)), 'Died 3 Jan 2023');
    expect(GraveyardCopy.date(CalendarDate(2026, 12, 31)), '31 Dec 2026');
  });
}
