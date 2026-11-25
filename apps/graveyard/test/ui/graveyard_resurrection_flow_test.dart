import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/ui/empty_graveyard_panel.dart';
import 'package:graveyard/src/ui/grave_tombstone.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';
import 'package:graveyard/src/ui/living_row.dart';
import 'package:graveyard/src/ui/resurrection_play.dart';
import 'package:graveyard/src/ui/seance_control.dart';

import '../support/controller_harness.dart';
import '../support/fake_coffin_ai.dart';
import '../support/throwing_record_repository.dart';

final CalendarDate _diedA = CalendarDate(2023, 1, 3);
final CalendarDate _diedB = CalendarDate(2024, 1, 3);
final CalendarDate _risen = CalendarDate(2026, 5, 1);
final CalendarDate _today = CalendarDate(2026, 5, 10);

Grave _plain(String id, {CalendarDate? died}) =>
    Grave.manual(id: id, name: 'n$id', dateOfDeath: died ?? _diedA);

Grave _alive(String id) =>
    Grave.manual(id: id, name: 'n$id', dateOfDeath: _diedA, risenOn: _risen);

ControllerHarness _harness(List<Grave> graves) {
  final ControllerHarness h = ControllerHarness(
    seed: <String, String>{
      for (final Grave g in graves) g.id: ControllerHarness.envelopeOf(g),
    },
  );
  addTearDown(h.dispose);
  return h;
}

Widget _app(
  ControllerHarness h, {
  bool reduced = false,
  double textScale = 1,
  Key? key,
}) => MaterialApp(
  theme: CoffinTheme.dark(),
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: GraveyardScreen(
    key: key,
    controller: h.controller,
    seanceAi: FakeCoffinAI.replying('Boo.'),
  ),
);

Future<void> _show(
  WidgetTester tester,
  ControllerHarness h, {
  bool reduced = false,
  Key? key,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await h.controller.load();
  await tester.pumpWidget(_app(h, reduced: reduced, key: key));
  await tester.pump(const Duration(milliseconds: 700));
}

/// The longest frame step of [_ms]. The play ends on the first frame at or
/// after its Play_Duration, so it is gone one frame after 2800 ms at most.
const int _frame = 50;

/// Pumps [ms] of fake time in frames of at most 50 ms, like a running app.
Future<void> _ms(WidgetTester tester, int ms) async {
  var left = ms;
  while (left > 0) {
    final int step = left < _frame ? left : _frame;
    await tester.pump(Duration(milliseconds: step));
    left -= step;
  }
}

Finder _stone(String id) => find.byWidgetPredicate(
  (Widget w) => w is GraveTombstone && w.grave.id == id,
  description: 'tombstone $id',
);

/// Opens the séance of [id] and taps "Raise it", then lets the sheet close
/// (600 ms). The play starts with the tap.
Future<void> _raise(WidgetTester tester, String id) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey<String>(id)),
      matching: find.byType(SeanceControl),
    ),
  );
  await tester.pump();
  await _ms(tester, 1000);
  await tester.tap(find.text(GraveyardCopy.raiseControlText));
  await tester.pump(); // builds the play
  await tester.pump(); // its ticker takes 0 ms here
  await _ms(tester, 600);
}

Future<void> _layToRest(WidgetTester tester) async {
  await tester.tap(find.text(GraveyardCopy.layToRestText));
  await _ms(tester, 600);
  await tester.tap(find.text(GraveyardCopy.restConfirmText));
  await _ms(tester, 600);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('raise: save, one play, RISEN, then into the Living_Row', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[
      _plain('b', died: _diedB),
      _plain('a'),
    ]);
    await _show(tester, h);
    expect(find.byType(LivingRow), findsNothing);

    await _raise(tester, 'b'); // t = 600 ms of the play
    expect(find.text(GraveyardCopy.raiseControlText), findsNothing);
    expect(h.controller.graves.first.risenOn, _today);
    expect((await h.repository.getAll()).where((g) => g.risenOn != null), [
      h.controller.graves.first,
    ]);
    expect(find.byType(ResurrectionPlay), findsOneWidget);
    expect(find.text(GraveyardCopy.epitaph), findsNWidgets(2));
    expect(find.text(GraveyardCopy.epitaphRisen), findsNothing);

    await _ms(tester, 1400); // 2000 ms
    expect(find.text(GraveyardCopy.epitaphRisen), findsNothing);
    await _ms(tester, 600); // 2600 ms
    expect(find.text(GraveyardCopy.epitaphRisen), findsOneWidget);
    expect(find.byType(LivingRow), findsNothing);

    await _ms(tester, 200 + _frame); // the whole play
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(_stone('b'), findsNothing);
    expect(find.byType(LivingRow), findsOneWidget);
    expect(find.text(GraveyardCopy.livingRowHeading), findsOneWidget);
    expect(_stone('a'), findsOneWidget);
    expect(tester.widget<GraveTombstone>(_stone('a')).riseProgress, 1);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('the play lasts no longer than the Play_Duration', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_plain('a')]);
    await _show(tester, h);
    await _raise(tester, 'a');
    await _ms(tester, PlayTiming.playDurationMs - 600 - _frame);
    expect(find.byType(ResurrectionPlay), findsOneWidget);
    await _ms(tester, 2 * _frame);
    expect(find.byType(ResurrectionPlay), findsNothing);
    await _finish(tester);
  });

  testWidgets('a saved risen grave shows at once and stays after a reload', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_alive('a'), _plain('b')]);
    await _show(tester, h);
    expect(find.byType(LivingRow), findsOneWidget);
    expect(find.byType(ResurrectionPlay), findsNothing);
    await _ms(tester, 3000);
    expect(find.byType(ResurrectionPlay), findsNothing);

    final ControllerHarness h2 = ControllerHarness(repository: h.repository);
    addTearDown(h2.dispose);
    await h2.controller.load();
    await tester.pumpWidget(_app(h2, key: const ValueKey<String>('second')));
    await _ms(tester, 100);
    expect(find.byType(LivingRow), findsOneWidget);
    expect(find.byType(ResurrectionPlay), findsNothing);
    await _ms(tester, 3000);
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(find.byType(LivingRow), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('no replay after a rebuild, a new width or a new text scale', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_plain('a')]);
    await _show(tester, h);
    await _raise(tester, 'a');
    final State before = tester.state(find.byType(ResurrectionPlay));

    await tester.pumpWidget(_app(h)); // plain rebuild
    await _ms(tester, 100);
    tester.view.physicalSize = const Size(700, 1400);
    await _ms(tester, 100);
    await tester.pumpWidget(_app(h, textScale: 1.5));
    await _ms(tester, 100);
    expect(find.byType(ResurrectionPlay), findsOneWidget);
    expect(tester.state(find.byType(ResurrectionPlay)), same(before));

    await _ms(tester, 1900 + _frame); // 600 + 300 + 1950 = 2850 ms
    expect(find.byType(ResurrectionPlay), findsNothing);
    await _ms(tester, 3000);
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(find.byType(LivingRow), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('lay to rest then raise again plays one new play', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_plain('a')]);
    await _show(tester, h);
    await _raise(tester, 'a');
    await _ms(tester, 2200 + _frame);
    expect(find.byType(LivingRow), findsOneWidget);

    await _layToRest(tester);
    expect(find.byType(LivingRow), findsNothing);
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(h.controller.graves.single.risenOn, isNull);
    await _ms(tester, 1000);

    await _raise(tester, 'a');
    expect(find.byType(ResurrectionPlay), findsOneWidget);
    await _ms(tester, 2200 + _frame);
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(find.byType(LivingRow), findsOneWidget);
    expect(h.controller.graves.single.risenOn, _today);
    await _finish(tester);
  });

  testWidgets('two plays on different graves do not disturb each other', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[
      _plain('b', died: _diedB),
      _plain('a'),
    ]);
    await _show(tester, h);
    await _raise(tester, 'a'); // a at 600 ms
    await _ms(tester, 400); // a at 1000 ms
    await _raise(tester, 'b'); // a at 2600 ms, b at 600 ms
    expect(find.byType(ResurrectionPlay), findsNWidgets(2));

    await _ms(tester, 200 + _frame); // a ends, b at 850 ms
    expect(find.byType(ResurrectionPlay), findsOneWidget);
    expect(_stone('a'), findsNothing);
    expect(_stone('b'), findsOneWidget);
    expect(find.byType(LivingRow), findsOneWidget);

    await _ms(tester, 2000); // b ends
    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(_stone('b'), findsNothing);
    expect(find.text(GraveyardCopy.allRisen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('deleting a grave mid-play stops its play cleanly', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[
      _plain('b', died: _diedB),
      _plain('a'),
    ]);
    await _show(tester, h);
    await _raise(tester, 'b');
    await _ms(tester, 500);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('b')),
        matching: find.text(GraveyardCopy.delete),
      ),
    );
    await _ms(tester, 600);
    await tester.tap(find.byKey(const ValueKey<String>('delete-confirm')));
    await _ms(tester, 600);

    expect(find.byType(ResurrectionPlay), findsNothing);
    expect(_stone('b'), findsNothing);
    expect(h.controller.graves.map((Grave g) => g.id), <String>['a']);
    expect(find.byType(LivingRow), findsNothing);
    await _ms(tester, 5000);
    expect(tester.takeException(), isNull);
    expect((await h.repository.getAll()).map((Grave g) => g.id), <String>['a']);
    await _finish(tester);
  });

  testWidgets('the Playing_Set and the play progress are never saved', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_plain('a')]);
    await _show(tester, h);
    await _raise(tester, 'a');
    await _ms(tester, 500);

    final Grave inList = h.controller.graves.single;
    final Map<String, Object?> encoded = const GraveCodec().encode(inList);
    expect(encoded.keys, containsAll(<String>['risen']));
    expect(
      encoded.keys.where(
        (String k) => k.contains('play') || k.contains('progress'),
      ),
      isEmpty,
    );
    expect(await h.repository.getAll(), <Grave>[inList]);
    await _ms(tester, 2000);
    expect(await h.repository.getAll(), <Grave>[inList]);
    await _finish(tester);
  });

  testWidgets('with every grave risen: Living_Row and the line, no panel', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_alive('a'), _alive('b')]);
    await _show(tester, h);
    expect(find.byType(LivingRow), findsOneWidget);
    expect(find.text(GraveyardCopy.allRisen), findsOneWidget);
    expect(find.byType(EmptyGraveyardPanel), findsNothing);
    await _finish(tester);
  });

  testWidgets('with no risen grave the Living_Row is not shown', (
    tester,
  ) async {
    final ControllerHarness h = _harness(<Grave>[_plain('a')]);
    await _show(tester, h);
    expect(find.byType(LivingRow), findsNothing);
    expect(find.text(GraveyardCopy.livingRowHeading), findsNothing);
    expect(find.text(GraveyardCopy.allRisen), findsNothing);
    await _finish(tester);
  });

  testWidgets('the Living_Row sits below the title and the banners', (
    tester,
  ) async {
    final ThrowingRecordRepository repo = ThrowingRecordRepository();
    await repo.put('a', _alive('a'));
    await repo.put('b', _plain('b'));
    final ControllerHarness h = ControllerHarness(
      repository: repo,
      isPersistent: false,
    );
    addTearDown(h.dispose);
    await _show(tester, h);
    repo.failOnPut = true;
    h.controller.replaceGrave(_plain('b')); // a failing write: banner shows
    await _ms(tester, 200);
    expect(find.text(GraveyardCopy.saveError), findsOneWidget);

    final double heading = tester
        .getTopLeft(find.text(GraveyardCopy.livingRowHeading))
        .dy;
    expect(
      heading,
      greaterThan(
        tester.getBottomLeft(find.text(GraveyardCopy.screenTitle)).dy,
      ),
    );
    expect(
      heading,
      greaterThan(tester.getBottomLeft(find.text(GraveyardCopy.saveError)).dy),
    );
    expect(
      heading,
      greaterThan(
        tester.getBottomLeft(find.text(GraveyardCopy.memoryNotice)).dy,
      ),
    );
    await _finish(tester);
  });

  testWidgets('a failing write of a Raise shows the banner; retry saves it', (
    tester,
  ) async {
    final ThrowingRecordRepository repo = ThrowingRecordRepository();
    await repo.put('a', _plain('a'));
    final ControllerHarness h = ControllerHarness(repository: repo);
    addTearDown(h.dispose);
    await _show(tester, h);

    repo.failOnPut = true;
    await _raise(tester, 'a');
    expect(find.text(GraveyardCopy.saveError), findsOneWidget);
    expect(h.controller.graves.single.risenOn, _today);
    expect((await repo.get('a'))!.risenOn, isNull);
    expect(find.byType(ResurrectionPlay), findsOneWidget);

    repo.failOnPut = false;
    await tester.tap(find.byKey(const ValueKey<String>('save-retry')));
    await _ms(tester, 100);
    expect(find.text(GraveyardCopy.saveError), findsNothing);
    expect((await repo.get('a'))!.risenOn, _today);
    expect(h.controller.graves.single.risenOn, _today);

    await _ms(tester, 2200 + _frame);
    expect(find.byType(LivingRow), findsOneWidget);
    await _finish(tester);
  });
}
