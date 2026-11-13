<p align="center">
  <img src="docs/images/icon.png" alt="Dighouse app icon: a mound drawn in lidar dots of soil brown, tan and green" width="128" height="128">
</p>

<h1 align="center">Dighouse</h1>

<p align="center">
  <strong>Open archaeology on your Mac.</strong><br>
  AI agents search public lidar for places people built, check every find, and keep a record an archaeologist can trust. You make the calls.
</p>

<p align="center">
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-0A84FF?logo=apple">
  <img alt="Native SwiftUI app" src="https://img.shields.io/badge/app-SwiftUI-FF9F0A?logo=swift&logoColor=white">
  <img alt="Python 3.11 or later" src="https://img.shields.io/badge/tools-Python%203.11%2B-3776AB?logo=python&logoColor=white">
  <img alt="30 tools over the Model Context Protocol" src="https://img.shields.io/badge/MCP-30%20tools-8B5E3C">
  <img alt="Runs the Codex engine" src="https://img.shields.io/badge/engine-Codex%20app--server-5E5CE6">
  <img alt="Any model through OpenCodex" src="https://img.shields.io/badge/models-any%2C%20via%20OpenCodex-5E5CE6">
  <img alt="Open lidar from four countries" src="https://img.shields.io/badge/lidar-US%20%C2%B7%20England%20%C2%B7%20NL%20%C2%B7%20France-6B8E23">
  <img alt="No account or key needed for any data service" src="https://img.shields.io/badge/data%20accounts-none-30D158">
  <img alt="Locations stay on your Mac" src="https://img.shields.io/badge/locations-stay%20on%20your%20Mac-30D158">
  <a href="LICENSE"><img alt="Apache 2.0 licence" src="https://img.shields.io/badge/licence-Apache%202.0-8E8E93"></a>
  <img alt="Not notarized yet" src="https://img.shields.io/badge/notarized-not%20yet-FFD60A">
</p>

<p align="center">
  <a href="#build-and-run"><b>Build and run</b></a> ·
  <a href="#how-a-search-works">How a search works</a> ·
  <a href="#the-tools">The tools</a> ·
  <a href="#open-data">Open data</a> ·
  <a href="#the-rules-the-tools-enforce">Rules</a> ·
  <a href="#status">Status</a>
</p>

![A whole search at Angel Mounds, Indiana: the agent's run summary and what it needs from the person on the left, five flagged candidates on the bare-ground map on the right](docs/images/angel-mounds-run.png)

<sub>A search at Angel Mounds, Indiana, from open USGS lidar. The agent screened 9 tiles, flagged 5 candidates, cut a section through each and searched the literature, then stopped for the second look and the decisions.</sub>

**AI disclosure:** Dighouse uses substantial AI assistance for code, tests, documentation, debugging and maintenance. There is no audited percentage of AI-generated code; the [run logs](docs/NEXT_LOOP.md#log) state what has actually been checked and how.

> [!IMPORTANT]
> **Dighouse is not a download yet.** You build it from source on your own Mac. The build is signed for local use only and is not notarized. The tools work today, in the app or in any harness that speaks the Model Context Protocol.

## Why

In November 2026 Pietro Miotti let AI agents screen about 1,200 km² of NASA lidar overnight, and they flagged a Maya site. It turned out to be already published. Finding candidates was cheap; checking them was the part that failed.

Dighouse is built around the check. Every flag gets a slice through the raw laser points, a second opinion from a different model, a look at open maps for roads and buildings, and a search of what is published. The tools refuse a status the evidence does not support, and nothing is ever called new. A person makes the last call.

A dig house is the building where an excavation team lives, works and keeps its records. The app plays the same role for a search.

## How a search works

<p align="center">
  <img src="docs/images/treetops-to-ground.gif" alt="Serpent Mound, Ohio: a handle sweeps across the picture, taking the trees away to show the winding mound on the bare ground beneath" width="720">
</p>

<p align="center"><sub>Serpent Mound, Ohio, from open USGS lidar. Lidar sees through the gaps in the trees; Dighouse keeps only the ground returns.</sub></p>

1. **Choose where to look.** Ask "What should I research?" and the agent compares open lidar with what is already on record and proposes three searches. Or pick an area on a map and see which open lidar covers it.
2. **Bare ground.** The tools download the raw laser points (or a national ground model), keep the ground returns and build relief, slope, local relief and sky-view pictures of the terrain.
3. **Screen.** The terrain is cut into tiles and agents look at every one, in two styles. A tile with too little ground data is marked unreadable, never "nothing found".
4. **Check.** Each flag gets a section through the raw points, a second look from a different model, and a check for modern features and mapped sites nearby.
5. **Read.** The agent searches the literature and Open Context, opens what it can, and logs every source as read, could not open, or not relevant. Pages that refuse a program can be opened by you in the Sources tab and handed to the agent.
6. **Record.** Every candidate is a Markdown page with its pictures, measurements, checks and sources. You decide what it is, and your name and reason go into the record.

## The app

`app/` holds Dighouse for macOS: a native SwiftUI app that runs the [Codex](https://github.com/openai/codex) engine with the archaeology tools attached. If the [OpenCodex](https://github.com/lidge-jun/opencodex) router is running, every model in its roster appears in the model menu, so a different maker's model can give the second opinion.

<table>
  <tr>
    <td width="50%"><img src="docs/images/home.png" alt="Home: drag between treetops and bare ground at Serpent Mound, a message box, and two ways in"><br><sub><b>Home.</b> Drag between the treetops and the bare ground, ask about a place, or take one of two ways in.</sub></td>
    <td width="50%"><img src="docs/images/new-project.png" alt="New project at Mound City Group: name, question, a search area drawn on the map, and the open lidar that covers it"><br><sub><b>New project.</b> Place the search area on the map and see which open lidar covers it before you start.</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/images/maiden-castle.png" alt="Maiden Castle in England from Environment Agency lidar: the agent describes the ramparts and entrances beside the tiled map"><br><sub><b>A project.</b> Maiden Castle from the Environment Agency's 1 m ground model. The agent reads the ramparts and both entrances from the views.</sub></td>
    <td width="50%"><img src="docs/images/record.png" alt="A candidate record at Angel Mounds with its relief, its section, and checks for ground returns, a second look and modern features"><br><sub><b>Records.</b> Each candidate with its relief, its section and every check. The decision is yours.</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/images/toolbox.png" alt="The Toolbox walking through the Check stage of a real search at Cahokia, with the section through Monks Mound"><br><sub><b>Toolbox.</b> One real search at Cahokia in six stages, each with its tools and a Run button.</sub></td>
    <td width="50%"><img src="docs/images/open-data.png" alt="The Open data tab: OpenTopography and USGS 3DEP cards with pictures made from their data and a live status"><br><sub><b>Open data.</b> Every service the tools read, what Dighouse takes from it, and whether it answers right now.</sub></td>
  </tr>
</table>

- **Chat** works with or without a project. It shows the agent's plan, each step it takes, helper agents, and long runs folded into one line. One control picks the model and its thinking effort, and the message box takes images, video, audio and other files.
- **A project** puts a workspace beside the chat: the map of tiles with candidates on it, the records, the project's notes, and its sources with a browser to open them. The dividers drag.
- **Settings** explains in plain words how the model, the agent engine, the tools and the optional router fit together. It has three colour looks (Earth, the default, is the soil brown, tan and green of the icon), a Test button for each model that marks which ones answered, and a page on what data goes where.

## Build and run

You need an Apple silicon Mac with macOS 14 or later, [Codex](https://github.com/openai/codex) (tested with 0.146.0) signed in, and [uv](https://docs.astral.sh/uv/).

~~~sh
git clone https://github.com/chrissotraidis/dighouse.git
cd dighouse/app
./scripts/bundle.sh          # builds app/build/Dighouse.app
open build/Dighouse.app
~~~

The first launch walks through setup and builds the tools' Python environment by itself, which takes about a minute.

### Use the tools without the app

The tools are a Model Context Protocol server, so they also work in Codex or any other harness that speaks MCP.

~~~sh
cd dighouse
uv sync
codex mcp add dighouse -- uv run --directory "$PWD" dighouse-tools
~~~

Then start a chat in an empty folder and ask the agent to follow [skills/dighouse/SKILL.md](skills/dighouse/SKILL.md).

### Tests

~~~sh
uv run pytest            # offline, on a synthetic survey (4 tests)
uv run pytest -m live    # the same chain against the real data services (8 tests)
~~~

## The tools

| Stage | Tools |
|---|---|
| Choose where to look | `find_place`, `open_surveys`, `survey_area`, `find_gaps`, `open_resources`, `search_records` |
| Set up | `init_project` |
| Find and fetch open lidar, or use your own | `find_data`, `fetch_terrain`, `import_terrain` |
| Look at the bare ground | `view_terrain`, `make_tiles`, `render_tiles`, `next_tiles`, `view_tile` |
| Screen | `record_verdict`, `flag_candidate` |
| Check each flag | `cut_section`, `second_look`, `check_modern`, `add_control` |
| Prior art | `search_literature`, `read_source`, `log_source` |
| Records and run | `add_evidence`, `set_status`, `list_candidates`, `run_status`, `write_summary`, `export_finds` |

Terrain renders in four styles: `composite`, `hillshade`, `local_relief` and `sky_view`. `export_finds` writes the candidates as GeoJSON for QGIS, ArcGIS or Google Earth, under `private/` because it holds coordinates.

## Open data

Everything Dighouse searches is public, and none of it needs an account or a key.

| Service | What Dighouse reads |
|---|---|
| [OpenTopography](https://portal.opentopography.org/datasets) | The catalog of lidar surveys, including ones flown for archaeology, and their raw points |
| [USGS 3DEP](https://registry.opendata.aws/usgs-lidar/) | Raw lidar points for most of the United States |
| [Environment Agency](https://environment.data.gov.uk/survey) | England's 1 m lidar ground model |
| [AHN](https://www.ahn.nl/) | The Netherlands' 0.5 m ground model |
| [IGN LiDAR HD](https://geoservices.ign.fr/lidarhd) | France's 0.5 m ground model |
| [OpenStreetMap](https://www.openstreetmap.org/) | Mapped sites and modern features, through [QLever](https://qlever.dev/) with Overpass as the fallback |
| [Wikidata](https://www.wikidata.org/) | Archaeological sites already on record |
| [Pleiades](https://pleiades.stoa.org/) | About 35,000 located ancient places |
| [National Register of Historic Places](https://www.nps.gov/subjects/nationalregister/) | Historic places in the United States |
| [Open Context](https://opencontext.org/) | Published excavation and survey records |
| [OpenAlex](https://openalex.org/) | The literature search |

Historic aerial photographs, declassified CORONA imagery and Denmark's lidar need an account, so the tools name them as out of reach.

## The rules the tools enforce

These are built into the tools, so they hold whichever model is running.

- A tile with too little ground data is marked unreadable and cannot be given a verdict.
- A candidate cannot be marked as a ground feature without a section that shows it in the ground returns.
- The second look must come from a different model than the one that raised the flag.
- A candidate cannot be marked as having no match in the literature until a section, a second look, a modern-feature check and at least one read source are on its record, and a named person makes that call. Sources that could not be opened are written into the decision.
- Nothing is ever called new. A record says how many sources were read and that none matched.
- Locations are stored only under `private/` in the project folder. Records, notes and run summaries carry no coordinates, because published coordinates invite looting.

## A project is a folder

~~~
my-project/
  PROJECT.md      the question and the rules agents follow
  candidates/     one Markdown record per candidate, with its images
  notes/          a dated log the tools write as work happens, and run summaries
  sources/        what was read, what could not be opened, and pages you saved
  reports/        drafts for the heritage authority
  data/           downloaded points, ground models, tiles (not versioned)
  private/        locations, exports and run state (not versioned)
~~~

Markdown is the record of truth, so a project works offline and can be shared, versioned or handed to an archaeologist like any folder.

## Checked against known sites

Finding a known site again is the right answer for a test.

- **Cahokia, Illinois.** The control run measured Monks Mound at 27.6 m high in its section, with 79 ground returns within 5 m of its peak, and the map check found the paths and stairs on it.
- **Angel Mounds, Indiana.** A run flagged five mounds. The largest, C-001, matches the published description of Mound A in the sources the agent read, and a second model agreed it looks built.
- **Maiden Castle, England.** From the Environment Agency's ground model, the agent described the four lines of rampart and both entrances.
- **Mound City Group, Ohio.** A run counted 22 mounds inside the enclosure from the lidar; the thesis it read gives 24, and it matched the hollows outside the wall to the published borrow pits.
- **Perry Mesa, Arizona.** Proposed by "What should I research?", it built into 66 readable tiles at 4 ground returns per square metre.

## Status

Working: everything in the tables above, and the macOS app as shown. The run logs in [docs/NEXT_LOOP.md](docs/NEXT_LOOP.md) and [docs/GOAL_LOOP.md](docs/GOAL_LOOP.md) say what was checked in the running app and what was not.

Not built yet: the agent driving a browser of its own, bulk screening through the model router, a button that pushes records to Notion, a notarized download, and sections that show canopy for datasets published as ground points only. The design is in [docs/concept.md](docs/concept.md), and the state of the work is in [docs/HANDOFF.md](docs/HANDOFF.md).

## Licence

Apache 2.0, matching the Codex engine.

