"""When did it appear: a find's ground from two flights, and the change between them.

Where two dated USGS point projects cover a find, the oldest and the newest are fetched over a square 120 m across,
each gridded the same way. The steady offset between them (a different datum or calibration) is taken out using the
ground 30 m or more from the find, and what is left there is the noise: its 95th percentile. The find is called present
in a flight when its centre rises above the ground around it by more than that noise. Only the years and the numbers
are filed; the location stays where it was.
"""

from __future__ import annotations

import math
import re

import numpy as np
import pyproj
from PIL import Image, ImageDraw

from . import ledger, sources
from . import terrain as T
from .project import Project

HALF_M = 60.0      # the square is 120 m across
RES = 1.0          # metres a cell, the same for both flights
RING_M = 30.0      # ground this far out sets the offset and the noise


def flown(name: str) -> int | None:
    """The year a USGS project was flown, from its name, or None. The first year is the flight
    (USGS_LPC_IN_Vanderburgh_2013_LAS_2016 was flown in 2013 and released in 2016); short codes such as _B21 or _D23
    are not read as years."""
    years = [int(y) for y in re.findall(r"(?<!\d)(?:19[89]\d|20[0-4]\d)(?!\d)", name)]
    return years[0] if years else None


def _box(lon: float, lat: float, half_m: float) -> list[float]:
    dlat = half_m / 111_320
    dlon = half_m / (111_320 * max(math.cos(math.radians(lat)), 0.01))
    return [lon - dlon, lat - dlat, lon + dlon, lat + dlat]


def _ground(dataset: str, lon: float, lat: float) -> tuple[np.ndarray, np.ndarray, dict]:
    pts, _ = sources.fetch_points(dataset, _box(lon, lat, HALF_M + 10), spacing=0.35)
    utm = sources.utm_epsg(lon, lat)
    x, y = pyproj.Transformer.from_crs(pts.epsg, utm, always_xy=True).transform(pts.x, pts.y)
    cx, cy = sources.to_xy(utm, lon, lat)
    moved = sources.Points(np.asarray(x), np.asarray(y), pts.z, pts.cls, utm)
    dtm, gap, _, stats = T.grid_ground(moved, (cx - HALF_M, cy - HALF_M, cx + HALF_M, cy + HALF_M), RES)
    return dtm.astype(np.float64), gap, stats


def _picture(old: np.ndarray, new: np.ndarray, change: np.ndarray, noise: float, years: tuple[int, int]) -> Image.Image:
    size = 300
    shade = lambda d: Image.fromarray((T.hillshade(d, RES, 315) * 255).astype(np.uint8), "L").convert("RGB").resize((size, size))
    span = max(3 * noise, 0.3)
    v = np.clip(change / span, -1, 1)
    rgb = np.full(change.shape + (3,), 235.0)
    rgb[..., 0] -= np.where(v < 0, -v * 200, 0)       # removed: blue
    rgb[..., 1] -= np.abs(v) * 160
    rgb[..., 2] -= np.where(v > 0, v * 200, 0)        # added: red
    diff = Image.fromarray(rgb.clip(0, 255).astype(np.uint8), "RGB").resize((size, size))
    out = Image.new("RGB", (size * 3 + 16, size + 26), (24, 22, 20))
    draw = ImageDraw.Draw(out)
    for i, (img, label) in enumerate(((shade(old), str(years[0])), (shade(new), str(years[1])),
                                       (diff, f"change, ±{span:.1f} m"))):
        out.paste(img, (i * (size + 8), 0))
        r = RING_M / 2 / (2 * HALF_M) * size
        ImageDraw.Draw(out).ellipse([i * (size + 8) + size / 2 - r, size / 2 - r, i * (size + 8) + size / 2 + r, size / 2 + r],
                                    outline=(80, 160, 255), width=2)
        draw.text((i * (size + 8) + 4, size + 6), label, fill=(200, 196, 188))
    return out


def compare_at(lon: float, lat: float, across: float = 15.0) -> tuple[dict, Image.Image | None]:
    """The comparison for one place: the check to file, and the picture (None when there was nothing to compare)."""
    dated = sorted({(y, h["id"]) for h in sources._find_usgs(_box(lon, lat, 5)) if (y := flown(h["title"]))})
    grounds = []
    # The oldest flight that has ground here, then the newest; an outline can reach a place its points do not.
    for order in (dated, dated[::-1]):
        for y, d in order:
            if grounds and (y, d) == grounds[0][0]:
                break
            try:
                grounds.append(((y, d), _ground(d, lon, lat)))
                break
            except ValueError:
                continue
    years = sorted({y for y, _ in dated})
    if len(grounds) < 2 or grounds[0][0][0] == grounds[1][0][0]:
        return {"flights": len(dated), "years": years,
                "answer": "one dated flight here" if dated else "no dated USGS flight here"}, None
    ((y0, d0), (old, gap0, s0)), ((y1, d1), (new, gap1, s1)) = grounds
    rows, cols = old.shape
    yy, xx = np.mgrid[:rows, :cols]
    dist = np.hypot((yy - rows / 2) * RES, (xx - cols / 2) * RES)
    centre = dist <= max(across / 2, 4.0)
    seen = (gap0 <= T.GAP_M) & (gap1 <= T.GAP_M)
    ring = (dist >= RING_M) & seen
    near = (dist > across) & (dist < across * 2) & seen
    if ring.sum() < 50 or (centre & seen).sum() < 5 or near.sum() < 5:
        return {"flights": len(dated), "years": [y0, y1], "answer": "too little ground in one flight to compare"}, None
    change = new - old
    change -= float(np.median(change[ring]))
    noise = max(float(np.percentile(np.abs(change[ring]), 95)), 0.05)
    lift = lambda d: float(np.median(d[centre & seen]) - np.median(d[near]))
    up0, up1 = lift(old), lift(new)
    here0, here1 = up0 > noise, up1 > noise
    if here0 and here1:
        answer = f"present in both flights, {y0} and {y1}"
    elif here1:
        answer = f"absent in {y0}, present in {y1}: possibly modern"
    elif here0:
        answer = f"present in {y0}, gone by {y1}: possibly levelled"
    else:
        answer = f"no clear rise in either flight, {y0} or {y1}"
    check = {"flights": len(dated), "years": [y0, y1], "datasets": [d0, d1], "answer": answer,
             "rise_m": [round(up0, 2), round(up1, 2)], "change_m": round(float(np.median(change[centre & seen])), 2),
             "noise_m": round(noise, 2), "ground_points_per_m2": [s0["ground_points_per_m2"], s1["ground_points_per_m2"]]}
    return check, _picture(old, new, change, noise, (y0, y1))


def compare(p: Project, cid: str) -> dict:
    """Compare the oldest and newest dated USGS flights over one find, file the result as its "flights" check and
    draw candidates/img/<id>-flights.png. Returns the check."""
    loc = (p.load("locations", {}) or {}).get(cid)
    if not loc or "lon" not in loc:
        raise ValueError(f"{cid} has no location on this Mac.")
    meta, _ = ledger.get(p, cid)
    across = float((meta["checks"].get("shape") or {}).get("diameter_m") or 15.0)
    check, picture = compare_at(loc["lon"], loc["lat"], across)
    if picture is not None:
        check["image"] = f"candidates/img/{cid}-flights.png"
        picture.save(p.path("candidates", "img", f"{cid}-flights.png"))
    ledger.set_check(p, cid, "flights", check)
    return check
