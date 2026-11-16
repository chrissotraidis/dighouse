"""The project's research record, RESEARCH.md.

It is rebuilt from the project's own files (records, tile verdicts, notes and logs) whenever a run ends,
a person decides, or the project is opened. It says what has been looked at, read, ruled out and decided,
so the next person or agent builds on it instead of repeating it. It never holds coordinates.
"""

from __future__ import annotations

import datetime as dt
import json
import re

from . import ledger, national
from .project import INDEX_MD, KEPT_SECTION, METHODOLOGY_MD, RECORD_SECTION, Project, commit

# A decimal degree. DOIs such as 10.2307/503404 are left alone: their number runs straight into a slash.
COORD = re.compile(r"(?<![\w/.])-?\d{1,3}\.\d{4,}(?![\w/.])")
VERDICT_WORDS = {"built": "looked built", "possible": "possible", "natural": "natural", "modern": "modern", "nothing": "nothing"}
SOURCE_WORDS = {"read": "Read", "could_not_open": "Could not be opened", "not_relevant": "Not relevant"}
# How a stop by the person is written in the dated notes. The stage the run was on follows it.
STOPPED = "A person stopped the run during: "


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
    project_md = p.path("PROJECT.md")
    if project_md.exists() and "## How this project is kept" not in project_md.read_text():
        project_md.write_text(project_md.read_text().rstrip() + "\n\n" + KEPT_SECTION)
    index = p.path("notes", "INDEX.md")
    if not index.exists():
        index.parent.mkdir(parents=True, exist_ok=True)
        runs = sorted(p.path("notes").glob("*-run-*.md"), reverse=True)
        def when(stem: str) -> str:
            day, _, hm = stem.partition("-run-")
            return f"{day} {hm[:2]}:{hm[2:]}" if len(hm) == 4 else stem
        index.write_text(INDEX_MD + "".join(f"- [{when(f.stem)}]({f.name})\n" for f in runs))


def _searches(p: Project) -> list[tuple[str, str, str]]:
    """Literature searches, read from the dated notes: (date, query, results), newest first, each query once."""
    seen: dict[str, tuple[str, str, str]] = {}
    for f in sorted(p.path("notes").glob("20??-??-??.md")):
        for line in f.read_text().splitlines():
            m = re.search(r"Searched the literature for '(.+)': (\d+) results", line)
            if m:
                seen[m.group(1).lower()] = (f.stem, m.group(1), m.group(2))
    return sorted(seen.values(), reverse=True)


def _map_failures(p: Project) -> dict[str, str]:
    """Candidates whose check for modern features was tried and got no answer, with the last day it was tried."""
    out: dict[str, str] = {}
    for f in sorted(p.path("notes").glob("20??-??-??.md")):
        for cid in re.findall(r"Could not check for modern features near (C-\d+)", f.read_text()):
            out[cid] = f.stem
    return out


def _last_stop(p: Project) -> tuple[str, str, str] | None:
    """The day, time and stage of the last stop by a person, unless a run has finished or a report been written since."""
    last = None
    for f in sorted(p.path("notes").glob("20??-??-??.md")):
        for line in f.read_text().splitlines():
            m = re.match(r"- (\d\d:\d\d) (.*)", line)
            if not m:
                continue
            if m.group(2).startswith(STOPPED):
                last = (f.stem, m.group(1), m.group(2)[len(STOPPED):])
            elif m.group(2).startswith(("Wrote the run summary", "Wrote the search report")):
                last = None
    return last


def facts(p: Project) -> tuple[dict, dict]:
    """The surveys used and the tiles looked at: what is on this Mac, plus what came with the project.

    A shared project arrives without private/ and data/, so the state that says which ground was looked at is
    gone. notes/record.json keeps a copy of those facts with no locations in it, and it travels with the project.
    Anything in it that this Mac does not have is marked as earlier work, so the record survives a handover.
    """
    f = p.path("notes", "record.json")
    try:
        kept = json.loads(f.read_text()) if f.exists() else {}
    except ValueError:
        kept = {}
    terrains = {k: {x: v.get(x) for x in ("dataset", "source", "collected", "area_km2", "ground_points_per_m2", "res", "survey_details")}
                for k, v in (p.load("terrains", {}) or {}).items()}
    tiles = {k: {"terrain": v.get("terrain"), "status": v.get("status"), "verdict": v.get("verdict"),
                 "note": _clean(v.get("note") or ""), "model": v.get("model")}
             for k, v in (p.load("tiles", {}) or {}).items()}
    for name, here in (("terrains", terrains), ("tiles", tiles)):
        for k, v in (kept.get(name) or {}).items():
            if k not in here:
                here[k] = {**v, "earlier": True}
    if terrains or tiles:
        f.parent.mkdir(parents=True, exist_ok=True)
        text = json.dumps({"terrains": terrains, "tiles": tiles}, indent=1, ensure_ascii=False)
        if not f.exists() or f.read_text() != text:
            f.write_text(text)
    return terrains, tiles


def question(p: Project) -> str:
    q = p.load("project", {}).get("question", "")
    if not q and p.path("PROJECT.md").exists():
        after = p.path("PROJECT.md").read_text().split("## Question", 1)
        line = next((l.strip() for l in after[1].splitlines() if l.strip()), "") if len(after) > 1 else ""
        q = "" if line.startswith("#") else line
    return q


def listed(items: list[str]) -> str:
    """Words in a row, as a person would say them: a, b and c."""
    return " and ".join(([", ".join(items[:-1])] if len(items) > 1 else []) + items[-1:])


def density(t: dict) -> str:
    """Ground returns per square metre, or why there are none: a national ground model is built already, with no points."""
    d = t.get("ground_points_per_m2")
    return f"{d:.1f}" if isinstance(d, (int, float)) else "none (a ready-made ground model)"


def still_to_do(p: Project) -> list[str]:
    terrains, tiles = facts(p)
    records = ledger.everything(p)
    out = [] if question(p) else ["Write the project's question under \"## Question\" in PROJECT.md, so everyone knows what the search is for."]
    left = sum(t["status"] == "unscreened" and not t.get("earlier") for t in tiles.values())
    earlier = sum(t["status"] == "screened" and bool(t.get("earlier")) for t in tiles.values())
    notice = ""
    if terrains and all(t.get("earlier") for t in terrains.values()):
        notice = ("To look at the ground yourself, fetch it again: the downloads and the locations stayed on the Mac "
                  f"this project came from. {earlier} tile{'s were' if earlier != 1 else ' was'} already looked at, "
                  "and each is listed below with what it showed, so this is not needed to carry on.")
    elif not terrains:
        out.append("Fetch the ground for the area: nothing has been downloaded yet.")
    if left:
        out.append(f"Look at {left} tile{'s' if left != 1 else ''} nobody has looked at yet.")
    open_ = [m for m in records if m["status"] in ("flagged", "ground_confirmed")]
    for key, what in (("section", "a slice through the laser points"), ("modern", "a check of open maps for modern features"),
                      ("second_look", "a second opinion from another model")):
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
        out.append("Every find here is decided. Widen the area, try another survey or view, or write up what was found.")
    elif not out and tiles:
        out.append("Every tile was looked at and nothing was marked. Look again in another view (sky view shows low banks best), "
                   "widen the area, or try another survey. Search the literature for the area too: it is worth knowing what is "
                   "published here even when the lidar shows nothing.")
    if notice:
        out.append(notice)
    return out


def document(p: Project, commit_it: bool = True) -> dict:
    """Rebuild RESEARCH.md and save it in the project's history."""
    _upgrade(p)
    info = p.load("project", {})
    terrains, tiles = facts(p)
    # Handed over: the record lists ground that this Mac holds no data for.
    handed = any(t.get("earlier") for t in terrains.values()) and not any(not t.get("earlier") for t in terrains.values())
    records = ledger.everything(p)
    sources: dict[str, dict] = {}
    for m in records:
        for s in m["sources"]:
            entry = sources.setdefault(s["title"], {**s, "for": []})
            entry["for"].append(m["id"])
            if s["status"] == "read":
                entry.update(status="read", finding=s["finding"], link=s.get("link") or entry.get("link", ""))
    searches = _searches(p)
    # Sources read in the chat a project was made from, before there were any finds to log them against.
    log = p.path("sources", "read-log.md")
    from_chat = [l.split(" · read · ", 1)[1] for l in log.read_text().splitlines()
                 if " · before the project, in the chat · read · " in l] if log.exists() else []
    todo = still_to_do(p)
    name = info.get("name") or _title(p) or p.root.name
    question_text = question(p)
    now = dt.datetime.now()

    screened = [t for t in tiles.values() if t["status"] == "screened"]
    counts = {v: sum(t.get("verdict") == v for t in screened) for v in VERDICT_WORDS}
    models: dict[str, int] = {}
    for t in screened:
        models[t.get("model") or "unnamed"] = models.get(t.get("model") or "unnamed", 0) + 1
    decided = [m for m in records if m.get("decisions")]
    n_status = {k: sum(s["status"] == k for s in sources.values()) for k in SOURCE_WORDS}
    failed_maps = _map_failures(p)

    # The top is for someone who has never seen the project: what it asks, how far it got, the finds, and how to carry on.
    short = [f"This project asks: {question_text}" if question_text else "This project has no question written down yet."]
    if tiles:
        flagged = (f"{len(records)} feature{'s' if len(records) != 1 else ''} that looked built "
                   f"{'were' if len(records) != 1 else 'was'} marked" if records else "nothing that looks built was marked")
        short.append(f"So far {len(screened)} of {len(tiles)} squares of ground (tiles) have been looked at, and {flagged}.")
    else:
        short.append("No ground has been looked at yet.")
    if records:
        short.append(f"A person has decided {len(decided)} of {len(records)}.")
    if sources:
        short.append(f"{n_status['read']} published source{'s' if n_status['read'] != 1 else ''} "
                     f"{'were' if n_status['read'] != 1 else 'was'} read"
                     + (f", and {n_status['could_not_open']} could not be opened" if n_status["could_not_open"] else "") + ".")
    elif from_chat:
        short.append(f"{len(from_chat)} source{'s were' if len(from_chat) != 1 else ' was'} read in the chat that started "
                     "the project; none has been logged against a find yet.")
    else:
        short.append("Nothing published has been read yet.")
    if handed:
        short.append("The project was handed over without its downloaded data and its locations, which stay on the Mac "
                     "that made them. What is written here still stands.")
    L = [f"# Research record: {name}", "", "**In short.** " + " ".join(short), ""]
    if records:
        L += ["**The finds.**", ""]
        for m in records:
            last = m["decisions"][-1] if m.get("decisions") else None
            state = (f"{ledger.LABELS.get(last['status'], last['status']).lower()}, decided by {last['by']}" if last
                     else "waiting for a person's decision")
            L.append(f"- [{m['id']} {_clean(m['name'], 70)}](candidates/{m['id']}.md): {state}.")
        L.append("")
    L += ["**How to continue.** Open this folder in Dighouse (File, then Open Project Folder) and ask the agent to carry on. "
          "It reads this record first, so nothing listed here is done twice."
          + (f" Next: {todo[0][0].lower() + todo[0][1:]}" if todo else ""), "",
          f"Updated {now:%Y-%m-%d %H:%M}. Started {info.get('created') or 'on another Mac'}.", ""]
    area = sum(t.get("area_km2") or 0 for t in terrains.values())
    L += ["## Where things stand", "",
          f"- **Ground:** {len(terrains)} survey download{'s' if len(terrains) != 1 else ''}, {area:.2f} sq km.",
          f"- **Tiles looked at:** {len(screened)} of {len(tiles)}"
          + (f", {sum(t['status'] == 'unreadable' for t in tiles.values())} unreadable" if tiles else "") + ".",
          f"- **Finds:** {len(records)}, of which {len(decided)} decided by a person.",
          f"- **Sources:** {n_status['read']} read, {n_status['could_not_open']} could not be opened, {n_status['not_relevant']} not relevant.",
          f"- **Literature searches:** {len(searches)}.", ""]
    stop = _last_stop(p)
    if stop:
        L[-1:] = [f"- **The last run was stopped** by a person on {stop[0]} at {stop[1]}, during: {stop[2]}. "
                  "Everything it did up to then is in this record. Start a run again to carry on from here.", ""]
    reports = sorted(p.path("reports").glob("*-search-report.md"), reverse=True)
    if reports:
        L[-1:] = [f"- **Search report:** [{reports[0].stem[:10]}](reports/{reports[0].name}), a two-minute read of what was found.", ""]
    if todo:
        L += ["## Still to do", ""] + [f"- {t}" for t in todo] + [""]

    from .answers import calibration_lines, score_lines
    L += score_lines(p)
    L += calibration_lines(p)
    rises = p.load("rises", {}) or {}
    rise_rows = [(t, s) for t, spots in sorted(rises.items()) for s in spots]
    if rise_rows:
        L += ["## Measured rises to look at", "", "Round rises the tools measured in the ground model (find_mounds) that may be small mounds a "
              "picture hides. They are not finds: look at each in the tile's mounds picture and mark the ones that look built.", "",
              "| Tile | Spot | Across | High |", "|---|---|---|---|"]
        L += [f"| {t} | {s['n']} | {s['diameter_m']:.0f} m | {s['height_m']:.1f} m |" for t, s in rise_rows[:40]]
        L.append("")
    L += ["## Data used", ""]
    if terrains:
        L += ["| Survey | From | Flown | Area | Ground returns per sq m | Cell |", "|---|---|---|---|---|---|"]
        for t in sorted(terrains.values(), key=lambda t: t.get("dataset", "")):
            prefix = t.get("dataset", "").split(":")[0]
            L.append(f"| {t.get('dataset', '')} | {t.get('source') or ('Imported by a person' if prefix == 'own' else national.publisher(prefix))} | {t.get('collected') or 'not stated'} "
                     f"| {(t.get('area_km2') or 0):.2f} sq km | {density(t)} | {t.get('res') or 0.5} m |")
        surveys = [x for t in terrains.values() for x in (t.get("survey_details") or [])]
        if surveys:
            L += ["", "| Seafloor survey | Surveyed | By | Median depth uncertainty | Record |", "|---|---|---|---|---|"]
            for x in surveys:
                u = f"{x['uncertainty_m']:g} m" if x.get("uncertainty_m") is not None else "not read"
                L.append(f"| {x['survey']} | {x.get('surveyed') or 'not stated'} | {x.get('platform') or 'not stated'} | {u} | {x.get('record') or ''} |")
    else:
        L.append("No ground yet.")
    L.append("")

    L += ["## Ground looked at", ""]
    if tiles:
        parts = [f"{counts[v]} {w}" for v, w in VERDICT_WORDS.items() if counts[v]]
        L.append(f"Of {len(tiles)} tiles, {len(screened)} were looked at" + (f": {', '.join(parts)}" if parts else "") + ". "
                 "A tile marked nothing or natural was looked at and showed nothing built; that is a result too, "
                 "and it saves the next person from looking again without a reason.")
        if models:
            L.append("")
            L.append("Looked at by " + ", ".join(f"{k} ({v})" for k, v in sorted(models.items(), key=lambda kv: -kv[1])) + ".")
        if any(t.get("earlier") for t in tiles.values()):
            L += ["", "Tiles marked \"earlier\" were looked at before the project was handed over. Their pictures are not on "
                  "this Mac, but what each showed is."]
        L += ["", "| Tile | Verdict | Note |", "|---|---|---|"]
        for tid, t in sorted(tiles.items()):
            verdict = VERDICT_WORDS.get(t.get("verdict"), t["status"].replace("unscreened", "not yet"))
            L.append(f"| {tid} | {verdict}{' (earlier)' if t.get('earlier') else ''} | {_clean(t.get('note') or '', 220)} |")
    else:
        L.append("No tiles yet.")
    L.append("")

    L += ["## Finds", ""]
    if records:
        L += ["| Id | What | Status | Slice | Second opinion | Open maps | Sources read | Decision |", "|---|---|---|---|---|---|---|---|"]
        for m in records:
            c = m["checks"]
            sec = c.get("section")
            sec_t = (f"{sec.get('feature_height_m', '?')} m high, " + ("in the ground" if sec.get("in_ground") else "above the seafloor" if sec.get("seafloor")
                                                                      else "on a ready-made ground model" if sec.get("from_ground_model_only") else "not in the ground")
                     if isinstance(sec, dict) else "not yet")
            second = c.get("second_look")
            second_t = (("agrees" if second.get("agrees") else "disagrees") + f" ({second.get('model', '')})"
                        if isinstance(second, dict) else "not yet")
            modern = c.get("modern")
            if isinstance(modern, dict):
                modern_t = ((listed(modern.get("near") or []) or "modern features") + " nearby" if modern.get("likely_modern")
                            else "nothing modern nearby")
            else:
                modern_t = (f"not yet: the map service did not answer on {failed_maps[m['id']]}" if m["id"] in failed_maps else "not yet")
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
        L.append("No finds yet.")
    L.append("")

    L += ["## What has been read", ""]
    if from_chat:
        L += ["### Read in the chat that started the project", ""] + [f"- {_clean(s, 400)}" for s in from_chat] + [""]
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
    elif not from_chat:
        L += ["Nothing logged yet.", ""]

    L += ["## Literature searches run", ""]
    L += [f"- {d}: \"{_clean(q, 160)}\" ({n} results)" for d, q, n in searches] or ["None yet."]
    L.append("")

    index = p.path("notes", "INDEX.md")
    runs = [l for l in index.read_text().splitlines() if l.startswith("- [")] if index.exists() else []
    # The index links from inside notes/; from here the same files are under notes/.
    runs = [re.sub(r"\]\((?!notes/|https?:)([^)]+)\)", r"](notes/\1)", l) for l in runs]
    L += ["## History", ""] + (runs[:8] or ["No runs yet."])
    L += ["", "The full history is in [notes/INDEX.md](notes/INDEX.md), the dated notes, and the project's git log.", ""]
    L += ["## How this project keeps its record", "",
          "Dighouse rebuilds this file from the records, notes and logs whenever a run ends, a decision is recorded or the "
          "project is opened, so do not edit it by hand: write in notes/ or in a find's Notes instead. "
          "It holds no coordinates; those stay in private/ on the Mac that made them.", "",
          "- [PROJECT.md](PROJECT.md): the question and the rules.",
          "- [METHODOLOGY.md](METHODOLOGY.md): how the search is done here, and lessons learned.",
          "- RESEARCH.md: this file.",
          "- candidates/: one record per find, with its pictures, checks, sources and decisions.",
          "- notes/: a summary of each run, listed in notes/INDEX.md, and a dated log of every step.",
          "- notes/record.json: which surveys were used and which tiles were looked at, without locations, so the record "
          "survives when the project is shared.",
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
    return {"written": "RESEARCH.md", "changed": changed, "still_to_do": todo, "handed_over": handed,
            "screened_before": sum(t["status"] == "screened" and bool(t.get("earlier")) for t in tiles.values())}


def _title(p: Project) -> str:
    """The project's name from the first heading of PROJECT.md, for a project that arrived without its private state."""
    f = p.path("PROJECT.md")
    first = f.read_text().splitlines()[0] if f.exists() and f.read_text().strip() else ""
    return first.lstrip("# ").strip() if first.startswith("#") else ""

