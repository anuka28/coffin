import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/empty_graveyard_panel.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';
import 'package:graveyard/src/ui/living_row.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
import 'package:graveyard/src/ui/risen_announcement.dart';
import 'package:graveyard/src/ui/seance_control.dart';

import '../support/controller_harness.dart';
import '../support/fake_coffin_ai.dart';

final CalendarDate _died = CalendarDate(2023, 1, 3);
final CalendarDate _risen = CalendarDate(2026, 5, 1);

Grave _plain(String id) =>
    Grave.manual(id: id, name: 'n$id', dateOfDeath: _died);

Grave _alive(String id) =>
    Grave.manual(id: id, name: 'n$id', dateOfDeath: _died, risenOn: _risen);

ControllerHarness _harness(List<Grave> graves) {
  final ControllerHarness h = ControllerHarness(
    seed: <String, String>{
      for (final Grave g in graves) g.id: ControllerHarness.envelopeOf(g),
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

void main() {
  testWidgets('a saved risen grave shows in the Living_Row with no play', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_alive('a'), _plain('b')]);
    await _pump(tester, h);
    expect(find.byType(LivingRow), findsOneWidget);
    expect(find.text(GraveyardCopy.livingRowHeading), findsOneWidget);
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(find.text(GraveyardCopy.allRisen), findsNothing);
  });

  testWidgets('only risen graves: allRisen line, no empty panel', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_alive('a')]);
    await _pump(tester, h);
    expect(find.text(GraveyardCopy.allRisen), findsOneWidget);
    expect(find.byType(EmptyGraveyardPanel), findsNothing);
    expect(find.byType(LivingRow), findsOneWidget);
  });

  testWidgets('no graves: empty panel and no allRisen line', (tester) async {
    final ControllerHarness h = _harness(<Grave>[]);
    await _pump(tester, h);
    expect(find.byType(EmptyGraveyardPanel), findsOneWidget);
    expect(find.text(GraveyardCopy.allRisen), findsNothing);
    expect(find.byType(LivingRow), findsNothing);
  });

  testWidgets('lay to rest: cancel keeps it risen, confirm moves it back', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_alive('a'), _plain('b')]);
    await _pump(tester, h);
    final Finder rest = find.text(GraveyardCopy.layToRestText);

    await tester.tap(rest);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(GraveyardCopy.restCancelText));
    await tester.pump(const Duration(milliseconds: 600));
    expect(h.controller.graves.first.risenOn, _risen);
    expect(find.byType(LivingRow), findsOneWidget);

    await tester.tap(rest);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text(GraveyardCopy.restConfirmText));
    await tester.pump(const Duration(milliseconds: 600));
    expect(h.controller.graves.every((Grave g) => g.risenOn == null), isTrue);
    expect(find.text(GraveyardCopy.livingRowHeading), findsNothing);
    expect(find.byType(ResurrectionPlay), findsNothing);
  });

  testWidgets('raise: play starts, announces once, ends and joins the row', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_plain('a')]);
    await _pump(tester, h, reduced: false);
    expect(find.byType(RisenAnnouncement), findsOneWidget);

    await tester.tap(find.byType(SeanceControl));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tap(find.text(GraveyardCopy.raiseControlText));
    await tester.pump(const Duration(milliseconds: 600));

    expect(h.controller.graves.single.risenOn, isNotNull);
    expect(find.byType(ResurrectionPlay), findsOneWidget);
    expect(find.text(GraveyardCopy.livingRowHeading), findsNothing);
    expect(
      find.bySemanticsLabel(GraveyardCopy.risenAnnouncement('na')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(find.text(GraveyardCopy.livingRowHeading), findsOneWidget);
    expect(find.text(GraveyardCopy.allRisen), findsOneWidget);
  });
}
