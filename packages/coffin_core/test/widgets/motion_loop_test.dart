import 'package:coffin_core/src/widgets/motion_loop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

class _LoopProbe extends StatefulWidget {
  const _LoopProbe();

  @override
  State<_LoopProbe> createState() => _LoopProbeState();
}

class _LoopProbeState extends State<_LoopProbe>
    with SingleTickerProviderStateMixin, MotionLoop {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

_LoopProbeState _state(WidgetTester tester) =>
    tester.state<_LoopProbeState>(find.byType(_LoopProbe));

void main() {
  // pumpSpooky itself leaves no transient callbacks: MaterialApp only
  // animates a theme change, so with a constant theme the counts below come
  // from the probe's controller alone.

  testWidgets('ticks under normal motion', (tester) async {
    await pumpSpooky(tester, const _LoopProbe());
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));
    expect(_state(tester).loopController.isAnimating, isTrue);
    expect(_state(tester).elapsedMs, greaterThan(0));
  });

  testWidgets('is stopped under reduced motion', (tester) async {
    await pumpSpooky(tester, const _LoopProbe(), reducedMotion: true);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.binding.transientCallbackCount, 0);
    expect(_state(tester).reducedMotion, isTrue);
    expect(_state(tester).elapsedMs, 0);
  });

  testWidgets('stops and restarts when disableAnimations toggles', (
    tester,
  ) async {
    await pumpSpooky(tester, const _LoopProbe());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));

    await pumpSpooky(tester, const _LoopProbe(), reducedMotion: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, 0);

    await pumpSpooky(tester, const _LoopProbe());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));
  });

  testWidgets('leaves no transient callbacks after removal', (tester) async {
    await pumpSpooky(tester, const _LoopProbe());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThanOrEqualTo(1));

    await pumpSpooky(tester, const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.transientCallbackCount, 0);
  });
}
