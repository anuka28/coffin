import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/dead_for_formatter.dart';
import 'package:graveyard/src/domain/fetch_result.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/domain/repo_response_parser.dart';

import '../support/fixed_offset_zone.dart';

void main() {
  const ref = RepoRef('octo', 'cat');
  final today = CalendarDate(2026, 6, 15);
  const utc = FixedOffsetZone(Duration.zero);

  FetchResult parse(
    String body, {
    FixedOffsetZone zone = utc,
    CalendarDate? on,
  }) => RepoResponseParser.parse(
    body,
    requested: ref,
    today: on ?? today,
    zone: zone.call,
  );

  FetchSucceeded ok(
    String body, {
    FixedOffsetZone zone = utc,
    CalendarDate? on,
  }) => parse(body, zone: zone, on: on) as FetchSucceeded;

  void expectMalformed(String body) {
    final r = parse(body);
    expect(r, isA<FetchFailed>());
    expect(
      (r as FetchFailed).failure.kind,
      ImportFailureKind.malformedResponse,
    );
  }

  test('reads a full body and ignores updated_at', () {
    final r = ok('''{
      "full_name": "octo/cat", "html_url": "https://github.com/octo/cat",
      "description": "Meow", "archived": true, "stargazers_count": 42,
      "pushed_at": "2020-03-04T10:00:00Z", "updated_at": "2025-01-01T00:00:00Z",
      "extra": [1, 2]}''').repo;
    expect(r.dateOfDeath, CalendarDate(2020, 3, 4));
    expect(r.info.fullName, 'octo/cat');
    expect(r.info.htmlUrl, 'https://github.com/octo/cat');
    expect(r.info.description, 'Meow');
    expect(r.info.archived, isTrue);
    expect(r.info.stars, 42);
  });

  test('applies the zone before reading the date', () {
    const body = '{"pushed_at": "2020-03-04T23:30:00Z"}';
    expect(
      ok(
        body,
        zone: const FixedOffsetZone(Duration(hours: 1)),
      ).repo.dateOfDeath,
      CalendarDate(2020, 3, 5),
    );
    expect(
      ok(
        body,
        zone: const FixedOffsetZone(Duration(hours: -24)),
      ).repo.dateOfDeath,
      CalendarDate(2020, 3, 3),
    );
  });

  test('honours a numeric offset in pushed_at', () {
    expect(
      ok('{"pushed_at": "2020-03-04T23:30:00-05:00"}').repo.dateOfDeath,
      CalendarDate(2020, 3, 5),
    );
  });

  test('clamps to Today and to 1970-01-01', () {
    expect(ok('{"pushed_at": "2030-01-01T00:00:00Z"}').repo.dateOfDeath, today);
    expect(
      ok('{"pushed_at": "1960-01-01T00:00:00Z"}').repo.dateOfDeath,
      CalendarDate.earliest,
    );
  });

  test('defaults optional fields', () {
    final info = ok('{"pushed_at": "2020-03-04T10:00:00Z"}').repo.info;
    expect(info.fullName, 'octo/cat');
    expect(info.htmlUrl, isNull);
    expect(info.description, isNull);
    expect(info.archived, isFalse);
    expect(info.stars, 0);
  });

  test('full_name falls back when empty, non-string or too long', () {
    for (final v in ['""', '"   "', '5', 'null', '"${'a' * 141}"']) {
      expect(
        ok('{"pushed_at": "2020-03-04T10:00:00Z", "full_name": $v}')
            .repo
            .info
            .fullName,
        'octo/cat',
        reason: v,
      );
    }
  });

  test('stargazers_count accepts integral numbers only', () {
    int stars(String v) =>
        ok('{"pushed_at": "2020-03-04T10:00:00Z", "stargazers_count": $v}')
            .repo
            .info
            .stars;
    expect(stars('12'), 12);
    expect(stars('12.0'), 12);
    expect(stars('12.5'), 0);
    expect(stars('-3'), 0);
    expect(stars('"9"'), 0);
  });

  test('pushed_at without time, zone or as non-string is malformed', () {
    expectMalformed('{"pushed_at": "2020-03-04"}');
    expectMalformed('{"pushed_at": "2020-03-04T10:00:00"}');
    expectMalformed('{"pushed_at": 5}');
    expectMalformed('{"pushed_at": null}');
    expectMalformed('{"updated_at": "2020-03-04T10:00:00Z"}');
  });

  test('non-object and broken bodies are malformed', () {
    expectMalformed('[]');
    expectMalformed('"x"');
    expectMalformed('null');
    expectMalformed('{');
    expectMalformed('');
    expectMalformed('[' * 100000);
  });

  group('real repositories at +00:00 (Requirement 4.16)', () {
    void check(
      String owner,
      String repo,
      String pushedAt,
      bool archived,
      int stars,
      CalendarDate death,
    ) {
      final r = RepoResponseParser.parse(
        '{"full_name": "$owner/$repo", "pushed_at": "$pushedAt", '
        '"updated_at": "2026-11-23T23:00:00Z", "archived": $archived, '
        '"stargazers_count": $stars, "description": null}',
        requested: RepoRef(owner, repo),
        today: CalendarDate(2026, 11, 23),
        zone: utc.call,
      );
      final repo0 = (r as FetchSucceeded).repo;
      expect(repo0.dateOfDeath, death);
      expect(repo0.info.fullName, '$owner/$repo');
      expect(repo0.info.archived, archived);
      expect(repo0.info.stars, stars);
    }

    test('flutter/flutter', () {
      check(
        'flutter',
        'flutter',
        '2026-11-23T00:29:13Z',
        false,
        181478,
        CalendarDate(2026, 11, 23),
      );
    });
    test('atom/atom', () {
      check(
        'atom',
        'atom',
        '2023-01-03T10:49:48Z',
        true,
        60681,
        CalendarDate(2023, 1, 3),
      );
    });
    test('mojombo/grit', () {
      check(
        'mojombo',
        'grit',
        '2023-08-17T19:15:41Z',
        false,
        2046,
        CalendarDate(2023, 8, 17),
      );
    });
    test('octocat/Hello-World', () {
      check(
        'octocat',
        'Hello-World',
        '2024-08-20T23:54:42Z',
        false,
        4037,
        CalendarDate(2024, 8, 20),
      );
    });
  });

  group('fixed offsets (Requirements 4.18, 4.19, 4.20)', () {
    test('+05:30 crosses midnight forward and reads "Died today"', () {
      final death = ok(
        '{"pushed_at": "2026-11-22T19:30:00Z"}',
        zone: const FixedOffsetZone(Duration(hours: 5, minutes: 30)),
        on: CalendarDate(2026, 11, 23),
      ).repo.dateOfDeath;
      expect(death, CalendarDate(2026, 11, 23));
      expect(
        DeadForFormatter.format(death, CalendarDate(2026, 11, 23)),
        'Died today',
      );
    });

    test('-05:00 crosses midnight backward and reads "Died today"', () {
      final death = ok(
        '{"pushed_at": "2026-11-23T03:00:00Z"}',
        zone: const FixedOffsetZone(Duration(hours: -5)),
        on: CalendarDate(2026, 11, 22),
      ).repo.dateOfDeath;
      expect(death, CalendarDate(2026, 11, 22));
      expect(
        DeadForFormatter.format(death, CalendarDate(2026, 11, 22)),
        'Died today',
      );
    });

    test('+05:30 that does not cross midnight keeps the UTC date', () {
      expect(
        ok(
          '{"pushed_at": "2026-11-23T10:00:00Z"}',
          zone: const FixedOffsetZone(Duration(hours: 5, minutes: 30)),
          on: CalendarDate(2026, 11, 23),
        ).repo.dateOfDeath,
        CalendarDate(2026, 11, 23),
      );
    });
  });

  test('updated_at and created_at are ignored', () {
    expect(
      ok(
        '{"pushed_at": "2020-03-04T10:00:00Z", '
        '"updated_at": "2025-05-05T10:00:00Z", '
        '"created_at": "2010-01-01T10:00:00Z"}',
      ).repo.dateOfDeath,
      CalendarDate(2020, 3, 4),
    );
    expectMalformed('{"updated_at": "2025-05-05T10:00:00Z"}');
  });

  test('clamps in both directions with a zone offset', () {
    expect(
      ok(
        '{"pushed_at": "2026-06-15T23:00:00Z"}',
        zone: const FixedOffsetZone(Duration(hours: 2)),
      ).repo.dateOfDeath,
      today,
    );
    expect(
      ok('{"pushed_at": "1969-12-31T23:00:00Z"}').repo.dateOfDeath,
      CalendarDate.earliest,
    );
  });

  test('html_url is kept only when a string', () {
    expect(
      ok('{"pushed_at": "2020-03-04T10:00:00Z", "html_url": 5}')
          .repo
          .info
          .htmlUrl,
      isNull,
    );
    expect(
      ok('{"pushed_at": "2020-03-04T10:00:00Z", "html_url": "u"}')
          .repo
          .info
          .htmlUrl,
      'u',
    );
  });

  test('description non-string and archived non-bool default', () {
    final info = ok(
      '{"pushed_at": "2020-03-04T10:00:00Z", '
      '"description": 3, "archived": "yes"}',
    ).repo.info;
    expect(info.description, isNull);
    expect(info.archived, isFalse);
  });

  test('full_name of exactly 140 code points is kept', () {
    final name = 'a' * 140;
    expect(
      ok('{"pushed_at": "2020-03-04T10:00:00Z", "full_name": "$name"}')
          .repo
          .info
          .fullName,
      name,
    );
  });

  test('full_name over 140 code points counts code points, not units', () {
    final name = '😀' * 141;
    expect(
      ok('{"pushed_at": "2020-03-04T10:00:00Z", "full_name": "$name"}')
          .repo
          .info
          .fullName,
      'octo/cat',
    );
  });

  test('pushed_at with fractional seconds and offset parses', () {
    expect(
      ok('{"pushed_at": "2020-03-04T10:00:00.123+02:00"}').repo.dateOfDeath,
      CalendarDate(2020, 3, 4),
    );
  });
}
