import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_result.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/seance_control.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/fake_coffin_ai.dart';

// Feature: graveyard-seance, layout of the control and the sheet.
// Validates: Requirements 8.1, 10.7, 11.1, 11.2, 11.5, 14.12

const List<double> _widths = <double>[320, 360, 768, 1280];
const List<double> _scales = <double>[1.0, 1.5, 2.0];
const String _closeKey = 'seance-close';

final CalendarDate _today = CalendarDate(2026, 5, 10);
final Grave _grave = Grave.manual(
  id: 'g1',
  name: 'The Very Long Named Project Of Many Forgotten Weekends',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

enum _State { pending, ready, fallback }

FakeCoffinAI _aiFor(_State state) => switch (state) {
  _State.pending => FakeCoffinAI.never(),
  _State.ready => FakeCoffinAI.replying(
    'A long verdict that has to wrap onto several lines on a narrow screen.',
  ),
  _State.fallback => FakeCoffinAI.failing(),
};

SeanceResult _expectedFor(Grave g) =>
    SeanceRules.evaluate(SeanceFacts.of(grave: g, today: _today));

SeanceResult _expected() => _expectedFor(_grave);

void _setView(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app({required double scale, required Widget home}) => MaterialApp(
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Future<void> _openSheet(
  WidgetTester tester,
  CoffinAI ai, {
  required double scale,
  Grave? grave,
}) async {
  final Grave opened = grave ?? _grave;
  await tester.pumpWidget(
    _app(
      scale: scale,
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

Future<void> _settleVerdict(WidgetTester tester, _State state) async {
  if (state == _State.fallback || state == _State.pending) {
    await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
  }
}

/// Every text of the sheet lies inside the sheet scroll area horizontally.
void _expectNoClippedText(WidgetTester tester) {
  final Rect area = tester.getRect(
    find.descendant(
      of: find.byType(SeanceSheet),
      matching: find.byType(SingleChildScrollView),
    ),
  );
  final Finder texts = find.descendant(
    of: find.byType(SeanceSheet),
    matching: find.byType(Text),
  );
  for (final Element e in texts.evaluate()) {
    final Rect r = tester.getRect(find.byElementPredicate((x) => x == e));
    expect(r.left, greaterThanOrEqualTo(area.left - 0.5), reason: '$e');
    expect(r.right, lessThanOrEqualTo(area.right + 0.5), reason: '$e');
  }
}

void main() {
  group('SeanceControl', () {
    for (final double width in _widths) {
      for (final double scale in _scales) {
        testWidgets('renders without overflow at $width wide, scale $scale', (
          tester,
        ) async {
          _setView(tester, width, 800);
          await tester.pumpWidget(
            _app(
              scale: scale,
              home: Scaffold(
                body: Center(
                  child: SeanceControl(grave: _grave, onPressed: () {}),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final Size size = tester.getSize(find.byType(TextButton));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          expect(
            tester.getRect(find.byType(TextButton)).right,
            lessThanOrEqualTo(width),
          );
        });
      }
    }
  });

  group('SeanceSheet', () {
    for (final _State state in _State.values) {
      for (final double width in _widths) {
        for (final double scale in _scales) {
          testWidgets(
            '${state.name}: no overflow at $width wide, scale $scale',
            (tester) async {
              _setView(tester, width, 800);
              await _openSheet(tester, _aiFor(state), scale: scale);
              if (state != _State.pending) {
                await _settleVerdict(tester, state);
                await tester.pump(const Duration(milliseconds: 600));
              }
              expect(tester.takeException(), isNull);
              expect(find.byType(SeanceSheet), findsOneWidget);
              final SeanceResult r = _expected();
              expect(find.text('${r.score}'), findsOneWidget);
              for (final k in r.steps) {
                expect(
                  find.text(GraveyardCopy.revivalStepText(k)),
                  findsOneWidget,
                );
              }
              switch (state) {
                case _State.pending:
                  expect(find.byType(GhostLoader), findsOneWidget);
                case _State.ready:
                  expect(find.byType(GhostLoader), findsNothing);
                  expect(find.textContaining('A long verdict'), findsOneWidget);
                case _State.fallback:
                  expect(
                    find.text(GraveyardCopy.safeVerdictLine),
                    findsOneWidget,
                  );
              }
              _expectNoClippedText(tester);
              if (state == _State.pending) {
                await tester.pump(
                  verdictWaitLimit + const Duration(seconds: 1),
                );
              }
            },
          );
        }
      }
    }

    for (final double width in <double>[768, 1280]) {
      testWidgets('content is at most 560 wide and centered at $width', (
        tester,
      ) async {
        _setView(tester, width, 800);
        await _openSheet(tester, FakeCoffinAI.replying('Boo.'), scale: 1.0);
        final Rect area = tester.getRect(
          find.descendant(
            of: find.byType(SeanceSheet),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        expect(area.width, lessThanOrEqualTo(560));
        expect(area.center.dx, closeTo(width / 2, 0.5));
        final Rect close = tester.getRect(
          find.byKey(const ValueKey<String>(_closeKey)),
        );
        expect(close.right, lessThanOrEqualTo(area.right));
        expect(close.left, greaterThanOrEqualTo(area.left));
      });
    }

    testWidgets('uses the full width on a narrow screen', (tester) async {
      _setView(tester, 320, 800);
      await _openSheet(tester, FakeCoffinAI.replying('Boo.'), scale: 1.0);
      final Rect area = tester.getRect(
        find.descendant(
          of: find.byType(SeanceSheet),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(area.width, 320);
    });

    for (final _State state in _State.values) {
      testWidgets('${state.name}: scrolls when short and keeps close '
          'reachable', (tester) async {
        _setView(tester, 320, 260);
        await _openSheet(tester, _aiFor(state), scale: 2.0, grave: _grave);
        if (state != _State.pending) {
          await _settleVerdict(tester, state);
          await tester.pump(const Duration(milliseconds: 600));
        }
        expect(tester.takeException(), isNull);

        final Finder scrollFinder = find.descendant(
          of: find.byType(SeanceSheet),
          matching: find.byType(Scrollable),
        );
        final ScrollableState scrollable = tester.state<ScrollableState>(
          scrollFinder,
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));

        final Finder close = find.byKey(const ValueKey<String>(_closeKey));
        expect(tester.getRect(close).top, greaterThanOrEqualTo(0));
        expect(close.hitTestable(), findsOneWidget);
        // The long name wraps past the button height, yet the button stays
        // aligned to the top of the title row, with no scrolling needed.
        final Rect title = tester.getRect(find.text(_grave.name));
        expect(title.height, greaterThan(48));
        expect(tester.getRect(close).top, closeTo(title.top, 0.5));
        expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(close).height, greaterThanOrEqualTo(48));

        // Scroll to the end: the verdict area is reachable.
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final Finder last = switch (state) {
          _State.pending => find.byType(GhostLoader),
          _State.ready => find.textContaining('A long verdict'),
          _State.fallback => find.text(GraveyardCopy.safeVerdictLine),
        };
        expect(last.hitTestable(), findsOneWidget);

        // Back at the top the close button is reachable and closes the sheet.
        scrollable.position.jumpTo(0);
        await tester.pump();
        expect(close.hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(SeanceSheet), findsNothing);
        if (state == _State.pending) {
          await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
        }
      });
    }
  });
}
