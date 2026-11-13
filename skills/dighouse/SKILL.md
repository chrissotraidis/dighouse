---
name: dighouse
description: Run an archaeological search over open lidar with the Dighouse tools. Use when asked to search an area for unrecorded sites, screen terrain tiles, check a candidate, or continue a Dighouse project.
---

# Running a Dighouse search

Work inside one project folder and pass its absolute path to every tool. Read `PROJECT.md` and the latest file in `notes/` before doing anything, so a run continues where the last one stopped.

## Choosing where to look

When there is no project yet, help the person choose one. Ask what region, period or kind of site interests them, unless they already said.

- `open_surveys` lists open lidar flown with archaeology in mind. Prefer ones with a `checked_start`, which were fetched and built into terrain in testing, and leave out any with a `known_problem`.
- `find_place` turns a place name into an area.
- `survey_area` shows which open lidar covers an area and which sites are already recorded there.

Offer two or three areas, each with what lidar covers it, what is already recorded, and what a search could add. Areas with open lidar and few recorded sites add most. A published site is a good first project for someone learning. When the person picks one, call `init_project` with a box under 6 square km and a folder inside the projects folder you were given.

## When someone asks what to research

Do not answer from memory alone. Work it out from the open data, then add what you know about archaeology.

1. `open_resources` shows which archives exist, how big they are, and which of them these tools read. Say plainly what is out of reach.
2. `open_surveys` lists lidar flown for archaeology. Searching one of these feature by feature against what its authors published is the most useful work for a beginner.
3. For a region the person cares about, `find_place` then `find_gaps` ranks its parts by open lidar and by how few sites are on open record. `search_records` shows what excavations have published there.
4. Use what you know: which cultures built in earth or stone that survives as relief (mounds, enclosures, terraces, field systems, causeways, hillforts), which landscapes hide it under forest, and which regions are known to be under-surveyed. Lidar finds shapes in the ground. It does not find scatters of pottery or buried deposits.

Offer three concrete searches. For each give the place, the lidar that covers it, what is on open record there and from which sources, what kind of feature to expect, and what a search could add. Say what the open record cannot show: official site files are not public, so a gap in the list is a place to check, never proof that nothing is known.

Only propose lidar that is known to build. That means an `open_surveys` entry with a `checked_start`, or USGS 3DEP inside the United States as listed by `find_data` for the area. Never propose a survey with a `known_problem`, and do not offer one that is fetchable but untested as if it were ready: name it as untested if you mention it at all.

When the person picks one, call `init_project` (for a tested survey, use its `checked_start` box or a box around it under 6 square km), then call `fetch_terrain` straight away and report how many ground returns per square metre came back. If it fails or comes back nearly empty, say so plainly and offer the next proposal.

## Working with other agents

- When more than 12 tiles need screening, hand batches of about 8 tile ids to sub-agents. Tell each to view every tile in two styles and record a verdict, and to flag nothing: flags stay with you so one feature gets one record.
- The second look is never yours. The person asks a different model for it from the candidate's record.
- Keep a plan and update it as stages finish, so the person can see where the run stands.

## The loop

Finish what you start. Budget the run so the prior-art step and the summary always happen: if web searches or time run short, log what you have and write the summary before anything else. A run that stops with candidates and no logged sources leaves the person nothing to act on.

1. **Plan.** Call `run_status`. If there are unscreened tiles, continue screening. If not, pick the next part of the search area.
2. **Acquire.** `find_data` for the area, then `fetch_terrain` in boxes under 6 square km. Read the dataset description: it names earlier studies of the same data. Write those down as the first sources to read.
3. **Prepare.** `make_tiles`. Unreadable tiles stay unreadable. Report how many there are.
4. **Screen.** For each tile from `next_tiles`: `view_tile`, look, then `record_verdict` with the name of the model that looked. Use a second style (`local_relief`, `sky_view` or `hillshade`) before deciding on anything doubtful. `sky_view` shows ditches and low banks whatever their direction, where a hillshade can hide a bank that runs parallel to the light.
5. **Flag.** `flag_candidate` for anything that looks built. One record per feature group.
6. **Check every flag.**
   - `cut_section` across the feature, starting and ending on the surrounding ground, with the candidate id.
   - `second_look` from a different model, shown the tile without the first model's note.
   - `check_modern`.
7. **Prior art.** `search_literature`, starting with the dataset's own name and the studies its description cites, then the region and site type. Open the promising ones with `read_source`. `log_source` each one as read, could not open, or not relevant, with what it shows about this place. Log a source as soon as you know its outcome, one at a time, so a run that stops early still leaves its sources on the record. When one source bears on several candidates, pass their ids together, or "all". A source you know only from its abstract is logged as could not open, with what the abstract says.
8. **Record.** `add_evidence` for measurements. `set_status` only as far as the checks support.
9. **Summarise.** End every run, finished or not, with `write_summary`: what was done, what each candidate's checks show, the sources read and not opened, what is left, and what waits for the person.
10. **Suggest each decision.** For every open candidate, call `suggest_decision` with the decision the evidence points to and a reason the person can check in one read: for already published, where (author, year, title or record id); for modern or natural, what shows it. Suggest "no match in sources read" only when the checks and sources support it. The person's review opens with these filled in.
11. **Stop for the person** when `run_status` lists anything under `needs_a_person`, when controls are being missed, or when data needs an account.

## What built ground looks like

Straight edges, right angles, flat rectangles, evenly spaced low platforms, mounds with regular outlines, raised courtyards, and long straight raised lines. Groups matter more than single shapes.

Usually not built: sinkholes (round pits), rock outcrops (irregular, rough), stream channels (branching), ridges that follow the lie of the land.

Usually modern: roads and tracks (long, even width, connected), field boundaries, quarries, drainage ditches, building pads beside a road.

Flat dark grey in a tile means the laser did not reach the ground there. Say so; do not read it as empty.

## Rules

- Never say a site is new, undiscovered or unknown. Say how many sources were read and that none matched.
- Never write coordinates in a message, a Markdown file, or anything pushed to another service. Refer to candidates by id.
- A person decides before a candidate is marked `no_match_in_sources_read` or `reported`. Ask, then pass their name as `decided_by`.
- When pushing records to Notion or elsewhere, push the Markdown record and its images only. Nothing from `private/` or `data/`.
- Cite each dataset the way `find_data` says its publisher asks.
