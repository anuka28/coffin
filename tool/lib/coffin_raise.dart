/// Public API surface for the Coffin app generator.
///
/// `tool/raise.dart` imports this barrel and never files under `src/`.
library;

export 'src/cli/exit_codes.dart' show ExitCodes;
export 'src/cli/raise_cli.dart' show RaiseCli;
export 'src/names/display_names.dart' show DisplayNames;
export 'src/names/name_issue.dart' show NameIssue;
export 'src/names/name_issue_kind.dart' show NameIssueKind;
export 'src/names/name_suggester.dart' show NameSuggester;
export 'src/names/name_validator.dart' show NameValidator;
export 'src/raise/raise_error_kind.dart' show RaiseErrorKind;
export 'src/raise/raise_result.dart'
    show RaiseFailure, RaiseResult, RaiseSuccess;
export 'src/raise/raiser.dart' show Raiser;
