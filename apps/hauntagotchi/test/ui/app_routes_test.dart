import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/main.dart';
import 'package:hauntagotchi/src/ui/app_routes.dart';
import 'package:hauntagotchi/src/ui/placeholder_screen.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, String location) async {
    final GoRouter router = FogRouter.create(
      routes: appRoutes,
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: CoffinTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the real app starts on the home route', (tester) async {
    await tester.pumpWidget(const HauntagotchiApp());
    await tester.pumpAndSettle();

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
  });

  testWidgets('the home route is the only declared route', (tester) async {
    expect(appRoutes, hasLength(1));
    expect(appRoutes.single.path, '/');
    expect(appRoutes.single.name, 'home');
  });

  testWidgets('an unknown location shows the not-found page', (tester) async {
    await pumpAt(tester, '/nowhere');

    expect(find.byType(NotFoundPage), findsOneWidget);
    expect(find.byType(PlaceholderScreen), findsNothing);
  });

  testWidgets('the not-found button returns to the placeholder', (
    tester,
  ) async {
    await pumpAt(tester, '/nowhere');

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
  });
}
