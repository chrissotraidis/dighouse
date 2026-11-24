# Dighouse goal loop: seeing a find clearly

Written 2026-11-24, after the find loop. A plan to agree on with Chris before any code changes. The Log at the end will say what was done and checked.

Read [FIND_LOOP.md](FIND_LOOP.md) first. The search now reaches 31 to 34 km² an hour on ready-made ground (sweeps of three areas at once) and puts a short list in front of a person. This loop makes each find on that list quicker to understand and to rule out.

## Where the ideas come from

WYKOPKI, a Polish lidar tool shown in a 15-minute video (ARCHEO LAB, November 2026). It is built from open parts:

- **Its views come from RVT,** the Relief Visualization Toolbox, Apache-2.0. These include VAT, multi-scale relief, local dominance and openness.
- **Its detectors come from ADAF,** whose code is Apache-2.0. Its eight pretrained models are a 5 GB download.
- **Its strongest check compares lidar flights from different years** around a find.

What it does that Dighouse does not:

- **A count of reasons for and against** on each find, labelled as a count of statements and never a probability.
- **Ranks by how many methods agree.**
- **Four numbers on each find card.**
- **A switch between two slice directions.**
- **A 1.70 m figure for scale.**
- **A 3D view whose height can be stretched.**
- **"Find similar"** from a drawn example.

The site at <https://www.ekipa.tv> holds its notes. Its visit list, route and phone link are left out of this plan (see Decisions).

## The aim

A person understands a find in under 20 seconds. They can see why it was marked, what speaks against it, whether the ground changed between flights, and how big it is. More of the finds that are modern or natural are ruled out before a person sees them.

## Goals

| Goal | What | Done when |
|---|---|---|
| V0 | **Measure and check.** Time a person deciding 20 finds from Elverum and Dartmoor in the test copy. Check that RVT's code runs on Python 3.12 if copied in, or else pin it. Read the terms of ADAF's model files on Zenodo. Time ADAF on 1 km² on this Mac, and note PyTorch's size. Count how many of Chris's areas have flights from two years: USGS through WESM, the Netherlands (AHN 2 to 4), Denmark and England. | A baseline table, and a yes or no with reasons for RVT, ADAF and comparing flights, written in the Log. |
| V1 | **The case on the card.** Each check already on a record becomes one line, for or against: the slice, the second opinion, the map check, the records check and old maps. The card shows a count bar labelled "a count, not a probability". Chips show what marked the find: the agent, the bulk look or a measured rise. Four numbers: the height against the ground around it, ground points per m² or forest nearby where known, the change between flights once V4 lands, and other finds within 200 m. The slice switches between west–east and north–south, and shows a 1.70 m figure. | Fits 1440 × 900 without scrolling. VoiceOver reads the count. Keys still clear 20 finds. Word count on the card is no higher than before. |
| V2 | **Ranks by agreement.** A means the shape check, the agent's eye and the second opinion all say built. B means two of them do, and C means one. Decide sorts Needs you by rank. The rank never changes what counts as "needs you". | Ranks match a hand count on three projects. The counts in the header, on Home and in Decide still agree. |
| V3 | **Better views of the ground.** VAT, multi-scale relief and local dominance from RVT's code join the six close views, each with one line saying what it shows. Add closed hollows, and ground points per m² where raw points exist. A person sees them first. They reach the bulk look or the agent only if the blind tests are no worse. | Views draw in under a second at 60 m. Smoke test passes. If any view reaches a model, Borre, Mound City, Maiden Castle, Cahokia, Andía and Sandefjord are no worse. |
| V4 | **When did it appear.** Where two flights cover a find, fetch both over 120 × 120 m. Shade each the same way and remove the steady offset between them. Record the noise as the 95th percentile of change. Draw the change blue where ground was removed and red where it was added. The card gets a slider between flights. The record says "absent in 2011, present in 2019, possibly modern" or "present in both flights". Start with the Netherlands and USGS. | On five known modern features and five known monuments, the record says right on at least 8 of 10. No coordinate leaves `private/`. |
| V5 | **Compare on the map.** A divider and a transparency slider between the ground and an old map or photo already fetched: US topographic sheets, France's État-major map and its 1950s photos, and NAIP in the US if V0 finds it open. Esri's imagery stays out unless its terms allow it. | The divider works with a mouse and the keyboard, and has no stall over 250 ms. |
| V6 | **A find in 3D.** The 120 m square in 3D, with height at ×1, ×2 or ×4, the light's direction, the 1.70 m figure and a vertical ruler. A small still on the card opens it. | Opens in under a second. Respects Reduce Motion. Both window sizes checked. |
| V7 | **Find similar.** From a find a person agreed is built, look for rises in the project with the same radial profile, built on `find_mounds`. Results join the map as a layer, the way finds kept on the map do, each with an agree or reject button. | Seeded with one Borre mound, it brings back more of Borre's key than it misses, at no more than 15 false finds per km². Blind tests are no worse. |
| V8 | **A person marks a spot.** Click a point or draw an area, add a note, and the agent runs the usual checks on it. | A marked spot gets a slice, a second opinion and a records check like any find. |
| V9 | **ADAF as a second detector,** only if V0 says yes. It runs on the Mac beside the bulk look, and its finds feed V2's ranks. | Ships only if recall at Borre and Sandefjord rises with no rise in false finds per km². |

V1 and V2 come first, because they help the finds already waiting. Then V4 and V3. V5 to V8 can follow in any order. V9 waits on a decision.

## Decisions (taken as defaults, 2026-11-24; Chris can change any of them)

1. **ADAF.** Its model files' terms are checked in V0; nothing is downloaded until Chris says yes to a 5 GB download and PyTorch for a detector trained mostly on Irish lidar. V9 waits on that.
2. **Esri imagery** stays out unless its terms allow showing it (WYKOPKI marks it "for viewing only").
3. **Visit list, route and phone link** stay out: they go against "Do not visit or dig" and keeping locations in `private/`.
4. **Merging.** One pull request per goal, merged when its check passes, as before.

## Ground rules

As in [AGENTS.md](../AGENTS.md) and [DESIGN.md](DESIGN.md). Few words. One word for one thing. A person decides. Nothing is called new. Locations stay under `private/`. Tests that talk to a model use primary / 6.1 Terra. The benchmark guards any change to how finds are made. Work in the test copy, and leave Chris's settings and projects as they were. Credit RVT and ADAF in the README's sources and in each file taken from them.

## Log

- **2026-11-24.** Plan written in another chat from a second, full-resolution pass through the video and a read of the code on `main` after G7, and added to the repo with the decisions above taken as defaults. Work starts with V0 to V2.
