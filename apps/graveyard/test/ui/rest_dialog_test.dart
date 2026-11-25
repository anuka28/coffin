import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/rest_dialog.dart';

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
                  _result = await showRestDialog(context, 'Old Idea'),
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
  testWidgets('names the grave, shows body and both buttons', (tester) async {
    await _open(tester);
    expect(
      find.text(GraveyardCopy.restDialogTitle('Old Idea')),
      findsOneWidget,
    );
    expect(find.text(GraveyardCopy.restDialogBody('Old Idea')), findsOneWidget);
    expect(find.text(GraveyardCopy.restConfirmText), findsOneWidget);
    expect(find.text(GraveyardCopy.restCancelText), findsOneWidget);
    expect(find.bySemanticsLabel('Lay Old Idea back to rest?'), findsWidgets);
  });

  testWidgets('confirm returns true', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('rest-confirm')));
    await tester.pumpAndSettle();
    expect(_result, isTrue);
    expect(find.byType(RestDialog), findsNothing);
  });

  testWidgets('cancel and Escape return false', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey<String>('rest-cancel')));
    await tester.pumpAndSettle();
    expect(_result, isFalse);
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_result, isFalse);
    expect(find.byType(RestDialog), findsNothing);
  });

  testWidgets('tap outside returns false', (tester) async {
    await _open(tester);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(_result, isFalse);
    expect(find.byType(RestDialog), findsNothing);
  });

  testWidgets('buttons are 48 by 48 and usable at text scale 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _open(tester);
    for (final String key in <String>['rest-cancel', 'rest-confirm']) {
      final Size size = tester.getSize(find.byKey(ValueKey<String>(key)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second dialog cannot open while one is open', (tester) async {
    await _open(tester);
    final BuildContext context = tester.element(find.byType(RestDialog));
    expect(await showRestDialog(context, 'Other'), isFalse);
    expect(find.byType(RestDialog), findsOneWidget);
  });
}
