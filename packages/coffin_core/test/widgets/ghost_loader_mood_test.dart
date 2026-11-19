import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:coffin_core/src/widgets/math/mood_traits.dart';
import 'package:coffin_core/src/widgets/motion_loop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

const Duration _settle = Duration(milliseconds: 300);

Widget _loader(GhostMood mood, {double size = 64, String? caption = 'Wake'}) =>
    Center(
      child: GhostLoader(mood: mood, size: size, caption: caption),
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

Future<Uint8List> _pixels(WidgetTester tester, Key key) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(key));
  final Uint8List? bytes = await tester.runAsync<Uint8List>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data = (await image.toByteData())!;
    return data.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  group('layout is the same for every mood', () {
    for (final double size in <double>[24, 64, 96, 256]) {
      for (final double width in testWidths) {
        for (final double scale in testTextScales) {
          for (final Brightness brightness in Brightness.values) {
            testWidgets(
              'size $size, width $width, scale $scale, ${brightness.name}',
              (tester) async {
                Size? firstSize;
                Offset? firstCaption;
                for (final GhostMood mood in GhostMood.values) {
                  await pumpSpooky(
                    tester,
                    _loader(mood, size: size),
                    width: width,
                    textScale: scale,
                    brightness: brightness,
                  );
                  await tester.pump(_settle);
                  final Size s = tester.getSize(find.byType(GhostLoader));
                  final Offset c = tester.getTopLeft(find.text('Wake'));
                  firstSize ??= s;
                  firstCaption ??= c;
                  expect(s, firstSize, reason: mood.name);
                  expect(c, firstCaption, reason: mood.name);
                  expect(tester.takeException(), isNull);
                }
                final double reserve = MoodTraits.reserveFor(size).toDouble();
                final Size box = tester.getSize(
                  find.descendant(
                    of: find.byType(GhostLoader),
                    matching: find.byType(RepaintBoundary),
                  ),
                );
                expect(box.width, size);
                expect(box.height, size + 2 * reserve);
              },
            );
          }
        }
      }
    }

    testWidgets('caption sits 8 px below the box', (tester) async {
      await pumpSpooky(tester, _loader(GhostMood.hungry));
      final Rect box = tester.getRect(
        find
            .descendant(
              of: find.byType(GhostLoader),
              matching: find.byType(RepaintBoundary),
            )
            .first,
      );
      expect(tester.getTopLeft(find.text('Wake')).dy, box.bottom + 8);
    });
  });

  group('semantics', () {
    for (final String? caption in <String?>[null, 'Summoning…']) {
      testWidgets('one live region labelled ${caption ?? 'Loading'}', (
        tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpSpooky(tester, _loader(GhostMood.thriving, caption: caption));
        await tester.pump(const Duration(milliseconds: 100));
        for (final GhostMood mood in GhostMood.values) {
          await pumpSpooky(tester, _loader(mood, caption: caption));
          await tester.pump(const Duration(milliseconds: 100));
          final SemanticsNode node = tester.getSemantics(
            find.byType(GhostLoader),
          );
          expect(
            node,
            matchesSemantics(
              label: caption ?? 'Loading',
              isLiveRegion: true,
              hasEnabledState: false,
            ),
            reason: mood.name,
          );
          expect(node.label.toLowerCase(), isNot(contains(mood.name)));
          int children = 0;
          node.visitChildren((SemanticsNode child) {
            children++;
            return true;
          });
          expect(children, 0, reason: 'painted ghost is excluded');
        }
        handle.dispose();
      });
    }
  });

  group('reduced motion', () {
    testWidgets('every mood shows rest(mood), bob 0, no ticker', (
      tester,
    ) async {
      for (final GhostMood mood in GhostMood.values) {
        await pumpSpooky(tester, _loader(mood), reducedMotion: true);
        await tester.pump(_settle);
        expect(tester.binding.transientCallbackCount, 0, reason: mood.name);
        final GhostPainter painter = _painter(tester);
        expect(painter.pose, MoodPose.rest(mood));
        expect(painter.bobOffset, 0);
        expect(
          find.descendant(
            of: find.byType(GhostLoader),
            matching: find.byType(AnimatedBuilder),
          ),
          findsNothing,
        );
        await tester.pump(const Duration(milliseconds: 700));
        expect(_painter(tester).bobOffset, 0);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('still frames of all moods differ in pixels', (tester) async {
      final Key key = UniqueKey();
      final List<Uint8List> frames = <Uint8List>[];
      for (final GhostMood mood in GhostMood.values) {
        await pumpSpooky(
          tester,
          Center(
            child: RepaintBoundary(
              key: key,
              child: GhostLoader(mood: mood, size: 96),
            ),
          ),
          reducedMotion: true,
        );
        await tester.pump(_settle);
        frames.add(await _pixels(tester, key));
      }
      for (int i = 0; i < frames.length; i++) {
        for (int j = i + 1; j < frames.length; j++) {
          expect(
            frames[i],
            isNot(orderedEquals(frames[j])),
            reason: '${GhostMood.values[i]} vs ${GhostMood.values[j]}',
          );
        }
      }
    });
  });

  group('normal motion', () {
    for (final GhostMood mood in GhostMood.values) {
      if (mood == GhostMood.dead) continue;
      testWidgets('${mood.name} ticks and its bob offset moves', (
        tester,
      ) async {
        await pumpSpooky(tester, _loader(mood));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.binding.transientCallbackCount, greaterThan(0));
        final double first = _painter(tester).bobOffset;
        await tester.pump(const Duration(milliseconds: 700));
        expect(_painter(tester).bobOffset, isNot(first));
        expect(_painter(tester).headroom, MoodTraits.reserveFor(64));
      });
    }

    testWidgets('toggling disableAnimations stops and restarts the ticker', (
      tester,
    ) async {
      final ValueNotifier<bool> reduced = ValueNotifier<bool>(false);
      addTearDown(reduced.dispose);
      const Widget child = Material(
        child: Center(child: GhostLoader(mood: GhostMood.thriving)),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: CoffinTheme.dark(),
          home: ValueListenableBuilder<bool>(
            valueListenable: reduced,
            child: child,
            builder: (BuildContext context, bool value, Widget? child) =>
                MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: value),
                  child: child!,
                ),
          ),
        ),
      );
      final MotionLoop<GhostLoader> loop =
          tester.state(find.byType(GhostLoader)) as MotionLoop<GhostLoader>;
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(loop.loopController.isAnimating, isTrue);

      reduced.value = true;
      await tester.pump();
      await tester.pump(_settle);
      expect(tester.binding.transientCallbackCount, 0);
      expect(loop.loopController.isAnimating, isFalse);
      expect(_painter(tester).bobOffset, 0);

      reduced.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(loop.loopController.isAnimating, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('null to mood and back switches path without error', (
      tester,
    ) async {
      await pumpSpooky(tester, const Center(child: GhostLoader()));
      expect(_painter(tester).pose, isNull);
      await pumpSpooky(
        tester,
        const Center(child: GhostLoader(mood: GhostMood.fading)),
      );
      expect(_painter(tester).pose, MoodPose.rest(GhostMood.fading));
      await pumpSpooky(tester, const Center(child: GhostLoader()));
      expect(_painter(tester).pose, isNull);
      expect(tester.takeException(), isNull);
    });
  });
}
