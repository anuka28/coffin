import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/main.dart';
import 'package:graveyard/src/ui/app_routes.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';

import '../support/controller_harness.dart';

void main() {
  Future<ControllerHarness> pumpAt(WidgetTester tester, String location) async {
    final ControllerHarness h = ControllerHarness();
    addTearDown(h.dispose);
    final GoRouter router = FogRouter.create(
      routes: buildAppRoutes(h.controller),
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: CoffinTheme.dark(), routerConfig: router),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return h;
  }

  testWidgets('the real app loads the graves and shows the home route', (
    tester,
  ) async {
    final ControllerHarness h = ControllerHarness();
    addTearDown(h.dispose);
    await tester.pumpWidget(GraveyardApp(controller: h.controller));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GraveyardScreen), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
    expect(h.controller.status.name, 'ready');
  });

  testWidgets('the home route is the only declared route', (tester) async {
    final ControllerHarness h = ControllerHarness();
    addTearDown(h.dispose);
    final List<AppRoute> routes = buildAppRoutes(h.controller);
    expect(routes, hasLength(1));
    expect(routes.single.path, '/');
    expect(routes.single.name, 'home');
  });

  testWidgets('an unknown location shows the not-found page', (tester) async {
    await pumpAt(tester, '/nowhere');
    expect(find.byType(NotFoundPage), findsOneWidget);
    expect(find.byType(GraveyardScreen), findsNothing);
  });

  testWidgets('the not-found button returns to the graveyard', (tester) async {
    await pumpAt(tester, '/nowhere');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GraveyardScreen), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
  });
}
