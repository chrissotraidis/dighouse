# Dighouse goal loop: second opinions that work, and finding more

Written 2026-11-21. Chris said begin; the Log at the end says what was done and checked.

Read [RELEASE_LOOP.md](RELEASE_LOOP.md) and [2026-11-21-five-hour-run.md](2026-11-21-five-hour-run.md) first. The app now holds up for a stranger. The run showed where the work is now: no find has ever had a second opinion, the agent leaves most small mounds on tiles it calls "possible", and its 17 open leads are mostly hollows and cuts that old maps could explain.

## What was checked before writing this (2026-11-21)

- OCX 2.100.4 no longer lists `google-antigravity`, but Dighouse still has `google-antigravity/gemini-3.8-flash` saved as the second model, and OCX still lists one Google model through another route (`command-code/google-gemini-3.8-flash`). The Toolbox's worked example still names "Gemini 3.8 Flash".
- Asked live with a Borre tile, through OCX, in one short request each:

| Model | Answered | Read the hillshade correctly |
|---|---|---|
| anthropic/claude-sonnet-5-5 | Yes | Yes ("burial barrows or tumuli"); in sky view it said "bomb craters" |
| opencode-go-secondary/glm-5.3 | Yes | Yes |
| opencode-go/kimi-k3 | Yes | Yes |
| xai/grok-4.7 | No: "Grok Build usage balance exhausted" | — |
| kimi/k3 | No: OAuth sign-in failed | — |

- The second opinion is sent the tile in composite and local relief, not sky view, which suits all three that worked.

## Goals

Each is done when its check passes in the running app or in a logged benchmark run. Work them in order.

| Goal | What | Check |
|---|---|---|
| S1 | **Remove Google models.** Hide any model whose id or provider mentions google, gemini or antigravity from every model list (chat, Settings, set-up, second opinion), wherever OCX lists it. If a saved model (main or second) is one of them, or is no longer listed, replace it with a working default and say so once. Rewrite the Toolbox example and HANDOFF notes that name Gemini. | No Google model appears anywhere in the app; a settings file holding the old Antigravity id opens with a working second model and a one-line note. |
| S2 | **A second opinion that works.** Default to Claude Sonnet 5.5, a different maker from the GPT models that do the search. If the provider refuses or is out of credit, try GLM-5.3 and then Kimi K3 (opencode-go) by itself, and record which model answered. Settings shows each second-opinion model with a "Check" that sends one tile and shows the reply. | A refused model falls through to the next on its own. "Check" works for all three. Each record names the model that gave its opinion. |
| S3 | **Is the second opinion any good?** A blind check of the reviewer itself: give it the finds from the Borre, Mound City and Maiden Castle tests (true mounds, misses, and false finds, which the scorecard already knows) and score how often it agrees with the truth. Do the same for Sonnet and GLM. | A table in the Log: agreement on real features and on false finds for each model. The default stays only if it beats a coin toss clearly on both; otherwise the second opinion is labelled advisory in the app. |
| S4 | **Second opinions on the work already done.** Run them on the 42 ground-search finds and the open Cahokia finds. | Every open find has an opinion or a recorded reason it could not get one. The Log says where the reviewer disagreed with the agent's suggestion. |
| S5 | **Mark the mounds the agent leaves on "possible" tiles.** On every tile called possible or built, list the top measured rises ranked by `shape_check` (not height) as finds for review, capped per sq km, marked "measured, not seen" so a person knows where they came from. They go through slice, maps and suggestion like any find. | Borre twice, Mound City, Maiden Castle and one Thunder Bay wreck test rerun. Kept only if recall rises and false finds per sq km stay under the cap Chris sets (see below). On last week's numbers Borre should go from 21 toward 33 of 53, with about 26 more rises to look at. |
| S6 | **Clear the hollows with old maps.** For finds that are hollows, cuts or straight traces, check open historical and mining records before suggesting: USGS historical topographic maps (ponds, quarries, buildings, roads at the time), the USGS mineral resources record (mines and prospects), and open water features on OpenStreetMap. Cite what was found on the record. | Run on the 17 leads. The Log says how many were explained by a cited map or record, and how many are still leads. Nothing is filtered silently: an explained find keeps its record with the reason. |
| S7 | **A session that searches without a coordinator.** Run a 2-hour timed session with no steering. | It searches at least 3 sq km (the second session reached 9.4 km² in about 3 hours once steered), its finds all carry second opinions, and an early close is turned back once. Any further step-ins are logged with the reason. |
| S8 | **Hand over.** Records show finds grouped as before, now with second opinions and map checks. README, HANDOFF and the Toolbox example match the app. | Merged, `main` clean, the app rebuilt and launched with Chris's settings unchanged apart from the replaced second model. |

## Decisions for Chris before starting

1. **Default second opinion:** Claude Sonnet 5.5 (most reliable, Anthropic usage), or GLM-5.3 (opencode-go, cheaper) with Sonnet as the fallback?
2. **Cap on extra rises in S5:** how many more small rises per sq km will you look over? 50 per km² adds about 14 at Borre and finds about 26 of 53; 100 per km² adds about 26 and finds about 33.
3. **Usage:** the primary account showed 20% left at the end of the run. S3, S4, S5 and S7 all spend it. Run them now, or wait for the reset?
4. **Merging:** one pull request per goal, merged when its check passes, as in the last loop?

## Ground rules

As in RELEASE_LOOP: few words, a person decides, nothing is called new, locations stay under `private/`, tests that talk to a model use primary / 6.1 Terra, and the benchmark guards the method (a change to finding ships only if the blind tests are no worse).



## Log

### 2026-11-21, decisions taken

Chris said to begin without answering the four questions, so the recommended choices were taken: Claude Sonnet 5.5 first, then GLM-5.3, then Kimi K3; at most 50 extra measured rises per sq km in S5; run now on the remaining usage; one pull request per goal, merged when its check passes.

### 2026-11-21, S1 and S2: no Google models, a second opinion that falls through

Any model whose id contains google, gemini or antigravity is dropped as the model list loads, so it appears nowhere (Settings showed 91 models, down from 94). After the list loads, a saved agent or second model that is no longer offered is replaced: on Chris's settings `google-antigravity/gemini-3.8-flash` became Claude Sonnet 5.5, with a one-line notice in Settings until he picks a model. The Toolbox example and HANDOFF no longer name Gemini.

Settings, Models now lists the second-opinion models in the order they are asked, each with Check, which sends a Borre picture in a throwaway chat. All three answered correctly in the app: Sonnet ("round burial mounds, some with ditches"), GLM-5.3 ("a cluster of prehistoric round burial mounds") and Kimi K3 ("the royal Viking Age barrows of Borre"). When a second-opinion model fails or answers without an opinion, it is set aside for this run and the next model is asked about the same find. Checked by choosing xAI Grok 4.7 (out of credit) and asking on Cahokia C-009: Grok was refused, Sonnet answered, and the record says "Cl · Sonnet 5.5: … looks built by people, though the surrounding road-and-parcel grid means a modern structure should be ruled out." Sonnet was put back as the second model.



### 2026-11-21, S3: are the second opinions any good?

`scripts/rate_reviewers.py` takes ground whose truth the blind tests know (Mound City, Borre, Angel Mounds, Cahokia): published features from the answer keys, measured rises the keys do not list, and plain ground away from both. It renders a 120 m crop in composite and local relief (the views the app sends) and asks each model through the router whether the thing at the centre was built. 102 crops:

| Model | Answered | Published features called built | Look-alike rises called not built | Plain ground called not built | When it says built, right | When it says not built, right |
|---|---|---|---|---|---|---|
| Claude Sonnet 5.5 | 102/102 | 19/24 | 24/38 | 26/40 | 40% | **91%** |
| GLM-5.3 | 102/102 | 6/24 | 34/38 | 37/40 | 46% | 80% |
| Kimi K3 | 88/102 (14 timed out) | 15/24 | 22/35 | 23/29 | 44% | 83% |

Sonnet stays the default: it finds most real features and is the most trustworthy when it says no. GLM almost never says yes, so it misses three real features in four. No model's "yes" is worth much: all three call plenty of plain and modern ground built (at Mound City and Cahokia the "plain" crops include roads and houses, which are built, just not ancient, so the true rate is a little better than this). The app now says so on each record: a disagreeing second opinion "counts", an agreeing one is "a weak check". The second opinion is useful as a filter, not as a confirmation.



### 2026-11-21, S4 (part): Cahokia

The seven open Cahokia finds got second opinions from the app's Get a second opinion, all from Claude Sonnet 5.5. The twelve published mounds were already decided.

### 2026-11-21, S5: mark the mounds left on possible tiles

`add_measured_rises` opens a find for each of the best measured rises on tiles called possible or built, ranked by `shape_check` (hollows rank last), at most 50 per sq km of those tiles, never within 10 m of an existing find, each marked "measured, not seen". The whole-search workflow and the skill call it once after every tile has a verdict. Scored on the five blind tests on this Mac by adding its rises to the agent's finds:

| Test | Agent alone | With rises (cap 50/km²) | Extra finds per km² after |
|---|---|---|---|
| Borre, run 11-21 #2 | 20/53, 0 extra | **24/53**, 9 extra | 24 |
| Borre, run 11-21 #3 | 21/53, 0 extra | **25/53**, 9 extra | 24 |
| Mound City | 19/19, 3 extra | 19/19, 9 extra | 36 |
| Maiden Castle | 1/3, 2 extra | **3/3**, 31 extra | 35 |
| Cahokia | 1/1, 4 extra | 1/1, 6 extra | 24 |

Recall rose on both sites with misses and false finds stayed under the cap of 50 per km², so it is kept. At 100 per km² Borre reaches 28/53 with 17–18 extra. Seafloor projects are skipped, so the Thunder Bay wreck test is unchanged by design. Limit: this is scored offline on saved runs, not a fresh agent run; S7's session uses it live.



### 2026-11-21, S4: second opinions on the ground-search finds

`scripts/second_opinions.py` gives every open find in the given projects a second opinion the way the app does (Sonnet, then GLM-5.3, then Kimi K3; the 120 m composite and local relief crops rated in S3; written through `second_look`, so each record names the model). Run on the nine ground-search projects: all 42 finds answered by Claude Sonnet 5.5, none needed a fallback.

| Agent's suggestion | Sonnet: built | Sonnet: not built |
|---|---|---|
| Modern (17) | 11 | 6 |
| Natural (8) | 0 | 8 |
| No match in the sources read (17) | **6** | **11** |

Sonnet agreed with every "natural" call. Of the 17 open leads it called 11 not built (natural hollows, gullies, a lidar artefact); since its "no" was right nine times in ten on known ground, those 11 drop to low priority. The 6 it called built are all straight-edged or rectangular (Darby Prairie C-001 and C-008, Lusk Creek C-003 and C-005, Shawnee Woodland Larger C-003 and C-008): regular geometry, which fits a modern pond, foundation or field work as well as anything older. Those six are what S6 checks against old maps. With the Cahokia seven, every open find in the session's projects has a second opinion.



### 2026-11-21, S6: clear the hollows with old maps

`check_old_maps` (new `history.py`) shows a find on the USGS historical topographic sheets that cover it (the oldest 1:24,000 sheet and the oldest of any scale, 200 m each way, the find ringed in red; sheets cached once in Application Support) and lists mines and prospects from the USGS Mineral Resources Data System within 300 m. `record_old_maps` files what they show, and the record gets an Old maps row. The skill and the whole search call it on every hollow, cut or straight-edged find in the United States. A test point in the fluorspar district came back with "Prospect" and a mine symbol drawn beside it on the 1959 Karbers Ridge sheet, which is the kind of thing the 17 leads needed.

Run on all 17 leads (sheets from 1923 to 1961; read by eye):

| Result | Finds |
|---|---|
| Explained: a building drawn on the spot (Galloway, OH 1955) | Darby Prairie C-001 |
| Explained: a straight cut along a section line (Eddyville, IL 1961) | Lusk Creek C-005 |
| Something nearby, not at the find: a farmstead about 70 m away; disturbed ground or a pit about 50 m away | Lusk Creek C-003, Darby Prairie C-002 |
| Nothing drawn, no mine on record within 300 m | 13 others |

The two explained finds now suggest "modern", citing the sheet. No mine or prospect is on record within 300 m of any lead, so prospect pits, the obvious guess in the Shawnee hills, are not supported by the records (small pits often went unrecorded). After S4 and S6, the leads that still stand are the four that Sonnet called built and old maps do not explain: **Darby Prairie C-008, Lusk Creek C-003, Shawnee Woodland Larger C-003 and C-008**. They are straight-edged hollows and banks, and the record says what to check next (the Illinois and Ohio state site files, which are not public).


### 2026-11-21, S7: a two-hour session without a coordinator

Started at 11:27 with `open Dighouse.app --args -startTimedResearch 120` (the new launch argument), deadline 13:27, primary / 6.1 Terra. Nobody typed into it.

What it did:

| Time | Work |
|---|---|
| 11:28–12:03 | Finished the 5 tiles left at Lusk Creek East, then went back over the earlier ground-search projects with the new tools: 109 measured rises opened as finds there, and old maps checked on their hollows and cuts. |
| 12:03–12:31 | Prairie Oaks, Ohio: 1.46 km², 6 finds marked by eye, 25 measured rises, old maps on all 6. A park page named a recorded mound in the window, which the agent took as a control. |
| 12:31–12:45 | Tried to place that mound from public sources, could not, and called the goal **blocked**, 40 minutes before closing time. |
| 12:55 | Step-in (see below); the app turned the session back once. |
| 12:55–13:09 | Paint Creek, Ohio: 1.48 km², 8 finds marked by eye, 25 measured rises, old maps on 22. |
| 13:09–13:21 | Zaleski, Ohio: 27 of 36 tiles looked at, no finds yet. Closed at the app's 13:17 prompt. |

| Check | Result |
|---|---|
| At least 3 km² searched | **3.2 km²** finished (Prairie Oaks, Paint Creek, the end of Lusk Creek East), plus about 1.1 km² of Zaleski looked at and not finished. Without the turn-back it would have been about 1.7 km². |
| Every find has a second opinion | **224 of 224** open finds in the projects it touched, all from Claude Sonnet 5.5, none refused. 191 were asked by the app on its own when the session ended; Paint Creek's 33 by `scripts/second_opinions.py` (step-in 2). |
| An early close turned back once | Yes, by the app, after the fix in step-in 1. |
| add_measured_rises and check_old_maps used | Both, on every project it touched: 165 measured rises in all. |

The agent's suggestions against Sonnet's opinions, on all 224 finds:

| Agent's suggestion | Sonnet: built | Sonnet: not built |
|---|---|---|
| Modern (79) | 63 | 16 |
| Natural (137) | 49 | 88 |
| No match in the sources read (8) | 4 | 4 |

None of the new finds became a lead: everything at Prairie Oaks and Paint Creek was suggested modern or natural. The four leads Sonnet calls built are the same four as after S6: Darby Prairie C-008, Lusk Creek Woodland C-003, Shawnee Woodland Larger C-003 and C-008.

Step-ins, with the reason:

1. **12:54, rebuilt and relaunched the app.** The early-close rule reopened a session only when the agent marked it complete; this agent marked it blocked (no provider error), so the app would have left it idle until 13:27. `TimedResearch.reopenIfEarly` now turns back a self-declared block the same way, once, and a relaunch checks a restored session for it. On relaunch it did: `reopened: true`, and the agent started Paint Creek.
2. **13:33, ran `scripts/second_opinions.py` on Paint Creek.** A project the agent makes was added to the project list only when its chat was on screen. After the relaunch Home was showing, so Paint Creek and Zaleski were never listed and the end-of-session second opinions skipped them. Projects made in any chat now join the list (`onProjectMade`).

Also fixed from watching it: every tool now has a plain name in the chat (`add_measured_rises` and others showed raw), and step names no longer take "1.46," or "C-003." for file names.

What this says: the session searched on its own and kept the method (calibration, measured rises, old maps, sources, a suggestion on every find), but it is slow on new ground: about 25 minutes per 1.5 km² window, after half an hour spent going back over earlier projects. It stops on a check it cannot finish unless the app turns it back.

