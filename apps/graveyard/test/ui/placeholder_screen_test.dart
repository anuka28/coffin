import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/main.dart';
import 'package:graveyard/src/ui/placeholder_screen.dart';

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(theme: CoffinTheme.dark(), home: const PlaceholderScreen()),
);

String? _familyOf(WidgetTester tester, String text) {
  final Finder finder = find.text(text);
  final BuildContext context = tester.element(finder);
  final Text widget = tester.widget<Text>(finder);
  return DefaultTextStyle.of(context).style.merge(widget.style).fontFamily;
}

void main() {
  testWidgets('PlaceholderScreen shows the CoffinMark', (tester) async {
    await _pump(tester);

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(find.byType(CoffinMark), findsOneWidget);
    expect(find.text('Coffin'), findsOneWidget);
  });

  testWidgets('uses night background and Coffin fonts', (tester) async {
    await _pump(tester);

    final Scaffold scaffold = tester.widget(find.byType(Scaffold));
    expect(
      scaffold.backgroundColor ??
          Theme.of(tester.element(find.byType(Scaffold)))
              .scaffoldBackgroundColor,
      CoffinColorTokens.night.background,
    );
    expect(_familyOf(tester, 'Graveyard'), CoffinTypography.displayFamilyName);
    expect(
      _familyOf(tester, 'This project has been dead for 214 days'),
      CoffinTypography.bodyFamilyName,
    );
  });

  testWidgets('wraps the mark in a glowing decoration', (tester) async {
    await _pump(tester);

    final Iterable<DecoratedBox> glowing = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final Decoration d = box.decoration;
          return d is BoxDecoration && (d.boxShadow?.isNotEmpty ?? false);
        });
    expect(glowing, isNotEmpty);
  });

  testWidgets('GraveyardApp applies CoffinTheme.dark()', (tester) async {
    await tester.pumpWidget(const GraveyardApp());

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    final ThemeData expected = CoffinTheme.dark();
    expect(app.theme?.colorScheme, expected.colorScheme);
    expect(app.theme?.textTheme, expected.textTheme);
  });
}
