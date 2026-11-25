# Dighouse goal loop 6: prove it works, and make it easy to try

Last updated: 2026-11-15

Read [HANDOFF.md](../HANDOFF.md) first, then the end of [REFINE_LOOP.md](REFINE_LOOP.md). Loops 1 to 5 built the app, the tools, the look and the research record. This loop answers the question an archaeologist asks first: how often does it find what is really there, and how often does it mark things that are not? It does that with **blind tests on known sites**, scored against published answers. The same tests become the easiest way for a newcomer to try Dighouse, from Home.

## Who this is for

- **A newcomer** who wants to see it work before trusting it. They pick a famous site, watch the agent look at it without being told what it is, and see a scorecard.
- **An archaeologist** deciding whether to take it seriously. They want a hit rate, the misses and the false alarms, with sources for the answer key.
- **Someone searching for something new.** Before a search where nothing is on record, the agent proves on a known site nearby, with the same lidar, that it can find what is there.

## Decisions already made (Chris, 2026-11-15)

- Tests are **blind** by default. The agent is not told the site's name and does not search the literature until its looking is scored. The literature search runs afterwards, as in a normal run.
- Answer keys are **curated by hand** for six launch sites, with an **automatic** key from open records as a backup for any other place.
- Scores are **published** in the README, whatever they are.
- Order of work: the blind test and scorecard first, then "What is this?", then the feature guide, calibration and a smarter "What should I research?".

## Goals

Each goal is done when its check passes in the running app. Record the date and what was seen in the Log below. Work them in order.

| Goal | What | Check |
|---|---|---|
| T1 | **Answer keys.** Six launch sites, each with a key: Angel Mounds, Mound City Group, Serpent Mound, Cahokia (the Monks Mound area), Maiden Castle and Borre.<br>- **Contents:** every published feature inside a fixed test area: what it is, a rough size, and the source (author, year, title or record id).<br>- **Storage:** inside the app's own data, never in a project's records, notes or reports, and never in the README.<br>- **Automatic keys** for any other area: the same format, built from OpenStreetMap, Wikidata and the National Register, and marked as automatic and incomplete. | Each launch key lists its features with a source for each. An automatic key built for each launch area is compared with its curated key, and the gaps are written in the Log. |
| T2 | **The blind test and its score.**<br>- **Blind run:** a project marked as a test hides the site's name and question from the agent, and blocks the literature tools until scoring is done.<br>- **Scoring tool:** matches each find to a key feature within a distance set by the feature's size, then counts found, missed and marked-but-not-in-the-key.<br>- **Afterwards:** the literature search runs, and each extra find is labelled as a false alarm or worth a second look.<br>- The score goes into the research record and the report, without coordinates. | Offline tests on the synthetic survey cover a perfect run, a miss, a false find, and a find matching two features. One live blind run on Mound City with primary / 6.1 Terra produces a score. |
| T3 | **"Test it on a known site" on Home.**<br>- **The card:** a third card beside "What should I research?" and "I know where to look". It opens a short list of the six sites with a picture and a sentence each, and one press starts a blind test.<br>- **During the run:** the strip shows the stage and a Stop.<br>- **The scorecard:** found, missed and extra, each with its picture; a map with the key's features and the agent's finds in two colours; the time and model; and "Run it again" and "Try a new area".<br>- "Why not just ask ChatGPT?" moves lower on Home or goes, if the test card does its job better. | From Home, one press on Angel Mounds ends in the scorecard with no typing, using primary / 6.1 Terra. Stop leaves the project consistent. Screenshots in Earth and one other look. |
| T4 | **"What is this?", a quick look.**<br>- **How to ask:** type a place name in Home's box, or click a spot on a map, and choose "What is this?".<br>- **What it does:** fetches about 300 m around the spot, renders it in sky view and hillshade, describes the shapes in plain words, and checks open records for what is known there.<br>- **The answer:** a card with the picture, what the shapes probably are, what is on record (with sources), and "Search this properly", which starts a project there.<br>- It finishes in about three minutes or says why not. No project is created unless asked. | Three places checked with primary / 6.1 Terra (one famous, one ordinary field, one wooded area): each ends in the card, and times are in the Log. |
| T5 | **A feature guide.**<br>- **Form:** a Markdown guide the agent reads before it looks (skills/dighouse/FEATURES.md).<br>- **Each feature type that survives as relief** (mounds, enclosures, banks and ditches, terraces, hollow ways, field systems, charcoal hearths, kilns, house platforms): what it looks like in sky view and hillshade, and its usual size.<br>- **Look-alikes to rule out:** sinkholes, tree throws, bomb craters, mining and quarry pits, drainage, plough ridges, modern trails, and spoil heaps.<br>- Every finding names the guide entry it relied on. | The blind test on two sites, before and after the guide, with primary / 6.1 Terra. The Log compares found, missed and extra. If the guide makes scores worse, revise it until it does not. |
| T6 | **Calibration and a smarter "What should I research?".**<br>- **Proposals:** areas are ranked by open lidar quality, few recorded sites, landscape where relief survives (forest above ploughed land), nearness to known sites of the same culture, and not built over. Each proposal names the known site that will calibrate it.<br>- **Calibration:** before a search where nothing is on record, the agent runs the blind test on that nearby known site with the same survey. A poor score stops the search and says so plainly.<br>- **Early check:** each new find is checked against open records straight away, so known sites drop out before the slice and second opinion.<br>- The calibration score goes into the record and the report. | "What should I research?" gives three proposals, each with its calibration site. Running one with primary / 6.1 Terra calibrates first, and the report shows the calibration score. A deliberately poor calibration (a survey with a known_problem) stops the search. |
| T7 | **The benchmark.**<br>- **Runs:** the blind test on all six sites with primary / 6.1 Terra, then a results table: site, data, found of known, missed, extra (false alarm and worth a second look), time.<br>- **Smoke test:** a script that runs one tile end to end in about a minute.<br>- **Rerun rule:** both are rerun whenever the model, the prompt, the skill or the feature guide changes, and the results go in the Log. | The table is in the Log with the date and model. The smoke test passes. |
| T8 | **README and docs.**<br>- **Lead:** "Search public lidar for possible built features, check each one, and record what is already published. You decide what they are." Define "find" once as a shape that might be built and is not yet confirmed.<br>- **New sections:** "Benchmarks" (T7's table, honestly); "What it cannot do" above the pictures; "Responsible use" (don't visit or dig, disturbing sites is illegal in many places, report to the state historic preservation office or local heritage record and not online, think of the communities connected to a place, and the GeoJSON export holds coordinates).<br>- **Trim:** the self-praise, and the badges to three.<br>- **Pictures:** retake the README pictures, adding the scorecard and "What is this?".<br>- **Docs:** HANDOFF, concept, ROADMAP and this file agree with the app. | The README reads plainly to someone new, and every claim in it is backed by the Log. main is pushed and clean. |

## Rules for this loop

- **Cheap models only.** Every test that sends a message to a model uses primary / 6.1 Terra. Never test with Opus. The second-opinion model may be any non-Opus model from another maker.
- **Keep the blind test blind.** If the agent can see the site's name, its question, or literature before scoring, the score is void. Check this in the chat's steps.
- **Report scores as they are.** Do not tune a prompt on one site and report that site's score as if it were fresh. Say what was changed between runs.
- **Locations stay private.** Answer keys and finds carry coordinates only in the app's private data or a project's private/. Scorecards, records, reports, the README and chats never show coordinates.
- **Keep it simple.** One clear control over three clever ones. Reuse Controls.swift, Theme, Motion and .arrives(). Do not suggest Figma.
- **Plain words:** find, slice, look at, second opinion, the ground. Write lidar in lowercase. Never call a site new. A person decides and a person sends.
- **Say only what was checked.** Recheck every control you rewire, and the ones next to it.
- **One branch and pull request per goal:** codex/ prefix, logged first, squash-merged with gh pr merge --squash --delete-branch.
- **Work in the existing checkout,** /Users/chrissotraidis/GitHub/dighouse. No sibling clones in ~/GitHub.
- **Nothing is released.** The repository stays private until Chris says so.
- **Leave Chris's things as you found them:** his settings, projects list and model choice. Archive the test chats and remove test projects from the sidebar list (keep their folders) when a goal is done.

## How to build, check and drive the app

- **Build and open:** cd app && (pkill -x Dighouse || true) && ./scripts/bundle.sh && open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES. Building takes 1 to 3 minutes; poll the session and don't block.
- **Tests:** uv run pytest -q (offline). uv run pytest -m live talks to real services.
- **Driving the app** with Computer Use: prefer accessibility element indices from getAXState. Coordinate clicks are in full-resolution pixels (a screenshot point divided by about 0.696). Keep each call under 30 seconds. ⌘K jumps to any project, chat or find.
- **Window size and README pictures:** see the same section in [POLISH_LOOP.md](POLISH_LOOP.md):
  - back up the settings plist first;
  - hide the test projects while the app is closed;
  - bring Dighouse to the front before screencapture;
  - cover the Computer Use indicator.

## The loop (every turn)

1. Read HANDOFF.md, this file and the Log below.
2. Pick the lowest unfinished goal.
3. Build it, then run its check in the running app and look at the result.
4. Fix what the check shows. Repeat until it passes.
5. Record the result in the Log with the date. Run the tests, commit, open the pull request and merge it.
6. Stop when T1 to T8 are checked, when a decision is needed from Chris, or when the time Chris set runs out. Before stopping, write in the Log what is half done and where, and update HANDOFF.md.

## Log


### 2026-11-15, T1: answer keys

- **Six launch keys** in src/dighouse/keys/, rebuilt from open data by scripts/build_answer_keys.py. Each feature names where its position comes from (an OpenStreetMap element or a record in Norway's heritage register) and the publication that describes it. A feature is either a point with a size (a mound) or a work drawn as lines (ramparts, an effigy, an enclosure wall). Features the key keeps but does not count (gone, found only by ground radar, low stone footings, a modern reconstruction) say why.
- **Storage:** the keys hold coordinates, so they stay with the tools' own data. Nothing a person sees from them (answers.summary, the comparison, and later the scorecard) holds any; an offline test checks this.

| Site | Counted | From | Coverage |
|---|---|---|---|
| Angel Mounds | 4 mounds (A, B, C, E) | OpenStreetMap; Black (1967) describes 11 mounds at the site | partial |
| Mound City Group | 18 mounds and the enclosure wall | OpenStreetMap; Squier and Davis (1848) map 23 mounds, the National Park Service counts 25 | partial |
| Serpent Mound | the effigy and 2 burial mounds | OpenStreetMap; Squier and Davis (1848), Fletcher et al. (1996) | partial |
| Cahokia | Monks Mound | OpenStreetMap; Fowler (1997) maps more than a hundred mounds at Cahokia | partial |
| Maiden Castle | the ramparts, the west entrance outworks, the east entrance outworks | OpenStreetMap; Wheeler (1943), Sharples (1991) | partial |
| Borre | 53 burial mounds, cairns and graves (7 more kept but not counted) | Riksantikvaren's Askeladden register; Myhre (1992) | register |

- **Not in the keys, and said so in each key:** Angel Mounds' other mounds and palisade, Mound City's other 5 to 7 mounds and borrow pits, Cahokia's smaller mounds, Maiden Castle's Neolithic long mound. A partial key means an extra find may be real; the literature step labels each one.
- **Automatic keys** (answers.auto_key, from OpenStreetMap, Wikidata, the National Register and Pleiades) compared with the curated keys (answers.compare):

| Site | Automatic sites | Curated features held |
|---|---|---|
| Angel Mounds | 6 | 4 of 4 |
| Mound City Group | 2 | 4 of 19 (two site points near the middle, matched generously) |
| Serpent Mound | 2 | 2 of 3 |
| Cahokia | 1 | 1 of 1 |
| Maiden Castle | 11 | 0 of 3 (the sites are points inside the fort; the ramparts are lines) |
| Borre | 2 | 1 of 53 |

  The automatic keys hold 12 of the 83 counted features. They stay as the backup for other places, marked automatic and incomplete, but a score against one is a lower bound and the scorecard will say so.
- **Overpass was down** (502 and 504 from three servers) while the keys were built; OpenStreetMap's own map service was used instead.
- Test: test_answer_keys_are_sourced_and_inside_their_areas. uv run pytest: 14 passed.

### 2026-11-15, T2: the blind test and its score

- **Blind run:** start_test (answers.start) makes a project named "Blind test <date> <n>" with a neutral question. The test area is registered in the tools' cache, and until the test is scored:
  - search_literature, read_source and log_source refuse in the project;
  - survey_area, find_gaps and search_records refuse for the area;
  - find_data drops titles and descriptions that could name the place;
  - check_modern leaves out historic place names.
  run_status shows blind_test, and the skill and the "Find and report back" prompt tell the agent what that means.
- **Scoring:** score_test (answers.score) works as follows.
  - Each mound in the key takes at most one find, the nearest within half its size plus 15 m.
  - A find within 20 m of a rampart or wall counts that work once; more finds on it are not extra.
  - A find on a feature the key does not count is set aside.
  - Everything else is extra. After the literature step, its decision or suggestion labels it a false alarm (modern or natural), real but not in the key, or worth a second look.
  - The score goes into private/state/score.json, a "Blind test" section of RESEARCH.md and one sentence in the 400-word report, none with coordinates.
- **Three tools:** list_tests, start_test and score_test, making 36 in all.
- **Two fixes found by the live run:**
  - The agent gave up on a USGS fetch that was still going: 71 of 158 parts after about 5 minutes. A full fetch of this 0.25 sq km area took 421 seconds, so the skill and the "Find and report back" prompt now say a fetch can take ten minutes and to wait.
  - Fetched points are cached by dataset and area (sources.fetch_points), so a rerun of a blind test or the benchmark takes seconds instead of minutes.
- **The app froze on launch** while macOS waited for permission to read the Documents folder. Each rebuild has a new signature, so macOS asks again, and file dates were read on the main thread with FileManager.attributesOfItem, which also reads extended attributes. Dates and sizes now come from stat(2) (FileInfo in Core.swift), and Home's greeting card reads the project folders off the main thread. The permission prompt itself waits for Chris.

**The live check (headless):** the in-app run waits on that prompt, so the check ran through the same Codex engine (0.167) and the Dighouse tools from the terminal, with primary / 6.1 Terra at medium effort, on Mound City Group.

| | |
|---|---|
| Ground | OH_StatewideP3_7_B21, 0.25 sq km, 5.4 ground returns per sq m, fetched in about 7 minutes |
| Looked at | 6 of 6 tiles in sky view and hillshade: 4 looked built, 2 modern |
| Finds | 23, each sliced and checked against open maps; no second opinion (the run had no way to ask the second model) |
| **Score** | **19 of 19 features in the key found, 0 missed, 3 not in the key** |
| Extras after the literature step | 3, each suggested "already published" (real, but not in the key): the National Park Service counts 25 mounds, and the key holds 18 |

- **The run stayed blind.** Its shell commands read only the skill, the project's own files and three of its find records, never the keys or the cache. All four searches (3 literature, 1 web) came after score_test.
- **What the score does not show:** the key is partial (18 of the 23 to 25 mounds), so 19 of 19 says the agent finds the mapped mounds, not that it finds every mound. Matching uses each mound's mapped size plus 15 m; mounds here are 30 m or more apart, so one find cannot take two mounds.
- **Tests:** test_scoring_counts_found_missed_and_extra and test_blind_test_closes_the_literature_until_scored. uv run pytest: 16 passed.

### 2026-11-16, T3 and T4 built; the in-app checks wait on a macOS prompt

macOS is asking whether Dighouse may read the Documents folder ("Allow" or "Don't Allow"). Every rebuild has a new signature, so it asks again, and the app waits on any project read until someone answers. Granting an OS permission needs Chris, so T3's and T4's checks in the running app are not done. Both are on the branch codex/t3-test-card, unmerged.

- **T3 (built, not checked in the app):**
  - **Home:** a third card, "Test it on a known site", opens a picker of the six sites, each with a picture. New pictures were drawn for Angel Mounds, Maiden Castle and Borre from their lidar. One press runs start_test, opens the project and starts Find and report back.
  - **Scorecard:** it opens at the top of the search report when the project has a score, with found, missed and not-in-the-key tallies, the time and model, a map with the key's features and the finds, a close-up of each miss and extra, "Run it again" and "Try a new area".
  - **Pictures:** score_test now draws the map and close-ups under private/state/score/. From the Mound City run, the map has every mapped mound circled with a find on each.
- **T4 (built; the tool checked headless):**
  - **The tool:** quick_look (src/dighouse/quicklook.py), the 37th tool. It looks up a place, fetches 400 m of ground at 1 m in a scratch folder in the cache (a national ground model first, then USGS, then OpenTopography), draws sky view and hillshade side by side, and lists what open records hold within 1 km. No project is made.
  - **In the app:** "What is this?" sits beside "Find and report back" when a place is typed on Home, and there is a /whatis command. The chat shows the picture in a card with "Search this properly", which makes a project on that square and runs the whole search.
  - **Faster fetches:** a 1 m fetch now asks the archive for a quarter of the points. Shawnee State Forest went from 402 s to 146 s with 1.8 ground returns per sq m, so the first live run timed out there and the second did not.

| Place (quick_look) | Data | Seconds | On record within 1 km |
|---|---|---|---|
| Newark Earthworks, Ohio | USGS 3DEP, 7.4 per sq m | 58 (cold), 2 (cached) | 4 (OpenStreetMap: the Great Circle, Eagle Mound, Wright Square) |
| Shawnee State Forest, Ohio (wooded) | USGS 3DEP, 1.8 per sq m | 146 after the change, 402 before | 0 |
| Rantoul, Illinois (ordinary town and fields) | USGS 3DEP | under 3 minutes | 0 |
| Maiden Castle, Dorset | Environment Agency 1 m | 54 to 220 (the service is slow) | 18 |
| Borre, Norway | Kartverket 1 m | 55 | 2 |

- **Headless run with primary / 6.1 Terra on the three places T4 names:** Newark was described as a circular bank and ditch with a mound inside, matched to the recorded Great Circle and Eagle Mound. Rantoul read as modern streets and lots, with nothing on record. Shawnee timed out on that run, before the faster fetch.
- uv run pytest: 17 passed.

### 2026-11-16, T5: a feature guide (checked headless)

- **The guide:** src/dighouse/FEATURES.md, read through a new tool, feature_guide (38 tools in all), so the agent gets it in the app, from the terminal and in any MCP harness. The plan named skills/dighouse/FEATURES.md, but the app hands the agent the skill as text, so a file beside it could not be opened. The guide covers:
  - ten built features that survive as relief, each with what it looks like and its usual size: burial mound, platform mound, bank and ditch, hillfort ramparts, terraces, hollow way, field system, charcoal hearth, house platform, kiln and mine workings;
  - twelve look-alikes: sinkhole, tree throw, crater, prospect pit, drainage, plough lines, tracks, spoil, gullies and river forms, glacial and wind forms, modern earthworks, data artefacts;
  - what to do when unsure.
- **The skill:** the agent reads the guide before the first tile, marks one find per mound (one per rampart or field system), and starts each note with the guide entry it matches. In the runs below, every find did ("Guide: burial mound", or "Guide: no entry" twice at Mound City).
- **Tiles drawn larger:** a 1 m ground model gave a 250 m tile only 250 × 250 pixels, so a 6 m mound was 6 pixels across. Tile images are now drawn at least 1000 pixels across.

Blind tests, primary / 6.1 Terra at medium effort, no second opinion, run headless (the in-app runs still wait on the macOS prompt). "Before" used the skill as it was; "after" added the guide and the one-find-per-mound line.

| Site | Before | After (guide) | After (guide, larger tiles) |
|---|---|---|---|
| Borre (53 in the key) | 19 found, 34 missed, 1 extra | 19 found, 34 missed, 0 extra | 17 found, 36 missed, 0 extra |
| Mound City (19 in the key) | 19 found, 0 missed, 3 extra (T2) | 19 found, 0 missed, 2 extra | not run |

- **What this shows:** the guide did not make scores worse. It trimmed the extras by one at each site and labelled every find. It did not raise Borre's count.
- **Borre's misses** are almost all small mounds, 6 to 16 m across. Several had a find within 12 m that was matched to a larger neighbour, so the agent marked one find for a cluster. In all three runs it marked 17 to 20 finds, whatever the image size or the guide said. That is the gap to work on: the agent stops at the obvious mounds. The difference between 19 and 17 is within run-to-run variation.
- **Every run stayed blind:** the agent read only the skill and its own project files, and every search came after score_test.
- uv run pytest: 17 passed.

### 2026-11-16, T6: calibration and a smarter "What should I research?" (checked headless)

- **Calibration** (answers.py, four tools; 41 in all):
  - **calibration_site** names the nearest answer key whose lidar comes from the same source (USGS 3DEP, Environment Agency, Kartverket and so on), for proposals to a person.
  - **start_calibration** starts the blind test on that site for a search project without telling the agent which site it is. A first headless run showed why: the agent had been told "Mound City" by calibration_site.
  - **record_calibration** copies the scored test into the search project.
  - **The pass mark** is half the key's features found. Below it, flag_candidate refuses, and run_status, RESEARCH.md and the report say the search stopped and why.
  - **The plan said "the same survey".** Calibration uses the same lidar source, since the six keys cannot sit on every survey; the agent's proposals said so themselves.
- **Early check:** flag_candidate reads the sites on open record for the project's area once (OpenStreetMap, Wikidata, National Register, Pleiades) and, when a new find sits within 120 m of one, says so at once with a hint to check it first. Not in a blind test.
- **"What should I research?":** the prompt now ranks places by open lidar, few sites on record, landscape where earthworks survive (woodland and pasture over ploughed land), nearness to known sites of the same culture, and not built over. It may use quick_look, and it names each proposal's calibration site. find_gaps adds a calibration site to each ranked cell. Forest, ploughing and building are judged by the agent from quick_look pictures and what it knows; no land-cover data is read.
- **A leak found and fixed:** in a blind calibration, check_modern returned names from the map ("City Mound access road", "Visitor Center"). The agent noticed, refused to score a compromised test and stopped. In a blind test the map check now gives only kinds of things ("service", "a building"). Test: test_blind_map_check_names_nothing.
- **Second opinion:** the skill now says a blind test does not need a second opinion before score_test, because the score measures the looking; in the app Dighouse asks the second model itself.

Checks, primary / 6.1 Terra at medium effort, headless (the app still waits on the macOS prompt):

| Check | Seen |
|---|---|
| "What should I research?" | Three proposals in the Chillicothe woods (Great Seal State Park, Tar Hollow and Scioto Trail State Forests), each with its USGS survey, ground density from a quick_look, what is on record (nothing in the four lists for each 4 sq km area), what to expect, and Mound City named as the calibration site 18 to 20 km away. It said plainly that a pass would not prove small or eroded features can be found, and left out Middle Usumacinta and Perry Mesa because their calibration sites use a different lidar source. |
| A calibrated search, Great Seal State Park woods (600 m) | start_calibration, then a blind test the agent was not told the name of: **18 of 19 found, 1 missed, 1 extra, passed**. Then the search: 9 tiles in two views, gullies, slopes and tracks, nothing marked. The report's Calibration section gives the score. Every literature search came after score_test. |
| A poor calibration | A calibration test with no finds (0 of 1 at Cahokia), recorded on a search: flag_candidate refused with the reason, and RESEARCH.md and run_status said the search stopped (test_a_poor_calibration_stops_the_search, through the real tools). Not tried live with a survey that has a known_problem, because such a survey does not build at all, so there is nothing to score. |

- uv run pytest: 19 passed.

### 2026-11-16, why macOS kept asking

The build was signed ad hoc, so every rebuild looked like a new app to macOS, and it asked again for the Documents folder. When answered, the next rebuild asked again, over whatever Chris was doing. app/scripts/bundle.sh now signs with the first "Apple Development" identity on the Mac (DIGHOUSE_SIGN overrides it, and a Mac without one falls back to ad hoc). The designated requirement is the certificate, so one Allow lasts across rebuilds. Checked with codesign -d: Authority "Apple Development: the maintainer's Apple ID (P52SY73DYK)". Dighouse is left closed until Chris allows it once.

### 2026-11-16, T7: the benchmark

All six blind tests ran at once on 2026-11-16 from 00:45, headless through the Codex engine (0.167) and the Dighouse tools, with **primary / 6.1 Terra at medium effort**. The skill included the feature guide (T5), one find per feature, no second opinion before scoring, and the blind map check. Each run read only the skill and its own project files, and every literature search came after score_test.

| Site | Data | Found of known | Missed | Not in the key | About |
|---|---|---|---|---|---|
| Angel Mounds | USGS 3DEP | **4 of 4** | 0 | 2 (not labelled) | 3 min |
| Mound City Group | USGS 3DEP | **19 of 19** | 0 | 3 (real mounds the key leaves out) | 3 min |
| Serpent Mound | USGS 3DEP | **1 of 3** (the effigy) | 2 burial mounds | 1 round mound, 66 m from the nearer one | 3 min |
| Cahokia, Monks Mound | USGS 3DEP | **1 of 1** | 0 | 1 (suggested worth a second look) | 3 min |
| Maiden Castle | Environment Agency 1 m | **1 of 3** (the ramparts) | both entrance outworks | 2 (a small rise, a square hollow) | 10 min |
| Borre | Kartverket 1 m | **18 of 53** | 35 burial mounds, almost all 6 to 16 m across | 0 | 3 min |
| **All six** | | **44 of 83 (53%)** | 39 | 9 | |

- **What it does well:** large and medium earthworks, including platform mounds, Hopewell mounds, an effigy and hillfort ramparts, with few false finds. Without Borre it found 26 of 30.
- **What it misses:** small, low mounds. That is most of Borre's misses and Serpent Mound's two burial mounds. At Maiden Castle it marked the whole fort as one work "with complex entrances", which the key counts as three features. That is partly how the key is drawn, and the miss is reported as it stands.
- **A scoring fix found here:** Angel Mounds first scored 3 of 4. A find on Mound A was 36 m from the mound and 15 m from the modern reconstructed house beside it, and the house, which the key does not count, took it. Counted features are now matched first, and a test covers it (test_scoring_counts_found_missed_and_extra). With the same finds, Angel Mounds is 4 of 4; no other site changed. The stored scores were recomputed from the same finds.
- **The key limits what a score means:** five of the six keys are partial (open data maps only some features), so an extra can be a real feature the key leaves out, as at Mound City.
- **Smoke test:** scripts/smoke_test.py runs one tile end to end through the real tools and services with no model: start a blind test, fetch, tile, render, mark Monks Mound, slice, check maps, score, rebuild the record. It **passed in 30 s** (slice 27.3 m, score 1 of 1).
- **When to rerun:** both are rerun whenever the model, the prompt, the skill or the feature guide changes, with the results added here.
- uv run pytest: 19 passed.


### 2026-11-16, T3 and T4 checked in the running app; T8 done

- **Getting past the macOS prompt:** Dighouse was launched with launch-argument overrides of its projects list and projects folder, pointed at a test folder in the home folder. The app then read nothing in Documents and macOS did not ask. Chris's settings were backed up first and restored after (11 projects, model primary/gpt-6.1-terra).
- **T3, in the app:** Home shows "Test it on a known site". It opened the picker of six sites with their pictures (screenshot checked). One press on Angel Mounds made "Blind test 2026-11-16 1" and started Find and report back, with no typing. The run ended in about 6 minutes, the report opened, and the scorecard sat on top: "It was Angel Mounds", the tallies, the time and model, the map with each mound circled and a find on it, "Run it again" and "Try a new area". The picker's "about twenty minutes" is now "about five minutes".
- **A leak found in the app:** the agent's first step was to search Codex's own memories (~/.codex/memories) for "dighouse lidar" and "blind test". Those notes come from Chris's other chats and could name a site. Dighouse's engine now starts with features.memories=false; this was checked in the running engine's command line. That run's score stands: the agent found the mounds from the tiles, and its searches came after score_test.
- **T4, in the app:** typing "Newark Earthworks, Ohio" on Home showed "What is this?" beside Find and report back. One press opened a chat with the quick look card in about a minute: sky view and hillshade, "USGS 3DEP · 4 on open record within 1 km", and "Search this properly". The agent (primary / 6.1 Terra) described the circular bank and central mound as built, matched them to the recorded Great Circle and Eagle Mound, and named OpenStreetMap as the source.
- **T8:** the README pictures for the scorecard and "What is this?" were taken from these runs and added beside the Benchmarks table. The other README pictures show screens this loop did not change, so they were not retaken.

- **Stop, in the app:** a blind test on Cahokia was started from the picker (in Canopy, where the picker reads well) and stopped during the ground fetch with the strip's Stop. The chat marked the running steps "(stopped)". The notes say "A person stopped the run during: Getting the bare ground". The project stays a blind test with its area still guarded. The overview offers "Next: Get the ground", and RESEARCH.md lists fetching the ground as still to do.
- **Pictures:** Home was retaken at 1440 × 900 in Earth to show the test card (with launch overrides, so no test projects showed). Chris's settings were restored after each check (11 projects, Earth).
- **Docs:** concept.md has a "Testing the method" section, ROADMAP.md puts finding small mounds first, and HANDOFF.md says loop 6 is finished.
- **T4's third place, through the agent after the faster fetch:** Shawnee State Forest with primary / 6.1 Terra (memories off). quick_look returned USGS 3DEP at 1.8 ground returns per sq m, with nothing on record. The agent read broad ridges and branching hollows as natural, the narrow lines as likely tracks, named the four lists it checked, and called nothing new. The run took 18 s with the fetch cached; the fetch itself took 146 s uncached. Rantoul was also run in the app and ended in the card.
- **Loop 6 is finished.** T1 to T8 are logged above and merged (PRs #41 to #44). Two things remain for Chris:
  - macOS still asks once for the Documents folder; with the stable signature, one Allow should last.
  - The small-mound gap is the first item on the roadmap.
