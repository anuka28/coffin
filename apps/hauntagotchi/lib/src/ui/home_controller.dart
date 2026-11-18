import 'package:flutter/foundation.dart';

import '../data/haunt_storage.dart';
import '../domain/clock.dart';
import '../domain/ghost.dart';
import '../domain/habit.dart';
import '../domain/habit_book.dart';
import '../domain/habit_rejection.dart';
import '../domain/haunt_result.dart';
import '../domain/haunting.dart';
import '../domain/local_day.dart';
import 'home_status.dart';
import 'save_status.dart';

/// Owns the [Haunting], the clock and the storage for the home screen.
///
/// Every action first syncs with the [Clock]. If the day changed, the new day
/// is shown and the tap is ignored. Changes show at once in memory and are
/// then written, one record after another. There is no timer.
class HomeController extends ChangeNotifier {
  /// Creates a controller. [openStorage] is called by [load].
  HomeController({required this._clock, required this._openStorage});

  final Clock _clock;
  final Future<HauntStorage> Function() _openStorage;

  HauntStorage? _storage;
  Haunting? _haunting;
  HomeStatus _status = HomeStatus.loading;
  SaveStatus _saveStatus = SaveStatus.saved;
  bool _isPersistent = true;
  String? _welcomeBack;
  bool _disposed = false;
  bool _writeFailed = false;
  int _writesInFlight = 0;
  Future<void> _writeChain = Future<void>.value();

  /// Where loading stands.
  HomeStatus get status => _status;

  /// Whether the latest changes are written.
  SaveStatus get saveStatus => _saveStatus;

  /// The game state, or null until [status] is [HomeStatus.ready].
  Haunting? get haunting => _haunting;

  /// Whether storage saves to disk. False means progress lives in memory only.
  bool get isPersistent => _isPersistent;

  /// A message welcoming the ghost back, set when a ritual completes and
  /// cleared by [dismissWelcome].
  String? get welcomeBack => _welcomeBack;

  /// Opens storage, reads the records and builds the haunting.
  ///
  /// Also the retry after a [HomeStatus.loadError].
  Future<void> load() async {
    _status = HomeStatus.loading;
    _notify();
    try {
      final HauntStorage storage = _storage ??= await _openStorage();
      final List<Habit> stored = await storage.habits.getAll();
      final Ghost? storedGhost = await storage.ghost.get(HauntStorage.ghostKey);
      final LocalDay today = LocalDay.fromDateTime(_clock.now());
      final Haunting opened = Haunting.open(
        book: HabitBook.restore(stored, today: today),
        ghost: storedGhost,
        today: today,
      );
      _haunting = opened;
      _isPersistent = storage.isPersistent;
      _status = HomeStatus.ready;
      _notify();
      final Map<String, Habit> before = <String, Habit>{
        for (final Habit h in stored) h.id: h,
      };
      await _enqueueWrite(
        habits: <Habit>[
          for (final Habit h in opened.book.all)
            if (before[h.id] != h) h,
        ],
        ghost: opened.ghost,
      );
    } on Object {
      _status = HomeStatus.loadError;
      _notify();
    }
  }

  /// Syncs with the clock, for example when the app returns to the foreground.
  Future<void> refresh() async {
    final Haunting? current = _haunting;
    if (current == null || _status != HomeStatus.ready) {
      return;
    }
    await _syncDay(current);
  }

  /// Adds a habit. Returns the rejection reason, or null when added (or when
  /// the day changed and the tap was ignored).
  Future<HabitRejection?> addHabit(String name) =>
      _act((Haunting h) => h.addHabit(name));

  /// Renames habit [id]. Returns the rejection reason, or null.
  Future<HabitRejection?> renameHabit(String id, String name) =>
      _act((Haunting h) => h.renameHabit(id, name));

  /// Archives habit [id].
  Future<void> archiveHabit(String id) async {
    await _act((Haunting h) => h.archiveHabit(id));
  }

  /// Completes habit [id] for today, or undoes today's completion.
  Future<void> toggle(String id) async {
    await _act((Haunting h) {
      for (final Habit habit in h.book.all) {
        if (habit.id == id && habit.isCompletedOn(h.today)) {
          return h.undo(id);
        }
      }
      return h.complete(id);
    });
  }

  /// Rewrites every record after a failed write.
  Future<void> retrySave() async {
    final Haunting? current = _haunting;
    if (current == null) {
      return;
    }
    await _enqueueWrite(
      habits: current.book.all,
      ghost: current.ghost,
      isRetry: true,
    );
  }

  /// Hides the welcome-back message.
  void dismissWelcome() {
    if (_welcomeBack == null) {
      return;
    }
    _welcomeBack = null;
    _notify();
  }

  /// Closes the storage. Call when the app goes away.
  Future<void> disposeStorage() async {
    final HauntStorage? storage = _storage;
    _storage = null;
    if (storage == null) {
      return;
    }
    await _writeChain;
    try {
      await storage.close();
    } on Object {
      // Nothing more to do while closing.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Syncs with the clock. Returns true when the day changed.
  Future<bool> _syncDay(Haunting current) async {
    final Haunting synced = current.syncTo(LocalDay.fromDateTime(_clock.now()));
    if (identical(synced, current)) {
      return false;
    }
    _haunting = synced;
    _notify();
    await _enqueueWrite(
      habits: _changedHabits(current, synced),
      ghost: synced.ghost,
    );
    return synced.today != current.today;
  }

  Future<HabitRejection?> _act(HauntResult Function(Haunting) action) async {
    final Haunting? current = _haunting;
    if (current == null || _status != HomeStatus.ready) {
      return null;
    }
    // The ghost may be revived by syncing alone; treat that like any change.
    if (await _syncDay(current)) {
      return null;
    }
    final Haunting synced = _haunting ?? current;
    final HauntResult result = action(synced);
    switch (result) {
      case HauntRejected(:final reason):
        return reason;
      case HauntChanged(:final next, :final resurrected):
        _haunting = next;
        if (resurrected) {
          _welcomeBack = _welcomeText(next.ghost.name);
        }
        _notify();
        await _enqueueWrite(
          habits: _changedHabits(synced, next),
          ghost: next.ghost,
        );
        return null;
    }
  }

  List<Habit> _changedHabits(Haunting before, Haunting after) {
    final Map<String, Habit> old = <String, Habit>{
      for (final Habit h in before.book.all) h.id: h,
    };
    return <Habit>[
      for (final Habit h in after.book.all)
        if (old[h.id] != h) h,
    ];
  }

  Future<void> _enqueueWrite({
    required List<Habit> habits,
    required Ghost ghost,
    bool isRetry = false,
  }) {
    _writesInFlight++;
    _saveStatus = SaveStatus.saving;
    _notify();
    final Future<void> done = _writeChain.then((_) async {
      bool failed = false;
      try {
        final HauntStorage? storage = _storage;
        if (storage == null) {
          throw StateError('Storage is closed');
        }
        for (final Habit h in habits) {
          await storage.habits.put(h.id, h);
        }
        await storage.ghost.put(HauntStorage.ghostKey, ghost);
      } on Object {
        failed = true;
      }
      _writesInFlight--;
      if (failed) {
        _writeFailed = true;
      } else if (isRetry) {
        _writeFailed = false;
      }
      if (_writesInFlight == 0) {
        _saveStatus = _writeFailed ? SaveStatus.saveError : SaveStatus.saved;
      } else if (_writeFailed) {
        _saveStatus = SaveStatus.saving;
      }
      _notify();
    });
    _writeChain = done;
    return done;
  }

  static String _welcomeText(String ghostName) =>
      '$ghostName drifts back, a little wobbly. Welcome home.';
}
