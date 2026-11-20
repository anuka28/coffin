import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hauntagotchi/src/domain/ghost_state.dart';
import 'package:hauntagotchi/src/ui/ghost_panel.dart';
import 'package:hauntagotchi/src/ui/ghost_reaction.dart';
import 'package:hauntagotchi/src/ui/ghost_reaction_kind.dart';
import 'package:hauntagotchi/src/ui/haunt_copy.dart';
import 'package:hauntagotchi/src/ui/mood_map.dart';

const GhostReaction _fed1 = GhostReaction(GhostReactionKind.fed, 1);
const GhostReaction _fed2 = GhostReaction(GhostReactionKind.fed, 2);
const GhostReaction _rising3 = GhostReaction(GhostReactionKind.rising, 3);

Future<void> _pump(
  WidgetTester tester, {
  GhostState state = GhostState.thriving,
  int health = 85,
  int streak = 3,
  GhostReaction? reaction,
  bool reduced = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: Scaffold(
        body: GhostPanel(
          ghostName: 'Wisp',
          health: health,
          state: state,
          streak: streak,
          reaction: reaction,
        ),
      ),
    ),
  );
}

GhostLoader _loader(WidgetTester tester) =>
    tester.widget<GhostLoader>(find.byType(GhostLoader));

GhostMood? _mood(WidgetTester tester) => _loader(tester).mood;

/// Pumps [totalMs] in 100 ms steps and returns every mood the loader had.
Future<Set<GhostMood?>> _run(WidgetTester tester, int totalMs) async {
  final seen = <GhostMood?>{_mood(tester)};
  for (var t = 0; t < totalMs; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
    seen.add(_mood(tester));
  }
  return seen;
}

void main() {
  testWidgets('the loader shows the mood of each state', (tester) async {
    for (final s in GhostState.values) {
      await _pump(tester, state: s);
      expect(_mood(tester), moodFor(s));
    }
  });

  testWidgets('a state change is a transition on the same loader element', (
    tester,
  ) async {
    await _pump(tester);
    final before = tester.element(find.byType(GhostLoader));
    await _pump(tester, state: GhostState.hungry, health: 30);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.element(find.byType(GhostLoader)), same(before));
    expect(_mood(tester), GhostMood.hungry);
  });

  testWidgets('fed plays after an event and returns to the steady mood', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, reaction: _fed1);
    expect(_mood(tester), GhostMood.fed);
    expect(_loader(tester).reactionKey, 1);
    expect(_loader(tester).onReactionEnd, isNotNull);

    final seen = await _run(tester, 1500);
    expect(seen, contains(GhostMood.fed));
    expect(_mood(tester), GhostMood.thriving);
    expect(_loader(tester).onReactionEnd, isNull);
  });

  testWidgets('a second event during a running fed restarts it', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, reaction: _fed1);
    await tester.pump(const Duration(milliseconds: 400));
    await _pump(tester, reaction: _fed2);
    expect(_mood(tester), GhostMood.fed);
    expect(_loader(tester).reactionKey, 2);

    // 500 ms after the second event, the first run would have ended.
    await tester.pump(const Duration(milliseconds: 500));
    expect(_mood(tester), GhostMood.fed);
    await _run(tester, 1500);
    expect(_mood(tester), GhostMood.thriving);
  });

  testWidgets(
    'a rebuild for another reason keeps the key and does not replay',
    (tester) async {
      await _pump(tester);
      await _pump(tester, reaction: _fed1);
      await _run(tester, 1500);
      expect(_mood(tester), GhostMood.thriving);

      await _pump(tester, reaction: _fed1, streak: 4);
      expect(_mood(tester), GhostMood.thriving);
      expect(_loader(tester).reactionKey, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_mood(tester), GhostMood.thriving);
    },
  );

  testWidgets('a panel mounted late does not replay an old event', (
    tester,
  ) async {
    await _pump(tester, reaction: _fed1);
    expect(_mood(tester), GhostMood.thriving);
    expect(_loader(tester).reactionKey, 0);
    expect(_loader(tester).onReactionEnd, isNull);

    await _pump(tester, reaction: _fed2);
    expect(_mood(tester), GhostMood.fed);
  });

  testWidgets('a fed event handed to a dead ghost is ignored', (tester) async {
    await _pump(tester, state: GhostState.dead, health: 0);
    await _pump(tester, state: GhostState.dead, health: 0, reaction: _fed1);
    expect(_mood(tester), GhostMood.dead);
    expect(_loader(tester).reactionKey, 0);
    await _run(tester, 1200);
    expect(_mood(tester), GhostMood.dead);
  });

  testWidgets('an active fed is dropped when the state becomes dead', (
    tester,
  ) async {
    await _pump(tester, state: GhostState.fading, health: 20);
    await _pump(tester, state: GhostState.fading, health: 20, reaction: _fed1);
    expect(_mood(tester), GhostMood.fed);

    await _pump(tester, state: GhostState.dead, health: 0, reaction: _fed1);
    expect(_mood(tester), GhostMood.dead);
    expect(_loader(tester).onReactionEnd, isNull);
  });

  testWidgets('reduced motion never gives the loader a reaction mood', (
    tester,
  ) async {
    await _pump(tester, reduced: true);
    for (final event in [_fed1, _rising3]) {
      await _pump(tester, reduced: true, reaction: event);
      final seen = await _run(tester, 300);
      expect(seen, {GhostMood.thriving});
      expect(_loader(tester).reactionKey, 0);
    }
  });

  testWidgets('turning reduced motion on drops an active reaction', (
    tester,
  ) async {
    await _pump(tester);
    await _pump(tester, reaction: _fed1);
    expect(_mood(tester), GhostMood.fed);

    await _pump(tester, reaction: _fed1, reduced: true);
    await tester.pump();
    expect(_mood(tester), GhostMood.thriving);
  });

  testWidgets('rising plays once and then shows the steady mood', (
    tester,
  ) async {
    await _pump(tester, state: GhostState.hungry, health: 40);
    await _pump(
      tester,
      state: GhostState.hungry,
      health: 40,
      reaction: _rising3,
    );
    expect(_mood(tester), GhostMood.rising);
    expect(_loader(tester).reactionKey, 3);

    final seen = await _run(tester, 2600);
    expect(seen, contains(GhostMood.rising));
    expect(_mood(tester), GhostMood.hungry);

    await _pump(
      tester,
      state: GhostState.hungry,
      health: 40,
      reaction: _rising3,
      streak: 5,
    );
    expect(_mood(tester), GhostMood.hungry);
  });

  testWidgets('the semantics label is the same in every case', (tester) async {
    final handle = tester.ensureSemantics();
    for (final s in GhostState.values) {
      final label =
          'Wisp, health 50 of 100, ${HauntCopy.stateWord(s).toLowerCase()}';
      for (final reaction in <GhostReaction?>[null, _fed1, _rising3]) {
        for (final reduced in [false, true]) {
          await _pump(tester, state: s, health: 50);
          await _pump(
            tester,
            state: s,
            health: 50,
            reaction: reaction,
            reduced: reduced,
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.bySemanticsLabel(label), findsOneWidget);
        }
      }
    }
    handle.dispose();
  });
}
