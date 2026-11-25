import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/seance_control.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/fake_coffin_ai.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);
final CalendarDate _died = CalendarDate(2023, 1, 3);

Widget _app({
  required Grave grave,
  required List<Grave> raised,
  bool playing = false,
}) => MaterialApp(
  theme: CoffinTheme.dark(),
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Scaffold(
      body: SingleChildScrollView(
        child: GraveTombstone(
          grave: grave,
          today: _today,
          onDelete: () {},
          seanceAi: FakeCoffinAI.replying('Boo.'),
          playing: playing,
          onRaise: raised.add,
        ),
      ),
    ),
  ),
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(SeanceControl));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  final Finder raise = find.text(GraveyardCopy.raiseControlText);

  testWidgets('not risen and not playing: the sheet raises through onRaise', (
    tester,
  ) async {
    final Grave grave = Grave.manual(id: 'm', name: 'moth', dateOfDeath: _died);
    final List<Grave> raised = <Grave>[];
    await tester.pumpWidget(_app(grave: grave, raised: raised));
    await _openSheet(tester);
    expect(raise, findsOneWidget);
    await tester.tap(raise);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SeanceSheet), findsNothing);
    expect(raised, <Grave>[grave]);
  });

  testWidgets('playing: the sheet has no Raise control', (tester) async {
    final Grave grave = Grave.manual(id: 'm', name: 'moth', dateOfDeath: _died);
    await tester.pumpWidget(
      _app(grave: grave, raised: <Grave>[], playing: true),
    );
    await tester.pump();
    await _openSheet(tester);
    expect(find.byType(SeanceSheet), findsOneWidget);
    expect(raise, findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('risen: the sheet has no Raise control', (tester) async {
    final Grave grave = Grave.manual(
      id: 'm',
      name: 'moth',
      dateOfDeath: _died,
      risenOn: _today,
    );
    await tester.pumpWidget(_app(grave: grave, raised: <Grave>[]));
    await _openSheet(tester);
    expect(find.byType(SeanceSheet), findsOneWidget);
    expect(raise, findsNothing);
  });
}
