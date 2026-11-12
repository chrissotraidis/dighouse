# Dighouse handoff

Written 2026-11-12, at commit `50ecc50` on `main`. This file is the prompt for whoever continues the work. Read it, then [NEXT_LOOP.md](NEXT_LOOP.md), then start.

## Your brief

You are continuing Dighouse for Chris Sotraidis. It is a free, open-source macOS app for open archaeology: the Codex agent engine, any model the person has (through the OpenCodex router), and archaeology tools built in. A person should be able to open it, be helped to choose a place, run a search over open lidar, and end with records an archaeologist could trust.

Chris reviews by using the app and sending screenshots. His standing complaint is that it is "not there yet": he wants to use it to find things, and it must look and feel like its own product. Work in passes: build, check in the running app, fix, log, commit, push.

Register the next loop as your goal. Suggested objective: "Finish the Dighouse loop in docs/NEXT_LOOP.md: every goal N1 to N10 is met, with its check verified in the running macOS app, logged, committed and pushed."

## Rules

- Keep it simple and consistent. Recheck every control after rewiring it. Do not suggest Figma.
- Work in the existing checkout, `/Users/chrissotraidis/GitHub/dighouse`. No sibling clones or worktrees in `~/GitHub`.
- The repository stays private and nothing is released until Chris says so. Licence is Apache 2.0 for now.
- Nothing is ever called new. Locations stay under `private/`. A person decides and sends.
- Write "lidar" in lowercase. Plain words in the app: a first-time user must understand every label.
- Say only what was checked. Do not claim a model, a service or a control works unless you saw it work.
- Final replies to Chris link only files under `/Users/chrissotraidis/Documents/Codex/2026-11-12/vb/outputs`.

## Where things stand

Read the Log in [GOAL_LOOP.md](GOAL_LOOP.md) for what was checked and how. In short:

- **App** (`app/Sources/Dighouse`, SwiftUI, macOS 14): one page at a time (Home, chat, New project, Toolbox, Settings). A project puts a workspace beside the chat with Map, Records, Notes and Sources tabs. Three looks; Earth is the default.
- **Tools** (`src/dighouse`, Python, MCP): 26 tools. `discover.py` chooses where to look, `sources.py` and `terrain.py` fetch and build terrain, `tiles.py` and `section.py` screen and cut, `checks.py` reads maps and literature, `ledger.py` keeps records. The agent's instructions are `skills/dighouse/SKILL.md`.
- **Engine**: `codex app-server` (0.146.0) as a child process, spoken to in JSON lines by `Engine.swift`.
- **Tests**: 2 offline, 5 live (`uv run pytest`, `uv run pytest -m live`). Offline pass at this commit.

## What was in progress when work stopped

1. **Animated mark beside "Dighouse" in the sidebar.** Chris's last request: the mound mark should animate while the agent is running. Nothing is written yet. The mark is `MoundMark` in `Controls.swift`, a `Canvas` of dots; the sidebar header is in `Sidebar` in `MainView.swift`. A run is in progress when `chat.live` is not empty (also `app.starting` and `app.secondLookBusy`). One idea: a pulse that sweeps across the dots like a laser pass, drawn in a `TimelineView` that is paused when idle, and still when Reduce Motion is on.
2. **Full pass on the current build.** At the zoomed size every page and control in a 39-step click-through passed. Half width and the narrow layout (under 860 points, where the sidebar becomes an overlay) passed on older builds but were not repeated on this one. The Canopy look was never opened.
3. **Live tests.** They passed once, before the OpenStreetMap fallback and the published-record count in `find_gaps` were changed. A rerun was started and its result was lost. Run `uv run pytest -m live` again.
4. **"What should I research?"** It proposed two Chaco surveys that do not build into terrain. `open_surveys` now marks those with `known_problem`, and the skill says to leave them out. The workflow was not rerun after that fix.

## Not verified

- **Dragging the edges with a real mouse.** The sidebar edge and the chat divider pass under the test tooling, but so did the earlier handle that failed in Chris's hand. He was asked to try it and has not answered.
- **Dropping a file onto the message box.** The Attach files panel and opening a file with Dighouse both work. A real drag from Finder was never tested.
- **Codex's browser plugin inside Dighouse.** It appears in the tool list. Nobody has asked the agent to use it here.
- **Effort steps.** The slider shows what the model list says. Tested at the top step: Opus 5.5 and Gemini 3.8 Flash answered; Kimi K3 failed with an OpenCodex sign-in error; 6.1 Sol was refused for a ChatGPT account. Most of the 91 models are untested.

## Known problems

- **OpenStreetMap's query service** timed out or refused through most checks. The tools say which source did not answer and carry on, so site counts are often short.
- **Publishers refuse programs.** In the Angel Mounds sweep the agent opened 6 sources and was refused by 14. The Sources tab lets a person open those, but the agent cannot drive that browser.
- **Two surveys do not build**: `ot:NM16_Dorshow` (its tile index has no readable projection) and `ot:NM10_Dorshow` (almost no points classed as ground).
- **Sections show no canopy** for datasets published as ground points only (the G-LiHT ones).
- **Old chats** made before workflow titles were added show their whole prompt as a title.
- **The welcome guide** was only lightly updated and still reads like the first build.

## What Chris has asked for that is not built

- The agent driving a browser of its own, as Codex does, to look up records.
- Thinking from first principles about what else archaeologists use, and adding it. Not yet read by any tool: national lidar outside the United States, Pleiades in bulk, tDAR (its interface for programs needs approval), the Archaeology Data Service, EAMENA, CORONA imagery. Sizes of the last three were never verified.
- Settings pages, "How it runs" and the Toolbox to keep getting clearer and less generic.
- Runs and sweeps that work well enough to find things: "I want to be able to use this to find stuff and it's just not there yet."
- From the first plan, still open: a button that pushes records to Notion, bulk screening through the model router, a notarized download.

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
- Test projects on Chris's Mac: `~/Documents/Dighouse/angel-mounds-east-plaza` (9 tiles, 5 candidates, sections, second looks, 20 sources) and `~/Documents/Dighouse/middle-usumacinta-settlement` (4 tiles screened by two helper agents). The Cahokia control run, which the Toolbox tour pictures come from, is in `~/Documents/Codex/2026-11-12/vb/work/dighouse-projects/cahokia-control-run`.
- Pictures in `app/Resources/tour` and `app/Resources/starts` were made with the tools from open data. Keep it that way, and say in the caption where each comes from.
