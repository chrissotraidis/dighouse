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
- **H2, a project page with its chats.**
  - **The page.** The overview has a Chats list under its first card: each chat of the project with what it is doing ("Searching on its own · ends 18:40", "Working on its goal", "Working"), five at a time with "Show all". The line beside it says new chats start from the message box below. With none yet: "No chats yet. Anything you ask below becomes a chat here, and each one starts from the research record."
  - **Context.** The skill already tells every chat to read RESEARCH.md first, so no prompt changed and the blind tests are not affected.
  - **Titles.** `ChatThread.label` takes boxes and coordinates out of a chat's title wherever it shows: the sidebar, the project page, the chat's header, ⌘K and Find a chat. The Perry Mesa title "Use find_gaps on the Middle Usumacinta region (west -91.6, south 17.4, east -91." shows as "Use find_gaps on the Middle Usumacinta region". A new app test covers it, with titles that must stay whole ("Fetch 2.5 km² of …").
  - **The map's areas, refined.** Unnamed ground of two surveys stays together when the pieces lie side by side (Shawnee's two 2019 surveys). They are shown apart only when they cover much the same place, as two flights over one site do.
  - **Checked** in the test copy on the probe region. A question typed on its page became a chat named "Project research areas". It showed in the Chats list and under the project in the sidebar, and it answered "The project holds two areas: Perry A1 and Athens A1." The Perry Mesa title was checked by the app test, not on screen, so as not to open Chris's own project from the test copy.
- **H3, projects first in the sidebar.**
  - **Order.** Projects come first, then the chats that belong to no project, then a folded "Blind tests" group with its count. The group opens by itself when a blind test is the open project.
  - **Folding.** Any project unfolds to its chats, not only the open one. Unfolding a closed project asks the engine for its chats, so they show even if the project was never opened on this Mac. A folded project shows how many chats it has, and a working mark when one of them is running.
  - **The fold arrow** is now a button of its own ("Unfold Hocking Hills region, Ohio"), so the keyboard and VoiceOver can reach it. Before, it was a tap area inside the project's button.
  - **The map's area menu** shortens a long survey name on its button ("OH_Statewide_Phase2_2…"), and the menu shows it whole.
  - **Checked** in the test copy:
    - **Chris's whole list** (66 projects plus the probe) sorted into 51 projects, his 19 chats and "Blind tests 15", with nothing opened.
    - **A smaller test list.** Unfolding the closed probe region showed its chat. Unfolding a blind test of Chris's listed "Find and report back" from the engine. That project's last commit and RESEARCH.md were unchanged afterwards.
    - **Nothing moved.** No folder was moved, renamed or opened.
- **H4, Search on its own lives in one project.**
  - **The app.** Pressing it makes the session's project ("Search on its own, Nov 23", with no area yet), opens it, and starts the timed chat inside it. "Show the session" opens that chat in its project; sessions from before still open under Chats.
  - **The instructions.** The timed session's own instructions, and its workflow prompt, now say to choose one region, name the project after it with `name_project` (with the region's box) before calibrating, and add every area with `fetch_terrain` and a short area name. They also say to make no other search project, and to keep the session's record in the project. They no longer say "create a fresh project for each" or keep a record in the general chat folder. The skill did not change.
  - **The tools.** `add_measured_rises` skips ground that already has its measured rises, so a project searched area by area does not fill the first area again. `start_calibration` refuses until the project has a region, so it cannot pick the known site nearest to 0°, 0°. A project asked for in `/tmp` or Dighouse's Application Support folder goes to the projects folder instead (`lasting_folder`).
  - **Names follow.** The app reads a project's name again whenever its `project.json` changes, and at launch, so a project renamed by the agent shows its new name in the header and sidebar.
  - **Checked with a 20-minute session** in the test copy (primary / 6.1 Terra, second opinions from Sonnet 5.5):
    - **The project.** It named the project "Perry Mesa" with a question and the region's box in its first minutes, and passed a blind calibration on Cahokia.
    - **The area.** It searched one named area, "Perry A4" (1.52 km², USGS 3DEP 2021, all 36 tiles), and added 74 measured rises. All 74 were checked in one pass and given a suggestion, and every one had a Sonnet opinion before the session ended. Its checkpoint, run summary and search report are in the project's `notes/` and `reports/`.
    - **No other projects.** It made no other search project.
    - **On relaunch** the project read "Perry Mesa" in the header and sidebar, with its chat "Search on its own" under it, 1 find for a person and 73 measured rises on the map.
  - **Found while checking, and fixed:**
    - The calibration test went to `/tmp`, because the old instructions had been the only thing steering it to the projects folder.
    - The project kept its first name on screen until the app was relaunched.
  - **Not checked:**
    - A session long enough to search a second area in the same project.
    - A name changing on screen while the session runs; the watcher was added after this run, so the name was seen to follow at launch only.
  - **Tests.** Offline tests pass (43, three new), and the smoke test passes (31 s, score 1 of 1).
- **H5, hand over.** README (Search on its own, a project as the home, the tool table, 58 tools, 43 tests), HANDOFF, DESIGN (projects first, titles without places), ROADMAP and DECIDE_LOOP (D6 done here as H3) brought up to date. The app was rebuilt and relaunched with Chris's settings unchanged.

## Where it stands

A project now holds its areas, its finds and its chats, and a timed session builds one project for its region instead of a project per square km. One gap stays open: no session has yet run long enough to put two areas into one project, and that is the first thing the next long run will show.
