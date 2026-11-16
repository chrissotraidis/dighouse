# Proving it: answering "why not ChatGPT?" and "what has it found?"

Last updated: 2026-11-16

The two doubts a release will meet, and what answers each with evidence instead of claims.

## "Why not just ask ChatGPT?"

A chat app can describe lidar. It cannot fetch a survey, look at every tile, cut a slice through the points, or remember what was read. The answer is to show the difference, not argue it.

1. **A side-by-side test (done 2026-11-16).** primary / 6.1 Terra with no tools and no web was given the Mound City blind test box and asked what built features are in it. It answered that it could not reliably identify, count or place features from coordinates alone. Through Dighouse the same model found 19 of 19 there blind. The README says so under "Why it exists".
2. **The scorecard on Home.** Replace the "Why not just ask ChatGPT?" board's claims with the benchmark: 44 of 83 found blind, and a button to run one yourself. (Still to do.)
3. **Receipts in every report.** Each finding links the tile picture, the slice and the sources it rests on, so a reader can check it in a minute.

## "If it is so useful, why has it found nothing?"

Until 2026-11-16 every run was on a famous site, by design: that is how the method is tested. The honest path to a first real result:

1. **Calibrate, then search where nothing is on open record.** Two searches so far, both calibrated first on Mound City (18 of 19 each time):
   - Great Seal State Park woods, Ohio: 9 tiles, nothing marked.
   - Tar Hollow ridges, Ohio, 1 sq km: 25 tiles (19 modern, 5 natural, 1 built). One find, a graded pad by a road junction, which the checks suggest is modern. The measured rises there sit on slopes and track edges and are not convincing.

   Nothing worth reporting yet. The next searches should be wider (10 sq km and more) and in wooded uplands where the open records are thin.
2. **Report candidates the right way.** A find with a slice in the ground, nothing modern on it and no match in what was read is a candidate, not a discovery. In Ohio it goes to the State Historic Preservation Office's Ohio Archaeological Inventory, which holds the site files the public cannot see. The office can say in days whether it is recorded.
3. **Tell the story whatever the answer.**
   - "Already recorded" means the method found a real site blind, which is a result.
   - "Not recorded" is the headline, and it is still worded as "not in the records we could reach, confirmed as unrecorded by the SHPO". The tool never calls it new; the authority does.
4. **Fix the known weakness first where it matters.** Small mounds are the gap (Borre 18 of 53 by eye). `find_mounds` measures round rises from the ground model, and the clearest (at least 0.6 m high, roundness 0.85) go on a list for a person:

   | Site | Found by the agent | With the measured rises | Extra spots added |
   |---|---|---|---|
   | Borre | 19 of 53 | 23 | 7 |
   | Mound City | 19 of 19 | 19 | 4 |
   | Cahokia | 1 of 1 | 1 | 1 |
   | Maiden Castle | 1 of 3 | 2 | 3 |
   | Angel Mounds | 4 of 4 | 4 | 2 |
   | Serpent Mound | 1 of 3 | 1 | 11 |
   | **All six** | **45 of 83** | **50** | **28 more (37 in all)** |

   A lower bar finds more and costs more: at 0.4 m it is 52 of 83 with 55 spots that are not on the key. The agent, given the spots, still marks few of them, so the list is shown to the person beside the finds. Next: mask slopes and tracks to cut the extras.

## First-time users

- **One button to see it work:** "Test it on a known site" (done). A first-time user should see a scorecard within five minutes.
- **No build from source:** a notarized download is the biggest barrier left.
- **No iCloud trap:** projects in an iCloud-synced Documents folder go "dataless" and stall reads. Default the projects folder to ~/Dighouse, outside Documents, and offer to move existing projects.
- **No setup wall:** a missing Codex install or model should lead to one clear page, not a failed chat.
- **Costs stated:** a test costs a few minutes of a cheap model; say so before the first run.

## Credibility with archaeologists

- **Publish the benchmark method,** keys and code so others can rerun it, and invite people to add answer keys from their own regions.
- **Name the limits on the first screen** (done in the README; do the same in the app's welcome guide).
- **Ask two or three archaeologists to try a blind test** and quote what they say, criticism included.


## Loop 7: more of the world (2026-11-16)

- **Coverage:** five more places (Navarre, Bavaria, Saxony, New Zealand, Denmark with a token) and the seafloor of US waters. Two official registers are read in the checks (Navarre, Denmark), so "not on record" there means "not in the national register, checked on this date".
- **Method:** a look at the whole area before the tiles found enclosures the tiles had been calling field edges (Oberhaching 0 to 2 of 3, Lauske 2 to 3 of 3).
- **Benchmark:** 53 of 103 known features across eleven land sites in five countries, and 4 of 7 charted wrecks in a seafloor pilot.
- **Still no novel find.** The registers make Navarre and Denmark the best places to try first: a find there can be checked against the official list the same day.
