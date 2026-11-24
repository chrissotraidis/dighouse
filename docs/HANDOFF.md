# Dighouse handoff

Rewritten 2026-11-14, when the fifth loop (R1 to R7 in [REFINE_LOOP.md](REFINE_LOOP.md)) finished, and brought up to date on 2026-11-16 after loop 8, on 2026-11-21 after the second-opinion loop, and on 2026-11-22 after the mound loop and a review of every project. This file is the prompt for whoever continues the work. Read it and [AGENTS.md](../AGENTS.md), then [DECIDE_LOOP.md](DECIDE_LOOP.md) (where things stand, and the next plan) and the Log at the end of [MOUND_LOOP.md](MOUND_LOOP.md), which says what was checked and how, and what was not.

## Your brief

You are continuing Dighouse for Chris Sotraidis. It is a free, open-source macOS app for open archaeology: the Codex agent engine, any model the person has (through the OpenCodex router), and archaeology tools built in. A person should be able to open it, be helped to choose a place, run a search over open lidar, and end with records an archaeologist could trust.

Chris reviews by using the app and sending screenshots. He wants to use it to find things, and it must look and feel like its own product. Work in passes: build, check in the running app, fix, log, commit, push.

Eight loops are finished. The eighth was [PROJECT_LOOP.md](PROJECT_LOOP.md): every project is its own folder and repository (see "What loop 8 added" below). Its appendix drafts the next loop, a real search in Bavaria, and a model bake-off. The sixth was [TEST_LOOP.md](TEST_LOOP.md): blind tests on known sites with a scorecard, "What is this?", a feature guide, calibration and an honest README. The seventh was [WORLD_LOOP.md](WORLD_LOOP.md), whose Log has every source probe, run and score. It added Navarre (Spain), Bavaria, Saxony, New Zealand and Denmark (with a token), registers for Navarre and Denmark in the checks, and a pilot on the seafloor from NOAA's sonar surveys with charted wrecks as the key. It changed the method to look at the whole area before the tiles (enclosures bigger than a tile were being called field edges). The benchmark is 67 of 105 on thirteen land sites (five rerun on 2026-11-22) and 4 of 7 charted wrecks. Small low mounds remain the clearest gap (Borre 29 of 53, Andía 4 of 11). Rerun scripts/smoke_test.py and the blind tests after any change to the model, prompt, skill or feature guide.

Denmark is an option for anyone with a free Dataforsyningen token (Chris chose not to make one). Waiting for Chris: the macOS Documents prompt.

## Rules

- Keep it simple and consistent. Recheck every control after rewiring it. Do not suggest Figma.
- **Only people are credited.** No AI as author or co-author of a commit or pull request, and no "Generated with" lines ([AGENTS.md](../AGENTS.md)). CI checks it.
- Design rules are in [DESIGN.md](DESIGN.md); security in [SECURITY.md](../SECURITY.md).
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

- **App** (`app/Sources/Dighouse`, SwiftUI, macOS 14): one page at a time (Home, chat, New project, Toolbox, Settings). New chat starts a chat in no project; an empty chat's Project menu, beside Workflows, says where it goes and moves it. A project puts a workspace beside the chat with Map, Records, Notes, Sources and Data tabs. Three looks; Earth is the default. The mark at the top of the sidebar opens Home.
- **Tools** (`src/dighouse`, Python, MCP): 62 tools. `triage.py` looks at every tile in bulk (`look_at_tiles`). `discover.py` chooses where to look, `sources.py`, `national.py` and `terrain.py` fetch and build the ground, `tiles.py` and `section.py` cut tiles and slices, `checks.py` reads maps and literature, `ledger.py` keeps records, `record.py` builds the research record and `report.py` the search report. The agent's instructions are `skills/dighouse/SKILL.md`.
- **Open lidar:** the United States (USGS 3DEP), surveys on OpenTopography, and ready-made ground models for England, the Netherlands, France, Flanders, Norway, Estonia, Switzerland, Navarre and the Basque Country (Spain), Bavaria, Saxony, New Zealand, Czechia (2 m, ČÚZK's image service), Canada (HRDEM 1 m, a WCS 1.1 service, kind `wcs11`) and Denmark (Denmark needs a free token pasted in Settings, Data and privacy). Each is one entry in `NATIONAL` in national.py; Bavaria, Saxony and New Zealand use the `tiles` kind (files on a grid of map sheets).
- **Seafloor:** NOAA's sonar surveys of US waters and the Great Lakes (`us:noaa-bag`), offered only where a 2 m or finer survey covers the box, and INFOMAR's seabed model of Irish waters (`ie:infomar`, about 4 m: large wrecks only). The modern check reads NOAA's charts in US waters; elsewhere it records the charts as not checked.
- **Project state** is saved atomically and changed under a file lock (`Project.change`), because the agent records verdicts from parallel helpers.
- **Engine**: `codex app-server` as a child process, spoken to in JSON lines by `Engine.swift`. Dighouse starts the **newest** copy of Codex on the Mac (`Setup.detect`); on Chris's Mac that is 0.167 inside the ChatGPT app, because 0.146 on the PATH is refused GPT-6.1 Terra. Dighouse's own tools are approved at launch (`default_tools_approval_mode`), since newer engines ask before every tool call.
- **Tests**: 49 offline, 10 live (`uv run pytest`, `uv run pytest -m live`), and 4 for the app (`cd app && swift test`). The live test of the national ground models takes two minutes. CI (`.github/workflows/checks.yml`) runs the offline tests and the people-only check on every pull request, once GitHub Actions billing on Chris's account lets jobs start (it did not on 2026-11-22).
- **README** is written for people who download the app (2026-11-24): download steps without GitHub, questions people ask, Discord for help (the Kahris server, Dighouse role), and the developer material lower down. Home, the Angel Mounds project, a record and Decide were retaken that day in the real app at 1366 × 974 in Earth, cropped to known sites, the Computer Use indicator painted over. New project was not retaken: its map now shows the ground you have searched. Loop 5's own pictures are in `docs/loop5`.

## Where it stands (2026-11-22)

The search works; deciding does not. Across the 66 projects in Chris's list there are 744 finds outside blind tests, and a person has decided 18, all in early test projects. Eight are leads, 72 are "look again" (71 of them measured rises), and none has been marked "no match in the sources read" or reported, so nothing has gone past a lead. Every ground search since 2026-11-20 was in Ohio, Illinois or Alabama, where the site files are closed. Measured rises are 62% of all finds. The Review screen shows one find at a time, its counts disagree with the header, and it shows a disagreeing second opinion with a green tick. [DECIDE_LOOP.md](DECIDE_LOOP.md) has the full count, what a person sees, and the plan (D0 to D8), with six decisions for Chris before it starts.

## The find loop (FIND_LOOP, started 2026-11-23)

The aim and every check are in [FIND_LOOP.md](FIND_LOOP.md): a person downloads Dighouse, an agent searches large areas on its own, and the person ends with a short list of possible unrecorded sites checked against open records. A timed session on a ready-made model now sweeps three areas at once (`sweep`: fetch side by side and the bulk look in one call; 34 km² an hour in Norway). After G7, a timed session looks closely at no more than 24 shortlisted tiles an area (14.2 km² in an hour in Norway), and a calibration is judged over the last ten tests of its site on the same lidar (`blind-scores.json` in the cache, the last ten tests). G7 ran three unattended hours of Find something (Arizona on raw points, 4.4 km²; Norway and England on ready-made models, 9.6 and 9.4 km²): sessions now search 5 km² areas on ready-made ground, records name only the registers that reach a find, and the open-map check shares downloads across an area. Twice G0's area an hour; the agent's close look on the shortlist is now the limit. G6 adds [GETTING_STARTED.md](GETTING_STARTED.md) for people who download the app, makes SETUP.md the build-from-source page, and keeps downloaded points once (a project's points are a hard link to the cache's; the cache keeps 10 GB of points no project holds; `scripts/tidy.py` for what is already on disk). G5 puts **Find something** first on Home (the agent chooses the region, preferring Norway, where finds can be checked without an account), lists what waits on a person across projects under **Waiting for you**, draws the register outlines on the New project map, and adds `who_to_tell` and the **Ask the records office** letter (written under `private/requests/` only). G4 adds the Developer ID release build (`app/scripts/release.sh`; notarizing waits on a notary profile Chris saves once), the engine install and ChatGPT sign-in inside the app, and same-maker second opinions with the ringed tile (`opinion_pictures`) where OpenCodex is missing. G3 shows the second model the find ringed on its tile (89 of 102 rated right, from 62), keeps untaken bulk finds on the map, says one height, and suggests decisions only for finds a person sees. G2 reads Norway's and England's registers beside Denmark's, files a dated records check on every find, gives each project a shade (can find and check, can find, no open lidar) and adds eleven register answer keys (\`scripts/register_keys.py\`). G1 added the bulk look (\`triage.py\`, \`look_at_tiles\`): every tile goes to a low-cost model first, the agent looks closely at the shortlist and takes over the bulk finds it agrees with; the automatic pass runs at 53 km² an hour, and the five blind tests are no worse (Andía one better). USGS's ready-made 1 m model is \`us:3dep-dem-1m\`. G0 measured where finds stop (\`scripts/funnel.py\`: 744 finds, 18 decided, none answered), probed every ground source (\`scripts/coverage.py\`) and the open registers of Denmark, Norway and England, and timed the stages (\`scripts/speed.py\`: 76 km² an hour without the agent).

## The seeing loop (SEE_LOOP, started 2026-11-24)

The plan is [SEE_LOOP.md](SEE_LOOP.md), from the WYKOPKI video: help a person see a find clearly before deciding. V1 and V2 put the case on the Decide card. `check_finds` also cuts a north-to-south slice (`C-xxx-section-ns.png`, D switches) and files a `context` check with the finds within 200 m and the ground points per m². Slices show a 1.70 m figure. The card shows one line of numbers, the checks as **For** and **Against**, and a rank: A when the shape, the agent's eye and the second opinion all say built, B for two, C for one or none. Needs you is sorted by rank inside each group; the rank never changes what needs a person.

V3 adds three close views from the Relief Visualization Toolbox on the keys 7 to 9: VAT (RVT's flat-ground blend of hillshade, slope, openness and sky view), multi-scale relief (rises 2 to 20 m across) and local dominance (a person 1.70 m tall looking 5 to 10 m around). `src/dighouse/rvt.py` holds the copied functions and their credit; rvt-py itself is not a dependency, since its install metadata stops before Python 3.12. Each view's caption says in one line what it shows. They are for the person only, so the blind tests are unchanged by them. All three draw in about 0.1 s together.

A review of every page in the test copy (SEE_LOOP Log) left the app more consistent: repeated project names are numbered in the list, failed steps fold into a chat run and are counted on its line, Sources puts what was read first and folds the off-topic ones, Data names each download by its area, and the research record lists what waits for a person first.

## What the home loop added (H0 to H5, 2026-11-23)

The goals, the probe and every check are in [HOME_LOOP.md](HOME_LOOP.md). A project is now the home for its work.

- **H1, areas.** `fetch_terrain(area=…)` names an area and keeps its box in degrees (`lonlat`). `Project.grow_area` widens the project's box after each fetch. `name_project` names a project after its region. The map shows one area at a time from a menu of names, and Pick a place shades each area.
- **H2, the project page** lists its chats with what each is doing. `ChatThread.label` keeps coordinates out of chat titles.
- **H3, the sidebar** puts projects first, each unfolding to its chats (a closed project's chats are listed from the engine when unfolded), then loose chats, then a folded Blind tests group. The fold arrow is its own button.
- **H4, Search on its own** makes the session's project, starts its chat inside it, and is told to name the project after its region and add every area to it.
  - **Tool guards:** `add_measured_rises` skips ground that already has its rises. `start_calibration` waits for a region. `lasting_folder` keeps projects out of `/tmp` and Application Support.
  - **The app** follows a project's name from `project.json`.
  - **Older sessions** and their small projects are left as they were.
- **Defaults the app now uses:** `timedProject` (the running session's project) and `sidebarTestsOpen`.
- **Polish pass (2026-11-23).** One count everywhere for what waits on a person (`needsYou` and `toAgree` in `ProjectStore`), now also in the search report and the Toolbox. The Sources tab reads the project's own sources from `sources/read-log.md` (`ProjectStore.projectSources`, `allSources`). The Data tab wraps in a narrow pane. The Toolbox lists all 58 tools. Three things found and left for a decision are at the end of the polish entry in [HOME_LOOP.md](HOME_LOOP.md): second opinions that describe another feature on the tile, a measured rise's three heights, and tile seams on the map.

## What the decide loop added (D0 to D4, 2026-11-22)

The goals and every check are in [DECIDE_LOOP.md](DECIDE_LOOP.md).

- **D1, Decide** (`Decide.swift`) replaces the Review sheet, the group sheet and the record's decision sheet.
  - **Its steps:** Needs you (one at a time), Agree in bulk (a grid of 60 m close views, untick the wrong ones), and Done (with Undo).
  - **The verdict line** replaces the ticks.
  - **The tools** gain `decide_many` (one commit for a batch) and `undo_decision` (decisions now keep the status they replaced, `was`).
  - **Keys:** Return agrees; N, M, P and R pick another decision; S skips; ⌘Z undoes; ⌘R opens Decide.
- **D2, a find at a glance:** six close views on keys 1 to 6 (`find_views`, drawn under `data/views`), the whole tile, and the slice, fitting at 1440 × 900. VoiceOver reads the verdict as one sentence.
- **D3, measured rises on the map.**
  - **The rule:** `ledger.layer`, mirrored in `ProjectStore.layer`. A rise goes to a person only when the second model calls it built and it ranks in the top half of the project's rises, or when a person raises it (`raise_rise`).
  - **Blind tests** still count every rise.
  - **The effect:** on M6's projects, 36 of 232 finds go to a person.
- **D4, counts that agree:** one count everywhere (`needsYou`, `toAgree`), reports that rebuild with the record (`report.refresh`), tabs that turn into icons, and map labels that show on hover when there are many.
- **Decisions taken** (Chris, all six recommendations):
  - measured rises off the list;
  - searches go where a register is open (D5);
  - Sweden and Finland once he makes the accounts;
  - site-file requests are drafts he sends;
  - one pull request per goal;
  - Borre closes at 29 of 53, with the raw points left on the roadmap.

## What the mound loop added (2026-11-22)

The goals and every check are in [MOUND_LOOP.md](MOUND_LOOP.md).

- **M0, measured.** `scripts/mound_measures.py` compares fifteen measures on every measured rise against the answer keys. On rough ground the old rise ranking was worse than chance.
- **M1 and M2, second opinions in seconds.** `review.py` and `ask_second_opinions` (app only): each find's whole tile (composite and local relief, with its position in words; it rated better on known ground than a centred crop) goes straight to the second-opinion models through the router, four at a time, with the same fallback; the agent chat is kept when the router is off. During a timed session each area's opinions are asked as soon as its summary is written (`onAreaSummarized`). About a second a find, against 46. `-secondOpinions YES` with `-openProject` times it.
- **M3, rises that travel.** `mounds.contrast` and `mounds.travel_rank`: rise against roughness, two relief windows, a pit beside it counts against. Rises come from every tile looked at, 40 per km². `scripts/score_rises.py` scores a ranking on the saved blind runs.
- **M4, a mound-only pass: tried, not kept.** One mound in 115 quarter tiles, 72 false finds on rough ground. The code is on `codex/m4-mound-pass-tried`.
- **M5, resolution.** `scripts/resolution_test.py`: finer data shows no more mounds at Borre and fewer on stony ground in the Ardèche. The rest of Borre's misses are not in the 1 m model at all.
- **M6, two hours where mounds are small.** 6.84 km², 232 finds, every opinion in before the session ended. A project the agent places in Application Support now goes to `~/Dighouse`; the note "The run was stopped during" replaces "A person stopped", since the timer stops runs too.

## What the reach loop added (2026-11-21)

The goals and every check are in [REACH_LOOP.md](REACH_LOOP.md).

- **F0, measuring.** `open Dighouse.app --args -measure YES -measureTour YES` logs every main-thread stall over 250 ms with what the app was last doing, and times a scripted tour (Home, the largest project and its tabs, the Toolbox, Settings, New project, the longest chat, ten steps added to it) into `~/Library/Application Support/Dighouse/perf.log` (`Perf.swift`). `-openProject <folder> -openTab Notes` opens a project on a tab at launch; `-startBlindTests borre,mound-city` runs blind tests in turn.
- **F1, the window.** `MarkdownText` parses each text once and lays out lazily (the Notes tab stalled 0.6 s); the Sources list is lazy; the last eight chats are kept in memory; long tool results are shortened by bytes (counting characters walked whole texts and stalled opening a long chat for seconds).
- **F2, a faster search.** `check_finds` slices, measures and map-checks every open find in one call. The skill and prompts: sources once per area, at most ten minutes on one check, one summary per area; a timed session starts on new ground with helper agents. One hour searched 4.0 km² (15 minutes per km², against 36).
- **F3, the method holds.** Borre 25/53, Mound City 19/19, Maiden Castle 3/3, Cahokia 1/1, Andía 1/11; extra finds under 50 per km². Every miss is "looked at, not marked".
- **F4, the review list.** Records open on leads, then **Look again** (the agent says natural, the second model says built), then routine groups with **Agree with these**. A lead is decided alone.
- **F5, more of the world.** North Rhine-Westphalia, Scotland (newest survey first, by Ordnance Survey sheet), Wales (one cloud-optimised file) and Slovenia (text sheets; block found once and kept). Old maps in France (IGN's État-major map and 1950s photographs).
- **F6, easier to start and follow.** Home: **Search on its own** (two presses to a running session) and, while one runs, its progress card. Sidebar: second opinions left. Pick a place: searched ground shaded, dots when zoomed out.
- **F7, two hours alone.** Started from Home: 8.45 km² in five areas, 102 finds, every one sliced, suggested and given a Sonnet opinion, no step-ins, no stall while it searched. The header badge counts what the review list shows.
- **Where it stands.** The search is fast and holds its method; the open questions are the person's: about 9 finds to look again across the five new projects, plus the routine groups, and the four leads from the second-opinion loop. Second opinions are the slow part now (Sonnet took 79 minutes for 102 finds).

## What the second-opinion loop added (2026-11-21)

The goals and every check are in [SECOND_OPINION_LOOP.md](SECOND_OPINION_LOOP.md).

- **S1, no Google models.** `ModelInfo.unsupported` drops any model whose id mentions google, gemini or antigravity as the list loads. `reconcileModels()` replaces a saved agent or second model that is no longer offered and shows a one-line notice in Settings (`modelNotice`).
- **S2, a second opinion that falls through.** `ModelInfo.secondOpinionOrder`: Claude Sonnet 5.5, then GLM-5.3, then Kimi K3 (opencode-go). A model that fails is set aside for the run and the next is asked about the same find; the record names the model that answered. Settings, Models lists them in that order, each with Check.
- **S3, how good the reviewers are.** `scripts/rate_reviewers.py` scores models on crops of known ground. Sonnet's "not built" was right 91% of the time, its "built" 40%. The record says a disagreeing opinion counts and an agreeing one is a weak check (`secondMeaning`).
- **S4, opinions on old work.** `scripts/second_opinions.py` asks for opinions outside the app, the same way the app does. Every open find in the ground-search and Cahokia projects has one.
- **S5, measured rises.** `add_measured_rises` opens the best-shaped rises on possible or built tiles as finds marked "measured, not seen", at most 50 per km². The whole search calls it once after every tile has a verdict.
- **S6, old maps.** `history.py`: `check_old_maps` shows the find on the oldest USGS topographic sheets (TNM) and lists mines within 300 m from MRDS; `record_old_maps` files the result and the record gets an Old maps row. Of 17 leads, 2 were explained (a 1955 building, a section-line cut).
- **S7, searching alone.** The timed session's prompt asks for 1 to 2 km² areas, one calibration per source, measured rises, old maps and a running tally. When a timed session ends (`searchEnded`, defaults `timedThread` and `timedStart`), second opinions are queued for every non-test project it touched (`askSecondOpinions(in:)`). An early "complete" or a self-declared "blocked" is turned back once (`reopenIfEarly`). A project made in any chat joins the list (`onProjectMade`). For scripted runs, `open Dighouse.app --args -startTimedResearch 120` starts one at launch. The two-hour run searched 3.2 km² and every one of its 224 open finds got a Sonnet opinion; it is slow on new ground (about 25 minutes per 1.5 km²).
- **Where the leads stand.** Four leads remain that Sonnet calls built and old maps do not explain: Darby Prairie C-008, Lusk Creek Woodland C-003, Shawnee Woodland Larger C-003 and C-008. Each needs the state site file (Ohio, Illinois), which is not public.

## Where a person starts (2026-11-19)

Chris could not see where to start: the Home cards, the Toolbox's coverage map and "Help me choose a place" did not lead to a place. Now the map is the way in.

- **Home:** the first card is **Pick a place on the map**; then **Suggest a place for me** (the agent proposes three) and **Test it on a known site**. Right below is **Where you can search**: the coverage map, which starts a project wherever it is clicked, with its legend. How it works keeps two tabs.
- **The coverage map** (`CoverageMap`, ToolboxView.swift) is clickable on Home, the Toolbox's first stage and the Open data tab. A click opens New project with the map on that region (`startProject(near:lon:)`, `StartingPoint.look`).
- **New project:** zoomed out, the map shades where open lidar reaches (the `Reach` outlines and the survey dots) with a legend, and a click zooms in. Zoomed in, a click places the area. An unnamed project gets the nearest place's name ("Bowling Green area") and a first question; a typed name is never replaced. With no open data, a button zooms back out to the shaded areas. Under Create, a line says what is missing.
- **"Pick a place on the map"** is the `choose` workflow, which now opens New project with no chat, from the empty chat, the Workflows menu and the Toolbox's first stage. The guide's "Help me choose" became "Suggest a place" (the research workflow).
- Checked in the test copy: Home map to New project; world to Ohio to an area named "Bowling Green area" with USGS 3DEP listed; a spot in India with no data; the Toolbox's first stage; the empty chat's card. Create was not pressed.

### Home, refined (2026-11-19)

Chris found Home long and the copy weak ("You decide what each one is"), and the places to start were missed at the bottom. Home is now: the hero with two plain sentences; four ways in on one row (Pick a place, Suggest a place, Test it blind, Open a project); Places to start right below, four known sites (Cahokia, Newark, Lauske, Thunder Bay) with Show all, and Open surveys as the second tab; Where you can search; How it works. "Why not just ask ChatGPT?" is gone from Home.

- README pictures of Home and New project retaken on 2026-11-19 at 1440 x 900 in Earth, in the test copy with no projects (-projects <5b5d> -tutorialDone YES), the Computer Use indicator painted over. New project now opens on the United States and Europe together (an MKMapRect fitted to the width; a region fitted only the height).

## What loop 8 added (2026-11-16)

- **P1, own folder.** Every way of starting a project makes a new folder in `~/Dighouse` (`projects_home()`, `new_folder()` in project.py) with git and a first commit. A taken name gets -2, -3. The engine starts the tool server with a filtered environment, so the folders reach it through `mcp_servers.dighouse.env` in `Engine.swift`.
- **P2, Make this a project.** The agent offers a project with `suggest_project` (it makes nothing). The chat shows a card; pressing it opens New project filled in. Once the project is made, `ChatModel.move` forks the chat into the project's folder and archives the general copy, because the engine lists chats by the folder they started in. A fork has no message of its own until it is used, and the engine does not list it until then, so moved chats are kept in the `movedChats` default. `/make-project` uses the offer, asks the agent for one, or moves a chat into the project it already made.
- **P3, first records.** `start_from_chat` writes "Why this area" into PROJECT.md, the chat's sources into `sources/read-log.md`, and `notes/<date>-started-from-chat.md`, then commits "Started from chat: <title>". Coordinates are taken out.
- **P4, GitHub only when asked.** New project has a Folder row; `suggest_project` takes `work_in_github`. `new_folder` refuses iCloud folders and anything inside an existing repository.
- **P5, history and publishing.** The overview's History section lists the last five commits, with Show in Finder and Publish to GitHub. `check_before_publishing` runs first, then `gh repo create --private --push`; after that the button is Push changes. Every step shows in a panel under the history: Chris did not want pop-up windows.
- **P6, explained in the folder.** PROJECT.md's "How this project is kept", added to older projects when the record is rebuilt. A plain Codex session read a project correctly from it.
- **After the loop (polish):** "What should I research?" ends with an offer card rather than making the project itself, and a project made from a chat starts on its ground in that chat, as any new project does. The agent's own "Project created" card brings its chat along. A moved chat named after a workflow is renamed "Choosing <project>". The agent writes a search report only in a whole search. The stage strip no longer steps back. Coordinates are taken out of shared notes without breaking DOIs and links.
- **2026-11-17:** Home has a "How it works" section (how a search runs on its own, what a project writes down, where Dighouse can look). Asking in a chat to search a place makes the agent offer a card, Make it a project and search, which makes the project and runs Find and report back (`search_now` on `suggest_project`); checked end to end at Miamisburg Mound, which ended with a search report. A refused second opinion goes on the record (`second_look_failed`), so the report says it was asked and what to do. The stage strip follows the project's state until every tile is looked at. Czechia, Canada and INFOMAR added, each with a live test; Poland's WCS (`mapy.geoportal.gov.pl`) never answered from this Mac.
- **2026-11-17, later:** a second model that its provider refuses (403, access denied, disabled) is remembered (`secondModelRefused` default) until another is chosen or it answers again. The project card then says "The second model is refused" with the provider's reason and Choose another model; the step leaves the header, `/second-opinion` explains, Settings, Models warns, and a whole search skips the second opinion and writes its report. Find and report back from a typed place checks open data first: with none, it says so and makes no project. Publishing checks that gh is signed in and picks a free repository name (dighouse-2 when dighouse is taken), named in the confirmation. A draft typed on Home no longer follows you into a project.
- **2026-11-18:** the engine runs with its own Codex folder, `~/Library/Application Support/Dighouse/Codex` (`CODEX_HOME`, set up by `Paths.prepareCodexHome` at every launch): a link to `~/.codex/auth.json` for the sign-in, a link to the installed plugins, and a `config.toml` copied from `~/.codex/config.toml` with only the top-level keys (minus `model` and `notify`), model providers, profiles, shell policy, features, plugins and marketplaces. Dighouse's chats are saved there and no longer appear in the Codex app. Chris's 228 earlier Dighouse chat files were copied in once, with their names and history rows from `state_5.sqlite` and `thread_history_1.sqlite`, and the 181 active ones archived in `~/.codex` (the list is in `Dighouse/Codex/archived-in-codex.json`; unarchive to undo). The project overview has a "The project folder" list: each document, what it holds and a live count, opening it in the workspace.
- **2026-11-19:** `scripts/setup.sh` checks the Mac, Xcode, uv, Codex and the sign-in, offers to install uv and to sign in, builds, offers to copy to Applications, and will not open a second copy when Dighouse is running. `docs/SETUP.md` is the plain setup page. Building with only the Command Line Tools failed on this Mac (the package manifest would not link), so the docs ask for Xcode. Shizuoka Prefecture's 0.5 m ground model (`jp-22:shizuoka-dem`, zipped text grids per 300 by 400 m map sheet, newest survey first; `_shizuoka_sheets` names the sheets) added with a live test at Yamanaka Castle. Its coastal bathymetric lidar (ALB) was left out: it covers scattered strips, and offering it across the prefecture would mislead. Tirol and Poland did not answer; the UK seabed site has no open service at the address tried.
- **P7, goals and commands.** A running goal shows a bar with Stop at the top of its chat. A command typed in full is the one Return runs, even when it can't run (it then says why), and an unknown /word gets an answer.

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

- **Delete the test repository** `chrissotraidis/default-folder-check` (private), made to check publishing.
- **The promotional video** (30 to 40 seconds, made from real app footage) waits for his pass.
- **Going public.** The README reads as if the repository were public. Making it public, tagging a release, and a notarized download are his decisions.

- **Use this build and say what is still rough.** Loop 5 answered his list item by item (the Log has a picture for each), but his eye has not been over the result.
- **Second opinions** run on Claude Sonnet 5.5 by default, falling back to GLM-5.3 and then Kimi K3 (opencode-go) when a provider refuses. Google models (Antigravity and Gemini by any route) no longer run through OpenCodex and are hidden from every model list (2026-11-21).
- **OpenAlex and a key.** Without a key, a network address shares about 100 literature searches a day, and Dighouse falls back to Crossref past that. A free key lifts it to about 1,000. Asking for one sends an email address to OpenAlex, so it is his to do; a field for the key in Settings is a small job if he wants it.
- **Real hands:** dragging a line across the mound in the Toolbox, dragging the sidebar edge and the chat divider with a mouse, dropping a file from Finder onto the message box, pinch zoom and two-finger panning on the map, the "…" button that shows under the pointer on a sidebar row, and how the menus in the menu bar look (test tooling opens them without drawing them).
- **Decisions:** a notarized download, a Notion button, looking at tiles in bulk through the model router, the licence, and when the repository goes public.
- **Open astronomy:** whether to try a sky version, and which first step. The research is in [research/open-astronomy.md](research/open-astronomy.md); it recommends a second field in this app, starting with a tool server run in plain Codex.
- **His three test chats named "What should I research?"** were left as they are. New chats from the same workflow are numbered.

## Not verified

- **Publishing** with gh signed out (handled in words, not seen) or set to SSH. A taken name was checked: the confirmation offered dighouse-2.
- **The GitHub folder in iCloud or missing,** in the app. The refusal is covered by the offline test only.
- **Two sign-in refreshes at once.** Dighouse's engine and the Codex app share `auth.json` through a link but not Codex's lock file, so if both refresh the sign-in at the same moment one may be refused and need `codex login`. Not seen.
- **A moved chat whose archived original is deleted.** The copy reads its earlier turns from the original, so deleting archived chats in Codex would cut that history.
- **A second opinion from GLM-5.3 or Kimi K3 inside a real search.** Both answered Check in Settings and the S3 rating; in the S4 runs Sonnet always answered, so the fallback was seen only with Grok chosen by hand.
- **The map check's second way in** in a town dense enough for the map service to refuse the 4 km square, other than in the offline test.
- **The "Nothing here looked built" card** on a project where no tile was marked, and Widen the search.
- **Reduce Motion with the Mac's own setting.** The indicator was checked with SwiftUI's flag outside the app. The mark in the sidebar and the tutorial's ring were not checked at all.
- **A handover between two real Macs,** and a receiver who then fetches the ground for the same place.
- **Find and report back** with usage running out part-way. (A name that cannot be found, and a place with no open data, were checked on 2026-11-17.) (A whole search outside the United States was seen in loop 5, at Borre in Norway.)
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

## What Chris has asked for that is not built

- The agent driving a browser of its own to look up records.
- From the first plan: a button that pushes records to Notion, looking at tiles in bulk through the model router, a notarized download.
- A version for the sky. Researched, not started.
- Out of reach without an account or a key: historic aerial photographs, CORONA imagery, and the lidar of Finland and Sweden (Sweden's 1 m model has been free with an account since February 2025; Denmark is read with a token). Not read yet: Spain beyond Navarre and the Basque Country (5 m only), Poland (no answer), Luxembourg (no ground model listed). Scotland, Wales and Slovenia were added in the reach loop. Not yet checked: the Archaeology Data Service, EAMENA, tDAR.

## How to build, run and check

```sh
cd app && (pkill -x Dighouse || true) && ./scripts/bundle.sh
open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES
```

- **Start it clean when you start it from an agent's shell.** A shell inside the Codex app carries Codex's own environment into the app and its engine. Use `env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" TMPDIR="$TMPDIR" PATH="/usr/bin:/bin:/usr/sbin:/sbin" /usr/bin/open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES`.
- **A quick loop:** `swift build` (a debug build, a few seconds), copy `.build/debug/Dighouse` into the bundle, copy `Resources/tour` and the Python tools with it, re-sign with `codesign --force --deep --sign -`, relaunch. Finish with `bundle.sh` for the release build. Loop 5's script for this is `~/Documents/Codex/2026-11-14/dighouse-loop5/work/devrun.sh`.
- `bundle.sh` copies the Python tools into the app. The tools' environment is rebuilt by the app only when `uv.lock` changes; changed Python is picked up at the next launch.
- **Window size:** quit the app, write the frame to both the `NSWindow Frame main` key and the long `NSWindow Frame SwiftUI…AppWindow-1` key, then launch with `-ApplePersistenceIgnoreState YES`.
- **Checking while Chris has Dighouse open:** run `app/scripts/test-copy.sh` after `bundle.sh` and open `build/DighouseTest.app`. It has its own settings (`com.chrissotraidis.dighouse.test`), so it cannot change his projects list; a second copy of the real app shares his settings and can. `bundle.sh` now replaces the binary rather than writing over it, so a running copy keeps its own file.
- **Driving it with Computer Use:** find controls by their accessibility text. Sidebar chats can share a name with a button on the page, so look for a control after the Settings button in the list. A drag takes screen pixels, twice the points on this Mac. Menus in the menu bar can be opened and clicked but are not drawn. A right-click works; hover does not. Keep each call under 30 seconds. A run can be watched by polling for the Stop button.
- **Counting words:** take the accessibility text of the page after the sidebar's Settings button, keep names and values, leave out help text, and count. Loop 5's numbers were taken at 1440 × 900.
- **Pictures:** `screencapture -o -x -l<window id>` gives the window alone, with no Computer Use pill and no pointer; bring Dighouse to the front first. Computer Use's own screenshots include both.
- **Empty settings for a first-run check:** export the settings, `defaults delete com.chrissotraidis.dighouse`, write back the window frames, `model` and a scratch `projectsHome`, run the check, then delete and import the export.
- The engine takes about four seconds to list one folder's chats on this Mac. Chat lists are cached in defaults under `chatLists`.
- Defaults keys the app uses: `look`, `textSize`, `chatWidth`, `sidebarWidth`, `layout`, `model`, `recentModels`, `secondModel`, `effort`, `toolboxTab`, `tourStage`, `startKind`, `mapStyle`, `toolServers`, `projects`, `currentProject`, `projectsHome`, `githubHome` (tests only), `userName`, `onboarded`, `chatLists`, `movedChats`, `secondModelRefused`, and the tutorial's `tutorialOn`, `tutorialProject`, `tutorialReached`, `tutorialDone`.
- **Checking project creation without touching Chris's folders:** launch with `-projects '<5b5d>' -currentProject '' -projectsHome $HOME/dighouse-ui-test -githubHome $HOME/dighouse-ui-test-github` (both scratch folders, from loop 8). To list chosen test projects, pass `-projects "<hex of the JSON list>"`. Export the settings first and import them afterwards, then delete `projectsHome`, `githubHome` and `movedChats` if present.
- **Projects on Chris's Mac:** `~/Documents/Dighouse` holds his own (Angel Mounds, Maiden Castle, Mound City Group, Perry Mesa, Serpent Mound, Middle Usumacinta) and three test projects (`mound-city-review-test`, `serpent-mound-goal-run`, `fort-ancient-ohio`). The Cahokia control run is in `~/Documents/Codex/2026-11-12/vb/work/dighouse-projects`. Scratch projects from loops 4 and 5 are under `~/Documents/Codex/2026-11-14/dighouse-loop4/work` and `~/Documents/Codex/2026-11-14/dighouse-loop5/work` (a finished Mound City search, and a Borre search in Norway that waits for decisions). They are not in his list; open them with File, then Open Project Folder.
- Pictures in `app/Resources/tour` and `app/Resources/starts` were made with the tools from open data. Keep it that way, and say in the caption where each comes from.
