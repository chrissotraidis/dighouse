# Dighouse goal loop: easy, fast, good-looking and exciting

Written 2026-11-25 from Chris's review of the app after the find loop and the seeing loop. The Log at the end says what was done and checked.

## Why this loop

The find loop made the search work over large areas and the seeing loop put the video's tools on the find card. Chris's review of the running app on 2026-11-25 found the parts around them hard to use:

- **Home** shows four cards in a grid of three, so one hangs on its own, and two of them overlap.
- **Zooming the app** with ⌘+ and ⌘− is slow, and looks bad while it redraws.
- **The Settings gear** does not go back where you were when pressed again.
- **The Toolbox** explains how the app is built instead of helping a person do something: four tabs, a workflow chart that is hard to read, 64 tool chips grouped by the app's own stages, and a data map that cannot be zoomed.
- **Models** assume Codex and the OpenCodex router. Most people will have neither, and many will use Claude.
- **Second opinions use up the account.** In run 18 every one of 8,065 finds got a second opinion, though only 687 were put to a person.
- **A project's page** leads with how the search works and the folder's files, not with what was found and what to do next.
- **The search does not feel alive.** The video's tools are in, but behind buttons on the decision card; while the agent works, a person reads a log.

## The aim

A person who downloads Dighouse understands Home at a glance, starts a search in one press, watches it work on the map, and opens any project to see in ten seconds what was found, what needs them and what comes next. Testing the app no longer uses up the account.

## Goals

| Goal | What | Done when |
|---|---|---|
| E0 | **Measure first.** Time ⌘+ and ⌘− and switching pages; count second opinions and their cost per session; try the tools under Claude Code; pictures of every page at two window sizes. | A table of times and costs, a yes or no on Claude Code with why, and the before pictures. |
| E1 | **Second opinions that do not use up the account.** Ask only about finds a person will see; finds kept on the map are asked only when raised. A lower-cost model of another maker by default. Read the usage left before each batch: below 20% second opinions pause, below 10% a session closes, and each says so. | Run 18's project needs about 690 opinions, not 8,065; a test cannot take the account below the floor. |
| E2 | **The basics feel right.** ⌘+ and ⌘− fast; the gear goes back where you were, and Escape closes Settings; even grids; one spacing scale. | Zoom answers in under 100 ms; every page checked at two sizes. |
| E3 | **Home.** One main action, Find something; three equal choices under it; recent work and what waits for you when there is some; nothing hanging. | Home reads at a glance, checked from an empty home folder and from a full one. |
| E4 | **Toolbox reformed.** Two parts: **Do something** (the workflows, each one card with Run) and **What it can read** (a data map that zooms and pans, a country or source picked to see what it gives). The tools behind a search. | Every workflow runs in one press; the map zooms; a source is found in two clicks. |
| E5 | **Models for people without Codex.** Setup starts from what a person has: a ChatGPT account, Claude Code, or an API key. One plain page says what runs the search, what checks it, and what each costs. OpenCodex optional. | A Claude path runs a small search, or E0 says exactly why it cannot yet and the page says so. |
| E6 | **Settings, all of it.** Grouped by what a person wants: account and models, data and keys, how it looks, advanced. One layout throughout. | Every setting has one place, one sentence and a control that works. |
| E7 | **A project that says where it stands.** At the top: what was found (the best leads first), what needs you, what is next. How it was done and the files lower down. The research record opens as a readable page in the app. | Any project says in ten seconds what was done and what to do next. |
| E8 | **A search you can watch.** Tiles light up on the map as they are looked at, finds appear as they are made, the best leads rise while it runs. The video's tools shown, not hidden: the slice, the 3D view, the flights and old maps reachable from the find on the map. | During a session the map changes visibly every minute; a find's views open from the map in one press. |
| E9 | **Proof.** A fresh-home run through the whole flow, before and after pictures of every page, the docs, and blind tests no worse wherever a method changed. | Logged with pictures and the list of what is still open. |

## Decisions (defaults Chris agreed or can change)

- **E1 first:** without it every test uses up the account.
- **Second opinions** move to a lower-cost model of another maker; Sonnet stays a choice.
- **Usage floor:** second opinions pause below 20% left; a session closes below 10%.
- **Claude:** first prove whether Claude Code can run the tools (E0), then design the path (E5). An API key route follows if Claude Code cannot.
- **Method:** nothing about how finds are made changes in this loop, except which finds are asked for a second opinion.

## Ground rules

The same as every loop (AGENTS.md): no AI credit anywhere, locations only under a project's `private/`, nothing called new, a person decides, blind tests guard method changes. One pull request per goal, squash-merged; every control rewired is rechecked in the running test copy.

## Log

- **2026-11-25.** Plan written from Chris's review and agreed. Work starts with E0 and E1.
- **E0, measured** (2026-11-25).
  - **Timing** (the app's own tour, `-measure YES -measureTour YES`, on the largest project, 8,065 finds): ⌘+ froze the window for 847 ms and ⌘− for 724 ms, because a new text size gave the whole window a new identity and every view, the map and the open project were built again. Opening that project stalls 1.9 s and reading it again after a change takes 1.3 s; switching tabs and pages is instant except Notes (0.65 s).
  - **Second opinions** in run 18: all 8,065 finds were asked, though only 687 reached a person. The second opinion is also what brings a measured rise or a bulk shape to a person, so "only the finds a person sees" cannot be known before asking. What can: a measured rise reaches a person only if its shape ranks in the top half of the project's rises, so the 3,288 below that cut could never reach a person whatever the answer. Asking the rest gives 4,777 opinions for exactly the same finds, 41% fewer. Fewer than that changes which finds reach a person (in Natchez the top-half rises brought 160 finds, the bulk shapes 182, the agent's own marks 345).
  - **Second-opinion models,** rated as in G3 on 102 known views with the find ringed (`scripts/rate_reviewers.py --ring`): Sonnet 5.5 89 right, 19 of 24 published features called built (G3); GPT-6 Luna 78 right, 9 of 24; Haiku 5.5 77, 9 of 24; GPT-6.2 Astra 76, 23 of 24 but "built" 48 times; GPT-6 Sol 69, 18 of 24, "built" 45 times. No model on the ChatGPT account matches Sonnet: the low-cost ones miss real features, the larger ones call almost everything built.
  - **Claude Code** runs Dighouse's tools: given the tool server in `--mcp-config`, Claude Code 2.1 with Haiku called `find_place` and `survey_area` and answered "USGS 3DEP covers it" for the Newark Earthworks in about 90 s. The app itself speaks only to Codex's app server, so a Claude path needs an engine of its own (E5).
  - **Before pictures:** 21 pages at the usual window size, kept on this Mac (`~/dighouse-ui-test/ease-pictures/before`), not in the repository, since project maps show places. The gear did not go back (pressed again it stayed on Settings).
- **E1 and E2's first part** (2026-11-25).
  - **Second opinions only where they can matter:** `ProjectStore.worthAsking` leaves out measured rises below the project's cut (unless a person raised them) and asks the rest best first, the agent's own marks first. Both queues use it: a session's areas and the Second opinion workflow. An app test keeps the rule in step with `ledger.layer`.
  - **GPT-6 Luna by default,** on the ChatGPT account, the lowest-cost model there that reads images; GLM-5.3 and Kimi K3 are no longer fallen through to. Those who had the old default are moved once, with a note; Sonnet stays a choice, and Settings, Models says what each finds. The record says "same maker as the agent" when it is.
  - **A usage floor:** second opinions billed to the ChatGPT account wait below 20% left (the sidebar shows a pause sign and why) and try again every five minutes; a running session is asked to close below 10%, saves its record, and ends within ten minutes; Find something does not start below 10%.
  - **⌘+ and ⌘−** no longer rebuild the window: the text size is one observed value that the views read, so only they redraw. The same tour: no stall over 250 ms for either key (847 and 724 ms before), and the Toolbox stayed on its tab while the text grew and shrank.
  - **The gear** goes back where you were when pressed again; Escape and ⌘, do the same. Checked in the test copy from the Toolbox's More tools tab.
  - **Checked with the account at 5%:** Find something refused to start and said why, making no project; Get a second opinion on a find waited, with the pause sign and "Second opinions wait: 5% of the account's usage is left" in the sidebar. **Not checked:** a session closing when the account crosses 10% mid-run, and Luna's opinions in a real session (both need usage).
