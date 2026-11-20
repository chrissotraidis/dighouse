"""Find small round mounds in a ground model by their shape, for the agent to look at.

A vision model misses low mounds a few metres across; they are a handful of pixels in a tile. This measures them
instead: a mound is a local high point that stands above its surroundings by a few tens of centimetres, rises on
every side, and is roughly round. Each spot it returns is a suggestion to look at, not a find.
"""

from __future__ import annotations

import numpy as np
from scipy import ndimage

from .terrain import GAP_M


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



def shape(dtm: np.ndarray, gap: np.ndarray, res: float, row: int, col: int, diameter_m: float = 12.0) -> dict:
    """Measure a marked shape the way a person checks a small mound: does it rise coherently above its surroundings, is
    there a pit beside it, is it as wide one way as the other, how rough is the ground around it, and how much of it
    sits over cells with no ground returns. Nothing is filtered out by this; it ranks finds for review.

    Returns heights in metres, shares between 0 and 1, and short plain hints."""
    from scipy import ndimage
    r = max(2, int(round(diameter_m / 2 / res)))
    R = 3 * r
    r0, r1, c0, c1 = max(0, row - R), min(dtm.shape[0], row + R + 1), max(0, col - R), min(dtm.shape[1], col + R + 1)
    z = dtm[r0:r1, c0:c1].astype(np.float64)
    g = gap[r0:r1, c0:c1]
    cy, cx = row - r0, col - c0
    yy, xx = np.ogrid[:z.shape[0], :z.shape[1]]
    d = np.hypot(yy - cy, xx - cx)
    finite = np.isfinite(z)
    inner, ring = (d <= r) & finite, (d > r) & (d <= 2 * r) & finite
    if not inner.any() or not ring.any():
        return {"problem": "Too close to the edge of the ground model to measure."}
    base = float(np.median(z[ring]))
    rise = float(z[inner].max() - base)
    pit = float(base - z[ring].min())
    pit_at = np.unravel_index(np.where(ring, z, np.inf).argmin(), z.shape)
    # Width at half the rise, east-west and north-south through the peak.
    peak = np.unravel_index(np.where(inner, z, -np.inf).argmax(), z.shape)
    half = base + rise / 2
    def width(line: np.ndarray, at: int) -> float:
        above = line > half
        if not above[at]:
            return 0.0
        a = b = at
        while a > 0 and above[a - 1]:
            a -= 1
        while b < len(line) - 1 and above[b + 1]:
            b += 1
        return (b - a + 1) * res
    ew, ns = width(z[peak[0], :], peak[1]), width(z[:, peak[1]], peak[0])
    symmetry = round(float(min(ew, ns) / max(ew, ns)), 2) if max(ew, ns) > 0 else 0.0
    around = (d > 2 * r) & finite
    detrended = z - ndimage.gaussian_filter(np.where(finite, z, base), max(2.0, 5 / res))
    roughness = float(np.std(detrended[around])) if around.any() else 0.0
    no_ground = float(np.mean(g[d <= r] > GAP_M)) if (d <= r).any() else 0.0
    # A hollow (a pit, a pond, a quarry) sits below the ground around it; the rest of the measure is for raised shapes.
    sink = float(base - np.median(z[inner]))
    hints = []
    if sink > 0.2 and sink > rise:
        hints.append(f"a hollow, {sink:.1f} m below the ground around it, not a rise")
    elif rise < 0.2:
        hints.append("barely rises above the ground around it")
    if pit > 0.25 and pit > 0.4 * rise and np.hypot(pit_at[0] - cy, pit_at[1] - cx) < 1.8 * r:
        hints.append("a pit lies beside it, as beside a tree throw")
    if symmetry and symmetry < 0.5:
        hints.append("much longer one way than the other")
    if roughness > max(0.15, rise / 2):
        hints.append("the ground around it is as rough as the shape is high")
    if no_ground > 0.3:
        hints.append("much of it lies over cells with no ground returns, so the shape may be smoothed across a gap")
    score = 0.0 if sink > rise else max(0.0, rise) * (symmetry or 0.5) * (1 - no_ground) / (1 + roughness / max(rise, 0.05))
    default = "a coherent, round rise" if symmetry >= 0.5 and rise >= 0.2 else "no clear shape either way"
    return {"rise_m": round(rise, 2), "sink_m": round(max(sink, 0.0), 2), "pit_beside_m": round(max(pit, 0.0), 2), "width_ew_m": round(float(ew), 1), "width_ns_m": round(float(ns), 1),
            "symmetry": symmetry, "roughness_m": round(roughness, 2), "share_without_ground": round(no_ground, 2),
            "rank": round(float(score), 3), "hints": hints or [default]}

