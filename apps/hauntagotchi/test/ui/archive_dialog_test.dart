import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/archive_dialog.dart';

void main() {
  Future<void> open(WidgetTester tester, List<bool> results) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoffinTheme.dark(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await ArchiveDialog.show(context, habitName: 'Stretch'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirm returns true', (tester) async {
    final results = <bool>[];
    await open(tester, results);
    expect(find.textContaining('Stretch'), findsOneWidget);
    expect(results, isEmpty);

    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('cancel returns false', (tester) async {
    final results = <bool>[];
    await open(tester, results);
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('dismissing by tapping outside returns false', (tester) async {
    final results = <bool>[];
    await open(tester, results);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('buttons are at least 48x48 and labelled', (tester) async {
    await open(tester, <bool>[]);
    for (final type in [TextButton, FilledButton]) {
      final size = tester.getSize(
        find.descendant(
          of: find.byType(ArchiveDialog),
          matching: find.byType(type),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.bySemanticsLabel('Keep habit'), findsOneWidget);
    expect(find.bySemanticsLabel('Archive Stretch'), findsOneWidget);
  });
}
