import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/delete_grave_dialog.dart';

bool? _result;

Future<void> _open(WidgetTester tester) async {
  _result = null;
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey<String>('open'),
              onPressed: () async =>
                  _result = await showDeleteGraveDialog(context, 'Old Idea'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey<String>('open')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names the grave and focuses Keep it', (tester) async {
    await _open(tester);
    expect(find.text('Delete Old Idea?'), findsOneWidget);
    expect(find.text('Keep it'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    final TextButton keep = tester.widget(
      find.byKey(const ValueKey<String>('delete-keep')),
    );
    expect(keep.autofocus, isTrue);
    expect(find.bySemanticsLabel('Delete Old Idea?'), findsWidgets);
  });

  testWidgets('Delete confirms', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('delete-confirm')));
    await tester.pumpAndSettle();
    expect(_result, isTrue);
    expect(find.byType(DeleteGraveDialog), findsNothing);
  });

  testWidgets('Keep it returns false', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('delete-keep')));
    await tester.pumpAndSettle();
    expect(_result, isFalse);
  });

  testWidgets('Escape closes without confirming', (tester) async {
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_result, isFalse);
    expect(find.byType(DeleteGraveDialog), findsNothing);
  });

  testWidgets('buttons are at least 48 by 48', (tester) async {
    await _open(tester);
    for (final String key in <String>['delete-keep', 'delete-confirm']) {
      final Size size = tester.getSize(find.byKey(ValueKey<String>(key)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
