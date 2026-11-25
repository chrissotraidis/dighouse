# The five-hour run, 21 November 2026

From 02:00 to 06:58 JST, after the release loop (G0 to G13) was merged, Dighouse ran timed research on primary / 6.1 Terra (High) in the Mac app. A coordinator watched through computer use and stepped in twice. This is what it did, what it found, and what it showed about the app.

## What happened

| Time (JST) | What | Coordinator |
|---|---|---|
| 02:00 | Timed research session started for 5 hours. It read the earlier session's record and re-checked its benchmarks (El Tiradero field plans, Moundville's 1905 plan and repeat flights, Cahokia map registration). | — |
| 02:52 | It saved a ranked assessment and **marked the goal complete after 52 minutes**, judging that more image-only passes could not settle its open questions. | — |
| 02:58 | A second session started to 06:58, with an instruction to search less recorded ground for finds rather than re-rank benchmarks (calibrate blind first, search fully, tally). | Intervention 1 |
| 02:58–03:40 | Eight projects in 40 minutes: four blind calibrations and four target windows of 0.15 to 0.25 km², most dropped as "not comparable" to their calibration. 0.15 km² searched, no finds. | — |
| 03:58 | Coordinator: one calibration per lidar source is enough; search 1 to 2 km² windows; an imperfect calibration lowers confidence but is no reason to skip; aim for 5 km². | Intervention 2 |
| 04:00–06:50 | Darby Creek prairie (Ohio), Alabama floodplain, three Shawnee and Lusk Creek woodland windows (Illinois): 7 windows in under 3 hours. | — |
| 06:50 | Dighouse's closeout timer asked it to close; it saved the session record, kept the earlier ranking unchanged and listed the decisions for a person. | — |

## What it found

- **Searched:** 8 completed windows, 10.0 km² requested, about 9.44 km² with ground data (plus a ninth window 31 of 36 tiles done). The windows include fields and built-up ground, so the 5 km² of woodland or pasture was not separately shown.
- **Finds:** 42, each sliced, measured, checked against open maps and the literature, and given a suggestion: 17 modern, 8 natural, **17 with no match in the sources read**, 0 matching a published site.
- **Calibration:** one blind test on the USGS source, Mound City Group, 19 of 19, reused for every window. Its restored mounds on open level ground say little about wooded slopes, which the agent said each time.
- **The 17 leads are almost all hollows, cuts and straight traces** ("Oval hollow with rim", "Rectangular basin at field edge", "Parallel cuts on slope"); one is a rise. In the Illinois fluorspar district and on old farms these are most likely prospect pits, ponds and field boundaries, and the agent says so in each suggestion. None is a mound, and none is called new.
- **No second opinions:** the second-opinion model (google-antigravity/gemini-3.8-flash) is refused by its provider.

## What it showed about the app

1. **A timed session can end itself early.** The first session left four of its five hours unused. Fixed: if the agent marks the goal complete more than 20 minutes before the deadline, Dighouse reopens it once with the next thing to do.
2. **Without a push it optimises for caution, not coverage.** It spent the first hour calibrating and dropping windows. One instruction (reuse a calibration, search 1 to 2 km²) took coverage from 0.15 km² to 9.4 km². That rule belongs in the skill, not a coordinator's message.
3. **`shape_check` called hollows "a coherent, round rise".** It measures raised shapes and fell back to that hint when nothing else fired. Fixed: a hollow is now described as a hollow and ranked last, with a test.
4. **The record said "a person stopped the run" when nobody had.** An interrupted turn (a message sent mid-turn) was written as the person's stop. Fixed: only a press of Stop counts.
5. **The closeout reads as the person's request.** Its message now says it comes from Dighouse's timer.
6. **It did not mis-claim anything.** Every lead is called a lead for a person, restricted state records are named as unchecked, and partial windows are kept out of the totals.

