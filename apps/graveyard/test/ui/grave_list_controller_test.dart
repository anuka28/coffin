import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/data/grave_storage.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/fetched_repo.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/grave_rejection.dart';
import 'package:graveyard/src/domain/grave_source.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/repo_parse_problem.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/ui/grave_list_status.dart';
import 'package:graveyard/src/ui/import_state.dart';
import 'package:graveyard/src/ui/save_status.dart';

import '../support/controller_harness.dart';
import '../support/throwing_record_repository.dart';

FetchSucceeded _found(String fullName, {CalendarDate? died, String? url}) =>
    FetchSucceeded(
      FetchedRepo(
        info: RepoInfo(fullName: fullName, htmlUrl: url),
        dateOfDeath: died ?? CalendarDate(2024, 3, 1),
      ),
    );

Grave _manual(String id, String name, CalendarDate died) =>
    Grave.manual(id: id, name: name, dateOfDeath: died);

ControllerHarness _harness({
  RecordRepository<Grave>? repository,
  Map<String, String> seed = const <String, String>{},
  bool isPersistent = true,
}) {
  final harness = ControllerHarness(
    repository: repository,
    seed: seed,
    isPersistent: isPersistent,
  );
  addTearDown(harness.dispose);
  return harness;
}

Future<ControllerHarness> _loaded({
  RecordRepository<Grave>? repository,
  Map<String, String> seed = const <String, String>{},
}) async {
  final harness = _harness(repository: repository, seed: seed);
  await harness.controller.load();
  return harness;
}

Future<GraveRejection?> _add(
  ControllerHarness h,
  String name, {
  int year = 2025,
  int month = 1,
  int day = 2,
}) => h.controller.addManual(rawName: name, year: year, month: month, day: day);

void main() {
  group('load', () {
    test('starts loading, then is ready and empty with no data', () async {
      final h = _harness();
      expect(h.controller.status, GraveListStatus.loading);
      await h.controller.load();
      expect(h.controller.status, GraveListStatus.ready);
      expect(h.controller.graves, isEmpty);
      expect(h.controller.isPersistent, isTrue);
      expect(h.controller.saveStatus, SaveStatus.saved);
    });

    test('shows stored graves sorted, newest death first', () async {
      final old = _manual('g1', 'Old', CalendarDate(2020, 1, 1));
      final fresh = _manual('g2', 'Fresh', CalendarDate(2025, 6, 1));
      final h = await _loaded(
        seed: <String, String>{
          'g1': ControllerHarness.envelopeOf(old),
          'g2': ControllerHarness.envelopeOf(fresh),
        },
      );
      expect(h.controller.status, GraveListStatus.ready);
      expect(h.controller.graves, <Grave>[fresh, old]);
    });

    test('skips a corrupt entry and keeps the readable ones', () async {
      final good = _manual('g1', 'Good', CalendarDate(2020, 1, 1));
      final h = await _loaded(
        seed: <String, String>{
          'g1': ControllerHarness.envelopeOf(good),
          'bad': 'not json',
        },
      );
      expect(h.controller.status, GraveListStatus.ready);
      expect(h.controller.graves, <Grave>[good]);
    });

    test('the graves list cannot be modified', () async {
      final h = await _loaded();
      expect(
        () => h.controller.graves.add(
          _manual('x', 'X', CalendarDate(2020, 1, 1)),
        ),
        throwsUnsupportedError,
      );
    });

    test('a failed load shows the error and a retry recovers', () async {
      final repo = ThrowingRecordRepository(failOnGetAll: true);
      final h = _harness(repository: repo);
      await h.controller.load();
      expect(h.controller.status, GraveListStatus.loadError);
      expect(h.controller.graves, isEmpty);

      repo.failOnGetAll = false;
      await repo.put('g1', _manual('g1', 'Back', CalendarDate(2021, 2, 3)));
      await h.controller.load();
      expect(h.controller.status, GraveListStatus.ready);
      expect(h.controller.graves.single.name, 'Back');
    });

    test('a failure to open storage is retried by load', () async {
      var attempts = 0;
      final h = ControllerHarness(
        openStorage: () async {
          attempts++;
          if (attempts == 1) throw StateError('cannot open');
          return GraveStorage.memory();
        },
      );
      addTearDown(h.dispose);
      await h.controller.load();
      expect(h.controller.status, GraveListStatus.loadError);
      await h.controller.load();
      expect(h.controller.status, GraveListStatus.ready);
      expect(attempts, 2);
    });
  });

  group('memory fallback', () {
    test(
      'runs with a non-persistent repository and every feature works',
      () async {
        final h = _harness(isPersistent: false);
        await h.controller.load();
        expect(h.controller.isPersistent, isFalse);
        expect(await _add(h, 'Draft'), isNull);
        await h.controller.retrySave();
        expect(h.controller.saveStatus, SaveStatus.saved);
        final id = h.controller.graves.single.id;
        await h.controller.deleteGrave(id);
        expect(h.controller.graves, isEmpty);
      },
    );
  });

  group('addManual', () {
    test('adds a normalised grave and saves it', () async {
      final h = await _loaded();
      expect(await _add(h, '  Todo   app '), isNull);
      expect(h.controller.graves.single.name, 'Todo app');
      expect(h.controller.graves.single.source, GraveSource.manual);
      await h.controller.retrySave();
      expect(h.controller.saveStatus, SaveStatus.saved);
      expect(await h.repository.getAll(), hasLength(1));
    });

    test('keeps the list sorted after an add', () async {
      final h = await _loaded();
      await _add(h, 'Middle', year: 2024);
      await _add(h, 'Newest', year: 2026);
      await _add(h, 'Oldest', year: 2020);
      expect(h.controller.graves.map((g) => g.name), <String>[
        'Newest',
        'Middle',
        'Oldest',
      ]);
    });

    test('gives each grave a unique id', () async {
      final h = await _loaded();
      await _add(h, 'One');
      await _add(h, 'Two');
      final ids = h.controller.graves.map((g) => g.id).toSet();
      expect(ids, hasLength(2));
    });

    test('every rejection returns its reason and changes nothing', () async {
      final h = await _loaded();
      await _add(h, 'Existing');
      await h.controller.retrySave();
      final before = h.controller.graves;
      final notified = h.notifications;

      final cases = <(GraveRejection, Future<GraveRejection?> Function())>[
        (GraveRejection.nameEmpty, () => _add(h, '   ')),
        (GraveRejection.nameTooLong, () => _add(h, 'a' * 81)),
        (
          GraveRejection.dateMissing,
          () => h.controller.addManual(
            rawName: 'X',
            year: null,
            month: 1,
            day: 1,
          ),
        ),
        (GraveRejection.dateNotReal, () => _add(h, 'X', month: 2, day: 30)),
        (
          GraveRejection.dateInFuture,
          () => _add(h, 'X', year: 2026, month: 5, day: 11),
        ),
        (
          GraveRejection.dateTooEarly,
          () => _add(h, 'X', year: 1969, month: 12, day: 31),
        ),
        (GraveRejection.duplicate, () => _add(h, ' existing ')),
      ];
      for (final (reason, run) in cases) {
        expect(await run(), reason, reason: reason.name);
        expect(h.controller.graves, before, reason: reason.name);
      }
      expect(h.notifications, notified, reason: 'rejections do not notify');
      expect(h.controller.saveStatus, SaveStatus.saved);
      expect(await h.repository.getAll(), hasLength(1));
      expect(h.controller.saveStatus, SaveStatus.saved);
    });

    test('the same name on another day is not a duplicate', () async {
      final h = await _loaded();
      expect(await _add(h, 'Twin'), isNull);
      expect(await _add(h, 'Twin', day: 3), isNull);
      expect(h.controller.graves, hasLength(2));
    });

    test('reads Today from the clock at each add', () async {
      final h = await _loaded();
      expect(h.controller.today, CalendarDate(2026, 5, 10));
      expect(
        await _add(h, 'Soon', year: 2026, month: 5, day: 11),
        GraveRejection.dateInFuture,
      );
      h.clock.set(DateTime(2026, 5, 12, 9));
      expect(h.controller.today, CalendarDate(2026, 5, 12));
      expect(await _add(h, 'Soon', year: 2026, month: 5, day: 11), isNull);
    });
  });

  group('startImport', () {
    test('success adds a github grave named by full_name', () async {
      final h = await _loaded();
      h.github.enqueue(_found('Octo/Hello-World', url: 'https://x.test/a'));
      final state = await h.controller.startImport('octo/hello-world');
      final grave = h.controller.graves.single;
      expect(state, ImportSucceeded(grave.id));
      expect(h.controller.importState, ImportSucceeded(grave.id));
      expect(grave.name, 'Octo/Hello-World');
      expect(grave.source, GraveSource.github);
      expect(grave.dateOfDeath, CalendarDate(2024, 3, 1));
      expect(grave.repo?.fullName, 'Octo/Hello-World');
      expect(h.github.calls.single.ref, const RepoRef('octo', 'hello-world'));
      await h.controller.retrySave();
      expect(await h.repository.getAll(), <Grave>[grave]);
    });

    test(
      'each failure kind ends in ImportFetchFailed and adds nothing',
      () async {
        final h = await _loaded();
        for (final kind in ImportFailureKind.values) {
          final failure = ImportFailure(kind);
          h.github.enqueue(FetchFailed(failure));
          final state = await h.controller.startImport('a/b');
          expect(state, ImportFetchFailed(failure), reason: kind.name);
          expect(h.controller.importState, ImportFetchFailed(failure));
          expect(h.controller.graves, isEmpty);
        }
      },
    );

    test('an exception from the client becomes an offline failure', () async {
      final h = await _loaded();
      final held = h.github.enqueueHeld();
      final running = h.controller.startImport('a/b');
      held.completeError(StateError('boom'));
      await running;
      expect(
        h.controller.importState,
        const ImportFetchFailed(ImportFailure(ImportFailureKind.offline)),
      );
      expect(h.controller.graves, isEmpty);
    });

    test('a new attempt clears the earlier failure', () async {
      final h = await _loaded();
      h.github.enqueue(
        const FetchFailed(ImportFailure(ImportFailureKind.offline)),
      );
      await h.controller.startImport('a/b');
      final held = h.github.enqueueHeld();
      final running = h.controller.startImport('a/b');
      expect(h.controller.importState, const ImportRunning(RepoRef('a', 'b')));
      held.complete(_found('a/b'));
      await running;
      expect(h.controller.importState, isA<ImportSucceeded>());
    });

    test('rejects each bad input without a request', () async {
      final h = await _loaded();
      final inputs = <String, RepoParseProblem>{
        'https://gitlab.com/a/b': RepoParseProblem.notGitHub,
        'justone': RepoParseProblem.needOwnerRepo,
        '-bad-/repo': RepoParseProblem.invalidOwner,
        'owner/bad name': RepoParseProblem.invalidRepo,
      };
      for (final entry in inputs.entries) {
        final state = await h.controller.startImport(entry.key);
        expect(state, ImportInputRejected(entry.value), reason: entry.key);
        expect(h.controller.importState, state);
      }
      expect(h.github.calls, isEmpty);
      expect(h.controller.graves, isEmpty);
    });

    test('a duplicate adds nothing and names the existing grave', () async {
      final h = await _loaded();
      h.github.enqueue(_found('octo/repo'));
      await h.controller.startImport('octo/repo');
      await h.controller.retrySave();

      h.github.enqueue(_found('Octo/Repo'));
      final state = await h.controller.startImport('octo/repo');
      expect(state, const ImportDuplicateFound('Octo/Repo'));
      expect(h.controller.graves, hasLength(1));
      expect(await h.repository.getAll(), hasLength(1));
    });

    test('cuts a long name to 79 characters plus an ellipsis', () async {
      final h = await _loaded();
      final repoName = 'r' * 100;
      final fullName = 'owner/$repoName';
      h.github.enqueue(_found(fullName));
      await h.controller.startImport(fullName);
      final grave = h.controller.graves.single;
      expect(grave.name, '${'r' * 79}…');
      expect(grave.name.runes.length, 80);
      expect(grave.repo?.fullName, fullName);
      await h.controller.retrySave();
      final stored = (await h.repository.getAll()).single;
      expect(stored.repo?.fullName, fullName);
    });

    test('a double submit starts one request', () async {
      final h = await _loaded();
      final held = h.github.enqueueHeld();
      final first = h.controller.startImport('a/b');
      final second = h.controller.startImport('a/b');
      expect(h.github.calls, hasLength(1));
      expect(await second, isA<ImportRunning>());
      held.complete(_found('a/b'));
      expect(await first, isA<ImportSucceeded>());
      expect(h.github.calls, hasLength(1));
      expect(h.controller.graves, hasLength(1));
    });

    test('reads Today from the clock at each import', () async {
      final h = await _loaded();
      h.github.enqueue(_found('a/one'));
      await h.controller.startImport('a/one');
      h.clock.set(DateTime(2026, 7, 4, 8));
      h.github.enqueue(_found('a/two'));
      await h.controller.startImport('a/two');
      expect(h.github.calls[0].today, CalendarDate(2026, 5, 10));
      expect(h.github.calls[1].today, CalendarDate(2026, 7, 4));
    });
  });

  group('cancelImport and dispose', () {
    test('cancelImport drops a late result and returns to idle', () async {
      final h = await _loaded();
      final held = h.github.enqueueHeld();
      final running = h.controller.startImport('a/b');
      expect(h.controller.importState, isA<ImportRunning>());
      h.controller.cancelImport();
      expect(h.controller.importState, const ImportIdle());
      held.complete(_found('a/b'));
      expect(await running, const ImportIdle());
      expect(h.controller.importState, const ImportIdle());
      expect(h.controller.graves, isEmpty);
      await h.controller.retrySave();
      expect(await h.repository.getAll(), isEmpty);
    });

    test('cancelImport when idle does not notify', () async {
      final h = await _loaded();
      final before = h.notifications;
      h.controller.cancelImport();
      expect(h.notifications, before);
    });

    test('a late failure after cancelImport is dropped too', () async {
      final h = await _loaded();
      final held = h.github.enqueueHeld();
      final running = h.controller.startImport('a/b');
      h.controller.cancelImport();
      held.complete(
        const FetchFailed(ImportFailure(ImportFailureKind.offline)),
      );
      await running;
      expect(h.controller.importState, const ImportIdle());
    });

    test('a late result after dispose is dropped without notifying', () async {
      final h = await _loaded();
      final held = h.github.enqueueHeld();
      final running = h.controller.startImport('a/b');
      final before = h.notifications;
      h.dispose();
      held.complete(_found('a/b'));
      await running;
      expect(h.notifications, before);
      expect(h.controller.graves, isEmpty);
    });

    test('a write finishing after dispose does not notify', () async {
      final h = await _loaded();
      await _add(h, 'Late');
      final before = h.notifications;
      h.dispose();
      await h.controller.retrySave();
      expect(h.notifications, before);
    });

    test('refreshToday notifies, and not after dispose', () async {
      final h = await _loaded();
      final before = h.notifications;
      h.controller.refreshToday();
      expect(h.notifications, before + 1);
      h.dispose();
      h.controller.refreshToday();
      expect(h.notifications, before + 1);
    });
  });

  group('saving', () {
    test('writes in the order the changes were made', () async {
      final h = await _loaded();
      final events = <StorageEvent>[];
      final sub = h.repository.watch().listen(events.add);
      addTearDown(sub.cancel);

      await _add(h, 'First');
      await _add(h, 'Second', day: 3);
      await h.controller.retrySave();
      await h.controller.deleteGrave('g1');
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => '${e.kind.name}:${e.key}'), <String>[
        'put:g1',
        'put:g2',
        'delete:g1',
      ]);
    });

    test('reports saving until the writes finish, then saved', () async {
      final h = await _loaded();
      await _add(h, 'One');
      expect(h.controller.saveStatus, SaveStatus.saving);
      await h.controller.retrySave();
      expect(h.controller.saveStatus, SaveStatus.saved);
    });

    test('a failed write keeps the list and a retry saves it', () async {
      final repo = ThrowingRecordRepository(failOnPut: true);
      final h = await _loaded(repository: repo);
      expect(await _add(h, 'Keep me'), isNull);
      await h.controller.retrySave();
      expect(h.controller.saveStatus, SaveStatus.saveError);
      expect(h.controller.graves.single.name, 'Keep me');
      expect(await repo.getAll(), isEmpty);

      // The app stays usable while the save is failing.
      expect(await _add(h, 'Also', day: 5), isNull);
      expect(h.controller.graves, hasLength(2));

      repo.failOnPut = false;
      await h.controller.retrySave();
      expect(h.controller.saveStatus, SaveStatus.saved);
      expect(await repo.getAll(), hasLength(2));
    });

    test('a failed delete keeps it pending and a retry repeats it', () async {
      final repo = ThrowingRecordRepository();
      final h = await _loaded(repository: repo);
      await _add(h, 'Doomed');
      await h.controller.retrySave();
      final id = h.controller.graves.single.id;

      repo.failOnDelete = true;
      await h.controller.deleteGrave(id);
      expect(h.controller.graves, isEmpty);
      expect(h.controller.saveStatus, SaveStatus.saveError);
      expect(await repo.getAll(), hasLength(1));

      repo.failOnDelete = false;
      await h.controller.retrySave();
      expect(h.controller.saveStatus, SaveStatus.saved);
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('deleteGrave', () {
    test('removes the grave from the list and from storage', () async {
      final h = await _loaded();
      await _add(h, 'Gone');
      await _add(h, 'Stays', day: 3);
      await h.controller.retrySave();
      final gone = h.controller.graves.firstWhere((g) => g.name == 'Gone');
      await h.controller.deleteGrave(gone.id);
      expect(h.controller.graves.map((g) => g.name), <String>['Stays']);
      expect(h.controller.saveStatus, SaveStatus.saved);
      expect((await h.repository.getAll()).map((g) => g.name), <String>[
        'Stays',
      ]);
    });

    test('an unknown id changes nothing and does not notify', () async {
      final h = await _loaded();
      await _add(h, 'Here');
      await h.controller.retrySave();
      final before = h.notifications;
      await h.controller.deleteGrave('nope');
      expect(h.controller.graves, hasLength(1));
      expect(h.notifications, before);
    });

    test('a grave deleted before its write is never stored', () async {
      final h = await _loaded();
      await _add(h, 'Quick');
      final id = h.controller.graves.single.id;
      await h.controller.deleteGrave(id);
      expect(await h.repository.getAll(), isEmpty);
      expect(h.controller.saveStatus, SaveStatus.saved);
    });
  });

  group('disposeStorage', () {
    test('closes the repository and ignores a second close', () async {
      final h = await _loaded();
      await h.controller.disposeStorage();
      await h.controller.disposeStorage();
    });

    test('does nothing when storage was never opened', () async {
      final h = _harness();
      await h.controller.disposeStorage();
    });
  });
}
