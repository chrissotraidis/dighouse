"""The search report: what a person reads when a search ends.

It is built from the project's own records, so it cannot say more than they do, and it holds no coordinates.
The only words that are not taken from the records are the agent's advice on what to try next.
"""

from __future__ import annotations

import datetime as dt
import re

from . import ledger, record
from .project import Project, commit

ADVICE = "**The agent adds:** "
PUBLISHERS = {"usgs": "USGS 3DEP", "ot": "OpenTopography", "uk": "the Environment Agency (England)", "nl": "AHN (Netherlands)",
              "fr": "IGN (France)", "own": "a file added by a person"}


def _s(n: int, word: str, plural: str = "") -> str:
    return f"{n} {word if n == 1 else (plural or word + 's')}"


def _first(text: str, limit: int) -> str:
    """The first sentence of a note, or as many whole words of it as fit, ending in a full stop or an ellipsis."""
    text = record._clean(text)
    cut = re.search(r"(?<=[a-z\)\d])[.;] ", text)
    if cut and cut.start() <= limit:
        text = text[: cut.start()]
    if len(text) > limit:
        return text[:limit].rsplit(" ", 1)[0].rstrip(",;:") + "…"
    return text.rstrip(".;") + "." if text else ""


def _short(text: str, limit: int) -> str:
    """A title cut to whole words."""
    text = record._clean(text)
    return text if len(text) <= limit else text[:limit].rsplit(" ", 1)[0].rstrip(",;:") + "…"


def _checks(m: dict, failed_maps: dict, maps: bool = True) -> str:
    """What the checks on a find showed, as one sentence. With maps off, the map check is left for a line of its own."""
    c, parts = m["checks"], []
    sec = c.get("section")
    if isinstance(sec, dict):
        parts.append(f"a section through the laser points measured {sec.get('feature_height_m', '?')} m, "
                     + ("in the ground" if sec.get("in_ground") else "not clearly in the ground"))
    else:
        parts.append("no section yet")
    second = c.get("second_look")
    if isinstance(second, dict):
        parts.append(f"a second model ({record._clean(second.get('model', ''), 40)}) "
                     + ("agreed it looks built" if second.get("agrees") else "did not agree it looks built"))
    else:
        parts.append("no second model has looked yet")
    modern = c.get("modern")
    if not maps:
        pass
    elif isinstance(modern, dict):
        parts.append("open maps show modern features close by" if modern.get("likely_modern") else "open maps show nothing modern on it")
    elif m["id"] in failed_maps:
        parts.append("open maps could not be checked, because the map service did not answer")
    else:
        parts.append("open maps not checked yet")
    text = "; ".join(parts) + "."
    return text[0].upper() + text[1:]


def write(p: Project, advice: str = "") -> dict:
    """Write today's search report in reports/ and link it from the research record."""
    advice = " ".join(advice.split())
    if record.COORD.search(advice):
        raise ValueError("The advice looks like it holds coordinates. Refer to places by candidate id instead.")
    f = p.path("reports", f"{dt.date.today().isoformat()}-search-report.md")
    if not advice and f.exists():
        # Rebuilt after more work the same day: keep what the agent advised.
        advice = next((l[len(ADVICE):] for l in f.read_text().splitlines() if l.startswith(ADVICE)), "")

    info = p.load("project", {}) or {}
    terrains, tiles = record.facts(p)
    records = ledger.everything(p)
    failed_maps = record._map_failures(p)
    name = info.get("name") or record._title(p) or p.root.name
    screened = [t for t in tiles.values() if t["status"] == "screened"]
    unreadable = sum(t["status"] == "unreadable" for t in tiles.values())
    counts = {v: sum(t.get("verdict") == v for t in screened) for v in record.VERDICT_WORDS}
    open_ = [m for m in records if m["status"] in ("flagged", "ground_confirmed")]

    L = [f"# Search report: {name}", "",
         f"{dt.datetime.now():%Y-%m-%d %H:%M}. Written by Dighouse from the project's records. Nothing here is called new, "
         "and locations are left out.", ""]

    L += ["## What was asked", "", record.question(p) or "No question was written down for this project.", ""]

    L += ["## The data used", ""]
    for t in sorted(terrains.values(), key=lambda t: t.get("dataset") or ""):
        dataset = t.get("dataset") or ""
        kind = dataset.split(":")[0]
        where = "a file a person added" if kind == "own" else f"open lidar from {t.get('source') or PUBLISHERS.get(kind, 'an open archive')}"
        L.append(f"- {dataset.split(':', 1)[-1]}, {where}: {(t.get('area_km2') or 0):.2f} sq km, "
                 + (f"{record.density(t)} laser points per square metre reached the ground."
                    if isinstance(t.get("ground_points_per_m2"), (int, float)) else "a ground model that was already built."))
    if not terrains:
        L.append("None yet: no terrain was fetched.")
    L.append("")

    L += ["## What was looked at", ""]
    if tiles:
        parts = [f"{counts[v]} {w}" for v, w in record.VERDICT_WORDS.items() if counts[v]]
        L.append(f"The ground was cut into {_s(len(tiles), 'tile')}, each a square of ground. {len(screened)} of {len(tiles)} "
                 f"{'was' if len(screened) == 1 else 'were'} looked at, each in two views"
                 + (f": {', '.join(parts)}." if parts else ".")
                 + (f" {_s(unreadable, 'tile')} could not be read, because the laser did not reach the ground there." if unreadable else ""))
        left = sum(t["status"] == "unscreened" for t in tiles.values())
        if left:
            L.append(f"{_s(left, 'tile')} {'has' if left == 1 else 'have'} not been looked at yet.")
    else:
        L.append("Nothing yet.")
    L.append("")

    L += ["## What was flagged, and why", ""]
    # When the map service was down for every find, that is said once, under the finds.
    no_maps = bool(records) and all("modern" not in m["checks"] and m["id"] in failed_maps for m in records)
    for m in records:
        why = _first(m["evidence"][0], 150) if m.get("evidence") else "No note was left."
        L += [f"- **[{m['id']} {_short(m['name'], 60)}](../candidates/{m['id']}.md).** {why} {_checks(m, failed_maps, not no_maps)}"]
    if not records:
        L += ["Nothing was flagged as looking built."]
    if no_maps:
        L += ["", "Open maps could not be checked for modern features near "
              + ("it" if len(records) == 1 else "any of them") + ": the map service did not answer."]
    L.append("")

    L += ["## What is already published", ""]
    sources: dict[str, dict] = {}
    for m in records:
        for s in m["sources"]:
            entry = sources.setdefault(s["title"], {**s, "for": []})
            entry["for"].append(m["id"])
            if s["status"] == "read":
                entry.update(status="read", finding=s["finding"], link=s.get("link") or entry.get("link", ""))
    read = [s for s in sources.values() if s["status"] == "read"]
    for s in read[:3]:
        link = f" ([link]({s['link']}))" if s.get("link") else ""
        L.append(f"- **{_short(s['title'], 90)}**{link}. {_first(s.get('finding', ''), 170)}")
    if len(read) > 3:
        L.append(f"- And {len(read) - 3} more that were read, listed in the research record.")
    unopened = sum(s["status"] == "could_not_open" for s in sources.values())
    if not read:
        L.append("No source has been read yet, so nothing can be said about what is published." if records
                 else "Nothing was flagged, so no source was read against a find.")
    if unopened:
        L.append(f"- {_s(unopened, 'source')} could not be opened by the agent. You can open {'it' if unopened == 1 else 'them'} "
                 "in the Sources tab and hand the page over.")
    L.append("")

    L += ["## What was ruled out", ""]
    ruled = []
    for v, words in (("natural", "natural ground"), ("modern", "modern features"), ("nothing", "nothing built")):
        if counts[v]:
            ruled.append(f"- {_s(counts[v], 'tile')} showed {words}.")
    for m in records:
        last = m["decisions"][-1] if m.get("decisions") else None
        if last and last["status"] in ("modern", "natural"):
            ruled.append(f"- {m['id']} was decided to be a {last['status']} feature by {last['by']}: {_first(last.get('reason', ''), 150)}")
    L += ruled or ["Nothing was ruled out."]
    L.append("")

    L += ["## What needs your decision", ""]
    for m in open_:
        sug = m.get("suggestion")
        if sug:
            L.append(f"- **{m['id']}.** The agent suggests: {ledger.LABELS.get(sug['status'], sug['status']).lower()}. "
                     f"{_first(sug.get('reason', ''), 190)}")
        else:
            L.append(f"- **{m['id']}.** No suggestion yet.")
    decided = [m for m in records if m.get("decisions")]
    if open_:
        L.append("")
        L.append("You decide each one, in the review. The agent only suggests.")
    elif decided:
        L.append(f"Nothing. {_s(len(decided), 'find')} {'has' if len(decided) == 1 else 'have'} been decided: "
                 + "; ".join(f"{m['id']}, {ledger.LABELS.get(m['decisions'][-1]['status'], '').lower()}, by {m['decisions'][-1]['by']}" for m in decided) + ".")
    else:
        L.append("Nothing is waiting for a decision.")
    L.append("")

    L += ["## What to try next", ""]
    # The decisions have their own heading above, and the record's "listed below" does not hold here.
    L += [f"- {t}" for t in record.still_to_do(p) if not t.startswith(("Decide ", "Try the "))][:3]
    if advice:
        L += ["", ADVICE + record._clean(advice, 320)]
    L += ["", "The full record of this project is in [RESEARCH.md](../RESEARCH.md).", ""]

    text = "\n".join(L)
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text)
    p.note(f"Wrote the search report {f.name}")
    record.document(p, commit_it=False)
    commit(p.root, f"Search report {dt.date.today().isoformat()}")
    # Words a person reads: link addresses do not count.
    words = len(re.findall(r"[\w'’-]+", re.sub(r"\]\([^)]*\)", "]", text)))
    return {"written": f"reports/{f.name}", "words": words, "waiting_for_a_person": [m["id"] for m in open_]}

