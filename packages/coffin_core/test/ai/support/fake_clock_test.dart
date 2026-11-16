import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'fake_clock.dart';

void main() {
  group('FakeClock', () {
    test('starts at zero with no pending timers', () {
      final FakeClock clock = FakeClock();
      expect(clock.now, Duration.zero);
      expect(clock.pendingTimers, 0);
    });

    test('advance moves now by exactly the elapsed time', () {
      final FakeClock clock = FakeClock();
      clock.advance(const Duration(seconds: 3));
      clock.advance(const Duration(milliseconds: 5));
      expect(clock.now, const Duration(seconds: 3, milliseconds: 5));
    });

    test('advance rejects a negative duration', () {
      expect(
        () => FakeClock().advance(const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
    });

    test('timers fire in due-time order, ties in creation order', () {
      final FakeClock clock = FakeClock();
      final List<String> fired = <String>[];
      clock.create(const Duration(seconds: 3), () => fired.add('c'));
      clock.create(const Duration(seconds: 1), () => fired.add('a'));
      clock.create(const Duration(seconds: 2), () => fired.add('b1'));
      clock.create(const Duration(seconds: 2), () => fired.add('b2'));
      clock.advance(const Duration(seconds: 10));
      expect(fired, <String>['a', 'b1', 'b2', 'c']);
      expect(clock.now, const Duration(seconds: 10));
    });

    test('now equals the due time while a timer callback runs', () {
      final FakeClock clock = FakeClock();
      final List<Duration> seen = <Duration>[];
      clock.create(const Duration(seconds: 1), () => seen.add(clock.now));
      clock.create(const Duration(seconds: 2), () => seen.add(clock.now));
      clock.advance(const Duration(seconds: 5));
      expect(seen, <Duration>[
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });

    test('a timer due at exactly now + d fires on advance(d), not before', () {
      final FakeClock clock = FakeClock();
      const Duration d = Duration(seconds: 30);
      int fired = 0;
      clock.advance(const Duration(seconds: 7));
      clock.create(d, () => fired++);
      clock.advance(d - const Duration(milliseconds: 1));
      expect(fired, 0);
      expect(clock.pendingTimers, 1);
      clock.advance(const Duration(milliseconds: 1));
      expect(fired, 1);
      expect(clock.pendingTimers, 0);
    });

    test('a timer due at exactly now + d fires on a single advance(d)', () {
      final FakeClock clock = FakeClock();
      const Duration d = Duration(seconds: 30);
      int fired = 0;
      clock.create(d, () => fired++);
      clock.advance(d);
      expect(fired, 1);
    });

    test('advance is synchronous and runs no microtask', () async {
      final FakeClock clock = FakeClock();
      final List<String> order = <String>[];
      clock.create(const Duration(seconds: 1), () => order.add('timer'));
      unawaited(Future<void>.value().then((_) => order.add('microtask')));
      clock.advance(const Duration(seconds: 1));
      expect(order, <String>['timer']);
      for (int i = 0; i < 5; i++) {
        await Future<void>.value();
      }
      expect(order, <String>['timer', 'microtask']);
    });

    test('a timer created inside the window by a callback fires too', () {
      final FakeClock clock = FakeClock();
      final List<String> fired = <String>[];
      clock.create(const Duration(seconds: 1), () {
        fired.add('first');
        clock.create(const Duration(seconds: 1), () => fired.add('second'));
        clock.create(const Duration(seconds: 9), () => fired.add('late'));
      });
      clock.advance(const Duration(seconds: 3));
      expect(fired, <String>['first', 'second']);
      expect(clock.pendingTimers, 1);
    });

    test('a zero duration timer fires on the next advance', () {
      final FakeClock clock = FakeClock();
      int fired = 0;
      clock.create(Duration.zero, () => fired++);
      expect(fired, 0);
      clock.advance(Duration.zero);
      expect(fired, 1);
    });

    test('a timer fires once only', () {
      final FakeClock clock = FakeClock();
      int fired = 0;
      clock.create(const Duration(seconds: 1), () => fired++);
      clock.advance(const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 5));
      expect(fired, 1);
    });

    test('a cancelled timer never fires', () {
      final FakeClock clock = FakeClock();
      int fired = 0;
      final Timer timer = clock.create(const Duration(seconds: 1), () {
        fired++;
      });
      timer.cancel();
      clock.advance(const Duration(seconds: 10));
      expect(fired, 0);
    });

    test('a timer cancelled by an earlier callback does not fire', () {
      final FakeClock clock = FakeClock();
      int fired = 0;
      late final Timer second;
      clock.create(const Duration(seconds: 1), () => second.cancel());
      second = clock.create(const Duration(seconds: 2), () => fired++);
      clock.advance(const Duration(seconds: 5));
      expect(fired, 0);
    });

    test('isActive and tick behave like a one-shot Timer', () {
      final FakeClock clock = FakeClock();
      final Timer fires = clock.create(const Duration(seconds: 1), () {});
      final Timer cancelled = clock.create(const Duration(seconds: 1), () {});
      expect(fires.isActive, isTrue);
      expect(fires.tick, 0);
      cancelled.cancel();
      expect(cancelled.isActive, isFalse);
      cancelled.cancel(); // a second cancel is harmless
      expect(cancelled.isActive, isFalse);
      clock.advance(const Duration(seconds: 1));
      expect(fires.isActive, isFalse);
      expect(fires.tick, 1);
      fires.cancel(); // cancel after firing is harmless
      expect(fires.isActive, isFalse);
    });

    test('pendingTimers counts active timers only', () {
      final FakeClock clock = FakeClock();
      final Timer a = clock.create(const Duration(seconds: 1), () {});
      clock.create(const Duration(seconds: 2), () {});
      clock.create(const Duration(seconds: 3), () {});
      expect(clock.pendingTimers, 3);
      a.cancel();
      expect(clock.pendingTimers, 2);
      clock.advance(const Duration(seconds: 2));
      expect(clock.pendingTimers, 1);
      clock.advance(const Duration(seconds: 1));
      expect(clock.pendingTimers, 0);
    });

    test('the timer duration counts from the clock time at creation', () {
      final FakeClock clock = FakeClock();
      clock.advance(const Duration(seconds: 10));
      int fired = 0;
      clock.create(const Duration(seconds: 5), () => fired++);
      clock.advance(const Duration(seconds: 4));
      expect(fired, 0);
      clock.advance(const Duration(seconds: 1));
      expect(fired, 1);
    });
  });
}
