<p align="center">
  <img src="docs/images/icon.png" alt="Dighouse app icon: a mound drawn in lidar dots of soil brown, tan and green" width="128" height="128">
</p>

<h1 align="center">Dighouse</h1>

<p align="center">
  <strong>Search public lidar for possible built features, check each one, and record what is already published.</strong><br>
  You decide what they are.
</p>

<p align="center">
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-0A84FF?logo=apple">
  <img alt="42 tools over the Model Context Protocol" src="https://img.shields.io/badge/MCP-42%20tools-8B5E3C">
  <a href="LICENSE"><img alt="Apache 2.0 licence" src="https://img.shields.io/badge/licence-Apache%202.0-8E8E93"></a>
</p>

<p align="center">
  <a href="#get-started"><b>Get started</b></a> ·
  <a href="#benchmarks">Benchmarks</a> ·
  <a href="#how-a-search-works">How a search works</a> ·
  <a href="#the-tools">Tools</a> ·
  <a href="#open-data">Open data</a> ·
  <a href="#responsible-use">Responsible use</a> ·
  <a href="docs/ROADMAP.md">Roadmap</a>
</p>

![Angel Mounds, Indiana, opened in Dighouse: the project overview says what happens next and shows the search so far; five finds are marked on the bare-ground map](docs/images/angel-mounds-run.png)

<sub>A search at Angel Mounds, Indiana, from open USGS lidar: 9 tiles looked at, 5 finds marked, each one sliced, given a second model's opinion and searched in the literature.</sub>

Lidar is a laser scan from an aircraft that maps the ground through gaps in the trees, and a great deal of it is public. Most of it has never been searched for archaeology. Dighouse gives an AI model the tools to fetch that data, take the trees away, look over every square of ground, and check each thing it marks, then hands the decision to a person.

A **find** in Dighouse is a shape that might be built and is not yet confirmed. Most finds on open lidar turn out to be published already, and a record that says so is a result too.

## What it cannot do

- **It does not confirm sites.** A find is a reason to look, not a discovery. Confirming one takes an archaeologist, and often fieldwork.
- **It misses things.** In the blind tests below it found large earthworks reliably and missed most small, low mounds: 18 of 53 at Borre.
- **It cannot read everything published.** Many papers are behind paywalls, and official site registers in most countries are not public, so "no match in the sources read" often means little was readable.
- **It sees shapes in the ground, not artefacts.** Lidar cannot show buried deposits, pottery scatters, or a feature's date or culture.
- **It needs a Mac and some setup.** It builds from source on an Apple silicon Mac today; the tools also run on their own in any harness that speaks the Model Context Protocol.

## Benchmarks

Each test is **blind**: the agent is not told the site, looks at every tile, marks what it finds, and is scored against an answer key of published features before it may read any literature. Try one yourself from Home with **Test it on a known site**.

| Site | Data | Found of known | Missed | Not in the key |
|---|---|---|---|---|
| Mound City Group, Ohio | USGS 3DEP | 19 of 19 | 0 | 3 (real mounds the key leaves out) |
| Angel Mounds, Indiana | USGS 3DEP | 4 of 4 | 0 | 2 |
| Cahokia, Monks Mound, Illinois | USGS 3DEP | 1 of 1 | 0 | 1 |
| Serpent Mound, Ohio | USGS 3DEP | 1 of 3 (the effigy) | 2 burial mounds | 1 |
| Maiden Castle, England | Environment Agency 1 m | 1 of 3 (the ramparts) | both entrance outworks | 2 |
| Borre, Norway | Kartverket 1 m | 18 of 53 | 35 small burial mounds | 0 |
| **All six** | | **44 of 83** | 39 | 9 |

<table>
  <tr>
    <td width="50%"><img src="docs/images/scorecard.png" alt="The scorecard of a blind test at Angel Mounds: 4 of 4 found, 0 missed, 2 not in the key, and the map with each published mound circled and the agent's find on it"><br><sub><b>A blind test's scorecard.</b> The agent was not told it was Angel Mounds. Each published mound is circled; each green dot is a find.</sub></td>
    <td width="50%"><img src="docs/images/what-is-this.png" alt="What is this? at Newark Earthworks, Ohio: the ground in sky view and hillshade side by side, what is on record within 1 km, and the agent's short description"><br><sub><b>What is this?</b> Type a place and get the ground in two views and what is on record nearby, in about a minute, without making a project.</sub></td>
  </tr>
</table>

Run on 2026-11-16 with primary / 6.1 Terra, a low-cost model, at medium effort, about 3 minutes a site (10 at Maiden Castle). The answer keys come from Norway's heritage register (Borre) and from OpenStreetMap features with the publications that describe them (the rest). Five of the six keys are partial, so a find "not in the key" can be a real feature. Every site, run, miss and fix is in [TEST_LOOP.md](docs/TEST_LOOP.md#log). Results will differ with other models.

Small mounds are the weak spot: a mound 5 m across is a few pixels in a tile picture. `find_mounds` measures round rises in the ground model instead, and the clearest ones (at least 0.6 m high and nearly round) go on a list for a person to look over, apart from the agent's finds. Across the six keys that list puts 50 of 83 known features in front of a person instead of 45, at the cost of 28 more spots to rule out. At Borre it adds 4 mounds and 7 spots that are not.

> [!NOTE]
> Dighouse builds from source today. The app is signed for local use and is not yet notarized. The archaeology tools also run on their own in Codex or any harness that speaks the Model Context Protocol.

## Why it exists

In November 2026 Pietro Miotti let AI agents search about 1,200 km² of NASA lidar overnight, and they marked a Maya site. It turned out to be already published. Finding things was cheap; checking them was the part that failed.

Dighouse is built around the check. Every find gets a slice through the raw laser points, a second opinion from a different model, a look at open maps for roads and buildings, and a search of what is published. The tools refuse a status the evidence does not support, and nothing is ever called new.

A chat app can talk about archaeology. It cannot download a survey, look at every tile of an area, cut a slice through the points, or keep a record that someone else can pick up. Dighouse gives the same kind of model those abilities, with rules that hold whichever model is running.

We checked. Given the Mound City blind test box with no tools, the same model that found 19 of 19 mounds there through Dighouse answered that it could not reliably identify, count or place any features from the coordinates alone. That is the right answer for a chat app, and the reason the tools exist.

*A dig house is the building where an excavation team lives, works and keeps its records. The app plays the same role for a search.*

## How a search works

<p align="center">
  <img src="docs/images/treetops-to-ground.gif" alt="Serpent Mound, Ohio: a handle sweeps across the picture, taking the trees away to show the winding mound on the bare ground beneath" width="720">
</p>

<p align="center"><sub>Serpent Mound, Ohio, from open USGS lidar. Dighouse keeps only the laser returns that reached the ground.</sub></p>

1. **Choose where to look.** Ask "What should I research?" and the agent weighs open lidar, how little is on record, and where earthworks survive, then proposes three searches. Or draw an area on a map, or type a place and press **What is this?** for a one-minute look.
2. **Calibrate.** Before searching where nothing is on record, the agent runs a blind test on the nearest known site with the same kind of lidar. If it finds less than half of what is published there, the search stops.
3. **Take the trees away.** The tools download the raw laser points, or a national ground model, and keep the ground.
4. **Look at every tile.** The ground is cut into squares called tiles, and agents look at each one in two renderings. A feature guide tells it what mounds, banks and terraces look like, and what to rule out (sinkholes, tree throws, craters, tracks). A tile with too little ground data is marked unreadable, never "nothing found".
5. **Check every find.** A slice straight down through the laser points shows whether a shape is in the ground or only in the treetops. A second, different model gives its own opinion without seeing the first. Open maps are checked for roads, buildings and sites already mapped.
6. **Search what is published.** The agent searches books, papers and site records, opens what it can, and logs every source as read, could not open, or not relevant.
7. **Keep the record, and you decide.** Every find is a Markdown page with its pictures, measurements, checks and sources. You decide what it is, and your name and reason go into the record.

Take the stages one at a time, or press **Find and report back** and the agent carries the search to its end, then returns a report of at most 400 words with your decisions listed first.

## A look at the app

<table>
  <tr>
    <td width="50%"><img src="docs/images/home.png" alt="Home: a greeting with the last project and what it waits for, the treetops-to-ground picture, a message box and two ways in"><br><sub><b>Home.</b> Picks up where you left off, and starts a search from a place name in one press.</sub></td>
    <td width="50%"><img src="docs/images/new-project.png" alt="New project at Mound City Group: name, question, a search area drawn on the map, and the open lidar that covers it"><br><sub><b>New project.</b> Place the area on the map and see which open lidar covers it before you start.</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/images/maiden-castle.png" alt="Maiden Castle in England from Environment Agency lidar: the project overview with what happens next beside the tiled map of the ramparts and five finds"><br><sub><b>A project.</b> Maiden Castle from England's 1 m ground model. The card at the top says what the agent does next, why, and what follows.</sub></td>
    <td width="50%"><img src="docs/images/record.png" alt="A find's record at Angel Mounds with its relief, its slice, and the checks: in the ground, second opinion, open maps, what is published"><br><sub><b>A record.</b> Each find with its relief, its slice and every check.</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/images/toolbox.png" alt="The Toolbox on the Check stage of a real search at Cahokia: a line dragged across Monks Mound and the slice it cuts drawn beside it"><br><sub><b>Toolbox.</b> One real search at Cahokia in six stages, each a picture to press or drag. Here a line across Monks Mound draws its slice.</sub></td>
    <td width="50%"><img src="docs/images/open-data.png" alt="The Open data tab: a map of the world showing where open lidar reaches, and a tile for each service with its status"><br><sub><b>Open data.</b> Where each kind of data reaches, and a page for every service the tools read.</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/images/workflows.png" alt="The Workflows tab: three lanes for the agent, a second model and you, with the eight parts of a search in order"><br><sub><b>Workflows.</b> Who does each part of a search, and where the open project stands.</sub></td>
    <td width="50%"><img src="docs/images/how-it-runs.png" alt="Settings, How it runs: you, the model, the engine and the tools in a row, each with its state and one button"><br><sub><b>How it runs.</b> You, the model, the engine and the tools, each with its state now.</sub></td>
  </tr>
</table>

**Also in the app:** a ten-minute first project at Serpent Mound, a chat with `/` commands, `@` mentions and ⌘K, any model through the [OpenCodex](https://github.com/lidge-jun/opencodex) router (so a different maker's model can give the second opinion), three colour looks and five text sizes.

## Get started

You need an Apple silicon Mac with macOS 14 or later, [Codex](https://github.com/openai/codex) signed in, and [uv](https://docs.astral.sh/uv/).

~~~sh
git clone https://github.com/chrissotraidis/dighouse.git
cd dighouse/app
./scripts/bundle.sh          # builds app/build/Dighouse.app
open build/Dighouse.app
~~~

The first launch walks through setup and builds the tools' Python environment, which takes about a minute. Dighouse runs the newest copy of Codex it finds on the Mac, including the one inside the Codex app, because providers refuse newer models to an older engine. It was last checked with Codex 0.167.

**Use the tools without the app.** They are a Model Context Protocol server:

~~~sh
cd dighouse
uv sync
codex mcp add dighouse -- uv run --directory "$PWD" dighouse-tools
~~~

Then start a chat in an empty folder and ask the agent to follow [skills/dighouse/SKILL.md](skills/dighouse/SKILL.md).

**Tests.**

~~~sh
uv run pytest            # offline, on a synthetic survey (19 tests)
uv run python scripts/smoke_test.py   # one tile end to end against the real services, about a minute
uv run pytest -m live    # the same chain against the real data services (8 tests)
~~~

## The tools

| Stage | Tools |
|---|---|
| Choose where to look | `find_place`, `open_surveys`, `survey_area`, `find_gaps`, `open_resources`, `search_records` |
| Set up | `init_project` |
| Fetch open lidar, or use your own | `find_data`, `fetch_terrain`, `import_terrain` |
| Draw the bare ground | `view_terrain`, `make_tiles`, `render_tiles`, `next_tiles`, `view_tile` |
| Look at every tile | `record_verdict`, `flag_candidate`, `find_mounds` |
| Check each find | `cut_section`, `second_look`, `check_modern`, `add_control` |
| Test the method on a known site | `list_tests`, `start_test`, `score_test`, `calibration_site`, `start_calibration`, `record_calibration` |
| A quick look at one place | `quick_look` |
| Know what to look for | `feature_guide` |
| Search what is published | `search_literature`, `read_source`, `log_source` |
| Records and runs | `add_evidence`, `suggest_decision`, `set_status`, `list_candidates`, `run_status`, `write_summary`, `write_report`, `document_project`, `export_finds` |

The ground is drawn as `composite`, `hillshade`, `local_relief` and `sky_view`. Tool names keep the project's older words (candidate, section, second look). `export_finds` writes GeoJSON for QGIS, ArcGIS or Google Earth, under `private/` because it holds coordinates.

## Open data

Everything Dighouse reads is public, and none of it needs an account or a key.

| Service | What Dighouse reads |
|---|---|
| [OpenTopography](https://portal.opentopography.org/datasets) | The catalog of lidar surveys, including ones flown for archaeology, and their raw points |
| [USGS 3DEP](https://registry.opendata.aws/usgs-lidar/) | Raw lidar points for most of the United States |
| [Environment Agency](https://environment.data.gov.uk/survey) | England's 1 m ground model |
| [AHN](https://www.ahn.nl/) | The Netherlands' 0.5 m ground model |
| [IGN LiDAR HD](https://geoservices.ign.fr/lidarhd) | France's 0.5 m ground model |
| [Digitaal Vlaanderen](https://www.vlaanderen.be/digitaal-vlaanderen) | Flanders' 1 m ground model |
| [Kartverket](https://hoydedata.no) | Norway's 1 m ground model |
| [Estonian Land Board](https://geoportaal.maaamet.ee/eng/Spatial-Data/Elevation-data-p308.html) | Estonia's 1 m ground model |
| [swisstopo](https://www.swisstopo.admin.ch/en/height-model-swissalti3d) | Switzerland's 0.5 m ground model |
| [IDENA](https://idena.navarra.es) | Navarre's 2 m ground model, from the Government of Navarre (the only part of Spain so far) |
| [Bavarian Surveying Administration](https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=dgm1) | Bavaria's 1 m ground model |
| [GeoSN](https://www.geodaten.sachsen.de/downloadbereich-digitale-hoehenmodelle-4851.html) | Saxony's 1 m ground model |
| [Toitū Te Whenua LINZ](https://registry.opendata.aws/nz-elevation/) | New Zealand's 1 m ground model, where it has been flown |
| [Dataforsyningen](https://dataforsyningen.dk/data/930) | Denmark's 0.4 m ground model, with a free token pasted in Settings |
| [Fund og Fortidsminder](https://www.kulturarv.dk/fundogfortidsminder/) | Denmark's national register of ancient monuments, for checking a find |
| [IDENA heritage layer](https://idena.navarra.es) | Navarre's register of protected archaeological sites, for checking a find |
| [OpenStreetMap](https://www.openstreetmap.org/) | Mapped sites through [QLever](https://qlever.dev/); roads and buildings near a find through Overpass, or OpenStreetMap's own map service when Overpass is down |
| [Wikidata](https://www.wikidata.org/) | Archaeological sites already on record |
| [Pleiades](https://pleiades.stoa.org/) | About 35,000 located ancient places |
| [National Register of Historic Places](https://www.nps.gov/subjects/nationalregister/) | Historic places in the United States |
| [Open Context](https://opencontext.org/) | Published excavation and survey records |
| [OpenAlex](https://openalex.org/) and [Crossref](https://www.crossref.org/) | The literature search. Without a key, OpenAlex allows about 100 searches a day for each network address, and Crossref takes over past that |

Historic aerial photographs, declassified CORONA imagery, and the lidar of Denmark, Finland and Sweden need an account or a key, so the tools name them as out of reach. Scotland, Wales, Slovenia, Spain, Poland and Luxembourg were tried and are not read yet; the Open data tab says why for each.

## Rules the tools enforce

These live in the tools, so they hold whichever model is running.

- A tile with too little ground data is marked unreadable and cannot be given a verdict.
- A find cannot be marked as in the ground without a slice that shows it there.
- The second opinion must come from a different model than the one that marked the find.
- A find cannot be marked as having no match in what is published until a slice, a second opinion, a map check and at least one read source are on its record, and a named person makes that call.
- Nothing is ever called new. A record says how many sources were read and that none matched.
- Locations are stored only under `private/`. Records, notes and run summaries carry no coordinates, because published coordinates invite looting.

## Responsible use

- **Do not visit or dig.** A find is a desk result. Digging or metal-detecting on a site destroys what it holds, and in many places it is illegal without a permit.
- **Report, do not post.** Send a find to the heritage authority (in the United States, the state historic preservation office; in England, the local Historic Environment Record), not to social media. Published locations invite looting.
- **Think of the people connected to a place.** Many sites, including the mound sites in the tests above, matter to descendant communities. Consult them before anything is made public.
- **Keep locations private.** Dighouse keeps coordinates under `private/`. Export for mapping software writes a GeoJSON file there too; that file holds locations, so treat it as you would the site itself.

## A project is a folder

~~~
my-project/
  RESEARCH.md     the research record: everything looked at, read and decided, and what is left
  PROJECT.md      the question and the rules agents follow
  METHODOLOGY.md  how the search and the record are kept, and lessons learned here
  candidates/     one Markdown record per find, with its pictures
  notes/          a dated log, run summaries, and record.json (what was looked at, without locations)
  sources/        what was read, what could not be opened, and pages you saved
  reports/        the search report, and drafts for the heritage authority
  data/           downloaded points, ground models, tiles (not versioned)
  private/        locations, exports and run state (not versioned)
~~~

Markdown is the record of truth, so a project works offline and can be handed to an archaeologist like any folder. Each project keeps its own git history without `data/` or `private/`. Dighouse rebuilds `RESEARCH.md` whenever a run ends, a person decides or the project is opened, and the agent reads it before it starts, so work adds up instead of starting over.

**Handing a project over.** File › Export Project makes a zip without `data/` or `private/`, so it holds no locations. The other person opens the folder, the record shows every tile and what it showed as earlier work, and one button, Carry on, picks up what is left.

## Status and limits

The app and the tools in this README work today, and the run logs say exactly what was checked in the running app and what was not: [TEST_LOOP.md](docs/TEST_LOOP.md) is the newest, after [REFINE_LOOP.md](docs/REFINE_LOOP.md), [POLISH_LOOP.md](docs/POLISH_LOOP.md), [USABILITY_LOOP.md](docs/USABILITY_LOOP.md), [NEXT_LOOP.md](docs/NEXT_LOOP.md) and [GOAL_LOOP.md](docs/GOAL_LOOP.md).

- There is no notarized download yet.
- A vision model's eye is the weak point of any search; the benchmarks above show where it is weak. The checks exist because a model marks shapes that are not there, and misses some that are.
- Open services go down and rate-limit. The tools say "could not check" rather than guess.

What comes next, including a second field for open astronomy, is in the [roadmap](docs/ROADMAP.md). The design is in [concept.md](docs/concept.md) and the state of the work in [HANDOFF.md](docs/HANDOFF.md).

## Contributing

Issues and pull requests are welcome. The tools are plain Python in `src/dighouse` with offline tests; the app is SwiftUI in `app/Sources/Dighouse`. A new national ground model is a good first contribution: see how `national.py` reads the seven there now. Please keep the rules above intact, and never put coordinates of a find in an issue.

**AI disclosure.** Dighouse was built with substantial AI assistance for code, tests, documentation and debugging. There is no audited share of AI-written code; the run logs state what was checked and how.

## Acknowledgements

Dighouse stands on open data published by the agencies and projects in the table above, on the [Codex](https://github.com/openai/codex) engine, and on [OpenCodex](https://github.com/lidge-jun/opencodex) for model routing. Lidar is read with [laspy](https://laspy.readthedocs.io/) and [rasterio](https://rasterio.readthedocs.io/).

## Licence

Apache 2.0, matching the Codex engine.
