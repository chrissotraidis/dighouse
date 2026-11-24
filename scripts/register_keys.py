"""Build blind-test answer keys from open site registers: England's scheduled monuments and Norway's heritage register.
FIND_LOOP G2. A test area is a box about 0.8 km across around a recorded barrow cemetery, grave field or hillfort, and
every register record inside it goes into the key; earthworks a lidar search can see are counted, the rest (find spots,
buildings, churches) are kept and not counted. England's list schedules whole monuments, often a cemetery as one area,
so its keys score whether a search marked something on each scheduled monument, not each mound. Norway's register
lists single monuments.

    uv run python scripts/register_keys.py
The keys hold coordinates, so they live with the tools' own data (src/dighouse/keys), never in a project's records.
"""

from __future__ import annotations

import datetime as dt
import json
import math
import re
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
from dighouse import discover  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "src" / "dighouse" / "keys"
SIDE_KM = 0.8
NHLE = discover.NHLE_SCHEDULED
SEEN = re.compile(r"barrow|tumul|mound|cairn|hillfort|camp|enclosure|earthwork|dyke|ditch|bank|rampart|motte|henge|fort|"
                  r"gravhaug|gravrøys|grav\b|røys|haug|voll|tuft|kullgrop|fangstgrop|gravfelt|bygdeborg", re.I)
# Places where barrows are scheduled one by one, so a key counts mounds: 5 to 9 scheduled monuments in each 1 km box.
ENGLAND = ["Normanton Down", "Lake Down", "Winterbourne Stoke", "Seven Barrows", "Overton Hill", "Priddy Nine Barrows", "Therfield Heath",
           "Wexcombe"]
NORWAY = ["Sandefjord", "Larvik", "Karmøy", "Tønsberg", "Fredrikstad", "Ullensaker"]


def box_around(lon, lat, side_km=SIDE_KM):
    dy = side_km / 110.574 / 2
    dx = side_km / (111.32 * math.cos(math.radians(lat))) / 2
    return [round(lon - dx, 5), round(lat - dy, 5), round(lon + dx, 5), round(lat + dy, 5)]


def slug(text):
    text = text.lower().translate(str.maketrans({"ø": "o", "å": "a", "æ": "ae"}))
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")[:40]


KINDS = [("long barrow", "Long barrow"), ("bell barrow", "Bell barrow"), ("disc barrow", "Disc barrow"), ("barrow cemetery", "Barrow cemetery"),
         ("barrows", "Barrow group"), ("barrow", "Barrow"), ("ring ditch", "Ring ditch"), ("avenue", "Avenue"), ("circle", "Circle"),
         ("hillfort", "Hillfort"), ("enclosure", "Enclosure"), ("burial mound", "Burial mound")]


def feature(i, prefix, site):
    counted = bool(SEEN.search(site["name"] + " " + site.get("kind", "")))
    what = site["name"][:80]
    if prefix == "EN":   # England's entries are titles ("Bowl barrow 300m south of ..."): the key says the kind, the note the title
        what = next((v for k, v in KINDS if k in site["name"].lower()), "Scheduled monument")
    f = {"id": f"{prefix}-{i:02d}", "what": what, "expect": counted, "source": f"{site['source']}: {site.get('record', '')}".strip(": ")}
    if prefix == "EN":
        f["note"] = site["name"]
    if site.get("ring"):
        return {**f, "kind": "work", "area": True, "lines": [[[round(x, 6), round(y, 6)] for x, y in site["ring"]]]}
    return {**f, "kind": "point", "lon": round(site["lon"], 6), "lat": round(site["lat"], 6), "size_m": 15}


def inside_box(site, box, slack=0.0015):
    """An area wholly inside the test area stays an area; one that reaches out of it becomes a point at its middle,
    kept only when the middle is inside, so a key never counts ground the test does not fetch."""
    w, s, e, n = box
    if site.get("ring") and not all(w - slack <= x <= e + slack and s - slack <= y <= n + slack for x, y in site["ring"]):
        site = {k: v for k, v in site.items() if k != "ring"}
    return site if (w <= site["lon"] <= e and s <= site["lat"] <= n) else None


def key(kid, name, place, data, box, sites, published, cite, prefix):
    sites = [x for x in (inside_box(s, box) for s in sites) if x]
    feats = [feature(i, prefix, s) for i, s in enumerate(sorted(sites, key=lambda s: (-s["lat"], s["lon"])), 1)]
    return {"id": kid, "name": name, "place": place, "data": data, "box": box, "coverage": "register",
            "published": published + f" Built {dt.date.today().isoformat()} by scripts/register_keys.py.",
            "sources": [{"cite": cite}], "features": feats}


def england():
    out = []
    for name in ENGLAND:
        r = httpx.get(NHLE, timeout=60, params={"where": f"Name LIKE '%{name}%'", "outFields": "Name", "returnGeometry": "true",
                                               "outSR": 4326, "f": "geojson", "resultRecordCount": 1})
        feats = r.json().get("features", [])
        if not feats:
            print("not found:", name)
            continue
        ring = discover._outer_ring(feats[0]["geometry"])
        lon, lat = sum(c[0] for c in ring) / len(ring), sum(c[1] for c in ring) / len(ring)
        box = box_around(lon, lat, 1.0)
        sites = discover._english_sites(box)
        if sum(bool(SEEN.search(s["name"])) for s in sites) < 5:
            continue
        out.append(key(f"en-{slug(name)}", name, "England", "Environment Agency 1 m", box, sites,
                       "England's National Heritage List: every scheduled monument in the area. It holds designated monuments only, "
                       "and often schedules a whole cemetery as one area, so the key counts monuments, not mounds.",
                       "Historic England, National Heritage List for England, Open Government Licence", "EN"))
    return out


def norway():
    out = []
    for town in NORWAY:
        best, offset = None, 0
        while offset < 20_000:
            r = httpx.get("https://api.ra.no/kulturminner/collections/kulturminner/items", timeout=120,
                          params={"f": "json", "kommune": town, "limit": 500, "offset": offset})
            page = r.json().get("features", [])
            for f in page:
                p, g = f.get("properties") or {}, f.get("geometry") or {}
                if "gravfelt" in (p.get("lokalitetsart") or "").lower() and p.get("minnetype") == "LOK" and g:
                    ring = discover._outer_ring(g)
                    n = int(p.get("antallEnkeltminner") or 0) if str(p.get("antallEnkeltminner") or "").isdigit() else len(ring)
                    if ring and (best is None or n > best[0]):
                        best = (n, ring, p.get("navn") or f"Gravfelt i {town}")
            if len(page) < 500:
                break
            offset += 500
        if not best:
            print("no grave field found:", town)
            continue
        _, ring, name = best
        lon, lat = sum(c[0] for c in ring) / len(ring), sum(c[1] for c in ring) / len(ring)
        box = box_around(lon, lat)
        # A grave field's own outline holds the graves it lists one by one; counting both would count them twice.
        sites = [s for s in discover._norwegian_api(box) if "gravfelt" not in s["kind"]]
        if sum(bool(SEEN.search(s["name"] + " " + s["kind"])) for s in sites) < 5:
            continue
        out.append(key(f"no-{slug(town)}", f"{name} ({town})", f"{town}, Norway", "Kartverket 1 m", box, sites,
                       "Norway's heritage register (Askeladden): every record in the area that the public copy holds. Records kept back "
                       "as sensitive are not in it, so a find outside the key can be a real feature.",
                       "Riksantikvaren, Askeladden, through api.ra.no, available under the Norwegian Licence for Open Government Data", "NR"))
    return out


if __name__ == "__main__":
    only = sys.argv[1:]   # names from ENGLAND or NORWAY to build just those
    if only:
        ENGLAND[:] = [n for n in ENGLAND if n in only]
        NORWAY[:] = [n for n in NORWAY if n in only]
    made = england() + norway()
    for k in made:
        head = json.dumps({x: v for x, v in k.items() if x != "features"}, ensure_ascii=False)[1:-1]
        feats = ",\n".join(json.dumps(f, ensure_ascii=False, separators=(",", ":")) for f in k["features"])
        (OUT / f"{k['id']}.json").write_text("{" + head + ', "features": [\n' + feats + "\n]}\n")   # one feature a line
        print(k["id"], len(k["features"]), "features,", sum(f["expect"] for f in k["features"]), "counted")
