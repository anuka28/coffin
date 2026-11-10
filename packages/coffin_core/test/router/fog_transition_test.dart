import 'package:coffin_core/src/router/fog_math.dart';
import 'package:coffin_core/src/router/fog_transition.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AnimationController controller;

  setUp(() {
    controller = AnimationController(
      vsync: const TestVSync(),
      duration: FogMath.defaultDuration,
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpFog(WidgetTester tester, {bool reduced = false}) {
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: FogTransition(
            animation: controller,
            child: Semantics(
              label: 'fog page',
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );
  }

  double fade(WidgetTester tester) =>
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

  Finder translations() => find.descendant(
    of: find.byType(FogTransition),
    matching: find.byType(Transform),
  );

  double translationY(WidgetTester tester) {
    final finder = translations();
    if (finder.evaluate().isEmpty) return 0;
    return tester.widget<Transform>(finder).transform.getTranslation().y;
  }

  Finder blurs() => find.descendant(
    of: find.byType(FogTransition),
    matching: find.byType(ImageFiltered),
  );

  group('normal motion', () {
    testWidgets('progress 0 is invisible, low and blurred', (tester) async {
      controller.value = 0;
      await pumpFog(tester);

      expect(fade(tester), 0);
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition))
            .alwaysIncludeSemantics,
        isTrue,
      );
      expect(translationY(tester), closeTo(FogMath.defaultMaxDrift, 1e-9));
      expect(blurs(), findsOneWidget);
    });

    testWidgets('progress 0.5 sits between the extremes', (tester) async {
      controller.value = 0.5;
      await pumpFog(tester);

      expect(fade(tester), closeTo(0.5, 1e-9));
      expect(translationY(tester), inExclusiveRange(0, 16));
      expect(blurs(), findsOneWidget);
    });

    testWidgets('progress 1 is settled: opaque, no move, no blur', (
      tester,
    ) async {
      controller.value = 1;
      await pumpFog(tester);

      expect(fade(tester), 1);
      expect(translations(), findsNothing);
      expect(blurs(), findsNothing);
    });

    testWidgets('uses FadeTransition, not an Opacity widget', (tester) async {
      controller.value = 0.3;
      await pumpFog(tester);

      expect(find.byType(Opacity), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FogTransition),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
      // The fade is the outermost fog widget: nothing between it and the
      // transition except itself.
      final outermost = tester.element(find.byType(FogTransition));
      Element? first;
      outermost.visitChildren((e) => first = e);
      expect(first?.widget, isA<FadeTransition>());
    });

    testWidgets('forward run ends settled', (tester) async {
      await pumpFog(tester);
      controller.forward();
      await tester.pump();
      await tester.pump(FogMath.defaultDuration ~/ 2);

      expect(fade(tester), inExclusiveRange(0, 1));
      expect(translationY(tester), greaterThan(0));

      await tester.pump(FogMath.defaultDuration);
      expect(fade(tester), 1);
      expect(translations(), findsNothing);
      expect(blurs(), findsNothing);
    });

    testWidgets('reverse run goes back to invisible', (tester) async {
      controller.value = 1;
      await pumpFog(tester);
      controller.reverse();
      await tester.pump();
      await tester.pump(FogMath.defaultDuration ~/ 2);

      expect(fade(tester), inExclusiveRange(0, 1));
      expect(translationY(tester), greaterThan(0));

      await tester.pump(FogMath.defaultDuration);
      expect(fade(tester), 0);
    });
  });

  group('reduced motion', () {
    testWidgets('never translates or blurs, but still fades', (tester) async {
      controller.value = 0;
      await pumpFog(tester, reduced: true);

      for (final value in <double>[0, 0.25, 0.5, 0.75, 1]) {
        controller.value = value;
        await tester.pump();
        expect(translations(), findsNothing, reason: 'progress $value');
        expect(blurs(), findsNothing, reason: 'progress $value');
        expect(
          fade(tester),
          closeTo(Curves.easeInOut.transform(value), 1e-9),
          reason: 'progress $value',
        );
      }
    });

    testWidgets('changing the setting changes the next build', (tester) async {
      controller.value = 0.2;
      await pumpFog(tester);
      expect(translationY(tester), greaterThan(0));
      expect(blurs(), findsOneWidget);

      await pumpFog(tester, reduced: true);
      expect(translations(), findsNothing);
      expect(blurs(), findsNothing);

      await pumpFog(tester);
      expect(translationY(tester), greaterThan(0));
    });
  });

  group('semantics', () {
    testWidgets('page is reachable at progress 0 and adds no extra nodes', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      controller.value = 0;
      await pumpFog(tester);

      expect(find.bySemanticsLabel('fog page'), findsOneWidget);
      // The only Semantics widget under the transition is the test's own.
      expect(
        find.descendant(
          of: find.byType(FogTransition),
          matching: find.byType(Semantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  testWidgets('works without a MediaQuery above it', (tester) async {
    controller.value = 0.5;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: FogTransition(
          animation: controller,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );

    expect(translationY(tester), greaterThan(0));
  });
}
