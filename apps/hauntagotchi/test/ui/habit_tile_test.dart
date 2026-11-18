import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/habit_tile.dart';

void main() {
  var toggled = 0;
  var renamed = 0;
  var archived = 0;

  Future<void> pump(WidgetTester tester, {required bool done}) {
    toggled = renamed = archived = 0;
    return tester.pumpWidget(
      MaterialApp(
        theme: CoffinTheme.dark(),
        home: Scaffold(
          body: HabitTile(
            name: 'Read a page',
            done: done,
            onToggle: () => toggled++,
            onRename: () => renamed++,
            onArchive: () => archived++,
          ),
        ),
      ),
    );
  }

  testWidgets('check control is labelled by state', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, done: false);
    expect(find.bySemanticsLabel('Read a page, not done yet'), findsOneWidget);

    await pump(tester, done: true);
    expect(find.bySemanticsLabel('Read a page, done today'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('check control and menu are at least 48 by 48', (tester) async {
    await pump(tester, done: false);
    for (final key in const ['habit-check', 'habit-menu']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
    }
  });

  testWidgets('tapping the check control toggles', (tester) async {
    await pump(tester, done: false);
    await tester.tap(find.byKey(const ValueKey('habit-check')));
    expect(toggled, 1);
  });

  testWidgets('menu offers Rename and Archive', (tester) async {
    await pump(tester, done: false);
    await tester.tap(find.byKey(const ValueKey('habit-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(renamed, 1);

    await tester.tap(find.byKey(const ValueKey('habit-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(archived, 1);
  });

  testWidgets('check control reacts to hover', (tester) async {
    await pump(tester, done: false);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('habit-check'))),
    );
    await tester.pump();
    final response = tester.widget<InkResponse>(
      find.byKey(const ValueKey('habit-check')),
    );
    expect(response.hoverColor, isNotNull);
    expect(response.highlightColor, isNotNull);
  });
}
