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

