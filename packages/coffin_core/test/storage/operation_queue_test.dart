import 'dart:async';

import 'package:coffin_core/src/storage/operation_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OperationQueue', () {
    test(
      'runs operations in submission order even when earlier ones are slower',
      () async {
        final queue = OperationQueue();
        final log = <String>[];

        Future<void> op(String name, int ms) async {
          log.add('start $name');
          await Future<void>.delayed(Duration(milliseconds: ms));
          log.add('end $name');
        }

        await Future.wait([
          queue.run(() => op('a', 30)),
          queue.run(() => op('b', 1)),
          queue.run(() => op('c', 10)),
        ]);

        expect(log, [
          'start a',
          'end a',
          'start b',
          'end b',
          'start c',
          'end c',
        ]);
      },
    );

    test('returns each result to the right caller', () async {
      final queue = OperationQueue();
      final results = await Future.wait([
        queue.run(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 1;
        }),
        queue.run(() async => 'two'),
        queue.run(() async => 3.5),
      ]);
      expect(results, [1, 'two', 3.5]);
    });

    test(
      'a failing operation errors its own future; later ones still run',
      () async {
        final queue = OperationQueue();
        final failing = queue.run<int>(() async => throw StateError('boom'));
        final later = queue.run(() async => 42);

        await expectLater(failing, throwsA(isA<StateError>()));
        expect(await later, 42);
        expect(await queue.run(() async => 'still works'), 'still works');
      },
    );

    test(
      'a synchronously throwing operation does not block the queue',
      () async {
        final queue = OperationQueue();
        final failing = queue.run<int>(() => throw ArgumentError('sync'));
        final later = queue.run(() async => 7);

        await expectLater(failing, throwsA(isA<ArgumentError>()));
        expect(await later, 7);
      },
    );

    test('a swallowed failure raises no uncaught error in the zone', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        final queue = OperationQueue();
        final failing = queue.run<int>(() async => throw StateError('boom'));
        final later = queue.run(() async => 1);
        final another = queue.run<int>(() async => throw FormatException('x'));
        final last = queue.run(() async => 2);

        Object? caught;
        try {
          await failing;
        } on StateError catch (e) {
          caught = e;
        }
        expect(caught, isA<StateError>());
        expect(await later, 1);
        await expectLater(another, throwsFormatException);
        expect(await last, 2);
        // Let any stray async error surface before leaving the zone.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, (error, stack) => uncaught.add(error));

      expect(uncaught, isEmpty);
    });
  });
}
