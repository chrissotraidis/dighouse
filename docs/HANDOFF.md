# Dighouse handoff

Rewritten 2026-11-13, after the second loop (N1 to N10) and the README; updated when Chris paused the third loop, after U1 to U8 and most of his review (F1 to F11). This file is the prompt for whoever continues the work. Read it, then [USABILITY_LOOP.md](USABILITY_LOOP.md), whose Log ends with "where this run stopped", then start.

## Your brief

You are continuing Dighouse for Chris Sotraidis. It is a free, open-source macOS app for open archaeology: the Codex agent engine, any model the person has (through the OpenCodex router), and archaeology tools built in. A person should be able to open it, be helped to choose a place, run a search over open lidar, and end with records an archaeologist could trust.

Chris reviews by using the app and sending screenshots. His standing complaint is that it is "not there yet": he wants to use it to find things, and it must look and feel like its own product. Work in passes: build, check in the running app, fix, log, commit, push.

The third loop is finished. Goals U1 to U12, F1 to F11 and P1 are done. The next loop should start from Chris's next review.

## Rules

- Keep it simple and consistent. Recheck every control after rewiring it. Do not suggest Figma.
- Work in the existing checkout, `/Users/chrissotraidis/GitHub/dighouse`. No sibling clones or worktrees in `~/GitHub`.
- The repository stays private and nothing is released until Chris says so. Licence is Apache 2.0 for now.
- Nothing is ever called new. Locations stay under `private/`. A person decides and sends.
- Write "lidar" in lowercase. Plain words in the app: a first-time user must understand every label.
- Tests that send a message to a model use a cheap one: primary / 6.1 Terra (Chris, 2026-11-14). Never test with Opus.
- Say only what was checked. Do not claim a model, a service or a control works unless you saw it work.
- Final replies to Chris link only files under `/Users/chrissotraidis/Documents/Codex/2026-11-12/vb/outputs`.

## Where things stand

Read the Logs in [GOAL_LOOP.md](GOAL_LOOP.md) and [NEXT_LOOP.md](NEXT_LOOP.md) for what was checked and how. In short:

- **App** (`app/Sources/Dighouse`, SwiftUI, macOS 14): one page at a time (Home, chat, New project, Toolbox, Settings). A project puts a workspace beside the chat with Map, Records, Notes and Sources tabs. Three looks; Earth is the default. The mark beside "Dighouse" animates.
- **Tools** (`src/dighouse`, Python, MCP): 32 tools. `discover.py` chooses where to look, `sources.py` and `terrain.py` fetch and build terrain (USGS, OpenTopography, and national ground models for England, the Netherlands and France), `tiles.py` and `section.py` screen and cut, `checks.py` reads maps and literature, `ledger.py` keeps records. The agent's instructions are `skills/dighouse/SKILL.md`.
- **Engine**: `codex app-server` (0.146.0) as a child process, spoken to in JSON lines by `Engine.swift`. Dighouse opts into the experimental API, because newer chats are stored page by page and only `thread/turns/list` returns them.
- **Tests**: 5 offline, 8 live (`uv run pytest`, `uv run pytest -m live`).
- **README** has screenshots in `docs/images`, taken from the running app at 1440 × 900 with real projects. Retake them when the app changes in a way they show.

## What the third loop added (U1 to U7)

- Slash commands (`/` in the message box), including Codex's /fork, /undo, /compact, /goal and /status, built on the engine's experimental API (Dighouse opts in at initialize).
- @ mentions for candidates, tiles, sources, files and projects; the references go to the agent below the message and are hidden in the chat.
- Message actions (Copy, Edit and send again, Ask again, Copy the chat up to here), Find a chat with archived chats and Restore, and "Run the whole search" as a Codex goal.
- A status line (chat fullness, usage left), download progress in the strip with a Cancel that stops the tool through `private/state/stop-download`.
- Typing a place on Home starts a project there; creating a project fetches its terrain; the strip names the next step.
- A Data tab: terrain details, your own GeoTIFF/LAS/LAZ through the new `import_terrain` tool, exports, and a map that draws nearby terrains as one mosaic.

## What has been added since U7

- **U8:** a map with views (Composite, Hillshade, Local relief, Sky view, through the `render_tiles` tool), toggles, zoom, click and double-click, and drawing a line to cut a section.
- **Chris's review (F1 to F11):** the review comes prepared (the `suggest_decision` tool and "Prepare my review"), one button style, /review, a bigger and animated Home, How it runs rewritten around model, engine and tools, Settings › Tools, Open data grouped by region, a project overview, readable section labels, a text size setting, Models warnings and Test both, and each project kept as its own git repository with METHODOLOGY.md and a Notes tab in three parts.
- **Done on 2026-11-14:** F2, F5, F6, U10 (⌘K), U11 (failures say what to do), U12 (every size and look, and the README pictures and docs), the model button opening the model list first, and P1 (every project keeps a research record). **Still open:** check pinch zoom and two-finger panning with a real trackpad. The Log in USABILITY_LOOP.md has the details and the test leftovers.

## How a project documents itself (P1, Chris's priority)

Every project is a folder with a git history (data/ and private/ left out) and one method. RESEARCH.md is its research record, rebuilt by `src/dighouse/record.py` when a run ends, a person decides, or the project is opened. METHODOLOGY.md says how the work and the record are kept, and the agent reads both first. Keep this method when changing anything that writes into a project: whatever a run looks at or reads should end up in the record, so the next person or agent can build on it.

## Waiting on Chris

- **N2:** dragging the sidebar edge and the chat divider with a real mouse, and dropping a file from Finder onto the message box. Test tooling cannot start a real drag.
- **N9:** review of the welcome guide, How it runs, Models, Toolbox and Data and privacy for anything that "looks generated".
- **Decisions:** a notarized download, a Notion button, bulk screening through the model router, the licence, and when the repository goes public.

## Not verified

- **N1:** the mark on hover and with Reduce Motion on.
- **Codex's browser plugin inside Dighouse.** It appears in the tool list. Nobody has asked the agent to use it here.
- **Effort steps.** Most of the models in the roster have not been tested; the Test button in Settings records each one that is.
- **A provider that refuses an effort step outright** (none was found).

## Known problems

- **Publishers refuse programs.** The Sources tab lets a person open a refused page and hand it to the agent; the agent cannot drive a browser on its own.
- **Two surveys do not build**: `ot:NM16_Dorshow` (its tile index has no readable projection) and `ot:NM10_Dorshow` (almost no points classed as ground). Both are marked `known_problem`.
- **Sections show no canopy** for datasets published as ground points only (the G-LiHT ones), and a section through a national ground model shows the profile only.
- **The Environment Agency service is slow and rate-limits.** England downloads one 500 m request at a time; 1.9 sq km took about 15 minutes.
- **The National Register** withholds archaeological site locations, so it adds almost nothing near mound sites (none around Cahokia or Moundville). Its card has no picture for that reason.
- **A stopped run leaves no run summary.** Everything it did is in the notes and records, but the summary is written only when a run ends by itself.

## What Chris has asked for that is not built

- The agent driving a browser of its own to look up records.
- From the first plan: a button that pushes records to Notion, bulk screening through the model router, a notarized download.
- Out of reach without an account, named in `open_resources`: historic aerial photographs, CORONA imagery, Denmark's lidar. Not yet checked: the Archaeology Data Service, EAMENA, tDAR, and lidar for Slovenia, Spain and Scotland.

## How to build, run and check

```sh
cd app && (pkill -x Dighouse || true) && ./scripts/bundle.sh
open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES
```

- `bundle.sh` copies the Python tools into the app. On launch the app rebuilds the tools' environment by itself when `uv.lock` has changed; give it about a minute.
- To open at a chosen size, quit the app, write the frame to both the `NSWindow Frame main` key and the long `NSWindow Frame SwiftUI…AppWindow-1` key in the `com.chrissotraidis.dighouse` defaults, then launch with `-ApplePersistenceIgnoreState YES`. Without that flag macOS restores the old size.
- Drags made by accessibility tooling are not proof that a real mouse works. Ask Chris, or say it is unverified.
- The engine takes about four seconds to list one folder's chats on this Mac (2,300 Codex sessions). Chat lists are cached in defaults under `chatLists`.
- Defaults keys the app uses: `look`, `chatWidth`, `sidebarWidth`, `layout`, `model`, `secondModel`, `effort`, `toolboxTab`, `tourStage`, `startKind`, `toolServers`, `projects`, `currentProject`.
- Test projects on Chris's Mac: `~/Documents/Dighouse/mound-city-group` (a stopped whole run: 12 tiles, 5 candidates, 1 source), `~/Documents/Dighouse/angel-mounds-east-plaza` (9 tiles, 5 candidates, sections, second looks, 20 sources) and `~/Documents/Dighouse/middle-usumacinta-settlement` (4 tiles screened by two helper agents). The Cahokia control run, which the Toolbox tour pictures come from, is in `~/Documents/Codex/2026-11-12/vb/work/dighouse-projects/cahokia-control-run`.
- Pictures in `app/Resources/tour` and `app/Resources/starts` were made with the tools from open data. Keep it that way, and say in the caption where each comes from.
