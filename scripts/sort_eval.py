"""Score the bulk look (triage.sort_tiles) on copies of saved blind tests against what the agent did on the same tiles:
how many tiles each sends for a closer look, and how many answer-key features sit on those tiles. The copies go to a
scratch folder; the saved runs are not changed. Prints no coordinates.

    uv run python scripts/sort_eval.py <saved blind test folder> ... [--model id]
"""

import json
import shutil
import sys
import tempfile
from pathlib import Path

import pyproj

from dighouse import answers, ledger, triage
from dighouse.project import Project

SHORT = ("possible", "built")


def feature_tiles(p, k):
    """Each counted feature of the key and the tiles it sits on."""
    terrains = p.load("terrains", {}) or {}
    all_tiles = p.load("tiles", {}) or {}
    out = {}
    for f in k["features"]:
        if not f["expect"]:
            continue
        pts = [(f["lon"], f["lat"])] if f["kind"] == "point" else [pt for line in f["lines"] for pt in line]
        here = set()
        for tid, t in all_tiles.items():
            meta = terrains.get(t["terrain"])
            if not meta:
                continue
            tr = pyproj.Transformer.from_crs(4326, meta["epsg"], always_xy=True)
            x0, y0, x1, y1 = meta["box"]
            r0, c0, h, w = t["window"]
            for lon, lat in pts:
                x, y = tr.transform(lon, lat)
                col, row = (x - x0) / meta["res"], (y1 - y) / meta["res"]
                if r0 <= row < r0 + h and c0 <= col < c0 + w:
                    here.add(tid)
        out[f["id"]] = here
    return out


def run(saved: str, model: str) -> dict:
    src = Path(saved)
    copy = Path(tempfile.mkdtemp(prefix="dh-sorteval-")) / src.name
    shutil.copytree(src, copy, ignore=shutil.ignore_patterns(".git"))
    p = Project(copy)
    state = json.loads((copy / "private/state/test.json").read_text())
    k = answers.key(state["key"])
    before = {tid: t.get("verdict") for tid, t in p.load("tiles", {}).items()}
    with p.change("tiles", {}) as t:
        for v in t.values():
            if v["status"] == "screened":
                v.update(status="unscreened", verdict=None, note=None, model=None)
    got = triage.sort_tiles(str(copy), model=model)
    short = {x["tile"] for x in got["shortlist"]}
    strict = {x["tile"] for x in got["shortlist"] if x["verdict"] in SHORT}  # without tiles shortlisted only for a spot
    after = {tid: ("possible" if tid in short else t.get("verdict")) for tid, t in p.load("tiles", {}).items()}
    ft = feature_tiles(p, k)
    score = json.loads((src / "private/state/score.json").read_text())
    records = {m["id"]: m for m in ledger.everything(Project(src))}
    seen = {m["feature"] for m in score["matches"] if m.get("counted") and not ledger.is_rise(records.get(m["find"], {"checks": {}, "flagged_by": ""}))}
    on = lambda verdicts, tids: any(verdicts.get(t) in SHORT for t in tids)
    strict_v = {tid: ("possible" if tid in strict else None) for tid in after}
    return {
        "site": k["name"], "tiles": len(before), "seconds": got["seconds"], "failed": len(got["failed"]),
        "agent_sent_closer": sum(v in SHORT for v in before.values()), "sort_sent_closer": sum(v in SHORT for v in after.values()),
        "features": len(ft), "on_agent_shortlist": sum(on(before, t) for t in ft.values()),
        "on_sort_shortlist": sum(on(after, t) for t in ft.values()),
        "seen_by_agent": len(seen), "seen_and_on_sort_shortlist": sum(on(after, ft.get(f, set())) for f in seen),
        "strict_sent_closer": len(strict), "on_strict_shortlist": sum(on(strict_v, t) for t in ft.values()),
        "seen_and_on_strict_shortlist": sum(on(strict_v, ft.get(f, set())) for f in seen),
        "verdicts_agent": {v: list(before.values()).count(v) for v in set(before.values())},
        "verdicts_sort": got["verdicts"],
    }


def pipeline(saved: str, model: str) -> dict:
    """The whole search without the agent on a copy of a saved blind test: the bulk look, a find for each shape it pointed
    at, the measured rises, scored against the key; beside the saved run's own score."""
    from dighouse import server
    src = Path(saved)
    copy = Path(tempfile.mkdtemp(prefix="dh-pipeline-")) / src.name
    shutil.copytree(src, copy, ignore=shutil.ignore_patterns(".git"))
    p = Project(copy)
    state = json.loads((copy / "private/state/test.json").read_text())
    k = answers.key(state["key"])
    for f in (copy / "candidates").glob("C-*.md"):
        f.unlink()
    p.save("locations", {})
    with p.change("tiles", {}) as t:
        for v in t.values():
            if v["status"] == "screened":
                v.update(status="unscreened", verdict=None, note=None, model=None)
    p.save("test", {**state, "blind": True})
    got = triage.sort_tiles(str(copy), model=model)
    seen = triage.mark_spots(str(copy), got["shortlist"], model=model)
    rises = server.add_measured_rises(str(copy))
    places = p.load("locations", {}) or {}
    result = answers.score(k, {cid: {"lon": v["lon"], "lat": v["lat"]} for cid, v in places.items()})
    area = sum((m.get("area_km2") or 0) for m in (p.load("terrains", {}) or {}).values())
    saved_score = json.loads((src / "private/state/score.json").read_text())
    return {"site": k["name"], "known": result["known"],
            "found_without_agent": result["found"], "extra_per_km2_without_agent": round(len(result["extra"]) / area, 1) if area else None,
            "seen_in_bulk": seen["count"], "measured_rises": rises["count"], "sort_seconds": got["seconds"],
            "found_saved_run": saved_score["found"], "extra_per_km2_saved_run": saved_score.get("extra_per_km2")}


if __name__ == "__main__":
    model = sys.argv[sys.argv.index("--model") + 1] if "--model" in sys.argv else ""
    folders = [a for a in sys.argv[1:] if not a.startswith("--") and a != model]
    for f in folders:
        print(json.dumps(pipeline(f, model) if "--pipeline" in sys.argv else run(f, model)), flush=True)
