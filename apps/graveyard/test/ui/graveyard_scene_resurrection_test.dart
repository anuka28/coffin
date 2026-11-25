import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_scene.dart';
import 'package:graveyard/src/ui/living_row.dart';
import 'package:graveyard/src/ui/seance_ai.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);
final ThemeData _theme = CoffinTheme.dark();

Grave _grave(String id, {CalendarDate? risenOn}) => Grave.manual(
  id: id,
  name: 'Project $id',
  dateOfDeath: CalendarDate(2024, 1, 3),
  risenOn: risenOn,
);

Widget _host(
  List<Grave> graves, {
  Set<String> playing = const <String>{},
  ValueChanged<String>? onPlayEnd,
  ValueChanged<Grave>? onLayToRest,
}) => MaterialApp(
  theme: _theme,
  home: Scaffold(
    body: GraveyardScene(
      graves: graves,
      today: _today,
      onDelete: (_) {},
      seanceAi: buildSeanceAi(),
      playingIds: playing,
      onPlayEnd: onPlayEnd,
      onLayToRest: onLayToRest ?? (_) {},
    ),
  ),
);

Finder _tombstone(String id) => find.byWidgetPredicate(
  (w) => w is GraveTombstone && w.grave.id == id,
  description: 'tombstone $id',
);

GraveTombstone _stone(WidgetTester tester, String id) =>
    tester.widget<GraveTombstone>(_tombstone(id));

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  final CalendarDate raised = CalendarDate(2024, 1, 9);

  testWidgets('shows no Living_Row when no grave is risen', (tester) async {
    await tester.pumpWidget(_host(<Grave>[_grave('a'), _grave('b')]));
    expect(find.byType(LivingRow), findsNothing);
    expect(find.text(GraveyardCopy.livingRowHeading), findsNothing);
    expect(_tombstone('a'), findsOneWidget);
    expect(_tombstone('b'), findsOneWidget);
    await _teardown(tester);
  });

  testWidgets('a risen grave sits in the Living_Row above the rows only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(<Grave>[_grave('a'), _grave('b', risenOn: raised)]),
    );
    expect(find.text(GraveyardCopy.livingRowHeading), findsOneWidget);
    expect(_tombstone('b'), findsNothing);
    expect(_tombstone('a'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(GraveyardCopy.livingRowHeading)).dy,
      lessThan(tester.getTopLeft(_tombstone('a')).dy),
    );
    await _teardown(tester);
  });

  testWidgets('a playing risen grave stays in the rows with playing set', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        <Grave>[_grave('a'), _grave('b', risenOn: raised)],
        playing: const <String>{'b'},
      ),
    );
    expect(find.byType(LivingRow), findsNothing);
    expect(_stone(tester, 'b').playing, isTrue);
    expect(_stone(tester, 'a').playing, isFalse);
    await _teardown(tester);
  });

  testWidgets('onPlayEnd reports the grave id once at the end of the play', (
    tester,
  ) async {
    final List<String> ended = <String>[];
    await tester.pumpWidget(
      _host(
        <Grave>[_grave('b', risenOn: raised)],
        playing: const <String>{'b'},
        onPlayEnd: ended.add,
      ),
    );
    await tester.pump(const Duration(milliseconds: PlayTiming.playDurationMs));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ended, <String>['b']);
    await _teardown(tester);
  });

  testWidgets('the gap closes with no Rise when a play ends', (tester) async {
    final List<Grave> graves = <Grave>[
      _grave('a'),
      _grave('b', risenOn: raised),
    ];
    await tester.pumpWidget(_host(graves, playing: const <String>{'b'}));
    await tester.pumpWidget(_host(graves));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_tombstone('b'), findsNothing);
    expect(find.text(GraveyardCopy.livingRowHeading), findsOneWidget);
    expect(_stone(tester, 'a').riseProgress, 1);
    await _teardown(tester);
  });

  testWidgets('a grave back from Lay_To_Rest rises like a new grave', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(<Grave>[_grave('a'), _grave('b', risenOn: raised)]),
    );
    await tester.pumpWidget(_host(<Grave>[_grave('a'), _grave('b')]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_stone(tester, 'b').riseProgress, lessThan(1));
    expect(_stone(tester, 'a').riseProgress, 1);
    await _teardown(tester);
  });

  testWidgets('onLayToRest from the Living_Row reaches the scene caller', (
    tester,
  ) async {
    Grave? rested;
    await tester.pumpWidget(
      _host(<Grave>[
        _grave('b', risenOn: raised),
      ], onLayToRest: (g) => rested = g),
    );
    await tester.tap(find.text(GraveyardCopy.layToRestText));
    expect(rested?.id, 'b');
    await _teardown(tester);
  });
}
