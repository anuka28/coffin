import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_reaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

Widget _loader(GhostMood mood, {int? key, VoidCallback? onEnd}) => Center(
  child: key == null
      ? GhostLoader(mood: mood, onReactionEnd: onEnd)
      : GhostLoader(mood: mood, reactionKey: key, onReactionEnd: onEnd),
);

MoodPose _pose(WidgetTester tester) {
  final GhostPainter painter =
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(GhostLoader),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as GhostPainter;
  return painter.pose!;
}

Future<ValueNotifier<Widget>> _start(
  WidgetTester tester,
  Widget first, {
  bool reducedMotion = false,
}) async {
  final ValueNotifier<Widget> host = ValueNotifier<Widget>(first);
  addTearDown(host.dispose);
  await pumpSpooky(
    tester,
    ValueListenableBuilder<Widget>(
      valueListenable: host,
      builder: (BuildContext context, Widget value, Widget? child) => value,
    ),
    reducedMotion: reducedMotion,
  );
  return host;
}

Future<void> _show(
  WidgetTester tester,
  ValueNotifier<Widget> host,
  Widget next,
) async {
  host.value = next;
  await tester.pump();
}

Future<void> _ms(WidgetTester tester, int ms) =>
    tester.pump(Duration(milliseconds: ms));

List<double> _numbers(MoodPose p) => <double>[
  p.opacity,
  p.lean,
  p.droop,
  p.scale,
  p.lift,
  p.bobAmplitude,
  ...p.weights,
];

void main() {
  group('run length', () {
    for (final (GhostMood mood, int ms) in <(GhostMood, int)>[
      (GhostMood.fed, 900),
      (GhostMood.rising, 2200),
    ]) {
      testWidgets('${mood.name} ends once at $ms ms, not before', (
        tester,
      ) async {
        int calls = 0;
        final ValueNotifier<Widget> host = await _start(
          tester,
          _loader(mood, onEnd: () => calls++),
        );
        await tester.pump();
        await _ms(tester, ms - 1);
        expect(calls, 0);
        await _ms(tester, 1);
        expect(calls, 1);
        // Rebuilds with the same mood and key never call again.
        await _show(tester, host, _loader(mood, onEnd: () => calls++));
        await _ms(tester, 500);
        await _show(tester, host, _loader(mood, key: 0, onEnd: () => calls++));
        await _ms(tester, 3000);
        expect(calls, 1);
        // Held pose is the rest pose; only the bob loop ticks.
        expect(_pose(tester), MoodPose.rest(mood));
        expect(tester.binding.transientCallbackCount, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no call after a change away from a running reaction', (
      tester,
    ) async {
      int calls = 0;
      final ValueNotifier<Widget> host = await _start(
        tester,
        _loader(GhostMood.fed, onEnd: () => calls++),
      );
      await tester.pump();
      await _ms(tester, 400);
      await _show(
        tester,
        host,
        _loader(GhostMood.content, onEnd: () => calls++),
      );
      await _ms(tester, 3000);
      expect(calls, 0);
    });

    testWidgets('a change to a reaction mood starts a run whatever the key', (
      tester,
    ) async {
      int calls = 0;
      final ValueNotifier<Widget> host = await _start(
        tester,
        _loader(GhostMood.content, key: 5, onEnd: () => calls++),
      );
      await tester.pump();
      await _ms(tester, 300);
      await _show(
        tester,
        host,
        _loader(GhostMood.fed, key: 5, onEnd: () => calls++),
      );
      await _ms(tester, 899);
      expect(calls, 0);
      await _ms(tester, 1);
      expect(calls, 1);
    });

    testWidgets('reactionKey defaults to 0', (tester) async {
      expect(const GhostLoader().reactionKey, 0);
      int calls = 0;
      final ValueNotifier<Widget> host = await _start(
        tester,
        _loader(GhostMood.fed, onEnd: () => calls++),
      );
      await tester.pump();
      await _ms(tester, 400);
      await _show(
        tester,
        host,
        _loader(GhostMood.fed, key: 0, onEnd: () => calls++),
      );
      await _ms(tester, 500);
      expect(calls, 1);
    });
  });

  group('key changes', () {
    testWidgets('restart blends over 200 ms with no jump or speed spike', (
      tester,
    ) async {
      int calls = 0;
      final ValueNotifier<Widget> host = await _start(
        tester,
        _loader(GhostMood.fed, key: 0, onEnd: () => calls++),
      );
      await tester.pump();
      await _ms(tester, 450);
      final MoodPose before = _pose(tester);
      expect(before.scale, greaterThan(1.05));

      await _show(
        tester,
        host,
        _loader(GhostMood.fed, key: 1, onEnd: () => calls++),
      );
      expect(_pose(tester), before);

      final List<List<double>> frames = <List<double>>[_numbers(_pose(tester))];
      for (int i = 0; i < 12; i++) {
        await _ms(tester, 16);
        frames.add(_numbers(_pose(tester)));
      }
      await _ms(tester, 8);
      // Nominal travel of the blend: from the interrupted pose to the pose the
      // new run starts at (progress 0), spread over the blend duration.
      final MoodPose runStart = MoodPose.rest(GhostMood.fed).copyWith(
        scale: MoodReaction.scaleAt(GhostMood.fed, 0),
        lift: MoodReaction.liftAt(GhostMood.fed, 0),
        opacity: MoodReaction.opacityAt(GhostMood.fed, 0),
      );
      final List<double> end = _numbers(runStart);
      final List<double> start = frames.first;
      expect(MoodBlend.restartMs, 200);
      for (int n = 0; n < start.length; n++) {
        final double avgPerFrame = (end[n] - start[n]).abs() / 200 * 16;
        for (int f = 1; f < frames.length; f++) {
          final double step = (frames[f][n] - frames[f - 1][n]).abs();
          expect(
            step,
            lessThanOrEqualTo(1.5 * avgPerFrame + 1e-9),
            reason: 'number $n frame $f',
          );
        }
      }

      // Interrupted run ends at 900 ms after the first start: no call.
      await _ms(tester, 450);
      expect(calls, 0);
      // New run started at 450 and ends at 1350.
      await _ms(tester, 249);
      expect(calls, 0);
      await _ms(tester, 1);
      expect(calls, 1);
      await _ms(tester, 2000);
      expect(calls, 1);
    });

    testWidgets('a changed key on a steady mood starts nothing', (
      tester,
    ) async {
      int calls = 0;
      final ValueNotifier<Widget> host = await _start(
        tester,
        _loader(GhostMood.hungry, key: 0, onEnd: () => calls++),
      );
      await tester.pump();
      await _ms(tester, 100);
      await _show(
        tester,
        host,
        _loader(GhostMood.hungry, key: 1, onEnd: () => calls++),
      );
      for (int i = 0; i < 5; i++) {
        expect(_pose(tester), MoodPose.rest(GhostMood.hungry));
        await _ms(tester, 100);
      }
      expect(calls, 0);
    });
  });

  group('reduced motion', () {
    testWidgets('a reaction mood calls once after the first frame', (
      tester,
    ) async {
      int calls = 0;
      final ValueNotifier<Widget> host = await _start(
        tester,
        _loader(GhostMood.rising, onEnd: () => calls++),
        reducedMotion: true,
      );
      expect(calls, 1);
      expect(tester.binding.transientCallbackCount, 0);
      await _ms(tester, 3000);
      await _show(
        tester,
        host,
        _loader(GhostMood.rising, key: 0, onEnd: () => calls++),
      );
      await _ms(tester, 100);
      expect(calls, 1);
      expect(_pose(tester), MoodPose.rest(GhostMood.rising));
    });

    testWidgets('a changed key restarts nothing and calls once more', (
      tester,
    ) async {
      int calls = 0;
      final ValueNotifier<Widget> host = await _start(
        tester,
        _loader(GhostMood.fed, key: 0, onEnd: () => calls++),
        reducedMotion: true,
      );
      expect(calls, 1);
      await _show(
        tester,
        host,
        _loader(GhostMood.fed, key: 1, onEnd: () => calls++),
      );
      expect(calls, 2);
      expect(tester.binding.transientCallbackCount, 0);
      await _ms(tester, 2000);
      expect(calls, 2);
    });
  });

  testWidgets('removing the loader leaves no ticker and no callback', (
    tester,
  ) async {
    int calls = 0;
    final ValueNotifier<Widget> host = await _start(
      tester,
      _loader(GhostMood.rising, onEnd: () => calls++),
    );
    await tester.pump();
    await _ms(tester, 500);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await _show(tester, host, const SizedBox());
    await _ms(tester, 3000);
    expect(tester.binding.transientCallbackCount, 0);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });
}
