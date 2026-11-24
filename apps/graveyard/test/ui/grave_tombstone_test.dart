import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for_formatter.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);

Grave _github(CalendarDate died) => Grave.github(
  id: 'b',
  name: 'atom',
  dateOfDeath: died,
  repo: const RepoInfo(
    fullName: 'atom/atom',
    stars: 60681,
    archived: true,
    description: ':atom: The hackable text editor',
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Grave grave, {
  VoidCallback? onDelete,
  ThemeData? theme,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? CoffinTheme.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: GraveTombstone(
          grave: grave,
          today: _today,
          onDelete: onDelete ?? () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('shows cleaned description, stars and no cracks when young', (
    tester,
  ) async {
    await _pump(tester, _github(CalendarDate(2023, 1, 3)));
    expect(find.text('The hackable text editor'), findsOneWidget);
    expect(find.text('60,681, Archived'), findsOneWidget);
    expect(find.text('R.I.P.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cracks-b')), findsNothing);
  });

  testWidgets('draws cracks above 1825 days and not at 1825', (tester) async {
    await _pump(tester, _github(CalendarDate(2010, 1, 3)));
    expect(find.byKey(const ValueKey<String>('cracks-b')), findsOneWidget);
    final todayEpoch = CalendarDate(1970, 1, 1).daysUntil(_today);
    await _pump(tester, _github(CalendarDate.fromEpochDay(todayEpoch - 1825)));
    expect(find.byKey(const ValueKey<String>('cracks-b')), findsNothing);
    await _pump(tester, _github(CalendarDate.fromEpochDay(todayEpoch - 1826)));
    expect(find.byKey(const ValueKey<String>('cracks-b')), findsOneWidget);
  });

  testWidgets('manual grave says Buried by hand and delete works', (
    tester,
  ) async {
    var deleted = 0;
    await _pump(
      tester,
      Grave.manual(id: 'a', name: 'Old', dateOfDeath: CalendarDate(2024, 1, 3)),
      onDelete: () => deleted++,
    );
    expect(find.text('Buried by hand.'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    expect(deleted, 1);
  });

  for (final entry in <String, ThemeData Function()>{
    'dark': CoffinTheme.dark,
    'daylight': CoffinTheme.light,
  }.entries) {
    group('content in the ${entry.key} theme', () {
      ThemeData theme() => entry.value();
      final deadFor = DeadForFormatter.format(CalendarDate(2023, 1, 3), _today);

      Grave named(String name, {String? description}) => Grave.github(
        id: 'g',
        name: name,
        dateOfDeath: CalendarDate(2023, 1, 3),
        repo: RepoInfo(
          fullName: 'atom/atom',
          stars: 60681,
          archived: true,
          description: description,
        ),
      );

      // The body column is the nearest Column around the Dead_For_Text.
      Size bodySize(WidgetTester tester) => tester.getSize(
        find
            .ancestor(of: find.text(deadFor), matching: find.byType(Column))
            .first,
      );

      testWidgets('Dead_For_Text and owner/repo each appear once', (
        tester,
      ) async {
        await _pump(tester, named('atom/atom'), theme: theme());
        expect(find.text(deadFor), findsOneWidget);
        expect(find.text('atom/atom'), findsOneWidget);
      });

      testWidgets('a different name shows the full name once as source', (
        tester,
      ) async {
        await _pump(tester, named('atom'), theme: theme());
        expect(find.text('atom'), findsOneWidget);
        expect(find.text('atom/atom'), findsOneWidget);
        expect(find.text(deadFor), findsOneWidget);
      });

      testWidgets('shows cleaned description, stars and Archived in words', (
        tester,
      ) async {
        await _pump(
          tester,
          named('atom', description: ':atom: The hackable text editor'),
          theme: theme(),
        );
        expect(find.text('The hackable text editor'), findsOneWidget);
        expect(find.textContaining(':atom:'), findsNothing);
        expect(find.text('60,681, Archived'), findsOneWidget);
      });

      testWidgets('an empty cleaned description leaves no gap', (tester) async {
        await _pump(
          tester,
          named('atom', description: ':atom:'),
          theme: theme(),
        );
        final emptyCleaned = bodySize(tester);
        await _pump(tester, named('atom'), theme: theme());
        expect(bodySize(tester), emptyCleaned);
        await _pump(
          tester,
          named('atom', description: 'The hackable text editor'),
          theme: theme(),
        );
        expect(bodySize(tester).height, greaterThan(emptyCleaned.height));
      });

      testWidgets('a manual grave says Buried by hand once', (tester) async {
        await _pump(
          tester,
          Grave.manual(
            id: 'm',
            name: 'Old',
            dateOfDeath: CalendarDate(2023, 1, 3),
          ),
          theme: theme(),
        );
        expect(find.text('Buried by hand.'), findsOneWidget);
        expect(find.text(deadFor), findsOneWidget);
        expect(find.byIcon(Icons.star), findsNothing);
      });

      testWidgets('semantic labels for manual and GitHub graves', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final old = DeadForFormatter.format(CalendarDate(2010, 1, 3), _today);
        await _pump(
          tester,
          Grave.manual(
            id: 'm',
            name: 'Old',
            dateOfDeath: CalendarDate(2010, 1, 3),
          ),
          theme: theme(),
        );
        expect(
          find.bySemanticsLabel('Old. $old. Buried by hand.'),
          findsOneWidget,
        );

        await _pump(
          tester,
          Grave.github(
            id: 'g',
            name: 'atom',
            dateOfDeath: CalendarDate(2010, 1, 3),
            repo: const RepoInfo(
              fullName: 'atom/atom',
              stars: 60681,
              archived: true,
              description: ':atom: The hackable text editor',
            ),
          ),
          theme: theme(),
        );
        final label =
            'atom. $old. From GitHub, atom/atom, 60,681 stars, '
            'archived. Description: The hackable text editor';
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(label.toLowerCase(), isNot(contains('crack')));
        expect(find.byKey(const ValueKey<String>('cracks-g')), findsOneWidget);
        handle.dispose();
      });

      testWidgets('the description is limited to 3 lines', (tester) async {
        final long = List.filled(60, 'haunted').join(' ');
        await _pump(tester, named('atom', description: long), theme: theme());
        final text = tester.widget<Text>(find.text(long));
        expect(text.maxLines, 3);
        expect(text.overflow, TextOverflow.ellipsis);
        final height = tester.getSize(find.text(long)).height;
        await _pump(
          tester,
          named('atom', description: 'haunted'),
          theme: theme(),
        );
        final one = tester.getSize(find.text('haunted')).height;
        expect(height, closeTo(one * 3, 1));
      });

      testWidgets('the delete target is at least 48x48 and labelled', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, named('atom'), theme: theme());
        final size = tester.getSize(find.byType(TextButton));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(find.bySemanticsLabel('Delete atom'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('delete has hover and press states', (tester) async {
        var deleted = 0;
        await _pump(
          tester,
          named('atom'),
          onDelete: () => deleted++,
          theme: theme(),
        );
        final button = tester.widget<TextButton>(find.byType(TextButton));
        final context = tester.element(find.byType(TextButton));
        final overlay = button.defaultStyleOf(context).overlayColor!;
        expect(
          overlay.resolve(<WidgetState>{WidgetState.hovered})!.a,
          greaterThan(0),
        );
        expect(
          overlay.resolve(<WidgetState>{WidgetState.pressed})!.a,
          greaterThan(0),
        );

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(TextButton)));
        await tester.pump();

        await mouse.down(tester.getCenter(find.byType(TextButton)));
        await tester.pump();
        await mouse.up();
        await tester.pump();
        expect(deleted, 1);
        await mouse.removePointer();
      });
    });
  }
}
