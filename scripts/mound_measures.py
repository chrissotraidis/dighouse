
"""M0: every measured rise in three blind-test areas, labelled by whether it sits on a known feature, with the measures
that might separate real small mounds from look-alikes. Prints a separation table (AUC per measure) and per-key coverage."""
import json, math, os, sys
import numpy as np
import pyproj
from scipy import ndimage
from dighouse import mounds, terrain as T, answers
RUNS = {"borre": "blind-test-2026-11-21-5", "andia": "blind-test-2026-11-21-9", "mound-city": "blind-test-2026-11-21-6"}
HOME = os.path.expanduser("~/Dighouse/")
KEYS = os.path.expanduser("~/GitHub/dighouse/src/dighouse/keys/")

def profile_rise(z, r, c, half, axis):
    line = z[r, max(c-half,0):c+half+1] if axis == 0 else z[max(r-half,0):r+half+1, c]
    if len(line) < 5: return 0.0
    base = np.linspace(line[0], line[-1], len(line))
    return float((line - base).max())

def auc(pos, neg):
    if not pos or not neg: return None
    allv = sorted([(v,1) for v in pos] + [(v,0) for v in neg])
    ranks = {}; i = 0
    while i < len(allv):
        j = i
        while j < len(allv) and allv[j][0] == allv[i][0]: j += 1
        for k in range(i, j): ranks.setdefault(k, (i + j - 1) / 2 + 1)
        i = j
    rs = sum(ranks[k] for k,(v,l) in enumerate(allv) if l == 1)
    return (rs - len(pos)*(len(pos)+1)/2) / (len(pos)*len(neg))

out = {}
for key, run in RUNS.items():
    proj = HOME + run
    terr = json.load(open(proj + "/private/state/terrains.json")); meta = list(terr.values())[0]
    dtm, gap, outside = T.load_terrain(proj + "/" + meta["file"])
    res = meta["res"]; x0, y0, x1, y1 = meta["box"]
    to = pyproj.Transformer.from_crs(4326, meta["epsg"], always_xy=True)
    fro = pyproj.Transformer.from_crs(meta["epsg"], 4326, always_xy=True)
    k = json.load(open(KEYS + key + ".json"))
    feats = [f for f in k["features"] if f["expect"] and f["kind"] == "point"]
    score = json.load(open(proj + "/private/state/score.json"))
    missed = {m["feature"] for m in score["missed"]}
    z = np.where(np.isfinite(dtm), dtm, np.nanmedian(dtm)).astype(np.float64)
    valid = ~((gap > T.GAP_M) | outside.astype(bool))
    lr_s = T.local_relief(z, res, 4.0); lr_l = T.local_relief(z, res, 12.0)
    pos_o, neg_o = T.openness(z, res, 15.0)
    rows = []
    for b in mounds.bumps(dtm, res, min_h=0.25, valid=valid):
        r, c = b["row"], b["col"]
        s = mounds.shape(dtm, gap, res, r, c, max(6.0, b["diameter_m"]))
        if "rank" not in s: continue
        rad = max(2, int(round(max(6.0, b["diameter_m"]) / 2 / res)))
        win = (slice(max(r-6*rad,0), r+6*rad+1), slice(max(c-6*rad,0), c+6*rad+1))
        ew, ns = profile_rise(z, r, c, 2*rad, 0), profile_rise(z, r, c, 2*rad, 1)
        near = (slice(max(r-2*rad,0), r+2*rad+1), slice(max(c-2*rad,0), c+2*rad+1))
        lon, lat = fro.transform(x0 + (c + 0.5) * res, y1 - (r + 0.5) * res)
        hit = next((f["id"] for f in feats if answers.distance_m(f, lon, lat) <= answers.reach_m(f)), None)
        rows.append(dict(hit=hit, height=b["height_m"], diameter=b["diameter_m"], roundness=b["roundness"], rank=s["rank"],
            rise=s["rise_m"], pit=s["pit_beside_m"], symmetry=s["symmetry"], roughness=s["roughness_m"],
            rise_over_rough=s["rise_m"] / max(s["roughness_m"], 0.02), pit_over_rise=s["pit_beside_m"] / max(s["rise_m"], 0.05),
            small_contrast=float(lr_s[r, c] / max(np.std(lr_s[win]), 0.01)), large_contrast=float(lr_l[r, c] / max(np.std(lr_l[win]), 0.01)),
            profiles_agree=min(ew, ns) / max(ew, ns, 0.01), pos_open=float(pos_o[r, c]), neg_open_min=float(neg_o[near].max()),
            no_ground=s["share_without_ground"]))
    hits = {r["hit"] for r in rows if r["hit"]}
    real = [r for r in rows if r["hit"]]; other = [r for r in rows if not r["hit"]]
    area = dtm.size * res * res / 1e6
    print(f"\n{key}: {len(rows)} rises on {area:.2f} km2 ({len(rows)/area:.0f}/km2); {len(real)} on {len(hits)} of {len(feats)} counted features; "
          f"missed by the agent and seen as a rise: {len(missed & hits)} of {len(missed)}")
    for m in ["rank","height","diameter","roundness","rise","symmetry","roughness","rise_over_rough","pit_over_rise","small_contrast","large_contrast","profiles_agree","pos_open","neg_open_min","no_ground"]:
        a = auc([r[m] for r in real], [r[m] for r in other])
        print(f"  {m:16s} AUC {a:.2f}  real median {np.median([r[m] for r in real]):.2f}  others {np.median([r[m] for r in other]):.2f}" if a is not None else f"  {m} n/a")
    out[key] = dict(rows=rows, feats=[f["id"] for f in feats], missed=sorted(missed), area=area)
json.dump(out, open("/tmp/dhtest/m0_rises.json", "w"))

