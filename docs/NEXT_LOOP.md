# Dighouse goal loop 2: make it find things

Last updated: 2026-11-12

This loop follows [GOAL_LOOP.md](GOAL_LOOP.md), whose goals G1 to G21 are logged there. Read [HANDOFF.md](HANDOFF.md) first. The first loop made the app understandable. This one makes it something a person can use to do real work, and finishes what was left unverified.

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

1. Read [HANDOFF.md](HANDOFF.md), this file and the Log below.
2. Pick the lowest unfinished goal. N1 and N2 come first: N1 is Chris's latest request and N2 is owed.
3. Build it, then run its check in the app and look at the result.
4. Fix what the check shows. Repeat until it passes.
5. Record the result in the Log with the date, run the tests, commit and push.
6. Stop only when N1 to N10 are checked, or when a decision is needed from Chris.

## Log

Nothing yet.
