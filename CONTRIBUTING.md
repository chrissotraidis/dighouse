# Contributing to Dighouse

Thank you for helping. Dighouse is a macOS app (SwiftUI, in `app/`) and a set of archaeology tools (Python, in `src/dighouse`) that any agent harness speaking the Model Context Protocol can use.

## Ground rules

- **Never post the coordinates of a site or a find,** in an issue, a pull request, a commit, a screenshot or a test. Describe places by region.
- **Keep the project's rules intact:** nothing is called new, a person decides, and a tile with too little ground data is unreadable, not empty. See "Rules the tools enforce" in the [README](README.md).
- **Only people are credited.** You may use AI tools. You are the author of what you submit, and you must be able to explain every line. Do not list an AI as an author or co-author, and do not add "Generated with" lines. A check enforces this. The full policy is in [AGENTS.md](AGENTS.md).

## Set up

~~~sh
git clone https://github.com/chrissotraidis/dighouse.git
cd dighouse
./scripts/setup.sh        # checks Xcode, uv, Codex and your sign-in, then builds the app
~~~

[docs/SETUP.md](docs/SETUP.md) covers the first launch. For the tools alone, `uv sync` is enough.

## Where things are

| Path | What |
|---|---|
| `src/dighouse/` | The tools. `sources.py` and `national.py` fetch lidar, `terrain.py` builds the ground, `tiles.py` and `section.py` cut tiles and slices, `checks.py` reads maps and literature, `ledger.py` keeps records, `server.py` is the tool server. |
| `skills/dighouse/SKILL.md` | The agent's instructions. |
| `app/Sources/Dighouse/` | The app. `Controls.swift` and `Theme` (in `Core.swift`) hold the shared controls and colours. |
| `tests/` | Offline tests on a synthetic survey, and live tests against the real services. |
| `scripts/` | Setup, the smoke test, and the benchmark scripts. |
| `docs/` | Setup, design, the roadmap, the handoff, and a log for every loop of work. |

## Checks

~~~sh
uv run pytest -q                       # offline, needed for every change
uv run pytest -m live                  # when you touch fetching
uv run python scripts/smoke_test.py    # one tile end to end
cd app && swift build && swift test    # when you touch the app
~~~

If you change a prompt, the skill, the feature guide or how finds are made, rerun the smoke test and the blind tests ("Test it on a known site" in the app) and give the scores in your pull request.

## A good first contribution: a new ground model

Each national or regional ground model is one entry in `NATIONAL` in `src/dighouse/national.py`, with a `kind` saying how it is served (an image service, WCS, or files on a grid of map sheets). Copy the closest existing entry, add a live test in `tests/test_live.py` on a known site it covers, add a row to the README's Open data table, and say in the pull request what the licence allows.

## Pull requests

- One change per pull request, with a title that says what changes for a person.
- Describe what you checked and what you did not.
- Follow [docs/DESIGN.md](docs/DESIGN.md) for anything a person sees, and include a screenshot at 1440 × 900 (with no locations in it).
- Update the README and the docs when the change is visible.

Security problems and leaked locations go through [SECURITY.md](SECURITY.md), never a public issue.
