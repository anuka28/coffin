import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/seance_ai.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);

const List<double> _scales = <double>[1.0, 1.5, 2.0];

Future<void> _pump(
  WidgetTester tester, {
  required ThemeData theme,
  double scale = 1.0,
  VoidCallback? onDelete,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GraveTombstone(
            grave: Grave.manual(
              id: 'a',
              name: 'Old',
              dateOfDeath: CalendarDate(2024, 1, 3),
            ),
            today: _today,
            onDelete: onDelete ?? () {},
            seanceAi: buildSeanceAi(),
          ),
        ),
      ),
    ),
  );
}

/// The color the framework resolved for the text [label] inside [control].
Color _labelColor(WidgetTester tester, Finder control, String label) {
  final Finder rich = find.descendant(
    of: control,
    matching: find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == label,
    ),
  );
  expect(rich, findsOneWidget);
  final RichText widget = tester.widget<RichText>(rich);
  final Color? color = widget.text.style?.color;
  expect(color, isNotNull, reason: 'label "$label" has no resolved color');
  return color!;
}

Color _iconColor(WidgetTester tester, IconData icon) {
  final Finder rich = find.descendant(
    of: find.byIcon(icon),
    matching: find.byType(RichText),
  );
  expect(rich, findsOneWidget);
  final Color? color = tester.widget<RichText>(rich).text.style?.color;
  expect(color, isNotNull);
  return color!;
}

double _ratio(Color foreground, Color background) =>
    WcagContrast.ratio(foreground.toARGB32(), background.toARGB32());

Finder get _seanceButton =>
    find.widgetWithText(TextButton, GraveyardCopy.seanceControlText);

Finder get _deleteButton =>
    find.widgetWithText(TextButton, GraveyardCopy.delete);

void main() {
  final Map<String, (ThemeData, CoffinColorTokens)> themes =
      <String, (ThemeData, CoffinColorTokens)>{
        'night': (CoffinTheme.dark(), CoffinColorTokens.night),
        'daylight': (CoffinTheme.light(), CoffinColorTokens.daylight),
      };

  for (final MapEntry<String, (ThemeData, CoffinColorTokens)> entry
      in themes.entries) {
    final ThemeData theme = entry.value.$1;
    final CoffinColorTokens tokens = entry.value.$2;

    group('ground controls contrast, ${entry.key} theme', () {
      testWidgets('Séance label uses primary and reaches 4.5 on background', (
        tester,
      ) async {
        await _pump(tester, theme: theme);
        final Color color = _labelColor(
          tester,
          _seanceButton,
          GraveyardCopy.seanceControlText,
        );
        expect(color, tokens.primary);
        expect(
          _ratio(color, tokens.background),
          greaterThanOrEqualTo(WcagContrast.aaNormalText),
        );
      });

      testWidgets('Delete label uses primary and reaches 4.5 on background', (
        tester,
      ) async {
        await _pump(tester, theme: theme);
        final Color color = _labelColor(
          tester,
          _deleteButton,
          GraveyardCopy.delete,
        );
        expect(color, tokens.primary);
        expect(
          _ratio(color, tokens.background),
          greaterThanOrEqualTo(WcagContrast.aaNormalText),
        );
      });

      testWidgets('Delete icon uses primary and reaches 4.5 on background', (
        tester,
      ) async {
        await _pump(tester, theme: theme);
        final Color color = _iconColor(tester, Icons.delete_outline);
        expect(color, tokens.primary);
        expect(
          _ratio(color, tokens.background),
          greaterThanOrEqualTo(WcagContrast.aaNormalText),
        );
      });
    });
  }

  group('ground controls tap targets', () {
    for (final double scale in _scales) {
      testWidgets('Séance and Delete are at least 48 by 48 at scale $scale', (
        tester,
      ) async {
        var deleted = 0;
        await _pump(
          tester,
          theme: CoffinTheme.dark(),
          scale: scale,
          onDelete: () => deleted++,
        );
        expect(tester.takeException(), isNull);

        for (final Finder button in <Finder>[_seanceButton, _deleteButton]) {
          expect(button, findsOneWidget);
          final Size size = tester.getSize(button);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }

        // The whole padded area is the target: a tap near the top-left corner
        // of the button box reaches the control.
        final Rect rect = tester.getRect(_deleteButton);
        await tester.tapAt(rect.topLeft + const Offset(2, 2));
        expect(deleted, 1);
      });
    }
  });
}
