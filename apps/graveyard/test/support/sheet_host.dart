import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/add_grave_sheet.dart';
import 'package:graveyard/src/ui/add_mode.dart';

import 'controller_harness.dart';

/// Key of the button in the test host that opens the add sheet.
const Key openSheetKey = ValueKey<String>('open-sheet');

/// Pumps a page with one button that opens the add sheet for [harness], with
/// the dark Coffin theme and a [width] by 900 screen.
Future<void> pumpSheetHost(
  WidgetTester tester,
  ControllerHarness harness, {
  AddMode initial = AddMode.buryByHand,
  double width = 400,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await harness.controller.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              key: openSheetKey,
              onPressed: () => showAddGraveSheet(
                context,
                harness.controller,
                initial: initial,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Taps the open button and waits for the sheet to settle.
Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(openSheetKey));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Checks that [finder] is at least 48 by 48 logical pixels.
void expectTapTarget(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final Size size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}
