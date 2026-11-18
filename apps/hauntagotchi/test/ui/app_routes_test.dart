import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/main.dart';
import 'package:hauntagotchi/src/ui/app_routes.dart';
import 'package:hauntagotchi/src/ui/home_screen.dart';

import '../support/memory_home_controller.dart';

void main() {
  // The home screen has looping effects. Reduced motion keeps them still so
  // pumpAndSettle can finish.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  Future<void> pumpAt(WidgetTester tester, String location) async {
    final GoRouter router = FogRouter.create(
      routes: buildAppRoutes(memoryHomeController()),
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: CoffinTheme.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the real app starts on the home route', (tester) async {
    await tester.pumpWidget(
      HauntagotchiApp(controller: memoryHomeController()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
  });

  testWidgets('opening / shows the home screen', (tester) async {
    await pumpAt(tester, '/');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
  });

  testWidgets('the app declares the home and gallery routes', (tester) async {
    final routes = buildAppRoutes(memoryHomeController());
    expect(routes, hasLength(2));
    expect(routes.map((r) => r.path).toList(), <String>['/', '/gallery']);
    expect(routes.map((r) => r.name).toList(), <String?>['home', 'gallery']);
  });

  testWidgets('an unknown location shows the not-found page', (tester) async {
    await pumpAt(tester, '/nowhere');

    expect(find.byType(NotFoundPage), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('the not-found button returns to the home screen', (
    tester,
  ) async {
    await pumpAt(tester, '/nowhere');

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NotFoundPage), findsNothing);
  });
}
