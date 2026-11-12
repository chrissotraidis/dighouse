"""Turn ground points into a bare-ground model and render it for inspection."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import rasterio
from PIL import Image
from rasterio.transform import from_origin
from scipy import ndimage

from .sources import Points

GAP_M = 3.0  # a cell further than this from any ground return has no usable ground data


def grid_ground(pts: Points, box: tuple[float, float, float, float], res: float) -> tuple[np.ndarray, np.ndarray, np.ndarray, dict]:
    """Grid ground returns into a filled ground model.

    Returns the model, the distance in metres from each cell to its nearest ground
    return, a mask of cells outside the survey (no returns of any kind nearby), and
    summary numbers. Cells are filled from their nearest neighbour so the surface is
    continuous, and the distance band records where that is a guess.
    """
    x0, y0, x1, y1 = box
    cols, rows = int(np.ceil((x1 - x0) / res)), int(np.ceil((y1 - y0) / res))
    ground = pts.ground
    classified = bool(ground.any())
    use = ground if classified else np.ones(len(pts), bool)
    c = ((pts.x[use] - x0) / res).astype(np.int64)
    r = ((y1 - pts.y[use]) / res).astype(np.int64)
    ok = (c >= 0) & (c < cols) & (r >= 0) & (r < rows)
    flat = r[ok] * cols + c[ok]
    z = pts.z[use][ok].astype(np.float64)
    count = np.bincount(flat, minlength=rows * cols)
    if classified:
        total = np.bincount(flat, weights=z, minlength=rows * cols)
        dtm = np.where(count > 0, total / np.maximum(count, 1), np.nan)
    else:  # no ground classes: take the lowest return per cell as a rough stand-in
        dtm = np.full(rows * cols, np.inf)
        np.minimum.at(dtm, flat, z)
        dtm[~np.isfinite(dtm)] = np.nan
    dtm = dtm.reshape(rows, cols)
    empty = np.isnan(dtm)
    if empty.all():
        raise ValueError("No points fall inside the requested area.")
    gap, (ri, ci) = ndimage.distance_transform_edt(empty, return_indices=True)
    filled = dtm[ri, ci]
    soft = ndimage.gaussian_filter(filled, 1.0)
    dtm = np.where(empty, soft, dtm).astype(np.float32)
    gap = (gap * res).astype(np.float32)
    ca = ((pts.x - x0) / res).astype(np.int64)
    ra = ((y1 - pts.y) / res).astype(np.int64)
    inside = (ca >= 0) & (ca < cols) & (ra >= 0) & (ra < rows)
    any_return = np.bincount(ra[inside] * cols + ca[inside], minlength=rows * cols).reshape(rows, cols) > 0
    outside = ndimage.distance_transform_edt(~any_return) * res > GAP_M
    surveyed = max(int((~outside).sum()), 1)
    stats = {
        "ground_classified": classified,
        "ground_points": int(ok.sum()),
        "other_points": int(len(pts) - use.sum()) if classified else 0,
        "ground_points_per_m2": round(float(ok.sum()) / (surveyed * res * res), 2),
        "share_outside_survey": round(float(outside.mean()), 3),
        "share_without_ground_data": round(float(((gap > GAP_M) & ~outside).sum()) / surveyed, 3),
    }
    return dtm, gap, outside, stats


def save_terrain(path: Path, dtm: np.ndarray, gap: np.ndarray, outside: np.ndarray, x0: float, y1: float, res: float, epsg: int) -> None:
    with rasterio.open(path, "w", driver="GTiff", height=dtm.shape[0], width=dtm.shape[1], count=3,
                       dtype="float32", crs=f"EPSG:{epsg}", transform=from_origin(x0, y1, res, res),
                       compress="deflate") as dst:
        dst.write(dtm, 1)
        dst.write(gap, 2)
        dst.write(outside.astype(np.float32), 3)


def load_terrain(path: Path, window: tuple[int, int, int, int] | None = None) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Read the ground model, the gap band and the outside-survey mask, optionally only (row, col, rows, cols)."""
    with rasterio.open(path) as src:
        win = None
        if window:
            r, c, h, w = window
            win = rasterio.windows.Window(c, r, w, h)
        return src.read(1, window=win), src.read(2, window=win), src.read(3, window=win) > 0


def hillshade(dtm: np.ndarray, res: float, azimuth: float, altitude: float = 35, exaggerate: float = 2.0) -> np.ndarray:
    gy, gx = np.gradient(dtm.astype(np.float64), res)
    gx, gn = gx * exaggerate, -gy * exaggerate  # rows run north to south
    az, alt = np.radians(azimuth), np.radians(altitude)
    lit = (np.sin(alt) - np.cos(alt) * (gx * np.sin(az) + gn * np.cos(az))) / np.sqrt(1 + gx**2 + gn**2)
    return np.clip(lit, 0, 1)


def slope_degrees(dtm: np.ndarray, res: float) -> np.ndarray:
    gy, gx = np.gradient(dtm.astype(np.float64), res)
    return np.degrees(np.arctan(np.hypot(gx, gy)))


def local_relief(dtm: np.ndarray, res: float, radius_m: float = 8.0) -> np.ndarray:
    """Height above the smoothed surroundings: flattens hills, keeps low banks and platforms."""
    return dtm - ndimage.gaussian_filter(dtm.astype(np.float64), radius_m / res)


def sky_view(dtm: np.ndarray, res: float, radius_m: float = 10.0, directions: int = 16) -> np.ndarray:
    """Share of the sky visible from each cell, looking out to radius_m in every direction.

    Ditches and hollows see less sky and turn dark, ridges and banks see more, and unlike
    a hillshade no direction of light is favoured. A standard view for archaeological lidar.
    """
    h = dtm.astype(np.float32)
    rows, cols = h.shape
    reach = max(int(radius_m / res), 2)
    steps = sorted({max(1, int(round(reach * f))) for f in np.geomspace(1 / reach, 1, 12)})
    pad = reach + 1
    big = np.pad(h, pad, mode="edge")
    total = np.zeros_like(h)
    for a in np.linspace(0, 2 * np.pi, directions, endpoint=False):
        horizon = np.zeros_like(h)
        for k in steps:
            dr, dc = int(round(-np.sin(a) * k)), int(round(np.cos(a) * k))
            ahead = big[pad + dr:pad + dr + rows, pad + dc:pad + dc + cols]
            dist = np.hypot(dr, dc) * res
            if dist > 0:
                horizon = np.maximum(horizon, np.arctan((ahead - h) / dist))
        total += np.sin(horizon)
    return 1 - total / directions


def _stretch(a: np.ndarray, lo: float = 2, hi: float = 98) -> np.ndarray:
    p0, p1 = np.percentile(a, [lo, hi])
    return np.clip((a - p0) / max(p1 - p0, 1e-9), 0, 1)


STYLES = ("composite", "hillshade", "slope", "local_relief", "sky_view")


def render(dtm: np.ndarray, gap: np.ndarray, outside: np.ndarray, res: float, style: str = "composite") -> Image.Image:
    """Render a ground model as a greyscale image.

    Areas without ground data are flat dark grey; areas outside the survey are near black.
    """
    if style not in STYLES:
        raise ValueError(f"style must be one of {STYLES}")
    many = np.mean([hillshade(dtm, res, az) for az in (315, 0, 45, 270)], axis=0)
    if style == "hillshade":
        img = _stretch(many)
    elif style == "slope":
        img = 1 - np.clip(slope_degrees(dtm, res) / 40, 0, 1)
    elif style == "local_relief":
        img = np.clip(local_relief(dtm, res) / 2.0 + 0.5, 0, 1)
    elif style == "sky_view":
        img = _stretch(sky_view(dtm, res), 1, 99) ** 1.6
    else:
        lrm = np.clip(local_relief(dtm, res) / 2.0 + 0.5, 0, 1)
        img = (0.6 * _stretch(many) + 0.4 * lrm) * (1 - 0.35 * np.clip(slope_degrees(dtm, res) / 35, 0, 1))
        img = _stretch(img, 1, 99)
    img = np.where(gap > GAP_M, 0.18, img)
    img = np.where(outside, 0.05, img)
    return Image.fromarray((img * 255).astype(np.uint8), "L")
