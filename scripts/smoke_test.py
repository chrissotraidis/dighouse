"""Smoke test: one tile, end to end, through the real tools and services, in about a minute.

Run with: uv run python scripts/smoke_test.py
It fetches a small square at Cahokia from USGS 3DEP (cached after the first run), cuts one tile, renders it, marks
Monks Mound, cuts a slice through it, checks open maps, scores it as a blind test and rebuilds the record.
No model is used. A failure names the step.
"""

from __future__ import annotations

import json
import sys
import tempfile
import time
from pathlib import Path

from dighouse import answers, ledger, server
from dighouse.project import Project

BOX = [-90.0638, 38.6592, -90.0604, 38.6620]  # Monks Mound and a little around it


def step(name, fn):
    t0 = time.time()
    try:
        out = fn()
    except Exception as exc:
        print(f"FAIL  {name}: {exc}")
        sys.exit(1)
    print(f"ok    {name} ({time.time() - t0:.1f} s)")
    return out


def main() -> None:
    start = time.time()
    folder = Path(tempfile.mkdtemp(prefix="dighouse-smoke-"))
    root = step("start a blind test", lambda: answers.start(folder, "cahokia")["project"])
    p = Project(root)
    p.save("project", {**p.load("project"), "bbox": BOX})
    data = step("find data", lambda: next(d["id"] for d in server.find_data(*BOX) if d.get("id", "").startswith("usgs:")))
    got = step("fetch the ground", lambda: server.fetch_terrain(root, data, *BOX))
    step("cut tiles", lambda: server.make_tiles(root, got["terrain"], tile_m=400))
    tile = step("pick a tile", lambda: server.next_tiles(root, 1)[0])
    step("render it in sky view", lambda: server.view_tile(root, tile, "sky_view"))
    step("record a verdict", lambda: server.record_verdict(root, tile, "built", "smoke test", "smoke"))
    step("mark Monks Mound", lambda: server.flag_candidate(root, tile, 0.5, 0.5, "Large platform mound", "Guide: platform mound.", "smoke"))
    stats = step("cut a slice", lambda: json.loads(server.cut_section(root, tile, 0.5, 0.05, 0.5, 0.95, "C-001")[0]))
    if not (stats.get("feature_height_m", 0) > 15 and stats.get("in_ground")):
        print(f"FAIL  the slice did not show Monks Mound in the ground: {stats.get('feature_height_m')} m")
        sys.exit(1)
    try:
        server.check_modern(root, "C-001")
        print("ok    check open maps")
    except Exception as exc:  # the public map services are often busy; that is not a failure of Dighouse
        print(f"skip  check open maps: {str(exc)[:100]}")
    score = step("score the blind test", lambda: server.score_test(root))
    if score["found"] != 1:
        print(f"FAIL  Monks Mound was not matched in the score: {score}")
        sys.exit(1)
    step("rebuild the research record", lambda: server.document_project(root))
    print(f"passed in {time.time() - start:.0f} s, slice {stats['feature_height_m']:.1f} m, score {score['found']} of {score['known']}")


if __name__ == "__main__":
    main()

