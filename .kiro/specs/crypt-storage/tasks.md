# Implementation Plan: crypt-storage

## Overview

Build the storage layer of `coffin_core` in dependency order. First the dependency gate (dry-run, stop if the package list differs). Then the whole pure Dart layer with its tests: contracts and value types, key validator, JSON safety, envelope, operation queue, raw stores, the shared `EnvelopeRepository` engine and the memory repository. After a checkpoint, the Hive-aware layer: the real-box test helper first, then `HiveRawStore`, `HiveRecordRepository`, the validator-vs-real-box agreement test, `StorageOpener` and `hiveFlutterInitializer`. Then the model-based Property 6, the barrel and source scans, the timing report, the Chrome run and final verification.

All code is Dart in Flutter, matching the design. Paths are relative to the repo root. Tests use `flutter_test` and `glados`. Per the tech steering rules, unit tests and property tests for the pure logic are required, not optional. Every task is required.

Notes that apply to all tasks:

- Edit only files inside this repository (`/Users/ranmanlabs/Documents/Kiroween/coffin`). The only files created outside it are temporary directories under `Directory.systemTemp` made by the tests, which the tests delete. Use no `/tmp` scratch files and no shell redirections to paths outside the repo.
- Do not modify `requirements.md`, `design.md` or `.config.kiro`. Do not touch `DIARY.md`. The user keeps the diary.
- Do not wire storage into either app. No app `pubspec.yaml` changes. No app code imports the storage API.
- Only `hive_ce` 2.23.3, `hive_ce_flutter` 2.3.4 and `meta` 1.19.0 (all exact, no caret) are added to `coffin_core`. Add no `hive_ce_generator`, `build_runner`, encryption package or generated `*.g.dart` file. Register no Hive type adapters.
- Pure storage files import no Flutter and no `hive_ce`. Only `hive_raw_store.dart` imports `hive_ce`. Only `hive_flutter_initializer.dart` imports `hive_ce_flutter`.
- Files follow the design's file layout under `packages/coffin_core/lib/src/storage/`, one public class per file, `snake_case.dart`. Every public member in `coffin_core` carries a doc comment (`public_member_api_docs` is enabled).
- Tests mirror `lib/` under `packages/coffin_core/test/storage/`. Test files import `src/` files directly, as the router tests do.
- `glados` exports its own `expect`, `group` and `test`, so test files must `hide` the clashing names from the glados import, as `packages/coffin_core/test/router/fog_math_property_test.dart` does. Tag each property with `// Feature: crypt-storage, Property N: <title>` and `// Validates: Requirements ...`.
- Run counts: Property 6 uses `ExploreConfig(numRuns: 100)` with at most 30 operations per sequence. Every other glados property uses `ExploreConfig(numRuns: 200)`. Never lower a run count or sequence length silently. See the timing task.
- Key generators include the boundary keys B1 to B11 from the design's boundary key table, plus a small pool of ordinary keys.
- Real-box hygiene (design "Real-box test hygiene"): every test and every glados run that opens a real box uses a unique, lowercase, ASCII box name; opens it with `openBox(name, path:)` in its own `Directory.systemTemp.createTemp('crypt_storage_')` directory; and closes the box BEFORE deleting that directory, in `finally` or `addTearDown`, even on failure. The persistence test is the only same-name exception. Each glados run owns all of its state, because glados re-runs a failed body once without awaiting it.
- Tests that touch `dart:io` or `hive_ce` carry `@TestOn('vm')` and are never imported by a Chrome-run file.
- Do not mark a task done until `flutter test` passes for the package or app it touches.
- Tests render with the Ahem font, so never assert on glyph shapes. (Storage has no UI, so this rarely applies.)

## Tasks

- [ ] 1. Dependency gate
  - [ ] 1.1 Dry-run, then add the storage packages to `coffin_core`
    - Read `packages/coffin_core/pubspec.yaml` and the numbered "Expected package list" in design.md's "Dependency decision" first.
    - In `packages/coffin_core`, run `flutter pub add hive_ce:2.23.3 hive_ce_flutter:2.3.4 --dry-run`. Compare every package it would add against the expected list. `meta`, `crypto`, `path`, `web`, `ffi` and `collection` are already in the lock and do not count as additions.
    - If it would add ANY package not on the list, STOP. Show the user the full dry-run output, add nothing, and wait for their decision. Do not continue to later tasks.
    - Only if it matches: add `hive_ce: 2.23.3`, `hive_ce_flutter: 2.3.4` and `meta: 1.19.0` (exact, no caret) under `dependencies` in `packages/coffin_core/pubspec.yaml`. Edit no app pubspec. Add no `hive_ce_generator` or `build_runner`.
    - Run `flutter pub get` at the workspace root and confirm in `pubspec.lock` that only listed packages were added.
    - _Requirements: 16.6, 16.7, 16.8, 15.7, 15.10_

- [ ] 2. Contracts and value types
  - [ ] 2.1 Implement `JsonMap`, `RecordCodec` and `RecordRepository`
    - Create `json_map.dart` (`typedef JsonMap = Map<String, Object?>`), `record_codec.dart` (`abstract interface class RecordCodec<T>` with `encode` and `decode`) and `record_repository.dart` (`abstract interface class RecordRepository<T>` with `get`, `getAll`, `put`, `delete`, `clear`, `watch`, `close`) in `packages/coffin_core/lib/src/storage/`.
    - Full doc comments on every member, stating semantics (missing key gives null, order, overwrite, closed behavior, unencrypted storage). No Hive type in any signature. No Flutter import.
    - Add `test/storage/storage_contracts_test.dart` with a tiny in-test fake implementing the interfaces, checking they compile and have the expected shape.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 6.1, 6.2, 15.1, 15.4, 15.5_

  - [ ] 2.2 Implement events, issues, reporter and migration hook
    - Create `storage_event_kind.dart`, `storage_event.dart` (immutable, value equality, `put`/`delete`/`clear` constructors, readable `toString`), `storage_issue_kind.dart`, `storage_issue.dart` (immutable, value equality), `issue_reporter.dart` (`IssueReporter` typedef, `discardIssues`, `reportSafely` that swallows reporter exceptions) and `migration_hook.dart`.
    - Import `@immutable` from `package:meta/meta.dart`, never from Flutter.
    - Add `storage_event_test.dart`, `storage_issue_test.dart` and `issue_reporter_test.dart`: equality and `hashCode` per field, `clear` has a null key, the default reporter discards, a throwing reporter is swallowed and later calls still work.
    - _Requirements: 4.8, 10.4, 10.8, 10.9, 9.2, 15.4, 15.5_

- [ ] 3. Key validator
  - [ ] 3.1 Implement `KeyValidator`
    - Create `key_validator.dart` with `maxLength` 255, `maxCodeUnit` 0x7F, `violation`, `isValid` and `check` (throws `ArgumentError`). Messages state a length or index, never the key text.
    - Add `key_validator_test.dart`: every row of the boundary key table B1 to B11 with the expected coffin verdict (B1, B4, B7, B8, B9, B10 reject; B2, B3, B5, B6, B11 accept), the error message does not contain the key, and `check` does not throw for valid keys.
    - _Requirements: 3.1, 3.5, 3.6, 3.7, 3.9, 15.4_

  - [ ] 3.2 Write property test for the key validator
    - Create `key_validator_property_test.dart`, hiding the glados name clashes. `numRuns: 200`.
    - **Property 3: Key validator matches its rule.** For any string (generator mixes ASCII, accented letters, emoji, lone surrogates, lengths around 255, and the boundary keys), `isValid` is true exactly when non-empty, at most 255 code units, every unit at most 0x7F. When false, `check` throws `ArgumentError` and the message does not contain the input. When true, `check` does not throw.
    - **Validates: Requirements 3.1, 3.5, 3.6**

- [ ] 4. JSON safety and envelope
  - [ ] 4.1 Implement `JsonSafety`
    - Create `json_safety.dart` with `maxSafeInt` (2^53 - 1), `maxDepth` (64), `isSafe`, `check` (throws `ArgumentError` naming the path, never the value) and `deepCopy` (fresh `Map<String, Object?>` and `List<Object?>`). Detect NaN, infinity, big ints, non-String map keys, other object types and cyclic or too deep values.
    - Add `json_safety_test.dart` with examples for each unsafe class, the exact limits (2^53 - 1 safe, 2^53 unsafe, depth 64 safe, depth 65 unsafe), and a copy that shares no instance with the original.
    - _Requirements: 6.2, 6.6, 9.11, 15.4_

  - [ ] 4.2 Write property test for JSON safety
    - Create `json_safety_property_test.dart`. `numRuns: 200`.
    - **Property 4: JSON safety detects every unsafe value.** For any generated safe map, `check` passes and `deepCopy` equals the original and shares no `Map` or `List` instance. With one unsafe value injected at a random position (NaN, infinity, integer beyond +/-(2^53 - 1), non-String map key, `DateTime`, depth beyond 64), `check` throws `ArgumentError`. Build doubles with `any.doubleInRange`, never `any.double`.
    - **Validates: Requirements 6.2, 6.6, 9.11**

  - [ ] 4.3 Implement `Envelope`, `EnvelopeFormatException` and `EnvelopeCodec`
    - Create `envelope.dart`, `envelope_format_exception.dart` (fixed reason string, never part of the input) and `envelope_codec.dart` (`maxVersion` 2^31 - 1, `encode(version, data)` giving `{"v":..,"data":{..}}`, `parse(raw)` implementing decode table steps 1 to 3: not JSON or not an object, bad `v`, bad `data`). A `v` such as `2.0` is accepted as 2; `1.5`, negatives, strings, null and values above `maxVersion` are rejected. Extra envelope properties are ignored.
    - Add `envelope_codec_test.dart`: the exact encoded text for a sample, each rejection case, `2.0` accepted, `maxVersion` accepted and `maxVersion + 1` rejected, extra properties ignored, messages never contain input text.
    - _Requirements: 6.3, 6.7, 9.7, 15.4_

  - [ ] 4.4 Write property test for the envelope round trip
    - Create `envelope_codec_property_test.dart`. `numRuns: 200`.
    - **Property 2: Envelope round trip.** For any safe map (depth at most 3, at most 4 entries per map or list, nulls, bools, finite doubles in `[-1e9, 1e9]`, ints within +/-(2^53 - 1), strings from a mixed alphabet including unicode, an emoji, a lone surrogate, quotes, backslashes and control characters, keys from the same alphabet) and any version in `0..maxVersion`, `parse(encode(v, m))` returns version `v` and a deeply equal map.
    - **Validates: Requirements 6.3, 6.5, 12.2**

- [ ] 5. Queue and raw stores
  - [ ] 5.1 Implement `OperationQueue`
    - Create `operation_queue.dart` with `run<R>` that chains each operation after the previous one, swallowing the previous failure so one failed operation never blocks later ones.
    - Add `operation_queue_test.dart`: operations run in submission order even when earlier ones take longer, a failing operation completes its own future with the error and later operations still run, results are returned to the right caller.
    - _Requirements: 2.8, 2.9, 15.4_

  - [ ] 5.2 Implement `RawStore` and `MemoryRawStore`
    - Create `raw_store.dart` (the interface from the design) and `memory_raw_store.dart` (Map-backed, no shared state between instances, `close` drops entries, seed keys validated with `KeyValidator` and a bad seed key throws `ArgumentError`).
    - Add `memory_raw_store_test.dart`: read, keys, write, remove (reports whether the key existed), removeAll, close, two instances share nothing, a bad seed key throws.
    - _Requirements: 8.2, 8.4, 8.5, 5.4, 3.1, 15.4_

- [ ] 6. Pure test support
  - [ ] 6.1 Create pure test support files
    - Create under `test/storage/support/` (pure, no `dart:io`, no `hive_ce`): `test_note.dart` (`TestNote` with `title`, `count`, `weight`, `tags`, `extra`, value equality and readable `toString`, plus `TestNoteCodec`), `storage_generators.dart` (key generator weighted toward six ordinary keys `a` to `f` plus the boundary keys B1 to B11; `TestNote` generator; safe JSON map generator; stored-entry generators for every decode table class; `Op` sealed class with `PutOp`, `DeleteOp`, `ClearOp` and readable `toString` such as `put("a", TestNote(...))`; a deep-equals helper) and `repository_contract.dart` (a shared example body that takes a repository factory and a way to read raw contents).
    - Add a small sanity test for the generators and `TestNote` equality.
    - _Requirements: 12.1, 12.5, 12.10, 12.11, 14.1_

  - [ ] 6.2 Write property test for the codec round trip
    - Create `record_codec_property_test.dart`. `numRuns: 200`.
    - **Property 1: Codec round trip.** For any generated `TestNote` `x`, `codec.decode(codec.encode(x))` equals `x` and `JsonSafety.isSafe(codec.encode(x))` is true.
    - **Validates: Requirements 6.2, 6.4, 12.1**

- [ ] 7. Shared engine and memory repository
  - [ ] 7.1 Implement `EnvelopeRepository` and `MemoryRecordRepository`
    - Create `envelope_repository.dart` and `memory_record_repository.dart`, implementing the design's put flow, queue rules, decode table, event rules and close rules.
    - Checks at call time before enqueueing, in this order: closed (`StateError`), key (`ArgumentError`), encode and `JsonSafety.check` (`ArgumentError`). `encode` exceptions propagate unchanged.
    - `getAll` ignores non-valid or non-String keys silently, sorts with `String.compareTo`, decodes each value by the table (current version without hook; lower with hook once, with a copy; lower without hook and higher are `unknownVersion`; throwing hook is `migrationFailed`; the rest `corruptRecord`), skips bad entries and reports one `StorageIssue` per skipped entry per read with fixed messages that never include payload text or the exception message.
    - `put` always emits; `delete` emits only if the store reported the key existed; `clear` always emits one `clear`. Events are emitted after the store write completes, in application order, from a repository-owned broadcast controller. `close` marks the repository closed at once, runs the queued close after earlier calls, is idempotent (same future), completes the stream, and `watch` after close returns an empty stream.
    - Reads never write. `currentVersion` outside `0..maxVersion` fails an assert.
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10, 3.2, 3.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.1, 5.2, 5.3, 5.4, 6.6, 8.1, 8.2, 8.3, 8.4, 8.5, 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 9.10, 9.11, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.10, 15.4, 15.5_

  - [ ] 7.2 Write example tests for the memory repository
    - Create `memory_record_repository_test.dart`, running the shared `repository_contract` body plus memory-only cases.
    - Semantics: get missing key is null; overwrite; delete missing emits nothing; `clear` on an empty repository emits one `clear`; ordering by code unit; boundary keys at and past the limit (valid keys round trip, invalid keys throw `ArgumentError` from `get`, `put` and `delete`, with no event); `clear` takes no key.
    - Watch: broadcast with two listeners; no replay for a late listener; events in order; stream completes on close; no stream error for corrupt entries.
    - Close: second `close` completes; each method throws `StateError` after close; closed check wins over key check; `watch` after close completes with no events; memory drops data.
    - Migration: lower with hook (called once with stored version and a copy), lower without hook, equal (hook not called), higher (entry untouched), missing version, invalid versions, throwing hook, hook mutating its argument leaves stored data unchanged, put after migrate stores the current version.
    - Corrupt entries: seed unparseable, non-object and codec-rejected entries; `get` and `getAll` skip them; one issue per skipped entry per read; entries unchanged; `put` over a corrupt entry emits `put`; `delete` of one emits `delete`; a throwing reporter is swallowed; the default reporter works; issue messages contain no payload marker.
    - Encoding: a non-JSON-safe encode result throws `ArgumentError`, leaves records and raw store unchanged and emits nothing; an `encode` that throws propagates unchanged and writes nothing.
    - Concurrency: calls made without awaiting apply in call order.
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.9, 3.2, 3.5, 3.6, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.1, 5.2, 5.3, 5.4, 6.6, 8.1, 8.4, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 9.9, 9.10, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.10, 14.1, 14.2, 14.3, 14.6_

  - [ ] 7.3 Write property test for rejected puts
    - Create `envelope_repository_property_test.dart` (pure, memory store, Chrome-run). `numRuns: 200`.
    - **Property 5: A rejected put changes nothing.** For any record whose codec returns an unsafe map, `put` fails with `ArgumentError`, `getAll` is unchanged, the raw store contents are unchanged and no event is emitted. (The Hive-backed variant of this check is an example test in task 10.2.)
    - **Validates: Requirements 6.6, 14.6**

  - [ ] 7.4 Write property test for the decode table
    - In `envelope_repository_property_test.dart`. `numRuns: 200`. Each run owns its repository and store.
    - **Property 7: Stored entries are decoded by the table, and only that.** For any seeded set of entries from the generator classes and any current version, with a counting migration hook: each entry reads as the decode table says; `get` returns null for skipped entries; `getAll` returns exactly the decodable records in key order; the reporter gets exactly one issue per skipped entry per read with the right kind and key; the hook is called exactly once with the stored version and a payload copy for lower versions; no issue message contains the unique payload marker string carried by each entry.
    - **Validates: Requirements 2.6, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7, 9.8, 10.1, 10.2, 10.3, 10.10**

  - [ ] 7.5 Write property test that reads change nothing
    - In `envelope_repository_property_test.dart`. `numRuns: 200`.
    - **Property 8: Reads change nothing.** For any seeded set of entries and any sequence of `get` and `getAll` calls, the raw store contents (every key and string) are identical before and after, for valid, outdated, newer and corrupt entries.
    - **Validates: Requirements 9.6, 9.9, 10.5**

  - [ ] 7.6 Write property test that put stores the current version
    - In `envelope_repository_property_test.dart`. `numRuns: 200`.
    - **Property 9: Put stores the current version.** For any record and current version, after `put` the raw envelope for the key has version equal to the current version and `get` returns an equal record, including when the key previously held an older or corrupt entry that was read first.
    - **Validates: Requirements 9.1, 9.10, 10.6**

- [ ] 8. Checkpoint - Pure layer verification
  - Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` in `packages/coffin_core`. Fix anything that fails.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 16.1, 16.2, 16.5_

- [ ] 9. Real-box test helper
  - [ ] 9.1 Create the shared Hive test helper
    - Create `test/storage/support/hive_test_box.dart` (VM only, imports `dart:io` and `hive_ce`) FIRST among the Hive tests. Expose `Future<HiveTestBox> openHiveTestBox()` returning the box, its unique name, its directory and a `dispose()`.
    - Names are unique, lowercase, ASCII and at most 255 characters: fixed prefix, monotonically increasing counter and a random lowercase hex suffix.
    - The directory comes from `Directory.systemTemp.createTemp('crypt_storage_')`. The box opens with `Hive.openBox<dynamic>(name, path: dir.path)`. Call no global `Hive.init`.
    - `dispose()` closes that specific box BEFORE deleting the directory with `recursive: true`, and is safe to call twice. Never call `Hive.close()` or `Hive.deleteBoxFromDisk`.
    - Add `hive_test_box_test.dart` (`@TestOn('vm')`): names are unique and valid, dispose closes then removes the directory, a second dispose is safe, dispose still removes the directory when the test body failed (use `addTearDown`).
    - _Requirements: 12.9, 7.6, 15.9_

  - [ ] 9.2 Write the box leakage test
    - Create `hive_box_isolation_test.dart` (`@TestOn('vm')`). Open two boxes with different unique names through the helper, put the same key with different values in each, and assert each returns only its own value, both before and after closing and reopening one of them (the reopen closes first).
    - If this test ever fails, STOP and tell the user before changing the helper.
    - _Requirements: 12.9, 7.1_

- [ ] 10. Hive implementation
  - [ ] 10.1 Implement `HiveRawStore`
    - Create `hive_raw_store.dart` (imports `hive_ce` only) with `HiveRawStore(Box<dynamic>)` and `static Future<HiveRawStore> open(String boxName, String? location)` that calls `Hive.openBox<dynamic>(name, path: location)`.
    - `read` returns the string, `''` for any other non-null value, null when absent. `keys()` returns `box.keys.whereType<String>()`. `remove` checks `containsKey` then `delete`. `removeAll` calls `box.clear()`. `close` closes the box and keeps the data. Register no adapters. Call no global initializer.
    - Add `hive_raw_store_test.dart` (`@TestOn('vm')`, uses the helper): read/write/remove/keys/removeAll, foreign non-String value reads as `''`, non-String keys not reported, close keeps data on disk.
    - _Requirements: 7.1, 7.2, 7.3, 7.5, 5.5, 15.9_

  - [ ] 10.2 Implement `HiveRecordRepository` and test it
    - Create `hive_record_repository.dart`, a `final class` extending `EnvelopeRepository<T>` that takes a `RawStore`. Its doc comment states that data is stored unencrypted and persists in the Hive box (IndexedDB on web).
    - Add `hive_record_repository_test.dart` (`@TestOn('vm')`, uses the helper): run the shared `repository_contract` body against a repository over a real box; Hive-backed variant of the rejected-put check (unsafe encode leaves raw box contents unchanged and emits nothing); migration and corrupt-entry cases through seeded raw box values; closed behavior (box closed, data kept).
    - Persistence test: put a record, close the repository, reopen at the SAME box name and directory, and `get` returns an equal record. This is the only same-name reuse. The box is closed before reopening and before the directory is deleted.
    - A store whose write throws: the exception propagates, nothing is emitted, later calls still work.
    - _Requirements: 7.1, 7.2, 7.4, 7.7, 7.8, 5.5, 3.3, 3.4, 14.1, 14.5, 14.6, 15.11_

  - [ ] 10.3 Write the validator-vs-real-box agreement test
    - Create `key_validator_hive_agreement_test.dart` (`@TestOn('vm')`, uses the helper, runs with the debug assert on).
    - Per row of the boundary table, assert the expected coffin verdict and the expected real-box outcome separately. For rows the validator accepts (B2, B3, B5, B6, B11): `put`, `get` and `box.keys` return the same key and record. For B4: `expectLater(() => box.put(...), throwsA(isA<HiveError>()))` (it throws synchronously). Rows B8, B9 and B10 are validator-only and are never written to a real box.
    - Add clearly named characterization tests for B1 (empty key) and B7 (`'x\u0080'`) showing Hive accepts them, so a future `hive_ce` change shows up as a failure.
    - Assert both directions of the reworded Req 3.8: every key the validator accepts works in a real box, and every key the real box rejects is also rejected by the validator.
    - _Requirements: 3.7, 3.8, 3.5, 3.6_

- [ ] 11. Opener and initializer
  - [ ] 11.1 Implement `OpenedRepository` and `StorageOpener`
    - Create `opened_repository.dart` and `storage_opener.dart` with `StorageInitializer`, `RawStoreOpener`, and `StorageOpener.open<T>` as in the design (`boxName`, `codec`, `currentVersion`, optional `location`, `migrate`, `repositoryIssues`).
    - The whole body sits in one `try`/`catch (Object)`. A bad box name (not lowercase-able ASCII or over 255) is checked first and takes the fallback path. On any failure return a `MemoryRecordRepository` with `isPersistent: false` and report exactly one `fallbackToMemory` issue whose message names the exception type but not its text. Success reports no issue. `open` never throws. `repositoryIssues` defaults to `reportIssue`.
    - Doc comment on `StorageOpener` states that data is stored unencrypted and must not hold secrets. Note that Hive lowercases box names.
    - Add `storage_opener_test.dart` (`@TestOn('vm')`): success with injected fakes, initializer failure, box-open failure, bad box name, exactly one `fallbackToMemory` report, no report on success, `isPersistent` values, the fallback repository works, a throwing reporter does not make `open` throw, and one real-store case using `HiveRawStore.open` with a unique name and a temp directory as `location` through the hygiene rules (no global `Hive.init`).
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 14.4, 15.11, 7.6_

  - [ ] 11.2 Implement `hiveFlutterInitializer`
    - Create `hive_flutter_initializer.dart`, the ONLY file that imports `hive_ce_flutter`. Signature `Future<void> hiveFlutterInitializer([String? subDir])`, calling `Hive.initFlutter(subDir)`.
    - The doc comment states that `hive_ce_flutter` registers the Flutter Color and TimeOfDay adapters (type ids 200 and 201), that coffin registers none of its own, that coffin boxes hold only JSON strings so those adapters are never used, that data is stored unencrypted, and recommends prefixed box names such as `hauntagotchi_ghosts`.
    - Add `hive_flutter_initializer_test.dart` checking the function has the `StorageInitializer` shape (a compile-time assignment). Do not call it in a unit test unless it runs cleanly on the test VM.
    - _Requirements: 7.4, 7.6, 7.9, 15.4, 15.11_

- [ ] 12. Model-based property test
  - [ ] 12.1 Write Property 6 (memory vs Hive vs plain Map)
    - Create `repository_model_property_test.dart` (`@TestOn('vm')`). Use an async glados body (design "Async smoke test result": glados 1.1.7 awaits async bodies).
    - **Property 6: Memory, Hive and a plain Map agree.** `ExploreConfig(numRuns: 100)`, sequences of at most 30 `Op`s, keys from the generator including B1 to B11. Apply each sequence to a `MemoryRecordRepository`, a `HiveRecordRepository` over a real box, and a `Map<String, TestNote>` reference model written independently of the engine (it validates keys with `KeyValidator`). After every op, assert that `get` for every touched key and `getAll` agree across the three in `String.compareTo` order, and that the events seen by `watch` on both repositories equal the model's expected events (`put` always, `delete` only if present, `clear` always, none for a rejected op). An invalid key makes all three throw `ArgumentError`, leaves state unchanged and emits nothing. Run each sequence in both modes: awaiting each call, and firing all calls first then awaiting them together; both give the same final state and events.
    - Each run owns its repositories, unique box name, box and temp directory (via `openHiveTestBox`), disposed in `finally` with the box closed before the directory is deleted. Share nothing between runs, because glados re-runs a failed body once without awaiting it.
    - Non-vacuous counters: top-level `runsExecuted` and `opsExecuted` incremented inside the body. A plain `test('model test really ran', ...)` declared after the glados test in the same group asserts `runsExecuted == 100` and `opsExecuted > 0`.
    - Wrap the body in `try`/`catch` and rethrow `TestFailure('... after op N of [put("a", ...), delete("b"), ...]: <original>')` so the operation sequence is in the failure output.
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.7, 2.8, 2.9, 2.10, 3.2, 3.3, 3.4, 4.2, 4.3, 4.4, 7.7, 8.1, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 12.10, 12.11, 13.1, 13.2, 13.3**

- [ ] 13. Barrel and source scans
  - [ ] 13.1 Export the storage API from the barrel
    - Edit `packages/coffin_core/lib/coffin_core.dart`, keeping every existing export. Add `show` exports for exactly the names the design lists: `hiveFlutterInitializer`, `IssueReporter`, `discardIssues`, `JsonMap`, `KeyValidator`, `MemoryRecordRepository`, `MigrationHook`, `OpenedRepository`, `RecordCodec`, `RecordRepository`, `StorageEvent`, `StorageEventKind`, `StorageIssue`, `StorageIssueKind`, `StorageInitializer`, `StorageOpener`.
    - Do not export `RawStore`, `RawStoreOpener`, `MemoryRawStore`, `HiveRawStore`, `EnvelopeRepository`, `HiveRecordRepository`, `OperationQueue`, `Envelope`, `EnvelopeCodec`, `JsonSafety` or `reportSafely`. No Hive type or Hive-aware class is exported except the initializer.
    - _Requirements: 15.3, 1.4, 7.9_

  - [ ] 13.2 Write barrel and source-scan tests
    - Create `storage_sources_test.dart` (`@TestOn('vm')`, resolves repo paths relative to the test file location so it works from any working directory).
    - Barrel: importing only `package:coffin_core/coffin_core.dart` gives access to every exported storage name; the barrel uses `show` for every storage export; none of the non-exported names listed in 13.1 are exported.
    - Imports: the pure storage files import no `package:flutter/` and no `package:hive_ce`; only `hive_raw_store.dart` imports `hive_ce`; only `hive_flutter_initializer.dart` imports `hive_ce_flutter`; nothing under `lib/src/storage` imports `apps/`, `package:hauntagotchi` or `package:graveyard`.
    - Chrome rule: every file in the Chrome-run list from the design imports no `dart:io`, no `package:hive_ce`, no `package:hive_ce_flutter`, not `support/hive_test_box.dart`, and carries no `@TestOn('vm')`.
    - Structure: each file under `lib/src/storage` declares at most one public class (and the typedef-only files are exempt); no `TypeAdapter`, `registerAdapter`, `encryptionCipher`, `HiveAesCipher` or encryption package appears in `lib/src/storage` or in the coffin_core pubspec; no Riverpod, AI or routing import in `lib/src/storage`.
    - Packages: `coffin_core/pubspec.yaml` pins `hive_ce: 2.23.3`, `hive_ce_flutter: 2.3.4` and `meta: 1.19.0` exactly (no caret); no pubspec in the repo lists `hive_ce_generator` or `build_runner`; neither app pubspec lists `hive_ce`, `hive_ce_flutter`; no `*.g.dart` file exists under `packages/` or `apps/` (ignoring `.dart_tool` and `build`); no file under `apps/*/lib` or `apps/*/test` references the storage API names (`StorageOpener`, `RecordRepository`, `hiveFlutterInitializer`, `MemoryRecordRepository`).
    - _Requirements: 1.4, 6.8, 7.3, 7.9, 12.10, 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 15.7, 15.8, 15.10, 16.3, 16.6, 16.7_

- [ ] 14. Checkpoint - Storage layer verification
  - Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` in `packages/coffin_core`. Fix anything that fails.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 16.1, 16.2, 16.4, 16.5_

- [ ] 15. Timing report
  - [ ] 15.1 Measure the storage test run time
    - In `packages/coffin_core`, run `flutter test test/storage` and measure total wall-clock time (for example with the shell `time` builtin, with an explicit timeout of 1800000 ms). Also note the slowest files (run `--reporter expanded` or time the heavy files separately: `repository_model_property_test.dart`, `envelope_repository_property_test.dart`, `key_validator_hive_agreement_test.dart`).
    - Report the total and the slowest files to the user in the task summary.
    - If the total exceeds about 60 seconds, STOP and tell the user the timing BEFORE lowering any run count or sequence length. Wait for their decision. Never lower counts silently.
    - _Requirements: 12.4, 16.4, 16.5_

- [ ] 16. Chrome run of the pure storage tests
  - [ ] 16.1 Run the pure storage tests on the web runner
    - First check that Chrome is available (`flutter devices` lists Chrome, or `flutter doctor`). If it is not, REPORT that the Chrome step could not run and why. Do not skip silently and do not mark the step as passed.
    - In `packages/coffin_core`, run `flutter test --platform chrome` with exactly this file list from the design: `test/storage/key_validator_test.dart`, `test/storage/key_validator_property_test.dart`, `test/storage/json_safety_test.dart`, `test/storage/json_safety_property_test.dart`, `test/storage/envelope_codec_test.dart`, `test/storage/envelope_codec_property_test.dart`, `test/storage/record_codec_property_test.dart`, `test/storage/storage_event_test.dart`, `test/storage/storage_issue_test.dart`, `test/storage/issue_reporter_test.dart`, `test/storage/operation_queue_test.dart`, `test/storage/memory_raw_store_test.dart`, `test/storage/memory_record_repository_test.dart`, `test/storage/envelope_repository_property_test.dart`.
    - If glados or any file fails to compile or run on the web runner, report the exact failure to the user. Do not drop the file, do not weaken tests, and do not lower run counts. If the run is slow, the timing rule from task 15 applies.
    - Report what the Chrome run does and does not cover: it checks the VM/web number differences (integral versions, the 2^53 limit) but not IndexedDB itself.
    - _Requirements: 6.5, 9.7, 12.2, 16.4, 16.5_

- [ ] 17. Final verification
  - [ ] 17.1 Format, analyze and test everything
    - Run `dart format --set-exit-if-changed .`, `flutter analyze` (zero warnings) and `flutter test` in `packages/coffin_core`, `apps/hauntagotchi` and `apps/graveyard`. All must be clean and passing.
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_

  - [ ] 17.2 Build both apps for the web
    - Run `flutter build web` in `apps/hauntagotchi` and in `apps/graveyard`, even though neither imports storage, because the barrel now brings `hive_ce` and `hive_ce_flutter` into the compile graph. Report success or the exact failure. Do not edit the design to work around a failure.
    - _Requirements: 16.9, 15.7_

  - [ ] 17.3 Confirm cleanliness and scope
    - List `crypt_storage_*` under `Directory.systemTemp` (read-only check) and confirm no directories created by the tests remain. If any remain, report them and find which test leaked; do not delete anything outside the repo without telling the user.
    - Run `git status --short` and confirm only expected files changed: `.kiro/specs/crypt-storage/`, `packages/coffin_core/pubspec.yaml`, `pubspec.lock`, `packages/coffin_core/lib/coffin_core.dart`, `packages/coffin_core/lib/src/storage/` and `packages/coffin_core/test/storage/`. Confirm no app files, `DIARY.md`, secrets or `*.g.dart` files changed or were added, and that nothing outside the repository was created or edited.
    - In the final message, state plainly what was not verified: real IndexedDB behavior in a browser, private-browsing failures, quota errors, and the manual web check that a later app spec should add.
    - _Requirements: 12.9, 15.6, 15.7, 15.9, 16.8_

- [ ] 18. Final checkpoint - Full workspace verification
  - Confirm `hive_ce` 2.23.3, `hive_ce_flutter` 2.3.4 and `meta` 1.19.0 are the only dependency changes and that the lockfile gained only packages from the design's expected list.
  - Ensure all tests pass, ask the user if questions arise.
  - _Requirements: 16.1, 16.2, 16.5, 16.6, 16.9_

## Notes

- All tasks are required. Unit tests and property tests are required because the tech steering says pure logic and numeric invariants must be tested.
- Property tests use glados 1.1.7 (already a dev dependency of `coffin_core`). Property 6 runs 100 times with at most 30 operations; Properties 1 to 5 and 7 to 9 run 200 times.
- Property mapping: 1 in task 6.2, 2 in 4.4, 3 in 3.2, 4 in 4.2, 5 in 7.3, 6 in 12.1, 7 in 7.4, 8 in 7.5, 9 in 7.6.
- Requirement coverage: 1 (2.1, 13.1), 2 (7.1, 7.2, 12.1), 3 (3.1, 10.3), 4 (2.2, 7.1), 5 (7.2, 10.2), 6 (4.1 to 4.4), 7 (10.1, 10.2, 11.2), 8 (5.2, 7.1), 9 (7.1, 7.4 to 7.6), 10 (7.1, 7.2, 7.4), 11 (11.1), 12 (6.1, 12.1), 13 (12.1), 14 (7.2, 10.2, 11.1), 15 (13.1, 13.2), 16 (1.1, 17.1 to 17.3).
- The pure layer (tasks 2 to 7) must stay free of Flutter and `hive_ce` imports. Task 13.2 enforces that with a source scan.
- Task 1.1 and task 9.2 are hard stops: if the dry-run lists an unexpected package, or the leakage test fails, work stops and the user decides.
- Tasks 15.1 and 16.1 report and stop rather than weaken tests.
- The workflow ends once these tasks exist. Open `tasks.md` and start tasks from there. No implementation has been started.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "3.1", "4.1", "4.3", "5.1"] },
    { "id": 3, "tasks": ["3.2", "4.2", "4.4", "5.2", "6.1"] },
    { "id": 4, "tasks": ["6.2", "7.1"] },
    { "id": 5, "tasks": ["7.2", "7.3", "7.4", "7.5", "7.6"] },
    { "id": 6, "tasks": ["9.1"] },
    { "id": 7, "tasks": ["9.2", "10.1"] },
    { "id": 8, "tasks": ["10.2", "10.3"] },
    { "id": 9, "tasks": ["11.1", "11.2"] },
    { "id": 10, "tasks": ["12.1"] },
    { "id": 11, "tasks": ["13.1"] },
    { "id": 12, "tasks": ["13.2"] },
    { "id": 13, "tasks": ["15.1"] },
    { "id": 14, "tasks": ["16.1"] },
    { "id": 15, "tasks": ["17.1"] },
    { "id": 16, "tasks": ["17.2", "17.3"] }
  ]
}
```
