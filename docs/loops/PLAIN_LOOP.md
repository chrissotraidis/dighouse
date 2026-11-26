# Dighouse plain loop: say what it is, and what happens next

Started and finished 2026-11-26, from Chris's third review that day, of the clear loop's build ([CLEAR_LOOP.md](CLEAR_LOOP.md)). Read [HANDOFF.md](../HANDOFF.md) first.

## Why this loop

Chris opened the rebuilt test copy and sent twenty screenshots. "It's decent but I'm still wanting it to be a little bit better." In his words:

- **Accounts:** "a lot of people are going to want to use Claude by default."
- **Space used:** "it'd be nice to have a better way to clear storage or know what's in storage."
- **Free keys:** "see what other services exist that could be added", and make adding one easier.
- **Looks:** when the colours change "it kind of bounces around".
- **Tools:** "what is that tool? I don't know." The other apps "don't have the app icons", and pressing one is "not clear".
- **Advanced:** "why is it advanced? Why can't it be something else?" The wording is "poorly worded and bizarre".
- **The welcome guide** "could be more centered", and "the text is kind of small".
- **A new chat:** "still some clashing" in the colours. The dial "doesn't tell you what percentage you have left". The project menu has no new project. Find something's length list "sucks". "What should I research?" starts with "no way to stop it from starting". Show open surveys is "not totally clear".
- **A project:** "where is it in the U.S.?" The project's map button "goes back, I guess".
- **Decide:** "is there any way to push it to be like, what is this?" Second opinions is "grayed out, but there's no tooltip for why". The fold-outs are "very abstract and odd". In 3D "I don't even know what I'm looking at". After Agree, "what have I reported and where does that go?"
- **The Data tab** "could be better organized".
- **The map:** "shaded areas have open lidar, but the whole thing is kind of shaded."

## Goals

Each goal is done when its check passes in the running app.

| Goal | What | Check |
|---|---|---|
| P1 | **Claude beside ChatGPT.** Settings shows two accounts of equal weight, each with what it runs. The welcome guide offers Claude as a third choice, and a person with Claude alone can finish it. | Settings seen. The guide walked in an empty home with nobody signed in. |
| P2 | **Space you can see and clear.** What takes the space, part by part, each project's size, and a way to clear what can be fetched again. | Seen with the test copy's 104 projects. |
| P3 | **Keys that say whether they work.** Which other services could take a key, and a key checked with its service on Save. | A made-up token saved in the app. |
| P4 | **A look that changes in place.** | Earth, Canopy and Graphite chosen in turn in one window. |
| P5 | **Tools in plain words.** One request followed through. The other apps wear their own icons, and a press says what it did. | Seen, and one card pressed. |
| P6 | **"How it runs"** in place of Advanced, in sentences. | Seen. |
| P7 | **The welcome guide, centred and larger.** | Each of its three pages seen at 1440 × 900. |
| P8 | **A new chat that waits for you.** Calmer colours, a dial that says its number, a project menu with a new project, a sheet before a start runs, and Stop always in reach. | The sheets opened, the menu opened. |
| P9 | **Where, more closely.** The state, the whole country in the small map, the nearest town on request. | A project in the United States seen. |
| P10 | **Decide answers back.** A way to ask about a find, words in place of a greyed button, named notes in place of fold-outs, a 3D view that says what it shows, and what a decision does. | Seen on a find in Perry Mesa 2. |
| P11 | **The Data tab, in the order a search uses it.** | Seen. |
| P12 | **A map where covered ground stands apart.** | The world view seen. Stalls measured while it moved. |
| P13 | **Docs and checks.** | The spacing and link checks pass, and the app's tests. |

## Log

- **P1, accounts.** Settings, Account and models opens with **Your accounts**: a ChatGPT card and a Claude card of the same shape, each with a seal when it is ready and one sentence on what it runs. The Claude card (`ClaudeAccount`) has a line each for second opinions (**Use Claude** sets Claude Sonnet through Claude Code), for searching from Claude Code (**Add to Claude Code**), and, where the OpenCodex router lists Claude models, for the search in Dighouse. A sentence under the cards says what the search inside Dighouse needs. Your name has its own row.
  - **The welcome guide** offers **A Claude account** under the two OpenAI choices. **Use Claude Code** gives Claude Code the tools and the guide, the step ticks as "Claude, through Claude Code", and Continue lights up (`AppState.searchesFromClaude`). The last page then says how to ask Claude Code for a first search, and Home carries a line that the chat there needs ChatGPT or a key.
  - **Seen:** Settings at 1440 × 900 with both cards. In an empty home with nobody signed in: the three choices, Use Claude Code pressed, the tick, the last page, and Home with its line. The tools went into the empty home's Claude Code settings, and the real ones were unchanged (their checksum was the same before and after).
  - **Not checked:** a search run from Claude Code, a search in the app on a Claude model through the router, and Use Claude in Settings (it sets the same value the model list sets).
- **P2, space used.** Data and keys has **Space used** (`StorageSettings`): one bar in colours, then a line each for the projects, the raw points no project holds, lidar files as downloaded, national ground models, quick looks, and the catalogs. Each says what it is and what it takes. **List them** unfolds the projects, largest first, eight and then all, each with **Show** and **Trash…**. Each kind of download has **Clear**, which asks first and is off while a search runs. `DiskUse` measures each project and each of the cache's folders.
  - **Seen** with 104 projects: 56.52 GB in all, the list of the eight largest. **Not pressed:** Clear's Remove and Trash's Move to Trash, since both would remove Chris's own data. Clear for the three folders is new code that has not run.
- **P3, keys.** The tools read two keys, Denmark's token and OpenAlex's key, and no others. Three services were looked at for a third:

  | Service | What a key would open | Access | Worth adding |
  |---|---|---|---|
  | Finland, the National Land Survey | The 2 m elevation model, over a service like Denmark's | A free key from a personal account | Yes |
  | Sweden, Lantmäteriet | The 1 m ground model as files | An account and an order for the product, with no fee | Yes, with more setup |
  | OpenTopography | Its service for USGS 1 m ground | A free key, with 1 m ground for academic users only | No: Dighouse reads that ground from USGS |

  Finland and Sweden each need an account in Chris's name before either can be tried, so neither was added. Spain beyond Navarre and the Basque Country was not looked at.
  - **Adding a key:** Add shows the two steps side by side, **1. Get a token** and the box to paste into. Save asks the key's own service whether it takes it (`Keys.accepted`). A refusal keeps the box open and says so. No answer saves the key and says it could not be checked.
  - **Seen:** a made-up token saved for Denmark: "Dataforsyningen did not accept this token", and nothing was kept. **Not checked:** a real token or key (there is none here), so "accepted" was never seen. OpenAlex's refusal of a made-up key was seen from the command line only.
- **P4, looks.** The colours are observed, as the text size is (`LookNow`), so a view that reads a colour is drawn again in place. The window is no longer rebuilt, so nothing arrives again and nothing scrolls back. **Seen:** Earth to Canopy to Graphite in one window, the sidebar and the page recoloured where they stood, and the new chat in Graphite. **Not seen:** every page in Canopy and Graphite, and a project's map or Decide open during a change.
- **P5, tools.** The page opens with one request followed through: what was asked, the two tools the agent used, and what came back. Then one sentence on what a tool is. **Other apps the agent can use** shows each app's own icon, read from its plugin folder on this Mac (`PluginIcons`), what the app is for, and a request with **Try in a chat**. The press opens a new chat with the request in the box and a line over it: "A request to try with Gmail. Change it if you like, then press Return to send it." The text is cleared on leaving for another chat. **Seen:** nine apps with their icons. **Pressed:** Gmail's request.
- **P6, How it runs.** Advanced is **How it runs** (`SettingsSection.runs`). Its four lines are sentences: "You type what you want, in your own words." "The model reads it and chooses the next step." "The engine is Codex, a program on this Mac. It carries the step out." "The tools do the work: fetch lidar, check a find, keep the record." **Seen.**
- **P7, the welcome guide.** Each page sits in the middle of the window, in a column 720 wide, with larger words throughout. **Seen** in an empty home at 1440 × 900: Welcome, Set up and the last page. **Not seen:** 1280 × 800.
- **P8, a new chat.**
  - **Colour:** the four smaller cards keep the page's own surface, with their colour in the icon and under the pointer. Two colours joined `Theme`, clay and sky, and violet left the cards.
  - **The dial** says "5% of your plan's usage is left" in a label over it under the pointer. **Not seen:** the label, since the pointer could not be moved over it.
  - **The project menu** leads with No project and **A new project…**, leaves out blind tests, is wider, and a long name takes a second line.
  - **A start is shown first** (`StartSheet`, `AppState.preview`): what the agent will do, a step each, then Cancel and Start. Find something's length is six buttons in a row. Size up a place asks for the place there, so the agent does not spend a turn asking. The cards on a new chat, in the Toolbox and on Home open it.
  - **Stop** shows whenever a run is going, beside Send when the box has words.
  - **Show open surveys** says "The agent lists the lidar surveys archaeologists flew and shared, and what a search in each could add."
  - **Seen:** the cards in Earth and Graphite, the menu, and the sheets for Find something and Size up a place. **Not pressed:** Start, on either sheet, and Stop during a run, since each uses the plan.
- **P9, where.** A project's Where panel names the state, read from the survey's own name ("usgs:AZ_…" is Arizona), and its small map shows the whole country with the ring in it (`Reach.frame`). **Name the nearest town** asks Apple Maps and keeps the answer in the project's private folder. The project's map button shows only while the map is out of sight. **Seen** on Perry Mesa 2: "Arizona, United States". **Not pressed:** Name the nearest town, since it sends the place to Apple, and Open in Maps. **Not seen:** ground with no state in its name, which shows the country alone.
- **P10, Decide.**
  - **Not sure what it is?** sits under the verdict: **Ask the agent about it** closes Decide and puts a question about the find in a new chat, unsent. **Ask a second model** shows where a find has no second opinion. **Turn it in 3D** moved here.
  - **Second opinions** in the header is a button only when there is something to ask. Otherwise it reads "Every find has a second opinion", or the reason in amber.
  - **The notes** are a panel in view, each with its name and whose words they are: The agent's notes, The second opinion, What was read.
  - **The 3D view** opens with what it is, and its legend is four lines: its width, the white post, the ruler, and how to turn it.
  - **A decision** says what it does under the buttons, and after Record: "C-149 is recorded as worth reporting, signed Chris Sotraidis. Nothing was sent. Draft a report under Data when you are ready." Done has **Where these went**, with **Go to the drafts**.
  - **A bug found on the way:** with words that wrap, the 3D sheet sized itself many screens tall and showed no ground. It has a set width and height now.
  - **Seen:** the card with its new row, the header's words, the line under the buttons, the notes panel on C-007 with all three notes, and the 3D view with its ground and legend. **Not pressed:** Agree and Record, since a decision changes Chris's project, so the line after a decision and Where these went were not seen. Ask the agent about it was not pressed either: it uses the same draft as a Tools card, which was.
- **P11, the Data tab** is four groups in the order a search uses them: **The ground** (one panel, with its total), **Get more ground** (what each button asks the agent, and a file of your own), **Report what you decided** (the report and the letter), and **Take it elsewhere** (the two exports). A file that holds locations says so with a lock. **Seen** wide and narrow.
- **P12, the map.** Open lidar is one gold on the New project map, in the United States and the national models alike, and the hint says "The gold areas have open lidar." The survey dots are clay with a white edge. **Seen** at world zoom. **Measured:** with the app's own watcher on (`-measure YES`), four drags, a zoom to the world and a scroll logged no stall of 250 ms or more. How smoothly the map draws between those was not measured.
- **P13, checks.** 67 offline tests and the app's 13 pass. No search prompt, the skill or the feature guide changed, so the blind tests were not rerun. Size up a place now sends the place in a plain question from its sheet, and the workflow's own prompt is unchanged.
