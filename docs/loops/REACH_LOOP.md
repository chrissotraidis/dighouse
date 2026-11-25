# Dighouse goal loop: faster, wider, easier to review

Written 2026-11-21. Chris said go; the Log at the end says what was done and checked.

Read [SECOND_OPINION_LOOP.md](SECOND_OPINION_LOOP.md) first, especially the S7 entry. The method holds up when nobody steers it. What holds it back now is time and attention: the agent's time on new ground, and the person's time on the finds it leaves.

## What the last loop showed (2026-11-21)

- **Fast when focused, slow overall.** Paint Creek took 14 minutes for 1.48 km². The whole two-hour session searched 3.2 km², about 37 minutes per km². It spent the first 35 minutes going back over earlier projects, 15 minutes trying to place one control mound before calling itself blocked, and all of its slicing, old-map checks and source logging one find at a time.
- **Too much to review.** One session left 224 open finds, 165 of them measured rises, and 216 already suggested natural or modern. Each still needs its own decision from a person. Only 8 were leads.
- **The second opinion is a filter.** Sonnet's "not built" was right 91% of the time on known ground, its "built" 40%. It called 112 of the 224 built.
- **The app missed background work.** A timed session that stopped itself early was not turned back; projects it made while another page was showing were not listed; their records went stale. All three are fixed, but they show that background runs are tested less than the visible ones.
- **Reach.** Open lidar is read in the United States and 18 national or regional services. Old maps, which cleared hollows in S6, work only in the United States. Not read yet: Scotland, Wales, Slovenia (files by sheet), Poland and Tirol (no answer), Spain beyond Navarre and the Basque Country (5 m only), and the German states other than Bavaria and Saxony (not checked).
- **App speed has not been measured.** Nothing in the log says how long a project takes to open or whether the window stalls. The project list re-reads every record file of the open project every 2 seconds, and Home reads every project's records for its greeting. Those are suspects to measure first; nothing has been timed.

## Goals

Each is done when its check passes in the running app or in a logged benchmark run. Work them in order. F2–F5 can share pull requests, one per goal.

| Goal | What | Check |
|---|---|---|
| F0 | **Measure first.** Time the app (launch to Home, open the largest project, switch each tab, scroll a long chat, the records list with 50 finds) with signposts and `sample`, and count hangs over 250 ms in a ten-minute session. Time the agent from the S7 notes: minutes per km², per find, and per stage. | A baseline table in the Log, with the three slowest app actions and the three biggest agent time sinks named. |
| F1 | **A window that never stalls.** Fix what F0 finds, starting with file reading on the main thread: watch the project folder for changes instead of polling it, read records off the main thread, and cache Home's totals. | Every action from F0 is under 300 ms after launch (opening a project under 1 s), and no hang over 250 ms in a ten-minute session with a search running. |
| F2 | **A faster search.** Helper agents take tile batches in timed sessions, as they do in a whole search. Slices, map checks and old-map checks run for all of a project's finds in one call. Sources are searched once per area and logged on the finds they bear on. A check the agent cannot finish in ten minutes (a control it cannot place, a page that will not open) is noted as open and left behind. Timed sessions start on new ground; going back over old projects happens only when asked. | A one-hour timed session searches at least 3 km² with the same steps on every find. Minutes per km² at least halves against S7. |
| F3 | **The method holds.** Rerun the blind tests (Borre, Mound City, Maiden Castle, Cahokia, Navarre) after F2. Log false finds per km² beside recall, and for each miss, where it was lost: never marked, a tile called natural, or filtered later. | Recall no worse than the last run on any site. If F2 costs recall, the change that cost it is undone. |
| F4 | **A review list a person can finish.** Records open on "Needs you": leads first, then finds where the agent and the second opinion disagree. Finds the agent calls natural or modern that Sonnet also calls not built sit in groups (by project and suggestion), each with one "Agree with these" that writes the person's name and the agent's reason on every record. Measured rises the agent called natural are folded into their tile's group. A lead is always decided one by one. | In the app, Chris clears Prairie Oaks's 31 open finds in under two minutes. Every record still names who decided and why. The four leads stay one at a time. |
| F5 | **More of the world.** Probe and add, each with a live fetch and a quick look at a known site: Scotland, Wales and Slovenia (a sheet reader like Switzerland's), German states with open 1 m ground models (North Rhine-Westphalia, Thuringia, Hesse and Brandenburg to probe), and Navarre's newer 0.5 m model. Old maps outside the United States where they are open: France's 19th-century État-major map (IGN) and England's old Ordnance Survey sheets, if an open service exists. | At least four new regions read, each named on the coverage map with its live test in the Log. Old maps answer in at least one country outside the United States. Anything that does not answer is listed with why. |
| F6 | **Easier to start and to follow.** One button on Home starts a timed session with a length picker, and what it is doing shows on Home while you are elsewhere (area, km², finds, time left). Every background job (second opinions, record rebuilds) shows as one quiet line with a count. Pick a place shades ground your projects have already searched. A first-time user reaches a running search in three presses from Home. | Walked from clean settings by a test copy of the app: three presses to a running search; the background line visible from every page; searched ground shaded on the map. |
| F7 | **Two hours, no step-ins.** Run the unsteered two-hour session again on the new build, in a new region from F5 if one fits. | At least 6 km² searched, no step-ins, every find has a second opinion, and the review list from F4 fits on one screen per project. |
| F8 | **Hand over.** README, HANDOFF, the Toolbox and Open data match the app; the coverage list in the README is regenerated from the code. | Merged, `main` clean, the app rebuilt and launched with Chris's settings unchanged. |

## Decisions for Chris before starting

1. **Agreeing in groups (F4).** May a person accept the agent's suggestion for a group of natural or modern finds in one press, with their name on each record? Or should every find stay one by one?
2. **Sources once per area (F2).** Searching the literature once per area, rather than per find, is the biggest time saving after helper agents. Records would cite the area search. Acceptable?
3. **Regions first (F5).** The suggested order is Scotland and Wales, then the German states, then Slovenia, then old maps for France. Change it if you have a place in mind.
4. **Usage.** The primary account is at 11%. F0, F1, F4, F5 and F6 need little model use; F2, F3 and F7 need a lot. Do the code now and the runs after the reset?
5. **Merging.** One pull request per goal, merged when its check passes, as before?

## Ground rules

As before: few words, a person decides, nothing is called new, locations stay under `private/`, tests that talk to a model use primary / 6.1 Terra, and the benchmark guards the method (a change to finding or checking ships only if the blind tests are no worse). Speed never removes a check from a find; it changes when and how the check runs.

## Log

### 2026-11-21, decisions taken

Chris said go without changing the five decisions, so the recommended ones stand: agreeing in groups is allowed, with the person's name and the agent's reason on every record, and a lead is always decided alone; sources are searched once per area; regions in the order Scotland and Wales, the German states, Slovenia, then old maps for France; the low-model goals first, with F2, F3 and F7 run as usage allows; one pull request per goal, merged when its check passes.

### 2026-11-21, F0: measured

The app now has a measuring mode: `open Dighouse.app --args -measure YES -measureTour YES`. A watcher thread logs every time the main thread stops answering for more than 250 ms, with what the app was doing, and a scripted tour times Home, opening the largest project (48 finds), each tab, the Toolbox, Settings, New project and the longest chat (`Perf.swift`, results in `~/Library/Application Support/Dighouse/perf.log`). Off by default; it costs nothing when off.

Three tours on this Mac with Chris's 42 projects:

| Action | Ready | Window stalled |
|---|---|---|
| Launch to engine and chats ready | 1.0–1.4 s | no |
| Home, Toolbox, Settings, New project, Records, Data, Map | at once | no |
| Open the largest project | 12 ms | no |
| **Notes tab** (the research record of 48 finds) | at once | **551–614 ms, every time** |
| **Sources tab** | at once | **284–322 ms, every time** |
| **Open the longest chat** (Timed research session 3) | **1.3–1.8 s** | no (waiting on the engine) |
| Poll the open project, nothing changed | 0 ms | — |
| Read the open project again after a file changes | 12 ms | — |

The polling suspected in the proposal is cheap. The real cost is the Notes tab: it reads and lays out the whole record inside the view, so it pays the 0.6 s again whenever the project changes while it is showing, which during a search is every few seconds.

The agent, from the S7 notes (3.2 km² in about 114 minutes of work, 36 minutes per km²):

| Where the time went | Minutes |
|---|---|
| **Going back over earlier projects** before any new ground | 35 |
| **Chasing one control mound it could not place**, then idle while blocked | 14 + 10 |
| **Sources per area** (Prairie Oaks: 4 before the tiles, 9 after) | 13 |
| Looking at 36 tiles (Prairie Oaks) | 8 |
| Slices, measured rises and old maps for 31 finds | 4–5 |
| Writing the run summary and report again (three times in Prairie Oaks) | 2–3 |
| Calibration (run again on each new project, once below the pass mark first) | 1–2 |

Paint Creek, with none of the detours, took 14 minutes for 1.48 km² (9.5 minutes per km²). So the search itself is not slow; the detours are. F2 aims at the first three rows: no going back unless asked, a ten-minute limit on any one check, and sources once per area.

### 2026-11-21, F1: a window that does not stall

The Notes tab spent its 0.6 s parsing the research record's Markdown (a record of 48 finds has about 400 table cells, each run through the Markdown parser) and laying out every block, and did it again on every redraw. `MarkdownText` now parses each text once and keeps it (emptied past 300 texts), and lays its blocks out lazily, so only what is on screen is measured. The Sources list is lazy too. A chat opened before shows at once from memory while the engine reads it again (the last eight are kept). For checks, `-openProject <folder> -openTab Notes` opens a project on a tab at launch.

The same tour after the change:

| Action | Before | After |
|---|---|---|
| Notes tab | stalled 551–614 ms | no stall |
| Sources tab | stalled 284–322 ms | no stall |
| Go back to the longest chat | 1.3–1.8 s | **36 ms** |
| Open the longest chat the first time | 1.3–1.8 s | 1.7 s (the engine reading it; nothing stalls) |
| Everything else | at once | at once |

The research record was checked by eye in the Notes tab of Darby Prairie: headings, lists and the finds read as before. Still to check: no stall in ten minutes with a search running, which F2's run measures.

### 2026-11-21, F2: a faster search

`check_finds` slices every open find east to west (three times its width, 30 to 120 m), measures its shape and checks open maps, three map checks at a time, in one call: 9 finds took 35 s on a copy of Prairie Oaks, about 4 s each against 11 s one by one. The skill and both prompts now say: check_finds once after add_measured_rises; sources searched for the area as a whole and logged on "all" or the finds they bear on; at most ten minutes on any one check, then note it as open and move on, never stop over it; the summary written once per area. A timed session starts on new ground, hands tiles to helper agents in batches of about 8, and leaves earlier projects alone unless asked.

One-hour timed session, started 14:55 with `-startTimedResearch 60 -measure YES`, nobody steering:

| Area | km² | Tiles | Finds (measured rises) | Slices, maps, shapes | Old maps | Literature searches | Summaries |
|---|---|---|---|---|---|---|---|
| Muskingum A1 | 1.33 | 30 | 14 (11) | 14 of 14 | 5 | 2 | 1 |
| Pike B2 | 1.35 | 30 | 39 (31) | 39 of 39 | 16 | 2 | 1 |
| Knox A2 | 1.32 | 30 | 13 (9) | 13 of 13 | 13 | 2 | 1 |
| Athens A2 | 1.34 | fetched and cut, not looked at when time ran out | | | | | |

**4.0 km² searched fully in 60 minutes, 15 minutes per km²**, against 36 in S7: the target was half (18). The first new ground was cut two minutes after the start (S7: 35 minutes). Every find has a slice, an open-map check, a shape, logged sources and a suggestion; each area took one check_finds call and one summary. Second opinions were queued by the app when the session ended.

The window is not yet right: the watcher logged 9 stalls over 250 ms during the hour (worst 998 ms), all while the session's chat was showing and the agent was looking at tiles or old maps. F1 continues below.

### 2026-11-21, F5: more of the world

Four regions added to `national.py`, each fetched live and looked at on a known site with `quick_look`:

| Region | Source | How it is read | Live check |
|---|---|---|---|
| North Rhine-Westphalia | Geobasis NRW, 1 m | WCS 2.0 (`nw_dgm`, EPSG:25832), like Flanders | Hünenburg, Bielefeld: earthworks on the hilltop, 2 s |
| Scotland | Scottish Remote Sensing Portal, 0.5 to 1 m | files on AWS by Ordnance Survey sheet, newest first: the National LiDAR Programme (1 km sheets), then phases 6 to 3 (5 km quarter sheets) and 2 to 1 (10 km sheets) | Torhouse stone circle (national programme), Traprain Law ramparts (earlier phases), 28 s each |
| Wales | DataMapWales, 1 m | one cloud-optimised GeoTIFF for all of Wales (48.6 GB), read only where needed | Pen Dinas hillfort, Aberystwyth, 26 s |
| Slovenia | ARSO, 1 m | x;y;z text per 1 km sheet (27 MB each); each sheet's flight block (b_11 to b_39) is found by asking each once, then kept, because ARSO's block index service is "temporarily unavailable" | Magdalenska gora: terraced ramparts and the mounds beside them, 18 s |

Old maps now also answer in **France**: `check_old_maps` shows IGN's État-major map (1820 to 1866, zoom 15) and its aerial photographs of 1950 to 1965 (zoom 17), 200 m each way with the find ringed, from IGN's tile service. Checked at Alise-Sainte-Reine (Alesia): the village's buildings in red on the État-major map and the village and fields in the 1950s photograph. France has no open mine register here, and the reply says so. The skill and prompts say "in the United States and France".

The Toolbox's coverage map and Open data pages list the four regions with a picture from each live check; Scotland, Wales and Slovenia leave the "not read yet" list. The README's open-data table and the national module's description list them. A test checks Ordnance Survey sheet names, since a wrong letter would read the wrong place silently.

### 2026-11-21, F4: a review list a person can finish

Records now open on what needs a person, in this order: **Worth a closer look** (the leads), **Look again** (the agent says natural but the second model says built: a real disagreement), **No suggestion yet**, **Already published**, **Modern or natural**, **Decided**. A modern find the second model calls built is an agreement, since modern things are built. The two routine groups have **Agree with these**: a sheet lists each find with its reason, anything can be unticked, and each record gets the person's name and its own reason. A lead has no group button; it is decided alone. Review and decide (one at a time, from the keyboard) follows the same order. The group title keeps its line so its count shows.

Checked on a scratch copy of Prairie Oaks (31 finds, 30 routine and 1 to look again), with Chris's settings backed up and restored afterwards: from the first click to the last record written, **86 seconds**, including screenshots. 30 records were written 13 seconds after "Agree with 30", each "decided by Chris Sotraidis" with the agent's reason; C-019, the disagreement, was decided alone through its own sheet.

### 2026-11-21, F6: easier to start and to follow (part)

Home has a fifth way in, **Search on its own**, which opens the length picker (now titled the same, starting at one hour): two presses to a running search. While a timed session runs, Home's top card says what it has done so far (areas, square km, finds, when it ends) and opens its chat; it reads the project folders every half minute, off the main thread. A line above Settings in the sidebar counts the second opinions still to come, on every page. Pick a place shades the search box of every project you made (not blind tests) and, zoomed out, marks each with a white dot, with "Ground you have searched" in the legend. The five Home cards fit on one row.

Seen in the app: the five cards, and the dots over Ohio, Illinois, Mexico and England with the legend. Still to see: the session card and the background line during F7's run, started from the new card.

### 2026-11-21, F3: the method holds

The five blind tests rerun on the F2 build, one after another, with `open Dighouse.app --args -startBlindTests borre,mound-city,maiden-castle,cahokia,andia -measure YES` (new: runs the listed answer keys in turn, each until it is scored). Primary / 6.1 Terra, the whole search as a person would start it. Last runs are those in SECOND_OPINION_LOOP (Borre, Maiden Castle) and the README (Mound City, Cahokia, Andía).

| Site | Last run | Now | Extra finds | Extra per km² | Where the misses were lost | Minutes |
|---|---|---|---|---|---|---|
| Borre | 21 of 53 | **25 of 53** | 9 | 24 | 28 looked at, not marked | 6 |
| Mound City | 19 of 19 | 19 of 19 | 11 | 44 | — | 4 |
| Maiden Castle | 1 of 3 | **3 of 3** | 32 | 36 | — | 4 |
| Cahokia | 1 of 1 | 1 of 1 | 4 | 16 | — | 3 |
| Sierra de Andía (Navarre) | 0 of 11 | **1 of 11** | 63 | 29 | 10 looked at, not marked | 10 |

Recall is no worse on any site and better on three; extra finds stay under the cap of 50 per km² everywhere. The gains come from the measured rises (S5) now running inside the whole search, and the speed changes cost nothing measurable. Every miss was lost the same way: the tile was looked at and the mound not marked. Nothing was lost to the records check or to a second model. That is where the next gain lies (small, low mounds a picture does not show), as before.

### 2026-11-21, F1 continued: the stalls during a search

F2's hour logged 9 stalls (worst 998 ms) while the session's chat was showing. The watcher now names what the app was last doing (the last engine message, or reading the open project), and the tour opens the longest chat (a timed session, 428 items) and adds ten steps to it the way a running agent does. That tour showed opening the chat stalling 1.2 to 2.3 s, and a sample of the main thread put nearly all of it in building the chat's steps from the engine's record, where a step's text was being shortened by counting its characters (a Swift string counts characters by walking the whole text; some results are hundreds of kilobytes). The text is now measured in bytes, which a string knows at once, and cut after 40,000 characters with a note of the full size.

| The same tour | Before | After |
|---|---|---|
| Open the longest chat (428 items) | 1.3–10 s, stalls of 1.2–7.5 s | 1.3 s, no stall |
| Ten new steps in that chat | no stall | no stall |
| Everything else | no stall | no stall |

Whether a two-hour search now runs with no stall is checked in F7, which runs with `-measure YES`.

### 2026-11-21, F7: two hours, no step-ins

Started at 17:08 from Home on the new build: **Search on its own** (one press opens the picker with Start ready; "2 hours" chosen there), measuring on. Nobody steered it; it ended at 19:08 on its own.

| Area | km² | Finds | Sliced and suggested | Second opinions | To decide alone (Look again) |
|---|---|---|---|---|---|
| Hocking A1 | 1.60 | 16 | 16 | 16 | 1 |
| Vinton A2 | 1.73 | 40 | 40 | 40 | 5 |
| Highland A1 | 1.73 | 4 | 4 | 4 | 0 |
| Licking A1 | 1.70 | 7 | 7 | 7 | 1 |
| Mohican Region | 1.69 | 35 | 35 | 35 | 2 |
| **Total** | **8.45** | **102** | **102** | **102** | 9 |

| Check | Result |
|---|---|
| At least 6 km² | **8.45 km²**, every tile looked at, 14 minutes per km² |
| No step-ins | none |
| Every find has a second opinion | **102 of 102**, all from Claude Sonnet 5.5, asked by the app when the session ended, none refused (the queue took 79 minutes; Sonnet slowed to about a minute each near the end) |
| The review list fits on one screen | yes: at most 5 finds to look again in a project, then one routine group with **Agree with these**; seen in the app for Vinton |

Also seen during the run, finishing F6: Home's top card read "Searching on its own · 2 areas, 3.3 square km, 56 finds so far · Ends at 7:08 PM" half an hour in, and the sidebar showed "Second opinions: 67 left" when the session ended. And finishing F1: the watcher logged two stalls in the first minute (301 ms while the length menu was open, which holds the main thread by design, and 297 ms as the session's chat started its tools) and **none in the two hours of searching**.

One mismatch found and fixed: the project header's "12 need you" counted finds ready for a no-match decision, not the review list beside it (5 to look again). The badge now counts what the list shows: finds to decide alone, or else "N to agree with", and opens Records.

### 2026-11-21, F8: hand over

README: 52 tools in the badge; **Search on its own** and the review groups described; the benchmark table carries the five reruns (marked *), now 60 of 105 on land; the open-data table lists North Rhine-Westphalia, Scotland, Wales, Slovenia and IGN's old maps; check_finds in the tools table. HANDOFF: "What the reach loop added" (F0 to F7, with the measuring arguments), 52 tools, the benchmark line. ROADMAP: the small-mounds item brought up to date, the Scotland/Wales/Slovenia item removed. The workflow is named Search on its own everywhere.

Checked: offline tests (37), swift test (3), smoke test, swift build. The app rebuilt from main and launched with Chris's settings: agent primary / 6.1 Terra, second model Claude Sonnet 5.5, split layout (put back after the checks), 56 projects (the new ones are the sessions' and blind tests'; the scratch copy used for F4 was taken out by restoring his settings). The worktree used for F5 was removed after its branch merged.

### 2026-11-21, after F8: the last rough edges

- **Measured rises fold by tile.** In the routine group, finds a model marked keep a row each; measured rises on the same tile fold into one row ("5 measured rises · Tile r002c000") that opens on a click. Vinton's 35 routine finds now take about half the rows. They are agreed with together like the rest.
- **The first open of a recent chat is instant too.** After launch the app reads the last two general chats and the open project's latest into memory, from the engine's record only. The tour: opening the longest chat (428 items) **131 ms**, against 1.3 s before and up to 10 s at the start of the loop; going back to it 38 ms.
- **A newcomer's Home**, launched with no projects and the tutorial done: five ways in, Search on its own among them, two presses to a running search. Chris's settings were not touched (launch arguments only).

### 2026-11-21, F5: what was not added, and why

- **Thuringia**: its 1 m model is free, but only through a download page where tiles are picked by hand and the address is built in the browser; its map service is based on a coarser 2 to 5 m model. Not scriptable as found.
- **Hesse and Brandenburg**: not probed in this loop. Four regions met the goal first; they are next in line.
- **Navarre's newer 0.5 m model**: not probed; Navarre stays on IDENA's 2 m model.
- **England's old Ordnance Survey sheets**: not probed for an open tile service; old maps answer in the United States and France.

