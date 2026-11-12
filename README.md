# Dighouse

Dighouse is an open-source project for finding archaeological sites in open data with AI agents. It is an agent harness with archaeology tools built in: a macOS app that runs the Codex engine with any model you have, and a tool server that finds, fetches and reads open lidar and keeps the records. The design is in [docs/concept.md](docs/concept.md), and the current work loop is in [docs/GOAL_LOOP.md](docs/GOAL_LOOP.md).

The tools speak the Model Context Protocol, so they also work on their own in Codex, Claude Code and other harnesses.

## The app

`app/` holds Dighouse for macOS: a native app that runs the Codex engine with these tools attached.

- **Home** opens with a picture you can drag between the treetops and the bare ground at Serpent Mound, a table of what a chat app cannot do, and a real run at Cahokia. It has a message box and two ways in. "Help me choose a place" starts a chat in which the agent compares open surveys with what is already recorded. "I know where to look" opens a map where you place the search area and see which open lidar covers it. Below are open surveys read from OpenTopography's live catalog and published sites to learn on.
- **Chat** works with or without a project. It shows the agent's plan, each step it takes, helper agents, and long runs folded into one line. The message box has one control for the model and its thinking effort, and takes images, video, audio and other files.
- **A project** adds a workspace beside the chat: the map of bare-ground tiles, the candidate records with their checks, and the project's notes. The dividers drag: between the sidebar and the page, and between the chat and the workspace.
- **Toolbox** explains how a search works in six stages, each with its tools and a Run button. It also lists the workflows with who does each part, the open data services and what Dighouse takes from each, and the other tools your Codex setup already has. You can add another tool server there.
- **Settings** is a page in the window. "How it runs" explains the three parts: the AI model, the agent engine, and the archaeology tools. Other pages cover models and thinking effort, and what data goes where.

~~~sh
cd app
./scripts/bundle.sh          # builds app/build/Dighouse.app
open build/Dighouse.app
~~~

It needs [Codex](https://github.com/openai/codex) and [uv](https://docs.astral.sh/uv/) installed. The first launch walks through setup. If the OpenCodex router is running, every model in its roster appears in the model menu.

The build is signed for local use only. It is not notarized, so it is not yet a download for other people.

## What the tools do

| Stage | Tools |
|---|---|
| Choose where to look | `find_place`, `open_surveys`, `survey_area` |
| Set up | `init_project` |
| Find and fetch open lidar | `find_data`, `fetch_terrain` |
| Look at the bare ground | `view_terrain`, `make_tiles`, `next_tiles`, `view_tile` |
| Screen | `record_verdict`, `flag_candidate` |
| Check each flag | `cut_section`, `second_look`, `check_modern` |
| Prior art | `search_literature`, `read_source`, `log_source` |
| Records and run | `add_evidence`, `set_status`, `list_candidates`, `add_control`, `run_status` |

Lidar comes from two public sources that need no account: [OpenTopography](https://portal.opentopography.org/datasets)'s bulk datasets and the [USGS 3DEP](https://registry.opendata.aws/usgs-lidar/) point clouds. Place names and modern features come from OpenStreetMap, recorded sites from Wikidata, and the literature search from OpenAlex.

## The rules the tools enforce

- A tile with too little ground data is marked unreadable and cannot be given a verdict.
- A candidate cannot be marked as a confirmed ground feature without a section that shows it in the ground returns.
- The second look must come from a different model than the one that raised the flag.
- A candidate cannot be marked as having no match in the literature until a section, a second look, a modern-feature check and at least one read source are on its record, and a named person makes that call. Sources that could not be opened are written into the decision.
- Locations are stored only under `private/` in the project folder. Records, notes and anything pushed elsewhere carry no coordinates.

## Install and run

Requires [uv](https://docs.astral.sh/uv/).

~~~sh
git clone https://github.com/chrissotraidis/dighouse.git
cd dighouse
uv sync
uv run pytest            # offline tests on a synthetic survey
uv run pytest -m live    # the same chain against the real data services
~~~

Add the tools to Codex:

~~~sh
codex mcp add dighouse -- uv run --directory /path/to/dighouse dighouse-tools
~~~

Then start a chat in an empty folder and ask the agent to follow [skills/dighouse/SKILL.md](skills/dighouse/SKILL.md).

## A project is a folder

~~~
my-project/
  PROJECT.md      the question and the rules agents follow
  candidates/     one Markdown record per candidate, with its images
  notes/          a dated log the tools write as work happens
  sources/        what was read and what could not be opened
  reports/        drafts for the heritage authority
  data/           downloaded points, ground models, tiles (not versioned)
  private/        locations and run state (not versioned)
~~~

## Checked against a known site

The live test fetches USGS lidar over Monks Mound at Cahokia, Illinois, builds the ground model, and cuts a section through the mound. The tools measure it at about 32 m above the surrounding ground with dense ground returns, and the modern-feature check reports Monks Mound among the historic places already mapped nearby.

## Status

Working: everything in the table above, and the macOS app as described. Not built yet: bulk screening through a model router, a button that pushes records to Notion, a notarized download, and sections that show canopy for datasets published as ground points only.

## Licence

Apache 2.0.
