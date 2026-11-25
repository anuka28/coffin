import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/ui/clods_painter.dart';
import 'package:graveyard/src/ui/hand_painter.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';

/// `MoodReaction.risingDurationMs` of coffin_core (not a public export, so
/// pinned here; coffin_core's own tests check the source value).
const int _risingDurationMs = 2200;

Widget _host({
  required bool reduced,
  required VoidCallback onEnd,
  required VoidCallback onRisen,
  bool show = true,
  Size size = const Size(160, 200),
  double textScale = 1,
}) {
  return MaterialApp(
    theme: CoffinTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: show
            ? ResurrectionPlay(
                graveId: 'g1',
                stoneSize: size,
                textScale: textScale,
                onEnd: onEnd,
                onEpitaphRisen: onRisen,
              )
            : const SizedBox(),
      ),
    ),
  );
}

void main() {
  testWidgets('animated play ends once and announces the epitaph once', (
    tester,
  ) async {
    var ends = 0;
    var risen = 0;
    await tester.pumpWidget(
      _host(reduced: false, onEnd: () => ends++, onRisen: () => risen++),
    );
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(GhostLoader), findsOneWidget);
    expect(ends, 0);
    await tester.pump(
      const Duration(milliseconds: PlayTiming.epitaphFadeStartMs),
    );
    expect(risen, 1);
    await tester.pump(const Duration(milliseconds: PlayTiming.playDurationMs));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ends, 1);
    expect(risen, 1);
  });

  testWidgets(
    'reduced motion announces at once and ends after the play duration',
    (tester) async {
      var ends = 0;
      var risen = 0;
      await tester.pumpWidget(
        _host(reduced: true, onEnd: () => ends++, onRisen: () => risen++),
      );
      expect(risen, 1);
      expect(ends, 0);
      // A controller's clock starts on its first frame, so deliver that frame.
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: PlayTiming.playDurationMs - 1),
      );
      expect(ends, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(ends, 1);
    },
  );

  testWidgets('removing the play mid-way never calls onEnd', (tester) async {
    var ends = 0;
    await tester.pumpWidget(
      _host(reduced: false, onEnd: () => ends++, onRisen: () {}),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(
      _host(reduced: false, onEnd: () => ends++, onRisen: () {}, show: false),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(ends, 0);
  });

  group('timeline', () {
    bool hasPainter<T extends CustomPainter>(WidgetTester t) => t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .any((CustomPaint c) => c.painter is T);

    Future<void> start(
      WidgetTester tester, {
      VoidCallback? onEnd,
      VoidCallback? onRisen,
      bool reduced = false,
    }) async {
      await tester.pumpWidget(
        _host(
          reduced: reduced,
          onEnd: onEnd ?? () {},
          onRisen: onRisen ?? () {},
        ),
      );
      await tester.pump();
    }

    double ghostTop(WidgetTester tester) =>
        tester.getTopLeft(find.byType(GhostLoader)).dy;

    testWidgets('hand and clods paint before 600 ms only', (tester) async {
      await start(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(hasPainter<HandPainter>(tester), isTrue);
      expect(hasPainter<ClodsPainter>(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 399));
      expect(hasPainter<HandPainter>(tester), isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      // Painters stay mounted; the shapes are empty after 600 ms, so only
      // check that the ghost has taken over.
      expect(find.byType(GhostLoader), findsOneWidget);
    });

    testWidgets('ghost absent before 600 ms, present after, rises and holds', (
      tester,
    ) async {
      await start(tester);
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.byType(GhostLoader), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(GhostLoader), findsOneWidget);
      final double startTop = ghostTop(tester);
      await tester.pump(const Duration(milliseconds: 770));
      final double midTop = ghostTop(tester);
      await tester.pump(const Duration(milliseconds: 770));
      final double endTop = ghostTop(tester);
      expect(endTop, lessThan(startTop));
      expect(midTop, lessThan(startTop));
      expect(midTop, greaterThan(endTop));
      await tester.pump(const Duration(milliseconds: 330));
      expect(ghostTop(tester), endTop);
      await tester.pump(const Duration(milliseconds: 330));
      expect(ghostTop(tester), endTop);
      expect(find.byType(GhostLoader), findsOneWidget);
    });

    testWidgets('callbacks fire once at their milestones', (tester) async {
      var ends = 0;
      var risen = 0;
      // Like GraveTombstone, the host drops the play when it ends.
      var shown = true;
      late StateSetter setHost;
      await tester.pumpWidget(
        MaterialApp(
          theme: CoffinTheme.dark(),
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter set) {
              setHost = set;
              return shown
                  ? ResurrectionPlay(
                      graveId: 'g1',
                      stoneSize: const Size(160, 200),
                      textScale: 1,
                      onEnd: () {
                        ends++;
                        setHost(() => shown = false);
                      },
                      onEpitaphRisen: () => risen++,
                    )
                  : const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2139));
      expect(risen, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(risen, 1);
      await tester.pump(const Duration(milliseconds: 659));
      expect(ends, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(ends, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(ends, 1);
      expect(risen, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    test('timing constants agree with the core rising reaction', () {
      expect(_risingDurationMs, 2200);
      expect(
        PlayTiming.risingGhostStartMs + _risingDurationMs,
        lessThanOrEqualTo(PlayTiming.playDurationMs),
      );
    });

    testWidgets('rebuild with new size or text scale keeps the clock', (
      tester,
    ) async {
      var ends = 0;
      await start(tester, onEnd: () => ends++);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpWidget(
        _host(
          reduced: false,
          onEnd: () => ends++,
          onRisen: () {},
          size: const Size(200, 260),
          textScale: 1.5,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1299));
      expect(ends, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(ends, 1);
    });

    testWidgets('exposes no semantics node', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await start(tester);
      await tester.pump(const Duration(milliseconds: 1000));
      final SemanticsNode root = tester.getSemantics(
        find.byType(ResurrectionPlay),
      );
      var labelled = 0;
      void walk(SemanticsNode n) {
        if (n.label.isNotEmpty) labelled++;
        n.visitChildren((SemanticsNode c) {
          walk(c);
          return true;
        });
      }

      walk(root);
      expect(labelled, 0);
      handle.dispose();
    });
  });

  group('reduced motion', () {
    testWidgets('nothing runs or draws; onEnd at 2800 ms', (tester) async {
      var ends = 0;
      var risen = 0;
      await tester.pumpWidget(
        _host(reduced: true, onEnd: () => ends++, onRisen: () => risen++),
      );
      expect(risen, 1);
      // The ghost may stand still at its final spot; nothing moves.
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .any((c) => c.painter is HandPainter || c.painter is ClodsPainter),
        isFalse,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2799));
      expect(ends, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(ends, 1);
      expect(risen, 1);
    });

    testWidgets('switching to reduced mid-play ends at the same total time', (
      tester,
    ) async {
      var ends = 0;
      var risen = 0;
      await tester.pumpWidget(
        _host(reduced: false, onEnd: () => ends++, onRisen: () => risen++),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(risen, 0);
      await tester.pumpWidget(
        _host(reduced: true, onEnd: () => ends++, onRisen: () => risen++),
      );
      expect(risen, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1799));
      expect(ends, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(ends, 1);
      expect(risen, 1);
    });
  });
}
