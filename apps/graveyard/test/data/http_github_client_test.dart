import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/data/http_github_client.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/fetched_repo.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_clock.dart';
import '../support/fixed_offset_zone.dart';

/// A timer the test fires by hand.
class _ManualTimer implements Timer {
  _ManualTimer(this.onTimeout);

  final void Function() onTimeout;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    if (cancelled) return;
    fired = true;
    onTimeout();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;
}

const String _body = '''{
  "full_name": "octo/cat", "html_url": "https://github.com/octo/cat",
  "description": "Meow", "archived": true, "stargazers_count": 42,
  "pushed_at": "2020-03-04T10:00:00Z"}''';

void main() {
  const ref = RepoRef('octo', 'cat');
  final today = CalendarDate(2026, 6, 15);
  final now = DateTime.utc(2026, 6, 15, 12);
  late FakeClock clock;
  late List<http.BaseRequest> requests;
  late List<_ManualTimer> timers;

  setUp(() {
    clock = FakeClock(now);
    requests = <http.BaseRequest>[];
    timers = <_ManualTimer>[];
  });

  HttpGitHubClient build(
    Future<http.Response> Function(http.Request) handler,
  ) => HttpGitHubClient(
    client: MockClient((http.Request r) {
      requests.add(r);
      return handler(r);
    }),
    clock: clock,
    zone: const FixedOffsetZone(Duration.zero).call,
    startTimer: (Duration d, void Function() cb) {
      final t = _ManualTimer(cb);
      timers.add(t);
      return t;
    },
  );

  Future<FetchResult> fetchWith(
    int status, {
    Map<String, String> headers = const <String, String>{},
    String body = '',
  }) =>
      build((_) async => http.Response(body, status, headers: headers))
          .fetch(ref, today: today);

  ImportFailureKind kindOf(FetchResult r) {
    expect(r, isA<FetchFailed>());
    return (r as FetchFailed).failure.kind;
  }

  DateTime? resetOf(FetchResult r) => (r as FetchFailed).failure.resetAt;

  group('request', () {
    test('sends exactly one GET to the exact URL with only Accept', () async {
      await build((_) async => http.Response(_body, 200))
          .fetch(ref, today: today);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.toString(),
        'https://api.github.com/repos/octo/cat',
      );
      expect(
        requests.single.headers.map((k, v) => MapEntry(k.toLowerCase(), v)),
        <String, String>{'accept': 'application/vnd.github+json'},
      );
      expect(
        requests.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    test('percent-encodes the path segments', () async {
      await build((_) async => http.Response('', 404))
          .fetch(const RepoRef('a b', 'c/d?e#f'), today: today);
      expect(
        requests.single.url.toString(),
        'https://api.github.com/repos/a%20b/c%2Fd%3Fe%23f',
      );
    });
  });

  group('statuses', () {
    test('200 returns the parsed repository', () async {
      final r = await fetchWith(200, body: _body);
      expect(
        r,
        FetchSucceeded(
          FetchedRepo(
            info: const RepoInfo(
              fullName: 'octo/cat',
              htmlUrl: 'https://github.com/octo/cat',
              description: 'Meow',
              archived: true,
              stars: 42,
            ),
            dateOfDeath: CalendarDate(2020, 3, 4),
          ),
        ),
      );
    });

    test('200 applies the injected zone', () async {
      final client = HttpGitHubClient(
        client: MockClient(
          (_) async =>
              http.Response('{"pushed_at": "2020-03-04T23:30:00Z"}', 200),
        ),
        clock: clock,
        zone: const FixedOffsetZone(Duration(hours: 2)).call,
        startTimer: (d, cb) => _ManualTimer(cb),
      );
      final r = await client.fetch(ref, today: today) as FetchSucceeded;
      expect(r.repo.dateOfDeath, CalendarDate(2020, 3, 5));
    });

    test('404 is notFoundOrPrivate', () async {
      expect(kindOf(await fetchWith(404)), ImportFailureKind.notFoundOrPrivate);
    });

    test('429 is rateLimited', () async {
      final r = await fetchWith(429);
      expect(kindOf(r), ImportFailureKind.rateLimited);
      expect(resetOf(r), isNull);
    });

    test('403 with x-ratelimit-remaining 0 is rateLimited', () async {
      final r = await fetchWith(403, headers: {'x-ratelimit-remaining': '0'});
      expect(kindOf(r), ImportFailureKind.rateLimited);
    });

    test('403 with Retry-After is rateLimited', () async {
      final r = await fetchWith(403, headers: {'retry-after': '30'});
      expect(kindOf(r), ImportFailureKind.rateLimited);
      expect(resetOf(r), now.add(const Duration(seconds: 30)));
    });

    test('403 without rate-limit headers is unexpectedStatus', () async {
      expect(kindOf(await fetchWith(403)), ImportFailureKind.unexpectedStatus);
    });

    test('403 with remaining above 0 is unexpectedStatus', () async {
      final r = await fetchWith(403, headers: {'x-ratelimit-remaining': '12'});
      expect(kindOf(r), ImportFailureKind.unexpectedStatus);
    });

    test('301 is unexpectedStatus', () async {
      expect(kindOf(await fetchWith(301)), ImportFailureKind.unexpectedStatus);
    });

    test('500 is unexpectedStatus', () async {
      expect(kindOf(await fetchWith(500)), ImportFailureKind.unexpectedStatus);
    });
  });

  group('rate-limit wait headers', () {
    test('Retry-After adds seconds to the clock', () async {
      final r = await fetchWith(429, headers: {'retry-after': '120'});
      expect(resetOf(r), now.add(const Duration(seconds: 120)));
    });

    test('unreadable Retry-After gives no reset', () async {
      for (final v in <String>['soon', '', '-5', '1.5', '99999999999']) {
        final r = await fetchWith(429, headers: {'retry-after': v});
        expect(kindOf(r), ImportFailureKind.rateLimited, reason: v);
        expect(resetOf(r), isNull, reason: v);
      }
    });

    test('x-ratelimit-reset is read as epoch seconds', () async {
      final r = await fetchWith(
        429,
        headers: {'x-ratelimit-reset': '1800000000'},
      );
      expect(
        resetOf(r),
        DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000, isUtc: true),
      );
    });

    test('unreadable x-ratelimit-reset gives no reset', () async {
      for (final v in <String>['tomorrow', '', '-1', '9999999999']) {
        final r = await fetchWith(429, headers: {'x-ratelimit-reset': v});
        expect(kindOf(r), ImportFailureKind.rateLimited, reason: v);
        expect(resetOf(r), isNull, reason: v);
      }
    });

    test('Retry-After wins over x-ratelimit-reset', () async {
      clock.set(DateTime.utc(2030));
      final r = await fetchWith(
        429,
        headers: {'retry-after': '90', 'x-ratelimit-reset': '1800000000'},
      );
      expect(resetOf(r), DateTime.utc(2030).add(const Duration(seconds: 90)));
    });

    test('unreadable Retry-After falls back to x-ratelimit-reset', () async {
      final r = await fetchWith(
        429,
        headers: {'retry-after': 'later', 'x-ratelimit-reset': '1800000000'},
      );
      expect(
        resetOf(r),
        DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000, isUtc: true),
      );
    });
  });

  group('failures', () {
    test('ClientException is offline', () async {
      final r = await build(
        (_) async => throw http.ClientException('no network'),
      ).fetch(ref, today: today);
      expect(kindOf(r), ImportFailureKind.offline);
    });

    test('any other exception is offline', () async {
      final r = await build((_) async => throw StateError('boom'))
          .fetch(ref, today: today);
      expect(kindOf(r), ImportFailureKind.offline);
    });

    test('a malformed 200 body is malformedResponse', () async {
      for (final b in <String>['not json', '[]', '']) {
        expect(
          kindOf(await fetchWith(200, body: b)),
          ImportFailureKind.malformedResponse,
          reason: b,
        );
      }
    });
  });

  group('timeout', () {
    test('a request that never completes ends as timeout', () async {
      final never = Completer<http.Response>();
      final future = build((_) => never.future).fetch(ref, today: today);
      await Future<void>.delayed(Duration.zero);
      expect(timers, hasLength(1));
      timers.single.fire();
      expect(kindOf(await future), ImportFailureKind.timeout);
    });

    test('the timer uses the 10 second request timeout', () {
      expect(HttpGitHubClient.requestTimeout, const Duration(seconds: 10));
    });

    test('a late response after the timeout is dropped', () async {
      final late = Completer<http.Response>();
      final future = build((_) => late.future).fetch(ref, today: today);
      await Future<void>.delayed(Duration.zero);
      timers.single.fire();
      final result = await future;
      late.complete(http.Response(_body, 200));
      await Future<void>.delayed(Duration.zero);
      expect(kindOf(result), ImportFailureKind.timeout);
    });

    test('a late error after the timeout is dropped', () async {
      final late = Completer<http.Response>();
      final future = build((_) => late.future).fetch(ref, today: today);
      await Future<void>.delayed(Duration.zero);
      timers.single.fire();
      final result = await future;
      late.completeError(http.ClientException('late'));
      await Future<void>.delayed(Duration.zero);
      expect(kindOf(result), ImportFailureKind.timeout);
    });

    test('a response in time cancels the timer', () async {
      await build((_) async => http.Response(_body, 200))
          .fetch(ref, today: today);
      expect(timers.single.cancelled, isTrue);
    });
  });
}
