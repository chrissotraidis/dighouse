"""Candidate records.

Each candidate is one Markdown file. Its structured fields sit in a header block
(one "key: json" line each) and the readable body is rebuilt from them on every
change. Anything written under "## Notes" by a person or an agent is kept.

Locations are never written here. They live in private/state/locations.json.
"""

from __future__ import annotations

import json
import math
import os
import re
import threading
from urllib.parse import unquote, urlparse

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


def readable_link(link: str) -> str:
    """The page a person reads, for a link copied from a data service: DataCite and Crossref API addresses for a
    DOI become https://doi.org/..., an OpenAlex API work becomes its openalex.org page. Anything else is kept."""
    link = (link or "").strip()
    try:
        u = urlparse(link)
    except ValueError:
        return link
    host, path = (u.hostname or "").lower(), unquote(u.path)
    for api, prefix in (("api.datacite.org", "/dois/"), ("api.crossref.org", "/works/")):
        if host == api and path.startswith(prefix) and path[len(prefix):].startswith("10."):
            return "https://doi.org/" + path[len(prefix):]
    if host == "api.openalex.org" and path.startswith("/works/"):
        work = path[len("/works/"):]
        if re.match(r"(?i)https?://doi\.org/", work):
            return work
        if work.lower().startswith("doi:"):
            return "https://doi.org/" + work[4:]
        return "https://openalex.org/" + work
    return link


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
    f = _file(p, meta["id"])
    # Written beside the file and swapped in whole: checks run on many finds at once while the record and the report
    # read them, and a half-written find once stopped the report ("not enough values to unpack").
    tmp = f.with_name(f".{f.name}.{os.getpid()}.{threading.get_ident()}.tmp")
    tmp.write_text(f"---\n{head}\n---\n{_body(meta, p)}\n{NOTES}\n\n{notes}\n")
    os.replace(tmp, f)


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


def set_status(p: Project, cid: str, status: str, decided_by: str = "", reason: str = "", commit_it: bool = True) -> dict:
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
                                  "open_items": missing, "was": meta["status"]})
    meta["status"] = status
    write(p, meta, notes)
    p.note(f"{cid} marked {status}" + (f" by {decided_by}" if decided_by else ""))
    if decided_by and commit_it:
        from .record import document
        document(p, commit_it=False)
        commit(p.root, f"{cid} marked {LABELS[status].lower()} by {decided_by}")
    return meta


def set_statuses(p: Project, decisions: list[dict], decided_by: str) -> list[dict]:
    """A person's decisions on many finds at once ({candidate, status, reason} each): the record is rebuilt once and
    they are saved in one commit. Every decision is checked before any is written, so a refused one changes nothing."""
    if not decided_by.strip():
        raise ValueError("A person decides. Pass their name as decided_by.")
    for d in decisions:
        if d["status"] not in STATUSES or not str(d.get("reason", "")).strip():
            raise ValueError(f"{d.get('candidate')}: give a status from {STATUSES} and a reason.")
        get(p, d["candidate"])
    done = [set_status(p, d["candidate"], d["status"], decided_by, d["reason"].strip(), commit_it=False) for d in decisions]
    if done:
        from .record import document
        document(p, commit_it=False)
        commit(p.root, f"{len(done)} find{'s' if len(done) != 1 else ''} decided by {decided_by}")
    return done


def undo_decision(p: Project, cid: str, by: str) -> dict:
    """Take back the last decision on a find: it returns to the status it had before, the decision leaves its record,
    and the undoing is written in the log and the history."""
    meta, notes = get(p, cid)
    if not meta.get("decisions"):
        raise ValueError(f"{cid} has no decision to undo.")
    last = meta["decisions"].pop()
    meta["status"] = last.get("was") or "flagged"   # decisions made before "was" was kept came from a waiting find
    write(p, meta, notes)
    p.note(f"{cid}: {by} undid the decision {LABELS[last['status']].lower()!r} of {last['date']}")
    from .record import document
    document(p, commit_it=False)
    commit(p.root, f"{cid}: decision undone by {by}")
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


# A measured rise goes to a person when the second model calls it built and its shape ranks in the top half of this
# project's measured rises, or when a person raises it. A find the bulk look opened and the agent did not take over goes
# to a person when the second model calls it built, or when a person raises it. The rest stay on the map as a layer, and still count in blind
# tests. Ranks are compared within a project because how rises are ranked has changed between versions. The app's
# ProjectStore.layer keeps the same rule.
RISE_SHARE = 0.5


def is_rise(meta: dict) -> bool:
    return str(meta.get("flagged_by", "")).startswith("measured")


def is_bulk(meta: dict) -> bool:
    """A find the bulk look opened and no model has taken over on a closer look."""
    return str(meta.get("flagged_by", "")).startswith("seen in bulk")


def _rank(meta: dict) -> float:
    return float((meta["checks"].get("shape") or {}).get("rank") or 0)


def layer(records: list[dict]) -> set[str]:
    """The measured rises kept on the map rather than put to a person (see RISE_SHARE)."""
    ranks = sorted(_rank(m) for m in records if is_rise(m))
    cut = ranks[min(int(len(ranks) * (1 - RISE_SHARE)), len(ranks) - 1)] if ranks else 0.0
    out = set()
    for m in records:
        if m["status"] not in ("flagged", "ground_confirmed") or m.get("raised"):
            continue
        says_built = m["checks"].get("second_look", {}).get("agrees") is True
        if is_rise(m) and not (says_built and _rank(m) >= cut):
            out.add(m["id"])
        elif is_bulk(m) and not says_built:
            # A shape the bulk look pointed at and the agent did not mark on its closer look waits on the map,
            # unless the second model calls it built (FIND_LOOP G3).
            out.add(m["id"])
    return out


def raise_rise(p: Project, cid: str, by: str) -> dict:
    """A person asks to decide a find kept on the map (a measured rise, or a shape the bulk look pointed at): it joins the
    finds that wait for them."""
    meta, notes = get(p, cid)
    if not (is_rise(meta) or is_bulk(meta)):
        raise ValueError(f"{cid} is not kept on the map.")
    meta["raised"] = {"by": by, "date": today()}
    write(p, meta, notes)
    p.note(f"{cid} raised from the map by {by}")
    from .record import document
    document(p, commit_it=False)
    commit(p.root, f"{cid} raised from the map by {by}")
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
    link = readable_link(link)
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


def _body(meta: dict, p=None) -> str:
    cid, checks, sources = meta["id"], meta["checks"], meta["sources"]
    by = str(meta["flagged_by"])
    # "seen in bulk by …" and "measured (…)" already say how; a model's name needs "by".
    marked = f"{meta['flagged']}, {by}" if by.startswith(("seen in bulk", "measured")) else f"{meta['flagged']} by {by}"
    # As the app says it: a flag with its slice and its open-map check on record waits for a person, not for checks.
    state = ("Checked, waiting for a person's decision" if meta["status"] == "flagged" and checks.get("section") and checks.get("modern")
             else LABELS[meta["status"]])
    out = [f"# {cid} {meta['name']}", "",
           f"Status: {state} · Marked {marked}", ""]
    for kind, caption in (("relief", "Bare-ground relief"), ("section", "Slice through the feature")):
        if (checks.get(kind) or {}).get("image") or kind == "relief":
            # New finds' pictures are JPEGs (written just after the record); finds from before keep their PNGs.
            ext = "png" if kind != "relief" or (p is not None and p.path("candidates", "img", f"{cid}-relief.png").exists()
                                                   and not p.path("candidates", "img", f"{cid}-relief.jpg").exists()) else "jpg"
            out += [f"![{caption}](img/{cid}-{kind}.{ext})", ""]
    out += ["## Evidence", ""] + [f"- {e}" for e in meta["evidence"]] + [""]
    out += ["## Checks", ""]
    s = checks.get("section")
    out.append(_tick(s and s.get("in_ground"), "In the ground",
                     "" if not s else f"{height_words(checks).capitalize()}, measured on a ready-made ground model, which has no treetops to compare"
                     if s.get("from_ground_model_only")
                     else f"{height_words(checks).capitalize()}; {s['ground_returns_within_5m_of_peak']} laser points reached the ground at its top"))
    look = checks.get("second_look")
    tried = checks.get("second_look_tried")
    out.append(_tick(look and look.get("agrees"), "A second model says it looks built", f"{look['model']}: {look['note']}" if look
                     else f"asked {tried['model']} on {tried['date']}; it could not answer: {tried['reason']}" if tried else ""))
    m = checks.get("modern")
    out.append(_tick(m is not None and not m.get("likely_modern"), "Nothing modern on open maps", m["summary"] if m else ""))
    rec = checks.get("records")
    if rec is not None:
        out.append(_tick(not rec.get("near"), "Not on the open records read" if not rec.get("near") else "On the open records",
                         records_words(rec)))
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


def height_words(checks: dict) -> str:
    """One height for a find, named for what it measures: how far it rises above (or sits below) the ground around it,
    from the shape check; the slice's rise above the line between its ends only when there is no shape check, since on a
    slope that reads high (FIND_LOOP G3)."""
    shape, sec = checks.get("shape") or {}, checks.get("section") or {}
    if shape.get("rise_m") is not None:
        if (shape.get("sink_m") or 0) > max(0.2, shape["rise_m"]):
            return f"{shape['sink_m']} m below the ground around it"
        return f"rises {shape['rise_m']} m above the ground around it"
    if sec.get("feature_height_m") is not None:
        return f"{sec['feature_height_m']} m above the line between the slice's ends"
    return "height not measured"


def records_words(rec: dict) -> str:
    """What the open records hold at a find, which were read and when, and what that can and cannot say."""
    reach, near = rec.get("reach_m", 120), rec.get("near") or []
    if near:
        first = near[0]
        where = "inside its recorded area" if first["metres"] == 0 else f"{first['metres']} m away"
        words = f"{first['name']} ({first['kind']}, {first['source']}) is {where}" + (f", {first['record']}" if first.get("record") else "")
        words += f"; {len(near) - 1} more within {reach} m" if len(near) > 1 else ""
    else:
        words = f"nothing within {reach} m in {', '.join(rec.get('answered') or []) or 'the lists that answered'}"
    words += f" (read {rec['date']})" if rec.get("date") else ""
    if rec.get("silent"):
        words += "; did not answer: " + "; ".join(x.split(":")[0] for x in rec["silent"])
    registers = rec.get("registers") or []
    if registers:
        words += ". " + "; ".join(f"{r['register']} lists {r['holds']}" for r in registers)
    else:
        words += ". No open official register covers this place, so the site records here were not read"
    return words + "."


def _tick(done, label: str, detail: str) -> str:
    return f"- [{'x' if done else ' '}] {label}" + (f": {detail}" if detail else "")
