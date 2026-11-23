import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/repo_ref.dart';

void main() {
  group('RepoRef.isValidOwner', () {
    test('accepts letters, digits and single hyphens', () {
      expect(RepoRef.isValidOwner('flutter'), isTrue);
      expect(RepoRef.isValidOwner('a-b-1'), isTrue);
      expect(RepoRef.isValidOwner('a' * 39), isTrue);
    });

    test('rejects bad hyphens, length and characters', () {
      expect(RepoRef.isValidOwner(''), isFalse);
      expect(RepoRef.isValidOwner('-a'), isFalse);
      expect(RepoRef.isValidOwner('a-'), isFalse);
      expect(RepoRef.isValidOwner('a--b'), isFalse);
      expect(RepoRef.isValidOwner('a' * 40), isFalse);
      expect(RepoRef.isValidOwner('a.b'), isFalse);
      expect(RepoRef.isValidOwner('a b'), isFalse);
    });
  });

  group('RepoRef.isValidRepo', () {
    test('accepts the allowed characters', () {
      expect(RepoRef.isValidRepo('Hello-World'), isTrue);
      expect(RepoRef.isValidRepo('a_b.c'), isTrue);
      expect(RepoRef.isValidRepo('a' * 100), isTrue);
    });

    test('rejects dots, .git in any case, length and characters', () {
      expect(RepoRef.isValidRepo(''), isFalse);
      expect(RepoRef.isValidRepo('.'), isFalse);
      expect(RepoRef.isValidRepo('..'), isFalse);
      expect(RepoRef.isValidRepo('repo.git'), isFalse);
      expect(RepoRef.isValidRepo('repo.GIT'), isFalse);
      expect(RepoRef.isValidRepo('.git'), isFalse);
      expect(RepoRef.isValidRepo('a' * 101), isFalse);
      expect(RepoRef.isValidRepo('a/b'), isFalse);
    });
  });

  test('toString is owner/repo and equality is by value', () {
    expect(const RepoRef('atom', 'atom').toString(), 'atom/atom');
    expect(const RepoRef('a', 'b'), const RepoRef('a', 'b'));
    expect(const RepoRef('a', 'b').hashCode, const RepoRef('a', 'b').hashCode);
    expect(const RepoRef('a', 'b'), isNot(const RepoRef('A', 'b')));
  });
}
