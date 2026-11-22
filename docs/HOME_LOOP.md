# Dighouse goal loop: a project is the home for its work

Written 2026-11-23, after the decide loop. Chris asked for this: a region or project you work on, with its chats inside it. The Log at the end says what was built and checked.

## Why it does not feel right today

- **The biggest searches run outside any project.** "Search on its own" runs in a general chat and makes a new project for every 1 to 2 km² area: one two-hour run made Perry A1, Perry A2, Athens A1, Coshocton A1 and Guernsey A1. None of them has a chat of its own; the conversation that made them sits under Chats. The region the run worked in has no project at all.
- **A chat belongs to a folder, not to a project.** The engine lists chats by the folder they started in. The sidebar is two flat lists, 19 loose chats above 66 projects, and only the open project shows its chats.
- **The overview and a chat take turns in one column.** Nothing shows a project with its chats under it.
- **Chat names say little.** "Prior-art sweep" three times, "Find and report back" in every blind test, prompts cut short. One title holds coordinates ("Use find_gaps on the Middle Usumacinta region (west -91.6, …"), which breaks the rule that locations stay private.

## What was tested first (H0)

With the tools alone, no model: a project in the test folder, two areas about 30 km apart fetched into it (USGS 3DEP, 0.43 km² each, 10 and 13 seconds), each cut into 9 tiles, then opened in the test copy.

| Question | Answer |
|---|---|
| Can one project hold areas far apart? | Yes. Two pieces of ground, 18 tiles, one research record. |
| Does the project's area follow? | No. Its box stays the first area's, so calibration picks a known site near the first area only, and the check that stops a web address carrying the project's location covers only the first area (it caught the second here only because the two were 30 km apart). |
| Does the map show both? | No. "All of it, side by side" leaves out any ground more than 5 km from the first, without a word. The second area is reachable only by its survey name in the menu. |
| Does Pick a place shade what was searched? | It shades the project's box, so a region project would show the whole region as searched. |
| Can a timed session work inside one project? | Its instructions tell it to make a project per area and to keep its record in the general chat folder. |

## The aim

A project is a place you work on, usually a region. It holds its areas of ground, its finds and decisions, and its chats: the run that searched it, a chat that checks one lead, a chat that writes the report. "Search on its own" makes one such project and works inside it.

## Goals

| Goal | What | Check |
|---|---|---|
| H1 | **Areas in one project.** `fetch_terrain` takes an optional area name and keeps each area's box in degrees. The project's box grows to cover every area. A new tool, `name_project`, sets a project's name, question and region box (the folder keeps its name). The map's menu lists areas by name, groups the ground of one area, and says "Show: Perry A1" in place of a silent "All of it". The research record lists the areas. Pick a place shades each area, not the project's box. | Offline tests: the box grows; `name_project` changes the name and question only. In the test copy, the probe project shows both areas by name on the map. |
| H2 | **A project page with its chats.** Under the overview's first card, a Chats list: each chat of the project with what it is doing (searching, until 18:40; stopped; done), and New chat. A chat started in a project is told to read the research record first, so it carries on from it. Titles never show coordinates. | In the test copy, a project with chats lists them, a new chat appears in the list, and the Perry Mesa title shows without coordinates. |
| H3 | **Projects first in the sidebar.** Projects at the top, each with its chats folded under it (from the saved lists, so a closed project shows them too) and a mark when one of its chats is working. Blind tests in their own folded group. Other chats below. No folder is moved or renamed. | Chris's list sorts with no folder touched; his settings match the backup. |
| H4 | **Search on its own lives in one project.** Pressing it makes a project for the session ("Search on its own, 23 Nov") and starts the chat inside it. The agent names it after the region it chooses (`name_project`) and adds every area to it with `fetch_terrain`, named. Calibration tests stay projects of their own, since each is scored against one known site. Second opinions still arrive area by area. | A 20-minute session in the test copy, primary / 6.1 Terra: one project named for its region, its areas named, its chat under it, opinions asked, no other search projects made. |
| H5 | **Hand over.** README, HANDOFF, DESIGN and this log match the app. | Merged, `main` clean, the app rebuilt and running with Chris's settings unchanged. |

## Choices made, for Chris to overrule

1. **Older sessions stay as they are.** Their chats stay under Chats and their small projects stay separate. Merging them would move folders and history, which the plan for the project list ruled out.
2. **A one-area project is still a project.** "Find and report back" from a typed place, New project and Make this a project are unchanged.
3. **Blind tests stay one site per project,** in their own group.
4. **The skill and the feature guide do not change.** The new behaviour is in the timed session's own instructions and in the tools' descriptions, so the blind tests, which use the skill, are not affected. The 20-minute session is the check for H4.

## Log

- **2026-11-23, H0.** Probe above. Plan written.
- **H1, areas in one project.**
  - **Tools.** `fetch_terrain` takes `area` (refused if it looks like coordinates) and keeps each area's box in degrees (`lonlat`, left out of the reply). `Project.grow_area` widens the project's box after every fetch and drops the cached sites on record, so the location guard and calibration follow every area. `name_project` renames the project and its question in `project.json` and PROJECT.md, and can set the region's box; the folder keeps its name.
  - **Record and report.** RESEARCH.md's Ground line names the areas ("in 2 areas: Perry A1, Athens A1"), and the search report lists them.
  - **App.** The map groups ground into areas: one area name, or one survey's ground lying close together. It shows one area at a time, from a menu headed "2 areas in this project", whose button names the area shown. Choosing a find on another area brings that area onto the map. The overview's Bare ground row says "2 areas, 18 tiles". Pick a place shades each area's own box, and older projects keep their project box.
  - **Checked.** A probe project was made the way a session would: started as "Search on its own, 23 Nov", named "Hocking Hills region, Ohio" with `name_project`, with two named areas about 30 km apart fetched into it. Its box covered both, RESEARCH.md named both, PROJECT.md took the new name, and in the test copy the menu listed both areas and switched the map between them. A new offline test covers naming, the box growing, the cache dropped, the area kept, and names with coordinates refused. The offline tests pass (41).
  - **Not checked:** the shading on Pick a place for a project with areas (no such project was in the list when it was looked at).
