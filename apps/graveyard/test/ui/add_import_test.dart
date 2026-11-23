import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_parse_problem.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/ui/add_mode.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';

import '../support/controller_harness.dart';
import '../support/fake_github_client.dart';
import '../support/fixed_offset_zone.dart';
import '../support/sheet_host.dart';

const Key _name = ValueKey<String>('bury-name');
const Key _date = ValueKey<String>('bury-date');
const Key _bury = ValueKey<String>('bury-submit');
const Key _field = ValueKey<String>('import-field');
const Key _dig = ValueKey<String>('import-submit');
const Key _retry = ValueKey<String>('import-retry');
const Key _failure = ValueKey<String>('import-failure');

final CalendarDate _today = CalendarDate(2026, 5, 10);
const RepoRef _ref = RepoRef('octocat', 'Hello-World');
const String _typed = 'octocat/Hello-World';

FetchResult _found() => FakeGitHubClient.parsed(
  _ref,
  pushedAt: '2024-01-03T10:00:00Z',
  today: _today,
  offset: const FixedOffsetZone(Duration(hours: 2)).offset,
);

ControllerHarness _harness() {
  final ControllerHarness harness = ControllerHarness();
  addTearDown(harness.dispose);
  return harness;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openImport(WidgetTester tester, ControllerHarness h) async {
  await pumpSheetHost(tester, h, initial: AddMode.importFromGitHub);
  await openSheet(tester);
}

Future<void> _typeAndEnter(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(_field), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _pickToday(WidgetTester tester) async {
  await tester.tap(find.byKey(_date));
  await _settle(tester);
  await tester.tap(find.text('OK'));
  await _settle(tester);
}

bool _isLiveRegion(Widget w) =>
    w is Semantics && w.properties.liveRegion == true;

void main() {
  group('add by hand', () {
    testWidgets('a name and a date add a tombstone to the screen', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: CoffinTheme.dark(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: GraveyardScreen(controller: h.controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(_name), 'Old Idea');
      await _pickToday(tester);
      await tester.tap(find.byKey(_bury));
      await tester.pumpAndSettle();

      expect(h.controller.graves.single.name, 'Old Idea');
      expect(find.byKey(const ValueKey<String>('sheet-mode')), findsNothing);
      expect(find.text('Old Idea'), findsWidgets);
      expect(find.text(GraveyardCopy.emptyTitle), findsNothing);
    });

    testWidgets('an empty name shows its reason under the field', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      await pumpSheetHost(tester, h);
      await openSheet(tester);
      await _pickToday(tester);

      await tester.tap(find.byKey(_bury));
      await tester.pump();

      final Finder reason = find.text(
        GraveyardCopy.rejection(GraveRejection.nameEmpty),
      );
      expect(reason, findsOneWidget);
      expect(
        find.descendant(of: find.byKey(_name), matching: reason),
        findsOneWidget,
      );
      expect(find.text('10 May 2026'), findsOneWidget);
      expect(h.controller.graves, isEmpty);
    });

    testWidgets('a name over 80 characters is rejected and kept', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      final String longName = 'x' * 81;
      await pumpSheetHost(tester, h);
      await openSheet(tester);

      await tester.enterText(find.byKey(_name), longName);
      await _pickToday(tester);
      await tester.tap(find.byKey(_bury));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(_name),
          matching: find.text(
            GraveyardCopy.rejection(GraveRejection.nameTooLong),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(longName), findsOneWidget);
      expect(h.controller.graves, isEmpty);
      expect(find.text(GraveyardCopy.sheetTitle), findsOneWidget);
    });

    testWidgets('a missing date is rejected under the date field, name kept', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      await pumpSheetHost(tester, h);
      await openSheet(tester);

      await tester.enterText(find.byKey(_name), 'Half Built');
      await tester.tap(find.byKey(_bury));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(_date),
          matching: find.text(
            GraveyardCopy.rejection(GraveRejection.dateMissing),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Half Built'), findsOneWidget);
      expect(h.controller.graves, isEmpty);
    });

    testWidgets('the date picker runs from 1 Jan 1970 to Today', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      await pumpSheetHost(tester, h);
      await openSheet(tester);

      await tester.tap(find.byKey(_date));
      await _settle(tester);

      final DatePickerDialog dialog = tester.widget(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, DateTime(1970));
      expect(dialog.lastDate, DateTime(2026, 5, 10));
    });
  });

  group('import', () {
    testWidgets('a found repository is added from the fake client', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      h.github.enqueue(_found());
      await _openImport(tester, h);

      await _typeAndEnter(tester, _typed);
      await _settle(tester);

      expect(h.github.calls.single.ref, _ref);
      expect(h.github.calls.single.today, _today);
      expect(h.controller.graves.single.name, _typed);
      expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
    });

    testWidgets('a parse problem shows under the field and starts no request', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      await _openImport(tester, h);

      await _typeAndEnter(tester, 'nope');

      expect(
        find.descendant(
          of: find.byKey(_field),
          matching: find.text(
            GraveyardCopy.parseProblem(RepoParseProblem.needOwnerRepo),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('nope'), findsOneWidget);
      expect(h.github.calls, isEmpty);
      expect(h.controller.graves, isEmpty);
    });

    for (final ImportFailureKind kind in ImportFailureKind.values) {
      testWidgets('failure $kind: message, text kept, Try again, by hand', (
        tester,
      ) async {
        final ControllerHarness h = _harness();
        final ImportFailure failure = ImportFailure(
          kind,
          resetAt: kind == ImportFailureKind.rateLimited
              ? h.clock.now().add(const Duration(minutes: 5))
              : null,
        );
        h.github
          ..enqueue(FetchFailed(failure))
          ..enqueue(_found());
        await _openImport(tester, h);

        await _typeAndEnter(tester, _typed);
        await tester.pump();

        final String message = GraveyardCopy.importFailure(
          failure,
          now: h.clock.now(),
        );
        expect(find.text(message), findsOneWidget);
        expect(message, isNot(contains('Exception')));
        expect(find.text(_typed), findsOneWidget);
        expect(find.text(GraveyardCopy.tryAgain), findsOneWidget);
        expect(h.controller.graves, isEmpty);

        // The by-hand option still works.
        await tester.tap(find.text(GraveyardCopy.buryByHand));
        await tester.pump();
        expect(find.byKey(_name), findsOneWidget);
        await tester.tap(find.text(GraveyardCopy.importFromGitHub));
        await tester.pump();

        // Back in the import option, a new submit works.
        await _typeAndEnter(tester, _typed);
        await _settle(tester);
        expect(h.controller.graves, hasLength(1));
      });
    }

    testWidgets('the failure message sits in a live region', (tester) async {
      final ControllerHarness h = _harness();
      await _openImport(tester, h);

      await _typeAndEnter(tester, _typed);
      await tester.pump();

      expect(
        find.ancestor(
          of: find.byKey(_failure),
          matching: find.byWidgetPredicate(_isLiveRegion),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Try again repeats the request and keeps the typed text', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      h.github
        ..enqueue(const FetchFailed(ImportFailure(ImportFailureKind.timeout)))
        ..enqueue(_found());
      await _openImport(tester, h);

      await _typeAndEnter(tester, _typed);
      await tester.pump();
      expect(find.text(_typed), findsOneWidget);

      await tester.tap(find.byKey(_retry));
      await _settle(tester);

      expect(h.github.calls, hasLength(2));
      expect(h.controller.graves, hasLength(1));
    });

    testWidgets('double submit: disabled button and one request', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      final held = h.github.enqueueHeld();
      await _openImport(tester, h);

      await _typeAndEnter(tester, _typed);

      expect(tester.widget<FilledButton>(find.byKey(_dig)).onPressed, isNull);
      expect(find.byType(GhostLoader), findsOneWidget);
      await tester.tap(find.byKey(_dig), warnIfMissed: false);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(h.github.calls, hasLength(1));

      held.complete(_found());
      await _settle(tester);
      expect(h.github.calls, hasLength(1));
      expect(h.controller.graves, hasLength(1));
    });

    testWidgets('closing the sheet during an import adds nothing', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      final held = h.github.enqueueHeld();
      await _openImport(tester, h);
      await _typeAndEnter(tester, _typed);

      await tester.tap(find.byKey(const ValueKey<String>('sheet-close')));
      await _settle(tester);
      expect(find.text(GraveyardCopy.sheetTitle), findsNothing);

      held.complete(_found());
      await _settle(tester);

      expect(h.controller.graves, isEmpty);
      expect(h.github.calls, hasLength(1));
    });

    testWidgets('a duplicate shows its message and keeps the text', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      h.github
        ..enqueue(_found())
        ..enqueue(_found());
      await _openImport(tester, h);
      await _typeAndEnter(tester, _typed);
      await _settle(tester);
      expect(h.controller.graves, hasLength(1));

      await tester.tap(find.byKey(openSheetKey));
      await _settle(tester);
      await tester.tap(find.text(GraveyardCopy.importFromGitHub));
      await tester.pump();
      await _typeAndEnter(tester, _typed);
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(_field),
          matching: find.text(GraveyardCopy.duplicate),
        ),
        findsOneWidget,
      );
      expect(find.text(_typed), findsOneWidget);
      expect(h.controller.graves, hasLength(1));
    });

    testWidgets('Escape closes the sheet during no import, adding nothing', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      await _openImport(tester, h);
      await tester.enterText(find.byKey(_field), _typed);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);

      expect(find.text(GraveyardCopy.sheetTitle), findsNothing);
      expect(h.github.calls, isEmpty);
    });
  });
}
