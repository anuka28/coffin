import 'dart:async';

import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/record_codec.dart';
import 'package:coffin_core/src/storage/record_repository.dart';
import 'package:coffin_core/src/storage/storage_event.dart';
import 'package:flutter_test/flutter_test.dart';

class _Note {
  const _Note(this.text);
  final String text;
}

class _NoteCodec implements RecordCodec<_Note> {
  const _NoteCodec();

  @override
  JsonMap encode(_Note record) => {'text': record.text};

  @override
  _Note decode(JsonMap json) => _Note(json['text']! as String);
}

class _FakeRepository implements RecordRepository<_Note> {
  final Map<String, JsonMap> _data = {};
  final StreamController<StorageEvent> _events = StreamController.broadcast();
  final RecordCodec<_Note> _codec = const _NoteCodec();

  @override
  Future<_Note?> get(String key) async {
    final json = _data[key];
    return json == null ? null : _codec.decode(json);
  }

  @override
  Future<List<_Note>> getAll() async {
    final keys = _data.keys.toList()..sort();
    return [for (final k in keys) _codec.decode(_data[k]!)];
  }

  @override
  Future<void> put(String key, _Note record) async {
    _data[key] = _codec.encode(record);
    _events.add(StorageEvent.put(key));
  }

  @override
  Future<void> delete(String key) async {
    if (_data.remove(key) != null) _events.add(StorageEvent.delete(key));
  }

  @override
  Future<void> clear() async {
    _data.clear();
    _events.add(const StorageEvent.clear());
  }

  @override
  Stream<StorageEvent> watch() => _events.stream;

  @override
  Future<void> close() => _events.close();
}

void main() {
  group('RecordCodec', () {
    test('encode and decode round trip through a JsonMap', () {
      const codec = _NoteCodec();
      final JsonMap json = codec.encode(const _Note('boo'));
      expect(json, {'text': 'boo'});
      expect(codec.decode(json).text, 'boo');
    });
  });

  group('RecordRepository', () {
    test('has the expected shape', () async {
      final RecordRepository<_Note> repo = _FakeRepository();
      final events = <StorageEvent>[];
      final sub = repo.watch().listen(events.add);

      expect(await repo.get('missing'), isNull);
      await repo.put('b', const _Note('two'));
      await repo.put('a', const _Note('one'));
      expect((await repo.get('a'))!.text, 'one');
      expect((await repo.getAll()).map((n) => n.text), ['one', 'two']);
      await repo.delete('a');
      await repo.clear();
      await Future<void>.delayed(Duration.zero);
      expect(events, const [
        StorageEvent.put('b'),
        StorageEvent.put('a'),
        StorageEvent.delete('a'),
        StorageEvent.clear(),
      ]);

      await sub.cancel();
      await repo.close();
    });
  });

  group('StorageEvent', () {
    test('has value equality and a readable toString', () {
      expect(const StorageEvent.put('a'), const StorageEvent.put('a'));
      expect(
        const StorageEvent.put('a'),
        isNot(const StorageEvent.delete('a')),
      );
      expect(const StorageEvent.clear().key, isNull);
      expect(const StorageEvent.put('a').toString(), 'StorageEvent.put("a")');
      expect(const StorageEvent.clear().toString(), 'StorageEvent.clear()');
    });
  });
}
