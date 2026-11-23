import '../domain/calendar_date.dart';
import '../domain/grave_rejection.dart';
import '../domain/import_failure.dart';
import '../domain/import_failure_kind.dart';
import '../domain/rate_limit_wait.dart';
import '../domain/repo_parse_problem.dart';

/// Every user-facing string of Graveyard, in one place.
///
/// The tone is short, spooky and kind. No message shows an exception text, a
/// stack trace, an HTTP body or a raw status code, and none blames the user.
abstract final class GraveyardCopy {
  // ---------------------------------------------------------------- Import

  /// Message for a text the import parser rejected.
  static String parseProblem(RepoParseProblem problem) => switch (problem) {
    RepoParseProblem.notGitHub =>
      'Only GitHub addresses work here. Try owner/repo.',
    RepoParseProblem.needOwnerRepo =>
      'Type it as owner/repo, like flutter/flutter.',
    RepoParseProblem.invalidOwner || RepoParseProblem.invalidRepo =>
      "That doesn't look like a GitHub owner/repo. Check the spelling.",
  };

  /// Gentle message for an import failure.
  ///
  /// [now] is the moment the message is built. It only matters for a
  /// rate limit that carries a reset moment.
  static String importFailure(ImportFailure failure, {required DateTime now}) =>
      switch (failure.kind) {
        ImportFailureKind.notFoundOrPrivate =>
          "GitHub couldn't find that repository, or it's private. "
              "Without signing in, Graveyard can't tell which.",
        ImportFailureKind.rateLimited => _rateLimited(failure.resetAt, now),
        ImportFailureKind.offline =>
          "Graveyard can't reach the network right now. "
              'Check your connection and try again.',
        ImportFailureKind.timeout =>
          'GitHub took too long to answer. Give it another try.',
        ImportFailureKind.malformedResponse =>
          "Graveyard couldn't read GitHub's answer, or it has no last-push "
              'date. You can bury this project by hand instead.',
        ImportFailureKind.unexpectedStatus =>
          'GitHub answered in an unexpected way. Try again in a moment.',
      };

  static String _rateLimited(DateTime? resetAt, DateTime now) {
    if (resetAt == null) {
      return 'GitHub asked Graveyard to wait a while. '
          'Try again a little later.';
    }
    final n = RateLimitWait.minutes(resetAt: resetAt, now: now);
    return 'GitHub asked Graveyard to wait. '
        'Try again in about $n ${n == 1 ? 'minute' : 'minutes'}.';
  }

  /// Message shown when a grave already exists (import or by hand).
  static const String duplicate = 'This grave already exists.';

  // -------------------------------------------------------------- By hand

  /// Message for a by-hand rule rejection.
  static String rejection(GraveRejection reason) => switch (reason) {
    GraveRejection.nameEmpty => 'Every grave needs a name.',
    GraveRejection.nameTooLong =>
      'That name is too long. Keep it to 80 characters.',
    GraveRejection.dateMissing => 'Pick the day it last drew breath.',
    GraveRejection.dateNotReal =>
      "That day isn't on the calendar. Pick another.",
    GraveRejection.dateInFuture => "A project can't have died in the future.",
    GraveRejection.dateTooEarly => 'The graveyard starts on 1 Jan 1970.',
    GraveRejection.duplicate => duplicate,
  };

  // -------------------------------------------------------------- Storage

  /// Banner text when a write to storage throws.
  static const String saveError =
      "Couldn't tuck that into the crypt. Your graves are still here.";

  /// Text of the load error state.
  static const String loadError =
      "The graveyard won't open right now. Give it another try.";

  /// Memory fallback notice.
  static const String memoryNotice =
      "Graves can't be kept between visits here. "
      'They stay while this tab stays open.';

  // ---------------------------------------------------------------- Dates

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Date text with an English month name, such as `3 Jan 2023`.
  static String date(CalendarDate date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// The tombstone date line, such as `Died 3 Jan 2023`.
  static String dateLine(CalendarDate dateOfDeath) =>
      'Died ${date(dateOfDeath)}';

  /// The engraved epitaph, built from the Dead_For_Text.
  ///
  /// [deadForText] is `Died today`, `Dead for 3 weeks`, and so on.
  static String epitaph(String deadForText) => '$deadForText. Rest easy.';

  // ----------------------------------------------------------- Tombstones

  /// Line under a by-hand grave.
  static const String buriedByHand = 'Buried by hand.';

  /// Star count text, with the word "Archived" if needed.
  ///
  /// It has no star glyph. The tile shows an `Icons.star` next to it.
  static String stars(int count, {required bool archived}) =>
      '$count${archived ? ', Archived' : ''}';

  /// Semantic label of a by-hand tombstone.
  static String manualGraveLabel({
    required String name,
    required String deadForText,
  }) => '$name. $deadForText. Buried by hand.';

  /// Semantic label of a GitHub tombstone.
  static String githubGraveLabel({
    required String name,
    required String deadForText,
    required String fullName,
    required int stars,
    required bool archived,
    String? description,
  }) {
    final hasDescription = description != null && description.isNotEmpty;
    return '$name. $deadForText. From GitHub, $fullName, '
        '$stars ${stars == 1 ? 'star' : 'stars'}'
        '${archived ? ', archived' : ''}.'
        '${hasDescription ? ' Description: $description' : ''}';
  }

  /// Label of the delete button of one tombstone.
  static String deleteLabel(String name) => 'Delete $name';

  // --------------------------------------------------------------- Screen

  /// Caption of the loading ghost.
  static const String loadingCaption = 'Waking the graveyard…';

  /// Semantic label of the loading state.
  static const String loadingLabel = 'Loading graves';

  /// Label of the add button.
  static const String addButton = 'Bury a project';

  /// Title of the app bar or heading.
  static const String screenTitle = 'Graveyard';

  /// Label of every "try again" control.
  static const String tryAgain = 'Try again';

  // ---------------------------------------------------------- Empty state

  /// Heading of the empty state.
  static const String emptyTitle = 'Nothing is buried here yet';

  /// Invitation of the empty state, naming both ways.
  static const String emptyBody =
      'Lay an abandoned project to rest by hand, '
      'or dig one up from GitHub.';

  // ------------------------------------------------------------ Add sheet

  /// Title of the add sheet.
  static const String sheetTitle = 'Bury a project';

  /// Label of the by-hand option.
  static const String buryByHand = 'Bury by hand';

  /// Label of the import option.
  static const String importFromGitHub = 'Import from GitHub';

  /// Label of the close control of the sheet.
  static const String closeSheet = 'Close';

  /// Label of the name field.
  static const String nameLabel = 'Project name';

  /// Hint of the name field.
  static const String nameHint = 'My unfinished masterpiece';

  /// Label of the date field.
  static const String dateLabel = 'Last worked on';

  /// Hint of the date field.
  static const String dateHint = 'Pick the day';

  /// Label of the by-hand submit button.
  static const String buryButton = 'Bury it';

  /// Label of the import field.
  static const String repoLabel = 'GitHub repository';

  /// Hint of the import field.
  static const String repoHint = 'owner/repo or a github.com address';

  /// Label of the import submit button.
  static const String digUpButton = 'Dig it up';

  /// Caption of the ghost while an import runs.
  static const String importingCaption = 'Digging up the repository…';

  // -------------------------------------------------------------- Dialog

  /// Title of the delete dialog.
  static String deleteTitle(String name) => 'Delete $name?';

  /// Body of the delete dialog.
  static const String deleteBody = 'This grave will be gone for good.';

  /// Button that keeps the grave.
  static const String keepIt = 'Keep it';

  /// Button that deletes the grave.
  static const String delete = 'Delete';
}
