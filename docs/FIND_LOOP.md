# Dighouse goal loop: find possibly unrecorded sites, for anyone who downloads it

Started 2026-11-23. The point of the app: a person downloads Dighouse, an agent searches large areas of open lidar on its own, and the person ends up with a short list of possible unrecorded sites, each checked against the open records, that they decide and report. Everything here is judged by that.

## Why this loop

The polish pass left an app whose screens are fast and consistent. What it does not yet do is reach an answer:

- **Few finds reach a person's decision, and none an answer.** Across Chris's 51 projects (blind tests left out), 63.1 km² were looked at and 744 finds made, 11.8 per km². 313 were put to a person, 18 were decided, and none reached "no match in the sources read" (`scripts/funnel.py`).
- **The ground searched was mostly where the records are closed.** 97 of 103 downloads were USGS or OpenTopography lidar in the United States, where state site files are not open, so no find there can be checked against the record.
- **The search is slow.** About 4 to 5 km² an hour, because an agent chat looks at every tile (five-hour run, 2026-11-21; second opinion loop).
- **A stranger cannot run it.** The build is signed for development only, the Codex command line and `uv` must be installed by hand, and second opinions from another maker need OpenCodex.
- **The screens are fast.** The measuring tour (`-measure YES -measureTour YES`): launch 3.5 s with the engine ready, every page under 50 ms, the longest chat opens in 0.4 s, no stalls. Speed work belongs in the search, not the interface.

## Decisions (made by the agent at Chris's request: "use your best judgment")

- **Work wherever lidar is open, and say what can be checked.** Three shades on the map and on every project: *can find and check* (open lidar and an open site register), *can find, not check* (open lidar, closed records), *no open lidar yet*.
- **First registers: Denmark and Norway, then England's open list.** Denmark's Fund og Fortidsminder includes sites that are not protected; Norway's register (Askeladden, published as open data) leaves out sensitive records; England's open list holds designated monuments only. A "no match" against any of them is still never called new.
- **Ready-made ground models for the wide search,** raw points only to slice a lead.
- **The search in three stages:** measure every km² on the Mac, sort tiles in bulk with a cheaper model through the model router, and let the agent look closely only at the shortlist. The blind tests decide whether it ships.
- **Fewer, honest finds:** rank before suggesting, call a hollow a hollow, one height, the ring drawn on the tile the second model sees.
- **Second opinions** use OpenCodex where it runs; otherwise a different model through the same ChatGPT sign-in, labelled as from the same maker; a key for another maker's model can be added in Settings.
- **Register locations are kept like find locations,** under `private/` or the cache, never in Markdown, commits or logs.

## Goals

| Goal | What | Done when |
|---|---|---|
| G0 | **Measure and check.** The funnel per project and overall; every ground source probed on about 1 km²; the registers probed; what stops a stranger. | Funnel numbers match the records by hand on 3 projects; a coverage table from the code; each register answers and its terms are written down; the stranger list is written. |
| G1 | **Fast and wide.** Ground models first (USGS's ready-made 1 m model too), measured on the Mac, tiles sorted in bulk, the agent on the shortlist; old downloads tidied. | At least 50 km² an hour on ready-made ground; blind-test recall no worse; a five-hour run under a set disk size. |
| G2 | **Checked against the records.** Register lookups for Denmark, Norway and England's open list; the three shades on projects and finds; registers as answer keys. | Each find names what it was checked against and when; Borre scored against Norway's register too; at least 10 new blind tests from registers. |
| G3 | **Fewer, honest finds.** | At most 15 finds per km² to a person; blind tests no worse and false flags per km² down. |
| G4 | **A download a stranger can use.** Signed and notarized if a Developer ID exists; setup inside the app; second opinions without OpenCodex. | From a fresh account, download to a running search with only a ChatGPT sign-in. |
| G5 | **One clear flow.** Find something, the coverage map, the agent proposing and running, a leads inbox across projects, decide, a report or a records request. | A new person reaches an agent-chosen search within 3 minutes of first launch without typing a place. |
| G6 | **Docs for people who download it.** | Someone new installs and runs it from the docs alone; every count in the docs matches the code. |
| G7 | **Prove it.** Unattended runs from a fresh install in three countries, at least one that can be checked. | Ten times the area an hour of G0, fewer finds per km² for a person, at least one lead taken through the register check to a decision. |

## Log

- **G0, measure and check** (2026-11-23).
  - **The funnel** (`src/dighouse/funnel.py`, `scripts/funnel.py`; read-only). Chris's 51 projects, blind tests left out: 71.4 km² fetched, 63.1 km² looked at, 744 finds (506 measured rises), 11.8 finds per km² looked at, 313 put to a person, 18 decided, 0 answered ("no match in the sources read" or reported). Checked by hand on three test projects: finds, measured rises and decisions match a count of the record files, "to a person" matches the app's "1 needs you" on Perry Mesa, and 1.52 km² matches its Data tab.
  - **Every ground source, about 1 km² each** (`scripts/coverage.py`: a box inside each outline, a full `fetch_terrain`, no coordinates printed). Seconds per km² for the fetch alone:

    | Source | Cell | s per km² | Note |
    |---|---|---|---|
    | New Zealand | 1 m | 3.9 | |
    | North Rhine-Westphalia | 1 m | 3.6 | dropped the connection once, answered on retry |
    | Saxony | 1 m | 4.3 | |
    | Flanders | 1 m | 5.6 | |
    | Estonia | 1 m | 5.6 | |
    | Norway | 1 m | 6.3 | 25 per km² on a 4 km² box |
    | Wales | 1 m | 6.9 | |
    | Canada (HRDEM) | 1 m | 7.6 | |
    | Czechia | 2 m | 15.6 | |
    | Shizuoka (Japan) | 0.5 m | 15.6 | failed before: newer sheets are "n,x,y,z,flag"; fixed |
    | Basque Country | 1 m | 17.8 | |
    | Bavaria | 1 m | 18.6 | |
    | Switzerland | 0.5 m | 21.8 | |
    | France (LiDAR HD) | 0.5 m | 23.4 | |
    | Netherlands | 0.5 m | 25.2 | 89% of the box covered |
    | Navarre | 2 m | 40.2 | |
    | England | 1 m | 59.8 | one request at a time |
    | Slovenia | 1 m | 88.9 | text sheets |
    | USGS 3DEP (raw points) | 0.5 m | 179 | the points, not a ground model |
    | Scotland | | | the box in the middle of its outline has no survey; coverage is patchy, not a failure |
    | Denmark | | | needs its free token |
    | Ireland (INFOMAR sonar) | | | 502 from the service; the live test that passed two hours earlier failed too |
    | NOAA sonar | | | survey strips; left to the live tests |

  - **The stages on 4 km² of Norway, without the agent** (`scripts/speed.py`): fetch 101.5 s, cut 81 tiles 4.1 s, draw two views 7.3 s, measure rises on every tile 77.9 s (about 1 s a tile, each drawing a picture): 47.3 s per km², 76 km² an hour. The machine already goes past 50 km² an hour; what holds a search to 4 or 5 is the agent looking at every tile. US ground is the exception: its raw points take 179 s per km² to fetch, so USGS's ready-made 1 m model is the lever there.
  - **The registers, asked live:**
    - **Denmark, Fund og Fortidsminder** (Slots- og Kulturstyrelsen, WFS at `kulturarv.dk/ffgeoserver/public/wfs`, in ETRS89 / UTM 32N; no fees or access constraints declared). Layers for points, lines and areas, protected and not protected, and at sea. A box of about 150 km² in Jutland held 74 protected points, 326 points that are not protected and 86 areas, each with its kind (`anlaegstype`), dating and a link to its record.
    - **Norway, kulturminner** (Riksantikvaren through Geonorge, WFS at `wfs.geonorge.no/skwms1/wfs.kulturminner`, NLOD; the public copy leaves out sensitive records). Layers Lokalitet, Enkeltminne and Sikringssone. Around the Borre test box: 108 localities and 179 single monuments, each with its kind, dating, protection and a link to Askeladden.
    - **England, the National Heritage List** (Historic England, ArcGIS FeatureServer layer 6 "Scheduled Monuments", Open Government Licence). A 20 km box on Salisbury Plain held 412. It holds designated monuments only; the county records, where most known sites are, are not open.
    - The Netherlands, Estonia and Slovenia were not probed yet.
  - **What stops a stranger** (from `Setup.swift` and `bundle.sh`; a fresh macOS account was not made, since that needs Chris's admin password):
    - `bundle.sh` signs with the first "Apple Development" identity, so Gatekeeper refuses the app on another Mac. This Mac has a "Developer ID Application" identity, so a notarized build is possible (G4).
    - The tools need `uv` already installed; without it they cannot be prepared.
    - The engine is found only as the Codex command line or inside the ChatGPT or Codex apps; there is no way to install it from Dighouse.
    - Second opinions from another maker need OpenCodex on 127.0.0.1:10100.
  - **The measuring tour** found no slow screen (launch 3.5 s, pages under 50 ms, the longest chat 0.4 s, no stalls).
  - **Tests:** offline 45 (two new: Shizuoka's two sheet layouts, and the funnel on a fresh project).
- **G1, fast and wide** (2026-11-23).
  - **The bulk look** (`src/dighouse/triage.py`, the tool `look_at_tiles`). Every tile, in composite and sky view with the feature guide, goes straight to a low-cost vision model through the model router (primary/gpt-6.1-terra, eight at a time; `DIGHOUSE_SORT_MODEL` overrides it). A tile it sets aside is asked once more, since the same model can answer differently. Each verdict is recorded under that model's name, every shape it points at on a tile worth a closer look becomes a find marked "seen in bulk", and the agent looks closely only at the shortlist, best first. Without the router the agent looks at every tile, as before. The skill, the tools' instructions, `start_test` and the "Find and report back" and "Look at the tiles" workflows say so.
  - **Scored offline on copies of the five saved blind tests** (`scripts/sort_eval.py`; the saved runs are not changed). Over three runs, every answer-key feature on a tile the agent had called possible or built was also on the bulk shortlist, and so was every mound the agent had seen (Borre 21 of 21 each time, Mound City 19 of 19). Without the second look on set-aside tiles, one run lost 2 of Borre's 21. The shortlist is not smaller on these dense test sites (Borre 7 of 9 tiles, Andía 45 of 49 on rough ground); on Perry Mesa, ordinary ground, it was 17 of 36, both of the agent's possible tiles among them, in 27 s.
  - **Without the agent at all** (`--pipeline`: bulk look, its finds, measured rises), the search ties at Maiden Castle (3 of 3), Cahokia (1 of 1) and Andía (5 against 4), and falls short at Mound City (17 or 18 of 19) and Borre (18 to 23 of 53, 25 to 27 with GPT-6 as the eye, against 29). A model asked for every mound points at fewer than an agent marks, and judging the measured rises' numbered rings did not close the gap. So the bulk look leads and the agent's close look stays.
  - **The live blind tests**, the five sites run in the app on the new skill (`-startBlindTests`, primary / 6.1 Terra), against the saved runs of 2026-11-22. A first round, with the agent told to "mark what the bulk look missed", found Borre 27 and 26 of 53: the agent marked fewer mounds itself and the bulk look's places are coarser. So a mark the agent makes within 15 m of a bulk find now takes that find over, at the agent's place and in its words (`flag_candidate`), and the agent marks every feature it sees as if nothing were marked. The second round, on that:

    | Site | Found (saved) | Extra finds per km² (saved) | Minutes |
    |---|---|---|---|
    | Borre, two runs | 29 and 29 of 53 (29) | 29.0 and 36.8 (26.3) | 5 and 5 |
    | Mound City | 19 of 19 (19) | 68 (56) | 5 |
    | Maiden Castle | 3 of 3 (3) | 39.8 (37.5) | 6 |
    | Cahokia | 1 of 1 (1) | 48 (32) | 4 |
    | Andía | 5 of 11 (4) | 61.6 (86.1) | 12 |

    No site is worse, and Andía found one more. Extra finds rise at four sites, from the bulk look's finds the agent did not take over; G3 is where they are held back. One Borre run was stopped and repeated when Norway's ground service stopped answering for a time (the same outage left its register's map service returning 504).
  - **The search without the agent's close look, timed** (`scripts/speed.py no:nhm-dtm-1m 2.4 --bulk`): 5.8 km² of Norway, 121 tiles: fetch 155 s, cut 7 s, draw 11 s, bulk look 114 s, measured rises 107 s: **53 km² an hour**, with 26 tiles (21%) shortlisted and 15 finds opened. The agent's close look on the shortlist comes on top of that.
  - **USGS's ready-made ground model** (`us:3dep-dem-1m`, the 3DEP image service): 4.6 s per km², against 179 for the points. Where no 1 m model exists the service fills in 10 or 30 m ground, and the dataset's note says so.
- **G2, checked against the records** (2026-11-23).
  - **Registers read** (`discover.py`, part of the open lists every check uses): Denmark's Fund og Fortidsminder now with its mapped areas as well as its points; **Norway's heritage register** through Geonorge's map service, falling back to Riksantikvaren's own service by municipality when the map service is down (it returned 504 for part of the afternoon; the fallback read 198 records around Borre in 10 s); and **England's scheduled monuments** from Historic England's National Heritage List (412 in a 20 km box on Salisbury Plain). A find inside a recorded area counts as on it, at 0 m; outside, the distance is to the area's edge.
  - **Every find says what it was checked against, and when.** The map check (`check_modern`, and so `check_finds`) files a records check on each find outside a blind test: the sites within 120 m with their record links, the lists that answered and those that did not, the date read, and the official registers that cover the place with what each holds, or that none does, so the site records there were not read. It shows on the record ("Not on the open records read" or "On the open records"), on the record pane with a button to open the register's own page, and as a chip in Decide. Checked live on a project made on Normanton Down: the find's record named the Wikidata entry for the barrow cemetery 69 m away and said England's list holds scheduled monuments only.
  - **Three shades.** `discover.shade` says what a search in an area can do: *can find and check* (open lidar and a register that lists every recorded site: Denmark, Norway), *can find, not fully check* (open lidar, the records closed or partial, such as England's scheduled monuments only or the United States), or *no open lidar yet*. A project keeps its shade when its area is set (`init_project`, `name_project`) and shows it under its question; `survey_area` says it too.
  - **Registers as answer keys** (`scripts/register_keys.py`): eleven new blind tests from the registers, eight in England (barrow groups where each barrow is scheduled on its own: Normanton Down, Lake Down, Winterbourne Stoke, Seven Barrows, Overton Hill, Priddy Nine Barrows, Therfield Heath, Wexcombe; 4 to 9 counted monuments each) and three in Norway (grave fields in Sandefjord, Karmøy and Tønsberg; 11 to 36 counted). England's list often schedules a whole group as one area, so its keys count monuments, not mounds. An area reaching out of a test's box becomes a point at its middle. Borre's key was already built from Norway's register. Two of the new keys were run in the app on the G1 flow: **Normanton Down, 9 of 9** scheduled monuments found, 10.9 finds outside the key per km², 10 minutes; **Sandefjord (Stokke prestegård), 6 of 22**, 59 per km², 7 minutes, every miss on a tile looked at and not marked (low, ploughed grave mounds; a test for G3 and the raw-points work). The other nine are not run yet.
  - **Tests:** offline 48 (two new: a find inside a recorded area is on it, measured to the edge outside; which registers cover a place, and the words when none does).
- **G3, fewer, honest finds** (2026-11-23).
  - **The second opinion sees a ring.** The whole tile, as before (it gives context), now with the find ringed in orange, and the model asked to say what is inside the ring before it judges (`review.py`). Rated on 102 views of known ground at Borre, Mound City, Angel Mounds and Cahokia with Sonnet 5.5 (`scripts/rate_reviewers.py --tile` against `--ring`):

    | View | Right | Published features found | Measured rises refused | Plain ground refused | Its "built" right |
    |---|---|---|---|---|---|
    | Tile, place in words (before) | 62 of 102 | 18 of 24 | 20 of 38 | 24 of 40 | 18 of 52 |
    | Tile, find ringed | 89 of 102 | 19 of 24 | 33 of 38 | 37 of 40 | 19 of 27 |

    This is the C-037 problem from the polish pass: the second model said "built" about a track elsewhere on the tile.
  - **Finds the bulk look opened that the agent did not take over wait on the map**, like measured rises, until the second model calls them built or a person raises them (`ledger.layer`, `ProjectStore.layer`; `raise_rise` raises either). What the app, the record and the report call "measured rises on the map" are now "finds kept on the map", with what that covers.
  - **One height**, named for what it measures (`ledger.height_words`, `Candidate.heightWords`): how far a find rises above or sits below the ground around it, from the shape check; the slice's rise above the line between its ends only when there is no shape check, since on a slope it reads high. The record, the report, the research record, Decide and the record pane use it.
  - **Hollows.** The shape check already calls a pit a hollow ("a hollow, 0.5 m below the ground around it, not a rise" on a synthetic pit); with one height, a hollow's height is said as below the ground.
  - **Suggestions only for finds a person sees.** `run_status` lists `to_suggest` (open finds not kept on the map and without a suggestion) and `kept_on_the_map`; the skill, the timed session's instructions and the workflows suggest only for those, so a session no longer writes "tentative natural" on 74 measured rises a person never sees.
  - **What a person is shown** (`scripts/person_load.py`, on the G1 blind runs, the old map rule against the new): finds outside the key shown per km² fell at Borre (15.8 to 13.2), Mound City (24 to 16), Maiden Castle (5.7 to 3.4), Cahokia (24 to 8), Andía (13.4 to 10.6), Normanton Down (5.0 to 1.0) and Sandefjord (6.2 to 0). On these test sites the finds shown are mostly real monuments (Borre has 53 in 0.38 km²), so the 15 per km² of the goal is read as false flags a person has to rule out: all but Mound City (16) are under it. On ordinary ground, Perry Mesa showed a person 1 find in 1.52 km².
  - **Blind tests on G3** (the five sites in the app, primary / 6.1 Terra): Borre 28, then 29 of 53; Mound City 18, then 19 of 19; Maiden Castle 3 of 3; Cahokia 1 of 1; Andía 5 of 11. Nothing in G3 changes how finds are marked (it changes the second opinion, what is kept on the map, the height and the suggestions), and the reruns came back to G1's figures, so the first Borre and Mound City runs are taken as the usual spread. Open map services (Overpass) did not answer for much of the evening, which leaves map checks open but does not touch the score.
