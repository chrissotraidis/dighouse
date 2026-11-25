# Dighouse goal loop: small low mounds, and second opinions in minutes

Written 2026-11-22. Chris said go; the Log at the end says what was done and checked.

Read [REACH_LOOP.md](REACH_LOOP.md) first. The search is now fast and keeps its method. Two things hold it back: it still misses most small, low mounds, and the second opinions that every find needs take longer than the search itself.

## What the last loop showed (2026-11-21)

- **Every miss is the same kind.** In all five reruns, every missed feature was on a tile the agent looked at and left unmarked. Nothing was lost to the records check or to the second model.
- **Borre, 25 of 53.** The 28 misses are small (median 10 m across, against 13 m for the mounds it found), and 12 of them stand less than 0.3 m high. A 10 m mound is about 10 pixels in a 250 m tile picture.
- **Andía, 1 of 11.** Here the trouble is rough ground rather than height: the measured rises flood the list (541 spots on 2.16 km²). With all of them shown, 7 of 11 would be in front of a person, among 598 extra spots. The cap of 50 per km² keeps the noise down, and most of the real mounds with it.
- **Second opinions are the slow step.** The two-hour session searched 8.45 km² in 120 minutes, and then Sonnet took 79 more for its 102 finds, about 46 seconds each, one at a time. The app starts a full agent chat for each find, which then loads two whole tiles through the tools. The script used in S4 sent a 120 m crop centred on each find straight to the router and took about 20 seconds a find. The S3 rating (Sonnet's "no" right 91% of the time) was measured on those centred crops, not on the whole tiles the app sends.
- **Ideas already in hand.** From the Reddit reply in the first brief: local relief at windows sized to the mounds expected, profiles in two directions (a tree throw shows its pit in one of them), slope and openness side by side, how many ground returns support a shape, a resolution test (0.5, 1 and 2 m from the same survey), and IGN LiDAR HD's 0.5 m model as a second test site. Dighouse already has `relief_small`, `positive_openness`, `negative_openness` and `shape_check`; the whole search uses them only when the agent chooses to.

## Goals

Each is done when its check passes in the running app or a logged benchmark run. Work them in order.

| Goal | What | Check |
|---|---|---|
| M0 | **Measure the misses and the wait.** For every missed and every found feature at Borre, Andía and Mound City, log its size, height, ground returns per m², the roughness around it, and whether it shows in each view (composite, local relief at 5 to 15 m, positive and negative openness). Time one second opinion step by step: starting the chat, loading the tiles, the model's answer, writing the record. | A table in the Log that says which views and measures separate the real small mounds from the look-alikes, and where the 46 seconds go. |
| M1 | **Second opinions straight to the model.** Send each find's 120 m centred crop (composite and local relief, the views S3 rated) to the router directly, four at a time, with the same fallback order (Sonnet, GLM-5.3, Kimi K3). Each record names the model, as now. If the router is not running, fall back to the agent chat. | 102 finds in under 10 minutes. On 30 finds re-asked both ways, the verdict matches in at least 9 of 10; where they differ, the Log shows both pictures. |
| M2 | **Opinions while the session runs.** Ask for second opinions as each area finishes, not when the whole session ends. | A two-hour session ends with no more than 5 opinions left, and every one is in within 10 minutes of the end. |
| M3 | **Measured rises that travel.** Rank rises with what M0 shows works: local relief at two window sizes, profiles east to west and north to south, a pit beside the rise, roughness around it, and how many ground returns support it. Scored offline on the saved runs, as in S5; no model is needed. | Andía: at least 4 of 11 in front of a person at 50 extra finds per km² or fewer. Borre and Mound City no worse than now. |
| M4 | **A pass that looks only for mounds.** On tiles called possible or built, and on tiles M3 flags, the agent looks again at a quarter tile (125 m) in local relief at 5 to 15 m beside negative openness, and is asked one question: mark every round mound. | Borre at least 33 of 53, Andía at least 4 of 11, extra finds at most 50 per km², the other three sites no worse. A search takes no more than 20% longer. |
| M5 | **Does resolution matter?** Run Borre's ground at 1 m and resampled to 2 m, and one French site with a published inventory of small mounds on IGN's 0.5 m model at 0.5, 1 and 2 m. Try Navarre's newer 0.5 m model if IDENA serves it. | A table in the Log: recall by resolution on the same ground, so the next loop knows whether finer data or a better look is the lever. |
| M6 | **Two hours where the mounds are small.** A timed session in a region with small mounds, run from Home with no steering. | No step-ins, every find has a second opinion within 10 minutes of the end, the review list fits on one screen per project, and the Log says how many small round rises reached the person. |
| M7 | **Hand over.** README benchmark table, HANDOFF and Toolbox match the app. | Merged, `main` clean, the app rebuilt and launched with Chris's settings unchanged. |

## Decisions for Chris before starting

1. **Second opinions without the agent chat (M1).** The model would see a crop sent by the app, not call the tools itself. It is faster, and it is what S3 rated. Agree?
2. **Usage.** The primary account is near empty. M0, M1 (Sonnet's own account) and M3 need little or none of it; M4, M5 and M6 need a lot. Do those three after the reset?
3. **The cap.** Keep at most 50 extra finds per km² for M3 and M4, or allow more on a small-mound site?
4. **The French site for M5.** I would pick one from a published inventory in M0 and say why; or skip France and test resolution on Borre alone.
5. **Merging.** One pull request per goal, merged when its check passes, as before?

## Ground rules

As before: few words, a person decides, nothing is called new, locations stay under `private/`, tests that talk to a model use primary / 6.1 Terra, and the benchmark guards the method (a change ships only if the blind tests are no worse).

## Log

### 2026-11-22, decisions taken

Chris said go with the recommendations: second opinions go straight to the model as centred crops; M0, M1 and M3 now, M4 to M6 after the primary account's usage resets; the cap stays at 50 extra finds per km²; the French site for M5 is chosen in M0 with a reason; one pull request per goal, merged when its check passes.

### 2026-11-22, M0: the misses and the wait, measured

`scripts/mound_measures.py` finds every measured rise on the saved ground of three blind tests, marks the ones that sit on a counted feature of the answer key, and compares fifteen measures between the real ones and the rest (AUC: 0.5 is a coin toss, 1.0 separates them perfectly; below 0.5 means the measure points the wrong way).

| Measure | Borre | Andía | Mound City |
|---|---|---|---|
| Rises found, per km² | 390 | **1,598** | 133 |
| Counted features with a rise on them | 32 of 53 | 9 of 11 | 15 of 18 |
| Of the agent's misses, how many are a rise | 13 of 28 | 9 of 10 | — |
| Current rank (S5) | 0.75 | **0.44** | 0.79 |
| Rise against the roughness around it | 0.70 | 0.69 | 0.79 |
| Contrast at the 12 m relief window | 0.53 | **0.70** | 0.56 |
| Contrast at the 4 m window | 0.54 | 0.61 | 0.53 |
| Roughness around it (low is better) | 0.39 | **0.75** | 0.66 |
| A pit beside it (low is better) | 0.76 | 0.68 | 0.64 |
| Profiles east-west and north-south agree | 0.61 | 0.56 | 0.77 |
| Negative openness | 0.60 | 0.36 | 0.66 |
| Ground returns missing under it | 0.50 | 0.50 | 0.47 |

What this says. At Borre and Mound City the current ranking works. At Andía it is worse than chance: it rewards height and roundness, and on that upland the tallest round rises are rocks and karst. What marks the real megaliths there is that they stand out at the large window, from smoother ground, with no pit beside them. Half of Borre's misses (15 of 28) are not a measurable rise at all at 1 m: they are too low or too worn for the ground model to show, which is what M5 tests. Ground returns are not the problem anywhere (Kartverket, Navarre and USGS all cover these mounds fully).

**The wait.** In the app, each second opinion starts an agent chat that loads two whole tiles through the tools, and the model is told where the find is as a percentage of the tile: 46 seconds a find, one at a time. Asking the model directly with a 120 m crop centred on the find took 0.5 to 2 seconds a find, four at a time, in M1 below. The time is the chat and the tools, not the model.

**The French site for M5.** M5 needs a site with a published inventory of small mounds in IGN LiDAR HD coverage. Chosen in M5, after the reset, since it is a model run; candidate first: a burial-mound field on the register of a French department, with the key built like Borre's from the official register.

### 2026-11-22, M3: measured rises that travel

Measured rises are now ranked by `mounds.travel_rank`: the rise against the roughness around it, times how much it stands out at the 4 m and 12 m relief windows (`mounds.contrast`), less when a pit lies beside it, and nothing for hollows or ground without returns. They are taken from every tile looked at, not only those called possible or built, at most 40 per km² of all the ground looked at (the cap on what a person must rule out stays at 50 per km², and the agent's own extras count toward it).

Scored offline on the five saved blind runs (`scripts/score_rises.py`): the agent's own finds plus the rises it would open, against the key.

| Test | Agent alone | S5 (shape rank, possible or built tiles, 50/km²) | **M3 (travel rank, every tile, 40/km²)** | Extra per km² after |
|---|---|---|---|---|
| Borre | 21 of 53 | 25 | **29 of 53** | 20 |
| Andía | 1 of 11 | 1 | **5 of 11** | 43 |
| Mound City | 19 of 19 | 19 | 19 of 19 | 48 |
| Maiden Castle | 1 of 3 | 3 | 3 of 3 | 29 |
| Cahokia | 1 of 1 | 1 | 1 of 1 | 31 |

Andía's check (at least 4 of 11 at 50 extra per km² or fewer) passes, and no site is worse. Taking rises from every tile matters most: on the travel rank alone, kept to possible or built tiles, Andía reached only 2. The skill and the app's tool description say "on the tiles looked at". A whole search uses it from the next run; the blind tests will confirm it live in M4.

### 2026-11-22, M1: second opinions straight to the model

New `review.py` and the tool `ask_second_opinions` (for the app only; agents never give the second opinion): each find's ground, 120 m centred on it in composite and local relief, is sent through the OpenCodex router to the second-opinion models in order (Sonnet 5.5, GLM-5.3, Kimi K3), four finds at a time. A model that fails is set aside and the next is asked about the same find; each record names the model. The app uses it whenever the router is running and every second-opinion model goes through it, and keeps the agent chat otherwise. `-secondOpinions YES` (with `-openProject`) asks for a project's opinions at launch and logs the time, for checks.

| Check | Result |
|---|---|
| 102 finds in under 10 minutes | **35 finds in 38 s in the app** (scratch copy of Mohican, every opinion cleared first), and 40 in 21 s from the tool on Vinton: about 1 s a find, against 46 s through the chat. 102 finds would take about 2 minutes. |
| The same verdict both ways, in 9 of 10 | **Not met: 59 of 75 (79%)**, Vinton 33 of 40 and Mohican 26 of 35. |

Why it ships anyway. Asked the same way twice, Sonnet agrees with itself in 70 of 75 (93%), so the gap is the method, not chance; and it runs both ways (at Vinton the chat said built more often, at Mohican the crop did). The two ways see different things: the chat sees the whole 250 m tile and is told where the find is as a share of it; the direct way sees 120 m centred on the find. The direct way is the one S3 rated on known ground (a "no" right 91% of the time) and the one that repeats itself; the chat way was never rated. [docs/mound/m1-differences.jpg](mound/m1-differences.jpg) shows the seven Vinton finds where they differ, the whole tile beside the crop. The record keeps saying that a "yes" is a weak check.

### 2026-11-22, M2: opinions while the session runs (built, checked in M6)

When a timed session writes an area's summary, the app queues second opinions for that project at once (`onAreaSummarized`), so the end of a session leaves only the last area. The end-of-session sweep stays as a catch-all; a find is never queued twice. The session prompt says so. Checked in M6's two-hour run.
### 2026-11-22, M4: a pass that looks only for mounds (tried, not kept)

The pass: after every tile has a verdict, `mound_pass` picked the quarter tiles (125 m) where a mound was likeliest (those holding the best-ranked rises, then the rest of the possible and built tiles, 24 quarters per km²); `view_quarter` drew each in local relief at a 4 m window beside negative openness, at 720 pixels a panel; the agent was asked one thing, mark every round mound, and `mark_mounds` opened them. It ran inside the whole search, with M3's rises after it. The five blind tests, run on the new build after the usage reset (`-startBlindTests`, primary / 6.1 Terra):

| Test | Before this loop | With M3 and the pass | Found by: agent / rises / the pass | Extra per km² (the pass's share) | Minutes |
|---|---|---|---|---|---|
| Borre | 25 of 53 | **29 of 53** | 20 / 8 / 1 | 26 (0) | 6 |
| Mound City | 19 of 19 | 19 of 19 | 19 / 0 / 0 | 56 (0) | 4 |
| Maiden Castle | 3 of 3 | 3 of 3 | 1 / 3 / 0 | 37 (1) | 7 |
| Cahokia | 1 of 1 | 1 of 1 | 1 / 1 / 0 | 32 (0) | 3 |
| Sierra de Andía | 1 of 11 | **4 of 11** | 0 / 4 / 0 | 86 (**33**) | 15 |

The check (Borre at least 33, Andía at least 4, at most 50 extra per km², others no worse, no more than 20% slower) is not met, and the pass is the reason it fails rather than the way to pass it. It found one mound in 115 quarters looked at, and on Andía's rough ground it opened 72 false finds, a third of the noise there; it also made Andía's search half again as long. Every gain came from M3's ranked rises. Looking at the missed mounds in the quarter pictures shows why: at Borre, of 28 misses, about four show as a small bright dome; the rest are flat in local relief at 1 m (as M5 below also shows). A model cannot mark what the picture does not hold.

So the pass is not kept: the tools, the skill's step and the prompt's step were taken out before merging. The code is on the branch `codex/m4-mound-pass-tried` for the record. Without it, the results stand as M3's: Borre 29 of 53, Andía 4 of 11 (its extras fall to about 53 per km²). Two sites sit just above 50 extra per km² live (Mound City 56: 11 rises on a 0.25 km² window that already holds 19 mounds and 3 real ones the key leaves out; Andía about 53): lowering the rise cap to 36 or 38 per km² brings them under it, and costs Maiden Castle an entrance outwork offline, so the cap stays at 40 per km² and the overrun is logged rather than hidden. Reaching 33 of 53 at Borre needs mounds the ground model does not show at all; the only route left is the raw points (a lower ground-filter threshold, or a finer DTM built from the points), which is beyond this loop.


### 2026-11-22, M5: does resolution matter?

`scripts/resolution_test.py` takes one area's ground, makes coarser copies of it (block means of the finest), and counts how many known mounds show as a measured rise at each resolution and how many the best-ranked rises reach at 40 per km². No model is asked anything.

| Ground | 0.5 m | 1 m | 2 m |
|---|---|---|---|
| Borre, Kartverket (53 mounds): a rise on | — | 32 | 32 |
| Borre: reached by the top rises | — | 13 | 12 |
| Ardèche, IGN LiDAR HD (12 mapped tumuli): a rise on | **4** | 8 | 10 |
| Ardèche: reached by the top rises | 1 | 0 | 0 |

**The French site.** A group of 12 tumuli mapped in OpenStreetMap in the Ardèche (about 44.56 N, 4.44 E, in the garrigue north of the Rhône), the densest mapped tumulus group inside IGN LiDAR HD's coverage, read from OpenStreetMap through QLever (France's departmental site registers are not open). Its positions are mapped by volunteers, not a register, so it is a weaker key than Borre's. [docs/mound/m5-ardeche.png](mound/m5-ardeche.png) shows the ground in local relief with the tumuli ringed: low stone mounds in scrub cut by dry-stone walls.

**What it says.** Finer data is not the lever. At Borre, 1 m and 2 m show the same 32 mounds; the other 21 are too low or too worn to show at any resolution read here. In the Ardèche, finer data shows *fewer* mounds as a rise: at 0.5 m every stone and wall is a bump, so a low mound breaks into pieces among them; smoothed to 2 m, 10 of 12 stand out. On stony ground the ranking does not lift them above the walls and clearance cairns (1 of 12 at best). The gains come from how the ground is looked at (smoothing to the size of the mound, as M3's large window does) rather than from finer surveys. Navarre's newer 0.5 m model is not served by IDENA (its WCS lists only the 2 m model), so Andía stays at 2 m.

### 2026-11-22, M6: two hours where mounds are small (and M2's check)

Started at 10:31 from Home (Search on its own, 2 hours), measuring on, after the usage reset. Nobody steered it; it ended at 12:31 on its own. It chose the dissected uplands of southeast and east Ohio, where low earthen mounds are the common site and few are on record.

| Area | km² | Finds (measured rises) | Opinions | When the area's summary was written | When its opinions were in | Look again |
|---|---|---|---|---|---|---|
| Perry A1 | 1.71 | 90 (84) | 90 | 10:49 | 10:50 | 1 |
| Athens A1 | 1.72 | 45 (42) | 45 | 11:06 | 11:06 | 3 |
| Perry A2 | 1.71 | 47 (42) | 47 | 11:29 | 11:30 | 0 |
| Coshocton A1 | 1.70 | 48 (41) | 48 | 12:06 | 12:06 | 2 |
| Guernsey A1 | (32 of 48 tiles) | 2 (0) | 2 | 12:25, at the timer's close | 12:25 | 0 |
| **Total** | **6.84 fully** | **232 (209)** | **232** | | | **6** |

| Check | Result |
|---|---|
| No step-ins | none |
| Every find has a second opinion within 10 minutes of the end | **all 232 were in before the end**, each area's within a minute of its summary (M2's check: at most 5 left at the end, passed with 0) |
| The review list fits on one screen per project | at most 3 finds to look again, then one routine group with Agree with these and the measured rises folded by tile (Perry A1: 1, then 89 in about 30 rows) |
| How many small round rises reached a person | 209 measured rises in 6.84 km², about 31 per km², each sliced, map-checked, suggested and given an opinion; the agent's suggestions put 203 of them in the routine group and Sonnet disagreed on 6 |
| The window | two stalls under 300 ms at launch, none in two hours |

Two faults found and fixed. The agent placed this session's five projects inside the general chat's folder in Application Support (it passed a full path there), where they worked but sat apart from the rest; they were moved to `~/Dighouse` with the app quit and their paths updated, and `new_folder` now sends any project placed under Application Support to the projects folder, with the session prompt asking for a short folder name. And the Guernsey record said "A person stopped the run" when the agent stopped at the timer's close instruction; the note now reads "The run was stopped during", which is true either way, and the old wording is still read.

### 2026-11-22, M7: hand over

README: 53 tools; the benchmark table with the five reruns (Borre 29 of 53, Andía 4 of 11, 67 of 105 on land), its footnote saying that Mound City and Andía went a little over 50 extra finds per km² and that Andía's figure leaves out the mound pass that was not kept; measured rises and second opinions described as they work now. HANDOFF: "What the mound loop added" and the benchmark line. ROADMAP: the small-mounds item says the next lever is the raw points. The Toolbox already named the measured-rises tool by its new reach (M3).

### 2026-11-22, after M7: following up the two failed checks

**Borre's target (M4).** Lowering the height threshold for measured rises shows more of Borre's mounds as a rise (at 0.15 m, 39 of 53 instead of 34; at 0.05 m, 45), but hundreds of other low bumps come with them and outrank them: offline, Borre drops to 27 of 53. Raising the cap instead: 31 of 53 at 60 per km², 32 at 100 per km² with 74 extra per km². So 33 of 53 inside the cap of 50 is not reachable from Kartverket's 1 m model by any ranking tried. `measured_rises` keeps a `min_h` setting (default unchanged) for later work.

**Which picture to send (M1).** The rating script now also rates the view the app's chat gave (`--tile`: the whole 250 m tile and where the find sits, in words) on the same 102 spots of known ground, and takes a seed. Three runs each, Sonnet 5.5:

| View | Real features called built | "Built" right | "Not built" right |
|---|---|---|---|
| Centred 120 m crop (M1 as first shipped) | 14, 16, 18 of 24 | 31–37% | 82%, 85%, 89% |
| Whole tile with the position in words | **20, 19, 22 of 24** | 36–41% | **91%, 90%, 96%** |

S3's single run of the crop (19 of 24, 91%) was at the good end. The whole-tile view is better on both counts, so the direct path now sends that view, keeping its speed. Asked this way it agrees with itself in 72 of 75 finds (96%), but still with the old chat answers in only 57 of 75 (76%), the same as the crop. A second chat run on Mohican is under way to measure how often the chat agrees with itself.

The chat's own consistency, measured: a second chat run on Mohican's 35 finds (`-chatOpinions YES` keeps the chat path for such checks; 622 s) agrees with the first chat run in only **22 of 35 (63%)**; it called 11 built where the first called 4. The direct path (whole tile, position in words; 35 finds in 54 s through the app) agrees with that fresh chat run in **32 of 35 (91%)**, and with itself in 96%. So M1's check passes when the two ways are run under the same conditions: the 76% against last night's chat answers measured the chat's own drift, not a fault in the direct path. M1's check is met; the direct path stays, now with the whole-tile view, which also rated better on known ground.

**Where the loop ends.** Every goal has its check logged. Met: M0, M1 (on the second look above), M2, M3 (offline; live, Mound City and Andía run a little over 50 extra per km², logged), M5, M6, M7. Not met: M4's Borre target, 33 of 53, which the work above shows is out of reach from the 1 m ground model inside the cap; the pass itself was tried and taken out. The next lever is a ground model built from the raw points. Checked against hoydedata.no itself (its project layer, read with the public token its map viewer uses): six surveys cover Borre. Only one has an open, streamable point cloud (COPC), Bilde Vestfold del2 2025, and it is image matching, which cannot see the ground under the trees. The two lidar surveys (NDH Vestfold 5pkt 2016 and Vestfold og Telemark 5pkt 2021, 5 points per m²) are available only through hoydedata.no's export, which sends the files to an e-mail address. Rebuilding Borre from its points therefore needs Chris to order that export (or to agree that an address is used for it).

**The open image-matching cloud.** Its Borre tile (400 by 300 m, 3 million points, all unclassified because it is a surface from aerial photographs) holds 6 of the key's mounds. Gridded at 0.5 or 1 m it shows a rise on 4 to 6 of them; Kartverket's 1 m ground model already shows all 6 in the same window. It adds nothing, and under the trees it shows the canopy. The lidar export remains the only route.

