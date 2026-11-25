import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/domain/repo_parse_problem.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

/// Names used for the label functions.
final List<String> _names = <String>['Foo', 'Café Ghost', 'x' * 80];

/// Whether [text] only holds printable ASCII, "é" and "…".
bool _allowed(String text) => text.runes.every(
  (r) => (r >= 0x20 && r <= 0x7E) || r == 0x00E9 || r == 0x2026,
);

/// Every Resurrection_Copy output, labelled for failure messages.
Map<String, String> _allCopy() {
  final date = CalendarDate.tryParse('2024-03-05')!;
  final out = <String, String>{
    'raiseControlText': GraveyardCopy.raiseControlText,
    'epitaphRisen': GraveyardCopy.epitaphRisen,
    'livingRowHeading': GraveyardCopy.livingRowHeading,
    'layToRestText': GraveyardCopy.layToRestText,
    'restConfirmText': GraveyardCopy.restConfirmText,
    'restCancelText': GraveyardCopy.restCancelText,
    'linkCopied': GraveyardCopy.linkCopied,
    'linkCopyFailed': GraveyardCopy.linkCopyFailed,
    'allRisen': GraveyardCopy.allRisen,
    'risenOnLine': GraveyardCopy.risenOnLine(date),
  };
  for (final name in _names) {
    final n = name.length > 10 ? 'long' : name;
    out['raiseControlLabel($n)'] = GraveyardCopy.raiseControlLabel(name);
    out['layToRestLabel($n)'] = GraveyardCopy.layToRestLabel(name);
    out['restDialogRouteName($n)'] = GraveyardCopy.restDialogRouteName(name);
    out['restDialogTitle($n)'] = GraveyardCopy.restDialogTitle(name);
    out['restDialogBody($n)'] = GraveyardCopy.restDialogBody(name);
    out['repositoryLinkLabel($n)'] = GraveyardCopy.repositoryLinkLabel(name);
    out['risenAnnouncement($n)'] = GraveyardCopy.risenAnnouncement(name);
  }
  return out;
}

void main() {
  group('Resurrection copy rules', () {
    test('the sample names cover 80 code points and an "é"', () {
      expect(_names.any((n) => n.runes.length == 80), isTrue);
      expect(_names.any((n) => n.contains('é')), isTrue);
    });

    test('uses only Allowed_Characters', () {
      for (final e in _allCopy().entries) {
        expect(_allowed(e.value), isTrue, reason: '${e.key}: ${e.value}');
      }
    });

    test('has no emoji', () {
      final emoji = RegExp(
        r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]',
        unicode: true,
      );
      for (final e in _allCopy().entries) {
        expect(emoji.hasMatch(e.value), isFalse, reason: e.key);
      }
    });

    test('names no time of day', () {
      const words = [
        'morning',
        'afternoon',
        'evening',
        'night',
        'midnight',
        'dawn',
        'dusk',
      ];
      for (final e in _allCopy().entries) {
        final lower = e.value.toLowerCase();
        for (final w in words) {
          expect(lower, isNot(contains(w)), reason: e.key);
        }
      }
    });

    test('never blames, never shows exceptions or status codes', () {
      const banned = ['failed', 'invalid', 'your fault'];
      final technical = RegExp(
        r'exception|error|stack|\b[1-5]\d\d\b',
        caseSensitive: false,
      );
      for (final e in _allCopy().entries) {
        final lower = e.value.toLowerCase();
        for (final w in banned) {
          expect(lower, isNot(contains(w)), reason: e.key);
        }
        expect(technical.hasMatch(e.value), isFalse, reason: e.key);
      }
    });

    test('pins the exact strings', () {
      expect(GraveyardCopy.raiseControlText, 'Raise it');
      expect(GraveyardCopy.epitaphRisen, 'RISEN');
      expect(GraveyardCopy.livingRowHeading, 'Back among the living');
      expect(
        GraveyardCopy.risenOnLine(CalendarDate.tryParse('2024-03-05')!),
        'Risen on 5 Mar 2024',
      );
      expect(GraveyardCopy.layToRestText, 'Lay it back to rest');
      expect(GraveyardCopy.restConfirmText, 'Lay it to rest');
      expect(GraveyardCopy.restCancelText, 'Keep it risen');
      expect(GraveyardCopy.linkCopied, 'Link copied');
      expect(
        GraveyardCopy.linkCopyFailed,
        'That link would not copy. Try once more.',
      );
      expect(GraveyardCopy.allRisen, 'Every grave here has risen.');
      expect(GraveyardCopy.risenAnnouncement('Foo'), 'Foo has risen.');
    });

    test('rest dialog body mentions the graveyard, not "delete"', () {
      for (final name in _names) {
        final body = GraveyardCopy.restDialogBody(name).toLowerCase();
        expect(body, contains('graveyard'));
        expect(body, isNot(contains('delete')));
      }
    });
  });

  group('Pre-existing GraveyardCopy strings are unchanged', () {
    test('epitaph is still R.I.P.', () {
      expect(GraveyardCopy.epitaph, 'R.I.P.');
    });

    test('constants', () {
      expect(GraveyardCopy.duplicate, 'This grave already exists.');
      expect(
        GraveyardCopy.saveError,
        "Couldn't tuck that into the crypt. Your graves are still here.",
      );
      expect(
        GraveyardCopy.loadError,
        "The graveyard won't open right now. Give it another try.",
      );
      expect(GraveyardCopy.buriedByHand, 'Buried by hand.');
      expect(GraveyardCopy.loadingCaption, 'Waking the graveyard…');
      expect(GraveyardCopy.loadingLabel, 'Loading graves');
      expect(GraveyardCopy.addButton, 'Bury a project');
      expect(GraveyardCopy.screenTitle, 'Graveyard');
      expect(GraveyardCopy.tryAgain, 'Try again');
      expect(GraveyardCopy.emptyTitle, 'Nothing is buried here yet');
      expect(
        GraveyardCopy.emptyBody,
        'Lay an abandoned project to rest by hand, '
        'or dig one up from GitHub.',
      );
      expect(GraveyardCopy.sheetTitle, 'Bury a project');
      expect(GraveyardCopy.buryByHand, 'Bury by hand');
      expect(GraveyardCopy.importFromGitHub, 'Import from GitHub');
      expect(GraveyardCopy.closeSheet, 'Close');
      expect(GraveyardCopy.nameLabel, 'Project name');
      expect(GraveyardCopy.nameHint, 'My unfinished masterpiece');
      expect(GraveyardCopy.dateLabel, 'Last worked on');
      expect(GraveyardCopy.dateHint, 'Pick the day');
      expect(GraveyardCopy.buryButton, 'Bury it');
      expect(GraveyardCopy.repoLabel, 'GitHub repository');
      expect(GraveyardCopy.repoHint, 'owner/repo or a github.com address');
      expect(GraveyardCopy.digUpButton, 'Dig it up');
      expect(GraveyardCopy.importingCaption, 'Digging up the repository…');
      expect(GraveyardCopy.deleteBody, 'This grave will be gone for good.');
      expect(GraveyardCopy.keepIt, 'Keep it');
      expect(GraveyardCopy.delete, 'Delete');
      expect(GraveyardCopy.seanceControlText, 'Hold a séance');
      expect(GraveyardCopy.closeSeanceLabel, 'Close séance');
      expect(GraveyardCopy.seanceThinkingCaption, 'The spirits are murmuring…');
      expect(
        GraveyardCopy.safeVerdictLine,
        'The spirits are quiet, but every project can rise again.',
      );
    });

    test('functions', () {
      final date = CalendarDate.tryParse('2023-01-03')!;
      expect(GraveyardCopy.date(date), '3 Jan 2023');
      expect(GraveyardCopy.dateLine(date), 'Died 3 Jan 2023');
      expect(GraveyardCopy.stars(1200, archived: true), '1,200, Archived');
      expect(GraveyardCopy.deleteLabel('Foo'), 'Delete Foo');
      expect(GraveyardCopy.deleteTitle('Foo'), 'Delete Foo?');
      expect(
        GraveyardCopy.manualGraveLabel(name: 'Foo', deadForText: 'Dead 1 day'),
        'Foo. Dead 1 day. Buried by hand.',
      );
      expect(GraveyardCopy.seanceControlLabel('Foo'), 'Hold a séance for Foo');
      expect(GraveyardCopy.seanceRouteName('Foo'), 'Séance for Foo');
      expect(
        GraveyardCopy.revivalStepLabel(1, 3, 'Do it'),
        'Step 1 of 3: Do it',
      );
      expect(
        GraveyardCopy.rejection(GraveRejection.nameEmpty),
        'Every grave needs a name.',
      );
      expect(
        GraveyardCopy.parseProblem(RepoParseProblem.notGitHub),
        'Only GitHub addresses work here. Try owner/repo.',
      );
    });
  });
}
