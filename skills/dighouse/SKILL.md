---
name: dighouse
description: Run an archaeological search over open lidar with the Dighouse tools. Use when asked to search an area for unrecorded sites, screen terrain tiles, check a candidate, or continue a Dighouse project.
---

# Running a Dighouse search

Work inside one project folder and pass its absolute path to every tool. Read `PROJECT.md` and the latest file in `notes/` before doing anything, so a run continues where the last one stopped.

## The loop

1. **Plan.** Call `run_status`. If there are unscreened tiles, continue screening. If not, pick the next part of the search area.
2. **Acquire.** `find_data` for the area, then `fetch_terrain` in boxes under 6 square km. Read the dataset description: it names earlier studies of the same data. Write those down as the first sources to read.
3. **Prepare.** `make_tiles`. Unreadable tiles stay unreadable. Report how many there are.
4. **Screen.** For each tile from `next_tiles`: `view_tile`, look, then `record_verdict` with the name of the model that looked. Use a second style (`local_relief` or `hillshade`) before deciding on anything doubtful.
5. **Flag.** `flag_candidate` for anything that looks built. One record per feature group.
6. **Check every flag.**
   - `cut_section` across the feature, starting and ending on the surrounding ground, with the candidate id.
   - `second_look` from a different model, shown the tile without the first model's note.
   - `check_modern`.
7. **Prior art.** `search_literature`, starting with the dataset's own name and the studies its description cites, then the region and site type. Read what you find. `log_source` each one as read, could not open, or not relevant, with what it shows about this place.
8. **Record.** `add_evidence` for measurements. `set_status` only as far as the checks support.
9. **Stop for the person** when `run_status` lists anything under `needs_a_person`, when controls are being missed, or when data needs an account.

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
