import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

void main() {
  group('GraveyardCopy resurrection strings', () {
    test('static strings are exact', () {
      expect(GraveyardCopy.epitaph, 'R.I.P.');
      expect(GraveyardCopy.raiseControlText, 'Raise it');
      expect(GraveyardCopy.epitaphRisen, 'RISEN');
      expect(GraveyardCopy.livingRowHeading, 'Back among the living');
      expect(GraveyardCopy.layToRestText, 'Lay it back to rest');
      expect(GraveyardCopy.restConfirmText, 'Lay it to rest');
      expect(GraveyardCopy.restCancelText, 'Keep it risen');
      expect(GraveyardCopy.linkCopied, 'Link copied');
      expect(
        GraveyardCopy.linkCopyFailed,
        'That link would not copy. Try once more.',
      );
      expect(GraveyardCopy.allRisen, 'Every grave here has risen.');
    });

    test('name based strings are exact', () {
      expect(GraveyardCopy.raiseControlLabel('Foo'), 'Raise Foo from the dead');
      expect(GraveyardCopy.layToRestLabel('Foo'), 'Lay Foo back to rest');
      expect(GraveyardCopy.restDialogRouteName('Foo'), 'Lay Foo back to rest?');
      expect(
        GraveyardCopy.repositoryLinkLabel('Foo'),
        'Copy the repository link of Foo',
      );
      expect(GraveyardCopy.risenAnnouncement('Foo'), 'Foo has risen.');
      expect(
        GraveyardCopy.risenOnLine(CalendarDate.tryParse('2024-03-05')!),
        'Risen on 5 Mar 2024',
      );
    });

    test('rest dialog text never says anything is deleted', () {
      final text =
          '${GraveyardCopy.restDialogTitle('Foo')} '
                  '${GraveyardCopy.restDialogBody('Foo')}'
              .toLowerCase();
      expect(text, contains('graveyard'));
      expect(text, isNot(contains('delete')));
    });
  });
}
