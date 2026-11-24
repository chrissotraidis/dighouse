# Enhancements

Things to build into Dighouse, one line each. Add to it freely. When an item becomes a goal in a loop, link the loop. When it ships, move it to Done with the pull request.

## Seeing a find (planned in [SEE_LOOP.md](SEE_LOOP.md))

- Closed hollows as a view of their own (sky view and openness down show them now), and ground points per m² as a picture rather than a number.
- Flights from different years: the Netherlands' older AHN (PDOK serves only the current one), and a check of "possibly modern" on known modern features.
- ADAF as a second detector: not in the download. Its model files are 5.5 GB under CC BY-SA 4.0 and it needs PyTorch, so it would be an optional add-on, and only if it finds more at Borre than the bulk look.

## Asked for earlier, not built

- The agent driving a browser of its own, for sources that refuse a program.
- A button that sends records to Notion.
- Borre's raw points from hoydedata.no, to build a ground model that shows more small mounds.
- Sweden's and Finland's lidar, once Chris makes the free accounts.
- Poland, Spain's national 2 m model, more German states, the UK's Admiralty surveys, NOAA's coastal lidar.
- Archaeoastronomy, with `horizon_profile` and `alignment_check`.
- A second field for open astronomy.

## Rough edges seen

- Tile seams on the map.

## Done

- The case on the find card: For and Against as a count, ranks A, B and C, a line of numbers, a north-to-south slice and a 1.70 m figure ([#137](https://github.com/chrissotraidis/dighouse/pull/137)).
- VAT, multi-scale relief and local dominance views, each with one line saying what it shows ([#138](https://github.com/chrissotraidis/dighouse/pull/138)).
- When did a find appear: `compare_flights` on two dated USGS flights ([#140](https://github.com/chrissotraidis/dighouse/pull/140)).
- Old maps beside the ground, with a divider ([#141](https://github.com/chrissotraidis/dighouse/pull/141)).
- A person marks a spot on the map and it gets the usual checks ([#142](https://github.com/chrissotraidis/dighouse/pull/142)).
- A find in 3D with stretched height and a 1.70 m post ([#143](https://github.com/chrissotraidis/dighouse/pull/143)).
- Find similar: tried and not built, it found fewer of Borre's mounds than the plain ranking; the numbers are in SEE_LOOP's log ([#143](https://github.com/chrissotraidis/dighouse/pull/143)).
- A divider between two flights on the Decide card, beside the change map; a slider that fades an old map over the ground; a ruler in the 3D view; a person drags a box on the Map and the agent looks closely at those tiles; a field for an OpenAlex key in Settings ([#147](https://github.com/chrissotraidis/dighouse/pull/147)).
- A notarized download (`app/scripts/release.sh` with a notary profile), and a first run tried in an empty home folder ([#146](https://github.com/chrissotraidis/dighouse/pull/146)).
