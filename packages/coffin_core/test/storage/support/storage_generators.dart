import 'dart:convert';
import 'dart:math' as math;

import 'package:coffin_core/src/storage/envelope_codec.dart';
import 'package:coffin_core/src/storage/json_map.dart';
import 'package:coffin_core/src/storage/storage_issue_kind.dart';
import 'package:glados/glados.dart' hide expect, group, test;

import 'test_note.dart';

export 'test_note.dart' show deepEquals, deepHash;

// Pure support code: no dart:io, no hive_ce. It also runs in Chrome.

/// The boundary keys B1 to B11 from the design's boundary key table.
abstract final class BoundaryKeys {
  /// B1: the empty key. Coffin rejects it.
  static final String b1 = '';

  /// B2: the shortest valid key.
  static final String b2 = 'a';

  /// B3: 255 code units, the longest valid key.
  static final String b3 = 'k' * 255;

  /// B4: 256 code units, one too many.
  static final String b4 = 'k' * 256;

  /// B5: the highest valid character, `0x7F`.
  static final String b5 = 'x\u007F';

  /// B6: the lowest character, `0x00`.
  static final String b6 = '\u0000';

  /// B7: the first invalid character, `0x80`.
  static final String b7 = 'x\u0080';

  /// B8: a non-BMP character (two code units).
  static final String b8 = '\u{1F47B}';

  /// B9: a lone surrogate.
  static final String b9 = '\uD800';

  /// B10: 128 accented letters, 256 UTF-8 bytes.
  static final String b10 = 'é' * 128;

  /// B11: ordinary punctuation and a space.
  static final String b11 = 'a/b..c d';

  /// All eleven keys, in table order.
  static final List<String> all = <String>[
    b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, //
  ];

  /// The keys coffin accepts (B2, B3, B5, B6, B11).
  static final List<String> valid = <String>[b2, b3, b5, b6, b11];

  /// The keys coffin rejects (B1, B4, B7, B8, B9, B10).
  static final List<String> invalid = <String>[b1, b4, b7, b8, b9, b10];
}

/// Integers from [min] inclusive to [max] exclusive.
///
/// Use this instead of `any.intInRange`: glados 1.1.7 computes `1 << 32` in
/// its range helper, which is 0 on web, so `any.intInRange` and
/// `any.listWithLengthInRange` throw in Chrome. This one calls
/// `Random.nextInt` directly, which works on every platform for ranges below
/// 2^32. Shrinks towards [min] (or 0 when 0 is in range).
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
/// The web-safe counterpart of `any.listWithLengthInRange` (see
/// [anyIntBetween]). Shrinks by dropping and shrinking elements.
Generator<List<T>> anyListBetween<T>(int min, int max, Generator<T> item) {
  assert(0 <= min && min < max);
  return (math.Random random, int size) {
    final int length = min + random.nextInt(max - min);
    return ShrinkableList<T>(<Shrinkable<T>>[
      for (int i = 0; i < length; i++) item(random, size),
    ], min);
  };
}

/// The six ordinary keys, so overwrites and deletes of existing keys are
/// common (Requirement 12.5).
const List<String> ordinaryKeys = <String>['a', 'b', 'c', 'd', 'e', 'f'];

/// Generates a key: about 80% one of [ordinaryKeys], otherwise a boundary key.
///
/// Shrinks towards `'a'`.
Generator<String> get anyKey => any.simple<String>(
  generate: (math.Random random, int size) {
    if (random.nextInt(100) < 80) {
      return ordinaryKeys[random.nextInt(ordinaryKeys.length)];
    }
    return BoundaryKeys.all[random.nextInt(BoundaryKeys.all.length)];
  },
  shrink: (String key) => key == 'a' ? const <String>[] : const <String>['a'],
);

/// Generates only keys the validator accepts (the six ordinary keys plus the
/// valid boundary keys).
Generator<String> get anyValidKey => any.simple<String>(
  generate: (math.Random random, int size) {
    if (random.nextInt(100) < 85) {
      return ordinaryKeys[random.nextInt(ordinaryKeys.length)];
    }
    return BoundaryKeys.valid[random.nextInt(BoundaryKeys.valid.length)];
  },
  shrink: (String key) => key == 'a' ? const <String>[] : const <String>['a'],
);

// Pieces for strings. Mixed on purpose: ASCII, accents, CJK, an emoji, quotes,
// backslashes and control characters.
const List<String> _pieces = <String>[
  'a', 'Z', '0', ' ', 'é', 'ß', '漢', '字', '\u{1F47B}', '"', '\\', '/', //
  '\n', '\t', '\u0001', "'", '{', ']',
];

/// A lone surrogate. JSON text keeps it, but UTF-8 storage (a real Hive box)
/// would turn it into U+FFFD, so only [anySafeMap] may use it.
const String _loneSurrogate = '\uD800';

Generator<String> _stringOf(List<String> pieces) => any.simple<String>(
  generate: (math.Random random, int size) {
    final int length = random.nextInt(9);
    return <String>[
      for (int i = 0; i < length; i++) pieces[random.nextInt(pieces.length)],
    ].join();
  },
  shrink: (String s) sync* {
    if (s.isNotEmpty) yield s.substring(0, s.length ~/ 2);
  },
);

/// Text that survives UTF-8 storage unchanged (no lone surrogate).
Generator<String> get anyNoteText => _stringOf(_pieces);

/// Text that may also contain a lone surrogate. Only for in-memory JSON.
Generator<String> get anyJsonText =>
    _stringOf(<String>[..._pieces, _loneSurrogate]);

/// Generates a [TestNote] that is safe to store in a real box.
///
/// `weight` comes from `any.doubleInRange`, never `any.double`, so it is
/// always finite. Integers stay far below 2^53, so everything round trips
/// exactly on the VM and on web, and `==` is the right comparison.
Generator<TestNote> get anyTestNote =>
    any.combine5<
      String,
      int,
      double?,
      List<String>,
      Map<String, Object?>,
      TestNote
    >(
      anyNoteText,
      anyIntBetween(-1000000, 1000001),
      any.doubleInRange(-1e9, 1e9).nullable,
      anyListBetween(0, 4, anyNoteText),
      _anySmallMap(_pieces),
      (
        String title,
        int count,
        double? weight,
        List<String> tags,
        Map<String, Object?> extra,
      ) => TestNote(
        title: title,
        count: count,
        weight: weight,
        tags: tags,
        extra: extra,
      ),
    );

Generator<Map<String, Object?>> _anySmallMap(List<String> pieces) =>
    any.simple<Map<String, Object?>>(
      generate: (math.Random random, int size) =>
          _randomMap(random, 2, pieces, 3),
      shrink: _shrinkMap,
    );

Iterable<Map<String, Object?>> _shrinkMap(Map<String, Object?> map) sync* {
  if (map.isEmpty) return;
  yield <String, Object?>{};
  for (final String key in map.keys) {
    yield <String, Object?>{...map}..remove(key);
  }
}

/// Generates a JSON-safe map: depth at most 3, at most 4 entries per map or
/// list, finite doubles in `[-1e9, 1e9]`, ints within +/-(2^53 - 1), and
/// mixed-alphabet strings (including a lone surrogate) as values and keys.
Generator<JsonMap> get anySafeMap => any.simple<JsonMap>(
  generate: (math.Random random, int size) =>
      _randomMap(random, 3, <String>[..._pieces, _loneSurrogate], 4),
  shrink: _shrinkMap,
);

/// Generates a version for the envelope property: `0..EnvelopeCodec.maxVersion`
/// with small values and the limits both common.
Generator<int> get anyEnvelopeVersion => any.simple<int>(
  generate: (math.Random random, int size) {
    switch (random.nextInt(6)) {
      case 0:
        return 0;
      case 1:
        return EnvelopeCodec.maxVersion;
      case 2:
        return random.nextInt(EnvelopeCodec.maxVersion);
      default:
        return random.nextInt(6);
    }
  },
  shrink: (int v) => v == 0 ? const <int>[] : <int>[v ~/ 2],
);

/// Largest integer that is exact as a JS number.
const int _maxSafeInt = 9007199254740991;

JsonMap _randomMap(
  math.Random random,
  int depth,
  List<String> pieces,
  int maxEntries,
) {
  final int count = random.nextInt(maxEntries + 1);
  return <String, Object?>{
    for (int i = 0; i < count; i++)
      _randomString(random, pieces): _randomValue(random, depth - 1, pieces),
  };
}

String _randomString(math.Random random, List<String> pieces) {
  final int length = random.nextInt(6);
  return <String>[
    for (int i = 0; i < length; i++) pieces[random.nextInt(pieces.length)],
  ].join();
}

Object? _randomValue(math.Random random, int depth, List<String> pieces) {
  switch (random.nextInt(depth > 0 ? 7 : 5)) {
    case 0:
      return null;
    case 1:
      return random.nextBool();
    case 2:
      // Ints up to +/-(2^53 - 1), built from two halves so this works on web.
      final int big =
          random.nextInt(1 << 26) * (1 << 26) + random.nextInt(1 << 26);
      final int value = big > _maxSafeInt ? _maxSafeInt : big;
      return random.nextBool() ? value : -value;
    case 3:
      return random.nextDouble() * 2e9 - 1e9;
    case 4:
      return _randomString(random, pieces);
    case 5:
      return <Object?>[
        for (int i = 0, n = random.nextInt(5); i < n; i++)
          _randomValue(random, depth - 1, pieces),
      ];
    default:
      return _randomMap(random, depth, pieces, 4);
  }
}

// ---------------------------------------------------------------------------
// Stored entries (decode table classes)
// ---------------------------------------------------------------------------

/// One class per row group of the design's decode table.
enum StoredEntryClass {
  /// Valid envelope at the current version.
  currentValid,

  /// Valid envelope at a lower version (needs a migration hook).
  lowerValid,

  /// Valid envelope at a higher version.
  higherVersion,

  /// Text that is not JSON.
  garbageText,

  /// JSON that is not an object.
  jsonNonObject,

  /// An object without `v`.
  missingVersion,

  /// An object whose `v` is negative, `1.5`, a string, null or too large.
  invalidVersion,

  /// A current-version envelope whose `data` is not an object.
  dataNotObject,

  /// A valid envelope that `TestNoteCodec.decode` rejects.
  codecThrows,
}

/// A raw value to seed into a store, plus what reading it must do.
final class StoredEntry {
  /// Creates an entry.
  const StoredEntry({
    required this.key,
    required this.raw,
    required this.entryClass,
    required this.marker,
    this.version,
    this.note,
  });

  /// A valid coffin key.
  final String key;

  /// The exact string to store under [key].
  final String raw;

  /// Which decode table class this is.
  final StoredEntryClass entryClass;

  /// A unique text carried inside [raw] (except for bare JSON scalars such as
  /// `42` in [StoredEntryClass.jsonNonObject]). Issue messages must never
  /// contain it.
  final String marker;

  /// The stored version, for the classes that have a valid one.
  final int? version;

  /// The record this entry decodes to when it can be read, else null.
  ///
  /// For [StoredEntryClass.lowerValid] this is what an identity migration
  /// hook gives.
  final TestNote? note;

  /// The issue kind a read must report, or null when the entry decodes.
  ///
  /// [hasHook] says whether a migration hook is set and [hookThrows] whether
  /// that hook throws. An identity hook is assumed otherwise.
  StorageIssueKind? expectedIssue({
    required bool hasHook,
    bool hookThrows = false,
  }) {
    switch (entryClass) {
      case StoredEntryClass.currentValid:
        return null;
      case StoredEntryClass.lowerValid:
        if (!hasHook) return StorageIssueKind.unknownVersion;
        return hookThrows ? StorageIssueKind.migrationFailed : null;
      case StoredEntryClass.higherVersion:
        return StorageIssueKind.unknownVersion;
      case StoredEntryClass.garbageText:
      case StoredEntryClass.jsonNonObject:
      case StoredEntryClass.missingVersion:
      case StoredEntryClass.invalidVersion:
      case StoredEntryClass.dataNotObject:
      case StoredEntryClass.codecThrows:
        return StorageIssueKind.corruptRecord;
    }
  }

  /// The record a read returns, or null when the entry is skipped.
  TestNote? expectedNote({required bool hasHook, bool hookThrows = false}) =>
      expectedIssue(hasHook: hasHook, hookThrows: hookThrows) == null
      ? note
      : null;

  @override
  String toString() =>
      'StoredEntry(${entryClass.name}, key: "$key", raw: $raw)';
}

/// A seeded store: a current version and entries with distinct keys.
final class StoredEntrySet {
  /// Creates a set.
  const StoredEntrySet({required this.currentVersion, required this.entries});

  /// The repository's current version for this run.
  final int currentVersion;

  /// Entries with distinct keys.
  final List<StoredEntry> entries;

  /// The raw map to seed: key to stored string.
  Map<String, String> get raw => <String, String>{
    for (final StoredEntry e in entries) e.key: e.raw,
  };

  @override
  String toString() =>
      'StoredEntrySet(currentVersion: $currentVersion, entries: $entries)';
}

/// Distinct valid keys that stored entries use.
final List<String> _entryKeys = <String>{
  ...ordinaryKeys,
  ...BoundaryKeys.valid,
}.toList();

/// Builds one entry of class [entryClass].
///
/// If [entryClass] is [StoredEntryClass.lowerValid] and [currentVersion] is 0
/// there is no lower version, so the entry becomes `currentValid`.
StoredEntry buildStoredEntry({
  required math.Random random,
  required StoredEntryClass entryClass,
  required int currentVersion,
  required String key,
  required String marker,
}) {
  StoredEntryClass kind = entryClass;
  if (kind == StoredEntryClass.lowerValid && currentVersion == 0) {
    kind = StoredEntryClass.currentValid;
  }
  // The marker is the title, so it sits inside the payload.
  final TestNote note = TestNote(
    title: marker,
    count: random.nextInt(100),
    weight: random.nextBool() ? random.nextDouble() * 100 : null,
    tags: <String>[if (random.nextBool()) 'x'],
  );
  final JsonMap data = const TestNoteCodec().encode(note);
  String envelope(Object? v, Object? d) =>
      jsonEncode(<String, Object?>{'v': v, 'data': d});

  switch (kind) {
    case StoredEntryClass.currentValid:
      return StoredEntry(
        key: key,
        raw: envelope(currentVersion, data),
        entryClass: kind,
        marker: marker,
        version: currentVersion,
        note: note,
      );
    case StoredEntryClass.lowerValid:
      final int v = random.nextInt(currentVersion);
      return StoredEntry(
        key: key,
        raw: envelope(v, data),
        entryClass: kind,
        marker: marker,
        version: v,
        note: note,
      );
    case StoredEntryClass.higherVersion:
      final int v = currentVersion + 1 + random.nextInt(3);
      return StoredEntry(
        key: key,
        raw: envelope(v, data),
        entryClass: kind,
        marker: marker,
        version: v,
      );
    case StoredEntryClass.garbageText:
      const List<String> prefixes = <String>['not json ', '{"v":', 'oops<', ''];
      return StoredEntry(
        key: key,
        raw: '${prefixes[random.nextInt(prefixes.length)]}$marker {{',
        entryClass: kind,
        marker: marker,
      );
    case StoredEntryClass.jsonNonObject:
      final List<String> raws = <String>[
        '[1,2,"$marker"]',
        '"$marker"',
        '42',
        'null',
        'true',
      ];
      return StoredEntry(
        key: key,
        raw: raws[random.nextInt(raws.length)],
        entryClass: kind,
        marker: marker,
      );
    case StoredEntryClass.missingVersion:
      return StoredEntry(
        key: key,
        raw: jsonEncode(<String, Object?>{'data': data}),
        entryClass: kind,
        marker: marker,
      );
    case StoredEntryClass.invalidVersion:
      final List<Object?> bad = <Object?>[
        -1,
        1.5,
        '$currentVersion',
        null,
        EnvelopeCodec.maxVersion + 1,
        true,
      ];
      return StoredEntry(
        key: key,
        raw: envelope(bad[random.nextInt(bad.length)], data),
        entryClass: kind,
        marker: marker,
      );
    case StoredEntryClass.dataNotObject:
      final List<Object?> bad = <Object?>[
        <Object?>[marker],
        marker,
        null,
        7,
      ];
      return StoredEntry(
        key: key,
        // An extra envelope property carries the marker when `data` cannot.
        raw: jsonEncode(<String, Object?>{
          'v': currentVersion,
          'data': bad[random.nextInt(bad.length)],
          'note': marker,
        }),
        entryClass: kind,
        marker: marker,
      );
    case StoredEntryClass.codecThrows:
      // `title` has the wrong type, so TestNoteCodec.decode throws.
      return StoredEntry(
        key: key,
        raw: envelope(currentVersion, <String, Object?>{
          ...data,
          'title': <Object?>[marker],
        }),
        entryClass: kind,
        marker: marker,
      );
  }
}

/// Generates a single stored entry for [currentVersion], of any class.
Generator<StoredEntry> anyStoredEntry(int currentVersion) =>
    any.simple<StoredEntry>(
      generate: (math.Random random, int size) => buildStoredEntry(
        random: random,
        entryClass: StoredEntryClass
            .values[random.nextInt(StoredEntryClass.values.length)],
        currentVersion: currentVersion,
        key: _entryKeys[random.nextInt(_entryKeys.length)],
        marker: 'MK${random.nextInt(1 << 30)}',
      ),
      shrink: (StoredEntry e) => const <StoredEntry>[],
    );

/// Generates a seeded store: a current version in `0..5` and 0 to 8 entries
/// with distinct keys and unique markers, every decode table class likely.
Generator<StoredEntrySet> get anyStoredEntrySet => any.simple<StoredEntrySet>(
  generate: (math.Random random, int size) {
    final int currentVersion = random.nextInt(6);
    final List<String> keys = List<String>.of(_entryKeys)..shuffle(random);
    final int count = random.nextInt(9);
    return StoredEntrySet(
      currentVersion: currentVersion,
      entries: <StoredEntry>[
        for (int i = 0; i < count; i++)
          buildStoredEntry(
            random: random,
            entryClass: StoredEntryClass
                .values[random.nextInt(StoredEntryClass.values.length)],
            currentVersion: currentVersion,
            key: keys[i],
            marker: 'MK${i}_${random.nextInt(1 << 30)}',
          ),
      ],
    );
  },
  shrink: (StoredEntrySet s) sync* {
    for (int i = 0; i < s.entries.length; i++) {
      yield StoredEntrySet(
        currentVersion: s.currentVersion,
        entries: <StoredEntry>[...s.entries]..removeAt(i),
      );
    }
  },
);

// ---------------------------------------------------------------------------
// Operations for the model-based test
// ---------------------------------------------------------------------------

/// Prints a key readably: short printable keys in quotes, others escaped or
/// abbreviated.
String describeKey(String key) {
  if (key.length > 24) {
    return '"${key.substring(0, 6)}..."(${key.length} units)';
  }
  final StringBuffer buffer = StringBuffer('"');
  for (final int unit in key.codeUnits) {
    if (unit >= 0x20 && unit < 0x7F) {
      buffer.writeCharCode(unit);
    } else {
      buffer.write('\\u${unit.toRadixString(16).padLeft(4, '0')}');
    }
  }
  return (buffer..write('"')).toString();
}

/// One step of a generated operation sequence.
sealed class Op {
  /// Base constructor.
  const Op();
}

/// `put(key, note)`.
final class PutOp extends Op {
  /// Creates a put.
  const PutOp(this.key, this.note);

  /// Target key.
  final String key;

  /// Record to store.
  final TestNote note;

  @override
  String toString() => 'put(${describeKey(key)}, $note)';
}

/// `delete(key)`.
final class DeleteOp extends Op {
  /// Creates a delete.
  const DeleteOp(this.key);

  /// Target key.
  final String key;

  @override
  String toString() => 'delete(${describeKey(key)})';
}

/// `clear()`.
final class ClearOp extends Op {
  /// Creates a clear.
  const ClearOp();

  @override
  String toString() => 'clear()';
}

/// 0 = put, 1 = delete, 2 = clear. About 55%, 38% and 7%.
Generator<int> get _anyOpKind => any.simple<int>(
  generate: (math.Random random, int size) {
    final int roll = random.nextInt(100);
    return roll < 55 ? 0 : (roll < 93 ? 1 : 2);
  },
  shrink: (int kind) => kind == 0 ? const <int>[] : const <int>[0],
);

/// Generates one [Op]. Keys come from [anyKey], so invalid keys appear too.
Generator<Op> get anyOp => any.combine3<int, String, TestNote, Op>(
  _anyOpKind,
  anyKey,
  anyTestNote,
  (int kind, String key, TestNote note) => switch (kind) {
    0 => PutOp(key, note),
    1 => DeleteOp(key),
    _ => const ClearOp(),
  },
);

/// Generates a sequence of 0 to [maxLength] operations.
Generator<List<Op>> anyOps({int maxLength = 30}) =>
    anyListBetween(0, maxLength + 1, anyOp);
