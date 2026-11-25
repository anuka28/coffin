import '../domain/calendar_date.dart';
import '../domain/grave_rejection.dart';
import '../domain/import_failure.dart';
import '../domain/import_failure_kind.dart';
import '../domain/rate_limit_wait.dart';
import '../domain/repo_parse_problem.dart';
import '../domain/scene/description_cleaner.dart';
import '../domain/scene/thousands_formatter.dart';
import '../domain/seance/revival_band.dart';
import '../domain/seance/revival_step_kind.dart';

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

  /// The engraved epitaph, the same on every tombstone.
  static const String epitaph = 'R.I.P.';

  // ----------------------------------------------------------- Tombstones

  /// Line under a by-hand grave.
  static const String buriedByHand = 'Buried by hand.';

  /// Star count text, with the word "Archived" if needed.
  ///
  /// It has no star glyph. The tile shows an `Icons.star` next to it.
  static String stars(int count, {required bool archived}) =>
      '${ThousandsFormatter.format(count)}${archived ? ', Archived' : ''}';

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
    final cleaned = description == null
        ? ''
        : DescriptionCleaner.clean(description);
    return '$name. $deadForText. From GitHub, $fullName, '
        '${ThousandsFormatter.format(stars)} '
        "${stars == 1 ? 'star' : 'stars'}"
        '${archived ? ', archived' : ''}.'
        '${cleaned.isNotEmpty ? ' Description: $cleaned' : ''}';
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

  // --------------------------------------------------------------- Séance

  /// Visible text of the séance control on a tombstone.
  static const String seanceControlText = 'Hold a séance';

  /// Semantic label of the séance control of one tombstone.
  static String seanceControlLabel(String name) => 'Hold a séance for $name';

  /// Word shown next to the revival score for one band.
  static String revivalBandLabel(RevivalBand band) => switch (band) {
    RevivalBand.restless => 'Restless',
    RevivalBand.stirring => 'Stirring',
    RevivalBand.readyToRise => 'Ready to rise',
  };

  /// Semantic label of the revival score and its band.
  static String revivalScoreLabel(int score, RevivalBand band) =>
      'Revival score $score out of 100, ${revivalBandLabel(band)}';

  /// Semantic label of one revival step, such as `Step 1 of 3: ...`.
  static String revivalStepLabel(int k, int total, String text) =>
      'Step $k of $total: $text';

  /// Route name of the séance sheet for one grave.
  static String seanceRouteName(String name) => 'Séance for $name';

  /// Label of the close control of the séance sheet.
  static const String closeSeanceLabel = 'Close séance';

  /// Caption of the ghost while the verdict is pending.
  static const String seanceThinkingCaption = 'The spirits are murmuring…';

  /// Verdict shown when no verdict line is available. It fits every grave.
  static const String safeVerdictLine =
      'The spirits are quiet, but every project can rise again.';

  /// Revival step: fork the repository first.
  static const String stepForkRepository =
      'Fork the repository before you touch anything';

  /// Revival step: write down the purpose.
  static const String stepWriteDownPurpose =
      'Write down what the project was meant to do';

  /// Revival step: update dependencies.
  static const String stepUpdateDependencies =
      'Update dependencies before writing new code';

  /// Revival step: skim the README.
  static const String stepSkimReadme =
      'Open the repository and skim the README';

  /// Revival step: fix one small thing.
  static const String stepFixOneThing =
      'Pick one small bug or TODO to fix first';

  /// Revival step: ask a friend.
  static const String stepAskAFriend = 'Ping a friend to co-revive it with you';

  /// Revival step: add one test.
  static const String stepAddOneTest = 'Add one test before changing any code';

  /// The text of one revival step kind.
  static String revivalStepText(RevivalStepKind kind) => switch (kind) {
    RevivalStepKind.forkRepository => stepForkRepository,
    RevivalStepKind.writeDownPurpose => stepWriteDownPurpose,
    RevivalStepKind.updateDependencies => stepUpdateDependencies,
    RevivalStepKind.skimReadme => stepSkimReadme,
    RevivalStepKind.fixOneThing => stepFixOneThing,
    RevivalStepKind.askAFriend => stepAskAFriend,
    RevivalStepKind.addOneTest => stepAddOneTest,
  };

  // ---------------------------------------------------------- Resurrection

  /// Visible text of the Raise control in the séance sheet.
  static const String raiseControlText = 'Raise it';

  /// Semantic label of the Raise control for one grave.
  static String raiseControlLabel(String name) => 'Raise $name from the dead';

  /// The epitaph engraved on a risen tombstone.
  static const String epitaphRisen = 'RISEN';

  /// Heading of the row of risen projects.
  static const String livingRowHeading = 'Back among the living';

  /// The "Risen on" line of one living entry.
  static String risenOnLine(CalendarDate risenOn) =>
      'Risen on ${date(risenOn)}';

  /// Visible text of the Lay to rest control.
  static const String layToRestText = 'Lay it back to rest';

  /// Semantic label of the Lay to rest control for one grave.
  static String layToRestLabel(String name) => 'Lay $name back to rest';

  /// Route name of the rest dialog for one grave.
  static String restDialogRouteName(String name) => 'Lay $name back to rest?';

  /// Title of the rest dialog.
  static String restDialogTitle(String name) => 'Lay $name back to rest?';

  /// Body of the rest dialog. It says nothing is deleted.
  static String restDialogBody(String name) =>
      '$name goes back to the graveyard. You can raise it again any time.';

  /// Button that confirms laying a grave back to rest.
  static const String restConfirmText = 'Lay it to rest';

  /// Button that keeps a grave risen.
  static const String restCancelText = 'Keep it risen';

  /// Semantic label of the repository link of one living entry.
  static String repositoryLinkLabel(String name) =>
      'Copy the repository link of $name';

  /// Confirmation after a repository link was copied.
  static const String linkCopied = 'Link copied';

  /// Message when a repository link could not be copied.
  static const String linkCopyFailed =
      'That link would not copy. Try once more.';

  /// Line shown when every grave has risen.
  static const String allRisen = 'Every grave here has risen.';

  /// Live-region announcement for a risen project.
  static String risenAnnouncement(String name) => '$name has risen.';
}
