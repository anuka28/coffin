import 'dart:convert';
import 'dart:math' as math;

import 'package:coffin_core/coffin_core.dart' show CoffinColorTokens;
import 'package:flutter_test/flutter_test.dart' show expect, equals, isPositive;
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:graveyard/src/domain/calendar_date.dart';
import 'package:graveyard/src/domain/grave.dart';
import 'package:graveyard/src/domain/name_rules.dart';
import 'package:graveyard/src/domain/repo_info.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/domain/resurrection/play_timing.dart';
import 'package:graveyard/src/domain/scene/keep_out_rect.dart';
import 'package:graveyard/src/domain/seance/seance_facts.dart';

// Pure support code with no file-system access. It also runs in Chrome.
// Every generated integer stays far below 2^53.

/// Runs per property in the graveyard tests.
const int numRuns = 200;

/// Integers from [min] inclusive to [max] exclusive.
///
/// Use this instead of the built-in ranged integer generator: glados 1.1.7 computes `1 << 32` in
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
/// The web-safe counterpart of the built-in ranged list generator. Shrinks by
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

/// Doubles from [min] to [max] inclusive in steps of 0.001: an integer in
/// thousandths divided by 1000. Web-safe. Shrinks towards [min] (or 0 when 0
/// is in range).
Generator<double> anyDoubleBetween(double min, double max) {
  final int lo = (min * 1000).round();
  final int hi = (max * 1000).round();
  assert(lo <= hi && hi - lo < 0xFFFFFFFF);
  final int target = lo <= 0 && hi >= 0 ? 0 : lo;
  return any.simple<double>(
    generate: (math.Random random, int size) =>
        (lo + random.nextInt(hi - lo + 1)) / 1000,
    shrink: (double v) sync* {
      final int t = (v * 1000).round();
      if (t > target) {
        yield (target + (t - target) ~/ 2) / 1000;
      } else if (t < target) {
        yield (target - (target - t) ~/ 2) / 1000;
      }
    },
  );
}

/// Seeds from 0 to 2147483646. Shrinks towards 0.
Generator<int> get anySeed => anyIntBetween(0, 2147483647);

/// A scene size in logical pixels.
final class SceneSize {
  /// Creates a size.
  const SceneSize(this.width, this.height);

  /// Width, 1 or more.
  final int width;

  /// Height, 1 or more.
  final int height;

  @override
  bool operator ==(Object other) =>
      other is SceneSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'SceneSize(${width}x$height)';
}

/// Scene sizes: width 1 to 2000 and height 1 to 4000, with 1 by 1 and
/// 320 by 640 drawn about one time in five. Shrinks towards 1 by 1.
Generator<SceneSize> get anySceneSize => any.simple<SceneSize>(
  generate: (math.Random random, int size) {
    switch (random.nextInt(10)) {
      case 0:
        return const SceneSize(1, 1);
      case 1:
        return const SceneSize(320, 640);
      default:
        return SceneSize(1 + random.nextInt(2000), 1 + random.nextInt(4000));
    }
  },
  shrink: (SceneSize s) sync* {
    if (s.width > 1 || s.height > 1) {
      yield SceneSize(1 + (s.width - 1) ~/ 2, 1 + (s.height - 1) ~/ 2);
    }
  },
);

/// The inputs of one twinkle opacity reading.
final class TwinkleInput {
  /// Creates an input.
  const TwinkleInput({
    required this.phaseMs,
    required this.periodMs,
    required this.elapsedMs,
  });

  /// Phase offset, 0 up to but not including [periodMs].
  final int phaseMs;

  /// Period, 3000 to 8000.
  final int periodMs;

  /// Elapsed time, 0 to 10^9.
  final int elapsedMs;

  @override
  bool operator ==(Object other) =>
      other is TwinkleInput &&
      other.phaseMs == phaseMs &&
      other.periodMs == periodMs &&
      other.elapsedMs == elapsedMs;

  @override
  int get hashCode => Object.hash(phaseMs, periodMs, elapsedMs);

  @override
  String toString() =>
      'TwinkleInput(phase: $phaseMs, period: $periodMs, elapsed: $elapsedMs)';
}

/// Twinkle inputs: a period from 3000 to 8000, a phase from 0 to the period
/// minus 1, and an elapsed time from 0 to 10^9. Shrinks towards 0 elapsed and
/// phase.
Generator<TwinkleInput> get anyTwinkleInput => any.simple<TwinkleInput>(
  generate: (math.Random random, int size) {
    final int period = 3000 + random.nextInt(5001);
    return TwinkleInput(
      phaseMs: random.nextInt(period),
      periodMs: period,
      elapsedMs: random.nextInt(1000000001),
    );
  },
  shrink: (TwinkleInput t) sync* {
    if (t.elapsedMs > 0 || t.phaseMs > 0) {
      yield TwinkleInput(
        phaseMs: t.phaseMs ~/ 2,
        periodMs: t.periodMs,
        elapsedMs: t.elapsedMs ~/ 2,
      );
    }
  },
);

/// Edge widths around the layout breakpoints and limits.
const List<int> _edgeWidths = <int>[319, 320, 719, 720, 1000, 1280, 4096];

/// Available widths: 1 to 4096, with the edges 319, 320, 719, 720, 1000,
/// 1280 and 4096 drawn about one time in four. Shrinks towards 1.
Generator<int> get anyAvailableWidth => any.simple<int>(
  generate: (math.Random random, int size) => random.nextInt(4) == 0
      ? _edgeWidths[random.nextInt(_edgeWidths.length)]
      : 1 + random.nextInt(4096),
  shrink: (int w) sync* {
    if (w > 1) {
      yield 1 + (w - 1) ~/ 2;
    }
  },
);

/// Column counts from 1 to 4. Shrinks towards 1.
Generator<int> get anyColumnCount => anyIntBetween(1, 5);

/// Grave counts from 0 to 60. Shrinks towards 0.
Generator<int> get anyGraveCount => anyIntBetween(0, 61);

/// The 15 ids [anyIdList] draws from.
final List<String> idPool = List<String>.unmodifiable(<String>[
  for (int i = 1; i <= 15; i++) 'g$i',
]);

/// Lists of 0 to 12 distinct ids from [idPool], in any order. Shrinks by
/// dropping ids.
Generator<List<String>> get anyIdList => any.simple<List<String>>(
  generate: (math.Random random, int size) {
    final List<String> pool = List<String>.of(idPool);
    // Fisher-Yates shuffle with the generator's own random source.
    for (int i = pool.length - 1; i > 0; i--) {
      final int j = random.nextInt(i + 1);
      final String tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }
    return pool.sublist(0, random.nextInt(13));
  },
  shrink: (List<String> list) sync* {
    if (list.isNotEmpty) {
      yield list.sublist(0, list.length ~/ 2);
      yield list.sublist(1);
    }
  },
);

/// Fixed day counts on the weathering and crack boundaries.
const List<int> _edgeDayCounts = <int>[
  0,
  1,
  1824,
  1825,
  1826,
  3649,
  3650,
  3651,
];

/// Day counts from -5 to 4000, with the edge days 0, 1, 1824, 1825, 1826,
/// 3649, 3650 and 3651 drawn about one time in four. Shrinks towards 0.
Generator<int> get anyDayCount => any.simple<int>(
  generate: (math.Random random, int size) => random.nextInt(4) == 0
      ? _edgeDayCounts[random.nextInt(_edgeDayCounts.length)]
      : -5 + random.nextInt(4006),
  shrink: (int d) sync* {
    if (d > 0) {
      yield d ~/ 2;
    } else if (d < 0) {
      yield 0;
    }
  },
);

/// Ids that are not `g1` to `g99`: non-ASCII, a single space, 200 characters.
final List<String> _oddGraveIds = List<String>.unmodifiable(<String>[
  'g\u00e9',
  '\u5e55\u8d1d',
  'g\u{1F47B}',
  '\u00e9\u00f1\u00fc',
  ' ',
  'g' * 200,
]);

/// Grave ids: `g1` to `g99`, plus now and then a non-ASCII id, an id of one
/// space or an id of 200 characters. Shrinks towards `g1`.
Generator<String> get anyMixedGraveId => any.simple<String>(
  generate: (math.Random random, int size) => random.nextInt(5) == 0
      ? _oddGraveIds[random.nextInt(_oddGraveIds.length)]
      : 'g${1 + random.nextInt(99)}',
  shrink: (String id) sync* {
    if (id != 'g1') {
      yield 'g1';
    }
  },
);

/// Theme tokens: index 0 maps to [CoffinColorTokens.night], index 1 to
/// [CoffinColorTokens.daylight]. Shrinks towards night.
Generator<CoffinColorTokens> get anyThemeTokens =>
    any.simple<CoffinColorTokens>(
      generate: (math.Random random, int size) => random.nextBool()
          ? CoffinColorTokens.daylight
          : CoffinColorTokens.night,
      shrink: (CoffinColorTokens t) sync* {
        if (!identical(t, CoffinColorTokens.night)) {
          yield CoffinColorTokens.night;
        }
      },
    );

/// The inputs of one epitaph fit into an arch.
final class ArchInput {
  /// Creates an input.
  const ArchInput({
    required this.archWidth,
    required this.archRise,
    required this.lineHeight,
    required this.textWidth,
  });

  /// Arch width, 120 to 300.
  final int archWidth;

  /// Arch rise, 60 to 200.
  final int archRise;

  /// Line height, 8 to 60.
  final int lineHeight;

  /// Text width, 1 to [archWidth].
  final int textWidth;

  @override
  bool operator ==(Object other) =>
      other is ArchInput &&
      other.archWidth == archWidth &&
      other.archRise == archRise &&
      other.lineHeight == lineHeight &&
      other.textWidth == textWidth;

  @override
  int get hashCode => Object.hash(archWidth, archRise, lineHeight, textWidth);

  @override
  String toString() =>
      'ArchInput(width: $archWidth, rise: $archRise, '
      'line: $lineHeight, text: $textWidth)';
}

/// Arch inputs: width 120 to 300, rise 60 to 200, line height 8 to 60 and a
/// text width from 1 to the arch width. Shrinks towards the smallest values.
Generator<ArchInput> get anyArchInput => any.simple<ArchInput>(
  generate: (math.Random random, int size) {
    final int width = 120 + random.nextInt(181);
    return ArchInput(
      archWidth: width,
      archRise: 60 + random.nextInt(141),
      lineHeight: 8 + random.nextInt(53),
      textWidth: 1 + random.nextInt(width),
    );
  },
  shrink: (ArchInput a) sync* {
    if (a.archRise > 60 || a.lineHeight > 8 || a.textWidth > 1) {
      yield ArchInput(
        archWidth: a.archWidth,
        archRise: 60 + (a.archRise - 60) ~/ 2,
        lineHeight: 8 + (a.lineHeight - 8) ~/ 2,
        textWidth: 1 + (a.textWidth - 1) ~/ 2,
      );
    }
  },
);

const List<String> _descriptionPieces = <String>[
  ':ghost:',
  ':skull:',
  ':jack_o_lantern:',
  ':+1:',
  ':100:',
  ':not_a_code',
  '12:30',
  '09:05:59',
  'localhost:8080',
  ':3000',
  ':',
  '::',
  ': :',
  'a:b',
  ' ',
  '   ',
  '\t',
  '\n',
  '\n\n  \n',
  '\u{1F47B}',
  '\u{1F480}\u{1F383}',
  '\u2764\uFE0F',
  '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}',
  'caf\u00e9',
  '\u4e2d\u6587',
  'plain words',
  'Haunted project',
];

/// Descriptions of 0 to 2,000 characters built from shortcodes (`:ghost:`,
/// `:+1:`, `:100:`), times, ports, runs of whitespace, Unicode emoji, lone
/// colons and plain words. Shrinks by halving.
Generator<String> get anyDescription => any.simple<String>(
  generate: (math.Random random, int size) {
    final int limit = random.nextInt(8) == 0 ? 2000 : 1 + random.nextInt(120);
    final StringBuffer out = StringBuffer();
    while (out.length < limit) {
      out.write(_descriptionPieces[random.nextInt(_descriptionPieces.length)]);
    }
    final List<int> runes = out.toString().runes.toList();
    final int count = random.nextInt(8) == 0 ? runes.length : limit;
    // Cut at a rune boundary, then keep it within 2,000 UTF-16 units.
    var text = String.fromCharCodes(
      runes.sublist(0, count < runes.length ? count : runes.length),
    );
    while (text.length > 2000) {
      final List<int> r = text.runes.toList();
      text = String.fromCharCodes(r.sublist(0, r.length - 1));
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

const List<String> _dateLines = <String>[
  'Died 29 Feb 2024',
  'Died 1 Jan 1970',
  'Died 31 Dec 2099',
  '2024-02-29',
  'Rest in peace since 2026',
  '\u00e9t\u00e9 2024',
  '\u4e2d\u6587 2024',
  '\u{1F47B} 2024-03-01',
  ' ',
  'x',
];

/// Date-line texts: short date texts, some with non-ASCII characters, one
/// single space and one single character, with now and then a long line.
/// Shrinks towards `x`.
Generator<String> get anyDateLine => any.simple<String>(
  generate: (math.Random random, int size) {
    final String base = _dateLines[random.nextInt(_dateLines.length)];
    return random.nextInt(10) == 0
        ? List<String>.filled(1 + random.nextInt(30), base).join(' ')
        : base;
  },
  shrink: (String line) sync* {
    if (line != 'x') {
      yield 'x';
    }
  },
);

/// Fixed non-negative integers drawn on their own.
const List<int> _edgeNonNegativeInts = <int>[
  0,
  7,
  999,
  1000,
  60683,
  181478,
  1234567,
];

/// Non-negative integers from 0 to 2^53 - 1, built from a high half of 21
/// bits and a low half of 32 bits (so no draw needs a range above 2^32), with
/// 0, 7, 999, 1000, 60683, 181478 and 1234567 drawn about one time in four.
/// Shrinks towards 0.
Generator<int> get anyNonNegativeInt => any.simple<int>(
  generate: (math.Random random, int size) {
    if (random.nextInt(4) == 0) {
      return _edgeNonNegativeInts[random.nextInt(_edgeNonNegativeInts.length)];
    }
    final int high = random.nextInt(1 << 21);
    final int low = random.nextInt(4294967296);
    return high * 4294967296 + low;
  },
  shrink: (int n) sync* {
    if (n > 0) {
      yield n ~/ 2;
    }
  },
);

/// The inputs of one crack generation, with the keep-out list the tombstone
/// builds.
final class CrackInput {
  /// Creates an input.
  const CrackInput({
    required this.stoneWidth,
    required this.stoneHeight,
    required this.dayCount,
    required this.graveId,
    required this.keepOut,
  });

  /// Stone width, 240 to 300.
  final int stoneWidth;

  /// Stone height, 260 to 900.
  final int stoneHeight;

  /// Days since the grave died.
  final int dayCount;

  /// Grave id.
  final String graveId;

  /// The content box and the epitaph rectangle.
  final List<KeepOutRect> keepOut;

  @override
  bool operator ==(Object other) =>
      other is CrackInput &&
      other.stoneWidth == stoneWidth &&
      other.stoneHeight == stoneHeight &&
      other.dayCount == dayCount &&
      other.graveId == graveId &&
      other.keepOut.length == keepOut.length &&
      <bool>[
        for (int i = 0; i < keepOut.length; i++) other.keepOut[i] == keepOut[i],
      ].every((bool same) => same);

  @override
  int get hashCode =>
      Object.hash(stoneWidth, stoneHeight, dayCount, graveId, keepOut.length);

  @override
  String toString() =>
      'CrackInput(${stoneWidth}x$stoneHeight, days: $dayCount, '
      'id: $graveId, keepOut: $keepOut)';
}

/// Arch rise of the tombstone card: the epitaph lies within it.
const int _crackArchRise = 140;

/// Crack inputs: stone width 240 to 300, stone height 260 to 900, a day count
/// from [anyDayCount], a grave id from [anyMixedGraveId], and the keep-out list as
/// the tombstone builds it: the content box `(20, 0, width - 20, height - 20)`
/// and an epitaph rectangle inside the arch (top 56 to 80, 20 to 44 high,
/// 40 to 120 wide, centered, bottom at most 140). Shrinks towards the
/// smallest stone, keeping the day count and the id.
Generator<CrackInput> get anyCrackInput => any.simple<CrackInput>(
  generate: (math.Random random, int size) {
    final int width = 240 + random.nextInt(61);
    final int height = 260 + random.nextInt(641);
    final int dayCount = anyDayCount(random, size).value;
    final String graveId = anyMixedGraveId(random, size).value;
    final int top = 56 + random.nextInt(25);
    final int bottom = math.min(top + 20 + random.nextInt(25), _crackArchRise);
    final int epitaphWidth = 40 + random.nextInt(81);
    final double left = (width - epitaphWidth) / 2;
    return CrackInput(
      stoneWidth: width,
      stoneHeight: height,
      dayCount: dayCount,
      graveId: graveId,
      keepOut: <KeepOutRect>[
        KeepOutRect(
          left: 20,
          top: 0,
          right: (width - 20).toDouble(),
          bottom: (height - 20).toDouble(),
        ),
        KeepOutRect(
          left: left,
          top: top.toDouble(),
          right: left + epitaphWidth,
          bottom: bottom.toDouble(),
        ),
      ],
    );
  },
  shrink: (CrackInput c) sync* {
    if (c.stoneWidth > 240 || c.stoneHeight > 260) {
      final int w = 240 + (c.stoneWidth - 240) ~/ 2;
      final int h = 260 + (c.stoneHeight - 260) ~/ 2;
      yield CrackInput(
        stoneWidth: w,
        stoneHeight: h,
        dayCount: c.dayCount,
        graveId: c.graveId,
        keepOut: <KeepOutRect>[
          KeepOutRect(
            left: 20,
            top: 0,
            right: (w - 20).toDouble(),
            bottom: (h - 20).toDouble(),
          ),
          c.keepOut[1],
        ],
      );
    }
  },
);

/// Day counts on the séance band edges.
const List<int> _seanceEdgeDays = <int>[
  0, 30, 31, 90, 91, 180, 181, 365, 366, 730, 731, 1095, 1096, 1825, 1826, //
  3650, 3651,
];

/// Star counts on the séance band edges and two real-world values.
const List<int> _seanceEdgeStars = <int>[0, 1, 511, 1023, 2000, 60680, 181400];

int _dayCountFrom(math.Random random, int size) => random.nextInt(4) == 0
    ? _seanceEdgeDays[random.nextInt(_seanceEdgeDays.length)]
    : anyIntBetween(0, 20001)(random, size).value;

int _starsFrom(math.Random random, int size) => random.nextInt(4) == 0
    ? _seanceEdgeStars[random.nextInt(_seanceEdgeStars.length)]
    : anyIntBetween(0, 1048577)(random, size).value;

bool _flag(math.Random random, int size) =>
    anyIntBetween(0, 2)(random, size).value == 1;

Iterable<SeanceFacts> _shrinkFacts(SeanceFacts f) sync* {
  if (f.dayCount > 0 || f.stars > 0) {
    yield SeanceFacts(
      dayCount: f.dayCount ~/ 2,
      archived: f.archived,
      stars: f.stars ~/ 2,
      hasDescription: f.hasDescription,
      manual: f.manual,
    );
  }
}

/// Séance facts of any grave: a day count from 0 to 20000 (the band edges 0,
/// 30, 31, 90, 91, 180, 181, 365, 366, 730, 731, 1095, 1096, 1825, 1826, 3650
/// and 3651 drawn about one time in four), stars from 0 to 1048576 (with 0,
/// 1, 511, 1023, 2000, 60680 and 181400 drawn about one time in four) and
/// random flags. A manual fact has no archive flag, no stars and no
/// description. Shrinks towards 0 days and 0 stars.
Generator<SeanceFacts> get anySeanceFacts => any.simple<SeanceFacts>(
  generate: (math.Random random, int size) {
    final int dayCount = _dayCountFrom(random, size);
    final int stars = _starsFrom(random, size);
    final bool archived = _flag(random, size);
    final bool hasDescription = _flag(random, size);
    final bool manual = _flag(random, size);
    return SeanceFacts(
      dayCount: dayCount,
      archived: manual ? false : archived,
      stars: manual ? 0 : stars,
      hasDescription: manual ? false : hasDescription,
      manual: manual,
    );
  },
  shrink: _shrinkFacts,
);

/// Séance facts of a manual grave: any day count as in [anySeanceFacts],
/// `manual` true, `archived` false, 0 stars and a random `hasDescription`
/// (which a real manual grave never has, but the scorer must ignore).
Generator<SeanceFacts> get anyManualFacts => any.simple<SeanceFacts>(
  generate: (math.Random random, int size) => SeanceFacts(
    dayCount: _dayCountFrom(random, size),
    archived: false,
    stars: 0,
    hasDescription: _flag(random, size),
    manual: true,
  ),
  shrink: _shrinkFacts,
);

/// Scores from 0 to 100 with the edges 0, 39, 40, 69, 70 and 100 drawn about
/// one time in four. Shrinks towards 0.
Generator<int> get anyScore => any.simple<int>(
  generate: (math.Random random, int size) => random.nextInt(4) == 0
      ? const <int>[0, 39, 40, 69, 70, 100][random.nextInt(6)]
      : random.nextInt(101),
  shrink: (int v) sync* {
    if (v > 0) {
      yield v ~/ 2;
    }
  },
);

/// A valid grave name from [raw]: normalised, cut to 80 code points, and
/// never empty (an empty result becomes `a`).
String _validGraveName(String raw) {
  final String normalized = NameRules.normalize(raw);
  final String cut = String.fromCharCodes(normalized.runes.take(80));
  final String name = NameRules.normalize(cut);
  return name.isEmpty ? 'a' : name;
}

/// Graves for the séance request tests: a grave from [anyGrave] with a name
/// drawn from [anyProjectName], normalised to 1 to 80 code points (spaces,
/// accents and emoji appear). Shrinks towards a one-code-point name.
Generator<Grave> get anyGraveWithSource => any.simple<Grave>(
  generate: (math.Random random, int size) {
    final Grave base = anyGrave(random, size).value;
    final String name = _validGraveName(anyProjectName(random, size).value);
    final RepoInfo? repo = base.repo;
    return repo == null
        ? Grave.manual(id: base.id, name: name, dateOfDeath: base.dateOfDeath)
        : Grave.github(
            id: base.id,
            name: name,
            dateOfDeath: base.dateOfDeath,
            repo: repo,
          );
  },
  shrink: (Grave g) sync* {
    final List<int> runes = g.name.runes.toList();
    if (runes.length > 1) {
      final String name = _validGraveName(
        String.fromCharCodes(runes.sublist(0, runes.length ~/ 2)),
      );
      yield g.repo == null
          ? Grave.manual(id: g.id, name: name, dateOfDeath: g.dateOfDeath)
          : Grave.github(
              id: g.id,
              name: name,
              dateOfDeath: g.dateOfDeath,
              repo: g.repo!,
            );
    }
  },
);

/// Edge text scales: the smallest, the largest and a common middle value.
const List<double> _edgeTextScales = <double>[1.0, 1.5, 2.0];

/// Text scales from 1.00 to 2.00 in steps of 0.01 (an integer from 100 to
/// 200 divided by 100), with 1.0, 1.5 and 2.0 drawn about one time in four.
/// Shrinks towards 1.0.
Generator<double> get anyTextScale => any.simple<double>(
  generate: (math.Random random, int size) => random.nextInt(4) == 0
      ? _edgeTextScales[random.nextInt(_edgeTextScales.length)]
      : anyIntBetween(100, 201)(random, size).value / 100,
  shrink: (double s) sync* {
    final int hundredths = (s * 100).round();
    if (hundredths > 100) {
      yield (100 + (hundredths - 100) ~/ 2) / 100;
    }
  },
);

/// Stone widths from 120 to 400 logical pixels as whole numbers. Shrinks
/// towards 120.
Generator<double> get anyStoneWidth => any.simple<double>(
  generate: (math.Random random, int size) =>
      anyIntBetween(120, 401)(random, size).value.toDouble(),
  shrink: (double w) sync* {
    if (w > 120) {
      yield 120 + ((w - 120) ~/ 2).toDouble();
    }
  },
);

/// Stone heights from 160 to 480 logical pixels as whole numbers. Shrinks
/// towards 160.
Generator<double> get anyStoneHeight => any.simple<double>(
  generate: (math.Random random, int size) =>
      anyIntBetween(160, 481)(random, size).value.toDouble(),
  shrink: (double h) sync* {
    if (h > 160) {
      yield 160 + ((h - 160) ~/ 2).toDouble();
    }
  },
);

/// The play length in milliseconds. Mirrors `PlayTiming.playDurationMs`
/// 2800 drawn about one time in four. Shrinks towards 0.
Generator<int> get anyElapsedMs => any.simple<int>(
  generate: (math.Random random, int size) => random.nextInt(4) == 0
      ? const <int>[
          0,
          1,
          PlayTiming.playDurationMs - 1,
          PlayTiming.playDurationMs,
        ][random.nextInt(4)]
      : anyIntBetween(0, PlayTiming.playDurationMs + 1)(random, size).value,
  shrink: (int ms) sync* {
    if (ms > 0) {
      yield ms ~/ 2;
    }
  },
);

/// Elapsed times from -500 to 3300 inclusive, so values before the start and
/// after the end appear. The edges -500, -1, 0, 2800, 2801 and 3300 are drawn
/// about one time in four. Shrinks towards 0.
Generator<int> get anyWideElapsedMs => any.simple<int>(
  generate: (math.Random random, int size) => random.nextInt(4) == 0
      ? const <int>[
          -500,
          -1,
          0,
          PlayTiming.playDurationMs,
          PlayTiming.playDurationMs + 1,
          3300,
        ][random.nextInt(6)]
      : anyIntBetween(-500, 3301)(random, size).value,
  shrink: (int ms) sync* {
    if (ms > 0) {
      yield ms ~/ 2;
    } else if (ms < 0) {
      yield ms ~/ 2;
    }
  },
);

/// Risen dates: null about one time in three, otherwise a date from
/// [anyCalendarDate]. Shrinks towards null.
Generator<CalendarDate?> get anyRisenOn => any.simple<CalendarDate?>(
  generate: (math.Random random, int size) =>
      random.nextInt(3) == 0 ? null : anyCalendarDate(random, size).value,
  shrink: (CalendarDate? d) sync* {
    if (d != null) {
      yield null;
    }
  },
);

/// Graves from [anyGrave], GitHub and manual, with `risenOn` from
/// [anyRisenOn]. Shrinks towards a Grave that is not Risen.
Generator<Grave> get anyGraveWithRisen => any.simple<Grave>(
  generate: (math.Random random, int size) => anyGrave(
    random,
    size,
  ).value.copyWithRisenOn(anyRisenOn(random, size).value),
  shrink: (Grave g) sync* {
    if (g.risenOn != null) {
      yield g.copyWithRisenOn(null);
    }
  },
);

/// Lists of 0 to 12 Graves with distinct ids. About one Grave in three takes
/// the list's shared `risenOn` value (which may be null), so equal values
/// are common. Shrinks by dropping Graves.
Generator<List<Grave>> get anyRisenGraveList => any.simple<List<Grave>>(
  generate: (math.Random random, int size) {
    final int length = random.nextInt(13);
    final CalendarDate? shared = anyRisenOn(random, size).value;
    final Map<String, Grave> byId = <String, Grave>{};
    for (int i = 0; i < length; i++) {
      Grave g = anyGraveWithRisen(random, size).value;
      if (random.nextInt(3) == 0) {
        g = g.copyWithRisenOn(shared);
      }
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

/// A Grave list and a set of ids marked as playing.
typedef PlayingCase = ({List<Grave> graves, Set<String> playing});

/// A Grave list from [anyRisenGraveList] and a set of playing ids: a random
/// subset of the list's ids plus up to two ids that are not in the list.
/// Shrinks towards an empty playing set.
Generator<PlayingCase> get anyPlayingSet => any.simple<PlayingCase>(
  generate: (math.Random random, int size) {
    final List<Grave> graves = anyRisenGraveList(random, size).value;
    final Set<String> playing = <String>{
      for (final Grave g in graves)
        if (random.nextBool()) g.id,
      for (int i = 0, n = random.nextInt(3); i < n; i++) 'missing$i',
    };
    return (graves: graves, playing: playing);
  },
  shrink: (PlayingCase c) sync* {
    if (c.playing.isNotEmpty) {
      yield (graves: c.graves, playing: <String>{});
    }
  },
);

/// Grave ids of 1 to 24 characters, each a code point from 0x30 to 0x7A
/// (digits, letters and a few punctuation marks), built with
/// [anyIntBetween]. Shrinks by dropping characters.
Generator<String> get anyGraveId => any.simple<String>(
  generate: (math.Random random, int size) => String.fromCharCodes(
    anyListBetween<int>(1, 25, anyIntBetween(0x30, 0x7B))(random, size).value,
  ),
  shrink: (String id) sync* {
    if (id.length > 1) {
      yield id.substring(0, id.length ~/ 2);
    }
  },
);
