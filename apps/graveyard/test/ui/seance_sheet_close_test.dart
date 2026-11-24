import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/seance_control.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/controller_harness.dart';
import '../support/fake_coffin_ai.dart';

final Grave _grave = Grave.manual(
  id: 'g1',
  name: 'Ghost',
  dateOfDeath: CalendarDate(2025, 1, 1),
);
final CalendarDate _today = CalendarDate(2026, 5, 10);
final Finder _close = find.byKey(const ValueKey<String>('seance-close'));
final Finder _control = find.byType(SeanceControl);
final Finder _sheet = find.byType(SeanceSheet);

// One theme for the whole file, so no theme tween keeps a ticker running.
final ThemeData _theme = CoffinTheme.dark();

Widget _host(
  CoffinAI ai, {
  bool disableAnimations = false,
  ValueNotifier<bool>? showControl,
}) {
  final ValueNotifier<bool> visible = showControl ?? ValueNotifier<bool>(true);
  return MaterialApp(
    theme: _theme,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (BuildContext _, bool show, Widget? _) => show
                ? SeanceControl(
                    grave: _grave,
                    onPressed: () => showSeanceSheet(
                      context,
                      grave: _grave,
                      today: _today,
                      seanceAi: ai,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

/// Whether [focus] is the primary focus and lies inside a widget of [type].
bool _focusIsIn(Type type) {
  final BuildContext? context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  bool inside = false;
  context.visitAncestorElements((Element e) {
    if (e.widget.runtimeType == type) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

/// Moves keyboard focus onto the séance control and presses Enter.
Future<void> _openByKeyboard(WidgetTester tester) async {
  for (int i = 0; i < 6 && !_focusIsIn(SeanceControl); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(_focusIsIn(SeanceControl), isTrue);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _open(WidgetTester tester, CoffinAI ai) async {
  await tester.pumpWidget(_host(ai, disableAnimations: true));
  await tester.tap(_control);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  expect(_sheet, findsOneWidget);
}

Future<void> _settleClose(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

FadeTransition _reveal(WidgetTester tester) => tester.widget<FadeTransition>(
  find.descendant(of: _sheet, matching: find.byType(FadeTransition)).first,
);

void main() {
  group('closing', () {
    testWidgets('the close button is 48x48, labelled and closes', (
      tester,
    ) async {
      await _open(tester, FakeCoffinAI.replying('Boo.'));
      final Size size = tester.getSize(_close);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(GraveyardCopy.closeSeanceLabel, 'Close séance');
      expect(find.byTooltip('Close séance'), findsOneWidget);

      await tester.tap(_close);
      await _settleClose(tester);
      expect(_sheet, findsNothing);
    });

    testWidgets('Escape closes', (tester) async {
      await _open(tester, FakeCoffinAI.replying('Boo.'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settleClose(tester);
      expect(_sheet, findsNothing);
    });

    testWidgets('a tap outside closes', (tester) async {
      await _open(tester, FakeCoffinAI.replying('Boo.'));
      await tester.tapAt(const Offset(5, 5));
      await _settleClose(tester);
      expect(_sheet, findsNothing);
    });

    testWidgets('a drag down closes', (tester) async {
      await _open(tester, FakeCoffinAI.replying('Boo.'));
      await tester.fling(_sheet, const Offset(0, 600), 1500);
      await _settleClose(tester);
      expect(_sheet, findsNothing);
    });

    testWidgets('the scene keeps its scroll position and tombstones', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final List<Grave> seeded = <Grave>[
        for (int i = 0; i < 6; i++)
          Grave.manual(
            id: 'g$i',
            name: 'Project $i',
            dateOfDeath: CalendarDate(2025, 1, 1 + i),
          ),
      ];
      final ControllerHarness h = ControllerHarness(
        seed: <String, String>{
          for (final Grave g in seeded) g.id: ControllerHarness.envelopeOf(g),
        },
      );
      addTearDown(h.dispose);
      await h.controller.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: GraveyardScene(
              graves: h.controller.graves,
              today: h.controller.today,
              onDelete: (_) {},
              seanceAi: FakeCoffinAI.replying('Boo.'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final Finder scrollable = find
          .descendant(
            of: find.byType(GraveyardScene),
            matching: find.byType(Scrollable),
          )
          .first;
      final int count = h.controller.graves.length;
      await tester.ensureVisible(_control.at(count - 1));
      await tester.pump();
      final double offset = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      expect(offset, greaterThan(0));

      await tester.tap(_control.at(count - 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_sheet, findsOneWidget);
      await tester.tap(_close);
      await _settleClose(tester);

      expect(_sheet, findsNothing);
      expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
      expect(_control, findsNWidgets(count));
      expect(tester.takeException(), isNull);
    });

    testWidgets('closing during the Reveal does not throw', (tester) async {
      await tester.pumpWidget(_host(FakeCoffinAI.replying('Boo.')));
      await tester.tap(_control);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_reveal(tester).opacity.value, lessThan(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settleClose(tester);
      expect(_sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a late reply after closing is dropped', (tester) async {
      final FakeCoffinAI ai = FakeCoffinAI.held('Too late.');
      await _open(tester, ai);
      await tester.tap(_close);
      await _settleClose(tester);
      expect(_sheet, findsNothing);

      ai.release();
      await tester.pump();
      await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Too late.'), findsNothing);
    });
  });

  group('focus', () {
    testWidgets('moves into the sheet, stays inside, returns to the control', (
      tester,
    ) async {
      await tester.pumpWidget(_host(FakeCoffinAI.replying('Boo.')));
      await _openByKeyboard(tester);
      expect(_sheet, findsOneWidget);
      expect(_focusIsIn(SeanceSheet), isTrue);

      for (int i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(_focusIsIn(SeanceSheet), isTrue, reason: 'tab $i');
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_focusIsIn(SeanceSheet), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settleClose(tester);
      expect(_sheet, findsNothing);
      expect(_focusIsIn(SeanceControl), isTrue);
    });

    testWidgets('closing after the control left the tree does not throw', (
      tester,
    ) async {
      final ValueNotifier<bool> show = ValueNotifier<bool>(true);
      addTearDown(show.dispose);
      await tester.pumpWidget(
        _host(
          FakeCoffinAI.replying('Boo.'),
          disableAnimations: true,
          showControl: show,
        ),
      );
      await _openByKeyboard(tester);
      expect(_sheet, findsOneWidget);
      show.value = false;
      await tester.pump();
      expect(_control, findsNothing);

      await tester.tap(_close);
      await _settleClose(tester);
      expect(_sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('reduced motion', () {
    testWidgets('with disableAnimations the result shows at once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(FakeCoffinAI.replying('Boo.'), disableAnimations: true),
      );
      await tester.tap(_control);
      await tester.pump();
      expect(_reveal(tester).opacity.value, 1);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_reveal(tester).opacity.value, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('without it one Reveal of 300 to 600 ms plays once', (
      tester,
    ) async {
      await tester.pumpWidget(_host(FakeCoffinAI.replying('Boo.')));
      await tester.tap(_control);
      await tester.pump();
      expect(_reveal(tester).opacity.value, 0);

      await tester.pump(const Duration(milliseconds: 299));
      final double midway = _reveal(tester).opacity.value;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(1));

      await tester.pump(const Duration(milliseconds: 301));
      expect(_reveal(tester).opacity.value, 1);
      // The route transition has finished too, so nothing keeps running.
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pump(const Duration(seconds: 3));
      expect(_reveal(tester).opacity.value, 1);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('only the ghost loader keeps running while pending', (
      tester,
    ) async {
      final FakeCoffinAI ai = FakeCoffinAI.held('Boo.');
      await tester.pumpWidget(_host(ai));
      await tester.tap(_control);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(GhostLoader), findsOneWidget);
      expect(_reveal(tester).opacity.value, 1);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      ai.release();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(GhostLoader), findsNothing);
      expect(find.text('Boo.'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
