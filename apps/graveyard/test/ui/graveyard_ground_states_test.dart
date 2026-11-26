// Feature: graveyard-polish, ground states: Ground_Field and Ground_Band.
// Validates: Requirements 1.4, 2.7, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6,
// 5.1, 5.2, 5.3, 5.4, 5.6, 12.5, 12.6, 12.7
import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/ground_painter.dart';
import 'package:graveyard/src/ui/night_sky_painter.dart';

import '../support/fake_coffin_ai.dart';

const double _tolerance = 1;
const Key _bandKey = ValueKey<String>('ground-band');
const Key _tapKey = ValueKey<String>('test-tap');

final CalendarDate _today = CalendarDate(2026, 5, 10);

// One ThemeData for the whole file, so Material runs no theme tween.
final ThemeData _theme = CoffinTheme.dark();

Grave _grave(int i) => Grave.manual(
  id: 'g$i',
  name: i.isEven ? 'Project $i' : 'A long wrapping name of project number $i',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

Grave _risen(int i) => Grave.manual(
  id: 'r$i',
  name: 'Risen $i',
  dateOfDeath: CalendarDate(2025, 1, 1),
  risenOn: CalendarDate(2026, 5, 1),
);

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(
  List<Grave> graves, {
  bool reduced = true,
  Widget? header,
  ValueChanged<Grave>? onDelete,
}) => MaterialApp(
  theme: _theme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: Scaffold(
    body: GraveyardScene(
      graves: graves,
      today: _today,
      onDelete: onDelete ?? (_) {},
      seanceAi: FakeCoffinAI.replying('Boo.'),
      header: header,
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  List<Grave> graves, {
  double width = 400,
  double height = 700,
  bool reduced = true,
  Widget? header,
  ValueChanged<Grave>? onDelete,
}) async {
  _setView(tester, width, height);
  await tester.pumpWidget(
    _host(graves, reduced: reduced, header: header, onDelete: onDelete),
  );
  await tester.pump();
  await tester.pump();
}

/// Pumps a new list into the already mounted scene and measures it.
Future<void> _update(
  WidgetTester tester,
  List<Grave> graves, {
  bool reduced = true,
  Widget? header,
}) async {
  await tester.pumpWidget(_host(graves, reduced: reduced, header: header));
  await tester.pump();
  await tester.pump();
}

bool _isGround(Widget w) => w is CustomPaint && w.painter is GroundPainter;

Finder get _anyGround => find.byWidgetPredicate(_isGround);

/// The Ground_Field: a ground painter inside the scroll content.
Finder get _field => find.descendant(
  of: find.byType(SingleChildScrollView),
  matching: _anyGround,
);

Finder get _band => find.byKey(_bandKey);

Finder get _scroll => find.byType(SingleChildScrollView);

RenderBox _fieldBox(WidgetTester tester) =>
    tester.renderObject<RenderBox>(_field);

RenderBox _content(WidgetTester tester) => tester.renderObject<RenderBox>(
  find.descendant(of: _scroll, matching: find.byType(Stack)).first,
);

/// Base of the first Stone_Box in the coordinates of [ancestor].
double _firstBase(WidgetTester tester, RenderBox ancestor) {
  final Element e = find.byType(GraveTombstone).evaluate().first;
  final Finder box = find
      .descendant(
        of: find.byElementPredicate((x) => x == e),
        matching: find.byWidgetPredicate(
          (w) =>
              w is ConstrainedBox &&
              w.constraints.maxWidth == GraveTombstone.maxStoneWidth,
        ),
      )
      .first;
  final RenderBox stone = tester.renderObject<RenderBox>(box);
  return stone
      .localToGlobal(
        Offset(stone.size.width / 2, stone.size.height),
        ancestor: ancestor,
      )
      .dy;
}

double _horizon(WidgetTester tester) {
  final RenderBox content = _content(tester);
  final RenderBox ground = _fieldBox(tester);
  return ground.localToGlobal(Offset.zero, ancestor: content).dy +
      math.min(GroundPainter.maxSoftEdge, ground.size.height / 2);
}

void _expectHorizonAtBase(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(
    _horizon(tester),
    closeTo(_firstBase(tester, _content(tester)), _tolerance),
  );
}

/// The tall header makes the scroll content scroll without any rows.
Widget get _tallHeader => const SizedBox(height: 2000);

void _expectBand(WidgetTester tester) {
  expect(_band, findsOneWidget);
  expect(_field, findsNothing);
  expect(_anyGround, findsOneWidget);
  final Rect scene = tester.getRect(find.byType(GraveyardScene));
  final Rect band = tester.getRect(_band);
  expect(band.left, closeTo(scene.left, 0.01));
  expect(band.right, closeTo(scene.right, 0.01));
  expect(band.bottom, closeTo(scene.bottom, 0.01));
  expect(band.height, closeTo(scene.height * 0.34, 0.01));
}

void main() {
  group('one ground at a time', () {
    testWidgets('with rows: one Ground_Field and no Ground_Band', (
      tester,
    ) async {
      await _pump(tester, <Grave>[_grave(0), _grave(1)]);
      expect(_field, findsOneWidget);
      expect(_band, findsNothing);
      expect(_anyGround, findsOneWidget);
    });

    testWidgets('empty graves: one Ground_Band, no Ground_Field', (
      tester,
    ) async {
      await _pump(tester, const <Grave>[]);
      _expectBand(tester);
    });

    testWidgets('load-error scene (header only, no graves) has the band', (
      tester,
    ) async {
      await _pump(
        tester,
        const <Grave>[],
        header: const Text('The earth would not open.'),
      );
      _expectBand(tester);
    });

    testWidgets('All_Risen_State: one Ground_Band, no Ground_Field', (
      tester,
    ) async {
      await _pump(tester, <Grave>[_risen(1), _risen(2)]);
      _expectBand(tester);
    });

    for (final double height in <double>[500, 900]) {
      testWidgets('band is 34% of a $height px Scene_Box', (tester) async {
        await _pump(tester, const <Grave>[], height: height);
        _expectBand(tester);
      });
    }

    testWidgets('the band stays at its place when the content scrolls', (
      tester,
    ) async {
      await _pump(tester, const <Grave>[], header: _tallHeader);
      final Rect before = tester.getRect(_band);
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(of: _scroll, matching: find.byType(Scrollable)).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(500));
      scrollable.position.jumpTo(500);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_band), before);
      _expectBand(tester);
    });
  });

  group('switching states', () {
    testWidgets('empty to rows and back swaps the two in the same frame', (
      tester,
    ) async {
      _setView(tester, 400, 700);
      await tester.pumpWidget(_host(const <Grave>[]));
      expect(_band, findsOneWidget);
      expect(_field, findsNothing);

      await tester.pumpWidget(_host(<Grave>[_grave(0), _grave(1)]));
      expect(tester.takeException(), isNull);
      expect(_field, findsOneWidget);
      expect(_band, findsNothing);
      await tester.pump();
      await tester.pump();
      _expectHorizonAtBase(tester);

      await tester.pumpWidget(_host(const <Grave>[]));
      expect(tester.takeException(), isNull);
      expect(_band, findsOneWidget);
      expect(_field, findsNothing);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      _expectBand(tester);
    });

    testWidgets('rows to All_Risen_State and back throws nothing', (
      tester,
    ) async {
      await _pump(tester, <Grave>[_grave(0)]);
      await _update(tester, <Grave>[_risen(0)]);
      expect(tester.takeException(), isNull);
      _expectBand(tester);
      await _update(tester, <Grave>[_risen(0), _grave(0)]);
      expect(_field, findsOneWidget);
      expect(_band, findsNothing);
      _expectHorizonAtBase(tester);
    });
  });

  group('the Horizon follows the First_Row_Base', () {
    testWidgets('adding and deleting a grave moves the Horizon', (
      tester,
    ) async {
      await _pump(tester, <Grave>[_grave(0), _grave(2)]);
      _expectHorizonAtBase(tester);

      // A new first grave with a long, wrapping name.
      await _update(tester, <Grave>[_grave(1), _grave(0), _grave(2)]);
      _expectHorizonAtBase(tester);

      // Delete it again and then the new first one.
      await _update(tester, <Grave>[_grave(0), _grave(2)]);
      _expectHorizonAtBase(tester);
      await _update(tester, <Grave>[_grave(2)]);
      _expectHorizonAtBase(tester);
    });

    testWidgets('a column count change recomputes the Horizon', (tester) async {
      final List<Grave> graves = <Grave>[for (int i = 0; i < 8; i++) _grave(i)];
      await _pump(tester, graves, width: 700);
      _expectHorizonAtBase(tester);

      // 700 px: one column. 720 px: two columns or more.
      tester.view.physicalSize = const Size(720, 700);
      await tester.pump();
      await tester.pump();
      _expectHorizonAtBase(tester);

      tester.view.physicalSize = const Size(1280, 700);
      await tester.pump();
      await tester.pump();
      _expectHorizonAtBase(tester);

      tester.view.physicalSize = const Size(700, 700);
      await tester.pump();
      await tester.pump();
      _expectHorizonAtBase(tester);
    });

    testWidgets('a rising grave keeps the Horizon in place', (tester) async {
      await _pump(tester, <Grave>[_grave(0), _grave(2)], reduced: false);
      _expectHorizonAtBase(tester);

      // The new first grave rises out of the ground.
      await _update(tester, <Grave>[
        _grave(1),
        _grave(0),
        _grave(2),
      ], reduced: false);
      final double before = _horizon(tester);
      _expectHorizonAtBase(tester);

      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.hasRunningAnimations, isTrue);
      expect(tester.takeException(), isNull);
      expect(_horizon(tester), closeTo(before, 0.5));

      await tester.pump(const Duration(milliseconds: 250));
      expect(_horizon(tester), closeTo(before, 0.5));

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(_horizon(tester), closeTo(before, 0.5));
      _expectHorizonAtBase(tester);
    });
  });

  group('the ground is not interactive and not semantic', () {
    bool isGroundWrapper(Widget w) =>
        w is IgnorePointer &&
        w.ignoring &&
        w.child is ExcludeSemantics &&
        (w.child! as ExcludeSemantics).excluding &&
        _isGround((w.child! as ExcludeSemantics).child ?? const SizedBox());

    testWidgets('the Ground_Field has IgnorePointer and ExcludeSemantics', (
      tester,
    ) async {
      await _pump(tester, <Grave>[_grave(0)]);
      expect(find.byWidgetPredicate(isGroundWrapper), findsOneWidget);
      expect(
        find.ancestor(of: _field, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
    });

    testWidgets('the Ground_Band has IgnorePointer and ExcludeSemantics', (
      tester,
    ) async {
      await _pump(tester, const <Grave>[]);
      expect(find.byWidgetPredicate(isGroundWrapper), findsOneWidget);
      expect(
        find.descendant(
          of: _band,
          matching: find.byWidgetPredicate(isGroundWrapper),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tap on the band area reaches the control under it', (
      tester,
    ) async {
      int taps = 0;
      await _pump(
        tester,
        const <Grave>[],
        header: SizedBox(
          height: 560,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              key: _tapKey,
              onPressed: () => taps++,
              child: const Text('Tap'),
            ),
          ),
        ),
      );
      final Rect band = tester.getRect(_band);
      final Offset center = tester.getCenter(find.byKey(_tapKey));
      expect(band.contains(center), isTrue);
      await tester.tap(find.byKey(_tapKey));
      expect(taps, 1);
    });

    testWidgets('a tap on the Ground_Field reaches the control above it', (
      tester,
    ) async {
      final List<Grave> deleted = <Grave>[];
      await _pump(tester, <Grave>[_grave(0)], onDelete: deleted.add);
      final Rect ground = tester.getRect(_field);
      final Finder button = find.text(GraveyardCopy.delete);
      expect(ground.contains(tester.getCenter(button)), isTrue);
      await tester.tap(button);
      await tester.pump();
      expect(deleted, hasLength(1));
    });

    testWidgets('the ground adds no semantics node', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      Rect globalRect(SemanticsNode node) {
        Rect rect = node.rect;
        SemanticsNode? n = node;
        while (n != null) {
          final Matrix4? t = n.transform;
          if (t != null) rect = MatrixUtils.transformRect(t, rect);
          n = n.parent;
        }
        return rect;
      }

      List<SemanticsNode> nodes() {
        final List<SemanticsNode> out = <SemanticsNode>[];
        void walk(SemanticsNode node) {
          out.add(node);
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
        return out;
      }

      for (final List<Grave> graves in <List<Grave>>[
        <Grave>[_grave(0), _grave(1)],
        const <Grave>[],
      ]) {
        await _pump(tester, graves);
        final Finder ground = graves.isEmpty ? _band : _field;
        final Rect rect = tester.getRect(ground);
        for (final SemanticsNode node in nodes()) {
          final Rect r = globalRect(node);
          final bool same =
              (r.left - rect.left).abs() < 0.5 &&
              (r.top - rect.top).abs() < 0.5 &&
              (r.width - rect.width).abs() < 0.5 &&
              (r.height - rect.height).abs() < 0.5;
          expect(same, isFalse, reason: 'a node covers the ground');
        }
      }
      handle.dispose();
    });
  });

  group('motion, sky and fog', () {
    testWidgets('Reduced_Motion paints a static Field and runs no animation', (
      tester,
    ) async {
      await _pump(tester, <Grave>[_grave(0), _grave(1)]);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.widget<CustomPaint>(_field).painter, isA<GroundPainter>());
    });

    testWidgets('Reduced_Motion paints a static Band and runs no animation', (
      tester,
    ) async {
      await _pump(tester, const <Grave>[]);
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester.widget<CustomPaint>(_anyGround).painter,
        isA<GroundPainter>(),
      );
      expect(tester.takeException(), isNull);
    });

    for (final (String, List<Grave>) state in <(String, List<Grave>)>[
      ('rows', <Grave>[_grave(0), _grave(1)]),
      ('empty', <Grave>[]),
      ('all risen', <Grave>[_risen(1)]),
    ]) {
      testWidgets('${state.$1}: one Night_Sky, Fog_Layer above the scroll', (
        tester,
      ) async {
        await _pump(tester, state.$2);
        final int skies = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((p) => p.painter is NightSkyPainter)
            .length;
        expect(skies, 1);
        final Finder fog = find.byKey(const ValueKey<String>('fog-layer'));
        expect(fog, findsOneWidget);
        expect(
          find.descendant(of: fog, matching: find.byType(FogBackground)),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: _scroll.first,
            matching: find.byType(FogBackground),
          ),
          findsWidgets,
        );
        expect(find.descendant(of: fog, matching: _scroll), findsWidgets);
      });
    }
  });
}
