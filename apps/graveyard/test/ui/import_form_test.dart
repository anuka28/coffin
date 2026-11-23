import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_parse_problem.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/ui/add_mode.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

import '../support/controller_harness.dart';
import '../support/fake_github_client.dart';
import '../support/fixed_offset_zone.dart';
import '../support/sheet_host.dart';

const Key _field = ValueKey<String>('import-field');
const Key _submit = ValueKey<String>('import-submit');
const Key _retry = ValueKey<String>('import-retry');
const Key _failure = ValueKey<String>('import-failure');

final CalendarDate _today = CalendarDate(2026, 5, 10);
const RepoRef _ref = RepoRef('octocat', 'Hello-World');

FetchResult _found({String pushedAt = '2024-01-03T10:00:00Z'}) =>
    FakeGitHubClient.parsed(
      _ref,
      pushedAt: pushedAt,
      today: _today,
      offset: const FixedOffsetZone(Duration(hours: 2)).offset,
    );

Future<void> _open(WidgetTester tester, ControllerHarness harness) async {
  await pumpSheetHost(tester, harness, initial: AddMode.importFromGitHub);
  await openSheet(tester);
}

Future<void> _typeAndEnter(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(_field), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

FilledButton _submitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(_submit));

ControllerHarness _harness() {
  final ControllerHarness harness = ControllerHarness();
  addTearDown(harness.dispose);
  return harness;
}

void main() {
  testWidgets('Enter submits: a found repository is buried and sheet closes', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    harness.github.enqueue(_found());
    await _open(tester, harness);

    await _typeAndEnter(tester, 'octocat/Hello-World');
    await tester.pump(const Duration(seconds: 1));

    expect(harness.github.calls.single.ref, _ref);
    expect(harness.controller.graves.single.name, 'octocat/Hello-World');
    expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
  });

  testWidgets('a rejected text shows its reason under the field, text kept', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    await _open(tester, harness);

    await _typeAndEnter(tester, 'nope');

    expect(
      find.text(GraveyardCopy.parseProblem(RepoParseProblem.needOwnerRepo)),
      findsOneWidget,
    );
    expect(find.text('nope'), findsOneWidget);
    expect(harness.github.calls, isEmpty);
    expect(find.text(GraveyardCopy.sheetTitle), findsOneWidget);
  });

  testWidgets('a duplicate shows its message under the field, text kept', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    harness.github
      ..enqueue(_found())
      ..enqueue(_found());
    await _open(tester, harness);
    await _typeAndEnter(tester, 'octocat/Hello-World');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(openSheetKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await _typeAndEnter(tester, 'octocat/Hello-World');
    await tester.pump();

    expect(find.text(GraveyardCopy.duplicate), findsOneWidget);
    expect(find.text('octocat/Hello-World'), findsOneWidget);
    expect(harness.controller.graves, hasLength(1));
  });

  testWidgets('running: GhostLoader shows, submit is disabled, field is not', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    final held = harness.github.enqueueHeld();
    await _open(tester, harness);

    await _typeAndEnter(tester, 'octocat/Hello-World');

    expect(find.byType(GhostLoader), findsOneWidget);
    expect(find.text(GraveyardCopy.importingCaption), findsWidgets);
    expect(_submitButton(tester).onPressed, isNull);
    expect(tester.widget<TextField>(find.byKey(_field)).enabled, isNot(false));
    expect(
      tester.widget<IconButton>(find.byKey(const ValueKey('sheet-close'))),
      isNotNull,
    );

    // A second Enter starts no second request.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.github.calls, hasLength(1));

    held.complete(_found());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GhostLoader), findsNothing);
    expect(harness.controller.graves, hasLength(1));
  });

  testWidgets('failure: live region message, text kept, Try again works', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    harness.github
      ..enqueue(const FetchFailed(ImportFailure(ImportFailureKind.offline)))
      ..enqueue(_found());
    await _open(tester, harness);

    await _typeAndEnter(tester, 'octocat/Hello-World');
    await tester.pump();

    final String message = GraveyardCopy.importFailure(
      const ImportFailure(ImportFailureKind.offline),
      now: harness.clock.now(),
    );
    expect(find.text(message), findsOneWidget);
    final Finder live = find.ancestor(
      of: find.byKey(_failure),
      matching: find.byWidgetPredicate(
        (Widget w) => w is Semantics && w.properties.liveRegion == true,
      ),
    );
    expect(live, findsOneWidget);
    expect(find.text('octocat/Hello-World'), findsOneWidget);
    expect(find.text(GraveyardCopy.tryAgain), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);
    expect(harness.controller.graves, isEmpty);

    await tester.tap(find.byKey(_retry));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(harness.github.calls, hasLength(2));
    expect(harness.controller.graves, hasLength(1));
    expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
  });

  testWidgets('failure leaves the mode selector and close button usable', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    await _open(tester, harness);
    await _typeAndEnter(tester, 'octocat/Hello-World');
    await tester.pump();
    expect(find.byKey(_failure), findsOneWidget);

    await tester.tap(find.text(GraveyardCopy.buryByHand));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('bury-name')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('sheet-close')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
  });

  testWidgets('Escape closes the sheet without adding a grave', (tester) async {
    final ControllerHarness harness = _harness();
    await _open(tester, harness);
    await tester.enterText(find.byKey(_field), 'octocat/Hello-World');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
    expect(harness.controller.graves, isEmpty);
  });

  testWidgets('field, submit and Try again are at least 48 by 48', (
    tester,
  ) async {
    final ControllerHarness harness = _harness();
    await _open(tester, harness);
    expectTapTarget(tester, find.byKey(_field));
    expectTapTarget(tester, find.byKey(_submit));

    await _typeAndEnter(tester, 'octocat/Hello-World');
    await tester.pump();
    expectTapTarget(tester, find.byKey(_retry));
  });
}
