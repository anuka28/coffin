import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';
import 'package:graveyard/src/ui/living_row.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
import 'package:graveyard/src/ui/rest_dialog.dart';

import '../support/controller_harness.dart';
import '../support/fake_coffin_ai.dart';

final CalendarDate _died = CalendarDate(2023, 1, 3);
final CalendarDate _risen = CalendarDate(2026, 5, 1);

const String _name = 'Old Idea';

Grave _risenGrave() =>
    Grave.manual(id: 'a', name: _name, dateOfDeath: _died, risenOn: _risen);

Grave _plain() => Grave.manual(id: 'b', name: 'Other', dateOfDeath: _died);

final Finder _restControl = find.byKey(const ValueKey<String>('lay-to-rest-a'));
final Finder _confirm = find.byKey(const ValueKey<String>('rest-confirm'));
final Finder _cancel = find.byKey(const ValueKey<String>('rest-cancel'));
final Finder _tombstoneA = find.byWidgetPredicate(
  (Widget w) => w is GraveTombstone && w.grave.id == 'a',
);

ControllerHarness _harness() {
  final ControllerHarness h = ControllerHarness(
    seed: <String, String>{
      for (final Grave g in <Grave>[_risenGrave(), _plain()])
        g.id: ControllerHarness.envelopeOf(g),
    },
  );
  addTearDown(h.dispose);
  return h;
}

Future<void> _pump(
  WidgetTester tester,
  ControllerHarness h, {
  bool reduced = true,
}) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await h.controller.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: GraveyardScreen(
        controller: h.controller,
        seanceAi: FakeCoffinAI.replying('Boo.'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(_restControl);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 600));

bool _focusInDialog() {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  return focused?.findAncestorWidgetOfExactType<RestDialog>() != null;
}

Future<void> _expectUnchangedAndRisen(
  WidgetTester tester,
  ControllerHarness h,
) async {
  expect(find.byType(RestDialog), findsNothing);
  expect(
    h.controller.graves.firstWhere((Grave g) => g.id == 'a'),
    _risenGrave(),
  );
  expect(find.byType(LivingRow), findsOneWidget);
  expect(_tombstoneA, findsNothing);
  final List<Grave> stored = await h.repository.getAll();
  expect(stored.firstWhere((Grave g) => g.id == 'a').risenOn, _risen);
}

void main() {
  testWidgets('activating the control opens the dialog and changes nothing', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    final int before = h.notifications;
    await _openDialog(tester);

    expect(find.byType(RestDialog), findsOneWidget);
    expect(h.notifications, before);
    expect(
      h.controller.graves.firstWhere((Grave g) => g.id == 'a').risenOn,
      _risen,
    );
    expect(_tombstoneA, findsNothing);
    expect(find.text(GraveyardCopy.livingRowHeading), findsOneWidget);
  });

  testWidgets('the dialog names the grave and never says delete', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);

    final String body = GraveyardCopy.restDialogBody(_name);
    expect(find.text(GraveyardCopy.restDialogTitle(_name)), findsOneWidget);
    expect(find.text(body), findsOneWidget);
    expect(body, contains(_name));
    expect(body, contains('goes back to the graveyard'));
    expect(body.toLowerCase(), isNot(contains('delete')));
    expect(find.text(GraveyardCopy.restConfirmText), findsOneWidget);
    expect(find.text(GraveyardCopy.restCancelText), findsOneWidget);
    expect(GraveyardCopy.restConfirmText, 'Lay it to rest');
    expect(GraveyardCopy.restCancelText, 'Keep it risen');
  });

  testWidgets('the route is named "Lay <name> back to rest?"', (tester) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);

    final Route<dynamic>? route = ModalRoute.of(
      tester.element(find.byType(RestDialog)),
    );
    expect(route?.settings.name, 'Lay $_name back to rest?');
  });

  testWidgets('confirm lays the grave back among the graveyard rows', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h, reduced: false);
    expect(find.text('R.I.P.'), findsOneWidget);
    await _openDialog(tester);
    await tester.tap(_confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(RestDialog), findsNothing);
    final Grave a = h.controller.graves.firstWhere((Grave g) => g.id == 'a');
    expect(a.risenOn, isNull);
    expect(find.text(GraveyardCopy.livingRowHeading), findsNothing);
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(_tombstoneA, findsOneWidget);
    expect(find.text('R.I.P.'), findsNWidgets(2));
    expect(find.text('RISEN'), findsNothing);

    // The grave appeared after the first list, so it rises out of the ground.
    final GraveTombstone mid = tester.widget<GraveTombstone>(_tombstoneA);
    expect(mid.riseProgress, lessThan(1));
    expect(mid.playing, isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.widget<GraveTombstone>(_tombstoneA).riseProgress, 1);

    final List<Grave> stored = await h.repository.getAll();
    expect(stored.firstWhere((Grave g) => g.id == 'a').risenOn, isNull);
    expect(h.controller.saveStatus.name, 'saved');
  });

  testWidgets('cancel leaves the grave risen and unchanged', (tester) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    await tester.tap(_cancel);
    await _settle(tester);
    await _expectUnchangedAndRisen(tester, h);
  });

  testWidgets('Escape leaves the grave risen and unchanged', (tester) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    await _expectUnchangedAndRisen(tester, h);
  });

  testWidgets('a tap outside leaves the grave risen and unchanged', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    await tester.tapAt(const Offset(2, 2));
    await _settle(tester);
    await _expectUnchangedAndRisen(tester, h);
  });

  testWidgets('focus moves into the dialog and stays inside it', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    expect(_focusInDialog(), isTrue);
    for (int i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusInDialog(), isTrue, reason: 'after Tab $i');
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_focusInDialog(), isTrue);
  });

  testWidgets('focus returns to the control after cancel', (tester) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    await tester.tap(_cancel);
    await _settle(tester);

    final TextButton button = tester.widget<TextButton>(_restControl);
    expect(button.focusNode, isNotNull);
    expect(button.focusNode!.hasPrimaryFocus, isTrue);
    expect(_focusInDialog(), isFalse);
  });

  testWidgets('focus returns to the control after Escape', (tester) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);

    final TextButton button = tester.widget<TextButton>(_restControl);
    expect(button.focusNode!.hasPrimaryFocus, isTrue);
  });

  testWidgets('a grave deleted before the confirm closes the dialog quietly', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    await h.controller.deleteGrave('a');
    await tester.pump();
    await tester.tap(_confirm);
    await _settle(tester);

    expect(find.byType(RestDialog), findsNothing);
    expect(h.controller.graves.any((Grave g) => g.id == 'a'), isFalse);
    expect(find.byType(LivingRow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a grave deleted before cancel closes the dialog quietly', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    await h.controller.deleteGrave('a');
    await tester.pump();
    await tester.tap(_cancel);
    await _settle(tester);

    expect(find.byType(RestDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second dialog cannot open while one is open', (tester) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);
    final BuildContext context = tester.element(find.byType(RestDialog));

    expect(await showRestDialog(context, 'Other'), isFalse);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(RestDialog), findsOneWidget);
    expect(find.text(GraveyardCopy.restDialogTitle(_name)), findsOneWidget);
  });

  testWidgets('both buttons are at least 48 by 48 with a semantic label', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    await _openDialog(tester);

    for (final Finder button in <Finder>[_confirm, _cancel]) {
      final Size size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    for (final (Finder button, String label) in <(Finder, String)>[
      (_confirm, GraveyardCopy.restConfirmText),
      (_cancel, GraveyardCopy.restCancelText),
    ]) {
      expect(
        find.ancestor(
          of: button,
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is Semantics &&
                w.properties.label == label &&
                w.properties.button == true,
          ),
        ),
        findsOneWidget,
      );
    }
    handle.dispose();
  });
}
