"""Prepare the ground around Mound A at Angel Mounds for the 3D shot: a square of the bare-ground model centred on
the find, as heights in metres above its lowest point. Nothing in the file says where on Earth it is.
Run with a Python that has rasterio (Dighouse's tools environment):
    mound_prep.py <project folder> <find id> source/angel-mound.npz"""
import sys, json, numpy as np, rasterio
from rasterio.warp import transform
root, find, out = sys.argv[1], sys.argv[2], sys.argv[3]
HALF = 190.0
loc = json.load(open(root + "/private/state/locations.json"))[find]
tif = [t for t in __import__("glob").glob(root + "/data/terrain/*.tif")][0]
with rasterio.open(tif) as src:
    xs, ys = transform("EPSG:4326", src.crs, [loc["lon"]], [loc["lat"]])
    r, c = src.index(xs[0], ys[0]); cell = abs(src.transform.a); n = int(HALF / cell)
    win = rasterio.windows.Window(c - n, r - n, 2 * n, 2 * n)
    z = src.read(1, window=win, boundless=True, fill_value=np.nan).astype(np.float32); nod = src.nodata
if nod is not None: z[z == nod] = np.nan
bad = ~np.isfinite(z); z[bad] = np.nanmedian(z); z -= np.nanmin(z)
np.savez_compressed(out, z=np.round(z, 3).astype(np.float32), cell=np.float32(cell))
print(out, z.shape, "cell", cell, "relief", float(z.max()), "no data", int(bad.sum()))

