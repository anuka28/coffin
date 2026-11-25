import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/living_split.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/living_row.dart';

Grave _grave(String id, String name, CalendarDate? risen) => Grave.manual(
  id: id,
  name: name,
  dateOfDeath: CalendarDate(2024, 1, 1),
  risenOn: risen,
);

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('renders nothing when there are no entries', (tester) async {
    await tester.pumpWidget(
      _host(LivingRow(entries: const <Grave>[], onLayToRest: (_) {})),
    );
    expect(find.text(GraveyardCopy.livingRowHeading), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('shows heading, entries in order and the risen line', (
    tester,
  ) async {
    final first = _grave('a', 'Alpha', CalendarDate(2025, 5, 2));
    final second = _grave('b', 'Beta', CalendarDate(2025, 5, 1));
    await tester.pumpWidget(
      _host(LivingRow(entries: [first, second], onLayToRest: (_) {})),
    );
    expect(find.text(GraveyardCopy.livingRowHeading), findsOneWidget);
    expect(
      find.text(GraveyardCopy.risenOnLine(first.risenOn!)),
      findsOneWidget,
    );
    expect(find.text(GraveyardCopy.layToRestText), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Beta')).dy),
    );
  });

  testWidgets('lay to rest control is 48x48, labelled and calls back', (
    tester,
  ) async {
    final grave = _grave('a', 'Alpha', CalendarDate(2025, 5, 2));
    Grave? tapped;
    await tester.pumpWidget(
      _host(LivingRow(entries: [grave], onLayToRest: (g) => tapped = g)),
    );
    final button = find.byType(TextButton);
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel(GraveyardCopy.layToRestLabel('Alpha')),
      findsOneWidget,
    );
    await tester.tap(button);
    expect(tapped, grave);
  });

  testWidgets('an 80 code point name at text scale 2.0 does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final grave = _grave('a', 'W' * 80, CalendarDate(2025, 5, 2));
    await tester.pumpWidget(
      _host(
        scale: 2,
        Padding(
          padding: const EdgeInsets.all(16),
          child: LivingRow(entries: [grave], onLayToRest: (_) {}),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('task 23.7', () {
    testWidgets('heading is a semantic header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          LivingRow(
            entries: [_grave('a', 'Alpha', CalendarDate(2025, 5, 2))],
            onLayToRest: (_) {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text(GraveyardCopy.livingRowHeading)),
        matchesSemantics(label: GraveyardCopy.livingRowHeading, isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('entries show name and Risen on date', (tester) async {
      final grave = _grave('a', 'Alpha', CalendarDate(2025, 5, 2));
      await tester.pumpWidget(
        _host(LivingRow(entries: [grave], onLayToRest: (_) {})),
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(
        find.text(GraveyardCopy.risenOnLine(CalendarDate(2025, 5, 2))),
        findsOneWidget,
      );
      expect(find.textContaining('Risen on'), findsOneWidget);
    });

    testWidgets('LivingSplit order: newest risenOn first, ties by sorter', (
      tester,
    ) async {
      Grave g(String id, String name, CalendarDate died, CalendarDate risen) =>
          Grave.manual(id: id, name: name, dateOfDeath: died, risenOn: risen);
      final old = g(
        'o',
        'Old',
        CalendarDate(2024, 1, 1),
        CalendarDate(2025, 1, 1),
      );
      final newest = g(
        'n',
        'Newest',
        CalendarDate(2024, 1, 1),
        CalendarDate(2025, 6, 1),
      );
      final tieB = g(
        'b',
        'Bravo',
        CalendarDate(2024, 3, 1),
        CalendarDate(2025, 3, 1),
      );
      final tieA = g(
        'a',
        'Alpha',
        CalendarDate(2024, 3, 1),
        CalendarDate(2025, 3, 1),
      );
      final tieRecent = g(
        'r',
        'Zulu',
        CalendarDate(2024, 9, 1),
        CalendarDate(2025, 3, 1),
      );
      final living = LivingSplit.split(
        graves: [old, tieB, newest, tieA, tieRecent],
        playing: const <String>{},
      ).$2;
      await tester.pumpWidget(
        _host(LivingRow(entries: living, onLayToRest: (_) {})),
      );
      double y(String n) => tester.getTopLeft(find.text(n)).dy;
      final names = ['Newest', 'Zulu', 'Alpha', 'Bravo', 'Old'];
      for (var i = 0; i < names.length - 1; i++) {
        expect(y(names[i]), lessThan(y(names[i + 1])), reason: names[i]);
      }
    });

    testWidgets('empty list shows no row, heading or placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(LivingRow(entries: const <Grave>[], onLayToRest: (_) {})),
      );
      expect(find.byType(Text), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.getSize(find.byType(LivingRow)), Size.zero);
    });

    testWidgets('an 80 code point name renders with no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final name = List.generate(80, (i) => 'ab cd'[i % 5]).join();
      await tester.pumpWidget(
        _host(
          LivingRow(
            entries: [_grave('a', name, CalendarDate(2025, 5, 2))],
            onLayToRest: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(name), findsOneWidget);
    });

    testWidgets('one semantic node per entry text, no decorative node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final grave = _grave('a', 'Alpha', CalendarDate(2025, 5, 2));
      await tester.pumpWidget(
        _host(LivingRow(entries: [grave], onLayToRest: (_) {})),
      );
      final line = GraveyardCopy.risenOnLine(grave.risenOn!);
      expect(find.bySemanticsLabel('Alpha. $line'), findsOneWidget);
      expect(find.bySemanticsLabel('Alpha'), findsNothing);
      expect(find.bySemanticsLabel(line), findsNothing);
      expect(find.bySemanticsLabel(GraveyardCopy.layToRestText), findsNothing);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(GraveyardCopy.layToRestLabel('Alpha')),
        ),
        matchesSemantics(
          label: GraveyardCopy.layToRestLabel('Alpha'),
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a manual grave has no repository link', (tester) async {
      await tester.pumpWidget(
        _host(
          LivingRow(
            entries: [_grave('a', 'Alpha', CalendarDate(2025, 5, 2))],
            onLayToRest: (_) {},
          ),
        ),
      );
      expect(find.byKey(const ValueKey('repository-link-a')), findsNothing);
    });

    testWidgets('control has visible and semantic label and a 48x48 target', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          LivingRow(
            entries: [_grave('a', 'Alpha', CalendarDate(2025, 5, 2))],
            onLayToRest: (_) {},
          ),
        ),
      );
      expect(find.text('Lay it back to rest'), findsOneWidget);
      expect(find.bySemanticsLabel('Lay Alpha back to rest'), findsOneWidget);
      final size = tester.getSize(find.byKey(const ValueKey('lay-to-rest-a')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('control reacts to focus, hover and press', (tester) async {
      final grave = _grave('a', 'Alpha', CalendarDate(2025, 5, 2));
      Grave? tapped;
      await tester.pumpWidget(
        _host(LivingRow(entries: [grave], onLayToRest: (g) => tapped = g)),
      );
      final button = find.byKey(const ValueKey('lay-to-rest-a'));
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final focusNode = tester.widget<TextButton>(button).focusNode!;
      expect(focusNode.hasFocus, isFalse);
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(focusNode.hasFocus, isTrue);
      final focusedHighlight = _overlayPaintCount(tester);
      focusNode.unfocus();
      await tester.pumpAndSettle();
      expect(_overlayPaintCount(tester), lessThan(focusedHighlight));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      final idle = _overlayPaintCount(tester);
      await mouse.moveTo(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_overlayPaintCount(tester), greaterThan(idle));
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 300));

      final touch = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_overlayPaintCount(tester), greaterThan(idle));
      await touch.up();
      await tester.pumpAndSettle();
      expect(tapped, grave);
    });
  });
}

int _overlayPaintCount(WidgetTester tester) {
  var count = 0;
  void visit(Element e) {
    if (e is StatefulElement &&
        e.widget.runtimeType.toString() == '_InkResponseStateWidget') {
      final state = e.state as dynamic;
      try {
        if (state.highlightsExist == true) count++;
      } catch (_) {}
    }
    e.visitChildren(visit);
  }

  visit(tester.element(find.byType(TextButton)));
  return count;
}
