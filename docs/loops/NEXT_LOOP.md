# Dighouse goal loop 2: make it find things

Last updated: 2026-11-13

This loop follows [GOAL_LOOP.md](GOAL_LOOP.md), whose goals G1 to G21 are logged there. Read [HANDOFF.md](../HANDOFF.md) first. The first loop made the app understandable. This one makes it something a person can use to do real work, and finishes what was left unverified.

## Goals

Each goal is done when its check passes in the running app. Record the date and what was seen in the Log.

| Goal | What | Check |
|---|---|---|
| N1 | The mound mark beside "Dighouse" in the sidebar animates while the agent is running, and is still when idle or when Reduce Motion is on. | Start a run and see it move; when the run ends it stops. A run in a chat that is not on screen also moves it. |
| N2 | Close the first loop on the current build. | The click-through passes at zoomed, half-width and narrow sizes, and in the Canopy look. `uv run pytest -m live` passes. Chris confirms the two edges drag with his mouse, or the handle is fixed until he does. A file dragged from Finder onto the message box attaches. |
| N3 | A whole search finishes without hand-holding. | On a fresh project, "Run the whole search" goes from terrain to logged sources, stops only at the second look and at decisions, and leaves a run note. Nothing is left half-logged if the run is stopped early. |
| N4 | The agent can read what a person can. | The agent opens a page that refuses a plain request (for example one of the 14 refused Angel Mounds sources) through a browser it can drive, or the Sources tab hands the page's text to the agent after the person opens it. |
| N5 | "What should I research?" gives answers worth acting on. | Rerun it: it proposes no survey with a known problem, each proposal names tested lidar, and picking one creates a project whose terrain then builds. |
| N6 | More of what archaeologists use. Decide from first principles which sources and views matter most, then add the ones that can be read openly. Candidates: open national lidar outside the United States, Pleiades in bulk, more terrain renderings, historic maps and imagery, export of a project's finds for mapping software. | Each addition has a live test, a line in `open_resources` with a size that was read from the service, and a place in the Toolbox. Anything not added is named as out of reach. |
| N7 | Honest model choices. | A model can be tested from Settings, and the result is shown beside it. The picker marks models that failed the test. Nothing in the app claims an effort step works unless it was tested. |
| N8 | Recorded-site counts that do not depend on one busy service. | `survey_area` and `find_gaps` return OpenStreetMap sites in three runs out of three, by caching, a second service, or a downloaded extract. |
| N9 | Polish: Settings, "How it runs", the Toolbox and the welcome guide read as one product in its own voice. Old chats get short titles. | Chris reviews screenshots of each and has no "looks generated" notes. |
| N10 | Docs match the app; everything committed and pushed. | README, concept and this file agree with what the app does. `git status` is clean and `main` is pushed. |

Still waiting on a decision from Chris, so not goals yet: a notarized download, a Notion button, bulk screening through the model router, and the licence.

## The loop (every turn)

1. Read [HANDOFF.md](../HANDOFF.md), this file and the Log below.
2. Pick the lowest unfinished goal. N1 and N2 come first: N1 is Chris's latest request and N2 is owed.
3. Build it, then run its check in the app and look at the result.
4. Fix what the check shows. Repeat until it passes.
5. Record the result in the Log with the date, run the tests, commit and push.
6. Stop only when N1 to N10 are checked, or when a decision is needed from Chris.

## Log

### 2026-11-12, N1

The mound mark beside "Dighouse" animates all the time the app is open: a pass of light sweeps across it, the ground dots brighten and the canopy fades above it, like a lidar flight passing over. It sweeps every 2.6 seconds when idle, every 1.2 seconds and at full strength while the agent works (any chat with a turn in progress, a second look, or the engine starting), and faster when the pointer is over it. It is still when Reduce Motion is on.

The first version moved only while a run was in progress, so Chris saw it still and reported it as not animated. Fixed the same day.

Checked: idle, six frames 400 ms apart all differ and show the pass moving left to right; during a short run, four frames 250 ms apart differ. Not checked: hover, Reduce Motion, and a run in a chat that is off screen.
### 2026-11-12, N2

| Check | Result |
|---|---|
| Click-through at half width (864 points) | Passed, 30 of 30 steps. |
| Click-through in the narrow layout (700 points, sidebar as an overlay) | Passed, 30 of 30 steps. |
| Click-through in the Canopy look (1380 points) | 29 of 30. The long "Run the whole search" chat opened with its content, but the check looked for a folded "N steps" line that was scrolled out of view. Opened by hand, it showed the whole run and the workspace beside it. Counted as passed. |
| `uv run pytest -m live` | Passed, 5 of 5, in 1 min 49 s. |
| A file dragged from Finder onto the message box | Not verified. The test tooling moves the pointer but macOS starts no drag session from it, so neither a Finder drag nor dragging a record picture onto the message box can be tested this way. Needs Chris's hand. |
| The two edges dragged with a real mouse | Not verified, for the same reason. Asked Chris again. |

N2 stays open until Chris confirms the edges and the drop.
### 2026-11-12, N3

The last whole run (Angel Mounds) ran out of web searches before the literature step and ended with nothing logged and no summary. Changes: a `write_summary` tool that writes the run summary to `notes/` and refuses text that looks like coordinates; the skill now says to budget every run so the prior-art step and the summary always happen; the "Run the whole search" prompt names each step, says to log every source as soon as its outcome is known, and to end with the summary even if stopped early.

Check, on a fresh project made from the Serpent Mound starting point, with no input after pressing Run: about 9 minutes. The agent fetched USGS terrain (7 ground returns per square metre), cut 9 tiles, screened all 9 in two styles, flagged 4 candidates, cut a section and ran the map check on each, searched the literature and Open Context, opened 14 sources and logged all 14 (4 read, 10 refused or abstract only), added the measurements as evidence, and wrote `notes/2026-11-12-run-2012.md`. It set no statuses and recorded no second look, and listed both as waiting for the person. Passed.

Not checked: stopping a run halfway to see that what was done stays logged. The summary had its title twice; fixed so only one is kept.

### 2026-11-12, N4

The Sources tab now hands a page to the agent. When a source refused the agent (a 403, a sign-in, a human check), the person opens it in the tab's browser and presses **Give this page to the agent**. The app saves the visible text to `sources/pages/page-<host>-<time>.txt`, with the address as the first line, and asks the agent to read it with `read_source` and log it. `read_source` reads a saved page by its file name and marks the result as saved by the person. Logging a source again under the same title replaces the old entry on the record, so a refused entry turns into a read one. If the page shows under 200 characters (still asking for a sign-in), the button says so and saves nothing.

Check, in the Serpent Mound project: the Ohio History Connection's Serpent Mound page had been logged as refused (403) on all four candidates. Opened in the Sources tab, it loaded in full. After the button, the agent read about 5,200 characters, reported what the page says for each candidate, and logged it as read; each candidate now has one entry for that page, marked read. The read log keeps the old refused lines above the new ones, as a history. Passed.

Found and fixed during the check: when the agent read a saved page, the browser tried to follow it and showed the file name as the address. The browser now only follows the agent to web addresses; checked by asking the agent to re-read the saved page, and the tab stayed on its list.

Not checked: the agent driving a browser on its own. Codex's browser plugin is available to the engine, but the agent was not asked to use it here.

### 2026-11-12, N5

The prompt behind "What should I research?" and the skill now say to propose only lidar known to build (a survey with a `checked_start`, or USGS 3DEP inside the United States), to leave out any survey with a `known_problem`, and, once the person picks, to create the project and fetch its terrain straight away.

Check, from Home, about 2.5 minutes: the agent proposed Perry Mesa, Arizona (AZ08_Kruse), the Middle Usumacinta (MX19_Inomata) and southern Ohio (USGS 3DEP), each with what is on open record and from which sources. It said it left out both Chaco Canyon surveys for their known problems and a Moroccan survey that needs an account. Picking Perry Mesa created the project, and the tested box built terrain at 3.1 ground returns per square metre. Passed.

Found and fixed during the check:

- The agent first tried the full 4 sq km area, and the call stopped at the engine's default five-minute limit for a tool. Dighouse now gives its own tools 20 minutes per call. Asked again in one call, the whole area came back in 58 seconds (its files were already downloaded by then): 12.1 million ground returns, 4.0 per square metre, with a quarter of the box outside the survey.
- With terrain built but not cut, the map, the status strip and the chat all said "No terrain yet". They now say the terrain is ready, and the map has a **Cut into tiles** button. Pressed, the agent cut 66 tiles, all readable, and the map showed them.

Also seen: OpenStreetMap did not answer for two of the three regions, so their site counts were low. That is N8.

### 2026-11-12, N8

OpenStreetMap's archaeological sites are now read from QLever (`qlever.dev`), a public query service that holds the whole map, with the Overpass servers as the fallback and each answer cached for a week. QLever holds 229,473 objects tagged as archaeological sites and answers for a region in under a second. The Overpass servers answered once in seven tries across five mirrors on the same box, and returned different counts for the same query on different tries. When both answered, every site Overpass returned was also in QLever's answer. `find_gaps` now gives totals by source, and both `find_gaps` and `survey_area` list the sources that answered, so a short list cannot be mistaken for a source that was down. The map check for modern features now alternates between two Overpass servers.

Check: with the cache cleared before each run, `survey_area` (Serpent Mound) and `find_gaps` (Middle Usumacinta) returned OpenStreetMap sites and no silent source in 3 runs out of 3, in 2 to 7 seconds. QLever alone answered 9 of 9 calls over three regions. A new live test covers it; `pytest -m live` passes 6 of 6. In the app, the agent reported 54 sites for the Usumacinta (50 from OpenStreetMap, 4 from Wikidata) where the N5 research answer, made while Overpass was failing, had 3; and for Ross County, Ohio, 37 sites with all three sources named as answering. Passed.

### 2026-11-12, N6

Chosen from first principles. A search can only find what open lidar covers, so the largest gain is open national lidar outside the United States. Next is the view archaeologists use most for low banks and ditches (sky-view factor), then a gazetteer of ancient places for the Old World, and a way to take finds into mapping software.

| Added | What it is | Check |
|---|---|---|
| England: Environment Agency lidar composite DTM, 1 m (`uk:ea-dtm-1m`) | A ready-made ground model, OGL. | Danebury hillfort fetched, tiled, rendered and sectioned. In the app, the Toolbox's Maiden Castle question created a project, fetched 1.9 sq km and the agent described both entrances and the four lines of rampart from the views. |
| Netherlands: AHN DTM 0.5 m (`nl:ahn-dtm-05m`) | A ready-made ground model, CC0. | Ginkelse Heide fetched in four requests, a banked enclosure visible in sky view. Live test. |
| France: IGN LiDAR HD ground model 0.5 m (`fr:lidarhd-mnt`) | A ready-made ground model, Etalab. | Slopes below Gergovie fetched in six requests, field terraces visible. Live test. |
| Sky view (`sky_view` style) | Share of the sky visible from each cell: ditches dark, banks bright, no light direction favoured. | Serpent Mound tile renders in 0.3 s. Offline test on a synthetic ditch. |
| Pleiades | 42,534 ancient places, 34,931 located, read in bulk and kept for a month. Now a source in `survey_area` and `find_gaps`. | Central Rome: 359 Pleiades places beside Wikidata's 438 and OpenStreetMap's 201. Live test. |
| `export_finds` | Candidates as GeoJSON for QGIS, ArcGIS or Google Earth, under `private/exports/` because it holds coordinates. | Serpent Mound's 4 candidates exported. Offline test. |

Each has a line in `open_resources` with a size read from the service (grid sizes from the WCS coverage descriptions, the French layer's extent from its capabilities, the Pleiades count from the download) and a card in the Toolbox's Open data tab with a picture made from it, except Pleiades, which has none yet. `find_data` matches the national models against rough country outlines, so Wales gets none and the Channel coast gets the right country. A section through a ready-made ground model shows the profile only and says it cannot tell ground from vegetation.

Found during the check: the Environment Agency service is slow and rate-limits. Four parallel requests drew a 504 and then "429 Too Many Requests". England now goes one 500 m request at a time, and a 429 waits as long as the server asks; under the limit 1.9 sq km took about 15 minutes. The Toolbox's reachability dot can read "Cannot be reached" while a download is holding the service.

Out of reach, named in `open_resources`: historic aerial photographs and declassified CORONA imagery (both need a USGS EarthExplorer account), Denmark's lidar (account), the Archaeology Data Service and EAMENA (no open bulk access checked), and other national lidar not yet checked (Slovenia, Spain, Scotland).
Tests: `pytest -m live` passed 7 of 8 on the first run. Monks Mound failed when a USGS server dropped a connection partway through the download, so tile reads now retry; rerun, it passed. Offline tests pass 4 of 4.

### 2026-11-12, N7

Settings now has a **Test** button beside the agent model and the second-look model. It sends the model one short message at the chosen effort step and shows the result beside the picker ("Answered at Medium", or "Failed" with the provider's message underneath). Results are kept between launches. Both model pickers, in Settings and in the message box, label each tested model "tested" or "failed test", with the step and message in the tooltip. The effort note in Settings and in the message box's effort popover says whether the chosen step was tested with this model, and on which day, and says "not tested" otherwise. Nothing in the app claims a step works without a test. When the engine retries a failing provider, the last error it reports is kept, so a timeout can name the reason.

Check, in the running app: Opus 5.5 at Medium answered in about 4 seconds, and the note read "Medium was tested on Nov 12, 2026 and the model answered." G1 · Kimi K3.1 Pro at High gave no answer within two minutes and was marked "failed test" in the picker. Called directly through the OpenCodex router, both opencode-go Kimi models hung for 100 seconds with no reply, so the failure is the provider's. Passed.

Not checked: a provider that refuses a step outright with a message (none was found in this session).

### 2026-11-12, N9 (built, waiting for Chris's review)

- **Short chat titles.** A chat started from free text gets a name of two to five words, written by the agent model at its lowest effort step in a separate short request, then set with `thread/name/set`. Old chats without a name are named one at a time when the list loads. Seen in the app: "Maiden Castle Lidar Ramparts", "Southern Ohio Site Gaps", "Choosing a Lidar Search Area", "Terrain Tiles and Rampart Analysis". Those first titles came out in Title Case with "Lidar" capitalised, so the request now asks for sentence case with lidar in lowercase. The four already named keep their names.
- **Welcome guide.** The step names at the top only went back, so a returning reader could not jump ahead. They now open any step once the guide has been seen, except First project before the engine runs. Checked: steps 2, 3 and 4 open, and Welcome again. The opening line now says what Dighouse is for: "Open archaeology on your Mac. AI agents search public lidar for places people built and check what they find. You make the calls."
- **Settings.** The account line in How it runs no longer shows the email address. Data and privacy now names every service the tools contact (the national lidar services, QLever and Pleiades were missing).
- **Toolbox.** The new sources, the sky view and the export are in it (see N6).

Screenshots for review: `outputs/dighouse-26-welcome.jpg`, `dighouse-27-how-it-runs.jpg`, `dighouse-28-models.jpg`, `dighouse-29-toolbox.jpg`, `dighouse-30-privacy.jpg`. N9 is done when Chris has no "looks generated" notes on them.

### 2026-11-13, N10 and a chat that would not open

- **Old chats would not open.** Opening "Terrain Tiles and Rampart Analysis" in Maiden Castle showed "paginated threads do not support thread/read(includeTurns=true)". Codex 0.146.0 stores newer chats page by page and refuses to return their turns through `thread/read`. Dighouse now opts into the engine's experimental API and reads those chats a page at a time with `thread/turns/list`; older chats still come from `thread/read`. Checked in the app: the Maiden Castle chat opened with its whole history, an older chat in Cahokia ("Open lidar fetch and tiling") still opened through thread/read, and a new chat sent a message, got its short title, and opened again after switching away.
- **Open data** said the tools read seven services; there are 11 since N6. The sentence now counts the list.
- **Docs.** The README was rewritten with the icon, badges, screenshots of the current build, an animation of the treetops coming away at Serpent Mound, the tools by stage, every open data service, the rules, and what is checked and not. `concept.md` no longer describes a Notion mirror, a crew file or bulk screening as built, and lists the real tools and data. `HANDOFF.md` was rewritten for the state after this loop.
- Two leftover test chats ("Reply with the single word OK.") were archived so they do not show in the sidebar.

N10 passes. N2 and N9 still wait on Chris.


### 2026-11-13, N1 and N3 checks left open, and two fixes they turned up

- **N1, a run off screen.** The mark's sweep was timed from screenshots of the sidebar, by where the light was brightest in each frame. Idle, one sweep took about 2.5 seconds. With "Run the whole search" going in Mound City Group and Home on screen, one sweep took about 1.2 seconds. Passed. Hover and Reduce Motion are still not checked.
- **N3, stopping early.** A fresh Mound City Group project (from Home's starting places) ran on its own for about seven minutes: two terrain fetches, 12 tiles screened, 5 flags, a section through each, one modern-feature check, six literature searches and one source read and logged. Stop was pressed while the next modern-feature checks were running. Everything done before the stop was on the record: five candidate pages with sections, the source on both candidates it bears on (C-001 and C-003), and the notes. No run summary, since a stopped turn cannot write one; the notes hold every step for the next run. Passed. The source the agent read says Mound City has 24 mounds inside the wall; the agent's lidar count was 22.
- **A new chat could drop out of the sidebar.** The run above vanished from its project in the sidebar after a trip to Home and came back only a minute later. When a project opens, the app asks the engine for its chats, which takes several seconds; if the person starts a chat and leaves before the answer, the old answer replaced the saved list. Chats started since launch are now kept until the engine lists them. Checked: a chat sent and left for Home within a second was still listed on return.
- **A step cut off by Stop kept spinning.** Steps still running when a turn ends are now marked "(stopped)". Checked by stopping a modern-feature check partway.
- **Pleiades** now has a picture on its Open data card, made from the tool's own Pleiades data around Nîmes. The National Register card stays without one: the register returned no archaeological sites around Cahokia or Moundville, because it withholds their locations.

