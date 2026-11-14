# Dighouse goal loop 3: make it easy to use

Last updated: 2026-11-13

This loop follows [NEXT_LOOP.md](NEXT_LOOP.md). Read [HANDOFF.md](HANDOFF.md) first. The first loop made the app understandable and the second made it find things. This one makes it easy: a person who is curious about archaeology, and is not a programmer, should be able to open Dighouse, start a project, pull in data, run a search and decide on what it finds, without reading anything first. Someone who knows Codex should find the chat works the way they expect.

## What "easier" means here

Three people to keep in mind, and every goal should help at least one of them:

- **A first-timer** who has never used lidar or an agent. They need the next step to be obvious on every screen.
- **A returning user** with a project half done. They need to pick up where they left off and get to their candidates fast.
- **A Codex user.** They expect slash commands, @-mentions, editing a message, forking, a stop button that stops, and to see how much of their usage is left.

## Goals

Each goal is done when its check passes in the running app. Record the date and what was seen in the Log. Work them in order, except that anything U1 finds to be broken comes first.

| Goal | What | Check |
|---|---|---|
| U1 | **Walk it as a first-timer.** Start from a clean setup (empty defaults, no projects) and go from first launch to a first decided candidate, writing down every place that needs a guess, a wait with no explanation, a dead end or a word a newcomer would not know. | A dated list of friction points in the Log, each with a screenshot, ranked by how badly it stops someone. The goals below are adjusted if the list shows something bigger. |
| U2 | **Slash commands.** Typing `/` in the message box opens a menu that filters as you type, moves with the arrow keys, runs on Return and closes on Escape. Dighouse's own commands: `/research`, `/new-project`, `/terrain`, `/screen`, `/check`, `/second-look`, `/sources`, `/decide`, `/report`, `/run`. Codex's: `/new`, `/model`, `/effort`, `/rename`, `/fork`, `/undo`, `/compact`, `/goal`, `/status`, `/archive`, `/help`. A command that does not apply here (no project open, nothing to undo) is shown greyed with the reason. | Every command runs from the keyboard alone and does what its line says. `/help` lists them all. Typing `/sc` and Return starts screening. |
| U3 | **@-mentions.** Typing `@` offers the project's candidates, tiles, sources and files, and recent places. Picking one puts a chip in the message, and the agent receives the exact reference (a candidate id, a tile name, a file path). | "Cut a section through @C-002" runs on C-002. "@" followed by part of a file name finds it in the project. |
| U4 | **The chat works like Codex.** Edit and resend your last message (rolls the chat back), retry the last answer, fork a chat from any message, copy a message, compact a long chat, search across all chats, see archived chats and bring one back. Long runs use Codex goals, so "Run the whole search" keeps going across turns until it is done or needs you. | Each action works on a real chat in the app. A whole search set as a goal finishes without a "continue" from the person. |
| U5 | **Know what is happening and what it costs.** A quiet status line shows the model, how much of the chat's context is used, and the account's usage left (from the engine's rate limits). Long waits (an England download, a slow map service) show what is happening, roughly how long, and a Cancel. | Start a 1 sq km England fetch: progress and Cancel show, and Cancel stops it and leaves the project consistent. The usage figure matches what Codex reports. |
| U6 | **A shorter road to a first project.** From Home, typing a place name ("Maiden Castle") offers to start a project there in one step, with the area and the open lidar already chosen. Every empty screen (a project with no terrain, no candidates, no sources) says what it is for and has one button for the next step. The run strip names the next step and runs it. | A first-timer goes from Home to terrain on screen in three clicks or fewer, and from there to a screened project with one more. |
| U7 | **Pulling in data is visible and in your hands.** A project shows what data it holds (each terrain: source, date flown, area, ground returns per square metre, size on disk), with Fetch more, Widen the area and Use another survey. A person can drop their own LAZ, LAS or GeoTIFF into the project and the tools use it. Finds, the project folder and a report draft can be exported from one place. | Drop a GeoTIFF in: it becomes a terrain that tiles and renders. Widen an area: the new tiles join the old ones. Export makes a GeoJSON and a zipped project with no coordinates outside `private/`. |
| U8 | **A map you can work on.** Pan and zoom with the trackpad, switch the view (composite, hillshade, local relief, sky view) from the map, toggle tiles and candidates, click a tile to see its verdict, click a candidate to open its record, and draw a line to have a section cut there. | Each of these done by hand in the app on the Mound City project. A drawn line produces a section on the right record. |
| U9 | **Deciding is quick.** "Needs you" opens a review that goes one candidate at a time: the relief, the section, the checks and the sources side by side, with the decisions as buttons and keys, and Next. A second look can be asked for all waiting candidates at once. | Review all five Mound City candidates from the keyboard in under three minutes, with each decision and name written into its record. |
| U10 | **Find anything fast.** ⌘K opens a palette that jumps to any project, chat, candidate or command. Help lists every shortcut. | From anywhere, ⌘K and a few letters open the Angel Mounds C-001 record. |
| U11 | **Failures say what to do.** Every error a person can see (a service down, a model that failed, a refused page, an engine that stopped) says in plain words what happened and offers the next step (Retry, Choose another model, Open the page yourself, Restart the engine). Nothing fails silently. | Turn the network off mid-fetch, pick a model that fails, and stop the engine: each shows a plain message with a working button. |
| U12 | **One product, then docs.** A pass over every screen for consistent words, spacing, buttons and icons, at the zoomed, half-width and narrow sizes and in all three looks. Then the README screenshots are retaken, the docs match the app, and everything is merged. | The click-through passes at every size and look. README, concept, HANDOFF and this file agree with the app. `main` is pushed and clean. |

## Chris's review, 2026-11-13 (after U8)

Chris used the app after U1 to U8 and sent screenshots. His notes are goals F1 to F11, worked before U10 to U12; U9 is folded into F1. The audience is people with little or no archaeology: every screen has to say what it is for and what to do next.

| Goal | What | Check |
|---|---|---|
| F1 | **The review comes prepared.** The agent suggests each decision and its reason (where a find is published, what makes it modern) as part of its work, and the review fills them in; the person accepts with Return or changes them. Asking for second looks is one short, clear button. | Reviewing the five Mound City candidates starts from a suggestion on each that came from the record, and needs only Return where the suggestion is right. |
| F2 | **Buttons look professional.** One button style used everywhere, short labels (no sentence on a button), icons where they help, one main action per screen. | Screenshots of Review, Records, Data, Toolbox and Settings show the same buttons and no label over four words. |
| F3 | **Every slash command works well.** | Each of the 21 commands run once in the app, with the result written in the Log. |
| F4 | **Home reads well and moves.** The opening text is bigger; the marks on Home and on a new chat animate like the one in the sidebar. | Seen in the app. |
| F5 | **Nothing looks clickable that is not, and everything clickable does something visible.** "Open surveys / Known sites" reads as a switch with the chosen side marked. | Click-through of Home, Toolbox and Settings: every control gives a visible result. |
| F6 | **Settings, gone over.** Personalize, Models and testing, How it runs (what the engine is, what the model is, and how to use Claude or any other maker's model), Data and privacy, About. | Each page reviewed in the app; How it runs says plainly that the engine is Codex and the model can be Claude through OpenCodex. |
| F7 | **The tools live in Settings too.** A Tools page in Settings lists the archaeology tools and other tool servers; "Open the Toolbox" stays as the guided tour. | Settings › Tools shows every tool and the add-a-server control. |
| F8 | **The Toolbox's data page fits and does not surprise.** Services grouped by where they work (anywhere, United States, England, Netherlands, France, ancient Mediterranean), compact enough to see at a glance, status checked at the top, and "Try it" replaced by a button that says it starts a chat with the agent. | The page shows every service without long scrolling; pressing a service's button says first that it starts a chat. |
| F9 | **A project opens on its story so far.** Opening a project shows its question, what has been done (terrain, tiles, screening, checks, sources, decisions), what the last run found, and the next step explained for a beginner. | Opening Mound City shows the overview with the right counts and one next step. |
| F10 | **A project is its own little repository with a method.** A new project gets a METHODOLOGY.md that the agent follows and keeps, a notes index, and a git history of its records (data and private/ left out). The Notes tab shows the method, the run summaries and the daily log as separate parts. | A new project has the files and a first commit; a run adds a commit; the Notes tab shows the three parts. |
| F11 | **Pictures are crisp.** Text inside the section pictures and the map pictures is drawn large enough to read. | A new section picture's labels are readable at normal size. |


## Chris's priority, 2026-11-14

| Goal | What | Check |
|---|---|---|
| P1 | **Every project documents itself by one method.** A project keeps a research record a person or agent reads first: the data used, every tile looked at and its verdict, every candidate's checks and decision, every source and literature search, and what is still to do. Then nobody redoes work, and amateurs, archaeologists and agents can build on each other's projects. Older projects get the same files when opened. | A new project and an old one both have RESEARCH.md, a method that explains the record, and a git history without data/ or private/. The Notes tab and the overview show the record. |

Still with Chris from loop 2: dragging the two edges and dropping a Finder file (N2), and his review of the N9 screens. Still waiting on decisions, so not goals: a notarized download, a Notion button, bulk screening through the router, the licence, and going public.

## Rules for this loop

- Keep it simple. Prefer one clear control over three clever ones, and reuse the app's existing parts and look.
- Recheck every control you touch, and the ones next to it. A rewired button that breaks something else is worse than no change.
- Plain words in the app. A first-timer must understand every label; lidar is written in lowercase.
- Say only what was checked. A drag or a hover done by test tooling is not proof that a real mouse works; say it is unverified.
- Locations stay under `private/`. Nothing is ever called new. A person decides and sends.
- One branch and pull request per goal, squash-merged once its check passes, so each change can be reviewed on its own.

## The loop (every turn)

1. Read [HANDOFF.md](HANDOFF.md), this file and the Log below.
2. Pick the lowest unfinished goal (or a U1 finding that is breaking something).
3. Build it, then run its check in the running app and look at the result.
4. Fix what the check shows. Repeat until it passes.
5. Record the result in the Log with the date, run the tests, commit, open the pull request and merge it.
6. Stop when U1 to U12 are checked, when a decision is needed from Chris, or when the time Chris set runs out. Before stopping, write in the Log what is half done and where.

## Log


### 2026-11-13, U1: walked as a first-timer

Dighouse's settings were cleared (saved first and put back afterwards), so the app opened as on first launch: the welcome guide, no projects. The general chats live outside the settings and still showed in the sidebar. The walk went from first launch to a decided candidate in about 17 minutes: the guide, Cahokia as the first project, "Run the whole search" (11 minutes, no input: 6 tiles, 4 candidates, sections, 20 sources logged, a run summary), then C-001 marked as already published with a reason.

Friction, worst first:

| # | What stops a newcomer | Screenshot | What it becomes |
|---|---|---|---|
| 1 | A workflow shows its full instructions as if the person had typed them: a wall of tool names (`read_source`, `log_source`, `write_summary`). | [run](loop3/u1-04-run-prompt-wall.jpg) | Fixed here. |
| 2 | On the guide's first-project step the only button in view is Back. Create project is below nine places and needs a scroll. | [first project](loop3/u1-02-first-project-no-button.jpg) | Fixed here. |
| 3 | The line under a running chat said "Step 1 of 5: Find data…" while the agent was reading sources in step 4, because it stopped updating its plan. | [stale step](loop3/u1-06-run-later.jpg) | Fixed here. |
| 4 | The decision buttons are at the very bottom of a record, below every source (20 here). | [decision](loop3/u1-08-decision-at-bottom.jpg) | U9. |
| 5 | An empty project offers three ways to start (two cards and "Find and fetch lidar") and the map is blank: it does not show where the area is before terrain arrives. | [empty project](loop3/u1-03-empty-project.jpg) | U6. |
| 6 | Steps named only "Ran a command" (the agent reading files). | [run](loop3/u1-04-run-prompt-wall.jpg) | Fixed here. |
| 7 | The first project was called "Cahokia control run", a word a newcomer does not know. | [empty project](loop3/u1-03-empty-project.jpg) | Fixed here. |
| 8 | The places on the first-project step had no line saying why each is worth a first run, though Home has one for each. | [first project](loop3/u1-02-first-project-no-button.jpg) | Fixed here. |
| 9 | Model names start with a provider code ("Cl · Opus 5.5") that nothing explains. | [empty project](loop3/u1-03-empty-project.jpg) | U12. |
| 10 | Two pages of reading in the guide before setup. | [welcome](loop3/u1-01-first-launch.jpg) | U12, by trimming. |
| 11 | At the end of the run, what to do next (a second look on each record) is only in the agent's last message; nothing in the project points there. | [end of run](loop3/u1-07-run-end.jpg) | U6 and U9. |

Nothing was broken outright. The goals stand as written; U6 and U9 take items 4, 5 and 11.

Fixed in this pull request, each checked in the app:

- A message sent by a workflow shows the workflow's name ("Run the whole search"), with "Show the instructions" to unfold what was sent. Checked on today's Mound City run. Chats sent with an older wording of a prompt still show the full text, since they no longer match.
- The first-project choices (Skip or Close guide, Help me choose a place, Create project) are in the guide's footer, and each place has its one-line description. Checked by opening the guide from Settings.
- The line under a running chat shows the step that is running, and the plan's step only when nothing is running.
- Shell steps are named from the command: "Read PROJECT.md", "Searched the files", "Looked through the project folder". Not yet seen in a run; checked in U2.
- The Cahokia starting place makes a project called "Cahokia".

Left over: the walk made a second Cahokia project at `~/Documents/Dighouse/cahokia-control-run`; with the settings put back it is not in the sidebar.


### 2026-11-13, U2: slash commands

Typing `/` in the message box opens a list of 21 commands that filters as you type. Up and Down move the highlight, Tab fills in the name, Return runs it and Escape closes the list. A command that cannot run here is grey with the reason ("Needs a project", "Start a chat first", "Nothing to take back", "Wait for the run to finish"), and the highlight starts on the first one that can run. Dighouse's own commands run the same workflows as the Workflows menu; text typed after one (`/run look for ring ditches`) is added to its instructions. The Codex ones use the engine directly: `/fork` (thread/fork), `/undo` (thread/rollback), `/compact` (thread/compact/start), `/goal` (thread/goal/set). `/status` and `/help` write a note into the chat that is not sent to the model. Stop now pauses a chat's goal before it interrupts the turn, so the engine does not start the next one.

Checked in the app, keyboard only:

| Command | Seen |
|---|---|
| `/` in a general chat | All 21 listed; project commands grey with "Needs a project". |
| Escape, Down ×3, Return | The list closed; the highlight moved to `/status` and it ran. |
| `/sc` and Return, in Maiden Castle | Only `/screen` left; screening started (5 helper agents, 40 tiles) and finished all 42 tiles with 5 candidates. The chat shows "Screen the tiles". |
| `/status` | Model and effort, project, and "Usage for this period: 77% left, resets Nov 18" from the engine's rate limits. Context use shows once the engine has reported it for the chat. |
| `/rename Hillfort test` | The sidebar name changed. |
| `/fork` | "Copy of Hillfort test" opened with the whole history and a note that the original is untouched. |
| `/undo` in the copy | The message and its answer went; the message came back into the box to edit. The original kept both. |
| `/compact` | "Summarized the conversation so far" appeared as a step. |
| `/model`, `/effort` | The model list and the effort slider opened over the message box. |
| `/goal Reply with the single word done, then stop.` | The goal note, then "done", and the goal ended on its own. |
| `/help` | Both groups listed with their descriptions. |
| `/archive` twice | Both test chats left the sidebar. |
| `/new-project`, `/new` | The New project page; a new chat. `/new` first picked `/new-project` because it was listed first; an exact name now comes first. |

The other workflow commands (`/research`, `/run`, `/terrain`, `/check`, `/second-look`, `/sources`, `/decide`, `/report`) go through the same path as `/screen` and were seen in the list with the right availability, but not each run.

Found and fixed during the check: opening a chat that the Codex app also has open showed only "thread … already has an active writer" and hid the history. The history now shows, with a note that the chat can be read here but not continued until it is closed in the other app.

Seen and left for later: the modern-feature check stalled again in the Maiden Castle run (the map service was slow), and the agent stopped it. That is U5 and U11.


### 2026-11-13, U3: @ mentions

Typing `@` opens a list of what the open project holds: its candidates (with their names), tiles (with their verdicts), sources on the records, and its own files, then the other projects. It filters as you type, by name or by what is written beside it, and the same keys work as for commands. Picking one writes `@C-002` into the message and adds a chip above it; the chip's tooltip says what it points at, and its × keeps the words but drops the link. On sending, a short list of references goes with the message for the agent ("@C-002: candidate C-002 (Single mound west of the enclosure); its record is candidates/C-002.md"), and the chat shows only what was typed. Downloaded data and `private/` are left out of the file list, so no locations are offered.

Checked in Mound City Group:

- "Cut a section through @C-0", Down, Return: the chip read @C-002. Sent with "and tell me its height in one line". The agent read C-002.md, cut a section through C-002 and answered "about 1.6 m high (1.61 m) … The earlier filed section gave 1.63 m". Passed.
- "What does @2026": the only match was `notes/2026-11-13.md`. Picked and sent; the agent read that file and answered from its last entry. Passed.

Two small fixes from the same run: a step still open when a turn ends normally is now closed quietly, and "(stopped)" is added only when the engine says the turn was interrupted (the C-002 chat had shown two finished Python steps as stopped). Shell step names drop trailing punctuation ("Read C-002.md", not "Read C-002.md;").

Not done: recent places in the list (the plan said "recent places"); Home's starting places are one click away and a project's own area is already known to the agent.


### 2026-11-13, U4: the chat works like Codex

- **Message actions.** Under each answer: Copy, Ask again (on the last answer) and "Copy the chat up to here". Under the person's last message: Copy and "Edit and send again"; earlier messages show Copy on hover. They are always visible under answers because hover does not register over selectable text; Codex shows them the same way.
- **Edit and Ask again roll back properly.** Both take the chat back to just before the person's last message, including turns after it that had no message of their own (a /compact summary). The first try rolled back one turn, which removed only the summary and left two copies of the question.
- **Copy the chat up to here** forks the chat through that answer's turn (`thread/fork` with `lastTurnId`), so a person can try something else from a point in a run.
- **Find a chat** (sidebar, ⇧⌘F) searches every Dighouse chat by what was said in it and shows the line it matched, with its project; it opens the chat there. The engine's own `thread/search` reads every Codex chat on this Mac and took 72 seconds, so the app lists Dighouse's own folders and reads only their chat files, in both of the engine's file formats. **Archived chats** lists them with their projects, and Restore puts one back in its project's list.
- **Long runs as goals.** "Run the whole search" now starts as a Codex goal: the chat opens with a "Goal: Run the whole search" note, the engine keeps taking turns until the goal is met or it needs the person, and Stop pauses the goal before interrupting. A goal chat reopened later shows its goal note at the top.

Checked in the app:

| Action | Seen |
|---|---|
| Copy under an answer | The clipboard held the answer's text. |
| Ask again | Before the fix: a second question and answer were added. After: the last answer was replaced and the chat kept two turns, as before. |
| Copy the chat up to here, on the first answer | "Copy of Hillfort test" with only the first question and answer, and a note. |
| Edit and send again, in the copy | The message went back into the box and left the chat. |
| Find a chat: "Monks Mound" | Three chats from Angel Mounds and the Cahokia control run, each with the matching line. The first version found nothing: older chat files store messages differently. |
| Archived chats, Restore "Hillfort test" | It left the list and came back under Maiden Castle in the sidebar. |
| Run the whole search on a fresh Serpent Mound project | Started as a goal with no message from the person. It finished on its own: the goal ended as complete after 3 turns and 17 minutes, with no message from the person. Terrain (about 7 ground returns per square metre), 9 tiles, 3 candidates (the serpent embankment, the published conical mound, a doubtful knob), a section, modern check and sources on each (5 read, 15 could not open), and a run summary. Passed. |

Test chats were archived again afterwards.


### 2026-11-13, U5: know what is happening and what it costs

- **Status line** under the message box: "Chat 4% full" from the engine's token reports for that chat (amber over 80%, with a hint that /compact shortens it), and "76% of usage left" from the account's rate limits, read at launch and updated whenever the engine reports them. /status gives the details; the same figure (76–77% over the afternoon) came from both.
- **Downloads show progress.** While `fetch_terrain` runs, the tools write `private/state/progress.json` (dataset, parts done of total, start time, no coordinates) and remove it when the fetch ends. The project strip shows "Downloading ea-dtm-1m: 5 of 20 parts, under a minute left" with a Cancel beside it. It works for USGS point clouds, OpenTopography files and the national ground models.
- **Cancel stops the download, not only the agent.** Stopping a turn does not stop a tool call already running on the tool server: the first test kept downloading after the chat said "(stopped)". Cancel now also writes a stop file that the fetch checks before each part and during waits between retries, so it ends at the next part and adds nothing to the project.
- **The modern-feature check gives up sooner.** In two runs today it hung for minutes while every Overpass server was down (overpass-api.de answered 406 to every request; the others timed out). It now allows 20 seconds per server, tries each once and the first again, and says plainly that the map services are down and the run should carry on.
- **The map shows a terrain with tiles.** After a new terrain was fetched the map went blank, because it showed the newest terrain, which had no tiles. It now shows one with tiles unless the person picks another. The terrain menu says each one's size and whether it is cut, and an uncut one offers "Cut into tiles".

Checked in the app on Maiden Castle:

| Check | Seen |
|---|---|
| 1 sq km England fetch | Finished in about a minute, faster than expected; the strip showed "Downloading ea-dtm-1m: 0 of 6 parts" with Cancel, then went back to the tile count. The map stayed on the tiled terrain. |
| 4 sq km fetch, Cancel at 5 of 24 parts | The part in flight finished and the fetch ended about 1 min 45 s after the press (the Environment Agency answers slowly). progress.json and the stop file were gone, the terrains list was unchanged (still two), and the steps showed "(stopped)". Passed. |
| Usage | 76% in the status line and 76–77% from /status, both from the engine's rate limits. |

Left over: a fetch can still take up to two minutes to stop while one request is in flight to a slow service. The cancelled test chats in Maiden Castle are named "Environment Agency terrain fetch".


### 2026-11-13, U6: a shorter road to a first project

- **Type a place on Home.** Short text on Home that reads like a place (one to five words, no question) shows "Start a project at …" above the message box; Return still asks the agent. The New project page opens with the place looked up, the search area placed on the best match, the open lidar found, and the other matches listed to pick from.
- **Creating a project gets its terrain.** "Create and get the terrain" (the New project page and the guide's first project) creates the project and starts "Get the terrain" at once, so a new project is never left empty.
- **The strip names the next step.** In a project, the run strip ends with "Next: Screen the tiles" (or Check the flags, Second look, Prior-art sweep, What needs my decision?), the first one that is ready, and pressing it runs it. It hides while a run or download is going.
- **Empty Records** offers that next step as its button.

Checked from Home: typed "Fort Ancient Ohio" and clicked **Start a project at Fort Ancient Ohio** (1). The page had found Fort Ancient State Memorial, placed the area on the earthworks and listed OH_StatewideP3_6_B21. Clicked **Create and get the terrain** (2): the project opened and the terrain came in on its own, 17.4 ground returns per square metre, 9 tiles, on the map in under a minute. Clicked **Next: Screen the tiles** in the strip (3): all 9 tiles screened, 3 candidates flagged (the embankment wall along the ravine rims and two round mounds), and a run summary. Home to terrain on screen in two clicks, and to a screened project with one more. Passed.

Not done here: the map does not show where the area is before terrain arrives. The terrain now comes in within a minute of creating the project, so the blank map is brief.


### 2026-11-13, U7: pulling in data is visible and in your hands

A project now has a **Data** tab:

- **Terrain in this project:** each terrain with its survey, area, cell size, ground returns per square metre, the year flown when the survey's name gives it, how many tiles, and its size on disk. One not yet cut has "Cut into tiles".
- **Fetch more, Widen the area, Use another survey:** each asks the agent to do that one thing. "Use another survey" lists every survey over the area and asks before fetching.
- **Your own data:** drop or choose a GeoTIFF ground model or a LAS/LAZ point cloud. A new tool, `import_terrain`, reads it into the project like fetched terrain: a point cloud's ground returns are gridded at 0.5 m and its points are kept, so sections show canopy; a GeoTIFF is used at its own cell size. Files without a projected coordinate system in metres are refused with a plain reason. The agent is then asked to cut it into tiles.
- **Take it with you:** "Export finds" writes the candidates as GeoJSON under `private/exports/` and shows it in Finder. "Export project…" zips the records, notes, sources and reports, leaving out `data/` and `private/`. "Draft a report" runs the report workflow once a candidate has been decided as no match in the sources read.
- **The map puts terrains side by side.** With no terrain picked, every tiled terrain in the same coordinate system and within 5 km is drawn together, each tile at its real position. Fetching more of an area or widening it adds tiles beside the old ones, and candidates sit on the right tile. The menu still shows one terrain at a time.

Checked:

| Check | Seen |
|---|---|
| Mound City map, "All terrain" | The project's two terrains (0.32 and 0.15 sq km, fetched separately during N3) drawn as one mosaic, the enclosure and its mounds continuous across both, all five candidates on it. Before, only one terrain showed and C-005 sat on its own small map. |
| Choose a file: a GeoTIFF of real ground (Fort Ancient's) | Added as "dh-own-dtm.tif, 0.39 sq km, your own file", cut into 9 tiles, 0 unreadable, and drawn on the map. Removed again afterwards, since it was not Mound City ground. |
| `import_terrain` with a LAZ, from the tools directly | 0.36 sq km at 10.8 ground returns per square metre, 3 tiles, a sky-view tile and a section with ground returns. A missing file gave "No file at …". |
| Export finds | "Saved 5 candidates to …/private/exports/candidates.geojson", five points. |
| Export project… | `mound-city-group.zip`, 25 files, 2 MB: records with their pictures, notes, sources, PROJECT.md. No entries under data/ or private/, and no coordinates in any text file. |

Widen the area and Use another survey were not run end to end here; they hand the agent a plain request, and the map change they rely on (new tiles beside old ones) is what the Mound City mosaic shows.


### 2026-11-13, where this run stopped

U1 to U7 are done and merged (pull requests #3 to #8). U8 to U12 are not started. Nothing is half done.

Next, in order:

- **U8, a map you can work on.** The map now draws every nearby terrain at its real position, so a drawn section line can be turned into metres from there. Still to build: pan and zoom with the trackpad (zoom is two buttons now), the view switcher (composite, hillshade, local relief, sky view; the tools already render all four), toggles for tiles and candidates, and drawing a line to cut a section.
- **U9, deciding is quick.** U1 found the decision buttons at the bottom of a record, below every source. A review that goes one candidate at a time, with keys for the decisions and "ask a second look for all", is the plan.
- **U10, ⌘K palette.** Find a chat (⇧⌘F) and the @ list already gather projects, chats and candidates; the palette can reuse them.
- **U11, failures say what to do.** Partly done along the way: the modern-feature check now gives up within a minute with a plain message, a chat open in Codex says so, and a cancelled download says nothing was added. Still to do: a Retry or "choose another model" button on errors in the chat, and a message when the engine stops.
- **U12, one product, then docs.** README screenshots predate the Data tab, slash commands, @ mentions and the status line; retake them and bring README, concept and HANDOFF into line.

Seen during this run and not fixed: the Overpass servers were down all afternoon, so modern-feature checks fail; the National Register still withholds site locations; a cancelled download can take up to two minutes to stop while one slow request finishes.

Test leftovers: projects "Cahokia control run" (a second one, at `~/Documents/Dighouse/cahokia-control-run`, not in the sidebar), "Serpent Mound goal run" and "Fort Ancient Ohio" in `~/Documents/Dighouse`; several archived test chats; five "Environment Agency terrain fetch" chats in Maiden Castle, three of them cancelled downloads.


### 2026-11-13, U8: a map you can work on

- **View switcher** on the map: Composite, Hillshade, Local relief and Sky view. The first time a view is chosen, a new tool, `render_tiles`, renders every tile that way (9 tiles in 0.3 s), and the choice is kept between tabs and launches.
- **Toggles** for the tile outlines (and the darkening of unscreened tiles) and for the candidates.
- **Zoom** with the buttons as before, and with a pinch on the trackpad; the map scrolls to pan once zoomed.
- **Click a tile** for its verdict and note; **click a pin** to see the candidate, **double-click** to open its record.
- **Draw a section.** The line button turns on drawing; drag across the ground and the tools cut a section along the line through the raw points. It is filed on the selected candidate, or on one within 25 m of the line's middle, and the card shows the picture, length, height and whether it is in the ground returns.

Checked on Mound City Group:

| Check | Seen |
|---|---|
| Sky view | Every tile of both terrains redrawn; the enclosure bank, the mounds inside and the hollows outside stand out more than in Composite. |
| Hillshade, then Records and back to Map | Still Hillshade. |
| Hide tile outlines, hide candidates | The picture alone, then back. |
| Click a tile | "Tile r000c000, Possible" with the screening note and "Ask the agent to look here". |
| Select C-002, draw a line across it | "76 m long, rises 1.49 m above the line between its ends, in the ground returns. Filed on C-002's record." The record's section check now reads 1.49 m and its picture was replaced. Passed. |
| Double-click the C-003 pin | Records opened on C-003. |
| Zoom in twice | Map enlarged with a scrollbar to pan. |

Not verified: pinch zoom and two-finger panning with a real trackpad, since the test tooling sends neither.


### 2026-11-13, F1, F2, F4, F5, F6 (How it runs), F7, F8, F9, F11

- **F1, the review comes prepared.** A new tool, `suggest_decision`, lets the agent write the decision the evidence points to and its reason onto a record ("Suggested decision" in the Markdown), changing nothing else. "What needs my decision?" became **Prepare my review**: the agent reads each record and sources and suggests a decision for each, naming where a find is published. "Run the whole search" now ends with suggestions too. The review opens each candidate with the suggestion shown and filled in, so a right one needs only Return. "Second looks" is a short button with the count in its tooltip. Checked on the Mound City test copy: Prepare my review suggested already published for C-001 and C-003 (Benson 2012, Everhart and Ruby 2020, Seeman et al. 2026), modern for C-002 and C-005, natural for C-004; five Returns recorded all five in 11 seconds, each with Chris's name and the reason.
- **F2, buttons.** One button shape everywhere: rounded rectangles with a soft fill, a slight shadow and a press effect, with an icon where it helps. Long labels shortened ("Get the terrain", "See how it works", "Create project", "Ask the agent", "Try it yourself").
- **F4, Home.** The opening paragraph is 17 pt, up from 14.5; the heading is larger; the marks on Home and on a new chat animate (consecutive frames differ).
- **F5.** "Open surveys / Known sites" is now a two-sided switch with the chosen side raised.
- **F6 in part, How it runs.** Rewritten as three numbered parts: the model (the thinker, which can be Claude, GPT, Gemini or Grok), the engine (the hands: Codex, which runs any model), the tools. A "Which models you can use" panel lists the makers on offer from the model list (OpenAI 20, Alibaba 9, xAI 8, Moonshot 8, Zhipu 7, Anthropic 6, Google 4, …), explains the short codes in model names, and says Claude Code cannot replace Codex as the engine yet.
- **F7.** Settings has a **Tools** page listing every tool by stage, with "Guided tour" to the Toolbox and "Manage tool servers".
- **F8.** The Toolbox's Open data page groups services by where they work (Anywhere, United States, England/Netherlands/France, ancient Mediterranean) as compact rows that open for details; status and "Check status" are at the top ("11 of 11 online"). "Try it" became **Ask the agent…**, which first says it starts a chat and uses the model.
- **F9.** Opening a project without a chat shows its overview: the question, the next step with why in plain words and one button, the six stages with counts, and the last run's summary.
- **F11.** Section pictures have labels drawn in a real font at a readable size, and a colour key for ground and other returns.

Left for the next turn: F3 (each slash command run once), F6 for Personalize, Models, Data and privacy and About, and F10 (a project as a repository with a method).


### 2026-11-13, F3, F6 (Personalize, Models), F10, and two fixes

- **F3, slash commands.** Each command was run in the app. Worked: /help, /status, /effort, /model (the list opened), /rename (the engine had the new name), /fork, /undo, /archive, /compact, /goal, /new and /new-project. A new command, **/review**, opens the review. /decide now reads "Have the agent suggest a decision for each find". Of the workflow commands, /screen and /decide were run and worked. /research, /run, /terrain, /check, /second-look, /sources and /report share their code path. Each shows in the list as ready or greyed with the reason, but none was run on its own.
- **F6 in part.** Personalize has a **Text size** switch (Standard, Large, Larger) that scales every font in the app. Models has a plain introduction, warnings for a model that cannot read images, a missing second model or two models from the same maker, and **Test both**. General, Data and privacy and About are not reviewed yet.
- **F10, a project is a repository.** A new project gets METHODOLOGY.md (the method the agent follows and adds Lessons to), notes/INDEX.md and a git history with a first commit; data/ and private/ stay out of git. Each run summary adds a line to the index and a commit, and so does each decision a person records. The skill tells the agent to read the method first. Checked on a scratch project: the files were there, there were two commits after a summary, and data/ and private/ were not tracked. The **Notes** tab now has three parts, Runs, Method and Log, with "Ask the agent to write it" when a project made before this has no method file. Seen on the Mound City test copy.
- **Sidebar.** Clicking a project's name opens its overview; only the arrow folds its chats away. Before, the click hid the chats.
- **Next step.** Once every find is decided, the strip and the overview no longer name a next step, and the decide stage reads "N to prepare", "Prepared" or "All decided".


### 2026-11-13, where this run stopped (paused by Chris)

Chris paused the loop here. Everything above is merged. Left to do, in order:

- **F2:** screenshots of Review, Records, Data, Toolbox and Settings to confirm the same buttons and short labels everywhere.
- **F5:** a full click-through of Home, Toolbox and Settings, confirming every control gives a visible result.
- **F6:** General, Data and privacy and About.
- **U10:** the ⌘K palette.
- **U11:** Retry and Choose another model on errors, and a plain message with Restart when the engine stops.
- **U12:** the consistency pass at every size and look, new README screenshots, and docs brought into line.

Known problems: the Overpass map servers were down during this run, so the modern-feature check failed (it now gives up within about a minute). A cancelled download can take up to two minutes to stop. Pinch zoom and two-finger panning were never tried with a real trackpad.

Test leftovers in ~/Documents/Dighouse: mound-city-review-test (a copy of Mound City whose five decisions were recorded in Chris's name for testing only), serpent-mound-goal-run, fort-ancient-ohio and a second cahokia-control-run that is not in the sidebar; archived test chats; five "Environment Agency terrain fetch" chats in Maiden Castle. A backup of Chris's settings is at ~/.codex/worktrees/dighouse-u1/defaults-backup.plist, and a scratch project at /tmp/dh-repo-test.


### 2026-11-14, F2, F5, F6 (the rest)

The loop resumed at Chris's request.

- **F2, buttons.** Screenshots of Review, Records, Data, the Toolbox (all four tabs) and every Settings page show the same button style, and no label is over four words ("Review and decide", "Use another survey", "Run this stage" are the longest). About's GitHub link was the one odd control, a bare green word; it is now a button like the rest.
- **F5, nothing looks clickable that is not.** On Home, the Open surveys / Known sites switch, the six "Why not just ask ChatGPT?" tabs, See how it works (opens the Toolbox) and a known-site card (opens New project filled in for Cahokia) each gave a visible result. In the Toolbox, these were fixed:
  - **Open data:** an opened service row repeated its first sentence. The row now shows the full sentence once. The stage tags under it looked like buttons, so they became a plain "Used for" line.
  - **Pictures of search results:** the green "Open copy" and "Open record" labels looked like links but were part of a picture. They now read "Free to read" or "No free copy", with a tick or a dash under the author line.
  - **More tools:** the cards for the Codex tools had button-like outlines but did nothing when clicked, so the outlines were removed. "Also connected" became a line of text in place of pills.
  - **How a search works:** a stage that is already done on the open project said only "Done". It now names the project ("Mound City review test: done").
- **F6, General, Data and privacy, About.**
  - **Folder paths:** shown with ~ for the home folder.
  - **Data and privacy:** says each project keeps a git history that leaves out the private folder and the downloaded data. "QLever" became "a copy of Wikidata for faster searches".
  - **About:** opens with the same plain description as Home. "Agent harness" is gone. The repeated Welcome guide row became **Versions** (Dighouse 0.2.0, engine codex-cli 0.146.0), to quote when reporting a problem. Personalize, Models, How it runs and Tools were rechecked and needed nothing.

### 2026-11-14, U10: find anything fast

- **⌘K** (View › Jump To…) opens a palette covering four kinds of item. Typing narrows the list, the arrow keys move, Return opens and Escape closes. A command that cannot run shows its reason in amber and does not run.
  - **Every project and every candidate in every project:** candidates are read from each project's records.
  - **Every chat** Dighouse has listed.
  - **The pages:** Home, New chat, New project, Toolbox, Find a chat, each Settings page, and each tab of the open project.
  - **Every slash command.**
- **Shortcuts:** /help and Help › Commands and Shortcuts now end with every keyboard shortcut.
- **A fix:** a project whose question section was empty showed its next heading ("## Rules for agents") as the question on its overview. It now shows nothing there.

| Check | Seen |
|---|---|
| From Settings, ⌘K, "angel c-001", Return | Angel Mounds east plaza opened on Records with C-001 selected. Passed. |
| ⌘K, "mound", ↓ ↓ | The highlight moved down two rows. |
| ⌘K, "report" | /report, greyed, "Needs a decided candidate". |
| ⌘K, "southern ohio", Return | The general chat Southern Ohio Site Gaps opened. |
| Help › Commands and Shortcuts | The commands, then 14 shortcuts, in the chat. |

### 2026-11-14, U11: failures say what to do

- **A failed reply.** When a chat ends on a failure, a bar above the message box gives a heading in plain words and what to do, with **Try again** and **Choose another model**. Headings cover a missing model, the usage limit, a dropped connection, a chat too long for the model and a refused key. Try again resends the last message, first taking back the failed attempt.
- **The engine stopping.** Every page already gives way to a status page when the engine is down. That page used to read "Dighouse needs a few things" with only Check again. It now reads **The Codex engine stopped**, says the projects and chats are safe, and offers **Restart the engine**. After a restart, the chat that was open comes back.
- **A service that fails.** A tool that cannot reach a service now names it and says what to do. Example: "Could not reach nonexistent.invalid. Check that this Mac is online; if it is, the service may be down, so try again later." The same goes for timeouts, rate limits (429), refusals (401, 403) and server errors (5xx). A refused page already had "Open the page yourself" in the Sources tab.

| Check | Seen |
|---|---|
| Stopped Dighouse's engine process (its own child, not the Codex app's) | Every page showed "The Codex engine stopped" with Restart the engine; the top bar and sidebar flagged it too. |
| Restart the engine | The engine came back in about ten seconds and the open chat, Southern Ohio Site Gaps, was on screen again. |
| Set the model to "test/no-such-model" and sent "Reply with the single word ok." | The failure line, then the bar: "This model could not run the request", Try again, Choose another model. |
| Choose another model, Opus 5.5, Try again | The model list opened; after picking Opus 5.5, Try again answered "ok" and the bar went away. The test chat was archived and the saved model is Opus 5.5 again. |
| The service messages, from Python | An unreachable host and a 503 each gave the sentences above. |

Not verified: turning the network off in the middle of a fetch. That would cut this Mac off for everything else running on it. The fetch's error passes through the same service messages, which were checked on their own.

### 2026-11-14, U12 part 1: every size and look

Checked Home, a project, the Toolbox, Settings and the review at full screen (1728 × 1084), half width (864) and narrow (600). Earth, Canopy and Graphite were also checked at 1440 × 900. Fixed:

- **Find a chat, ⌘K and the rename box did not open when the sidebar was hidden** (any window under 860 wide), because they hung off the sidebar. They now hang off the window.
- **The review, Find a chat and ⌘K panels** were wider than a narrow window and hung off its edge. They now fit inside it, and the review stacks its checks under the pictures.
- **Settings at half width**: the section tabs ran off the side ("Data ar…"). They now wrap onto a second line.
- **The map's toolbar and colour key overlapped** when the map pane was narrow. The key now drops under the toolbar.

Left for part 2: new README screenshots and bringing the docs into line, after the project method (P1) that Chris put first.


### 2026-11-14, the model is easy to change

Chris found the model hard to change: the button in the message box opened the effort panel, and the model list hid behind a small link. The button now opens one panel with the model list and a search box, with the thinking slider at its top. The last five models picked show first under "Recent". Checked in the app: typed "terra" and picked primary / 6.1 Terra, which is now the default, and the button reads "primary / 6.1 Terra, Medium". Tests now use that model (rule added to HANDOFF.md).


### 2026-11-14, P1: every project documents itself by one method

Chris asked for this to come first. It builds on F10, which gave projects a method file, a notes index and a git history.

- **RESEARCH.md, the research record.** A new module, `record.py`, rebuilds it from the project's own files whenever a run ends, a person decides, or the project is opened. It covers, without coordinates:
  - the question and where things stand;
  - **Still to do**, worked out from the files (tiles not screened, checks missing, sources that could not be opened, decisions waiting, a missing question);
  - the data used;
  - every tile with its verdict, who looked and what was seen, nothing and natural included;
  - every candidate with its section, second look, modern-features check, sources and decision;
  - every source, grouped as read, could not be opened (the next ones to try) and not relevant;
  - every literature search run, read from the dated notes so older projects get theirs too;
  - the run history, and a guide to the project's files.
- **The method explains the record.** METHODOLOGY.md has a "How this project keeps its record" section: every look leaves a trace, a blank result is a result, one record per feature, decisions carry a name, date and reason, and Export project hands everything but private/ and data/ to someone else to carry on.
- **The agent reads the record first.** It builds on the record and does not redo work it lists without saying why. A new "Keeping the record" section in the skill covers this, and a new tool, `document_project`, rebuilds the record on request and returns what is still to do. That makes 32 tools. `init_project` now says to read RESEARCH.md first.
- **Older projects catch up when opened.** The app calls document_project, with no model involved. The project gets a .gitignore, the method (or the record section added to its existing method), a notes index built from its run summaries, a git history and the record.
- **In the app:** the Notes tab opens on **Record**, and the project overview has a **Research record** button.
- **Coordinates:** they are stripped from anything copied into the record. DOIs such as 10.2307/503404 are left intact.

| Check | Seen |
|---|---|
| A scratch project: create, then a run summary | The method had the record section. RESEARCH.md was written. Two commits: "Start the project", then the run summary. |
| A copy of Angel Mounds (made before F10) | RESEARCH.md matches the project: 9 tiles with verdicts, 5 candidates with their checks, 1 source read, 17 not opened, 2 not relevant, 16 literature searches. Still to do lists the missing question, the 17 sources and the 5 decisions. |
| Opened Angel Mounds in the app | The record was rebuilt at 11:18. The project now has METHODOLOGY.md and one commit, with nothing from data/ or private/ tracked. Notes › Record shows it, and the overview button opens it. |
