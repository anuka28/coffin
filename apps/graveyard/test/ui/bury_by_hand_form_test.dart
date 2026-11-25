import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

import '../support/controller_harness.dart';
import '../support/sheet_host.dart';

const Key _name = ValueKey<String>('bury-name');
const Key _date = ValueKey<String>('bury-date');
const Key _submit = ValueKey<String>('bury-submit');

Future<void> _pickToday(WidgetTester tester) async {
  await tester.tap(find.byKey(_date));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(find.text('OK'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

ControllerHarness _harness() {
  final ControllerHarness harness = ControllerHarness();
  addTearDown(harness.dispose);
  return harness;
}

void main() {
  testWidgets('Enter submits: name and picked date bury a grave and close', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);

    await tester.enterText(find.byKey(_name), '  Old   Idea ');
    await _pickToday(tester);
    expect(find.text('10 May 2026'), findsOneWidget);

    await tester.tap(find.byKey(_name));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(harness.controller.graves.single.name, 'Old Idea');
    expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
  });

  testWidgets('empty name shows its reason under the field', (tester) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);
    await _pickToday(tester);

    await tester.tap(find.byKey(_submit));
    await tester.pump();

    expect(
      find.text(GraveyardCopy.rejection(GraveRejection.nameEmpty)),
      findsOneWidget,
    );
    expect(harness.controller.graves, isEmpty);
    expect(find.text(GraveyardCopy.sheetTitle), findsOneWidget);
  });

  testWidgets('missing date shows its reason and keeps the typed name', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);

    await tester.enterText(find.byKey(_name), 'Half Built');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(
      find.text(GraveyardCopy.rejection(GraveRejection.dateMissing)),
      findsOneWidget,
    );
    expect(find.text('Half Built'), findsOneWidget);
    expect(harness.controller.graves, isEmpty);
  });

  testWidgets('too long name shows the rule and keeps the text', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    final String longName = 'x' * 81;
    await pumpSheetHost(tester, harness);
    await openSheet(tester);

    await tester.enterText(find.byKey(_name), longName);
    await _pickToday(tester);
    await tester.tap(find.byKey(_submit));
    await tester.pump();

    expect(
      find.text(GraveyardCopy.rejection(GraveRejection.nameTooLong)),
      findsOneWidget,
    );
    expect(find.text(longName), findsOneWidget);
  });

  testWidgets('duplicate shows its reason and keeps the text', (tester) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);

    for (var i = 0; i < 2; i++) {
      await tester.enterText(find.byKey(_name), 'Twin');
      if (i == 0) await _pickToday(tester);
      await tester.tap(find.byKey(_submit));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      if (i == 0) {
        await tester.tap(find.byKey(openSheetKey));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await _pickToday(tester);
      }
    }

    expect(find.text(GraveyardCopy.duplicate), findsOneWidget);
    expect(find.text('Twin'), findsOneWidget);
    expect(harness.controller.graves, hasLength(1));
  });

  testWidgets('date picker offers Today as the last day', (tester) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);

    await tester.tap(find.byKey(_date));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final DatePickerDialog dialog = tester.widget(
      find.byType(DatePickerDialog),
    );
    expect(dialog.lastDate, DateTime(2026, 5, 10));
    expect(dialog.firstDate, DateTime(1970));
    expect(dialog.initialDate, DateTime(2026, 5, 10));
  });

  testWidgets('Escape closes without adding a grave', (tester) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);
    await tester.enterText(find.byKey(_name), 'Never Saved');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
    expect(harness.controller.graves, isEmpty);
  });

  testWidgets('fields and submit are at least 48 by 48', (tester) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);

    expectTapTarget(tester, find.byKey(_name));
    expectTapTarget(tester, find.byKey(_date));
    expectTapTarget(tester, find.byKey(_submit));
  });

  testWidgets('the name field capitalizes sentences', (tester) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);
    expect(
      tester.widget<TextField>(find.byKey(_name)).textCapitalization,
      TextCapitalization.sentences,
    );
  });
}
