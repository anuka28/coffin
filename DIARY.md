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
- **Kiro CLI:** installed `kiro-cli` 3.1.0 with one curl command and logged in with the same Google account, so it shares my Kiroween credits. It has `chat`, `agent`, `mcp`, `powers` and even a `crew` command. Will try it on a real task later.
