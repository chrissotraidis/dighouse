# Dighouse goal loop 8: from a chat to a project with its own repository

Last updated: 2026-11-17

Read [HANDOFF.md](HANDOFF.md) and the end of [WORLD_LOOP.md](WORLD_LOOP.md) first.

## The problem

Today a chat and a project are separate things:

- A chat about "what should I research?" keeps everything in the chat. Nothing it learns becomes a folder.
- A project is made from a form (name, question, a box on the map) into the projects folder. You cannot choose where it lives, and it cannot start from a chat.
- A project is already a git repository with a documentation hierarchy (PROJECT.md, METHODOLOGY.md, RESEARCH.md, candidates/, notes/, sources/, reports/; private/ and data/ ignored). But nobody sees that it is one, and it cannot be pushed anywhere.

Chris wants this path:

1. Open a new chat and work out what to research.
2. When the chat has a place and a question, turn it into a project.
3. The project lives in a folder he chooses, such as a new repository under ~/GitHub, under version control.
4. The project's documentation carries what the chat worked out, so a later agent or person can pick it up.

## Decisions (Chris, 2026-11-17)

- A chat can become a project. The project keeps the chat, and its first records come from what the chat settled.
- New project lets you choose the folder: the projects folder (default ~/Dighouse) or any folder, such as a new repo under ~/GitHub.
- Every project is a git repository. Pushing to GitHub is a separate, explicit step that a person presses; nothing is published by default.
- Locations stay in private/, which git ignores, so a pushed repo carries no coordinates.

## Goals

| Goal | What | Check |
|---|---|---|
| P1 | **Make it a project.** In a general chat, once the agent has a place (a box or a named place) and a question, a card offers "Make this a project". It opens New project filled in from the chat (name, question, area). After creating, the chat moves into the project and stays its first chat. The agent can also suggest it, through a tool that returns the proposal; the person presses. | A general chat about a place ends in a project with that chat inside it, in the running app. |
| P2 | **The chat becomes the first records.** On creation, write what the chat settled: the question and why it was chosen into PROJECT.md, sources it read into sources/, places ruled out and why into notes/, and the proposal into METHODOLOGY.md ("Why this area"). Use the tools' existing writers, no new formats. Commit it as "Started from chat: <title>". | The new project's RESEARCH.md and git log show the chat's reasoning and sources. |
| P3 | **Choose where it lives.** New project gets a "Folder" row: the projects folder (default) or "Choose…" for any folder, with "Make a new folder in ~/GitHub" as the second option. Refuse iCloud folders, with the reason. The sidebar shows the folder on hover. | A project created in ~/GitHub/<name> opens, runs /ground, and its folder is a git repo with the hierarchy. |
| P4 | **Version control you can see.** The project overview shows the history (the last five commits, in plain words) and "Show in Finder". A "Publish to GitHub" button runs `gh repo create --private --source <folder> --push` only when `gh` is signed in. It first checks that private/ and data/ are ignored and that no file outside them holds coordinates, and says so. Never public by default. | In the app, a test project publishes to a private repo, and the pushed tree has no private/ or data/. The test repo is deleted afterwards by Chris, not the agent. |
| P5 | **One documentation layout, explained.** METHODOLOGY.md and a short "How this project is kept" section in PROJECT.md say what each file and folder is for, who writes it (agent, tools or person), and what never leaves the Mac. Another agent opening the folder in Codex, without Dighouse, can follow it. | A plain Codex session given only the folder lists what was looked at, what was found and what is still open, correctly. |
| P6 | **Slash commands everywhere.** Every command either runs or says why not (done 2026-11-17 in PR #56). Add /make-project (P1) and /publish (P4), and show the active goal at the top of the chat with a Stop button. | Each command typed and Return in the running app does something visible. |
| P7 | **Docs.** README "A project is a folder" gets the chat-to-project path and the GitHub step. HANDOFF and this file agree with the app. | README matches the app. |

## Rules

- Cheap models only for tests: primary / 6.1 Terra. Never Opus.
- Nothing is pushed to GitHub, made public or sent without Chris pressing the button, and the agent never creates a public repository.
- Locations stay in private/. Check every pushed tree.
- Leave Chris's settings and projects as found. Back up the settings plist and use `-projectsHome $HOME/dighouse-ui-test`.
- One branch and PR per goal, `codex/` prefix, squash-merged. `rm` is blocked; move files to /tmp.
- Plain words. Recheck every control you rewire.

## After this loop: the search loop

Once a project can live in its own repository, run the first real search for something unrecorded. Bavaria is the place to start: open raw lidar, an open register of known sites, and enclosures the method finds. The prompt for a Dighouse chat, after making a project for a 10 to 25 sq km wooded area:

> /goal Search this project's area for built features that are not on record. First calibrate on the Oberhaching blind test and stop if it finds fewer than half. Then fetch the ground, look at the whole area in sky view and hillshade, look at every tile, and mark each enclosure, rampart and mound group once. For every find, cut a slice, check open maps, check the Bavarian monument register, and search the literature. Mark a find "not on record" only when all of those are on its record. Keep the research record up to date after each stage, never call anything new, and finish with a report for the Bavarian State Office for Monument Protection that I can review. Do not send it.

Before that, Bavaria's register needs adding as a records source (it answers per point through the Denkmal-Atlas WMS, already used for the Oberhaching key).

## Which model

Every model on Chris's engine accepts images, and Dighouse hands the agent each tile as an image through view_tile, so no computer use is involved. What matters is how well a model reads relief and how much each run costs:

- **primary / 6.1 Terra:** every benchmark so far (53 of 105 on land, 4 of 7 wrecks) used it at medium. The default for searches.
- **6.1 Sol** ("workhorse") and **6 Astra** ("most capable"): likely better at telling a rampart from a field edge, at a higher cost per run. Worth it for the looking stage only if a test shows it finds more.
- **6 Luna and 5.6 Luna** ("fast and affordable"): worth trying for the bookkeeping stages (slices, map checks, the record), not for looking.

Settle it with a bake-off before the real search: the same four blind tests (Borre, Oberhaching, Lauske, Thunder Bay east) on Luna, Terra and Sol at medium, comparing features found per percent of usage spent (the meter under the message box).
