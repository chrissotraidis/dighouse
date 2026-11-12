"""Where does it make sense to look? Open catalogs of places, surveys and known sites."""

from __future__ import annotations

import json
import logging
import math
import re
import time
from concurrent.futures import ThreadPoolExecutor

import httpx

from . import sources

NOMINATIM = "https://nominatim.openstreetmap.org/search"
WIKIDATA = "https://query.wikidata.org/sparql"
# Surveys that are offered for download but did not build into usable terrain when tested on 2026-11-12.
PROBLEMS = {
    "ot:NM16_Dorshow": "fetch_terrain fails on it: its tile index has no readable map projection.",
    "ot:NM10_Dorshow": "almost none of its points are classed as ground (0.01 per square metre where tested), so the bare ground cannot be built.",
}
ARCHAEOLOGY = re.compile(
    r"archaeolog|\bmaya\b|prehispanic|pre-?columbian|\bruins\b|cultural heritage|ancient (agricultur|settlement|cit)|"
    r"\bpueblo\b|chaco canyon|hillfort|earthworks", re.IGNORECASE)

logging.getLogger("httpx").setLevel(logging.WARNING)

# Surveys whose points were fetched and built into terrain on 2026-11-12, each with a small box that has ground data.
# The app only offers a survey as a starting point when it is listed here.
CHECKED = {
    "ot:MX13E_Britton": [-88.6448, 21.2883, -88.6410, 21.2920],
    "ot:MX13W_Britton": [-90.1304, 20.4739, -90.1265, 20.4774],
    "ot:MX19_Inomata": [-91.3593, 17.6485, -91.3555, 17.6521],
    "ot:AZ08_Kruse": [-112.0176, 34.2496, -112.0133, 34.2532],
}
_client = httpx.Client(timeout=40, follow_redirects=True,
                       headers={"User-Agent": "dighouse/0.1 (https://github.com/chrissotraidis/dighouse)"})


def find_place(query: str, limit: int = 5) -> list[dict]:
    """Look a place name up in OpenStreetMap's gazetteer."""
    r = _client.get(NOMINATIM, params={"q": query, "format": "jsonv2", "limit": limit})
    r.raise_for_status()
    out = []
    for hit in r.json():
        south, north, west, east = (float(v) for v in hit["boundingbox"])
        out.append({"name": hit["display_name"], "kind": hit.get("type"), "lat": float(hit["lat"]), "lon": float(hit["lon"]),
                    "west": west, "south": south, "east": east, "north": north})
    return out


def _catalog() -> list[dict]:
    """Every point-cloud dataset OpenTopography hosts, cached for a week."""
    cache = sources.cache_dir() / "opentopography-catalog.json"
    if not cache.exists() or time.time() - cache.stat().st_mtime > 7 * 86400:
        r = _client.get(sources.OT_CATALOG, timeout=90, params={
            "productFormat": "PointCloud", "minx": -180, "miny": -85, "maxx": 180, "maxy": 85,
            "detail": "true", "outputFormat": "json", "include_federated": "false"})
        r.raise_for_status()
        cache.write_bytes(r.content)
    return [item["Dataset"] for item in json.loads(cache.read_text())["Datasets"]]


def _bounds(geojson) -> list[float] | None:
    xs, ys = [], []

    def walk(node):
        if isinstance(node, dict):
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            if len(node) >= 2 and all(isinstance(v, (int, float)) for v in node[:2]):
                xs.append(node[0])
                ys.append(node[1])
            else:
                for value in node:
                    walk(value)

    walk(geojson)
    return [min(xs), min(ys), max(xs), max(ys)] if xs else None


def _fetchable(short_name: str | None) -> bool:
    if not short_name:
        return False
    try:
        return _client.head(f"{sources.OT_BULK}/{short_name}/{short_name}_TileIndex.zip", timeout=15).status_code == 200
    except httpx.HTTPError:
        return False


def open_surveys(keyword: str = "") -> list[dict]:
    """Open lidar surveys on OpenTopography that were flown with archaeology in mind, or that match a keyword."""
    pattern = re.compile(re.escape(keyword), re.IGNORECASE) if keyword else ARCHAEOLOGY
    found, seen = [], set()
    for d in _catalog():
        about = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", d.get("description") or ""))
        text = f"{d.get('name', '')}. {d.get('keywords') or ''}. {about}"
        match = pattern.search(text)
        if not match or d["name"] in seen:
            continue
        seen.add(d["name"])
        box = _bounds((d.get("spatialCoverage") or {}).get("geo"))
        if not box:
            continue
        start = max(match.start() - 90, 0)
        found.append({
            "id": f"ot:{d['alternateName']}" if d.get("alternateName") else None,
            "title": d["name"], "collected": (d.get("temporalCoverage") or "")[:4], "landing_page": d.get("url"),
            "why": text[start:match.end() + 140].strip(),
            "west": box[0], "south": box[1], "east": box[2], "north": box[3],
        })
    with ThreadPoolExecutor(8) as pool:
        ready = list(pool.map(lambda s: _fetchable((s["id"] or "")[3:] or None), found))
    for survey, ok in zip(found, ready):
        survey["fetchable_without_account"] = ok
        survey["checked_start"] = CHECKED.get(survey["id"]) if ok else None
        if survey["id"] in PROBLEMS:
            survey["known_problem"] = PROBLEMS[survey["id"]]
    return sorted(found, key=lambda s: (s["checked_start"] is None, not s["fetchable_without_account"], s["title"]))

# ------------------------------------------------------------ what is already recorded

OVERPASS_HOSTS = (("https://overpass-api.de/api/interpreter", 35), ("https://overpass.private.coffee/api/interpreter", 20))
NRHP = "https://mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer/0/query"
OPENCONTEXT = "https://opencontext.org/query/.json"


def _wikidata_sites(bbox: list[float]) -> list[dict]:
    w, s, e, n = bbox
    query = f"""SELECT DISTINCT ?item ?itemLabel ?kindLabel ?loc WHERE {{
  SERVICE wikibase:box {{ ?item wdt:P625 ?loc .
    bd:serviceParam wikibase:cornerSouthWest "Point({w} {s})"^^geo:wktLiteral .
    bd:serviceParam wikibase:cornerNorthEast "Point({e} {n})"^^geo:wktLiteral . }}
  ?item wdt:P31 ?kind . ?kind wdt:P279* wd:Q839954 .
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }} }} LIMIT 2000"""
    r = _client.get(WIKIDATA, params={"query": query}, headers={"Accept": "application/sparql-results+json"})
    r.raise_for_status()
    sites: dict[str, dict] = {}
    for row in r.json()["results"]["bindings"]:
        lon, lat = (float(v) for v in re.findall(r"-?\d+\.?\d*", row["loc"]["value"])[:2])
        sites.setdefault(row["item"]["value"], {"name": row["itemLabel"]["value"], "kind": row["kindLabel"]["value"],
                                                "lon": lon, "lat": lat, "source": "Wikidata", "record": row["item"]["value"]})
    return list(sites.values())


QLEVER_OSM = "https://qlever.dev/api/osm-planet"
QLEVER_QUERY = """PREFIX osmkey: <https://www.openstreetmap.org/wiki/Key:>
PREFIX geo: <http://www.opengis.net/ont/geosparql#>
PREFIX geof: <http://www.opengis.net/def/function/geosparql/>
SELECT ?osm ?name ?type ?centre WHERE {{ ?osm osmkey:historic "archaeological_site" . ?osm geo:hasGeometry/geo:asWKT ?shape .
BIND(geof:centroid(?shape) AS ?centre) BIND(geof:longitude(?centre) AS ?x) BIND(geof:latitude(?centre) AS ?y)
FILTER(?x >= {w} && ?x <= {e} && ?y >= {s} && ?y <= {n})
OPTIONAL {{ ?osm osmkey:name ?name }} OPTIONAL {{ ?osm osmkey:site_type ?type }} }}"""


def _osm_site(kind: str | None, name: str | None, lon: float, lat: float, record: str) -> dict:
    kind = (kind or "archaeological site").replace("_", " ")
    return {"name": name or f"Unnamed {kind}", "kind": kind, "lon": lon, "lat": lat, "source": "OpenStreetMap", "record": record}


def _tsv_value(cell: str) -> str | None:
    cell = cell.strip()
    if not cell:
        return None
    if cell.startswith("<") and cell.endswith(">"):
        return cell[1:-1]
    if cell.startswith('"'):
        cell = cell[1:cell.rindex('"')] if cell.count('"') > 1 else cell[1:]
    return cell.replace("\\t", "\t").replace("\\n", " ").replace('\\"', '"').replace("\\\\", "\\")


def _osm_qlever(bbox: list[float]) -> list[dict]:
    """OpenStreetMap's archaeological sites from QLever, a public query service that holds the whole map."""
    w, s, e, n = bbox
    r = _client.post(QLEVER_OSM, data={"query": QLEVER_QUERY.format(w=w, s=s, e=e, n=n)},
                     headers={"Accept": "text/tab-separated-values"}, timeout=40)
    r.raise_for_status()
    out = []
    for line in r.text.splitlines()[1:]:
        osm, name, kind, centre = (_tsv_value(c) for c in (line.split("\t") + ["", "", "", ""])[:4])
        point = re.findall(r"-?\d+\.?\d*", centre or "")
        if osm and len(point) >= 2:
            out.append(_osm_site(kind, name, float(point[0]), float(point[1]), osm))
    return out


def _osm_overpass(bbox: list[float]) -> list[dict]:
    w, s, e, n = bbox
    query = f"[out:json][timeout:25];nwr[historic=archaeological_site]({s},{w},{n},{e});out center tags 3000;"
    r, failure = None, "no answer"
    for host, patience in OVERPASS_HOSTS:  # the public map services are often busy, so try each in turn
        try:
            r = _client.post(host, data={"data": query}, timeout=patience)
        except httpx.HTTPError as exc:
            failure = str(exc)[:80]
            continue
        if r.status_code == 200:
            break
        failure = f"status {r.status_code}"
    if r is None or r.status_code != 200:
        raise RuntimeError(f"Overpass did not answer ({failure})")
    out = []
    for el in r.json().get("elements", []):
        at = el if "lat" in el else el.get("center")
        if at:
            tags = el.get("tags", {})
            out.append(_osm_site(tags.get("site_type") or tags.get("archaeological_site"), tags.get("name"),
                                 at["lon"], at["lat"], f"https://www.openstreetmap.org/{el['type']}/{el['id']}"))
    return out


def _osm_sites(bbox: list[float]) -> list[dict]:
    """OpenStreetMap's archaeological sites in a box: QLever first, then Overpass, and a week-old answer as a last resort."""
    folder = sources.cache_dir() / "osm-sites"
    folder.mkdir(parents=True, exist_ok=True)
    cache = folder / ("_".join(f"{v:.4f}" for v in bbox) + ".json")
    if cache.exists() and time.time() - cache.stat().st_mtime < 7 * 86400:
        return json.loads(cache.read_text())
    failures = []
    for reader in (_osm_qlever, _osm_overpass):
        try:
            found = reader(bbox)
        except Exception as exc:  # each service is tried in turn
            failures.append(f"{reader.__name__[5:]}: {str(exc)[:80]}")
            continue
        cache.write_text(json.dumps(found))
        return found
    if cache.exists():
        return json.loads(cache.read_text())
    raise RuntimeError("the open map services did not answer (" + "; ".join(failures) + ")")


def _nrhp_sites(bbox: list[float]) -> list[dict]:
    w, s, e, n = bbox
    if not (-180 <= w <= -64 and 17 <= n <= 72):  # the register covers the United States only
        return []
    r = _client.get(NRHP, params={
        "where": "ResType='site'", "geometry": f"{w},{s},{e},{n}", "geometryType": "esriGeometryEnvelope", "inSR": 4326,
        "spatialRel": "esriSpatialRelIntersects", "outFields": "RESNAME,NRIS_Refnum", "returnGeometry": "true",
        "outSR": 4326, "resultRecordCount": 2000, "f": "json"})
    r.raise_for_status()
    return [{"name": f["attributes"]["RESNAME"], "kind": "site on the National Register", "lon": f["geometry"]["x"],
             "lat": f["geometry"]["y"], "source": "National Register of Historic Places",
             "record": f"NRIS {f['attributes'].get('NRIS_Refnum')}"}
            for f in r.json().get("features", []) if f.get("geometry")]


SITE_READERS = {"Wikidata": _wikidata_sites, "OpenStreetMap": _osm_sites, "National Register of Historic Places": _nrhp_sites}


def _answered(silent: list[str]) -> list[str]:
    """The site lists that answered, so a short list is not mistaken for a source that was down."""
    down = {line.split(":")[0] for line in silent}
    return [name for name in SITE_READERS if name not in down]


def recorded_sites(bbox: list[float]) -> tuple[list[dict], list[str]]:
    """Sites on open record inside a box, from every source that answers, and the sources that did not."""
    readers = SITE_READERS
    sites, silent, seen = [], [], set()
    with ThreadPoolExecutor(3) as pool:
        jobs = {name: pool.submit(reader, bbox) for name, reader in readers.items()}
    for name, job in jobs.items():
        try:
            found = job.result()
        except Exception as exc:  # one source being down should not hide the others
            silent.append(f"{name}: {str(exc)[:120]}")
            continue
        for site in found:
            key = (re.sub(r"\W+", "", site["name"].lower()), round(site["lon"], 2), round(site["lat"], 2))
            if key not in seen:
                seen.add(key)
                sites.append(site)
    return sites, silent


def known_sites(bbox: list[float]) -> dict:
    """Recorded sites inside a box, listed by name, distance and direction from its centre. No coordinates."""
    w, s, e, n = bbox
    cx, cy = (w + e) / 2, (s + n) / 2
    sites, silent = recorded_sites(bbox)
    listed = []
    for site in sites:
        east_km = (site["lon"] - cx) * 111.32 * math.cos(math.radians(cy))
        north_km = (site["lat"] - cy) * 110.54
        bearing = (math.degrees(math.atan2(east_km, north_km)) + 360) % 360
        listed.append({"name": site["name"], "kind": site["kind"], "source": site["source"],
                       "km_from_centre": round(math.hypot(east_km, north_km), 1),
                       "direction": ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][int((bearing + 22.5) // 45) % 8],
                       "record": site["record"]})
    listed.sort(key=lambda site: site["km_from_centre"])
    by_source: dict[str, int] = {}
    for site in listed:
        by_source[site["source"]] = by_source.get(site["source"], 0) + 1
    out = {"count": len(listed), "by_source": by_source, "sources_that_answered": _answered(silent), "nearest": listed[:40]}
    if silent:
        out["sources_that_did_not_answer"] = silent
    return out


def survey_area(bbox: list[float]) -> dict:
    """What is openly available and already recorded for an area: lidar coverage and known sites."""
    w, s, e, n = bbox
    if e - w > 2 or n - s > 2:
        raise ValueError("Keep the area under 2 degrees on a side. Use find_place to narrow it down first.")
    out: dict = {"area_km2": round((e - w) * 111.32 * math.cos(math.radians((s + n) / 2)) * (n - s) * 110.54)}
    lidar = sources.find_data(bbox)
    out["open_lidar"] = [{k: d.get(k) for k in ("id", "source", "title", "collected")} for d in lidar if d.get("id")]
    out["known_sites"] = known_sites(bbox)
    out["how_to_read"] = RECORD_CAVEAT
    return out


RECORD_CAVEAT = ("Open lidar with few recorded sites is where a search adds most. The site lists come from Wikidata, "
                 "OpenStreetMap and the public part of the US National Register. All three are far from complete: in the "
                 "United States the full site files are held by each State Historic Preservation Office and are not "
                 "public, and other countries keep theirs with a heritage authority. A short list does not mean nothing "
                 "is known there. records_in_open_context counts published records in the region, which in the United States "
                 "includes state site-file entries placed only at county level: it shows how much is known that the named "
                 "lists miss. Only the literature and the authority can settle what is known at one spot.")


def find_gaps(bbox: list[float], cells: int = 4) -> dict:
    """Split a region into a grid and rank the cells: open lidar first, then the fewest sites on open record."""
    w, s, e, n = bbox
    if e - w > 2 or n - s > 2:
        raise ValueError("Keep the region under 2 degrees on a side. Use find_place to narrow it down first.")
    sites, silent = recorded_sites(bbox)
    usgs = [f for f in sources._usgs_index() if sources._overlaps(f["geometry"], bbox)]
    surveys = []
    for d in _catalog():
        box = _bounds((d.get("spatialCoverage") or {}).get("geo"))
        if box and not (box[2] < w or box[0] > e or box[3] < s or box[1] > n) and d.get("alternateName"):
            text = f"{d.get('name', '')}. {d.get('keywords') or ''}. {d.get('description') or ''}"
            surveys.append((f"ot:{d['alternateName']}", box, bool(ARCHAEOLOGY.search(text))))
    dx, dy = (e - w) / cells, (n - s) / cells
    grid = []
    for row in range(cells):
        for col in range(cells):
            cw, cs = w + col * dx, n - (row + 1) * dy
            cell = [cw, cs, cw + dx, cs + dy]
            lidar = [f"usgs:{f['properties']['name']}" for f in usgs if sources._overlaps(f["geometry"], cell)]
            flown = [sid for sid, box, arch in surveys
                     if arch and not (box[2] < cell[0] or box[0] > cell[2] or box[3] < cell[1] or box[1] > cell[3])]
            lidar += [sid for sid, box, _ in surveys
                      if not (box[2] < cell[0] or box[0] > cell[2] or box[3] < cell[1] or box[1] > cell[3])]
            inside = [x for x in sites if cell[0] <= x["lon"] < cell[2] and cell[1] <= x["lat"] < cell[3]]
            by_source: dict[str, int] = {}
            for x in inside:
                by_source[x["source"]] = by_source.get(x["source"], 0) + 1
            grid.append({
                "cell": f"{'ABCDEFGH'[row]}{col + 1}", "west": round(cell[0], 4), "south": round(cell[1], 4),
                "east": round(cell[2], 4), "north": round(cell[3], 4),
                "area_km2": round(dx * 111.32 * math.cos(math.radians(cs + dy / 2)) * dy * 110.54),
                "open_lidar_datasets": len(lidar), "open_lidar": lidar[:4], "flown_for_archaeology": flown,
                "recorded_sites": len(inside), "by_source": by_source, "examples": [x["name"] for x in inside[:4]]})
    totals: dict[str, int] = {}
    for x in sites:
        totals[x["source"]] = totals.get(x["source"], 0) + 1
    covered = [c for c in grid if c["open_lidar_datasets"]]
    covered.sort(key=lambda c: (not c["flown_for_archaeology"], c["recorded_sites"]))
    try:
        published = search_records("", bbox, 1)["total"]
    except Exception:
        published = None
    out = {"grid": f"{cells} by {cells}, rows A (north) to {'ABCDEFGH'[cells - 1]} (south), columns 1 (west) to {cells} (east)",
           "sites_on_open_record": len(sites), "by_source": totals, "sources_that_answered": _answered(silent),
           "records_in_open_context": published, "cells_with_open_lidar": len(covered),
           "cells_without_open_lidar": len(grid) - len(covered), "ranked": covered[:8], "how_to_read": RECORD_CAVEAT}
    if silent:
        out["sources_that_did_not_answer"] = silent
    return out


def search_records(query: str, bbox: list[float] | None = None, limit: int = 10) -> dict:
    """Search Open Context, an open archive of published excavation and survey data."""
    params = {"rows": min(limit, 50), "response": "metadata,uri-meta"}
    if query:
        params["q"] = query
    if bbox:
        params["bbox"] = ",".join(str(v) for v in bbox)
    r = _client.get(OPENCONTEXT, params=params, timeout=60)
    r.raise_for_status()
    data = r.json()
    rows = data.get("oc-api:has-results") or (data if isinstance(data, list) else [])
    return {"total": data.get("totalResults") if isinstance(data, dict) else len(rows), "records": [{
        "label": x.get("label"), "kind": x.get("item category"), "project": x.get("project label"),
        "where": x.get("context label"), "from_year": x.get("early bce/ce"), "to_year": x.get("late bce/ce"),
        "link": x.get("href")} for x in rows[:limit]]}


def open_resources(topic: str = "") -> list[dict]:
    """The open archives a search can draw on: what each holds, how big it is, and whether these tools read it."""
    try:
        surveys = len(_catalog())
    except Exception:
        surveys = None
    try:
        usgs = len(sources._usgs_index())
    except Exception:
        usgs = None
    rows = [
        {"name": "USGS 3DEP", "kind": "lidar", "region": "United States",
         "holds": "Public-domain lidar point clouds covering most of the United States.",
         "size": f"{usgs} collections in the public index" if usgs else "size not read", "read_by": "find_data, fetch_terrain, find_gaps",
         "note": "Flown for mapping, not archaeology, so most of it has never been searched for earthworks."},
        {"name": "OpenTopography", "kind": "lidar", "region": "World, mostly the Americas",
         "holds": "Research lidar surveys, including ones flown for archaeologists.",
         "size": f"{surveys} point-cloud datasets in its catalog" if surveys else "size not read", "read_by": "open_surveys, find_data, fetch_terrain",
         "note": "Only datasets published as bulk files can be fetched without an account. open_surveys says which."},
        {"name": "OpenStreetMap", "kind": "recorded sites", "region": "World",
         "holds": "Places mapped by volunteers, including archaeological sites.",
         "size": "231,107 features tagged as archaeological sites (taginfo, 12 November 2026)", "read_by": "survey_area, find_gaps, check_modern",
         "note": "Coverage is uneven: dense in parts of Europe, thin elsewhere. Sites are read through QLever, a public query service that holds the whole map, with Overpass as the fallback."},
        {"name": "National Register of Historic Places", "kind": "recorded sites", "region": "United States",
         "holds": "The public, non-restricted listings of the US National Park Service.",
         "size": "74,636 point listings and 22,905 mapped boundaries (queried 12 November 2026)", "read_by": "survey_area, find_gaps",
         "note": "Archaeological sites with restricted locations are left out of the public layer on purpose."},
        {"name": "Wikidata", "kind": "recorded sites", "region": "World",
         "holds": "The open database behind Wikipedia, with archaeological sites that have an entry.",
         "size": "not counted", "read_by": "survey_area, find_gaps", "note": "Holds well-known sites; thin for ordinary ones."},
        {"name": "Open Context", "kind": "published records", "region": "World",
         "holds": "Published excavation and survey data: finds, features, site files, images. It also hosts the Digital "
                  "Index of North American Archaeology.",
         "size": "2,439,980 records (queried 12 November 2026)", "read_by": "search_records",
         "note": "Records are what projects chose to publish, so a place with none may still be well studied."},
        {"name": "OpenAlex", "kind": "literature", "region": "World", "holds": "An open index of scholarly books and papers.",
         "size": "not counted", "read_by": "search_literature, read_source",
         "note": "Finds titles and abstracts. Many publishers refuse to show the full text to a program."},
        {"name": "Pleiades", "kind": "recorded sites", "region": "Ancient Mediterranean and Near East",
         "holds": "A gazetteer of ancient places.", "size": "about 36,500 places, with a daily open download",
         "read_by": "read_source, one place page at a time", "note": "Not yet read in bulk by these tools."},
        {"name": "tDAR, the Digital Archaeological Record", "kind": "published records", "region": "Mostly the Americas",
         "holds": "Reports, datasets and images deposited by archaeologists.", "size": "several hundred thousand resources by its own account",
         "read_by": "read_source, one page at a time", "note": "Its search interface for programs needs approval from its staff."},
        {"name": "State and national site files", "kind": "recorded sites", "region": "Each state or country",
         "holds": "The full official record of known sites, held by a State Historic Preservation Office or a national heritage authority.",
         "size": "not public", "read_by": "none",
         "note": "This is why nothing found here is called new. A find that matches no open source is reported to the authority, which checks its own files."},
        {"name": "Not yet checked by Dighouse", "kind": "other", "region": "Various",
         "holds": "The Archaeology Data Service (UK), EAMENA (Middle East and North Africa), declassified CORONA satellite "
                  "imagery, and national lidar outside the United States (for example England, the Netherlands, Denmark, Slovenia).",
         "size": "not checked", "read_by": "none", "note": "Named so you know they exist. These tools do not read them and their sizes were not verified."},
    ]
    if topic:
        rows = [x for x in rows if topic.lower() in json.dumps(x).lower()]
    return rows
