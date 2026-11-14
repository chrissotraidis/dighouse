"""The project's research record, RESEARCH.md.

It is rebuilt from the project's own files (records, tile verdicts, notes and logs) whenever a run ends,
a person decides, or the project is opened. It says what has been looked at, read, ruled out and decided,
so the next person or agent builds on it instead of repeating it. It never holds coordinates.
"""

from __future__ import annotations

import datetime as dt
import re

from . import ledger
from .project import INDEX_MD, METHODOLOGY_MD, RECORD_SECTION, Project, commit

# A decimal degree. DOIs such as 10.2307/503404 are left alone: their number runs straight into a slash.
COORD = re.compile(r"(?<![\w/.])-?\d{1,3}\.\d{4,}(?![\w/.])")
VERDICT_WORDS = {"built": "looked built", "possible": "possible", "natural": "natural", "modern": "modern", "nothing": "nothing"}
SOURCE_WORDS = {"read": "Read", "could_not_open": "Could not be opened", "not_relevant": "Not relevant"}


def _clean(text: str, limit: int = 0) -> str:
    text = COORD.sub("[location removed]", " ".join(str(text).split()))
    text = text.replace("|", "/")
    return text if not limit or len(text) <= limit else text[: limit - 1].rstrip() + "…"


def _upgrade(p: Project) -> None:
    """Give a project made before the record existed the method, the notes index and the history it lacks."""
    if not p.path(".gitignore").exists():
        p.path(".gitignore").write_text("data/\nprivate/\n")
    method = p.path("METHODOLOGY.md")
    if not method.exists():
        method.write_text(METHODOLOGY_MD)
    elif "## How this project keeps its record" not in method.read_text():
        method.write_text(method.read_text().rstrip() + "\n\n" + RECORD_SECTION)
    index = p.path("notes", "INDEX.md")
    if not index.exists():
        index.parent.mkdir(parents=True, exist_ok=True)
        runs = sorted(p.path("notes").glob("*-run-*.md"), reverse=True)
        index.write_text(INDEX_MD + "".join(f"- [{f.stem.replace('-run-', ' ')}]({f.name})\n" for f in runs))


def _searches(p: Project) -> list[tuple[str, str, str]]:
    """Literature searches, read from the dated notes: (date, query, results), newest first, each query once."""
    seen: dict[str, tuple[str, str, str]] = {}
    for f in sorted(p.path("notes").glob("20??-??-??.md")):
        for line in f.read_text().splitlines():
            m = re.search(r"Searched the literature for '(.+)': (\d+) results", line)
            if m:
                seen[m.group(1).lower()] = (f.stem, m.group(1), m.group(2))
    return sorted(seen.values(), reverse=True)


def question(p: Project) -> str:
    q = p.load("project", {}).get("question", "")
    if not q and p.path("PROJECT.md").exists():
        after = p.path("PROJECT.md").read_text().split("## Question", 1)
        line = next((l.strip() for l in after[1].splitlines() if l.strip()), "") if len(after) > 1 else ""
        q = "" if line.startswith("#") else line
    return q


def still_to_do(p: Project) -> list[str]:
    tiles = p.load("tiles", {})
    records = ledger.everything(p)
    out = [] if question(p) else ["Write the project's question under \"## Question\" in PROJECT.md, so everyone knows what the search is for."]
    left = sum(t["status"] == "unscreened" for t in tiles.values())
    if not p.load("terrains", {}):
        out.append("Fetch terrain for the area: nothing has been downloaded yet.")
    if left:
        out.append(f"Screen {left} tile{'s' if left != 1 else ''} nobody has looked at yet.")
    open_ = [m for m in records if m["status"] in ("flagged", "ground_confirmed")]
    for key, what in (("section", "a section through the raw points"), ("modern", "a check for modern features"),
                      ("second_look", "a second look by another model")):
        ids = [m["id"] for m in open_ if key not in m["checks"]]
        if ids:
            out.append(f"Give {', '.join(ids)} {what}.")
    ids = [m["id"] for m in open_ if not any(s["status"] == "read" for s in m["sources"])]
    if ids:
        out.append(f"Search the literature for {', '.join(ids)}; no source has been read for them.")
    unopened = sorted({s["title"] for m in records for s in m["sources"] if s["status"] == "could_not_open"})
    if unopened:
        out.append(f"Try the {len(unopened)} source{'s' if len(unopened) != 1 else ''} that could not be opened (listed below); "
                   "a person can open them in the Sources tab and hand them to the agent.")
    if open_:
        out.append(f"Decide {', '.join(m['id'] for m in open_)}: a person makes each decision.")
    if not out and records:
        out.append("Every candidate here is decided. Widen the area, try another survey or view, or write up what was found.")
    return out


def document(p: Project, commit_it: bool = True) -> dict:
    """Rebuild RESEARCH.md and save it in the project's history."""
    _upgrade(p)
    info = p.load("project", {})
    terrains = p.load("terrains", {})
    tiles = p.load("tiles", {})
    records = ledger.everything(p)
    sources: dict[str, dict] = {}
    for m in records:
        for s in m["sources"]:
            entry = sources.setdefault(s["title"], {**s, "for": []})
            entry["for"].append(m["id"])
            if s["status"] == "read":
                entry.update(status="read", finding=s["finding"], link=s.get("link") or entry.get("link", ""))
    searches = _searches(p)
    todo = still_to_do(p)
    name = info.get("name") or p.root.name
    question_text = question(p)
    now = dt.datetime.now()

    screened = [t for t in tiles.values() if t["status"] == "screened"]
    counts = {v: sum(t.get("verdict") == v for t in screened) for v in VERDICT_WORDS}
    models: dict[str, int] = {}
    for t in screened:
        models[t.get("model") or "unnamed"] = models.get(t.get("model") or "unnamed", 0) + 1
    decided = [m for m in records if m.get("decisions")]
    n_status = {k: sum(s["status"] == k for s in sources.values()) for k in SOURCE_WORDS}

    L = [f"# Research record: {name}", "",
         "This is the project's memory. Dighouse rebuilds it from the records, notes and logs whenever a run ends, "
         "a decision is recorded or the project is opened, so do not edit it by hand: write in notes/ or in a "
         "candidate's Notes instead. Anyone continuing this work, a person or an agent, reads it first and builds "
         "on it rather than repeating it. It holds no coordinates; those stay in private/ on the Mac that made them.", "",
         f"Updated {now:%Y-%m-%d %H:%M}. Started {info.get('created', 'unknown')}.", ""]
    if question_text:
        L += ["## The question", "", question_text, ""]
    area = sum(t.get("area_km2", 0) for t in terrains.values())
    L += ["## Where things stand", "",
          f"- **Terrain:** {len(terrains)} survey download{'s' if len(terrains) != 1 else ''}, {area:.2f} sq km.",
          f"- **Ground looked at:** {len(screened)} of {len(tiles)} tiles screened"
          + (f", {sum(t['status'] == 'unreadable' for t in tiles.values())} unreadable" if tiles else "") + ".",
          f"- **Candidates:** {len(records)}, of which {len(decided)} decided by a person.",
          f"- **Sources:** {n_status['read']} read, {n_status['could_not_open']} could not be opened, {n_status['not_relevant']} not relevant.",
          f"- **Literature searches:** {len(searches)}.", ""]
    if todo:
        L += ["## Still to do", ""] + [f"- {t}" for t in todo] + [""]

    L += ["## Data used", ""]
    if terrains:
        L += ["| Survey | From | Flown | Area | Ground returns per sq m | Cell |", "|---|---|---|---|---|---|"]
        for t in sorted(terrains.values(), key=lambda t: t.get("dataset", "")):
            L.append(f"| {t.get('dataset', '')} | {t.get('source') or t.get('dataset', '').split(':')[0]} | {t.get('collected') or 'not stated'} "
                     f"| {t.get('area_km2', 0):.2f} sq km | {t.get('ground_points_per_m2', 0):.1f} | {t.get('res', 0.5)} m |")
    else:
        L.append("No terrain yet.")
    L.append("")

    L += ["## Ground looked at", ""]
    if tiles:
        parts = [f"{counts[v]} {w}" for v, w in VERDICT_WORDS.items() if counts[v]]
        L.append(f"Of {len(tiles)} tiles, {len(screened)} were screened" + (f": {', '.join(parts)}" if parts else "") + ". "
                 "A tile marked nothing or natural was looked at and showed nothing built; that is a result too, "
                 "and it saves the next person from screening it again without a reason.")
        if models:
            L.append("")
            L.append("Looked at by " + ", ".join(f"{k} ({v})" for k, v in sorted(models.items(), key=lambda kv: -kv[1])) + ".")
        L += ["", "| Tile | Verdict | Note |", "|---|---|---|"]
        for tid, t in sorted(tiles.items()):
            verdict = VERDICT_WORDS.get(t.get("verdict"), t["status"].replace("unscreened", "not yet"))
            L.append(f"| {tid} | {verdict} | {_clean(t.get('note', ''), 220)} |")
    else:
        L.append("No tiles yet.")
    L.append("")

    L += ["## Candidates", ""]
    if records:
        L += ["| Id | What | Status | Section | Second look | Modern features | Sources read | Decision |", "|---|---|---|---|---|---|---|---|"]
        for m in records:
            c = m["checks"]
            sec = c.get("section")
            sec_t = (f"{sec.get('feature_height_m', '?')} m high, " + ("in the ground" if sec.get("in_ground") else "not in the ground")
                     if isinstance(sec, dict) else "not yet")
            second = c.get("second_look")
            second_t = (("agrees" if second.get("agrees") else "disagrees") + f" ({second.get('model', '')})"
                        if isinstance(second, dict) else "not yet")
            modern = c.get("modern")
            modern_t = ("modern features nearby" if modern.get("likely_modern") else "none nearby") if isinstance(modern, dict) else "not yet"
            read = sum(s["status"] == "read" for s in m["sources"])
            if m.get("decisions"):
                d = m["decisions"][-1]
                dec = f"{ledger.LABELS.get(d['status'], d['status'])}, by {d['by']}, {d['date']}"
            elif m.get("suggestion"):
                dec = f"Suggested: {ledger.LABELS.get(m['suggestion']['status'], '')}"
            else:
                dec = "waiting"
            L.append(f"| [{m['id']}](candidates/{m['id']}.md) | {_clean(m['name'], 70)} | {ledger.LABELS.get(m['status'], m['status'])} "
                     f"| {sec_t} | {_clean(second_t, 30)} | {modern_t} | {read} | {_clean(dec, 90)} |")
    else:
        L.append("No candidates yet.")
    L.append("")

    L += ["## What has been read", ""]
    if sources:
        for key, title in SOURCE_WORDS.items():
            group = [s for s in sources.values() if s["status"] == key]
            if not group:
                continue
            L += [f"### {title}", ""]
            if key == "could_not_open":
                L += ["These are the next ones to try: a person can open each in the Sources tab and hand it to the agent.", ""]
            for s in group:
                link = f" ([link]({s['link']}))" if s.get("link") else ""
                L.append(f"- **{_clean(s['title'], 200)}**{link}. For {', '.join(sorted(set(s['for'])))}. {_clean(s.get('finding', ''), 400)}")
            L.append("")
    else:
        L += ["Nothing logged yet.", ""]

    L += ["## Literature searches run", ""]
    L += [f"- {d}: \"{_clean(q, 160)}\" ({n} results)" for d, q, n in searches] or ["None yet."]
    L.append("")

    index = p.path("notes", "INDEX.md")
    runs = [l for l in index.read_text().splitlines() if l.startswith("- [")] if index.exists() else []
    L += ["## History", ""] + (runs[:8] or ["No runs yet."])
    L += ["", "The full history is in [notes/INDEX.md](notes/INDEX.md), the dated notes, and the project's git log.", ""]
    L += ["## How this project keeps its record", "",
          "- [PROJECT.md](PROJECT.md): the question and the rules.",
          "- [METHODOLOGY.md](METHODOLOGY.md): how the search is done here, and lessons learned.",
          "- RESEARCH.md: this file.",
          "- candidates/: one record per feature, with its pictures, checks, sources and decisions.",
          "- notes/: a summary of each run, listed in notes/INDEX.md, and a dated log of every step.",
          "- sources/: the log of every source, and pages a person saved for the agent.",
          "- reports/: drafts for a heritage authority, sent only by a person.",
          "- private/ and data/ hold locations and downloads. They stay on this Mac and out of the history.", ""]

    f = p.path("RESEARCH.md")
    text = "\n".join(L)
    old = f.read_text() if f.exists() else ""
    changed = re.sub(r"Updated .*?\.", "", old) != re.sub(r"Updated .*?\.", "", text)
    if changed:
        f.write_text(text)
        if commit_it:
            commit(p.root, "Update the research record")
    return {"written": "RESEARCH.md", "changed": changed, "still_to_do": todo}

