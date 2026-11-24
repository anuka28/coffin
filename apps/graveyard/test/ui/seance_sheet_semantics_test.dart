import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_result.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/fake_clock.dart';
import '../support/fake_coffin_ai.dart';

final Grave _grave = Grave.manual(
  id: 'g1',
  name: 'Ghost',
  dateOfDeath: CalendarDate(2025, 1, 1),
);
final FakeClock _clock = FakeClock(DateTime(2026, 5, 10, 12));
final CalendarDate _today = CalendarDate.fromDateTime(_clock.now());
const String _verdict = 'The lantern still flickers.';

SeanceResult _expected() =>
    SeanceRules.evaluate(SeanceFacts.of(grave: _grave, today: _today));

Future<void> _open(
  WidgetTester tester,
  FakeCoffinAI ai,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
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
  await tester.pump(const Duration(milliseconds: 600));
}

/// Every semantics node at or below [node], in tree order.
List<SemanticsNode> _all(SemanticsNode node) {
  final List<SemanticsNode> out = <SemanticsNode>[node];
  node.visitChildren((SemanticsNode child) {
    out.addAll(_all(child));
    return true;
  });
  return out;
}

List<SemanticsNode> _sheetNodes(WidgetTester tester) =>
    _all(tester.getSemantics(find.byType(SeanceSheet)));

SemanticsNode? _withLabel(List<SemanticsNode> nodes, String label) {
  final Iterable<SemanticsNode> hits = nodes.where(
    (SemanticsNode n) => n.label == label,
  );
  return hits.length == 1 ? hits.first : null;
}

/// Lets the wait limit of a never-answering fake pass, so no timer is left.
Future<void> _drain(WidgetTester tester) =>
    tester.pump(verdictWaitLimit + const Duration(seconds: 1));

int _argb(Color c) => c.toARGB32();

void main() {
  group('semantics', () {
    testWidgets('score, steps, live verdict, route name and no extra nodes', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final SeanceResult result = _expected();
      await _open(tester, FakeCoffinAI.replying(_verdict), CoffinTheme.dark());

      final List<SemanticsNode> nodes = _sheetNodes(tester);

      final String scoreLabel = GraveyardCopy.revivalScoreLabel(
        result.score,
        result.band,
      );
      expect(
        scoreLabel,
        'Revival score ${result.score} out of 100, '
        '${GraveyardCopy.revivalBandLabel(result.band)}',
      );
      expect(_withLabel(nodes, scoreLabel), isNotNull);

      final List<String> stepLabels = <String>[
        for (int i = 0; i < 3; i++)
          GraveyardCopy.revivalStepLabel(
            i + 1,
            3,
            GraveyardCopy.revivalStepText(result.steps[i]),
          ),
      ];
      for (final String label in stepLabels) {
        expect(_withLabel(nodes, label), isNotNull, reason: label);
      }
      expect(stepLabels.first, startsWith('Step 1 of 3: '));

      final SemanticsNode? verdict = _withLabel(nodes, _verdict);
      expect(verdict, isNotNull);
      expect(verdict!.getSemanticsData().flagsCollection.isLiveRegion, isTrue);

      final BuildContext sheet = tester.element(find.byType(SeanceSheet));
      expect(ModalRoute.of(sheet)?.settings.name, 'Séance for Ghost');
      expect(GraveyardCopy.seanceRouteName('Ghost'), 'Séance for Ghost');

      // Only the title, close button, score, steps and verdict are exposed.
      final Set<String> expected = <String>{
        'Ghost',
        GraveyardCopy.closeSeanceLabel,
        scoreLabel,
        ...stepLabels,
        _verdict,
      };
      final Set<String> labelled = <String>{
        for (final SemanticsNode n in nodes)
          if (n.label.isNotEmpty || n.tooltip.isNotEmpty)
            n.label.isNotEmpty ? n.label : n.tooltip,
      };
      expect(labelled, expected);
      handle.dispose();
    });

    testWidgets('pending: only the loader caption is added, and it is live', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _open(tester, FakeCoffinAI.never(), CoffinTheme.dark());
      final List<SemanticsNode> nodes = _sheetNodes(tester);
      final SemanticsNode? caption = _withLabel(
        nodes,
        GraveyardCopy.seanceThinkingCaption,
      );
      expect(caption, isNotNull);
      expect(caption!.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(nodes.where((SemanticsNode n) => n.label == 'Loading'), isEmpty);
      // The loader graphic, glows and Reveal add no labelled node.
      final int labelled = nodes
          .where(
            (SemanticsNode n) => n.label.isNotEmpty || n.tooltip.isNotEmpty,
          )
          .length;
      expect(labelled, 1 + 1 + 1 + 3 + 1); // title, close, score, steps, loader
      await _drain(tester);
      handle.dispose();
    });
  });

  group('contrast', () {
    const Map<String, CoffinColorTokens> variants = <String, CoffinColorTokens>{
      'dark': CoffinColorTokens.night,
      'daylight': CoffinColorTokens.daylight,
    };

    for (final MapEntry<String, CoffinColorTokens> v in variants.entries) {
      final CoffinColorTokens tokens = v.value;
      final ThemeData theme = v.key == 'dark'
          ? CoffinTheme.dark()
          : CoffinTheme.light();

      testWidgets('every text and icon is readable in the ${v.key} theme', (
        tester,
      ) async {
        final SeanceResult result = _expected();
        await _open(tester, FakeCoffinAI.replying(_verdict), theme);
        final Finder sheet = find.byType(SeanceSheet);

        // The colors behind the content, read from the widget tree.
        final BottomSheet bottom = tester.widget<BottomSheet>(
          find.byType(BottomSheet),
        );
        expect(bottom.backgroundColor, tokens.surface);
        final Finder card = find.descendant(
          of: sheet,
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == tokens.raised,
          ),
        );
        expect(card, findsOneWidget);

        final Set<String> onRaised = <String>{
          '${result.score}',
          GraveyardCopy.revivalBandLabel(result.band),
        };

        int texts = 0;
        for (final Element e
            in find
                .descendant(of: sheet, matching: find.byType(Text))
                .evaluate()) {
          final Text t = e.widget as Text;
          final String data = t.data ?? '';
          final Color? color =
              t.style?.color ?? DefaultTextStyle.of(e).style.color;
          expect(color, isNotNull, reason: data);
          final Color behind = onRaised.contains(data)
              ? tokens.raised
              : tokens.surface;
          expect(
            WcagContrast.ratio(_argb(color!), _argb(behind)),
            greaterThanOrEqualTo(WcagContrast.aaNormalText),
            reason: 'text "$data"',
          );
          texts++;
        }
        // Title, score, band, 3 numbers, 3 steps and the verdict.
        expect(texts, 10);

        int icons = 0;
        for (final Element e
            in find
                .descendant(of: sheet, matching: find.byType(Icon))
                .evaluate()) {
          final Icon i = e.widget as Icon;
          final Color? color = i.color ?? IconTheme.of(e).color;
          expect(color, isNotNull);
          expect(
            WcagContrast.ratio(_argb(color!), _argb(tokens.surface)),
            greaterThanOrEqualTo(3.0),
            reason: 'icon',
          );
          icons++;
        }
        expect(icons, 1);
      });
    }

    for (final MapEntry<String, CoffinColorTokens> v in variants.entries) {
      testWidgets('the loader caption is readable in the ${v.key} theme', (
        tester,
      ) async {
        final ThemeData theme = v.key == 'dark'
            ? CoffinTheme.dark()
            : CoffinTheme.light();
        await _open(tester, FakeCoffinAI.never(), theme);
        final Finder caption = find.descendant(
          of: find.byType(SeanceSheet),
          matching: find.text(GraveyardCopy.seanceThinkingCaption),
        );
        final Color? color = tester.widget<Text>(caption).style?.color;
        expect(color, isNotNull);
        expect(
          WcagContrast.ratio(_argb(color!), _argb(v.value.surface)),
          greaterThanOrEqualTo(WcagContrast.aaNormalText),
        );
        await _drain(tester);
      });
    }
  });
}
