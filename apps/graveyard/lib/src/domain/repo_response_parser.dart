import 'dart:convert';

import 'calendar_date.dart';
import 'fetch_result.dart';
import 'fetched_repo.dart';
import 'import_failure.dart';
import 'import_failure_kind.dart';
import 'name_rules.dart';
import 'repo_info.dart';
import 'repo_ref.dart';
import 'zone_converter.dart';

/// Reads the body of a GitHub repository answer. Never throws.
abstract final class RepoResponseParser {
  static const int _maxFullNameLength = 140;

  static final RegExp _pushedAt = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?'
    r'(Z|[+-](\d{2}):(\d{2}))$',
  );

  static const FetchResult _malformed = FetchFailed(
    ImportFailure(ImportFailureKind.malformedResponse),
  );

  /// Parses [body] into a [FetchResult].
  ///
  /// The date of death is the local calendar date of `pushed_at` (through
  /// [zone]), clamped between 1970-01-01 and [today]. Only `pushed_at` is
  /// required. [requested] names the repository when `full_name` is unusable.
  static FetchResult parse(
    String body, {
    required RepoRef requested,
    required CalendarDate today,
    ZoneConverter zone = localZone,
  }) {
    try {
      final Object? json = jsonDecode(body);
      if (json is! Map) return _malformed;
      final pushed = json['pushed_at'];
      if (pushed is! String || !_isRealTimestamp(pushed)) return _malformed;
      final instant = DateTime.parse(pushed).toUtc();
      var date = CalendarDate.fromDateTime(zone(instant));
      if (date.compareTo(today) > 0) date = today;
      if (date.compareTo(CalendarDate.earliest) < 0) {
        date = CalendarDate.earliest;
      }
      final info = RepoInfo(
        fullName: _fullName(json['full_name'], requested),
        htmlUrl: _stringOrNull(json['html_url']),
        description: _stringOrNull(json['description']),
        archived: json['archived'] == true,
        stars: _stars(json['stargazers_count']),
      );
      return FetchSucceeded(FetchedRepo(info: info, dateOfDeath: date));
    } on Object {
      return _malformed;
    }
  }

  /// True when [text] has the timestamp shape and every field is in range.
  static bool _isRealTimestamp(String text) {
    final match = _pushedAt.firstMatch(text);
    if (match == null) return false;
    int field(int group) => int.parse(match.group(group)!);
    // tryCreate rejects year 0000 and every impossible month or day.
    if (CalendarDate.tryCreate(field(1), field(2), field(3)) == null) {
      return false;
    }
    if (field(4) > 23 || field(5) > 59 || field(6) > 59) return false;
    if (match.group(9) != null) {
      if (field(9) > 14 || field(10) > 59) return false;
    }
    return true;
  }

  static String _fullName(Object? value, RepoRef requested) {
    if (value is String) {
      final normalized = NameRules.normalize(value);
      final length = NameRules.length(normalized);
      if (length >= 1 && length <= _maxFullNameLength) return normalized;
    }
    return '${requested.owner}/${requested.repo}';
  }

  static String? _stringOrNull(Object? value) => value is String ? value : null;

  static int _stars(Object? value) {
    if (value is num &&
        value.isFinite &&
        value >= 0 &&
        value == value.truncate()) {
      return value.toInt();
    }
    return 0;
  }
}
