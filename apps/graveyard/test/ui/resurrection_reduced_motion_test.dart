import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/clods_painter.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';
import 'package:graveyard/src/ui/hand_painter.dart';
import 'package:graveyard/src/ui/living_row.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
import 'package:graveyard/src/ui/seance_control.dart';

import '../support/controller_harness.dart';
import '../support/fake_coffin_ai.dart';

const String _name = 'Moon';

Grave _grave() =>
    Grave.manual(id: 'a', name: _name, dateOfDeath: CalendarDate(2023, 1, 3));

Widget _app(ControllerHarness h, {required bool reduced}) => MaterialApp(
  theme: CoffinTheme.dark(),
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: GraveyardScreen(
    controller: h.controller,
    seanceAi: FakeCoffinAI.replying('Boo.'),
  ),
);

Future<ControllerHarness> _start(
  WidgetTester tester, {
  required bool reduced,
}) async {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Grave g = _grave();
  final ControllerHarness h = ControllerHarness(
    seed: <String, String>{g.id: ControllerHarness.envelopeOf(g)},
  );
  addTearDown(h.dispose);
  await h.controller.load();
  await tester.pumpWidget(_app(h, reduced: reduced));
  await tester.pump(const Duration(milliseconds: 700));
  return h;
}

/// Opens the séance and taps Raise; the play starts with the last pump here.
Future<void> _raise(WidgetTester tester) async {
  await tester.tap(find.byType(SeanceControl));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
  await tester.tap(find.text(GraveyardCopy.raiseControlText));
  await tester.pump();
}

Future<void> _ms(WidgetTester tester, int ms) =>
    tester.pump(Duration(milliseconds: ms));

Finder get _announcement =>
    find.bySemanticsLabel(GraveyardCopy.risenAnnouncement(_name));

bool _hasPlayPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .any((c) => c.painter is HandPainter || c.painter is ClodsPainter);

void main() {
  group('with reduced motion', () {
    testWidgets('RISEN at once on a still stone, then the move at 2800 ms', (
      tester,
    ) async {
      await _start(tester, reduced: true);
      await _raise(tester);
      await _ms(tester, 600);

      expect(find.text(GraveyardCopy.epitaphRisen), findsOneWidget);
      expect(find.text(GraveyardCopy.epitaph), findsNothing);
      expect(find.byType(ResurrectionPlay), findsOneWidget);
      expect(_hasPlayPainter(tester), isFalse);
      expect(find.byType(GraveTombstone), findsOneWidget);
      expect(find.byType(LivingRow), findsNothing);

      await _ms(tester, 2000);
      expect(find.byType(GraveTombstone), findsOneWidget);
      expect(find.byType(LivingRow), findsNothing);

      await _ms(tester, 400);
      expect(find.byType(GraveTombstone), findsNothing);
      expect(find.byType(LivingRow), findsOneWidget);
    });

    // Requirement 12.1 and the design ("no ticking controller", a plain
    // Timer): fails today because ResurrectionPlay waits with an
    // AnimationController, which keeps a ticker running for 2800 ms.
    testWidgets('no animation is running after the play has started', (
      tester,
    ) async {
      await _start(tester, reduced: true);
      await _raise(tester);
      // Let the sheet finish closing; only the play could still tick.
      await _ms(tester, 600);
      expect(find.byType(ResurrectionPlay), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await _ms(tester, 3000);
    });

    testWidgets('announces once, keeps focus, no repeat on rebuild or move', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ControllerHarness h = await _start(tester, reduced: true);
      await _raise(tester);
      await _ms(tester, 600);
      final FocusNode? focusBefore = FocusManager.instance.primaryFocus;

      expect(_announcement, findsOneWidget);
      final int id = tester.getSemantics(_announcement).id;

      await tester.pumpWidget(_app(h, reduced: true));
      await _ms(tester, 100);
      expect(_announcement, findsOneWidget);
      expect(tester.getSemantics(_announcement).id, id);

      await _ms(tester, 3000);
      expect(find.byType(LivingRow), findsOneWidget);
      expect(_announcement, findsOneWidget);
      expect(tester.getSemantics(_announcement).id, id);
      expect(FocusManager.instance.primaryFocus, focusBefore);
      handle.dispose();
    });
  });

  group('with motion', () {
    testWidgets('announces exactly once and keeps focus', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ControllerHarness h = await _start(tester, reduced: false);
      await _raise(tester);
      await _ms(tester, 600);
      final FocusNode? focusBefore = FocusManager.instance.primaryFocus;

      expect(_announcement, findsOneWidget);
      final int id = tester.getSemantics(_announcement).id;
      expect(find.byType(ResurrectionPlay), findsOneWidget);

      await tester.pumpWidget(_app(h, reduced: false));
      await _ms(tester, 100);
      expect(_announcement, findsOneWidget);
      expect(tester.getSemantics(_announcement).id, id);

      await _ms(tester, 3500);
      expect(find.byType(LivingRow), findsOneWidget);
      expect(_announcement, findsOneWidget);
      expect(tester.getSemantics(_announcement).id, id);
      expect(FocusManager.instance.primaryFocus, focusBefore);
      handle.dispose();
    });
  });

  testWidgets('switching to reduced motion mid-play stops it, once', (
    tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final ControllerHarness h = await _start(tester, reduced: false);
    await _raise(tester);
    await _ms(tester, 600);
    await _ms(tester, 400);
    expect(find.text(GraveyardCopy.epitaphRisen), findsNothing);
    expect(_announcement, findsOneWidget);
    final int id = tester.getSemantics(_announcement).id;

    await tester.pumpWidget(_app(h, reduced: true));
    await _ms(tester, 50);

    expect(find.text(GraveyardCopy.epitaphRisen), findsOneWidget);
    expect(_hasPlayPainter(tester), isFalse);
    expect(_announcement, findsOneWidget);
    expect(tester.getSemantics(_announcement).id, id);
    // About 1100 ms of the 2800 ms have passed.
    await _ms(tester, 1500);
    expect(find.byType(GraveTombstone), findsOneWidget);
    expect(find.byType(LivingRow), findsNothing);

    await _ms(tester, 400);
    expect(find.byType(GraveTombstone), findsNothing);
    expect(find.byType(LivingRow), findsOneWidget);
    expect(_announcement, findsOneWidget);
    expect(tester.getSemantics(_announcement).id, id);
    handle.dispose();
  });
}
