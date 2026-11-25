# Could Dighouse search the sky? Open astronomy with the same method

Research for Chris Sotraidis, 14 November 2026, for goal R6 of [REFINE_LOOP.md](../loops/REFINE_LOOP.md). No code was written.

A service marked "probed" was called that day with one small, read-only request and no account or key. Afterwards three things were fetched a second time, independently: the OpenAlex notice, the CDS incident notice, and five of the arXiv records cited. All matched. Dighouse's words are used throughout: a shape the agent marked is a find, a cut through the laser points is a slice, and another model gives a second opinion. "Candidate" is kept where it is astronomy's own term.

## Short answer

Yes. The method carries over almost whole: cut open data into tiles, have a model look at each one, check every find, test it against what is published, keep a record, and leave the decision to a person. People already do each part of this in astronomy, mostly as separate projects. The honest limit: survey teams already run trained classifiers over most of the sky, so the chance of adding something is small and sits in a few niches.

## 1. Is it the same shape of problem?

| Dighouse stage | Astronomy counterpart |
|---|---|
| Choose where to look | Choose a survey and a target list, and compare it with what the catalogs already hold |
| Build the bare ground | Fetch calibrated images or light curves. The survey has done the processing |
| Tile | An image cutout around a target, or one object's light curve |
| Unreadable tile | A cutout off the survey's footprint, masked, or swamped by a bright star; a light curve with too few points |
| Mark a find | A candidate at a sky position |
| Slice through the raw points | A step back toward less-processed data: single exposures, each colour band alone, the survey's model residual, the pixels behind a light curve |
| Modern-feature check | Artefact check: satellite trails, ghosts, diffraction spikes, cosmic rays, a known asteroid at that place and time |
| Mapped sites and literature | SIMBAD, NED, VizieR, TNS, MPC, VSX, ExoFOP, then the literature |
| Controls (known sites found again) | Known objects of the same kind mixed into the tiles |
| Second opinion, records, report, human decision | The same |
| Draft for the heritage authority | Draft for TNS, MPC, VSX, ExoFOP or a researcher |

Where the analogy breaks:

- **Privacy flips.** An object's coordinates are its identity and every report carries them. "Locations stay private" has no counterpart.
- **The sky changes.** A transient fades in days and surveys report within hours.
- **The data is already screened.** Most open lidar was never searched for archaeology; most open sky data has been searched by its own survey team.
- **Nobody can look at every tile.** The Legacy Surveys cover [more than 20,000 square degrees](https://www.legacysurvey.org/dr10/description/). At 256 pixels (67 arcseconds) a cutout, that is about 58 million tiles (my arithmetic). A search starts from a target list, not an area.
- **Confirmation needs a telescope.** A lens, a brown dwarf or a supernova is confirmed with a spectrum.
- **Registries assign the name.** That is stricter than archaeology, and it helps: "already published" is mostly a database query.

## 2. What people already do

Citizen science on [Zooniverse](https://www.zooniverse.org/) is the closest relative. Dates and counts below come from its API (probed).

| Project | What volunteers look at | Launched | State |
|---|---|---|---|
| [Galaxy Zoo](https://www.zooniverse.org/projects/zookeeper/galaxy-zoo) | Galaxy shapes; about 153,000 volunteers on the current project | Mar 2018 | Live |
| [Backyard Worlds: Planet 9](https://www.zooniverse.org/projects/marckuchner/backyard-worlds-planet-9) | Moving objects in WISE images; about 92,000 volunteers; [first brown dwarf paper, 2017](https://arxiv.org/abs/1705.02919) | Feb 2017 | Paused |
| [Planet Hunters TESS](https://www.zooniverse.org/projects/nora-dot-eisner/planet-hunters-tess) | Dips in TESS light curves ([results paper, 2020](https://arxiv.org/abs/2011.13944)) | Dec 2018 | Live |
| [Kilonova Seekers](https://www.zooniverse.org/projects/tkillestein/kilonova-seekers) | Transient candidates from the GOTO telescopes; [600,000 classifications from about 2,000 people in one observing run](https://arxiv.org/abs/2406.02334) | Jul 2023 | Live |
| Radio Galaxy Zoo and [Radio Galaxy Zoo: EMU](https://www.zooniverse.org/projects/hongming-tang/radio-galaxy-zoo-emu) | Matching radio sources to host galaxies ([2015 paper](https://arxiv.org/abs/1507.07272)) | Dec 2013; Jul 2024 | Finished; paused |
| [Space Warps: ESA Euclid](https://www.zooniverse.org/projects/aprajita/space-warps-esa-euclid) | Gravitational lenses | Nov 2024 | Live |
| [Four Rubin projects](https://www.zooniverse.org/rubin) | Comet Catchers, Difference Detectives, Alert Explorers, Blobs and Blurs | Jun 2025 to Sep 2026 | Mixed |

**Alert brokers.** Rubin alerts have streamed to brokers since [24 February 2026](https://rubinobservatory.org/for-scientists/data-products/recent-data-releases) and are world public. [Seven brokers take the full stream](https://rubinobservatory.org/for-scientists/data-products/alerts-and-brokers): ALeRCE, AMPEL, ANTARES, Babamul, Fink, Lasair and Pitt-Google. They filter, cross-match and classify with machine learning; ALeRCE also reports early supernova candidates to TNS.

**Amateurs.** Koichi Itagaki is the reporter of [SN 2023ixf in M101](https://www.wis-tns.org/object/2023ixf). [IASC](http://iasc.cosmosearch.org/) runs month-long asteroid search campaigns for volunteers. A dwarf galaxy, Donatiello I, was found [in a deep image from an amateur telescope](https://arxiv.org/abs/1810.04741), and three faint dwarfs near NGC 253 came from [visual inspection of public Dark Energy Survey images](https://arxiv.org/abs/2106.08868). In 2025 a high-school student, Matteo Paz, published [1.5 million candidate variable objects](https://www.caltech.edu/about/news/exploring-space-with-ai) from NEOWISE data ([paper](https://arxiv.org/abs/2409.15499)).

**Where machines have taken over.** Routine galaxy shapes ([volunteers' labels trained a model that classified 8.7 million galaxies](https://arxiv.org/abs/2309.11425)) and the daily scanning for bright ZTF transients ([BTSbot](https://arxiv.org/abs/2401.15167)). Lens searches run [deep learning first, then volunteers](https://arxiv.org/abs/2503.15324): 497 candidates in Euclid's first 63 square degrees.

**Where people still add something.** Faint, diffuse or odd things the classifiers were not trained on; variable-star records; follow-up observing; training labels.

**AI agents.** [mephisto](https://arxiv.org/abs/2409.14807) (Sep 2024) interprets galaxy observations, [StarWhisper Telescope](https://arxiv.org/abs/2412.06412) (Dec 2024) automates observing, and [Denario](https://arxiv.org/abs/2510.26887) (Oct 2025) is a multi-agent system for research. Gemini, given 15 examples, [sorted real from bogus transients at about 93% and explained each call](https://arxiv.org/abs/2510.06931) (Oct 2025). Nearest to Dighouse, an August 2026 paper has [agents vet anomalies among 370,000 ASAS-SN variable stars](https://arxiv.org/abs/2608.23688). There is pushback: ["Agentic research is oxymoronic"](https://arxiv.org/abs/2608.31161) (Aug 2026) says it will breed distrust. A written record and a human decision are Dighouse's answer.

## 3. Open data a tool could read

| Need | Service | Account or key | Probe result |
|---|---|---|---|
| Image cutouts | [Legacy Surveys viewer](https://www.legacysurvey.org/viewer) ([DR11](https://www.legacysurvey.org/dr11/description/) is the latest) | None | JPEG and FITS returned; a third parallel request got HTTP 429 |
| | [Pan-STARRS](https://outerspace.stsci.edu/display/PANSTARRS/PS1+Image+Cutout+Service), [SDSS](https://skyserver.sdss.org/dr18), [unWISE](https://unwise.me/) | None | Each returned an image |
| | hips2fits at [CDS](https://cds.unistra.fr/) | None | Down. CDS reports a cybersecurity incident affecting SIMBAD, VizieR, Aladin images and X-Match |
| Catalogs | [Gaia archive](https://gea.esac.esa.int/archive/), [NED](https://ned.ipac.caltech.edu/), [NOIRLab Data Lab](https://datalab.noirlab.edu/), IRSA | None | Each answered an anonymous query |
| | SIMBAD, VizieR | None | Strasbourg down; the [Harvard SIMBAD mirror](https://simbad.cfa.harvard.edu/simbad/) answered (data to 14 Oct 2026); VizieR mirrors returned no rows |
| | [AAVSO VSX](https://vsx.aavso.org/) | None to read; account to submit | Returned a known variable |
| Time series | [ZTF at IRSA](https://irsa.ipac.caltech.edu/docs/program_interface/ztf_lightcurve_api.html) ([DR24](https://www.ztf.caltech.edu/ztf-public-releases.html), to Oct 2025) | None | Light curve returned |
| | [TESS at MAST](https://mast.stsci.edu/tesscut/), [ExoFOP](https://exofop.ipac.caltech.edu/tess/) | None to read | Sector lookup, star catalog and a light curve file returned |
| Alerts | [ALeRCE](https://science.alerce.online/), [ANTARES](https://antares.noirlab.edu/), [Fink](https://fink-broker.org/); [Lasair](https://lasair.lsst.ac.uk/) | None; Lasair needs a token | Three answered; Lasair refused (401) |
| Transients | [TNS](https://www.wis-tns.org/content/tns-getting-started) | Pages open in a browser; the API needs a bot key; reporting needs an account, open to amateurs | API refused (403) |
| Minor planets | [MPC API](https://data.minorplanetcenter.net/), [SkyBoT](https://ssp.imcce.fr/webservices/skybot/), [JPL Horizons](https://ssd-api.jpl.nasa.gov/doc/horizons.html) | None to read; [an observatory code to report](https://www.minorplanetcenter.net/iau/info/Astrometry.html) | Each answered |
| Literature | [arXiv](https://info.arxiv.org/help/api/index.html); [ADS](https://ui.adsabs.harvard.edu/help/api/) | None; ADS needs a token | arXiv answered; ADS refused (401) |
| | [OpenAlex](https://help.openalex.org/) | Works without, on a shared budget | Answered with a notice: keyless requests share $0.10 a day per network address; a free key gives $1 a day |

The OpenAlex notice matters for Dighouse today, since its literature search runs there without a key. A search costs $0.001, so a network address gets about 100 a day. Since this loop the tools ask Crossref when OpenAlex turns a request away. The notice also tells AI agents they can request a key by posting the user's email address. Dighouse does not do that; a key is Chris's to ask for.

**Rubin.** Alerts are public through the brokers. Images and catalogs are not: [Data Preview 1](https://dp1.lsst.io/) (June 2025) and [Data Preview 2](https://dp2.lsst.io/) (early release July 2026, full release expected December 2026) are open only to scientists and students in the US and Chile and named partners. Its platform refused my anonymous query (401). Rubin's [page for amateurs](https://rubinobservatory.org/for-scientists/resources/amateurs) points to alerts, Zooniverse, and yearly releases after a two-year wait.

**Euclid.** Public. Q1 came in March 2025 and [DR1 "Foundation"](https://euclid.caltech.edu/page/euclid-dr1), about 1,900 square degrees, on 12 November 2026. The [ESA archive](https://www.cosmos.esa.int/web/euclid/dr1-data) and [IRSA](https://irsa.ipac.caltech.edu/data/Euclid/docs/overview_dr1.html) serve it (about 1.8 PB). ESA's Q1 archive answered an anonymous query.

**Gaia.** DR3 is open now; [DR4 is due on 2 December 2026](https://www.cosmos.esa.int/web/gaia/release).

## 4. Searches a person with agents could run

Ranked by fit to Dighouse's method, then by the honest chance of adding something. Every find also gets a second model's opinion.

| # | Search and data | Tile and find | Checks | "Already published" test | Where it is reported | Chance; what a beginner learns |
|---|---|---|---|---|---|---|
| 1 | Faint companions and tidal features around nearby galaxies, Legacy Surveys | A cutout around each listed galaxy; a diffuse patch, stream or shell | Same patch in Pan-STARRS or SDSS; residual image; bright-star ghosts, Galactic dust | SIMBAD and NED around the spot; [SMUDGes](https://arxiv.org/abs/2205.02193); the [Stellar Stream Legacy Survey](https://arxiv.org/abs/2104.06071); a [2024 tidal-feature set](https://arxiv.org/abs/2404.06487) | No registry; a short paper with a researcher, as in section 2 | Modest. Reading deep images |
| 2 | Variable stars in ZTF, against VSX | One star's light curve, raw and folded; a repeating change | Bad-data flags; a blended neighbour in Gaia; a period near one day (an alias) | VSX around the spot; the [ZTF periodic-variable catalog](https://arxiv.org/abs/2005.08662); Gaia; SIMBAD | VSX, with an account | Best odds of an accepted record; small science value. Periods, folding |
| 3 | Slow-moving objects in WISE | A blink of unWISE epochs; a source that shifts | Motion in IRSA's CatWISE table; spikes and ghosts; Gaia match | SIMBAD; CatWISE; Backyard Worlds papers | The [Backyard Worlds](https://www.backyardworlds.org/) team; a spectrum confirms | Low to modest: 92,000 people have looked. Proper motion |
| 4 | Transit candidates in TESS | One star in one sector; repeated dips | Odd and even dips equal; no second eclipse; no shift in the pixels | [ExoFOP lists of TESS and community candidates](https://exofop.ipac.caltech.edu/tess/view_ctoi.php); SIMBAD | ExoFOP, with an account | Low. Why most dips are eclipsing binaries |
| 5 | Strong lens candidates, Legacy Surveys or Euclid | A cutout around a massive galaxy; an arc or ring | Arc colour differs from the galaxy; residual image | [Legacy Survey lens lists](https://arxiv.org/abs/2005.04730); the [Euclid Q1 catalogue](https://arxiv.org/abs/2503.15324); SIMBAD, NED | Space Warps or a researcher; a spectrum confirms | Low: deep learning and volunteers already sweep. Lens geometry |

Vetting live transients from a broker is the weakest fit. The checks map well (known asteroid, known variable star, host galaxy), but speed decides, brokers report automatically, and confirmation needs a spectrum. Past alerts would make a good tutorial.

## 5. What carries over and what would have to be built

**Unchanged:** the Codex engine, chat, the project folder, the Markdown records, the research record, the search report, the review, the second opinion, source logging, the tutorial and Toolbox frames, and the rule machinery. In the Python tools, the field-neutral files (project, record, report, ledger, sources) are about 1,300 of 3,100 lines.

**Rules, translated:** a find is recorded as "no match in the catalogs checked, on this date" and nothing more. "Unreadable" means off the footprint, masked, or too few points. "Locations stay private" becomes "a person submits; the tool only drafts".

**Astronomy tools to build:**

| Stage | Tools |
|---|---|
| Choose | `resolve_object`, `survey_coverage`, `make_targets` |
| Fetch and look | `fetch_cutout`, `fetch_epochs`, `fetch_light_curve`, `fold_light_curve` |
| Check | `view_residual` (the "slice"), `check_artefacts`, `check_moving_object` |
| Already published | `query_simbad`, `query_ned`, `query_vizier` (with VSX), `query_gaia`, `query_tns` (the user's key), `query_brokers`, `search_arxiv` |
| Records | `export_finds` (with coordinates), `draft_submission` |

That is 19 tools. With [astropy](https://docs.astropy.org/), [astroquery](https://github.com/astropy/astroquery) and [lightkurve](https://github.com/lightkurve/lightkurve) doing the heavy work, I estimate 1,500 to 2,000 lines of Python, a little more than Dighouse's own data half. Searches 1 and 2 need about ten of them. The app needs one workspace view (a cutout grid and a light-curve plot in place of the map), Toolbox text and a tutorial on a known object.

## 6. Two ways to build it

**Recommendation: a second field inside one app, built as a separate tool server on a shared record core.** The field-neutral half exists and is wired into about 10,700 lines of Swift; a sibling app would mean one maintainer keeping two copies in step. A field is then four things: a tool server, a skill file, a workspace view and a tutorial. Rules must be set per field, because the privacy rule reverses, and the README's promises need scoping to archaeology.

The cheapest first step needs no app change: write the astronomy tool server and run search 1 or 2 in plain Codex, as Dighouse's tools already run outside the app. If the records hold up, add the Toolbox field.

## 7. Risks and limits

- **False discoveries.** Most finds will be artefacts or known objects. "Not in SIMBAD" does not mean unknown: catalogs lag, and today's mirror stops at 14 October.
- **Crowded fields.** Transients, moving objects and lenses already have pipelines, brokers and many thousands of volunteers.
- **Rate limits and outages.** The Legacy viewer refused a third parallel request, TNS went quiet for a minute after a burst of page loads, OpenAlex meters keyless use, and CDS is down. The tool needs mirrors, slow pacing, and a "could not check" status, which is Dighouse's "could not open" again.
- **Data volume.** Target lists only; no bulk downloads.
- **Naming.** The registry assigns the designation: TNS for transients, the MPC for minor planets (names go through the [IAU working group](https://www.wgsbn-iau.org/)). The tool should use a coordinate label and never a name.
- **Model eyesight.** Faint features depend on how the image is stretched; whether vision models judge them well is untested here.

## 8. Archaeoastronomy

I read "astroarchaeology" as archaeoastronomy: how ancient sites line up with the sky. ("Galactic archaeology" is something else, [reading the Milky Way's history from its stars](https://arxiv.org/abs/1806.06038).)

There is a real, small tool here. It is archaeology with a little astronomy and uses no sky-survey data. Two tools would do it:

- `horizon_profile`: from a point on the ground model, the height of the horizon in every direction.
- `alignment_check`: the bearing of a feature's axis, turned into a declination and compared with solstice, equinox and lunar standstill lines for the period.

People do this already. A 2023 study [measured the orientations of many Mesoamerican ceremonial complexes from lidar](https://doi.org/10.1126/sciadv.abq7675) and tied them to the 260-day calendar. Stellarium ships an [ArchaeoLines plug-in](https://stellarium.org/doc/head/group__archaeoLines.html) that draws those lines, [skyscapeR](https://github.com/f-silva-archaeo/skyscapeR) is an R package for the analysis, and [HeyWhatsThat](https://www.heywhatsthat.com/) computes horizon panoramas.

Limits: the far horizon often lies beyond one lidar survey, so a coarser wide model is needed; trees change what was visible; one aligned axis proves little, since there are many axes and many sky targets; and a horizon profile can identify a place, so it belongs under private/. A few hundred lines.

## What was not checked

- The web search tool returned no readable results in this session. Every claim rests on a primary page, API or arXiv abstract fetched directly. News and forums were not surveyed, so smaller projects may be missing. I did not find a desktop tool that joins all of Dighouse's stages for astronomy, but that is an absence in a limited search.
- CDS services (SIMBAD, VizieR, hips2fits, X-Match) could not be tested at their home. hips2fits is unconfirmed.
- Nothing behind a key was tested: Lasair, the TNS API, ADS, the Rubin platform.
- For Euclid DR1 I confirmed the release pages, not an image download. The brokers were queried for ZTF only, not Rubin.
- None of the five searches was run. Whether vision models can read faint features in cutouts, or judge light curves, is the main open question.
- The share of supernovae and asteroids still found by amateurs was not measured.
- Each service's terms of use were not read.
- The IAU's general naming page returned 404; the naming rules rest on the TNS and MPC pages.
- The history of the word "astroarchaeology" was not looked up.
- The size estimates are judgment from line counts in the repository, which I read and did not change.
