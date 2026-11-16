---
name: dighouse
description: Run an archaeological search over open lidar with the Dighouse tools. Use when asked to search an area for unrecorded sites, look at tiles of bare ground, check a find, or continue a Dighouse project.
---

# Running a Dighouse search

Work inside one project folder and pass its absolute path to every tool. Each project is its own folder and git repository; the section "How this project is kept" in its PROJECT.md says which file holds what and where to write. Read `RESEARCH.md` first: it is the project's research record, listing the data used, every tile looked at and its verdict, every find's checks and decision, every source and literature search, and what is still to do. Build on it; do not redo work it lists unless you say why (a better survey, another view, a source that has since become readable). Then read `METHODOLOGY.md` (the project's method: follow it) and the newest run summary, so a run continues where the last one stopped. When a run teaches something the next run should know, such as a survey that builds badly or a kind of shape that fools the eye common here, add a dated line under Lessons in `METHODOLOGY.md`.

Begin your first message in a project by saying, in a sentence or two, what the research record shows is already done, and then what you will do now. The person may be new to the project and should not have to ask.

A project can be handed from one person to another. The downloads and the locations stay on the first Mac; the record of what was looked at and read travels. So if `RESEARCH.md` lists tiles as "earlier" and says the project was handed over, that ground has been looked at: do not fetch or look at it again unless the person asks to look at it themselves. Carry on from "Still to do": sources that could not be opened, checks that need no location, decisions and the report. A wider or different area needs the person to say where, because locations are never shared.


## Words

Write to the person in the app's words, in chat, notes, summaries and reasons. Tool names keep their older words; do not show a tool name to the person unless they ask.

- A shape you marked is a **find**. Not a flag, not a candidate.
- A cut straight down through the laser points is a **slice**. Not a section. Say what a slice is the first time you use the word.
- You **look at** tiles. Not screen.
- Another model gives a **second opinion**. Not a second look.
- The bare-ground model is **the ground**. Not terrain.

## Keeping the record

Other people, many of them new to archaeology, and other agents will continue this work from what you leave. Novel research depends on knowing what was already looked at and read, so every step has to leave a trace:

- Record a verdict for every tile you look at, including nothing and natural. A blank result is still a result.
- Log every source you find as read, could not open, or not relevant, with what it says about this place, even when it says nothing.
- Literature searches are logged by the tool; search with specific queries so the log is useful to the next person.
- When you learn something about this place or this survey, add it under Lessons in `METHODOLOGY.md`.
- End with `write_summary`. It rebuilds `RESEARCH.md`; call `document_project` yourself after other work the record should show, and read the "still to do" it returns.
- When you were asked to report back, call `write_report` after `write_summary`. It builds the search report from the records, so it can say only what they hold: finish the records first. Pass as advice two or three plain sentences on what you would try next.

## Blind tests

A blind test checks the method on a known site whose features are published. `run_status` shows `blind_test` when a project is one.

- Do not try to work out where you are or what the site is. Do not search the literature, read sources, or look up records for the area: the tools refuse until the test is scored, and guessing the name spoils the score.
- Work as usual otherwise: fetch the ground with what `find_data` offers (a fetch can take ten minutes; it returns on its own, so wait for it and do not stop the run while it works), look at every tile in two renderings, mark a find for each thing that looks built (one per feature, not one per group, so each mound gets its own find), and slice each find. The score measures the looking, so a second opinion is not needed before `score_test`; in the app Dighouse asks the second model itself.
- Then call `score_test`. It says what was found, missed and extra against the published answer key, and opens the literature.
- After scoring, search what is published for each extra find and call `suggest_decision` on it, so the scorecard can say which extras are false alarms and which are worth a second look. Then write the summary and the report.

## Calibration before a search for something new

Before searching an area where nothing is on record, prove the method works on this kind of lidar.

1. `start_calibration` with a folder beside the project, the project, and the dataset `find_data` offers. It starts a blind test on the nearest known site with lidar from the same source, without telling you which; do not try to work it out.
2. Run that test blind to `score_test`, exactly as a blind test. (`calibration_site` names the site, for proposals to a person; do not call it for a project you are about to calibrate.)
3. `record_calibration` on the search project with the test's folder.
4. If it passed, search as usual and say the calibration score in the summary. If it failed, `flag_candidate` refuses: say plainly that the method found too little on the known site to trust it here, and suggest another survey, view or area.

When `flag_candidate` returns `already_on_open_record_nearby`, check that site first: the find is probably already published, so search the literature for it before the slice and the second opinion.

## Choosing where to look

When there is no project yet, help the person choose one. Ask what region, period or kind of site interests them, unless they already said.

- `open_surveys` lists open lidar flown with archaeology in mind. Prefer ones with a `checked_start`, which were fetched and built into bare ground in testing, and leave out any with a `known_problem`.
- `find_place` turns a place name into an area.
- `survey_area` shows which open lidar covers an area and which sites are already recorded there.

Offer two or three areas, each with what lidar covers it, what is already recorded, and what a search could add. Areas with open lidar and few recorded sites add most. A published site is a good first project for someone learning. When the person picks one, make it a project with a box under 6 square km. In the Dighouse app, call `suggest_project` with the name, the question, why this area and the box: the person presses Make this a project and this chat moves into it. Elsewhere, or when the person asks you to create it yourself, call `init_project` with a new folder name; it goes in the projects folder.

## When someone asks what to research

Do not answer from memory alone. Work it out from the open data, then add what you know about archaeology.

1. `open_resources` shows which archives exist, how big they are, and which of them these tools read. Say plainly what is out of reach.
2. `open_surveys` lists lidar flown for archaeology. Searching one of these feature by feature against what its authors published is the most useful work for a beginner.
3. For a region the person cares about, `find_place` then `find_gaps` ranks its parts by open lidar and by how few sites are on open record. `search_records` shows what excavations have published there.
4. Use what you know: which cultures built in earth or stone that survives as relief (mounds, enclosures, terraces, field systems, causeways, hillforts), which landscapes hide it under forest, and which regions are known to be under-surveyed. Lidar finds shapes in the ground. It does not find scatters of pottery or buried deposits.

Offer three concrete searches. For each give the place, the lidar that covers it, what is on open record there and from which sources, what kind of feature to expect, and what a search could add. Say what the open record cannot show: official site files are not public, so a gap in the list is a place to check, never proof that nothing is known.

Only propose lidar that is known to build. That means an `open_surveys` entry with a `checked_start`, or USGS 3DEP inside the United States as listed by `find_data` for the area. Never propose a survey with a `known_problem`, and do not offer one that is fetchable but untested as if it were ready: name it as untested if you mention it at all.

When the person picks one, make it a project as above (for a tested survey, use its `checked_start` box or a box around it under 6 square km). Once the project exists, call `fetch_terrain` straight away and report how many ground returns per square metre came back. If it fails or comes back nearly empty, say so plainly and offer the next proposal.

## Working with other agents

- When more than 12 tiles need looking at, hand batches of about 8 tile ids to sub-agents. Tell each to view every tile in two styles and record a verdict, and to mark nothing: marking finds stays with you so one feature gets one record.
- The second opinion is never yours. The person asks a different model for it from the find's record.
- Keep a plan and update it as stages finish, so the person can see where the run stands.

## The loop

Finish what you start. Budget the run so the prior-art step and the summary always happen: if web searches or time run short, log what you have and write the summary before anything else. A run that stops with finds and no logged sources leaves the person nothing to act on.

1. **Plan.** Call `run_status`. If there are tiles nobody has looked at, carry on with them. If not, pick the next part of the search area.
2. **Acquire.** `find_data` for the area, then `fetch_terrain` in boxes under 6 square km. If `find_data` offers a seafloor survey, the area is under water: fetch that survey, not the land lidar. A fetch can take ten minutes for a small area when the archive is slow; it returns on its own, so wait for it rather than concluding it failed. Read the dataset description: it names earlier studies of the same data. Write those down as the first sources to read.
3. **Prepare.** `make_tiles`. Unreadable tiles stay unreadable. Report how many there are.
   Then look at the whole area once with `view_terrain` in `sky_view` and in `hillshade`. Tiles are 250 m, so a fort, an enclosure or a rampart larger than about 100 m is cut into pieces that each look like a ditch or a field edge. Note every bank or ditch that closes on itself, square or round, and roughly where it is; when you reach its tiles, mark it once, with the point on the bank or ditch itself where it shows most clearly, never in the middle of the enclosure.
4. **Look.** Call `feature_guide` once before the first tile and use it. For each tile from `next_tiles`: `view_tile`, look, then `record_verdict` with the name of the model that looked. Use a second style (`local_relief`, `sky_view` or `hillshade`) before deciding on anything doubtful. `sky_view` shows ditches and low banks whatever their direction, where a hillshade can hide a bank that runs parallel to the light.
   Then call `find_mounds` on the tile: it measures round rises a picture hides. Look at each numbered spot in its picture and decide; most are not built.
   On the seafloor (a NOAA survey), the ground is depth below the chart datum: look for wrecks, their scour pits and debris, using the seafloor part of the feature guide. Call the shapes seafloor and wreck, never ground.
5. **Mark finds.** `flag_candidate` for anything that looks built, one record per feature: each mound gets its own find, while a rampart, enclosure or field system is one find. Start the note with the guide entry it matches ("Guide: burial mound."), or "Guide: no entry" with a description.
6. **Check every find.**
   - `cut_section` across the feature, starting and ending on the surrounding ground, with the find id.
   - `second_look` from a different model, shown the tile without the first model's note.
   - `check_modern`.
7. **Prior art.** `search_literature`, starting with the dataset's own name and the studies its description cites, then the region and site type. Open the promising ones with `read_source`. `log_source` each one as read, could not open, or not relevant, with what it shows about this place. Log a source as soon as you know its outcome, one at a time, so a run that stops early still leaves its sources on the record. When one source bears on several finds, pass their ids together, or "all". A source you know only from its abstract is logged as could not open, with what the abstract says.
8. **Record.** `add_evidence` for measurements. `set_status` only as far as the checks support.
9. **Summarise.** End every run, finished or not, with `write_summary`: what was done, what each find's checks show, the sources read and not opened, what is left, and what waits for the person.
10. **Suggest each decision.** For every open find, call `suggest_decision` with the decision the evidence points to and a reason the person can check in one read: for already published, where (author, year, title or record id); for modern or natural, what shows it. Suggest "no match in sources read" only when the checks and sources support it. The person's review opens with these filled in.
11. **Stop for the person** when `run_status` lists anything under `needs_a_person`, when controls are being missed, or when data needs an account.

## What built ground looks like

Straight edges, right angles, flat rectangles, evenly spaced low platforms, mounds with regular outlines, raised courtyards, and long straight raised lines. Groups matter more than single shapes.

Usually not built: sinkholes (round pits), rock outcrops (irregular, rough), stream channels (branching), ridges that follow the lie of the land.

Usually modern: roads and tracks (long, even width, connected), field boundaries, quarries, drainage ditches, building pads beside a road.

Flat dark grey in a tile means the laser did not reach the ground there. Say so; do not read it as empty.

## Rules

- Never say a site is new, undiscovered or unknown. Say how many sources were read and that none matched.
- Never write coordinates in a message, a Markdown file, or anything pushed to another service. Refer to finds by id.
- A person decides before a find is marked `no_match_in_sources_read` or `reported`. Ask, then pass their name as `decided_by`.
- When pushing records to Notion or elsewhere, push the Markdown record and its images only. Nothing from `private/` or `data/`.
- Cite each dataset the way `find_data` says its publisher asks.
