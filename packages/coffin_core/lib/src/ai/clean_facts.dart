import 'ai_fact_keys.dart';
import 'text_rules.dart';

/// The facts of a request after cleaning. A fact that is missing, has the
/// wrong type or fails its rule is `null`.
///
/// Only the four keys of [AiFactKeys] are read. Every other key is ignored,
/// so its value can never reach a reply.
final class CleanFacts {
  /// Creates facts from values that are already clean.
  const CleanFacts({
    this.streakCount,
    this.daysSinceLastCommit,
    this.ghostName,
    this.projectName,
  });

  /// Cleans the raw [facts] of a request.
  factory CleanFacts.from(Map<String, Object?> facts) {
    return CleanFacts(
      streakCount: _count(facts[AiFactKeys.streakCount]),
      daysSinceLastCommit: _count(facts[AiFactKeys.daysSinceLastCommit]),
      ghostName: _name(facts[AiFactKeys.ghostName]),
      projectName: _name(facts[AiFactKeys.projectName]),
    );
  }

  /// Days in a row a habit was kept, or `null` when missing.
  final int? streakCount;

  /// Days since the last commit, or `null` when missing.
  final int? daysSinceLastCommit;

  /// The cleaned ghost name. Never empty and never holds a banned word.
  final String? ghostName;

  /// The cleaned project name. Never empty and never holds a banned word.
  final String? projectName;

  /// The largest accepted count.
  static const int maxCount = 1000000;

  static int? _count(Object? value) {
    if (value is! num) return null;
    if (!value.isFinite) return null;
    if (value < 0 || value > maxCount) return null;
    if (value != value.truncateToDouble()) return null;
    // A zero of either sign is the plain integer 0 on every platform.
    if (value == 0) return 0;
    return value.toInt();
  }

  static String? _name(Object? value) {
    if (value is! String) return null;
    final cleaned = TextRules.cleanName(value);
    if (cleaned.isEmpty) return null;
    if (TextRules.containsBanned(cleaned)) return null;
    return cleaned;
  }
}
