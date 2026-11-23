"""Where finds stop: for each project, how much ground was fetched and looked at, how many finds were made, how many were
put to a person, how many a person decided, and how many reached an answer. Read-only; it changes no project."""

from __future__ import annotations

import json
import plistlib
import subprocess
from pathlib import Path

from . import ledger
from .project import Project

ANSWERED = ("no_match_in_sources_read", "reported")


def funnel(root: str) -> dict:
    """One project's funnel. Blind tests are marked, since their finds are scored, not decided."""
    p = Project(Path(root))
    state = p.root / "private" / "state"
    terrains = json.loads((state / "terrains.json").read_text()) if (state / "terrains.json").exists() else {}
    tiles = json.loads((state / "tiles.json").read_text()) if (state / "tiles.json").exists() else {}
    km2 = sum(t.get("area_km2") or 0 for t in terrains.values())
    looked = sum(t["status"] in ("screened", "unreadable") for t in tiles.values())
    records = ledger.everything(p)
    on_map = ledger.layer(records)
    waiting = [m for m in records if m["status"] in ("flagged", "ground_confirmed")]
    return {
        "project": p.root.name,
        "blind_test": (state / "test.json").exists(),
        "surveys": sorted({(t.get("dataset") or "?").split(":")[0] for t in terrains.values()}),
        "km2_fetched": round(km2, 2),
        "km2_looked_at": round(km2 * looked / len(tiles), 2) if tiles else 0.0,
        "finds": len(records),
        "measured_rises": sum(ledger.is_rise(m) for m in records),
        "to_a_person": len([m for m in waiting if m["id"] not in on_map]) + sum(bool(m.get("decisions")) for m in records),
        "decided": sum(bool(m.get("decisions")) for m in records),
        "answered": sum(m["status"] in ANSWERED for m in records),
    }


def totals(rows: list[dict]) -> dict:
    """The funnel summed over projects that are not blind tests."""
    keys = ("km2_fetched", "km2_looked_at", "finds", "measured_rises", "to_a_person", "decided", "answered")
    live = [r for r in rows if not r["blind_test"]]
    out = {k: round(sum(r[k] for r in live), 2) for k in keys}
    out["projects"] = len(live)
    out["finds_per_km2_looked_at"] = round(out["finds"] / out["km2_looked_at"], 1) if out["km2_looked_at"] else None
    return out


def app_projects() -> list[str]:
    raw = subprocess.run(["defaults", "export", "com.chrissotraidis.dighouse", "-"], capture_output=True).stdout
    try:
        return [p["path"] for p in json.loads(plistlib.loads(raw)["projects"])]
    except (KeyError, ValueError, plistlib.InvalidFileException):
        return []
