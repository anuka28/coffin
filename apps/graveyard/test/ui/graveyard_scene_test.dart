import 'dart:async';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';
import 'package:graveyard/src/ui/night_sky_painter.dart';

import '../support/controller_harness.dart';
import '../support/throwing_record_repository.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);

Grave _grave(String id) => Grave.manual(
  id: id,
  name: 'Project $id',
  dateOfDeath: CalendarDate(2024, 1, 3),
);

// One ThemeData for the whole file. `MaterialApp` animates a theme change for
// 200 ms, and `CoffinTheme.dark()` builds a new, unequal ThemeData on every
// call. A fresh theme on each `pumpWidget` therefore keeps a Material
// `AnimatedTheme` ticker running, even under `disableAnimations`.
final ThemeData _theme = CoffinTheme.dark();

Widget _host(
  List<Grave> graves, {
  bool disableAnimations = false,
  CalendarDate? today,
}) => MaterialApp(
  theme: _theme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(
    body: GraveyardScene(
      graves: graves,
      today: today ?? _today,
      onDelete: (_) {},
    ),
  ),
);

Grave _old(String id) => Grave.manual(
  id: id,
  name: 'Old $id',
  dateOfDeath: CalendarDate(2015, 1, 1),
);

int _skyCount(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .where((p) => p.painter is NightSkyPainter)
    .length;

ControllerHarness _harness({
  RecordRepository<Grave>? repository,
  bool isPersistent = true,
  Map<String, String> seed = const <String, String>{},
  Future<OpenedRepository<Grave>> Function()? openStorage,
}) {
  final h = ControllerHarness(
    repository: repository,
    isPersistent: isPersistent,
    seed: seed,
    openStorage: openStorage,
  );
  addTearDown(h.dispose);
  return h;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  ControllerHarness h, {
  double width = 400,
  double scale = 1,
  required bool disableAnimations,
}) async {
  if (width != 400 || tester.view.physicalSize.height != 640) {
    tester.view.physicalSize = Size(width, 900);
  }
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: GraveyardScreen(controller: h.controller),
    ),
  );
  if (disableAnimations) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

double _rise(WidgetTester tester, String id) => tester
    .widget<GraveTombstone>(
      find.byWidgetPredicate((w) => w is GraveTombstone && w.grave.id == id),
    )
    .riseProgress;

void main() {
  testWidgets('renders one tombstone per grave', (tester) async {
    await tester.pumpWidget(_host([_grave('a'), _grave('b'), _grave('c')]));
    expect(find.byType(GraveTombstone), findsNWidgets(3));
    expect(find.text('R.I.P.'), findsNWidgets(3));
  });

  testWidgets('graves in the first list never rise', (tester) async {
    await tester.pumpWidget(_host([_grave('a'), _grave('b')]));
    expect(_rise(tester, 'a'), 1);
    expect(_rise(tester, 'b'), 1);
  });

  testWidgets('an added grave rises once and the others stay put', (
    tester,
  ) async {
    await tester.pumpWidget(_host([_grave('a')]));
    await tester.pumpWidget(_host([_grave('a'), _grave('b')]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_rise(tester, 'a'), 1);
    expect(_rise(tester, 'b'), lessThan(1));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(_rise(tester, 'b'), 1);
    // A new Today does not replay the rise.
    await tester.pumpWidget(
      _host([_grave('a'), _grave('b')], today: CalendarDate(2024, 1, 11)),
    );
    expect(_rise(tester, 'b'), 1);
  });

  testWidgets('reduced motion runs no animation and nothing rises', (
    tester,
  ) async {
    await tester.pumpWidget(_host([_grave('a')], disableAnimations: true));
    await tester.pumpWidget(
      _host([_grave('a'), _grave('b')], disableAnimations: true),
    );
    expect(_rise(tester, 'b'), 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.hasRunningAnimations, isFalse);
  });

  for (final width in <double>[320, 768, 1280]) {
    testWidgets('does not overflow at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(List<Grave>.generate(5, (i) => _grave('g$i'))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  }

  group('reduced motion', () {
    testWidgets('has no running animation right after the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host([_old('a'), _old('b')], disableAnimations: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('has no running animation right after a grave is added', (
      tester,
    ) async {
      await tester.pumpWidget(_host([_old('a')], disableAnimations: true));
      await tester.pumpWidget(
        _host([_old('a'), _old('b')], disableAnimations: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('draws the cracks and every tombstone at rest', (tester) async {
      await tester.pumpWidget(
        _host([_old('a'), _old('b'), _grave('c')], disableAnimations: true),
      );
      expect(find.byType(GraveTombstone), findsNWidgets(3));
      for (final id in <String>['a', 'b', 'c']) {
        expect(_rise(tester, id), 1);
      }
      expect(find.byKey(const ValueKey<String>('cracks-a')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('cracks-b')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('cracks-c')), findsNothing);
      final sky = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<NightSkyPainter>()
          .single;
      expect(sky.reducedMotion, isTrue);
      expect(sky.twinkle, isNull);
    });

    // Documents the source of the extra running animation seen when a test
    // rebuilds the app with a new `CoffinTheme.dark()` on every pump. It is
    // Material's AnimatedTheme in the test host, not the scene, the fog or any
    // other Graveyard or coffin_core widget.
    testWidgets('a new ThemeData per pump runs only the Material theme tween', (
      tester,
    ) async {
      Widget host(List<Grave> graves) => MaterialApp(
        theme: CoffinTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: GraveyardScene(graves: graves, today: _today, onDelete: (_) {}),
        ),
      );
      await tester.pumpWidget(host([_grave('a')]));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(host([_grave('a'), _grave('b')]));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('motion turning off mid-Rise does not throw', (tester) async {
      await tester.pumpWidget(_host([_grave('a')]));
      await tester.pumpWidget(_host([_grave('a'), _grave('b')]));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_rise(tester, 'b'), lessThan(1));
      await tester.pumpWidget(
        _host([_grave('a'), _grave('b')], disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(_rise(tester, 'b'), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('motion turning off mid-Twinkle does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(_host([_grave('a')]));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(_host([_grave('a')], disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('rise', () {
    testWidgets('an added grave rises over 600 ms and then rests', (
      tester,
    ) async {
      await tester.pumpWidget(_host([_grave('a')]));
      await tester.pumpWidget(_host([_grave('a'), _grave('b')]));
      expect(_rise(tester, 'b'), 0);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_rise(tester, 'b'), inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_rise(tester, 'b'), 1);
      expect(_rise(tester, 'a'), 1);
    });

    testWidgets('deleting another grave starts no rise', (tester) async {
      await tester.pumpWidget(_host([_grave('a'), _grave('b'), _grave('c')]));
      await tester.pumpWidget(_host([_grave('a'), _grave('c')]));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_rise(tester, 'a'), 1);
      expect(_rise(tester, 'c'), 1);
    });

    testWidgets('deleting a grave mid-Rise keeps the other rise going', (
      tester,
    ) async {
      await tester.pumpWidget(_host([_grave('a'), _grave('b')]));
      await tester.pumpWidget(_host([_grave('a'), _grave('b'), _grave('c')]));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_host([_grave('a'), _grave('c')]));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(_rise(tester, 'a'), 1);
      expect(_rise(tester, 'c'), lessThan(1));
    });

    testWidgets('two quick adds rise independently', (tester) async {
      await tester.pumpWidget(_host([_grave('a')]));
      await tester.pumpWidget(_host([_grave('a'), _grave('b')]));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(_host([_grave('a'), _grave('b'), _grave('c')]));
      expect(_rise(tester, 'c'), 0);
      await tester.pump(const Duration(milliseconds: 200));
      final b = _rise(tester, 'b');
      final c = _rise(tester, 'c');
      expect(b, greaterThan(c));
      expect(c, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_rise(tester, 'b'), 1);
      expect(_rise(tester, 'c'), lessThan(1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(_rise(tester, 'c'), 1);
      expect(_rise(tester, 'a'), 1);
    });

    testWidgets('a grave rises when it is added through the screen', (
      tester,
    ) async {
      final h = _harness(
        seed: <String, String>{'g1': ControllerHarness.envelopeOf(_old('g1'))},
      );
      await h.controller.load();
      await _pumpScreen(tester, h, disableAnimations: false);
      expect(_rise(tester, 'g1'), 1);
      await h.controller.addManual(
        rawName: 'Newcomer',
        year: 2026,
        month: 5,
        day: 1,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final id = h.controller.graves.firstWhere((g) => g.name == 'Newcomer').id;
      expect(_rise(tester, id), lessThan(1));
      expect(_rise(tester, 'g1'), 1);
    });

    testWidgets('the first grave buried in an empty graveyard rises', (
      tester,
    ) async {
      final h = _harness();
      await h.controller.load();
      await _pumpScreen(tester, h, disableAnimations: false);
      expect(find.byType(GraveTombstone), findsNothing);
      final scene = tester.element(find.byType(GraveyardScene));
      await h.controller.addManual(
        rawName: 'First',
        year: 2026,
        month: 5,
        day: 1,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The same scene instance carries the change, so the grave rises.
      expect(tester.element(find.byType(GraveyardScene)), same(scene));
      final id = h.controller.graves.single.id;
      expect(_rise(tester, id), lessThan(1));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(_rise(tester, id), 1);

      // A fresh screen that loads that grave does not rise it, and the move
      // from loading to the loaded list does not count as an add.
      final reopened = _harness(
        seed: <String, String>{
          id: ControllerHarness.envelopeOf(h.controller.graves.single),
        },
      );
      final loading = reopened.controller.load();
      await _pumpScreen(tester, reopened, disableAnimations: false);
      await loading;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_rise(tester, id), 1);
    });

    testWidgets('graves of a retried load do not rise', (tester) async {
      final repo = ThrowingRecordRepository(failOnGetAll: true);
      final h = _harness(repository: repo);
      await h.controller.load();
      await _pumpScreen(tester, h, disableAnimations: false);
      expect(find.text(GraveyardCopy.loadError), findsOneWidget);
      await repo.put(
        'g1',
        Grave.manual(
          id: 'g1',
          name: 'Back again',
          dateOfDeath: CalendarDate(2025, 1, 1),
        ),
      );
      repo.failOnGetAll = false;
      await tester.tap(find.byKey(const ValueKey<String>('load-retry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Back again'), findsOneWidget);
      expect(_rise(tester, 'g1'), 1);
    });
  });

  group('layout', () {
    Future<int> columns(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(List<Grave>.generate(8, (i) => _grave('g$i'))),
      );
      final tops = <double>[
        for (var i = 0; i < 8; i++)
          tester.getTopLeft(find.byType(GraveTombstone).at(i)).dy,
      ];
      return tops.where((dy) => (dy - tops.first).abs() < 1).length;
    }

    testWidgets('360 px shows one column', (tester) async {
      expect(await columns(tester, 360), 1);
    });

    for (final width in <double>[768, 1280]) {
      testWidgets('$width px shows 2 to 4 columns', (tester) async {
        expect(await columns(tester, width), inInclusiveRange(2, 4));
      });
    }
  });

  group('semantics', () {
    testWidgets('node order follows the grave order', (tester) async {
      final handle = tester.ensureSemantics();
      for (final width in <double>[320, 360, 768, 1280]) {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final graves = <Grave>[
          for (final n in <String>['Alpha', 'Bravo', 'Charlie', 'Delta'])
            Grave.manual(id: n, name: n, dateOfDeath: CalendarDate(2024, 1, 3)),
        ];
        await tester.pumpWidget(_host(graves, disableAnimations: true));
        final labels = <String>[];
        void walk(SemanticsNode node) {
          if (node.label.isNotEmpty) labels.add(node.label);
          for (final child in node.debugListChildrenInOrder(
            DebugSemanticsDumpOrder.traversalOrder,
          )) {
            walk(child);
          }
        }

        walk(
          tester
              .renderObject(find.byType(MaterialApp))
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        // Each stone is followed by its own Delete button: stone 1, Delete 1,
        // stone 2, Delete 2, at every width.
        final sequence = <String>[
          for (final label in labels)
            for (var i = 0; i < graves.length; i++)
              if (label == GraveyardCopy.deleteLabel(graves[i].name))
                'delete $i'
              else if (label.contains(graves[i].name))
                'stone $i',
        ];
        expect(sequence, <String>[
          for (var i = 0; i < graves.length; i++) ...['stone $i', 'delete $i'],
        ], reason: 'reading order at width $width');
      }
      handle.dispose();
    });

    testWidgets('sky, moon, stars, ground and fog add no semantic node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      int count() {
        var n = 0;
        void walk(SemanticsNode node) {
          n++;
          node.visitChildren((child) {
            walk(child);
            return true;
          });
        }

        walk(
          tester
              .renderObject(find.byType(MaterialApp))
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        return n;
      }

      Widget app(Widget body) => MaterialApp(
        theme: _theme,
        home: Scaffold(body: body),
      );
      await tester.pumpWidget(app(const SizedBox.expand()));
      final bare = count();
      await tester.pumpWidget(
        app(
          GraveyardScene(
            graves: const <Grave>[],
            today: _today,
            onDelete: (_) {},
          ),
        ),
      );
      // The scene's scroll view may add one scrollable node. Nothing paints
      // a labeled node.
      final withScene = count();
      expect(withScene - bare, lessThanOrEqualTo(1));
      final labeled = <String>[];
      void walk(SemanticsNode node) {
        if (node.label.isNotEmpty) labeled.add(node.label);
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(
        tester
            .renderObject(find.byType(MaterialApp))
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      expect(labeled, isEmpty);
      handle.dispose();
    });
  });

  testWidgets('disposal during a Rise does not throw', (tester) async {
    await tester.pumpWidget(_host([_grave('a')]));
    await tester.pumpWidget(_host([_grave('a'), _grave('b')]));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  group('add button', () {
    testWidgets('the last Delete button scrolls clear of it and is tappable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = _harness(
        seed: <String, String>{
          for (var i = 0; i < 5; i++)
            'g$i': ControllerHarness.envelopeOf(
              Grave.manual(
                id: 'g$i',
                name: 'Late $i',
                dateOfDeath: CalendarDate(2026, 5, 5 - i),
              ),
            ),
        },
      );
      await h.controller.load();
      await _pumpScreen(tester, h, disableAnimations: true);

      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(GraveyardScene),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final fab = tester.getRect(
        find.byKey(const ValueKey<String>('screen-add')),
      );
      final lastDelete = find
          .widgetWithText(TextButton, GraveyardCopy.delete)
          .last;
      final button = tester.getRect(lastDelete);
      expect(button.overlaps(fab), isFalse);
      expect(
        GraveyardScene.bottomPadding,
        greaterThanOrEqualTo(
          GraveyardScene.addButtonHeight + GraveyardScene.addButtonGap,
        ),
      );

      await tester.tap(lastDelete);
      await tester.pumpAndSettle();
      expect(find.text(GraveyardCopy.deleteTitle('Late 4')), findsOneWidget);
    });
  });

  group('states over the sky and fog', () {
    const widths = <double>[320, 360, 768, 1280];
    const scales = <double>[1.0, 1.5];
    final states =
        <String, Future<void> Function(WidgetTester, ControllerHarness)>{
          'empty': (t, h) async {},
          'list': (t, h) async {},
          'load error': (t, h) async {},
          'memory notice': (t, h) async {},
          'save error': (t, h) async {
            await h.controller.addManual(
              rawName: 'Doomed',
              year: 2025,
              month: 1,
              day: 2,
            );
          },
        };

    for (final entry in states.entries) {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets('${entry.key} at $width px, scale $scale', (
            tester,
          ) async {
            final repo = ThrowingRecordRepository(
              failOnGetAll: entry.key == 'load error',
              failOnPut: entry.key == 'save error',
            );
            final h = _harness(
              repository: repo,
              isPersistent: entry.key != 'memory notice',
            );
            if (entry.key == 'list') {
              await repo.put(
                'g1',
                Grave.manual(
                  id: 'g1',
                  name: 'Old one',
                  dateOfDeath: CalendarDate(2019, 1, 1),
                ),
              );
            }
            await h.controller.load();
            await entry.value(tester, h);
            await _pumpScreen(
              tester,
              h,
              width: width,
              scale: scale,
              disableAnimations: true,
            );
            expect(tester.takeException(), isNull);
            expect(_skyCount(tester), 1);
            expect(find.byType(FogBackground), findsWidgets);
            // The scene keeps the full screen, never 0 px.
            expect(
              tester.getSize(find.byType(GraveyardScene)).height,
              greaterThan(0),
            );
          });
        }
      }
    }

    for (final width in widths) {
      for (final scale in scales) {
        testWidgets('loading at $width px, scale $scale', (tester) async {
          final gate = Completer<OpenedRepository<Grave>>();
          final h = _harness(openStorage: () => gate.future);
          unawaited(h.controller.load());
          await _pumpScreen(
            tester,
            h,
            width: width,
            scale: scale,
            disableAnimations: true,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(GhostLoader), findsOneWidget);
          expect(find.byType(FogBackground), findsWidgets);
          gate.complete(
            OpenedRepository<Grave>(
              repository: h.repository,
              isPersistent: true,
            ),
          );
          await tester.pumpAndSettle();
        });
      }
    }
  });
}
