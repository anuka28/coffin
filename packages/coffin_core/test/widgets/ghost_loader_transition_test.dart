import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_blend.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

Widget _loader(GhostMood mood) => Center(child: GhostLoader(mood: mood));

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

MoodPose _expected(GhostMood from, GhostMood to, int sinceMs) => MoodBlend.mix(
  MoodPose.rest(from),
  MoodPose.rest(to),
  MoodBlend.progressAt(sinceMs, MoodBlend.transitionMs),
);

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

/// Mounts [mood] and runs the first tick so the loop clock reads 0, then 100.
Future<ValueNotifier<Widget>> _mount(
  WidgetTester tester,
  GhostMood mood,
) async {
  final ValueNotifier<Widget> host = await _start(tester, _loader(mood));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return host;
}

void main() {
  testWidgets('blend follows MoodBlend.mix at 0, 250 and 500 ms', (
    tester,
  ) async {
    final ValueNotifier<Widget> host = await _mount(tester, GhostMood.thriving);
    expect(_pose(tester), MoodPose.rest(GhostMood.thriving));

    await _show(tester, host, _loader(GhostMood.dead));
    expect(_pose(tester), _expected(GhostMood.thriving, GhostMood.dead, 0));

    for (final int t in <int>[250, 500]) {
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        _pose(tester),
        _expected(GhostMood.thriving, GhostMood.dead, t),
        reason: '$t ms',
      );
      expect(tester.binding.transientCallbackCount, lessThanOrEqualTo(1));
    }
    expect(_pose(tester), MoodPose.rest(GhostMood.dead));
  });

  testWidgets('a change mid-blend continues from the shown pose', (
    tester,
  ) async {
    final ValueNotifier<Widget> host = await _mount(tester, GhostMood.thriving);
    await _show(tester, host, _loader(GhostMood.hungry));
    await tester.pump(const Duration(milliseconds: 250));
    final MoodPose shown = _pose(tester);
    expect(shown, isNot(MoodPose.rest(GhostMood.thriving)));
    expect(shown, isNot(MoodPose.rest(GhostMood.hungry)));

    await _show(tester, host, _loader(GhostMood.fading));
    expect(_pose(tester), shown);

    await tester.pump(const Duration(milliseconds: 250));
    expect(
      _pose(tester),
      MoodBlend.mix(
        shown,
        MoodPose.rest(GhostMood.fading),
        MoodBlend.progressAt(250, MoodBlend.transitionMs),
      ),
    );
    expect(tester.binding.transientCallbackCount, lessThanOrEqualTo(1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_pose(tester), MoodPose.rest(GhostMood.fading));
  });

  testWidgets('the same mood starts no blend', (tester) async {
    final ValueNotifier<Widget> host = await _mount(tester, GhostMood.content);
    await _show(tester, host, _loader(GhostMood.content));
    for (int i = 0; i < 3; i++) {
      expect(_pose(tester), MoodPose.rest(GhostMood.content));
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('one ticker during and after a transition', (tester) async {
    final ValueNotifier<Widget> host = await _mount(tester, GhostMood.content);
    expect(tester.binding.transientCallbackCount, 1);
    await _show(tester, host, _loader(GhostMood.fading));
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, lessThanOrEqualTo(1));
    }
    expect(tester.binding.transientCallbackCount, 1);
    expect(_pose(tester), MoodPose.rest(GhostMood.fading));
    expect(tester.takeException(), isNull);
  });
}
