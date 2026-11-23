# Requirements Document

## Introduction

The graveyard-core feature builds the core loop of Graveyard in `apps/graveyard`: abandoned side projects become tombstones, each showing the project name and its date of death. The user adds a grave in one of two ways: by hand (a project name and the date it was last worked on), or by importing a public GitHub repository, whose last push date becomes the date of death. Everything happens on one screen at `/`. The animated graveyard scene, the AI séance, and the resurrection belong to later specs and are not built here (see Out of Scope).

The rules live in pure Dart in `lib/src/domain` (no Flutter imports, no `dart:io`, no network). Dates are calendar dates. A date of death taken from GitHub is the local calendar date of `pushed_at`, converted through an injectable time-zone conversion. Today comes from an injected clock, and "dead for N days" uses calendar-day math on year, month and day values, never a `Duration`. GitHub access uses the public REST API without a token, behind an interface so that tests never touch the network. Graves are saved through `coffin_core`'s `StorageOpener` and `RecordRepository` with a `RecordCodec`, `currentVersion` 1. The design language is "Haunted, not horror", as defined in the design steering document.

Concrete numbers that are not stated here (visual sizes, exact copy strings, field layout) belong to the design phase. Numbers that affect behavior or tests (name length, date bounds, timeout, duration thresholds) are stated here.

## Dependency Notice

One approved dependency change:

- **HTTP.** Dart's official `http` package is added to `apps/graveyard/pubspec.yaml` under `dependencies`, pinned to one exact version with no caret and no range. The version is chosen at implementation time as the latest stable release that supports the project's Dart SDK, and recorded in the design. The root `pubspec.lock` changes only by the packages that this one dependency brings in. The implementation report must list exactly which packages the lock gained (the root lock already holds `http_parser`, `web` and `async`, so `http` itself is expected to be the only addition), and must show that no other line of the lock changed.
- **Property tests.** `glados` is added as one line under `dev_dependencies` of `apps/graveyard/pubspec.yaml`, pinned to `1.1.7` (the version `coffin_core` and Hauntagotchi use). It is already in the root `pubspec.lock`, so it adds no lock change.
- **Credits.** `CREDITS.md` gains exactly one entry for `http` (author, license, source link), in the existing entry style.
- **No secrets.** No API key, token or secret appears in the app, the tests or the repository.

State management is Flutter's `ChangeNotifier` with `ListenableBuilder`. No state-management package is added.

## Real API data observed

The following public repositories were read through the GitHub tooling on 2026-11-23. They ground the parser and the copy. The tooling shows a curated subset of the REST response. In the raw REST JSON, `description` can be `null`, and other fields can be missing.

| Repository | `pushed_at` | `archived` | `stargazers_count` | `description` |
| --- | --- | --- | --- | --- |
| flutter/flutter | 2026-11-23T00:29:13Z | false | 181478 | "Flutter makes it easy and fast to build beautiful apps for mobile and beyond" |
| atom/atom | 2023-01-03T10:49:48Z | true | 60681 | ":atom: The hackable text editor" |
| mojombo/grit | 2023-08-17T19:15:41Z | false | 2046 | "**Grit is no longer maintained. Check out libgit2/rugged.** ..." (long) |
| octocat/Hello-World | 2024-08-20T23:54:42Z | false | 4037 | "My first repository on GitHub!" |

What these rows mean for the requirements:

- `pushed_at` is an ISO-8601 UTC timestamp that ends in `Z`. The Date_Of_Death is the local calendar date of that instant (UTC converted to local time, then year, month and day), because Today also comes from the local clock. Mixing a UTC date with a local Today gives off-by-one results: in India (+05:30), a push at 01:00 local time is still the previous day in UTC, so a just-pushed repository would read "Dead for 1 day" instead of "Died today".
- `flutter/flutter` was pushed on the day of observation, so a fresh import, read in a zone where that instant falls on the local Today, gives "dead for 0 days". The wording for that case is natural ("Died today"), never "0 days".
- `updated_at` is a different field with a different meaning. For `atom/atom` it was recent although the last push was in 2023. The importer uses `pushed_at` and never `updated_at`.
- `atom/atom` is archived. `mojombo/grit` has been abandoned for years but is not archived, so the archived flag is a hint to show, not a condition for burial.
- Descriptions are arbitrary text. `:atom:` is an emoji shortcode and `**...**` is Markdown. Both are shown as plain text and never interpreted as markup. The `mojombo/grit` description is long, so it needs truncation with an ellipsis and the full text stays available to screen readers.
- Private repositories and missing repositories both return HTTP 404 without authentication, so the app cannot tell them apart.
- Unauthenticated requests are limited to 60 per hour. The limit answers with HTTP 403 or 429, with `x-ratelimit-remaining: 0` or a `Retry-After` header, and `x-ratelimit-reset` holds the reset time as Unix seconds.
- `api.github.com` allows cross-origin GET requests from a browser, so Flutter Web works without a proxy.

## Glossary

- **Graveyard_App**: The Flutter app in `apps/graveyard`.
- **Domain**: The pure Dart code in `apps/graveyard/lib/src/domain`. It imports no Flutter library, no `dart:io`, no `dart:html`, and no networking package.
- **Data_Layer**: The code in `apps/graveyard/lib/src/data`: the grave repository, its codec, and the GitHub client.
- **Graveyard_Screen**: The one screen of this feature, shown at route `/`, replacing `PlaceholderScreen`.
- **Clock**: The injected source of time, a Domain interface with one method that returns the current local `DateTime`. Neither the Domain nor the Data_Layer calls `DateTime.now()` outside the production Clock implementation.
- **Calendar_Date**: A date as a year, month and day value with no time of day and no time zone.
- **Today**: The Calendar_Date taken from the local year, month and day of the Clock. Every Domain function that needs Today receives it as a parameter.
- **Date_Of_Death**: The Calendar_Date on which a project was last worked on. For an imported repository, it is the local calendar date of `pushed_at`.
- **Zone_Converter**: A function that converts a parsed UTC instant (`DateTime`) to a `DateTime` in the target time zone. The production default is the device's local zone (`toLocal()`). Tests inject a converter that applies a fixed UTC offset, so that no test depends on the time zone of the machine.
- **Local_Calendar_Date**: The year, month and day of an instant after the Zone_Converter has been applied.
- **Earliest_Date**: 1970-01-01, the earliest accepted Date_Of_Death.
- **Day_Count**: The number of calendar days from one Calendar_Date to another, computed on year, month and day values and never by dividing a `Duration` by 24 hours.
- **Dead_For_Text**: The natural-words phrase for the time between a Date_Of_Death and Today, produced by the Dead_For_Formatter.
- **Dead_For_Formatter**: The pure function that turns a Date_Of_Death and Today into a Dead_For_Text.
- **Grave**: One tombstone. It has an id, a Project_Name, a Date_Of_Death, a source (Manual or GitHub), and for a GitHub source the Repo_Info.
- **Project_Name**: The display name of a Grave, 1 to 80 characters after Name_Normalisation.
- **Name_Normalisation**: Trimming leading and trailing whitespace and collapsing every run of whitespace inside the text to one space.
- **Repo_Ref**: A parsed GitHub repository reference with an owner and a repo name.
- **Owner_Name**: A GitHub account name: 1 to 39 characters, ASCII letters and digits and single hyphens, not starting or ending with a hyphen.
- **Repo_Name**: A GitHub repository name: 1 to 100 characters, ASCII letters and digits, `-`, `_` and `.`, and not equal to `.` or `..`.
- **Repo_Input_Parser**: The pure function that turns the text the user typed into a Repo_Ref or a parse failure.
- **Repo_Info**: The data kept for an imported Grave: `full_name`, an optional `html_url`, the description (nullable), the archived flag, and the star count.
- **Repo_Response_Parser**: The pure function that turns a GitHub JSON response body into a Repo_Info and a Date_Of_Death, or a failure.
- **GitHub_Client**: The interface in the Data_Layer with one method that fetches a Repo_Ref and returns either a fetched repository or a typed failure. The production implementation uses the `http` package.
- **Import_Failure**: One of `notFoundOrPrivate`, `rateLimited`, `offline`, `timeout`, `malformedResponse`, `unexpectedStatus`.
- **Request_Timeout**: 10 seconds.
- **Grave_Repository**: The `RecordRepository<Grave>` that stores Graves, keyed by Grave id.
- **Grave_Codec**: The `RecordCodec<Grave>` implementation.
- **Memory_Fallback**: The state in which `StorageOpener` returns a repository whose `isPersistent` is false.
- **Memory_Notice**: The gentle message on the Graveyard_Screen that graves will not be saved during a Memory_Fallback.
- **Graveyard_Controller**: The `ChangeNotifier` that owns the list of Graves, the Clock, the Grave_Repository and the GitHub_Client, and exposes them to the Graveyard_Screen.
- **Add_Sheet**: The modal sheet or dialog on the Graveyard_Screen that holds the two add options (by hand and from GitHub).
- **Import_Attempt**: One request to the GitHub_Client started from the Add_Sheet.
- **Fake_Clock**: A test Clock whose time the test sets.
- **Fake_GitHub_Client**: A test GitHub_Client whose results the test sets. It makes no network call.
- **Web_Safe_Generator**: A glados generator that avoids `any.intInRange` and `any.listWithLengthInRange`, which throw on Flutter Web in glados 1.1.7. It keeps every generated integer below 2^53.

## Requirements

### Requirement 1: Calendar dates and the injected clock

**User Story:** As a user, I want days counted by my own calendar, so that "dead for N days" never skips or repeats a day because of daylight saving time or the hour I open the app.

#### Acceptance Criteria

1. THE Domain SHALL obtain every time value from the Clock and SHALL NOT call `DateTime.now()`, except inside the production Clock implementation.
2. THE Domain SHALL derive Today from the year, month and day of the local `DateTime` that the Clock returns.
3. THE Domain SHALL compute the Day_Count between two Calendar_Dates on year, month and day values, and SHALL NOT add or divide a fixed 24-hour duration.
4. FOR ALL Calendar_Dates that span a daylight saving change, THE Domain SHALL count N consecutive calendar days as a Day_Count of N.
5. FOR ALL pairs of times on the same local calendar day, THE Domain SHALL produce the same Today, and therefore the same Dead_For_Text for any Grave.
6. FOR ALL Calendar_Dates, THE Calendar_Date encoding (`YYYY-MM-DD`) SHALL decode to an equal Calendar_Date (round-trip property).
7. THE Graveyard_App SHALL provide one production Clock that returns the current local time, and SHALL inject a Fake_Clock in every test that needs Today.

### Requirement 2: Grave model and manual rules

**User Story:** As a developer with a pile of unfinished projects, I want to bury a project by typing its name and the date I last worked on it, so that I can add graves that are not on GitHub.

#### Acceptance Criteria

1. WHEN the user submits a manual grave with a valid Project_Name and a valid Date_Of_Death, THE Graveyard_Controller SHALL add a Grave with a unique id, the normalised Project_Name, the Date_Of_Death, and the source Manual.
2. IF a Project_Name is empty after Name_Normalisation, THEN THE Domain SHALL reject the grave with a reason that says a name is needed.
3. IF a Project_Name is longer than 80 characters after Name_Normalisation, THEN THE Domain SHALL reject the grave with a reason that says the name is too long.
4. IF no Date_Of_Death is given, THEN THE Domain SHALL reject the grave with a reason that says a date is needed.
5. IF a Date_Of_Death is after Today, THEN THE Domain SHALL reject the grave with a reason that says the project cannot have died in the future.
6. IF a Date_Of_Death is before the Earliest_Date, THEN THE Domain SHALL reject the grave with a reason that gives the Earliest_Date.
7. IF a Date_Of_Death is not a real calendar date (for example 2025-02-30), THEN THE Domain SHALL reject the grave and SHALL NOT shift the date to another day.
8. WHEN a Date_Of_Death equals Today, THE Domain SHALL accept the grave.
9. WHEN a Date_Of_Death equals the Earliest_Date, THE Domain SHALL accept the grave.
10. WHEN a grave is rejected, THE Graveyard_Controller SHALL leave the list of Graves unchanged.
11. THE Domain SHALL treat the Project_Name as plain text and SHALL NOT interpret it as markup.
12. FOR ALL Project_Names, Name_Normalisation applied twice SHALL give the same result as applied once (idempotence).

### Requirement 3: Parsing owner/repo and GitHub URLs

**User Story:** As a user, I want to type `owner/repo` or paste a GitHub address in whatever shape I copied it, so that importing is forgiving.

#### Acceptance Criteria

1. WHEN the input is `owner/repo`, THE Repo_Input_Parser SHALL return a Repo_Ref with that Owner_Name and Repo_Name.
2. WHEN the input is a URL whose host is `github.com` or `www.github.com`, with the scheme `https` or `http` or with no scheme, THE Repo_Input_Parser SHALL return a Repo_Ref from the first two path segments.
3. WHEN the input has leading or trailing whitespace, a trailing slash, a `.git` suffix on the repo segment, extra path segments (such as `/tree/main` or `/issues`), a query string, or a fragment, THE Repo_Input_Parser SHALL ignore those parts and return the same Repo_Ref as for the plain `owner/repo` input.
4. IF the host is not `github.com` or `www.github.com`, THEN THE Repo_Input_Parser SHALL return a parse failure that says only GitHub addresses are supported.
5. IF the owner or the repo is empty, or the input has fewer than two path segments, THEN THE Repo_Input_Parser SHALL return a parse failure that asks for `owner/repo`.
6. IF the owner is not a valid Owner_Name, or the repo is not a valid Repo_Name, THEN THE Repo_Input_Parser SHALL return a parse failure.
7. IF the repo segment is `.` or `..`, THEN THE Repo_Input_Parser SHALL return a parse failure.
8. THE Repo_Input_Parser SHALL accept the inputs `flutter/flutter`, `https://github.com/atom/atom`, `https://www.github.com/mojombo/grit.git`, and `http://github.com/octocat/Hello-World/tree/main?tab=readme#top`.
9. THE Repo_Input_Parser SHALL keep the letter case that the user typed in the Repo_Ref.
10. THE Repo_Input_Parser SHALL be a pure function that never throws, whatever text it receives.
11. FOR ALL valid Owner_Names and Repo_Names, formatting a Repo_Ref as `owner/repo` and parsing it again SHALL return an equal Repo_Ref (round-trip property).
12. FOR ALL valid Repo_Refs, parsing `https://github.com/owner/repo` with any combination of the optional parts of criterion 3 SHALL return an equal Repo_Ref.

### Requirement 4: Parsing the GitHub response

**User Story:** As a user, I want an import to work with what GitHub really returns, so that real repositories become graves without surprises.

#### Acceptance Criteria

1. WHEN the response body is a JSON object with a `pushed_at` string that is an ISO-8601 UTC timestamp, THE Repo_Response_Parser SHALL parse it with `DateTime.parse`, apply the Zone_Converter to the parsed instant, and derive the Date_Of_Death from the year, month and day of the converted value (the Local_Calendar_Date).
2. THE Repo_Response_Parser SHALL NOT read `updated_at` or `created_at` to derive the Date_Of_Death.
3. THE Repo_Response_Parser SHALL accept the Zone_Converter as an injectable parameter that defaults to the device's local zone (`toLocal()`), so that the Date_Of_Death and Today are both read on the local calendar and the Day_Count has no off-by-one error near midnight.
4. WHEN the body holds `full_name`, THE Repo_Response_Parser SHALL keep it as the canonical name of the Repo_Info.
5. IF `full_name` is missing or is not a string, THEN THE Repo_Response_Parser SHALL use the owner/repo of the requested Repo_Ref as the canonical name.
6. IF `description` is null, missing, or not a string, THEN THE Repo_Response_Parser SHALL set the description of the Repo_Info to no value.
7. IF `archived` is missing or is not a boolean, THEN THE Repo_Response_Parser SHALL set the archived flag to false.
8. IF `stargazers_count` is missing, is not an integer, or is negative, THEN THE Repo_Response_Parser SHALL set the star count to 0.
9. WHEN the body holds an `html_url` string, THE Repo_Response_Parser SHALL keep it, and SHALL leave it empty otherwise.
10. IF `pushed_at` is null, missing, not a string, or not a parseable ISO-8601 timestamp, THEN THE Repo_Response_Parser SHALL return the failure `malformedResponse`, because no Date_Of_Death can be derived.
11. IF the body is not valid JSON or is not a JSON object, THEN THE Repo_Response_Parser SHALL return the failure `malformedResponse`.
12. IF the Local_Calendar_Date of `pushed_at` is after Today (clock skew), THEN THE Domain SHALL use Today as the Date_Of_Death.
13. IF the Local_Calendar_Date of `pushed_at` is before the Earliest_Date, THEN THE Domain SHALL use the Earliest_Date as the Date_Of_Death.
14. THE Repo_Response_Parser SHALL ignore every field it does not know.
15. THE Repo_Response_Parser SHALL be a pure function that never throws, whatever text it receives.
16. THE unit tests SHALL feed the Repo_Response_Parser the four repositories of the "Real API data observed" section, with a Zone_Converter of fixed offset +00:00, and SHALL expect the Date_Of_Death 2026-11-23 for `flutter/flutter`, 2023-01-03 for `atom/atom`, 2023-08-17 for `mojombo/grit`, and 2024-08-20 for `octocat/Hello-World`, with the archived flag and star counts of that section.
17. WHERE a Zone_Converter with a fixed UTC offset is injected, THE Repo_Response_Parser SHALL add that offset to the parsed instant, and SHALL derive the Date_Of_Death from the year, month and day of the result, without reading the time zone of the machine.
18. WHEN `pushed_at` is `2026-11-22T19:30:00Z` and the fixed offset is +05:30, THE Repo_Response_Parser SHALL derive the local time 2026-11-23 01:00 and the Date_Of_Death 2026-11-23, and WHEN Today is 2026-11-23, THE Dead_For_Formatter SHALL return "Died today" and SHALL NOT return "Dead for 1 day".
19. WHEN `pushed_at` is `2026-11-23T03:00:00Z` and the fixed offset is -05:00, THE Repo_Response_Parser SHALL derive the local time 2026-11-22 22:00 and the Date_Of_Death 2026-11-22, and WHEN Today is 2026-11-22 on the same offset, THE Dead_For_Formatter SHALL return "Died today".
20. WHEN `pushed_at` is `2026-11-23T10:00:00Z` and the fixed offset is +05:30, THE Repo_Response_Parser SHALL derive the local time 2026-11-23 15:30 and the Date_Of_Death 2026-11-23, the same date as the UTC date, because the offset does not cross midnight.
21. THE unit tests SHALL cover the three cases of criteria 18, 19 and 20 with a fixed-offset Zone_Converter, and these tests are mandatory.
22. THE property tests SHALL cover, FOR ALL instants and FOR ALL fixed whole-hour or half-hour offsets from -12:00 to +14:00 inclusive, that the derived Date_Of_Death (before clamping) equals the calendar date of the instant plus the offset, and that a push made at the instant "now" with Today computed from the same instant and the same offset always yields a Day_Count of 0 and the text "Died today".

### Requirement 5: Dead-for text

**User Story:** As a user, I want to read how long a project has been dead in plain words, so that the tombstone says something I understand at a glance.

#### Acceptance Criteria

1. WHEN the Day_Count is 0, THE Dead_For_Formatter SHALL return the text "Died today".
2. WHEN the Day_Count is 1, THE Dead_For_Formatter SHALL return the text "Dead for 1 day".
3. WHEN the Day_Count is 2 to 6, THE Dead_For_Formatter SHALL return "Dead for N days".
4. WHEN the Day_Count is 7 or more and fewer than 1 whole calendar month has passed, THE Dead_For_Formatter SHALL return "Dead for W weeks" with W as the Day_Count divided by 7, rounded down, and SHALL use the singular "1 week" when W is 1.
5. WHEN 1 to 11 whole calendar months have passed, THE Dead_For_Formatter SHALL return "Dead for M months" with the singular "1 month" when M is 1.
6. WHEN 12 or more whole calendar months have passed, THE Dead_For_Formatter SHALL return "Dead for Y years" with Y as the whole months divided by 12, rounded down, and the singular "1 year" when Y is 1.
7. THE Dead_For_Formatter SHALL count whole calendar months on year, month and day values: a month is whole when Today's day of month is at least the Date_Of_Death's day of month, or when Today is the last day of its month and the Date_Of_Death's day of month is greater than the length of that month.
8. THE Dead_For_Formatter SHALL never output the text "0 days", "1 days", "1 weeks", "1 months", "1 years", or a negative number.
9. IF the Date_Of_Death is after Today, THEN THE Dead_For_Formatter SHALL return the text "Died today".
10. THE Dead_For_Formatter SHALL be a pure function of the Date_Of_Death and Today, SHALL compute every Day_Count and month count with year, month and day arithmetic on Calendar_Dates, and SHALL NOT use a `Duration`.
11. FOR ALL pairs of Calendar_Dates, THE Dead_For_Formatter SHALL return a text that is not empty and that is the same for repeated calls with the same arguments.
12. FOR ALL Date_Of_Death values, THE Dead_For_Formatter SHALL return a text for Today plus one day that is never "younger" than the text for Today, in the order days, weeks, months, years, and with a number that does not decrease within one unit (monotonic property).
13. THE unit tests SHALL cover the Day_Counts 0, 1, 2, 6, 7, 13, 14, the end of February in a leap year and in a common year, the month-end clamp of criterion 7, the day before and the day of the first whole month, the day before and the day of the first whole year, and a span across a daylight saving change.

### Requirement 6: Sorting and duplicates

**User Story:** As a user, I want the newest death at the top and no accidental double burials, so that the list stays tidy.

#### Acceptance Criteria

1. THE Domain SHALL sort Graves with the most recent Date_Of_Death first.
2. WHEN two Graves have the same Date_Of_Death, THE Domain SHALL order them by Project_Name compared case-insensitively, and then by id as plain string comparison.
3. THE sort SHALL be a pure function that returns a new list and SHALL NOT modify its input.
4. FOR ALL lists of Graves, sorting twice SHALL give the same result as sorting once (idempotence).
5. FOR ALL lists of Graves, THE sort SHALL return a permutation of the input (same length, same elements).
6. FOR ALL lists of Graves with distinct ids, THE sort SHALL give the same result for every input order (confluence).
7. FOR ALL adjacent Graves in a sorted list, the Date_Of_Death of the first SHALL NOT be before the Date_Of_Death of the second (invariant).
8. WHEN the user imports a repository whose canonical name equals, case-insensitively, the `full_name` of a Grave already in the list, THE Domain SHALL report a duplicate and THE Graveyard_Controller SHALL leave the list unchanged.
9. WHEN the user adds a manual grave whose normalised Project_Name equals, case-insensitively, that of a Manual Grave already in the list and whose Date_Of_Death is the same, THE Domain SHALL report a duplicate and THE Graveyard_Controller SHALL leave the list unchanged.
10. WHEN a manual grave has the same Project_Name as an existing Grave but another Date_Of_Death, THE Domain SHALL accept it.
11. THE Domain SHALL NOT compare a Manual Grave with a GitHub Grave for duplicates.
12. WHEN a duplicate is reported, THE Graveyard_Screen SHALL tell the user kindly that this grave already exists, and SHALL keep the entered text.
13. FOR ALL Graves already in the list and every new candidate, THE duplicate check SHALL be symmetric with respect to letter case and surrounding or repeated whitespace of the compared names.

### Requirement 7: GitHub client

**User Story:** As a user, I want the import to fetch real repository facts without any account, so that I do not need to sign in or paste a token.

#### Acceptance Criteria

1. THE GitHub_Client SHALL send one HTTP GET request to `https://api.github.com/repos/{owner}/{repo}` for each Import_Attempt, and SHALL send no other kind of request.
2. THE GitHub_Client SHALL accept only a validated Repo_Ref, and SHALL percent-encode the owner and the repo before placing them in the URL path.
3. THE GitHub_Client SHALL send the header `Accept: application/vnd.github+json`.
4. THE GitHub_Client SHALL send no `Authorization` header and no credential of any kind.
5. THE GitHub_Client SHALL NOT require a `User-Agent` header, because browsers do not allow a page to set it.
6. THE Graveyard_App SHALL need no proxy, because `api.github.com` allows cross-origin GET requests from a browser.
7. WHEN the response status is 200, THE GitHub_Client SHALL pass the body to the Repo_Response_Parser and return the parsed result or its failure.
8. WHEN the response status is 404, THE GitHub_Client SHALL return the failure `notFoundOrPrivate`.
9. WHEN the response status is 429, or is 403 with the header `x-ratelimit-remaining` equal to `0` or with a `Retry-After` header, THE GitHub_Client SHALL return the failure `rateLimited`.
10. WHEN the failure is `rateLimited` and the header `x-ratelimit-reset` holds an integer of Unix seconds, or a `Retry-After` header holds an integer of seconds, THE GitHub_Client SHALL include the reset moment in the failure so that the screen can show a reset hint.
11. WHEN the failure is `rateLimited` and neither header is present or readable, THE GitHub_Client SHALL return the failure without a reset moment and SHALL NOT throw.
12. WHEN the response status is any other value (including 403 without rate-limit headers, 301, 5xx), THE GitHub_Client SHALL return the failure `unexpectedStatus`.
13. IF the request throws a network error (no connection, DNS failure, or a blocked request), THEN THE GitHub_Client SHALL return the failure `offline`.
14. IF no response arrives within the Request_Timeout of 10 seconds, THEN THE GitHub_Client SHALL stop waiting and return the failure `timeout`.
15. THE GitHub_Client SHALL never throw out of its fetch method. Every error SHALL arrive as an Import_Failure.
16. THE Graveyard_App SHALL define the GitHub_Client as an interface, and the Graveyard_Controller SHALL depend only on that interface.
17. THE tests SHALL exercise the production GitHub_Client only through `MockClient` from the `http` package, and every other test SHALL use the Fake_GitHub_Client, so that no test touches the network.
18. THE tests SHALL assert that every request made through the `MockClient` is a GET to the exact URL of criterion 1, with `Accept` set and no `Authorization` header.
19. THE tests SHALL cover each Import_Failure with a status code or an exception, and SHALL use a controllable timer or a never-completing future for the timeout case, so that no test waits 10 real seconds.

### Requirement 8: Import flow and state

**User Story:** As a user, I want the import to be calm and safe to repeat, so that a slow or failed request never breaks the form.

#### Acceptance Criteria

1. WHEN the user submits the import form with text that the Repo_Input_Parser rejects, THE Graveyard_Screen SHALL show the parse failure reason beside the field and SHALL start no Import_Attempt.
2. WHEN the user submits a valid Repo_Ref, THE Graveyard_Controller SHALL start one Import_Attempt and THE Add_Sheet SHALL show a `GhostLoader` with a caption while the Import_Attempt is running.
3. WHILE an Import_Attempt is running, THE Graveyard_Controller SHALL hold at most one in-flight Import_Attempt, and SHALL ignore a second submit.
4. WHILE an Import_Attempt is running, THE Add_Sheet SHALL show the import submit control as unavailable, so that a double submit does nothing.
5. WHEN an Import_Attempt succeeds, THE Graveyard_Controller SHALL add a Grave with a unique id, the canonical `full_name` as the Project_Name, the Date_Of_Death from Requirement 4, the source GitHub, and the Repo_Info, and THE Add_Sheet SHALL close.
6. WHEN an Import_Attempt succeeds and the canonical `full_name` is a duplicate by Requirement 6.8, THE Graveyard_Controller SHALL add nothing and THE Add_Sheet SHALL show the duplicate message.
7. WHEN an Import_Attempt fails, THE Add_Sheet SHALL stay open, SHALL keep the text the user typed, SHALL show the gentle message of Requirement 9 for that Import_Failure, SHALL offer a retry control, and SHALL keep the by-hand option available.
8. WHEN the user closes the Add_Sheet while an Import_Attempt is running, THE Graveyard_Controller SHALL ignore the result of that Import_Attempt, SHALL add no Grave, and SHALL NOT raise an error.
9. WHEN the user starts a new Import_Attempt after a failed one, THE Graveyard_Controller SHALL clear the earlier failure message.
10. WHEN the controller is disposed while an Import_Attempt is running, THE Graveyard_Controller SHALL ignore the late result and SHALL NOT call `notifyListeners` after disposal.
11. THE Graveyard_Controller SHALL read Today from the Clock at the time of each add or import, not once at startup.
12. THE Graveyard_Controller SHALL be the only owner of the Import_Attempt state, and THE widgets SHALL NOT call the GitHub_Client directly.

### Requirement 9: Gentle import messages

**User Story:** As a user, I want each kind of failure explained in a few kind words, so that I know what to do next and never feel blamed.

#### Acceptance Criteria

1. THE Graveyard_App SHALL show a distinct message for each Import_Failure: `notFoundOrPrivate`, `rateLimited`, `offline`, `timeout`, `malformedResponse`, and `unexpectedStatus`.
2. WHEN the failure is `notFoundOrPrivate`, THE message SHALL say that the repository was not found or is private, and that Graveyard cannot tell these two apart without signing in.
3. WHEN the failure is `rateLimited` with a reset moment, THE message SHALL say that GitHub asked Graveyard to wait, and SHALL give the wait as a rounded number of minutes computed from the Clock and the reset moment, never less than 1 minute.
4. WHEN the failure is `rateLimited` without a reset moment, THE message SHALL say that GitHub asked Graveyard to wait a while.
5. WHEN the failure is `offline`, THE message SHALL say that the network cannot be reached.
6. WHEN the failure is `timeout`, THE message SHALL say that GitHub took too long to answer.
7. WHEN the failure is `malformedResponse`, THE message SHALL say that the answer from GitHub could not be read or holds no last-push date, and SHALL suggest adding the grave by hand.
8. WHEN the failure is `unexpectedStatus`, THE message SHALL say that GitHub answered in an unexpected way.
9. THE messages SHALL NOT show an exception text, a stack trace, an HTTP body, or a raw status code as the only information.
10. THE messages SHALL NOT blame the user and SHALL NOT use the words "failed", "invalid", or "your fault".
11. WHILE a failure message is shown, THE Add_Sheet SHALL expose it as a live region so that screen readers announce it.
12. FOR ALL Import_Failures, THE Add_Sheet SHALL remain usable: the text field editable, the by-hand option reachable, and the sheet closable.

### Requirement 10: Saving and loading

**User Story:** As a user, I want my graves to be there when I return, so that the graveyard lasts across visits.

#### Acceptance Criteria

1. THE Data_Layer SHALL open the Grave_Repository through `StorageOpener.open` with `currentVersion` 1, one box name, and an initializer that calls `hiveFlutterInitializer` with the sub directory `graveyard`, so that Graveyard never shares storage with Hauntagotchi on the same site.
2. THE Grave_Codec SHALL implement `RecordCodec` and SHALL encode only JSON-safe values, with Calendar_Dates encoded as `YYYY-MM-DD` strings.
3. FOR ALL valid Graves, decoding the encoded Grave SHALL produce an equal Grave (round-trip property), for both the Manual and the GitHub source.
4. THE Grave_Codec SHALL ignore fields it does not know when it decodes, so that a later version can add fields.
5. WHEN a stored GitHub Grave lacks an optional field (`html_url`, description, archived flag, or star count), THE Grave_Codec SHALL decode the Grave with no value, false, or 0 for that field, and SHALL NOT fail.
6. IF a stored record lacks the id, the Project_Name, the Date_Of_Death, or the source, or holds a malformed Date_Of_Death, an empty Project_Name, or a Project_Name longer than 80 characters, THEN THE Grave_Codec SHALL throw on decode, so that `RecordRepository` skips the entry as corrupt.
7. WHEN the repository holds a corrupt entry, THE Graveyard_Controller SHALL show the readable Graves and SHALL NOT crash.
8. WHEN the Graveyard_App opens, THE Graveyard_Controller SHALL load the Graves from the Grave_Repository and show them sorted by Requirement 6.
9. WHEN a Grave is added or deleted, THE Data_Layer SHALL write the change before THE Graveyard_Controller reports the change as saved.
10. IF a write throws, THEN THE Graveyard_Controller SHALL keep the in-memory list, keep the app usable, and show a gentle message with a retry action.
11. IF the load throws, THEN THE Graveyard_Screen SHALL show the gentle error state of Requirement 13 with a retry control.
12. THE Data_Layer SHALL provide an in-memory fake of the Grave_Repository for tests (`MemoryRecordRepository`), and widget and controller tests SHALL use it instead of Hive.
13. THE Data_Layer SHALL hold no secret and no personal data beyond what the user typed and the public repository facts.
14. THE stored records SHALL be reachable only through the repository interface, and THE Graveyard_Screen SHALL NOT call Hive.

### Requirement 11: Memory fallback

**User Story:** As a user in a private window, I want the app to keep working and to tell me kindly that nothing will be saved, so that I am not surprised later.

#### Acceptance Criteria

1. IF `StorageOpener` returns a repository whose `isPersistent` is false, THEN THE Graveyard_Controller SHALL run with that in-memory repository and every feature of this document SHALL keep working.
2. WHILE the Memory_Fallback is active, THE Graveyard_Screen SHALL show the Memory_Notice, which says in short, gentle wording that graves will not be saved.
3. WHILE storage is persistent, THE Graveyard_Screen SHALL NOT show the Memory_Notice.
4. THE Memory_Notice SHALL NOT blame the user and SHALL NOT show an exception message.

### Requirement 12: Graveyard screen content

**User Story:** As a user, I want one screen with all my tombstones and the ways to add and remove them, so that the whole app is in one place.

#### Acceptance Criteria

1. THE Graveyard_Screen SHALL replace `PlaceholderScreen` at route `/` and SHALL show the list of Graves, newest Date_Of_Death first, and an add control.
2. THE Graveyard_Screen SHALL show each Grave as a `TombstoneCard` with the Project_Name as the title and the Date_Of_Death as the date line.
3. THE Graveyard_Screen SHALL show the Dead_For_Text on each tombstone, computed from the Date_Of_Death and the Today of the Clock.
4. THE Graveyard_Screen SHALL set the epitaph text of each `TombstoneCard` from the app copy, in the spooky, witty and never mean tone of the design steering, built from the Dead_For_Text (for example "This project has been dead for 214 days"), and SHALL keep the copy short.
5. WHERE the Grave has the source GitHub, THE Graveyard_Screen SHALL show on its tombstone the `full_name`, the star count, the description as plain text, and a visible "archived" marker when the archived flag is true.
6. WHERE the description is long, THE Graveyard_Screen SHALL truncate it to at most 3 lines with an ellipsis, and SHALL keep the full text in the semantic label of the tombstone.
7. THE Graveyard_Screen SHALL display the Project_Name and the description as plain text and SHALL NOT interpret Markdown, HTML, or emoji shortcodes.
8. THE Graveyard_Screen SHALL NOT show the archived marker as the only sign of source, and SHALL NOT use color alone to convey that a repository is archived.
9. WHEN the user activates the add control, THE Graveyard_Screen SHALL open the Add_Sheet with two options: "Bury by hand" (a Project_Name field and a Date_Of_Death picker) and "Import from GitHub" (one field for `owner/repo` or a github.com URL).
10. WHEN the user submits the by-hand option with invalid input, THE Add_Sheet SHALL show the reason of Requirement 2 beside the field and SHALL keep the entered text.
11. THE Add_Sheet SHALL set the latest date of the date picker to Today and the earliest date to the Earliest_Date.
12. WHEN the user chooses to delete a Grave, THE Graveyard_Screen SHALL open a confirmation dialog that names the Grave, and SHALL delete the Grave only after the user confirms.
13. WHEN the user cancels the confirmation dialog, THE Graveyard_Screen SHALL leave the list unchanged.
14. WHEN the user confirms the deletion, THE Graveyard_Controller SHALL remove the Grave from the list and from the Grave_Repository.
15. WHILE the Graveyard_Controller loads the saved data, THE Graveyard_Screen SHALL show a `GhostLoader` with a caption.
16. THE Graveyard_Screen SHALL use `FogRouter` from `coffin_core` with the single route `/`, and SHALL keep no other route.
17. THE Graveyard_Screen SHALL read all time through the Clock of the Graveyard_Controller.
18. WHEN the list changes by an add or a delete, THE Graveyard_Screen SHALL update in place and SHALL keep the Graves in the order of Requirement 6.

### Requirement 13: Empty, loading and error states

**User Story:** As a user, I want clear guidance when there are no graves or something goes wrong, so that I never meet a dead end.

#### Acceptance Criteria

1. WHILE the list of Graves is empty and loading has finished, THE Graveyard_Screen SHALL show an onboarding empty state with a short spooky invitation that names both ways to add a grave, and one control for each way that opens the Add_Sheet on that option.
2. WHILE the list of Graves is empty, THE Graveyard_Screen SHALL NOT show a blank area.
3. IF loading the saved data throws, THEN THE Graveyard_Screen SHALL show a gentle error state with a retry control and SHALL NOT show a blank screen.
4. WHEN the user activates the retry control of the error state, THE Graveyard_Controller SHALL load the saved data again.
5. IF a write throws, THEN THE Graveyard_Screen SHALL show the gentle message of Requirement 10.10 without removing the visible Graves.
6. THE Graveyard_Screen SHALL NOT use gore, blame, shaming, or the words "failed" or "your fault" in any state.
7. THE Graveyard_Screen SHALL write all copy short, witty and slightly spooky, and never mean to the user.

### Requirement 14: Accessibility and layout

**User Story:** As a user on any device or input method, I want the screen to be readable, reachable and calm, so that the app is comfortable to use.

#### Acceptance Criteria

1. THE Graveyard_Screen SHALL give every interactive element a tap target of at least 48 by 48 logical pixels, a hover state and a press state.
2. THE Graveyard_Screen SHALL give every interactive element a semantic label.
3. THE Graveyard_Screen SHALL give each tombstone one semantic label that states the Project_Name, the Dead_For_Text, and the source (by hand, or GitHub with the `full_name`), and that includes the full description and the archived state when they exist.
4. THE delete confirmation dialog SHALL move focus into the dialog when it opens, SHALL return focus to the control that opened it when it closes, and SHALL be announced as a dialog with a label that names the Grave.
5. WHEN the user presses Enter in a text field of the Add_Sheet, THE Add_Sheet SHALL submit that option, and WHEN the user presses Escape, THE Add_Sheet and the delete confirmation dialog SHALL close without changing the list.
6. THE Graveyard_Screen SHALL be operable with the keyboard alone on Flutter Web, with a visible focus indicator on every interactive element and a logical focus order.
7. THE Graveyard_Screen SHALL render without overflow at widths of 320 and 360 logical pixels, at the default text scale and at a text scale of 1.5, in the states list, empty, loading, error, and Add_Sheet with a failure message.
8. WHEN `MediaQuery.disableAnimations` is true, THE Graveyard_Screen SHALL add no moving effect, and the `GhostLoader` SHALL draw its still frame.
9. THE Graveyard_Screen SHALL use only theme tokens from `CoffinTheme` for color, and the text and interactive colors SHALL meet WCAG AA contrast in the dark and the daylight theme.
10. THE Graveyard_Screen SHALL NOT convey any state (archived, error, selected) by color alone.
11. THE Graveyard_Screen SHALL let long names, long descriptions and long messages wrap or truncate with an ellipsis instead of overflowing, with the full text available to screen readers.
12. WHILE the Graveyard_Screen shows a loading state, it SHALL expose a semantic label that says that graves are loading.

### Requirement 15: Architecture and boundaries

**User Story:** As a maintainer, I want the rules separate from the screen and the app separate from the skeleton, so that the code stays easy to read and test.

#### Acceptance Criteria

1. THE Graveyard_App SHALL import only `package:coffin_core/coffin_core.dart` from `coffin_core`, and SHALL NOT import any file under `coffin_core/lib/src`.
2. THE Domain SHALL import no `package:flutter` library, no `dart:io`, no `dart:html`, no `package:http`, and no `package:hive_ce`, and a test SHALL fail WHEN a file under `lib/src/domain` does.
3. THE Graveyard_App SHALL NOT import from Hauntagotchi, and `coffin_core` and Hauntagotchi SHALL stay unchanged by this feature.
4. THE Graveyard_App SHALL import `package:http` only in the production GitHub_Client file under `lib/src/data`.
5. THE Graveyard_App SHALL keep files in `snake_case.dart`, one public class per file, with the layout `domain`, `data`, `ui` under `lib/src`.
6. THE Graveyard_App SHALL use `go_router` through `coffin_core`'s `FogRouter`, `ChangeNotifier` with `ListenableBuilder` for state, and no state-management package.
7. THE Graveyard_App SHALL remove `PlaceholderScreen` and its test, and SHALL update `app_routes.dart` and its test to the Graveyard_Screen.
8. THE Graveyard_App SHALL add no font, image, sound, or other asset.
9. THE Graveyard_App SHALL pass `dart format` and `flutter analyze` with zero warnings.
10. THE Graveyard_App SHALL document each public Domain and Data_Layer type with a doc comment.

### Requirement 16: Scope and guardrails

**User Story:** As a maintainer, I want the change confined to the Graveyard app and its listed support files, so that the other apps and the skeleton cannot break.

#### Acceptance Criteria

1. THE implementation of this feature SHALL edit only these paths: `apps/graveyard/lib`, `apps/graveyard/test`, `apps/graveyard/pubspec.yaml` (the `http` and `glados` lines only), the root `pubspec.lock` (the packages that `http` brings in only), `CREDITS.md` (one entry for `http`), `.github/workflows/deploy-web.yml` (Graveyard analyze and test steps only), and `.kiro/specs/graveyard-core`.
2. THE implementation SHALL leave `packages/coffin_core`, `apps/hauntagotchi`, `tool/`, and the raise template under `tool/templates` unchanged, and the `git diff` of those paths SHALL be empty.
3. WHEN the implementation is done, THE tests of `coffin_core`, `apps/hauntagotchi` and `tool/` SHALL pass unchanged, including the template integrity tests, the raiser tests, the repo-guard tests, and the raise-check (`flutter test --tags raise-check --run-skipped` in `tool/`).
4. THE `git diff` of `pubspec.lock` SHALL show only the added `http` package and any package that `http` newly requires, and the implementation report SHALL name each added package with its version.
5. THE `git diff` of `apps/graveyard/pubspec.yaml` SHALL show only the added `http` line (an exact version, no caret) and the added `glados: 1.1.7` line.
6. THE `git diff` of `CREDITS.md` SHALL show only one added entry, for `http`.
7. THE `deploy-web.yml` workflow MAY gain a "Analyze graveyard" step and a "Test graveyard" step that mirror the Hauntagotchi steps, and SHALL change no other step.
8. THE repository SHALL hold no API key, token or secret, and THE Graveyard_App SHALL send no credential in any request.

### Requirement 17: Tests

**User Story:** As a maintainer, I want the rules covered by unit, property and widget tests that always run, so that a change cannot silently break the graveyard.

#### Acceptance Criteria

1. THE unit tests, the property tests and the widget tests of this document SHALL be mandatory, and no test task SHALL be marked optional or skippable.
2. THE test suite SHALL mirror the `lib/` folder structure under `apps/graveyard/test/`, with two extra folders: `test/support/` for test doubles (Fake_Clock, Fake_GitHub_Client) and `test/source_rules/` for every test that reads source files with `dart:io`. No file under `test/domain` or `test/data` SHALL import `dart:io`, so `flutter test --platform chrome test/domain test/data` runs.
3. THE property tests SHALL use glados with Web_Safe_Generators placed under `apps/graveyard/test/domain/support/`, SHALL NOT use `any.intInRange` or `any.listWithLengthInRange`, and SHALL keep every generated integer below 2^53.
4. THE property tests SHALL cover: the Calendar_Date round-trip (1.6), Name_Normalisation idempotence (2.12), the Repo_Ref round-trip and the optional-parts equivalence (3.11, 3.12), the never-throws behavior of both parsers on arbitrary text (3.10, 4.15), the Day_Count across daylight saving changes (1.4), the fixed-offset local-date properties (4.22), the Dead_For_Formatter properties (5.8, 5.11, 5.12), the sort properties (6.4 to 6.7), the duplicate symmetry (6.13), and the Grave_Codec round-trip (10.3).
5. THE unit tests SHALL cover each acceptance criterion of Requirements 2, 3, 4 (including the fixed-offset cases of 4.18 to 4.20) and 5, the duplicate rules of Requirement 6, the codec failures and tolerances of Requirements 10.4 to 10.6, and the controller behavior for a failed write, a failed load, a corrupt entry, and a late import result after the sheet closes or the controller is disposed.
6. THE GitHub_Client tests SHALL use `MockClient` and SHALL cover every Import_Failure, the request shape (URL, method, `Accept`, no `Authorization`), percent-encoding of the path, and the rate-limit headers with and without a reset moment.
7. THE widget tests SHALL cover the Graveyard_Screen in the states empty, loading, list, error and Memory_Notice, using a Fake_Clock, a Fake_GitHub_Client and `MemoryRecordRepository`, and SHALL NOT use real Hive storage or the network.
8. THE widget tests SHALL cover: adding a grave by hand, importing a grave from the Fake_GitHub_Client, each import failure message with the typed text kept, the double-submit guard, closing the Add_Sheet during an Import_Attempt, the duplicate message, the delete confirmation (confirm and cancel), the sort order after an add, and the "Died today" wording for the `flutter/flutter` import.
9. THE widget tests SHALL cover the layouts at 320 and 360 logical pixels at a text scale of 1.5 with no overflow, the semantic labels of the tombstone and of the controls, the 48 by 48 tap targets, the Enter and Escape keys, and the reduced-motion state.
10. THE route tests SHALL assert that `/` shows the Graveyard_Screen.
11. THE source-rule tests SHALL assert the Domain import rules of Requirement 15.2, the `http` import rule of Requirement 15.4, the absence of `Authorization` and of secret-like strings in `lib/`, and the single use of `api.github.com` URLs in the GitHub_Client file.
12. THE Graveyard_App SHALL pass `flutter analyze` with zero warnings, `dart format --set-exit-if-changed` with no changes, and `flutter test` in `apps/graveyard` before the feature counts as done.

## Out of Scope

The following belong to later specs or are not planned. This feature builds none of them:

- The animated graveyard scene (fog, bobbing, moving background).
- The AI séance, the resurrection score and the 3-step revival plan.
- Resurrection of a project.
- Editing a Grave after it is created (delete and add again instead).
- Search, filter, or any sort order other than newest death first.
- Authentication, GitHub tokens, OAuth, and private repositories.
- Any screen or route other than `/`.
- Export and import of the graveyard as a file.
- Notifications and reminders.
- Fetching anything from GitHub beyond the one repository endpoint (no commits list, no issues, no user repositories).
