import 'dart:convert';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/data/grave_storage.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';

Grave _grave() => Grave.manual(
  id: 'g1',
  name: 'Old app',
  dateOfDeath: CalendarDate(2024, 2, 29),
);

String _envelope(int version, Map<String, Object?> data) =>
    jsonEncode(<String, Object?>{'v': version, 'data': data});

void main() {
  test('uses the agreed box name, version and sub-directory', () {
    expect(GraveStorage.boxName, 'graveyard_graves');
    expect(GraveStorage.currentVersion, 1);
    expect(GraveStorage.subDirectory, 'graveyard');
  });

  test('open asks for the agreed box and uses the GraveCodec', () async {
    final List<String> requested = <String>[];
    final OpenedRepository<Grave> opened = await GraveStorage.open(
      StorageOpener(
        initializer: () async {},
        openStore: (String boxName, String? location) async {
          requested.add(boxName);
          throw StateError('fake store refuses');
        },
      ),
    );
    expect(requested, <String>['graveyard_graves']);
    expect(opened.isPersistent, isFalse);

    // The fallback repository uses the codec passed to the opener.
    await opened.repository.put('g1', _grave());
    final List<Grave> all = await opened.repository.getAll();
    expect(all.map((Grave g) => g.id), <String>['g1']);
    expect(all.single.name, 'Old app');
    await opened.repository.close();
  });

  test('open reports isPersistent false when the initializer fails', () async {
    final OpenedRepository<Grave> opened = await GraveStorage.open(
      StorageOpener(initializer: () async => throw StateError('no disk')),
    );
    expect(opened.isPersistent, isFalse);
    await opened.repository.close();
  });

  test('memory() is not persistent and stores graves', () async {
    final OpenedRepository<Grave> opened = GraveStorage.memory();
    expect(opened.isPersistent, isFalse);
    await opened.repository.put('g1', _grave());
    final List<Grave> all = await opened.repository.getAll();
    expect(all.map((Grave g) => g.id), <String>['g1']);
    await opened.repository.close();
  });

  test('a corrupt entry is skipped while readable entries load', () async {
    final List<StorageIssue> issues = <StorageIssue>[];
    final MemoryRecordRepository<Grave> repository =
        MemoryRecordRepository<Grave>(
          codec: const GraveCodec(),
          currentVersion: GraveStorage.currentVersion,
          reportIssue: issues.add,
          seed: <String, String>{
            'good': _envelope(1, const GraveCodec().encode(_grave())),
            'bad': _envelope(1, <String, Object?>{'id': 'bad'}),
            'junk': 'not json',
          },
        );
    final List<Grave> all = await repository.getAll();
    expect(all.map((Grave g) => g.id), <String>['g1']);
    expect(issues, hasLength(2));
    expect(
      issues.map((StorageIssue i) => i.kind),
      everyElement(StorageIssueKind.corruptRecord),
    );
    await repository.close();
  });
}
