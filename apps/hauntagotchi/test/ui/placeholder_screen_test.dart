import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/main.dart';
import 'package:hauntagotchi/src/ui/placeholder_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(theme: CoffinTheme.dark(), home: const PlaceholderScreen()),
    );
  }

  testWidgets('PlaceholderScreen shows the CoffinMark', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(find.byType(CoffinMark), findsOneWidget);
    expect(find.text('Coffin'), findsOneWidget);
  });

  testWidgets('scaffold uses the night background', (tester) async {
    await pumpScreen(tester);

    final context = tester.element(find.byType(Scaffold));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      CoffinColorTokens.night.background,
    );
  });

  testWidgets('title uses display font and body uses body font', (
    tester,
  ) async {
    await pumpScreen(tester);

    final title = tester.widget<Text>(find.text('Hauntagotchi'));
    final body = tester.widget<Text>(
      find.text('Your ghost is getting hungry…'),
    );

    expect(title.style?.fontFamily, CoffinTypography.displayFamilyName);
    expect(body.style?.fontFamily, CoffinTypography.bodyFamilyName);
  });

  testWidgets('the mark sits in a glowing DecoratedBox', (tester) async {
    await pumpScreen(tester);

    final glowing = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              (decoration.boxShadow?.isNotEmpty ?? false);
        });
    expect(glowing, isNotEmpty);
  });

  testWidgets('HauntagotchiApp applies the dark Coffin theme', (tester) async {
    await tester.pumpWidget(const HauntagotchiApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final expected = CoffinTheme.dark();
    expect(app.theme?.colorScheme, expected.colorScheme);
    expect(app.theme?.textTheme, expected.textTheme);
    expect(find.byType(PlaceholderScreen), findsOneWidget);
  });
}
