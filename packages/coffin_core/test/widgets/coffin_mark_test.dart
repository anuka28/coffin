import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CoffinMark renders one icon and the Coffin label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CoffinMark())),
    );

    expect(find.byType(CoffinMark), findsOneWidget);
    expect(find.byType(Icon), findsOneWidget);
    expect(find.text('Coffin'), findsOneWidget);
  });
}
