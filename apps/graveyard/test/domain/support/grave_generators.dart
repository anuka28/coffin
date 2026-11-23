import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart' show expect, equals, isPositive;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/repo_ref.dart';

// Pure support code: no dart:io. It also runs in Chrome. Every generated
// integer stays far below 2^53.

/// Runs per property in the graveyard tests.
const int numRuns = 200;

/// Integers from [min] inclusive to [max] exclusive.
///
/// Use this instead of `any.intInRange`: glados 1.1.7 computes `1 << 32` in
/// its range helper, which is 0 on web. This one calls `Random.nextInt`
/// directly, which works on every platform for ranges below 2^32. Shrinks
/// towards [min] (or 0 when 0 is in range).
Generator<int> anyIntBetween(int min, int max) {
  assert(min < max && max - min <= 0xFFFFFFFF);
  final int target = min <= 0 && max > 0 ? 0 : min;
  return any.simple<int>(
    generate: (math.Random random, int size) => min + random.nextInt(max - min),
    shrink: (int v) sync* {
      if (v > target) {
        yield target + (v - target) ~/ 2;
      } else if (v < target) {
        yield target - (target - v) ~/ 2;
      }
    },
  );
}

/// Lists of [item] with a length from [min] inclusive to [max] exclusive.
///
/// The web-safe counterpart of `any.listWithLengthInRange`. Shrinks by
/// dropping and shrinking elements.
Generator<List<T>> anyListBetween<T>(int min, int max, Generator<T> item) {
  assert(0 <= min && min < max);
  return (math.Random random, int size) {
    final int length = min + random.nextInt(max - min);
    return ShrinkableList<T>(<Shrinkable<T>>[
      for (int i = 0; i < length; i++) item(random, size),
    ], min);
  };
}

/// Counts the runs of a property body. Increment it in the body, then call
/// [expectRuns] in a plain test so a silent skip cannot pass.
final class RunCounter {
  /// Creates a counter at zero.
  RunCounter();

  int _runs = 0;

  /// How many times [increment] was called.
  int get runs => _runs;

  /// Records one run.
  void increment() => _runs++;

  /// Sets the count back to zero.
  void reset() => _runs = 0;

  /// Asserts that at least one run happened and that [runs] equals [numRuns].
  void expectRuns(int numRuns) {
    expect(_runs, isPositive, reason: 'the property body never ran');
    expect(_runs, equals(numRuns), reason: 'run count differs from numRuns');
  }
}

/// Last epoch day the generator draws from: 2099-12-31.
const int lastGeneratedEpochDay = 47482;

/// Days on calendar edges: leap days, month and year ends, the earliest
/// supported day, and the daylight saving changes of 2026.
final List<CalendarDate> edgeCalendarDates = <CalendarDate>[
  CalendarDate(1970, 1, 1),
  CalendarDate(1970, 12, 31),
  CalendarDate(1972, 2, 29),
  CalendarDate(2000, 2, 29),
  CalendarDate(2000, 12, 31),
  CalendarDate(2024, 2, 28),
  CalendarDate(2024, 2, 29),
  CalendarDate(2024, 3, 1),
  CalendarDate(2025, 2, 28),
  CalendarDate(2025, 3, 1),
  CalendarDate(2026, 1, 31),
  CalendarDate(2026, 2, 28),
  CalendarDate(2026, 3, 8),
  CalendarDate(2026, 3, 29),
  CalendarDate(2026, 4, 30),
  CalendarDate(2026, 10, 25),
  CalendarDate(2026, 11, 1),
  CalendarDate(2026, 12, 31),
  CalendarDate(2099, 12, 31),
];

/// Calendar dates from 1970-01-01 to 2099-12-31: about one in four is an
/// edge day from [edgeCalendarDates], the rest are any epoch day from 0 to
/// [lastGeneratedEpochDay]. Shrinks towards 1970-01-01.
Generator<CalendarDate> get anyCalendarDate => any.simple<CalendarDate>(
  generate: (math.Random random, int size) {
    if (random.nextInt(4) == 0) {
      return edgeCalendarDates[random.nextInt(edgeCalendarDates.length)];
    }
    return CalendarDate.fromEpochDay(random.nextInt(lastGeneratedEpochDay + 1));
  },
  shrink: (CalendarDate d) sync* {
    final int day = d.epochDay;
    if (day > 0) {
      yield CalendarDate.fromEpochDay(day ~/ 2);
    }
  },
);

/// Seconds since the Unix epoch, from 0 to 4102444799 (2099-12-31 23:59:59
/// UTC). The upper bound is below 2^32, far below 2^53.
Generator<int> get anyInstantSeconds => anyIntBetween(0, 4102444800);

/// Zone offsets in minutes: index 0 to 52 mapped to `-720 + 30 * index`, so
/// -720 (UTC-12:00) to +840 (UTC+14:00) in half-hour steps.
Generator<int> get anyOffsetMinutes => any.simple<int>(
  generate: (math.Random random, int size) => -720 + 30 * random.nextInt(53),
  shrink: (int minutes) sync* {
    if (minutes != 0) {
      yield 0;
    }
  },
);

/// Code points a project name is built from: ASCII letters, digits and
/// punctuation, accents, CJK, an emoji, tab, newline and space.
const List<int> _nameCodePoints = <int>[
  0x61, 0x62, 0x7A, 0x41, 0x5A, 0x30, 0x39, 0x2F, 0x2D, 0x5F, 0x2E, // ASCII
  0xE9, 0xF1, 0xFC, 0xC5, // accents
  0x4E2D, 0x6587, 0x672C, // CJK
  0x1F47B, // emoji
  0x09, 0x0A, // tab, newline
  0x20, 0x20, 0x20, // space, weighted for runs of spaces
];

/// Project names of 0 to 90 code points: ASCII, accents, CJK, an emoji,
/// tabs, newlines and runs of spaces. Shrinks by halving the length.
Generator<String> get anyProjectName => any.simple<String>(
  generate: (math.Random random, int size) {
    final int length = random.nextInt(91);
    final List<int> units = <int>[];
    while (units.length < length) {
      final int code = _nameCodePoints[random.nextInt(_nameCodePoints.length)];
      final int repeat = code == 0x20 ? 1 + random.nextInt(4) : 1;
      for (int i = 0; i < repeat && units.length < length; i++) {
        units.add(code);
      }
    }
    return String.fromCharCodes(units);
  },
  shrink: (String name) sync* {
    final List<int> runes = name.runes.toList();
    if (runes.isNotEmpty) {
      yield String.fromCharCodes(runes.sublist(0, runes.length ~/ 2));
    }
  },
);

/// Few dates, so graves often die on the same day.
final List<CalendarDate> _collidingDates = <CalendarDate>[
  CalendarDate(2024, 2, 29),
  CalendarDate(2025, 3, 1),
  CalendarDate(2026, 3, 8),
  CalendarDate(2026, 11, 1),
];

/// Name stems. Each is used in several letter cases, so names differ only
/// by case.
const List<String> _nameStems = <String>[
  'moonlit',
  'Crypt Keeper',
  'ghost-log',
  'élan',
  'owner/repo',
];

String _caseVariant(String stem, int variant) {
  switch (variant) {
    case 0:
      return stem;
    case 1:
      return stem.toUpperCase();
    case 2:
      return stem.toLowerCase();
    default:
      return stem.isEmpty
          ? stem
          : stem[0].toUpperCase() + stem.substring(1).toLowerCase();
  }
}

/// Descriptions with Markdown, emoji shortcodes and a 2,000-character text.
final List<String?> _descriptions = <String?>[
  null,
  '',
  '# Title\n\n**bold** _italic_ `code` [link](https://example.com)',
  '- item one\n- item two\n\n> quote\n```dart\nvoid main() {}\n```',
  'Haunted :ghost: and :skull: with :jack_o_lantern: inside',
  List<String>.filled(100, 'Twenty chars of text').join(),
  List<String>.filled(
    125,
    '**md** :ghost: '
    'x',
  ).join().padRight(2000, '.').substring(0, 2000),
];

/// Graves: manual or GitHub, ids `g0` to `g19`, dates from a few colliding
/// days, names that differ only in letter case, and GitHub descriptions of
/// Markdown, emoji shortcodes and 2,000-character text. Shrinks towards the
/// smallest id and the earliest date.
Generator<Grave> get anyGrave => any.simple<Grave>(
  generate: (math.Random random, int size) {
    final String id = 'g${random.nextInt(20)}';
    final CalendarDate date = random.nextInt(5) == 0
        ? CalendarDate.fromEpochDay(random.nextInt(lastGeneratedEpochDay + 1))
        : _collidingDates[random.nextInt(_collidingDates.length)];
    final String stem = _nameStems[random.nextInt(_nameStems.length)];
    final String name = _caseVariant(stem, random.nextInt(4));
    if (random.nextBool()) {
      return Grave.manual(id: id, name: name, dateOfDeath: date);
    }
    return Grave.github(
      id: id,
      name: name,
      dateOfDeath: date,
      repo: RepoInfo(
        fullName: name,
        htmlUrl: random.nextBool() ? 'https://github.com/$name' : null,
        description: _descriptions[random.nextInt(_descriptions.length)],
        archived: random.nextBool(),
        stars: random.nextInt(5000),
      ),
    );
  },
  shrink: (Grave g) sync* {
    if (g.dateOfDeath.epochDay > 0) {
      yield g.repo == null
          ? Grave.manual(
              id: g.id,
              name: g.name,
              dateOfDeath: CalendarDate.fromEpochDay(0),
            )
          : Grave.github(
              id: g.id,
              name: g.name,
              dateOfDeath: CalendarDate.fromEpochDay(0),
              repo: g.repo!,
            );
    }
  },
);

/// Lists of 0 to 12 graves with distinct ids (a later grave with an id
/// already taken is dropped). Shrinks by dropping graves.
Generator<List<Grave>> get anyGraveList => any.simple<List<Grave>>(
  generate: (math.Random random, int size) {
    final int length = random.nextInt(13);
    final Generator<Grave> item = anyGrave;
    final Map<String, Grave> byId = <String, Grave>{};
    for (int i = 0; i < length; i++) {
      final Grave g = item(random, size).value;
      byId.putIfAbsent(g.id, () => g);
    }
    return byId.values.toList();
  },
  shrink: (List<Grave> list) sync* {
    if (list.isNotEmpty) {
      yield list.sublist(0, list.length ~/ 2);
      yield list.sublist(1);
    }
  },
);

const String _alnum =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const String _repoChars = '$_alnum-_.';

String _owner(math.Random random) {
  final int length = 1 + random.nextInt(39);
  final StringBuffer out = StringBuffer();
  var previousHyphen = true; // no hyphen first
  for (int i = 0; i < length; i++) {
    final bool hyphen =
        !previousHyphen && i < length - 1 && random.nextInt(6) == 0;
    out.write(hyphen ? '-' : _alnum[random.nextInt(_alnum.length)]);
    previousHyphen = hyphen;
  }
  return out.toString();
}

String _repo(math.Random random) {
  // Short names are common, long names reach the 100 character limit.
  final int length = random.nextInt(4) == 0
      ? 1 + random.nextInt(100)
      : 1 + random.nextInt(12);
  final String text = String.fromCharCodes(<int>[
    for (int i = 0; i < length; i++)
      _repoChars.codeUnitAt(random.nextInt(_repoChars.length)),
  ]);
  if (RepoRef.isValidRepo(text)) {
    return text;
  }
  // `.`, `..` or ending in `.git`: change the last character to a letter.
  return '${text.substring(0, text.length - 1)}x';
}

/// Valid repository references: an owner of 1 to 39 characters (letters,
/// digits, single hyphens, none at either end) and a repo of 1 to 100
/// characters (letters, digits, `-`, `_`, `.`), never `.`, `..` or ending in
/// `.git`. Shrinks towards `a/a`.
Generator<RepoRef> get anyRepoRef => any.simple<RepoRef>(
  generate: (math.Random random, int size) =>
      RepoRef(_owner(random), _repo(random)),
  shrink: (RepoRef ref) sync* {
    if (ref.owner.length > 1) {
      yield RepoRef(ref.owner.substring(0, 1), ref.repo);
    }
    if (ref.repo.length > 1) {
      final String shorter = ref.repo.substring(0, ref.repo.length ~/ 2);
      if (RepoRef.isValidRepo(shorter)) {
        yield RepoRef(ref.owner, shorter);
      }
    }
  },
);

/// How a valid [RepoRef] is dressed up as user input: a scheme, a host in any
/// letter case, whitespace, a trailing slash, a `.git` suffix, extra path
/// segments, a query and a fragment. None of these change the reference.
final class UrlDecoration {
  /// Creates a decoration.
  const UrlDecoration({
    required this.scheme,
    required this.host,
    required this.hostUpperMask,
    required this.leadingSpace,
    required this.trailingSpace,
    required this.trailingSlash,
    required this.dotGit,
    required this.extraSegments,
    required this.query,
    required this.fragment,
  });

  /// `https://`, `http://` or empty. A scheme always comes with a host.
  final String scheme;

  /// `github.com` or `www.github.com`, or empty (only without a scheme).
  final String host;

  /// Bit `i` set means character `i` of [host] is upper case.
  final int hostUpperMask;

  /// Whitespace before the text.
  final String leadingSpace;

  /// Whitespace after the text.
  final String trailingSpace;

  /// Whether a `/` follows the repo (and the `.git`).
  final bool trailingSlash;

  /// Whether `.git` follows the repo name.
  final bool dotGit;

  /// Path segments after the repo, for example `['issues', '4']`.
  final List<String> extraSegments;

  /// Query text without the `?`, or null.
  final String? query;

  /// Fragment text without the `#`, or null.
  final String? fragment;

  /// The assembled input text for [ref].
  String render(RepoRef ref) {
    final StringBuffer out = StringBuffer(leadingSpace)..write(scheme);
    for (int i = 0; i < host.length; i++) {
      final String c = host[i];
      out.write((hostUpperMask >> i) & 1 == 1 ? c.toUpperCase() : c);
    }
    if (host.isNotEmpty) {
      out.write('/');
    }
    out
      ..write(ref.owner)
      ..write('/')
      ..write(ref.repo);
    if (dotGit) {
      out.write('.git');
    }
    for (final String segment in extraSegments) {
      out
        ..write('/')
        ..write(segment);
    }
    if (trailingSlash) {
      out.write('/');
    }
    if (query != null) {
      out
        ..write('?')
        ..write(query);
    }
    if (fragment != null) {
      out
        ..write('#')
        ..write(fragment);
    }
    out.write(trailingSpace);
    return out.toString();
  }
}

const List<String> _spaces = <String>['', ' ', '  ', '\t', '\n', ' \t\n '];
const List<String> _segmentPool = <String>[
  'issues',
  'tree',
  'main',
  '42',
  'pull',
  'blob',
  'README.md',
  '.git',
  'a b',
];
const List<String> _queryPool = <String>['tab=readme', 'a=1&b=2', '', 'x/y'];
const List<String> _fragmentPool = <String>['readme', '', 'L10', 'a/b?c'];

/// Decorations of a repository reference. Shrinks to the bare `owner/repo`.
Generator<UrlDecoration> get anyUrlDecoration => any.simple<UrlDecoration>(
  generate: (math.Random random, int size) {
    final int schemeIndex = random.nextInt(3);
    final String scheme = <String>['', 'http://', 'https://'][schemeIndex];
    final bool hasHost = schemeIndex != 0 || random.nextBool();
    final String host = hasHost
        ? (random.nextBool() ? 'github.com' : 'www.github.com')
        : '';
    return UrlDecoration(
      scheme: scheme,
      host: host,
      hostUpperMask: random.nextInt(1 << 16),
      leadingSpace: _spaces[random.nextInt(_spaces.length)],
      trailingSpace: _spaces[random.nextInt(_spaces.length)],
      trailingSlash: random.nextBool(),
      dotGit: random.nextBool(),
      extraSegments: <String>[
        for (int i = 0, n = random.nextInt(4); i < n; i++)
          _segmentPool[random.nextInt(_segmentPool.length)],
      ],
      query: random.nextBool()
          ? _queryPool[random.nextInt(_queryPool.length)]
          : null,
      fragment: random.nextBool()
          ? _fragmentPool[random.nextInt(_fragmentPool.length)]
          : null,
    );
  },
  shrink: (UrlDecoration d) sync* {
    if (d.scheme.isNotEmpty ||
        d.host.isNotEmpty ||
        d.dotGit ||
        d.extraSegments.isNotEmpty ||
        d.query != null ||
        d.fragment != null ||
        d.trailingSlash ||
        d.leadingSpace.isNotEmpty ||
        d.trailingSpace.isNotEmpty) {
      yield const UrlDecoration(
        scheme: '',
        host: '',
        hostUpperMask: 0,
        leadingSpace: '',
        trailingSpace: '',
        trailingSlash: false,
        dotGit: false,
        extraSegments: <String>[],
        query: null,
        fragment: null,
      );
    }
  },
);

const List<String> _urlFragments = <String>[
  'https://',
  'http://',
  'ftp://',
  'github.com',
  'www.github.com',
  'GitHub.COM',
  'example.com',
  '/',
  '//',
  '.git',
  '.GIT',
  '.',
  '..',
  '?',
  '#',
  '%2F',
  '-',
  'owner',
  'repo',
  ' ',
  '@',
  ':',
];

/// Text for the input parser: pieces of URL fragments mixed with arbitrary
/// code points (control characters, emoji, anything but lone surrogates),
/// and now and then a very long text. Shrinks by halving.
Generator<String> get anyUrlText => any.simple<String>(
  generate: (math.Random random, int size) {
    final int pieces = random.nextInt(10);
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < pieces; i++) {
      if (random.nextBool()) {
        out.write(_urlFragments[random.nextInt(_urlFragments.length)]);
      } else {
        final int count = 1 + random.nextInt(4);
        for (int j = 0; j < count; j++) {
          int code = random.nextInt(0x110000);
          if (code >= 0xD800 && code <= 0xDFFF) {
            code = 0x20;
          }
          out.writeCharCode(code);
        }
      }
    }
    var text = out.toString();
    if (random.nextInt(20) == 0) {
      text = List<String>.filled(1 + random.nextInt(300), 'a/b').join() + text;
    }
    return text;
  },
  shrink: (String text) sync* {
    final List<int> runes = text.runes.toList();
    if (runes.isNotEmpty) {
      yield String.fromCharCodes(runes.sublist(0, runes.length ~/ 2));
    }
  },
);

/// Marks a field as absent: [withField] removes the key instead of setting it.
const Object absentField = _AbsentField();

final class _AbsentField {
  const _AbsentField();

  @override
  String toString() => 'absent';
}

/// Longest nesting [anyJsonValue] builds (lists and objects inside each
/// other).
const int maxJsonDepth = 4;

const List<String> _jsonKeys = <String>[
  'id',
  'name',
  'full_name',
  'pushed_at',
  'updated_at',
  'stargazers_count',
  'archived',
  'x',
  '',
  'é',
];

const List<String> _jsonStrings = <String>[
  '',
  'ghost',
  'owner/repo',
  '2024-02-29T12:00:00Z',
  '2024-02-29',
  'tab\there "quoted" \\ back',
  'emoji 👻 and 中文',
];

Object? _jsonValue(math.Random random, int depth) {
  final int kinds = depth >= maxJsonDepth ? 6 : 8;
  switch (random.nextInt(kinds)) {
    case 0:
      return null;
    case 1:
      return random.nextBool();
    case 2:
      return random.nextInt(2001) - 1000;
    case 3:
      return random.nextInt(2000) / 4 - 100; // exact binary fractions
    case 4:
    case 5:
      return _jsonStrings[random.nextInt(_jsonStrings.length)];
    case 6:
      return <Object?>[
        for (int i = 0, n = random.nextInt(4); i < n; i++)
          _jsonValue(random, depth + 1),
      ];
    default:
      return <String, Object?>{
        for (int i = 0, n = random.nextInt(4); i < n; i++)
          _jsonKeys[random.nextInt(_jsonKeys.length)]: _jsonValue(
            random,
            depth + 1,
          ),
      };
  }
}

/// JSON values (`null`, bool, int, double, String, List, Map with String
/// keys) nested at most [maxJsonDepth] levels. Shrinks to `null`.
Generator<Object?> get anyJsonValue => any.simple<Object?>(
  generate: (math.Random random, int size) => _jsonValue(random, 0),
  shrink: (Object? value) sync* {
    if (value != null) {
      yield null;
    }
  },
);

/// Text for a JSON parser: valid documents, truncated documents, deeply
/// nested lists and objects (up to 600 levels), and arbitrary code points.
/// Shrinks by halving.
Generator<String> get anyJsonText => any.simple<String>(
  generate: (math.Random random, int size) {
    switch (random.nextInt(5)) {
      case 0:
        return jsonEncode(_jsonValue(random, 0));
      case 1:
        final String full = jsonEncode(_jsonValue(random, 0));
        return full.substring(0, random.nextInt(full.length + 1));
      case 2:
        final int depth = 1 + random.nextInt(600);
        return random.nextBool()
            ? '${'[' * depth}1${']' * depth}'
            : '${'{"a":' * depth}1${'}' * depth}';
      case 3:
        final StringBuffer out = StringBuffer();
        for (int i = 0, n = random.nextInt(30); i < n; i++) {
          int code = random.nextInt(0x110000);
          if (code >= 0xD800 && code <= 0xDFFF) {
            code = 0x20;
          }
          out.writeCharCode(code);
        }
        return out.toString();
      default:
        const List<String> pieces = <String>[
          '{',
          '}',
          '[',
          ']',
          ',',
          ':',
          '"',
          'null',
          'true',
          '12',
          '-',
          '1e',
          '"a"',
          ' ',
        ];
        return <String>[
          for (int i = 0, n = random.nextInt(12); i < n; i++)
            pieces[random.nextInt(pieces.length)],
        ].join();
    }
  },
  shrink: (String text) sync* {
    final List<int> runes = text.runes.toList();
    if (runes.isNotEmpty) {
      yield String.fromCharCodes(runes.sublist(0, runes.length ~/ 2));
    }
  },
);

/// Values of another type to put in place of a field: [absentField], `null`,
/// a string, an integer, a negative integer, a boolean, a list or an object.
/// Shrinks towards [absentField].
Generator<Object?> get anyReplacement => any.simple<Object?>(
  generate: (math.Random random, int size) {
    switch (random.nextInt(8)) {
      case 0:
        return absentField;
      case 1:
        return null;
      case 2:
        return _jsonStrings[random.nextInt(_jsonStrings.length)];
      case 3:
        return random.nextInt(100000);
      case 4:
        return -1 - random.nextInt(100000);
      case 5:
        return random.nextBool();
      case 6:
        return <Object?>[for (int i = 0; i < random.nextInt(3); i++) i];
      default:
        return <String, Object?>{'k': random.nextInt(10)};
    }
  },
  shrink: (Object? value) sync* {
    if (!identical(value, absentField)) {
      yield absentField;
    }
  },
);

/// A copy of [body] where [key] holds [replacement], or is removed when
/// [replacement] is [absentField]. [body] is not changed.
Map<String, Object?> withField(
  Map<String, Object?> body,
  String key,
  Object? replacement,
) {
  final Map<String, Object?> copy = Map<String, Object?>.of(body);
  if (identical(replacement, absentField)) {
    copy.remove(key);
  } else {
    copy[key] = replacement;
  }
  return copy;
}

/// A GitHub repository body: `pushed_at` set to [pushedAt] (any JSON value,
/// or [absentField] to leave it out) plus [fields]. [fields] may carry
/// `full_name`, `description`, `html_url`, `archived`, `stargazers_count`,
/// `updated_at` and unknown keys.
Map<String, Object?> pushedAtBody(
  Object? pushedAt, {
  Map<String, Object?> fields = const <String, Object?>{},
}) => withField(Map<String, Object?>.of(fields), 'pushed_at', pushedAt);

/// One named way to make an encoded grave unreadable. [apply] returns a
/// corrupted copy of a valid encoded grave and never changes its input.
final class Corruption {
  /// Creates a corruption.
  const Corruption(this.name, this.apply);

  /// Shown in test failures.
  final String name;

  /// Returns a corrupted copy of an encoded grave.
  final Map<String, Object?> Function(Map<String, Object?> encoded) apply;

  @override
  String toString() => name;
}

Corruption _set(String name, String key, Object? value) =>
    Corruption(name, (Map<String, Object?> m) => withField(m, key, value));

/// Corruptions of an encoded grave (keys `id`, `name`, `died`, `source`) that
/// a codec must reject: each of the four keys missing, `id` empty, non-ASCII
/// or over 255 characters, `name` empty, whitespace only or over 80 code
/// points, `died` malformed or impossible, `source` unknown, and every key
/// holding a value of the wrong JSON type.
final List<Corruption> anyCorruption = <Corruption>[
  _set('missing id', 'id', absentField),
  _set('missing name', 'name', absentField),
  _set('missing died', 'died', absentField),
  _set('missing source', 'source', absentField),
  _set('empty id', 'id', ''),
  _set('non-ASCII id', 'id', 'g\u00e9'),
  _set('emoji id', 'id', 'g\u{1F47B}'),
  _set('id of 256 characters', 'id', 'g' * 256),
  _set('empty name', 'name', ''),
  _set('whitespace-only name', 'name', ' \t\n  '),
  _set('name of 81 code points', 'name', 'a' * 81),
  _set('name of 81 emoji', 'name', '\u{1F47B}' * 81),
  _set('died without dashes', 'died', '20240229'),
  _set('died with short month', 'died', '2024-2-9'),
  _set('died as words', 'died', 'yesterday'),
  _set('empty died', 'died', ''),
  _set('died 2026-02-30', 'died', '2026-02-30'),
  _set('died 2025-02-29', 'died', '2025-02-29'),
  _set('died month 13', 'died', '2026-13-01'),
  _set('died with time', 'died', '2024-02-29T00:00:00Z'),
  _set('unknown source', 'source', 'zombie'),
  _set('empty source', 'source', ''),
  _set('source in capitals', 'source', 'GITHUB'),
  for (final String key in <String>[
    'id',
    'name',
    'died',
    'source',
  ]) ...<Corruption>[
    _set('$key as null', key, null),
    _set('$key as int', key, 7),
    _set('$key as bool', key, true),
    _set('$key as list', key, <Object?>['x']),
    _set('$key as object', key, <String, Object?>{'x': 1}),
  ],
];
