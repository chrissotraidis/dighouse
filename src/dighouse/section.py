"""Cut a vertical slice through the points: is the feature in the ground, or in the trees?"""

from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from . import terrain as T
from .project import Project
from .sources import Points

W, H, MARGIN = 1200, 380, 48


def _font(size: int):
    """A clear font for the scale labels, so they read at the size the picture is shown."""
    for path in ("/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/arial.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default(size=size)
GROUND_RGB, VEG_RGB, BG_RGB = (214, 168, 110), (86, 190, 96), (14, 16, 15)


def cut(p: Project, terrain_id: str, a: tuple[float, float], b: tuple[float, float], width_m: float = 4.0) -> tuple[Image.Image, dict]:
    """Slice along the line a to b (projected metres). Returns the picture and the measurements."""
    meta = p.load("terrains", {})[terrain_id]
    (ax, ay), (bx, by) = a, b
    length = float(np.hypot(bx - ax, by - ay))
    if length < 5:
        raise ValueError("The section line is shorter than 5 m.")
    ux, uy = (bx - ax) / length, (by - ay) / length
    if not meta.get("points") or not p.path(meta["points"]).exists():
        return _model_only(p, meta, ax, ay, ux, uy, length)
    pts = Points.load(p.path(meta["points"]))
    dx, dy = pts.x - ax, pts.y - ay
    along, across = dx * ux + dy * uy, -dx * uy + dy * ux
    m = (along >= 0) & (along <= length) & (np.abs(across) <= width_m / 2)
    s, z, ground = along[m], pts.z[m].astype(float), pts.ground[m]
    if not meta["ground_classified"]:
        ground = np.ones(len(s), bool)

    # ground profile in 1 m steps, from ground returns where there are any, else from the model
    steps = np.arange(0.5, length, 1.0)
    profile = _sample_model(p, meta, ax + ux * steps, ay + uy * steps)[0]
    bins = np.clip(s[ground].astype(int), 0, len(steps) - 1)
    hits = np.bincount(bins, minlength=len(steps))
    sums = np.bincount(bins, weights=z[ground], minlength=len(steps))
    profile = np.where(hits > 0, sums / np.maximum(hits, 1), profile)

    ends = np.linspace(np.median(profile[:5]), np.median(profile[-5:]), len(steps))
    rise = profile - ends
    peak = int(np.argmax(rise))
    near_peak = (s[ground] >= steps[peak] - 5) & (s[ground] <= steps[peak] + 5)
    above = z[~ground] - np.interp(s[~ground], steps, profile)
    stats = {
        "length_m": round(length, 1),
        "ground_returns": int(ground.sum()),
        "other_returns": int((~ground).sum()),
        "ground_returns_per_m": round(float(ground.sum()) / length, 1),
        "ground_returns_within_5m_of_peak": int(near_peak.sum()),
        "feature_height_m": round(float(rise[peak]), 2),
        "peak_at_m": round(float(steps[peak]), 1),
        "canopy_height_m": round(float(np.percentile(above, 95)), 1) if len(above) > 20 else None,
        "has_vegetation_returns": bool((~ground).sum() > 20),
    }
    return _draw(s, z, ground, length), stats


def _model_only(p: Project, meta: dict, ax: float, ay: float, ux: float, uy: float, length: float) -> tuple[Image.Image, dict]:
    """A section through a ready-made ground model: the profile, with no points to show the canopy."""
    steps = np.arange(0.25, length, 0.5)
    profile, missing = _sample_model(p, meta, ax + ux * steps, ay + uy * steps)
    if (~missing).sum() >= 10:  # samples in a gap between survey lines are fill, not ground
        steps, profile = steps[~missing], profile[~missing]
    ends = np.linspace(np.median(profile[:10]), np.median(profile[-10:]), len(steps))
    rise = profile - ends
    peak = int(np.argmax(rise))
    stats = {"length_m": round(length, 1), "ground_returns": None, "other_returns": None, "ground_returns_per_m": None,
             "ground_returns_within_5m_of_peak": None, "feature_height_m": round(float(rise[peak]), 2),
             "peak_at_m": round(float(steps[peak]), 1), "canopy_height_m": None, "has_vegetation_returns": False,
             "from_ground_model_only": True}
    legend = "seafloor, from a sonar survey" if meta.get("seafloor") else "ground model, no raw points"
    return _draw(steps, profile, np.ones(len(steps), bool), length, legend), stats


def _sample_model(p: Project, meta: dict, xs: np.ndarray, ys: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Heights along the line, and which samples fall outside the survey."""
    dtm, _, outside = T.load_terrain(p.path(meta["file"]))
    x0, _, _, y1 = meta["box"]
    c = np.clip(((xs - x0) / meta["res"]).astype(int), 0, dtm.shape[1] - 1)
    r = np.clip(((y1 - ys) / meta["res"]).astype(int), 0, dtm.shape[0] - 1)
    return dtm[r, c].astype(float), outside[r, c].astype(bool)


def _draw(s: np.ndarray, z: np.ndarray, ground: np.ndarray, length: float, legend: str = "") -> Image.Image:
    img = np.zeros((H, W, 3), np.uint8)
    img[:] = BG_RGB
    if len(z):
        z0, z1 = float(z.min()) - 1, float(z.max()) + 1
        px = (MARGIN + s / length * (W - 2 * MARGIN)).astype(int)
        py = (H - MARGIN - (z - z0) / (z1 - z0) * (H - 2 * MARGIN)).astype(int)
        for mask, rgb in ((~ground, VEG_RGB), (ground, GROUND_RGB)):  # ground drawn last, on top
            for ox in (0, 1):
                for oy in (0, 1):
                    img[np.clip(py[mask] + oy, 0, H - 1), np.clip(px[mask] + ox, 0, W - 1)] = rgb
    out = Image.fromarray(img)
    d = ImageDraw.Draw(out)
    font, small = _font(22), _font(18)
    ink, faint = (235, 232, 225), (150, 150, 145)
    bar_m = 10 if length < 80 else 20 if length < 250 else 50
    bar_px = bar_m / length * (W - 2 * MARGIN)
    d.line([(MARGIN, H - 18), (MARGIN + bar_px, H - 18)], fill=ink, width=3)
    d.text((MARGIN + bar_px + 10, H - 18), f"{bar_m} m", fill=ink, font=font, anchor="lm")
    if len(z):
        v_m = 5 if z1 - z0 < 30 else 10
        v_px = v_m / (z1 - z0) * (H - 2 * MARGIN)
        d.line([(18, H - MARGIN), (18, H - MARGIN - v_px)], fill=ink, width=3)
        d.text((26, H - MARGIN - v_px), f"{v_m} m", fill=ink, font=font, anchor="lm")
    if legend:  # a ground model has one line, not points sorted into ground and trees
        d.text((W - MARGIN, 16), legend, fill=GROUND_RGB, font=small, anchor="ra")
    else:
        d.text((W - MARGIN, 16), "ground returns", fill=GROUND_RGB, font=small, anchor="ra")
        d.text((W - MARGIN - d.textlength("ground returns", font=small) - 24, 16), "trees and other returns", fill=VEG_RGB, font=small, anchor="ra")
    return out
