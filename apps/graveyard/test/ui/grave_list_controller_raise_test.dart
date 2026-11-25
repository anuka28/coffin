import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/save_status.dart';

import '../support/controller_harness.dart';
import '../support/throwing_record_repository.dart';

Grave _manual(
  String id,
  String name,
  CalendarDate died, {
  CalendarDate? risen,
}) => Grave.manual(id: id, name: name, dateOfDeath: died, risenOn: risen);

final _today = CalendarDate(2026, 5, 10);

Future<ControllerHarness> _loaded(
  List<Grave> graves, {
  ThrowingRecordRepository? repository,
}) async {
  final harness = ControllerHarness(
    repository: repository,
    seed: <String, String>{
      for (final g in graves) g.id: ControllerHarness.envelopeOf(g),
    },
  );
  addTearDown(harness.dispose);
  if (repository != null) {
    for (final g in graves) {
      await repository.put(g.id, g);
    }
  }
  await harness.controller.load();
  return harness;
}

void main() {
  final a = _manual('g1', 'A', CalendarDate(2025, 6, 1));
  final b = _manual('g2', 'B', CalendarDate(2024, 6, 1));
  final c = _manual('g3', 'C', CalendarDate(2023, 6, 1));

  group('raise', () {
    test('sets risenOn to Today, keeps index and others, writes it', () async {
      final h = await _loaded([a, b, c]);
      expect(h.controller.raise('g2'), isTrue);
      await h.controller.retrySave();
      final graves = h.controller.graves;
      expect(graves.map((g) => g.id), ['g1', 'g2', 'g3']);
      expect(graves[1].risenOn, _today);
      expect(graves[0], a);
      expect(graves[2], c);
      final stored = await h.repository.get('g2');
      expect(stored?.risenOn, _today);
    });

    test(
      'a missing id returns false, writes nothing, notifies nobody',
      () async {
        final h = await _loaded([a]);
        final before = h.notifications;
        expect(h.controller.raise('nope'), isFalse);
        expect(h.notifications, before);
        expect(h.controller.saveStatus, SaveStatus.saved);
        expect(h.controller.graves, [a]);
      },
    );

    test('a second raise keeps the first date', () async {
      final h = await _loaded([a]);
      h.controller.raise('g1');
      h.clock.set(DateTime(2026, 5, 13, 9));
      expect(h.controller.raise('g1'), isTrue);
      expect(h.controller.graves.single.risenOn, _today);
    });
  });

  group('layToRest', () {
    test('clears risenOn and the stored record', () async {
      final risen = _manual('g1', 'A', CalendarDate(2025, 6, 1), risen: _today);
      final h = await _loaded([risen]);
      h.controller.layToRest('g1');
      await h.controller.retrySave();
      expect(h.controller.graves.single.risenOn, isNull);
      expect((await h.repository.get('g1'))?.risenOn, isNull);
    });

    test('a missing id does nothing', () async {
      final h = await _loaded([a]);
      final before = h.notifications;
      h.controller.layToRest('nope');
      expect(h.notifications, before);
      expect(h.controller.graves, [a]);
    });
  });

  group('replaceGrave', () {
    test('a missing id does nothing', () async {
      final h = await _loaded([a]);
      final before = h.notifications;
      h.controller.replaceGrave(_manual('zz', 'Z', CalendarDate(2020, 1, 1)));
      expect(h.notifications, before);
      expect(h.controller.graves, [a]);
      expect(await h.repository.get('zz'), isNull);
    });

    test('keeps the index without re-sorting', () async {
      final h = await _loaded([a, b]);
      // A later death date would sort first, but the place must not change.
      h.controller.replaceGrave(_manual('g2', 'B', CalendarDate(2030, 1, 1)));
      expect(h.controller.graves.map((g) => g.id), ['g1', 'g2']);
    });

    test('save status sequence equals that of an added grave', () async {
      final added = await _loaded([]);
      final addedSeq = <SaveStatus>[];
      added.controller.addListener(
        () => addedSeq.add(added.controller.saveStatus),
      );
      await added.controller.addManual(
        rawName: 'N',
        year: 2025,
        month: 1,
        day: 2,
      );
      await added.controller.retrySave();

      final h = await _loaded([a]);
      final seq = <SaveStatus>[];
      h.controller.addListener(() => seq.add(h.controller.saveStatus));
      h.controller.raise('g1');
      await h.controller.retrySave();

      expect(seq, addedSeq);
      expect(seq.last, SaveStatus.saved);
    });

    test(
      'a failing write sets saveError, keeps memory, retry writes',
      () async {
        final repo = ThrowingRecordRepository();
        final h = await _loaded([a], repository: repo);
        repo.failOnPut = true;
        h.controller.raise('g1');
        await h.controller.retrySave();
        expect(h.controller.saveStatus, SaveStatus.saveError);
        expect(h.controller.graves.single.risenOn, _today);

        repo.failOnPut = false;
        await h.controller.retrySave();
        expect(h.controller.saveStatus, SaveStatus.saved);
        expect((await repo.get('g1'))?.risenOn, _today);
      },
    );

    test('a deleted grave is not written back by a later replace', () async {
      final h = await _loaded([a]);
      final deleting = h.controller.deleteGrave('g1');
      h.controller.replaceGrave(a.copyWithRisenOn(_today));
      await deleting;
      await h.controller.retrySave();
      expect(h.controller.graves, isEmpty);
      expect(await h.repository.get('g1'), isNull);
    });
  });

  group('stored record key', () {
    test('raise stores a record with the risen key', () async {
      final h = await _loaded([a]);
      h.controller.raise('g1');
      await h.controller.retrySave();
      final stored = await h.repository.get('g1');
      expect(const GraveCodec().encode(stored!)['risen'], '2026-05-10');
    });

    test('layToRest stores a record without the risen key', () async {
      final risen = _manual('g1', 'A', CalendarDate(2025, 6, 1), risen: _today);
      final h = await _loaded([risen]);
      h.controller.layToRest('g1');
      await h.controller.retrySave();
      final stored = await h.repository.get('g1');
      expect(const GraveCodec().encode(stored!).containsKey('risen'), isFalse);
    });

    test('replaceGrave of a missing id throws nothing', () async {
      final h = await _loaded([a]);
      expect(
        () => h.controller.replaceGrave(
          _manual('zz', 'Z', CalendarDate(2020, 1, 1)),
        ),
        returnsNormally,
      );
      expect(() => h.controller.layToRest('nope'), returnsNormally);
    });
  });
}
