import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/scene/crack.dart';
import 'package:graveyard/src/ui/arch_epitaph.dart';
import 'package:graveyard/src/ui/crack_painter.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);
final int _todayEpoch = CalendarDate(1970, 1, 1).daysUntil(_today);

const String _description =
    'A long description of the project that wraps onto several lines so the '
    'stone is as tall as it can get and the text fills the content box';

Grave _grave(int ageDays, {String id = 'b', String name = 'atom'}) =>
    Grave.github(
      id: id,
      name: name,
      dateOfDeath: CalendarDate.fromEpochDay(_todayEpoch - ageDays),
      repo: const RepoInfo(
        fullName: 'atom/atom',
        stars: 60681,
        archived: true,
        description: _description,
      ),
    );

Finder _cracks([String id = 'b']) => find.byKey(ValueKey<String>('cracks-$id'));

Future<void> _pump(
  WidgetTester tester,
  Grave grave, {
  ThemeData? theme,
  double width = 300,
  double scale = 1,
  bool reduced = false,
  VoidCallback? onDelete,
  int rebuild = 0,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? CoffinTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduced,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            SizedBox(height: rebuild.toDouble()),
            Center(
              child: SizedBox(
                width: width,
                child: GraveTombstone(
                  grave: grave,
                  today: _today,
                  onDelete: onDelete ?? () {},
                  seanceAi: buildSeanceAi(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

List<Crack> _crackList(WidgetTester tester, [String id = 'b']) {
  final paint = tester.widget<CustomPaint>(_cracks(id));
  return (paint.painter! as CrackPainter).cracks;
}

CrackPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_cracks()).painter! as CrackPainter;

Rect _boundsOf(Crack crack) {
  var rect = Rect.fromLTRB(
    crack.points.first.x.toDouble(),
    crack.points.first.y.toDouble(),
    crack.points.first.x.toDouble(),
    crack.points.first.y.toDouble(),
  );
  for (final p in crack.points) {
    rect = rect.expandToInclude(
      Rect.fromLTWH(p.x.toDouble(), p.y.toDouble(), 0, 0),
    );
  }
  return rect.inflate(0.75);
}

/// Rects of every rendered text of the stone, in the crack layer's space.
List<Rect> _textRects(WidgetTester tester) {
  final layer = tester.renderObject<RenderBox>(_cracks());
  final texts = <Finder>[
    find.descendant(
      of: find.byType(TombstoneCard),
      matching: find.byType(Text),
    ),
    find.descendant(of: find.byType(ArchEpitaph), matching: find.byType(Text)),
  ];
  final rects = <Rect>[];
  for (final finder in texts) {
    for (final element in finder.evaluate()) {
      final box = element.renderObject!;
      RenderParagraph? paragraph;
      void visit(RenderObject o) {
        if (o is RenderParagraph && paragraph == null) paragraph = o;
        o.visitChildren(visit);
      }

      visit(box);
      final p = paragraph!;
      rects.add(
        MatrixUtils.transformRect(
          p.getTransformTo(layer),
          Offset.zero & p.size,
        ),
      );
    }
  }
  return rects;
}

void main() {
  group('presence', () {
    testWidgets('1826 days has 1 to 3 cracks on a keyed CustomPaint', (
      tester,
    ) async {
      await _pump(tester, _grave(1826));
      expect(_cracks(), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.widget(_cracks()), isA<CustomPaint>());
      expect(_crackList(tester).length, inInclusiveRange(1, 3));
    });

    for (final age in <int>[1825, 1824, 0]) {
      testWidgets('$age days has no crack layer', (tester) async {
        await _pump(tester, _grave(age));
        expect(_cracks(), findsNothing);
      });
    }
  });

  group('cracks keep clear of the text', () {
    for (final width in <double>[240, 270, 300]) {
      for (final scale in <double>[1, 1.5, 2]) {
        testWidgets('width $width, text scale $scale', (tester) async {
          await _pump(tester, _grave(3650), width: width, scale: scale);
          final cracks = _crackList(tester);
          expect(cracks, isNotEmpty);
          final rects = _textRects(tester);
          // title, date line, Dead_For, full name, stars, description, epitaph
          expect(rects.length, greaterThanOrEqualTo(5));
          for (final crack in cracks) {
            final bounds = _boundsOf(crack);
            for (final rect in rects) {
              expect(
                bounds.overlaps(rect),
                isFalse,
                reason: 'crack $bounds hits text $rect',
              );
            }
          }
        });
      }
    }
  });

  group('stability', () {
    testWidgets('same cracks after a rebuild and after a resize', (
      tester,
    ) async {
      await _pump(tester, _grave(3650));
      final first = _crackList(tester);
      await _pump(tester, _grave(3650), rebuild: 10);
      expect(_crackList(tester), first);
      await _pump(tester, _grave(3650), width: 240);
      await _pump(tester, _grave(3650));
      expect(_crackList(tester), first);
    });

    testWidgets('same cracks with disableAnimations true and false, '
        'and the painter schedules no frame', (tester) async {
      await _pump(tester, _grave(3650));
      final moving = _crackList(tester);

      await _pump(tester, _grave(3650), reduced: true);
      expect(_crackList(tester), moving);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('semantics', () {
    testWidgets('the crack layer has no node and the label has no mention', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _grave(3650));
      expect(
        find.ancestor(of: _cracks(), matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
      expect(tester.renderObject(_cracks()).debugSemantics, isNull);
      final stone = tester.getSemantics(find.byType(TombstoneCard));
      expect(stone.label.toLowerCase(), isNot(contains('crack')));
      final label = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label ?? '')
          .join(' ')
          .toLowerCase();
      expect(label, isNot(contains('crack')));
      handle.dispose();
    });
  });

  group('color', () {
    for (final entry in <String, ThemeData>{
      'dark': CoffinTheme.dark(),
      'daylight': CoffinTheme.light(),
    }.entries) {
      testWidgets('painter color is the background token: ${entry.key}', (
        tester,
      ) async {
        await _pump(tester, _grave(3650), theme: entry.value);
        final tokens = entry.value.brightness == Brightness.dark
            ? CoffinColorTokens.night
            : CoffinColorTokens.daylight;
        final color = _painter(tester).color;
        expect(color.withValues(alpha: 1), tokens.background);
        expect(color.a, closeTo(0.7, 0.01));
      });
    }
  });

  group('delete control', () {
    testWidgets('keeps its 48 by 48 target and is hit-testable', (
      tester,
    ) async {
      var deleted = 0;
      await _pump(tester, _grave(3650), onDelete: () => deleted++);
      final size = tester.getSize(
        find.widgetWithText(TextButton, GraveyardCopy.delete),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.widgetWithText(TextButton, GraveyardCopy.delete));
      expect(deleted, 1);
    });
  });

  group('refreshToday', () {
    testWidgets('crossing the threshold adds the cracks and plays no Rise', (
      tester,
    ) async {
      final grave = _grave(1825);
      Future<void> pumpScene(CalendarDate today) => tester.pumpWidget(
        MaterialApp(
          theme: CoffinTheme.dark(),
          home: Scaffold(
            body: GraveyardScene(
              graves: <Grave>[grave],
              today: today,
              onDelete: (_) {},
              seanceAi: buildSeanceAi(),
            ),
          ),
        ),
      );

      await pumpScene(_today);
      expect(_cracks(), findsNothing);

      await pumpScene(CalendarDate.fromEpochDay(_todayEpoch + 1));
      expect(_cracks(), findsOneWidget);
      expect(_crackList(tester).length, inInclusiveRange(1, 3));
      expect(
        tester.widget<GraveTombstone>(find.byType(GraveTombstone)).riseProgress,
        1,
      );
    });
  });
}
