import 'dart:async';

import 'package:coffin_core/coffin_core.dart';
import 'package:flutter/foundation.dart';

import '../data/github_client.dart';
import '../domain/calendar_date.dart';
import '../domain/clock.dart';
import '../domain/duplicate_rules.dart';
import '../domain/fetch_result.dart';
import '../domain/grave.dart';
import '../domain/grave_ids.dart';
import '../domain/grave_rejection.dart';
import '../domain/grave_rules.dart';
import '../domain/grave_sorter.dart';
import '../domain/import_failure.dart';
import '../domain/import_failure_kind.dart';
import '../domain/manual_grave_check.dart';
import '../domain/name_rules.dart';
import '../domain/raise_rules.dart';
import '../domain/repo_input_parser.dart';
import '../domain/repo_parse_result.dart';
import 'grave_list_status.dart';
import 'import_state.dart';
import 'save_status.dart';

/// Owns the list of graves, the saving state and the import state machine.
///
/// Widgets read its state and forward user actions. They never call the GitHub
/// client or the repository. The controller owns no timer.
class GraveListController extends ChangeNotifier {
  /// Creates a controller. Nothing is opened until [load] is called.
  GraveListController({
    required this._clock,
    required this._github,
    required this._openStorage,
  });

  final Clock _clock;
  final GitHubClient _github;
  final Future<OpenedRepository<Grave>> Function() _openStorage;

  OpenedRepository<Grave>? _opened;
  List<Grave> _graves = const <Grave>[];
  GraveListStatus _status = GraveListStatus.loading;
  SaveStatus _saveStatus = SaveStatus.saved;
  ImportState _importState = const ImportIdle();

  int _generation = 0;
  bool _disposed = false;

  Future<void> _writeChain = Future<void>.value();
  int _outstandingWrites = 0;
  final Set<String> _pendingPuts = <String>{};
  final Set<String> _pendingDeletes = <String>{};

  /// Whether loading has finished, is running, or has failed.
  GraveListStatus get status => _status;

  /// Whether the last writes finished, are running, or failed.
  SaveStatus get saveStatus => _saveStatus;

  /// The graves, newest death first. The list cannot be modified.
  List<Grave> get graves => List<Grave>.unmodifiable(_graves);

  /// Whether the graves are kept on the device. False until storage opens, and
  /// false when storage fell back to memory.
  bool get isPersistent => _opened?.isPersistent ?? false;

  /// The state of the import started from the add sheet.
  ImportState get importState => _importState;

  /// The clock. Widgets read time only through it.
  Clock get clock => _clock;

  /// Today's date on the local calendar, read from the clock at each call.
  CalendarDate get today => CalendarDate.fromDateTime(_clock.now());

  /// Opens storage on the first call, reads and sorts the graves.
  ///
  /// A failure to open or read sets [GraveListStatus.loadError]. Calling it
  /// again retries.
  Future<void> load() async {
    if (_status != GraveListStatus.loading) {
      _status = GraveListStatus.loading;
      _notify();
    }
    try {
      final opened = _opened ?? await _openStorage();
      _opened = opened;
      final loaded = await opened.repository.getAll();
      _graves = GraveSorter.sort(loaded);
      _status = GraveListStatus.ready;
    } catch (_) {
      _status = GraveListStatus.loadError;
    }
    _notify();
  }

  /// Tells listeners to recompute everything that depends on Today, for
  /// example when the app returns to the foreground after midnight.
  void refreshToday() => _notify();

  /// Buries a project by hand.
  ///
  /// Returns the reason when the grave is refused, and changes nothing then.
  /// Returns null when the grave was added.
  Future<GraveRejection?> addManual({
    required String rawName,
    required int? year,
    required int? month,
    required int? day,
  }) async {
    final check = GraveRules.checkManual(
      rawName: rawName,
      year: year,
      month: month,
      day: day,
      today: today,
    );
    switch (check) {
      case ManualGraveRejected(:final reason):
        return reason;
      case ManualGraveAccepted(:final name, :final dateOfDeath):
        final grave = Grave.manual(
          id: GraveIds.next(_graves.map((g) => g.id)),
          name: name,
          dateOfDeath: dateOfDeath,
        );
        if (DuplicateRules.isDuplicate(grave, _graves)) {
          return GraveRejection.duplicate;
        }
        _insert(grave);
        _notify();
        _enqueueWrite();
        return null;
    }
  }

  /// Starts importing a public repository from [text].
  ///
  /// Only one import runs at a time. A second call while one runs returns the
  /// current state. Returns the state the attempt ended in.
  Future<ImportState> startImport(String text) async {
    if (_importState is ImportRunning) return _importState;

    final parsed = RepoInputParser.parse(text);
    switch (parsed) {
      case RepoParseFailed(:final problem):
        _importState = ImportInputRejected(problem);
        _notify();
        return _importState;
      case RepoParsed(:final ref):
        final importToday = today;
        final generation = ++_generation;
        _importState = ImportRunning(ref);
        _notify();

        FetchResult result;
        try {
          result = await _github.fetch(ref, today: importToday);
        } catch (_) {
          result = const FetchFailed(ImportFailure(ImportFailureKind.offline));
        }
        if (_disposed || generation != _generation) return const ImportIdle();

        switch (result) {
          case FetchFailed(:final failure):
            _importState = ImportFetchFailed(failure);
            _notify();
            return _importState;
          case FetchSucceeded(:final repo):
            final grave = Grave.github(
              id: GraveIds.next(_graves.map((g) => g.id)),
              name: NameRules.forRepo(repo.info.fullName),
              dateOfDeath: repo.dateOfDeath,
              repo: repo.info,
            );
            if (DuplicateRules.isDuplicate(grave, _graves)) {
              _importState = ImportDuplicateFound(repo.info.fullName);
              _notify();
              return _importState;
            }
            _insert(grave);
            _importState = ImportSucceeded(grave.id);
            _notify();
            _enqueueWrite();
            return _importState;
        }
    }
  }

  /// Called when the add sheet closes. Drops any import result still on its
  /// way and returns the import state to idle.
  void cancelImport() {
    _generation++;
    if (_importState is! ImportIdle) {
      _importState = const ImportIdle();
      _notify();
    }
  }

  /// Removes the grave with [id]. Does nothing when there is no such grave.
  Future<void> deleteGrave(String id) async {
    final index = _graves.indexWhere((g) => g.id == id);
    if (index < 0) return;
    _graves = List<Grave>.of(_graves)..removeAt(index);
    _pendingPuts.remove(id);
    _pendingDeletes.add(id);
    _notify();
    _enqueueWrite();
    await _writeChain;
  }

  /// Replaces the grave that has the same id as [grave], at the same place in
  /// the list, and saves it. Does nothing, without a write or a notification,
  /// when no grave has that id.
  void replaceGrave(Grave grave) {
    final index = _graves.indexWhere((g) => g.id == grave.id);
    if (index < 0) return;
    _graves = List<Grave>.of(_graves)..[index] = grave;
    _pendingDeletes.remove(grave.id);
    _pendingPuts.add(grave.id);
    _notify();
    _enqueueWrite();
  }

  /// Raises the grave with [id], dated Today. A grave that is already risen
  /// keeps its first date. Returns false when there is no such grave.
  bool raise(String id) {
    final index = _graves.indexWhere((g) => g.id == id);
    if (index < 0) return false;
    replaceGrave(RaiseRules.raise(_graves[index], today));
    return true;
  }

  /// Lays the grave with [id] back to rest. Does nothing when there is no such
  /// grave.
  void layToRest(String id) {
    final index = _graves.indexWhere((g) => g.id == id);
    if (index < 0) return;
    replaceGrave(RaiseRules.layToRest(_graves[index]));
  }

  /// Repeats every write and delete that has not reached storage yet.
  Future<void> retrySave() {
    _enqueueWrite();
    return _writeChain;
  }

  /// Closes the repository. A [StateError] from a repository that is already
  /// closed is ignored.
  Future<void> disposeStorage() async {
    final opened = _opened;
    if (opened == null) return;
    try {
      await opened.repository.close();
    } on StateError {
      // Already closed.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _insert(Grave grave) {
    _graves = GraveSorter.sort(<Grave>[..._graves, grave]);
    _pendingDeletes.remove(grave.id);
    _pendingPuts.add(grave.id);
  }

  /// Adds one step to the ordered write chain. The step writes everything
  /// still pending, so a failed write is repeated by the next step.
  void _enqueueWrite() {
    _outstandingWrites++;
    if (_saveStatus != SaveStatus.saving) {
      _saveStatus = SaveStatus.saving;
      _notify();
    }
    _writeChain = _writeChain.then((_) => _flush());
  }

  Future<void> _flush() async {
    final repository = _opened?.repository;
    for (final id in List<String>.of(_pendingPuts)) {
      final index = _graves.indexWhere((g) => g.id == id);
      if (index < 0) {
        _pendingPuts.remove(id);
        continue;
      }
      try {
        if (repository == null) throw StateError('Storage is not open.');
        await repository.put(id, _graves[index]);
        _pendingPuts.remove(id);
      } catch (_) {
        // Kept in the pending set, repeated by the next step or retrySave.
      }
    }
    for (final id in List<String>.of(_pendingDeletes)) {
      try {
        if (repository == null) throw StateError('Storage is not open.');
        await repository.delete(id);
        _pendingDeletes.remove(id);
      } catch (_) {
        // Kept in the pending set, repeated by the next step or retrySave.
      }
    }
    _outstandingWrites--;
    if (_outstandingWrites == 0) {
      _saveStatus = _pendingPuts.isEmpty && _pendingDeletes.isEmpty
          ? SaveStatus.saved
          : SaveStatus.saveError;
      _notify();
    }
  }
}
