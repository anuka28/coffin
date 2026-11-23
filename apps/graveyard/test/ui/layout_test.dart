// Feature: graveyard-core, layout, accessibility and reduced motion.
// Validates: Requirements 14.1 to 14.12, 17.9
import 'dart:async';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';

import '../support/controller_harness.dart';
import '../support/throwing_record_repository.dart';

const Key _fab = ValueKey<String>('screen-add');
const Key _importField = ValueKey<String>('import-field');
const Key _importSubmit = ValueKey<String>('import-submit');

final String _longName = 'Wordy ' * 13;
final String _unbroken = 'W' * 79;

Grave _manual(String id, String name, CalendarDate died) =>
    Grave.manual(id: id, name: name, dateOfDeath: died);

Grave _github(String id, CalendarDate died) => Grave.github(
  id: id,
  name: 'octocat/Hello-World',
  dateOfDeath: died,
  repo: RepoInfo(
    fullName: 'octocat/Hello-World',
    description: 'A very long description. ' * 40,
    archived: true,
    stars: 4037,
  ),
);

Map<String, String> _seed(List<Grave> graves) => <String, String>{
  for (final Grave g in graves) g.id: ControllerHarness.envelopeOf(g),
};

Map<String, String> get _fullSeed => _seed(<Grave>[
  _manual('g1', _longName, CalendarDate(2020, 1, 1)),
  _github('g2', CalendarDate(2026, 4, 1)),
  _manual('g3', 'Fresh one', CalendarDate(2026, 5, 10)),
  _manual('g4', _unbroken, CalendarDate(2019, 1, 1)),
]);

ControllerHarness _harness({
  Map<String, String> seed = const <String, String>{},
  RecordRepository<Grave>? repository,
  Future<OpenedRepository<Grave>> Function()? openStorage,
}) {
  final ControllerHarness h = ControllerHarness(
    seed: seed,
    repository: repository,
    openStorage: openStorage,
  );
  addTearDown(h.dispose);
  return h;
}

Future<void> _pump(
  WidgetTester tester,
  ControllerHarness h, {
  double width = 360,
  double textScale = 1,
  bool disableAnimations = true,
  bool load = true,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (load) await h.controller.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: GraveyardScreen(controller: h.controller),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void _expectTapTarget(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final Size size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(48), reason: '$finder width');
  expect(size.height, greaterThanOrEqualTo(48), reason: '$finder height');
}

/// Resolves the overlay colour a button paints in [state].
Color? _overlay(WidgetTester tester, Finder finder, Set<WidgetState> state) {
  final ButtonStyleButton button = tester.widget<ButtonStyleButton>(finder);
  final BuildContext context = tester.element(finder);
  // The default style of a button is protected API, and it is the only place
  // where the hover and press colours of the theme can be read.
  // ignore: invalid_use_of_protected_member
  final ButtonStyle defaults = button.defaultStyleOf(context);
  // ignore: invalid_use_of_protected_member
  final ButtonStyle? themed = button.themeStyleOf(context);
  final ButtonStyle style = defaults.merge(themed).merge(button.style);
  return style.overlayColor?.resolve(state);
}

void _expectHoverAndPress(WidgetTester tester, Finder finder) {
  final Color? hover = _overlay(tester, finder, <WidgetState>{
    WidgetState.hovered,
  });
  final Color? press = _overlay(tester, finder, <WidgetState>{
    WidgetState.pressed,
  });
  expect(hover, isNotNull, reason: '$finder hover');
  expect(hover!.a, greaterThan(0), reason: '$finder hover is visible');
  expect(press, isNotNull, reason: '$finder press');
  expect(press!.a, greaterThan(0), reason: '$finder press is visible');
}

void main() {
  group('no overflow', () {
    for (final double width in <double>[320, 360]) {
      for (final double scale in <double>[1.0, 1.5]) {
        final String at = '$width px, scale $scale';

        testWidgets('list at $at', (tester) async {
          final ControllerHarness h = _harness(seed: _fullSeed);
          await _pump(tester, h, width: width, textScale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text('Fresh one'), findsOneWidget);
        });

        testWidgets('empty at $at', (tester) async {
          final ControllerHarness h = _harness();
          await _pump(tester, h, width: width, textScale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text(GraveyardCopy.emptyTitle), findsOneWidget);
        });

        testWidgets('loading at $at', (tester) async {
          final Completer<OpenedRepository<Grave>> gate =
              Completer<OpenedRepository<Grave>>();
          final ControllerHarness h = _harness(openStorage: () => gate.future);
          unawaited(h.controller.load());
          await _pump(tester, h, width: width, textScale: scale, load: false);
          expect(tester.takeException(), isNull);
          expect(find.byType(GhostLoader), findsOneWidget);
          gate.complete(
            OpenedRepository<Grave>(
              repository: h.repository,
              isPersistent: true,
            ),
          );
          await tester.pumpAndSettle();
        });

        testWidgets('error at $at', (tester) async {
          final ControllerHarness h = _harness(
            repository: ThrowingRecordRepository(failOnGetAll: true),
          );
          await _pump(tester, h, width: width, textScale: scale);
          expect(tester.takeException(), isNull);
          expect(find.text(GraveyardCopy.loadError), findsOneWidget);
        });

        testWidgets('add sheet with a failure message at $at', (tester) async {
          final ControllerHarness h = _harness();
          h.github.defaultResult = const FetchFailed(
            ImportFailure(ImportFailureKind.rateLimited),
          );
          await _pump(tester, h, width: width, textScale: scale);
          await tester.tap(find.byKey(const ValueKey<String>('empty-import')));
          await _settleSheet(tester);
          await tester.enterText(
            find.byKey(_importField),
            'octocat/Hello-World',
          );
          await tester.ensureVisible(find.byKey(_importSubmit));
          await tester.tap(find.byKey(_importSubmit));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey<String>('import-failure')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('tap targets and labels', () {
    testWidgets('screen controls are at least 48 by 48 and labelled', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ControllerHarness h = _harness(seed: _fullSeed);
      await _pump(tester, h, width: 320);
      _expectTapTarget(tester, find.byKey(_fab));
      expect(find.bySemanticsLabel(GraveyardCopy.addButton), findsWidgets);
      final Finder deletes = find.byType(TextButton);
      expect(deletes, findsAtLeast(2));
      for (final Element e in deletes.evaluate()) {
        final Finder one = find.byElementPredicate((Element x) => x == e);
        _expectTapTarget(tester, one);
      }
      expect(
        find.bySemanticsLabel(GraveyardCopy.deleteLabel('Fresh one')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('empty and error controls are 48 by 48 and labelled', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ControllerHarness empty = _harness();
      await _pump(tester, empty, width: 320);
      for (final String key in <String>['empty-bury', 'empty-import']) {
        final Finder f = find.byKey(ValueKey<String>(key));
        _expectTapTarget(tester, f);
        expect(tester.getSemantics(f).label, isNotEmpty);
      }
      handle.dispose();

      final SemanticsHandle handle2 = tester.ensureSemantics();
      final ControllerHarness broken = _harness(
        repository: ThrowingRecordRepository(failOnGetAll: true),
      );
      await _pump(tester, broken, width: 320);
      final Finder retry = find.byKey(const ValueKey<String>('load-retry'));
      _expectTapTarget(tester, retry);
      expect(tester.getSemantics(retry).label, isNotEmpty);
      handle2.dispose();
    });

    testWidgets('the add sheet controls are 48 by 48 and labelled', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ControllerHarness h = _harness();
      await _pump(tester, h, width: 320);
      await tester.tap(find.byKey(const ValueKey<String>('empty-bury')));
      await _settleSheet(tester);

      _expectTapTarget(
        tester,
        find.byKey(const ValueKey<String>('sheet-close')),
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey<String>('sheet-close')))
            .tooltip,
        GraveyardCopy.closeSheet,
      );
      _expectTapTarget(
        tester,
        find.byKey(const ValueKey<String>('bury-submit')),
      );
      expect(find.bySemanticsLabel(GraveyardCopy.buryButton), findsWidgets);
      for (final String text in <String>[
        GraveyardCopy.buryByHand,
        GraveyardCopy.importFromGitHub,
      ]) {
        final Finder segment = find.ancestor(
          of: find.descendant(
            of: find.byKey(const ValueKey<String>('sheet-mode')),
            matching: find.text(text),
          ),
          matching: find.byType(InkWell),
        );
        final Size size = tester.getSize(segment.first);
        expect(size.height, greaterThanOrEqualTo(48), reason: text);
        expect(size.width, greaterThanOrEqualTo(48), reason: text);
        expect(find.bySemanticsLabel(text), findsWidgets);
      }
      // Text fields expose their label.
      expect(find.bySemanticsLabel(GraveyardCopy.nameLabel), findsWidgets);
      expect(find.bySemanticsLabel(GraveyardCopy.dateLabel), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('sheet-mode')),
          matching: find.text(GraveyardCopy.importFromGitHub),
        ),
      );
      await tester.pump();
      _expectTapTarget(tester, find.byKey(_importSubmit));
      expect(tester.getSemantics(find.byKey(_importSubmit)).label, isNotEmpty);
      expect(find.bySemanticsLabel(GraveyardCopy.repoLabel), findsWidgets);
      handle.dispose();
    });

    testWidgets('retry button after a failure is 48 by 48', (tester) async {
      final ControllerHarness h = _harness();
      await _pump(tester, h, width: 320);
      await tester.tap(find.byKey(const ValueKey<String>('empty-import')));
      await _settleSheet(tester);
      await tester.enterText(find.byKey(_importField), 'octocat/Hello-World');
      await tester.ensureVisible(find.byKey(_importSubmit));
      await tester.tap(find.byKey(_importSubmit));
      await tester.pumpAndSettle();
      _expectTapTarget(
        tester,
        find.byKey(const ValueKey<String>('import-retry')),
      );
    });

    testWidgets('the delete dialog buttons are 48 by 48 and labelled', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ControllerHarness h = _harness(
        seed: _seed(<Grave>[_manual('g1', 'Doomed', CalendarDate(2020, 1, 1))]),
      );
      await _pump(tester, h);
      await tester.tap(find.text(GraveyardCopy.delete));
      await tester.pumpAndSettle();
      for (final String key in <String>['delete-keep', 'delete-confirm']) {
        final Finder f = find.byKey(ValueKey<String>(key));
        _expectTapTarget(tester, f);
        expect(tester.getSemantics(f).label, isNotEmpty);
      }
      expect(
        find.bySemanticsLabel(GraveyardCopy.deleteTitle('Doomed')),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('epitaph and text scale', () {
    testWidgets('shown at scale 1.0 and 1.2, hidden above 1.2', (tester) async {
      final ControllerHarness h = _harness(
        seed: _seed(<Grave>[
          _manual('g3', 'Fresh one', CalendarDate(2026, 5, 10)),
        ]),
      );
      final Finder epitaph = find.text(GraveyardCopy.epitaph('Died today'));
      await _pump(tester, h);
      expect(epitaph, findsOneWidget);
      await _pump(tester, h, textScale: 1.2);
      expect(epitaph, findsOneWidget);
      await _pump(tester, h, textScale: 1.25);
      expect(epitaph, findsNothing);
      await _pump(tester, h, textScale: 1.5);
      expect(epitaph, findsNothing);
      expect(find.text('Fresh one'), findsOneWidget);
    });
  });

  group('keyboard and focus', () {
    testWidgets('Enter submits the by-hand form and Escape leaves the list', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      await _pump(tester, h);
      await tester.tap(find.byKey(const ValueKey<String>('empty-bury')));
      await _settleSheet(tester);

      // Escape closes the sheet and changes nothing.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settleSheet(tester);
      expect(find.byKey(const ValueKey<String>('bury-name')), findsNothing);
      expect(h.controller.graves, isEmpty);

      // Enter on a field with a missing date submits and shows the reason.
      await tester.tap(find.byKey(const ValueKey<String>('empty-bury')));
      await _settleSheet(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('bury-name')),
        'Doomed',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text(GraveyardCopy.rejection(GraveRejection.dateMissing)),
        findsOneWidget,
      );
      expect(h.controller.graves, isEmpty);
    });

    testWidgets('Enter submits the import form', (tester) async {
      final ControllerHarness h = _harness();
      await _pump(tester, h);
      await tester.tap(find.byKey(const ValueKey<String>('empty-import')));
      await _settleSheet(tester);
      await tester.enterText(find.byKey(_importField), 'octocat/Hello-World');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(h.github.calls, hasLength(1));
    });

    testWidgets('Escape closes the delete dialog and keeps the list', (
      tester,
    ) async {
      final ControllerHarness h = _harness(
        seed: _seed(<Grave>[_manual('g1', 'Doomed', CalendarDate(2020, 1, 1))]),
      );
      await _pump(tester, h);
      await tester.tap(find.text(GraveyardCopy.delete));
      await tester.pumpAndSettle();
      expect(find.text(GraveyardCopy.deleteTitle('Doomed')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(GraveyardCopy.deleteTitle('Doomed')), findsNothing);
      expect(h.controller.graves, hasLength(1));
      expect(find.text('Doomed'), findsOneWidget);
    });

    testWidgets('focus enters the dialog and returns to the delete button', (
      tester,
    ) async {
      final ControllerHarness h = _harness(
        seed: _seed(<Grave>[_manual('g1', 'Doomed', CalendarDate(2020, 1, 1))]),
      );
      await _pump(tester, h);
      final Finder deleteButton = find.byType(TextButton);
      // Focus the delete button the way a keyboard user would.
      Focus.of(
        tester.element(
          find.descendant(of: deleteButton, matching: find.byType(Icon)),
        ),
      ).requestFocus();
      await tester.pump();
      final FocusNode? before = FocusManager.instance.primaryFocus;
      expect(before, isNotNull);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      final Element keep = tester.element(find.text(GraveyardCopy.keepIt));
      expect(Focus.of(keep).hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(GraveyardCopy.deleteTitle('Doomed')), findsNothing);
      final FocusNode? after = FocusManager.instance.primaryFocus;
      expect(after, same(before));
    });
  });

  group('hover and press states', () {
    testWidgets('buttons paint a hover and a press overlay', (tester) async {
      final ControllerHarness h = _harness(
        seed: _seed(<Grave>[_manual('g1', 'Doomed', CalendarDate(2020, 1, 1))]),
      );
      await _pump(tester, h);
      _expectHoverAndPress(tester, find.byType(TextButton));

      await tester.tap(find.byKey(_fab));
      await _settleSheet(tester);
      _expectHoverAndPress(
        tester,
        find.byKey(const ValueKey<String>('bury-submit')),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('sheet-mode')),
          matching: find.text(GraveyardCopy.importFromGitHub),
        ),
      );
      await tester.pump();
      _expectHoverAndPress(tester, find.byKey(_importSubmit));
    });

    testWidgets('the floating button reacts to a mouse and a press', (
      tester,
    ) async {
      final ControllerHarness h = _harness();
      await _pump(tester, h);
      final FloatingActionButton fab = tester.widget<FloatingActionButton>(
        find.byKey(_fab),
      );
      expect(fab.onPressed, isNotNull);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(_fab)));
      await tester.pump();
      final InkWell ink = tester.widget<InkWell>(
        find.descendant(of: find.byKey(_fab), matching: find.byType(InkWell)),
      );
      expect(ink.onTap, isNotNull);

      final TestGesture press = await tester.startGesture(
        tester.getCenter(find.byKey(_fab)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await press.cancel();
    });
  });

  group('reduced motion', () {
    testWidgets('disableAnimations draws the still ghost and ticks nothing', (
      tester,
    ) async {
      final Completer<OpenedRepository<Grave>> gate =
          Completer<OpenedRepository<Grave>>();
      final ControllerHarness h = _harness(openStorage: () => gate.future);
      unawaited(h.controller.load());
      await _pump(tester, h, load: false);
      expect(find.byType(GhostLoader), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      // pumpAndSettle in _pump already returned, so no loop keeps scheduling
      // frames. The ghost stays at the same place after time passes.
      final Offset before = tester.getTopLeft(find.byType(GhostLoader));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.getTopLeft(find.byType(GhostLoader)), before);
      expect(tester.binding.transientCallbackCount, 0);
      gate.complete(
        OpenedRepository<Grave>(repository: h.repository, isPersistent: true),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('without reduced motion the ghost loops', (tester) async {
      final Completer<OpenedRepository<Grave>> gate =
          Completer<OpenedRepository<Grave>>();
      final ControllerHarness h = _harness(openStorage: () => gate.future);
      unawaited(h.controller.load());
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: CoffinTheme.dark(),
          home: GraveyardScreen(controller: h.controller),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      gate.complete(
        OpenedRepository<Grave>(repository: h.repository, isPersistent: true),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('themes', () {
    testWidgets('the screen renders in the daylight theme without overflow', (
      tester,
    ) async {
      final ControllerHarness h = _harness(seed: _fullSeed);
      await _pump(
        tester,
        h,
        width: 320,
        textScale: 1.5,
        theme: CoffinTheme.light(),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
