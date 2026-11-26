# Dighouse clear loop: what am I looking at, and where

Started 2026-11-26, from Chris's second review of the launch loop's build ([LAUNCH_LOOP.md](LAUNCH_LOOP.md)). Read [HANDOFF.md](../HANDOFF.md) first.

## Why this loop

Chris opened the rebuilt test copy and sent eighteen screenshots. The reorganizing held ("the hierarchy for settings is okay"), and the rest "needs another pass". In his words:

- **Decide:** "what am I looking at? Where is this location? What is this?" The numbers over the close view are buttons, "but it's not even clear those are buttons". The slice "has no interactivity at all". "A count of reasons, not a probability" sits "way over on the side".
- **A project:** under What was found, "where are these locations? I have no idea". The last run says what was done, "but where is the location".
- **Usage:** "5% of usage left" takes a line of its own under the message box. "In ChatGPT there's like a dial". He asked for "a dig dial".
- **Settings:** still "blocky". Signing in through Codex "needs to be clear with assurance". Privacy and the keys look "poorly optimized". Tools: "what are these tools?" Advanced "looks just as bad as it did before", and "Models on offer" is "weird" language.
- **The map:** "slow, sluggish", "not interactive", and "it's not clear to me with the dots what the dots even are", nor where the searched ground comes from.
- **Starting a chat:** "such a lack of color", "all dirt colored".

## Goals

Each goal is done when its check passes in the running test copy.

| Goal | What | Check |
|---|---|---|
| C1 | **Decide says what and where.** A strip under the find's name: the project, the region, the area, the tile among its neighbours, and a small map, all from this Mac. Each picture has a name. The nine views are named buttons. The slice can be pointed at. The note on counting sits with the counts. | Opened on a find with a 3D surface and on one without. |
| C2 | **A project says where it is.** Under its question: a small map, the region, how many areas and square km, and Open in Maps. Each find's card names its area. | Seen on a project in Norway and one in the United States. |
| C3 | **A usage dial.** The line under the message box goes; a small dial sits in the box, and a larger one in Settings. | Seen at 5% (amber); a press opens Settings. |
| C4 | **Settings, less blocky.** Shorter rows. The account card says plainly that you are signed in and how. Privacy is one table. A key's box shows only when adding. Tools says what a tool is. Advanced is a short list of the parts and the models you can use. | Each page seen at 1440 × 900. |
| C5 | **Map dots that answer.** Searched ground gathers into fewer dots when zoomed out; a click on a dot says whose it is and offers to go there or open the project; a survey's dot names the survey. | A dot clicked at world and region zoom. |
| C6 | **Colour on the ways to start.** Each start card has its own colour, at rest and under the pointer. | Seen on the empty chat, the Toolbox and Home. |
| C7 | **Docs and checks.** | The spacing and link checks pass, and the app's tests. |

## Log

- **C1, Decide** (2026-11-26). Under the find's name there is now a strip that says where it is: a small map with a ring, the area's tiles with the find's tile in tan and the find as a dot, the project and the region ("Elverum woodland earthworks · Norway"), the area, "tile 14 of 110" and the survey, then one sentence on what the three pictures are, with **Show on the map** and **Open in Maps**. The small map is drawn by Dighouse from its own outline of the land (`Locator` in `Where.swift`), so showing it asks no map service. The region is the one the open data names (`Reach.place`): a country, or nothing where there is none.
  - **The nine views** are buttons with a number and a name each, the chosen one in tan, after the words "Draw the close view as". The keys 1 to 9 still choose.
  - **Each picture has a name**: Close view, Its whole tile, A slice through it, each with its size.
  - **The slice** is drawn by the app from the grid of heights kept for the 3D view (`SliceChart`): pointing at it shows a line, a dot and "23 m along · 0.9 m up". It covers the same 60 m as the close view, says how far heights are stretched, and keeps a person 1.70 m tall for scale. Where check_finds cut a slice from raw points, a Ground and Points switch shows that picture instead. A find with no grid of heights keeps the picture as before.
  - **The note on counting** sits under the reasons it is about.
  - **Seen** on C-011 in a Norwegian project at 1440 × 900: the strip, the nine buttons, the slice with its mound, and For and Against all fit without scrolling. **Not checked:** a find with raw points (the Ground and Points switch), a find with no grid of heights, pointing at the slice (the pointer was not moved over it), and Show on the map.
- **C2, where a project is.** A project's page has a Where panel under its question: the small map, the region, "2 areas · 9.5 square km" and the areas' names, "Shown on this Mac only", **The project's map** and **Open in Maps** (`WherePanel`, `Whereabouts`: each fetched area's box from the private folder, or the project's one box). In a project of several areas each find's card under What was found names its area. Open in Maps opens Apple Maps at the middle of the ground, and its help text says Apple then sees where you look. **Seen** on the Norwegian project. **Not pressed:** Open in Maps and The project's map. **Not seen:** a project in the United States, and one outside every region (it would say "Its own ground").
- **C3, a usage dial.** The line under the message box is gone. A small dial sits in the box beside the model: a ring that empties, green and then amber under 20%, with the trowel in the middle (`UsageDial`). A press opens Settings on the account. Settings has the larger dial with the number. **Seen** at 5%, amber, in the message box and in Settings. **Not pressed.**
- **C4, Settings again.** Rows are shorter (10 points above and below, from 14).
  - **Account:** "Signed in with ChatGPT" in green with a seal, then "You signed in to Codex in your browser, and Dighouse uses that sign-in. It never sees your password.", the plan and the dial. The row with the bar is gone.
  - **Privacy** is one table of seven lines: what it is, what happens to it, and a mark at the right, "Stays here" in green or where it goes in tan (Model provider, Open data, Apple Maps, GitHub with its switch).
  - **Keys:** one line each with Get a token and **Add**; the box to paste into shows only after Add.
  - **Tools** opens with what a tool is, and each stage's row says what the stage does instead of listing three tools.
  - **Advanced:** the four circles are four lines (You, The model, The engine, The tools), each with what it does, how it stands and its one button. "Models on offer" is **Models you can use**: "10 with your ChatGPT sign-in, 81 more through OpenCodex".
  - **Seen:** Account, Data and keys and Advanced at 1440 × 900. **Not pressed:** Add on a key (the Save and Remove behind it were checked in the launch loop and did not change), and Advanced's three buttons.
- **C5, the map's dots.** Zoomed out, the searched areas gather into dots (`clusters`: 142 areas were about a dozen dots over the United States), a larger dot for more than one area. A click on a dot shows a card, "You searched 2 areas here", the projects' names, "From the projects in your sidebar. Only this Mac shows them.", **Go there**, and **Open the project** when the dot is one project. A survey's dot is a button: its card names the survey and offers **Start a project here**. The legend says which dots can be clicked. **Seen:** a click on a dot in the Ohio valley (two projects named) and on Perry Mesa's survey dot. **Not pressed:** Go there, Open the project, Start a project here. **Not measured:** how fast the map moves; the fewer dots are the only change to its speed in this loop.
- **C6, colour.** Each way to start has its own colour, as a wash on its card, its icon and its edge under the pointer: violet for What should I research?, blue for Pick a place, green for Size up a place, amber for Show open surveys, and tan stays for Find something. Home's three cards and its How it works steps, and the question rows on the empty chat, follow. Two colours were added to `Theme` for this, violet and rose. **Seen** on the empty chat. **Not seen:** the Toolbox and Home after the change, and the cards under the pointer.
- **C7, checks.** The spacing and link checks pass, and the app's 13 tests. For checks: `-openDecide YES` with `-openProject`, and `-openPage chat`.
