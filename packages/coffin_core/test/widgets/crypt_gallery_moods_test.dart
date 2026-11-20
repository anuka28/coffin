import 'package:coffin_core/coffin_core.dart';
import 'package:coffin_core/src/widgets/crypt_gallery_panel.dart';
import 'package:coffin_core/src/widgets/math/mood_pose.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_spooky.dart';

Finder get _panels => find.byType(CryptGalleryPanel);

/// The seven mood loaders of [panel], in tree order.
List<GhostLoader> _moodLoaders(WidgetTester tester, Finder panel) => tester
    .widgetList<GhostLoader>(
      find.descendant(of: panel, matching: find.byType(GhostLoader)),
    )
    .where((GhostLoader l) => l.mood != null)
    .toList();

GhostPainter _painterOf(WidgetTester tester, Finder panel, GhostMood mood) {
  final Finder loader = find.descendant(
    of: panel,
    matching: find.byWidgetPredicate(
      (Widget w) => w is GhostLoader && w.mood == mood,
    ),
  );
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(of: loader, matching: find.byType(CustomPaint)),
  );
  return paint.painter! as GhostPainter;
}

Future<void> _pumpGallery(
  WidgetTester tester, {
  bool reducedMotion = false,
  Brightness brightness = Brightness.dark,
  double width = 360,
  double textScale = 1.0,
}) async {
  await pumpSpooky(
    tester,
    const CryptGallery(),
    reducedMotion: reducedMotion,
    brightness: brightness,
    width: width,
    textScale: textScale,
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('crypt gallery mood section', () {
    testWidgets('each panel shows seven mood loaders in order', (tester) async {
      await _pumpGallery(tester);
      expect(_panels, findsNWidgets(2));
      for (int i = 0; i < 2; i++) {
        final Finder panel = _panels.at(i);
        final List<GhostLoader> loaders = _moodLoaders(tester, panel);
        expect(
          loaders.map((GhostLoader l) => l.mood).toList(),
          GhostMood.values,
        );
        expect(
          loaders.map((GhostLoader l) => l.caption).toList(),
          GhostMood.values.map((GhostMood m) => m.name).toList(),
        );
        expect(
          loaders.every((GhostLoader l) => l.onReactionEnd == null),
          isTrue,
        );
        for (final GhostMood mood in GhostMood.values) {
          expect(
            find.descendant(of: panel, matching: find.text(mood.name)),
            findsOneWidget,
          );
        }
      }
    });

    testWidgets('the section title is a semantic header', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpGallery(tester);
      expect(find.text('Seven ways to be haunted'), findsNWidgets(2));
      expect(
        tester.getSemantics(find.text('Seven ways to be haunted').first),
        isSemantics(isHeader: true),
      );
      expect(
        find.text('Each ghost wears its mood on its face.'),
        findsNWidgets(2),
      );
      handle.dispose();
    });

    testWidgets('existing loaders and captions are still present', (
      tester,
    ) async {
      await _pumpGallery(tester);
      for (int i = 0; i < 2; i++) {
        final Finder panel = _panels.at(i);
        expect(
          find.descendant(of: panel, matching: find.byType(GhostLoader)),
          findsNWidgets(9),
        );
        expect(
          find.descendant(
            of: panel,
            matching: find.text('Summoning your ghost…'),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('does not overflow at any width, scale or theme', (
      tester,
    ) async {
      for (final Brightness brightness in Brightness.values) {
        for (final double width in testWidths) {
          for (final double scale in testTextScales) {
            await _pumpGallery(
              tester,
              brightness: brightness,
              width: width,
              textScale: scale,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '$brightness $width x$scale',
            );
          }
        }
      }
    });

    testWidgets('reduced motion shows each Still_Frame and no ticker', (
      tester,
    ) async {
      await _pumpGallery(tester, reducedMotion: true);
      await tester.pump(const Duration(milliseconds: 400));
      for (int i = 0; i < 2; i++) {
        for (final GhostMood mood in GhostMood.values) {
          final GhostPainter painter = _painterOf(tester, _panels.at(i), mood);
          expect(painter.pose, MoodPose.rest(mood), reason: mood.name);
          expect(painter.bobOffset, 0, reason: mood.name);
        }
      }
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('fed and rising play once and hold their rest pose', (
      tester,
    ) async {
      await _pumpGallery(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 2300));
      expect(tester.takeException(), isNull);
      for (int i = 0; i < 2; i++) {
        for (final GhostMood mood in <GhostMood>[
          GhostMood.fed,
          GhostMood.rising,
        ]) {
          expect(
            _painterOf(tester, _panels.at(i), mood).pose,
            MoodPose.rest(mood),
            reason: mood.name,
          );
        }
      }
    });
  });
}
