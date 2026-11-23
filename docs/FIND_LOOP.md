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
