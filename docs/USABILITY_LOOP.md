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

