# Dighouse handoff

Rewritten 2026-11-14, when the fifth loop (R1 to R7 in [REFINE_LOOP.md](REFINE_LOOP.md)) finished, and brought up to date on 2026-11-15 after the final pass. This file is the prompt for whoever continues the work. Read it, then the Log at the end of REFINE_LOOP.md, which says what was checked and how, and what was not.

## Your brief

You are continuing Dighouse for Chris Sotraidis. It is a free, open-source macOS app for open archaeology: the Codex agent engine, any model the person has (through the OpenCodex router), and archaeology tools built in. A person should be able to open it, be helped to choose a place, run a search over open lidar, and end with records an archaeologist could trust.

Chris reviews by using the app and sending screenshots. He wants to use it to find things, and it must look and feel like its own product. Work in passes: build, check in the running app, fix, log, commit, push.

Five loops are finished. The sixth is [TEST_LOOP.md](TEST_LOOP.md): blind tests on known sites with a scorecard, "What is this?", a feature guide, calibration before a search for something new, a benchmark, and an honest README. Register it as your goal. Suggested objective: "Finish the Dighouse loop in docs/TEST_LOOP.md: goals T1 to T8 are met, each check verified in the running macOS app with primary / 6.1 Terra, logged, committed and merged."

## Rules

- Keep it simple and consistent. Recheck every control after rewiring it. Do not suggest Figma.
- **Fewer words is the work.** Chris's note on loop 4 was "too much text". One sentence for one idea, 25 words at most, and a picture or a control wherever one can carry the meaning. Loop 5 halved the words on every Toolbox tab and Settings page; do not let them grow back.
- **One word for one thing, wherever a person reads:**
  - a shape the agent marked is a **find** (not a flag or a candidate);
  - a cut straight down through the laser points is a **slice** (not a section);
  - the agent **looks at** tiles (not screens);
  - another model gives a **second opinion** (not a second look);
  - the bare-ground model is **the ground** (not terrain).
  - Tool names, file names and code keep the older words. The agent's skill tells it to use the new ones when it writes to a person.
- Work in the existing checkout, `/Users/chrissotraidis/GitHub/dighouse`. No sibling clones or worktrees in `~/GitHub`.
- The repository stays private and nothing is released until Chris says so. Licence is Apache 2.0 for now.
- Nothing is ever called new. Locations stay under `private/`. A person decides and sends.
- Write "lidar" in lowercase. A first-time user must understand every label.
- Tests that send a message to a model use a cheap one: primary / 6.1 Terra (Chris, 2026-11-14). Never test with Opus.
- Say only what was checked. Do not claim a model, a service or a control works unless you saw it work.
- Leave Chris's settings, projects list and model as you found them. Back up `~/Library/Preferences/com.chrissotraidis.dighouse.plist` before a check that changes them, and compare afterwards.
- Final replies to Chris link only files under `/Users/chrissotraidis/Documents/Codex/2026-11-12/vb/outputs`. Copies of this file and the loop logs are kept there.

## Where things stand

- **App** (`app/Sources/Dighouse`, SwiftUI, macOS 14): one page at a time (Home, chat, New project, Toolbox, Settings). A project puts a workspace beside the chat with Map, Records, Notes, Sources and Data tabs. Three looks; Earth is the default. The mark at the top of the sidebar opens Home.
- **Tools** (`src/dighouse`, Python, MCP): 36 tools. `discover.py` chooses where to look, `sources.py`, `national.py` and `terrain.py` fetch and build the ground, `tiles.py` and `section.py` cut tiles and slices, `checks.py` reads maps and literature, `ledger.py` keeps records, `record.py` builds the research record and `report.py` the search report. The agent's instructions are `skills/dighouse/SKILL.md`.
- **Open lidar:** the United States (USGS 3DEP), surveys on OpenTopography, and seven national ground models: England, the Netherlands, France, Flanders, Norway, Estonia and Switzerland.
- **Engine**: `codex app-server` as a child process, spoken to in JSON lines by `Engine.swift`. Dighouse starts the **newest** copy of Codex on the Mac (`Setup.detect`); on Chris's Mac that is 0.167 inside the ChatGPT app, because 0.146 on the PATH is refused GPT-6.1 Terra. Dighouse's own tools are approved at launch (`default_tools_approval_mode`), since newer engines ask before every tool call.
- **Tests**: 13 offline, 8 live (`uv run pytest`, `uv run pytest -m live`). The live test of the national ground models takes two minutes.
- **README** has pictures in `docs/images`, retaken on 2026-11-14 at 1440 × 900 in Earth after loop 5. Loop 5's own pictures are in `docs/loop5`.

## What the fifth loop added

- **R1, the short list.** The mark opens Home. The search report holds to 400 words: decisions first, the rest counted. The map check asks OpenStreetMap's own map service when the Overpass servers are down. Models shows the model list's own names and descriptions for the thinking steps; the Test buttons are gone.
- **R2, a project that guides.** The word list above. The card at the top of a project says what the agent will do next, why, and what follows (`ProjectOverview.swift`). The main button is Find and report back; one step alone is the smaller button. Literature search falls back to Crossref when OpenAlex turns a keyless request away.
- **R3, the Toolbox.** Four tabs rebuilt in `ToolboxView.swift`: a picture to press or drag for each stage of one real search (on Check, a line dragged across Monks Mound draws its slice from `tour/slice.bin`); workflows as three lanes; open data on a map of the world (`CoverageMap`, `tour/world.json`) with a page for each service; other tools as a grid of requests to try.
- **R4, Settings.** Seven short pages on one row style. How it runs is one picture of you, the model, the engine and the tools with their state now. Tools is a searchable list.
- **R5, more of the world.** Flanders, Norway, Estonia and Switzerland in `national.py`. Switzerland is read from swisstopo's file catalog, one file for each square km.
- **R6, research.** [research/open-astronomy.md](research/open-astronomy.md): whether the same method could search open sky data. No code.

## What the final pass added (2026-11-15)

- **Text size:** five steps (`TextSize` in `Core.swift`), ⌘=, ⌘+ and ⌘− in the View menu, a short note at the top of the window, and the same five in Personalize. The workflow lanes and the Toolbox stage card hold at Largest.
- **Movement:** `Motion` in `Core.swift` and `.arrives()` in `Controls.swift` (fade and rise, in order); `CardButton` for cards that are buttons. All of it is off with Reduce Motion. Use these for anything new rather than adding another animation.
- **Personal:** Home's greeting card (`WelcomeBack` in `HomeView.swift`) shows the last project, what it waits for and the person's totals, read from the folders by `ProjectStore.glance`. The overview's card says "Your turn, Chris".
- **Docs:** the README is written for a public release, and [ROADMAP.md](ROADMAP.md) holds what comes next, including the open astronomy field.

## How a project documents itself (Chris's priority)

Every project is a folder with a git history (data/ and private/ left out) and one method. RESEARCH.md is its research record, rebuilt by `record.py` when a run ends (with or without a summary), a person decides, a second opinion comes back, or the project is opened. METHODOLOGY.md says how the work and the record are kept, and the agent reads both first. Keep this method when changing anything that writes into a project: whatever a run looks at or reads should end up in the record, and nothing with a location may go into notes/, reports/ or the record.

## Waiting on Chris

- **The promotional video** (30 to 40 seconds, made from real app footage) waits for his pass.
- **Going public.** The README reads as if the repository were public. Making it public, tagging a release, and a notarized download are his decisions.

- **Use this build and say what is still rough.** Loop 5 answered his list item by item (the Log has a picture for each), but his eye has not been over the result.
- **The second-opinion model is being refused.** On 2026-11-14 the provider of AG · Gemini 3.8 Flash answered every request with 403, "This service has been disabled in this account for violation of Terms of Service", and told the account holder to appeal. It worked that afternoon. Only Chris can look at that account or choose another second model. Until then no second opinion can be had; Dighouse says so on the record and carries on.
- **OpenAlex and a key.** Without a key, a network address shares about 100 literature searches a day, and Dighouse falls back to Crossref past that. A free key lifts it to about 1,000. Asking for one sends an email address to OpenAlex, so it is his to do; a field for the key in Settings is a small job if he wants it.
- **Real hands:** dragging a line across the mound in the Toolbox, dragging the sidebar edge and the chat divider with a mouse, dropping a file from Finder onto the message box, pinch zoom and two-finger panning on the map, the "…" button that shows under the pointer on a sidebar row, and how the menus in the menu bar look (test tooling opens them without drawing them).
- **Decisions:** a notarized download, a Notion button, looking at tiles in bulk through the model router, the licence, and when the repository goes public.
- **Open astronomy:** whether to try a sky version, and which first step. The research is in [research/open-astronomy.md](research/open-astronomy.md); it recommends a second field in this app, starting with a tool server run in plain Codex.
- **His three test chats named "What should I research?"** were left as they are. New chats from the same workflow are numbered.

## Not verified

- **A second opinion** in loop 5, for the reason above. It was last seen working in loop 4.
- **The map check's second way in** in a town dense enough for the map service to refuse the 4 km square, other than in the offline test.
- **The "Nothing here looked built" card** on a project where no tile was marked, and Widen the search.
- **Reduce Motion with the Mac's own setting.** The indicator was checked with SwiftUI's flag outside the app. The mark in the sidebar and the tutorial's ring were not checked at all.
- **A handover between two real Macs,** and a receiver who then fetches the ground for the same place.
- **Find and report back** with usage running out part-way, and with a place name that cannot be found. (A whole search outside the United States was seen in loop 5, at Borre in Norway.)
- **The whole tutorial** after the words changed. Its rings were checked on two steps; it was not run from start to end, nor when the agent marks nothing.
- **Codex's browser plugin inside Dighouse,** most models in the roster, and a provider that refuses an effort step outright.
- **Turning the network off in the middle of a download.**
- **Norway north of the Arctic Circle and the Swiss high Alps,** and the licence wording for Flanders and Estonia beyond "open data".

## Known problems

- **Publishers refuse programs.** The Sources tab lets a person open a refused page and hand it to the agent; the agent cannot drive a browser on its own.
- **The public Overpass servers are often down** for hours. The map check now goes round them; choosing a place reads mapped sites through QLever and does not need them.
- **OpenAlex meters keyless requests** and turns some away when busy. Crossref answers instead, with shorter abstracts and no links to open copies.
- **Two surveys do not build**: `ot:NM16_Dorshow` and `ot:NM10_Dorshow`. Both are marked `known_problem`.
- **A slice shows no treetops** for datasets published as ground points only. A slice through a national ground model measures a shape but cannot say whether it is ground; the record says "measured on a ready-made ground model".
- **The national services are slow.** England rate-limits; Norway and Estonia take about 15 seconds for a quarter of a square km.
- **The National Register** withholds archaeological site locations, so it adds almost nothing near mound sites.
- **A path within 150 m counts as a modern feature nearby.** The map check says what is there ("paths or roads, buildings"), and the person judges; it is not a verdict.
- **The stage in the strip follows the last tool called,** so it can step back from 4 to 3 when the agent cuts another slice.
- **A single step ends with a search report too,** because the agent is told to end every run with one. After "Only get the ground" the report says little.
- **The welcome guide** still has more words than the rest of the app, and was not gone over in loop 5.

## What Chris has asked for that is not built

- The agent driving a browser of its own to look up records.
- From the first plan: a button that pushes records to Notion, looking at tiles in bulk through the model router, a notarized download.
- A version for the sky. Researched, not started.
- Out of reach without an account or a key: historic aerial photographs, CORONA imagery, and the lidar of Denmark, Finland and Sweden. Tried in loop 5 and not read yet: Scotland, Wales and Slovenia (files only), Spain (5 m only), Poland (no answer), Luxembourg (no ground model listed). Not yet checked: the Archaeology Data Service, EAMENA, tDAR.

## How to build, run and check

```sh
cd app && (pkill -x Dighouse || true) && ./scripts/bundle.sh
open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES
```

- **Start it clean when you start it from an agent's shell.** A shell inside the Codex app carries Codex's own environment into the app and its engine. Use `env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" TMPDIR="$TMPDIR" PATH="/usr/bin:/bin:/usr/sbin:/sbin" /usr/bin/open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES`.
- **A quick loop:** `swift build` (a debug build, a few seconds), copy `.build/debug/Dighouse` into the bundle, copy `Resources/tour` and the Python tools with it, re-sign with `codesign --force --deep --sign -`, relaunch. Finish with `bundle.sh` for the release build. Loop 5's script for this is `~/Documents/Codex/2026-11-14/dighouse-loop5/work/devrun.sh`.
- `bundle.sh` copies the Python tools into the app. The tools' environment is rebuilt by the app only when `uv.lock` changes; changed Python is picked up at the next launch.
- **Window size:** quit the app, write the frame to both the `NSWindow Frame main` key and the long `NSWindow Frame SwiftUI…AppWindow-1` key, then launch with `-ApplePersistenceIgnoreState YES`.
- **Driving it with Computer Use:** find controls by their accessibility text. Sidebar chats can share a name with a button on the page, so look for a control after the Settings button in the list. A drag takes screen pixels, twice the points on this Mac. Menus in the menu bar can be opened and clicked but are not drawn. A right-click works; hover does not. Keep each call under 30 seconds. A run can be watched by polling for the Stop button.
- **Counting words:** take the accessibility text of the page after the sidebar's Settings button, keep names and values, leave out help text, and count. Loop 5's numbers were taken at 1440 × 900.
- **Pictures:** `screencapture -o -x -l<window id>` gives the window alone, with no Computer Use pill and no pointer; bring Dighouse to the front first. Computer Use's own screenshots include both.
- **Empty settings for a first-run check:** export the settings, `defaults delete com.chrissotraidis.dighouse`, write back the window frames, `model` and a scratch `projectsHome`, run the check, then delete and import the export.
- The engine takes about four seconds to list one folder's chats on this Mac. Chat lists are cached in defaults under `chatLists`.
- Defaults keys the app uses: `look`, `textSize`, `chatWidth`, `sidebarWidth`, `layout`, `model`, `recentModels`, `secondModel`, `effort`, `toolboxTab`, `tourStage`, `startKind`, `mapStyle`, `toolServers`, `projects`, `currentProject`, `projectsHome`, `userName`, `onboarded`, `chatLists`, and the tutorial's `tutorialOn`, `tutorialProject`, `tutorialReached`, `tutorialDone`.
- **Projects on Chris's Mac:** `~/Documents/Dighouse` holds his own (Angel Mounds, Maiden Castle, Mound City Group, Perry Mesa, Serpent Mound, Middle Usumacinta) and three test projects (`mound-city-review-test`, `serpent-mound-goal-run`, `fort-ancient-ohio`). The Cahokia control run is in `~/Documents/Codex/2026-11-12/vb/work/dighouse-projects`. Scratch projects from loops 4 and 5 are under `~/Documents/Codex/2026-11-14/dighouse-loop4/work` and `~/Documents/Codex/2026-11-14/dighouse-loop5/work` (a finished Mound City search, and a Borre search in Norway that waits for decisions). They are not in his list; open them with File, then Open Project Folder.
- Pictures in `app/Resources/tour` and `app/Resources/starts` were made with the tools from open data. Keep it that way, and say in the caption where each comes from.
