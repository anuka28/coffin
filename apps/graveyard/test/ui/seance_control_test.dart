import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/seance_control.dart';

void main() {
  final grave = Grave.manual(
    id: 'g1',
    name: 'Ghost',
    dateOfDeath: CalendarDate(2024, 1, 1),
  );

  Future<void> pumpControl(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SeanceControl(grave: grave, onPressed: () {}),
        ),
      ),
    ),
  );

  testWidgets('shows the visible text and is at least 48x48', (tester) async {
    await pumpControl(tester);
    expect(find.text(GraveyardCopy.seanceControlText), findsOneWidget);
    final size = tester.getSize(find.byType(TextButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('exposes one labelled button node', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpControl(tester);
    expect(
      find.bySemanticsLabel(GraveyardCopy.seanceControlLabel('Ghost')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('activates on tap, Enter and Space', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SeanceControl(grave: grave, onPressed: () => taps++),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 3);
  });
}
