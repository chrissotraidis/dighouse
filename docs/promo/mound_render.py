"""Render the 3D shot of Mound A at Angel Mounds from the bare-ground model (open USGS lidar): the camera circles the
mound while the heights stretch from x1 to x4, the light swings round, and a level line climbs it, leaving a contour
every metre. The app's own 3D view does the same things by hand: heights x1, x2 or x4, a light to move, a person for scale.
Usage: mound_render.py out_dir [frame numbers...]"""
import sys, os, json, numpy as np
from PIL import Image
W, H, FPS = 1920, 1080, 30
out = sys.argv[1]; only = [int(v) for v in sys.argv[2:]]
NF = 136
os.makedirs(out, exist_ok=True)
d = np.load("source/angel-mound.npz"); z0 = d["z"].astype(np.float32); cell = float(d["cell"])
# three times as fine, so the steep sides stay solid when the heights are stretched
UP = 3
n = z0.shape[0]; fine = np.linspace(0, n - 1, UP * (n - 1) + 1); i0 = np.floor(fine).astype(int).clip(0, n - 2); f = (fine - i0).astype(np.float32)
zr = z0[i0] * (1 - f)[:, None] + z0[i0 + 1] * f[:, None]; z = zr[:, i0] * (1 - f)[None, :] + zr[:, i0 + 1] * f[None, :]
cell /= UP; m = z.shape[0]; half = (m - 1) / 2 * cell
ys, xs = np.mgrid[0:m, 0:m]; gx = (xs * cell - half).astype(np.float32); gy = (half - ys * cell).astype(np.float32)
dzdy, dzdx = np.gradient(z, cell); dzdy = -dzdy                      # rows run north to south
keep = (np.abs(gx) < 172) & (np.abs(gy) < 172)
gx, gy, gz, dzdx, dzdy = gx[keep], gy[keep], z[keep], dzdx[keep], dzdy[keep]
base = float(np.median(gz)); top = float(z[m // 2 - 45:m // 2 + 45, m // 2 - 45:m // 2 + 45].max()); peak = top - base
print("points", len(gx), "the mound stands", round(peak, 1), "m", flush=True)

def ease_io(x): x = np.clip(x, 0, 1); return 3 * x * x - 2 * x * x * x
def look(az, el, dist, target):
    az, el = np.radians(az), np.radians(el)
    eye = np.asarray(target, float) + dist * np.array([np.cos(el) * np.cos(az), np.cos(el) * np.sin(az), np.sin(el)])
    fw = np.asarray(target, float) - eye; fw /= np.linalg.norm(fw); r = np.cross(fw, [0, 0, 1]); r /= np.linalg.norm(r); up = np.cross(r, fw)
    return eye, r, up, fw
FOC = 1500.0
def project(x, y, zz, cam):
    eye, r, up, fw = cam
    px, py, pz = x - eye[0], y - eye[1], zz - eye[2]
    cx = px * r[0] + py * r[1] + pz * r[2]; cy = px * up[0] + py * up[1] + pz * up[2]; cz = px * fw[0] + py * fw[1] + pz * fw[2]
    ok = cz > 10
    sx = (W / 2 + FOC * cx / np.maximum(cz, 10)).astype(np.int32); sy = (H / 2 - FOC * cy / np.maximum(cz, 10)).astype(np.int32)
    ok &= (sx >= 0) & (sx < W - 1) & (sy >= 0) & (sy < H - 1)
    return sx, sy, cz, ok
yy, xx = np.mgrid[0:H, 0:W]
vig = (1 - 0.3 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2))[..., None]
TAN = np.array([255, 200, 128], np.float32)
marks = {}
for k in range(NF):
    u = k / (NF - 1)
    zx = 1 + 3 * ease_io((u - 0.08) / 0.5)                       # the heights stretch from x1 to x4
    level = -1 + (peak + 2.5) * ease_io((u - 0.05) / 0.62)       # a level line climbs from the field to the top
    cam = look(208 + 92 * ease_io(u * 0.92 + 0.04), 31 - 9 * u, 345 - 105 * ease_io(u), (4, -4, base * zx + peak * zx * 0.42))
    person = project(np.zeros(2), np.zeros(2), np.array([top * zx, (top + 1.7) * zx]), cam)
    marks[k] = {"person": [int(person[0][1]), int(person[1][1])], "foot": [int(person[0][0]), int(person[1][0])], "zx": round(float(zx), 2), "peak": round(peak, 1)}
    if only and k not in only: continue
    # the light, low in the sky, swings from the north-west round to the south-west
    az, alt = np.radians(315 - 150 * ease_io(u)), np.radians(28)
    slope = np.arctan(np.hypot(dzdx, dzdy) * zx * 1.15); aspect = np.arctan2(-dzdx, -dzdy)
    shade = np.clip(np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect), 0, 1) ** 0.9
    col = np.stack([shade * 240 + 14, shade * 214 + 12, shade * 180 + 9], 1).astype(np.float32)
    hgt = gz - base
    line = np.clip(1 - np.abs(hgt - np.round(hgt)) / 0.085, 0, 1) * (hgt > 1.5) * (hgt < level - 0.3)     # contours left behind
    band = np.exp(-((hgt - level) / 0.3) ** 2) * (hgt > 1.2)                                              # the level itself
    glow = np.clip(0.9 * line + 1.5 * band, 0, 1)[:, None]
    col = col * (1 - 0.8 * glow) + TAN * (0.8 + 0.6 * band[:, None]) * glow
    sx, sy, cz, ok = project(gx, gy, gz * zx, cam)
    order = np.argsort(-cz[ok]); ix = sx[ok][order]; iy = sy[ok][order]
    c = col[ok][order] * np.clip(1.3 - cz[ok][order] / 620, 0.3, 1)[:, None]
    img = np.zeros((H, W, 3), np.float32)
    iy = np.clip(iy, 1, H - 2); ix = np.clip(ix, 1, W - 2)
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (-1, 0), (1, 0), (0, 1), (0, 0)): img[iy + dy, ix + dx] = c
    # stretched four times, a steep side opens gaps between the points: a hole takes the colour of the ground around it
    for _ in range(3):
        hole = img.sum(2) == 0; acc = np.zeros_like(img); cnt = np.zeros((H, W), np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            sh = np.roll(img, (dy, dx), (0, 1)); acc += sh; cnt += sh.sum(2) > 0
        fill = hole & (cnt >= 4); img[fill] = acc[fill] / cnt[fill][:, None]
    # a white post 1.70 m tall where the find is, drawn at the same stretch as the ground
    pz = np.linspace(top, top + 1.7, 60) * zx; px_, py_, _, pok = project(np.zeros(60), np.zeros(60), pz, cam)
    for dx in (-2, -1, 0, 1, 2): img[py_[pok], np.clip(px_[pok] + dx, 0, W - 1)] = (255, 255, 255)
    img = 255 * (1 - np.exp(-img / 190)) * vig
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(f"{out}/f{k:04d}.jpg", quality=92)
    if k % 30 == 0: print("frame", k, flush=True)
json.dump(marks, open(f"{out}/marks.json", "w"))
print("done")

