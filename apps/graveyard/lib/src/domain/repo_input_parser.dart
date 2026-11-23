import 'repo_parse_problem.dart';
import 'repo_parse_result.dart';
import 'repo_ref.dart';

/// Turns the text a user typed into a [RepoRef] or a [RepoParseProblem].
abstract final class RepoInputParser {
  static final RegExp _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.-]*)://');

  /// Parses `owner/repo` or a GitHub address. Never throws and never decodes
  /// percent escapes. The letter case the user typed is kept.
  static RepoParseResult parse(String input) {
    var s = input.trim();
    final cut = s.indexOf(RegExp(r'[?#]'));
    if (cut >= 0) s = s.substring(0, cut);

    var hasScheme = false;
    final schemeMatch = _scheme.firstMatch(s);
    if (schemeMatch != null) {
      final scheme = schemeMatch.group(1)!.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        return const RepoParseFailed(RepoParseProblem.notGitHub);
      }
      hasScheme = true;
      s = s.substring(schemeMatch.end);
    }

    final segments = s.split('/').where((p) => p.isNotEmpty).toList();

    if (segments.isNotEmpty && (hasScheme || segments.first.contains('.'))) {
      final host = segments.first.toLowerCase();
      if (host != 'github.com' && host != 'www.github.com') {
        return const RepoParseFailed(RepoParseProblem.notGitHub);
      }
      segments.removeAt(0);
    }

    if (segments.length < 2) {
      return const RepoParseFailed(RepoParseProblem.needOwnerRepo);
    }

    final owner = segments[0];
    var repo = segments[1];
    if (repo.toLowerCase().endsWith('.git')) {
      repo = repo.substring(0, repo.length - 4);
      if (repo.isEmpty) {
        return const RepoParseFailed(RepoParseProblem.needOwnerRepo);
      }
    }

    if (!RepoRef.isValidOwner(owner)) {
      return const RepoParseFailed(RepoParseProblem.invalidOwner);
    }
    if (!RepoRef.isValidRepo(repo)) {
      return const RepoParseFailed(RepoParseProblem.invalidRepo);
    }
    return RepoParsed(RepoRef(owner, repo));
  }
}
