# Dighouse goal loop 4: polish, theme, and "just go"

Last updated: 2026-11-14

Read [HANDOFF.md](HANDOFF.md) first, then the end of [USABILITY_LOOP.md](USABILITY_LOOP.md), whose Log says what loop 3 did. Loop 3 made Dighouse easy to use. This loop makes it look and feel like a finished archaeology product. The menus and buttons should be professional, every tool should work, and the research record should hold up when a project changes hands. A newcomer should be able to start a first project with a short tutorial, or press one button and have the agent go, search and report back.

## Who this is for

- **A newcomer** with no archaeology and no lidar. They need a tutorial that gets them to a first result, and words they understand.
- **An amateur or archaeologist picking up someone else's project.** They need the research record to tell them what was already done, so they can add to it.
- **Someone who just wants an answer.** They name a place, press one button, and get a report back: what was looked at, what was found, what is already published, and what needs their decision.

## Goals

Each goal is done when its check passes in the running app. Record the date and what was seen in the Log below. Work them in order. Anything A1 finds broken comes first.

| Goal | What | Check |
|---|---|---|
| A1 | **Audit first.** Screenshot every screen (Home, new chat, New project, a project's overview and its five tabs, the review, the Toolbox's four tabs, every Settings page, ⌘K, the slash menu, the model panel, every menu in the macOS menu bar) in Earth at 1440 × 900, and Home and a project in Canopy and Graphite. List every rough edge: inconsistent spacing, controls that look different for the same job, labels over four words on a button, a plain or generic icon, a menu missing an item or a shortcut, anything that looks generated. | A dated, ranked list in the Log, with a screenshot path for each item. The goals below are adjusted if the list shows something bigger. |
| A2 | **Menus that look and act professional.** The macOS menu bar has every action a person looks for there, grouped the way Mac apps group them, with shortcuts that match the Help list:<br>- **File:** New chat, New project, Open project folder, Export project, Close.<br>- **Edit:** the standard items.<br>- **View:** the three layouts, the sidebar, Jump to, Find a chat, text size.<br>- **Project:** the workflows, Review, the research record, Show in Finder.<br>- **Help:** the welcome guide, the tutorial, commands and shortcuts, GitHub.<br>Disabled items say why where macOS allows it. In-app menus (the PillMenus, a chat's or project's context menu, the model panel, Workflows) share one look: same padding, icons on the left, a divider between groups, a checkmark on the current choice. | Every menu-bar item is clicked once and does what it says (record the result per menu). Screenshots of four in-app menus show the same look. |
| A3 | **Every tool works.** Run all 32 tools once on a scratch project, through the engine (Engine.callTool, or a short chat with the cheap model) or through Python, and record the result of each. Fix whatever fails. Add an offline test for anything that broke and can be tested without the network. The Toolbox's Open data status reflects reality. | A table in the Log: tool, how it was run, result. Every row passes or names the outside service that was down. uv run pytest passes. |
| A4 | **The documentation system holds up.** RESEARCH.md (src/dighouse/record.py) is rebuilt at every point it should be: run end, a decision, project open, and document_project. Check it against a real run on a known site using the cheap model. Then hand the project over: Export project, unzip it into another folder, open it with Open project folder, and start a run there. The agent must say what was already done and must not redo it. Make the record readable to a newcomer: a short plain summary at the top, links to each candidate, and a "how to continue" line. | After a fresh run, the record matches the project's files. After the handover, the agent's first message cites the record and the run skips work it lists. Recorded in the Log with the chat's first lines. |
| A5 | **Archaeology look.** Give Dighouse its own visual language, drawn in SwiftUI (Shapes and Canvas). Use SF Symbols only where they already fit; no image files where a vector will do.<br>- **Icons:** a trowel, a brush, a sieve, soil layers, a mound in section and a survey grid. Use them for the stages (terrain, screen, check, sources, decide, report), the workflows and the empty states.<br>- **Thinking indicator:** replace the generic progress spinners in chat, the run strip and the review with one Dighouse indicator. For example, soil layers being brushed away, or a trowel scraping with dots of lidar falling. It respects Reduce Motion.<br>- **Empty states:** each gets a small drawing in the same style.<br>Everything works in all three looks and at every text size. Keep the words plain: the theme is in the pictures, not in jargon. | Screenshots of the stage list, a workflow menu, an empty state and the thinking indicator (two frames) in each look. Reduce Motion stills the indicator. No generic spinner remains where the agent is working (search the code for ProgressView and list what remains and why). |
| A6 | **A tutorial for a first project.** From Home, "Start your first project" walks a newcomer through a known site (Serpent Mound or Mound City Group). It goes step by step, each with one sentence and one highlighted control:<br>1. Choose the place.<br>2. Get the terrain.<br>3. Look at the tiles (screen a few with the cheap model).<br>4. Open a find and its checks.<br>5. Read the research record.<br>6. Make a first decision.<br>It can be left and resumed, and is offered again in Help. It replaces nothing that already works; the welcome guide stays. | Starting from empty settings (back up and restore Chris's settings; see How to drive the app), a run-through reaches a decided find without leaving the tutorial, every step's control is highlighted, and leaving and coming back resumes at the same step. |
| A7 | **"Just go": find and report back.** One button (on Home's place box, a project's overview, and as /investigate) that runs the whole search as a Codex goal and ends with a report a person can read in two minutes. The report covers what was asked, the data used, what was looked at, what was flagged and why, what is already published (with sources), what was ruled out, what needs the person's decision, and what to try next. It is written to reports/ (no coordinates), linked from the research record, and shown in the app when the run ends with one button for each decision waiting. While it runs, the strip shows the stage it is on and a Stop. | On a known site, with primary / 6.1 Terra, one press ends with the report on screen without anyone typing "continue". The report's claims match the records. Stop leaves the project consistent and the record says where it stopped. |
| A8 | **One product, then docs.** Repeat A1's screenshots and confirm every item on its list is fixed or explained. Retake the README pictures (at 1440 × 900 in Earth, test projects hidden, restored after). Bring README, concept, HANDOFF and this file into line with the app. | The A1 list is closed. README, concept, HANDOFF and this file agree with the app. main is pushed and clean. |

## Rules for this loop

- **Cheap models only.** Every test that sends a message to a model uses primary / 6.1 Terra. Never test with Opus. The second-look model may be any non-Opus model from another maker.
- **Keep it simple.** Prefer one clear control over three clever ones, reuse the app's parts (Controls.swift, Theme), and keep the look consistent across every screen. Do not suggest Figma.
- **Recheck what you touch.** Recheck every control you rewire, and the ones next to it. A broken button is worse than an old one.
- **Plain words.** A first-timer must understand every label. Write lidar in lowercase. Never call a site new. A person decides and a person sends.
- **Locations stay under private/.** Nothing in the research record, reports or chats carries coordinates.
- **Say only what was checked.** A drag, hover or pinch done by test tooling is not proof that a real mouse or trackpad works; say it is unverified.
- **One branch and pull request per goal,** squash-merged when its check passes: codex/ prefix, then gh pr merge --squash --delete-branch. Log first.
- **Work in the existing checkout,** /Users/chrissotraidis/GitHub/dighouse. No sibling clones in ~/GitHub.
- **Leave Chris's things as you found them:** his settings, his projects list, his model choice (primary/gpt-6.1-terra). Archive the test chats you make.

## How to build, check and drive the app

- **Build and open:** cd app && (pkill -x Dighouse || true) && ./scripts/bundle.sh && open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES. Building takes 1 to 3 minutes; poll the session and don't block.
- **Tests:** uv run pytest -q (5 offline). uv run pytest -m live talks to real services.
- **Driving the app** with Computer Use (cua_repl):
  - Prefer accessibility element indices from getAXState.
  - Coordinate clicks are in full-resolution pixels: take a point from a screenshot and divide by 0.696, so (36, 923) in the screenshot is about (52, 1329).
  - Keep each call under 30 seconds, or the session resets. ⌘K is the fastest way to any project, chat or candidate.
  - Opening a project unfolds its chats; the fold arrow is at the left of the project's row.
- **Window size:** quit the app, write the frame (for example "0 0 1440 900 0 0 1728 1084 ") to the NSWindow Frame main key and the long NSWindow Frame SwiftUI…AppWindow-1 key in the com.chrissotraidis.dighouse defaults, then relaunch with -ApplePersistenceIgnoreState YES.
- **README pictures:**
  - Back up ~/Library/Preferences/com.chrissotraidis.dighouse.plist first.
  - Hide the test projects (Serpent Mound goal run, Fort Ancient Ohio, Mound City review test) by editing the projects key, which is JSON, while the app is closed. Afterwards, restore only that key.
  - Bring Dighouse to the front before screencapture -o -x -l<window id>, or macOS may hand back a stale image. Find the window id with CGWindowListCopyWindowInfo.
  - Cover the Computer Use indicator, a violet pill in the top-left corner of the capture.
- **Engine:** Dighouse's engine is a child codex app-server of the Dighouse process. Stop that one to test a stopped engine, never the Codex app's own.

## Where things stand at the start

- **Merged:** loop 3 is done, with U1 to U12, F1 to F11 and P1 in PRs #1 to #20.
- **Tools:** 32, and the Toolbox lists them.
- **Research record:** every project keeps one (RESEARCH.md, rebuilt by src/dighouse/record.py) and a git history without data/ or private/.
- **Thinking indicators today:** the animated mound mark beside "Dighouse" in the sidebar, and plain SwiftUI ProgressView spinners elsewhere. A5 replaces the spinners.
- **Not verified:** pinch zoom and two-finger panning with a real trackpad; turning the network off mid-download.
- **Known problems:** the Overpass servers are sometimes down, so modern-feature checks fail with a plain message. The Environment Agency service is slow and rate-limits. Publishers often refuse programs, and the Sources tab is the workaround.
- **Test projects on this Mac:** mound-city-review-test (its five decisions were recorded in Chris's name for testing only), serpent-mound-goal-run, fort-ancient-ohio, and a second cahokia-control-run in ~/Documents/Dighouse.

## The loop (every turn)

1. Read HANDOFF.md, this file and the Log below.
2. Pick the lowest unfinished goal, or an A1 finding that is breaking something.
3. Build it, then run its check in the running app and look at the result.
4. Fix what the check shows. Repeat until it passes.
5. Record the result in the Log with the date. Run the tests, commit, open the pull request and merge it.
6. Stop when A1 to A8 are checked, when a decision is needed from Chris, or when the time Chris set runs out. Before stopping, write in the Log what is half done and where, and update HANDOFF.md.

## Log

