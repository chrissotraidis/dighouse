"""Build the answer keys for the blind tests from open, citable data.

Run with: uv run python scripts/build_answer_keys.py
It writes one JSON file per launch site to src/dighouse/keys/. Each feature names where its position comes from
(an OpenStreetMap element or a record in Norway's heritage register) and the publication that describes it.
The keys hold coordinates, so they live with the tools' own data, never in a project's records or the README.
"""

from __future__ import annotations

import datetime as dt
import json
import math
import re
from pathlib import Path

import httpx

OUT = Path(__file__).resolve().parent.parent / "src" / "dighouse" / "keys"
UA = {"User-Agent": "dighouse-answer-keys/0.1 (https://github.com/chrissotraidis/dighouse)"}
OSM = {"cite": "OpenStreetMap contributors, available under the Open Database Licence", "link": "https://www.openstreetmap.org/copyright"}


def osm_map(box):
    w, s, e, n = box
    r = httpx.get("https://api.openstreetmap.org/api/0.6/map.json", params={"bbox": f"{w},{s},{e},{n}"}, headers=UA, timeout=90)
    r.raise_for_status()
    els = r.json()["elements"]
    nodes = {x["id"]: x for x in els if x["type"] == "node"}
    return els, nodes


def osm_way(way_id):
    r = httpx.get(f"https://api.openstreetmap.org/api/0.6/way/{way_id}/full.json", headers=UA, timeout=60)
    r.raise_for_status()
    els = r.json()["elements"]
    nodes = {x["id"]: x for x in els if x["type"] == "node"}
    way = next(x for x in els if x["type"] == "way")
    return [[nodes[i]["lon"], nodes[i]["lat"]] for i in way["nodes"]]


def line_of(way, nodes):
    return [[nodes[i]["lon"], nodes[i]["lat"]] for i in way["nodes"] if i in nodes]


def extent_m(points):
    lat = sum(p[1] for p in points) / len(points)
    k = 111_320 * math.cos(math.radians(lat))
    return max((max(p[0] for p in points) - min(p[0] for p in points)) * k, (max(p[1] for p in points) - min(p[1] for p in points)) * 110_540)


def centre(points):
    return sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points)


def point(fid, what, lon, lat, size, source, expect=True, note=""):
    f = {"id": fid, "what": what, "kind": "point", "lon": round(lon, 6), "lat": round(lat, 6), "size_m": round(size), "expect": expect, "source": source}
    if note:
        f["note"] = note
    return f


def work(fid, what, lines, source, area=False, expect=True, note=""):
    f = {"id": fid, "what": what, "kind": "work", "lines": [[[round(x, 6), round(y, 6)] for x, y in l] for l in lines],
         "area": area, "expect": expect, "source": source}
    if note:
        f["note"] = note
    return f


def angel_mounds():
    box = [-87.45921, 37.94013, -87.45238, 37.94556]
    els, _ = osm_map(box)
    feats = []
    for x in els:
        t = x.get("tags", {})
        if x["type"] == "node" and t.get("archaeological_site") == "tumulus" and t.get("name", "").startswith("Mound"):
            feats.append(point(f"AM-{t['name'][-1]}", t["name"], x["lon"], x["lat"], 50,
                               f"OpenStreetMap node {x['id']}; described in Black (1967)",
                               note="Its outline is not in open data, so a find within 40 m of the mapped point counts."))
        if x["type"] == "node" and "Hut" in t.get("name", ""):
            feats.append(point("AM-HUT", "Reconstructed house", x["lon"], x["lat"], 10, f"OpenStreetMap node {x['id']}", expect=False,
                               note="A modern reconstruction, not an earthwork."))
    feats.sort(key=lambda f: f["id"])
    return {"id": "angel-mounds", "name": "Angel Mounds", "place": "Indiana, United States", "data": "USGS 3DEP", "box": box,
            "coverage": "partial",
            "published": "Black (1967) describes 11 mounds at the Angel site and a palisade around the town. Four of the mounds inside this test area are mapped in open data, so a find on another mound is listed as not in the key, and the literature step says what it is.",
            "sources": [{"cite": "Black, G. A. (1967) Angel Site: An Archaeological, Historical, and Ethnological Study. Indianapolis: Indiana Historical Society."}, OSM],
            "features": feats}


def mound_city():
    box = [-83.00875, 39.37455, -83.00275, 39.37895]
    els, nodes = osm_map(box)
    feats, n = [], 0
    rings = sorted((x for x in els if x["type"] == "way" and x.get("tags", {}).get("man_made") == "embankment"),
                   key=lambda w: (-centre(line_of(w, nodes))[1], centre(line_of(w, nodes))[0]))
    for w in rings:
        pts = line_of(w, nodes)
        if len(pts) < 3 or extent_m(pts) > 60:
            continue
        n += 1
        lon, lat = centre(pts)
        feats.append(point(f"MC-{n:02d}", "Mound", lon, lat, extent_m(pts), f"OpenStreetMap way {w['id']}; Squier and Davis (1848)"))
    wall = next(x for x in els if x["type"] == "way" and x.get("tags", {}).get("historic") == "archaeological_site")
    feats.append(work("MC-WALL", "Enclosure wall", [line_of(wall, nodes)], f"OpenStreetMap way {wall['id']}; Squier and Davis (1848)",
                      note="A find on the wall counts once; more finds on it are not counted as false."))
    return {"id": "mound-city", "name": "Mound City Group", "place": "Ohio, United States", "data": "USGS 3DEP", "box": box,
            "coverage": "partial",
            "published": f"Squier and Davis (1848) mapped 23 mounds inside the enclosure, and the National Park Service counts 25 today. {n} of them are mapped one by one in open data and make up this key.",
            "sources": [{"cite": "Squier, E. G. and Davis, E. H. (1848) Ancient Monuments of the Mississippi Valley. Washington: Smithsonian Institution."},
                        {"cite": "National Park Service, Hopewell Culture National Historical Park: Mound City Group", "link": "https://www.nps.gov/hocu/learn/historyculture/mound-city-group.htm"}, OSM],
            "features": feats}


def serpent_mound():
    box = [-83.4334, 39.0226, -83.427, 39.0278]
    els, _ = osm_map(box)
    feats = [work("SM-EFFIGY", "Serpent effigy", [osm_way(772057857)], "OpenStreetMap relation 18046217; Squier and Davis (1848); Fletcher et al. (1996)", area=True)]
    tumuli = sorted((x for x in els if x["type"] == "node" and x.get("tags", {}).get("archaeological_site") == "tumulus"), key=lambda x: x["lon"])
    for i, x in enumerate(tumuli, 1):
        feats.append(point(f"SM-M{i}", "Burial mound", x["lon"], x["lat"], 30, f"OpenStreetMap node {x['id']}; Fletcher et al. (1996)",
                           note="Its outline is not in open data, so a find within 30 m of the mapped point counts."))
    return {"id": "serpent-mound", "name": "Serpent Mound", "place": "Ohio, United States", "data": "USGS 3DEP", "box": box,
            "coverage": "partial",
            "published": "The effigy was mapped by Squier and Davis (1848). Burial mounds near it are described by Fletcher et al. (1996); the two mapped in open data are in this key.",
            "sources": [{"cite": "Squier, E. G. and Davis, E. H. (1848) Ancient Monuments of the Mississippi Valley. Washington: Smithsonian Institution."},
                        {"cite": "Fletcher, R. V., Cameron, T. L., Lepper, B. T., Wymer, D. A. and Pickard, W. (1996) Serpent Mound: a Fort Ancient icon? Midcontinental Journal of Archaeology 21(1)."}, OSM],
            "features": feats}


def cahokia():
    box = [-90.0652, 38.6585, -90.0592, 38.6628]
    feats = [work("CA-MONKS", "Monks Mound", [osm_way(360096331)], "OpenStreetMap way 360096331; Fowler (1997)", area=True,
                  note="Its terraces are part of the one mound.")]
    return {"id": "cahokia", "name": "Cahokia, Monks Mound", "place": "Illinois, United States", "data": "USGS 3DEP", "box": box,
            "coverage": "partial",
            "published": "Fowler (1997) maps more than a hundred mounds at Cahokia. Only Monks Mound is mapped in open data inside this test area, so finds on smaller mounds nearby are listed as not in the key.",
            "sources": [{"cite": "Fowler, M. L. (1997) The Cahokia Atlas: A Historical Atlas of Cahokia Archaeology. Revised edition. Urbana: University of Illinois."}, OSM],
            "features": feats}


def maiden_castle():
    outline = osm_way(146411874)
    w, e = min(p[0] for p in outline), max(p[0] for p in outline)
    s, n = min(p[1] for p in outline), max(p[1] for p in outline)
    pad_lon, pad_lat = 60 / (111_320 * math.cos(math.radians(s))), 60 / 110_540
    box = [round(w - pad_lon, 5), round(s - pad_lat, 5), round(e + pad_lon, 5), round(n + pad_lat, 5)]
    els, nodes = osm_map(box)
    banks = [x for x in els if x["type"] == "way" and x.get("tags", {}).get("man_made") == "embankment"]
    long_lines, west, east = [], [], []
    mid = (w + e) / 2
    for b in banks:
        pts = line_of(b, nodes)
        if len(pts) < 2:
            continue
        length = sum(math.hypot((a[0] - c[0]) * 111_320 * math.cos(math.radians(a[1])), (a[1] - c[1]) * 110_540) for a, c in zip(pts, pts[1:]))
        if length > 600:
            long_lines.append(pts)
        elif centre(pts)[0] < mid:
            west.append(pts)
        else:
            east.append(pts)
    feats = [work("MC-RAMPARTS", "Ramparts and ditches", long_lines, "OpenStreetMap embankments; Wheeler (1943); Sharples (1991)"),
             work("MC-WEST", "West entrance outworks", west, "OpenStreetMap embankments; Wheeler (1943)"),
             work("MC-EAST", "East entrance outworks", east, "OpenStreetMap embankments; Wheeler (1943)")]
    for x in els:
        t = x.get("tags", {})
        if x["type"] == "way" and t.get("name") in ("Romano British Temple", "Priest's House"):
            pts = line_of(x, nodes)
            lon, lat = centre(pts)
            feats.append(point("MC-TEMPLE" if "Temple" in t["name"] else "MC-HOUSE", "Romano-British temple" if "Temple" in t["name"] else "Romano-British house",
                               lon, lat, max(extent_m(pts), 8), f"OpenStreetMap way {x['id']}; Wheeler (1943)", expect=False,
                               note="Low stone footings that may not show in a 1 m ground model."))
    for f in feats:
        f["id"] = f["id"].replace("MC-", "MD-")
    return {"id": "maiden-castle", "name": "Maiden Castle", "place": "Dorset, England", "data": "Environment Agency 1 m ground model", "box": box,
            "coverage": "partial",
            "published": "Wheeler (1943) and Sharples (1991) describe the multiple ramparts and both entrances, a Neolithic long mound along the hilltop and a Romano-British temple. The long mound is not mapped in open data and is not in this key.",
            "sources": [{"cite": "Wheeler, R. E. M. (1943) Maiden Castle, Dorset. London: Society of Antiquaries."},
                        {"cite": "Sharples, N. M. (1991) Maiden Castle: Excavations and Field Survey 1985–6. London: English Heritage."}, OSM],
            "features": feats}


GONE = re.compile(r"borte|ikke spor|ikke synlig|utslettet|beskåret|fjernet", re.I)
GRAVE = {"Gravhaug", "Gravrøys", "Grav", "Gravkammer-gravkiste"}


def borre():
    box = [10.464, 59.38, 10.474, 59.386]
    base = "https://api.ra.no/kulturminner/collections/kulturminner/items"
    records, offset = [], 0
    while True:
        r = httpx.get(base, params={"f": "json", "kommune": "Horten", "limit": 500, "offset": offset}, headers=UA, timeout=120)
        r.raise_for_status()
        page = r.json().get("features", [])
        records += page
        if len(page) < 500:
            break
        offset += 500
    feats = []
    for rec in records:
        g, p = rec.get("geometry"), rec["properties"]
        art = p.get("enkeltminneart")
        if not g or art not in GRAVE | {"Rydningsrøys", "Boplass"}:
            continue
        pts = {"Point": lambda c: [c], "Polygon": lambda c: c[0], "MultiPolygon": lambda c: [q for poly in c for q in poly[0]],
               "MultiPoint": lambda c: c}.get(g["type"], lambda c: [])(g["coordinates"])
        if not pts:
            continue
        lon, lat = centre(pts)
        if not (box[0] <= lon <= box[2] and box[1] <= lat <= box[3]):
            continue
        info = p.get("informasjon") or ""
        size = extent_m(pts) if len(pts) > 2 else 0
        m = re.search(r"[Dd]iameter\s*(?:ca\.?\s*)?(\d+(?:[.,]\d+)?)", info)
        if m and size < 3:
            size = float(m.group(1).replace(",", "."))
        size = max(size, 6)
        link = p.get("linkKulturminnesøk") or p.get("linkAskeladden") or ""
        kid = (p.get("linkAskeladden") or "").split("kid=")[-1]
        source = f"Riksantikvaren, Askeladden record {kid}" + (f" ({link})" if link else "")
        expect, note = True, ""
        if art in ("Boplass", "Rydningsrøys"):
            expect, note = False, "A house site found by ground radar; it leaves no mound." if art == "Boplass" else "Recorded as an uncertain clearance cairn."
        elif not p.get("synlig") or GONE.search(info):
            expect, note = False, "The register says it is gone or not visible on the ground."
        elif size < 6.5 and not m:
            note = "Its size is not given; 6 m is assumed."
        what = {"Gravhaug": "Burial mound", "Gravrøys": "Burial cairn", "Grav": "Grave", "Gravkammer-gravkiste": "Chamber grave",
                "Rydningsrøys": "Clearance cairn", "Boplass": "House site"}[art]
        feats.append({**point("", what, lon, lat, size, source, expect, note)})
    feats.sort(key=lambda f: (-f["lat"], f["lon"]))
    for i, f in enumerate(feats, 1):
        f["id"] = f"BO-{i:02d}"
    shown = sum(f["expect"] for f in feats)
    return {"id": "borre", "name": "Borre mound cemetery", "place": "Vestfold, Norway", "data": "Kartverket 1 m ground model", "box": box,
            "coverage": "register",
            "published": f"Norway's heritage register (Askeladden) lists every recorded monument here. {shown} burial mounds and cairns are recorded as visible on the ground; those it says are gone or were found only by ground radar are kept in the key but not counted.",
            "sources": [{"cite": "Riksantikvaren, Askeladden, through Kulturminnesøk, available under the Norwegian Licence for Open Government Data", "link": "https://kulturminnesok.no"},
                        {"cite": "Myhre, B. (1992) Borre: et merovingertidssenter i Øst-Norge. Universitetets Oldsaksamling."}],
            "features": feats}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    built = dt.date.today().isoformat()
    for make in (angel_mounds, mound_city, serpent_mound, cahokia, maiden_castle, borre):
        key = make()
        key["built"] = built
        (OUT / f"{key['id']}.json").write_text(json.dumps(key, indent=1, ensure_ascii=False) + "\n")
        print(key["id"], len(key["features"]), "features,", sum(f["expect"] for f in key["features"]), "counted")


if __name__ == "__main__":
    main()

