import 'package:coffin_core/src/ai/ai_purpose.dart';
import 'package:coffin_core/src/ai/ai_request.dart';
import 'package:coffin_core/src/ai/compose_path.dart';
import 'package:coffin_core/src/ai/composed_text.dart';
import 'package:coffin_core/src/ai/offline_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/legacy_catalog.dart';

final Map<String, AiPurpose> _purposes = <String, AiPurpose>{
  'ghost': AiPurpose.ghostMoodLine,
  'seance': AiPurpose.seanceVerdict,
  'custom': AiPurpose('custom_purpose'),
};

final String _longName = 'Z' * 60;

final Map<String, Map<String, Object?>> _facts = <String, Map<String, Object?>>{
  'none': <String, Object?>{},
  'streak3': <String, Object?>{'streakCount': 3},
  'streak1': <String, Object?>{'streakCount': 1},
  'days214': <String, Object?>{'daysSinceLastCommit': 214},
  'ghostName': <String, Object?>{'ghostName': 'Wisp'},
  'project': <String, Object?>{'projectName': 'Crypt Keeper'},
  'all': <String, Object?>{
    'streakCount': 12,
    'daysSinceLastCommit': 214,
    'ghostName': 'Wisp',
    'projectName': 'Crypt Keeper',
  },
  'zero': <String, Object?>{'streakCount': 0, 'daysSinceLastCommit': 0},
  'negative': <String, Object?>{'streakCount': -1, 'daysSinceLastCommit': -1},
  'fraction': <String, Object?>{'streakCount': 2.5, 'daysSinceLastCommit': 2.5},
  'longName': <String, Object?>{
    'ghostName': _longName,
    'projectName': _longName,
  },
  'bannedName': <String, Object?>{
    'ghostName': 'Killer',
    'projectName': 'Blood Moon',
  },
  'bannedWithStreak': <String, Object?>{
    'ghostName': 'Killer',
    'streakCount': 5,
  },
};

/// One pinned case. [text] and [path] were recorded from the unmodified
/// engine, before any ghost-voice edit.
final class _Row {
  const _Row(
    this.purpose,
    this.facts,
    this.maxLength,
    this.seed,
    this.text,
    this.path,
  );

  final String purpose;
  final String facts;
  final int maxLength;
  final int seed;
  final String text;
  final ComposePath path;

  AiRequest get request => AiRequest(
    purpose: _purposes[purpose]!,
    facts: _facts[facts]!,
    maxLength: maxLength,
    seed: seed,
  );

  @override
  String toString() => '$purpose/$facts/$maxLength/$seed';
}

/// The baseline table, recorded from the unmodified engine.
const List<_Row> _baseline = <_Row>[
  _Row('ghost', 'none', 16, 0, 'Floating along.', ComposePath.picked),
  _Row(
    'ghost',
    'streak3',
    40,
    1,
    '3 days so far. Your ghost is humming.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'streak1',
    80,
    7,
    'Your ghost has counted 1 day and is still floating.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'days214',
    200,
    42,
    'Your ghost is getting hungry…',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'ghostName',
    16,
    4294967295,
    'Floating along.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'project',
    40,
    0,
    'Mist, moonlight and good company.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'all',
    80,
    1,
    '12 days so far. Wisp is humming.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'zero',
    200,
    7,
    'Mist, moonlight and good company.',
    ComposePath.picked,
  ),
  _Row('ghost', 'negative', 16, 42, 'Floating along.', ComposePath.picked),
  _Row(
    'ghost',
    'fraction',
    40,
    4294967295,
    'Your ghost drifts by to say boo. 👻',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'longName',
    80,
    0,
    'ZZZZZZZZZZZZZZZZZZZZZZZZ drifts by to say boo. 👻',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'bannedName',
    200,
    1,
    'Mist, moonlight and good company.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'bannedWithStreak',
    16,
    7,
    'Floating along.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'none',
    40,
    42,
    'The spirits are still listening.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'streak3',
    80,
    4294967295,
    'Not gone, just napping.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'streak1',
    200,
    0,
    'This project still glows faintly in the dark.',
    ComposePath.picked,
  ),
  _Row('seance', 'days214', 16, 1, 'Not quite gone.', ComposePath.picked),
  _Row(
    'seance',
    'ghostName',
    40,
    7,
    'Not gone, just napping.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'project',
    80,
    42,
    'Crypt Keeper still glows faintly in the dark.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'all',
    200,
    4294967295,
    '214 days of silence, and Crypt Keeper is still worth a séance.',
    ComposePath.picked,
  ),
  _Row('seance', 'zero', 16, 0, 'Not quite gone.', ComposePath.picked),
  _Row(
    'seance',
    'negative',
    40,
    1,
    'Not gone, just napping.',
    ComposePath.picked,
  ),
  _Row('seance', 'fraction', 80, 7, 'Not quite gone.', ComposePath.picked),
  _Row(
    'seance',
    'longName',
    200,
    42,
    'ZZZZZZZZZZZZZZZZZZZZZZZZ still glows faintly in the dark.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'bannedName',
    16,
    4294967295,
    'Not quite gone.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'bannedWithStreak',
    40,
    0,
    'Not quite gone.',
    ComposePath.picked,
  ),
  _Row(
    'custom',
    'none',
    80,
    1,
    'Something spooky this way comes.',
    ComposePath.picked,
  ),
  _Row(
    'custom',
    'streak3',
    200,
    7,
    '3 days so far. The moon approves.',
    ComposePath.picked,
  ),
  _Row('custom', 'streak1', 16, 42, 'Quiet in here.', ComposePath.picked),
  _Row(
    'custom',
    'days214',
    40,
    4294967295,
    'This one is waiting in the moonlight.',
    ComposePath.picked,
  ),
  _Row('custom', 'ghostName', 80, 0, 'Wisp says hello.', ComposePath.picked),
  _Row(
    'custom',
    'project',
    200,
    1,
    'Crypt Keeper is waiting in the moonlight.',
    ComposePath.picked,
  ),
  _Row('custom', 'all', 16, 7, 'Wisp says hello.', ComposePath.picked),
  _Row(
    'custom',
    'zero',
    40,
    42,
    'Boo. Hello from the mist.',
    ComposePath.picked,
  ),
  _Row(
    'custom',
    'negative',
    80,
    4294967295,
    'This one is waiting in the moonlight.',
    ComposePath.picked,
  ),
  _Row('custom', 'fraction', 200, 0, 'Quiet in here.', ComposePath.picked),
  _Row('custom', 'longName', 16, 1, 'Quiet in here.', ComposePath.picked),
  _Row(
    'custom',
    'bannedName',
    40,
    7,
    'A friendly ghost says hello.',
    ComposePath.picked,
  ),
  _Row(
    'custom',
    'bannedWithStreak',
    80,
    42,
    '5 days so far. The moon approves.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'all',
    80,
    0,
    'Wisp has counted 12 days and is still floating.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'all',
    80,
    7,
    'Wisp has counted 12 days and is still floating.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'all',
    80,
    42,
    'Wisp has counted 12 days and is still floating.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'all',
    80,
    4294967295,
    '12 days so far. Wisp is humming.',
    ComposePath.picked,
  ),
  _Row('ghost', 'all', 16, 42, 'Floating along.', ComposePath.picked),
  _Row(
    'ghost',
    'all',
    40,
    42,
    '12 days so far. Wisp is humming.',
    ComposePath.picked,
  ),
  _Row(
    'ghost',
    'all',
    200,
    42,
    'Wisp has counted 12 days and is still floating.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'all',
    80,
    0,
    'Crypt Keeper has been dead for 214 days. Not forever, though.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'all',
    80,
    1,
    '214 days of silence, and Crypt Keeper is still worth a séance.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'all',
    80,
    7,
    'Crypt Keeper has been dead for 214 days. Not forever, though.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'all',
    80,
    42,
    'Crypt Keeper has been dead for 214 days. Not forever, though.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'all',
    80,
    4294967295,
    '214 days of silence, and Crypt Keeper is still worth a séance.',
    ComposePath.picked,
  ),
  _Row('seance', 'all', 16, 42, 'Not quite gone.', ComposePath.picked),
  _Row(
    'seance',
    'all',
    40,
    42,
    'The spirits are still listening.',
    ComposePath.picked,
  ),
  _Row(
    'seance',
    'all',
    200,
    42,
    'Crypt Keeper has been dead for 214 days. Not forever, though.',
    ComposePath.picked,
  ),
  _Row(
    'custom',
    'all',
    80,
    0,
    '12 days so far. The moon approves.',
    ComposePath.picked,
  ),
  _Row(
    'custom',
    'all',
    80,
    1,
    '214 days on the clock. The fog is patient.',
    ComposePath.picked,
  ),
  _Row('custom', 'all', 80, 7, 'Wisp says hello.', ComposePath.picked),
  _Row('custom', 'all', 80, 42, 'Wisp says hello.', ComposePath.picked),
  _Row(
    'custom',
    'all',
    80,
    4294967295,
    '214 days on the clock. The fog is patient.',
    ComposePath.picked,
  ),
  _Row('custom', 'all', 40, 42, 'Wisp says hello.', ComposePath.picked),
  _Row('custom', 'all', 200, 42, 'Wisp says hello.', ComposePath.picked),
];

void main() {
  group('legacy baseline', () {
    test('the table has at least 40 rows and covers every input value', () {
      // The other four ComposePath values cannot be reached through the
      // public request API with the legacy catalog: maxLength is at least 16
      // and every set has a slot-free template of 15 characters or fewer, so
      // nothing is truncated, eligible is never empty, and cleaned names never
      // hold a banned word. Rows for them cannot be pinned without editing lib/.
      final Map<ComposePath, int> perPath = <ComposePath, int>{};
      for (final _Row r in _baseline) {
        perPath[r.path] = (perPath[r.path] ?? 0) + 1;
      }
      expect(perPath[ComposePath.picked], greaterThanOrEqualTo(2));
      expect(perPath.keys.toSet(), <ComposePath>{ComposePath.picked});
      expect(_baseline.length, greaterThanOrEqualTo(40));
      expect(
        _baseline.map((_Row r) => r.purpose).toSet(),
        unorderedEquals(_purposes.keys),
      );
      expect(
        _baseline.map((_Row r) => r.facts).toSet(),
        unorderedEquals(_facts.keys),
      );
      expect(_baseline.map((_Row r) => r.maxLength).toSet(), <int>{
        16,
        40,
        80,
        200,
      });
      expect(_baseline.map((_Row r) => r.seed).toSet(), <int>{
        0,
        1,
        7,
        42,
        4294967295,
      });
    });

    test('the frozen catalog engine gives every pinned text and path', () {
      for (final _Row row in _baseline) {
        final ComposedText got = frozenLegacyEngine.compose(row.request);
        expect(got.text, row.text, reason: '$row');
        expect(got.path, row.path, reason: '$row');
      }
    });

    test('OfflineEngine.standard gives every pinned text and path', () {
      for (final _Row row in _baseline) {
        final ComposedText got = OfflineEngine.standard.compose(row.request);
        expect(got.text, row.text, reason: '$row');
        expect(got.path, row.path, reason: '$row');
      }
    });
  });
}
