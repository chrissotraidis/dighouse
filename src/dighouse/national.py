"""National lidar published as ready-made ground models: England, the Netherlands and France.

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
                        "about": f"A bare-ground model for {d['country']} at {d['res']:g} m, built by the national agency from its lidar. "
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
        time.sleep(min(wait, 90))
    raise RuntimeError("unreachable")


def _request(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    if d["kind"] == "wms":
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
    if "xml" in r.headers.get("content-type", "") or r.content[:5] == b"<?xml":
        raise RuntimeError(f"{d['source']} refused the request: {r.text[:200]}")
    with rasterio.open(io.BytesIO(r.content)) as src:
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
    with ThreadPoolExecutor(d.get("parallel", 4)) as pool:
        got = list(pool.map(lambda b: (b, _chunk(d, *b)), parts))
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
