"""Outside checks: is it modern, and has someone already written about it?"""

from __future__ import annotations

import hashlib
import tempfile
import threading
from pathlib import Path

import html
import io
import ipaddress
import logging
import math
import re
import socket
import time

import httpx

OVERPASS = ("https://overpass-api.de/api/interpreter", "https://overpass.private.coffee/api/interpreter")
OSM_MAP = "https://api.openstreetmap.org/api/0.6/map.json"
_overpass_back = 0.0  # when to try the Overpass servers again after both failed
OPENALEX = "https://api.openalex.org/works"
CROSSREF = "https://api.crossref.org/works"
logging.getLogger("httpx").setLevel(logging.WARNING)
_client = httpx.Client(timeout=40, follow_redirects=True,
                       headers={"User-Agent": "dighouse/0.1 (https://github.com/chrissotraidis/dighouse)"})
_READER = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
           "Accept": "text/html,application/pdf;q=0.9,*/*;q=0.8"}
# The largest source the agent downloads. Scanned site reports run to tens of megabytes; nothing a person reads is larger.
MAX_SOURCE_BYTES = 150_000_000


def _public_only(request: httpx.Request) -> None:
    """Sources come from pages anyone can write, so a link, or a redirect, may point at this Mac or the local network.
    Those are refused before anything is sent."""
    url = request.url
    if url.scheme not in ("http", "https"):
        raise RuntimeError("Only web addresses (http or https) are opened. Log it as could_not_open.")
    try:
        infos = socket.getaddrinfo(url.host, url.port or (443 if url.scheme == "https" else 80), proto=socket.IPPROTO_TCP)
    except socket.gaierror as e:
        raise RuntimeError(f"The address {url.host} could not be found. Log it as could_not_open.") from e
    for info in infos:
        if not ipaddress.ip_address(info[4][0].split("%")[0]).is_global:
            raise RuntimeError(f"{url.host} is on this Mac or a private network, so it is not opened. Log it as could_not_open.")


_sources_client = httpx.Client(timeout=60, follow_redirects=True, headers=dict(_client.headers),
                               event_hooks={"request": [_public_only]})


def _sort(elements: list[dict], near: set | None = None, far: set | None = None, named: bool = True) -> dict[str, list[str]]:
    """Mapped things by kind. near and far say which elements are within the radius and within 2 km; None means all are.
    named=False leaves out the names (a blind test must not learn where it is) and keeps only what kind of thing each is."""
    def name(tags):
        return tags.get("name") if named else None
    kinds = {"roads": [], "buildings": [], "land_use": [], "structures": [], "historic_within_2km": []}
    for el in elements:
        tags, key = el.get("tags") or {}, (el.get("type"), el.get("id"))
        if "historic" in tags:
            if far is None or key in far:
                kinds["historic_within_2km"].append(name(tags) or tags["historic"])
        elif near is not None and (key not in near or el.get("type") == "node" and "man_made" not in tags):
            continue
        elif "highway" in tags:
            kinds["roads"].append(name(tags) or tags["highway"])
        elif "building" in tags:
            kinds["buildings"].append(name(tags) or (tags["building"] if tags["building"] != "yes" else "a building"))
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


_boxes: dict[tuple, list[dict] | None] = {}


def _map_box(lon: float, lat: float, reach_m: float, shared: bool = True) -> list[dict] | None:
    """Everything OpenStreetMap's own map service holds in a square around a point. None when it refuses or is down.
    A shared square is kept for the session by its 0.01-degree cell, wide enough for any point in the cell, so the
    hundreds of finds in one area share a few downloads instead of each asking a service that soon turns them away.
    shared=False asks for the point's own square, the smallest the service can be asked for."""
    cell = (round(lon, 2), round(lat, 2), reach_m) if shared else (lon, lat, reach_m, "own")
    if cell in _boxes:
        return _boxes[cell]
    if shared:
        lon, lat, reach_m = cell[0], cell[1], reach_m + 800  # half a cell is at most about 560 m from its centre
    dy, dx = reach_m / 111_320, reach_m / (111_320 * max(0.1, math.cos(math.radians(lat))))
    try:
        r = _client.get(OSM_MAP, params={"bbox": f"{lon - dx:.6f},{lat - dy:.6f},{lon + dx:.6f},{lat + dy:.6f}"}, timeout=25)
    except httpx.HTTPError:
        return None
    if r.status_code == 400:  # the square holds too much, and will next time too
        _boxes[cell] = None
    elif r.status_code == 200:
        _boxes[cell] = r.json().get("elements", [])
    return _boxes.get(cell)


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


def modern_features(lon: float, lat: float, radius_m: int = 300, named: bool = True) -> dict:
    """What OpenStreetMap has mapped around a point: roads, buildings, land use, and known sites.

    There are two ways in. The Overpass servers answer exactly this question, but they are public and often full.
    OpenStreetMap's own map service hands over everything in a small square, and the sorting is done here.
    """
    historic_m, via = 2000, "the Overpass servers"
    found = _overpass(lon, lat, radius_m)
    if found is not None:
        kinds = _sort(found, named=named)
    else:
        via = "OpenStreetMap's map service"
        box = _map_box(lon, lat, 2000)
        if box is None:
            # A square of 4 km can hold more than the service gives at once (a town does). Ask for the radius alone.
            box, historic_m = _map_box(lon, lat, radius_m), radius_m
        if box is None:
            # Where even a shared square holds too much (a town), the find's own square, as before squares were shared.
            box = _map_box(lon, lat, radius_m, shared=False)
        if box is None:
            raise RuntimeError("The open map services (OpenStreetMap's Overpass servers and its own map service) did not answer; "
                               "they are busy or down. Leave this check for now and carry on; run it again later.")
        kinds = _sort(box, _within(box, lon, lat, radius_m), _within(box, lon, lat, historic_m), named=named)
    out = {k: sorted(set(v)) for k, v in kinds.items()}
    out["mapped_features_within_radius"] = sum(len(kinds[k]) for k in ("roads", "buildings", "land_use", "structures"))
    out["radius_m"] = radius_m
    out["historic_searched_within_m"] = historic_m
    out["asked"] = via
    return out


ENC = "https://encdirect.noaa.gov/arcgis/rest/services/encdirect"
# Charted things on the seafloor that are modern: (service, layer, what). From NOAA's electronic charts at three scales.
ENC_MODERN = [("enc_coastal", 88, "submarine cable"), ("enc_approach", 118, "submarine cable"), ("enc_harbour", 114, "submarine cable"),
              ("enc_coastal", 127, "pipeline"), ("enc_approach", 172, "pipeline"), ("enc_harbour", 167, "pipeline"),
              ("enc_coastal", 136, "dumping ground"), ("enc_approach", 196, "dumping ground"), ("enc_harbour", 191, "dumping ground")]
ENC_WRECKS = [("enc_general", 29), ("enc_coastal", 33), ("enc_approach", 39), ("enc_harbour", 36)]


def seafloor_features(lon: float, lat: float, radius_m: int = 150, wrecks: bool = True) -> dict:
    """Charted cables, pipelines and dumping grounds near a point on the seafloor, and charted wrecks unless asked not to."""
    from concurrent.futures import ThreadPoolExecutor
    dx, dy = radius_m / (111_320 * math.cos(math.radians(lat))), radius_m / 110_540
    box = f"{lon - dx},{lat - dy},{lon + dx},{lat + dy}"

    def count(svc: str, layer: int) -> int | None:
        for attempt in range(5):  # the chart services say "could not find service" now and then, and answer a moment later
            r = _client.get(f"{ENC}/{svc}/MapServer/{layer}/query", params={
                "geometry": box, "geometryType": "esriGeometryEnvelope", "inSR": 4326, "spatialRel": "esriSpatialRelIntersects",
                "returnCountOnly": "true", "f": "json"}, timeout=60)
            if r.status_code == 200 and "error" not in (j := r.json()):
                return int(j.get("count", 0))
            time.sleep(2 * (attempt + 1))
        return None

    jobs = [(svc, layer, what) for svc, layer, what in ENC_MODERN] + ([(svc, layer, "charted wreck") for svc, layer in ENC_WRECKS] if wrecks else [])
    with ThreadPoolExecutor(2) as pool:
        counts = list(pool.map(lambda j: (j[2], count(j[0], j[1])), jobs))
    if all(n is None for _, n in counts):
        raise RuntimeError("NOAA's chart services did not answer")
    answered = {what for what, n in counts if n is not None}
    modern = sorted({what for what, n in counts if n and what != "charted wreck"})
    return {"modern": modern, "charted_wreck_within_radius": any(n for what, n in counts if what == "charted wreck"),
            "not_checked": sorted({what for what, _ in counts} - answered),
            "source": "NOAA electronic navigational charts"}


def _abstract(index: dict | None) -> str:
    """OpenAlex stores an abstract as each word with its positions. Put the words back in order."""
    if not index:
        return ""
    words = sorted((place, word) for word, places in index.items() for place in places)
    return " ".join(word for _, word in words)[:1500]


def _source_response(url: str) -> httpx.Response:
    r = _fetch_source(url)
    if r.status_code in (401, 402, 403, 406, 429):
        r = _fetch_source(url, _READER)  # some publishers only answer a browser
    if r.status_code in (401, 402, 403):
        raise RuntimeError(f"The publisher refused to show this page (status {r.status_code}). Log it as could_not_open.")
    r.raise_for_status()
    return r


def _fetch_source(url: str, headers: dict | None = None) -> httpx.Response:
    """Download a source, public addresses only, and stop at MAX_SOURCE_BYTES."""
    with _sources_client.stream("GET", url, headers=headers or {}) as r:
        if int(r.headers.get("content-length") or 0) > MAX_SOURCE_BYTES:
            raise RuntimeError("The file is too large to read here. Log it as could_not_open.")
        data = bytearray()
        for chunk in r.iter_bytes():
            data += chunk
            if len(data) > MAX_SOURCE_BYTES:
                raise RuntimeError("The file is too large to read here. Log it as could_not_open.")
        # The bytes are already decoded, so the copy carries no content encoding.
        headers = [(k, v) for k, v in r.headers.items() if k.lower() not in ("content-encoding", "content-length", "transfer-encoding")]
        return httpx.Response(r.status_code, headers=headers, content=bytes(data), request=r.request)


def _pdf_path(folder: Path, url: str) -> Path:
    return folder / (hashlib.sha256(url.encode()).hexdigest() + ".pdf")


def _keep_pdf(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as tmp:
        tmp.write(data)
    Path(tmp.name).replace(path)


def read_source(url: str, start: int = 0, max_chars: int = 12000, folder: Path | None = None) -> dict:
    """Read text and retain original PDF pages privately for figure inspection."""
    from pypdf import PdfReader

    path = _pdf_path(folder, url) if folder else None
    cached = path is not None and path.exists()
    r = None if cached else _source_response(url)
    fields = {}
    if cached or r.content.startswith(b"%PDF-") or "pdf" in r.headers.get("content-type", ""):
        reader = PdfReader(path if cached else io.BytesIO(r.content))
        if path and not cached:
            _keep_pdf(path, r.content)
        fields = {"pages": len(reader.pages), "figure_tool": "view_source_page"}
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
    else:
        body = re.sub(r"(?is)<(script|style|nav|header|footer)\b.*?</\1>", " ", r.text)
        text = html.unescape(re.sub(r"(?s)<[^>]+>", " ", body))
    text = re.sub(r"[^\S\n]+", " ", text)
    text = re.sub(r"\s*\n\s*", "\n", text).strip()
    if len(text) < 200 and not fields:
        raise RuntimeError("The page opened but held no readable text. It may need a sign-in or be a scanned image. "
                           "Log it as could_not_open.")
    return {**fields, "url": url if cached or fields else str(r.url), "characters": len(text), "start": start, "text": text[start:start + max_chars],
            "more_from": start + max_chars if len(text) > start + max_chars else None}


_pdf_render_lock = threading.Lock()  # PDFium is not thread-safe.


def source_page(folder: Path, url: str, page: int) -> tuple[dict, bytes]:
    """Render from the same private original used for reading text, including image-only PDFs."""
    import pypdfium2 as pdfium

    path = _pdf_path(folder, url)
    if not path.exists():
        response = _source_response(url)
        if not response.content.startswith(b"%PDF-"):
            raise ValueError("Use the link to the original PDF.")
        with _pdf_render_lock, pdfium.PdfDocument(response.content):
            _keep_pdf(path, response.content)
    with _pdf_render_lock, pdfium.PdfDocument(path) as document:
        if not 1 <= page <= len(document):
            raise ValueError(f"Choose a PDF page from 1 to {len(document)}.")
        leaf = document[page - 1]
        scale = min(2.5, 2200 / max(leaf.get_size()))
        bitmap = leaf.render(scale=scale)
        buffer = io.BytesIO()
        bitmap.to_pil().save(buffer, format="PNG")
        return {"url": url, "page": page, "pages": len(document)}, buffer.getvalue()


def _openalex(query: str, limit: int) -> list[dict] | None:
    """Search OpenAlex. None when it refuses: without a key, a network address shares a small daily budget, and it is
    turned away for a few seconds when the service is busy."""
    from .national import access_key
    params = {"search": query, "per-page": limit}
    # A free key has its own daily budget; sent as a header, so it is never part of an address.
    headers = {"Authorization": f"Bearer {key}"} if (key := access_key("openalex")) else {}
    r = None
    for attempt in (0, 1):
        try:
            r = _client.get(OPENALEX, params=params, headers=headers)
        except httpx.HTTPError:
            return None
        if r.status_code != 429 or attempt:
            break
        try:
            wait = float(r.json().get("retryAfter") or 10)
        except ValueError:
            wait = 10
        if wait > 12:  # the day's budget is spent, not a busy moment
            break
        time.sleep(wait)
    if r.status_code != 200:
        return None
    return [{
        "title": w.get("title"),
        "year": w.get("publication_year"),
        "authors": [a["author"]["display_name"] for a in w.get("authorships", [])[:4]],
        "doi": w.get("doi"),
        "open_copy": (w.get("open_access") or {}).get("oa_url"),
        "cited_by": w.get("cited_by_count"),
        "abstract": _abstract(w.get("abstract_inverted_index")),
        "index": "OpenAlex",
    } for w in r.json().get("results", [])]


def _crossref(query: str, limit: int) -> list[dict]:
    """Search Crossref, the publishers' own register of works. It needs no key and has no daily budget."""
    r = _client.get(CROSSREF, params={"query": query, "rows": limit,
                                      "select": "title,DOI,issued,author,abstract,is-referenced-by-count"})
    r.raise_for_status()
    out = []
    for w in r.json().get("message", {}).get("items", []):
        year = ((w.get("issued") or {}).get("date-parts") or [[None]])[0][0]
        names = [" ".join(x for x in (a.get("given"), a.get("family")) if x) or a.get("name", "") for a in w.get("author", [])[:4]]
        text = html.unescape(re.sub(r"(?s)<[^>]+>", " ", w.get("abstract") or ""))
        out.append({
            "title": " ".join(w.get("title") or []) or None,
            "year": year,
            "authors": names,
            "doi": f"https://doi.org/{w['DOI']}" if w.get("DOI") else None,
            "open_copy": None,
            "cited_by": w.get("is-referenced-by-count"),
            "abstract": " ".join(text.split())[:1500],
            "index": "Crossref",
        })
    return out


def search_literature(query: str, limit: int = 15) -> list[dict]:
    """Search the scholarly literature: OpenAlex first, and Crossref when OpenAlex turns the request away."""
    found = _openalex(query, limit)
    return found if found is not None else _crossref(query, limit)
