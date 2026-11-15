# Dighouse goal loop 6: prove it works, and make it easy to try

Last updated: 2026-11-15

Read [HANDOFF.md](HANDOFF.md) first, then the end of [REFINE_LOOP.md](REFINE_LOOP.md). Loops 1 to 5 built the app, the tools, the look and the research record. This loop answers the question an archaeologist asks first: how often does it find what is really there, and how often does it mark things that are not? It does that with **blind tests on known sites**, scored against published answers. The same tests become the easiest way for a newcomer to try Dighouse, from Home.

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

