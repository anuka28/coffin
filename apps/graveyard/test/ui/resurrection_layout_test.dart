// Feature: graveyard-resurrection, layout of the Raise_Control, the Living_Row,
// the Rest_Dialog and the Resurrection_Play.
// Validates: Requirements 5.10, 13.6, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 17.9
import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/domain/scene/scene_layout.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';
import 'package:graveyard/src/ui/living_row.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
import 'package:graveyard/src/ui/rest_dialog.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/seance_control.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/controller_harness.dart';
import '../support/fake_coffin_ai.dart';

const List<double> _widths = <double>[320, 360, 768, 1280];
const List<double> _scales = <double>[1.0, 1.5];
final CalendarDate _today = CalendarDate(2026, 5, 10);
final CalendarDate _risen = CalendarDate(2026, 5, 1);
final String _name80 = 'W' * 80;

final List<(String, ThemeData Function())> _themes =
    <(String, ThemeData Function())>[
      ('dark', CoffinTheme.dark),
      ('daylight', CoffinTheme.light),
    ];

Grave _plain(String id, [String? name]) => Grave.manual(
  id: id,
  name: name ?? 'Grave $id',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

Grave _alive(String id, String name) => Grave.manual(
  id: id,
  name: name,
  dateOfDeath: CalendarDate(2025, 1, 1),
  risenOn: _risen,
);

Grave _aliveGithub(String id) => Grave.github(
  id: id,
  name: 'a-very-long-repository-name-for-the-living',
  dateOfDeath: CalendarDate(2025, 1, 1),
  risenOn: _risen,
  repo: const RepoInfo(
    fullName: 'some-organisation-with-a-long-name/a-very-long-repository-name-for-the-living',
    htmlUrl: 'https://github.com/some-organisation-with-a-long-name/a-very-long-repository-name-for-the-living',
  ),
);

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app({
  required ThemeData theme,
  required double scale,
  required Widget home,
  bool reduced = false,
}) => MaterialApp(
  theme: theme,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reduced,
    ),
    child: child!,
  ),
  home: home,
);

/// Every Text under [root] lies inside [root] horizontally.
void _expectNoClippedText(WidgetTester tester, Finder root) {
  final Rect area = tester.getRect(root);
  final Finder texts = find.descendant(of: root, matching: find.byType(Text));
  expect(texts, findsWidgets);
  for (final Element e in texts.evaluate()) {
    final Rect r = tester.getRect(find.byElementPredicate((x) => x == e));
    expect(r.left, greaterThanOrEqualTo(area.left - 0.5), reason: '$e');
    expect(r.right, lessThanOrEqualTo(area.right + 0.5), reason: '$e');
  }
}

// -- Raise_Control in the sheet ---------------------------------------------

Future<void> _openSheet(
  WidgetTester tester, {
  required ThemeData theme,
  required double scale,
}) async {
  await tester.pumpWidget(
    _app(
      theme: theme,
      scale: scale,
      reduced: true,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showSeanceSheet(
              context,
              grave: _plain('s', 'The Very Long Named Project Of Weekends'),
              today: _today,
              seanceAi: FakeCoffinAI.replying('Boo.'),
              onRaise: (_) {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

final Finder _raise = find.byKey(const ValueKey<String>('seance-raise'));

Finder get _sheetScroll => find.descendant(
  of: find.byType(SeanceSheet),
  matching: find.byType(SingleChildScrollView),
);

// -- Living_Row --------------------------------------------------------------

Future<void> _pumpLiving(
  WidgetTester tester, {
  required double width,
  required double scale,
  required ThemeData theme,
}) async {
  _setView(tester, width, 900);
  await tester.pumpWidget(
    _app(
      theme: theme,
      scale: scale,
      reduced: true,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LivingRow(
            entries: <Grave>[_alive('a', _name80), _aliveGithub('b')],
            onLayToRest: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// -- Rest_Dialog -------------------------------------------------------------

Future<void> _openRest(
  WidgetTester tester, {
  required double width,
  required double scale,
  required ThemeData theme,
}) async {
  _setView(tester, width, 800);
  await tester.pumpWidget(
    _app(
      theme: theme,
      scale: scale,
      reduced: true,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showRestDialog(context, _name80),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

// -- Resurrection_Play -------------------------------------------------------

Future<void> _pumpPlay(
  WidgetTester tester, {
  required double width,
  required double scale,
  required ThemeData theme,
  List<Grave>? graves,
  VoidCallback? onEnd,
}) async {
  _setView(tester, width, 900);
  final List<Grave> shown = graves ?? <Grave>[_plain('p')];
  await tester.pumpWidget(
    _app(
      theme: theme,
      scale: scale,
      home: GraveyardScene(
        graves: shown,
        today: _today,
        onDelete: (_) {},
        seanceAi: buildSeanceAi(),
        playingIds: const <String>{'p'},
        onPlayEnd: (_) => onEnd?.call(),
      ),
    ),
  );
}

Future<void> _finishPlay(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump(const Duration(milliseconds: PlayTiming.playDurationMs));
}

// -- Screen with risen graves ------------------------------------------------

Future<ControllerHarness> _pumpScreen(
  WidgetTester tester,
  List<Grave> graves, {
  required double width,
  double height = 800,
}) async {
  _setView(tester, width, height);
  final ControllerHarness h = ControllerHarness(
    seed: <String, String>{
      for (final Grave g in graves) g.id: ControllerHarness.envelopeOf(g),
    },
  );
  addTearDown(h.dispose);
  await h.controller.load();
  await tester.pumpWidget(
    _app(
      theme: CoffinTheme.dark(),
      scale: 1,
      reduced: true,
      home: GraveyardScreen(
        controller: h.controller,
        seanceAi: FakeCoffinAI.replying('Boo.'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  return h;
}

void main() {
  group('Raise_Control', () {
    for (final (String, ThemeData Function()) theme in _themes) {
      for (final double width in _widths) {
        for (final double scale in _scales) {
          testWidgets(
            '${theme.$1}: no overflow, reachable at $width wide, scale $scale',
            (tester) async {
              _setView(tester, width, 800);
              await _openSheet(tester, theme: theme.$2(), scale: scale);
              expect(tester.takeException(), isNull);
              await tester.ensureVisible(_raise);
              await tester.pump();
              expect(_raise.hitTestable(), findsOneWidget);
              final Size size = tester.getSize(_raise);
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
              final Rect area = tester.getRect(_sheetScroll);
              final Rect r = tester.getRect(_raise);
              expect(r.left, greaterThanOrEqualTo(area.left - 0.5));
              expect(r.right, lessThanOrEqualTo(area.right + 0.5));
              _expectNoClippedText(tester, _raise);
            },
          );
        }
      }
    }

    for (final double width in <double>[768, 1280]) {
      testWidgets('the sheet content is at most 560 wide at $width', (
        tester,
      ) async {
        _setView(tester, width, 800);
        await _openSheet(tester, theme: CoffinTheme.dark(), scale: 1);
        final Rect area = tester.getRect(_sheetScroll);
        expect(area.width, lessThanOrEqualTo(560));
        expect(area.center.dx, closeTo(width / 2, 0.5));
      });
    }

    for (final double scale in <double>[1.5, 2.0]) {
      testWidgets('a short sheet scrolls to Raise and keeps close pinned at '
          'scale $scale', (tester) async {
        _setView(tester, 320, 260);
        await _openSheet(tester, theme: CoffinTheme.dark(), scale: scale);
        expect(tester.takeException(), isNull);
        final ScrollableState scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(SeanceSheet),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        final Finder close = find.byKey(const ValueKey<String>('seance-close'));
        expect(close.hitTestable(), findsOneWidget);

        await tester.ensureVisible(_raise);
        await tester.pump();
        expect(_raise.hitTestable(), findsOneWidget);

        scrollable.position.jumpTo(0);
        await tester.pump();
        expect(close.hitTestable(), findsOneWidget);
        expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Living_Row', () {
    for (final (String, ThemeData Function()) theme in _themes) {
      for (final double width in _widths) {
        for (final double scale in <double>[..._scales, 2.0]) {
          testWidgets(
            '${theme.$1}: no overflow, no clipped text at $width wide, '
            'scale $scale',
            (tester) async {
              await _pumpLiving(
                tester,
                width: width,
                scale: scale,
                theme: theme.$2(),
              );
              expect(tester.takeException(), isNull);
              expect(find.text(_name80), findsOneWidget);
              expect(
                find.textContaining('a-very-long-repository-name-for-the'),
                findsWidgets,
              );
              _expectNoClippedText(tester, find.byType(LivingRow));
              for (final Element e
                  in find
                      .descendant(
                        of: find.byType(LivingRow),
                        matching: find.byType(TextButton),
                      )
                      .evaluate()) {
                final Size s = tester.getSize(
                  find.byElementPredicate((x) => x == e),
                );
                expect(s.width, greaterThanOrEqualTo(48));
                expect(s.height, greaterThanOrEqualTo(48));
              }
            },
          );
        }
      }
    }

    for (final double width in <double>[320, 768, 1280]) {
      testWidgets('uses the side padding and width of the header at $width', (
        tester,
      ) async {
        await _pumpScreen(tester, <Grave>[
          _plain('a'),
          _alive('b', 'Risen one'),
        ], width: width);
        expect(tester.takeException(), isNull);
        final double side = 16 + math.max(0, (width - 560) / 2);
        final Rect row = tester.getRect(find.byType(LivingRow));
        final Rect title = tester.getRect(find.text(GraveyardCopy.screenTitle));
        expect(row.left, closeTo(side, 0.5));
        expect(row.right, closeTo(width - side, 0.5));
        expect(row.left, closeTo(title.left, 0.5));
        expect(row.right, closeTo(title.right, 0.5));
        if (width > 592) expect(row.width, lessThanOrEqualTo(560));
      });
    }

    testWidgets('a long row scrolls with the header and traps no scroll', (
      tester,
    ) async {
      await _pumpScreen(tester, <Grave>[
        for (int i = 0; i < 8; i++) _alive('r$i', 'Risen number $i'),
        _plain('a'),
      ], width: 360);
      expect(tester.takeException(), isNull);
      final Finder scrollables = find.ancestor(
        of: find.byType(LivingRow),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scrollables, findsOneWidget);
      expect(
        find.descendant(
          of: scrollables,
          matching: find.text(GraveyardCopy.screenTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(LivingRow),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find
            .descendant(of: scrollables, matching: find.byType(Scrollable))
            .first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));

      final Finder title = find.text(GraveyardCopy.screenTitle);
      final double titleTop = tester.getTopLeft(title).dy;
      final double lastTop = tester.getTopLeft(find.text('Risen number 7')).dy;
      // Drag from inside the Living_Row itself.
      await tester.drag(find.text('Risen number 3'), const Offset(0, -200));
      await tester.pump();
      expect(scrollable.position.pixels, greaterThan(0));
      expect(tester.getTopLeft(title).dy, lessThan(titleTop));
      expect(
        tester.getTopLeft(find.text('Risen number 7')).dy,
        lessThan(lastTop),
      );

      await tester.drag(find.text('Risen number 3'), const Offset(0, 200));
      await tester.pump();
      expect(scrollable.position.pixels, 0);
      expect(tester.getTopLeft(title).dy, titleTop);

      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      expect(find.text('Grave a'), findsOneWidget);
      expect(find.text('Grave a').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Rest_Dialog', () {
    for (final (String, ThemeData Function()) theme in _themes) {
      for (final double width in _widths) {
        for (final double scale in <double>[..._scales, 2.0]) {
          testWidgets('${theme.$1}: usable, no clipped text at $width wide, '
              'scale $scale', (tester) async {
            await _openRest(
              tester,
              width: width,
              scale: scale,
              theme: theme.$2(),
            );
            expect(tester.takeException(), isNull);
            expect(find.byType(RestDialog), findsOneWidget);
            final Finder dialog = find.byType(AlertDialog);
            _expectNoClippedText(tester, dialog);
            for (final String key in <String>['rest-cancel', 'rest-confirm']) {
              final Finder f = find.byKey(ValueKey<String>(key));
              await tester.ensureVisible(f);
              await tester.pump();
              expect(f.hitTestable(), findsOneWidget, reason: key);
              expect(tester.getSize(f).width, greaterThanOrEqualTo(48));
              expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
              final Rect r = tester.getRect(f);
              final Rect d = tester.getRect(dialog);
              expect(r.left, greaterThanOrEqualTo(d.left - 0.5));
              expect(r.right, lessThanOrEqualTo(d.right + 0.5));
            }
          });
        }
      }
    }
  });

  group('Resurrection_Play', () {
    for (final (String, ThemeData Function()) theme in _themes) {
      for (final double width in _widths) {
        for (final double scale in _scales) {
          testWidgets(
            '${theme.$1}: a running play has no overflow at $width wide, '
            'scale $scale',
            (tester) async {
              int ended = 0;
              await _pumpPlay(
                tester,
                width: width,
                scale: scale,
                theme: theme.$2(),
                onEnd: () => ended++,
              );
              expect(find.byType(ResurrectionPlay), findsOneWidget);
              for (final int ms in <int>[300, 600, 900, 600, 600, 600]) {
                await tester.pump(Duration(milliseconds: ms));
                expect(tester.takeException(), isNull);
              }
              await _finishPlay(tester);
              expect(tester.takeException(), isNull);
              expect(ended, 1);
            },
          );
        }
      }
    }
  });

  group('Scene_Layout stays put', () {
    final Map<double, (int, double)> expected = <double, (int, double)>{
      320: (1, 288),
      360: (1, 300),
      768: (2, 300),
      1280: (4, 294),
    };
    for (final MapEntry<double, (int, double)> e in expected.entries) {
      testWidgets('column count and tombstone width at ${e.key}', (
        tester,
      ) async {
        expect(SceneLayout.columnsFor(e.key), e.value.$1);
        expect(
          SceneLayout.tombstoneWidthFor(e.key, e.value.$1),
          closeTo(e.value.$2, 1e-9),
        );
        await _pumpPlay(
          tester,
          width: e.key,
          scale: 1,
          theme: CoffinTheme.dark(),
          graves: <Grave>[
            _plain('p'),
            for (int i = 0; i < 5; i++) _plain('q$i'),
            _alive('r', 'Risen one'),
          ],
        );
        await tester.pump(const Duration(milliseconds: 900));
        expect(tester.takeException(), isNull);
        final Finder stones = find.byType(GraveTombstone);
        expect(stones, findsNWidgets(6));
        final Set<int> lefts = <int>{};
        for (final Element el in stones.evaluate()) {
          final Finder one = find.byElementPredicate((x) => x == el);
          expect(tester.getSize(one).width, closeTo(e.value.$2, 0.01));
          lefts.add(tester.getTopLeft(one).dx.round());
        }
        expect(lefts.length, math.min(e.value.$1, 6));
        await _finishPlay(tester);
      });
    }

    test('the tilt limit is still 3 degrees', () {
      expect(
        GraveyardScene.tiltMargin(300),
        closeTo(300 * math.sin(3 * math.pi / 180), 1e-9),
      );
    });

    testWidgets('an old stone keeps its tilt of at most 3 degrees while it '
        'plays', (tester) async {
      _setView(tester, 360, 900);
      final Grave old = Grave.manual(
        id: 'p',
        name: 'Ancient',
        dateOfDeath: CalendarDate(2010, 1, 1),
      );
      await _pumpPlay(
        tester,
        width: 360,
        scale: 1,
        theme: CoffinTheme.dark(),
        graves: <Grave>[old],
      );
      await tester.pump(const Duration(milliseconds: 900));
      final Finder tilt = find.descendant(
        of: find.byType(GraveTombstone),
        matching: find.byWidgetPredicate(
          (w) => w is Transform && w.alignment == Alignment.bottomCenter,
        ),
      );
      final m = tester.widget<Transform>(tilt.first).transform;
      expect(
        math.atan2(m.storage[1], m.storage[0]).abs(),
        lessThanOrEqualTo(3 * math.pi / 180 + 1e-9),
      );
      await _finishPlay(tester);
    });

    testWidgets('the Seance_Control keeps its tap target at 320 wide', (
      tester,
    ) async {
      await _pumpPlay(
        tester,
        width: 320,
        scale: 1.5,
        theme: CoffinTheme.dark(),
      );
      await tester.pump(const Duration(milliseconds: 900));
      final Size s = tester.getSize(find.byType(SeanceControl));
      expect(s.width, greaterThanOrEqualTo(48));
      expect(s.height, greaterThanOrEqualTo(48));
      await _finishPlay(tester);
    });
  });
}
