"""Answer keys for blind tests on known sites, and how a run's finds are scored against them.

A key lists the published features inside a fixed test area. Each feature is a point with a size (a mound) or a
work drawn as lines (a rampart, an effigy, an enclosure wall). The keys hold coordinates, so they stay with the
tools' own data. What leaves this module for a person or a record (a scorecard, a comparison) never holds any.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

KEYS = Path(__file__).parent / "keys"
POINT_SLACK_M = 15   # a find may sit this far beyond a mound's edge and still be on it: tiles are coarse, mounds are soft-edged
WORK_REACH_M = 20    # how close to a rampart or wall line a find must be


def keys() -> list[dict]:
    return [json.loads(f.read_text()) for f in sorted(KEYS.glob("*.json"))]


def key(site: str) -> dict:
    f = KEYS / f"{site}.json"
    if not f.exists():
        raise ValueError(f"No answer key called {site!r}. Known: {[k['id'] for k in keys()]}")
    return json.loads(f.read_text())


def summary(k: dict) -> dict:
    """What a person may see about a key: no coordinates."""
    counted = [f for f in k["features"] if f["expect"]]
    kinds: dict[str, int] = {}
    for f in counted:
        kinds[f["what"]] = kinds.get(f["what"], 0) + 1
    return {"id": k["id"], "name": k["name"], "place": k["place"], "data": k["data"], "coverage": k["coverage"],
            "counted": len(counted), "kinds": kinds, "published": k["published"], "sources": [s["cite"] for s in k["sources"]]}


def _metres(lon: float, lat: float, lon0: float, lat0: float) -> tuple[float, float]:
    return (lon - lon0) * 111_320 * math.cos(math.radians(lat0)), (lat - lat0) * 110_540


def _to_segment(p, a, b) -> float:
    ux, uy = b[0] - a[0], b[1] - a[1]
    t = 0.0 if not (ux or uy) else max(0.0, min(1.0, ((p[0] - a[0]) * ux + (p[1] - a[1]) * uy) / (ux * ux + uy * uy)))
    return math.hypot(a[0] + t * ux - p[0], a[1] + t * uy - p[1])


def _inside(p, ring) -> bool:
    x, y, hit = p[0], p[1], False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            hit = not hit
    return hit


def distance_m(feature: dict, lon: float, lat: float) -> float:
    """How far a spot is from a feature: from a mound's centre, or from the nearest line of a work (0 inside an area)."""
    if feature["kind"] == "point":
        return math.hypot(*_metres(lon, lat, feature["lon"], feature["lat"]))
    best = math.inf
    for line in feature["lines"]:
        pts = [_metres(x, y, lon, lat) for x, y in line]
        if feature.get("area") and len(pts) > 2 and _inside((0.0, 0.0), pts):
            return 0.0
        for a, b in zip(pts, pts[1:] or pts):
            best = min(best, _to_segment((0.0, 0.0), a, b))
    return best


def reach_m(feature: dict) -> float:
    return feature["size_m"] / 2 + POINT_SLACK_M if feature["kind"] == "point" else WORK_REACH_M


def score(k: dict, finds: dict[str, dict]) -> dict:
    """Score finds ({id: {"lon", "lat", "name"?}}) against a key.

    Each mound takes at most one find, the nearest within its reach, and each find counts once. A find on a work
    marks the work found; more finds on the same work are listed as on it, not as extra. A find on a feature the key
    does not count (gone, or not expected in lidar) is listed as such, not as extra. Every other find is extra:
    after the literature search a person labels it a false alarm or worth a second look.
    """
    feats = k["features"]
    pairs = sorted((distance_m(f, v["lon"], v["lat"]), fid, f["id"]) for fid, v in finds.items()
                   for f in feats if f["kind"] == "point" and distance_m(f, v["lon"], v["lat"]) <= reach_m(f))
    matched: dict[str, str] = {}   # find id -> feature id
    taken: set[str] = set()
    for _, fid, kid in pairs:
        if fid not in matched and kid not in taken:
            matched[fid] = kid
            taken.add(kid)
    on_work: dict[str, list[str]] = {}
    for fid, v in finds.items():
        if fid in matched:
            continue
        for f in feats:
            if f["kind"] == "work" and distance_m(f, v["lon"], v["lat"]) <= reach_m(f):
                on_work.setdefault(f["id"], []).append(fid)
                break
    by_id = {f["id"]: f for f in feats}
    found_ids = taken | set(on_work)
    counted = [f for f in feats if f["expect"]]
    found = [f for f in counted if f["id"] in found_ids]
    missed = [f for f in counted if f["id"] not in found_ids]
    placed = set(matched) | {fid for ids in on_work.values() for fid in ids}
    extra = sorted(fid for fid in finds if fid not in placed)
    rows = [{"find": fid, "feature": kid, "what": by_id[kid]["what"], "counted": by_id[kid]["expect"]} for fid, kid in sorted(matched.items())]
    rows += [{"find": fid, "feature": kid, "what": by_id[kid]["what"], "counted": by_id[kid]["expect"], "on_work": True}
             for kid, ids in sorted(on_work.items()) for fid in ids]
    return {
        "site": k["name"], "coverage": k["coverage"],
        "known": len(counted), "found": len(found),
        "found_share": round(len(found) / len(counted), 2) if counted else None,
        "missed": [{"feature": f["id"], "what": f["what"], "source": f["source"]} for f in missed],
        "extra": extra,
        "matches": rows,
        "note": ("The key comes from an official register." if k["coverage"] == "register" else
                 "The key holds only the features mapped in open data, so an extra find may be a real feature the key leaves out. "
                 "The literature step labels each one."),
    }


def auto_key(box: list[float]) -> dict:
    """A key built from open records for any area: incomplete by nature, and marked so."""
    from .discover import recorded_sites
    sites, silent = recorded_sites(box)
    feats = [{"id": f"AUTO-{i:02d}", "what": s.get("kind") or "Recorded site", "kind": "point", "lon": s["lon"], "lat": s["lat"],
              "size_m": 30, "expect": True, "source": f"{s['source']}: {s.get('name', '')}".strip(": ")} for i, s in enumerate(sites, 1)]
    return {"id": "automatic", "name": "Automatic key", "place": "", "data": "", "box": box, "coverage": "automatic",
            "published": "Built from OpenStreetMap, Wikidata, the National Register and Pleiades. It lists only what those hold, "
                         "usually a fraction of what is there." + (f" Did not answer: {'; '.join(silent)}." if silent else ""),
            "sources": [{"cite": "OpenStreetMap, Wikidata, the National Register of Historic Places and Pleiades"}], "features": feats}


def compare(curated: dict, automatic: dict) -> dict:
    """How much of a curated key an automatic key for the same area holds. No coordinates."""
    counted = [f for f in curated["features"] if f["expect"]]
    held = [f for f in counted if any(distance_m(f, a["lon"], a["lat"]) <= reach_m(f) + 15 for a in automatic["features"])]
    return {"site": curated["name"], "curated": len(counted), "automatic_sites": len(automatic["features"]),
            "held": len(held), "missing": [f"{f['id']} {f['what']}" for f in counted if f not in held]}

