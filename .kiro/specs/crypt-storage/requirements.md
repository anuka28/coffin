# Requirements Document

## Introduction

The crypt-storage feature adds the storage layer of `coffin_core`: a generic repository interface for keyed records, a JSON codec contract, a `hive_ce` implementation that stores JSON (no type adapters, no code generation), an in-memory implementation with identical observable behavior, a schema version stored with every record plus a migration hook, and a reporting path for corrupt records. If persistent storage cannot be opened (for example in some private browsing modes on web), the layer falls back to the in-memory implementation and reports the fallback. Storage must work on Flutter Web (IndexedDB) and on VM tests.

The pure logic (codec contract, envelope, key validation, migration, in-memory repository, error reporting) is plain Dart with no Flutter imports. The codec round-trip and a model-based comparison of both implementations against a plain Dart `Map` are verified with glados property tests. Apps are NOT wired to storage in this feature; each app adopts it in its own spec. The design language does not apply to this feature because it has no UI.

## Non-Goals

- The name "crypt" is thematic only. Encryption is out of scope.
- Data is stored unencrypted (in the Hive box, in IndexedDB or in memory) and must not be used for secrets.
- No encryption package, cipher, key management or `hive_ce` encryption option is added.

## Dependency Approval Notice

This feature requires two packages that are not yet declared in the workspace. Per the tech steering rules, the user must approve new packages before they are added. The user has APPROVED:

- `hive_ce` (dependency of `coffin_core`): approved, with an exact pinned version.
- `hive_ce_flutter` (dependency of `coffin_core`): approved, with an exact pinned version.

The exact pinned versions are chosen and verified during the design phase against Flutter 3.47 and Dart 3.13, including Flutter Web (IndexedDB) support. Neither package needs secrets in client code. No other new package is approved or required. In particular, `hive_ce_generator`, `build_runner` and any other code generation tool are NOT added, and no Hive type adapters are written. `glados` is already a dev dependency of `coffin_core` and is reused. Riverpod, the AI layer and routing are out of scope. No app `pubspec.yaml` changes.

## Glossary

- **Crypt_Storage**: The storage layer in `coffin_core` described by this document.
- **Record**: A value of an app-defined type `T` that is stored under a String key.
- **Key_Rules**: Coffin's own rules for a valid Key: a non-empty String of at most 255 UTF-16 code units, each code unit in the range 0x00 to 0x7F. The Key_Rules are a deliberate strict subset of what `hive_ce` 2.23.3 accepts. `hive_ce` accepts any String of at most 255 code units, checked only in a debug assert, and stores keys as UTF-8 with a one-byte length. The exact source findings are recorded in design.md.
- **Key**: A non-empty String that satisfies the Key_Rules and identifies one Record in a repository.
- **Key_Validator**: The single shared pure Dart function or class that implements the Key_Rules and is used by both the Memory_Repository and the Hive_Repository.
- **Record_Repository**: The abstract generic interface `RecordRepository<T>` for keyed Records, with async methods `get`, `getAll`, `put`, `delete`, `clear` and `watch`, plus `close`.
- **Record_Codec**: The abstract generic interface `RecordCodec<T>` with `encode(T)` returning a Json_Map and `decode(Json_Map)` returning `T`.
- **Json_Map**: A `Map<String, Object?>` whose values are JSON-safe: `null`, `bool`, `num` (finite), `String`, `List` of JSON-safe values, or `Map<String, Object?>` of JSON-safe values.
- **Envelope**: The stored wrapper of one Record: a schema version plus the Json_Map payload, serialized as a JSON string.
- **Envelope_Codec**: The pure Dart class that turns a Json_Map and a schema version into an Envelope string and back.
- **Schema_Version**: A non-negative integer stored in each Envelope that identifies the payload shape.
- **Current_Version**: The Schema_Version that the repository's Record_Codec produces and understands, supplied when the repository is created.
- **Migration_Hook**: A function supplied by the app that upgrades a Json_Map from an older Schema_Version to the Current_Version before decoding.
- **Hive_Repository**: The `hive_ce` implementation of Record_Repository.
- **Memory_Repository**: The in-memory implementation of Record_Repository.
- **Storage_Opener**: The injectable component that opens a Hive_Repository, given a storage location and a box name, and falls back to a Memory_Repository when opening fails.
- **Storage_Initializer**: The injectable function that prepares `hive_ce` for use (for example `Hive.initFlutter` on app side, or `Hive.init` with a temporary directory in tests).
- **Storage_Event**: An immutable value emitted by `watch` that describes one change: a Key and a kind (`put`, `delete` or `clear`).
- **Storage_Issue**: An immutable value describing a problem: a kind (`corruptRecord`, `migrationFailed`, `unknownVersion`, `fallbackToMemory`), the Key if any, and a message.
- **Issue_Reporter**: The injectable callback `void Function(Storage_Issue)` that receives every Storage_Issue.
- **Corrupt_Record**: A stored entry that cannot be turned into a Record because the Envelope is unparseable, the Schema_Version is missing or invalid, the payload is not a Json_Map, migration fails, or the Record_Codec throws.
- **Reference_Model**: A plain Dart `Map<String, T>` used by tests as the oracle. The Reference_Model also validates Keys with the Key_Validator.
- **Barrel**: The file `packages/coffin_core/lib/coffin_core.dart`, the only public import for apps.
- **Storage_Property_Tests**: The glados property-based tests defined in Requirement 12.
- **Async_Smoke_Test**: The throwaway, deliberately failing async glados test defined in Requirement 13.

## Requirements

### Requirement 1: Generic repository interface

**User Story:** As a Flutter developer using Coffin, I want one small interface for keyed records, so that my app code never depends on Hive.

#### Acceptance Criteria

1. THE Record_Repository SHALL be a generic abstract interface over a Record type `T` with String Keys.
2. THE Record_Repository SHALL declare the async methods `Future<T?> get(String key)`, `Future<List<T>> getAll()`, `Future<void> put(String key, T record)`, `Future<void> delete(String key)` and `Future<void> clear()`.
3. THE Record_Repository SHALL declare `Stream<StorageEvent> watch()` and `Future<void> close()`.
4. THE Record_Repository SHALL expose no Hive type in any signature.
5. THE Record_Repository SHALL carry a doc comment on every public member that states its semantics.

### Requirement 2: Repository semantics

**User Story:** As a developer, I want precisely defined behavior, so that both implementations are interchangeable.

#### Acceptance Criteria

1. WHEN `get` is called with a Key that has no stored Record, THE Record_Repository SHALL return null.
2. WHEN `put` is called with a Key that already holds a Record, THE Record_Repository SHALL overwrite the stored Record.
3. WHEN `delete` is called with a Key that has no stored Record, THE Record_Repository SHALL complete normally and SHALL emit no Storage_Event.
4. WHEN `clear` is called, THE Record_Repository SHALL remove every Record and SHALL emit one Storage_Event of kind `clear`, even if the repository was already empty.
5. THE Record_Repository SHALL return `getAll` Records in ascending order of Key, compared by UTF-16 code units.
6. THE Record_Repository SHALL omit Corrupt_Records from `getAll`, and SHALL return null from `get` for a Corrupt_Record.
7. IF `put`, `get` or `delete` receives a Key that violates the Key_Rules, THEN THE Record_Repository SHALL throw an `ArgumentError` as specified in Requirement 3.
8. WHEN `put` completes, THE Record_Repository SHALL make the new Record visible to every later `get` and `getAll`.
9. WHEN `put` or `delete` is called concurrently for the same Key, THE Record_Repository SHALL apply the calls in the order they were made.
10. THE Record_Repository SHALL return Records from `get` and `getAll` that are equal to the Records that were put, as decoded by the Record_Codec.

### Requirement 3: Key rules

**User Story:** As a developer, I want one shared definition of a valid Key, so that the in-memory fallback never accepts a Key that Hive would reject.

#### Acceptance Criteria

1. THE Key_Validator SHALL implement the Key_Rules as a single shared pure Dart implementation that both the Memory_Repository and the Hive_Repository use.
2. IF `get`, `put` or `delete` receives a Key that violates the Key_Rules, THEN THE Memory_Repository SHALL throw an `ArgumentError` before touching storage and before emitting a Storage_Event.
3. IF `get`, `put` or `delete` receives a Key that violates the Key_Rules, THEN THE Hive_Repository SHALL throw an `ArgumentError` before touching storage and before emitting a Storage_Event.
4. THE Hive_Repository SHALL validate every Key with the Key_Validator before calling the box, so that callers see an `ArgumentError` and never a Hive-specific error.
5. WHEN a Key at the limit (the longest valid length, and a Key containing the highest valid character) is passed to `put`, THE Memory_Repository and THE Hive_Repository SHALL accept the Key and SHALL return the Record for that Key from `get` and `getAll`.
6. IF a Key just past the limit (one character longer than the longest valid length, or a Key containing the first invalid character just past the allowed range) is passed to `put`, `get` or `delete`, THEN THE Memory_Repository and THE Hive_Repository SHALL each throw an `ArgumentError`.
7. THE design phase SHALL verify the Key_Rules against the `hive_ce` source and SHALL record the exact limits (length unit, maximum length, allowed character range and whether empty is allowed) in `design.md`.
8. THE test suite SHALL include a test that checks the Key_Validator against a real `hive_ce` box on a table of boundary Keys, and SHALL assert that every Key the Key_Validator accepts works in a real box (put, get and the box keys return the same Key and Record), and that every Key the real box rejects is also rejected by the Key_Validator. THE Key_Validator MAY reject Keys that `hive_ce` accepts (for example empty or non-ASCII Keys), so that the Key_Rules are a strict subset of what `hive_ce` accepts.
9. THE `clear` method SHALL take no Key and SHALL perform no Key validation.

### Requirement 4: Watch stream

**User Story:** As a developer, I want a change stream, so that the UI can react to storage changes.

#### Acceptance Criteria

1. THE Record_Repository SHALL return a broadcast stream from `watch`, so that any number of listeners can subscribe.
2. WHEN `put` completes for a Key, THE Record_Repository SHALL emit a Storage_Event of kind `put` carrying that Key.
3. WHEN `delete` completes for a Key that held a Record, THE Record_Repository SHALL emit a Storage_Event of kind `delete` carrying that Key.
4. THE Record_Repository SHALL emit Storage_Events in the order the changes were applied.
5. THE Record_Repository SHALL emit no Storage_Event to a listener for changes applied before that listener subscribed.
6. THE Record_Repository SHALL never emit a stream error for a Corrupt_Record.
7. WHEN `close` completes, THE Record_Repository SHALL complete the `watch` stream for every listener.
8. THE Storage_Event SHALL be an immutable value type with value equality.

### Requirement 5: Lifecycle after close

**User Story:** As a developer, I want predictable behavior after a repository is closed, so that late calls cannot crash the app.

#### Acceptance Criteria

1. WHEN `close` is called a second time, THE Record_Repository SHALL complete normally.
2. IF `get`, `getAll`, `put`, `delete` or `clear` is called after `close`, THEN THE Record_Repository SHALL throw a `StateError` with a descriptive message.
3. WHEN `watch` is called after `close`, THE Record_Repository SHALL return a stream that completes without emitting events.
4. THE Memory_Repository SHALL drop its in-memory Records on `close`.
5. THE Hive_Repository SHALL close its box on `close` and SHALL keep the stored data on disk or in IndexedDB.

### Requirement 6: Record codec and envelope

**User Story:** As a developer, I want records converted to JSON maps by a codec I write, so that no code generation or adapters are needed.

#### Acceptance Criteria

1. THE Record_Codec SHALL convert a Record to a Json_Map with `encode` and a Json_Map to a Record with `decode`.
2. THE Record_Codec SHALL require that `encode` returns only JSON-safe values.
3. THE Envelope_Codec SHALL serialize a Schema_Version and a Json_Map into one JSON string, and parse such a string back into a Schema_Version and a Json_Map.
4. FOR ALL valid Records, `decode(encode(x))` SHALL equal `x` (round-trip property).
5. FOR ALL Json_Maps and non-negative Schema_Versions, parsing the Envelope string after serializing SHALL return an equal Schema_Version and an equal Json_Map (round-trip property).
6. IF the Record_Codec `encode` returns a value that is not JSON-safe (for example a non-finite number or a non-String map key), THEN THE Record_Repository SHALL throw an `ArgumentError` from `put` and SHALL leave the stored Records unchanged.
7. THE Envelope_Codec SHALL be a plain Dart class with no Flutter imports.
8. THE Storage layer SHALL expose no Hive type adapters and SHALL use no code generation.

### Requirement 7: Hive implementation

**User Story:** As a developer, I want persistent storage that works on web and mobile, so that user data survives restarts.

#### Acceptance Criteria

1. THE Hive_Repository SHALL implement Record_Repository on top of one `hive_ce` box opened per repository.
2. THE Hive_Repository SHALL store each Record as the Envelope JSON string, with the Key as the box key.
3. THE Hive_Repository SHALL register no Hive type adapters.
4. THE Hive_Repository SHALL run on Flutter Web (IndexedDB), on Android, on iOS and on the Dart VM.
5. THE Hive_Repository SHALL NOT call any global initialization function by itself.
6. THE Storage_Initializer SHALL be injectable, so that an app passes the `hive_ce_flutter` initializer and tests pass a VM initializer that uses a temporary directory.
7. THE Hive_Repository SHALL read `getAll` from the box in Key order as defined by Requirement 2.5.
8. WHEN a Record is put through one Hive_Repository instance and the box is closed and reopened at the same location, THE Hive_Repository SHALL return an equal Record from `get`.
9. THE Hive_Repository file SHALL live under `packages/coffin_core/lib/src/storage/`, and the code that imports `hive_ce_flutter` SHALL be confined to the Flutter-facing initializer file, so that the other storage files remain testable on the Dart VM.

### Requirement 8: In-memory implementation

**User Story:** As a developer, I want an in-memory repository with identical behavior, so that tests and fallbacks behave like the real thing.

#### Acceptance Criteria

1. THE Memory_Repository SHALL implement Record_Repository with the same observable behavior as the Hive_Repository for every criterion in Requirements 2, 3, 4 and 5.
2. THE Memory_Repository SHALL store Records as Envelope strings, so that encoding, migration and Corrupt_Record handling behave as in the Hive_Repository.
3. THE Memory_Repository SHALL be a plain Dart class with no Flutter imports.
4. THE Memory_Repository SHALL accept optional seed entries of raw Envelope strings, so that tests can inject corrupt data.
5. THE Memory_Repository SHALL keep no state shared between instances.

### Requirement 9: Schema version and migration

**User Story:** As a developer, I want stored data versioned, so that future app changes do not break saved data.

#### Acceptance Criteria

1. WHEN a Record is put, THE Record_Repository SHALL store the Current_Version in its Envelope.
2. THE Record_Repository SHALL accept an optional Migration_Hook with the signature `Json_Map Function(int fromVersion, Json_Map data)`.
3. WHEN a stored Envelope has a Schema_Version lower than the Current_Version and a Migration_Hook exists, THE Record_Repository SHALL call the Migration_Hook once with the stored version and payload before decoding, and SHALL decode the returned Json_Map.
4. WHEN a stored Envelope has a Schema_Version lower than the Current_Version and no Migration_Hook exists, THE Record_Repository SHALL treat the Record as a Corrupt_Record of kind `unknownVersion`.
5. WHEN a stored Envelope has a Schema_Version equal to the Current_Version, THE Record_Repository SHALL decode the payload without calling the Migration_Hook.
6. IF a stored Envelope has a Schema_Version higher than the Current_Version, THEN THE Record_Repository SHALL treat the Record as a Corrupt_Record of kind `unknownVersion` and SHALL leave the stored entry unchanged.
7. IF a stored entry has no Schema_Version, or a Schema_Version that is negative or not an integer, THEN THE Record_Repository SHALL treat the Record as a Corrupt_Record of kind `corruptRecord`.
8. IF the Migration_Hook throws, THEN THE Record_Repository SHALL treat the Record as a Corrupt_Record of kind `migrationFailed`.
9. THE Record_Repository SHALL NOT write a migrated Record back to storage on read, so that reads change no stored data.
10. WHEN a migrated Record is later put, THE Record_Repository SHALL store it with the Current_Version.
11. THE Migration_Hook SHALL receive a copy of the stored payload, so that mutating it cannot alter stored data.

### Requirement 10: Corrupt records and error reporting

**User Story:** As a user, I want a damaged record to be skipped, so that one bad entry never crashes the app or hides my other data.

#### Acceptance Criteria

1. IF a stored entry is a Corrupt_Record, THEN THE Record_Repository SHALL skip that entry in `get` and `getAll` and SHALL NOT throw to the caller.
2. WHEN a Corrupt_Record is skipped, THE Record_Repository SHALL report one Storage_Issue to the Issue_Reporter, carrying the Key and a message.
3. IF the Record_Codec `decode` throws, THEN THE Record_Repository SHALL treat the Record as a Corrupt_Record of kind `corruptRecord`.
4. IF the Issue_Reporter itself throws, THEN THE Record_Repository SHALL swallow that exception and continue.
5. THE Record_Repository SHALL leave a Corrupt_Record untouched in storage until a `put` with the same Key overwrites it, or `delete` or `clear` removes it, so that no data is lost silently.
6. WHEN `put` overwrites a Corrupt_Record, THE Record_Repository SHALL emit a Storage_Event of kind `put`.
7. WHEN `delete` removes a Corrupt_Record, THE Record_Repository SHALL emit a Storage_Event of kind `delete`.
8. WHERE no Issue_Reporter is supplied, THE Record_Repository SHALL use a reporter that discards Storage_Issues.
9. THE Storage_Issue SHALL be an immutable value type with value equality.
10. THE Storage_Issue message SHALL NOT include the stored payload content, so that user data does not leak into logs.

### Requirement 11: Open failure and fallback

**User Story:** As a user in a restricted browser mode, I want the app to still work when persistent storage is blocked, so that I am never stuck.

#### Acceptance Criteria

1. WHEN the Storage_Opener is asked to open a repository, THE Storage_Opener SHALL run the injected Storage_Initializer and open the Hive_Repository.
2. IF the Storage_Initializer or the box open throws, THEN THE Storage_Opener SHALL return a Memory_Repository instead of throwing.
3. WHEN the Storage_Opener falls back, THE Storage_Opener SHALL report one Storage_Issue of kind `fallbackToMemory` to the Issue_Reporter.
4. THE Storage_Opener SHALL return a result that states whether the repository is persistent, so that an app can warn the user that data will not be saved.
5. WHEN the Storage_Opener succeeds, THE Storage_Opener SHALL report no Storage_Issue.
6. THE Storage_Opener SHALL accept an injectable box-open function, so that tests can simulate a failure without a real browser.
7. THE Storage_Opener SHALL complete in all cases without an unhandled exception.

### Requirement 12: Property-based verification

**User Story:** As a maintainer, I want the storage invariants checked over many generated inputs, so that no edge case slips through.

#### Acceptance Criteria

1. THE Storage_Property_Tests SHALL use glados to generate records and assert `decode(encode(x)) == x` for the Record_Codec.
2. THE Storage_Property_Tests SHALL use glados to generate Json_Maps and Schema_Versions and assert the Envelope round-trip of Requirement 6.5.
3. THE Storage_Property_Tests SHALL use glados to generate random sequences of `put`, `delete` and `clear` operations and apply each sequence to the Memory_Repository, to the Hive_Repository and to the Reference_Model.
4. WHILE applying a generated sequence, THE Storage_Property_Tests SHALL assert after every operation that `get` for every touched Key and `getAll` agree across the three, and that the `watch` events of both repositories equal the events expected from the Reference_Model.
5. THE Storage_Property_Tests SHALL use glados Key generators that deliberately include an empty Key, a Key of the longest valid length, a Key one character longer than the longest valid length, a Key containing the highest valid character, and a Key containing the first invalid character, plus a small pool of ordinary Keys, so that overwrites and deletes of existing Keys occur often.
6. WHEN a generated operation uses a Key that violates the Key_Rules, THE Storage_Property_Tests SHALL assert that the Memory_Repository, the Hive_Repository and the Reference_Model validation each throw an `ArgumentError`, that the stored state is unchanged, and that no Storage_Event is emitted.
7. IF any generated input violates an invariant, THEN THE Storage_Property_Tests SHALL fail and report the input, including the operation sequence.
8. THE model-based test SHALL count the runs executed and the operations executed, and SHALL assert that both counts are greater than zero and that the runs executed equal the configured number of runs.
9. THE Hive_Repository tests SHALL use a temporary directory created under `Directory.systemTemp`, and SHALL delete it after each test, including when the test fails.
10. THE Storage_Property_Tests SHALL live under `packages/coffin_core/test/storage/`, mirroring the `lib/` layout.
11. THE Storage_Property_Tests SHALL follow the style of the existing glados tests in `packages/coffin_core/test/router/fog_math_property_test.dart` and `packages/coffin_core/test/theme/coffin_glow_property_test.dart`.

### Requirement 13: Async glados verification

**User Story:** As a maintainer, I want proof that glados awaits async test bodies, so that the model-based test cannot pass vacuously.

#### Acceptance Criteria

1. THE design phase SHALL confirm that glados 1.1.7 awaits async test bodies by running an Async_Smoke_Test, for example an async glados test whose body awaits `Future.delayed` and then fails an expectation, and by observing that `flutter test` reports that test as FAILED.
2. THE design phase SHALL record the result of the Async_Smoke_Test in `design.md`.
3. IF glados does not await async test bodies, THEN THE model-based test SHALL NOT rely on async glados bodies, and THE design SHALL use an alternative, for example glados generating operation sequences that run inside an ordinary awaited `flutter_test` test, or a synchronous driver.
4. THE Async_Smoke_Test SHALL be a throwaway experiment that does not remain in the committed test suite.
5. THE Async_Smoke_Test SHALL NOT leave the test suite failing after the experiment.

### Requirement 14: Example-based tests

**User Story:** As a maintainer, I want the specific behaviors covered by plain tests, so that failures are easy to read.

#### Acceptance Criteria

1. THE test suite SHALL include unit tests for the semantics of Requirements 2, 3, 4 and 5 against both the Memory_Repository and the Hive_Repository.
2. THE test suite SHALL include unit tests for migration: lower version with a hook, lower version without a hook, equal version, higher version, missing version, invalid version and a throwing hook.
3. THE test suite SHALL include unit tests that seed unparseable, non-object and codec-rejected entries, and confirm that `get` and `getAll` skip them, that one Storage_Issue is reported per skipped entry, and that the stored entries remain unchanged.
4. THE test suite SHALL include unit tests for the Storage_Opener covering success, initializer failure, box-open failure and the `fallbackToMemory` report.
5. THE test suite SHALL include a persistence test that closes and reopens the Hive_Repository at the same temporary location.
6. THE test suite SHALL include unit tests that confirm a non-JSON-safe encode result is rejected without changing stored Records.

### Requirement 15: Package boundaries and scope

**User Story:** As a maintainer, I want the storage layer to follow the project structure, so that the skeleton stays easy to read.

#### Acceptance Criteria

1. THE storage source files SHALL live under `packages/coffin_core/lib/src/storage/`, in `snake_case.dart` files with one public class per file.
2. THE storage tests SHALL live under `packages/coffin_core/test/storage/`, mirroring the `lib/` layout.
3. THE Barrel SHALL export the public storage names using `show` clauses consistent with the existing exports, and SHALL export no Hive type.
4. THE codec contract, Envelope_Codec, Key_Validator, migration logic, Memory_Repository, Storage_Event, Storage_Issue and Issue_Reporter SHALL import no Flutter library.
5. EVERY public API in the storage source files SHALL carry a doc comment.
6. THE coffin_core package SHALL import nothing from `apps/hauntagotchi` or `apps/graveyard`.
7. THE Hauntagotchi and Graveyard apps SHALL NOT import the storage API in this feature, and no app `pubspec.yaml` SHALL change.
8. THE feature SHALL add no Riverpod, AI or routing code.
9. THE feature SHALL write no files outside the repository, except temporary directories under `Directory.systemTemp` that the tests delete afterwards.
10. THE feature SHALL add no encryption code or encryption dependency.
11. THE doc comments of the Hive_Repository and the Storage_Opener SHALL state that data is stored unencrypted.

### Requirement 16: Quality gates

**User Story:** As a maintainer, I want the feature to meet the workspace quality rules, so that the codebase stays clean.

#### Acceptance Criteria

1. THE feature code SHALL pass `dart format` with no changes.
2. THE feature code SHALL pass `flutter analyze` with zero warnings across the workspace.
3. THE feature SHALL include unit tests for every class under `packages/coffin_core/lib/src/storage/`.
4. THE feature SHALL include the glados property tests of Requirement 12.
5. WHEN `flutter test` runs for `coffin_core` and for both apps, THE test suite SHALL pass before any task is marked done.
6. THE feature SHALL add `hive_ce` and `hive_ce_flutter` with exact pinned versions and no other new package.
7. THE feature SHALL add no `hive_ce_generator`, `build_runner` or generated file.
8. THE feature SHALL add no API keys, secrets or tokens to the repository.
9. THE feature SHALL leave the Flutter Web build of both apps compiling.
