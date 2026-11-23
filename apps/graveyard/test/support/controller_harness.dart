import 'dart:convert';

import 'package:coffin_core/coffin_core.dart';
import 'package:graveyard/src/data/grave_codec.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/ui/grave_list_controller.dart';

import 'fake_clock.dart';
import 'fake_github_client.dart';

/// Builds a `GraveListController` from test doubles and counts its
/// notifications.
///
/// By default the repository is a `MemoryRecordRepository<Grave>` with the
/// real `GraveCodec`, the clock reads 2026-05-10 13:00, and storage reports
/// itself persistent. Pass [repository] to use another repository, for
/// example a `ThrowingRecordRepository`.
class ControllerHarness {
  /// Creates a harness and its controller. Nothing is loaded yet.
  ControllerHarness({
    RecordRepository<Grave>? repository,
    DateTime? now,
    bool isPersistent = true,
    Map<String, String> seed = const <String, String>{},
    Future<OpenedRepository<Grave>> Function()? openStorage,
  }) : clock = FakeClock(now ?? DateTime(2026, 5, 10, 13)),
       github = FakeGitHubClient(),
       repository =
           repository ??
           MemoryRecordRepository<Grave>(
             codec: const GraveCodec(),
             currentVersion: 1,
             seed: seed,
           ) {
    controller = GraveListController(
      clock: clock,
      github: github,
      openStorage:
          openStorage ??
          () async => OpenedRepository<Grave>(
            repository: this.repository,
            isPersistent: isPersistent,
          ),
    );
    controller.addListener(() => notifications++);
  }

  /// The clock the controller reads Today from.
  final FakeClock clock;

  /// The GitHub client double.
  final FakeGitHubClient github;

  /// The repository behind the controller.
  final RecordRepository<Grave> repository;

  /// The controller under test.
  late final GraveListController controller;

  /// How many times the controller has notified its listener.
  int notifications = 0;

  bool _disposed = false;

  /// Disposes the controller once. Safe to call again.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
  }

  /// The raw stored text for [grave], as the repository would write it.
  static String envelopeOf(Grave grave) => jsonEncode(<String, Object?>{
    'v': 1,
    'data': const GraveCodec().encode(grave),
  });
}
