# Dighouse goal loop: second opinions that work, and finding more

Written 2026-11-21 as a proposal. Not started: Chris reviews it first.

Read [RELEASE_LOOP.md](RELEASE_LOOP.md) and [2026-11-21-five-hour-run.md](2026-11-21-five-hour-run.md) first. The app now holds up for a stranger. The run showed where the work is now: no find has ever had a second opinion, the agent leaves most small mounds on tiles it calls "possible", and its 17 open leads are mostly hollows and cuts that old maps could explain.

## What was checked before writing this (2026-11-21)

- OCX 2.100.4 no longer lists `google-antigravity`, but Dighouse still has `google-antigravity/gemini-3.8-flash` saved as the second model, and OCX still lists one Google model through another route (`command-code/google-gemini-3.8-flash`). The Toolbox's worked example still names "Gemini 3.8 Flash".
- Asked live with a Borre tile, through OCX, in one short request each:

| Model | Answered | Read the hillshade correctly |
|---|---|---|
| anthropic/claude-sonnet-5-5 | Yes | Yes ("burial barrows or tumuli"); in sky view it said "bomb craters" |
| opencode-go-secondary/glm-5.3 | Yes | Yes |
| opencode-go/kimi-k3 | Yes | Yes |
| xai/grok-4.7 | No: "Grok Build usage balance exhausted" | — |
| kimi/k3 | No: OAuth sign-in failed | — |

- The second opinion is sent the tile in composite and local relief, not sky view, which suits all three that worked.

## Goals

Each is done when its check passes in the running app or in a logged benchmark run. Work them in order.

| Goal | What | Check |
|---|---|---|
| S1 | **Remove Google models.** Hide any model whose id or provider mentions google, gemini or antigravity from every model list (chat, Settings, set-up, second opinion), wherever OCX lists it. If a saved model (main or second) is one of them, or is no longer listed, replace it with a working default and say so once. Rewrite the Toolbox example and HANDOFF notes that name Gemini. | No Google model appears anywhere in the app; a settings file holding the old Antigravity id opens with a working second model and a one-line note. |
| S2 | **A second opinion that works.** Default to Claude Sonnet 5.5, a different maker from the GPT models that do the search. If the provider refuses or is out of credit, try GLM-5.3 and then Kimi K3 (opencode-go) by itself, and record which model answered. Settings shows each second-opinion model with a "Check" that sends one tile and shows the reply. | A refused model falls through to the next on its own. "Check" works for all three. Each record names the model that gave its opinion. |
| S3 | **Is the second opinion any good?** A blind check of the reviewer itself: give it the finds from the Borre, Mound City and Maiden Castle tests (true mounds, misses, and false finds, which the scorecard already knows) and score how often it agrees with the truth. Do the same for Sonnet and GLM. | A table in the Log: agreement on real features and on false finds for each model. The default stays only if it beats a coin toss clearly on both; otherwise the second opinion is labelled advisory in the app. |
| S4 | **Second opinions on the work already done.** Run them on the 42 ground-search finds and the open Cahokia finds. | Every open find has an opinion or a recorded reason it could not get one. The Log says where the reviewer disagreed with the agent's suggestion. |
| S5 | **Mark the mounds the agent leaves on "possible" tiles.** On every tile called possible or built, list the top measured rises ranked by `shape_check` (not height) as finds for review, capped per sq km, marked "measured, not seen" so a person knows where they came from. They go through slice, maps and suggestion like any find. | Borre twice, Mound City, Maiden Castle and one Thunder Bay wreck test rerun. Kept only if recall rises and false finds per sq km stay under the cap Chris sets (see below). On last week's numbers Borre should go from 21 toward 33 of 53, with about 26 more rises to look at. |
| S6 | **Clear the hollows with old maps.** For finds that are hollows, cuts or straight traces, check open historical and mining records before suggesting: USGS historical topographic maps (ponds, quarries, buildings, roads at the time), the USGS mineral resources record (mines and prospects), and open water features on OpenStreetMap. Cite what was found on the record. | Run on the 17 leads. The Log says how many were explained by a cited map or record, and how many are still leads. Nothing is filtered silently: an explained find keeps its record with the reason. |
| S7 | **A session that searches without a coordinator.** Run a 2-hour timed session with no steering. | It searches at least 3 sq km (the second session reached 9.4 km² in about 3 hours once steered), its finds all carry second opinions, and an early close is turned back once. Any further step-ins are logged with the reason. |
| S8 | **Hand over.** Records show finds grouped as before, now with second opinions and map checks. README, HANDOFF and the Toolbox example match the app. | Merged, `main` clean, the app rebuilt and launched with Chris's settings unchanged apart from the replaced second model. |

## Decisions for Chris before starting

1. **Default second opinion:** Claude Sonnet 5.5 (most reliable, Anthropic usage), or GLM-5.3 (opencode-go, cheaper) with Sonnet as the fallback?
2. **Cap on extra rises in S5:** how many more small rises per sq km will you look over? 50 per km² adds about 14 at Borre and finds about 26 of 53; 100 per km² adds about 26 and finds about 33.
3. **Usage:** the primary account showed 20% left at the end of the run. S3, S4, S5 and S7 all spend it. Run them now, or wait for the reset?
4. **Merging:** one pull request per goal, merged when its check passes, as in the last loop?

## Ground rules

As in RELEASE_LOOP: few words, a person decides, nothing is called new, locations stay under `private/`, tests that talk to a model use primary / 6.1 Terra, and the benchmark guards the method (a change to finding ships only if the blind tests are no worse).



## Log

### 2026-11-21, decisions taken

Chris said to begin without answering the four questions, so the recommended choices were taken: Claude Sonnet 5.5 first, then GLM-5.3, then Kimi K3; at most 50 extra measured rises per sq km in S5; run now on the remaining usage; one pull request per goal, merged when its check passes.

### 2026-11-21, S1 and S2: no Google models, a second opinion that falls through

Any model whose id contains google, gemini or antigravity is dropped as the model list loads, so it appears nowhere (Settings showed 91 models, down from 94). After the list loads, a saved agent or second model that is no longer offered is replaced: on Chris's settings `google-antigravity/gemini-3.8-flash` became Claude Sonnet 5.5, with a one-line notice in Settings until he picks a model. The Toolbox example and HANDOFF no longer name Gemini.

Settings, Models now lists the second-opinion models in the order they are asked, each with Check, which sends a Borre picture in a throwaway chat. All three answered correctly in the app: Sonnet ("round burial mounds, some with ditches"), GLM-5.3 ("a cluster of prehistoric round burial mounds") and Kimi K3 ("the royal Viking Age barrows of Borre"). When a second-opinion model fails or answers without an opinion, it is set aside for this run and the next model is asked about the same find. Checked by choosing xAI Grok 4.7 (out of credit) and asking on Cahokia C-009: Grok was refused, Sonnet answered, and the record says "Cl · Sonnet 5.5: … looks built by people, though the surrounding road-and-parcel grid means a modern structure should be ruled out." Sonnet was put back as the second model.



### 2026-11-21, S3: are the second opinions any good?

`scripts/rate_reviewers.py` takes ground whose truth the blind tests know (Mound City, Borre, Angel Mounds, Cahokia): published features from the answer keys, measured rises the keys do not list, and plain ground away from both. It renders a 120 m crop in composite and local relief (the views the app sends) and asks each model through the router whether the thing at the centre was built. 102 crops:

| Model | Answered | Published features called built | Look-alike rises called not built | Plain ground called not built | When it says built, right | When it says not built, right |
|---|---|---|---|---|---|---|
| Claude Sonnet 5.5 | 102/102 | 19/24 | 24/38 | 26/40 | 40% | **91%** |
| GLM-5.3 | 102/102 | 6/24 | 34/38 | 37/40 | 46% | 80% |
| Kimi K3 | 88/102 (14 timed out) | 15/24 | 22/35 | 23/29 | 44% | 83% |

Sonnet stays the default: it finds most real features and is the most trustworthy when it says no. GLM almost never says yes, so it misses three real features in four. No model's "yes" is worth much: all three call plenty of plain and modern ground built (at Mound City and Cahokia the "plain" crops include roads and houses, which are built, just not ancient, so the true rate is a little better than this). The app now says so on each record: a disagreeing second opinion "counts", an agreeing one is "a weak check". The second opinion is useful as a filter, not as a confirmation.

