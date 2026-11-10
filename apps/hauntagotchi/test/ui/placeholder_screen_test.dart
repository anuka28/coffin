import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/ui/placeholder_screen.dart';

void main() {
  testWidgets('PlaceholderScreen shows the CoffinMark', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlaceholderScreen()));

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(find.byType(CoffinMark), findsOneWidget);
    expect(find.text('Coffin'), findsOneWidget);
  });
}
