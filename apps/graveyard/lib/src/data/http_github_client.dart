import 'dart:async';

import 'package:http/http.dart' as http;

import '../domain/calendar_date.dart';
import '../domain/clock.dart';
import '../domain/fetch_result.dart';
import '../domain/import_failure.dart';
import '../domain/import_failure_kind.dart';
import '../domain/repo_ref.dart';
import '../domain/repo_response_parser.dart';
import '../domain/zone_converter.dart';
import 'github_client.dart';

/// Starts a timer that calls [onTimeout] after [duration]. Tests pass a manual
/// timer.
typedef TimeoutTimerFactory = Timer Function(
  Duration duration,
  void Function() onTimeout,
);

/// The production [GitHubClient]: one unauthenticated GET to the GitHub API.
///
/// This is the only file that imports `package:http` and the only file that
/// holds an `api.github.com` URL.
final class HttpGitHubClient implements GitHubClient {
  /// Creates a client.
  ///
  /// Pass [client] to use your own HTTP client (it is not closed by [close]).
  /// [clock] turns a `Retry-After` wait into a moment. [zone] converts
  /// `pushed_at` to the local calendar. [startTimer] and [timeout] control the
  /// request timeout.
  HttpGitHubClient({
    http.Client? client,
    required this._clock,
    this._zone = localZone,
    this._startTimer = Timer.new,
    this._timeout = requestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// How long a request may take before it ends as a timeout.
  static const Duration requestTimeout = Duration(seconds: 10);

  final http.Client _client;
  final bool _ownsClient;
  final Clock _clock;
  final ZoneConverter _zone;
  final TimeoutTimerFactory _startTimer;
  final Duration _timeout;

  static const FetchResult _offline = FetchFailed(
    ImportFailure(ImportFailureKind.offline),
  );
  static const FetchResult _timedOut = FetchFailed(
    ImportFailure(ImportFailureKind.timeout),
  );

  static const int _maxRetryAfterSeconds = 10000000;
  static const int _maxResetSeconds = 4102444800;

  /// Closes the HTTP client, only when this object created it.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<FetchResult> fetch(RepoRef ref, {required CalendarDate today}) async {
    try {
      final Uri uri = Uri(
        scheme: 'https',
        host: 'api.github.com',
        pathSegments: <String>['repos', ref.owner, ref.repo],
      );
      final Completer<FetchResult> completer = Completer<FetchResult>();
      Timer? timer;
      void finish(FetchResult result) {
        if (!completer.isCompleted) {
          completer.complete(result);
        }
        timer?.cancel();
      }

      timer = _startTimer(_timeout, () => finish(_timedOut));
      if (completer.isCompleted) {
        timer.cancel();
      }

      _client
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
            },
          )
          .then<void>(
            (http.Response response) {
              if (completer.isCompleted) {
                return;
              }
              try {
                finish(_map(response, ref, today));
              } catch (_) {
                finish(_offline);
              }
            },
            onError: (Object _) {
              finish(_offline);
            },
          );

      return await completer.future;
    } catch (_) {
      return _offline;
    }
  }

  FetchResult _map(http.Response response, RepoRef ref, CalendarDate today) {
    final int status = response.statusCode;
    final Map<String, String> headers = response.headers;
    if (status == 200) {
      return RepoResponseParser.parse(
        response.body,
        requested: ref,
        today: today,
        zone: _zone,
      );
    }
    if (status == 404) {
      return const FetchFailed(
        ImportFailure(ImportFailureKind.notFoundOrPrivate),
      );
    }
    final bool limited =
        status == 429 ||
        (status == 403 &&
            (headers['x-ratelimit-remaining']?.trim() == '0' ||
                headers.containsKey('retry-after')));
    if (limited) {
      return FetchFailed(
        ImportFailure(
          ImportFailureKind.rateLimited,
          resetAt: _resetAt(headers),
        ),
      );
    }
    return const FetchFailed(ImportFailure(ImportFailureKind.unexpectedStatus));
  }

  DateTime? _resetAt(Map<String, String> headers) {
    final int? retryAfter = _readInt(
      headers['retry-after'],
      _maxRetryAfterSeconds,
    );
    if (retryAfter != null) {
      return _clock.now().add(Duration(seconds: retryAfter));
    }
    final int? reset = _readInt(headers['x-ratelimit-reset'], _maxResetSeconds);
    if (reset != null) {
      return DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true);
    }
    return null;
  }

  static final RegExp _digits = RegExp(r'^[0-9]{1,10}$');

  int? _readInt(String? text, int max) {
    if (text == null) {
      return null;
    }
    final String trimmed = text.trim();
    if (!_digits.hasMatch(trimmed)) {
      return null;
    }
    final int value = int.parse(trimmed);
    return value <= max ? value : null;
  }
}
