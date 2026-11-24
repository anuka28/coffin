import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/seance_ai.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);
final int _todayEpoch = CalendarDate(1970, 1, 1).daysUntil(_today);

const double _maxTilt = 3 * math.pi / 180;

Grave _grave(int ageDays) => Grave.github(
  id: 'b',
  name: 'atom',
  dateOfDeath: CalendarDate.fromEpochDay(_todayEpoch - ageDays),
  repo: const RepoInfo(
    fullName: 'atom/atom',
    stars: 60681,
    archived: true,
    description: ':atom: The hackable text editor',
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Grave grave, {
  ThemeData? theme,
  int rebuild = 0,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? CoffinTheme.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            SizedBox(height: rebuild.toDouble()),
            GraveTombstone(
              grave: grave,
              today: _today,
              onDelete: () {},
              seanceAi: buildSeanceAi(),
            ),
          ],
        ),
      ),
    ),
  ),
);

Finder get _tilt => find.descendant(
  of: find.byType(GraveTombstone),
  matching: find.byWidgetPredicate(
    (w) => w is Transform && w.alignment == Alignment.bottomCenter,
  ),
);

Finder get _halo => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint &&
      w.painter != null &&
      w.painter.runtimeType.toString() == '_FadeHaloPainter',
);

double _tiltOf(WidgetTester tester) {
  final m = tester.widget<Transform>(_tilt.first).transform;
  return math.atan2(m.storage[1], m.storage[0]);
}

Offset _baseCenter(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(find.byType(TombstoneCard));
  return box.localToGlobal(Offset(box.size.width / 2, box.size.height));
}

void main() {
  group('weathering', () {
    testWidgets('a ten-year-old grave tilts at most 3 degrees and has a halo', (
      tester,
    ) async {
      await _pump(tester, _grave(3650));
      final angle = _tiltOf(tester);
      expect(angle.abs(), greaterThan(0));
      expect(angle.abs(), lessThanOrEqualTo(_maxTilt + 1e-9));
      expect(_halo, findsOneWidget);
    });

    testWidgets('a fresh grave has no tilt and no halo', (tester) async {
      await _pump(tester, _grave(0));
      expect(_tiltOf(tester), 0);
      expect(_halo, findsNothing);
    });

    testWidgets('the tilt is the same after a rebuild', (tester) async {
      await _pump(tester, _grave(3650));
      final first = _tiltOf(tester);
      await _pump(tester, _grave(3650), rebuild: 10);
      expect(_tiltOf(tester), first);
      await _pump(tester, _grave(3650), theme: CoffinTheme.light());
      expect(_tiltOf(tester), first);
    });

    testWidgets('the base center stays on the ground when tilted', (
      tester,
    ) async {
      await _pump(tester, _grave(3650));
      final tilted = tester.getRect(_tilt.first);
      final base = _baseCenter(tester);
      expect(base.dx, closeTo(tilted.center.dx, 1e-6));
      expect(base.dy, closeTo(tilted.bottom, 1e-6));
    });
  });

  group('contrast', () {
    for (final theme in <String, ThemeData>{
      'dark': CoffinTheme.dark(),
      'daylight': CoffinTheme.light(),
    }.entries) {
      for (final age in <int>[0, 1825, 3650]) {
        testWidgets('text keeps 3.0 against the stone: ${theme.key}, $age days '
            '(${age > 1825 ? 'cracks' : 'no cracks'})', (tester) async {
          await _pump(tester, _grave(age), theme: theme.value);
          final cracks = find.byKey(const ValueKey<String>('cracks-b'));
          expect(cracks, age > 1825 ? findsOneWidget : findsNothing);

          final tokens = theme.value.brightness == Brightness.dark
              ? CoffinColorTokens.night
              : CoffinColorTokens.daylight;
          final stone = tokens.surface;
          final texts = find.descendant(
            of: find.byType(TombstoneCard),
            matching: find.byType(Text),
          );
          expect(texts, findsWidgets);
          for (final element in texts.evaluate()) {
            final text = element.widget as Text;
            final style = DefaultTextStyle.of(element).style.merge(text.style);
            final color = Color.alphaBlend(style.color!, stone);
            final ratio = WcagContrast.ratio(
              color.toARGB32(),
              stone.toARGB32(),
            );
            expect(
              ratio,
              greaterThanOrEqualTo(3.0),
              reason: '"${text.data}" ratio $ratio',
            );
          }
        });
      }
    }
  });
}
