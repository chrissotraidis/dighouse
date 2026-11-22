# Roadmap

Where Dighouse goes next, in rough order. Nothing here is promised by a date. What already works is in the [README](../README.md); what was checked, and how, is in the run logs ([REFINE_LOOP.md](REFINE_LOOP.md) is the newest).

## Next, for archaeology

- **Finding small mounds.** Borre 29 of 53 and Andía 4 of 11 on 2026-11-22. A mound-only look at quarter tiles did not help, and finer ground models do not show more mounds. Of Borre's misses, most are not in the 1 m ground model at all, so the next lever is the raw points: a ground model built from them with a lower ground-filter threshold, or a slice and shape check that reads the points directly. Borre's lidar points (2016 and 2021, 5 points per m²) come from hoydedata.no's export, which e-mails the files; ordering it is the first step.
- **More answer keys.** Six sites today, five of them partial. Official registers like Norway's give complete keys; England's and the Netherlands' would add more.
- **A download.** A signed, notarized build, so nobody has to compile the app to try it.
- **An OpenAlex key in Settings.** Without a key, one network address shares about 100 literature searches a day; a free key lifts that to about 1,000. Dighouse falls back to Crossref today.
- **Looking at tiles in bulk.** Sending batches of tiles straight to a cheaper vision model through the router, for areas too large for one chat.
- **A browser of the agent's own,** for sources that refuse a program and today have to be opened by a person in the Sources tab.
- **Slices with treetops for ground-only data.** Some surveys publish only the ground returns, so a slice can measure a shape but cannot show the trees above it.
- **Archaeoastronomy.** Two small tools: `horizon_profile` (the height of the horizon in every direction from a point on the ground model) and `alignment_check` (the bearing of a feature's axis, turned into a declination and compared with solstice, equinox and lunar standstill lines). People already do this by hand from lidar. It needs a coarser wide model for the far horizon, and a horizon profile can identify a place, so it is stored under `private/` like any location.

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
