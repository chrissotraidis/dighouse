# Dighouse goal loop 4: polish, theme, and "just go"

Last updated: 2026-11-14

**Status: finished on 2026-11-14.** All eight goals are checked, in pull requests #22 to #29. The Log below says what was seen for each, and what was not verified.

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
- **Tests:** uv run pytest -q (10 offline by the end of this loop). uv run pytest -m live talks to real services.
- **Driving the app** with Computer Use (cua_repl):
  - Prefer accessibility element indices from getAXState.
  - Coordinate clicks are in full-resolution pixels: take a point from a screenshot and divide by 0.696, so (36, 923) in the screenshot is about (52, 1329).
  - Keep each call under 30 seconds, or the session resets. ⌘K is the fastest way to any project, chat or candidate.
  - Menus in the menu bar can be opened and clicked through accessibility but are not drawn, so they cannot be photographed. A right-click works; hover does not.
  - Start the app with a clean environment when launching it from an agent's shell (see HANDOFF.md), or the engine inherits the Codex app's settings.
  - Opening a project unfolds its chats; the fold arrow is at the left of the project's row.
- **Window size:** quit the app, write the frame (for example "0 0 1440 900 0 0 1728 1084 ") to the NSWindow Frame main key and the long NSWindow Frame SwiftUI…AppWindow-1 key in the com.chrissotraidis.dighouse defaults, then relaunch with -ApplePersistenceIgnoreState YES.
- **README pictures:**
  - Back up ~/Library/Preferences/com.chrissotraidis.dighouse.plist first.
  - Hide the test projects (Serpent Mound goal run, Fort Ancient Ohio, Mound City review test) by editing the projects key, which is JSON, while the app is closed. Afterwards, restore only that key.
  - Bring Dighouse to the front before screencapture -o -x -l<window id>, or macOS may hand back a stale image. Find the window id with CGWindowListCopyWindowInfo.
  - screencapture -l gives the window alone, with no Computer Use pill and no pointer. Computer Use's own screenshots have both, and the pill then needs covering.
- **Engine:** Dighouse's engine is a child codex app-server of the Dighouse process. Stop that one to test a stopped engine, never the Codex app's own. Since A2 Dighouse starts the newest copy of Codex on the Mac; 0.146 is refused the cheap model.

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

### 2026-11-14, A1: the audit

Every screen was captured from the running app in Earth at 1440 × 900, and Home and a project in Canopy and Graphite. The pictures are in [loop4/](loop4/). The menu bar was read through accessibility, because a menu opened by test tooling is not drawn on screen, so there is no picture of it. The list is ranked: wrong first, then inconsistent, then plain.

**Wrong or misleading**

| # | What | Picture | Goal |
|---|---|---|---|
| 1 | In Canopy, "Looks built" and "Possible" tiles are outlined in almost the same orange, on the map and in its key. The accent colour is tan in that look. | loop4/a1-33-canopy-project.jpg | A2 |
| 2 | A candidate with every check on its record still reads "Not yet checked", on its record and in the review. It is waiting for a decision. | loop4/a1-13-records.jpg, loop4/a1-17-review.jpg | A2 |
| 3 | The menu bar has no Export project, no Review, no research record, no Show in Finder, no text size and no tutorial. The project menu is called Run. Its items are in sentence case while every other menu uses title case. A greyed item does not say why. | read through accessibility | A2 |
| 4 | Open data: a service still being checked already has the tooltip "This service replied to a test request from this Mac." | loop4/a1-18-toolbox-open-data.jpg | A3 |
| 5 | The + button in the message box opens a menu with one item, "Attach files…", when nothing is selected. | loop4/a1-09-attach-menu.jpg | A2 |

**Inconsistent**

| # | What | Picture | Goal |
|---|---|---|---|
| 6 | In-app menus come in three looks: the system menu (the + button, the map's view menu, the record picker, a chat's or project's menu), a custom panel (Workflows, the model list) and a bare list (slash commands). None marks the current choice the same way. | loop4/a1-06-slash-menu.jpg, loop4/a1-07-workflows-menu.jpg, loop4/a1-08-model-panel.jpg, loop4/a1-09-attach-menu.jpg | A2 |
| 7 | The Workflows menu cuts each description off with "…". | loop4/a1-07-workflows-menu.jpg | A2 |
| 8 | Two search panels for the same job look different: ⌘K has a bare field and Close at the bottom right; Find a chat has a boxed field and Close at the top right. | loop4/a1-10-jump-palette.jpg, loop4/a1-32-find-a-chat.jpg | A2 |
| 9 | "This starts something" is drawn with three arrows: → on cards, ↑ on question rows, ↗ on "Ask the agent for every survey in the catalog". | loop4/a1-04-home-open-surveys.jpg, loop4/a1-05-new-chat.jpg | A5 |
| 10 | In the sidebar and the Settings list, labels start at different places because the icons have different widths. | loop4/a1-01-home.jpg, loop4/a1-22-settings-general.jpg | A5 |
| 11 | The Toolbox jumps about 7 points sideways between tabs, as the scroll bar comes and goes. | loop4/a1-18-toolbox-open-data.jpg, loop4/a1-21-toolbox-more-tools.jpg | A2 |
| 12 | "Open a shared project folder…" on Home is a text link among buttons, and five words long. | loop4/a1-02-home-lower.jpg | A2 |
| 13 | In the review the relief picture floats in the middle of its column; everything else is aligned left. | loop4/a1-17-review.jpg | A2 |
| 14 | Sources: the status reads "Could Not Open" in title case, and the first row has no arrow while the others do. | loop4/a1-15-sources.jpg | A2 |
| 15 | The Data tab starts a few points further left than the other tabs. | loop4/a1-16-data.jpg | A2 |
| 16 | Buttons over four words: "Ask the agent for every survey in the catalog" and "Next: Search what is published" (Toolbox). | loop4/a1-04-home-open-surveys.jpg, loop4/a1-19-toolbox-how.jpg | A2 |

**Plain, generic, or looks generated**

| # | What | Picture | Goal |
|---|---|---|---|
| 17 | Every "working" sign is the system spinner: in chat, the top bar, the sidebar, the review, the map, Open data and more (23 places in the code). | loop4/a1-18-toolbox-open-data.jpg | A5 |
| 18 | The six stages are ticks in circles with no picture of their own, on the overview and in the Toolbox. | loop4/a1-12-project-overview.jpg, loop4/a1-19-toolbox-how.jpg | A5 |
| 19 | Generic system icons: an aeroplane for a survey, a bank for an archive, a chip for the model, a light bulb for a suggestion, an arrow in a circle for the next step, a wrench beside each tool. | loop4/a1-04-home-open-surveys.jpg, loop4/a1-05-new-chat.jpg, loop4/a1-17-review.jpg, loop4/a1-20-toolbox-workflows.jpg | A5 |
| 20 | Empty states are one grey line (Find a chat, "No projects yet") or a system icon on a tile (the Map, Records and Sources with nothing in them). | loop4/a1-32-find-a-chat.jpg | A5 |
| 21 | Toolbox › More tools lists raw plugin names under "Also connected" (build-macos-apps, codex-app-tools, unified-computer-use…). | loop4/a1-21-toolbox-more-tools.jpg | A2 |
| 22 | The research record opens with two explanations of itself, one from the app and one from the file, before any fact about the project. | loop4/a1-14-notes.jpg | A4 |
| 23 | Three chats in the sidebar are all called "What should I research?", so they cannot be told apart. | loop4/a1-01-home.jpg | A2 |

**Looked at and left alone:** Home, New project, the project overview's layout, Records, the model panel, ⌘K, the welcome guide and the seven Settings pages are consistent with each other in spacing, buttons and type. Graphite has no problems of its own (loop4/a1-34-graphite-project.jpg).

**Captured later, during A2:** a project with no terrain (loop4/a1-36-project-no-terrain.jpg) and a chat while the agent is working, with the system spinner beside "Working" and in the top bar (loop4/a1-37-chat-working.jpg).

**The goals stand as written.** Nothing on the list is bigger than a goal already covers. Items 1, 2 and 4 are wrong rather than rough, so they are fixed first, with A2.

### 2026-11-14, A2: menus, and an engine that runs the cheap model

**Found on the way, and fixed first: the cheap model did not run.** Every message to primary / 6.1 Terra failed with "The 'gpt-6.1-terra' model is not supported when using Codex with a ChatGPT account." Dighouse was starting the first `codex` on the PATH, version 0.146.0, and the provider refuses Terra to that version. The copy inside the ChatGPT app is 0.167 and answers.

- **The newest engine wins.** Setup now asks every copy of Codex on the Mac for its version and starts the newest. On this Mac that is 0.167.0-alpha.4.1.
- **The newer engine asks before every tool call.** With no one to ask, it refused all 32 tools ("the Dighouse tools require approval"). Dighouse's own tools are now approved when the engine starts; tools a person adds still ask.
- **A failure of this kind says so.** The bar under a failed chat reads "This model needs a newer Codex engine". In a narrow chat its buttons go under the words; they used to squeeze the words into a column three words wide (loop4/a2-recovery-bar.jpg).
- **Checked:** on the scratch project, Get the terrain, Screen the tiles and Check the flags each ran to the end on Terra with engine 0.167. Chats, the model list, usage left and the second look (Gemini 3.8 Flash) work as before.

**The menu bar** was read and clicked through accessibility. A menu opened by test tooling is not drawn on screen, so its shortcuts and the grey second line that says why an item is off were not seen, only set in the code.

| Menu | Item | Result |
|---|---|---|
| Dighouse | About Dighouse | The About panel: icon, "Dighouse Version 0.2.0 (1)". |
| Dighouse | Settings… ⌘, | Settings opened on General. |
| File | New Chat ⌘N | A new general chat. |
| File | New Project… ⇧⌘N | The New project page. |
| File | Open Project Folder… ⌘O | The folder panel with its message. Chose the scratch project's folder; it opened with its overview and was added to the sidebar. |
| File | Export Project… ⇧⌘E | Off with no project open. With one open, the save panel with "The records, notes, sources and reports, without downloaded data or locations." The export itself is checked in A4. |
| File | Close ⌘W | The window closed; opening the app again brought it back. |
| View | Chat Only ⌘1, Chat and Workspace ⌘2, Workspace Only ⌘3 | Each set the layout (read back from the saved setting). |
| View | Hide Sidebar ⌃⌘S | The sidebar went, and the item became Show Sidebar, which brought it back. |
| View | Jump To… ⌘K | The palette opened. |
| View | Find a Chat… ⇧⌘F | The search panel opened. |
| View | Home ⌘0, Toolbox ⌘T | Each page opened. |
| View | Bigger Text ⌘+, Smaller Text ⌘− | Standard became Large and back. Smaller is off at Standard. The Text Size submenu lists the three sizes. |
| Project | Get the Terrain | A chat started and fetched USGS 3DEP lidar: 7.41 ground returns per sq m, 4 tiles. |
| Project | Screen the Tiles | Screened 4 of 4 tiles and flagged the effigy as C-001. It went on to cut a section, search the literature and suggest a decision. |
| Project | Check the Flags | Ran. The section was already on record, so it did not cut another. The modern-features check timed out twice at OpenStreetMap's map service, and the agent said so. |
| Project | Second Look | Records opened and Gemini 3.8 Flash was asked; "A second model agrees it looks built" is on C-001's record. |
| Project | Search What Is Published, Prepare My Review | Both off, rightly: the screening run had already logged a source and suggested a decision. Not clicked while on. |
| Project | Draft a Report | Off: no candidate is decided as having no match. Not clicked while on. |
| Project | Run the Whole Search | Not clicked here. It is A7's button. |
| Project | Review the Finds… ⌘R | The review opened on C-001 with the agent's suggestion. Recorded it as already published. |
| Project | Research Record ⇧⌘R | Notes opened on Record. |
| Project | Show in Finder | Finder came forward on the project's folder. |
| Project | Stop the Run ⌘. | Stopped the screening run mid-way; the chat went idle. Off when nothing runs. |
| Help | Welcome Guide | The guide opened; Close guide closed it. |
| Help | Commands and Shortcuts ⌘/ | The commands and the shortcuts were written into the chat. |
| Help | How a Search Works | The Toolbox opened on that tab. |
| Help | Dighouse on GitHub | Not clicked: it opens the browser. The tutorial is added to this menu by A6. |

Edit, Window and the rest of the Dighouse menu are the system's own and were left as they are.

**In-app menus share one look.** One menu panel (MenuPanel in Controls.swift) now draws all of them: a row 30 points high, the icon on the left, a divider between groups, a heading where it helps, and a green tick on the current choice. A menu with a second line (Workflows) shows it in full, on up to three lines.

| Menu | Picture |
|---|---|
| A chat's menu (right-click, or the "…" that shows under the pointer): Rename, Archive | loop4/a2-menu-chat.jpg |
| A project's menu: Research record, Show in Finder, Export project, Remove from list | loop4/a2-menu-project.jpg |
| The map's view menu, with the tick on Composite | loop4/a2-menu-map-view.jpg |
| Workflows, with what each does, where it stands, and why a greyed one cannot run | loop4/a2-menu-workflows.jpg |
| The model panel, with the tick on the model in use | loop4/a2-menu-model.jpg |
| The + button with a candidate selected | loop4/a2-menu-attach.jpg |

The right-click was made by test tooling, which finds the row by where it sits in the window. The "…" button depends on the pointer being over the row, which tooling cannot do, so that button was seen only when the real pointer happened to rest on a row.

**The A1 list, as far as this goal goes**

| # | Now |
|---|---|
| 1 | Fixed. "Looks built" is green in every look. |
| 2 | Fixed. A flag with its section and modern-features check on record reads "Needs your decision" (loop4/a2-review.jpg). |
| 3 | Fixed, as the table above shows. The Run menu is now Project. |
| 5 | Fixed. With nothing selected the + button opens the file panel directly. |
| 6, 7 | Fixed, as above. |
| 8 | Fixed. Find a chat has the palette's frame (loop4/a2-find-a-chat.jpg). |
| 9 | Fixed early: one arrow, →. |
| 11 | Fixed. The Toolbox is always a point taller than the window, so its scroll bar stays. |
| 12 | Fixed. It is a button, "Open a project folder…". |
| 13 | Fixed. Both pictures sit on their captions, at the left. |
| 14 | Fixed: "Could not open". A source with no link has no arrow because there is nothing to open. |
| 15 | Fixed. |
| 16 | Fixed: "See every open survey" and "Next: Read". |
| 21 | Fixed. The names are under "Technical details". |
| 23 | Fixed for new chats: a second chat from the same workflow is numbered ("Get the terrain 2"). Chris's three older chats keep their names. |

Also changed: "Prior-art sweep" is now "Search what is published", in the app's words everywhere.

### 2026-11-14, A3: every tool, run once

All 32 tools were called once from Python against the real services, on a scratch project of about 200 m at Serpent Mound (`loop4-tools`, outside Chris's projects). Those marked "also in chat" were called by the agent itself, on Terra through engine 0.167, in the A2 run on the other scratch project.

| # | Tool | How it was run | Result |
|---|---|---|---|
| 1 | find_place | Python | Passed. "Serpent Mound, Ohio" came back as an archaeological site with its area. |
| 2 | open_surveys | Python | Passed. The four surveys Home lists. |
| 3 | survey_area | Python | Passed in 2 to 18 s. 573 sq km, the USGS surveys that cover it, and the recorded sites. |
| 4 | find_gaps | Python | Passed. A 4 by 4 grid, 5 sites on open record, four sources answered. |
| 5 | open_resources | Python | Passed. |
| 6 | search_records | Python | Passed. 19 records for "mound" around Cahokia and 14 for "Serpent Mound"; none inside the small box in Adams County, which is a true answer. |
| 7 | init_project | Python; also in the app | Passed. The folder, the method file and a git history. |
| 8 | find_data | Python; also in chat | Passed. USGS OH_StatewideP3_2_B21. |
| 9 | fetch_terrain | Python; also in chat | Passed in 5 s. 8.18 ground returns per sq m. |
| 10 | view_terrain | Python | Passed. A picture came back. |
| 11 | make_tiles | Python; also in chat | Passed. 1 tile here, 4 in the chat run, none unreadable. |
| 12 | next_tiles | Python; also in chat | Passed. |
| 13 | view_tile | Python; also in chat (hillshade and local relief for each tile) | Passed. |
| 14 | render_tiles | Python | Passed. Sky view drawn for the tile. |
| 15 | record_verdict | Python; also in chat | Passed. |
| 16 | flag_candidate | Python; also in chat | Passed. C-001 with its record and relief picture. |
| 17 | cut_section | Python; also in chat | Passed. 122 m long, 449 ground returns near the peak. |
| 18 | second_look | Python; also from the app, by Gemini 3.8 Flash | Passed. It refuses a second look from the model that flagged the find, which is the rule; that is how the first call in the script failed. |
| 19 | check_modern | Python; also in chat | **OpenStreetMap's map servers (Overpass) were down.** overpass-api.de, overpass.private.coffee and two other public copies all timed out or answered 502 and 504 for an hour. The tool gave up in 47 s with a plain message and wrote nothing on the record. To try again when they are back. |
| 20 | add_evidence | Python | Passed. |
| 21 | search_literature | Python; also in chat | Passed. Five works from OpenAlex. |
| 22 | read_source | Python; also in chat | Passed for a Wikipedia page (31,808 characters) and a DOI that leads to PLOS (45,878). The first link tried, a book PDF at oapen.org, was refused with 403, and the tool said to log it as could not open. |
| 23 | log_source | Python; also in chat | Passed. |
| 24 | suggest_decision | Python; also in chat | Passed. |
| 25 | set_status | Python; also from the review in the app | Passed. |
| 26 | list_candidates | Python; also in chat | Passed. It lists what each record still lacks. |
| 27 | add_control | Python | Passed. |
| 28 | write_summary | Python; also in chat | Passed. |
| 29 | document_project | Python; also in chat and on opening the project | Passed. |
| 30 | run_status | Python; also in chat | Passed. |
| 31 | export_finds | Python | Passed. The file is under private/exports. |
| 32 | import_terrain | Python | Passed. The project's own GeoTIFF came back in as a second terrain. |

- **Nothing in Dighouse's own code failed.** The one failure is an outside service.
- **The Toolbox's Open data page now says so.** OpenStreetMap was shown as Online, because the page asked only its place search. It now also asks the two map servers the modern-features check uses, and reads **Partly online** with the reason when they do not answer: "10 of 11 online" (loop4/a3-open-data.jpg). A service still being checked no longer has the tooltip of one that answered (A1 item 4).
- **Two offline tests added** (7 now): a map service that is down leaves the modern-features check open and writes nothing on the record, and counts what is mapped once it answers; a page that a publisher refuses says to log it as could not open. `uv run pytest`: 7 passed.
- **Not tried:** a search that would return the Environment Agency, AHN or IGN ground models (their services answered the status check; building from them is in the live tests).

### 2026-11-14, A4: the research record holds up when a project changes hands

**What was wrong.** A shared project arrives without private/ and data/, and the record was rebuilt from the state kept there. So the first time the other person opened the project, RESEARCH.md was rewritten to say no ground had been looked at. The record did not survive the handover it was written for.

**What changed**

- **The record survives.** `notes/record.json` keeps which surveys were used and what each tile showed, with no locations, and it travels with the project. The record is built from this Mac's state plus whatever that file lists that this Mac lacks, marked "earlier".
- **A newcomer can read the top.** RESEARCH.md opens with **In short** (the question, how much ground was looked at, how many finds, how much was read), **The finds** (a link to each record with its decision) and **How to continue** (open the folder, ask the agent, and the next thing to do). The paragraph about the file itself moved to the bottom. In the app the Record tab no longer puts its own explanation above the file's, and a link to a find opens its record.
- **Rebuilt at every point it should be.** It was already rebuilt at a run summary, a decision, on opening the project and by document_project. A run that ended without a summary, or that the person stopped, left it stale. The app now rebuilds it whenever a run in a project ends, and after a second look. No model is used.
- **A check that got no answer leaves a trace.** When the map service is down, the dated notes say so, and the record's Candidates table reads "not yet: the map service did not answer on" that day.
- **The app knows a shared project.** Its overview says "Pick up where it was left", with how many tiles were screened before and one button, **Carry on**. The stages read "Done on the other Mac". The map pane says the terrain stayed on the other Mac. A tool that needs a location says the location is not on this Mac, where it used to say "Unknown id".
- **The agent is told.** It begins its first message by saying what the record shows is done. In a shared project it does not fetch or screen the ground again unless asked (skills/dighouse/SKILL.md and the method file of new projects).
- **Export refreshes the record first**, and is now also in the File menu and a project's menu.

**Checked on a real run.** The scratch project at Serpent Mound, run on Terra: terrain, screening, section, second look (Gemini 3.8 Flash), literature search, a decision in the review.

| Check | Seen |
|---|---|
| The record against the project's files | 4 tiles in the state and 4 rows; verdicts 1 built, 1 natural, 2 modern in both; 1 candidate with its decision by Chris Sotraidis in both; 1 source, could not be opened, in both; 2 literature searches in the notes and 2 listed; 2 run summaries and 2 in History; no coordinates. |
| Rebuilt when a run ends | Moved RESEARCH.md out of the project, then asked the agent for one word with no tools. The file was back within four seconds of the reply. |
| Rebuilt on a decision and on opening | The decision was in the record at 12:57, the minute it was recorded. Opening the project at 13:16 rewrote it with the new top (loop4/a4-record-top.jpg). |
| The link to a find | Clicking "C-001 Serpent Mound effigy" in the record opened its record. |
| Export | File › Export Project…, saved as a zip of 707 KB. Unzipped into another folder: no private/, no data/, and no coordinate in any file or in the git history it carries. |
| Open the copy | File › Open Project Folder… The project took its name from PROJECT.md. Overview: "Pick up where it was left… 4 tiles screened and 1 find", stages "Done on the other Mac" (loop4/a4-handover-overview.jpg). |
| Start a run there | Pressed Carry on. First lines of the chat: "I'll use the Dighouse research record to trace the handover, then check the unopened sources and any missing candidate suggestions. I'll leave the previously screened ground alone and finish by updating the summary." Then: "The earlier run screened all four tiles and identified Serpent Mound as C-001; Chris already decided it was published. Its ground section and independent second look are recorded, while one source remained unopened and the modern-features check was not completed." (loop4/a4-handover-chat.jpg) |
| It skipped what the record lists | No terrain was fetched and no tile screened: the copy still has no data/ or private/. It opened the one source that had not been read (Garner 2023), logged it as read, and wrote a run summary that begins "Continued the handed-over project without downloading terrain or rescreening." |
| The copy's record afterwards | Still lists the survey and the 4 tiles, each marked "earlier", and now "1 published source was read". |

`uv run pytest`: 8 passed. The new test hands a project over, checks the record keeps its tiles and survey, that a tool needing a location says why it cannot run, and that work done afterwards is added to the earlier work.

**Not checked:** a handover between two real Macs, and a receiver who then fetches terrain for the same place.

### 2026-11-14, A5: an archaeology look, drawn in SwiftUI

**Found on the way: Dighouse could not start in Graphite.** With Graphite saved as the look, the app stopped before its window opened, three times in a row (three crash reports at 13:33). Graphite's menu colour was borrowed from the theme, which was still working itself out at that moment. Switching to Graphite while the app ran had hidden this, and had also given Graphite's menus Earth's brown. Graphite now has its own menu colour, and the app starts in all three looks.

**Six drawings** (app/Sources/Dighouse/Drawings.swift), each a set of lines on a 24-point grid, stroked at the weight of the system symbols beside them. No image files.

| Drawing | Stands for | Where |
|---|---|---|
| Trowel | The whole search, and the agent | Run the whole search, the Workflows button, "Ask the agent", the Agent in the Toolbox |
| Mound in section | The bare ground | Get the terrain, the Bare ground stage, the map with no terrain |
| Survey grid | Screening, tile by tile | Screen the tiles, the Screening stage, open surveys on Home, no projects yet |
| Soil layers | Checking a flag with a section | Check the flags, the Checks stage, cut_section in a chat, an empty notes list |
| Sieve | Searching what is published | Search what is published, that stage, literature searches in a chat, empty searches and Sources |
| Brush | Deciding what a find is | Prepare my review, the Your decisions stage, a suggestion in the review, no candidates yet |

System symbols stay where they already fit: people for the second opinion, an envelope for the report, binoculars for choosing a place, a book for the research record.

- **Stages.** The overview's six stages each have their drawing, in colour once done, with a green tick at the end of the row. The Next card and the top bar carry the drawing of the stage that is next. The Toolbox's six stops carry them too.
- **The thinking indicator.** One sign that the agent is at work: a trowel scrapes along a line of soil and the grains hop as it passes, turning green at the top. It replaced every system spinner, 22 places in all. `rg ProgressView app/Sources` now finds none.
- **Empty states.** A place with nothing in it has its drawing on a round of bare ground: the map (mound or grid), Records (brush), Sources (sieve), the notes lists (layers), Find a chat and ⌘K (sieve), no projects (grid), the end of a review (brush).
- **Also:** the sidebar's and Settings' icons sit in a column of their own, so the words line up (A1 item 10). The lone copy button that showed under the agent's latest message while it was still working is gone. "Sparkles" for asking the agent became the trowel.

| Check | Seen |
|---|---|
| Stage list, Workflows menu, an empty state, in each look | Earth: loop4/a5-earth-stages.jpg, a5-earth-workflows.jpg, a5-earth-empty.jpg. Canopy: a5-canopy-stages.jpg, a5-canopy-workflows.jpg, a5-canopy-empty.jpg. Graphite: a5-graphite-stages.jpg, a5-graphite-workflows.jpg, a5-graphite-empty.jpg. |
| The indicator, two frames, in each look | Taken 0.4 s apart from the top bar during a run on Terra: loop4/a5-earth-indicator.jpg, a5-canopy-indicator.jpg, a5-graphite-indicator.jpg. In each the trowel has moved and a grain is in the air in one frame. It also showed beside "Working" in the chat and on the running chat's row in the sidebar. |
| Reduce Motion | With the setting on, two frames a third of a second apart were identical: the trowel at rest, the grains on the ground. With it off they differed. This was checked by drawing the indicator outside the app with SwiftUI's Reduce Motion flag set; the Mac's own setting was not changed. |
| Every text size | At Larger the menus' drawings grow with the words (loop4/a5-earth-larger-text.jpg). |
| The Toolbox and a new chat | loop4/a5-toolbox-how.jpg. |
| ProgressView left in the code | None. |

**Not checked:** the indicator with the Mac's Reduce Motion setting itself, and how the drawings read on a display that is not Retina.

### 2026-11-14, A6: a tutorial for a first project

**"Start your first project"** is a card on Home for anyone with no project, or only their first. It walks through one real search at Serpent Mound in six steps. Each step is one sentence in a bar under the top bar, and the one control to press wears a green ring. Help › First Project Tutorial and ⌘K start it too. The welcome guide is as it was.

- **Where it stands is read from the project,** so nothing has to be remembered about a run: no terrain means step 2, tiles not looked at means step 3, a find means step 4. The three steps a person takes by looking (Records, Notes, the decision) are kept in the settings. Leaving, going elsewhere or quitting the app all come back to the same step.
- **Leave** hides the bar. Home's card then reads "Continue your first project".
- **While the agent works** the bar says what it is doing and shows the trowel; nothing is ringed, because there is nothing to press.
- **Step 2 is the person's own.** A project made in the tutorial does not start fetching by itself, and its overview offers "Get the terrain", where a project normally offers the whole search.
- **Also fixed:** the overview's Next card squeezed its words into a column three words wide in a narrow chat; its button now goes under the words.

**Run-through from empty settings.** Chris's settings were saved, Dighouse's settings were emptied (keeping the window size, the cheap model and a scratch projects folder), and the app was started as if for the first time. Afterwards his settings were put back and compared: identical.

| Step | The sentence | The ringed control | Seen |
|---|---|---|---|
| Before | (the welcome guide, Skip for now) | **Start your first project**, on Home | loop4/a6-01-home-card.jpg |
| 1. Choose the place | "Start with a place everyone knows: Serpent Mound in Ohio. Its name, question and area are filled in. Press Create project." | **Create project** | The page had the name, the question, a 300 m area and the USGS survey that covers it (loop4/a6-02-step1-create.jpg). |
| 2. Get the terrain | "Now get the ground. The agent downloads the laser scans for this spot and strips the trees away. Press Get the terrain." | **Get the terrain** | The agent fetched the survey and cut 4 tiles in about a minute (loop4/a6-03-step2-terrain.jpg, a6-06-step2-working.jpg). |
| 3. Look at the tiles | "The ground is cut into squares called tiles. The agent looks at each one for shapes people built. Press Next: Screen the tiles, at the top." | **Next: Screen the tiles** | Terra screened 4 of 4 and flagged the serpent as C-001, then cut a section and searched the literature. About three minutes (loop4/a6-07-step3-screen.jpg, a6-08-step3-working.jpg). |
| 4. Open the find | "The agent flagged a find. Press Records to see its pictures and how it was checked." | **Records** | loop4/a6-09-step4-records.jpg |
| 5. Read the research record | "Everything looked at and read is written in the research record, so anyone can pick this project up. Press Notes." | **Notes** | The record opened at "In short" (loop4/a6-10-step5-notes.jpg, a6-11-step6-record.jpg). |
| 6. Make a decision | "Now make the call yourself: a person decides, never the agent. Press Review and decide." Then, in the review: "Check the suggestion against the pictures. Then record what you think the find is. Press Record." | **Records**, then **Review and decide**, then **Record** | Recorded C-001 as already published. The bar read "First project: done" with Finish (loop4/a6-12-step6-review-button.jpg, a6-13-step6-review.jpg, a6-14-done.jpg). |

| Check | Seen |
|---|---|
| A decided find without leaving the tutorial | Yes: from the card on Home to "1 decision written into the records" in about nine minutes, pressing only ringed controls. |
| Every step's control is highlighted | Each ringed control above also carries "The tutorial's next step" for VoiceOver, and that is how each was found and pressed. At every step exactly one control was ringed, except where both the overview and the map offered Get the terrain; now only one of them is. |
| Quit and reopen | Quit at step 2 and again at step 3. Each time the app reopened on the tutorial's project with the bar at the same step (loop4/a6-04-resumed-after-quit.jpg). |
| Leave and come back | Leave at step 2: the bar and ring went. Home's card read "Continue your first project" (loop4/a6-05-home-continue.jpg). Pressing it reopened the project at step 2. |
| After Finish | Home, with no card. Help › First Project Tutorial started it again at step 1. |
| Chris's settings | Put back and compared with the copy taken before: the same 24 keys and values. |

**Not checked:** the ring's slow pulse with Reduce Motion on (the code leaves it still), and a tutorial run in which the agent flags nothing (the bar then says what to type).

### 2026-11-14, A7: "Find and report back"

One button runs the whole search as a goal and comes back with a report. It is on Home's place box, on a project's overview, in the Workflows menu and the Project menu, and as **/investigate** (which takes the place of /run).

- **On Home,** typing a place gives two buttons beside its name: **Find and report back**, which looks the place up, makes a project 600 m across around it and starts, and **Choose the area**, which opens New project as before.
- **The run** is a goal, so the engine keeps taking turns until the report is written. The agent does everything but the second look and the decisions. When it is done, Dighouse asks the second-look model about each find itself, then shows the report.
- **The strip** shows the trowel, "Stage 2 of 6: Looking at the tiles" and **Stop**. The stage comes from the last tool the agent called, so it is what the agent is doing, and it can step back (to cut another section, say).
- **The report** is a new tool, `write_report` (33 tools now), built only from the project's records, so it cannot say more than they do. Eight short parts: what was asked, the data used, what was looked at, what was flagged and why, what is already published, what was ruled out, what needs your decision, what to try next. The agent's own words in it are one short paragraph of advice. No coordinates; a note that holds one is refused. It is written to `reports/`, linked from the research record's "Where things stand", and opens from the overview and Project › Search Report.
- **In the app** the report opens when the run ends, with one button per decision waiting ("Decide C-001"). Each opens the review on that find with the suggestion filled in.
- **Stop** pauses the goal and ends the turn. The research record then says "The last run was stopped by a person on (day) at (time), during: (stage)", until a run finishes after it.

| Check | Seen |
|---|---|
| One press, on a known site, with primary / 6.1 Terra | Typed "Serpent Mound, Ohio" on Home and pressed Find and report back (loop4/a7-01-home-place.jpg). Nothing else was typed or pressed. The project was made, the goal set, and the strip read Stage 1 of 6 within 15 s (loop4/a7-02-started.jpg, a7-03-stage2.jpg, a7-04-stage4.jpg). |
| It ends with the report on screen | At 6 min 50 s the agent finished: 9 of 9 tiles, 3 finds, 33 sources logged, a summary and the report. Dighouse then asked Gemini 3.8 Flash for a second look at each find, and at 8 min 4 s the report opened with Decide C-001, Decide C-002 and Decide C-003 (loop4/a7-07-report.jpg). |
| The report's claims match the records | Checked line by line against the project's files: 9 tiles with 3 built, 1 possible, 3 natural, 2 modern; USGS OH_StatewideP3_2_B21, 0.36 sq km, 6.9 ground returns per sq m; the three sections at 2.47 m, 2.32 m and 0.33 m, each in the ground; a second look that agrees on each, by Gemini 3.8 Flash; no modern-features check on any, because the map service did not answer; 3 sources read and 16 that could not be opened; suggestions of already published, already published and modern; no decision yet. No coordinate, and nothing called new. |
| Two minutes to read | The first report ran to about 700 words, because it repeated each find's checks and quoted each source at length. It now gives one sentence per find and per source and says a failed map check once: 546 words for this project. |
| A decision button | Decide C-002 opened the review at "2 of 3" with the agent's suggestion and reason filled in (loop4/a7-13-decide-from-report.jpg). No decision was recorded. |
| From a project's overview and as /investigate | A second known site, Mound City Group, made as a scratch project. Its overview's main button is Find and report back (loop4/a7-08-overview-button.jpg). Typing /inv and Return started the search (loop4/a7-09-slash-investigate.jpg). |
| Stop | Pressed Stop in the strip at 96 s, during stage 2 (loop4/a7-10-before-stop.jpg). The run ended within 6 s and did not start again. All 4 tiles had verdicts and C-001 had its record; nothing was half-written, and the project's history had no uncommitted change. The research record read: "The last run was stopped by a person on 2026-11-14 at 14:15, during: Looking at the tiles", and Still to do listed the section, the map check, the second look, the literature and the decision for C-001. The overview then offered Check the flags and, beside it, Find and report back to finish in one go (loop4/a7-11-after-stop.jpg, a7-12-overview-after-stop.jpg). |

`uv run pytest`: 10 passed. Two new tests: the report says what the records say and refuses coordinates; a stopped run is on the record until a run finishes.

**Not checked:** a search that runs out of usage part-way (the app then notes it in the chat and still reports), a place name that cannot be found (the box says so), finishing a stopped search with the second button, and a search on a place outside the United States.

### 2026-11-14, A8: one product, then docs

**A1's screenshots were taken again** in the finished build: every page in Earth at 1440 × 900, and Home and a project in Canopy and Graphite (loop4/a8-*.jpg, 33 pictures). The menu bar was read through accessibility again.

**The A1 list is closed.**

| # | Rough edge | Now | Picture |
|---|---|---|---|
| 1 | Canopy: "Looks built" and "Possible" the same orange | Fixed in A2: green and amber in every look | loop4/a8-33-canopy-project.jpg |
| 2 | "Not yet checked" on a checked candidate | Fixed in A2: "Needs your decision" | loop4/a8-13-records.jpg, a8-17-review.jpg |
| 3 | Gaps in the menu bar | Fixed in A2, with the tutorial added to Help in A6 and Search Report to Project in A7 | read through accessibility |
| 4 | A tooltip that said a service had replied while it was still being checked | Fixed in A3 | loop4/a8-18-toolbox-open-data.jpg |
| 5 | A one-item menu on the + button | Fixed in A2: it opens the file panel directly | loop4/a2-menu-attach.jpg |
| 6, 7 | Three looks for in-app menus; Workflows cut its descriptions | Fixed in A2: one panel, full descriptions | loop4/a8-07-workflows-menu.jpg, a8-08-model-panel.jpg |
| 8 | Two search panels that looked different | Fixed in A2 | loop4/a8-10-jump-palette.jpg, a8-32-find-a-chat.jpg |
| 9 | Three kinds of arrow | Fixed in A2: one, → | loop4/a8-04-home-open-surveys.jpg, a8-05-new-chat.jpg |
| 10 | Sidebar and Settings labels not lined up | Fixed in A5: the icons have a column of their own | loop4/a8-22-settings-general.jpg |
| 11 | The Toolbox shifting sideways between tabs | Fixed in A2 | loop4/a8-19-toolbox-how.jpg, a8-21-toolbox-more-tools.jpg |
| 12 | A text link among buttons on Home | Fixed in A2: "Open a project folder…" | loop4/a8-04-home-open-surveys.jpg |
| 13 | The review's relief picture floating in its column | Fixed in A2 | loop4/a8-17-review.jpg |
| 14 | "Could Not Open" in title case | Fixed in A2. A source with no link still has no arrow, because there is nothing to open | loop4/a8-15-sources.jpg |
| 15 | The Data tab starting further left | Fixed in A2 | loop4/a8-16-data.jpg |
| 16 | Buttons over four words | Fixed in A2. "Find and report back", added in A7, is four | loop4/a8-12-project-overview.jpg |
| 17 | System spinners everywhere | Fixed in A5: none left in the code | loop4/a5-earth-indicator.jpg |
| 18 | Stages with no picture of their own | Fixed in A5 | loop4/a8-12-project-overview.jpg, a8-19-toolbox-how.jpg |
| 19 | Generic system icons | Fixed in A5 for the aeroplane, the bank, the light bulb, the arrow in a circle and the wrench beside each tool. **Left, and why:** the chip stays for "the model", in Settings and on "Choose another model", because a model is the one thing here that is a piece of computing and none of the six drawings stands for it | loop4/a8-24-settings-models.jpg |
| 20 | Empty states of one grey line | Fixed in A5 | loop4/a8-32-find-a-chat.jpg, a5-earth-empty.jpg |
| 21 | Raw plugin names in the Toolbox | Fixed in A2: under Technical details | loop4/a8-21-toolbox-more-tools.jpg |
| 22 | The research record explaining itself twice | Fixed in A4 | loop4/a8-14-notes.jpg |
| 23 | Three chats with the same name | Fixed in A2 for new chats. **Left, and why:** Chris's three older chats are his, so they keep their names | loop4/a8-01-home.jpg |

Nothing new was found in the second pass that is wrong. Two things read as unfinished and are noted in HANDOFF.md: the strip's stage can step back during a whole search, and a search report grows with the number of finds.

**README pictures** were retaken at 1440 × 900 in Earth, with the three test projects and loop 4's scratch projects out of the sidebar: Home, New project (Mound City Group), Maiden Castle, Angel Mounds, a record, the Toolbox and Open data. This time each is the window alone, taken with `screencapture -l`, so there is no Computer Use pill to cover and no pointer over the words. Open data shows OpenStreetMap as Partly online, which was true when it was taken; the caption says so.

**Docs brought into line:** README (33 tools, the tutorial, Find and report back, the look, the menus, handing a project over, the engine it needs, 10 offline tests), concept.md (five tabs, the search report, the newest engine, the project folder as it is now), HANDOFF.md (rewritten for whoever comes next) and this file.

**Chris's things, as found:**

- His settings were exported before the loop began and put back at its end; the two were compared key by key.
- His projects list is the ten projects he had. Loop 4's scratch projects are in `~/Documents/Codex/2026-11-14/dighouse-loop4/work` and not in the list.
- The model is primary / 6.1 Terra and the second-look model Gemini 3.8 Flash, as before. Every message sent to a model in this loop went to Terra, and every second look to Gemini 3.8 Flash.
- The chats made for testing were archived.
- **Changed, by design:** opening his projects in the new build rebuilt each one's RESEARCH.md in the new form and added `notes/record.json`, each as a commit in that project's own history. Angel Mounds and Maiden Castle were opened; the others catch up when he opens them.

`uv run pytest`: 10 passed. main is pushed and clean.

### Where loop 4 stopped

All eight goals are checked. Nothing is half done. What was not verified, and what waits on Chris, is listed in [HANDOFF.md](HANDOFF.md).









