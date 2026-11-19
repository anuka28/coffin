import 'package:coffin_core/src/widgets/motion_loop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.initialWanted, this.useOverride = true});

  final bool initialWanted;
  final bool useOverride;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe>
    with SingleTickerProviderStateMixin<_Probe>, MotionLoop<_Probe> {
  late bool wanted = widget.initialWanted;

  @override
  bool get loopWanted => widget.useOverride ? wanted : super.loopWanted;

  void setWanted(bool value) {
    setState(() => wanted = value);
    syncLoop();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('loopWanted false at build runs no ticker', (tester) async {
    await pumpSpooky(tester, const _Probe(initialWanted: false));
    await tester.pump(const Duration(seconds: 1));
    final state = tester.state<_ProbeState>(find.byType(_Probe));
    expect(tester.binding.transientCallbackCount, 0);
    expect(state.loopController.isAnimating, isFalse);
  });

  testWidgets('flipping loopWanted and syncing starts and stops the loop', (
    tester,
  ) async {
    await pumpSpooky(tester, const _Probe(initialWanted: false));
    final state = tester.state<_ProbeState>(find.byType(_Probe));

    state.setWanted(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.loopController.isAnimating, isTrue);
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    state.setWanted(false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.loopController.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion never ticks whatever loopWanted is', (
    tester,
  ) async {
    await pumpSpooky(
      tester,
      const _Probe(initialWanted: true),
      reducedMotion: true,
    );
    final state = tester.state<_ProbeState>(find.byType(_Probe));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 0);

    state.setWanted(false);
    state.setWanted(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.loopController.isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a probe without the override still ticks', (tester) async {
    await pumpSpooky(
      tester,
      const _Probe(initialWanted: false, useOverride: false),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final state = tester.state<_ProbeState>(find.byType(_Probe));
    expect(state.loopController.isAnimating, isTrue);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });
}
