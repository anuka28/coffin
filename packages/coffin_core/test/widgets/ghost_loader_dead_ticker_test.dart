import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

Widget _loader(GhostMood? mood, {int key = 0, VoidCallback? onEnd}) => Center(
  child: GhostLoader(mood: mood, reactionKey: key, onReactionEnd: onEnd),
);

GhostPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(GhostLoader),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as GhostPainter;

MoodPose _pose(WidgetTester tester) => _painter(tester).pose!;

int _count(WidgetTester tester) => tester.binding.transientCallbackCount;

Widget _hosted(ValueNotifier<Widget> host) => ValueListenableBuilder<Widget>(
  valueListenable: host,
  builder: (BuildContext context, Widget value, Widget? child) => value,
);

Future<ValueNotifier<Widget>> _start(
  WidgetTester tester,
  Widget first, {
  bool reducedMotion = false,
}) async {
  final ValueNotifier<Widget> host = ValueNotifier<Widget>(first);
  addTearDown(host.dispose);
  await pumpSpooky(tester, _hosted(host), reducedMotion: reducedMotion);
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

/// Mounts [first], runs the first tick, then lets [ms] pass.
Future<ValueNotifier<Widget>> _mount(
  WidgetTester tester,
  Widget first, [
  int ms = 100,
]) async {
  final ValueNotifier<Widget> host = await _start(tester, first);
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  return host;
}

Future<ValueNotifier<Widget>> _settledDead(WidgetTester tester) async {
  final ValueNotifier<Widget> host = await _mount(
    tester,
    _loader(GhostMood.content),
  );
  await _show(tester, host, _loader(GhostMood.dead));
  await tester.pump(const Duration(milliseconds: 600));
  expect(_count(tester), 0);
  return host;
}

void main() {
  testWidgets('a steady dead ghost has no ticker and no bob', (tester) async {
    await _start(tester, _loader(GhostMood.dead));
    expect(_count(tester), 0);
    final GhostLoader loader = tester.widget(find.byType(GhostLoader));
    expect(loader.mood, GhostMood.dead);
    for (int i = 0; i < 4; i++) {
      await tester.pump(Duration(milliseconds: i == 0 ? 1000 : 137));
      expect(_count(tester), 0);
      expect(_painter(tester).bobOffset, 0);
      expect(_pose(tester), MoodPose.rest(GhostMood.dead));
    }
  });

  testWidgets('dead to content resumes ticking and blends', (tester) async {
    final ValueNotifier<Widget> host = await _start(
      tester,
      _loader(GhostMood.dead),
    );
    await tester.pump(const Duration(seconds: 1));
    await _show(tester, host, _loader(GhostMood.content));
    expect(_count(tester), greaterThan(0));
    expect(_pose(tester), MoodPose.rest(GhostMood.dead));
    await tester.pump();
    for (final int t in <int>[0, 250, 250]) {
      await tester.pump(Duration(milliseconds: t));
    }
    // After 0, 250 and 500 ms the blend is complete.
    expect(_pose(tester), MoodPose.rest(GhostMood.content));
    expect(_count(tester), 1);
  });

  testWidgets('dead to content follows MoodBlend.mix at 0, 250, 500 ms', (
    tester,
  ) async {
    final ValueNotifier<Widget> host = await _start(
      tester,
      _loader(GhostMood.dead),
    );
    await tester.pump(const Duration(seconds: 1));
    await _show(tester, host, _loader(GhostMood.content));
    expect(_count(tester), greaterThan(0));
    await tester.pump();
    for (final int t in <int>[0, 250, 500]) {
      if (t > 0) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(
        _pose(tester),
        MoodBlend.mix(
          MoodPose.rest(GhostMood.dead),
          MoodPose.rest(GhostMood.content),
          MoodBlend.progressAt(t, MoodBlend.transitionMs),
        ),
        reason: '$t ms',
      );
    }
  });

  testWidgets('content to dead ticks, then stops at rest(dead)', (
    tester,
  ) async {
    final ValueNotifier<Widget> host = await _mount(
      tester,
      _loader(GhostMood.content),
    );
    expect(_count(tester), 1);
    await _show(tester, host, _loader(GhostMood.dead));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_count(tester), 1);
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_count(tester), 0);
    expect(_pose(tester), MoodPose.rest(GhostMood.dead));
    expect(_painter(tester).bobOffset, 0);
  });

  testWidgets('dead to fed runs once; fed to dead mid-run calls nothing', (
    tester,
  ) async {
    int ends = 0;
    final ValueNotifier<Widget> host = await _start(
      tester,
      _loader(GhostMood.dead),
    );
    await tester.pump(const Duration(seconds: 1));
    await _show(
      tester,
      host,
      _loader(GhostMood.fed, key: 1, onEnd: () => ends++),
    );
    expect(_count(tester), greaterThan(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(ends, 0);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 50));
    expect(ends, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(ends, 1);

    // fed to dead mid-run: a new run, interrupted.
    await _show(
      tester,
      host,
      _loader(GhostMood.fed, key: 2, onEnd: () => ends++),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _show(
      tester,
      host,
      _loader(GhostMood.dead, key: 2, onEnd: () => ends++),
    );
    final int before = ends;
    await tester.pump(const Duration(milliseconds: 400));
    expect(_count(tester), 1);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_count(tester), 0);
    expect(ends, before);
    expect(_pose(tester), MoodPose.rest(GhostMood.dead));
  });

  testWidgets('X to dead to Y quickly leaves no stale pose', (tester) async {
    final ValueNotifier<Widget> host = await _mount(
      tester,
      _loader(GhostMood.content),
    );
    await _show(tester, host, _loader(GhostMood.dead));
    await tester.pump(const Duration(milliseconds: 100));
    await _show(tester, host, _loader(GhostMood.hungry));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_pose(tester), MoodPose.rest(GhostMood.hungry));
    expect(_count(tester), 1);
    await _show(tester, host, _loader(GhostMood.dead));
    await _show(tester, host, _loader(GhostMood.content));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_pose(tester), MoodPose.rest(GhostMood.content));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a settled dead ghost stays stopped on rebuilds', (tester) async {
    final ValueNotifier<Widget> host = await _settledDead(tester);
    await _show(tester, host, _loader(GhostMood.dead));
    expect(_count(tester), 0);
    await _show(tester, host, _loader(GhostMood.dead, key: 0));
    expect(_count(tester), 0);
    await _show(tester, host, _loader(GhostMood.dead, key: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(_count(tester), 0);
    expect(_pose(tester), MoodPose.rest(GhostMood.dead));
  });

  testWidgets('reduced motion toggles keep a settled dead ghost stopped', (
    tester,
  ) async {
    final ValueNotifier<bool> reduced = ValueNotifier<bool>(false);
    addTearDown(reduced.dispose);
    final ValueNotifier<Widget> host = ValueNotifier<Widget>(
      _loader(GhostMood.content),
    );
    addTearDown(host.dispose);
    await pumpSpooky(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: reduced,
        builder: (BuildContext context, bool value, Widget? child) =>
            MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: value),
              child: _hosted(host),
            ),
      ),
    );
    await tester.pump();
    await _show(tester, host, _loader(GhostMood.dead));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_count(tester), 0);
    for (final bool value in <bool>[true, false]) {
      reduced.value = value;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_count(tester), 0);
    }
    expect(_pose(tester), MoodPose.rest(GhostMood.dead));
  });

  testWidgets('no mood and every bobbing mood keep one ticker', (tester) async {
    final ValueNotifier<Widget> host = await _start(tester, _loader(null));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_count(tester), 1);
    for (final GhostMood mood in GhostMood.values) {
      if (mood == GhostMood.dead) {
        continue;
      }
      await _show(tester, host, _loader(mood));
      await tester.pump(const Duration(seconds: 1));
      expect(_count(tester), 1, reason: '$mood');
    }
    await _show(tester, host, _loader(GhostMood.dead));
    await tester.pump(const Duration(seconds: 1));
    expect(_count(tester), 0);
    await _show(tester, host, _loader(null));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_count(tester), 1);
    await _show(tester, host, _loader(GhostMood.dead));
    expect(_count(tester), 0);
  });

  testWidgets('removing a stopped or running loader throws nothing', (
    tester,
  ) async {
    final ValueNotifier<Widget> host = await _settledDead(tester);
    await _show(tester, host, const SizedBox());
    expect(_count(tester), 0);

    await _show(tester, host, _loader(GhostMood.content));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_count(tester), 1);
    await _show(tester, host, const SizedBox());
    await tester.pump();
    expect(_count(tester), 0);
    expect(tester.takeException(), isNull);
  });
}
