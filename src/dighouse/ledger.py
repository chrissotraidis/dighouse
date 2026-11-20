"""Candidate records.

Each candidate is one Markdown file. Its structured fields sit in a header block
(one "key: json" line each) and the readable body is rebuilt from them on every
change. Anything written under "## Notes" by a person or an agent is kept.

Locations are never written here. They live in private/state/locations.json.
"""

from __future__ import annotations

import json
import math

from .project import Project, commit, today

STATUSES = ("flagged", "ground_confirmed", "modern", "natural", "already_published",
            "no_match_in_sources_read", "reported")
SOURCE_STATUSES = ("read", "could_not_open", "not_relevant")
LABELS = {
    "flagged": "Marked, not yet checked",
    "ground_confirmed": "In the ground, origin not yet checked",
    "modern": "Modern feature",
    "natural": "Natural feature",
    "already_published": "Already published",
    "no_match_in_sources_read": "No match in the sources read",
    "reported": "Reported to the heritage authority",
}
NOTES = "## Notes"


def _file(p: Project, cid: str):
    return p.path("candidates", f"{cid}.md")


def get(p: Project, cid: str) -> tuple[dict, str]:
    f = _file(p, cid)
    if not f.exists():
        raise ValueError(f"No find {cid}. Known: {[c['id'] for c in everything(p)]}")
    _, head, body = f.read_text().split("---\n", 2)
    meta = {k: json.loads(v) for k, v in (line.split(": ", 1) for line in head.strip().splitlines())}
    notes = body.split(NOTES, 1)[1].strip() if NOTES in body else ""
    return meta, notes


def everything(p: Project) -> list[dict]:
    return [get(p, f.stem)[0] for f in sorted(p.path("candidates").glob("C-*.md"))]


def write(p: Project, meta: dict, notes: str = "") -> None:
    head = "\n".join(f"{k}: {json.dumps(v, ensure_ascii=False)}" for k, v in meta.items())
    _file(p, meta["id"]).write_text(f"---\n{head}\n---\n{_body(meta)}\n{NOTES}\n\n{notes}\n")


def create(p: Project, name: str, tile: str, lonlat: tuple[float, float], note: str, flagged_by: str,
           at: tuple[float, float] = (0.5, 0.5)) -> dict:
    with p.locked("candidates"):  # two finds marked at once must not get the same id
        n = max([int(c["id"][2:]) for c in everything(p)] or [0]) + 1
        meta = {"id": f"C-{n:03d}", "name": name, "status": "flagged", "flagged": today(), "flagged_by": flagged_by,
                "tile": tile, "evidence": [note] if note else [], "checks": {}, "sources": [], "decisions": []}
        with p.change("locations", {}) as locations:
            locations[meta["id"]] = {"lon": lonlat[0], "lat": lonlat[1], "tile": tile, "x": at[0], "y": at[1]}
        write(p, meta)
    return meta


def location(p: Project, cid: str) -> tuple[float, float]:
    places = p.load("locations", {}) or {}
    if cid not in places:
        raise ValueError(f"{cid}'s location is not on this Mac. Locations stay under private/, which is not part of a shared "
                         "project. Ask whoever shared the project for it, or mark the feature again on ground fetched here.")
    loc = places[cid]
    return loc["lon"], loc["lat"]


def blockers(meta: dict, status: str) -> list[str]:
    """What still stands between this record and a status. An empty list means it may move."""
    checks, missing = meta["checks"], []
    section = checks.get("section", {})
    if status in ("ground_confirmed", "no_match_in_sources_read", "reported"):
        if not section:
            missing.append("no slice has been cut")
        elif not section.get("in_ground"):
            missing.append("the slice did not show the feature in the ground")
    if status in ("no_match_in_sources_read", "reported"):
        if not checks.get("second_look", {}).get("agrees"):
            missing.append("no second model has agreed that it looks built")
        if "modern" not in checks:
            missing.append("modern features have not been checked")
        if not any(s["status"] == "read" for s in meta["sources"]):
            missing.append("no source has been read")
        unread = [s["title"] for s in meta["sources"] if s["status"] == "could_not_open"]
        if unread:
            missing.append(f"{len(unread)} source(s) could not be opened: {'; '.join(unread)}")
    return missing


def set_status(p: Project, cid: str, status: str, decided_by: str = "", reason: str = "") -> dict:
    if status not in STATUSES:
        raise ValueError(f"status must be one of {STATUSES}")
    meta, notes = get(p, cid)
    missing = blockers(meta, status)
    needs_person = status in ("no_match_in_sources_read", "reported")
    if needs_person and not decided_by:
        raise ValueError(f"A person must decide before a find is marked {status!r}. Ask them, then pass decided_by.")
    if missing and not decided_by:
        raise ValueError(f"{cid} cannot be marked {status!r} yet: " + "; ".join(missing))
    if decided_by:
        meta["decisions"].append({"date": today(), "by": decided_by, "status": status, "reason": reason,
                                  "open_items": missing})
    meta["status"] = status
    write(p, meta, notes)
    p.note(f"{cid} marked {status}" + (f" by {decided_by}" if decided_by else ""))
    if decided_by:
        from .record import document
        document(p, commit_it=False)
        commit(p.root, f"{cid} marked {LABELS[status].lower()} by {decided_by}")
    return meta


def suggest(p: Project, cid: str, status: str, reason: str, by: str) -> dict:
    """The agent's suggestion for the person's decision. It changes nothing but the suggestion; the person decides."""
    if status not in ("modern", "natural", "already_published", "no_match_in_sources_read"):
        raise ValueError("suggest one of: already_published, modern, natural, no_match_in_sources_read")
    if not reason.strip():
        raise ValueError("Give the reason the person will read, such as where the feature is published.")
    meta, notes = get(p, cid)
    meta["suggestion"] = {"status": status, "reason": reason.strip(), "by": by, "date": today()}
    write(p, meta, notes)
    return meta


def set_check(p: Project, cid: str, key: str, value: dict) -> dict:
    meta, notes = get(p, cid)
    meta["checks"][key] = value
    write(p, meta, notes)
    return meta


def project_sources(p: Project) -> dict:
    path = p.path("sources", "project.json")
    return json.loads(path.read_text()) if path.exists() else p.load("project_sources", {})


def add_source(p: Project, cid: str, title: str, status: str, finding: str, link: str = "") -> dict:
    if status not in SOURCE_STATUSES:
        raise ValueError(f"status must be one of {SOURCE_STATUSES}")
    meta, notes = get(p, cid)
    meta["sources"] = [s for s in meta["sources"] if s["title"] != title]
    meta["sources"].append({"title": title, "status": status, "finding": finding, "link": link})
    write(p, meta, notes)
    log_read(p, cid, title, status, finding, link)
    return meta


def log_read(p, cid, title, status, finding, link):
    log = p.path("sources", "read-log.md")
    if not log.exists():
        log.write_text("# Sources read\n\n")
    with log.open("a") as fh:
        fh.write(f"- {today()} · {cid} · {status} · {title}" + (f" · {link}" if link else "") + f" · {finding}\n")


def distance_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    (lon1, lat1), (lon2, lat2) = a, b
    k = math.cos(math.radians((lat1 + lat2) / 2))
    return 111_320 * math.hypot((lon1 - lon2) * k, lat1 - lat2)


def _body(meta: dict) -> str:
    cid, checks, sources = meta["id"], meta["checks"], meta["sources"]
    out = [f"# {cid} {meta['name']}", "",
           f"Status: {LABELS[meta['status']]} · Marked {meta['flagged']} by {meta['flagged_by']}", ""]
    for kind, caption in (("relief", "Bare-ground relief"), ("section", "Slice through the feature")):
        if (checks.get(kind) or {}).get("image") or kind == "relief":
            out += [f"![{caption}](img/{cid}-{kind}.png)", ""]
    out += ["## Evidence", ""] + [f"- {e}" for e in meta["evidence"]] + [""]
    out += ["## Checks", ""]
    s = checks.get("section")
    out.append(_tick(s and s.get("in_ground"), "In the ground",
                     "" if not s else f"{s['feature_height_m']} m high, measured on a ready-made ground model, which has no treetops to compare"
                     if s.get("from_ground_model_only")
                     else f"{s['feature_height_m']} m high, {s['ground_returns_within_5m_of_peak']} laser points reached the ground at its top"))
    look = checks.get("second_look")
    tried = checks.get("second_look_tried")
    out.append(_tick(look and look.get("agrees"), "A second model agrees it looks built", f"{look['model']}: {look['note']}" if look
                     else f"asked {tried['model']} on {tried['date']}; it could not answer: {tried['reason']}" if tried else ""))
    m = checks.get("modern")
    out.append(_tick(m is not None and not m.get("likely_modern"), "Nothing modern on open maps", m["summary"] if m else ""))
    read = sum(x["status"] == "read" for x in sources)
    unread = sum(x["status"] == "could_not_open" for x in sources)
    out.append(_tick(read and not unread, "What is published", f"{read} read, {unread} could not be opened"))
    out += ["", "## Sources searched", ""]
    out += [f"- {x['title']} — {x['status'].replace('_', ' ')} — {x['finding']}" for x in sources] or ["None yet."]
    sug = meta.get("suggestion")
    if sug and meta["status"] in ("flagged", "ground_confirmed"):
        out += ["", "## Suggested decision", "",
                f"{sug['by']} suggests: {LABELS[sug['status']].lower()}. {sug['reason']} (A person decides.)"]
    if meta["decisions"]:
        out += ["", "## Decisions", ""]
        for d in meta["decisions"]:
            open_items = f" Open at the time: {'; '.join(d['open_items'])}." if d["open_items"] else ""
            out.append(f"- {d['date']} · {d['by']} marked this {LABELS[d['status']].lower()}. {d['reason']}{open_items}")
    return "\n".join(out) + "\n"


def _tick(done, label: str, detail: str) -> str:
    return f"- [{'x' if done else ' '}] {label}" + (f": {detail}" if detail else "")
