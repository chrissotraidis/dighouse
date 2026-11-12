"""A synthetic survey: forest over rolling ground, with a plaza, a 10 m mound and a blind strip."""

import numpy as np
import pytest

from dighouse import sources

BBOX = [-89.5020, 18.4990, -89.4990, 18.5020]  # about 320 m square
MOUND_HEIGHT = 10.0


def ground_height(x, y, cx, cy):
    h = 60 + 3 * np.sin(x / 70) + 2 * np.cos(y / 55)
    u, v = x - cx, y - cy
    plaza = (np.abs(u + 20) < 45) & (np.abs(v) < 30)
    h = np.where(plaza, 62.0, h)
    d = np.hypot((u - 50) / 20, v / 16)
    return np.where(d < 1, 62.0 + MOUND_HEIGHT * np.clip(1 - d, 0, None) ** 0.7, h)


@pytest.fixture
def survey(monkeypatch):
    epsg = sources.utm_epsg(BBOX[0], BBOX[1])
    x0, y0, x1, y1 = sources.project_bbox(BBOX, epsg)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rng = np.random.default_rng(1)
    n = int((x1 - x0) * (y1 - y0) * 3)
    gx, gy = rng.uniform(x0, x1, n), rng.uniform(y0, y1, n)
    seen = gx < x1 - 60  # the eastern strip has canopy so dense that no pulse reached the ground
    gx, gy = gx[seen], gy[seen]
    vx, vy = rng.uniform(x0, x1, 2 * n), rng.uniform(y0, y1, 2 * n)
    vz = ground_height(vx, vy, cx, cy) + rng.uniform(4, 17, 2 * n)
    pts = sources.Points(
        np.concatenate([gx, vx]), np.concatenate([gy, vy]),
        np.concatenate([ground_height(gx, gy, cx, cy) + rng.normal(0, 0.05, len(gx)), vz]).astype(np.float32),
        np.concatenate([np.full(len(gx), 2), np.full(len(vx), 5)]).astype(np.uint8), epsg)
    monkeypatch.setattr(sources, "fetch_points", lambda dataset, bbox, spacing=0.35: (pts, {"files": ["synthetic"]}))
    mound_lon, mound_lat = sources.to_lonlat(epsg, cx + 50, cy)
    return {"bbox": BBOX, "mound_xy": (cx + 50, cy), "mound_lonlat": (float(mound_lon), float(mound_lat)),
            "height_at": lambda x, y: float(ground_height(np.float64(x), np.float64(y), cx, cy))}
