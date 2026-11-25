import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';

Widget _host({required bool show, required VoidCallback onEnd}) {
  return MaterialApp(
    home: Center(
      child: show
          ? ResurrectionPlay(
              graveId: 'g1',
              stoneSize: const Size(160, 200),
              textScale: 1,
              onEnd: onEnd,
              onEpitaphRisen: () {},
            )
          : const SizedBox(),
    ),
  );
}

void main() {
  for (final int ms in <int>[0, 300, 700, 2300]) {
    testWidgets('disposing at $ms ms throws nothing and never ends', (
      tester,
    ) async {
      var ends = 0;
      await tester.pumpWidget(_host(show: true, onEnd: () => ends++));
      await tester.pump();
      if (ms > 0) await tester.pump(Duration(milliseconds: ms));
      await tester.pumpWidget(_host(show: false, onEnd: () => ends++));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(ends, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
