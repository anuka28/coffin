import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/scene/scene_layout.dart';
import 'package:graveyard/src/domain/scene/weathering.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/seance_control.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/fake_coffin_ai.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);

Grave _grave(String id, {String? name}) => Grave.manual(
  id: id,
  name: name ?? 'Project $id',
  dateOfDeath: CalendarDate(2024, 1, 3),
);

// One ThemeData for the whole file, so no theme tween keeps a ticker running.
final ThemeData _theme = CoffinTheme.dark();

Widget _app(Widget body, {bool disableAnimations = true}) => MaterialApp(
  theme: _theme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: Scaffold(body: body),
);

Widget _tombstone(Grave grave, {VoidCallback? onDelete, CoffinAI? ai}) => _app(
  SingleChildScrollView(
    child: Center(
      child: GraveTombstone(
        grave: grave,
        today: _today,
        onDelete: onDelete ?? () {},
        seanceAi: ai ?? FakeCoffinAI.replying('A calm verdict.'),
      ),
    ),
  ),
);

Widget _scene(List<Grave> graves) => _app(
  GraveyardScene(
    graves: graves,
    today: _today,
    onDelete: (_) {},
    seanceAi: FakeCoffinAI.replying('A calm verdict.'),
  ),
);

Finder get _button => find.descendant(
  of: find.byType(SeanceControl),
  matching: find.byType(TextButton),
);

void main() {
  final grave = Grave.manual(
    id: 'g1',
    name: 'Ghost',
    dateOfDeath: CalendarDate(2024, 1, 1),
  );

  Future<void> pumpControl(WidgetTester tester, {VoidCallback? onPressed}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SeanceControl(grave: grave, onPressed: onPressed ?? () {}),
            ),
          ),
        ),
      );

  group('the control alone', () {
    testWidgets('shows the visible text and is at least 48x48', (tester) async {
      await pumpControl(tester);
      expect(find.text('Hold a séance'), findsOneWidget);
      expect(find.text(GraveyardCopy.seanceControlText), findsOneWidget);
      final size = tester.getSize(find.byType(TextButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('exposes one labelled button node that names the grave', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpControl(tester);
      final finder = find.bySemanticsLabel('Hold a séance for Ghost');
      expect(finder, findsOneWidget);
      final data = tester.getSemantics(finder);
      expect(data.label, GraveyardCopy.seanceControlLabel('Ghost'));
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('activates on tap, Enter and Space', (tester) async {
      var taps = 0;
      await pumpControl(tester, onPressed: () => taps++);
      await tester.tap(find.byType(TextButton));
      expect(taps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 3);
    });

    testWidgets('keyboard focus is visible as a state of the button', (
      tester,
    ) async {
      await pumpControl(tester);
      Finder focused() {
        final context = FocusManager.instance.primaryFocus?.context;
        return find.descendant(
          of: find.byType(TextButton),
          matching: find.byElementPredicate((e) => e == context),
        );
      }

      expect(focused(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focused(), findsOneWidget);
      expect(_overlayAt(tester, <WidgetState>{WidgetState.focused}), isTrue);
    });

    testWidgets('hover and press show a state and do not throw', (
      tester,
    ) async {
      await pumpControl(tester);
      expect(_overlayAt(tester, <WidgetState>{WidgetState.hovered}), isTrue);
      expect(_overlayAt(tester, <WidgetState>{WidgetState.pressed}), isTrue);
      expect(_overlayAt(tester, <WidgetState>{}), isFalse);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(TextButton)));
      await tester.pump(const Duration(milliseconds: 200));
      final press = await tester.startGesture(
        tester.getCenter(find.byType(TextButton)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await press.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });

  group('on a tombstone', () {
    testWidgets('lies below the stone and overlaps no text or the delete', (
      tester,
    ) async {
      for (final g in <Grave>[
        _grave('a'),
        Grave.manual(
          id: 'old',
          name: 'A rather long project name that wraps over lines',
          dateOfDeath: CalendarDate(2015, 1, 1),
        ),
      ]) {
        await tester.pumpWidget(_tombstone(g));
        final stone = tester.getRect(
          find.ancestor(
            of: find.byType(TombstoneCard),
            matching: find.byType(Opacity),
          ),
        );
        final control = tester.getRect(find.byType(SeanceControl));
        final controlButton = tester.getRect(_button);
        final delete = tester.getRect(
          find.widgetWithText(TextButton, GraveyardCopy.delete),
        );
        expect(control.top, greaterThanOrEqualTo(stone.bottom - 0.01));
        expect(controlButton.overlaps(delete), isFalse);
        final texts = find.descendant(
          of: find.byType(GraveTombstone),
          matching: find.byType(Text),
        );
        for (final element in texts.evaluate()) {
          if (find
              .descendant(
                of: find.byType(SeanceControl),
                matching: find.byWidget(element.widget),
              )
              .evaluate()
              .isNotEmpty) {
            continue;
          }
          if (find
              .descendant(
                of: find.widgetWithText(TextButton, GraveyardCopy.delete),
                matching: find.byWidget(element.widget),
              )
              .evaluate()
              .isNotEmpty) {
            continue;
          }
          final rect = tester.getRect(find.byWidget(element.widget));
          expect(
            controlButton.overlaps(rect),
            isFalse,
            reason: 'text ${(element.widget as Text).data}',
          );
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('opens the sheet for that grave', (tester) async {
      final g = _grave('a', name: 'Spooky');
      await tester.pumpWidget(_tombstone(g));
      expect(find.byType(SeanceSheet), findsNothing);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(find.byType(SeanceSheet), findsOneWidget);
      expect(tester.widget<SeanceSheet>(find.byType(SeanceSheet)).grave, g);
      expect(find.text('Spooky'), findsWidgets);
    });

    testWidgets('opens no second sheet while one is open', (tester) async {
      await tester.pumpWidget(_tombstone(_grave('a')));
      final spot = tester.getCenter(_button);
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(find.byType(SeanceSheet), findsOneWidget);
      // The sheet and its barrier cover the control, so a tap there never
      // opens a second sheet.
      await tester.tapAt(spot);
      await tester.pump();
      expect(find.byType(SeanceSheet).evaluate().length, lessThanOrEqualTo(1));
      await tester.pumpAndSettle();
      expect(find.byType(SeanceSheet).evaluate().length, lessThanOrEqualTo(1));
      if (find.byType(SeanceSheet).evaluate().isNotEmpty) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      expect(find.byType(SeanceSheet), findsNothing);
      // The control still works afterwards.
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(find.byType(SeanceSheet), findsOneWidget);
    });
  });

  group('scene layout', () {
    for (final width in <double>[360, 768, 1280]) {
      testWidgets('keeps the columns, width and tilt at $width px', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final graves = List<Grave>.generate(8, (i) => _grave('g$i'));
        await tester.pumpWidget(_scene(graves));
        await tester.pump(const Duration(milliseconds: 50));

        final columns = SceneLayout.columnsFor(width);
        final tops = <double>[
          for (var i = 0; i < graves.length; i++)
            tester.getTopLeft(find.byType(GraveTombstone).at(i)).dy,
        ];
        expect(
          tops.where((dy) => (dy - tops.first).abs() < 1).length,
          math.min(columns, graves.length),
        );
        final expectedWidth = SceneLayout.tombstoneWidthFor(width, columns);
        for (var i = 0; i < graves.length; i++) {
          final tombstone = find.byType(GraveTombstone).at(i);
          expect(
            tester.getSize(tombstone).width,
            closeTo(expectedWidth, 0.01),
            reason: 'tombstone $i width',
          );
          final controlRect = tester.getRect(
            find.descendant(
              of: tombstone,
              matching: find.byType(SeanceControl),
            ),
          );
          expect(
            controlRect.left,
            greaterThanOrEqualTo(tester.getTopLeft(tombstone).dx - 0.01),
          );
          expect(
            controlRect.right,
            lessThanOrEqualTo(tester.getTopRight(tombstone).dx + 0.01),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tilt of a stone is the one Weathering gives', (tester) async {
      final g = _grave('tilted');
      await tester.pumpWidget(_tombstone(g));
      final expected = Weathering.of(dayCount: 7, graveId: g.id).tiltRadians;
      final rotate = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(GraveTombstone),
              matching: find.ancestor(
                of: find.byType(TombstoneCard),
                matching: find.byType(Transform),
              ),
            ),
          )
          .singleWhere((t) => t.alignment == Alignment.bottomCenter);
      final m = rotate.transform.storage;
      expect(math.atan2(m[1], m[0]), closeTo(expected, 1e-9));
    });
  });
}

/// Whether the button paints a visible overlay in [states].
bool _overlayAt(WidgetTester tester, Set<WidgetState> states) {
  final context = tester.element(find.byType(TextButton));
  final button = tester.widget<TextButton>(find.byType(TextButton));
  // ignore: invalid_use_of_protected_member
  final themed = button.themeStyleOf(context);
  // ignore: invalid_use_of_protected_member
  final defaults = button.defaultStyleOf(context);
  final style = (button.style ?? const ButtonStyle())
      .merge(themed)
      .merge(defaults);
  final color = style.overlayColor?.resolve(states);
  return color != null && color.a > 0;
}
