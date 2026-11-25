import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/habit_rejection.dart';
import 'package:hauntagotchi/src/ui/habit_name_dialog.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    HabitRejection? Function(String) onSubmit,
    List<bool> results, {
    String initialName = '',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoffinTheme.dark(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await HabitNameDialog.show(
                context,
                title: 'Add a habit',
                confirmLabel: 'Add',
                initialName: initialName,
                onSubmit: onSubmit,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('keeps the typed text and shows the reason on rejection', (
    tester,
  ) async {
    final results = <bool>[];
    await open(tester, (_) => HabitRejection.nameTooLong, results);
    await tester.enterText(find.byType(TextField), 'Read a chapter');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(
      find.text(HauntCopy.rejectionReason(HabitRejection.nameTooLong)),
      findsOneWidget,
    );
    expect(find.text('Read a chapter'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('closes with true when the name is accepted', (tester) async {
    final results = <bool>[];
    String? received;
    await open(tester, (name) {
      received = name;
      return null;
    }, results);
    await tester.enterText(find.byType(TextField), 'Stretch');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(received, 'Stretch');
    expect(results, [true]);
    expect(find.byType(HabitNameDialog), findsNothing);
  });

  testWidgets('cancel returns false without submitting', (tester) async {
    final results = <bool>[];
    var calls = 0;
    await open(tester, (_) {
      calls++;
      return null;
    }, results);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(calls, 0);
  });

  testWidgets('prefills the initial name and has 48x48 buttons with labels', (
    tester,
  ) async {
    await open(tester, (_) => null, <bool>[], initialName: 'Walk');
    expect(find.text('Walk'), findsOneWidget);

    for (final type in [TextButton, FilledButton]) {
      final size = tester.getSize(
        find.descendant(
          of: find.byType(HabitNameDialog),
          matching: find.byType(type),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.bySemanticsLabel('Cancel'), findsOneWidget);
    expect(find.bySemanticsLabel('Add'), findsOneWidget);
  });

  testWidgets('the name field capitalizes sentences', (tester) async {
    await open(tester, (_) => null, <bool>[]);
    expect(
      tester.widget<TextField>(find.byType(TextField)).textCapitalization,
      TextCapitalization.sentences,
    );
  });
}
