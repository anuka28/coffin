import 'dart:async';

/// A test clock that owns the timers created through [create].
///
/// Time is a plain [Duration] that only moves when a test calls [advance].
/// [advance] fires every due timer synchronously, in due-time order, and runs
/// no microtask. Pass [create] wherever an `AiTimerFactory` is expected.
///
/// Only one-shot timers exist: there is no periodic timer.
final class FakeClock {
  /// Creates a clock at time zero with no timers.
  FakeClock();

  final List<_FakeTimer> _timers = <_FakeTimer>[];
  Duration _now = Duration.zero;
  int _nextOrder = 0;

  /// The current fake time. It starts at zero and never reads a wall clock.
  Duration get now => _now;

  /// How many timers are active: created, not yet fired, not cancelled.
  int get pendingTimers => _timers.where((_FakeTimer t) => t.isActive).length;

  /// Starts a one-shot timer that is due at `now + duration`. A zero or
  /// negative duration is due at [now] and fires on the next [advance].
  Timer create(Duration duration, void Function() callback) {
    final _FakeTimer timer = _FakeTimer(
      _now + (duration.isNegative ? Duration.zero : duration),
      _nextOrder++,
      callback,
    );
    _timers.add(timer);
    return timer;
  }

  /// Moves the clock forward by [elapsed] and fires every active timer that is
  /// due at or before the new time.
  ///
  /// Timers fire in due-time order, ties in creation order, synchronously.
  /// While a timer fires, [now] equals its due time. A timer that a callback
  /// creates and that falls inside the window fires in the same call. No
  /// microtask runs, so a completion that is still queued has not been seen
  /// when a timer callback runs.
  void advance(Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'must not be negative');
    }
    final Duration target = _now + elapsed;
    while (true) {
      _FakeTimer? next;
      for (final _FakeTimer t in _timers) {
        if (!t.isActive || t.due > target) continue;
        if (next == null ||
            t.due < next.due ||
            (t.due == next.due && t.order < next.order)) {
          next = t;
        }
      }
      if (next == null) break;
      if (next.due > _now) _now = next.due;
      next._fire();
    }
    _now = target;
    _timers.removeWhere((_FakeTimer t) => !t.isActive);
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this.due, this.order, this._callback);

  final Duration due;
  final int order;
  final void Function() _callback;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _active = false;
  }

  void _fire() {
    _active = false;
    _tick++;
    _callback();
  }
}
