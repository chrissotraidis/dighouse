"""Prepare the Serpent Mound point cloud for the promo's 3D shots, from a Dighouse project's downloads:
the bare-ground model as a grid, and the laser returns that are not ground (the trees) as points.
Everything is measured in metres from the middle of the tile, so the file says nothing about where on Earth it is.
Run with a Python that has rasterio (Dighouse's tools environment):
    cloud_prep.py <project>/data/points/<tile>.npz <project>/data/terrain/<tile>.tif source/serpent-cloud.npz"""
import sys, numpy as np, rasterio
points, terrain, out = sys.argv[1:4]
HALF = 296.0                                             # the renders use the middle 592 m
d = np.load(points); x, y, z, cls = d["x"], d["y"], d["z"], d["cls"]
with rasterio.open(terrain) as src:
    dtm = src.read(1).astype(np.float32); tr = src.transform; nod = src.nodata
bad = ~np.isfinite(dtm) | (dtm == nod) if nod is not None else ~np.isfinite(dtm)
dtm[bad] = np.nanmedian(dtm[~bad])
rows, cols = dtm.shape
# hillshade, to colour the ground
gy, gx = np.gradient(dtm, abs(tr.e), tr.a)
az, alt = np.radians(315), np.radians(40)
slope = np.arctan(np.hypot(gx, gy) * 2.5); aspect = np.arctan2(-gx, gy)
shade = np.clip(np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect), 0, 1)
# the middle of the grid, and its usual height, become zero
cx = tr.c + cols / 2 * tr.a; cy = tr.f + rows / 2 * tr.e; z0 = float(np.median(dtm))
# trees: returns that are not ground, more than a metre above the ground under them
veg = cls != 2
c = np.clip(((x[veg] - tr.c) / tr.a).astype(int), 0, cols - 1); r = np.clip(((y[veg] - tr.f) / tr.e).astype(int), 0, rows - 1)
hag = z[veg] - dtm[r, c]
tx, ty, tz = (x[veg] - cx).astype(np.float32), (y[veg] - cy).astype(np.float32), (z[veg] - z0).astype(np.float32)
keep = (hag > 1.0) & (np.abs(tx) < HALF) & (np.abs(ty) < HALF)
cm = lambda a: np.round(a * 100)
np.savez_compressed(out, dtm=(dtm - z0).astype(np.float32), shade=shade.astype(np.float16), cell=np.float32(tr.a),
                    x0=np.float32(tr.c + 0.5 * tr.a - cx), y0=np.float32(tr.f + 0.5 * tr.e - cy),
                    trees=np.stack([cm(tx[keep]), cm(ty[keep]), cm(tz[keep])], 1).astype(np.int16), tree_height=cm(hag[keep]).astype(np.uint16))
print(out, "ground", dtm.shape, "trees", int(keep.sum()), "tallest", float(hag[keep].max()))

