import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:graveyard/src/data/github_client.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/domain/repo_response_parser.dart';

import 'fixed_offset_zone.dart';
import 'github_call.dart';

/// A [GitHubClient] for tests. It never touches the network.
///
/// Each call takes the next scripted result, or [defaultResult] when the
/// script is empty. A scripted result can be held open with a [Completer] so
/// a test decides when the call finishes. Every call is recorded in [calls].
class FakeGitHubClient implements GitHubClient {
  /// Creates a client that answers with [defaultResult] when nothing is
  /// scripted. Without one, it answers with an offline failure.
  FakeGitHubClient({FetchResult? defaultResult})
    : defaultResult =
          defaultResult ??
          const FetchFailed(ImportFailure(ImportFailureKind.offline));

  /// The answer used when the script is empty.
  FetchResult defaultResult;

  final Queue<Future<FetchResult>> _script = Queue<Future<FetchResult>>();
  final List<GitHubCall> _calls = <GitHubCall>[];

  /// Every call made so far, oldest first.
  List<GitHubCall> get calls => List<GitHubCall>.unmodifiable(_calls);

  /// Queues [result] for the next unscripted call.
  void enqueue(FetchResult result) {
    _script.add(Future<FetchResult>.value(result));
  }

  /// Queues a call that stays pending until the returned completer completes.
  Completer<FetchResult> enqueueHeld() {
    final completer = Completer<FetchResult>();
    _script.add(completer.future);
    return completer;
  }

  @override
  Future<FetchResult> fetch(RepoRef ref, {required CalendarDate today}) {
    _calls.add(GitHubCall(ref, today));
    if (_script.isEmpty) return Future<FetchResult>.value(defaultResult);
    return _script.removeFirst();
  }

  /// Builds a result by parsing a GitHub-shaped answer for [ref] through a
  /// [FixedOffsetZone], so it does not depend on the machine's time zone.
  ///
  /// [pushedAt] is the `pushed_at` timestamp. [offset] is the zone offset.
  static FetchResult parsed(
    RepoRef ref, {
    required String pushedAt,
    required CalendarDate today,
    Duration offset = Duration.zero,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    final body = jsonEncode(<String, Object?>{
      'full_name': '${ref.owner}/${ref.repo}',
      'html_url': 'https://github.com/${ref.owner}/${ref.repo}',
      'pushed_at': pushedAt,
      ...extra,
    });
    return RepoResponseParser.parse(
      body,
      requested: ref,
      today: today,
      zone: FixedOffsetZone(offset).call,
    );
  }
}
