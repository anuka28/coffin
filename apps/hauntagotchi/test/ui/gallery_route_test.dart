import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/main.dart';
import 'package:hauntagotchi/src/ui/app_routes.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';

import '../support/memory_home_controller.dart';

void main() {
  // The gallery has looping widgets, so these tests never use pumpAndSettle.
  // The end of each test swaps in an empty widget so no ticker is left.
  Future<void> advance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> endTest(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 700));
  }

  late GoRouter router;

  Future<void> pumpAt(WidgetTester tester, String location) async {
    router = FogRouter.create(
      routes: buildAppRoutes(memoryHomeController()),
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: CoffinTheme.dark(), routerConfig: router),
    );
    await advance(tester);
  }

  testWidgets('opening /gallery shows the crypt gallery', (tester) async {
    await pumpAt(tester, '/gallery');

    expect(find.byType(CryptGallery), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);

    await endTest(tester);
  });

  testWidgets('"Back to the crypt" returns to the home screen', (tester) async {
    await pumpAt(tester, '/gallery');

    final Finder button = find.text('Back to the crypt');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await advance(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CryptGallery), findsNothing);

    await endTest(tester);
  });

  testWidgets('the app started on /gallery shows it inside the fog page', (
    tester,
  ) async {
    tester.platformDispatcher.defaultRouteNameTestValue = '/gallery';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(
      HauntagotchiApp(controller: memoryHomeController()),
    );
    await advance(tester);

    expect(find.byType(CryptGallery), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
    expect(
      find.ancestor(
        of: find.byType(CryptGallery),
        matching: find.byType(FogTransition),
      ),
      findsOneWidget,
    );

    await endTest(tester);
  });
}
