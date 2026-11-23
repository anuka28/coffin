import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/ui/add_mode.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/import_state.dart';

import '../support/controller_harness.dart';
import '../support/fake_github_client.dart';
import '../support/fixed_offset_zone.dart';
import '../support/sheet_host.dart';

final CalendarDate _today = CalendarDate(2026, 5, 10);
const RepoRef _ref = RepoRef('octocat', 'Hello-World');

ControllerHarness _harness() {
  final ControllerHarness harness = ControllerHarness();
  addTearDown(harness.dispose);
  return harness;
}

void main() {
  testWidgets('opens on the chosen option and switches between the two', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness, initial: AddMode.importFromGitHub);
    await openSheet(tester);

    expect(find.text(GraveyardCopy.sheetTitle), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('import-field')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('bury-name')), findsNothing);

    await tester.tap(find.text(GraveyardCopy.buryByHand));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('bury-name')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('import-field')), findsNothing);
  });

  testWidgets('Escape closes the sheet and changes no grave', (tester) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);
    expect(find.text(GraveyardCopy.sheetTitle), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
    expect(harness.controller.graves, isEmpty);
  });

  testWidgets('the close button closes the sheet', (tester) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey<String>('sheet-close')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
  });

  testWidgets('closing during an import cancels it and drops the result', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    final held = harness.github.enqueueHeld();
    await pumpSheetHost(tester, harness, initial: AddMode.importFromGitHub);
    await openSheet(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('import-field')),
      'octocat/Hello-World',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.controller.importState, isA<ImportRunning>());

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(harness.controller.importState, isA<ImportIdle>());

    held.complete(
      FakeGitHubClient.parsed(
        _ref,
        pushedAt: '2024-01-03T10:00:00Z',
        today: _today,
        offset: FixedOffsetZone(Duration.zero).offset,
      ),
    );
    await tester.pump();

    expect(harness.controller.graves, isEmpty);
    expect(harness.controller.importState, isA<ImportIdle>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching away from import cancels a running import', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    harness.github.enqueueHeld();
    await pumpSheetHost(tester, harness, initial: AddMode.importFromGitHub);
    await openSheet(tester);

    await tester.enterText(
      find.byKey(const ValueKey<String>('import-field')),
      'octocat/Hello-World',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.controller.importState, isA<ImportRunning>());

    await tester.tap(find.text(GraveyardCopy.buryByHand));
    await tester.pump();

    expect(harness.controller.importState, isA<ImportIdle>());
    expect(find.byKey(const ValueKey<String>('bury-name')), findsOneWidget);
  });

  testWidgets('close button and mode selector are at least 48 by 48', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness);
    await openSheet(tester);

    expectTapTarget(tester, find.byKey(const ValueKey<String>('sheet-close')));
    for (final String label in <String>[
      GraveyardCopy.buryByHand,
      GraveyardCopy.importFromGitHub,
    ]) {
      final Finder segment = find.ancestor(
        of: find.text(label),
        matching: find.byType(TextButton),
      );
      expectTapTarget(tester, segment);
    }
  });

  testWidgets('fits 320 wide at text scale 1.5 without overflow', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    await pumpSheetHost(tester, harness, width: 320, textScale: 1.5);
    await openSheet(tester);

    expect(find.text(GraveyardCopy.sheetTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
