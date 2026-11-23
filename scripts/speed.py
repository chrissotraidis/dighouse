"""Time the stages of a search on a few km2 of ready-made ground: fetch, cut tiles, draw them, measure rises. The
baseline G1 of FIND_LOOP has to beat. Prints no coordinates.

    uv run python scripts/speed.py [dataset] [side_km] [--bulk]
"""

import json
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import coverage  # noqa: E402
from dighouse import national, server  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith("--")]
dataset = args[0] if args else "no:nhm-dtm-1m"
coverage.SIDE_KM = float(args[1]) if len(args) > 1 else 2.0
box = coverage.box_around(*coverage.inside_point(national.NATIONAL[dataset]["outline"]))
root = tempfile.mkdtemp(prefix="dh-speed-")
server.init_project(root, "speed", "How long does each stage take?", *box)
times, t = {}, time.time()


def lap(name):
    global t
    times[name] = round(time.time() - t, 1)
    t = time.time()


got = server.fetch_terrain(root, dataset, *box); lap("fetch")
made = server.make_tiles(root, got["terrain"]); lap("cut tiles")
server.render_tiles(root, "sky_view"); server.render_tiles(root, "composite"); lap("draw two views")
ids = server.next_tiles(root, 10_000)
if "--bulk" in sys.argv:
    # The search as a long session runs it before the agent looks closely: the bulk look, then the measured rises.
    looked = server.look_at_tiles(root); lap("bulk look")
    server.add_measured_rises(root); lap("measured rises")
    extra = {"shortlist": len(looked["shortlist"]), "finds_opened": len(looked["finds_opened"])}
else:
    spots = sum(len(server.find_mounds(root, i)[0:1]) for i in ids); lap("measure rises")
    extra = {}
km2 = got.get("area_km2") or coverage.SIDE_KM ** 2
total = sum(times.values())
print(json.dumps({"dataset": dataset, "km2": round(km2, 2), "tiles": len(ids), "seconds": times,
                  "seconds_per_km2": round(total / km2, 1), "km2_per_hour_without_the_agent": round(3600 * km2 / total, 1), **extra}))
