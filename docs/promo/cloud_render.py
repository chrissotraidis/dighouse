"""Render the promo's shots of the Serpent Mound point cloud (7 million laser returns, open USGS lidar).
  hero : eight bars. A pass of light crosses the canopy, the treetop points let go and rise away, and the camera
         comes down to the serpent on the bare ground
  slice: a slab through the serpent swings round to a side view: treetops above, the bank in the ground line
  end  : a slow orbit of the bare ground for the end card
Usage: cloud_render.py mode out_dir [frame numbers...]"""
import sys, os, json, numpy as np
from PIL import Image
W, H, FPS = 1920, 1080, 30
mode, out = sys.argv[1], sys.argv[2]; only = [int(v) for v in sys.argv[3:]]
NF = {"hero": 588, "slice": 148, "end": 224}[mode]
os.makedirs(out, exist_ok=True)
d = np.load("source/serpent-cloud.npz"); dtm = d["dtm"]; cell = float(d["cell"])
cc, rr = np.meshgrid(np.arange(dtm.shape[1]), np.arange(dtm.shape[0]))
G = np.stack([float(d["x0"]) + cc.ravel() * cell, float(d["y0"]) - rr.ravel() * cell, dtm.ravel(), d["shade"].ravel()], 1).astype(np.float32)
T = np.concatenate([d["trees"] / 100, d["tree_height"][:, None] / 100], 1).astype(np.float32)      # stored in centimetres
G = G[(np.abs(G[:, 0]) < 296) & (np.abs(G[:, 1]) < 296)]; T = T[(np.abs(T[:, 0]) < 296) & (np.abs(T[:, 1]) < 296)]
rng = np.random.default_rng(5)
ZX = 2.2
gx, gy, gz0, gs = G[:, 0], G[:, 1], G[:, 2], G[:, 3]
tx, ty, tz0, th = T[:, 0], T[:, 1], T[:, 2], T[:, 3]
tseed = rng.random(len(T)).astype(np.float32); tdrift = rng.normal(0, 1, (len(T), 2)).astype(np.float32)
shade = np.clip(gs, 0, 1) ** 1.1
gcol = np.stack([shade * 240 + 14, shade * 216 + 12, shade * 184 + 9], 1).astype(np.float32)
k = np.clip(th / 30, 0, 1)[:, None]
tcol = (np.array([34, 104, 50]) * (1 - k) + np.array([158, 240, 126]) * k).astype(np.float32)
SERPENT = np.array([-42.0, 5.0]); sz = float(gz0[np.argmin((gx - SERPENT[0]) ** 2 + (gy - SERPENT[1]) ** 2)])
MARK = (-18.0, -22.0); mz = float(gz0[np.argmin((gx - MARK[0]) ** 2 + (gy - MARK[1]) ** 2)])
SLICE_Y, SLICE_HALF = -22.0, 5.0
_b = gz0[(np.abs(gy - SLICE_Y) < SLICE_HALF) & (np.abs(gx + 30) < 200)]; BAND_MID = float((_b.min() + _b.max()) / 2)

def ease_io(x): x = np.clip(x, 0, 1); return 3 * x * x - 2 * x * x * x
def look(az, el, dist, target):
    az, el = np.radians(az), np.radians(el)
    eye = np.asarray(target, float) + dist * np.array([np.cos(el) * np.cos(az), np.cos(el) * np.sin(az), np.sin(el)])
    f = np.asarray(target, float) - eye; f /= np.linalg.norm(f); r = np.cross(f, [0, 0, 1]); r /= np.linalg.norm(r); up = np.cross(r, f)
    return eye, r, up, f
HERO_END = dict(az=262, el=36, dist=380, target=(SERPENT[0], SERPENT[1], sz * ZX))
def camera(u):
    if mode == "hero":
        # Eight bars: a slow drift over the canopy while the scan fills in, the move down to the serpent, then a slow drift again.
        e = ease_io((u - 0.225) / 0.45)
        return look(188 + (HERO_END["az"] - 196) * e + 18 * u, 55 + (HERO_END["el"] - 55) * e - 2 * u, 850 + (HERO_END["dist"] - 800) * e - 74 * u,
                    (20 + (SERPENT[0] - 20) * e, 30 + (SERPENT[1] - 30) * e, sz * ZX * e))
    if mode == "end":
        return look(HERO_END["az"] + 9 + 30 * u, HERO_END["el"] - 2 - 3 * u, HERO_END["dist"] - 24 + 100 * u, HERO_END["target"])
    e = ease_io(u / 0.5); hold = max(0.0, u - 0.45)           # slice: swing down to a side view from the south, then drift
    return look(HERO_END["az"] + (270 - HERO_END["az"]) * e + 5 * hold, HERO_END["el"] + (6 - HERO_END["el"]) * e, HERO_END["dist"] + (372 - HERO_END["dist"]) * e - 24 * hold,
                (SERPENT[0] + (-30 - SERPENT[0]) * e, SERPENT[1] + (SLICE_Y - SERPENT[1]) * e, (sz * ZX) + (BAND_MID * 3.0 + 18 - sz * ZX) * e))
FOC = 1500.0
def project(x, y, z, cam):
    eye, r, up, f = cam
    px, py, pz = x - eye[0], y - eye[1], z - eye[2]
    cx = px * r[0] + py * r[1] + pz * r[2]; cy = px * up[0] + py * up[1] + pz * up[2]; cz = px * f[0] + py * f[1] + pz * f[2]
    ok = cz > 10
    sx = (W / 2 + FOC * cx / np.maximum(cz, 10)).astype(np.int32); sy = (H / 2 - FOC * cy / np.maximum(cz, 10)).astype(np.int32)
    ok &= (sx >= 0) & (sx < W - 1) & (sy >= 0) & (sy < H - 1)
    return sx, sy, cz, ok
yy, xx = np.mgrid[0:H, 0:W]
vig = (1 - 0.3 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2))[..., None]
marks = {}
SCAN_END = 0.125
_c0 = camera(0.0); _ax = np.array([_c0[1][0], _c0[1][1]]); _ax /= np.linalg.norm(_ax)
gscan = gx * _ax[0] + gy * _ax[1]; tscan = tx * _ax[0] + ty * _ax[1]
SC0, SC1 = float(gscan.min()) - 10, float(gscan.max()) + 60
def scan_weight(s, u):
    """Bright just behind the pass, 1 everywhere else: the whole cloud is there from the first frame."""
    if mode != "hero" or u >= SCAN_END + 0.03: return None
    front = SC0 + (SC1 - SC0) * (u / SCAN_END)
    behind = front - s
    return (np.where(behind < 0, 1.0, 1.0 + 2.6 * np.exp(-np.maximum(behind, 0) / 22.0))).astype(np.float32)
def scan_edge(s, u):
    """1 on the line the pass has just reached, falling away behind it."""
    front = SC0 + (SC1 - SC0) * (u / SCAN_END); behind = front - s
    return np.where(behind < 0, 0.0, np.exp(-np.maximum(behind, 0) / 5.0)).astype(np.float32)
for n in range(NF):
    u = n / (NF - 1); cam = camera(u)
    zx = ZX if mode != "slice" else ZX + (3.0 - ZX) * ease_io(u / 0.5)       # the side view stretches height so a 1 m bank shows
    ms = project(np.array([MARK[0]]), np.array([MARK[1]]), np.array([mz * zx]), cam)
    marks[n] = [int(ms[0][0]), int(ms[1][0])]
    if only and n not in only: continue
    gz = gz0 * zx; tz = tz0 * zx
    img = np.zeros((H, W, 3), np.float32)
    reveal = ease_io((u - 0.30) / 0.225) if mode == "hero" else 1.0
    gsw = scan_weight(gscan, u); tsw = scan_weight(tscan, u)
    sx, sy, cz, ok = project(gx, gy, gz, cam)
    w = np.ones(len(gx), np.float32)
    if mode == "slice":
        inband = np.abs(gy - SLICE_Y) < SLICE_HALF
        fadeout = ease_io((u - 0.08) / 0.36)
        w = np.where(inband, 1.0, 1 - 0.93 * fadeout).astype(np.float32)
        sweep = -300 + 620 * ease_io(u / 0.28)                                 # the cut runs west to east first
        w = np.where(inband & (gx < sweep), 1.35, w)
    if gsw is not None: w = w * gsw
    order = np.argsort(-cz[ok]); ix = sx[ok][order]; iy = sy[ok][order]
    col = gcol[ok][order] * (np.clip(1.25 - cz[ok][order] / 1100, 0.35, 1) * w[ok][order])[:, None]
    if mode == "slice":
        tan = np.array([255, 196, 120], np.float32); mixk = (ease_io((u - 0.25) / 0.3) * (w[ok][order] > 1))[:, None]
        col = col * (1 - mixk) + tan * mixk
    if gsw is not None:
        k = scan_edge(gscan, u)[ok][order][:, None]; col = col * (1 - k) + np.array([255, 214, 150], np.float32) * 1.6 * k
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)): img[iy + dy, ix + dx] = col
    img *= (0.5 + 0.5 * reveal)
    def trees(alpha, sel=None, lift=None):
        x2, y2, z2, c = tx, ty, tz, tcol
        if sel is not None: x2, y2, z2, c, alpha = x2[sel], y2[sel], z2[sel], c[sel], alpha[sel]
        sx, sy, cz, ok = project(x2, y2, z2, cam)
        a = alpha[ok] * np.clip(1.3 - cz[ok] / 1000, 0.3, 1)
        flat = sy[ok].astype(np.int64) * W + sx[ok]
        for ch in range(3): img[..., ch] += np.bincount(flat, weights=a * c[ok][:, ch], minlength=W * H).reshape(H, W)
    if mode == "hero" and reveal < 1:
        p = np.clip((reveal * 1.25 - tseed) / 0.25, 0, 1); alive = p < 1
        scanw = tsw if tsw is not None else 1.0
        save = (tx, ty, tz)
        tx2 = tx + tdrift[:, 0] * p * 10; ty2 = ty + tdrift[:, 1] * p * 10; tz2 = tz + (p ** 1.6) * 150
        tx_, ty_, tz_ = tx, ty, tz; tx, ty, tz = tx2, ty2, tz2
        trees(((1 - p) ** 1.3 * 0.62 * scanw).astype(np.float32), sel=alive)
        tx, ty, tz = tx_, ty_, tz_
    if mode == "slice":
        inband = np.abs(ty - SLICE_Y) < SLICE_HALF
        trees(np.full(len(tx), 0.0, np.float32) + ease_io((u - 0.15) / 0.3) * 1.5, sel=inband)
    img = 255 * (1 - np.exp(-img / 190)) * vig
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(f"{out}/f{n:04d}.jpg", quality=92)
    if n % 30 == 0: print("frame", n, flush=True)
if not only or len(only) > 40: json.dump(marks, open(f"{out}/marks.json", "w"))
print("done", mode)

