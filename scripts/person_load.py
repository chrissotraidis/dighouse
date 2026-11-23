"""What a person is shown after a blind test, per km²: the finds not kept on the map, and the finds outside the answer key
among them (false flags a person has to rule out), under the rule that kept only measured rises on the map and under the
rule that also keeps the bulk look's untaken finds (FIND_LOOP G3). Read-only; prints no coordinates.

    uv run python scripts/person_load.py <blind test folder> ...
"""

import json
import sys
from pathlib import Path

from dighouse import ledger
from dighouse.project import Project


def old_layer(records):
    ranks = sorted(ledger._rank(m) for m in records if ledger.is_rise(m))
    if not ranks:
        return set()
    cut = ranks[min(int(len(ranks) * (1 - ledger.RISE_SHARE)), len(ranks) - 1)]
    return {m["id"] for m in records if ledger.is_rise(m) and m["status"] in ("flagged", "ground_confirmed") and not m.get("raised")
            and not (m["checks"].get("second_look", {}).get("agrees") is True and ledger._rank(m) >= cut)}


for folder in sys.argv[1:]:
    p = Project(Path(folder))
    score = json.loads((p.root / "private/state/score.json").read_text())
    records = ledger.everything(p)
    extra, km2 = set(score["extra"]), score.get("area_km2") or 1
    row = {"site": score["key"]["name"], "found": f"{score['found']}/{score['known']}", "finds": len(records),
           "second_opinions": sum(bool(m["checks"].get("second_look")) for m in records)}
    for name, kept in (("old", old_layer(records)), ("new", ledger.layer(records))):
        shown = [m["id"] for m in records if m["id"] not in kept]
        row[f"shown_per_km2_{name}"] = round(len(shown) / km2, 1)
        row[f"false_flags_shown_per_km2_{name}"] = round(len([c for c in shown if c in extra]) / km2, 1)
    print(json.dumps(row, ensure_ascii=False))
