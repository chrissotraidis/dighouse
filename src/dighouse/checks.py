"""Outside checks: is it modern, and has someone already written about it?"""

from __future__ import annotations

import html
import io
import logging
import re
import time

import httpx

OVERPASS = ("https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter")
OPENALEX = "https://api.openalex.org/works"
logging.getLogger("httpx").setLevel(logging.WARNING)
_client = httpx.Client(timeout=40, follow_redirects=True,
                       headers={"User-Agent": "dighouse/0.1 (https://github.com/chrissotraidis/dighouse)"})
_READER = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
           "Accept": "text/html,application/pdf;q=0.9,*/*;q=0.8"}


def modern_features(lon: float, lat: float, radius_m: int = 300) -> dict:
    """What OpenStreetMap has mapped around a point: roads, buildings, land use, and known sites."""
    around = f"(around:{radius_m},{lat},{lon})"
    query = f"""[out:json][timeout:40];
(way{around}[highway]; way{around}[building]; way{around}[landuse]; nwr{around}[man_made];
 nwr(around:2000,{lat},{lon})[historic];);
out tags 200;"""
    r = None
    # the public map services refuse requests that arrive too close together, so alternate between two and wait
    for wait, host in ((0, OVERPASS[0]), (0, OVERPASS[1]), (6, OVERPASS[0]), (6, OVERPASS[1])):
        time.sleep(wait)
        try:
            r = _client.post(host, data={"data": query})
        except httpx.HTTPError:
            continue
        if r.status_code == 200:
            break
    if r is None or r.status_code != 200:
        raise RuntimeError("The open map service is busy and did not answer. Wait a minute, then run this check again.")
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
