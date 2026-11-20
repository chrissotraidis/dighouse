# Dighouse goal loop: ready for strangers

Written 2026-11-20. Not started: Chris reviews this plan before any goal is worked.

Read [HANDOFF.md](HANDOFF.md) and [2026-11-20-research-session.md](2026-11-20-research-session.md) first. Earlier loops made Dighouse work. This one makes it hold up when people who have never met us open it, read its records and look for faults. People will criticise three things first: a tool that leaves the person to do the work, a screen they can't read, and anything that looks careless with heritage sites or with their Mac. Each goal below answers one of those.

## Chris's review, 2026-11-20

Chris used the app after the overnight research session and sent eight screenshots. His notes, in his order:

1. **Records leave the work to the person.** A Cahokia project shows 17 finds, every one "Needs your decision", and most are named after published mounds. The agent should look up the records itself and only bring the person what it couldn't settle.
2. **The checks don't say what to do.** "What is published: 5 read, 2 could not be opened" and a list of road names don't tell a newcomer that they can open the two pages themselves, or what the result means.
3. **Sources show raw machine text.** Clicking a source opened DataCite's JSON (the link points at `api.datacite.org`, not the paper's page).
4. **The project map doesn't zoom with the scroll wheel.** Only a trackpad pinch and the plus and minus buttons zoom (`MapView` in Workspace.swift has a `MagnifyGesture` only).
5. **Sonar can't be found.** Home and New project show only lidar; the NOAA and INFOMAR seafloor surveys appear nowhere a person would start.
6. **No push toward places worth looking.** Pick a place shows where open lidar exists, but not where few people have looked.
7. **Test it on a known site needs better layout,** and it can only be closed with Cancel.
8. **The Toolbox loses you.** Inside a tab you can't tell where you are or how to get back.
9. **Some labels sound machine-written.** "Every source, and whether it answers now" is the example.
10. **Keep the design.** Chris likes the look and the method. Refine; don't redesign.
11. **Security and usability both have to hold up** before release.

## Ideas from a reader

A reader on r/LiDAR (Sandiegosurf1) sent method ideas he wrote with ChatGPT. Treat each as an idea to test against the blind benchmark. Some of them, such as a 50 cm model for Navarre, haven't been checked yet.

- Run the Navarre sites at 0.5 m, then at 1 m and 2 m resampled from the same surface, beside the current 2 m model. If the two 2 m runs differ, the survey or how the ground model was built matters as well as the cell size. Repeat at a French site with IGN LiDAR HD (0.5 m, already supported) and a reliable published inventory.
- Look at shape across several scales: local relief with windows sized to the expected diameters, slices in two directions, and how many ground returns support the shape. A tree throw shows a pit beside its mound; a smooth bump over a gap in the points deserves less confidence.
- Add positive and negative openness beside slope. Show the agent and the person the same fixed-scale crop, with a wider view for context.
- Score false positives per square kilometre beside recall, include rough tiles with tree throws, and log where each miss happened: never marked when looking at tiles, turned down by the second opinion, or removed by the records check.

## Ground rules for this loop

- Everything in HANDOFF's rules still holds: few words, one word for one thing, lidar in lowercase, locations under `private/`, a person decides and sends, nothing is called new, tests that talk to a model use primary / 6.1 Terra.
- **A person still decides.** The agent does every lookup it can and suggests; the person confirms, singly or in a group. Nothing is written as decided without a person's name.
- **The benchmark guards the method.** A change to the prompt, skill, views or scoring ships only after the blind tests rerun, with recall and false positives per square kilometre no worse than before on the same sites.
- Fix what Chris pointed at before adding anything. A new feature in this loop must remove a step for the person.
- Say only what was checked in the running app.

## Goals

Each goal is done when its check passes in the running app (or, for the method goals, in a logged benchmark run). Work them in order. Anything the walk (G1) or the security review (G9) finds broken or high risk comes first.

| Goal | What | Check |
|---|---|---|
| G0 | **Land last night's work.** The tree holds uncommitted changes from the 2026-11-20 session (timed research, source PDFs, retries, tests). Review them, run the tests, and commit them as their own pull request before this loop changes anything. | `main` has the session's work, tests pass, and the tree is clean. |
| G1 | **Walk it as a stranger.** From clean settings, go from first launch through a project, a run, the records, Sources, Map, Toolbox and a blind test. Write down each place that needs a guess, shows machine text, traps you in a sheet, or leaves you unsure what happens next. Chris's notes 1 to 9 are on the list already. | A ranked friction list in the Log with screenshots. The goals below change if the walk shows something bigger. |
| G2 | **The agent settles what it can.** At the end of every search the agent looks up each find in the sources it read, the open maps and the registers, and leaves a suggestion with a plain reason. The Records list groups finds by suggestion: "Matches a published site", "Likely modern or natural", "Worth a closer look". A person can confirm a group in one step (their name and the shared reason go into each record) or open any one. Blind tests and known-site projects don't ask for decisions; they show a score. | On the Cahokia project, all 17 finds have suggestions without a button press. The published mounds are confirmed in one step with Chris's name on each record. Only finds without a match are left to look at singly. |
| G3 | **Each record reads in ten seconds.** Each record starts with two plain sentences: what the find is likely to be, and why. Each check ends with what it means and the next step ("2 pages refused the agent. Open them yourself"), and that button goes to those pages. Road names, pass numbers and measurements move under Details. | A newcomer can say what C-009 is and what to do about it without opening Details. Every check with a warning has a working next-step button. |
| G4 | **Sources a person can read.** Links go to the page a person reads (`doi.org`, the publisher, the register), never to an API. Existing records are migrated. Each source shows title, authors, year, whether it was read, and one line on what it says about the finds. If a page still returns JSON or XML, the app shows a readable card instead. | Every one of Cahokia's 26 sources opens to a readable page or card. A test covers the DataCite, Crossref and OpenAlex link cases. |
| G5 | **A map that moves like a map.** The project map zooms with the scroll wheel toward the pointer, pans by dragging, zooms on a double click and resets with one button. Pinch and the buttons still work. The same rules hold on every map in the app. | With a mouse and with a trackpad, zoom to one find on the Cahokia map and back out; click the find to open its record. |
| G6 | **No traps, and you always know where you are.** Every picker sheet closes with Escape or a click outside. Only a sheet with typing in it asks first. The Toolbox shows where you are and has one way back. Every label goes through a plain-words pass ("Every source, and whether it answers now" becomes something like "Data sources and their status"). | Each sheet and Toolbox tab is opened and left by mouse and keyboard with no dead end. The label pass is logged with before and after. |
| G7 | **Under water and where to look.** Home and New project show sonar coverage beside lidar in the legend, and Home has a clear way to start under water. Pick a place adds a "few published surveys" layer: open lidar with few published sites or studies in the registers, open maps and literature the app already reads. It is shown on a coarse grid with no site locations. | Thunder Bay and Irish waters can be found from Home without typing. The layer loads from live data for the US and one European country, and its grid hides exact places. |
| G8 | **Blind tests that explain themselves.** Each site card shows what it tests (big earthworks, small mounds, wrecks), how long it takes, and the last score. The underwater row is fully visible. After a run, the scorecard shows recall, false positives per square kilometre, and where each miss happened (see G10). | The picker looks right at full, half and narrow window sizes, and a finished Borre run shows all three numbers. |
| G9 | **Security review.** Write down what Dighouse can touch and test each item: the engine's sandbox and network access; the in-app browser (no file or custom schemes, no script bridge, downloads only on request); pages and PDFs the agent reads, treated as untrusted, with a prompt-injection test page; tools that take file names or paths, which must stay inside the project; where tokens and the Codex sign-in live and who can read them; logs and crash reports with no secrets; locked dependencies checked for known flaws. | A dated findings table in the Log, ranked. Every high finding fixed and retested. The injection page can't make the agent run a command, write outside the project, or send anything. |
| G10 | **Heritage and privacy hold up.** Exports, published projects, reports and README pictures carry no coordinates outside `private/`. Relief pictures of unpublished finds are kept out of anything shared, since terrain can be matched to a place. The "Reported to the heritage authority" path says who to tell in each supported country. | A test project with an unpublished find is exported and published to a private repository. Nothing in it places the find. |
| G11 | **Know where the benchmark loses finds.** Each blind run records, for every published feature: found, or the stage that lost it (never marked when looking at tiles, turned down by the second opinion, removed by the records check, outside the area). It also records the feature's size, height and the ground returns over it, false positives per square kilometre, and how many finds a person would have to look at. | Borre and Andía rerun with this, logged and compared with the last scores. |
| G12 | **Test the reader's ideas.** First check whether Navarre has a 0.5 m ground model that can be fetched. If so, run the Navarre sites at 0.5, 1 and 2 m from that surface and on the current 2 m model, then repeat at a French site with a published inventory. Add positive and negative openness, local relief at windows sized for 5 to 15 m and 15 to 40 m mounds, a second slice at right angles, a pit-beside-mound check for tree throws, and the ground-return support under each shape. Use them to rank finds; filter none out. | Each change is kept only if the benchmark shows it helps. The Log has the numbers for each, kept or not. |
| G13 | **Ready to hand over.** Walk G1 again with a fresh setup. Check every page at three window sizes and in all three looks. Update the README, HANDOFF, ROADMAP and pictures. Rerun the smoke test and the full benchmark. | The second walk finds nothing that stops a newcomer. Docs match the app. `main` is clean and pushed. |

## Decisions for Chris before G2

- **Group confirm.** Can one click confirm a group of "matches a published site" finds, with your name and one shared reason on each? The alternative is a quick one-at-a-time review with Return to accept.
- **Suggestions cost usage.** Should the agent suggest decisions automatically at the end of every search, or only when asked?
- **"Few published surveys" layer.** Is a coarse grid (about 10 km) the right level of detail, or should it stay off until a person zooms into a country?
- **Merging.** One pull request per goal, merged when its check passes (as in earlier loops), or held for your review?

## The loop (every turn)

1. Read this file and its Log.
2. Pick the lowest goal that isn't done.
3. Build the smallest change that passes its check. Reuse what exists: suggestions (`ledger.suggest`, `ReviewSheet`), slope and local relief (`terrain.py`), the answer keys and scorecard.
4. Run the check in the app, or the benchmark, and look at the result.
5. Fix what the check shows and repeat until it passes.
6. Log the date and what was seen, run the tests, commit and open the pull request.
7. Stop when G13 passes, when a decision above is needed, or when Chris's time runs out. Before stopping, write in the Log what is half done and where.

## Log

Nothing yet.
