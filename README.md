# Dighouse

Dighouse is an open-source project for finding archaeological sites in open data with AI agents. This repository holds its first part: a tool server that gives any agent harness the archaeology tools, plus the project format the tools write to. The design for the full desktop app is in [docs/concept.md](docs/concept.md).

The tools speak the Model Context Protocol, so they work in Codex, Claude Code and other harnesses today.

## The app

`app/` holds Dighouse for macOS: a native app that runs the Codex engine with these tools attached. It has a chat with the agent, a map of the bare-ground tiles, the candidate records with their checks, and an Explore page of starting points.

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
| Set up | `init_project` |
| Find and fetch open lidar | `find_data`, `fetch_terrain` |
| Look at the bare ground | `view_terrain`, `make_tiles`, `next_tiles`, `view_tile` |
| Screen | `record_verdict`, `flag_candidate` |
| Check each flag | `cut_section`, `second_look`, `check_modern` |
| Prior art | `search_literature`, `log_source` |
| Records and run | `add_evidence`, `set_status`, `list_candidates`, `add_control`, `run_status` |

Data comes from two public sources that need no account: [OpenTopography](https://portal.opentopography.org/datasets)'s bulk datasets and the [USGS 3DEP](https://registry.opendata.aws/usgs-lidar/) point clouds.

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

Working: everything in the table above, and the macOS app. Not built yet: bulk screening through a model router, pushing records to Notion from the app, a notarized download, and sections that show canopy for datasets published as ground points only.

## Licence

Apache 2.0.
