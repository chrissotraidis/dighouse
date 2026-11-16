"""Find small round mounds in a ground model by their shape, for the agent to look at.

A vision model misses low mounds a few metres across; they are a handful of pixels in a tile. This measures them
instead: a mound is a local high point that stands above its surroundings by a few tens of centimetres, rises on
every side, and is roughly round. Each spot it returns is a suggestion to look at, not a find.
"""

from __future__ import annotations

import numpy as np
from scipy import ndimage


def bumps(dtm: np.ndarray, res: float, min_d: float = 4.0, max_d: float = 40.0, min_h: float = 0.25,
          valid: np.ndarray | None = None) -> list[dict]:
    """Dome-shaped rises between min_d and max_d metres across and at least min_h high.

    Returns, for each, its position in pixels (row, col), its diameter and height in metres, and how round it is."""
    z = np.where(np.isfinite(dtm), dtm, np.nanmedian(dtm)).astype(np.float64)
    out: list[dict] = []
    seen = np.zeros(z.shape, bool)
    # Look at three scales, so a 5 m mound and a 30 m mound each stand out against their own surroundings.
    for diameter in (min_d * 1.5, (min_d * max_d) ** 0.5, max_d * 0.8):
        sigma = max(diameter / res, 2.0)
        relief = z - ndimage.gaussian_filter(z, sigma)
        size = max(int(round(diameter / 2 / res)), 2) * 2 + 1
        peaks = (relief == ndimage.maximum_filter(relief, size=size)) & (relief > min_h * 0.6)
        if valid is not None:
            peaks &= valid
        for r, c in zip(*np.nonzero(peaks)):
            if seen[max(r - 2, 0):r + 3, max(c - 2, 0):c + 3].any():
                continue
            h0 = relief[r, c]
            # The extent of the rise: pixels around the peak above half its height, connected to it.
            half = relief > h0 / 2
            lab, _ = ndimage.label(half)
            region = lab == lab[r, c]
            rows, cols = np.nonzero(region)
            if len(rows) == 0:
                continue
            d_px = 2 * np.sqrt(len(rows) / np.pi)
            d_m = d_px * res
            if not (min_d <= d_m <= max_d):
                continue
            span_r, span_c = rows.max() - rows.min() + 1, cols.max() - cols.min() + 1
            roundness = min(span_r, span_c) / max(span_r, span_c)
            fill = len(rows) / (span_r * span_c)
            if roundness < 0.5 or fill < 0.55:
                continue  # long banks, roads and ridges are not mounds
            # Height above the ground around the rise. The half-height region can be just the top of a larger mound,
            # so step outward until the ground stops falling (or half the largest size), and measure from there.
            step = max(2, int(round(d_px / 4)))
            inner, base = region, None
            for _ in range(max(1, int(max_d / 2 / res / step))):
                outer = ndimage.binary_dilation(inner, iterations=step)
                ring = outer & ~inner
                if not ring.any():
                    break
                level = float(np.median(z[ring]))
                if base is not None and level > base - 0.05:
                    break
                base, inner = level, outer
            height = float(z[r, c] - base) if base is not None else float(h0)
            if height < min_h:
                continue
            seen[max(r - 2, 0):r + 3, max(c - 2, 0):c + 3] = True
            seen |= region
            out.append({"row": int(r), "col": int(c), "diameter_m": round(float(d_m), 1), "height_m": round(height, 2),
                        "roundness": round(float(roundness), 2)})
    out.sort(key=lambda b: -b["height_m"] * b["roundness"])
    return out

