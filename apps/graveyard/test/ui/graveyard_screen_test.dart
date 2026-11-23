import 'dart:async';

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
import '../support/throwing_record_repository.dart';

Grave _manual(String id, String name, CalendarDate died) =>
    Grave.manual(id: id, name: name, dateOfDeath: died);

Map<String, String> _seed(List<Grave> graves) => <String, String>{
  for (final Grave g in graves) g.id: ControllerHarness.envelopeOf(g),
};

ControllerHarness _harness({
  Map<String, String> seed = const <String, String>{},
  bool isPersistent = true,
  Future<OpenedRepository<Grave>> Function()? openStorage,
  RecordRepository<Grave>? repository,
}) {
  final ControllerHarness h = ControllerHarness(
    seed: seed,
    isPersistent: isPersistent,
    openStorage: openStorage,
    repository: repository,
  );
  addTearDown(h.dispose);
  return h;
}

Future<void> _pump(
  WidgetTester tester,
  ControllerHarness h, {
  bool load = true,
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (load) await h.controller.load();
  await tester.pumpWidget(
    MaterialApp(
      theme: CoffinTheme.dark(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: GraveyardScreen(controller: h.controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the ghost loader while loading', (tester) async {
    final Completer<OpenedRepository<Grave>> gate =
        Completer<OpenedRepository<Grave>>();
    final ControllerHarness h = _harness(openStorage: () => gate.future);
    unawaited(h.controller.load());
    await _pump(tester, h, load: false);

    expect(find.byType(GhostLoader), findsOneWidget);
    expect(find.text(GraveyardCopy.loadingCaption), findsOneWidget);
    expect(find.bySemanticsLabel(GraveyardCopy.loadingLabel), findsOneWidget);
    expect(find.text(GraveyardCopy.addButton), findsNothing);

    gate.complete(
      OpenedRepository<Grave>(repository: h.repository, isPersistent: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GhostLoader), findsNothing);
    expect(find.text(GraveyardCopy.emptyTitle), findsOneWidget);
  });

  testWidgets('empty state names both ways and opens the sheet', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);

    expect(find.text(GraveyardCopy.emptyTitle), findsOneWidget);
    expect(find.text(GraveyardCopy.emptyBody), findsOneWidget);
    expect(find.text(GraveyardCopy.addButton), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('empty-bury')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('empty-import')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('empty-import')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('import-field')), findsOneWidget);
  });

  testWidgets('lists graves newest death first', (tester) async {
    final ControllerHarness h = _harness(
      seed: _seed(<Grave>[
        _manual('g1', 'Old one', CalendarDate(2020, 1, 1)),
        _manual('g2', 'Fresh one', CalendarDate(2026, 4, 1)),
      ]),
    );
    await _pump(tester, h);

    expect(find.text(GraveyardCopy.emptyTitle), findsNothing);
    final double fresh = tester.getTopLeft(find.text('Fresh one')).dy;
    final double old = tester.getTopLeft(find.text('Old one')).dy;
    expect(fresh, lessThan(old));
    expect(find.text(GraveyardCopy.memoryNotice), findsNothing);
  });

  testWidgets('shows the load error and retries', (tester) async {
    final ThrowingRecordRepository repo = ThrowingRecordRepository(
      failOnGetAll: true,
    );
    final ControllerHarness h = _harness(repository: repo);
    await _pump(tester, h);

    expect(find.text(GraveyardCopy.loadError), findsOneWidget);
    expect(find.text(GraveyardCopy.addButton), findsNothing);

    repo.failOnGetAll = false;
    await tester.tap(find.byKey(const ValueKey<String>('load-retry')));
    await tester.pumpAndSettle();
    expect(find.text(GraveyardCopy.loadError), findsNothing);
    expect(find.text(GraveyardCopy.emptyTitle), findsOneWidget);
  });

  testWidgets('shows the memory notice when storage is not persistent', (
    tester,
  ) async {
    final ControllerHarness h = _harness(isPersistent: false);
    await _pump(tester, h);

    expect(find.text(GraveyardCopy.memoryNotice), findsOneWidget);
    expect(find.text(GraveyardCopy.emptyTitle), findsOneWidget);
  });

  testWidgets('shows the save banner, keeps graves, and retries', (
    tester,
  ) async {
    final ThrowingRecordRepository repo = ThrowingRecordRepository(
      failOnPut: true,
    );
    final ControllerHarness h = _harness(repository: repo);
    await _pump(tester, h);

    await h.controller.addManual(
      rawName: 'Doomed',
      year: 2025,
      month: 1,
      day: 2,
    );
    await tester.pumpAndSettle();
    expect(find.text(GraveyardCopy.saveError), findsOneWidget);
    expect(find.text('Doomed'), findsOneWidget);

    repo.failOnPut = false;
    await tester.tap(find.byKey(const ValueKey<String>('save-retry')));
    await tester.pumpAndSettle();
    expect(find.text(GraveyardCopy.saveError), findsNothing);
    expect(find.text('Doomed'), findsOneWidget);
  });

  testWidgets('imports a repository pushed today and shows Died today', (
    tester,
  ) async {
    final ControllerHarness h = _harness();
    await _pump(tester, h);
    final RepoRef ref = const RepoRef('flutter', 'flutter');
    h.github.enqueue(
      FakeGitHubClient.parsed(
        ref,
        pushedAt: '2026-05-10T12:00:00Z',
        today: CalendarDate(2026, 5, 10),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('empty-import')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('import-field')),
      'flutter/flutter',
    );
    await tester.tap(find.byKey(const ValueKey<String>('import-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('import-field')), findsNothing);
    expect(find.text('flutter/flutter'), findsWidgets);
    expect(find.text('Died today'), findsOneWidget);
    expect(h.github.calls, hasLength(1));
  });

  testWidgets('delete asks first, keeps on cancel, removes on confirm', (
    tester,
  ) async {
    final ControllerHarness h = _harness(
      seed: _seed(<Grave>[_manual('g1', 'Doomed', CalendarDate(2020, 1, 1))]),
    );
    await _pump(tester, h);

    await tester.tap(find.text(GraveyardCopy.delete));
    await tester.pumpAndSettle();
    expect(find.text(GraveyardCopy.deleteTitle('Doomed')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('delete-keep')));
    await tester.pumpAndSettle();
    expect(find.text('Doomed'), findsOneWidget);
    expect(h.controller.graves, hasLength(1));

    await tester.tap(find.text(GraveyardCopy.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Doomed'), findsNothing);
    expect(h.controller.graves, isEmpty);
    expect(find.text(GraveyardCopy.emptyTitle), findsOneWidget);
  });

  testWidgets('resume recomputes the dead-for text from the clock', (
    tester,
  ) async {
    final ControllerHarness h = _harness(
      seed: _seed(<Grave>[_manual('g1', 'Ticker', CalendarDate(2026, 5, 10))]),
    );
    await _pump(tester, h);
    expect(find.text('Died today'), findsOneWidget);

    h.clock.set(DateTime(2026, 5, 11, 9));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Died today'), findsNothing);
    expect(find.text('Dead for 1 day'), findsOneWidget);
  });
}
