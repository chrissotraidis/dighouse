
"""M5: does resolution limit what can be measured? On the same ground at several resolutions (resampled by block
mean from the finest), count the known mounds that show as a measured rise, and how many the best-ranked rises reach
at 40 per km^2 of the area. No model is asked anything."""
import json, math, os, sys
import numpy as np
from dighouse import mounds, terrain as T, answers

def coarsen(a, k, how="mean"):
    h, w = (a.shape[0] // k) * k, (a.shape[1] // k) * k
    b = a[:h, :w].reshape(h // k, k, w // k, k)
    return np.nanmean(b, axis=(1, 3)) if how == "mean" else b.max(axis=(1, 3))

def run(dtm, gap, res, box, epsg, feats, label):
    import pyproj
    fro = pyproj.Transformer.from_crs(epsg, 4326, always_xy=True)
    x0, _, _, y1 = box
    valid = ~(gap > T.GAP_M)
    rows = []
    for b in mounds.bumps(dtm, res, min_h=0.2, valid=valid):
        r, c = b["row"], b["col"]
        s = mounds.shape(dtm, gap, res, r, c, max(6.0, b["diameter_m"]))
        if "rank" not in s: continue
        sm, lg = mounds.contrast(dtm, res, r, c, b["diameter_m"])
        lon, lat = fro.transform(x0 + (c + .5) * res, y1 - (r + .5) * res)
        hit = next((f["id"] for f in feats if answers.distance_m(f, lon, lat) <= answers.reach_m(f)), None)
        rows.append((mounds.travel_rank(s, sm, lg), hit))
    area = dtm.size * res * res / 1e6
    seen = {h for _, h in rows if h}
    top = sorted(rows, key=lambda t: -t[0])[:int(40 * area)]
    reached = {h for _, h in top if h}
    print(f"{label:28s} {res:>4} m: {len(rows):5d} rises ({len(rows)/area:.0f}/km2); a rise on {len(seen):3d} of {len(feats)}; "
          f"top {len(top)} reach {len(reached)}")
    return len(seen), len(reached)

if __name__ == "__main__":
    which = sys.argv[1]
    if which == "borre":
        proj = os.path.expanduser("~/Dighouse/blind-test-2026-11-21-5")
        meta = list(json.load(open(proj + "/private/state/terrains.json")).values())[0]
        dtm, gap, out = T.load_terrain(proj + "/" + meta["file"])
        feats = [f for f in answers.key("borre")["features"] if f["expect"] and f["kind"] == "point"]
        dtm = np.where(out, np.nan, dtm).astype(np.float64)
        for k in (1, 2):
            run(coarsen(dtm, k), coarsen(gap, k, "max"), meta["res"] * k, meta["box"], meta["epsg"], feats, "Borre (Kartverket 1 m)")
    else:
        from dighouse import national
        w, s, e, n = [float(v) for v in sys.argv[2:6]]
        dtm, gap, x0, y1, res, epsg, info = national.fetch_dtm("fr:lidarhd-mnt", [w, s, e, n], 0.5)
        pts = json.load(open(sys.argv[6]))
        feats = [{"id": f"F{i}", "kind": "point", "lon": x, "lat": y, "size_m": 12, "expect": True} for i, (x, y, _) in enumerate(pts)
                 if w <= x <= e and s <= y <= n]
        box = [x0, y1 - dtm.shape[0] * res, x0 + dtm.shape[1] * res, y1]
        dtm = dtm.astype(np.float64)
        for k in (1, 2, 4):
            run(coarsen(dtm, k), coarsen(gap, k, "max"), res * k, box, epsg, feats, which)

