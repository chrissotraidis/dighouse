"""What old maps and mining records say about a place. In the United States: USGS historical topographic maps (what was
drawn there then: ponds, pits, quarries, buildings, roads) and the USGS Mineral Resources Data System (mines and
prospects). In France: IGN's État-major map (1820 to 1866) and its aerial photographs of 1950 to 1965. Map sheets are kept
in a shared cache so each is downloaded once."""

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


IGN_WMTS = "https://data.geopf.fr/wmts"
# France's old maps on IGN's tile service: (title, layer, style, format, zoom). Zoom 15 is the finest the État-major map has.
FRANCE = [("État-major map, 1820 to 1866 (IGN)", "GEOGRAPHICALGRIDSYSTEMS.ETATMAJOR40", "normal", "image/jpeg", 15),
          ("Aerial photographs, 1950 to 1965 (IGN)", "ORTHOIMAGERY.ORTHOPHOTOS.1950-1965", "BDORTHOHISTORIQUE", "image/png", 17)]


def in_france(lon: float, lat: float) -> bool:
    from . import national
    return national._inside(lon, lat, national.NATIONAL["fr:lidarhd-mnt"]["outline"])


def in_us(lon: float, lat: float) -> bool:
    return -170 <= lon <= -65 and 17 <= lat <= 72


def where(lon: float, lat: float) -> str | None:
    """Which old maps cover a point: "us", "fr", or None."""
    return "us" if in_us(lon, lat) else "fr" if in_france(lon, lat) else None


def maps(lon: float, lat: float) -> list[dict]:
    """The old maps that cover a point. In the United States, the historical topographic sheets (the oldest at 1:24,000,
    and the oldest of any scale); in France, the État-major map and the 1950s aerial photographs."""
    if where(lon, lat) == "fr":
        return [{"title": t, "layer": layer, "style": style, "format": fmt, "zoom": z,
                 "page": "https://www.geoportail.gouv.fr/donnees/carte-de-letat-major-1820-1866" if "ETATMAJOR" in layer
                 else "https://www.geoportail.gouv.fr/donnees/photographies-aeriennes-1950-1965"} for t, layer, style, fmt, z in FRANCE]
    if where(lon, lat) != "us":
        return []
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


def _tiles(sheet: dict, lon: float, lat: float, half_m: float):
    """The tile-service map around a point, half_m each way, as an RGB array (web Mercator tiles, cached)."""
    import numpy as np
    from PIL import Image
    z = sheet["zoom"]
    n = 2 ** z

    def px(lo, la):  # the point in pixels of the whole map at this zoom
        return ((lo + 180) / 360 * n * 256, (1 - math.asinh(math.tan(math.radians(la))) / math.pi) / 2 * n * 256)

    dlon, dlat = half_m / (111_320 * math.cos(math.radians(lat))), half_m / 110_540
    x0, y0 = px(lon - dlon, lat + dlat)
    x1, y1 = px(lon + dlon, lat - dlat)
    cols, rows = range(int(x0 // 256), int(x1 // 256) + 1), range(int(y0 // 256), int(y1 // 256) + 1)
    mosaic = Image.new("RGB", (256 * len(cols), 256 * len(rows)), (255, 255, 255))
    folder = CACHE / "ign" / sheet["layer"] / str(z)
    folder.mkdir(parents=True, exist_ok=True)
    for i, c in enumerate(cols):
        for j, r in enumerate(rows):
            f = folder / f"{c}_{r}"
            if not f.exists():
                got = _client.get(IGN_WMTS, params={"SERVICE": "WMTS", "REQUEST": "GetTile", "VERSION": "1.0.0", "LAYER": sheet["layer"],
                                                    "STYLE": sheet["style"], "TILEMATRIXSET": "PM", "TILEMATRIX": z, "TILEROW": r,
                                                    "TILECOL": c, "FORMAT": sheet["format"]})
                if got.status_code != 200 or not got.headers.get("content-type", "").startswith("image"):
                    continue
                f.write_bytes(got.content)
            mosaic.paste(Image.open(f).convert("RGB"), (i * 256, j * 256))
    left, top = cols[0] * 256, rows[0] * 256
    return np.asarray(mosaic.crop((int(x0 - left), int(y0 - top), int(x1 - left), int(y1 - top))))


def crop(sheet: dict, lon: float, lat: float, half_m: float = 200) -> bytes:
    """A PNG of the sheet around the point, half_m each way, with a small ring at the centre."""
    if "layer" in sheet:
        from PIL import Image, ImageDraw
        img = Image.fromarray(_tiles(sheet, lon, lat, half_m).astype("uint8")).resize((512, 512))
        d = ImageDraw.Draw(img)
        d.ellipse([244, 244, 268, 268], outline=(230, 30, 30), width=3)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()
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

