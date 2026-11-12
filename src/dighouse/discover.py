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
    return sorted(found, key=lambda s: (s["checked_start"] is None, not s["fetchable_without_account"], s["title"]))


def known_sites(bbox: list[float], limit: int = 200) -> list[dict]:
    """Archaeological sites Wikidata records inside a lon/lat box."""
    w, s, e, n = bbox
    query = f"""SELECT DISTINCT ?item ?itemLabel ?kindLabel ?loc WHERE {{
  SERVICE wikibase:box {{ ?item wdt:P625 ?loc .
    bd:serviceParam wikibase:cornerSouthWest "Point({w} {s})"^^geo:wktLiteral .
    bd:serviceParam wikibase:cornerNorthEast "Point({e} {n})"^^geo:wktLiteral . }}
  ?item wdt:P31 ?kind . ?kind wdt:P279* wd:Q839954 .
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }} }} LIMIT {limit}"""
    r = _client.get(WIKIDATA, params={"query": query}, headers={"Accept": "application/sparql-results+json"})
    r.raise_for_status()
    cx, cy = (w + e) / 2, (s + n) / 2
    sites: dict[str, dict] = {}
    for row in r.json()["results"]["bindings"]:
        lon, lat = (float(v) for v in re.findall(r"-?\d+\.?\d*", row["loc"]["value"])[:2])
        east_km = (lon - cx) * 111.32 * math.cos(math.radians(cy))
        north_km = (lat - cy) * 110.54
        bearing = (math.degrees(math.atan2(east_km, north_km)) + 360) % 360
        sites.setdefault(row["item"]["value"], {
            "name": row["itemLabel"]["value"], "kind": row["kindLabel"]["value"],
            "km_from_centre": round(math.hypot(east_km, north_km), 1),
            "direction": ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][int((bearing + 22.5) // 45) % 8],
            "record": row["item"]["value"]})
    return sorted(sites.values(), key=lambda site: site["km_from_centre"])


def survey_area(bbox: list[float]) -> dict:
    """What is openly available and already recorded for an area: lidar coverage and known sites."""
    w, s, e, n = bbox
    if e - w > 2 or n - s > 2:
        raise ValueError("Keep the area under 2 degrees on a side. Use find_place to narrow it down first.")
    out: dict = {"area_km2": round((e - w) * 111.32 * math.cos(math.radians((s + n) / 2)) * (n - s) * 110.54)}
    lidar = sources.find_data(bbox)
    out["open_lidar"] = [{k: d.get(k) for k in ("id", "source", "title", "collected")} for d in lidar if d.get("id")]
    try:
        sites = known_sites(bbox)
        out["known_sites"] = {"count": len(sites), "nearest": sites[:40]}
    except httpx.HTTPError as exc:
        out["known_sites"] = {"error": f"Wikidata did not answer: {exc}"}
    out["how_to_read"] = ("Open lidar with few recorded sites is where a search adds most. Recorded sites are from Wikidata, "
                          "which is far from complete: an empty list does not mean nothing is known there.")
    return out
