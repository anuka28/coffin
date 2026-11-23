import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/import_failure.dart';
import 'package:graveyard/src/domain/import_failure_kind.dart';
import 'package:graveyard/src/domain/repo_parse_problem.dart';
import 'package:graveyard/src/domain/repo_ref.dart';
import 'package:graveyard/src/ui/import_state.dart';

String describe(ImportState state) => switch (state) {
  ImportIdle() => 'idle',
  ImportRunning() => 'running',
  ImportInputRejected() => 'rejected',
  ImportFetchFailed() => 'failed',
  ImportDuplicateFound() => 'duplicate',
  ImportSucceeded() => 'succeeded',
};

void main() {
  const failure = ImportFailure(ImportFailureKind.offline);

  /// Each entry holds two equal instances and one different instance.
  final cases = <String, (ImportState, ImportState, ImportState)>{
    'ImportIdle': (
      const ImportIdle(),
      const ImportIdle(),
      const ImportRunning(RepoRef('a', 'b')),
    ),
    'ImportRunning': (
      const ImportRunning(RepoRef('a', 'b')),
      const ImportRunning(RepoRef('a', 'b')),
      const ImportRunning(RepoRef('a', 'c')),
    ),
    'ImportInputRejected': (
      const ImportInputRejected(RepoParseProblem.notGitHub),
      const ImportInputRejected(RepoParseProblem.notGitHub),
      const ImportInputRejected(RepoParseProblem.invalidRepo),
    ),
    'ImportFetchFailed': (
      const ImportFetchFailed(failure),
      const ImportFetchFailed(ImportFailure(ImportFailureKind.offline)),
      const ImportFetchFailed(ImportFailure(ImportFailureKind.timeout)),
    ),
    'ImportDuplicateFound': (
      const ImportDuplicateFound('a/b'),
      const ImportDuplicateFound('a/b'),
      const ImportDuplicateFound('a/c'),
    ),
    'ImportSucceeded': (
      const ImportSucceeded('g1'),
      const ImportSucceeded('g1'),
      const ImportSucceeded('g2'),
    ),
  };

  for (final entry in cases.entries) {
    group(entry.key, () {
      final (a, b, other) = entry.value;

      test('equal values are equal with the same hashCode', () {
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('different values are not equal', () {
        expect(a == other, isFalse);
      });
    });
  }

  test('different subclasses are never equal', () {
    final all = [for (final c in cases.values) c.$1];
    for (var i = 0; i < all.length; i++) {
      for (var j = 0; j < all.length; j++) {
        if (i != j) expect(all[i] == all[j], isFalse);
      }
    }
  });

  test('exhaustive switch maps each subclass to its own label', () {
    final labels = [for (final c in cases.values) describe(c.$1)];
    expect(labels, [
      'idle',
      'running',
      'rejected',
      'failed',
      'duplicate',
      'succeeded',
    ]);
  });
}
