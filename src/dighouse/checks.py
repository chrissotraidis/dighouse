"""Outside checks: is it modern, and has someone already written about it?"""

from __future__ import annotations

import logging

import httpx

OVERPASS = "https://overpass-api.de/api/interpreter"
OPENALEX = "https://api.openalex.org/works"
logging.getLogger("httpx").setLevel(logging.WARNING)
_client = httpx.Client(timeout=60, follow_redirects=True, headers={"User-Agent": "dighouse/0.1"})


def modern_features(lon: float, lat: float, radius_m: int = 300) -> dict:
    """What OpenStreetMap has mapped around a point: roads, buildings, land use, and known sites."""
    around = f"(around:{radius_m},{lat},{lon})"
    query = f"""[out:json][timeout:40];
(way{around}[highway]; way{around}[building]; way{around}[landuse]; nwr{around}[man_made];
 nwr(around:2000,{lat},{lon})[historic];);
out tags 200;"""
    r = _client.post(OVERPASS, data={"data": query})
    r.raise_for_status()
    kinds = {"roads": [], "buildings": [], "land_use": [], "structures": [], "historic_within_2km": []}
    for el in r.json().get("elements", []):
        tags = el.get("tags", {})
        if "historic" in tags:
            kinds["historic_within_2km"].append(tags.get("name") or tags["historic"])
        elif "highway" in tags:
            kinds["roads"].append(tags.get("name") or tags["highway"])
        elif "building" in tags:
            kinds["buildings"].append(tags.get("name") or tags["building"])
        elif "landuse" in tags:
            kinds["land_use"].append(tags["landuse"])
        elif "man_made" in tags:
            kinds["structures"].append(tags["man_made"])
    out = {k: sorted(set(v)) for k, v in kinds.items()}
    nearby = sum(len(kinds[k]) for k in ("roads", "buildings", "land_use", "structures"))
    out["mapped_features_within_radius"] = nearby
    out["radius_m"] = radius_m
    return out


def search_literature(query: str, limit: int = 15) -> list[dict]:
    """Search OpenAlex, a free index of scholarly works."""
    r = _client.get(OPENALEX, params={"search": query, "per-page": limit})
    r.raise_for_status()
    out = []
    for w in r.json().get("results", []):
        out.append({
            "title": w.get("title"),
            "year": w.get("publication_year"),
            "authors": [a["author"]["display_name"] for a in w.get("authorships", [])[:4]],
            "doi": w.get("doi"),
            "open_copy": (w.get("open_access") or {}).get("oa_url"),
            "cited_by": w.get("cited_by_count"),
        })
    return out
