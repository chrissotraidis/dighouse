# Roadmap

Where Dighouse goes next, in rough order. Nothing here is promised by a date. What already works is in the [README](../README.md); what was checked, and how, is in the loop logs ([EASE_LOOP.md](loops/EASE_LOOP.md) is the newest). The first four sections come from a review on 2026-11-25 of what a person who downloads the app would still miss.

## What a public download still lacks

These are things a stranger meets in the first day. Each was checked in the code on 2026-11-25.

- **Keeping the Mac awake.** Nothing stops the Mac from sleeping while a search runs, so a timed session left overnight stops when the Mac sleeps. Hold an activity (`ProcessInfo.beginActivity`) while a search or second opinions run, and say so in the bar.
- **Saying when it is done.** There are no notifications. A person who leaves a search running learns that it finished, or that finds wait, only by coming back to look. One notification when a search reports back, one when second opinions finish, none for each step.
- **Updates.** Nothing tells a person that a newer version exists. A check against the repository's latest release at launch, with a quiet line on Home, is enough to start; Sparkle later.
- **Disk use.** A five-hour session left 4.5 GB. The cache keeps up to 10 GB of points and `scripts/tidy.py` frees more, but the app shows neither what is used nor a way to free it. A line in Settings with the size and a Free space button.
- **Reporting a problem.** Settings, Advanced has details to copy. A Report a problem button that opens a GitHub issue filled with the version, the macOS version and the last log lines, with locations taken out, would let strangers help.
- **What each plan gets.** Searches run through Codex, signed in with ChatGPT or an OpenAI API key; second opinions can also use Claude Code. Someone with only a Claude plan can run the tools in Claude Code but not the app's search. How much an hour costs was measured only on a ChatGPT Pro plan (about 1.6% of the account an hour). [GETTING_STARTED.md](GETTING_STARTED.md) should say plainly what works on which plan, and what was not measured.
- **Other computers.** The app needs Apple silicon and macOS 14. The tools run on any computer with Python, inside Codex or Claude Code, and that path should be its own short page.

## The biggest gap: finds pile up faster than people decide

On the test Mac, 104 projects hold 27,219 finds, and 24 have been decided. A five-hour session in Mississippi put 687 finds to a person. However good the leads, nobody reads 687 of them, so most of the work never reaches an answer.

- **A short list, every time.** Home leads with the few strongest leads across all projects, and Decide can be started for a set time ("ten minutes, the strongest twenty") instead of a whole project.
- **Decisions that teach the ranking.** A person's decisions in a project could change what is put to them next: if they call nine of ten small measured rises natural, ask about fewer of those. This changes how finds are put to a person, so it ships only if the blind tests are no worse.
- **Fewer finds per square km.** The benchmark reports how many known features were found. It should also report how many finds a person would have to look at per square km, and set a target for it.

## Closing the loop on a lead

After a person marks a find worth reporting, the app drafts the letter to the records office and stops. Nothing records what happened next.

- **A lead's progress:** drafted, sent, answered, already recorded, visited, recorded as new by the office. Kept in the find's record, so the research record and the report can say it.
- **Giving the office the location.** A records office needs the place. This is the one time a location should leave the Mac, so it should be its own step: the person chooses the finds, sees exactly what will be sent, and sends it themselves.

## Seeing where you have searched

The coverage map shows where open lidar reaches, not where you have already searched. A layer of the areas every project has covered, on Home's map and New project's, would stop a person searching the same ground twice and give "least explored" a meaning they can see. Sharing searched areas between people would need coarse squares and a clear opt-in, because locations stay private.

## Next, for archaeology

- **Finding small mounds.** Borre 29 of 53 and Andía 4 of 11 on 2026-11-22. Most of Borre's misses are not in the 1 m ground model at all, so the next lever is the raw points: a ground model built with a lower ground-filter threshold, or a shape check that reads the points directly. Borre's points come from hoydedata.no's export, which e-mails the files; ordering them is the first step.
- **More ground.** Navarre's 0.5 m model, Poland, Spain's national 2 m model, more German states; Sweden and Finland with a free account; the UK's Admiralty surveys and NOAA's coastal lidar under water.
- **More answer keys.** Official registers like Norway's give complete keys; England's and the Netherlands' would add more.
- **Looking at tiles in bulk through the router.** The bulk look already sends every tile to a low-cost model; sending batches straight through the model router, for areas too large for one chat, is still open.
- **A browser of the agent's own,** for sources that refuse a program and today have to be opened by a person in the Sources tab.
- **Slices with treetops for ground-only data.** Some surveys publish only the ground returns, so a slice can measure a shape but cannot show the trees above it.
- **Archaeoastronomy.** Two small tools: `horizon_profile` (the height of the horizon in every direction from a point on the ground model) and `alignment_check` (the bearing of a feature's axis, turned into a declination and compared with solstice, equinox and lunar standstill lines). It needs a coarser wide model for the far horizon, and a horizon profile can identify a place, so it is stored under `private/` like any location.

## The repository, before it is public

- **The docs folder.** Nineteen loop logs and run notes sit beside the pages a newcomer needs. Move finished loop logs to `docs/loops/` and keep a short index, updating the links in the same pull request.
- **Checks on every pull request.** GitHub Actions did not start on the private repository (billing, 2026-11-22). Public repositories run them free, so the first public pull request should show them passing.
- **What only hands can check.** The list under "Not verified" in [HANDOFF.md](HANDOFF.md): Reduce Motion with the Mac's own setting, dragging with a real mouse, pinch and pan on a trackpad, the whole tutorial from start to end.
- **Languages and VoiceOver.** The app is in English only. Its main controls have VoiceOver labels; nobody has gone through a whole search with VoiceOver.

## Done since the last roadmap

Seeing a find clearly ([SEE_LOOP.md](loops/SEE_LOOP.md): reasons for and against, ranks, two flights, old maps, 3D), deciding finds ([DECIDE_LOOP.md](loops/DECIDE_LOOP.md)), a project's areas and chats ([HOME_LOOP.md](loops/HOME_LOOP.md)), registers for England, Norway and Denmark read in the checks and letters to records offices drafted ([FIND_LOOP.md](loops/FIND_LOOP.md) G2 and G5), an OpenAlex key field in Settings, and a signed, notarized release build. That build is not published yet; publishing it is Chris's decision.

## Later: a second field, open astronomy

The question was whether the same method could search open sky data. The full study, with a source for each claim and a list of what was not checked, is [research/open-astronomy.md](research/open-astronomy.md). In brief:

**The method carries over almost whole.** Cut open data into tiles, have a model look at each one, check every find against less-processed data and known artefacts, test it against what is published, keep a record, and leave the decision to a person.

| Dighouse today | In astronomy |
|---|---|
| A tile of bare ground | An image cutout around a target, or one star's light curve |
| A slice through the laser points | The survey's residual image, single exposures, each colour band alone |
| Roads and buildings on open maps | Satellite trails, ghosts, diffraction spikes, known asteroids |
| Site records and the literature | SIMBAD, NED, VizieR, VSX, TNS, then the literature |
| Locations stay on this Mac | Reversed: an object's coordinates are its identity, so a person submits and the tool only drafts |

**Where it is honest to look.** Survey teams already run trained classifiers over most of the sky, so the chance of adding something is small and sits in a few places. The two best fits are faint companions and tidal features around nearby galaxies in the Legacy Surveys images, and variable stars in ZTF checked against the VSX catalogue. Transients, lenses and moving objects are already crowded with pipelines and volunteers.

**How it would be built.** A second field inside the same app: a separate tool server of about 19 tools (built on astropy, astroquery and lightkurve), a skill file, a workspace view with a cutout grid and a light-curve plot in place of the map, and a tutorial on a known object. The records, the research record, the review, the second opinion and the report are field-neutral and stay as they are. The rules are set per field, because the privacy rule reverses.

**The first step needs no app change:** write the astronomy tool server and run one search in plain Codex, as Dighouse's archaeology tools already run outside the app. If the records hold up, add the field to the Toolbox.

**Open questions before any of it:** whether vision models read faint features in sky images at all, and how each service's terms and rate limits treat a tool that queries them.
