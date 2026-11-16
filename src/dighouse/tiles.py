"""Cut a terrain into tiles and keep the coverage map: what has been looked at, and what could not be."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from . import terrain as T
from .project import Project
from .sources import to_lonlat

VERDICTS = ("nothing", "natural", "modern", "possible", "built")
MIN_PIXELS = 1000
PAD_M = 24  # context around a tile so filters behave at its edges


def make_tiles(p: Project, terrain_id: str, tile_m: float = 250, overlap_m: float = 25) -> dict:
    meta = p.load("terrains", {})[terrain_id]
    res = meta["res"]
    _, gap, outside = T.load_terrain(p.path(meta["file"]))
    blind = (gap > T.GAP_M) & ~outside
    rows, cols = gap.shape
    size, step = int(tile_m / res), int((tile_m - overlap_m) / res)
    tiles = p.load("tiles", {})
    added = unreadable = 0
    for i, r in enumerate(range(0, max(rows - size // 4, 1), step)):
        for j, c in enumerate(range(0, max(cols - size // 4, 1), step)):
            tid = f"{terrain_id}-r{i:03d}c{j:03d}"
            if tid in tiles:
                continue
            window = blind[r:r + size, c:c + size]
            surveyed = int((~outside[r:r + size, c:c + size]).sum())
            if surveyed < 0.02 * window.size:
                continue  # outside the survey
            no_data = float(window.sum()) / surveyed
            bad = no_data > 0.5
            tiles[tid] = {"terrain": terrain_id, "window": [r, c, int(window.shape[0]), int(window.shape[1])],
                          "status": "unreadable" if bad else "unscreened",
                          "share_without_ground_data": round(no_data, 2)}
            added += 1
            unreadable += bad
    p.save("tiles", tiles)
    for tid in tiles:
        cached_tile(p, tid)
    p.save("tiles", tiles)  # saved again so anything watching the project sees the finished images
    return {"tiles_added": added, "unreadable": int(unreadable)}


def tile_image(p: Project, tile_id: str, style: str = "composite", mark: tuple[float, float] | None = None) -> Image.Image:
    tile = p.load("tiles", {})[tile_id]
    meta = p.load("terrains", {})[tile["terrain"]]
    res = meta["res"]
    r, c, h, w = tile["window"]
    pad = int(PAD_M / res)
    r0, c0 = max(r - pad, 0), max(c - pad, 0)
    layers = T.load_terrain(p.path(meta["file"]), (r0, c0, h + (r - r0) + pad, w + (c - c0) + pad))
    img = T.render(*layers, res, style).crop((c - c0, r - r0, c - c0 + w, r - r0 + h))
    # A 1 m ground model gives a 250 m tile only 250 pixels, so a 6 m mound is 6 pixels: too small for a model to see.
    # Draw every tile at least 1000 pixels across. Positions on it are fractions, so nothing else changes.
    if max(img.size) < MIN_PIXELS:
        k = -(-MIN_PIXELS // max(img.size))
        img = img.resize((img.width * k, img.height * k), Image.LANCZOS)
        w, h = img.width, img.height
    if mark:
        img = img.convert("RGB")
        x, y, rad = mark[0] * w, mark[1] * h, max(w, h) * 0.035
        ImageDraw.Draw(img).ellipse([x - rad, y - rad, x + rad, y + rad], outline=(80, 160, 255), width=3)
    return img


def cached_tile(p: Project, tile_id: str, style: str = "composite") -> Path:
    f = p.path("data", "tiles", f"{tile_id}-{style}.png")
    if not f.exists():
        tile_image(p, tile_id, style).save(f)
    return f


def tile_xy(p: Project, tile_id: str, fx: float, fy: float) -> tuple[float, float, int]:
    """A point given as fractions of a tile image (0,0 top left; 1,1 bottom right) to projected metres."""
    tile = p.load("tiles", {})[tile_id]
    meta = p.load("terrains", {})[tile["terrain"]]
    r, c, h, w = tile["window"]
    x0, _, _, y1 = meta["box"]
    return x0 + (c + fx * w) * meta["res"], y1 - (r + fy * h) * meta["res"], meta["epsg"]


def tile_lonlat(p: Project, tile_id: str, fx: float, fy: float) -> tuple[float, float]:
    x, y, epsg = tile_xy(p, tile_id, fx, fy)
    lon, lat = to_lonlat(epsg, x, y)
    return float(lon), float(lat)


def next_unscreened(p: Project, n: int = 8) -> list[str]:
    return [tid for tid, t in p.load("tiles", {}).items() if t["status"] == "unscreened"][:n]


def record_verdict(p: Project, tile_id: str, verdict: str, note: str, model: str) -> dict:
    if verdict not in VERDICTS:
        raise ValueError(f"verdict must be one of {VERDICTS}")
    with p.change("tiles", {}) as tiles:
        tile = tiles[tile_id]
        if tile["status"] == "unreadable":
            raise ValueError("This tile has too little ground data to judge. It stays unreadable.")
        tile.update(status="screened", verdict=verdict, note=note, model=model)
    return tile


def coverage(p: Project) -> dict:
    tiles = p.load("tiles", {}).values()
    out = {"tiles": len(tiles)}
    for key in ("unscreened", "screened", "unreadable"):
        out[key] = sum(t["status"] == key for t in tiles)
    out["verdicts"] = {v: sum(t.get("verdict") == v for t in tiles) for v in VERDICTS}
    return out


def mound_spots(p: Project, tile_id: str, min_height_m: float = 0.3) -> tuple[list[dict], Image.Image]:
    """Round rises in a tile, measured from the ground model, and the tile in sky view with each one ringed and numbered.

    Positions are fractions of the tile, as flag_candidate takes them. A spot is a place to look, not a find."""
    from . import mounds
    tile = p.load("tiles", {})[tile_id]
    meta = p.load("terrains", {})[tile["terrain"]]
    res = meta["res"]
    r, c, h, w = tile["window"]
    pad = int((PAD_M + 40) / res)
    r0, c0 = max(r - pad, 0), max(c - pad, 0)
    dtm, gap, outside = T.load_terrain(p.path(meta["file"]), (r0, c0, h + (r - r0) + pad, w + (c - c0) + pad))
    valid = ~((gap > T.GAP_M) | outside.astype(bool))
    spots = []
    for b in mounds.bumps(dtm, res, min_h=min_height_m, valid=valid):
        y, x = b["row"] - (r - r0), b["col"] - (c - c0)
        if 0 <= y < h and 0 <= x < w:
            spots.append({"n": len(spots) + 1, "x": round((x + 0.5) / w, 3), "y": round((y + 0.5) / h, 3),
                          "diameter_m": b["diameter_m"], "height_m": b["height_m"], "roundness": b["roundness"]})
    from PIL import ImageFont
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 26)
        small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
    except OSError:
        font = small = ImageFont.load_default()
    img = tile_image(p, tile_id, "sky_view").convert("RGB")
    d = ImageDraw.Draw(img)
    for s in spots:
        cx, cy = s["x"] * img.width, s["y"] * img.height
        rad = max(s["diameter_m"] / res / w * img.width / 2 + 6, 14)
        d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=(255, 170, 40), width=3)
        d.text((cx + rad + 3, cy - rad - 4), str(s["n"]), fill=(255, 210, 90), font=font, stroke_width=3, stroke_fill=(0, 0, 0))
    # Below the tile, a close look at each spot (40 m across, hillshade), so a small rise can be judged.
    if spots:
        shade = tile_image(p, tile_id, "hillshade").convert("RGB")
        cell, per_row = 200, 5
        rows_n = -(-len(spots) // per_row)
        sheet = Image.new("RGB", (img.width, img.height + rows_n * (cell + 30)), (20, 18, 16))
        sheet.paste(img, (0, 0))
        dd = ImageDraw.Draw(sheet)
        span = 40 / res / w * shade.width
        for i, s in enumerate(spots):
            cx, cy = s["x"] * shade.width, s["y"] * shade.height
            crop = shade.crop((int(cx - span / 2), int(cy - span / 2), int(cx + span / 2), int(cy + span / 2))).resize((cell, cell))
            x, y = (i % per_row) * (img.width // per_row) + 6, img.height + (i // per_row) * (cell + 30) + 6
            sheet.paste(crop, (x, y))
            dd.text((x, y + cell + 2), f"{s['n']}: {s['diameter_m']:.0f} m, {s['height_m']:.1f} m high", fill=(230, 220, 205), font=small)
        img = sheet
    return spots, img
