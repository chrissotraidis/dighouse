<p align="center">
  <img src="docs/images/icon.png" alt="Dighouse app icon: a mound drawn in lidar dots of soil brown, tan and green" width="128" height="128">
</p>

<h1 align="center">Dighouse</h1>

<p align="center">
  <strong>Search public lidar for possible built features, check each one, and record what is already published.</strong><br>
  You decide what they are.
</p>

<p align="center">
  <a href="https://github.com/chrissotraidis/dighouse/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/chrissotraidis/dighouse?label=release&color=8B5E3C"></a>
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-0A84FF?logo=apple">
  <img alt="Apple silicon" src="https://img.shields.io/badge/Apple%20silicon-arm64-0A84FF?logo=apple">
  <img alt="Native SwiftUI" src="https://img.shields.io/badge/SwiftUI-native-FF9F0A?logo=swift&logoColor=white">
  <img alt="64 tools over the Model Context Protocol" src="https://img.shields.io/badge/MCP-64%20tools-8B5E3C">
  <img alt="Free to use" src="https://img.shields.io/badge/price-free-30D158">
  <img alt="Site locations stay on your Mac" src="https://img.shields.io/badge/site%20locations-stay%20on%20your%20Mac-30D158">
  <img alt="No analytics" src="https://img.shields.io/badge/analytics-none-30D158">
  <a href="LICENSE"><img alt="Apache 2.0 licence" src="https://img.shields.io/badge/licence-Apache%202.0-8E8E93"></a>
  <a href="https://discord.gg/xwHfUD2bxW"><img alt="Join the Discord" src="https://img.shields.io/badge/Discord-join-5865F2?logo=discord&logoColor=white"></a>
</p>

<p align="center">
  <a href="#download-and-set-up"><b>Download</b></a> ·
  <a href="#questions-people-ask">Questions</a> ·
  <a href="#get-help-and-share-ideas">Help and Discord</a> ·
  <a href="#benchmarks">Benchmarks</a> ·
  <a href="#how-a-search-works">How a search works</a> ·
  <a href="#open-data">Open data</a> ·
  <a href="#responsible-use">Responsible use</a> ·
  <a href="docs/ROADMAP.md">Roadmap</a>
</p>

![Angel Mounds, Indiana, opened in Dighouse: the project page says what happens next and lists the search so far; five finds are marked on the bare-ground map](docs/images/angel-mounds-run.png)

<sub>A search at Angel Mounds, Indiana, from open USGS lidar: 9 tiles looked at, 5 finds marked, each one sliced, given a second model's opinion and searched in the literature.</sub>

Lidar is a laser scan from an aircraft that maps the ground through gaps in the trees, and a great deal of it is public. Most of it has never been searched for archaeology. Dighouse gives an AI model the tools to fetch that data, take the trees away, look over every square of ground, and check each thing it marks, then hands the decision to a person.

A **find** in Dighouse is a shape that might be built and is not yet confirmed. Most finds on open lidar turn out to be published already, and a record that says so is a result too.

> [!NOTE]
> **This is an early release.** Dighouse finds large earthworks reliably and misses many small, low mounds, and so far no find from a search has gone past "worth a closer look". The quickest way to see what it does is to run it on a known site, where you can check its work against what is published.

## Download and set up

You don't need a GitHub account, Terminal or any coding to use Dighouse.

**What you need**

- A Mac with Apple silicon (M1 or later) and macOS 14 Sonoma or later. Intel Macs are not supported yet.
- A ChatGPT account on a plan that includes Codex. Dighouse runs its AI through your account, so a search counts toward your plan's usage. The chat box shows how much you have left.
- An internet connection. A search downloads a few megabytes of ground for each square kilometre.

**Install it**

1. Open the [latest release](https://github.com/chrissotraidis/dighouse/releases/latest). Under **Assets**, click the file whose name starts with `Dighouse-` and ends in `.dmg`.
2. Open the downloaded file and drag **Dighouse** into **Applications**.
3. Open Dighouse from Applications. If macOS says it cannot check the app, open **System Settings**, then **Privacy & Security**, scroll down and click **Open Anyway**. You only do this once.

**The first launch** shows a short checklist and fixes what it can:

1. **Install it** downloads OpenAI's Codex engine, which runs the agent, into Dighouse's own folder.
2. **Sign in with ChatGPT** opens your browser. You sign in there, and Dighouse never sees your password.
3. Dighouse prepares its archaeology tools, which takes about a minute the first time.
4. You pick the AI model that runs the search. It must be able to read images.

**Good first steps**

- **Your first project.** On a fresh install, Home offers **Start your first project**: six steps at Serpent Mound, Ohio, about ten minutes, from getting the ground to deciding what a find is.
- **A known site.** Under **Places to start** on Home, one press sets up Cahokia, the Newark Great Circle, a ring fort in Saxony or a wreck in Lake Huron.
- **Test it blind.** The agent searches a famous site without being told which, then gets a score against what is published.
- **What is this?** Type a place and see its ground in two views and what is on record nearby, in about a minute.
- **Find something.** Choose how long; an hour is a good start. The agent picks a region with open lidar and little on record, searches it on its own, and brings back what needs your decision.

[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) covers the first hour in more detail: deciding, what to do if something looks real, what stays on your Mac, and what to do when something goes wrong.

## What it cannot do

- **It does not confirm sites.** A find is a reason to look, not a discovery. Confirming one takes an archaeologist, and often fieldwork. So far no find from a search has gone past "worth a closer look".
- **It misses things.** In the blind tests below it found large earthworks reliably and missed most small, low mounds: 29 of 53 at Borre, and 4 of the 11 low megalithic mounds in Navarre's 2 m model.
- **Under water it is a pilot.** It reads NOAA's sonar surveys of US waters only. A wreck lying flat, buried in sediment, among rocks, or in a gap between survey lines will not show.
- **It cannot read everything published.** Many papers are behind paywalls, and official site registers in most countries are not public, so "no match in the sources read" often means little was readable. Dighouse reads the open registers (Denmark's, Norway's, England's scheduled monuments and Navarre's), and every find's record names the registers and lists it was checked against, and when. A project says at the top whether its area can be checked against a register at all.
- **It sees shapes in the ground, not artefacts.** Lidar cannot show buried deposits, pottery scatters, or a feature's date or culture.
- **It needs an Apple silicon Mac and a ChatGPT plan with Codex.** There is no Windows, Linux or iPad version. The tools also run on their own in any harness that speaks the Model Context Protocol.

## Responsible use

- **Do not visit or dig.** A find is a desk result. Digging or metal-detecting on a site destroys what it holds, and in many places it is illegal without a permit.
- **Report, do not post.** Send a find to the heritage authority (in the United States, the state historic preservation office; in England, the local Historic Environment Record), not to social media. Published locations invite looting.
- **Think of the people connected to a place.** Many sites, including the mound sites in the blind tests, matter to descendant communities. Consult them before anything is made public.
- **Leave wrecks alone.** Many wrecks are war graves or protected by law, and many hold the remains of those who sailed them. Report a wreck find to NOAA's Office of National Marine Sanctuaries or the state's underwater archaeology program, never online.
- **Keep locations private.** Dighouse keeps coordinates under `private/`. Export for mapping software writes a GeoJSON file there too; that file holds locations, so treat it as you would the site itself.

## Questions people ask

**Is it free?**
Yes. Dighouse is free and open source under the Apache 2.0 licence. The AI runs on your own ChatGPT account, so it uses your plan's Codex usage. The public data it reads is free, and only Denmark's ground model needs a token, which is also free.

**How much of my ChatGPT usage does a search take?**
It depends on the model and how long the search runs. On the maintainer's plan, an hour of **Find something** in Norway used about 2% of the account's usage limit. Your plan's limits may differ. The chat box shows how much you have left, and you can stop a search at any time.

**Do I need to know GitHub, Terminal or how to code?**
No. Download the app from the release page and open it. A GitHub account is only needed to open an issue or to build Dighouse yourself. Questions are welcome on [Discord](#get-help-and-share-ideas).

**Will it run on Windows, Linux, an Intel Mac or an iPad?**
Not yet. The app is for Macs with Apple silicon. The archaeology tools are plain Python and also run without the app, in Codex ([for developers](#for-developers)); other systems have not been tested.

**Which AI does it use?**
OpenAI's Codex engine, signed in with your ChatGPT account. Any model your account offers that can read images can run a search; the benchmarks below used primary / 6.1 Terra, a low-cost one. With the [OpenCodex](https://github.com/lidge-jun/opencodex) router you can add models from other makers, so the second opinion on each find comes from a different company.

**Has it discovered any new sites?**
Not yet. So far no find from a search has gone past "worth a closer look". Dighouse never calls anything new. A find that matches nothing it read is recorded as "no match in the sources read", and confirming a site takes an archaeologist, often with fieldwork.

**How good is it?**
On thirteen known sites, searched blind, it found 67 of 105 published features. It finds large earthworks reliably and misses many small, low mounds. Every site, score and miss is under [Benchmarks](#benchmarks).

**Where does my data go?**
Each project is a folder on your Mac. Site locations stay in the project's `private/` folder, which never goes into its history or anything it shares. The AI models see pictures of the ground and the project's records, through your ChatGPT account. The public data services see the area you download, as any map website would. The app has no analytics or tracking.

**Could this help looters?**
Public lidar is already open to anyone. Dighouse is built to keep what it finds private: locations never leave `private/`, shared files are checked for coordinates before anything is published, and exports leave out pictures of finds that are not on a published record. See [Responsible use](#responsible-use).

**I think I found something. What now?**
Don't post the location anywhere, and don't visit or dig. Mark the find **Worth reporting** in Decide. The project's Data tab drafts a letter asking the records office whether it is already recorded, and a report for the heritage authority Dighouse names for that country. You read both and send them yourself.

**Where can it search?**
The United States, Canada, much of Europe, New Zealand and Shizuoka in Japan, plus the seafloor of US and Irish waters. The map on Home shades where open data reaches, and [Open data](#open-data) lists every source. Anywhere else, you can give the agent your own data.

**Can I use my own lidar?**
Yes. Give the agent a ground model (GeoTIFF) or a point cloud (LAS or LAZ) with a coordinate system in metres, such as UTM or a national grid, and it searches that like ground it fetched.

**Can archaeologists, students or teachers use it?**
Yes. A project is a folder of plain Markdown records with pictures, so it can be read without the app and handed to someone else. **File › Export Project** makes a zip without the locations, and **Carry on** picks up the work on another Mac.

**Was Dighouse built with AI?**
Yes. Dighouse was built with substantial AI assistance for code, tests, documentation and debugging. There is no audited share of AI-written code; the run logs in `docs/` state what was checked and how.

**Why is it called Dighouse?**
A dig house is the building where an excavation team lives, works and keeps its records. The app plays the same role for a search.

## Get help and share ideas

- **Discord.** Join [Kahris on Discord](https://discord.gg/xwHfUD2bxW), the maintainer's server for his open projects. When you join, pick **Dighouse (lidar archaeology)**, or add it later under **Channels & Roles**. That opens **dighouse-help** for setup and problems, **dighouse-chat** for what you tried and ideas, and **dighouse-news** for releases.
- **GitHub issues** for bugs and new data sources: [open an issue](https://github.com/chrissotraidis/dighouse/issues/new/choose). This needs a free GitHub account.
- **A security problem or a site location that leaked:** report it privately, as [SECURITY.md](SECURITY.md) explains, never in public.

Never post where a site or a find is, on Discord, in an issue or anywhere else. Describe places by region. The Discord is set to block messages that hold coordinates.

## Benchmarks

Each test is **blind**: the agent is not told the site, looks at the ground tile by tile, marks what it finds, and is scored against an answer key of published features before it may read any literature. Try one yourself from Home with **Test it blind**.

| Site | Data | Found of known | Missed | Not in the key |
|---|---|---|---|---|
| Mound City Group, Ohio * | USGS 3DEP | 19 of 19 | 0 | 17 (real mounds the key leaves out, and measured rises) |
| Angel Mounds, Indiana | USGS 3DEP | 4 of 4 | 0 | 3 |
| Cahokia, Monks Mound, Illinois * | USGS 3DEP | 1 of 1 | 0 | 12 |
| Serpent Mound, Ohio | USGS 3DEP | 1 of 3 (the effigy) | 2 burial mounds | 2 |
| Maiden Castle, England * | Environment Agency 1 m | 3 of 3 | 0 | 35 |
| Borre, Norway * | Kartverket 1 m | 29 of 53 | 24 small burial mounds | 11 |
| Oberhaching square enclosures, Bavaria | Bavarian DGM1 1 m | 2 of 3 | 1 enclosure | 3 |
| Lauske ring forts, Saxony | Saxon DGM1 1 m | 3 of 3 | 0 | 5 |
| Irulegi hill, Navarre | Navarre 2 m | 1 of 2 (the castle) | the Iron Age village | 0 |
| Sierra de Andía megaliths, Navarre * | Navarre 2 m | 5 of 11 | 6 low mounds and dolmens | 133 |
| Puketapu Pa, Auckland | LINZ 1 m | 1 of 1 | 0 | 8 |
| Munoaundi hillfort, Basque Country | Basque 1 m | 0 of 1 | the rampart (marked 141 m off its mapped line) | 1 |
| Arrola hillfort, Basque Country | Basque 1 m | 0 of 1 | the rampart (banks marked 97 m outside the mapped outline) | 1 |
| **All thirteen on land** | | **67 of 105** | 38 | 202 |
| Thunder Bay wrecks, Lake Huron (three areas) | NOAA sonar, 1 m | 4 of 7 charted wrecks | 3 | 5 |

<table>
  <tr>
    <td width="50%"><img src="docs/images/scorecard.png" alt="The scorecard of a blind test at Angel Mounds: 4 of 4 found, 0 missed, 2 not in the key, and the map with each published mound circled and the agent's find on it"><br><sub><b>A blind test's scorecard.</b> The agent was not told it was Angel Mounds. Each published mound is circled; each green dot is a find.</sub></td>
    <td width="50%"><img src="docs/images/what-is-this.png" alt="What is this? at Newark Earthworks, Ohio: the ground in sky view and hillshade side by side, what is on record within 1 km, and the agent's short description"><br><sub><b>What is this?</b> Type a place and get the ground in two views and what is on record nearby, in about a minute, without making a project.</sub></td>
  </tr>
</table>

<p align="center"><img src="docs/images/test-sites.png" width="640" alt="Test it on a known site: ten known sites to try blind, from Mound City in Ohio to Puketapu Pā in Auckland, and a wreck on the bed of Lake Huron under water"><br><sub><b>Ten sites to test it on.</b> Mounds, hillforts, ring forts and a pā on land, and a wreck on the lake bed from NOAA's sonar surveys. Press one and the agent searches it blind.</sub></p>

\* Rerun on 2026-11-23, when every tile is first looked at in bulk by a low-cost model and the agent looks closely at the tiles worth it (FIND_LOOP G1): no site found less than on 2026-11-22, Andía found one more, and the finds outside the key rose a little at four sites. Before that, rerun on 2026-11-22, when a whole search also opens the measured rises that stand out most from the ground around them, on every tile looked at (at most 40 per km²): recall rose at Borre (21 to 29 of 53 over two loops), Maiden Castle (1 to 3) and Andía (0 to 4), and so did the finds a person rules out; Mound City and Andía went a little over 50 per km² of them. Andía's extras leave out 72 marked by a mound-only pass that was tried in the same run and not kept. The rest were run on 2026-11-16 with primary / 6.1 Terra, a low-cost model, at medium effort, about 3 to 10 minutes a site. Every land site was run with the same method (the two Basque hillforts a day later): a look at the whole area first, then every tile, then a slice and a map check for each find. The answer keys come from official registers (Norway, Navarre, the Bavarian monument office, Auckland Council), from NOAA's charts for the wrecks, and from OpenStreetMap features with the publications that describe them (the rest). Most keys are partial, so a find "not in the key" can be a real feature. Every site, run, miss and fix is in [TEST_LOOP.md](docs/TEST_LOOP.md#log) and [WORLD_LOOP.md](docs/WORLD_LOOP.md#log). Results will differ with other models.

The underwater row is a pilot: one source (NOAA's sonar surveys of US waters and the Great Lakes), three small areas of Thunder Bay National Marine Sanctuary, and one scored run each. The three charted wrecks it missed stand barely above a rocky lake bed, or lie at the edge of the survey.

Small mounds are the weak spot: a mound 5 m across is a few pixels in a tile picture. `find_mounds` measures round rises in the ground model instead, and the clearest ones (at least 0.6 m high and nearly round) go on a list for a person to look over, apart from the agent's finds. On the six original sites that list puts 50 of 83 known features in front of a person instead of 45, for 28 more spots to rule out. It does not travel well: on rough ground it floods the list, with 565 spots on the Navarre upland (where it reaches 6 of the 11 megaliths) and 54 at the Saxon forts.

A whole search now also opens the measured rises that stand out most from the ground around them, on every tile looked at, as finds marked "measured, not seen", at most 40 per km² (`add_measured_rises`). On rough ground the old ranking, by height and roundness, picked rocks; the new one looks at the rise against the roughness around it and at two window sizes. Scored on saved blind runs, that took Borre from 21 to 25 of 53 mounds and Maiden Castle from 1 to 3 of 3, with fewer than 50 extra finds per km² everywhere.

Measured rises are kept as a layer on the map rather than put to a person one by one. A rise joins the finds you decide when the second model calls it built and its shape ranks in the top half of the project's rises, or when you raise it from its record. Every rise still counts in the blind tests. On the two-hour search's five projects this leaves 36 of 232 finds for a person, against 232 before.

The second opinion takes about a second a find: the app sends the model the ground 120 m around each find, a few at a time, as soon as each area is done. It is a filter, not a confirmation. Rated blind on 102 crops of known ground, Claude Sonnet 5.5 called 19 of 24 published features built, and when it said "not built" it was right 91% of the time; when it said "built" it was right only 40% of the time. Each record says so: a second opinion that disagrees counts, one that agrees is a weak check.

## Why it exists

In November 2026 Pietro Miotti let AI agents search about 1,200 km² of NASA lidar overnight, and they marked a Maya site. It turned out to be already published. Finding things was cheap; checking them was the part that failed.

Dighouse is built around the check. Every find gets a slice through the raw laser points, a second opinion from a different model, a look at open maps for roads and buildings, and a search of what is published. Hollows, cuts and straight edges are also looked up on old maps: USGS sheets and mine records in the United States, the État-major map and 1950s aerial photographs in France. The tools refuse a status the evidence does not support, and nothing is ever called new.

A chat app can talk about archaeology. It cannot download a survey, look at every tile of an area, cut a slice through the points, or keep a record that someone else can pick up. Dighouse gives the same kind of model those abilities, with rules that hold whichever model is running.

We checked. Given the Mound City blind test box with no tools, the same model that found 19 of 19 mounds there through Dighouse answered that it could not reliably identify, count or place any features from the coordinates alone. That is the right answer for a chat app, and the reason the tools exist.

## How a search works

<p align="center">
  <img src="docs/images/treetops-to-ground.gif" alt="Serpent Mound, Ohio: a handle sweeps across the picture, taking the trees away to show the winding mound on the bare ground beneath" width="720">
</p>

<p align="center"><sub>Serpent Mound, Ohio, from open USGS lidar. Dighouse keeps only the laser returns that reached the ground.</sub></p>

<p align="center">
  <img src="docs/images/lake-to-wreck.gif" alt="Thunder Bay, Lake Huron: a handle sweeps across the lake surface, taking the water away to show two shipwrecks on the lake bed beside a harbour breakwater" width="720">
</p>

<p align="center"><sub>Thunder Bay, Lake Huron. The shore and breakwater come from airborne lidar, which stops at the water; the lake bed and its two wrecks come from NOAA's sonar surveys.</sub></p>

1. **Choose where to look.** Ask "What should I research?" and the agent weighs open lidar, how little is on record, and where earthworks survive, then proposes three searches. Or press **Pick a place on the map** on Home, where the places with open data are shaded, and click where you want to look. Or type a place and press **What is this?** for a one-minute look.
2. **Calibrate.** Before searching where nothing is on record, the agent runs a blind test on the nearest known site with the same kind of lidar. If it finds less than half of what is published there, the search stops. One test varies by a few features, so the mark is judged over the last ten tests of that site on that lidar on your Mac, and the record gives both figures.
3. **Take the trees away.** The tools download the raw laser points, or a national ground model, and keep the ground.
4. **Look at every tile.** The ground is cut into squares called tiles. A low-cost vision model looks at every one in bulk, a few at a time, and opens a find for each shape it points at; the agent then looks closely, in two renderings, at the tiles worth it, marks every feature it sees and takes over the bulk finds it agrees with. A feature guide tells both what mounds, banks and terraces look like, and what to rule out (sinkholes, tree throws, craters, tracks). A tile with too little ground data is marked unreadable, never "nothing found". Without the OpenCodex router the agent looks at every tile itself, which is slower.
5. **Check every find.** A slice straight down through the laser points shows whether a shape is in the ground or only in the treetops. A second, different model gives its own opinion without seeing the first. Open maps are checked for roads, buildings and sites already mapped.
6. **Search what is published.** The agent searches books, papers and site records, opens what it can, and logs every source as read, could not open, or not relevant.
7. **Keep the record, and you decide.** Every find is a Markdown page with its pictures, measurements, checks and sources. You decide what it is, and your name and reason go into the record.

Take the stages one at a time, or press **Find and report back** and the agent carries the search to its end, then returns a report of at most 400 words with your decisions listed first.

## A look at the app

<table>
  <tr>
    <td width="50%"><img src="docs/images/home.png" alt="Home: the headline beside a slider that takes the trees off Serpent Mound, Find something, the message box, four ways in (Pick a place, Suggest a place, Test it blind, Open a project) and the start of Places to start"><br><sub><b>Home.</b> <b>Find something</b> sets the agent searching on its own, and known sites to try are one press away.</sub></td>
    <td width="50%"><img src="docs/images/decide.png" alt="Decide at Angel Mounds: one find with a close view 60 m across, the whole tile and a slice through the laser points, its measurements, and keys for Natural, Modern, Published and Worth reporting"><br><sub><b>Decide.</b> One find at a time: a close view, the whole tile and a slice through the laser points. A key records your decision and your reason.</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/images/record.png" alt="A find's record at Angel Mounds beside the project page: its relief, its slice, what the agent suggests, the evidence and each check, with Location kept on this Mac at the top"><br><sub><b>A record.</b> Each find with its relief, its slice and every check. Its location stays on your Mac.</sub></td>
    <td width="50%"><img src="docs/images/new-project.png" alt="New project on a world map shaded where open lidar reaches: the United States, Canada, Europe, and dots for surveys flown for archaeology, with a legend"><br><sub><b>New project.</b> The shaded areas have open lidar. Click to zoom in, click again to place the area, and see which surveys cover it.</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/images/toolbox.png" alt="The Toolbox on the Check stage of a real search at Cahokia: a line dragged across Monks Mound and the slice it cuts drawn beside it"><br><sub><b>Toolbox.</b> One real search at Cahokia in six stages, each a picture to press or drag. Here a line across Monks Mound draws its slice.</sub></td>
    <td width="50%"><img src="docs/images/open-data.png" alt="The Open data tab: a map of the world showing where open lidar reaches, and a tile for each service with its status"><br><sub><b>Open data.</b> Where each kind of data reaches, from the United States to New Zealand, and a page for every service the tools read.</sub></td>
  </tr>
</table>

**Find something** from Home: choose how long, and Dighouse makes a project for the session. The agent picks a region with open lidar where little is on record, preferring one where a site register is open so finds can be checked, names the project after it, and searches it area by area, adding each area to the project: every tile in bulk first, then a close look where something showed. It checks every find, and a second model gives its opinion on each area as soon as the area is done. What needs your decision waits on Home under **Waiting for you**, across every project. **Ask the records office** drafts a letter, kept under `private/`, asking whether your strongest finds are already recorded where the official record is not open; **Draft a report** writes to the body `who_to_tell` names. You send both yourself.

**A project is the home for its work.** It holds its areas of ground, its finds and decisions, and its chats: the run that searched it, a chat that checks one lead, a chat that writes the report. The project page lists its chats and what each is doing. Anything typed there starts a new chat in the project, and every chat starts from the research record. **New chat** in the sidebar starts a chat in no project, wherever you are; until its first message, the Project menu beside Workflows says where the chat will go and moves it. In the sidebar, projects come first, each with its chats folded under it, then chats that belong to no project, then the blind tests in a group of their own. The map shows one area at a time, by name.

**Decide** is where a person makes the calls. **Needs you** shows the leads, then the finds where the agent and the second model disagree, one at a time and in order of rank: a close view 60 m across in nine styles on the keys 1 to 9 (among them VAT, multi-scale relief and local dominance from the Relief Visualization Toolbox), the whole tile, the slice (west to east or north to south, press D, with a 1.70 m figure for scale), one line of numbers (what marked it, height, size, ground points per m² and other finds within 200 m), and the checks sorted into **For** and **Against**. The rank, A, B or C, says how many of three checks call it built: the shape, the agent's eye and the second opinion. It is a count of reasons, not a probability, and it never changes what needs you. In the United States, where two dated USGS flights cover a find, **Compare two flights** shows both and the change between them, and says whether the find was there in both, appeared between them (possibly modern) or went. **Old maps beside the ground** lays the oldest USGS sheets (in France, the État-major map and the 1950s photographs) over the bare ground, 240 m of each, with a divider to slide between them. On the Map, **Mark a spot** lets you click anything you see yourself and say what it is: it becomes a find in your name, gets its slice and the open-map check at once, and the agent adds a second opinion, the records and a suggested decision. **See it in 3D** turns the ground 120 m around a find in 3D, with heights ×1, ×2 or ×4, the light moved round, and a person 1.70 m tall at the find. Return agrees with the suggestion; a letter picks another decision and asks for your reason. **Agree in bulk** shows the routine finds as a grid of close views; untick any that look wrong and agree with the rest in one press. **Done** lists what you decided, with Undo. Your name and a reason go on every record.

**Also in the app:** a ten-minute first project at Serpent Mound, a chat with `/` commands, `@` mentions and ⌘K, any model through the [OpenCodex](https://github.com/lidge-jun/opencodex) router (so a different maker's model can give the second opinion), three colour looks and five text sizes.

## For developers

Dighouse is a SwiftUI app (`app/`) and a set of archaeology tools in Python (`src/dighouse`) that speak the Model Context Protocol.

**Build it yourself.** You also need Xcode (free from the App Store). In Terminal:

~~~sh
git clone https://github.com/chrissotraidis/dighouse.git
cd dighouse
./scripts/setup.sh
~~~

The script checks for Codex, your sign-in and uv, offers to install what is missing, then builds and opens Dighouse. [docs/SETUP.md](docs/SETUP.md) walks through the first launch, where projects and chats are kept, and what to do if something goes wrong. Dighouse keeps its chats to itself, so they do not appear in the Codex app.

**Use the tools without the app.** They are a Model Context Protocol server:

~~~sh
cd dighouse
uv sync
codex mcp add dighouse -- uv run --directory "$PWD" dighouse-tools
~~~

Then start a chat in an empty folder and ask the agent to follow [skills/dighouse/SKILL.md](skills/dighouse/SKILL.md).

**Tests.**

~~~sh
uv run pytest            # offline, on a synthetic survey (60 tests)
uv run python scripts/smoke_test.py   # one tile end to end against the real services, about a minute
uv run pytest -m live    # the same chain against the real data services (10 tests)
uv run python scripts/funnel.py      # where finds stop, across the projects in the app's list (read-only)
uv run python scripts/coverage.py    # every ground source on about 1 km2: does it answer, and how fast
uv run python scripts/speed.py       # how long each stage of a search takes on a few km2
uv run python scripts/tidy.py        # free the space downloaded points take twice (add --apply)
~~~

## The tools

| Stage | Tools |
|---|---|
| Choose where to look | `find_place`, `open_surveys`, `survey_area`, `find_gaps`, `open_resources`, `search_records` |
| Set up | `init_project`, `name_project` |
| Fetch open lidar, or use your own | `find_data`, `fetch_terrain`, `import_terrain` |
| Draw the bare ground | `view_terrain`, `make_tiles`, `render_tiles`, `look_at_tiles`, `sweep`, `next_tiles`, `view_tile` |
| Look at every tile | `record_verdict`, `flag_candidate`, `find_mounds`, `add_measured_rises` |
| Check each find | `check_finds`, `cut_section`, `second_look`, `check_modern`, `check_old_maps`, `record_old_maps`, `add_control` |
| Test the method on a known site | `list_tests`, `start_test`, `score_test`, `calibration_site`, `start_calibration`, `record_calibration` |
| A quick look at one place | `quick_look` |
| Know what to look for | `feature_guide` |
| Search what is published | `search_literature`, `read_source`, `log_source` |
| Records and runs | `add_evidence`, `suggest_decision`, `set_status`, `list_candidates`, `run_status`, `write_summary`, `write_report`, `document_project`, `export_finds` |
| For the app, when a person decides | `decide_many`, `undo_decision`, `raise_rise`, `find_views` |

The ground is drawn as `composite`, `hillshade`, `local_relief` and `sky_view`. Tool names keep the project's older words (candidate, section, second look). `export_finds` writes GeoJSON for QGIS, ArcGIS or Google Earth, under `private/` because it holds coordinates.

## Open data

Everything Dighouse reads is public. Only Denmark's ground model needs a free token.

| Service | What Dighouse reads |
|---|---|
| [OpenTopography](https://portal.opentopography.org/datasets) | The catalog of lidar surveys, including ones flown for archaeology, and their raw points |
| [USGS 3DEP](https://registry.opendata.aws/usgs-lidar/) | Raw lidar points for most of the United States |
| [Environment Agency](https://environment.data.gov.uk/survey) | England's 1 m ground model |
| [AHN](https://www.ahn.nl/) | The Netherlands' 0.5 m ground model |
| [IGN LiDAR HD](https://geoservices.ign.fr/lidarhd) | France's 0.5 m ground model |
| [Digitaal Vlaanderen](https://www.vlaanderen.be/digitaal-vlaanderen) | Flanders' 1 m ground model |
| [Kartverket](https://hoydedata.no) | Norway's 1 m ground model |
| [Estonian Land Board](https://geoportaal.maaamet.ee/eng/Spatial-Data/Elevation-data-p308.html) | Estonia's 1 m ground model |
| [swisstopo](https://www.swisstopo.admin.ch/en/height-model-swissalti3d) | Switzerland's 0.5 m ground model |
| [IDENA](https://idena.navarra.es) | Navarre's 2 m ground model, from the Government of Navarre |
| [geoEuskadi](https://www.geo.euskadi.eus) | The Basque Country's 1 m ground model, from the Basque Government |
| [Bavarian Surveying Administration](https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=dgm1) | Bavaria's 1 m ground model |
| [GeoSN](https://www.geodaten.sachsen.de/downloadbereich-digitale-hoehenmodelle-4851.html) | Saxony's 1 m ground model |
| [ČÚZK](https://geoportal.cuzk.cz) | Czechia's 2 m ground model (DMR 5G) |
| [Geobasis NRW](https://www.bezreg-koeln.nrw.de/geobasis-nrw) | North Rhine-Westphalia's 1 m ground model |
| [Scottish Remote Sensing Portal](https://remotesensingdata.gov.scot) | Scotland's open lidar, 0.5 to 1 m, where flown |
| [DataMapWales](https://datamap.gov.wales/maps/lidar-viewer/) | Wales' 1 m ground model |
| [ARSO](https://gis.arso.gov.si/evode/profile.aspx?id=atlas_voda_Lidar@Arso) | Slovenia's 1 m ground model |
| [Toitū Te Whenua LINZ](https://registry.opendata.aws/nz-elevation/) | New Zealand's 1 m ground model, where it has been flown |
| [Dataforsyningen](https://dataforsyningen.dk/data/930) | Denmark's 0.4 m ground model, an option for anyone who pastes a free Dataforsyningen token in Settings |
| [Natural Resources Canada](https://open.canada.ca/data/en/dataset/0fe65119-e96e-4a57-8bfe-9d9245fba06b) | Canada's 1 m ground model (HRDEM), mostly from lidar, where it has been flown |
| [VIRTUAL SHIZUOKA](https://github.com/aigidjp/opendata_virtualshizuoka) | Shizuoka Prefecture's 0.5 m ground model, Japan |
| [INFOMAR](https://www.infomar.ie) | Sonar surveys of the seabed around Ireland, as an about 4 m depth model |
| [NOAA NCEI](https://www.ncei.noaa.gov/products/nos-hydrographic-survey) | Sonar surveys of the seafloor in US waters and the Great Lakes, as 1 m depth grids |
| [NOAA charts](https://encdirect.noaa.gov) | Charted cables, pipelines and dumping grounds near a find under water |
| [USGS historical topographic maps](https://www.usgs.gov/programs/national-geospatial-program/historical-topographic-maps-preserving-past) | Old map sheets (about 1890 to 1990) under a find in the United States: buildings, ponds, quarries and roads at the time |
| [USGS Mineral Resources Data System](https://mrdata.usgs.gov/mrds/) | Recorded mines and prospects near a find in the United States |
| [IGN Géoplateforme](https://geoservices.ign.fr) | The État-major map (1820 to 1866) and aerial photographs of 1950 to 1965 under a find in France |
| [Fund og Fortidsminder](https://www.kulturarv.dk/fundogfortidsminder/) | Denmark's national register of ancient monuments, for checking a find |
| [IDENA heritage layer](https://idena.navarra.es) | Navarre's register of protected archaeological sites, for checking a find |
| [Norway's heritage register](https://kulturminnesok.no) | Riksantikvaren's Askeladden, through Geonorge and api.ra.no: every recorded monument except those kept back as sensitive, for checking a find and for answer keys |
| [National Heritage List for England](https://historicengland.org.uk/listing/the-list/) | Scheduled monuments as mapped areas, for checking a find and for answer keys; designated monuments only |
| [OpenStreetMap](https://www.openstreetmap.org/) | Mapped sites through [QLever](https://qlever.dev/); roads and buildings near a find through Overpass, or OpenStreetMap's own map service when Overpass is down |
| [Wikidata](https://www.wikidata.org/) | Archaeological sites already on record |
| [Pleiades](https://pleiades.stoa.org/) | About 35,000 located ancient places |
| [National Register of Historic Places](https://www.nps.gov/subjects/nationalregister/) | Historic places in the United States |
| [Open Context](https://opencontext.org/) | Published excavation and survey records |
| [OpenAlex](https://openalex.org/) and [Crossref](https://www.crossref.org/) | The literature search. Without a key, OpenAlex allows about 100 searches a day for each network address, and Crossref takes over past that |

Historic aerial photographs, declassified CORONA imagery, and the lidar of Finland and Sweden need an account or a key (Sweden's 1 m model has been free since February 2025, with a free account), so the tools do not read them yet. Spain beyond Navarre and the Basque Country, Poland and Luxembourg were tried and are not read yet; the Open data tab says why for each.

## Rules the tools enforce

These live in the tools, so they hold whichever model is running.

- A tile with too little ground data is marked unreadable and cannot be given a verdict.
- A find cannot be marked as in the ground without a slice that shows it there.
- The second opinion must come from a different model than the one that marked the find.
- A find cannot be marked as having no match in what is published until a slice, a second opinion, a map check and at least one read source are on its record, and a named person makes that call.
- Nothing is ever called new. A record says how many sources were read and that none matched.
- Locations are stored only under `private/`. Records, notes and run summaries carry no coordinates, because published coordinates invite looting.

## A project is a folder

~~~
my-project/
  RESEARCH.md     the research record: everything looked at, read and decided, and what is left
  PROJECT.md      the question, why this area, the rules, and how the project is kept
  METHODOLOGY.md  how the search and the record are kept, and lessons learned here
  candidates/     one Markdown record per find, with its pictures
  notes/          a dated log, run summaries, how the project started, and record.json (what was looked at, without locations)
  sources/        what was read, what could not be opened, and pages you saved
  reports/        the search report, and drafts for the heritage authority
  data/           downloaded points, ground models, tiles (not versioned)
  private/        locations, exports and run state (not versioned)
~~~

A project can hold several areas of one region, each fetched under a short name (`fetch_terrain` with `area`); the record and the report name them, and the project's box grows to cover them all.

Markdown is the record of truth, so a project works offline and can be handed to an archaeologist like any folder. Each project keeps its own git history without `data/` or `private/`. Dighouse rebuilds `RESEARCH.md` whenever a run ends, a person decides or the project is opened, and the agent reads it before it starts, so work adds up instead of starting over. A section of `PROJECT.md`, "How this project is kept", says which file holds what, so an agent in plain Codex can carry a project on without Dighouse.

**Where projects go.** Every new project is a new folder in `~/Dighouse`, with its own repository and a first commit. If you keep your work in `~/GitHub`, choose "Work out of my GitHub folder" on New project, or say so in a chat, and the project goes in `~/GitHub/<name>` instead. Dighouse never picks that on its own, never writes into a repository that is already there (a taken name gets a number), and refuses folders kept in iCloud.

**From a chat to a project.** Talk a place through in a chat. Once the agent has a place and a question, it offers a card, Make this a project (or type `/make-project`). Pressing it opens New project already filled in. The chat moves into the project, and what it settled (the question, why this area, what it read and what it ruled out) becomes the project's first records, committed as "Started from chat".

**History and publishing.** A project's overview lists its latest changes, with Show in Finder and Publish to GitHub (or `/publish`). Publishing first checks that `private/` and `data/` stay out and that no shared file holds a coordinate. Then it asks you, and makes a private repository on your account with GitHub's `gh` tool. Later runs go up with Push changes. Nothing is ever made public or sent on its own.

**Handing a project over.** File › Export Project makes a zip without `data/` or `private/`, so it holds no locations. The other person opens the folder, the record shows every tile and what it showed as earlier work, and one button, Carry on, picks up what is left.

## Status and limits

The [eight-hour research session and replays](docs/2026-11-20-research-session.md) record where the coordinator intervened, why Cahokia's ranking changed, and what still needs a full-session test. Earlier app tests are documented in [TEST_LOOP.md](docs/TEST_LOOP.md), [REFINE_LOOP.md](docs/REFINE_LOOP.md), [POLISH_LOOP.md](docs/POLISH_LOOP.md), [USABILITY_LOOP.md](docs/USABILITY_LOOP.md), [NEXT_LOOP.md](docs/NEXT_LOOP.md) and [GOAL_LOOP.md](docs/GOAL_LOOP.md).

- Releases are signed with a Developer ID. Until a release is notarized by Apple, macOS asks once before opening it.
- A vision model's eye is the weak point of any search; the benchmarks above show where it is weak. The checks exist because a model marks shapes that are not there, and misses some that are.
- Open services go down and rate-limit. The tools say "could not check" rather than guess.

What comes next is in the [roadmap](docs/ROADMAP.md), and the next loop of work, on deciding finds, is planned in [DECIDE_LOOP.md](docs/DECIDE_LOOP.md). The concept is in [concept.md](docs/concept.md), the design rules in [DESIGN.md](docs/DESIGN.md), and the state of the work in [HANDOFF.md](docs/HANDOFF.md).

## Contributing

Issues and pull requests are welcome; [CONTRIBUTING.md](CONTRIBUTING.md) explains how. The tools are plain Python in `src/dighouse` with offline tests; the app is SwiftUI in `app/Sources/Dighouse`. A new national ground model is a good first contribution: copy the closest entry in `national.py`. Please keep the rules above intact, and never put coordinates of a find in an issue. Security problems and leaked locations go through [SECURITY.md](SECURITY.md).

**Only people are credited.** Contributors may use AI tools, but no AI is listed as an author or co-author of a commit or pull request; a check enforces it. The policy for people and agents is in [AGENTS.md](AGENTS.md).

Questions and ideas are welcome in **dighouse-chat** on [Discord](#get-help-and-share-ideas). How Dighouse was built is under [Questions people ask](#questions-people-ask).

## Acknowledgements

Dighouse stands on open data published by the agencies and projects in the table above, on the [Codex](https://github.com/openai/codex) engine, and on [OpenCodex](https://github.com/lidge-jun/opencodex) for model routing. Lidar is read with [laspy](https://laspy.readthedocs.io/) and [rasterio](https://rasterio.readthedocs.io/). The local dominance and multi-scale relief views are copied, with credit, from the [Relief Visualization Toolbox](https://github.com/EarthObservation/RVT_py) (ZRC SAZU and the University of Ljubljana, Apache 2.0), and the VAT view follows Kokalj and Somrak (2019).

## Licence

Apache 2.0, matching the Codex engine.
