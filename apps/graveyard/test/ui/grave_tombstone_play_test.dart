import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
import 'package:graveyard/src/ui/seance_ai.dart';

final CalendarDate _today = CalendarDate(2024, 1, 10);

Widget _app({
  required bool playing,
  VoidCallback? onPlayEnd,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: CoffinTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: SingleChildScrollView(
        child: GraveTombstone(
          grave: Grave.manual(
            id: 'm',
            name: 'moth',
            dateOfDeath: CalendarDate(2023, 1, 3),
          ),
          today: _today,
          onDelete: () {},
          seanceAi: buildSeanceAi(),
          playing: playing,
          onPlayEnd: onPlayEnd,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('not playing: no play layer and the epitaph is R.I.P.', (
    tester,
  ) async {
    await tester.pumpWidget(_app(playing: false));
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(find.text('R.I.P.'), findsOneWidget);
    expect(find.text('RISEN'), findsNothing);
  });

  testWidgets('playing: epitaph turns to RISEN, onPlayEnd fires once', (
    tester,
  ) async {
    var ended = 0;
    await tester.pumpWidget(_app(playing: true, onPlayEnd: () => ended++));
    expect(find.byType(ResurrectionPlay), findsOneWidget);
    expect(find.text('R.I.P.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('RISEN'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1300));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: PlayTiming.epitaphFadeMs));
    }
    expect(find.text('RISEN'), findsOneWidget);
    expect(find.text('R.I.P.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1000));
    expect(ended, 1);
    expect(find.text('Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion: RISEN at once without a fade', (tester) async {
    var ended = 0;
    await tester.pumpWidget(
      _app(playing: true, onPlayEnd: () => ended++, disableAnimations: true),
    );
    await tester.pump();
    expect(find.text('RISEN'), findsOneWidget);
    expect(find.text('R.I.P.'), findsNothing);
    await tester.pump(const Duration(milliseconds: PlayTiming.playDurationMs));
    await tester.pump(const Duration(milliseconds: 20));
    expect(ended, 1);
    expect(tester.takeException(), isNull);
  });
}
