"""Outside checks: is it modern, and has someone already written about it?"""

from __future__ import annotations

import html
import io
import logging
import math
import re
import time

import httpx

OVERPASS = ("https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter")
OSM_MAP = "https://api.openstreetmap.org/api/0.6/map.json"
_overpass_back = 0.0  # when to try the Overpass servers again after both failed
OPENALEX = "https://api.openalex.org/works"
logging.getLogger("httpx").setLevel(logging.WARNING)
_client = httpx.Client(timeout=40, follow_redirects=True,
                       headers={"User-Agent": "dighouse/0.1 (https://github.com/chrissotraidis/dighouse)"})
_READER = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
           "Accept": "text/html,application/pdf;q=0.9,*/*;q=0.8"}


def _sort(elements: list[dict], near: set | None = None, far: set | None = None) -> dict[str, list[str]]:
    """Mapped things by kind. near and far say which elements are within the radius and within 2 km; None means all are."""
    kinds = {"roads": [], "buildings": [], "land_use": [], "structures": [], "historic_within_2km": []}
    for el in elements:
        tags, key = el.get("tags") or {}, (el.get("type"), el.get("id"))
        if "historic" in tags:
            if far is None or key in far:
                kinds["historic_within_2km"].append(tags.get("name") or tags["historic"])
        elif near is not None and (key not in near or el.get("type") == "node" and "man_made" not in tags):
            continue
        elif "highway" in tags:
            kinds["roads"].append(tags.get("name") or tags["highway"])
        elif "building" in tags:
            kinds["buildings"].append(tags.get("name") or (tags["building"] if tags["building"] != "yes" else "a building"))
        elif "landuse" in tags:
            kinds["land_use"].append(tags["landuse"])
        elif "man_made" in tags:
            kinds["structures"].append(tags["man_made"])
    return kinds


def _overpass(lon: float, lat: float, radius_m: int) -> list[dict] | None:
    around = f"(around:{radius_m},{lat},{lon})"
    query = f"""[out:json][timeout:18];
(way{around}[highway]; way{around}[building]; way{around}[landuse]; nwr{around}[man_made];
 nwr(around:2000,{lat},{lon})[historic];);
out tags 200;"""
    global _overpass_back
    if time.monotonic() < _overpass_back:
        return None
    for host in OVERPASS:
        try:
            r = _client.post(host, data={"data": query}, timeout=12)
        except httpx.HTTPError:
            continue
        if r.status_code == 200:
            return r.json().get("elements", [])
    # Both are down. Do not make the next ten minutes of checks wait for them again.
    _overpass_back = time.monotonic() + 600
    return None


def _map_box(lon: float, lat: float, reach_m: float) -> list[dict] | None:
    """Everything OpenStreetMap's own map service holds in a square around a point. None when it refuses or is down."""
    dy, dx = reach_m / 111_320, reach_m / (111_320 * max(0.1, math.cos(math.radians(lat))))
    try:
        r = _client.get(OSM_MAP, params={"bbox": f"{lon - dx:.6f},{lat - dy:.6f},{lon + dx:.6f},{lat + dy:.6f}"}, timeout=25)
    except httpx.HTTPError:
        return None
    return r.json().get("elements", []) if r.status_code == 200 else None  # 400 means the square holds too much


def _within(elements: list[dict], lon: float, lat: float, reach_m: float) -> set:
    """Which elements come within reach of the point. A way is measured along its line, as the Overpass servers do."""
    k = 111_320 * math.cos(math.radians(lat))
    spot = {e["id"]: ((e["lon"] - lon) * k, (e["lat"] - lat) * 111_320) for e in elements if e.get("type") == "node"}

    def to_line(a, b) -> float:
        (ax, ay), (bx, by) = a, b
        ux, uy = bx - ax, by - ay
        t = 0 if not (ux or uy) else max(0, min(1, -(ax * ux + ay * uy) / (ux * ux + uy * uy)))
        return math.hypot(ax + t * ux, ay + t * uy)

    close: set = set()
    for e in elements:
        if e.get("type") == "node" and math.hypot(*spot[e["id"]]) <= reach_m:
            close.add(("node", e["id"]))
        elif e.get("type") == "way":
            pts = [spot[n] for n in e.get("nodes", []) if n in spot]
            if any(to_line(a, b) <= reach_m for a, b in zip(pts, pts[1:] or pts)):
                close.add(("way", e["id"]))
    for e in elements:
        if e.get("type") == "relation" and any((m.get("type"), m.get("ref")) in close for m in e.get("members", [])):
            close.add(("relation", e["id"]))
    return close


def modern_features(lon: float, lat: float, radius_m: int = 300) -> dict:
    """What OpenStreetMap has mapped around a point: roads, buildings, land use, and known sites.

    There are two ways in. The Overpass servers answer exactly this question, but they are public and often full.
    OpenStreetMap's own map service hands over everything in a small square, and the sorting is done here.
    """
    historic_m, via = 2000, "the Overpass servers"
    found = _overpass(lon, lat, radius_m)
    if found is not None:
        kinds = _sort(found)
    else:
        via = "OpenStreetMap's map service"
        box = _map_box(lon, lat, 2000)
        if box is None:
            # A square of 4 km can hold more than the service gives at once (a town does). Ask for the radius alone.
            box, historic_m = _map_box(lon, lat, radius_m), radius_m
        if box is None:
            raise RuntimeError("The open map services (OpenStreetMap's Overpass servers and its own map service) did not answer; "
                               "they are busy or down. Leave this check for now and carry on; run it again later.")
        kinds = _sort(box, _within(box, lon, lat, radius_m), _within(box, lon, lat, historic_m))
    out = {k: sorted(set(v)) for k, v in kinds.items()}
    out["mapped_features_within_radius"] = sum(len(kinds[k]) for k in ("roads", "buildings", "land_use", "structures"))
    out["radius_m"] = radius_m
    out["historic_searched_within_m"] = historic_m
    out["asked"] = via
    return out


def _abstract(index: dict | None) -> str:
    """OpenAlex stores an abstract as each word with its positions. Put the words back in order."""
    if not index:
        return ""
    words = sorted((place, word) for word, places in index.items() for place in places)
    return " ".join(word for _, word in words)[:1500]


def read_source(url: str, start: int = 0, max_chars: int = 12000) -> dict:
    """Open a web page or a PDF and return its text, a part at a time."""
    r = _client.get(url)
    if r.status_code in (401, 402, 403, 406, 429):
        r = _client.get(url, headers=_READER)  # some publishers only answer a browser
    if r.status_code in (401, 402, 403):
        raise RuntimeError(f"The publisher refused to show this page (status {r.status_code}). Log it as could_not_open.")
    r.raise_for_status()
    if r.content[:5] == b"%PDF-" or "pdf" in r.headers.get("content-type", ""):
        from pypdf import PdfReader

        text = "\n".join(page.extract_text() or "" for page in PdfReader(io.BytesIO(r.content)).pages)
    else:
        body = re.sub(r"(?is)<(script|style|nav|header|footer)\b.*?</\1>", " ", r.text)
        text = html.unescape(re.sub(r"(?s)<[^>]+>", " ", body))
    text = re.sub(r"[^\S\n]+", " ", text)
    text = re.sub(r"\s*\n\s*", "\n", text).strip()
    if len(text) < 200:
        raise RuntimeError("The page opened but held no readable text. It may need a sign-in or be a scanned image. "
                           "Log it as could_not_open.")
    return {"url": str(r.url), "characters": len(text), "start": start, "text": text[start:start + max_chars],
            "more_from": start + max_chars if len(text) > start + max_chars else None}


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
            "abstract": _abstract(w.get("abstract_inverted_index")),
        })
    return out
