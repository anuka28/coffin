import 'package:flutter_test/flutter_test.dart';
import 'package:graveyard/src/domain/repo_input_parser.dart';
import 'package:graveyard/src/domain/repo_parse_problem.dart';
import 'package:graveyard/src/domain/repo_parse_result.dart';
import 'package:graveyard/src/domain/repo_ref.dart';

RepoParseResult ok(String owner, String repo) =>
    RepoParsed(RepoRef(owner, repo));
RepoParseResult bad(RepoParseProblem p) => RepoParseFailed(p);

void main() {
  test('accepts the four inputs of Requirement 3.8', () {
    expect(RepoInputParser.parse('flutter/flutter'), ok('flutter', 'flutter'));
    expect(
      RepoInputParser.parse('https://github.com/atom/atom'),
      ok('atom', 'atom'),
    );
    expect(
      RepoInputParser.parse('https://www.github.com/mojombo/grit.git'),
      ok('mojombo', 'grit'),
    );
    expect(
      RepoInputParser.parse(
        'http://github.com/octocat/Hello-World/tree/main?tab=readme#top',
      ),
      ok('octocat', 'Hello-World'),
    );
  });

  test('ignores whitespace, slashes, extra segments and keeps letter case', () {
    expect(
      RepoInputParser.parse('  GitHub.com/Octo/Cat/  '),
      ok('Octo', 'Cat'),
    );
    expect(RepoInputParser.parse('a/b/issues'), ok('a', 'b'));
    expect(RepoInputParser.parse('HTTPS://github.com/a/B.GIT'), ok('a', 'B'));
  });

  test('rejects other hosts and schemes', () {
    const notGitHub = RepoParseFailed(RepoParseProblem.notGitHub);
    expect(RepoInputParser.parse('example.com/a/b'), notGitHub);
    expect(RepoInputParser.parse('ftp://github.com/a/b'), notGitHub);
  });

  test('asks for owner/repo when parts are missing', () {
    const need = RepoParseFailed(RepoParseProblem.needOwnerRepo);
    expect(RepoInputParser.parse(''), need);
    expect(RepoInputParser.parse('   '), need);
    expect(RepoInputParser.parse('github.com'), need);
    expect(RepoInputParser.parse('flutter'), need);
    expect(RepoInputParser.parse('a/.git'), need);
  });

  test('strips .git suffix in any case, and rejects a bare .git repo', () {
    expect(RepoInputParser.parse('a/repo.git'), ok('a', 'repo'));
    expect(RepoInputParser.parse('a/repo.GIT'), ok('a', 'repo'));
    expect(
      RepoInputParser.parse('github.com/a/.git'),
      bad(RepoParseProblem.needOwnerRepo),
    );
    expect(
      RepoInputParser.parse('a/.GIT'),
      bad(RepoParseProblem.needOwnerRepo),
    );
  });

  test('accepts boundary lengths and other-host failures keep the kind', () {
    expect(
      RepoInputParser.parse('${'a' * 39}/${'b' * 100}'),
      ok('a' * 39, 'b' * 100),
    );
    expect(
      RepoInputParser.parse('https://example.com/a/b'),
      bad(RepoParseProblem.notGitHub),
    );
    expect(
      RepoInputParser.parse('https://github.com'),
      bad(RepoParseProblem.needOwnerRepo),
    );
  });

  test('rejects invalid owners and repos', () {
    expect(RepoInputParser.parse('-a/b'), bad(RepoParseProblem.invalidOwner));
    expect(
      RepoInputParser.parse('${'a' * 40}/b'),
      bad(RepoParseProblem.invalidOwner),
    );
    expect(RepoInputParser.parse('a/.'), bad(RepoParseProblem.invalidRepo));
    expect(RepoInputParser.parse('a/..'), bad(RepoParseProblem.invalidRepo));
    expect(
      RepoInputParser.parse('a/${'b' * 101}'),
      bad(RepoParseProblem.invalidRepo),
    );
    expect(RepoInputParser.parse('a/b%20c'), bad(RepoParseProblem.invalidRepo));
  });
}
