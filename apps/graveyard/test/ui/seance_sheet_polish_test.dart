import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/fake_coffin_ai.dart';

// Feature: graveyard-polish, size of the séance sheet and its verdict slot.
// Validates: Requirements 7.1-7.8, 8.1-8.5, 12.8, 12.9

const List<double> _widths = <double>[320, 360, 768, 1280];
const List<double> _scales = <double>[1.0, 1.5, 2.0];
const String _closeKey = 'seance-close';
const String _verdict = 'The spirits stir, but only if you dig tonight.';

final CalendarDate _today = CalendarDate(2026, 5, 10);
final Grave _shortGrave = Grave.manual(
  id: 'g-short',
  name: 'Boo',
  dateOfDeath: CalendarDate(2025, 1, 1),
);
final Grave _longGrave = Grave.manual(
  id: 'g-long',
  name: 'The Very Long Named Project Of Many Forgotten Weekends',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

enum _State { pending, ready, fallback }

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Opens the sheet of [grave] with a text scale read from [scale], so a test
/// can change it while the sheet is open.
Future<void> _open(
  WidgetTester tester,
  CoffinAI ai, {
  required ValueNotifier<double> scale,
  Grave? grave,
}) async {
  final Grave opened = grave ?? _shortGrave;
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) =>
          ValueListenableBuilder<double>(
            valueListenable: scale,
            builder: (BuildContext _, double value, Widget? _) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(value)),
              child: child!,
            ),
          ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showSeanceSheet(
              context,
              grave: opened,
              today: _today,
              seanceAi: ai,
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

Future<void> _openAt(
  WidgetTester tester,
  CoffinAI ai, {
  double scale = 1,
  Grave? grave,
}) => _open(tester, ai, scale: ValueNotifier<double>(scale), grave: grave);

/// Lets the verdict of [state] arrive.
Future<void> _settle(WidgetTester tester, _State state) async {
  if (state != _State.ready) {
    await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
  }
  await tester.pump(const Duration(milliseconds: 600));
}

FakeCoffinAI _aiFor(_State state) => switch (state) {
  _State.pending => FakeCoffinAI.never(),
  _State.ready => FakeCoffinAI.replying(_verdict),
  _State.fallback => FakeCoffinAI.failing(),
};

/// The nearest Material above the sheet: the surface of the bottom sheet.
Finder get _surface => find.ancestor(
  of: find.byType(SeanceSheet),
  matching: find.byType(Material),
);

double _surfaceHeight(WidgetTester tester) =>
    tester.getSize(_surface.first).height;

Finder get _scrollArea => find.descendant(
  of: find.byType(SeanceSheet),
  matching: find.byType(SingleChildScrollView),
);

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byType(SeanceSheet),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

Finder get _close => find.byKey(const ValueKey<String>(_closeKey));

/// The Verdict_Slot: the box with a minimum height that holds the loader or
/// the verdict, found from [inner].
double _slotHeight(WidgetTester tester, Finder inner) {
  final Finder slot = find.ancestor(
    of: inner,
    matching: find.byWidgetPredicate(
      (Widget w) =>
          w is ConstrainedBox &&
          w.constraints.minHeight > 0 &&
          w.constraints.maxHeight == double.infinity &&
          w.constraints.maxWidth == double.infinity,
    ),
  );
  expect(slot, findsOneWidget);
  return tester.getSize(slot).height;
}

Finder get _verdictText => find.text(_verdict);

void _expectNoClippedText(WidgetTester tester) {
  final Rect area = tester.getRect(_scrollArea);
  for (final Element e
      in find
          .descendant(of: find.byType(SeanceSheet), matching: find.byType(Text))
          .evaluate()) {
    final Rect r = tester.getRect(find.byElementPredicate((x) => x == e));
    expect(r.left, greaterThanOrEqualTo(area.left - 0.5), reason: '$e');
    expect(r.right, lessThanOrEqualTo(area.right + 0.5), reason: '$e');
  }
}

void main() {
  group('sheet size', () {
    testWidgets('a short name at 1280 by 800 gives a small surface', (
      tester,
    ) async {
      _setView(tester, 1280, 800);
      await _openAt(tester, FakeCoffinAI.replying(_verdict));
      final double small = _surfaceHeight(tester);
      expect(small, lessThan(800 * 0.9));
      expect(_position(tester).maxScrollExtent, 0);
      // The surface is content sized: its height is the scroll content.
      expect(small, lessThan(600));

      final Grave tall = Grave.manual(
        id: 'g-tall',
        name: List<String>.filled(40, 'Forgotten Weekend').join(' '),
        dateOfDeath: CalendarDate(2025, 1, 1),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await _openAt(tester, FakeCoffinAI.replying(_verdict), grave: tall);
      expect(_surfaceHeight(tester), greaterThan(small + 100));
    });

    testWidgets('at 2.0 on 320 by 568 the content scrolls to every part', (
      tester,
    ) async {
      _setView(tester, 320, 568);
      await _openAt(
        tester,
        FakeCoffinAI.replying(_verdict),
        scale: 2,
        grave: _longGrave,
      );
      final ScrollPosition position = _position(tester);
      // The content is taller than the height offered.
      expect(position.maxScrollExtent, greaterThan(0));
      expect(_surfaceHeight(tester), lessThanOrEqualTo(568));
      expect(_surfaceHeight(tester), closeTo(568, 0.5));

      final Rect close = tester.getRect(_close);
      expect(close.top, greaterThanOrEqualTo(0));
      expect(close.bottom, lessThanOrEqualTo(568));
      expect(_close.hitTestable(), findsOneWidget);
      // The verdict is below the fold until the area is scrolled.
      expect(tester.getRect(_verdictText).bottom, greaterThan(568));

      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(_verdictText.hitTestable(), findsOneWidget);
      expect(tester.getRect(_verdictText).bottom, lessThanOrEqualTo(568));
      position.jumpTo(0);
      await tester.pump();
      expect(_close.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(_close);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SeanceSheet), findsNothing);
    });

    testWidgets('the close button works after scrolling down and back up', (
      tester,
    ) async {
      _setView(tester, 320, 568);
      await _openAt(
        tester,
        FakeCoffinAI.replying(_verdict),
        scale: 2,
        grave: _longGrave,
      );
      final ScrollPosition position = _position(tester);
      await tester.drag(_scrollArea, const Offset(0, -2000));
      await tester.pump();
      expect(position.pixels, position.maxScrollExtent);
      expect(_close.hitTestable(), findsNothing);
      await tester.drag(_scrollArea, const Offset(0, 2000));
      await tester.pump();
      expect(position.pixels, 0);
      expect(_close.hitTestable(), findsOneWidget);
      await tester.tap(_close);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SeanceSheet), findsNothing);
    });

    testWidgets('the 320 by 260 screen scrolls and keeps close reachable', (
      tester,
    ) async {
      _setView(tester, 320, 260);
      await _openAt(
        tester,
        FakeCoffinAI.replying(_verdict),
        scale: 2,
        grave: _longGrave,
      );
      final ScrollPosition position = _position(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(_surfaceHeight(tester), lessThanOrEqualTo(260));
      expect(tester.getRect(_close).top, greaterThanOrEqualTo(0));
      expect(_close.hitTestable(), findsOneWidget);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(_verdictText.hitTestable(), findsOneWidget);
      position.jumpTo(0);
      await tester.pump();
      await tester.tap(_close);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SeanceSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sheet grows with the text scale until the screen height', (
      tester,
    ) async {
      _setView(tester, 360, 1100);
      final ValueNotifier<double> scale = ValueNotifier<double>(1);
      await _open(tester, FakeCoffinAI.replying(_verdict), scale: scale);
      final List<double> heights = <double>[];
      for (final double s in <double>[1.0, 1.1, 1.2, 2.0]) {
        scale.value = s;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        heights.add(_surfaceHeight(tester));
      }
      // Below the available height the sheet grows with the text.
      expect(heights[1], greaterThan(heights[0]));
      expect(heights[2], greaterThan(heights[1]));
      expect(heights[2], lessThan(1100));
      expect(heights[0], lessThan(heights[2]));
      // At 2.0 the available height is reached and the area scrolls.
      expect(heights[3], closeTo(1100, 0.5));
      expect(_position(tester).maxScrollExtent, greaterThan(0));
    });
  });

  group('content width and alignment', () {
    for (final double width in _widths) {
      testWidgets('width of the content at $width', (tester) async {
        _setView(tester, width, 800);
        await _openAt(tester, FakeCoffinAI.replying(_verdict));
        final Rect area = tester.getRect(_scrollArea);
        if (width < 560) {
          expect(area.width, width);
        } else {
          expect(area.width, 560);
          expect(area.center.dx, closeTo(width / 2, 0.5));
        }
      });
    }

    for (final double scale in _scales) {
      testWidgets('the close button top aligns with the title at $scale', (
        tester,
      ) async {
        _setView(tester, 360, 800);
        await _openAt(
          tester,
          FakeCoffinAI.replying(_verdict),
          scale: scale,
          grave: _longGrave,
        );
        final Rect title = tester.getRect(find.text(_longGrave.name));
        expect(title.height, greaterThan(48));
        expect(tester.getRect(_close).top, closeTo(title.top, 0.5));
      });
    }
  });

  group('insets', () {
    testWidgets('the content stays above the keyboard inset', (tester) async {
      _setView(tester, 400, 1200);
      await _openAt(tester, FakeCoffinAI.replying(_verdict));
      final double without = _surfaceHeight(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await _openAt(tester, FakeCoffinAI.replying(_verdict));
      expect(
        tester.getRect(_verdictText).bottom,
        lessThanOrEqualTo(1200 - 300),
      );
      expect(tester.getRect(_scrollArea).bottom, lessThanOrEqualTo(1200 - 300));
      // The inset is made room for, not just covered.
      expect(_surfaceHeight(tester), closeTo(without + 300, 1));
    });

    testWidgets('the content stays above the safe-area inset', (tester) async {
      _setView(tester, 400, 1200);
      await _openAt(tester, FakeCoffinAI.replying(_verdict));
      final double without = _surfaceHeight(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));

      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      await _openAt(tester, FakeCoffinAI.replying(_verdict));
      expect(tester.getRect(_verdictText).bottom, lessThanOrEqualTo(1200 - 34));
      expect(tester.getRect(_scrollArea).bottom, lessThanOrEqualTo(1200 - 34));
      expect(_surfaceHeight(tester), closeTo(without + 34, 1));
    });
  });

  group('states without overflow', () {
    for (final _State state in _State.values) {
      for (final double width in _widths) {
        for (final double scale in _scales) {
          testWidgets('${state.name} at $width, scale $scale', (tester) async {
            _setView(tester, width, 800);
            await _openAt(
              tester,
              _aiFor(state),
              scale: scale,
              grave: _longGrave,
            );
            if (state != _State.pending) await _settle(tester, state);
            expect(tester.takeException(), isNull);
            switch (state) {
              case _State.pending:
                expect(find.byType(GhostLoader), findsOneWidget);
              case _State.ready:
                expect(_verdictText, findsOneWidget);
              case _State.fallback:
                expect(
                  find.text(GraveyardCopy.safeVerdictLine),
                  findsOneWidget,
                );
            }
            _expectNoClippedText(tester);
            if (state == _State.pending) {
              await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
            }
          });
        }
      }
    }
  });

  group('verdict slot', () {
    for (final _State to in <_State>[_State.ready, _State.fallback]) {
      for (final double width in _widths) {
        for (final double scale in _scales) {
          testWidgets(
            'slot is stable pending to ${to.name} at $width, $scale',
            (tester) async {
              _setView(tester, width, 800);
              final FakeCoffinAI ai = to == _State.ready
                  ? FakeCoffinAI.held(_verdict)
                  : FakeCoffinAI.never();
              await _openAt(tester, ai, scale: scale, grave: _longGrave);

              final Finder title = find.text(_longGrave.name);
              final Finder score = find.byType(DecoratedBox).first;
              final Finder steps = find.textContaining(RegExp(r'^[123]\.$'));
              final double slotBefore = _slotHeight(
                tester,
                find.byType(GhostLoader),
              );
              final double surfaceBefore = _surfaceHeight(tester);
              final List<Rect> before = <Rect>[
                tester.getRect(title),
                tester.getRect(score),
                for (int i = 0; i < 3; i++) tester.getRect(steps.at(i)),
              ];
              // A reserved slot is taller than the bare loader.
              expect(
                slotBefore,
                greaterThan(tester.getSize(find.byType(GhostLoader)).height),
              );

              if (to == _State.ready) {
                ai.release();
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 600));
              } else {
                await tester.pump(
                  verdictWaitLimit + const Duration(seconds: 1),
                );
                await tester.pump(const Duration(milliseconds: 600));
              }
              final Finder arrived = to == _State.ready
                  ? _verdictText
                  : find.text(GraveyardCopy.safeVerdictLine);
              expect(arrived, findsOneWidget);
              expect(find.byType(GhostLoader), findsNothing);

              expect(_slotHeight(tester, arrived), closeTo(slotBefore, 0.5));
              expect(_surfaceHeight(tester), closeTo(surfaceBefore, 0.5));
              final List<Rect> after = <Rect>[
                tester.getRect(title),
                tester.getRect(score),
                for (int i = 0; i < 3; i++) tester.getRect(steps.at(i)),
              ];
              for (int i = 0; i < before.length; i++) {
                expect(after[i].top, closeTo(before[i].top, 0.5), reason: '$i');
                expect(
                  after[i].left,
                  closeTo(before[i].left, 0.5),
                  reason: '$i',
                );
                expect(after[i].height, closeTo(before[i].height, 0.5));
              }
            },
          );
        }
      }
    }

    testWidgets('the slot is recomputed when the text scale changes', (
      tester,
    ) async {
      _setView(tester, 400, 3000);
      final ValueNotifier<double> scale = ValueNotifier<double>(1);
      await _open(tester, FakeCoffinAI.never(), scale: scale);
      final double atOne = _slotHeight(tester, find.byType(GhostLoader));
      scale.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final double atTwo = _slotHeight(tester, find.byType(GhostLoader));
      expect(atTwo, greaterThan(atOne + 20));

      // The same value as a sheet opened fresh at the new scale.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await _open(
        tester,
        FakeCoffinAI.never(),
        scale: ValueNotifier<double>(2),
      );
      expect(
        _slotHeight(tester, find.byType(GhostLoader)),
        closeTo(atTwo, 0.5),
      );
      await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
    });

    testWidgets('the slot is recomputed when the width changes', (
      tester,
    ) async {
      _setView(tester, 800, 3000);
      await _openAt(tester, FakeCoffinAI.never());
      final double wide = _slotHeight(tester, find.byType(GhostLoader));
      tester.view.physicalSize = const Size(320, 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final double narrow = _slotHeight(tester, find.byType(GhostLoader));
      expect(narrow, greaterThan(wide + 10));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await _openAt(tester, FakeCoffinAI.never());
      expect(
        _slotHeight(tester, find.byType(GhostLoader)),
        closeTo(narrow, 0.5),
      );
      await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
    });

    testWidgets('a verdict longer than the slot grows it and stays readable', (
      tester,
    ) async {
      // The sheet refuses a reply above 140 code units, so the longest
      // verdict that can reach it is 140 wide capitals. At text scale 2.0 on
      // a short screen the reservation is capped at the height of the scroll
      // area, and this verdict needs more than that.
      final String wide = 'W' * verdictMaxLength;
      _setView(tester, 320, 400);
      final FakeCoffinAI ai = FakeCoffinAI.held(wide);
      await _openAt(tester, ai, scale: 2);
      final double reserved = _slotHeight(tester, find.byType(GhostLoader));
      ai.release();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(wide), findsOneWidget);
      final double grown = _slotHeight(tester, find.text(wide));
      expect(grown, greaterThan(reserved + 1));
      expect(tester.getSize(find.text(wide)).height, closeTo(grown, 0.5));

      final ScrollPosition position = _position(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      // The last line is on screen (the verdict is taller than the area, so
      // its middle is not).
      final Rect last = tester.getRect(find.text(wide));
      expect(last.bottom, lessThanOrEqualTo(400));
      expect(last.bottom, greaterThan(300));
      // The scrolled distance covers the extra height of the verdict.
      expect(
        position.viewportDimension + position.maxScrollExtent,
        greaterThanOrEqualTo(last.height),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
