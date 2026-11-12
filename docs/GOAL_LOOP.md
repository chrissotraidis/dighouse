# Dighouse goal loop: redesign

Last updated: 2026-11-12

This is the standing work loop for turning the first Dighouse app into something a person would choose over a plain agent harness. It replaces the first build's layout, which Chris reviewed on 2026-11-12 and found confusing and unfinished.

## What Dighouse is

Dighouse is a model aggregator with an archaeology toolkit built in. It runs the Codex agent engine with any model the person has (their Codex sign-in, or every model in an OpenCodex roster), and adds what a plain harness lacks:

- tools that find, fetch and read open lidar, and viewers for the results
- a way to work out where it makes sense to look, from open catalogs
- records that hold their own evidence and refuse claims the evidence does not support
- workflows that hand work between models and stop for the person at the right points

Two kinds of people open it. One already knows the place and wants the project organized. The other wants to contribute and needs help choosing where to start. The first screen serves both.

## Design decisions

- **One place at a time.** The window shows exactly one of: Home, a chat, New project, Toolbox, Settings. The sidebar highlights exactly one row to match.
- **Chat works without a project.** A general chat can find places, compare areas and create a project. Opening a project adds the workspace beside the chat.
- **Home is a chat.** It opens with a message box and two clear paths, then live open surveys, published sites to learn on, and the person's projects.
- **Toolbox is its own section.** It shows the tool packs, the data sources and whether they answer, the workflows with their handoffs, what the person's Codex setup adds, and how to add a tool server.
- **Settings are a page in the window.** They explain the engine and the account in plain words.
- **The message box follows ChatGPT.** One model pill opens a thinking-effort slider with the model list behind it. Attachments cover images, audio, video and files.
- **Agent work is legible.** Plans, steps and sub-agents show in the chat, and long runs collapse.
- **Spelling.** "Lidar" is written in lowercase, as USGS and NOAA write it, and is explained on first use.

## Ground rules

- Keep it simple and consistent (AGENTS.md). One button style per role, one panel style, one list style.
- Recheck every control after changing how it is wired.
- Nothing is called new; locations stay under `private/`; a person decides and sends.
- The repository stays private and nothing is released until Chris says so.
- Starting points and surveys are listed only after their data was fetched from the live service.

## Goals

Each goal is done when its check passes in the running app. Record the date and what was seen.

| Goal | What | Check |
|---|---|---|
| G1 | Navigation and shell: one route, consistent sidebar, general chat, no email in the sidebar, draggable divider between chat and workspace | From every page, New chat, Home, Toolbox, Settings and each chat open the right view with one row highlighted. The divider drags and its width persists. |
| G2 | Engine reads off the main thread; opening a long chat does not freeze the window | Opening the screening chat (12 tile views) shows its content within about a second and the window stays responsive. |
| G3 | Message box: model pill, effort slider, searchable model list, attachments for images, audio, video and files, drag and drop | Changing model and effort changes what the next turn uses. An image, a video and a text file each attach and send. |
| G4 | Agent activity: plan checklist, grouped steps, sub-agents, plain errors | A run with a plan and a sub-agent shows both. A finished long run collapses to one line that expands. |
| G5 | Home: message box, two paths, live open surveys, published sites, projects | With no project, a message sent from Home starts a general chat. Open surveys load from OpenTopography. |
| G6 | Discovery tools: `find_place`, `open_surveys`, `survey_area`, with tests | Live tests pass. In a general chat the agent uses them to propose areas and creates a project that then appears in the sidebar. |
| G7 | New project page with a map area picker and a lidar coverage check | Picking an area on the map shows which open lidar covers it, and Create opens the project. |
| G8 | Toolbox: packs, data sources with live status, workflows with handoffs, connections from Codex, add a tool server | Every section renders with real data. Running a workflow from Toolbox opens the chat and starts it. |
| G9 | Settings page: General, Models, Agent engine and account, Data and privacy, About | Each section renders, and every control changes the setting it names. |
| G10 | Full pass at three window sizes, docs updated, committed and pushed | Every control clicked at full, default and half width with no dead ends. README and concept match the app. |

## The loop (every turn)

1. Read this file and the log below.
2. Pick the lowest unfinished goal.
3. Build it, then run its check in the app and look at the result.
4. Fix what the check shows. Repeat until it passes.
5. Record the result in the log, run the Python tests, commit and push.
6. Stop only when G1 to G10 are checked, or when a decision is needed from Chris.

## Log

### 2026-11-12

Every goal was built and then checked in the running app (Codex 0.146.0, OpenCodex running, 91 models).

| Goal | Result | What was seen |
|---|---|---|
| G1 | Passed | Home, New chat, Toolbox, Settings, New project and each chat open their own view, and one sidebar row is highlighted. New chat from Toolbox or Settings opens a general chat. The divider was dragged from 440 to 632 and the width was kept after a restart. No email in the sidebar. |
| G2 | Passed | The Angel Mounds run is a 5.4 MB chat with 18 tile views. It took about 6 seconds to open before the fix and 0.85 seconds after. The engine resumes the chat in the background, and the reader no longer rescans its buffer. |
| G3 | Passed, with two paths not checked | Picking AG · Gemini 3.8 Flash in the list changed the pill, and the next turn's record shows that model at medium effort. The effort slider was dragged from Medium to Extra high and back. A video, a text file and an image were attached and sent together; the agent described the video from its frames, quoted the text file and read the image. The files were attached by opening them with Dighouse. The Attach files panel and dropping onto the message box could not be driven by the test tooling. |
| G4 | Passed | "Run the whole search" on Angel Mounds showed a seven-step plan, tile views folded into "6 steps" lines, and sections shown inline. A run on the Middle Usumacinta project started two helper agents, waited for them, and finished its plan at 5 of 5. A table in the agent's reply now renders as a table. A chat that is still running shows a spinner in the sidebar and keeps running when another page is opened. |
| G5 | Passed | Home shows the message box, the two paths, the projects, four open surveys read from OpenTopography's catalog, and eight places with terrain. A message from Home starts a general chat. |
| G6 | Passed | `uv run pytest` (2 passed) and the live discovery test passed. In a general chat the agent called `open_surveys`, asked what interested me, called `survey_area` three times, proposed two areas, and created "Middle Usumacinta settlement" with `init_project`. The project card appeared in the chat and the project in the sidebar. |
| G7 | Passed | "Angel Mounds, Indiana" was found by name, the area was placed and moved by clicking the map, and the open lidar list changed with it (seven datasets, then three, then seven). Create opened the project. Starting from a survey fills the name, question and a tested area. |
| G8 | Passed | Workflows, Tools, Data sources and Connections render with real data: 22 tools, five sources answering, five tool servers and 25 plugins from the Codex setup. Running Second look from the Toolbox opened the project's records and got a recorded opinion from Gemini on all five candidates. A second tool server was added by command (a path with spaces, in quotes), listed with its 22 tools after the engine restarted, and removed. |
| G9 | Passed | General, Models, Agent engine, Data and privacy, and About render. The effort slider and model pickers change the setting. The account line explains whose Codex sign-in the models run on. |
| G10 | Passed, with one size not checked | Pages were checked at the default size, zoomed to the screen, and at half the screen. Layout buttons, the sidebar button, the Notes tab and the decision sheet were checked. The layout under 860 points wide, where the sidebar becomes an overlay, could not be reached by the test tooling and was not checked. |

Found and fixed along the way:

- A tool that returns a list sends one block per entry, so the survey list and the place search first showed nothing.
- Only four of the six surveys the catalog offers could be fetched and built: one index file has no readable projection, and one has almost no ground points. Home lists a survey only when it is in the tested list in `discover.py`.
- Leaving a running chat and coming back emptied it.
- A project's chats stayed listed under the next project that was opened.
- A workflow's chat took its whole prompt as its title.

Left over from the checks, on this Mac: the projects "Angel Mounds east plaza" and "Middle Usumacinta settlement" in `~/Documents/Dighouse`, and two short test chats.

Not built: a button that pushes records to Notion, bulk screening through the model router, a notarized download, and canopy in sections for datasets published as ground points only.
### 2026-11-12, second pass

Follow-up on the first pass, then Chris's second review.

Closed from the first pass:

- **Narrow layout (G10).** Checked at 700 points wide, where the sidebar becomes an overlay: every page, the overlay, the layout buttons and the records were opened with no dead ends.
- **Attach files panel (G3).** A file was chosen through the panel and appeared as a chip, and the chip's remove button cleared it. Dropping a file onto the message box is still not checked, because the test tooling cannot drag a file from Finder.
- **Prior art.** A prior-art run on Angel Mounds ended with nothing logged, because the agent could find titles but had no way to open them. Added `read_source` (web pages and PDFs) and abstracts in `search_literature`, with a live test. The workflow now tells the agent to log each source as soon as it knows the outcome.
- **Chat lists.** The engine takes about four seconds to list one folder's chats on this Mac, which has 2,300 Codex sessions. Lists are now kept between launches and refreshed behind, so a project's chats show in under a second.

Chris's second review, and what was done:

| Goal | What he said | What changed | Check |
|---|---|---|---|
| G11 | The chat cannot be widened by dragging its sides. | Both edges drag: the line between sidebar and page, and the line between chat and workspace. The handle is 13 points wide, lights up, shows a resize cursor, and is caught by AppKit so the drag never moves the window. Widths are kept. | Passed with the test tooling: the sidebar was dragged wider and back, and the chat divider narrower and wider. The old handle also passed this test while failing under a real mouse, so this needs Chris's hand to confirm. |
| G12 | "Archaeology tools: what tools? What is the agent engine?" | Settings ▸ How it runs explains the three parts in plain words: the AI model, the agent engine (Codex, what it is and who makes it), and the archaeology tools (count, what they do, the six stages), each with its status. | Passed: the page renders with live status, and "See what each tool does" opens the Toolbox. |
| G13 | Not every model has Ultra. | The slider shows the steps the selected model offers, with a label under each dot, and says how many it has. A model with no effort setting says so. | Passed: Opus 5.5 showed six steps, Kimi K3 four (Low, High, Max, Ultra), xAI Build "no effort setting". Dragging and clicking the slider changed the value. |
| G14 | The Toolbox is not well designed; "Answering" and "Connections" mean nothing. | Rebuilt around "How a search works": six numbered stages, each with what happens, why it matters, a picture made by the tools, its tools by plain name, and a Run button. "Open data" says what each service is, what Dighouse takes from it and what for, with Online or Cannot be reached. "More tools" lists what the person's Codex already has in plain words, and explains what a tool server is. | Passed: all four tabs render with real data. |
| G15 | The intro must make people want to use it and show why it beats ChatGPT. | Home opens with "See what the forest is hiding" and a picture of Serpent Mound that drags between treetops and bare ground, both built from the same open USGS points. Below: a table of what a chat app cannot do, and a real run at Cahokia with its section, second look and decision. A new chat offers example questions. | Passed: the reveal animates on arrival and drags; the comparison and the run render. |

The Serpent Mound pictures were made from `usgs:OH_StatewideP3_2_B21`: 2.2 million ground returns and 3.8 million others over the starting box. The treetop side is the highest return in each metre, the bare-ground side only the returns classed as ground.
