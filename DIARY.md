# Coffin — Build Diary 💀

A few lines per day: what I asked Kiro, what worked, what didn't, what I learned. This becomes the Kiro write-up and the blog post.

---

## Day 1 · Nov 7, 2026
- Registered for Kiroween 2026, picked the **Skeleton Crew** category.
- Installed Kiro IDE, requested hackathon credits, created the `coffin` repo (MIT).
- Plan: a Flutter starter kit (`coffin_core`) + two apps on it, Hauntagotchi and Graveyard.

## Day 2 · Nov 7, 2026 (started a day early)
- Opened the project in Kiro.
- Added steering docs: product, tech, structure, design.
- Notes / first impressions of Kiro:
  - Kiro opened the folder in Restricted Mode at first. I had to trust it before agents and hooks would work, and reload the window before my steering docs showed up under "Workspace".
  - Steering works automatically: when I asked Kiro to summarize the project rules, the reply showed "Included Steering" and covered all 4 docs (tech, structure, product, design) without me pointing it to them.
  - The Kiro panel puts Specs, Agent Hooks, Steering and MCP Servers in one place, and there are built-in agents (Spec, Plan, Bug Fix, Quick Spec). I'll use Spec from Day 3.

## Day 3 · Nov 9, 2026
- **Credits:** my first credit request was rejected because the description didn't name the category. Resubmitted with "Category: Skeleton Crew", passed eligibility and the ID check. Working on the free 50 credits until the code arrives.
- **MCP:** connected the official Dart MCP server (`dart mcp-server`) in `.kiro/settings/mcp.json`. Kiro shows it as connected with 14 tools (analyze, hot reload, pub.dev search, widget inspector…).
- **First spec: `workspace-setup`** (Dart pub workspace with `coffin_core` + 2 apps).
  - Even in Spec mode, Kiro first said it would "set up the monorepo directly". I stopped it and asked for the full requirements → design → tasks flow with approval at each step. Lesson: be explicit when you want the full spec workflow.
  - Requirements came out in EARS format (WHEN … THE … SHALL). In review I caught 3 technical issues before any code existed: empty folders aren't tracked by Git (needed `.gitkeep`), `flutter test` doesn't recurse into pub workspace members, and lint config is shared via `include:`, not via pubspec. Fixing these on paper was much cheaper than debugging later. This is the clearest win of spec-driven vs vibe coding so far.
  - Design used the official pub workspace pattern (`name: _` root, `resolution: workspace`). I added `--no-pub` to `flutter create` so no stray lock files land inside the apps.
  - Design correctly said property-based testing doesn't apply yet (no pure logic in a scaffold). PBT comes with ghost health and séance scoring.
  - Tasks marked the test tasks as optional (`*`), which contradicted Requirement 11 (a passing test in every member). I had them made required.
  - Kiro's spec subagent sometimes failed to save files to disk. The main agent noticed, verified, and rewrote them directly.
  - Whole spec (3 docs + revisions) cost about 1.85 credits.
- Committed the spec **before** writing any code, so the Git history shows plan first, build second.

## Day 4 · Nov 10, 2026
- **Credits arrived:** redeemed the 4,000 Kiroween credits. The stuck session yesterday had already used ~28 of my 50 free credits, so watch long-running sessions.
- **Running the tasks:** Kiro used the task dependency graph in `tasks.md` to run independent tasks in parallel (e.g. 1.1, 1.2, 1.3 as 3 sub-agents at once, and both `flutter create` steps early).
- **Sub-agent trouble:** on group 2 the sub-agents kept timing out and retrying for 3½ hours, and task 2.2 showed "Error implementing task". I checked the disk: the files were actually there and correct; only the status tracking broke. I cancelled, started a fresh session and told Kiro to verify the existing files and work directly without sub-agents. That worked.
- **Caught a gap in the plan:** even with `--no-pub`, `flutter create` left a `pubspec.lock` and `.iml` file in each app. Workspace members must not have their own lock file. I asked Kiro to add the cleanup, and it **updated tasks 3.4 and 4.4 in the spec** first, so the correction is recorded, not just done silently.
- **Kiro made good judgement calls:** it left an unused import out of `main.dart` (the design listed it, but it would have caused a lint warning), and it reported what it had and hadn't verified instead of claiming everything was done.
- **Result:** workspace-setup spec 100% complete. `flutter analyze`: no issues. `dart format`: clean. 3/3 widget tests pass (one per member). Both apps have a web shell.
- Cost of running all tasks: roughly 6 credits (plus the ~28 lost to the stuck session).
- Ran both apps in Chrome: Hauntagotchi and Graveyard both show the shared `CoffinMark` from `coffin_core`. First light!
- **Hook #1** ("Format + analyze Dart on save"): built with the hook form as a **Run Command** hook (trigger File Saved, matcher `\.dart$`, command `dart format packages apps && flutter analyze`), so it costs no credits per save.
  - It didn't fire. First cause: Kiro only loads new hooks at session start, so I had to reload the window (the log went from `registered: 0` to `registered: 1`).
  - It still didn't fire after reloading. Kiro suggested a debug hook that just appends the date and stdin to a log file; after another reload both hooks were registered, but a manual Cmd+S never created the log. So in this Kiro version, PostFileSave command hooks don't seem to run on manual editor saves. Reported it to the Kiro team; will try other trigger types next.
- **Second spec: `haunted-theme`** (color tokens, dark/light themes, fonts, glow helper).
  - I checked the palette's contrast myself before approving. All night text colors pass 4.5:1 on every background, but the requirements only tested text on *backgrounds*, not labels on *buttons*: bone-white on the purple button is only 2.9:1. Had Kiro add the "on" colors (onPrimary etc.) to the property-based contrast test, or we'd have shipped unreadable buttons with a passing test.
  - Asked for bundled fonts (Creepster + Outfit, both SIL OFL) instead of runtime downloads. In design, Kiro read the `google_fonts` source and found it throws an unhandled async error when a font is missing offline, so it recommended dropping the package and declaring the fonts in pubspec instead. One less dependency, fully offline.
  - Design defines 6 correctness properties (contrast pairs, contrast symmetry, glow shape, clamping, glow monotonicity, determinism) for glados, and explains why the rest gets example tests.
  - While running the theme tasks, the chat showed "1 hook triggered" when Kiro's agent wrote a Dart file. So my format + analyze hook *does* fire, just on the agent's file writes rather than my manual Cmd+S. That's actually the case that matters most: everything Kiro writes gets formatted and analyzed automatically.
  - Tasks 1–10 (the whole `coffin_core` theme) done in ~18 minutes, ~36 credits. I verified independently: `dart format` clean, `flutter analyze` no issues, **96 tests pass**, including 6 glados property tests at 200 runs each.
  - Kiro reported that one sub-agent had made a "no-op edit" to the glados package in my shared pub cache. I didn't just trust that: I downloaded the official glados 1.1.7 archive from pub.dev and diffed it. Identical, so no harm done. Lesson: agents can touch files outside the repo, so check when they tell you.
  - Tasks 11–13: both apps now use `CoffinTheme.dark()` with a glowing `CoffinMark`, a Creepster title and Outfit body copy. Kiro ran `flutter build web` and confirmed both font families are in `FontManifest.json`, which settled the one claim the design had left unverified. This time I told it not to touch anything outside the repo, and nothing was. Verified: analyze clean, 96 + 5 + 4 tests pass. ~10 credits.
- **Third spec: `fog-router`** (go_router helper, fog page transition, reduced motion, spooky 404 page).
  - In design, Kiro dry-ran both go_router versions and found that 18.x silently fails to recognise the framework `MaterialApp` and pulls in 4 extra packages, so it recommended pinning 17.5.0. I agreed, and asked for `FadeTransition` instead of rebuilding an `Opacity` widget every frame (cheaper on web).
  - The hook now visibly fires ("Run Command Hook: Format + analyze Dart on save") on every Dart file Kiro writes.
  - A widget test failed: it expected opacity 0.25 at 25% progress but got 0.129. The code was right (the transition uses an ease-in-out curve); the test assumed a straight line. Kiro fixed the test, not the code.
  - Kiro wrote a scratch file to `/tmp`, noticed that broke the "stay inside the repo" rule, deleted it and redid the step inside the repo, and told me. Good self-correction, and I verified it was gone.
  - Turned Autopilot on for task execution after approving the spec, since I verify at each checkpoint anyway.
  - Task 7 checkpoint, verified myself: format clean, analyze no issues, **197 tests pass** in coffin_core (7 new glados properties at 200 runs each). ~14 credits, 33 minutes.
  - Tasks 8–10: both apps now run through `MaterialApp.router` with the fog router. Built for web and served with a plain static server: `localhost:8080/#/nowhere` shows "THIS PAGE HAS PASSED ON…" with a tombstone glow, and the button fades home. No server rewrites needed. The server log showed the fonts loading from my bundled files, never from Google.
  - The 404 button has **dark text on purple**: that's the contrast catch from the theme spec, visible in the real app.
  - **Taste call:** in the browser the 450 ms fog felt a bit fast. No test could tell me that. I had Kiro raise the default to 600 ms (the top of my design rules), updating code, tests and design.md together. Much better.
- **Fourth spec: `crypt-storage`** (generic record repository, hive_ce + in-memory, schema versions and migrations, corrupt-record handling, fallback when storage is blocked).
  - The first save glitched again: Kiro showed me requirements that were never written to disk. Caught it when Kiro said the folder was empty; it regenerated them with my changes.
  - I assumed Hive keys must be ASCII and ≤255 chars. Kiro read the hive_ce source and found something worse: Hive accepts any characters, but stores the key length in **one byte of UTF-8**, and only checks the limit in debug builds. A long non-ASCII key would silently corrupt the file in release. So Coffin's `KeyValidator` is a deliberately stricter subset (non-empty, ≤255, ASCII), shared by both repositories and tested against a real box.
  - Asked Kiro to prove glados actually awaits async test bodies before trusting a model-based test. It ran a deliberately failing async test: it does, with a quirk (glados re-runs the body once without awaiting), which shaped the test design.
  - I spotted that Hive caches open boxes globally by name, so property-test runs could silently share a box. Every run now uses a unique box name, and Kiro added a leakage test to prove boxes stay independent.
  - **The dependency gate worked:** task 1 was a `pub add --dry-run` that had to match an expected package list. It found 4 extras (`jni`, `jni_flutter`, `objective_c`, `hooks`, all from path_provider's native Android/iOS code) and **stopped instead of adding them**. Kiro admitted it had only followed dependencies one level deep. I approved them, since any Flutter app saving data on mobile uses path_provider, and they're unused on web.
  - Task 8 checkpoint, verified myself: format clean, analyze no issues, **397 tests pass** in coffin_core. Pure layer done (no Hive imports yet). ~84 credits, 52 min, the most expensive run so far.

- **Kiro CLI:** installed `kiro-cli` 3.1.0 with one curl command and logged in with the same Google account, so it shares my Kiroween credits. It has `chat`, `agent`, `mcp`, `powers` and even a `crew` command.
  - First real task: had the CLI rewrite `README.md` from the repo root. It asked to trust the workspace (like the IDE did), picked up my steering docs, checked its claims against the actual files, and honestly said storage and AI aren't built yet. 36 seconds, 0.91 credits.
  - Review caught a copy-paste bug: the test commands used chained `cd`s that break when pasted in sequence. Asked the CLI to fix it (now each line is a `(cd … && …)` subshell) and to say "my" not "our" (solo entry). I ran the README's test commands exactly as written: 197 + 9 + 8 pass.
  - IDE vs CLI, my take: 

## Day 5 · Nov 13–15, 2026
- Ran crypt-storage tasks 9–12 on my own: the real-box test helper, `HiveRawStore`/`HiveRecordRepository`, the `StorageOpener` with in-memory fallback, and the **model-based property test** (100 random runs of put/delete/clear against memory, a real Hive box and a plain Dart `Map`, in both sequential and concurrent modes).
  - The model test can't pass vacuously: a follow-up test asserts the body ran exactly 100 times and saw more than 0 operations.
  - Box isolation holds: 200 box opens, 0 temp directories left behind, and the leakage test passes.
  - Verified afterwards: format clean, analyze no issues, **476 tests pass** in about 8 seconds. ~7.5 credits.
- Tasks 13–18 finished the storage spec: barrel exports (no Hive type leaks into the public API), source-scan tests that also assert they found files (so a wrong path can't make them pass by finding nothing), a secrets scan (clean), and a timing check.
  - The three older property files used glados generators that break on web (`1 << 32` is 0 in JavaScript). Kiro made them web-safe instead of dropping them. I ran the 14 pure storage test files in a real Chrome myself: **138 pass**, including all property tests at 200 runs.
  - **crypt-storage complete.** Verified: format clean, analyze no issues, coffin_core **499** + Hauntagotchi 9 + Graveyard 8 tests pass. ~33 credits for tasks 13–18.
  - Still to check by hand once an app uses storage: save a record in Chrome and reload (real IndexedDB), then repeat in a private window (memory fallback + reported issue).

## Day 7 · Nov 15–16, 2026
- **Key decision for the AI layer:** judges open the app by URL, so an API key in a Flutter web app would be visible to anyone. Plan: step 1 is a provider-agnostic `CoffinAI` with an offline template generator and a fallback wrapper (no network, no keys); step 2 adds a tiny proxy (e.g. a Cloudflare Worker) that holds the key with a rate limit and spend cap, falling back to offline if it's down.
- **Fifth spec: `coffin-ai`.** In review I added two things: banned words can form *across* a template and a name ("…go" + "re…" = "gore"), so the generator needs a deterministic recovery (drop the name, then next template, then a pre-verified safe line); and Purpose became an open type so each app can add its own purposes without touching coffin_core.
  - Kiro's research, run on both VM and Chrome: seeded `Random` matched, but Dart doesn't promise that, so it uses its own Mulberry32 generator. Several glados generators break in JavaScript, so it built web-safe copies. `Future.delayed(Duration.zero)` is ~180× slower in Chrome, so tests pump microtasks instead.
  - I reviewed the 24 lines of template copy for tone ("Not gone, just napping.", "Every great haunting starts with one small commit.", "The pumpkins say hi. 🎃").
  - Kiro caught a bug the design missed: equal requests could hash differently for `5` vs `5.0` on the VM.
  - Task 7 checkpoint, verified myself: format clean, analyze no issues, **331 AI tests pass on the VM and the same 331 in Chrome**; coffin_core total **830**. No clock, URL, HTTP, `dart:io` or unseeded `Random` in `lib/src/ai`, and nothing changed outside the AI folders.
- Golden-table tone read: the 11 sample texts read well, but row 10 showed every brand-new user would see "0 days so far. The moon approves." on day one. Changed the rule so a count of 0 is treated as missing for count templates; that row now reads "… waits by the window, glowing softly." A tiny change that fixes the app's first impression, and no test could have flagged it.
- Kiro stalled once (it was running tasks in parallel) and twice marked tasks done before doing them; it reopened them itself. I asked it to go one task at a time, which worked. An editor tab holding a stale copy of a test file triggered a "Failed to save… content is newer" prompt; I discarded the stale copy instead of overwriting Kiro's newer file.
- Task 10 checkpoint, verified myself: format clean, analyze no issues, coffin_core **942 tests** on the VM; the **443 AI tests pass in Chrome** in ~41 s. No stray files.
- The timing gate fired: the Chrome run of the AI tests took 68.6 s against a 60 s limit, and Kiro stopped to ask instead of lowering run counts. ~17 s is Chrome and compiler startup, and the everyday VM run is 9.3 s, so I accepted it: raised the Chrome limit to 90 s and kept every run count, since web coverage is what caught the JavaScript number bugs in crypt-storage. Kiro also found its own Chrome file list was missing a test file.
- **coffin-ai complete** (commit 2adf440; tasks 11–16 took ~11 credits and 11 min). Verified: all 16 tasks done, format clean, analyze no issues, coffin_core **985** + Hauntagotchi 9 + Graveyard 8 tests pass. No new packages; the barrel adds 13 AI exports; no secrets or URLs in the code.
- Not yet covered: a real remote provider. That's step 2, a small proxy that holds the API key.
- Started recording a short screen clip at each milestone for the demo video. First one: the coffin-ai spec (requirements → design → tasks) and `flutter test` ending on 985 passing.

## Day 8 · Nov 16, 2026 (a day early)
- **Sixth spec: `spooky-widgets`** (GhostLoader, TombstoneCard, FlickerText, FogBackground + a CryptGallery page at `/#/gallery` in Hauntagotchi). Requirements ~6.5 credits, design ~27, tasks ~19.5.
  - My review answers: move `SeededRandom` to a shared `lib/src/common/` (Graveyard and Hauntagotchi will need it too); keep the gallery in coffin_core because it's the kit's showcase; readability beats fog visibility.
  - Kiro computed real WCAG contrast before choosing numbers: fog alpha came down from 0.03–0.08 to 0.03–0.05 because night muted text dropped to 4.49 at 5.5%. It also found that `ShapeDecoration` already draws shadows along any shape, so the tombstone glow needed no `CoffinGlow` change.
  - It flagged honestly that moving `SeededRandom` needs one non-import edit to the coffin-ai source scan (one allow-list branch for one file); approved.
  - Ghost colour: bone white in night with a purple glow, purple in daylight (contrast 15.99 and 5.84).
  - Kiro's spec sub-agent wrote one temp file to `/tmp` while computing contrast and reported it itself; I checked and nothing was left behind.
- Task 1 (move `SeededRandom` to `lib/src/common/`): byte-identical move, only import paths changed plus the one approved scan branch; still exactly 985 tests. ~5 credits.
  - Git lesson: Kiro had *staged* the renames, and the Commit button then committed only the staged files, so commit 1cbbc0d has the moves without the import fixes (it doesn't build on its own). The next commit completes it. Now I check for a "Staged Changes" section before committing.
- Tasks 2–3, Checkpoint A: pure math (`PingPong`, `GhostBob`, `FlickerSchedule`, `FogField`) with glados property tests. Verified myself: format clean, analyze no issues, coffin_core **1,077 tests** on the VM and **106 pure tests pass in Chrome**. No Flutter, `dart:math`, `sin`/`cos` or unseeded `Random` in the math files. ~44 credits, 27 min.
  - Dimmest flicker frame still has 7.05:1 contrast (4.5 needed). Kiro replaced test-generator loop periods the design never uses with the real ones, and checked seed masking against actual web behaviour instead of against itself.
  - Asked Kiro to remove three debug `print()`s from the tests to keep the output (and my video clips) clean.
- Task 4.2 question from Kiro: `SpookyTokens.of` had a "no theme matched, use night" fallback that can never run (brightness is only light or dark). Instead of keeping dead code or changing the API just to test it, I chose a Dart exhaustive `switch` on brightness, so the compiler guarantees both cases.
- Tasks 4–5, Checkpoint B: the widgets exist. `GhostPainter` + `GhostLoader`, `TombstoneBorder` + `TombstoneCard`, `FlickerText`, `FogBackground`, a shared `MotionLoop` for reduced motion and dispose, and a VM-only source scan (no hard-coded colors). Verified myself: format clean, analyze no issues, coffin_core **1,263 tests**, Hauntagotchi 9. ~39 credits, 22 min.
  - Kiro's departures from the design, all reasonable: the tombstone clips only its scrolling content, not its decoration, otherwise the clip would cut off the glow; the hover tests switch Flutter to mouse-style highlighting because the test environment behaves like a touch device; one fog semantics test was wrong (not the widget) and was rewritten.
  - Another `/tmp` slip while debugging (an empty `/tmp/x` plus a debug test file in the repo). Kiro reported it and cleaned up; I confirmed both are gone.
- Tasks 6–7: `CryptGallery` (night and daylight panels side by side from 900 px), barrel exports for the six public widgets, and the Hauntagotchi `/gallery` route. **spooky-widgets complete.** Verified myself: format clean, analyze no issues in all three packages, coffin_core **1,285** + Hauntagotchi **12** + Graveyard 8 tests pass; no pubspec changes, nothing outside the repo. ~23 credits for this part, roughly 150 for the whole spec.
  - Kiro wrote its own copy for the gallery ("Every haunt we own, by moonlight and by day.", "Fog drifts past the gate.", and on tapping a tombstone: "The grave stirs, but nothing rises. Yet.").
  - Kiro was clear about what tests can't check: look, tone and motion feel need a human in a real browser.
- **First look in Chrome** at `/#/gallery`: it works (the ghost bobs, the tombstone glows, the snackbar shows), but the tombstones looked like loaves of bread, the fog was a few smudges, the Night panel had no frame, and the snackbar was Material-default lavender.
- **First vibe-coding session** (Kiro "Default" mode, not a spec), because this was visual polish rather than a feature: taller, narrower tombstones (300 px max, portrait with a child), larger and softer fog blobs, framed panels on both sides, and a themed floating snackbar. Kiro updated the spec docs and pinned test values to match (changed expected values, weakened none) and recomputed the fog alpha cap with `WcagContrast` (0.03–0.04 now, worst case 4.65:1). coffin_core **1,289 tests** pass. ~10 credits, 8 min.
  - My take on spec vs vibe: specs for anything with rules or logic, vibe for "make it look right" after a human has looked at it.
  - Kiro left an empty `/tmp/x` directory again, even though the prompt said not to. I removed it.
- Looked again in Chrome after the polish: the tombstones now read as gravestones, the fog reads as mist, and both panels are framed. Small follow-up vibe request: an engraved "R.I.P." in the tombstone arch (muted, Creepster 20 px, hidden from screen readers, `showEpitaph` flag). ~3.5 credits; coffin_core **1,293 tests**. (It landed in commit f59ece4, which reused the previous polish message by mistake.)
  - I accidentally sent the same prompt twice. Kiro noticed the work was already done, changed nothing and said so (0.65 credits).

## Day 9 · Nov 17, 2026 (a day early)
- **Kiro Crew** (desktop, v0.12.2 stable, not the rc). Skipped its offer to import my Claude Code / Gemini setup, so it works only from the repo's own Kiro steering and none of my other (client) projects' context leaks in.
- First Crew job: **Nightly Build Watch**, a scheduled (9 PM daily) **read-only** agent that runs format, analyze and tests in coffin_core, Hauntagotchi and Graveyard and reports a table, suggesting fixes as text only.
  - First run (manual): every package green: coffin_core 1,293, Hauntagotchi 12, Graveyard 8. It also found `dart`/`flutter` weren't on its PATH and used the Flutter SDK's own bin folder, and it noticed my uncommitted DIARY.md.
  - It asked for approval before running each command, even from a schedule. Good for safety, but an unattended 9 PM run will wait for a click.
  - I checked afterwards: same commit, same `git status`, same ignored files, `/tmp` unchanged. Crew kept to read-only.
  - IDE vs Crew, my take: the IDE is where I build with Kiro; Crew keeps watch while I'm away.
- Housekeeping: found a leftover `/tmp/l.dart` from a coffin-ai run on Nov 16 (Kiro measuring a template line's length) and removed it.
- **Seventh spec: `raise-app`**, the Kiro-native starter: `dart run tool/raise.dart <name>` creates `apps/<name>/` already wired to coffin_core, with its own `.kiro/` (steering, format hook, a README on writing the first spec). ~11 credits for requirements, ~9.5 for design, ~5 for tasks.
  - My review: make `tool/` a real workspace package (`coffin_raise`) instead of working around the resolver; copy `design.md` byte for byte with a drift test; tag the slow "raise a real app and run analyze + test" check so everyday runs stay fast (it will also go into the Crew nightly job).
  - What I caught: a raised app's `.kiro/` only loads when you open that app's folder in Kiro, not the repo root. Now stated in the app README, the success message (with a test) and the root README.
  - What I caught in the task list: Kiro had marked every test task optional (`*`). I made them all required, and removed a task that would have had Kiro write in this diary.
  - Kiro verified uncertain tool behaviour on a throwaway copy before designing around it (`exclude_tags` can't combine with `--tags`, so it uses `skip:` + `--run-skipped`).
- raise-app tasks 1–10 (checkpoint): `tool/` joined the workspace with exactly one line in the root `pubspec.yaml` and no lockfile change. Then the pure name rules, template renderer, workspace editor, planner, the disk layer with rollback, and the CLI. Verified myself: `tool` **91 tests**, coffin_core 1,293 (twice), Hauntagotchi 12, Graveyard 8; format and analyze clean; nothing under `apps/` or `packages/` changed. ~49 credits up to 7.1, plus the rest.
  - **A property test caught a real bug.** If the disk failed *after* the root `pubspec.yaml` replace had already gone through, the rollback skipped restoring it, leaving a workspace entry for an app folder that had been deleted. Kiro offered to narrow the test or fix the code; I chose to fix the code (a "replace attempted" flag, always restore) and kept the test exactly as written.
  - A Kiro sub-agent wrote a test file outside the repo (`Kiroween/test/plan/`). Kiro reported and removed it, then switched to absolute paths. It also moved the test temp roots from `/tmp` into a git-ignored `tool/.test_tmp/`. I checked the parent folder: clean.
  - One coffin_core run failed to load a test file while running in parallel with the tool tests; sequential reruns passed. Probably resource contention, but I'm watching for it in the Crew nightly runs.
- **raise-app complete** (tasks 11–13): the end-to-end raise-check (raise a real app into a temporary workspace, then `pub get`, format, analyze with zero issues, and test) passes in about 10 s. Default runs skip it, and `flutter test --tags raise-check --run-skipped` runs it. Root README gained a "Raise a new app" section; CREDITS lists the Flutter default web icons (BSD-3). Verified myself: `tool` 91 tests + raise-check, coffin_core 1,293, Hauntagotchi 12, Graveyard 8, format and analyze clean. ~9 credits for the last part.
  - Kiro wrote three test-output logs to `/tmp` again (`core_test.txt` and two others) despite the instruction. I removed them. Lesson: the "nothing outside the repo" rule needs repeating in every prompt, and checking afterwards.
