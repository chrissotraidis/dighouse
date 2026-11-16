# Dighouse goal loop 8: every project is its own folder and repository

Read docs/HANDOFF.md and the end of docs/WORLD_LOOP.md first.

## What should be true at the end

- Starting a project, from New project or from a chat, always creates the project's own folder. That folder is a git
  repository holding a fixed documentation layout.
- New projects go in ~/Dighouse. A project goes in ~/GitHub only when the person asks for it, either on New project or
  by saying so in the chat ("I want to work out of my GitHub folder").
- A chat that has worked out what to research can become a project with one press. The chat moves into the project,
  and what it settled becomes the project's first records.
- The project's history is visible in the app. "Publish to GitHub" makes a private repository, and only when the person
  presses it.
- Another agent opening the folder in plain Codex, without Dighouse, can tell what was looked at, found and left open.

## How a project is kept (the layout every project gets)

| Path | What it holds | Written by | Leaves the Mac |
|---|---|---|---|
| PROJECT.md | Name, question, why this area, how the project is kept | Tools, then the person | Yes |
| METHODOLOGY.md | Method, calibration, the data used and its limits | Tools | Yes |
| RESEARCH.md | The research record: tiles, finds, checks, sources, decisions | Tools, after every run | Yes |
| candidates/ | One page per find, with pictures and checks | Agent and tools | Yes |
| notes/ | Dated notes and run summaries, including what was ruled out | Agent and tools | Yes |
| sources/ | Sources read, with what each said | Agent | Yes |
| reports/ | Drafts for the heritage authority | Agent; the person sends | Yes |
| private/ | Locations and working state | Tools | Never (in .gitignore) |
| data/ | Ground models, tiles, points | Tools | Never (in .gitignore) |

## Goals

| Goal | What | Check (in the running app) |
|---|---|---|
| P1 | **Own folder, always, in ~/Dighouse.** Every way of starting a project (New project, Home starting points, blind tests, the agent's init_project, a chat) creates a new folder under ~/Dighouse with the layout above, runs git init and makes a first commit. If a name is taken, add a number; never reuse a folder. | Starting a project each of the five ways makes five folders in ~/Dighouse, each a git repo with the layout that starts with a commit. |
| P2 | **Make this a project.** In a general chat, once the agent has a place and a question, a card offers "Make this a project". So does /make-project at any time. It opens New project filled in from the chat (name, question, area). After creation, the chat moves into the project as its first chat. The agent may suggest it; only the person presses. | A chat about a place ends as a project containing that chat. |
| P3 | **The chat becomes the first records.** On creation, write what the chat settled into the layout: the question and why this area into PROJECT.md, sources it read into sources/, places ruled out and why into notes/. Commit it as "Started from chat: <title>". | The new project's files and git log show the chat's reasoning and sources. |
| P4 | **~/GitHub only when asked.** New project shows "Folder: ~/Dighouse" with one alternative, "Work out of my GitHub folder", which makes ~/GitHub/<project-name> instead. When the person says in the chat that they want to work out of GitHub, the agent fills that choice in on the card and names the folder it will use. It never picks ~/GitHub on its own. A name already taken in ~/GitHub gets a number; an existing repository is never written into. iCloud folders are refused, with the reason. | (a) A default project lands in ~/Dighouse. (b) Choosing the GitHub option lands in ~/GitHub/<name>. (c) Saying "work out of my GitHub folder" in a chat lands there too. Each folder opens, runs /ground, and is a repo with the layout. |
| P5 | **History you can see, publishing you control.** The project overview shows the last five commits in plain words, plus Show in Finder. "Publish to GitHub" (and /publish) first checks that private/ and data/ are ignored and that no tracked file holds coordinates, then runs gh repo create --private --push. It is never public and never automatic. | A test project publishes to a private repo whose tree has no private/ or data/. Chris deletes the test repo himself. |
| P6 | **Explained in the project itself.** A "How this project is kept" section in PROJECT.md (the table above, in plain words) and the skill tell any agent where to read and write. | A plain Codex session given only the folder correctly lists what was looked at, what was found and what is open. |
| P7 | **Goals are visible.** An active goal shows at the top of the chat with its objective and a Stop button. /goal alone uses the last message (done in PR #56). Every slash command either runs or says why not. | /goal, /make-project, /publish, /ground and /look each do something visible on Return. |
| P8 | **Docs.** The README section "A project is a folder" covers the chat-to-project path, ~/Dighouse as the home for projects, the GitHub option and the publish step. HANDOFF and this file agree with the app. | The README matches the app. |

## Rules

- Tests that send a message to a model use primary / 6.1 Terra. Never Opus.
- Nothing is pushed, made public or sent unless Chris presses the button. The agent never creates a public repository.
- Locations stay in private/. Check every pushed tree.
- Don't touch Chris's projects or existing repositories in ~/GitHub. Back up the settings plist, test with
  -projectsHome $HOME/dighouse-ui-test, and move any test folders made in ~/GitHub to /tmp afterwards.
- One branch and PR per goal, with the codex/ prefix, squash-merged. rm is blocked, so move files to /tmp.
- Plain words. Recheck every control you rewire and the ones next to it.

## The loop (every turn)

1. Read HANDOFF.md, this file and its Log.
2. Take the lowest unfinished goal, build it, and run its check in the running app.
3. Fix what the check shows, log the result with the date, run the tests, then commit, open the PR and merge.
4. Stop when P1 to P8 pass, or when a decision from Chris is needed. Before stopping, update the Log and HANDOFF.md.

## Next loop (drafted, not part of this one)

### The search loop

Once a project can live in its own repository, run the first real search for something unrecorded. Bavaria is the place to start: open raw lidar, an open register of known sites, and enclosures the method finds. The prompt for a Dighouse chat, after making a project for a 10 to 25 sq km wooded area:

> /goal Search this project's area for built features that are not on record. First calibrate on the Oberhaching blind test and stop if it finds fewer than half. Then fetch the ground, look at the whole area in sky view and hillshade, look at every tile, and mark each enclosure, rampart and mound group once. For every find, cut a slice, check open maps, check the Bavarian monument register, and search the literature. Mark a find "not on record" only when all of those are on its record. Keep the research record up to date after each stage, never call anything new, and finish with a report for the Bavarian State Office for Monument Protection that I can review. Do not send it.

Before that, Bavaria's register needs adding as a records source (it answers per point through the Denkmal-Atlas WMS, already used for the Oberhaching key).

### Which model

Every model on Chris's engine accepts images, and Dighouse hands the agent each tile as an image through view_tile, so no computer use is involved. What matters is how well a model reads relief and how much each run costs:

- **primary / 6.1 Terra:** every benchmark so far (53 of 105 on land, 4 of 7 wrecks) used it at medium. The default for searches.
- **6.1 Sol** ("workhorse") and **6 Astra** ("most capable"): likely better at telling a rampart from a field edge, at a higher cost per run. Worth it for the looking stage only if a test shows it finds more.
- **6 Luna and 5.6 Luna** ("fast and affordable"): worth trying for the bookkeeping stages (slices, map checks, the record), not for looking.

Settle it with a bake-off before the real search: the same four blind tests (Borre, Oberhaching, Lauske, Thunder Bay east) on Luna, Terra and Sol at medium, comparing features found per percent of usage spent (the meter under the message box).

## Log

**P1 passed (2026-11-16).** `projects_home()` (env `DIGHOUSE_PROJECTS_HOME`, else ~/Dighouse) and `new_folder()` in project.py: a bare name becomes a folder there, and a folder already in use gets -2, -3. `init_project` uses it and replies with the folder it made; the app swaps that path in (`ChatModel.withMadeFolder`) and passes its projects folder to the engine. The old fallback to ~/Documents/Dighouse is gone; a projects folder in iCloud is not used. Checked in the running app with a test projects folder: the Home starting point (Lauske) made `lauske-ring-fort`, the New project form with the same name made `lauske-ring-fort-2`, a blind test made its own folder, and the agent in a general chat, given the bare name `newark-check`, made `newark-check`, and Open project registered it. Each is a git repo with the layout, starting with a commit (later record updates add commits), with private/ and data/ ignored. The fifth way, from a chat, is P2. Offline test: `test_every_new_project_gets_its_own_folder_and_repository`.

**P2 passed (2026-11-16).** A new tool, `suggest_project`, lets the agent offer a project (name, question, why this area, box or place). It creates nothing; the chat shows a card with Make this a project. Pressing it opens New project filled in from the offer, and once the project is made the chat moves into it: the engine lists chats by the folder they started in, so the chat is forked whole into the project's folder, keeps its name, and the general copy is archived. `/make-project` opens the page from the chat's offer; with no offer it asks the agent for one in the chat; a chat that already made a project with init_project moves into that one; an empty chat just opens New project; inside a project it says the chat is already in one. Checked in the running app with Terra: a chat that settled on the Newark Great Circle got the card unprompted, the page opened with name, question and a 2.83 square km box, Create project made `newark-great-circle` with the chat in it and gone from Chats, the engine's record for the copy has the project folder as its cwd, and the moved chat named its project folder and question when asked. `/make-project` in the P1 test chat moved it into `newark-check` without making a second folder. Not looked at on screen: the reworded project card inside its own project (a text change). Offline test: `test_offering_a_project_makes_nothing`.

**P3 passed (2026-11-16).** `suggest_project` now carries what the chat read (title, link, what it says) and the places it ruled out with why. When the person makes the project, the app calls a new tool, `start_from_chat`, before moving the chat: it adds "Why this area" to PROJECT.md, appends the chat's sources to sources/read-log.md marked "before the project, in the chat", writes notes/<date>-started-from-chat.md (question, why this area, ruled out, read, and the chat in plain words), lists it in notes/INDEX.md, and commits "Started from chat: <title>". Anything that looks like a coordinate is replaced with "(location kept private)". A chat moved by /make-project into a project it already made gets the same note. RESEARCH.md now lists sources read in the chat, and its History links point into notes/ (they pointed at the project root before, for run summaries too). Checked in the running app with Terra: a chat comparing Fort Ancient and the Miamisburg Mound offered Fort Ancient, ruled out Miamisburg with a reason and read Dalbey 2007; making the project gave the git log "Start the project", then "Started from chat: Choosing an Ohio lidar site", with all four places written. Offline test: `test_a_chat_becomes_the_projects_first_records`.
