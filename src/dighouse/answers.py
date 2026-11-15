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
    # Counted features are matched first, so a find on a mound is never given to an uncounted thing beside it
    # (at Angel Mounds, the reconstructed house 15 m from a find on Mound A, 36 m away). Then nearest first.
    pairs = sorted((not f["expect"], distance_m(f, v["lon"], v["lat"]), fid, f["id"]) for fid, v in finds.items()
                   for f in feats if f["kind"] == "point" and distance_m(f, v["lon"], v["lat"]) <= reach_m(f))
    matched: dict[str, str] = {}   # find id -> feature id
    taken: set[str] = set()
    for _, _, fid, kid in pairs:
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



# ---------------------------------------------------------------- blind tests

BLIND = ("This is a blind test: the agent is not told what is here, and the literature and records for this area stay closed "
         "until score_test has scored the finds. Look at the tiles, mark finds, slice them and get a second opinion first.")


def _registry_file() -> Path:
    from .sources import cache_dir
    return cache_dir() / "blind-tests.json"


def _registry() -> dict:
    f = _registry_file()
    return json.loads(f.read_text()) if f.exists() else {}


def _save_registry(reg: dict) -> None:
    _registry_file().write_text(json.dumps(reg, indent=1))


def start(folder: str | Path, site: str) -> dict:
    """Create a blind-test project for a key's area. Its name, question and folder say nothing about the place."""
    from .project import Project, today
    k = key(site)
    folder = Path(folder).expanduser()
    n = 1
    while (folder / f"blind-test-{today()}-{n}").exists():
        n += 1
    root = folder / f"blind-test-{today()}-{n}"
    p = Project.create(root, f"Blind test {today()} {n}", "What built features show in the ground here?", k["box"])
    p.save("test", {"key": site, "blind": True, "started": today(), "started_at": __import__("time").time()})
    reg = _registry()
    reg[str(p.root)] = {"key": site, "box": k["box"]}
    _save_registry(reg)
    return {"project": str(p.root), "name": f"Blind test {today()} {n}", "question": "What built features show in the ground here?",
            "box": k["box"]}


def test_state(p) -> dict | None:
    return p.load("test")


def is_blind(p) -> bool:
    t = test_state(p)
    return bool(t and t.get("blind"))


def guard_project(p) -> None:
    if is_blind(p):
        raise ValueError(BLIND)


def blind_box(box: list[float]) -> bool:
    """Whether a box overlaps the area of a blind test that has not been scored yet."""
    w, s, e, n = box
    for t in _registry().values():
        bw, bs, be, bn = t["box"]
        if w < be and e > bw and s < bn and n > bs:
            return True
    return False


def guard_box(box: list[float]) -> None:
    if any(box) and blind_box(box):
        raise ValueError(BLIND)


def score_project(p) -> dict:
    """Score a blind test's finds against its key, write the score into the project, and open the literature."""
    from . import ledger
    t = test_state(p)
    if not t:
        raise ValueError("This project is not a blind test.")
    k = key(t["key"])
    places = p.load("locations", {}) or {}
    names = {m["id"]: m["name"] for m in ledger.everything(p)}
    finds = {cid: {"lon": v["lon"], "lat": v["lat"]} for cid, v in places.items() if cid in names}
    result = score(k, finds)
    result["key"] = summary(k)
    result["scored"] = __import__("datetime").date.today().isoformat()
    result["finds"] = {cid: names[cid] for cid in finds}
    models: dict[str, int] = {}
    for m in ledger.everything(p):
        models[m.get("flagged_by") or "unnamed"] = models.get(m.get("flagged_by") or "unnamed", 0) + 1
    result["model"] = max(models, key=models.get) if models else ""
    if t.get("started_at"):
        result["minutes"] = round((__import__("time").time() - t["started_at"]) / 60)
    try:
        result["pictures"] = _pictures(p, k, finds, result)
    except Exception as exc:  # a scorecard without pictures is still a score
        result["pictures"] = {"problem": str(exc)[:200]}
    p.save("score", result)
    t.update(blind=False, scored=result["scored"])
    p.save("test", t)
    reg = _registry()
    reg.pop(str(p.root), None)
    _save_registry(reg)
    p.note(f"Blind test scored against {k['name']}: {result['found']} of {result['known']} found, "
           f"{len(result['missed'])} missed, {len(result['extra'])} extra")
    return result


def labels(p, result: dict) -> dict[str, str]:
    """What each extra find turned out to be, from its decision or the agent's suggestion after the literature step."""
    from . import ledger
    out = {}
    for m in ledger.everything(p):
        if m["id"] not in result.get("extra", []):
            continue
        status = (m.get("decisions") or [{}])[-1].get("status") if m.get("decisions") else (m.get("suggestion") or {}).get("status")
        out[m["id"]] = {"modern": "false alarm (modern)", "natural": "false alarm (natural)",
                        "already_published": "real, but not in the key", "no_match_in_sources_read": "worth a second look"}.get(status, "not yet labelled")
    return out


def score_lines(p, short: bool = False) -> list[str]:
    """The blind test's score in plain Markdown for the record, or one sentence for the report, or nothing. No coordinates."""
    t = test_state(p)
    if not t:
        return []
    if t.get("blind"):
        return ["## Blind test", "", "This project is a blind test on a known site. What the site is, and the score, are shown once "
                "score_test has compared the finds with the published answer key.", ""]
    s = p.load("score")
    if not s:
        return []
    names = s.get("finds", {})
    lab = labels(p, s)
    if short:
        kinds: dict[str, int] = {}
        for v in lab.values():
            kinds[v] = kinds.get(v, 0) + 1
        extra = f", {len(s['extra'])} not in the key" + (f" ({', '.join(f'{n} {k}' for k, n in kinds.items())})" if kinds else "")
        return ["## Blind test", "", f"Scored against {s['key']['name']}'s published answer key: {s['found']} of {s['known']} found, "
                f"{len(s['missed'])} missed{extra}. The research record lists each one.", ""]
    L = ["## Blind test", "", f"Scored {s['scored']} against {s['key']['name']} ({s['key']['place']}): "
         f"**{s['found']} of {s['known']}** features in the answer key found, {len(s['missed'])} missed, "
         f"{len(s['extra'])} find{'s' if len(s['extra']) != 1 else ''} not in the key.", ""]
    if s["missed"]:
        L.append("Missed: " + "; ".join(f"{m['feature']} {m['what']}" for m in s["missed"][:12])
                 + (f"; and {len(s['missed']) - 12} more" if len(s["missed"]) > 12 else "") + ".")
        L.append("")
    if s["extra"]:
        L.append("Not in the key:")
        L += [f"- {cid} {names.get(cid, '')}: {lab.get(cid, 'not yet labelled')}" for cid in s["extra"]]
        L.append("")
    L += [s["note"], "", "The key: " + s["key"]["published"] + " Sources: " + "; ".join(s["key"]["sources"]) + ".", ""]
    return L


def _pictures(p, k: dict, finds: dict, result: dict) -> dict:
    """Draw the scorecard's pictures under private/: the ground with the key's features (tan) and the finds (green),
    and a close-up of each missed feature and each extra find. Returns their paths, relative to the project."""
    from PIL import Image, ImageDraw
    import pyproj
    from . import terrain as T
    terrains = p.load("terrains", {}) or {}
    if not terrains:
        return {}
    meta = max(terrains.values(), key=lambda t: t.get("area_km2") or 0)
    dtm, gap, outside = T.load_terrain(p.path(meta["file"]))
    img = T.render(dtm, gap, outside, meta["res"], "composite").convert("RGB")
    x0, _, _, y1 = meta["box"]
    res = meta["res"]
    to_xy = pyproj.Transformer.from_crs(4326, meta["epsg"], always_xy=True)

    def px(lon, lat):
        x, y = to_xy.transform(lon, lat)
        return (x - x0) / res, (y1 - y) / res

    out_dir = p.path("private", "state", "score")
    out_dir.mkdir(parents=True, exist_ok=True)
    found_ids = {r["feature"] for r in result["matches"]}
    big = img.copy()
    d = ImageDraw.Draw(big)
    w = max(2, round(img.width / 400))
    for f in k["features"]:
        colour = (214, 170, 96) if f["id"] in found_ids else (232, 120, 80)
        if not f["expect"]:
            colour = (150, 150, 150)
        if f["kind"] == "point":
            cx, cy = px(f["lon"], f["lat"])
            r = max(f["size_m"] / 2 / res, 4 * w)
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=colour, width=w)
        else:
            for line in f["lines"]:
                d.line([px(x, y) for x, y in line], fill=colour, width=w)
    for fid, v in finds.items():
        cx, cy = px(v["lon"], v["lat"])
        r = 3 * w
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(120, 200, 110), outline=(20, 40, 20))
    big.thumbnail((1400, 1400))
    big.save(out_dir / "map.png")
    pics = {"map": "private/state/score/map.png", "close": {}}

    def crop(name, lon, lat, metres=120.0):
        cx, cy = px(lon, lat)
        half = metres / 2 / res
        box = (round(cx - half), round(cy - half), round(cx + half), round(cy + half))
        c = img.crop(box).resize((360, 360), Image.LANCZOS)
        dd = ImageDraw.Draw(c)
        dd.ellipse([172, 172, 188, 188], outline=(232, 120, 80), width=3)
        c.save(out_dir / f"{name}.png")
        pics["close"][name] = f"private/state/score/{name}.png"

    by_id = {f["id"]: f for f in k["features"]}
    for m in result["missed"]:
        f = by_id[m["feature"]]
        lon, lat = (f["lon"], f["lat"]) if f["kind"] == "point" else f["lines"][0][len(f["lines"][0]) // 2]
        crop(m["feature"], lon, lat)
    for fid in result["extra"]:
        crop(fid, finds[fid]["lon"], finds[fid]["lat"])
    return pics


# ---------------------------------------------------------------- calibration

PASS_SHARE = 0.5   # a search for something new goes ahead only if the method found at least half of a known site nearby
SOURCE_OF = {"usgs": "USGS 3DEP", "uk": "Environment Agency", "no": "Kartverket", "nl": "AHN", "fr": "IGN", "ot": "OpenTopography"}


def _key_source(k: dict) -> str:
    d = k["data"].lower()
    return next((v for v in SOURCE_OF.values() if v.lower().split()[0] in d), k["data"])


def calibration_site(box: list[float], dataset: str = "") -> dict:
    """The known site that will calibrate a search of this area: the nearest key whose lidar comes from the same source."""
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    want = SOURCE_OF.get(dataset.split(":")[0], "") if dataset else ""
    rows = []
    for k in keys():
        kx, ky = (k["box"][0] + k["box"][2]) / 2, (k["box"][1] + k["box"][3]) / 2
        km = math.hypot((kx - cx) * 111.32 * math.cos(math.radians(cy)), (ky - cy) * 110.54)
        rows.append((not want or _key_source(k) == want, -km, k))
    same = [r for r in rows if r[0]] or rows
    _, neg_km, k = max(same, key=lambda r: r[1])
    return {"site": k["id"], "name": k["name"], "place": k["place"], "data": k["data"], "km_away": round(-neg_km),
            "same_source": _key_source(k) == want if want else None,
            "how": f"start_test with site {k['id']}, run it blind to score_test, then record_calibration on this project."}


def record_calibration(p, test_root: str) -> dict:
    """Copy a scored calibration test's result into the search project. A poor score stops the search."""
    from .project import Project
    test = Project(test_root)
    s = test.load("score")
    if not s:
        raise ValueError("That calibration test has not been scored yet. Finish it with score_test first.")
    share = s.get("found_share") or 0
    out = {"site": s["site"], "found": s["found"], "known": s["known"], "missed": len(s["missed"]), "extra": len(s["extra"]),
           "found_share": share, "passed": share >= PASS_SHARE, "pass_mark": PASS_SHARE, "scored": s.get("scored"),
           "model": s.get("model", ""), "test": test.root.name}
    p.save("calibration", out)
    p.note(f"Calibrated on {s['site']}: {s['found']} of {s['known']} found" + ("" if out["passed"] else ", below the pass mark; the search stops here"))
    return out


def calibration(p) -> dict | None:
    return p.load("calibration")


def guard_calibration(p) -> None:
    c = calibration(p)
    if c and not c["passed"]:
        raise ValueError(f"The calibration on {c['site']} found {c['found']} of {c['known']} known features, below the pass mark "
                         f"of {int(PASS_SHARE * 100)}%. A search for something new here would not be trusted, so finds are not "
                         "marked. Say so plainly, write the summary, and suggest another survey, view or area.")


def calibration_lines(p) -> list[str]:
    c = calibration(p)
    if not c:
        return []
    verdict = "passed" if c["passed"] else f"failed (the pass mark is {int(c['pass_mark'] * 100)}%), so the search stopped"
    return ["## Calibration", "", f"Before searching here, the method was tested blind on {c['site']}: {c['found']} of {c['known']} "
            f"known features found, {c['missed']} missed, {c['extra']} not in the key. The calibration {verdict}.", ""]


# ---------------------------------------------------------------- early check against open records

def on_record_near(p, lon: float, lat: float, reach_m: float = 120) -> list[dict]:
    """Sites on open record near a new find, from a list read once for the project's area. No coordinates returned."""
    if is_blind(p):
        return []
    sites = p.load("recorded")
    if sites is None:
        from .discover import recorded_sites
        info = p.load("project", {}) or {}
        box = info.get("bbox")
        if not box:
            return []
        w, s, e, n = box
        pad = 0.01
        try:
            sites, _ = recorded_sites([w - pad, s - pad, e + pad, n + pad])
        except Exception:
            return []
        p.save("recorded", sites)
    near = []
    for x in sites:
        d = math.hypot((x["lon"] - lon) * 111_320 * math.cos(math.radians(lat)), (x["lat"] - lat) * 110_540)
        if d <= reach_m:
            near.append({"name": x["name"], "kind": x.get("kind"), "source": x["source"], "metres": round(d)})
    return sorted(near, key=lambda x: x["metres"])[:5]
