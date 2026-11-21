"""What old maps and mining records say about a place: USGS historical topographic maps (what was drawn there then:
ponds, pits, quarries, buildings, roads) and the USGS Mineral Resources Data System (mines and prospects). United States
only. Map sheets are kept in a shared cache so each is downloaded once."""

from __future__ import annotations

import io
import math
import re
from pathlib import Path

import httpx

TNM = "https://tnmaccess.nationalmap.gov/api/v1/products"
MRDS = "https://mrdata.usgs.gov/services/wfs/mrds"
CACHE = Path.home() / "Library" / "Application Support" / "Dighouse" / "maps"
_client = httpx.Client(timeout=120, follow_redirects=True, headers={"User-Agent": "dighouse (https://github.com/chrissotraidis/dighouse)"})


def _metres(lon1, lat1, lon2, lat2) -> float:
    return math.hypot((lon1 - lon2) * 111_320 * math.cos(math.radians(lat1)), (lat1 - lat2) * 110_540)


def mines(lon: float, lat: float, radius_m: float = 300) -> list[dict]:
    """Mines, prospects and pits on record within radius_m, nearest first."""
    d = radius_m / 111_000
    r = _client.get(MRDS, params={"service": "WFS", "version": "1.1.0", "request": "GetFeature", "typeName": "mrds",
                                  "bbox": f"{lon - d * 1.5},{lat - d},{lon + d * 1.5},{lat + d}", "maxFeatures": 50})
    r.raise_for_status()
    out = []
    for block in re.findall(r"<ms:mrds\b.*?</ms:mrds>", r.text, re.S):
        get = lambda tag: (re.search(rf"<ms:{tag}>([^<]*)", block) or [None, ""])[1].strip()
        try:
            dist = _metres(lon, lat, float(get("longitude")), float(get("latitude")))
        except ValueError:
            continue
        if dist <= radius_m:
            out.append({"name": get("site_name"), "status": get("dev_stat"), "commodity": get("commod1"),
                        "distance_m": round(dist), "record": f"https://mrdata.usgs.gov/mrds/show-mrds.php?dep_id={get('dep_id')}"})
    return sorted(out, key=lambda m: m["distance_m"])


def maps(lon: float, lat: float) -> list[dict]:
    """The historical topographic sheets that cover a point: the oldest at 1:24,000, and the oldest of any scale."""
    r = _client.get(TNM, params={"datasets": "Historical Topographic Maps", "bbox": f"{lon - 0.0005},{lat - 0.0005},{lon + 0.0005},{lat + 0.0005}",
                                 "max": 100, "outputFormat": "JSON"})
    r.raise_for_status()
    sheets = []
    for i in r.json().get("items", []):
        tif, box = (i.get("urls") or {}).get("GeoTIFF"), i.get("boundingBox") or {}
        m = re.search(r"1:(\d+)-scale.*?(\d{4})\s*$", i.get("title", ""))
        if not tif or not m or not (box.get("minX", 1e9) <= lon <= box.get("maxX", -1e9) and box.get("minY", 1e9) <= lat <= box.get("maxY", -1e9)):
            continue
        sheets.append({"title": i["title"], "scale": int(m.group(1)), "year": int(m.group(2)), "tif": tif, "page": i.get("metaUrl", "")})
    picks = []
    fine = sorted((s for s in sheets if s["scale"] <= 24000), key=lambda s: s["year"])
    if fine:
        picks.append(fine[0])
    oldest = sorted(sheets, key=lambda s: s["year"])
    if oldest and oldest[0] not in picks:
        picks.append(oldest[0])
    return picks


def crop(sheet: dict, lon: float, lat: float, half_m: float = 200) -> bytes:
    """A PNG of the sheet around the point, half_m each way, with a small ring at the centre."""
    import rasterio
    from rasterio.warp import transform
    from rasterio.windows import from_bounds
    from PIL import Image, ImageDraw
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / Path(sheet["tif"]).name.replace("%20", "_")
    if not path.exists():
        with _client.stream("GET", sheet["tif"]) as r:
            r.raise_for_status()
            tmp = path.with_suffix(".part")
            with tmp.open("wb") as fh:
                for chunk in r.iter_bytes():
                    fh.write(chunk)
            tmp.replace(path)
    with rasterio.open(path) as src:
        xs, ys = transform("EPSG:4326", src.crs, [lon], [lat])
        unit = 1.0 if src.crs.is_projected else 1 / 111_000
        h = half_m * unit
        win = from_bounds(xs[0] - h, ys[0] - h, xs[0] + h, ys[0] + h, src.transform)
        data = src.read(window=win, boundless=True, fill_value=255)
        if src.count == 1 and src.colormap(1) if src.count == 1 else False:
            cmap = src.colormap(1)
            import numpy as np
            lut = np.array([cmap.get(i, (255, 255, 255, 255))[:3] for i in range(256)], dtype=np.uint8)
            rgb = lut[data[0]]
        else:
            import numpy as np
            rgb = np.moveaxis(data[:3], 0, -1) if data.shape[0] >= 3 else np.repeat(data[0][..., None], 3, -1)
    img = Image.fromarray(rgb.astype("uint8")).resize((512, 512))
    d = ImageDraw.Draw(img)
    d.ellipse([244, 244, 268, 268], outline=(230, 30, 30), width=3)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()

