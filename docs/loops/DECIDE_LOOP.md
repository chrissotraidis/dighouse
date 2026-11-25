# Dighouse goal loop: deciding finds, and getting leads to an answer

Written 2026-11-22, after the mound loop. This is a plan to agree on with Chris before any code changes. The Log at the end will say what was done and checked.

Read [MOUND_LOOP.md](MOUND_LOOP.md) first. The search is fast and keeps its method. What holds Dighouse back now is the step after the search: a person faces hundreds of finds, and a lead cannot reach an answer.

## Where things stand (counted on 2026-11-22)

From the 66 projects in Chris's list, read from each find's record:

| | Finds |
|---|---|
| All finds, outside blind tests | 744 |
| Decided by a person | 18, all in early test projects |
| Worth a closer look (leads) | 8 |
| Look again (the agent says natural, the second model says built) | 72, of which 71 are measured rises |
| Modern or natural, suggested | 546 |
| Already published, suggested | 48 |
| No suggestion yet | 52 |
| Marked "no match in the sources read", or reported | 0 |

- **Nothing has been found that could be called new,** and the method would not say so in any case. The eight leads are Darby Prairie C-002 and C-008, Shawnee Woodland Larger C-001, C-002, C-003 and C-008, and Lusk Creek Woodland C-002 and C-003. Six of them are rectangular or oval hollows, in the Hicks Dome fluorspar district or beside tracks. Prospect pits, cellar holes and charcoal hearths come first.
- **Every ground search since 2026-11-20 was in Ohio, Illinois or Alabama.** Their site files are not public, so a lead stops at "could not open" on the one source that would settle it. No ground search has run outside the United States.
- **Measured rises are most of the work.** They are 824 of all 1,332 finds (62%). The second model calls 28% of them built, against 54% of the finds the agent marked by eye. Perry A1 has 90 finds, and 84 of them are measured rises.
- **What a person sees** (Perry A1, 1440 × 900, chat and workspace side by side):
  - The header says "1 needs you", the overview says "Decide 90 finds", and Review opens on "1 of 90".
  - Review shows one find at a time. Agreeing with many at once lives elsewhere, in the Records list.
  - On a find the agent calls natural, "A second model agrees (a weak check)" shows a green tick. That second model said built, so it disagrees with the suggestion, yet the screen reads as agreement.
  - The relief picture is small, at one scale, with no wider view. The slice leaves half its box empty. The suggestion's reason is printed twice.
  - The workspace tabs shrink to "M… … … N… … 2 D…". On the map, 90 labels overlap into one block.
  - "Second opinions" is greyed out with no reason given.
- **Records go stale.** Perry A1's search report was written before the second opinions came in, and still asks for 75 more. RESEARCH.md says all 90 have one.
- **The project list is a pile.** 66 projects sit in one list: 15 blind tests, 15 with no finds, and several stopped part-way (Perry Mesa looked at 0 of 66 tiles, Fresh Athens A2 0 of 30, Zaleski 27 of 36). They use four naming styles. Chats repeat names ("What should I research? 4").

## The aim

A person clears a 90-find project in about ten minutes. They look one at a time only at the finds that need them, and a lead can reach an answer.

## How deciding should work

When a search ends, the project card says, for example: **6 need you · 70 to agree with · about 8 minutes**. One press opens **Decide**, which fills the workspace.

~~~
┌ Decide ─────────────────────────────────────────── 6 need you · 70 to agree ┐
│ 1 Needs you   2 Agree in bulk   3 Done                                        │
├───────────────────────────────────────────┬──────────────────────────────────┤
│  [ relief, fixed scale, find ringed ]     │ C-008 Angular bank beside creek   │
│  [ wider view ]   views: 1 2 3 4 5 6      │ Agent: natural   Second: built    │
│  [ slice through the points ]             │ → they disagree                   │
│                                           │ 0.6 m high · in the ground ·      │
│                                           │ track 40 m · 2 sources read       │
├───────────────────────────────────────────┴──────────────────────────────────┤
│ Natural N   Modern M   Published P   Worth reporting R   Skip S   Undo ⌘Z     │
└───────────────────────────────────────────────────────────────────────────────┘
~~~

- **Needs you:** the leads, then the finds where the agent and the second model disagree. One at a time, with big pictures.
- **Agree in bulk:** the routine finds as a grid of same-scale pictures, each with its suggestion underneath. Untick any that look wrong (they move to Needs you), then press **Agree with 64**. Every record still gets your name and its own reason. A lead can never be agreed with in bulk.
- **Done:** what you decided, with Undo.

## Goals

Work them in order. Each is done when its check passes in the running test copy, or in a logged benchmark run.

| Goal | What | Check |
|---|---|---|
| D0 | **Time the person.** Copy Perry A1 and Shawnee Woodland Larger into the test copy. Time clearing each as the app is now: presses, seconds and screens. | A baseline table in the Log. |
| D1 | **One place to decide.** Replace the Review sheet, the Records groups and the group sheet with one Decide view in three steps: Needs you, Agree in bulk, Done. Decisions are written as now, one commit per batch, and Undo reverts the record and its commit. | Perry A1 cleared in 10 minutes or less, with no more than a third of the D0 presses. Every record names the person and gives a reason. A lead cannot be agreed with in bulk. Undo restores the record. |
| D2 | **A find that reads at a glance.** Big relief at a fixed scale with the find ringed, and a wider view beside it. Views on keys 1 to 6: composite, local relief, sky view, hillshade, openness up, openness down. The slice at its own shape. One plain line: "Agent: natural · Second model: built · they disagree", with no tick for an opinion. Checks as short chips, sources folded to one line, the suggestion shown once. Keys for every decision. A reason is asked only when you change the suggestion. | No scrolling at 1440 × 900. VoiceOver reads the verdict line. The keyboard alone clears 20 finds. The tick bug is gone. |
| D3 | **Fewer finds to decide.** Measured rises become a layer: one row per area ("38 measured rises, 3 raised"), shown on the map and scored in blind tests as now. A rise becomes a find when the second model calls it built and its shape ranks high, or when a person opens it. | Blind-test recall unchanged, since rises still count when scored. Finds a person must decide fall by at least 60% across the M6 projects. Every look-again find is still listed. |
| D4 | **Counts and records that agree.** One count, "N need you", the same on the header, overview, sidebar and Decide, with "M to agree" beside it. The report and RESEARCH.md rebuild when opinions arrive and after each batch. The workspace tabs become icons with counts when narrow. Map labels show on hover, on selection or when zoomed in, and dots cluster when zoomed out. A greyed-out button says why. | In Perry A1 every count matches, the report has no stale line, the tabs are readable 1280 wide, and the map is readable with 90 finds. |
| D5 | **Leads that can reach an answer.** Read open heritage registers in the checks, after confirming each is open and its terms allow it: Historic England's scheduled monuments, Norway's Kulturminnesøk and Bavaria's monument layer (Denmark and Navarre are read already). Search on its own prefers ground where a register is open, unless a person picks the place. For a lead where the register is closed, "Ask the site file" drafts a request to that state's office, kept under `private/` because it names the place; the person sends it. Run old maps and mine records on the eight open leads. | A timed hour in a register region ends with every lead either matched to the register or ready for a person. Each of the eight leads has its next step on its record. |
| D6 | **Projects and chats in order.** The sidebar gets sections: Searches, Known sites, Blind tests, Archived. Archiving only hides; no folder moves. New searches get one naming style ("Perry, Ohio · A1 · 22 Nov"). A stopped project offers Carry on or Close. Chats are named from what was asked. | Chris's 66 projects sort into sections with no folder moved or renamed. His settings match the backup afterwards. |
| D7 | **Security and release hygiene.** Tokens move to the Keychain, and `keys.json` is read once, then removed. Text from web pages and PDFs is marked untrusted in tool results, and the skill says never to act on it. CI checks that a sample project's shared files hold no coordinates, and audits the Python dependencies. Prepare the notarized download (needs Chris's Apple Developer account). | Tests pass. A page with planted instructions does not change what the agent does. Smoke test and blind tests no worse, since the skill changes. |
| D8 | **More ground,** in this order, each with a live test on a known site and a README row: Navarre's 0.5 m model; Poland's 1 m model (retry its WCS); Spain's national 2 m model where it can be scripted; German states with open 1 m models (Thuringia, Hesse, Brandenburg, Lower Saxony). Then, if Chris makes the free accounts, Sweden's 1 m model and Finland's points. Under water: the UK's Admiralty surveys and NOAA's coastal lidar, which sees shallow water. | Each source fetches, builds and tiles a known site. The README's "not read yet" line matches the code. |

D0 to D4 are the review work and come first. D5 is what lets a find get past "lead". D6 to D8 can follow in any order.

## Decisions (Chris, 2026-11-22: "go with your recommendations on all six")

1. **Measured rises come off the list (D3).** They stay on the map and in scoring, and are not finds until raised.
2. **Search on its own goes where a register is open (D5),** unless a person picks the place.
3. **Accounts (D8):** Sweden and Finland are read once Chris makes the free accounts himself. Nothing is signed up for him.
4. **Site-file requests (D5)** are drafts that Chris sends.
5. **One pull request per goal,** merged when its check passes.
6. **Borre closes at 29 of 53** for the mound loop. Ordering the raw points stays on the roadmap; it needs Chris's e-mail address, and he sends it.

## The questions as they were put

1. **Measured rises off the list (D3).** They stay on the map and in scoring, but are not finds until raised. Agree?
2. **Where Search on its own goes (D5).** Default to regions with open registers (Norway, England, Bavaria, Navarre), or keep searching Ohio?
3. **Accounts (D8).** Make free accounts for Sweden (Lantmäteriet's Geotorget) and Finland (an NLS API key)? Each needs your e-mail. Denmark's token stays your call too.
4. **Site-file requests (D5).** Drafts only, and you send them. Agree?
5. **Merging.** One pull request per goal, merged when its check passes, as before?
6. **Borre's raw points** from hoydedata.no, still open from the mound loop: order them (needs your e-mail), or close at 29 of 53?

## Ground rules

As in [AGENTS.md](../../AGENTS.md): few words, a person decides, nothing is called new, locations stay under `private/`, only people are credited, tests that talk to a model use primary / 6.1 Terra, and the benchmark guards the method. Work in the test copy and leave Chris's settings and projects as they were.

## Log

- **2026-11-22.** Plan written from a count of all 66 projects and a look at Perry A1's overview and Review in the running app. Repository hygiene added in the same change: AGENTS.md (credit to people only), CLAUDE.md, CONTRIBUTING.md, SECURITY.md, docs/DESIGN.md, pull request and issue templates, and a CI workflow that runs the offline tests and `scripts/check_human_authors.sh`. No app code changed.
- **CI has not run yet.** On the first pull request (#107), GitHub did not start the jobs: "recent account payments have failed or your spending limit needs to be increased". Both jobs were run by hand instead: the offline tests pass after `uv sync --locked`, and the people-only check passes on #107's commits and description. It catches Claude, ChatGPT and Copilot attribution lines, and lets prose that mentions the rule through. The workflow runs as soon as Actions billing is fixed, or for free once the repository is public.
- **Decisions taken.** Chris chose the recommendations on all six (above). The mound loop is closed at Borre 29 of 53.

### D0: the person's time, before

Checked in the test copy (`DighouseTest.app`, its own settings) on copies of Perry A1 and Shawnee Woodland Larger in `~/dighouse-ui-test/decide`, with the window at 1440 × 900 and chat and workspace side by side, as Chris uses it.

| | Perry A1 | Shawnee Woodland Larger |
|---|---|---|
| Finds waiting | 90 (84 measured rises) | 36 (27 measured rises) |
| As the app groups them | 1 look again, 89 modern or natural | 4 leads, 21 look again, 11 modern or natural |
| What the header says | "1 needs you" | "25 need you" |
| What the overview offers | "Decide 90 finds" | "Decide 36 finds" |
| The way the overview leads: Review, one at a time | 91 presses, 90 pages | 37 presses, 36 pages |
| The app's own wait per decision | about 1.2 s (one tool call and one commit each; commits 1 to 2 s apart when Return was pressed straight away) | the same |
| A person's time, at about 20 s to look at one find's pictures and checks | about 32 minutes | about 13 minutes |

- **The quick way is hidden.** "Agree with these" exists only in the Records list, and the Records list shows its groups only when the workspace is at least 760 points wide. Side by side with the chat at 1440 × 900 it is narrower, so Records shows one find and a menu, with no groups and no way to agree in bulk.
- **Agreeing in bulk is blind.** Where it does show, its sheet lists names and reasons with no pictures. A careful person must still open every record: 89 for Perry A1.
- **The overview and the header count different things.** The header counts the leads and disagreements; the overview counts every waiting find.
- **Review always opens on all waiting finds,** leads and routine ones alike, so the few that matter are mixed in with the 89 that do not.
- **Seven decisions were recorded in the test copy** while timing (C-057 and C-001 to C-006). That copy was set aside, and a fresh copy is used for the D1 check.

So the target for D1: Perry A1 in 10 minutes or less (a third of 32), in no more than 31 presses, with pictures for every find a person agrees with.

### D1: one place to decide

**What changed.** `DecideView` (Decide.swift) replaces the Review sheet, the Records list's "Agree with these" sheet and the record's own decision sheet. It opens from the overview card, a record's Decide button, ⌘R and the Toolbox.

- **Needs you:** leads, then disagreements, then finds with no suggestion, one at a time. Return agrees with the suggestion. N, M, P and R pick Natural, Modern, Published or Worth reporting and ask for a reason; Escape takes the choice back without closing Decide. S skips, ← goes back, ⌘Z undoes. After the last one, Decide moves on to the routine finds by itself.
- **The verdict line** replaces the ticks: "Agent: natural · Second model: built · they disagree". A modern suggestion that the second model calls not built reads "both rule it out". A lead with checks still open says which, under the bar; the person may still decide, and the tools write them beside the decision.
- **Agree in bulk:** a grid of close views, each 60 m across with the find ringed (cut in the app from the record's tile picture, at a fixed scale from the tile's size), with the suggestion's reason under each. Unticked ones move to Needs you.
- **Done:** every decision made here, each with Undo.
- **Tools:** `decide_many` checks every decision first, writes them, rebuilds the research record once, and makes one commit. `undo_decision` returns a find to the status it had (now kept with each decision as `was`), removes the decision, logs who undid it, and commits. Both are for the app; agents do not call them. An offline test covers both.

**Checked** in the test copy, on fresh copies:

| | Before (D0) | Now |
|---|---|---|
| Perry A1, presses to clear | 91 | 6: open Decide, Return on the one look-again find, untick C-001, Agree with 88, then N, a reason and Return for C-001 |
| Perry A1, the app's wait | about 1.2 s × 90 | 1.2 s for the one find, 1.2 s for all 88 together, 1.3 s for C-001 |
| Perry A1, a person's time (20 s a find looked at alone, 3 s a close view in the grid) | about 32 minutes | about 5 minutes |
| Shawnee Woodland Larger | 37 presses, about 13 minutes | 25 alone and 11 in the grid: about 9 minutes. D3 is what shrinks this one, since 21 of its 25 are measured rises. |

- The 88 decisions came out as one commit, "88 finds decided by Test person", each record with its own reason and the person's name. RESEARCH.md said 89 of 90 decided.
- Undo on C-001 returned it to waiting with no decision on its record, logged "Test person undid the decision 'natural feature'", and committed "C-001: decision undone by Test person".
- Found and fixed while checking: the reason field did not take focus in the sheet, and Escape in it closed Decide.
- **Not checked:** the first-project tutorial end to end (Decide puts all of the tutorial project's finds under Needs you, so its words still fit), and VoiceOver (D2).

### D2: a find that reads at a glance

**What changed.**

- **Six views on keys 1 to 6:** composite, local relief (5 to 15 m), sky view, hillshade, openness up and openness down. Each is the same 60 m square with the find in the middle and the same ring as its record. The view chosen stays from find to find.
- **`find_views`** (tiles.py, and a tool) draws them from the ground model, under `data/views` so they stay out of the project's history, and never draws a view twice. Six views of one find took 0.28 s. Decide asks for them when a find opens and draws the next find's while this one is read.
- **The card** shows the close view, the whole tile with its width, and the slice. Below come chips for height, size, open maps, old maps and sources, then the second model's words, the sources and the agent's notes folded away. The suggestion's reason is shown once.
- **VoiceOver** reads the verdict as one sentence: "The agent says worth reporting. The second model says not built. They disagree."

**Checked** in the test copy at 1440 × 900 on the Shawnee copy:

- **No scrolling.** The lead C-001, with views, chips and the decision bar, fits with room to spare.
- **Views switch.** Key 2 switched to local relief, where the hollow stands out as a dark oval.
- **The verdict line reads as one sentence.** The accessibility tree gives the sentence above. Before the fix it read the separating dots aloud.
- **The keyboard alone cleared 20 finds.** The sequence was ⌘R to open Decide, Return to agree, M with a typed reason and Return, S to skip, ← to go back and ⌘Z to undo. The history shows 21 decisions and 1 undo, and Done shows 20.
- **Found, not fixed here.** The shape chip on hollows says "a coherent, round rise", because the shape check measures rises. A hollow needs its own wording, and its own check.

### D3: fewer finds to decide

**The rule** (`ledger.layer`, mirrored in the app's `ProjectStore.layer`): a measured rise goes to a person when the second model calls it built and its shape rank is in the top half of the project's measured rises, or when a person raises it. Ranks are compared within a project, because older projects were ranked on a 0 to 3 scale and newer ones (the M3 contrast ranking) on 10 to 300. The rest stay on the map as a layer.

- **The research record** says "A person has decided 0 of 4. 41 measured rises are kept as a layer on the map…", and lists each such rise as "a measured rise kept on the map".
- **The search report** counts them under its decisions instead of naming them.
- **`list_candidates`** marks each one `kept_on_the_map`.
- **`raise_rise`** lets a person bring one back from its record, with "Raise it".
- **On the map** a kept rise is a small dot with no label.
- **Decide** leaves them out. After the last decision it says how many are kept and offers "Look at the 4 the second model calls built".

**Checked.**

| | Finds | For a person before | Now | Fewer |
|---|---|---|---|---|
| The two-hour run's five projects (M6) | 232 | 232 | 36 | 84% |
| All 66 projects, outside blind tests | 744 | 744 | 313 | 58% |
| Athens A1 in the test copy | 45 | 45 | 4 (1 alone, 3 in bulk) | 91%; cleared in 3 presses |

- **Blind-test recall is unchanged.** Rescoring the saved runs gives Borre 29 of 53, Mound City 19 of 19 and Andía 4 of 11, the same as before, because every rise still counts.
- **What a person would not see.** At Borre, 8 of the 29 mounds found were found only by measured rises. Blind tests ask no second opinion, so all 8 would be on the map in a search like this; 4 of them rank in the top half and would reach a person if the second model called them built. At Andía all 4 were found only by rises, and 1 ranks in the top half. Mound City lost none.
- **Look again.** Across all projects, 34 of the 72 "look again" rises rank in the lower half, so they are on the map. Each is one press away in Decide, which is why the offer is there.
- **Tests:** a new offline test covers the rule, the record, the report, raising and `list_candidates`. The offline tests pass (39).

### D4: counts and records that agree

**What changed.**

- **One count.** `ProjectStore.needsYou` and `toAgree` feed every place that counts finds: the header badge ("10 to agree with", which now opens Decide), the overview card ("Your turn: 10 to agree with", with a time worked out at 20 s a find alone and 3 s each in the grid), the "Your decisions" row ("0 of 10 decided, 80 on the map") and the steps in Decide.
- **Reports follow the records.** Whenever RESEARCH.md is rebuilt, the newest search report is rebuilt in place, keeping its file and the agent's advice (`report.refresh`). After a batch of second opinions the open project's record is rebuilt too. The report now says "in Decide" where it said "in the review".
- **Tabs.** The workspace tabs show words when they fit, and icons with their counts when they do not.
- **The map.** With more than 15 finds put to a person and the map zoomed out, finds are plain dots, labelled when pointed at or chosen, and all labelled once zoomed in. The map's controls fit in one row, then with short names, then in two rows.
- **Second opinions** in Decide says why when it is greyed out.

**Checked** in the test copy:

- **Perry A1 (a fresh copy).** The header, the overview and the decisions row all say 10. The stale report line "Give C-015, C-017 and 73 more a second opinion" was gone once the project opened. The report now names the finds that wait and says 80 measured rises stay on the map.
- **At 1440 × 900.** The tabs read as icons with counts (90 finds, 2 sources) where they read "M… … N…" before.
- **At 1280 × 800 (Shawnee).** Nothing is cut off. The map's controls sit in two rows, and its 25 pins are plain dots until pointed at.
- **Tests:** a new offline test covers the report following a second opinion and a decision, keeping the agent's advice and the same file. The offline tests pass (40).

## Where the loop stands

D0 to D4 are done. On the two-hour run's five projects, a person now decides 36 finds instead of 232, from close views, with Undo. Perry A1 went from 91 presses and about 32 minutes to about 6 presses and 5 minutes. Next, as planned: D5 (registers, so a lead can reach an answer), then D6 to D8.

D6 (projects and chats in order) was done differently, as part of [HOME_LOOP.md](HOME_LOOP.md) (H3): projects first with their chats under them, and blind tests in their own group. Archiving and the naming style were left out; a session's project is named by the agent after its region.
