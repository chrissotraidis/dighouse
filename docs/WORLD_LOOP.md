# Dighouse goal loop 7: more of the world, then under water

Last updated: 2026-11-16

Read [HANDOFF.md](HANDOFF.md), [PROVING_IT.md](PROVING_IT.md) and the end of [TEST_LOOP.md](TEST_LOOP.md) first. Dighouse
fetches ground from the US, England, the Netherlands, France, Flanders, Norway, Estonia and Switzerland. This loop adds
five more places (Spain, Bavaria, Saxony, New Zealand, Denmark), each proven with a blind test on a known site. Then it
tries the same method on the seafloor, with a blind test on charted wrecks.

## Who this is for

- **People outside the current countries,** who today open the coverage map and find nothing near them.
- **Archaeologists in Spain, Germany, New Zealand and Denmark,** who want proof it works on their ground, with their own sites.
- **Maritime archaeologists and wreck researchers,** who want to know whether an agent can read sonar surveys of the seafloor.

## Decisions already made (Chris, 2026-11-16)

- Order: Spain, Bavaria, Saxony, New Zealand, Denmark, then the underwater pilot.
- Each new place counts as done only after a blind test on a known site there, scored and logged.
- Underwater is a pilot: one data source (NOAA), two or three test areas, and an honest score.

## What is known about the sources

Check each before building on it, and log what you find.

- **Spain:** PNOA LiDAR, second coverage. Raw points for the whole country in 2 km tiles from the CNIG download center
  (https://pnoa.ign.es/pnoa-lidar/segunda-cobertura, https://centrodedescargas.cnig.es/CentroDescargas/). Raw points
  mean the slice works unchanged. Check whether the downloads can be scripted without a form, and whether IGN also runs
  a ground-model web service.
- **Bavaria:** a 1 m ground model and raw laser points, open data, CC BY 4.0
  (https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=dgm1 and ?pn=laserdaten). Find the tile download pattern.
- **Saxony:** ground models and points free in 2 km tiles
  (https://www.geodaten.sachsen.de/downloadbereich-digitale-hoehenmodelle-4851.html). Find the tile download pattern.
- **New Zealand:** a 1 m ground model on AWS, CC BY 4.0, without raw points (https://registry.opendata.aws/nz-elevation/).
  It is probably cloud-optimized GeoTIFFs with a catalog, like swissALTI3D (the "files" kind); confirm.
- **Denmark:** Danmarks Højdemodel through Dataforsyningen. The web service needs a free account and token
  (https://confluence.kds.dk/display/MYD/Log%2Bind%2Bog%2BToken). Datafordeler's DHM service is a different service
  with its own access. The national site register, Fund og Fortidsminder, can be downloaded
  (https://www.kulturarv.dk/fundogfortidsminder/Download/).
- **Seafloor, US:**
  - NOAA hydrographic surveys come out as BAG files (gridded depth, uncertainty and metadata), searchable in NCEI's
    Bathymetric Data Viewer (https://www.ncei.noaa.gov/products/nos-hydrographic-survey,
    https://www.ncei.noaa.gov/maps/bathymetry/).
  - Newer surveys are in NOAA's open hydrographic data on AWS (the noaa-ocs-hydrodata registry entry).
  - BlueTopo is NOAA's compiled best-available depth model (https://nauticalcharts.noaa.gov/data/bluetopo_faq.html).
- **Wrecks, US:**
  - NOAA has retired AWOIS and stopped updating it. Legacy downloads remain: AWOIS_Wrecks.zip and ENC_Wrecks.zip at
    https://wrecks.nauticalcharts.noaa.gov/downloads/.
  - The current source is ENC Direct to GIS (https://nauticalcharts.noaa.gov/data/wrecks-and-obstructions.html), and
    there is a Wrecks_and_Obstructions FeatureServer.
  - NOAA says AWOIS is not comprehensive and its positions can differ from charted positions, so a key built from it
    needs a generous match distance and stated limits.

## Goals

Each goal is done when its check passes in the running app. Record the date and what you saw in the Log. Work them in order.

| Goal | What | Check |
|---|---|---|
| W0 | **Set up.** Save this file. Read src/dighouse/national.py (the NATIONAL entries and the "wcs", "wcs1", "wms" and "files" kinds), sources.py (raw points), the Reach.national outlines in ToolboxView.swift and the README services table. Write down in the Log the steps a new place needs, so each country goal follows the same steps. Extract a shared form only if two countries need the same new kind. | The Log lists the steps. Tests pass. |
| W1 | **Spain.**<br>- **Fetch:** raw PNOA points if they can be scripted (so the slice works); otherwise the ground model, said plainly in the dataset description.<br>- **Coverage:** add the outline to the coverage map, the services table and find_data.<br>- **Known site:** pick one earthwork that survives in relief and is on open record with a publication, such as a hillfort (castro) in the northwest or Numancia, and write an answer key for it in src/dighouse/keys/ with a source for each feature.<br>- **Blind test:** run it there. | find_data offers Spain inside Spain and not outside. A fetch builds the ground, the tiles render, and a slice works if points were used. The blind test score is in the Log. Screenshot of the coverage map. |
| W2 | **Bavaria.** The same steps as W1. Prefer raw points; use the 1 m model if the points are awkward. Known site: an earthwork with a published plan, such as a Celtic square enclosure (Viereckschanze) or the Manching oppidum wall. | As W1. |
| W3 | **Saxony.** The same steps as W1. Known site: a ring fort (Burgwall) or a group of burial mounds in woodland, on open record with a publication. | As W1. |
| W4 | **New Zealand.** The 1 m ground model (no raw points). Say in the dataset description and the slice that there are no points, as for the other national models. Known site: a pā with ditches, banks and terraces, on open record with a publication. Write the key and its notes with care: these are Māori places, so name them as their records do. | As W1, without the point slice. |
| W5 | **Denmark.**<br>- **Ground:** Danmarks Højdemodel through Dataforsyningen, using a token the person pastes in Settings, stored like other keys. Without a token, find_data says what is needed and links the sign-up page. Never create an account for Chris.<br>- **Register:** load Fund og Fortidsminder as a records source for the checks, so "not on record" in Denmark means "not in the national register, checked on this date".<br>- **Known site:** Trelleborg or Fyrkat (ring fortresses), or a group of burial mounds; the key comes from the register. | With Chris's token: as W1, and a check on a registered mound shows the register entry. Without one: the code, an offline test and the token message are done, and the live check is logged as waiting for Chris. |
| W6 | **The world, written down.** README: the services table, the coverage map picture and the benchmark table gain the new places, with scores as they are. Rerun the six old blind tests if anything they use changed. Update HANDOFF, concept and the tool count. | The README matches the Log. The smoke test passes. |
| W7 | **Seafloor ground.**<br>- **Fetch:** a NOAA source (BAG files or BlueTopo; pick whichever can be fetched for a box most simply) as terrain, with depth stored as negative height.<br>- **Render:** the same views as on land, tuned for depth: hillshade and local relief should show a wreck's hull and scour.<br>- **Dataset description:** the resolution, the survey's uncertainty and the survey date.<br>- find_data offers it only over water inside the survey footprints. | A fetch of a box around a charted wreck in a high-resolution survey renders tiles in which the wreck is visible. |
| W8 | **Wreck answer keys.**<br>- **Build:** keys from the current ENC wrecks (or the FeatureServer), for two or three test areas, each with several charted wrecks inside high-resolution survey coverage.<br>- **Count:** wrecks only, leaving out obstructions; a wreck charted only as a position with no survey evidence is kept and marked "may not show".<br>- **Match distance:** set from NOAA's warning about position accuracy, and stated in the key. Keys stay in the tools' private data. | Each key lists its wrecks with a source. The Log names the areas and why they were chosen. |
| W9 | **Looking under water.**<br>- **Feature guide:** add wrecks (hull outline, scour pit, debris field) and look-alikes (rock outcrops, sand waves, trawl scars, pipelines and cables, dumped material).<br>- **Modern check:** off the coast this means charted pipelines, cables and dumping areas.<br>- **Slice:** cuts across the depth model.<br>- **Words:** the skill and the app say "seafloor" and "wreck", and keep find / slice / look at / second opinion. | The guide and checks run on one test area without errors, and the slice across a wreck shows its height above the seafloor. |
| W10 | **The underwater blind test.**<br>- **Runs:** each test area, blind, scored against its key.<br>- **README:** a row marked "Underwater (pilot)" with the score as it is, and a short "What it cannot do" note: wrecks lying flat, buried, or in coarse surveys.<br>- **Responsible use:** many wrecks are war graves or protected; positions stay private; report to NOAA or the state's underwater archaeology program, never online. | The scores are in the Log and the README. Screenshots of one scorecard. |

## Rules for this loop

- **Cheap models only.** Every test that sends a message to a model uses primary / 6.1 Terra. Never test with Opus. The second-opinion model may be any non-Opus model from another maker.
- **Keep the blind test blind.** If the agent can see the site's name, its question or literature before scoring, the score is void.
- **Report scores as they are.** Say what changed between runs. Do not tune on one site and report it as fresh.
- **Respect each source's terms.** Cite each source's licence in the dataset description and the README. Keep requests polite (small chunks, few at a time, a User-Agent). Never bypass a login or a token.
- **Locations stay private.** Keys and finds carry coordinates only in the tools' private data or a project's private/.
- **Keep it simple.** A new country is a new entry, not a new system. Reuse Controls.swift, Theme and Motion. Do not suggest Figma.
- **Plain words:** find, slice, look at, second opinion, the ground, the seafloor. Write lidar in lowercase. Never call a site or a wreck new. A person decides and a person sends.
- **Say only what was checked.** Recheck every control you rewire, and the ones next to it.
- **One branch and pull request per goal:** codex/ prefix, logged first, squash-merged with gh pr merge --squash --delete-branch.
- **Work in the existing checkout,** /Users/chrissotraidis/GitHub/dighouse. `rm` is blocked; move files to /tmp.
- **Nothing is released.** The repository stays private until Chris says so.
- **Leave Chris's things as you found them.** Back up the settings plist before driving the app and restore it afterwards. Use `-projectsHome $HOME/dighouse-ui-test` so the macOS Documents prompt does not appear, and do not click that prompt.

## How to build, check and drive the app

- **Build and open:** cd app && ./scripts/bundle.sh && open -n build/Dighouse.app --args -ApplePersistenceIgnoreState YES -projects '<5b5d>' -currentProject '' -projectsHome $HOME/dighouse-ui-test
- **Tests:** uv run pytest -q (offline); uv run pytest -m live (real services); uv run python scripts/smoke_test.py.
- **Headless agent runs:** the codex exec command in HANDOFF.md, with -m primary/gpt-6.1-terra.
- **Driving the app:** Computer Use, accessibility indices first, each call under 30 seconds.

## The loop (every turn)

1. Read HANDOFF.md, this file and the Log.
2. Pick the lowest unfinished goal.
3. Confirm its source works (one real request, logged), then build it.
4. Run its check in the running app and look at the result. Fix what it shows, and repeat until it passes.
5. Log the result with the date. Run the tests, commit, open the pull request and merge it.
6. Stop when W0 to W10 are checked, when a decision or a token is needed from Chris, or when the time Chris set runs out. If one country is blocked (a source down, a form that cannot be scripted), log it and move on to the next. Before stopping, write in the Log what is half done and update HANDOFF.md.

## Log

### 2026-11-16, W0: set up

**What each source turned out to be** (one real request each, 2026-11-16):

| Place | Source | Form | Result |
|---|---|---|---|
| Spain | IGN WCS 2.0.1, `servicios.idee.es/wcs-inspire/mdt`, coverage `Elevacion25830_5` | Ready-made ground model from PNOA lidar, **5 m at best** (coverages are 1000, 500, 200, 25 and 5 m) | Answers. The CNIG download center (raw points, 2 m model) has no listing that can be scripted without its web form, so Spain starts at 5 m: good for hillforts and ramparts, too coarse for small mounds. |
| Bavaria | `download1.bayernwolke.de/a/dgm/dgm1/{E}_{N}.tif`, E and N in km, EPSG:25832 | 1 m ground model, 1 km GeoTIFF files (not cloud-optimized, about 3 MB each) | Reads with a windowed read. Raw points are 1 km LAZ files of about 100 MB at `geodaten.bayern.de/odd_data/laser/{E}_{N}.laz`. |
| Saxony | `geocloud.landesvermessung.sachsen.de/public.php/dav/files/JCcXyifaNdLDnxZ/dgm1_33{E}_{N}_2_sn_tiff.zip`, E and N in km on a 2 km grid, EPSG:25833 | 1 m ground model, 2 km zips of about 13 MB | A GET works; a HEAD request is refused (401), so each zip is downloaded whole and cached. |
| New Zealand | `nz-elevation.s3.ap-southeast-2.amazonaws.com/new-zealand/new-zealand/dem_1m/2193/{sheet}.tiff` | National 1 m ground model, one cloud-optimized GeoTIFF per Topo50 sheet (424 sheets), EPSG:2193 | Reads with a windowed read. The sheet comes from NZTM coordinates: 24 km wide columns from E 1,012,000 (column 01) and 36 km tall rows down from N 6,810,000 (row 0 is AA), letters without I and O. Checked against AS21, BA31, BA32 and BB31. Sea-only sheets are missing. |
| Denmark | Dataforsyningen WCS 1.0.0, `api.dataforsyningen.dk/dhm_wcs_DAF`, coverage `dhm_terraen`, EPSG:25832 | 0.4 m ground model | GetCapabilities answers, GetCoverage without a token says "User not authorized" (403). Needs Chris's free token. |

**The steps for a new place** (each country goal follows them):

1. Probe the source with one real request and log the result.
2. Add an entry to `NATIONAL` in `src/dighouse/national.py`: title, source, country, rough outline (lon, lat), EPSG, cell size, the way to fetch (`wcs`, `wcs1`, `wms`, `files`, or the new `tiles` for files on a grid of map sheets), citation with licence, landing page.
3. Publisher names come from that entry everywhere (report, record, calibration, quick look), so nothing else in Python needs a list of countries.
4. The app: the outline in `Reach.national` (ToolboxView.swift) for the coverage map, and a `DataSource` in ToolGuide.swift with a sky-view picture of a known site (`app/Resources/tour/data-xx.jpg`).
5. README services table and `docs/concept.md`.
6. An answer key for one known site: a function in `scripts/build_answer_keys.py` writing `src/dighouse/keys/<site>.json`, each feature with its source.
7. Check: `find_data` inside and outside the outline, a fetch, tiles rendered, then a blind test with primary / 6.1 Terra (headless, the command in HANDOFF.md), scored. Look at the coverage map and the scorecard in the running app.

**Shared form:** Bavaria, Saxony and New Zealand all publish files on a grid of map sheets, so they share one new way to fetch, `tiles`: the entry names the sheets covering a box, and each sheet is read with a windowed read, or downloaded and cached when it is a zip.


### 2026-11-16, W1 to W4: Navarre (Spain), Bavaria, Saxony and New Zealand

These four went in together because Bavaria, Saxony and New Zealand share one new way to fetch, and all four share the
publisher and calibration changes. Each was checked separately below.

**Code.**
- `NATIONAL` gains `es:navarra-mdt-2m` (wcs), `de-by:dgm1`, `de-sn:dgm1` and `nz:dem-1m` (the new `tiles` kind: `_km_grid` for Bavaria and Saxony, `_topo50` for New Zealand). Zipped sheets (Saxony) are downloaded once into the cache; others are read in windows. A missing sheet is skipped.
- Each entry carries its publisher. `national.publisher()` and `national.countries()` replace the copies in report.py, record.py and quicklook.py.
- Keys can name their dataset prefix (`"prefix": "es"`). Calibration matches on it, so a Spanish search is not calibrated on a French key because both agencies are called IGN.
- `scripts/build_answer_keys.py` takes key names, so a new key can be built without rebuilding (and so changing) the six launch keys.
- App: four outlines in `Reach.national`, four `DataSource` entries with sky-view pictures of sites outside the test boxes (Irulegi, the Laufzorner Holz enclosure, Ostro, Maungawhau). README services table and concept.md.

**Spain is Navarre for now.** IGN's national ground model service answers but rounds heights to whole metres (int16), which draws terraces over everything (a quick look at a Galician castro showed the steps). The CNIG download centre, which has the 2 m model and raw points, accepts a connection but never answers a script. Navarre's IDENA serves a 2 m model with real decimals (CC BY 4.0), and Navarre publishes its register of protected archaeological sites as an open layer (`PATRIM_Sym_BICarqueo`, 1,187 records).

**Found during W2: parallel writes corrupted a project.** The agent hands tiles to helpers that record verdicts at the same moment. Two saves of `tiles.json` interleaved ("Extra data" at character 12,626) and every later tool failed. Fixed: `Project.save` writes a temporary file and swaps it in, and `Project.change` holds a file lock while state is loaded, changed and saved (verdicts, measured rises, new finds and their ids). An offline test records 40 verdicts and 12 finds from 16 threads; it fails without the fix.

**Checks.** `find_data` offers each region inside its outline and nothing in Baden-Württemberg or Portugal. A fetch of each builds ground with decimal heights (Bavaria 17 s for four 1 km sheets, Saxony 4 s, New Zealand 3 s). In the running app the coverage map shows the four regions ([screenshot](loop7/coverage-map.png)), the four services answer "Online", and the Saxony card opens with its picture.

**Blind tests,** primary / 6.1 Terra at medium, with `find_mounds` in the workflow, second opinion skipped:

| Region | Site | Key from | Found | Extra | What happened |
|---|---|---|---|---|---|
| Navarre | Sierra de Andía megaliths | Navarre's register, 11 dolmens and mounds | 0 of 11 | 5 | The mounds do not stand out among hundreds of small bumps (shrubs or boulders) in the 2 m model. The measured rises reach 6 of 11 only among 561 spots. A limit of the data for low mounds on this upland. |
| Navarre | Irulegi hill | Register zone; OpenStreetMap outlines | 1 of 2 | 0 | Castle found; the Iron Age village on the terraces missed. |
| Bavaria | Oberhaching square enclosures | Bavarian monument office records D-1-7935-0042 and -0043 | 0 of 3 | 2 | First run broke on the corrupted tiles file (above). Rerun: every enclosure tile was called "modern", for its straight sides and field edges. |
| Saxony | Lauske, Niethen and Zschorna ring forts | OpenStreetMap | 2 of 3 | 1 | Niethen missed though its rampart is plain; 68 of 72 tiles were called modern. |
| New Zealand | Puketapu Pa (R12/85) | Auckland Council heritage schedule, place 2251 | 1 of 1 | 8 | Found. The extras are ditches and pits around the scheduled outline, unscored. |

**What the scores show.** The agent reads straight-sided or field-edge earthworks as modern. The feature guide tells it straight lines along field edges are modern and that an unsure tile is "possible", not a find. That costs the Bavarian enclosures and a Saxon ring fort. The guide is changed next (W2/W3 follow-up), and every site is rerun with it in W6, with both results reported.


### 2026-11-16, W5: Denmark

- **Ground:** `dk:dhm-terraen`, Danmarks Højdemodel terrain at 0.4 m through Dataforsyningen's WCS 1.0.0, with the token added to each request. The token comes from `DIGHOUSE_DATAFORSYNINGEN_TOKEN` or from `keys.json` in the app's support folder. The new "Denmark's ground model" row in Settings, Data and privacy, writes that file with owner-only permissions.
- **Without a token:** `find_data` lists Denmark as needing a free token, with the sign-up page; quick look passes over it. `fetch_terrain` says what is needed. A refused token says the token was not accepted (checked with a dummy token against the live service).
- **Register:** Fund og Fortidsminder's public WFS (protected and unprotected sites) is a records source, so a check in Denmark reads the national register. At Trelleborg it lists the fortress (Borg/Voldsted, Viking Age) and 19 other records. Navarre's register (`PATRIM_Sym_BICarqueo`) joined the same list.
- **App:** cards for Danmarks Højdemodel, Fund og Fortidsminder and Navarre's register; "Not read yet" now names Finland and Sweden only.
- **Checked in the running app:** the Settings row shows, Save stays off until something is typed, and a saved token reaches the tools (keys.json mode 600). Clearing it and saving removes it. An offline test covers the message without a token and reading the keys file.
- **Waiting for Chris:** the live fetch and the Danish blind test (Trelleborg or a mound group, keyed from the register) need a real token, which needs an account. That is Chris's to create.


### 2026-11-16, W6: the method changed, and every site rerun

The W1 to W4 scores showed the agent calling straight-sided earthworks at field edges "modern". Two changes, each rerun on the sites they touch:

1. **Feature guide** (src/dighouse/FEATURES.md): enclosures can be square, with sharp corners (Iron Age square enclosures, Roman forts, moated sites). A field edge runs on; an earthwork that closes on itself is an enclosure. "Straight is not the same as modern": a closed bank or ditch is worth a find, and the checks decide.
   - Rerun at Oberhaching with only this change: still 0 of 3. Every enclosure tile was still called modern. Looking at the tile showed why: a 250 m tile shows one side of a 100 m enclosure, which looks like a field edge.
2. **A look at the whole area first** (skills/dighouse/SKILL.md, step 3): after make_tiles, `view_terrain` in sky view and hillshade, noting every bank or ditch that closes on itself; mark each once, with the point on the bank or ditch itself. (The middle of an enclosure is not on its line: Maiden Castle's rampart find was 128 m from the rampart and scored as extra.)

**Three rounds, primary / 6.1 Terra at medium, `find_mounds` in each:**

| Site | First (W1 to W4, or loop 6) | Guide and overview | Final (point on the bank) |
|---|---|---|---|
| Mound City | 19 of 19 | 19 of 19 | 19 of 19, 3 extra |
| Angel Mounds | 4 of 4 | 4 of 4 | 4 of 4, 3 extra |
| Cahokia | 1 of 1 | 1 of 1 | 1 of 1, 3 extra |
| Serpent Mound | 1 of 3 | 1 of 3 | 1 of 3, 2 extra |
| Maiden Castle | 1 of 3 | 0 of 3 (rampart marked in its middle) | 1 of 3, 2 extra |
| Borre | 19 of 53 | 20 of 53 | 20 of 53, 0 extra |
| Oberhaching | 0 of 3 | 2 of 3 | 2 of 3, 3 extra |
| Lauske | 2 of 3 | 3 of 3 | 3 of 3, 5 extra |
| Irulegi | 1 of 2 | 1 of 2 | 1 of 2, 0 extra |
| Andía | 0 of 11 | 0 of 11 | 0 of 11, 12 extra |
| Puketapu | 1 of 1 | 1 of 1 | 1 of 1, 8 extra |
| **Eleven on land** | **49 of 103** | **52 of 103** | **53 of 103, 41 extra** |

The overview gained four enclosures and forts (Oberhaching 2, Lauske 1, Maiden Castle back to 1) and cost nothing on the mound sites. Extras rose from 30 to 41, most of them at Andía, where the agent marked rough upland bumps.

**The README** benchmark table has all eleven land sites and the underwater pilot, with the same caveats. "What it cannot do" names Andía and the pilot's limits. The services table lists the new sources. The tool count stays 42 (no new tool). Measured rises across the eleven: 63 of 103 in front of a person instead of 53, but 738 spots in all, 565 of them on the Andía upland. They help on smooth ground and flood rough ground, and the README says so.

### 2026-11-16, W7 to W10: the seafloor pilot

- **Source:** NOAA NCEI's `bag_bathymetry` image service (every BAG survey as one mosaic) is fetched like a ground model (`kind: image`, in the box's UTM zone, 32-bit depths, `us:noaa-bag`). `find_data` offers it only where a survey 2 m or finer covers the box, listing the surveys (from the service's catalog), so it never shows on land. Depth is negative height. The terrain records the surveys used (for example H12132, H14139, W00499 at 1 m). Checked by a live test: a charted wreck in Thunder Bay stands more than 1.5 m above the lake bed in the fetched model.
- **Land or water:** when a seafloor survey covers a box, `find_data` lists it first and notes on the land lidar that it stops at the water's surface; the skill says to fetch the seafloor survey. (Before that fix, two of the three first wreck runs fetched land lidar over the lake and found nothing to score.)
- **Keys** (W8): `wreck_key` in scripts/build_answer_keys.py reads the wrecks on NOAA's electronic charts at all four scales from ENC Direct, merging two symbols within 80 m. It checks each wreck's 120 m surroundings for survey data and marks it "may not show" below 30%. Match distance is 100 m (one Thunder Bay hull lies 70 m from its symbol), stated in the key. Coverage is "charted": the scorecard says an extra may be an uncharted wreck or debris. Three areas in Thunder Bay National Marine Sanctuary were chosen because all 27 charted wrecks there sit in 1 m surveys:
  - **thunder-bay-a**, west: 4 wrecks, 3 counted (one has 14% coverage).
  - **thunder-bay-south**: 2 wrecks.
  - **thunder-bay-east**: 2 wrecks.

  A Key Largo key was dropped: none of its charted wrecks had survey data around them. The chart services answer "could not find service" now and then, so key building and the checks retry; one empty key came from a single unanswered request.
- **Looking under water** (W9): the feature guide has a seafloor section (hull, scour pit, debris field; rock outcrops, sand waves, trawl and anchor scars, pipelines, dumped material, survey artefacts and gaps).
  - **Modern check:** `check_modern` reads charted cables, pipelines and dumping grounds from NOAA's charts, plus charted wrecks except during a blind test. A layer that does not answer is named as unchecked.
  - **Slice:** samples in gaps between survey lines are skipped, and the picture is labelled "seafloor, from a sonar survey". The report and record say "above the seafloor" and "Charts:". Checked end to end on a Thunder Bay hull: slice 2.3 m high over 51 m, charts "no cable, pipeline or dumping ground charted; a wreck is already charted within 150 m".
- **Blind tests** (W10), the final method, one scored run each:

| Area | Found | Extra | Notes |
|---|---|---|---|
| Thunder Bay west | 2 of 3 | 2 | |
| Thunder Bay east | 2 of 2 | 3 | Scorecard in the running app: [screenshot](loop7/wreck-scorecard.png) |
| Thunder Bay south | 0 of 2 | 0 | Both charted wrecks stand 1.3 to 2.3 m above a lake bed strewn with boulders of the same size; the agent called all 84 tiles natural. |
| **Pilot** | **4 of 7** | 5 | |

  The README benchmark table has an "underwater (pilot)" row. "What it cannot do" covers wrecks that lie flat, are buried, sit among rocks or in survey gaps. Responsible use adds that wrecks can be war graves and are reported to NOAA's sanctuaries office or the state's underwater archaeology program.

### Where loop 7 stands

- **Done and checked:** W0 to W4, W6 to W10.
- **W5, Denmark:** built and checked offline and in the app's Settings. The live fetch and a Danish blind test wait for Chris to create a free Dataforsyningen account and paste the token.
- **Not done:** Spain beyond Navarre (IGN's national service rounds heights to whole metres; CNIG's download centre does not answer scripts).
- **Next:**
  - Calibrate the wreck search on a rocky lake bed.
  - Try EMODnet for European waters.
  - Run the land sites again when the model changes.


**Live tests:** `uv run pytest -m live` gives 7 passed and 2 failed on this Mac. The 2 query the Cahokia area, which an unfinished loop-6 blind test (~/dighouse-ui-test/blind-test-2026-11-16-2) still holds closed in the blind-test registry. With an empty cache (`DIGHOUSE_CACHE=$(mktemp -d)`) all 9 pass. That project was left as it is; finishing or removing it is Chris's call.

**README picture:** Open data retaken at 1440 × 900 in Earth (window alone, `screencapture -l`): 42 tools, 21 of 22 services online (OpenStreetMap's Overpass partly online, as the caption says), the map with New Zealand and the European regions. Settings restored afterwards.

### 2026-11-17, after the loop: seafloor survey details and the Basque Country

- **Seafloor survey details** (the part of W7 still open): a seafloor fetch now reads each survey's dates, vessel and record link from NOAA's survey catalog (`nos_hydro_dynamic`, layer 0). It also reads the median of the BAG's uncertainty layer from the file's small overview grid, a few kilobytes over the network. All of this goes into the fetch warnings, the terrain's "Flown" column (for example "2010 to 2019") and a new "Seafloor survey" table in the research record. Thunder Bay: H12132, 2010-06-15 to 2010-11-04, NOAA SeaArk Launch S1211, 0.06 m. W00499, 2019-07-22 to 2019-08-02, NOAA R/V Storm, 0.06 m. H14139 is not in the catalog yet, so it is listed by name only.
- **More of Spain:**
  - **The Basque Country** joins as `es-pv:mdt-1m`: geoEuskadi's WCS, the latest 1 m lidar terrain model, CC BY 4.0, decimal heights (checked). It has an outline on the coverage map and a card in the Toolbox, which answers "Online" in the running app.
  - **Catalonia:** ICGC's 2 m model could not be reached. Every address tried for it answers 404, and the open service (`icc_mdt`) serves only 5 m and 15 m.
  - **Castilla y León:** its WCS answers, but at 5 m.
  - **Madrid:** its 50 cm model is in the CNIG download centre only.
- **Basque blind tests,** final method, primary / 6.1 Terra, keys from OpenStreetMap outlines with Wikidata records:

| Site | Found | Extra | What happened |
|---|---|---|---|
| Munoaundi hillfort | 0 of 1 | 1 | The agent marked a curving boundary round the ridge 141 m from the mapped rampart line. |
| Arrola hillfort | 0 of 1 | 1 | It marked "several parallel curving banks and ditches" 97 m outside the mapped outline. The outline may hold the inner enclosure only, while the outer banks are what show. |

  Both are reported as scored, without changing the method or the keys. The README table now has thirteen land sites: 53 of 105.


### 2026-11-17, Denmark as an option, and the new sites in the app

- **Denmark:** Chris decided not to make a token. Denmark stays an option for anyone who pastes their own free token, which is what W5's check allows: "Without one: the code, an offline test and the token message are done." W5 is closed on that basis. In the running app, an area at Trelleborg lists Danmarks Højdemodel with a key icon and "Needs a free token: paste it in Settings, Data and privacy" (New project now shows this for any service that needs a token). Denmark's register is read in the checks without a token.
- **The new sites in the app:**
  - "Test it on a known site" now offers ten sites, under On land and Under water: the six launch sites, Oberhaching, Lauske, Puketapu and the Thunder Bay wrecks, each with a picture made from its own data.
  - Home's "Known sites to learn on" adds the Lauske ring fort (Saxony) and a Thunder Bay wreck (NOAA sonar). The Thunder Bay starting point opens New project over the lake, which lists the NOAA survey.
  - New project's list is called "Open data here", since it lists sonar surveys too.
  - All of this was checked in the running app.
- **README:** a picture of the ten test sites under the benchmark, and the Denmark row says it is an option.


### 2026-11-17, README pictures: lake to wreck, and Home

- **docs/images/lake-to-wreck.gif:** a sweep like the treetops-to-ground animation, at Thunder Bay. The "Lake surface" side is the USGS lidar surface (the highest return in each cell) over the shore and breakwater, with the water drawn plain, since airborne lidar stops at the surface. The "Lake bed" side is the lidar ground on land and NOAA's sonar survey under the water, where two charted wrecks show. 938 × 586, 96 frames at 50 ms, the same size and timing as the first animation.
- **docs/images/home.png:** retaken in the running app at 1440 × 900 in Earth (window only, test projects out of the sidebar). It shows Places to start, with the Lauske ring fort and the Thunder Bay wreck in the last row. Settings restored afterwards.

### 2026-11-17, why Dighouse is slow to start and freezes

Measured on Chris's Mac:

- **Start:** the app started a login shell (`zsh -lic`) to find the engine and uv: 2.6 s every launch, before the engine could start. The engine itself is ready in about 1.3 s. Dighouse now saves what the full check found and starts the engine from it straight away, then runs the full check in the background. From launch to engine and tools running: 4.7 s before, 1.7 to 2.2 s after (three launches of the new build).
- **Freezes:** all 11 of Chris's projects sit in ~/Documents, which is synced to iCloud, and about half their files are offline (for example 118 of 225 in Maiden Castle, 2 to 4 state files in each project). Any read of an offline file waits for iCloud. Copying one 95 MB project (Middle Usumacinta) took 162 s, almost all of it waiting on downloads. The app reads project state every 2 seconds, so it stalls when a project is open.
- **Fix:** Home and Settings, Data and privacy, show "N projects are in iCloud" with **Move to this Mac**. The button copies each project with ditto (which waits for the downloads), checks every file and size, repoints the project, puts the original in the Trash and sets the projects folder to ~/Dighouse. A project that fails to copy is left in place, with a note saying so. Checked in the running app with two test projects in a folder marked as iCloud: both moved, the originals went to the Trash, the notice went away, and a moved project opened with its tiles and find.
- **Not done for Chris:** his own projects were not moved. The move puts originals in the Trash, so he presses the button himself.
