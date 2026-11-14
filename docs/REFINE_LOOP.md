# Dighouse goal loop 5: plain, visual, and guiding

Last updated: 2026-11-14

Read [HANDOFF.md](HANDOFF.md) first, then the end of [POLISH_LOOP.md](POLISH_LOOP.md), whose Log says what loop 4 did. Loop 4 gave Dighouse its own look, a tutorial and one button that runs a whole search. Chris used that build and said it looks a lot more polished, and then said where it still falls short. This loop is his list.

## What Chris said (2026-11-14, after using the loop 4 build)

- **The Toolbox is too much text.** "It's just too much shit, too much text. It needs to be a lot more straightforward and clear." How a search works and Workflows are not interactive enough. The Toolbox "needs to be more visual, more interactive, more refined, better in every possible way."
- **Open data looks thin, and clicking a service shows almost nothing.** "There's only a couple things, the US, England, the ancient Mediterranean. Why is there not more? And then if you try to click them, you can't really see any information about them at all."
- **More tools needs to be better too.**
- **A project does not guide.** "Next: Check the flags. Some flags have no section yet. A slice through the laser points shows whether a shape is in the ground or in the trees. Who knows what that even means? The whole point is it's supposed to be autonomous archaeology, so it's supposed to be guiding you."
- **Models: the thinking effort text is not consistent with the system,** and it is odd that it says models were tested or not tested, when the list simply comes from OpenCodex.
- **How it runs needs refining. "Essentially everything under Settings needs to be better."**
- **Clicking "Dighouse" at the top of the sidebar should go somewhere.**
- **Research, in parallel:** could the same tool serve open astronomy as well as open archaeology? What would a version for the sky take?
- **From the end of loop 4:** fix what is still rough, retry the modern-features check, and cap the search report's length.

## Goals

Each goal is done when its check passes in the running app. Record the date and what was seen in the Log below. Work them in order; R6 runs beside the others.

| Goal | What | Check |
|---|---|---|
| R1 | **The short list first.**<br>- Clicking the mark or the name at the top of the sidebar opens Home.<br>- **The search report has a ceiling:** 400 words however many finds there are. It names the finds that need a decision first and says how many more are in the research record.<br>- **The modern-features check works when Overpass is down.** The public Overpass servers were still refusing at the start of this loop (502, "at capacity"). OpenStreetMap's own map service answers for a small area in two seconds, so use it as the second way in.<br>- **Models says what the system says.** The model list gives each thinking step a name, a one-line description and a default. Show those, in Settings and in the message box, and drop Dighouse's own wording. Remove "tested" and "not tested"; a model that fails says so in the chat, where the failure bar already is. | The mark opens Home from three pages. A project with 20 finds gives a report under 400 words (an offline test). check_modern succeeds on the three finds of loop 4's Serpent Mound search with Overpass still down, and the record and the report then say what the map shows. Settings › Models and the model panel show the same step names and descriptions as the model list for Terra and for Gemini 3.8 Flash, and the word "tested" appears nowhere. |
| R2 | **A project that guides, in plain words.**<br>- **One word for one thing.** A shape the agent marked is a **find** everywhere a person reads: not a flag here and a candidate there. A slice through the ground is explained the first time it appears.<br>- **The Next card says three things** in words a newcomer has: what the agent will do, why it matters, and what you will have afterwards, with about how long it takes. No sentence a first-timer has to read twice.<br>- **The agent leads.** The main button carries the search on to the end and reports back; doing one step alone is the second choice. When nothing is left but decisions, the card takes you to them.<br>- The stages, the workflow names, the strip, the review, the record, the report and the tutorial use the same words. | Screenshots of the overview at four points of a search (no terrain, tiles not looked at, finds not checked, decisions waiting) in which every sentence passes a read-aloud test: no "flag", no bare "section", no "candidate". A search for the old words in the app's sources finds them only in tool names and code. The main button, pressed on a half-done project, finishes the search and shows the report. |
| R3 | **A Toolbox you can use, with half the words.** Count the words on each tab at 1440 × 900 before starting; each tab ends at half or less.<br>- **How a search works:** one real search you step through by doing. Each stage is a large picture with one sentence, and something to press or drag: take the trees away, click a tile to see what the agent wrote, drag across a mound to see its slice, flip between the first and second opinion, open a source. The tools of a stage sit behind one small control.<br>- **Workflows:** one picture of a search from left to right, showing who does each part (the agent, a second model, you), with Run on each part and one button for the whole thing. Details open on a click, not by default.<br>- **Open data:** a map of the world showing where each service reaches, so "why is there not more" is answered by looking. Clicking a service opens a real page about it: a large picture made from its data, what Dighouse takes, where it reaches, whether it answers now, and one thing to try. A plain list of what is not read yet, and why.<br>- **More tools:** what the agent can already use beyond archaeology, as a tidy grid with one thing to try for each, and adding a tool server behind one button. | Word counts before and after, from the accessibility text. Every control on the four tabs pressed once and its effect seen. Screenshots of each tab in Earth, and of How a search works in Canopy and Graphite. Clicking each of the open data services shows its page with a picture. |
| R4 | **Settings, gone over page by page.** General, Personalize, Models, How it runs, Tools, Data and privacy, About.<br>- Half the words, the same row and the same controls on every page, nothing said twice.<br>- **How it runs** is one diagram of the three parts (model, engine, tools) with each part's live state on it and the one thing you can do about it, in place of three paragraphs and a second box.<br>- **Tools** is a short list a person can search, one line per tool. | Word counts before and after for each page. Screenshots of all seven pages. Every control pressed once. |
| R5 | **More of the world.** Add ready-made national ground models where an open service needs no account: try Switzerland, Belgium, Norway, Scotland, Wales, Spain, Poland, Estonia, Slovenia and Luxembourg, and keep the ones that fetch, build and tile on a known site. Say plainly which were tried and did not work, and what needs an account. | At least three countries added, each fetched and tiled live on a known site, with a picture made from its data in Open data and a live test. The "not yet" list in Open data matches what was tried. |
| R6 | **Open astronomy: research, no code.** Is searching open sky data the same shape of problem? What do people already do, which data needs no account, which searches would a person with agents add something to, what carries over from Dighouse and what would be new, and should it be a second field in Dighouse or a sibling app? | docs/research/open-astronomy.md, with a source for each claim, a recommendation, and what was not checked. Linked from HANDOFF.md under decisions for Chris. |
| R7 | **One product, then docs.** Screenshot every screen this loop touched, in Earth, and the Toolbox and a project in Canopy and Graphite. Retake the README pictures that changed. Bring README, concept, HANDOFF and this file into line with the app. | Chris's list above is answered item by item in the Log, each with a picture. README, concept, HANDOFF and this file agree with the app. main is pushed and clean. |

## Rules for this loop

- **Fewer words is the work.** If a screen needs a paragraph to explain itself, change the screen. One sentence per idea, 25 words at most, and a picture or a control wherever one can carry the meaning.
- **Plain words.** A first-timer must understand every label without knowing archaeology or lidar. Write lidar in lowercase. Never call a site new. A person decides and a person sends.
- **Cheap models only.** Every test that sends a message to a model uses primary / 6.1 Terra. Never test with Opus. The second-look model stays Gemini 3.8 Flash.
- **Keep it simple.** Reuse the app's parts (Controls.swift, Drawings.swift, MenuPanel, Theme). One look across every screen. Do not suggest Figma.
- **Recheck what you touch,** and the controls next to it.
- **Locations stay under private/.** Nothing in a record, a report or a chat carries coordinates.
- **Say only what was checked.** A hover, drag or pinch made by test tooling is not proof that a real pointer works.
- **One branch and pull request per goal,** squash-merged when its check passes: codex/ prefix, then gh pr merge --squash --delete-branch. Log first.
- **Work in the existing checkout,** /Users/chrissotraidis/GitHub/dighouse. No sibling clones in ~/GitHub.
- **Leave Chris's things as you found them:** his settings, his projects list, his models. His settings at the start of this loop are saved in ~/Documents/Codex/2026-11-14/dighouse-loop5/backup. Archive the test chats you make.

## How to build, check and drive the app

HANDOFF.md has the full list. In short:

- **Quick loop:** ~/Documents/Codex/2026-11-14/dighouse-loop5/work/devrun.sh makes a debug build, puts it in the bundle and relaunches with a clean environment. Finish each goal with app/scripts/bundle.sh for the release build, started with relaunch.sh from the same folder.
- **Tests:** uv run pytest -q (10 offline at the start). uv run pytest -m live talks to real services.
- **Driving it:** Computer Use, finding controls by their accessibility text. Keep each call under 30 seconds. Menus in the menu bar are not drawn. A right-click works; hover does not.
- **Pictures:** screencapture -o -x -l<window id> gives the window alone; bring Dighouse to the front first. bin/winlist in the work folder prints the window id.
- **Word counts:** take the accessibility text of the page, leave out the sidebar and the top bar, and count the words.
- **Scratch projects** from loop 4 are in ~/Documents/Codex/2026-11-14/dighouse-loop4/work (a finished Serpent Mound search in justgo-home/serpent-mound-ohio). They are not in Chris's list; open them with File › Open Project Folder and take them out of the list afterwards.

## Where things stand at the start

- **Merged:** loop 4 is done, A1 to A8 in PRs #22 to #29.
- **Tools:** 33. **Tests:** 10 offline, 8 live.
- **Overpass:** still down at 21:37 on 2026-11-14 (502 from overpass-api.de, no answer from the second server).
- **The model list** gives primary / 6.1 Terra six steps (low, medium, high, xhigh, max, ultra), each with a description, and low as its default. Dighouse shows its own notes for them and its own short names (Med, X-high).
- **Words the app mixes today:** flag, candidate and find for the same thing; section and slice; screen and look at.

## The loop (every turn)

1. Read HANDOFF.md, this file and the Log below.
2. Pick the lowest unfinished goal.
3. Build it, then run its check in the running app and look at the result.
4. Fix what the check shows. Repeat until it passes.
5. Record the result in the Log with the date. Run the tests, commit, open the pull request and merge it.
6. Stop when R1 to R7 are checked, when a decision is needed from Chris, or when the time Chris set runs out. Before stopping, write in the Log what is half done and where, and update HANDOFF.md.

## Log
