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

