import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bone_shop/main.dart';
import 'package:bone_shop/src/ui/home_screen.dart';

void main() {
  // The ghost and the fog loop, so pumpAndSettle would never finish.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const BoneShopApp());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('shows the starter home screen', (tester) async {
    await pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(GhostLoader), findsOneWidget);
    expect(find.byType(TombstoneCard), findsOneWidget);
    expect(find.text('RISEN'), findsOneWidget);
  });

  testWidgets('applies the dark Coffin theme', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      CoffinColorTokens.night.background,
    );
  });

  testWidgets('still renders with animations disabled', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(const BoneShopApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TombstoneCard), findsOneWidget);
  });
}
