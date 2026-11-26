# Dighouse launch loop: ready for a first-time user

Started and finished 2026-11-26, from Chris's review of the running app before a public release. Read [HANDOFF.md](../HANDOFF.md) first.

## Why this loop

Chris opened the app and sent eight screenshots. In his words: someone who downloads Dighouse should "very quickly set it up, add inference, be walked through how to do it, run it". Settings "needs to be overhauled", page by page: Account and models is "not clean and organized", What leaves this Mac is "poorly designed", Tools is a "long meandering list", and Advanced mixes About with everything else. Home "just goes on and on", its greeting is "too blocky" and How it works is unclear. The Toolbox wants "another coat of paint". On the New project map it is hard to tell "where's lidar, where's not", and the maps "are slow to load" and do not zoom as expected.

## Goals

| Goal | What | Check |
|---|---|---|
| L1 | **A first run that sets itself up.** The guide has three steps. The engine and the tools are fetched without a press, the model step offers the two accounts, and the last step starts a guided search. | In an empty home folder, signed out and signed in: the tools prepare while the first page is read, and the guide ends in the first project. |
| L2 | **Settings, organized.** Six parts, About on its own. Every group has a heading with its status at the right. | Each page seen at 1440 × 900, and every rewired switch pressed. |
| L3 | **A shorter Home.** A first visit explains and offers the first project. After that Home is your own work: the message box, where you left off, what waits. | Both seen in the running app. |
| L4 | **The Toolbox.** One kind of tab bar, and no row of nine cards that can do nothing. | Seen with no project open and with one. |
| L5 | **A map that answers.** Loads at once zoomed out, says where lidar is, and zooms in steps. | World, region and area seen, each from a click. |
| L6 | **Docs and pictures** match. | The link check and the spacing check pass. |

## Log

- **L1, the first run.** The welcome guide went from four steps to three: Welcome, Set up, First search. The page on how a search works and the list of eleven places to choose from are gone from it (the Toolbox and Home hold both). `AppState.getReady` starts when the guide opens on a first run: it installs the Codex engine if the Mac has none, prepares the tools, and starts the engine. The checklist now lists its steps in the order they depend on each other (the engine, the tools, the model: the sign-in button used to sit second and stay grey until the tools, listed third, were prepared), shows a number, a trowel or a tick for each, and offers **A ChatGPT account** and **An OpenAI API key** side by side.
  - **A bug found on the way:** the engine lists models to a person who has not signed in, so Continue lit up with nobody signed in and the first message would have failed. `AppState.modelReady` asks for a sign-in, or for models from a router.
  - **Seen** in an empty home folder with its own settings: the first page fits the window without scrolling; on Get started, "Preparing 64 tools" with the trowel, and a tick about a minute later. Signed out: the two accounts, Continue off, "Continue lights up when a model is ready." With the sign-in linked: three ticks and the model menu with no press, Continue, then **Start the guided search** opened New project on Serpent Mound with the tutorial's bar and its ring on Create project.
  - **Not checked:** the engine download (this Mac has Codex, so the install did not run), a ChatGPT sign-in through the browser, an API key sign-in, and the tutorial past its first step.
- **L2, Settings.** One column in the middle of the page, a title with its icon, and six parts.
  - **Account and models:** the three summary cards are gone. One account card says who is signed in, the plan, how much of it is left as a bar, and the name that signs decisions. The search, Second opinions and Claude Code each have a heading with a status at its right ("Codex 0.171.0 is running"). Thinking effort is a row of six steps in place of the wide slider.
  - **Data and keys:** On this Mac (projects folder, space used, app data), then Privacy as two cards side by side, **Stays on this Mac** and **Leaves this Mac**, with the version check's switch in its own line. A key says **Not added** with a box to paste into, or **Added** with Replace and Remove.
  - **How it looks:** the colours first, then text size and how a project opens as switches.
  - **Tools:** the 64 tools fold into the six stages, each row with its number, its first three tools and a count. A stage unfolds to a table of each tool and what it does. A search unfolds every stage with a match. Tools from other apps follow.
  - **Advanced** keeps How it runs and Models on offer. **About** is new: the version, new versions, the welcome guide, Report a problem.
  - **Seen** at 1440 × 900, and How it looks, Advanced and About at 1280 × 800. **Pressed:** text size (Large and back), how a project opens (both ways), thinking effort (Medium and back; the settings file read back standard, split, high), a tool stage unfolded, and in the empty home a key saved (Added, Replace, Remove) and removed (Not added).
  - **Not pressed:** Check, Add to Claude Code, Restart, Sign in, Choose…, Free, Report…, Copy, and the version check's switch in Privacy. Their code did not change, only where they sit.
- **L3, Home.** A first visit (no project, or the first one under way) shows the pitch and the slider, the message box, **Start your first project**, **How it works** as three cards that open the Toolbox's real search at that stage, three ways to start, and Places to start. After that the pitch is gone: a greeting in plain type with the totals and **Find something**, the message box, **Where you left off** (the three projects worked in last, each with where it stands), and **Waiting for you**, which switches between the strongest leads, now five cards with a picture of the ground cut around each find, and the projects that hold finds. Places to start has three tabs: known sites, open surveys, and the map with its legend as a row of marks. The old How it works block with its folder listing is gone from Home.
  - `ProjectStore.Lead` keeps where the find sits on its tile, so the glances are read once more after this update.
  - **Seen** with the test copy's 104 projects at 1440 × 900 (the first screen ends at Start a new search, and the whole page is about two screens) and in an empty home. **Pressed:** By project (five rows with Decide, "16 more projects"), Strongest leads, The map.
  - **Not pressed:** a lead's card and a card under Where you left off. They call what Look and the greeting card called.
- **L4, the Toolbox.** The tabs are the shared switch, with icons. With no project open, In a project is one row of the nine steps and an **Open a project** menu (the sidebar's projects, without blind tests). With a project open the nine cards show as before, and the next step wears a tan edge and says Next. **Seen** both ways; **pressed:** Open a project, a project in it, the What it can read tab.
- **L5, the New project map.** Zoomed out, the map is Apple's plain dark map, which loads at once and shows the shading clearly; within about 200 km it turns to photographs. The shading stays until about 50 km, and a mark beside the hint says "Open lidar: England" or "No open lidar here" for the middle of the map. A click on the world goes to a region about 550 km across; a click there places the area and goes to it. The map's own zoom buttons are on, and **The world** goes back out. The ground you have searched is drawn by the map itself as circles: the test copy's 142 areas were 142 views laid over the map.
  - **A bug found on the way:** setting how much the map shows before it arrived changed the kind of map mid-flight, and the map stayed where it was. It is read on arrival now.
  - **Seen:** the world, a click on England (the region, "Open lidar: England"), a click near Wallingford (the area placed, the map on it in photographs, "Wallingford area" suggested, the Environment Agency's 1 m model listed).
  - **Not pressed:** The world, the zoom buttons, and Show how much is on record. Not timed: how long each view takes to load.
- **L6, docs and pictures.** README, GETTING_STARTED and SETUP describe the three-step guide and where About is. The README's pictures of Home, New project and the Toolbox were retaken in the empty home at 1366 × 974 and 1440 × 900. `Segmented` in `Controls.swift` is the one switch between a few choices.
  - **Checks:** 67 offline tests pass (the spacing scale and the link check among them), and the app's 13.
  - **Words:** not counted from the accessibility text, as DESIGN.md asks. As a stand-in, the words in each file's quoted text: Settings 1,016 to 1,026, Home 1,538 to 1,373, the welcome guide 504 to 580 (three pages in place of four, with more words for each step's states).
  - **For checks:** `-openPage settings` (or toolbox, new, welcome), `-settingsPart "Data and keys"`, `-hideSidebar YES` and `-windowSize 1440x900`.
  - No prompt, skill, feature guide or tool changed, so the smoke test and the blind tests were not rerun.

## Decisions taken (Chris, 2026-11-26)

- **Fetching without a press** is fine as long as the person is told. The first page now says so while it happens, beside Get started: "Getting ready: downloading the Codex engine from OpenAI's releases on GitHub." and then "Getting ready: preparing the archaeology tools, about a minute." The tools' line was seen in an empty home folder; the engine's was not, since this Mac has Codex.
- **A sign-in to continue** stays: the guide's Continue waits for a sign-in, an API key, or a router's models.
- **Tools from other apps** show in Settings, Tools, and still in the Toolbox.
