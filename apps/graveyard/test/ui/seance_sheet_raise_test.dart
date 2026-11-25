import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
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
final ThemeData _theme = CoffinTheme.dark();
final Finder _raise = find.byKey(const ValueKey<String>('seance-raise'));
final Finder _sheet = find.byType(SeanceSheet);

Future<void> _open(
  WidgetTester tester,
  List<Grave> raised, {
  bool withRaise = true,
  double textScale = 1,
  double width = 400,
  CoffinAI? ai,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => showSeanceSheet(
              context,
              grave: _grave,
              today: _today,
              seanceAi: ai ?? FakeCoffinAI.replying('Boo.'),
              onRaise: withRaise ? raised.add : null,
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

void main() {
  testWidgets('no onRaise means no Raise control', (tester) async {
    await _open(tester, <Grave>[], withRaise: false);
    expect(_raise, findsNothing);
    expect(find.text(GraveyardCopy.raiseControlText), findsNothing);
  });

  testWidgets('shows the control with label, size and semantics, even while '
      'the verdict is pending', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final FakeCoffinAI ai = FakeCoffinAI.held('Boo.');
    await _open(tester, <Grave>[], ai: ai);
    expect(find.text(GraveyardCopy.raiseControlText), findsOneWidget);
    expect(tester.getSize(_raise).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(_raise).height, greaterThanOrEqualTo(48));
    expect(find.byType(GhostLoader), findsOneWidget);
    expect(
      find.bySemanticsLabel(GraveyardCopy.raiseControlLabel('Ghost')),
      findsOneWidget,
    );
    ai.release();
    await tester.pump();
    handle.dispose();
  });

  testWidgets('tap closes the sheet and calls onRaise once', (tester) async {
    final List<Grave> raised = <Grave>[];
    await _open(tester, raised);
    await tester.tap(_raise);
    await tester.tap(_raise, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_sheet, findsNothing);
    expect(raised, <Grave>[_grave]);
  });

  testWidgets('Enter and Space activate the focused control', (tester) async {
    for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ]) {
      final List<Grave> raised = <Grave>[];
      await _open(tester, raised);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(raised, hasLength(1), reason: '$key');
      expect(_sheet, findsNothing);
    }
  });

  testWidgets('close button and Escape never call onRaise', (tester) async {
    final List<Grave> raised = <Grave>[];
    await _open(tester, raised);
    await tester.tap(find.byKey(const ValueKey<String>('seance-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_sheet, findsNothing);

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_sheet, findsNothing);
    expect(raised, isEmpty);
  });

  testWidgets('control stays reachable at narrow width and text scale 2', (
    tester,
  ) async {
    await _open(tester, <Grave>[], textScale: 2, width: 320);
    expect(_raise, findsOneWidget);
    await tester.ensureVisible(_raise);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover, pressed and focused states are visible', (tester) async {
    await _open(tester, <Grave>[]);
    final ButtonStyleButton button = tester.widget<ButtonStyleButton>(_raise);
    // ignore: invalid_use_of_protected_member
    final ButtonStyle style = button.defaultStyleOf(tester.element(_raise));
    final WidgetStateProperty<Color?> overlay = style.overlayColor!;
    for (final WidgetState s in <WidgetState>[
      WidgetState.hovered,
      WidgetState.pressed,
      WidgetState.focused,
    ]) {
      expect(overlay.resolve(<WidgetState>{s})?.a ?? 0, greaterThan(0));
    }
    expect(overlay.resolve(<WidgetState>{})?.a ?? 0, 0);

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: tester.getCenter(_raise));
    await tester.pump();
    final Element hovered = tester.element(_raise);
    expect(hovered.mounted, isTrue);
    await mouse.removePointer();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    expect(focused, isNotNull);
    expect(
      find
              .descendant(of: _raise, matching: find.byWidget(focused!.widget))
              .evaluate()
              .isNotEmpty ||
          focused.findAncestorWidgetOfExactType<FilledButton>() != null,
      isTrue,
    );
  });

  for (final double width in <double>[320, 360, 768, 1280]) {
    for (final double scale in <double>[1, 1.5, 2]) {
      for (final String state in <String>['pending', 'ready', 'fallback']) {
        testWidgets('reachable at $width, x$scale, $state', (tester) async {
          final FakeCoffinAI ai = switch (state) {
            'pending' => FakeCoffinAI.held('Boo.'),
            'ready' => FakeCoffinAI.replying('Boo.'),
            _ => FakeCoffinAI.failing(),
          };
          final List<Grave> raised = <Grave>[];
          await _open(tester, raised, width: width, textScale: scale, ai: ai);
          expect(_raise, findsOneWidget);
          final Rect r = tester.getRect(_raise);
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.height, greaterThanOrEqualTo(48));
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(width));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.bottom, lessThanOrEqualTo(800));
          expect(tester.takeException(), isNull);
          await tester.tap(_raise);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(raised, hasLength(1));
          ai.release();
        });
      }
    }
  }

  testWidgets('tap outside and drag down never raise', (tester) async {
    final List<Grave> raised = <Grave>[];
    await _open(tester, raised);
    await tester.tapAt(const Offset(200, 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(raised, isEmpty);
    await _open(tester, raised);
    expect(_sheet, findsOneWidget);
    await tester.fling(_sheet, const Offset(0, 700), 2000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(raised, isEmpty);
  });

  testWidgets('the control leaves score, band, steps and verdict unchanged', (
    tester,
  ) async {
    List<String> texts() => tester
        .widgetList<Text>(
          find.descendant(of: _sheet, matching: find.byType(Text)),
        )
        .map((Text t) => t.data ?? '')
        .where((String t) => t != GraveyardCopy.raiseControlText)
        .toList();
    await _open(tester, <Grave>[], withRaise: false);
    final List<String> without = texts();
    await _open(tester, <Grave>[]);
    expect(texts(), without);
    expect(without, contains('Boo.'));
  });

  group('on the screen', () {
    ControllerHarness harness(Grave g) {
      final ControllerHarness h = ControllerHarness(
        seed: <String, String>{g.id: ControllerHarness.envelopeOf(g)},
      );
      addTearDown(h.dispose);
      return h;
    }

    Future<void> pumpScreen(WidgetTester tester, ControllerHarness h) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await h.controller.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: GraveyardScreen(
            controller: h.controller,
            seanceAi: FakeCoffinAI.replying('Boo.'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> openSeance(WidgetTester tester) async {
      await tester.tap(find.byType(SeanceControl).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    final Grave dead = Grave.manual(
      id: 'a',
      name: 'Ghost',
      dateOfDeath: CalendarDate(2025, 1, 1),
    );

    testWidgets('raising closes, dates Today, saves, plays once, once only', (
      tester,
    ) async {
      final ControllerHarness h = harness(dead);
      await pumpScreen(tester, h);
      await openSeance(tester);
      await tester.tap(_raise);
      await tester.tap(_raise, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_sheet, findsNothing);
      expect(h.controller.graves.single.risenOn, _today);
      expect((await h.repository.get('a'))?.risenOn, _today);
      expect(find.byType(ResurrectionPlay), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a grave removed before activation: closes, no play', (
      tester,
    ) async {
      final ControllerHarness h = harness(dead);
      await pumpScreen(tester, h);
      await openSeance(tester);
      await h.controller.deleteGrave('a');
      await tester.pump();
      await tester.tap(_raise);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(_sheet, findsNothing);
      expect(find.byType(ResurrectionPlay), findsNothing);
      expect(h.controller.graves, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a sheet for a playing grave has no Raise control', (
      tester,
    ) async {
      final ControllerHarness h = harness(dead);
      await pumpScreen(tester, h);
      await openSeance(tester);
      await tester.tap(_raise);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ResurrectionPlay), findsOneWidget);
      await openSeance(tester);
      expect(_sheet, findsOneWidget);
      expect(_raise, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
