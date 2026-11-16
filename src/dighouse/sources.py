"""Find and fetch open lidar.

Two public sources are supported, neither of which needs an account:

- OpenTopography: datasets from its catalog, files from its public bulk bucket.
- USGS 3DEP: the public Entwine (EPT) point clouds on AWS.

Points come back in a metric projected CRS (the file's own, or the local UTM zone).
"""

from __future__ import annotations

import hashlib
import io
import json
import logging
import os
import re
import time
import zipfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import httpx
import laspy
import numpy as np
import pyproj
import shapefile

OT_CATALOG = "https://portal.opentopography.org/API/otCatalog"
OT_BULK = "https://opentopography.s3.sdsc.edu/pc-bulk"
USGS_INDEX = "https://raw.githubusercontent.com/hobuinc/usgs-lidar/master/boundaries/resources.geojson"
GROUND_CLASSES = (2, 8)  # 8 is used for near-ground returns in some reprocessed sets

logging.getLogger("httpx").setLevel(logging.WARNING)
_client = httpx.Client(timeout=120, follow_redirects=True, headers={"User-Agent": "dighouse/0.1"})


@dataclass
class Points:
    x: np.ndarray
    y: np.ndarray
    z: np.ndarray
    cls: np.ndarray
    epsg: int

    def __len__(self) -> int:
        return len(self.x)

    @property
    def ground(self) -> np.ndarray:
        return np.isin(self.cls, GROUND_CLASSES)

    def save(self, path: Path) -> None:
        np.savez(path, x=self.x, y=self.y, z=self.z, cls=self.cls, epsg=self.epsg)

    @classmethod
    def load(cls, path: Path) -> Points:
        d = np.load(path)
        return cls(d["x"], d["y"], d["z"], d["cls"], int(d["epsg"]))


def cache_dir() -> Path:
    d = Path(os.environ.get("DIGHOUSE_CACHE", Path.home() / ".cache" / "dighouse"))
    d.mkdir(parents=True, exist_ok=True)
    return d


def utm_epsg(lon: float, lat: float) -> int:
    return (32600 if lat >= 0 else 32700) + int((lon + 180) // 6) + 1


def to_xy(epsg: int, lon, lat):
    return pyproj.Transformer.from_crs(4326, epsg, always_xy=True).transform(lon, lat)


def to_lonlat(epsg: int, x, y):
    return pyproj.Transformer.from_crs(epsg, 4326, always_xy=True).transform(x, y)


def project_bbox(bbox: list[float], epsg: int) -> tuple[float, float, float, float]:
    """Lon/lat box (west, south, east, north) to the bounding box of its corners in a projected CRS."""
    w, s, e, n = bbox
    xs, ys = to_xy(epsg, [w, e, w, e], [s, s, n, n])
    return min(xs), min(ys), max(xs), max(ys)


# ---------------------------------------------------------------- finding data


def find_data(bbox: list[float]) -> list[dict]:
    """List open lidar datasets that overlap a lon/lat box."""
    found = []
    errors = []
    from . import national
    for finder in (_find_opentopography, _find_usgs, national.find):
        try:
            found += finder(bbox)
        except Exception as exc:  # one source being down should not hide the other
            errors.append(f"{finder.__name__[6:]}: {exc}")
    if errors:
        found.append({"errors": errors})
    if any(d.get("seafloor") for d in found):
        # A sonar survey covers the box, so it is at least partly under water: airborne lidar stops at the surface.
        for d in found:
            if d.get("id") and not d.get("seafloor"):
                d["note"] = "Lidar flown from the air maps the land and stops at the water's surface. A sonar survey of the seafloor also covers this box; use it for anything under water."
        found.sort(key=lambda d: not d.get("seafloor"))
    return found


def _find_opentopography(bbox: list[float]) -> list[dict]:
    w, s, e, n = bbox
    r = _client.get(
        OT_CATALOG,
        params={"productFormat": "PointCloud", "minx": w, "miny": s, "maxx": e, "maxy": n,
                "detail": "true", "outputFormat": "json", "include_federated": "false"},
    )
    r.raise_for_status()
    out = []
    for item in r.json().get("Datasets", []):
        d = item.get("Dataset", {})
        out.append({
            "id": f"ot:{d.get('alternateName')}",
            "source": "OpenTopography",
            "title": d.get("name"),
            "collected": d.get("temporalCoverage"),
            "published": d.get("dateCreated"),
            "landing_page": d.get("url"),
            "citation": d.get("citation"),
            "about": re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", d.get("description", "")))[:700],
        })
    return out


def _usgs_index() -> list[dict]:
    f = cache_dir() / "usgs-resources.geojson"
    if not f.exists() or time.time() - f.stat().st_mtime > 30 * 86400:
        r = _client.get(USGS_INDEX)
        r.raise_for_status()
        f.write_bytes(r.content)
    return json.loads(f.read_text())["features"]


def _rings(geom: dict):
    polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
    for poly in polys:
        yield np.asarray(poly[0], dtype=float)[:, :2]


def _overlaps(geom: dict, bbox: list[float]) -> bool:
    """True when a polygon's outer ring overlaps the box (corner inside, vertex inside, or box centre inside)."""
    w, s, e, n = bbox
    for ring in _rings(geom):
        x, y = ring[:, 0], ring[:, 1]
        if x.max() < w or x.min() > e or y.max() < s or y.min() > n:
            continue
        if ((x >= w) & (x <= e) & (y >= s) & (y <= n)).any():
            return True
        for px, py in ((w, s), (e, s), (w, n), (e, n), ((w + e) / 2, (s + n) / 2)):
            x2, y2 = np.roll(x, -1), np.roll(y, -1)
            crosses = ((y > py) != (y2 > py)) & (px < (x2 - x) * (py - y) / (y2 - y + 1e-300) + x)
            if crosses.sum() % 2:
                return True
    return False


def _find_usgs(bbox: list[float]) -> list[dict]:
    out = []
    for f in _usgs_index():
        if _overlaps(f["geometry"], bbox):
            p = f["properties"]
            out.append({
                "id": f"usgs:{p['name']}",
                "source": "USGS 3DEP",
                "title": p["name"],
                "points": p.get("count"),
                "landing_page": p["url"],
                "citation": "U.S. Geological Survey 3D Elevation Program lidar point cloud, public domain.",
            })
    return out


# --------------------------------------------------------------- fetching data


# A long download reports each finished part here, so the app can show progress and a time left.
# fetch_terrain sets it for the length of one fetch; it is a no-op otherwise.
progress: Callable[[int, int], None] = lambda done, total: None
# True once the person has cancelled the fetch; long waits between retries check it so a cancel does not wait them out.
cancelled: Callable[[], bool] = lambda: False


def _counted(fn, total: int):
    """Wrap fn so each call that finishes reports progress as done of total."""
    import threading
    lock, done = threading.Lock(), [0]

    def run(*args):
        progress(done[0], total)  # before each part too, so a cancelled fetch skips the parts still waiting
        out = fn(*args)
        with lock:
            done[0] += 1
            progress(done[0], total)
        return out
    return run


def fetch_points(dataset: str, bbox: list[float], spacing: float = 0.35) -> tuple[Points, dict]:
    """Download the points of one dataset inside a lon/lat box.

    The points are kept in the cache by dataset and box, so fetching the same area again (a rerun of a blind test,
    the benchmark, a second project on the same place) takes seconds instead of minutes.
    """
    kind, _, name = dataset.partition(":")
    if kind not in ("usgs", "ot"):
        raise ValueError(f"Unknown dataset id {dataset!r}. Use an id returned by find_data.")
    tag = hashlib.sha1(json.dumps([dataset, [round(v, 6) for v in bbox], spacing]).encode()).hexdigest()[:20]
    kept = cache_dir() / "points" / f"{tag}.npz"
    about = kept.with_suffix(".json")
    if kept.exists() and about.exists():
        return Points.load(kept), json.loads(about.read_text())
    if kind == "usgs":
        pts, info = _fetch_ept(f"https://s3-us-west-2.amazonaws.com/usgs-lidar-public/{name}/ept.json", bbox, spacing)
    else:
        pts, info = _fetch_opentopography(name, bbox)
    kept.parent.mkdir(parents=True, exist_ok=True)
    pts.save(kept)
    about.write_text(json.dumps(info))
    return pts, info


def _download(url: str) -> Path:
    f = cache_dir() / "files" / hashlib.sha1(url.encode()).hexdigest()[:16] / url.rsplit("/", 1)[-1]
    if not f.exists():
        f.parent.mkdir(parents=True, exist_ok=True)
        tmp = f.with_suffix(f.suffix + ".part")
        with _client.stream("GET", url) as r:
            r.raise_for_status()
            with tmp.open("wb") as fh:
                for chunk in r.iter_bytes(1 << 20):
                    fh.write(chunk)
        tmp.rename(f)
    return f


def _fetch_opentopography(name: str, bbox: list[float]) -> tuple[Points, dict]:
    r = _client.get(f"{OT_BULK}/{name}/{name}_TileIndex.zip")
    if r.status_code != 200:
        raise ValueError(f"OpenTopography dataset {name} has no public tile index, so it cannot be fetched without an account.")
    z = zipfile.ZipFile(io.BytesIO(r.content))
    ext = {n.rsplit(".", 1)[1].lower(): n for n in z.namelist()}
    index = shapefile.Reader(shp=io.BytesIO(z.read(ext["shp"])), dbf=io.BytesIO(z.read(ext["dbf"])),
                             shx=io.BytesIO(z.read(ext["shx"])))
    epsg = pyproj.CRS.from_wkt(z.read(ext["prj"]).decode()).to_epsg()
    x0, y0, x1, y1 = project_bbox(bbox, epsg)
    urls = []
    for sr in index.iterShapeRecords():
        bx0, by0, bx1, by1 = sr.shape.bbox
        if bx0 <= x1 and bx1 >= x0 and by0 <= y1 and by1 >= y0:
            urls.append(sr.record.as_dict()["URL"])
    progress(0, len(urls))
    parts = [_counted(lambda u: _read_las(_download(u), (x0, y0, x1, y1)), len(urls))(u) for u in urls]
    return _join(parts, epsg), {"files": [u.rsplit("/", 1)[-1] for u in urls]}


def _read_las(path: Path, box: tuple[float, float, float, float]):
    x0, y0, x1, y1 = box
    keep = []
    with laspy.open(path) as reader:
        for chunk in reader.chunk_iterator(2_000_000):
            x, y = np.asarray(chunk.x), np.asarray(chunk.y)
            m = (x >= x0) & (x <= x1) & (y >= y0) & (y <= y1)
            if m.any():
                keep.append((x[m], y[m], np.asarray(chunk.z)[m].astype(np.float32),
                             np.asarray(chunk.classification)[m].astype(np.uint8)))
    return keep


def _join(parts: list, epsg: int) -> Points:
    flat = [p for part in parts for p in part]
    if not flat:
        return Points(np.empty(0), np.empty(0), np.empty(0, np.float32), np.empty(0, np.uint8), epsg)
    return Points(*(np.concatenate([p[i] for p in flat]) for i in range(4)), epsg)


def _get(url: str) -> httpx.Response:
    """A GET that tries again when a server drops the connection or fails, as the public buckets now and then do."""
    for attempt in range(3):
        try:
            r = _client.get(url)
            if r.status_code < 500:
                return r.raise_for_status()
        except httpx.TransportError:
            if attempt == 2:
                raise
        time.sleep(2 * (attempt + 1))
    return r.raise_for_status()


def _fetch_ept(url: str, bbox: list[float], spacing: float) -> tuple[Points, dict]:
    """Read an Entwine Point Tile set: walk its octree and download only the nodes over the box."""
    base = url.rsplit("/", 1)[0]
    meta = _client.get(url).json()
    srs = meta["srs"]
    src_epsg = int(srs.get("horizontal") or srs["wkt"] and pyproj.CRS.from_wkt(srs["wkt"]).to_epsg())
    bx0, by0, _, bx1, _, _ = meta["bounds"]
    size = bx1 - bx0
    x0, y0, x1, y1 = project_bbox(bbox, src_epsg)
    hierarchy: dict[str, int] = {}

    def load(key: str) -> None:
        hierarchy.update(_get(f"{base}/ept-hierarchy/{key}.json").json())

    load("0-0-0-0")
    nodes, stack = [], ["0-0-0-0"]
    while stack:
        key = stack.pop()
        if hierarchy.get(key) == -1:
            load(key)
        if not hierarchy.get(key):
            continue
        d, i, j, k = map(int, key.split("-"))
        step = size / 2**d
        if bx0 + i * step > x1 or bx0 + (i + 1) * step < x0 or by0 + j * step > y1 or by0 + (j + 1) * step < y0:
            continue
        nodes.append(key)
        if step / meta["span"] > spacing:
            stack += [f"{d + 1}-{2 * i + a}-{2 * j + b}-{2 * k + c}" for a in (0, 1) for b in (0, 1) for c in (0, 1)]

    def read(key: str):
        las = laspy.read(io.BytesIO(_get(f"{base}/ept-data/{key}.laz").content))
        x, y = np.asarray(las.x), np.asarray(las.y)
        m = (x >= x0) & (x <= x1) & (y >= y0) & (y <= y1)
        return [(x[m], y[m], np.asarray(las.z)[m].astype(np.float32), np.asarray(las.classification)[m].astype(np.uint8))]

    progress(0, len(nodes))
    with ThreadPoolExecutor(8) as pool:
        parts = list(pool.map(_counted(read, len(nodes)), nodes))
    pts = _join(parts, src_epsg)
    w, s, e, n = bbox
    dst_epsg = utm_epsg((w + e) / 2, (s + n) / 2)
    if len(pts) and dst_epsg != src_epsg:
        x, y = pyproj.Transformer.from_crs(src_epsg, dst_epsg, always_xy=True).transform(pts.x, pts.y)
        pts = Points(np.asarray(x), np.asarray(y), pts.z, pts.cls, dst_epsg)
    return pts, {"nodes": len(nodes)}
