"""The search report: what a person reads when a search ends.

It is built from the project's own records, so it cannot say more than they do, and it holds no coordinates.
The only words that are not taken from the records are the agent's advice on what to try next.
"""

from __future__ import annotations

import datetime as dt
import re

from . import ledger, national, record
from .project import Project, commit

ADVICE = "**The agent adds:** "
LIMIT = 400  # words in a report, however many finds there are


def _s(n: int, word: str, plural: str = "") -> str:
    return f"{n} {word if n == 1 else (plural or word + 's')}"


def _first(text: str, limit: int) -> str:
    """The first sentence of a note, or as many whole words of it as fit, ending in a full stop or an ellipsis."""
    text = record._clean(text)
    cut = re.search(r"(?<=[a-z\)\d])[.;] ", text)
    if cut and cut.start() <= limit:
        text = text[: cut.start()]
    if len(text) > limit:
        # Stop at the end of a clause when one is near, so the cut does not fall in the middle of a thought.
        whole = text[:limit].rsplit(" ", 1)[0]
        clause = max(whole.rfind(", "), whole.rfind("; "), whole.rfind(": "))
        return (whole[:clause] if clause > limit * 0.6 else whole).rstrip(",;:") + "…"
    return text.rstrip(".;") + "." if text else ""


def _short(text: str, limit: int) -> str:
    """A title cut to whole words."""
    text = record._clean(text)
    return text if len(text) <= limit else text[:limit].rsplit(" ", 1)[0].rstrip(",;:") + "…"


def _checks(m: dict, failed_maps: dict, maps: bool = True) -> str:
    """What the checks on a find showed, in a few words each. With maps off, the map check is left for a line of its own."""
    c, parts = m["checks"], []
    sec = c.get("section")
    if isinstance(sec, dict):
        # A ready-made ground model has no treetops in it, so its slice can measure a shape but cannot place it.
        parts.append(f"Slice: {sec.get('feature_height_m', '?')} m high, "
                     + ("in the ground" if sec.get("in_ground") else "above the seafloor" if sec.get("seafloor")
                        else "on a ready-made ground model" if sec.get("from_ground_model_only") else "not clearly in the ground"))
    else:
        parts.append("Slice: not cut yet")
    second = c.get("second_look")
    if isinstance(second, dict):
        parts.append("Second model: " + ("agreed it looks built" if second.get("agrees") else "did not agree it looks built"))
    elif isinstance(c.get("second_look_tried"), dict):
        tried = c["second_look_tried"]
        parts.append(f"Second model: asked {tried.get('model', '')} on {tried.get('date', '')}, which could not answer ({tried.get('reason', '')})")
    else:
        parts.append("Second model: has not looked")
    modern = c.get("modern")
    if not maps:
        pass
    elif isinstance(modern, dict):
        near = record.listed(modern.get("near") or []) or "modern features"
        parts.append(("Charts: " if modern.get("charts") else "Open maps: ")
                     + (f"{near} within {modern.get('radius_m', 150)} m" if modern.get("likely_modern")
                        else "no cable, pipeline or dumping ground charted" if modern.get("charts") else "nothing modern on it"))
    elif m["id"] in failed_maps:
        parts.append("Open maps: did not answer")
    else:
        parts.append("Open maps: not checked")
    return ". ".join(parts) + "."


def _fewer(text: str) -> str:
    """A long run of find numbers cut to the first two and a count."""
    def cut(run: re.Match) -> str:
        ids = run.group(0).split(", ")
        return run.group(0) if len(ids) <= 3 else f"{ids[0]}, {ids[1]} and {len(ids) - 2} more"
    return re.sub(r"C-\d+(?:, C-\d+)+", cut, text)


def count(text: str) -> int:
    """Words a person reads: link addresses do not count."""
    return len(re.findall(r"[\w'’-]+", re.sub(r"\]\([^)]*\)", "]", text)))


def write(p: Project, advice: str = "") -> dict:
    """Write today's search report in reports/ and link it from the research record.

    The report stays under LIMIT words however many finds there are. The finds that wait for a decision come first,
    as many as fit, and the rest are counted and left to the research record.
    """
    advice = " ".join(advice.split())
    if record.COORD.search(advice):
        raise ValueError("The advice looks like it holds coordinates. Refer to places by find number instead.")
    f = p.path("reports", f"{dt.date.today().isoformat()}-search-report.md")
    if not advice and f.exists():
        # Rebuilt after more work the same day: keep what the agent advised.
        advice = next((l[len(ADVICE):] for l in f.read_text().splitlines() if l.startswith(ADVICE)), "")

    text, open_ = _compose(p, advice)
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text)
    p.note(f"Wrote the search report {f.name}")
    record.document(p, commit_it=False)
    commit(p.root, f"Search report {dt.date.today().isoformat()}")
    return {"written": f"reports/{f.name}", "words": count(text), "waiting_for_a_person": [m["id"] for m in open_]}


def _compose(p: Project, advice: str) -> tuple[str, list[dict]]:
    """The report's text from the project's records as they are now, and the finds it puts to a person."""
    info = p.load("project", {}) or {}
    terrains, tiles = record.facts(p)
    records = ledger.everything(p)
    failed_maps = record._map_failures(p)
    name = info.get("name") or record._title(p) or p.root.name
    screened = [t for t in tiles.values() if t["status"] == "screened"]
    unreadable = sum(t["status"] == "unreadable" for t in tiles.values())
    counts = {v: sum(t.get("verdict") == v for t in screened) for v in record.VERDICT_WORDS}
    on_map = ledger.layer(records)
    open_ = [m for m in records if m["status"] in ("flagged", "ground_confirmed") and m["id"] not in on_map]
    decided = [m for m in records if m["status"] not in ("flagged", "ground_confirmed")]

    # Written with room to spare when there is room, and cut short when there are many finds.
    tight = {"finding": 100, "advice": 200, "question": 160, "sources": 1}
    for cut in ({"reason": 190, "finding": 170, "advice": 320, "question": 220, "sources": 2}, {"reason": 190, **tight},
                {"reason": 150, **tight}, {"reason": 100, **tight}):
        text, shown = _build(p, name, terrains, tiles, records, open_, decided, counts, screened, unreadable, failed_maps, advice, cut)
        if shown == len(open_):
            break
    return text, open_


STAMP = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}\. Written by Dighouse")


def refresh(p: Project) -> bool:
    """Bring the newest search report up to date with the records, keeping its file and the agent's advice, so it never
    asks for what is already done (a second opinion that has come in, a decision made). Called whenever the research
    record is rebuilt. Returns whether it changed; the caller commits."""
    files = sorted(p.path("reports").glob("*-search-report.md")) if p.path("reports").exists() else []
    if not files:
        return False
    f = files[-1]
    old = f.read_text()
    advice = next((l[len(ADVICE):] for l in old.splitlines() if l.startswith(ADVICE)), "")
    text, _ = _compose(p, advice)
    same = lambda s: [l for l in s.splitlines() if not STAMP.match(l)]
    if same(old) == same(text):
        return False
    f.write_text(text)
    return True


def _build(p, name, terrains, tiles, records, open_, decided, counts, screened, unreadable, failed_maps, advice, cut) -> tuple[str, int]:
    """The report's text and how many of the waiting finds it names, with notes cut to the lengths given."""
    top = [f"# Search report: {_short(name, 80)}", "",
           f"{dt.datetime.now():%Y-%m-%d %H:%M}. Written by Dighouse from the project's records. Nothing here is called new, "
           "and locations are left out.", ""]

    # Everything after the decisions is built first, so the finds can take the words that are left.
    L = ["## What was asked", "", _short(record.question(p), cut["question"]) or "No question was written down for this project.", ""]

    L += ["## What was done", ""]
    for t in sorted(terrains.values(), key=lambda t: t.get("dataset") or "")[:1]:
        dataset = t.get("dataset") or ""
        kind = dataset.split(":")[0]
        where = ("a file a person added" if kind == "own" else f"a sonar survey of the seafloor from {t.get('source') or national.publisher(kind)}"
                 if t.get("seafloor") else f"open lidar from {t.get('source') or national.publisher(kind)}")
        L.append(f"- {_short(dataset.split(':', 1)[-1], 50)}, {_short(where, 70)}: {(t.get('area_km2') or 0):.2f} sq km, "
                 + (f"{record.density(t)} laser points per square metre reached the ground."
                    if isinstance(t.get("ground_points_per_m2"), (int, float)) else "a depth model built from it." if t.get("seafloor")
                    else "a ground model that was already built."))
    if len(terrains) > 1:
        L.append(f"- And {_s(len(terrains) - 1, 'more survey')}.")
    if tiles:
        parts = [f"{counts[v]} {w}" for v, w in record.VERDICT_WORDS.items() if counts[v]]
        left = sum(t["status"] == "unscreened" for t in tiles.values())
        L.append(f"- The ground was cut into {_s(len(tiles), 'square tile')}. {len(screened)} of {len(tiles)} "
                 f"{'was' if len(screened) == 1 else 'were'} looked at"
                 + (f": {', '.join(parts)}." if parts else ".")
                 + (f" {_s(unreadable, 'tile')} could not be read, because the laser did not reach the ground." if unreadable else "")
                 + (f" {_s(left, 'tile')} {'is' if left == 1 else 'are'} still to look at." if left else ""))
    elif not terrains:
        L.append("Nothing yet: no ground has been fetched.")
    L.append("")

    from .answers import score_lines
    L += score_lines(p, short=True)
    from .answers import calibration_lines
    L += calibration_lines(p)
    L += ["## What is already published", ""]
    sources = {title: {**item, "for": ["project"]} for title, item in ledger.project_sources(p).items()}
    for m in records:
        for s in m["sources"]:
            entry = sources.setdefault(s["title"], {**s, "for": []})
            entry["for"].append(m["id"])
            if s["status"] == "read":
                entry.update(status="read", finding=s["finding"], link=s.get("link") or entry.get("link", ""))
    read = [s for s in sources.values() if s["status"] == "read"]
    for s in read[:cut["sources"]]:
        link = f" ([link]({s['link']}))" if s.get("link") else ""
        L.append(f"- **{_short(s['title'], 70)}**{link}. {_first(s.get('finding', ''), cut["finding"])}")
    unopened = sum(s["status"] == "could_not_open" for s in sources.values())
    rest = [_s(len(read) - cut["sources"], "more source") + " read"] if len(read) > cut["sources"] else []
    rest += [f"{unopened} could not be opened by the agent"] if unopened else []
    if not read:
        L.append("No source has been read yet." if records else "Nothing was marked, so no source was read against a find.")
    if rest:
        text = " and ".join(rest)
        L.append(f"- {text[0].upper() + text[1:]}. The Sources tab lists them.")
    L.append("")

    ruled = [f"{_s(counts[v], 'tile')} showed {words}" for v, words in
             (("natural", "natural ground"), ("modern", "modern features"), ("nothing", "nothing built")) if counts[v]]
    if decided:
        if len(decided) <= 2:
            shown = "; ".join(f"{m['id']}, {ledger.LABELS.get(m['status'], m['status']).lower()}"
                              + (f", by {_short(m['decisions'][-1]['by'], 30)}" if m.get("decisions") else "") for m in decided)
        else:
            labels = [ledger.LABELS.get(m["status"], m["status"]).lower() for m in decided]
            shown = ", ".join(f"{labels.count(l)} {l}" for l in dict.fromkeys(labels))
        ruled.append(f"{_s(len(decided), 'find')} {'has' if len(decided) == 1 else 'have'} been decided: {shown}")
    L += ["## What was ruled out or decided", "", (". ".join(r[0].upper() + r[1:] for r in ruled) + ".") if ruled else "Nothing yet.", ""]

    L += ["## What to try next", ""]
    # The decisions have their own heading, and the record's "listed below" does not hold here.
    todo = [f"- {_short(_fewer(t), 90)}" for t in record.still_to_do(p) if not t.startswith(("Decide ", "Try the "))][:2]
    L += todo
    if advice:
        L += ([""] if todo else []) + [ADVICE + _first(advice, cut["advice"])]
    elif not todo:
        L.append("Nothing more: the decisions are what is left.")
    L += ["", "The full record of this project is in [RESEARCH.md](../RESEARCH.md).", ""]

    from .answers import test_state
    if test_state(p):
        # A blind test is scored against its key; its finds wait for no decision, and the score says what each was.
        D = ["## The finds", "", f"{_s(len(records), 'find')} marked. This is a blind test, so each is scored against the published "
             "key rather than decided; the scorecard above says which matched.", ""]
        return "\n".join(top + D + L), 0
    D = ["## What needs your decision", ""]
    # When the map service was down for every find, that is said once, under the finds.
    no_maps = bool(open_) and all("modern" not in m["checks"] and m["id"] in failed_maps for m in open_)
    closing = ["", "You decide each one, in Decide. The agent only suggests."]
    if no_maps:
        closing = ["", "Open maps could not be checked for modern features near "
                   + ("it" if len(open_) == 1 else "any of them") + ": the map service did not answer."] + closing
    room = LIMIT - count("\n".join(top + L + closing)) - 20  # 20 words for the heading and the line that counts the rest
    lines = []
    for m in open_:
        sug = m.get("suggestion")
        if sug:
            say = f"The agent suggests: {ledger.LABELS.get(sug['status'], sug['status']).lower()}. {_first(sug.get('reason', ''), cut["reason"])}"
        else:
            say = "No suggestion yet. " + (_first(m["evidence"][0], cut["reason"]) if m.get("evidence") else "")
        line = f"- **[{m['id']} {_short(m['name'], 45)}](../candidates/{m['id']}.md).** {say} {_checks(m, failed_maps, not no_maps)}"
        if lines and count("\n".join(lines + [line])) > room:
            break
        lines.append(line)
    D += lines
    if len(open_) > len(lines):
        D += ["", f"{_s(len(open_) - len(lines), 'more find')} wait{'s' if len(open_) - len(lines) == 1 else ''} for your decision. "
              "The research record and Decide list every one."]
    on_map = ledger.layer(records)
    if on_map:
        D += ["", f"{_s(len(on_map), 'measured rise')} {'are' if len(on_map) != 1 else 'is'} kept on the map, not put to you: "
              "the second model did not call them built, or their shape ranks low here. Decide lists them."]
    if open_:
        D += closing
    elif records:
        D.append("Nothing. Every find has been decided.")
    else:
        D.append("Nothing. No tile was marked as looking built.")
    D.append("")

    return "\n".join(top + D + L), len(lines)
