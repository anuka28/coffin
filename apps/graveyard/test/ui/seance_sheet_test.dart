import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/scene/stable_hash.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';
import 'package:graveyard/src/domain/seance/seance_result.dart';
import 'package:graveyard/src/domain/seance/seance_rules.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/seance_ai.dart';
import 'package:graveyard/src/ui/seance_sheet.dart';

import '../support/fake_coffin_ai.dart';

final Grave _grave = Grave.manual(
  id: 'g1',
  name: 'Ghost',
  dateOfDeath: CalendarDate(2025, 1, 1),
);
final CalendarDate _today = CalendarDate(2026, 5, 10);
const String _closeKey = 'seance-close';

SeanceResult _expected() =>
    SeanceRules.evaluate(SeanceFacts.of(grave: _grave, today: _today));

Future<void> _open(
  WidgetTester tester,
  CoffinAI ai, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
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

void _expectContent(SeanceResult result) {
  expect(find.text('${result.score}'), findsOneWidget);
  expect(
    find.text(GraveyardCopy.revivalBandLabel(result.band)),
    findsOneWidget,
  );
  expect(result.steps, hasLength(3));
  for (final step in result.steps) {
    expect(find.text(GraveyardCopy.revivalStepText(step)), findsOneWidget);
  }
}

void main() {
  testWidgets('shows score, band and steps while the verdict is pending', (
    tester,
  ) async {
    await _open(tester, FakeCoffinAI.never());
    _expectContent(_expected());
    expect(find.byType(GhostLoader), findsOneWidget);
    expect(find.text(GraveyardCopy.seanceThinkingCaption), findsOneWidget);
    // Drain the verdict timeout so no timer is left pending.
    await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
  });

  testWidgets('a reply replaces the loader and leaves the rest in place', (
    tester,
  ) async {
    final FakeCoffinAI ai = FakeCoffinAI.held('Rise, little ghost.');
    await _open(tester, ai);
    final SeanceResult result = _expected();
    _expectContent(result);
    expect(find.byType(GhostLoader), findsOneWidget);

    ai.release();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(GhostLoader), findsNothing);
    expect(find.text('Rise, little ghost.'), findsOneWidget);
    _expectContent(result);
  });

  for (final MapEntry<String, FakeCoffinAI> e in <String, FakeCoffinAI>{
    'never completes': FakeCoffinAI.never(),
    'fails': FakeCoffinAI.failing(),
    'throws': FakeCoffinAI.throwing(),
    'is blank': FakeCoffinAI.blank(),
  }.entries) {
    testWidgets('shows the safe line quietly when the generator ${e.key}', (
      tester,
    ) async {
      await _open(tester, e.value);
      await tester.pump(verdictWaitLimit + const Duration(seconds: 1));

      expect(find.text(GraveyardCopy.safeVerdictLine), findsOneWidget);
      expect(find.byType(GhostLoader), findsNothing);
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.textContaining('fake ai failure'), findsNothing);
      expect(
        find.textContaining(RegExp('error|retry', caseSensitive: false)),
        findsNothing,
      );
      _expectContent(_expected());
    });
  }

  testWidgets('asks for the verdict with two facts and the grave seed', (
    tester,
  ) async {
    final FakeCoffinAI ai = FakeCoffinAI.replying('Boo.');
    await _open(tester, ai);

    expect(ai.requests, hasLength(1));
    final AiRequest request = ai.requests.single;
    expect(request.purpose, AiPurpose.seanceVerdict);
    expect(request.facts, <String, Object?>{
      AiFactKeys.projectName: 'Ghost',
      AiFactKeys.daysSinceLastCommit: _grave.dateOfDeath.daysUntil(_today),
    });
    expect(request.maxLength, verdictMaxLength);
    expect(request.seed, StableHash.of('g1') % (AiRequest.maxSeed + 1));
  });

  testWidgets('exposes score, step and route semantics', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final SeanceResult result = _expected();
    await _open(tester, FakeCoffinAI.replying('Boo.'));

    expect(
      find.bySemanticsLabel(
        GraveyardCopy.revivalScoreLabel(result.score, result.band),
      ),
      findsOneWidget,
    );
    for (int i = 0; i < result.steps.length; i++) {
      expect(
        find.bySemanticsLabel(
          GraveyardCopy.revivalStepLabel(
            i + 1,
            3,
            GraveyardCopy.revivalStepText(result.steps[i]),
          ),
        ),
        findsOneWidget,
      );
    }
    expect(
      ModalRoute.of(tester.element(find.byType(SeanceSheet)))?.settings.name,
      GraveyardCopy.seanceRouteName('Ghost'),
    );
    handle.dispose();
  });

  testWidgets('the close button is 48x48 and closes the sheet', (tester) async {
    await _open(tester, FakeCoffinAI.replying('Boo.'));
    final Finder close = find.byKey(const ValueKey<String>(_closeKey));
    expect(close, findsOneWidget);
    final Size size = tester.getSize(close);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(find.byTooltip(GraveyardCopy.closeSeanceLabel), findsOneWidget);

    await tester.tap(close);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SeanceSheet), findsNothing);
  });

  testWidgets('a reply after closing causes no exception', (tester) async {
    final FakeCoffinAI ai = FakeCoffinAI.held('Too late.');
    await _open(tester, ai);
    await tester.tap(find.byKey(const ValueKey<String>(_closeKey)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SeanceSheet), findsNothing);

    ai.release();
    await tester.pump();
    await tester.pump(verdictWaitLimit + const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Too late.'), findsNothing);
  });

  testWidgets('with animations disabled the content shows at once', (
    tester,
  ) async {
    final FakeCoffinAI ai = FakeCoffinAI.never();
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SeanceSheet(grave: _grave, today: _today, seanceAi: ai),
        ),
      ),
    );

    final FadeTransition fade = tester.widget<FadeTransition>(
      find.byType(FadeTransition).last,
    );
    expect(fade.opacity.value, 1);
    _expectContent(_expected());
    await tester.pump(verdictWaitLimit + const Duration(seconds: 1));
  });
}
