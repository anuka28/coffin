import 'package:coffin_core/src/router/fog_math.dart';
import 'package:coffin_core/src/router/fog_transition.dart';
import 'package:coffin_core/src/router/fog_transition_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const child = SizedBox();

  test('defaults to 600 ms forward and reverse', () {
    final page = FogTransitionPage<void>(child: child);
    expect(page.transitionDuration, const Duration(milliseconds: 600));
    expect(page.reverseTransitionDuration, const Duration(milliseconds: 600));
  });

  test('is a CustomTransitionPage', () {
    expect(
      FogTransitionPage<void>(child: child),
      isA<CustomTransitionPage<void>>(),
    );
  });

  test('clamps a short request up to 300 ms', () {
    final page = FogTransitionPage<void>(
      child: child,
      duration: const Duration(milliseconds: 100),
    );
    expect(page.transitionDuration, FogMath.minDuration);
    expect(page.reverseTransitionDuration, FogMath.minDuration);
  });

  test('clamps a long request down to 600 ms', () {
    final page = FogTransitionPage<void>(
      child: child,
      duration: const Duration(milliseconds: 900),
    );
    expect(page.transitionDuration, FogMath.maxDuration);
    expect(page.reverseTransitionDuration, FogMath.maxDuration);
  });

  test('keeps an in-range request', () {
    final page = FogTransitionPage<void>(
      child: child,
      duration: const Duration(milliseconds: 350),
    );
    expect(page.transitionDuration, const Duration(milliseconds: 350));
  });

  test('is instant under reduced motion, not raised to 300 ms', () {
    final page = FogTransitionPage<void>(
      child: child,
      duration: const Duration(milliseconds: 100),
      reducedMotion: true,
    );
    expect(page.transitionDuration, Duration.zero);
    expect(page.reverseTransitionDuration, Duration.zero);
  });

  test('passes key, name and child through', () {
    const key = ValueKey<String>('k');
    final page = FogTransitionPage<void>(
      key: key,
      name: 'graves',
      child: child,
    );
    expect(page.key, key);
    expect(page.name, 'graves');
    expect(page.child, same(child));
  });

  testWidgets('transitionsBuilder returns a FogTransition with the math', (
    tester,
  ) async {
    const math = FogMath(maxDrift: 4, maxBlur: 2);
    final page = FogTransitionPage<void>(child: child, math: math);
    const animation = AlwaysStoppedAnimation<double>(1);

    late Widget built;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          built = page.transitionsBuilder(
            context,
            animation,
            animation,
            page.child,
          );
          return const SizedBox();
        },
      ),
    );

    expect(built, isA<FogTransition>());
    final fog = built as FogTransition;
    expect(fog.math, math);
    expect(fog.child, same(child));
    expect(fog.animation, same(animation));
  });
}
