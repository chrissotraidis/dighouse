# Dighouse handoff

Rewritten 2026-11-14, when the fourth loop (A1 to A8 in [POLISH_LOOP.md](POLISH_LOOP.md)) finished. This file is the prompt for whoever continues the work. Read it, then the Log at the end of POLISH_LOOP.md, which says what was checked and how, and what was not.

## Your brief

You are continuing Dighouse for Chris Sotraidis. It is a free, open-source macOS app for open archaeology: the Codex agent engine, any model the person has (through the OpenCodex router), and archaeology tools built in. A person should be able to open it, be helped to choose a place, run a search over open lidar, and end with records an archaeologist could trust.

Chris reviews by using the app and sending screenshots. He wants to use it to find things, and it must look and feel like its own product. Work in passes: build, check in the running app, fix, log, commit, push.

Four loops are finished. The fifth is [REFINE_LOOP.md](REFINE_LOOP.md), written from Chris's notes on the loop 4 build: register it as your goal. Suggested objective: "Finish the Dighouse loop in docs/REFINE_LOOP.md: goals R1 to R7 are met, each check verified in the running macOS app with the cheap model, logged, committed and merged."

## Rules

- Keep it simple and consistent. Recheck every control after rewiring it. Do not suggest Figma.
- Work in the existing checkout, `/Users/chrissotraidis/GitHub/dighouse`. No sibling clones or worktrees in `~/GitHub`.
- The repository stays private and nothing is released until Chris says so. Licence is Apache 2.0 for now.
- Nothing is ever called new. Locations stay under `private/`. A person decides and sends.
- Write "lidar" in lowercase. Plain words in the app: a first-time user must understand every label.
- Tests that send a message to a model use a cheap one: primary / 6.1 Terra (Chris, 2026-11-14). Never test with Opus.
- Say only what was checked. Do not claim a model, a service or a control works unless you saw it work.
- Leave Chris's settings, projects list and model as you found them. Back up `~/Library/Preferences/com.chrissotraidis.dighouse.plist` before a check that changes them, and compare afterwards.
- Final replies to Chris link only files under `/Users/chrissotraidis/Documents/Codex/2026-11-12/vb/outputs`. Copies of this file and the loop logs are kept there.

## Where things stand

- **App** (`app/Sources/Dighouse`, SwiftUI, macOS 14): one page at a time (Home, chat, New project, Toolbox, Settings). A project puts a workspace beside the chat with Map, Records, Notes, Sources and Data tabs. Three looks; Earth is the default.
- **Tools** (`src/dighouse`, Python, MCP): 33 tools. `discover.py` chooses where to look, `sources.py` and `terrain.py` fetch and build terrain, `tiles.py` and `section.py` screen and cut, `checks.py` reads maps and literature, `ledger.py` keeps records, `record.py` builds the research record and `report.py` the search report. The agent's instructions are `skills/dighouse/SKILL.md`.
- **Engine**: `codex app-server` as a child process, spoken to in JSON lines by `Engine.swift`. Dighouse starts the **newest** copy of Codex on the Mac (`Setup.detect`); on Chris's Mac that is 0.167 inside the ChatGPT app, because 0.146 on the PATH is refused GPT-6.1 Terra. Dighouse's own tools are approved at launch (`default_tools_approval_mode`), since newer engines ask before every tool call.
- **Tests**: 10 offline, 8 live (`uv run pytest`, `uv run pytest -m live`).
- **README** has pictures in `docs/images`, retaken on 2026-11-14 at 1440 × 900 in Earth.

## What the fourth loop added

- **A2, menus.** One menu panel (`MenuPanel` in Controls.swift) draws every in-app menu. The menu bar has File (Export Project), View (layouts, sidebar, Jump To, text size), Project (every workflow, the review, the research record, the search report, Show in Finder, Stop) and Help. A chat's or project's menu opens on a right-click or from a "…" button.
- **A3, tools.** All 32 tools of the time were run once against the real services; the table is in the Log. Open data says "Partly online" when OpenStreetMap's Overpass servers are down.
- **A4, the record.** RESEARCH.md opens with a plain summary, links to the finds and how to continue. `notes/record.json` keeps what was looked at, without locations, so the record survives Export Project. A shared project's overview offers Carry on, and the agent does not fetch or screen its ground again.
- **A5, the look.** Six drawings in `Drawings.swift` (trowel, brush, sieve, soil layers, mound, grid) for stages, workflows and empty states, and `DigIndicator`, a trowel scraping soil, in place of every spinner.
- **A6, the tutorial.** "Start your first project" on Home and in Help: six steps at Serpent Mound, one sentence and one ringed control each (`Tutorial.swift`). The step is read from the project, so it resumes anywhere.
- **A7, Find and report back.** One button on Home's place box, on the overview and as /investigate runs the whole search as a goal. Dighouse then asks the second-look model and shows the search report (`write_report`), with a button for each decision waiting. The strip shows the stage and a Stop; a stop is written into the research record.

## How a project documents itself (Chris's priority)

Every project is a folder with a git history (data/ and private/ left out) and one method. RESEARCH.md is its research record, rebuilt by `record.py` when a run ends (with or without a summary), a person decides, a second look comes back, or the project is opened. METHODOLOGY.md says how the work and the record are kept, and the agent reads both first. Keep this method when changing anything that writes into a project: whatever a run looks at or reads should end up in the record, and nothing with a location may go into notes/, reports/ or the record.

## Waiting on Chris

- **Use this build and say what is still rough.** Loop 4 closed its own audit list; his eye has not been over it.
- **Real hands:** dragging the sidebar edge and the chat divider with a mouse, dropping a file from Finder onto the message box, pinch zoom and two-finger panning on the map, the "…" button that shows under the pointer on a sidebar row, and how the menus in the menu bar look (test tooling opens them without drawing them).
- **Decisions:** a notarized download, a Notion button, bulk screening through the model router, the licence, and when the repository goes public.
- **Open astronomy:** whether to try a sky version, and which first step. The research is in [research/open-astronomy.md](research/open-astronomy.md); it recommends a second field in this app, starting with a tool server run in plain Codex.
- **His three test chats named "What should I research?"** were left as they are. New chats from the same workflow are numbered.

## Not verified

- **The modern-features check end to end.** OpenStreetMap's Overpass servers were down all day on 2026-11-14. The tool fails plainly and the record says so; a check that succeeds was last seen in loop 3.
- **Reduce Motion with the Mac's own setting.** The indicator was checked with SwiftUI's flag outside the app. The mark in the sidebar and the tutorial's ring were not checked at all.
- **A handover between two real Macs,** and a receiver who then fetches terrain for the same place.
- **Find and report back** on a place outside the United States, with usage running out part-way, and with a place name that cannot be found.
- **The tutorial** when the agent flags nothing.
- **Codex's browser plugin inside Dighouse,** most models in the roster, and a provider that refuses an effort step outright.
- **Turning the network off in the middle of a download.**

## Known problems

- **Publishers refuse programs.** The Sources tab lets a person open a refused page and hand it to the agent; the agent cannot drive a browser on its own.
- **The public Overpass servers are often down** for hours. Nothing else depends on them.
- **Two surveys do not build**: `ot:NM16_Dorshow` and `ot:NM10_Dorshow`. Both are marked `known_problem`.
- **Sections show no canopy** for datasets published as ground points only, and a section through a national ground model shows the profile only.
- **The Environment Agency service is slow and rate-limits.**
- **The National Register** withholds archaeological site locations, so it adds almost nothing near mound sites.
- **The stage in the strip follows the last tool called,** so it can step back from 4 to 3 when the agent cuts another section. That is true to what the agent is doing, but it is not a progress bar.
- **A search report has no word limit of its own.** Each find and each source adds a sentence, so a project with twenty finds will run long.

## What Chris has asked for that is not built

- The agent driving a browser of its own to look up records.
- From the first plan: a button that pushes records to Notion, bulk screening through the model router, a notarized download.
- Out of reach without an account, named in `open_resources`: historic aerial photographs, CORONA imagery, Denmark's lidar. Not yet checked: the Archaeology Data Service, EAMENA, tDAR, and lidar for Slovenia, Spain and Scotland.

## How to build, run and check

```sh
cd app && (pkill -x Dighouse || true) && ./scripts/bundle.sh
open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES
```

- **Start it clean when you start it from an agent's shell.** A shell inside the Codex app carries Codex's own environment into the app and its engine. Use `env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" TMPDIR="$TMPDIR" PATH="/usr/bin:/bin:/usr/sbin:/sbin" /usr/bin/open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES`.
- **A quick loop:** `swift build` (a debug build, a few seconds), copy `.build/debug/Dighouse` into the bundle, re-sign with `codesign --force --deep --sign -`, relaunch. Finish with `bundle.sh` for the release build.
- `bundle.sh` copies the Python tools into the app. The tools' environment is rebuilt by the app only when `uv.lock` changes; changed Python is picked up at the next launch.
- **Window size:** quit the app, write the frame to both the `NSWindow Frame main` key and the long `NSWindow Frame SwiftUI…AppWindow-1` key, then launch with `-ApplePersistenceIgnoreState YES`.
- **Driving it with Computer Use:** find controls by their accessibility text. Menus in the menu bar can be opened and clicked but are not drawn. A right-click works; hover does not. Keep each call under 30 seconds. A run can be watched by polling for the Stop button.
- **Pictures:** `screencapture -o -x -l<window id>` gives the window alone, with no Computer Use pill and no pointer; bring Dighouse to the front first. Computer Use's own screenshots include both.
- **Empty settings for a first-run check:** export the settings, `defaults delete com.chrissotraidis.dighouse`, write back the window frames, `model` and a scratch `projectsHome`, run the check, then delete and import the export.
- The engine takes about four seconds to list one folder's chats on this Mac. Chat lists are cached in defaults under `chatLists`.
- Defaults keys the app uses: `look`, `textSize`, `chatWidth`, `sidebarWidth`, `layout`, `model`, `recentModels`, `secondModel`, `effort`, `modelChecks`, `toolboxTab`, `tourStage`, `startKind`, `mapStyle`, `toolServers`, `projects`, `currentProject`, `projectsHome`, `userName`, `onboarded`, `chatLists`, and the tutorial's `tutorialOn`, `tutorialProject`, `tutorialReached`, `tutorialDone`.
- **Projects on Chris's Mac:** `~/Documents/Dighouse` holds his own (Angel Mounds, Maiden Castle, Mound City Group, Perry Mesa, Serpent Mound, Middle Usumacinta) and three test projects (`mound-city-review-test`, `serpent-mound-goal-run`, `fort-ancient-ohio`). The Cahokia control run is in `~/Documents/Codex/2026-11-12/vb/work/dighouse-projects`. Loop 4's scratch projects are under `~/Documents/Codex/2026-11-14/dighouse-loop4/work` and are not in his list.
- Pictures in `app/Resources/tour` and `app/Resources/starts` were made with the tools from open data. Keep it that way, and say in the caption where each comes from.
