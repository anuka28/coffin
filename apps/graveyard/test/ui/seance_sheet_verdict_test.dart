import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/fake_coffin_ai.dart';

// Feature: graveyard-polish, the Verdict_Block of the séance sheet.
// Validates: Requirements 9.1-9.9, 10.1-10.4, 12.8

const List<double> _widths = <double>[320, 360, 768, 1280];
const List<double> _scales = <double>[1.0, 1.5, 2.0];

final CalendarDate _today = CalendarDate(2026, 5, 10);
final Grave _grave = Grave.manual(
  id: 'g1',
  name: 'Ghost',
  dateOfDeath: CalendarDate(2025, 1, 1),
);

const String _shortVerdict = 'The lantern still flickers.';
const String _longVerdict =
    'The spirits whisper that this project still hums beneath the soil, '
    'and a single quiet evening of work could wake it from its long sleep.';

enum _Kind { ready, fallback }

String _textFor(_Kind kind) =>
    kind == _Kind.ready ? _longVerdict : GraveyardCopy.safeVerdictLine;

FakeCoffinAI _aiFor(_Kind kind) => kind == _Kind.ready
    ? FakeCoffinAI.replying(_longVerdict)
    : FakeCoffinAI.failing();

CoffinColorTokens _tokensOf(ThemeData theme) =>
    theme.brightness == Brightness.dark
    ? CoffinColorTokens.night
    : CoffinColorTokens.daylight;

void _setView(WidgetTester tester, double width, [double height = 1600]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester,
  CoffinAI ai, {
  double scale = 1.0,
  bool reduceMotion = true,
  ThemeData? theme,
  Duration settle = const Duration(milliseconds: 600),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
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
  if (settle > Duration.zero) await tester.pump(settle);
}

Finder get _sheet => find.byType(SeanceSheet);

Finder _verdictText(String verdict) =>
    find.descendant(of: _sheet, matching: find.text(verdict));

/// The `Stack` that holds the verdict text and its accent bar.
Finder _block(String verdict) => find
    .ancestor(of: _verdictText(verdict), matching: find.byType(Stack))
    .first;

/// The accent bar: the only `DecoratedBox` inside the verdict block.
Finder _bar(String verdict) => find.descendant(
  of: _block(verdict),
  matching: find.byWidgetPredicate(
    (Widget w) => w is DecoratedBox && w.decoration is BoxDecoration,
  ),
);

Finder _stepNumber(int n) =>
    find.descendant(of: _sheet, matching: find.text('$n.'));

Finder _raisedCard(CoffinColorTokens tokens) => find.descendant(
  of: _sheet,
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == tokens.raised,
  ),
);

/// The text of the first revival step of [_grave] on [_today].
String get _firstStepText => GraveyardCopy.revivalStepText(
  SeanceRules.evaluate(SeanceFacts.of(grave: _grave, today: _today))
      .steps
      .first,
);

Finder get _firstStep =>
    find.descendant(of: _sheet, matching: find.text(_firstStepText));

/// The right edge of the steps: the step texts fill the width of the steps.
double _stepsRight(WidgetTester tester) => tester.getRect(_firstStep).right;

Text _stepTextWidget(WidgetTester tester) => tester.widget<Text>(_firstStep);

Future<List<SemanticsNode>> _nodes(WidgetTester tester) async {
  final List<SemanticsNode> out = <SemanticsNode>[];
  void walk(SemanticsNode node) {
    out.add(node);
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(tester.getSemantics(_sheet));
  return out;
}

void main() {
  group('alignment with the steps', () {
    for (final _Kind kind in _Kind.values) {
      for (final double width in _widths) {
        for (final double scale in _scales) {
          testWidgets(
            'bar starts at the number column and block ends at the steps: '
            '${kind.name}, $width wide, scale $scale',
            (tester) async {
              _setView(tester, width);
              await _open(tester, _aiFor(kind), scale: scale);
              final String verdict = _textFor(kind);

              final Rect bar = tester.getRect(_bar(verdict));
              final Rect block = tester.getRect(_block(verdict));
              final Rect number = tester.getRect(_stepNumber(1));
              final Rect text = tester.getRect(_verdictText(verdict));

              expect(bar.left, closeTo(number.left, 0.5));
              expect(block.left, closeTo(bar.left, 0.01));
              expect(block.right, closeTo(_stepsRight(tester), 0.5));
              // The text sits inside the block and right of the bar.
              expect(text.left, greaterThan(bar.right));
              expect(text.right, lessThanOrEqualTo(block.right + 0.5));
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  group('style', () {
    testWidgets('the verdict font is larger than the step font', (
      tester,
    ) async {
      _setView(tester, 768);
      await _open(tester, _aiFor(_Kind.ready), scale: 1.5);
      final Text verdict = tester.widget<Text>(_verdictText(_longVerdict));
      final Text step = _stepTextWidget(tester);
      expect(verdict.style?.fontSize, isNotNull);
      expect(step.style?.fontSize, isNotNull);
      expect(verdict.style!.fontSize!, greaterThan(step.style!.fontSize!));
      // The rendered (scaled) size is larger as well.
      final RenderParagraph rv = tester.renderObject<RenderParagraph>(
        _verdictText(_longVerdict),
      );
      final RenderParagraph rs = tester.renderObject<RenderParagraph>(
        find.byWidget(step),
      );
      expect(
        rv.textScaler.scale(verdict.style!.fontSize!),
        greaterThan(rs.textScaler.scale(step.style!.fontSize!)),
      );
    });

    testWidgets('the safe verdict line has the style of a generated verdict', (
      tester,
    ) async {
      _setView(tester, 768);
      await _open(tester, FakeCoffinAI.replying(_shortVerdict));
      final TextStyle? generated = tester
          .widget<Text>(_verdictText(_shortVerdict))
          .style;

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));

      await _open(tester, FakeCoffinAI.failing());
      final Finder safe = _verdictText(GraveyardCopy.safeVerdictLine);
      expect(safe, findsOneWidget);
      final Text safeText = tester.widget<Text>(safe);
      expect(safeText.style, isNotNull);
      expect(safeText.style, generated);
      expect(safeText.textAlign, TextAlign.start);
      // The shared style is the verdict style, not the step style.
      expect(
        safeText.style!.fontSize,
        greaterThan(_stepTextWidget(tester).style!.fontSize!),
      );
    });

    testWidgets('the bar is 2 to 4 px wide and as tall as the verdict text', (
      tester,
    ) async {
      _setView(tester, 320);
      await _open(tester, _aiFor(_Kind.ready), scale: 2.0);
      final Rect bar = tester.getRect(_bar(_longVerdict));
      final Rect text = tester.getRect(_verdictText(_longVerdict));
      expect(bar.width, inInclusiveRange(2, 4));
      expect(bar.height, closeTo(text.height, 0.5));
      // The text is tall (it wraps), so the bar is not a short stub.
      expect(bar.height, greaterThan(60));
    });

    for (final ThemeData theme in <ThemeData>[
      CoffinTheme.dark(),
      CoffinTheme.light(),
    ]) {
      final CoffinColorTokens tokens = _tokensOf(theme);
      final String name = theme.brightness.name;

      testWidgets('colors come from the tokens and are readable: $name', (
        tester,
      ) async {
        _setView(tester, 768);
        await _open(tester, _aiFor(_Kind.ready), theme: theme);

        final DecoratedBox bar = tester.widget<DecoratedBox>(
          _bar(_longVerdict),
        );
        final Color barColor = (bar.decoration as BoxDecoration).color!;
        final Color textColor = tester
            .widget<Text>(_verdictText(_longVerdict))
            .style!
            .color!;
        expect(barColor, tokens.primary);
        expect(textColor, tokens.text);
        expect(barColor, isNot(tokens.surface));

        expect(
          WcagContrast.ratio(textColor.toARGB32(), tokens.surface.toARGB32()),
          greaterThanOrEqualTo(WcagContrast.aaNormalText),
        );
        expect(
          WcagContrast.ratio(barColor.toARGB32(), tokens.surface.toARGB32()),
          greaterThanOrEqualTo(3.0),
        );
      });
    }
  });

  group('wrapping and structure', () {
    testWidgets('a multi-line verdict wraps inside the block, start-aligned', (
      tester,
    ) async {
      _setView(tester, 320);
      await _open(tester, _aiFor(_Kind.ready), scale: 2.0);
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        _verdictText(_longVerdict),
      );
      final List<TextBox> boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: _longVerdict.length),
      );
      // The smallest left edge of each line is the left edge of the text.
      final Map<int, double> leftOfLine = <int, double>{};
      for (final TextBox box in boxes) {
        final int line = box.top.round();
        leftOfLine[line] = leftOfLine[line] == null
            ? box.left
            : (box.left < leftOfLine[line]! ? box.left : leftOfLine[line]!);
      }
      expect(leftOfLine.length, greaterThan(2));
      for (final MapEntry<int, double> e in leftOfLine.entries) {
        expect(e.value, closeTo(0, 0.01), reason: 'line at ${e.key}');
      }
      final Rect block = tester.getRect(_block(_longVerdict));
      final Rect text = tester.getRect(_verdictText(_longVerdict));
      expect(text.right, lessThanOrEqualTo(block.right + 0.5));
      // The block holds all lines: it is as tall as the text.
      expect(block.height, closeTo(text.height, 0.5));
    });

    testWidgets('the sheet order is title, score card, steps, verdict', (
      tester,
    ) async {
      _setView(tester, 768);
      await _open(tester, _aiFor(_Kind.ready));
      final CoffinColorTokens tokens = CoffinColorTokens.night;
      final double title = tester.getRect(find.text('Ghost')).top;
      final double card = tester.getRect(_raisedCard(tokens)).top;
      final double step1 = tester.getRect(_stepNumber(1)).top;
      final double step3 = tester.getRect(_stepNumber(3)).top;
      final double verdict = tester.getRect(_block(_longVerdict)).top;
      expect(title, lessThan(card));
      expect(card, lessThan(step1));
      expect(step1, lessThan(step3));
      expect(step3, lessThan(verdict));
    });

    testWidgets('one Icon, ten Text widgets and one raised DecoratedBox', (
      tester,
    ) async {
      _setView(tester, 768);
      await _open(tester, _aiFor(_Kind.ready));
      expect(
        find.descendant(of: _sheet, matching: find.byType(Icon)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _sheet, matching: find.byType(Text)),
        findsNWidgets(10),
      );
      expect(_raisedCard(CoffinColorTokens.night), findsOneWidget);
      // The bar is not a raised box, so it does not add to that count.
      final DecoratedBox bar = tester.widget<DecoratedBox>(_bar(_longVerdict));
      expect(
        (bar.decoration as BoxDecoration).color,
        isNot(CoffinColorTokens.night.raised),
      );
    });
  });

  group('semantics', () {
    testWidgets('the verdict is one live node with the verdict as label', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _setView(tester, 768);
      await _open(tester, _aiFor(_Kind.ready));
      final List<SemanticsNode> nodes = await _nodes(tester);
      final List<SemanticsNode> hits = nodes
          .where((SemanticsNode n) => n.label == _longVerdict)
          .toList();
      expect(hits, hasLength(1));
      expect(
        hits.first.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
      );
      expect(hits.first.childrenCount, 0);
      handle.dispose();
    });
  });

  group('fade', () {
    Finder fade() => find.descendant(
      of: _sheet,
      matching: find.ancestor(
        of: find.text(_longVerdict),
        matching: find.byType(FadeTransition),
      ),
    );

    testWidgets('fades in over 450 ms with motion allowed', (tester) async {
      _setView(tester, 768);
      await _open(
        tester,
        _aiFor(_Kind.ready),
        reduceMotion: false,
        settle: Duration.zero,
      );
      double opacity() =>
          tester.widget<FadeTransition>(fade().first).opacity.value;

      await tester.pump(const Duration(milliseconds: 100));
      final double early = opacity();
      expect(early, greaterThan(0));
      expect(early, lessThan(1));
      await tester.pump(const Duration(milliseconds: 200));
      final double mid = opacity();
      expect(mid, greaterThan(early));
      expect(mid, lessThan(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), lessThan(1), reason: 'still fading at about 400 ms');
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), 1.0);
    });

    testWidgets('appears at once with disableAnimations', (tester) async {
      _setView(tester, 768);
      await _open(
        tester,
        _aiFor(_Kind.ready),
        reduceMotion: true,
        settle: Duration.zero,
      );
      await tester.pump();
      expect(tester.widget<FadeTransition>(fade().first).opacity.value, 1.0);
    });
  });

  group('pending loader', () {
    for (final double scale in <double>[1.0, 2.0]) {
      testWidgets(
        'the GhostLoader stays centered in the slot at scale $scale',
        (tester) async {
          _setView(tester, 768);
          await _open(tester, FakeCoffinAI.never(), scale: scale);
          final Finder loader = find.descendant(
            of: _sheet,
            matching: find.byType(GhostLoader),
          );
          expect(loader, findsOneWidget);
          final Rect slot = tester.getRect(
            find.ancestor(of: loader, matching: find.byType(Center)).first,
          );
          final Rect ghost = tester.getRect(loader);
          // The slot is taller than the loader, so centering is a real test.
          expect(slot.height, greaterThan(ghost.height + 4));
          expect(ghost.center.dy, closeTo(slot.center.dy, 0.5));
          expect(ghost.center.dx, closeTo(slot.center.dx, 0.5));
          await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
        },
      );
    }
  });
}
