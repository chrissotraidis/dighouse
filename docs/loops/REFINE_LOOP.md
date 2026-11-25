# Dighouse goal loop 5: plain, visual, and guiding

Last updated: 2026-11-14

Read [HANDOFF.md](../HANDOFF.md) first, then the end of [POLISH_LOOP.md](POLISH_LOOP.md), whose Log says what loop 4 did. Loop 4 gave Dighouse its own look, a tutorial and one button that runs a whole search. Chris used that build and said it looks a lot more polished, and then said where it still falls short. This loop is his list.

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

### R1, the short list: done 2026-11-14

- **The mark opens Home.** The mark and the name at the top of the sidebar are one button. Pressed from the Toolbox, Settings and an open project, each time the title bar read Home.
- **The report has a ceiling of 400 words.** Decisions come first, one line per find with the agent's suggestion and what each check showed. Finds that do not fit are counted: "13 more finds wait for your decision." Notes are written in full when there is room and cut at a clause when there is not. An offline test builds 20 finds with long notes and gets a report under 400 words. The Serpent Mound report went from 546 words to 376 with all three finds in full.
- **The map check has a second way in.** When both Overpass servers fail, check_modern asks OpenStreetMap's own map service for a 4 km square, and sorts roads, buildings and mapped sites by distance itself. If the square holds too much, it asks for the radius alone and says how far it looked. Servers that failed are left alone for ten minutes, so the next check does not wait for them. Overpass was still down (502 and a timeout). In the app, Terra ran the check on C-001, C-002 and C-003 of the Serpent Mound search and all three succeeded: paths near each, the museum near two, and Serpent Mound itself among the mapped sites. The record and the report now say what the map shows ("Open maps: paths or roads and buildings within 150 m").
- **Models says what the model list says.** Step names are spelled out (Medium, Extra high). The line under the slider is the list's own description, with "The default for this model" on the default step. Read in the app for all six of Terra's steps and all five of Gemini 3.8 Flash's; each matched ~/.codex/opencodex-catalog.json. The same line is in the message-box panel.
- **Testing is gone:** the Test buttons, Test both, and the "tested / not tested" notes in Settings and in the model list. A model that fails says so in the chat. The word "tested" is on neither screen.
- **Tests:** 12 offline pass (two added: the second way in, and the ceiling).
- **Not checked:** the fallback in a town dense enough to make the map service refuse the 4 km square, other than in the offline test.
- **Pictures:** [the report](loop5/r1-report.jpg), [Models](loop5/r1-models.jpg), [the model panel](loop5/r1-model-panel.jpg).

### R2, a project that guides in plain words: done 2026-11-14

- **One word for one thing, everywhere a person reads.** A shape the agent marked is a **find**. A cut through the laser points is a **slice**. The agent **looks at** tiles. Another model gives a **second opinion**. The bare-ground model is **the ground**. The old words (flag, candidate, section, screen, second look, terrain) are gone from the app's text, the research record, the search report, the project's own PROJECT.md and METHODOLOGY.md, and the workflow prompts. They remain in tool names and code. A search of every text string in the app's sources finds none. The agent's skill has a Words section, and in the test search the agent wrote "grouped as one find" and "a 35 m slice".
- **The Next card says what, why and what follows.** For example: "Next: check 1 find. The agent cuts a slice, straight down through the laser points, to see if each find is in the ground or only in the treetops. It also looks on open maps for roads and buildings. After that: a second opinion, what is published, and a report. About 5 minutes in all."
- **The agent leads.** The main button is Find and report back, which does everything left and ends with the report. The step alone is the smaller button ("Only check 1 find"). When finds wait for you, the card reads "Your turn: decide 3 finds". A finished search offers the report and Widen the search. In the tutorial the card keeps to one step at a time.
- **Commands renamed to match:** /ground, /look, /second-opinion. Workflows: Get the ground, Look at the tiles, Check the finds, Get a second opinion, Suggest decisions.
- **Seen in the app at four points:** no ground, tiles not looked at, finds not checked, decisions waiting ([one](loop5/r2-1-no-ground.jpg), [two](loop5/r2-2-tiles.jpg), [three](loop5/r2-3-finds-not-checked.jpg), [four](loop5/r2-4-decisions-waiting.jpg)), and [the review](loop5/r2-review.jpg).
- **The main button on a half-done project:** a scratch Mound City project with its ground fetched and six tiles not looked at. Find and report back was pressed at 22:08; at 22:11 [the report was on screen](loop5/r2-5-report-after-main-button.jpg) with two finds, each with a slice, a map check, sources read and a suggestion. So the time lines on the card were cut to what was seen: about 5 to 15 minutes for a small area.
- **The tutorial's rings** still sit on Get the ground (step 2) and Next: Look at the tiles (step 3). Checked by pointing the tutorial at two scratch projects; the whole tutorial was not run again.
- **Found on the way, and fixed: OpenAlex now meters requests without a key.** A network address shares 100 searches a day, and a busy hour brings refusals. search_literature now waits once when asked to, then asks Crossref, which needs no key. One offline test added; 13 pass.
- **Found on the way, not ours to fix:** the second-opinion model, AG · Gemini 3.8 Flash, was refused by its provider during the test search (403, "This service has been disabled in this account for violation of Terms of Service"). Dighouse showed the provider's message on the record, the report said "Second model: has not looked", and the card offered [Get a second opinion or Decide 2 finds](loop5/r2-second-opinion-missing.jpg). No second opinion was obtained in this loop. Chris needs to look at that account.
- **A finished search:** both scratch finds were decided in the review, and the card then read ["This search is finished"](loop5/r2-6-finished.jpg), with Read the report and Widen the search.
- **Not checked:** the "Nothing here looked built" card, which needs a project where no tile was marked. Widen the search was not pressed.

### R3, a Toolbox you can use, with half the words: done 2026-11-14

Words on each tab at 1440 × 900, counted from the accessibility text of the page (sidebar and title bar left out):

| Tab | Before | After |
|---|---|---|
| How a search works, per stage | 357 to 486 | 113 to 150 |
| Workflows | 602 | 153 |
| Open data | 343 | 136 |
| More tools | 292 | 139 |

- **How a search works** is one large picture per stage with one sentence above it, and each picture has something to do.
  - **Choose:** a map of where lidar is open, or the sites on record at Cahokia.
  - **Bare ground:** drag the trees away.
  - **Look:** press a tile to read the agent's own note.
  - **Check:** [drag a line across Monks Mound and the slice is drawn beside it](loop5/r3-how-4-slice.jpg), from the real ground and the highest laser returns, with its length and rise. The second opinion and the map check are the other two.
  - **Read:** press a source to see what the agent does with it.
  - **Record:** the record the run ended with, and Try it yourself.
  - The tools of a stage are behind one button ("6 tools"), and the five rules behind one line.
- **Workflows** is [one picture](loop5/r3-workflows.jpg): three lanes (agent, second model, you) and eight parts in order, each showing where the open project stands. Press a part and one line under the picture says what it does, with its Run button. Find and report back sits above it. The four that need no project are a row of buttons.
- **Open data** opens with [a map of the world](loop5/r3-data.jpg) and Europe drawn larger beside it: the United States, the countries with a national ground model, the surveys flown for archaeology, and the region of ancient places on record. Pressing a name under the map brings that layer forward. So "why is there not more" is answered by looking: open lidar that needs no account is in few places. Each service is a tile, and pressing it opens [a page](loop5/r3-data-page.jpg) with a large picture made from its data, what Dighouse takes, where it reaches, whether it answers now, and one thing to try. The National Register had no picture; [it has one now](loop5/r3-data-page-register.jpg), made from its public layer. "Not read yet, and why" is a short list behind one line.
- **More tools** is [a grid](loop5/r3-more.jpg) with one request to try on each. Pressing one puts the request in the message box of a new chat, unsent. Adding a tool server is behind one button.
- **Every control pressed once and its effect seen:** six stops, both sides of Choose, the handle, six tiles, three checks, a slice dragged, a source, the tools list, the rules line, Back, Next, Run this stage (started on a scratch project and stopped), Try it yourself; four workflow buttons and eight lane parts, Run (Show open surveys started a chat); four map layers, eleven service pages, Ask the agent (the question was shown; cancelled), Check status, the not-yet list; a More tools card, the add form (opened, nothing added), the other-plugins line.
- **Fixed on the way:** Run on a workflow that needs no project now always starts a chat of its own from the Toolbox, Home or Settings. Before, it went into whichever general chat was open.
- **Looks:** [Canopy](loop5/r3-how-canopy.jpg) and [Graphite](loop5/r3-how-graphite.jpg) seen on How a search works; all four tabs seen in a narrow window (864 wide), where the pictures stack and the lanes scroll sideways.
- **Not checked:** the slice was dragged by the test tooling, not a hand on a trackpad. Links to the services' own websites were not pressed. Find and report back was not pressed from this tab (it was in R2, from the overview).

### R4, Settings gone over page by page: done 2026-11-14

Words on each page at 1440 × 900, counted the same way as R3:

| Page | Before | After |
|---|---|---|
| General | 62 | 24 |
| Personalize | 78 | 17 |
| Models | about 175 at the start of the loop, 82 after R1 | 82 |
| How it runs | 416 | 119 |
| Tools | 622 | 138 |
| Data and privacy | 196 | 90 |
| About | 127 | 49 |

- **One row on every page:** a name, at most one short line, and one control on the right. Notes that repeated the name are gone.
- **How it runs is [one picture](loop5/r4-how-it-runs.jpg):** you, the model, the engine and the tools in a row, each with what it does in three or four words, its state now (your name, the chosen model, the engine's version, "33 ready"), and the one thing to do about it (Change, Restart, See them; Get Codex, Get uv or Prepare when something is missing). Under it: where the models come from with a count for each maker, the account, and the web. The three long paragraphs and the second box are gone.
- **Tools is [a searchable list](loop5/r4-tools.jpg):** the tools of each stage as names. Press a name for its one line and the name the agent calls it by. Typing "slice" left one tool; "zzzz" said "No tool matches".
- **Pictures:** [General](loop5/r4-general.jpg), [Personalize](loop5/r4-personalize.jpg), [Models](loop5/r4-models.jpg), [Data and privacy](loop5/r4-data-and-privacy.jpg), [About](loop5/r4-about.jpg).
- **Fixed on the way:** the line under Models said "from the Codex sign-in" when the router had not answered a check at launch, though its models were listed. It now also looks at the list itself.
- **Pressed and seen:** the layout menu, the welcome guide (opened and closed), Choose (panel opened, cancelled), the three text sizes, the three looks (in R3), the model lists and the effort slider (in R1), Change, Restart (the button greyed while the engine restarted), See them, the tool search, a tool name, Add tools (went to More tools), Copy on About (the versions were on the clipboard; the earlier clipboard was put back).
- **Not pressed:** the Show buttons (they open Finder windows), and the links that open a browser (OpenCodex, GitHub).

### R6, open astronomy research: done 2026-11-14

- **The report is [research/open-astronomy.md](../research/open-astronomy.md),** about 2,800 words with a source linked for each claim, written by a helper agent beside the other goals and then read through and checked here. No code was written.
- **Its answer:** the method carries over almost whole. People already do each part of it for the sky as separate projects, and survey teams already run classifiers over most of the data, so the chance of adding something is small and sits in a few places. The best fits are faint companions and tidal features around nearby galaxies in Legacy Survey images, and variable stars in ZTF checked against the AAVSO index.
- **Where it breaks:** privacy flips (an object's coordinates are its identity), nobody can look at every tile of sky, and confirming most things needs a telescope.
- **Its recommendation:** a second field inside the one app, built as a separate tool server on the shared record core, about 19 tools. The cheapest first step is to write that tool server and run one search in plain Codex before touching the app.
- **Archaeoastronomy** (how ancient sites line up with the sky) is a real, small addition to the archaeology tools: a horizon profile and an alignment check, a few hundred lines.
- **Checked a second time here:** the OpenAlex notice (keyless requests share $0.10 a day for each network address, which is 100 searches), the CDS notice of a cybersecurity incident dated 9 November 2026, and five of the cited arXiv records, whose titles matched.
- **Not checked,** as the report says itself: nothing behind a key, none of the five searches was run, and whether vision models read faint features in sky images is untested.

### R5, more of the world: done 2026-11-14

- **Four national ground models added,** each needing no account: Flanders (Digitaal Vlaanderen, 1 m), Norway (Kartverket, 1 m), Estonia (Land and Spatial Development Board, 1 m) and Switzerland (swisstopo, 0.5 m). With England, the Netherlands and France that makes seven, and eight countries with the United States.
- **How each is read.** Flanders and Estonia answer the same kind of request as England. Flanders wraps its picture in a description, which is now unwrapped. Norway's server wanted the older form of the request. Switzerland has no such service: its model is one file for each square km, so the tools ask its catalog which files cover the box, take the newest of each, and read only the part needed.
- **Each fetched and tiled live on a known site,** by the live test (fetch, tiles, a slice): Hill 60 near Ypres, the Borre mounds, Varbola stronghold, and the Vindonissa amphitheatre. The six national models pass in two minutes.
- **A whole search in Norway, in the app:** a scratch project at Borre, Find and report back pressed at 23:08, [the report on screen at 23:14](loop5/r5-borre-report.jpg). The agent chose Kartverket's model itself, looked at 9 tiles, marked 3 finds on the mounds, checked open maps, read the county's page on Borrehaugene and suggested "already published" for each. [The overview](loop5/r5-borre-overview.jpg) and [a record](loop5/r5-borre-record.jpg).
- **Fixed on the way:** a slice through a ready-made ground model was reported as "not clearly in the ground". Such a model has no treetops in it, so the slice can measure a shape but cannot place it. The record, the review and the report now say "measured on a ready-made ground model".
- **Open data** shows the seven countries on [its map](loop5/r5-data.jpg) and has a page with a picture for each new service: [Flanders](loop5/r5-page-be.jpg), [Norway](loop5/r5-page-no.jpg), [Estonia](loop5/r5-page-ee.jpg), [Switzerland](loop5/r5-page-ch.jpg).
- **Tried and not added** (the "Not read yet" list in Open data says the same):
  - **Spain:** the open service gives a 5 m model, too coarse for most earthworks.
  - **Scotland, Wales and Slovenia:** open lidar, published as files by map sheet; no service was found that hands over an area. Slovenia's portal said parts of it were down.
  - **Poland:** its service did not answer from here (connection timed out).
  - **Luxembourg:** its service answered but listed no ground model.
  - **Denmark, Finland and Sweden** ask for an account or a key, and were not tried.
- **Not checked:** the second opinion on the Norway finds (the provider refused, as in R2). The licence wording for Flanders and Estonia was taken as "open data" and not read in full. Norway north of the Arctic Circle and the Swiss high Alps were not fetched.

### R7, one product, then docs: done 2026-11-14

**Chris's list, item by item.**

| What Chris said | What changed | Picture |
|---|---|---|
| Clicking "Dighouse" at the top should go somewhere | The mark and the name are one button that opens Home | [r1-models.jpg](loop5/r1-models.jpg) (top left) |
| The Toolbox is too much text, and not interactive enough | Each tab has half the words or fewer, and a picture to press or drag. Counts are under R3 | [r3-how-1.jpg](loop5/r3-how-1.jpg), [r3-how-2.jpg](loop5/r3-how-2.jpg), [r3-how-3.jpg](loop5/r3-how-3.jpg), [r3-how-4-slice.jpg](loop5/r3-how-4-slice.jpg), [r3-how-5.jpg](loop5/r3-how-5.jpg), [r3-how-6.jpg](loop5/r3-how-6.jpg) |
| How search works and workflows should show more | A slice you cut yourself across Monks Mound; workflows as three lanes showing who does each part | [r3-how-4-slice.jpg](loop5/r3-how-4-slice.jpg), [r3-workflows.jpg](loop5/r3-workflows.jpg) |
| Open data: "only a couple things… why is there not more?" | A map of where open lidar reaches, and four more countries: Flanders, Norway, Estonia, Switzerland. A list of what is not read yet, and why | [r5-data.jpg](loop5/r5-data.jpg) |
| "If you try to click them, you can't really see any information" | Each service opens a page with a large picture made from its data, what Dighouse takes, where it reaches, its status and something to try | [r3-data-page.jpg](loop5/r3-data-page.jpg), [r5-page-no.jpg](loop5/r5-page-no.jpg) |
| More tools needs to be better | A grid with one request to try on each; adding a tool server behind one button | [r3-more.jpg](loop5/r3-more.jpg) |
| "Next: Check the flags… who knows what that even means?" It should be guiding you | One word for one thing (find, slice, look at, second opinion). The card says what the agent will do, why, and what follows; the main button carries the search to its end | [r2-3-finds-not-checked.jpg](loop5/r2-3-finds-not-checked.jpg), [r2-4-decisions-waiting.jpg](loop5/r2-4-decisions-waiting.jpg) |
| Thinking effort text is not consistent with the system | The names, the line under the slider and the default come from the model list | [r4-models.jpg](loop5/r4-models.jpg), [r1-model-panel.jpg](loop5/r1-model-panel.jpg) |
| It is odd that models are "tested or not tested" | Testing is gone. A model that fails says so in the chat | [r4-models.jpg](loop5/r4-models.jpg) |
| How it runs needs to be more refined | One picture of you, the model, the engine and the tools, each with its state now and one button | [r4-how-it-runs.jpg](loop5/r4-how-it-runs.jpg) |
| "Essentially everything under Settings needs to be better" | Seven pages on one row style, each with half the words or fewer. Counts are under R4 | [r4-general.jpg](loop5/r4-general.jpg), [r4-personalize.jpg](loop5/r4-personalize.jpg), [r4-tools.jpg](loop5/r4-tools.jpg), [r4-data-and-privacy.jpg](loop5/r4-data-and-privacy.jpg), [r4-about.jpg](loop5/r4-about.jpg) |
| Research open astronomy in parallel | A report with sources, a recommendation and what was not checked | [research/open-astronomy.md](../research/open-astronomy.md) |
| Fix what is rough, retry the modern-features check, cap the report | Under R1 | [r1-report.jpg](loop5/r1-report.jpg) |

- **Other looks:** a project and the Toolbox in [Canopy](loop5/r7-project-canopy.jpg) ([Toolbox](loop5/r7-toolbox-canopy.jpg)) and [Graphite](loop5/r7-project-graphite.jpg) ([Toolbox](loop5/r7-toolbox-graphite.jpg)). Canopy's accent is tan, which made the national models and the United States the same colour on the map; the national models are now green in every look.
- **Fixed on the way:** when only the agent's suggestions are left, the card's main button is Suggest decisions and the smaller one goes to the review. It used to offer the whole search for that one step.
- **README pictures retaken** at 1440 × 900 in Earth: Home, the Angel Mounds project, Maiden Castle, a record, the Toolbox, Open data, and two added, Workflows and How it runs. New project did not change and was kept.
- **README, concept and HANDOFF** use the new words, list the eight countries, the two fallbacks and the 13 offline tests, and no longer mention a Test button. HANDOFF is rewritten for whoever comes next, with what waits on Chris at the top.
- **Chris's things:** his settings were put back from the copy taken at the start and compared. The scratch projects were taken out of his list, and the chats this loop made in general chat were archived.
- **Not done:** the welcome guide still has its older, longer text. A sixth plan was not written; it should come from Chris's notes on this build.

### Final pass, 2026-11-15

Chris asked for one more pass: text that grows and shrinks with ⌘+ and ⌘−, more tasteful movement, and a more personal app.

- **Text size.** Five steps now, from Small (92 %) to Largest (130 %). ⌘= and ⌘+ both make text bigger and ⌘− smaller; each press shows "Text size: Large" for a moment at the top of the window ([picture](final/text-size-note.jpg)). Settings › Personalize lists the same five and says the shortcuts work too ([picture](final/personalize-largest.jpg)). Every page was looked at in Small and Largest at 1440 × 900, and the main pages again at Largest in a 900 × 640 window.
- **Fixed for large text:** the workflow lanes grow with the text, so "What is published" no longer cuts off ([picture](final/lanes-largest.jpg)). The stage card's buttons take a second row when the window is narrow ([picture](final/narrow-largest-toolbox.jpg)).
- **Movement.** A page, a Toolbox tab, a Toolbox stage, a Settings page, a workflow's detail, a welcome page and each find in the review fade and rise into place in about a third of a second, a piece at a time. A project's counts roll to their new number and a stage's tick lands with a small spring. Cards brighten under the pointer and dip when pressed; a place's picture eases in a little; the arrow on Home's cards moves toward its target. None of it runs with Reduce Motion on.
- **Personal.** Home greets you by first name and time of day, says which project you had open last and what it waits for, and counts your projects, finds and decisions; pressing it opens that project ([picture](final/home-small.jpg)). A project waiting on you says "Your turn, Chris: decide 2 finds" ([picture](final/your-turn.jpg)). The name comes from Settings › General.
- **Left over from loop 5:** the welcome guide has the shorter words now. More tools said "Nothing else is connected" for a moment after launch, before the engine had answered; it now says it is reading your Codex setup.
- **Fixed on the way:** the review suggested "modern feature" for any find with roads nearby, including Maiden Castle's ramparts, because the same summary lists historic places mapped there. A find beside a mapped historic place now gets no suggestion from the map alone.
- **Pressed and seen:** ⌘=, ⌘+ and ⌘− from Standard to Largest and back to Small (the setting changed each time and stopped at each end); the greeting card (it opened Maiden Castle); Decide 2 finds, Record and Done in a scratch project; the welcome guide opened and closed; every Toolbox tab and Settings page. Movement was checked in screen recordings at 60 frames a second.
- **Not checked:** a real pointer's hover (the test tools move the pointer themselves), and Reduce Motion switched on in System Settings, which was left alone.
- `uv run pytest -q`: 13 passed.

- **Docs:** the README is rewritten for a public release (what it is, why, how a search works, getting started, tools, data, rules, known sites, limits, contributing), with a new Home picture. [ROADMAP.md](../ROADMAP.md) holds what comes next and summarizes the open astronomy study as a possible second field. HANDOFF and concept link to it. Nothing was made public or released.
