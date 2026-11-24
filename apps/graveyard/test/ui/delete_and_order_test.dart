import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/ui/graveyard_copy.dart';
import 'package:graveyard/src/ui/graveyard_screen.dart';

import '../support/controller_harness.dart';
import '../support/fake_github_client.dart';
import '../support/fixed_offset_zone.dart';

import 'package:graveyard/src/ui/seance_ai.dart';

Grave _manual(String id, String name, CalendarDate died) =>
    Grave.manual(id: id, name: name, dateOfDeath: died);

Map<String, String> _seed(List<Grave> graves) => <String, String>{
  for (final Grave g in graves) g.id: ControllerHarness.envelopeOf(g),
};

ControllerHarness _harness({
  Map<String, String> seed = const <String, String>{},
  DateTime? now,
}) {
  final ControllerHarness h = ControllerHarness(seed: seed, now: now);
  addTearDown(h.dispose);
  return h;
}

Future<void> _pump(WidgetTester tester, ControllerHarness h) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await h.controller.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: GraveyardScreen(
        controller: h.controller,
        seanceAi: buildSeanceAi(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapDelete(WidgetTester tester, String id) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey<String>(id)),
      matching: find.text(GraveyardCopy.delete),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _storedIds(List<Grave> graves) =>
    graves.map((Grave g) => g.id).toList()..sort();

void main() {
  final List<Grave> seeded = <Grave>[
    _manual('g1', 'Alpha', CalendarDate(2024, 1, 1)),
    _manual('g2', 'Beta', CalendarDate(2025, 1, 1)),
  ];

  group('delete', () {
    testWidgets('the confirmation names the grave', (tester) async {
      final ControllerHarness h = _harness(seed: _seed(seeded));
      await _pump(tester, h);

      await _tapDelete(tester, 'g1');

      expect(find.text(GraveyardCopy.deleteTitle('Alpha')), findsOneWidget);
      expect(find.text(GraveyardCopy.deleteBody), findsOneWidget);
      expect(find.text(GraveyardCopy.keepIt), findsOneWidget);
    });

    testWidgets('confirm removes the grave from the list and repository', (
      tester,
    ) async {
      final ControllerHarness h = _harness(seed: _seed(seeded));
      await _pump(tester, h);

      await _tapDelete(tester, 'g1');
      await tester.tap(find.byKey(const ValueKey<String>('delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('g1')), findsNothing);
      expect(find.byKey(const ValueKey<String>('g2')), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
      expect(h.controller.graves.map((Grave g) => g.id), <String>['g2']);
      expect(_storedIds(await h.repository.getAll()), <String>['g2']);
    });

    testWidgets('cancel leaves the list and repository unchanged', (
      tester,
    ) async {
      final ControllerHarness h = _harness(seed: _seed(seeded));
      await _pump(tester, h);

      await _tapDelete(tester, 'g1');
      await tester.tap(find.byKey(const ValueKey<String>('delete-keep')));
      await tester.pumpAndSettle();

      expect(find.text(GraveyardCopy.deleteTitle('Alpha')), findsNothing);
      expect(find.byKey(const ValueKey<String>('g1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('g2')), findsOneWidget);
      expect(h.controller.graves, hasLength(2));
      expect(_storedIds(await h.repository.getAll()), <String>['g1', 'g2']);
    });

    testWidgets('deleting the last grave shows the empty state', (
      tester,
    ) async {
      final ControllerHarness h = _harness(seed: _seed(<Grave>[seeded.first]));
      await _pump(tester, h);

      await _tapDelete(tester, 'g1');
      await tester.tap(find.byKey(const ValueKey<String>('delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text(GraveyardCopy.emptyTitle), findsOneWidget);
      expect(await h.repository.getAll(), isEmpty);
    });
  });

  group('order', () {
    testWidgets('a grave added later sorts into place, newest death first', (
      tester,
    ) async {
      final ControllerHarness h = _harness(seed: _seed(seeded));
      await _pump(tester, h);

      await h.controller.addManual(
        rawName: 'Middle',
        year: 2024,
        month: 6,
        day: 1,
      );
      await tester.pumpAndSettle();

      double top(String name) => tester.getTopLeft(find.text(name).first).dy;
      expect(top('Beta'), lessThan(top('Middle')));
      expect(top('Middle'), lessThan(top('Alpha')));
      expect(h.controller.graves.map((Grave g) => g.name), <String>[
        'Beta',
        'Middle',
        'Alpha',
      ]);
    });

    testWidgets('a grave dated newest goes to the top', (tester) async {
      final ControllerHarness h = _harness(seed: _seed(seeded));
      await _pump(tester, h);

      await h.controller.addManual(
        rawName: 'Fresh',
        year: 2026,
        month: 5,
        day: 10,
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Fresh').first).dy,
        lessThan(tester.getTopLeft(find.text('Beta').first).dy),
      );
    });
  });

  group('Died today', () {
    testWidgets('a push at the same instant as the clock reads "Died today"', (
      tester,
    ) async {
      // One instant: 2026-05-10 23:30 UTC. At +02:00 it is 2026-05-11 01:30,
      // so the local day differs from the UTC day.
      const FixedOffsetZone zone = FixedOffsetZone(Duration(hours: 2));
      final DateTime instant = DateTime.utc(2026, 5, 10, 23, 30);
      final DateTime localNow = zone(instant);
      final ControllerHarness h = _harness(now: localNow);
      const RepoRef ref = RepoRef('flutter', 'flutter');
      h.github.enqueue(
        FakeGitHubClient.parsed(
          ref,
          pushedAt: '2026-05-10T23:30:00Z',
          today: CalendarDate.fromDateTime(localNow),
          offset: zone.offset,
        ),
      );
      await _pump(tester, h);

      await h.controller.startImport('flutter/flutter');
      await tester.pumpAndSettle();

      expect(h.controller.graves.single.name, 'flutter/flutter');
      expect(h.controller.graves.single.dateOfDeath, CalendarDate(2026, 5, 11));
      expect(find.text('Died today'), findsOneWidget);
      expect(find.textContaining('Dead for'), findsNothing);
    });
  });
}
