"""Probe every source of ready-made ground, and USGS's points, on about 1 km2 each: does it answer, how much of the box
it covers, and how long the fetch takes. Prints no coordinates. G0 of FIND_LOOP.

    uv run python scripts/coverage.py [--json] [dataset ...]
"""

import json
import math
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from dighouse import national, server  # noqa: E402
from smoke_test import BOX  # noqa: E402

SIDE_KM = 1.0


def inside_point(ring):
    """A point inside a country's outline, near the middle of its vertices."""
    cx, cy = sum(x for x, _ in ring) / len(ring), sum(y for _, y in ring) / len(ring)
    if national._inside(cx, cy, ring):
        return cx, cy
    xs, ys = [x for x, _ in ring], [y for _, y in ring]
    grid = [(min(xs) + (max(xs) - min(xs)) * i / 20, min(ys) + (max(ys) - min(ys)) * j / 20) for i in range(21) for j in range(21)]
    return min((p for p in grid if national._inside(*p, ring)), key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)


def box_around(x, y):
    dy = SIDE_KM / 110.574 / 2
    dx = SIDE_KM / (111.32 * math.cos(math.radians(y))) / 2
    return [x - dx, y - dy, x + dx, y + dy]


def probe(dataset, box):
    root = tempfile.mkdtemp(prefix="dh-coverage-")
    server.init_project(root, "coverage probe", "Does the source answer?", *box)
    start = time.time()
    try:
        got = server.fetch_terrain(root, dataset, *box)
    except Exception as exc:  # a source that fails is a result, not a stop
        return {"dataset": dataset, "ok": False, "seconds": round(time.time() - start, 1), "problem": str(exc)[:160]}
    secs = time.time() - start
    km2 = got.get("area_km2") or SIDE_KM ** 2
    return {"dataset": dataset, "ok": True, "seconds": round(secs, 1), "seconds_per_km2": round(secs / km2, 1),
            "share_covered": round(1 - (got.get("share_outside_survey") or 0), 2), "res_m": got.get("res"),
            "ready_made": bool(got.get("ready_made_ground_model"))}


def main():
    wanted = [a for a in sys.argv[1:] if not a.startswith("--")]
    rows = []
    for key, d in national.NATIONAL.items():
        if wanted and key not in wanted:
            continue
        if d.get("catalog") == "noaa":   # survey strips: a box in the middle of a country tells nothing
            rows.append({"dataset": key, "ok": None, "problem": "seafloor survey strips; probed by the live tests"})
            continue
        rows.append(probe(key, box_around(*inside_point(d["outline"]))))
        print(json.dumps(rows[-1]), flush=True)
    if not wanted or any(w.startswith("usgs") for w in wanted):
        box = box_around((BOX[0] + BOX[2]) / 2, (BOX[1] + BOX[3]) / 2)
        usgs = next((x["id"] for x in server.find_data(*box) if x.get("id", "").startswith("usgs:")), None)
        rows.append(probe(usgs, box) if usgs else {"dataset": "usgs", "ok": False, "problem": "no USGS survey found"})
        print(json.dumps(rows[-1]), flush=True)
    if "--json" in sys.argv:
        from dighouse import sources
        out = sources.cache_dir() / "coverage.json"
        out.write_text(json.dumps(rows, indent=1))
        print(f"written to {out}")


if __name__ == "__main__":
    main()
