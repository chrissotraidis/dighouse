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


def andia():
    """Burial mounds and dolmens on the Sierra de Andía, Navarre, from the government's register of protected archaeological sites."""
    box = [-1.853, 42.825, -1.836, 42.839]
    w, s, e, n = box
    r = httpx.get("https://idena.navarra.es/ogc/wfs", headers=UA, timeout=90, params={
        "service": "WFS", "version": "2.0.0", "request": "GetFeature", "typeNames": "IDENA:PATRIM_Sym_BICarqueo",
        "outputFormat": "application/json", "srsName": "EPSG:4326", "bbox": f"{s},{w},{n},{e},urn:ogc:def:crs:EPSG::4326"})
    r.raise_for_status()
    feats = []
    for rec in r.json()["features"]:
        lon, lat = rec["geometry"]["coordinates"][:2]
        p = rec["properties"]
        if not (w <= lon <= e and s <= lat <= n):
            continue
        what, size = {"Dolmen": ("Dolmen in its mound", 12), "Túmulo": ("Burial mound", 10)}.get(p["TIPO"], (p["TIPO"], 8))
        note = f"The register gives no size; {size} m is assumed, usual for a {what.lower()} here."
        source = f"Gobierno de Navarra, register of protected cultural heritage, BIC {p['CBIC']} ({p['BIC']}), through IDENA"
        feats.append(point("", what, lon, lat, size, source, True, note))
    feats.sort(key=lambda f: (-f["lat"], f["lon"]))
    for i, f in enumerate(feats, 1):
        f["id"] = f"AN-{i:02d}"
    return {"id": "andia", "name": "Sierra de Andía megaliths", "place": "Navarre, Spain", "data": "Government of Navarre 2 m ground model",
            "prefix": "es", "box": box, "coverage": "register",
            "published": f"Navarre's register of protected cultural heritage (Bien de Interés Cultural) lists {len(feats)} dolmens and burial mounds "
                         "here, published through IDENA. Mounds worn low by grazing may barely show in a 2 m ground model.",
            "sources": [{"cite": "Gobierno de Navarra, Registro de Bienes del Patrimonio Cultural de Navarra, archaeological sites layer (PATRIM_Sym_BICarqueo) on IDENA", "link": "https://idena.navarra.es"},
                        {"cite": "Gobierno de Navarra, Registro de Bienes del Patrimonio Cultural de Navarra", "link": "https://administracionelectronica.navarra.es/webextregistrobienes/"}],
            "features": feats}


def oberhaching():
    """Late Iron Age square enclosures near Oberhaching, Bavaria, in woodland and at a field edge: records from the Bavarian monument office."""
    lon, lat = 11.59152, 48.00717  # OpenStreetMap node 1274621796 marks the western enclosure; it has no outline there
    feats = [point("OH-01", "Square enclosure (Viereckschanze)", lon, lat, 110,
                   "Bayerisches Landesamt für Denkmalpflege, ground monument D-1-7935-0043 (\"Viereckschanze (Mehrfachschanze) der späten Latènezeit\"); position from OpenStreetMap node 1274621796",
                   note="Mapped as a point; a Viereckschanze is usually 80 to 120 m across, so 110 m is assumed.")]
    pts = [[lon, lat]]
    for i, way in enumerate((25956101, 84301734), 2):
        line = osm_way(way)
        pts += line
        feats.append(work(f"OH-{i:02d}", "Square enclosure (Viereckschanze)", [line],
                          "Bayerisches Landesamt für Denkmalpflege, ground monument D-1-7935-0042 (\"Viereckschanze (Mehrfachschanze) der späten Latènezeit\"), "
                          f"one of its enclosures; outline from OpenStreetMap way {way}", area=True))
    pad_lon, pad_lat = 0.0015, 0.001
    box = [round(min(p[0] for p in pts) - pad_lon, 4), round(min(p[1] for p in pts) - pad_lat, 4),
           round(max(p[0] for p in pts) + pad_lon, 4), round(max(p[1] for p in pts) + pad_lat, 4)]
    return {"id": "oberhaching", "name": "Oberhaching square enclosures", "place": "Upper Bavaria, Germany", "data": "Bavarian DGM1 1 m ground model",
            "prefix": "de-by", "box": box, "coverage": "partial",
            "published": "The Bavarian State Office for Monument Protection lists Late Iron Age square enclosures (Viereckschanzen) here: one to the west "
                         "and a double enclosure to the east. The key counts those three enclosures; other ground monuments in the box are not in it.",
            "sources": [{"cite": "Bayerisches Landesamt für Denkmalpflege, Bayerischer Denkmal-Atlas, ground monuments D-1-7935-0042 and D-1-7935-0043", "link": "https://geoportal.bayern.de/denkmalatlas/"},
                        {"cite": "Schwarz, K. (1959) Atlas der spätkeltischen Viereckschanzen Bayerns. Munich: Bayerisches Landesamt für Denkmalpflege."},
                        OSM],
            "features": feats}


def irulegi():
    """The Iron Age village and medieval castle on Irulegi hill, Navarre: one protected archaeological zone, outlines from OpenStreetMap."""
    village, castle = osm_way(1112913101), osm_way(326419857)
    feats = [work("IR-01", "Iron Age village on the hilltop terraces", [village],
                  "Gobierno de Navarra, register of protected cultural heritage, archaeological zone Conjunto de Irulegi; outline from OpenStreetMap way 1112913101 (Irulegiko herrixka)", area=True),
             work("IR-02", "Medieval castle walls on the summit", [castle],
                  "Gobierno de Navarra, register of protected cultural heritage, archaeological zone Conjunto de Irulegi; outline from OpenStreetMap way 326419857 (Irulegiko gaztelua)", area=True)]
    pts = village + castle
    box = [round(min(p[0] for p in pts) - 0.002, 4), round(min(p[1] for p in pts) - 0.0015, 4),
           round(max(p[0] for p in pts) + 0.002, 4), round(max(p[1] for p in pts) + 0.0015, 4)]
    return {"id": "irulegi", "name": "Irulegi hill", "place": "Navarre, Spain", "data": "Government of Navarre 2 m ground model",
            "prefix": "es", "box": box, "coverage": "partial",
            "published": "Irulegi is a protected archaeological zone in Navarre: an Iron Age village on the terraces below the summit, where the inscribed "
                         "bronze Hand of Irulegi was found, and a medieval castle on top. The key counts the village and the castle; terraces and "
                         "tracks around them are not separate features in it.",
            "sources": [{"cite": "Gobierno de Navarra, Registro de Bienes del Patrimonio Cultural de Navarra, archaeological zone Conjunto de Irulegi (Aranguren)", "link": "https://idena.navarra.es"},
                        {"cite": "Aiestaran, M., Gorrochategui, J., Velaza, J. et al. (2024) A Vasconic inscription on a bronze hand: writing and rituality in the Iron Age Basque Country. Antiquity 98."},
                        OSM],
            "features": feats}


def lauske():
    """Three ring forts near Hochkirch in Upper Lusatia, Saxony: their circular ramparts, from OpenStreetMap."""
    note = "Mapped as a point; ring forts here are usually 80 to 130 m across, so 100 m is assumed."
    feats = [point("LA-01", "Ring fort (Lausker Schanze)", 14.6191159, 51.1700225, 100, "OpenStreetMap node 415415449 (Lausker Schanze, hill fort)", note=note),
             point("LA-02", "Ring fort (Niethener Schanze)", 14.5876813, 51.1627922, 100, "OpenStreetMap node 1372761444 (Niethener Schanze, hill fort); Wikidata Q131551600", note=note)]
    ring = osm_way(306286783)
    feats.append(work("LA-03", "Ring fort (Zschornaer Schanze)", [ring], "OpenStreetMap way 306286783 (Zschornaer Schanze, hill fort)", area=True))
    pts = [[f["lon"], f["lat"]] for f in feats[:2]] + ring
    box = [round(min(p[0] for p in pts) - 0.0025, 4), round(min(p[1] for p in pts) - 0.0018, 4),
           round(max(p[0] for p in pts) + 0.0025, 4), round(max(p[1] for p in pts) + 0.0018, 4)]
    return {"id": "lauske", "name": "Lauske, Niethen and Zschorna ring forts", "place": "Upper Lusatia, Saxony, Germany", "data": "Saxon DGM1 1 m ground model",
            "prefix": "de-sn", "box": box, "coverage": "partial",
            "published": "Three ring forts (Schanzen) near Hochkirch, of the kind built in Upper Lusatia in the Bronze Age and again by Slavic communities. "
                         "The key counts the three forts as OpenStreetMap maps them; Saxony's register of ground monuments is not open, so other monuments in the box may be missing.",
            "sources": [OSM, {"cite": "Wikidata Q131551600 (Niethener Schanze)", "link": "https://www.wikidata.org/wiki/Q131551600"}],
            "features": feats}


def puketapu():
    """Puketapu Pa south of Auckland: a ridge pā with ditches, terraces and pits, from Auckland Council's heritage schedule."""
    r = httpx.get("https://services1.arcgis.com/n4yPwebTjJCmXB6W/arcgis/rest/services/Historic_Heritage_Overlay_Extent_of_Place/FeatureServer/0/query",
                  params={"where": "SCHEDULE='2251'", "outFields": "SCHEDULE,NAME", "returnGeometry": "true", "outSR": 4326, "f": "json"},
                  headers=UA, timeout=60)
    r.raise_for_status()
    f = r.json()["features"][0]
    ring = f["geometry"]["rings"][0]
    name = f["attributes"]["NAME"]
    feats = [work("PU-01", "Pā on the ridge: ditches, terraces and storage pits", [ring],
                  f"Auckland Unitary Plan, Schedule 14.1 Historic Heritage, place 2251 ({name}); outline is the scheduled extent of place", area=True)]
    box = [round(min(p[0] for p in ring) - 0.002, 4), round(min(p[1] for p in ring) - 0.0016, 4),
           round(max(p[0] for p in ring) + 0.002, 4), round(max(p[1] for p in ring) + 0.0016, 4)]
    return {"id": "puketapu", "name": "Puketapu Pa", "place": "Auckland, New Zealand", "data": "LINZ 1 m ground model",
            "prefix": "nz", "box": box, "coverage": "partial",
            "published": f"Auckland Council schedules {name} as a historic heritage place, recorded by the New Zealand Archaeological Association as site R12/85. "
                         "The key counts the pā as one work, drawn as the scheduled extent of place; other recorded sites nearby are not in it.",
            "sources": [{"cite": "Auckland Council, Auckland Unitary Plan Schedule 14.1 Historic Heritage, Historic Heritage Overlay Extent of Place, place 2251",
                         "link": "https://unitaryplan.aucklandcouncil.govt.nz"},
                        {"cite": "New Zealand Archaeological Association site record R12/85, cited by the schedule"}],
            "features": feats}


ENC = "https://encdirect.noaa.gov/arcgis/rest/services/encdirect"
ENC_WRECKS = [("enc_harbour", 36, "harbour"), ("enc_approach", 39, "approach"), ("enc_coastal", 33, "coastal"), ("enc_general", 29, "general")]
WRECK_REACH_M = 100  # NOAA warns that charted wreck positions can be off; at Thunder Bay one hull lay 70 m from its chart symbol


def wreck_key(kid, prefix, name, place, box, why):
    """Charted wrecks inside a box, from NOAA's electronic charts at every scale, merged where two charts mark one wreck."""
    import numpy as np
    from dighouse import national
    found = []
    import time
    for svc, layer, scale in ENC_WRECKS:
        for attempt in range(4):  # the chart services answer "could not find service" now and then; a key must not miss wrecks
            r = httpx.get(f"{ENC}/{svc}/MapServer/{layer}/query", headers=UA, timeout=90, params={
                "geometry": ",".join(map(str, box)), "geometryType": "esriGeometryEnvelope", "inSR": 4326, "spatialRel": "esriSpatialRelIntersects",
                "outFields": "OBJNAM,CATWRK,VALSOU,SORDAT,SORIND", "returnGeometry": "true", "outSR": 4326, "f": "json"})
            r.raise_for_status()
            j = r.json()
            if "error" not in j:
                break
            if attempt == 3:
                raise RuntimeError(f"NOAA {svc} did not answer: {j['error'].get('message')}")
            time.sleep(10 * (attempt + 1))
        for f in j.get("features", []):
            a, g = f["attributes"], f["geometry"]
            if not (box[0] <= g["x"] <= box[2] and box[1] <= g["y"] <= box[3]):
                continue
            near = next((w for w in found if math.hypot((w["lon"] - g["x"]) * 111_320 * math.cos(math.radians(g["y"])), (w["lat"] - g["y"]) * 110_540) < 80), None)
            src = f"NOAA chart ({scale} scale), {a.get('CATWRK') or 'wreck'}, source {a.get('SORIND') or 'not stated'} {a.get('SORDAT') or ''}".strip()
            if near:
                near["charted"].append(src)
                continue
            found.append({"lon": g["x"], "lat": g["y"], "name": a.get("OBJNAM"), "charted": [src]})
    d = national.NATIONAL["us:noaa-bag"]
    feats = []
    for i, w in enumerate(sorted(found, key=lambda w: (-w["lat"], w["lon"])), 1):
        # A wreck needs survey data around it to show at all. Look at the 120 m around its chart position.
        b = [w["lon"] - 0.0008, w["lat"] - 0.00055, w["lon"] + 0.0008, w["lat"] + 0.00055]
        try:
            dtm, outside, *_ = national.fetch_dtm("us:noaa-bag", b)
            covered = float(1 - outside.mean())
        except ValueError:
            covered = 0.0
        expect = covered >= 0.3
        note = f"Charted {len(w['charted'])} times within 80 m; merged." if len(w["charted"]) > 1 else ""
        if not expect:
            note = (note + " " if note else "") + f"May not show: only {covered:.0%} of the 120 m around its chart position has survey data."
        f = point(f"{prefix}-{i:02d}", f"Wreck{': ' + w['name'] if w['name'] else ''}", w["lon"], w["lat"], 30, "; ".join(w["charted"]), expect, note)
        f["reach_m"] = WRECK_REACH_M
        feats.append(f)
    return {"id": kid, "name": name, "place": place, "data": "NOAA hydrographic surveys (BAG), 1 m", "prefix": "us", "box": box,
            "coverage": "charted", "seafloor": True,
            "published": f"Wrecks on NOAA's electronic navigational charts. {why} Charted positions can be tens of metres off, so a find within "
                         f"{WRECK_REACH_M} m of a charted wreck counts. Uncharted wrecks and debris are not in the key.",
            "sources": [{"cite": "NOAA Office of Coast Survey, Electronic Navigational Charts, through ENC Direct to GIS", "link": "https://encdirect.noaa.gov"},
                        {"cite": "NOAA National Centers for Environmental Information, NOS hydrographic surveys (BAG)", "link": "https://www.ncei.noaa.gov/products/nos-hydrographic-survey"}],
            "features": feats}


def thunder_bay_a():
    return wreck_key("thunder-bay-a", "TBA", "Thunder Bay wrecks, west", "Lake Huron, Michigan, United States", [-83.444, 45.045, -83.425, 45.058],
                     "Thunder Bay is a National Marine Sanctuary with some of the best-preserved wrecks in the Great Lakes.")


def thunder_bay_south():
    return wreck_key("thunder-bay-south", "TBS", "Thunder Bay wrecks, south", "Lake Huron, Michigan, United States", [-83.260, 44.801, -83.243, 44.824],
                     "Thunder Bay is a National Marine Sanctuary with some of the best-preserved wrecks in the Great Lakes.")


def thunder_bay_east():
    return wreck_key("thunder-bay-east", "TBE", "Thunder Bay wrecks, east", "Lake Huron, Michigan, United States", [-83.190, 45.050, -83.163, 45.071],
                     "Thunder Bay is a National Marine Sanctuary with some of the best-preserved wrecks in the Great Lakes.")

def hillfort_key(kid, prefix, name, place, way, record, published, data):
    """One hillfort's rampart line from OpenStreetMap, with its Wikidata record."""
    line = osm_way(way)
    f = work(f"{prefix}-01", "Hillfort rampart", [line], f"OpenStreetMap way {way}; Wikidata {record}", area=True)
    box = [round(min(p[0] for p in line) - 0.002, 4), round(min(p[1] for p in line) - 0.0015, 4),
           round(max(p[0] for p in line) + 0.002, 4), round(max(p[1] for p in line) + 0.0015, 4)]
    return {"id": kid, "name": name, "place": place, "data": data, "prefix": "es-pv", "box": box, "coverage": "partial",
            "published": published, "sources": [OSM, {"cite": f"Wikidata {record}", "link": f"https://www.wikidata.org/wiki/{record}"}], "features": [f]}


def munoaundi():
    return hillfort_key("munoaundi", "MU", "Munoaundi hillfort", "Gipuzkoa, Basque Country, Spain", 1090446321, "Q85965846",
                        "An Iron Age hillfort on the Munoaundi ridge between Azkoitia and Azpeitia, excavated since 2009 by the Aranzadi Science Society. "
                        "The key counts its rampart as one work; other features on the ridge are not in it.", "Basque Government 1 m lidar ground model")


def arrola():
    return hillfort_key("arrola", "AR", "Arrola hillfort (Marueleza)", "Bizkaia, Basque Country, Spain", 364190391, "Q16544867",
                        "The Iron Age hillfort of Arrola on Marueleza hill above Arratzu, one of the largest in Bizkaia, studied by the Arkeologi Museoa. "
                        "The key counts its rampart as one work.", "Basque Government 1 m lidar ground model")


KEYS = {"angel-mounds": angel_mounds, "mound-city": mound_city, "serpent-mound": serpent_mound, "cahokia": cahokia,
        "maiden-castle": maiden_castle, "borre": borre, "andia": andia, "irulegi": irulegi, "oberhaching": oberhaching, "lauske": lauske, "puketapu": puketapu,
        "thunder-bay-a": thunder_bay_a, "thunder-bay-south": thunder_bay_south, "thunder-bay-east": thunder_bay_east,
        "munoaundi": munoaundi, "arrola": arrola}


def main(names=None):
    """Build the named keys, or all of them. Rebuilding a key changes what earlier scores were measured against."""
    OUT.mkdir(parents=True, exist_ok=True)
    built = dt.date.today().isoformat()
    for make in (KEYS[n] for n in (names or KEYS)):
        key = make()
        key["built"] = built
        (OUT / f"{key['id']}.json").write_text(json.dumps(key, indent=1, ensure_ascii=False) + "\n")
        print(key["id"], len(key["features"]), "features,", sum(f["expect"] for f in key["features"]), "counted")


if __name__ == "__main__":
    import sys
    main(sys.argv[1:])

