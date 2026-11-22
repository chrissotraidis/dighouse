
import os, json, math, sys
from dighouse import answers, ledger, server
from dighouse.project import Project
runs = {"borre":"blind-test-2026-11-21-5","mound-city":"blind-test-2026-11-21-6","maiden-castle":"blind-test-2026-11-21-7","cahokia":"blind-test-2026-11-21-8","andia":"blind-test-2026-11-21-9"}
cap = float(sys.argv[1]) if len(sys.argv) > 1 else 50
min_h = float(sys.argv[2]) if len(sys.argv) > 2 else 0.25
for key, run in runs.items():
    p = Project(os.path.expanduser("~/Dighouse/" + run))
    k = answers.key(key)
    places = p.load("locations", {})
    agent = {m["id"]: {"lon": places[m["id"]]["lon"], "lat": places[m["id"]]["lat"]} for m in ledger.everything(p)
             if not m["flagged_by"].startswith("measured") and m["id"] in places}
    tiles_ = p.load("tiles", {}); terr = p.load("terrains", {})
    area = sum(t["window"][2]*t["window"][3]*terr[t["terrain"]]["res"]**2/1e6 for t in tiles_.values() if t.get("verdict") in ("possible","built"))
    alone = answers.score(k, agent)
    line = f"{key:14s} agent {alone['found']}/{alone['known']} extra {len(alone['extra'])}"
    for order, verdicts in (("shape", ("possible","built")), ("travel", ("possible","built")), ("travel-all", ("possible","built","natural","modern"))):
        rises = server.measured_rises(p, cap, verdicts=verdicts, exclude=agent, order=order.split("-")[0], min_h=min_h)
        both = answers.score(k, {**agent, **{f"R{i}": {"lon": r["lon"], "lat": r["lat"]} for i, r in enumerate(rises)}})
        allarea = sum(t["window"][2]*t["window"][3]*terr[t["terrain"]]["res"]**2/1e6 for t in tiles_.values())
        line += f" | {order}: {both['found']}/{both['known']} (+{len(rises)} rises, {len(both['extra'])/allarea:.0f} extra/km2)"
    print(line, f"[possible/built area {area:.2f} km2]")

