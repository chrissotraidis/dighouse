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

