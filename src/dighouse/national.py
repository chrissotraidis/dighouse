"""National lidar published as ready-made ground models: England, the Netherlands, France, Flanders, Norway, Estonia
and Switzerland.

These services hand out a bare-ground raster (a DTM) built by the national mapping agency,
not raw points. The terrain is as good as their ground classification; a section through it
shows the ground profile only, with no canopy to compare against.
"""

from __future__ import annotations

import io
import math
import time
from concurrent.futures import ThreadPoolExecutor

import httpx
import numpy as np
import rasterio

from . import sources

NATIONAL = {
    "uk:ea-dtm-1m": {
        "title": "Environment Agency lidar composite DTM, 1 m (England)",
        "source": "Environment Agency", "country": "England", "outline": [(-5.8, 50.0), (-4.2, 50.3), (-3.0, 50.6), (-1.0, 50.7), (1.4, 51.1), (1.8, 52.6), (0.3, 53.5), (-0.1, 54.5), (-1.6, 55.65), (-2.1, 55.85), (-3.1, 55.05), (-3.6, 54.5), (-3.1, 53.35), (-2.95, 52.0), (-2.65, 51.6), (-3.6, 51.2), (-4.6, 51.1), (-5.8, 50.0)],
        "epsg": 27700, "res": 1.0, "kind": "wcs", "axes": ("E", "N"), "chunk_px": 500, "parallel": 1,
        "url": "https://environment.data.gov.uk/spatialdata/lidar-composite-digital-terrain-model-dtm-1m/wcs",
        "coverage": "13787b9a-26a4-4775-8523-806d13af58fc__Lidar_Composite_Elevation_DTM_1m",
        "citation": "Contains Environment Agency information © Environment Agency and/or database right. Open Government Licence v3.0.",
        "landing_page": "https://environment.data.gov.uk/dataset/13787b9a-26a4-4775-8523-806d13af58fc",
    },
    "nl:ahn-dtm-05m": {
        "title": "AHN, Actueel Hoogtebestand Nederland, DTM 0.5 m (Netherlands)",
        "source": "Rijkswaterstaat / PDOK", "country": "the Netherlands", "outline": [(3.3, 51.4), (3.4, 51.2), (5.8, 51.0), (6.0, 50.75), (6.2, 51.4), (6.9, 51.9), (7.25, 53.2), (6.9, 53.6), (4.8, 53.4), (4.5, 52.5), (3.9, 51.9), (3.3, 51.4)],
        "epsg": 28992, "res": 0.5, "kind": "wcs", "axes": ("x", "y"),
        "url": "https://service.pdok.nl/rws/ahn/wcs/v1_0", "coverage": "dtm_05m",
        "citation": "AHN, Rijkswaterstaat, via PDOK. CC0 1.0.",
        "landing_page": "https://www.ahn.nl",
    },
    "fr:lidarhd-mnt": {
        "title": "IGN LiDAR HD, ground model (MNT) 0.5 m (France)",
        "source": "IGN", "country": "metropolitan France", "outline": [(-4.9, 48.4), (-1.6, 48.7), (-1.4, 49.75), (1.6, 50.95), (2.55, 51.1), (4.2, 49.95), (6.4, 49.5), (8.25, 48.95), (7.6, 47.55), (6.9, 47.35), (6.0, 46.2), (7.05, 45.9), (6.6, 45.1), (7.6, 43.8), (6.2, 43.05), (3.1, 43.0), (3.2, 42.4), (-1.8, 43.35), (-1.2, 46.0), (-2.6, 47.3), (-4.9, 48.4)],
        "epsg": 2154, "res": 0.5, "kind": "wms",
        "url": "https://data.geopf.fr/wms-r/wms", "coverage": "IGNF_LIDAR-HD_MNT_ELEVATION.ELEVATIONGRIDCOVERAGE.LAMB93",
        "citation": "IGN, LiDAR HD. Licence Ouverte Etalab 2.0.",
        "landing_page": "https://geoservices.ign.fr/lidarhd",
    },
    "be:dhmv-dtm-1m": {
        "title": "Digitaal Hoogtemodel Vlaanderen II, DTM 1 m (Flanders, Belgium)",
        "source": "Digitaal Vlaanderen", "country": "Flanders", "maker": "the Flemish government",
        "outline": [(2.55, 51.09), (3.37, 51.37), (4.24, 51.37), (5.04, 51.49), (5.85, 51.16), (5.9, 50.75), (5.1, 50.71), (4.3, 50.69), (3.2, 50.71), (2.6, 50.8), (2.55, 51.09)],
        "epsg": 31370, "res": 1.0, "kind": "wcs", "axes": ("x", "y"), "chunk_px": 500, "parallel": 2,
        "url": "https://geo.api.vlaanderen.be/DHMV/wcs", "coverage": "DHMVII_DTM_1m",
        "citation": "Digitaal Hoogtemodel Vlaanderen II, Digitaal Vlaanderen. Open data of the Flemish government.",
        "landing_page": "https://www.vlaanderen.be/digitaal-vlaanderen/onze-oplossingen/earth-observation-data-science-eodas/het-digitaal-hoogtemodel/digitaal-hoogtemodel-vlaanderen-ii",
    },
    "no:nhm-dtm-1m": {
        "title": "Nasjonal høydemodell, DTM 1 m (Norway)",
        "source": "Kartverket", "country": "Norway",
        "outline": [(4.6, 58.0), (7.0, 57.9), (11.8, 58.9), (12.6, 60.0), (12.2, 63.5), (14.5, 65.5), (16.5, 68.5), (20.5, 69.0), (26.0, 69.9), (31.2, 70.4), (28.0, 71.2), (20.0, 70.3), (13.5, 68.3), (10.5, 64.5), (4.8, 62.0), (4.6, 58.0)],
        "epsg": 25833, "res": 1.0, "kind": "wcs1", "chunk_px": 500, "parallel": 2,
        "url": "https://wcs.geonorge.no/skwms1/wcs.hoyde-dtm-nhm-25833", "coverage": "nhm_dtm_topo_25833",
        "citation": "Nasjonal høydemodell, © Kartverket. CC BY 4.0.",
        "landing_page": "https://hoydedata.no",
    },
    "ee:dtm-1m": {
        "title": "Estonian elevation model, DTM 1 m (Estonia)",
        "source": "Estonian Land and Spatial Development Board", "country": "Estonia",
        "outline": [(21.7, 57.9), (23.3, 57.5), (26.5, 57.5), (27.4, 57.5), (28.2, 59.4), (26.0, 59.7), (23.4, 59.5), (21.7, 58.9), (21.7, 57.9)],
        "epsg": 3301, "res": 1.0, "kind": "wcs", "axes": ("x", "y"), "chunk_px": 500, "parallel": 2,
        "url": "https://teenus.maaamet.ee/ows/wcs-dtm", "coverage": "dtm-1",
        "citation": "Elevation data, Estonian Land and Spatial Development Board. Open data.",
        "landing_page": "https://geoportaal.maaamet.ee/eng/Spatial-Data/Elevation-data-p308.html",
    },
    "ch:swissalti3d-05m": {
        "title": "swissALTI3D, DTM 0.5 m (Switzerland)",
        "source": "swisstopo", "country": "Switzerland",
        "outline": [(5.95, 46.13), (6.8, 45.83), (7.9, 45.9), (9.0, 45.82), (10.5, 46.5), (10.45, 46.95), (9.5, 47.55), (8.6, 47.82), (7.5, 47.6), (6.0, 46.6), (5.95, 46.13)],
        "epsg": 2056, "res": 0.5, "kind": "files", "chunk_px": 2000, "parallel": 2,
        "url": "https://data.geo.admin.ch/api/stac/v0.9/collections/ch.swisstopo.swissalti3d/items",
        "citation": "swissALTI3D, © swisstopo. Open government data.",
        "landing_page": "https://www.swisstopo.admin.ch/en/height-model-swissalti3d",
    },
}
CHUNK_PX = 1000  # the services answer faster for several small requests than for one large one
_client = httpx.Client(timeout=120, follow_redirects=True,
                       headers={"User-Agent": "dighouse/0.1 (https://github.com/chrissotraidis/dighouse)"})


def _inside(x: float, y: float, ring: list[tuple[float, float]]) -> bool:
    hit = False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            hit = not hit
    return hit


def _overlaps(bbox: list[float], ring: list[tuple[float, float]]) -> bool:
    """A coarse test: a corner or the centre of the box is in the country, or a point of its outline is in the box."""
    w, s, e, n = bbox
    probes = [(w, s), (w, n), (e, s), (e, n), ((w + e) / 2, (s + n) / 2)]
    return any(_inside(x, y, ring) for x, y in probes) or any(w <= x <= e and s <= y <= n for x, y in ring)


def find(bbox: list[float]) -> list[dict]:
    """National ground models whose country overlaps a lon/lat box."""
    out = []
    for key, d in NATIONAL.items():
        if _overlaps(bbox, d["outline"]):
            out.append({"id": key, "source": d["source"], "title": d["title"], "landing_page": d["landing_page"],
                        "citation": d["citation"], "ready_made_ground_model": True,
                        "about": f"A bare-ground model for {d['country']} at {d['res']:g} m, built by {d.get('maker', 'the national agency')} from its lidar. "
                                 "The box is matched against a rough outline of the country; parts of it with no data come back as outside the survey."})
    return out


def _chunk(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    tries = 6
    for attempt in range(tries):  # these services time out or limit the request rate now and then
        wait = 5 * (attempt + 1)
        try:
            return _request(d, x0, y0, x1, y1)
        except httpx.HTTPStatusError as exc:
            code = exc.response.status_code
            if (code != 429 and code < 500) or attempt == tries - 1:
                raise
            if code == 429:  # too many requests: wait as long as the server asks, or longer each time
                after = exc.response.headers.get("Retry-After", "")
                wait = int(after) if after.isdigit() else 20 * (attempt + 1)
        except httpx.TimeoutException:
            if attempt == tries - 1:
                raise
        for _ in range(int(min(wait, 90))):  # wait in short steps, so a cancelled fetch ends promptly
            if sources.cancelled():
                raise RuntimeError("Stopped by the person before the download finished.")
            time.sleep(1)
    raise RuntimeError("unreachable")


def _from_files(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    """A ground model published as one file for each map sheet: ask the catalog which sheets cover the box, and read only
    the part of each that is needed. Where a sheet was flown more than once, the newest is used."""
    from pyproj import Transformer
    from rasterio.windows import from_bounds

    res = d["res"]
    back = Transformer.from_crs(d["epsg"], 4326, always_xy=True)
    west, south = back.transform(x0, y0)
    east, north = back.transform(x1, y1)
    r = _client.get(d["url"], params={"bbox": f"{west},{south},{east},{north}", "limit": 100})
    r.raise_for_status()
    newest: dict[str, tuple[str, str]] = {}
    for item in r.json().get("features", []):
        _, year, sheet = item["id"].split("_")[:3]
        link = next((a["href"] for name, a in item["assets"].items() if name.endswith(".tif") and a.get("eo:gsd") == res), None)
        if link and (sheet not in newest or year > newest[sheet][0]):
            newest[sheet] = (year, link)
    out = np.full((int(round((y1 - y0) / res)), int(round((x1 - x0) / res))), np.nan, np.float32)
    for _, link in newest.values():
        with rasterio.open("/vsicurl/" + link) as src:
            part = src.read(1, window=from_bounds(x0, y0, x1, y1, src.transform), boundless=True, fill_value=np.nan, out_shape=out.shape).astype(np.float32)
            if src.nodata is not None:
                part[part == src.nodata] = np.nan
        out = np.where(np.isnan(out), part, out)
    return out, x0, y1, res, None


def _request(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    if d["kind"] == "files":
        return _from_files(d, x0, y0, x1, y1)
    if d["kind"] == "wcs1":  # the older form of the request, which some servers still want
        res = d["res"]
        r = _client.get(d["url"], params={
            "service": "WCS", "version": "1.0.0", "request": "GetCoverage", "coverage": d["coverage"], "crs": f"EPSG:{d['epsg']}",
            "bbox": f"{x0},{y0},{x1},{y1}", "width": int(round((x1 - x0) / res)), "height": int(round((y1 - y0) / res)), "format": "GeoTIFF"})
    elif d["kind"] == "wms":
        res = d["res"]
        r = _client.get(d["url"], params={
            "SERVICE": "WMS", "VERSION": "1.3.0", "REQUEST": "GetMap", "LAYERS": d["coverage"], "STYLES": "",
            "CRS": f"EPSG:{d['epsg']}", "BBOX": f"{x0},{y0},{x1},{y1}", "FORMAT": "image/geotiff",
            "WIDTH": int(round((x1 - x0) / res)), "HEIGHT": int(round((y1 - y0) / res))})
    else:
        ax, ay = d["axes"]
        r = _client.get(d["url"], params=[
            ("service", "WCS"), ("version", "2.0.1"), ("request", "GetCoverage"), ("coverageId", d["coverage"]),
            ("format", "image/tiff"), ("subset", f"{ax}({x0},{x1})"), ("subset", f"{ay}({y0},{y1})")])
    r.raise_for_status()
    body = r.content
    if "multipart" in r.headers.get("content-type", ""):  # some servers wrap the picture in a description of it
        start = max(body.find(b"II*\x00"), body.find(b"MM\x00*"))
        body = body[start:] if start >= 0 else body
    elif "xml" in r.headers.get("content-type", "") or body[:5] == b"<?xml" or "html" in r.headers.get("content-type", ""):
        raise RuntimeError(f"{d['source']} refused the request: {r.text[:200]}")
    with rasterio.open(io.BytesIO(body)) as src:
        a = src.read(1).astype(np.float32)
        t = src.transform
        return a, t.c, t.f, t.a, src.nodata


def fetch_dtm(dataset: str, bbox: list[float], res: float | None = None) -> tuple[np.ndarray, np.ndarray, float, float, float, int, dict]:
    """Download a national ground model for a lon/lat box. Returns the model, the no-data mask, its corner, cell size and EPSG."""
    d = NATIONAL.get(dataset)
    if not d:
        raise ValueError(f"Unknown national dataset {dataset!r}.")
    res = max(res or d["res"], d["res"])
    x0, y0, x1, y1 = (math.floor(v / res) * res if i < 2 else math.ceil(v / res) * res
                      for i, v in enumerate(sources.project_bbox(bbox, d["epsg"])))
    cols, rows = int(round((x1 - x0) / res)), int(round((y1 - y0) / res))
    dtm = np.full((rows, cols), np.nan, np.float32)
    step = d.get("chunk_px", CHUNK_PX) * d["res"]
    parts = [(cx, cy, min(cx + step, x1), min(cy + step, y1))
             for cx in np.arange(x0, x1, step) for cy in np.arange(y0, y1, step)]
    sources.progress(0, len(parts))
    with ThreadPoolExecutor(d.get("parallel", 4)) as pool:
        got = list(pool.map(sources._counted(lambda b: (b, _chunk(d, *b)), len(parts)), parts))
    for _, (a, left, top, cell, nodata) in got:
        if nodata is not None:
            a[a == nodata] = np.nan
        a[(a < -500) | (a > 9000)] = np.nan  # sentinel values the services use for "no data"
        if abs(cell - res) > 1e-3:  # resample to the requested cell size
            k = max(int(round(res / cell)), 1)
            h, w = a.shape[0] // k * k, a.shape[1] // k * k
            a = np.nanmean(a[:h, :w].reshape(h // k, k, w // k, k), axis=(1, 3))
            cell = res
        r0, c0 = int(round((y1 - top) / res)), int(round((left - x0) / res))
        rr0, cc0 = max(r0, 0), max(c0, 0)
        rr1, cc1 = min(r0 + a.shape[0], rows), min(c0 + a.shape[1], cols)
        if rr1 > rr0 and cc1 > cc0:
            block = a[rr0 - r0:rr1 - r0, cc0 - c0:cc1 - c0]
            target = dtm[rr0:rr1, cc0:cc1]
            dtm[rr0:rr1, cc0:cc1] = np.where(np.isnan(block), target, block)
    outside = np.isnan(dtm)
    if outside.all():
        raise ValueError(f"{d['source']} has no ground model inside this box. It covers {d['country']} only.")
    if outside.any():
        dtm[outside] = float(np.nanmedian(dtm))
    how = {"source": d["source"], "citation": d["citation"], "ready_made_ground_model": True, "requests": len(parts)}
    return dtm, outside, x0, y1, res, d["epsg"], how
