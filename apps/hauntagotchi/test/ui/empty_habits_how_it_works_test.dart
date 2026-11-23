import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/empty_habits_panel.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';

Widget _app({double width = 320, double scale = 1.0}) => MaterialApp(
  theme: CoffinTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 640),
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: SingleChildScrollView(child: EmptyHabitsPanel(onAdd: () {})),
    ),
  ),
);

void main() {
  test('copy is three short plain ASCII lines', () {
    expect(HauntCopy.howItWorksLines, hasLength(3));
    for (final text in [
      HauntCopy.howItWorksTitle,
      ...HauntCopy.howItWorksLines,
    ]) {
      expect(
        text.codeUnits.every((c) => c >= 32 && c < 127),
        isTrue,
        reason: text,
      );
      expect(text.toLowerCase(), isNot(contains('morning')));
      expect(text.toLowerCase(), isNot(contains('tonight')));
    }
  });

  testWidgets('shows the heading and the three lines as real text', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    expect(find.text(HauntCopy.howItWorksTitle), findsOneWidget);
    for (final line in HauntCopy.howItWorksLines) {
      expect(find.text(line), findsOneWidget);
    }
    expect(
      tester.getSemantics(find.text(HauntCopy.howItWorksTitle)),
      isSemantics(label: HauntCopy.howItWorksTitle, isHeader: true),
    );
    handle.dispose();
  });

  for (final scale in [1.0, 1.5]) {
    testWidgets('no overflow at 320 px, text scale $scale', (tester) async {
      await tester.pumpWidget(_app(scale: scale));
      expect(tester.takeException(), isNull);
    });
  }
}
