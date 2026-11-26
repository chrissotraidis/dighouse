"""The Dighouse promo: 65 s at 1920x1080, cut to a 98 BPM track (one bar = 2.449 s, 26.5 bars).
Real things only: 3D renders of the open lidar at Serpent Mound and Angel Mounds; the app's live map as a finished blind test
at Mound City is replayed into it; the app's own scorecard, Decide card, 3D view and view pictures at Angel Mounds.
Usage: render.py                    the whole film to build/video-only.mp4
       render.py t1 t2 ...          stills at those seconds, as build/still-<t>.jpg
       render.py --range a b out    frames from a to b (seconds) to one part of the film"""
import subprocess, sys, json, math, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

W, H, FPS = 1920, 1080, 30
BAR = 4 * 60 / 98; B = BAR; BEAT = BAR / 4; DUR = 26.5 * BAR
CLIPS = "source/clips/"; STILLS = "source/stills/"; BUILD = "build/"; STARTS = "../../app/Resources/starts/"
TEXT = (246, 240, 230); DIM = (196, 184, 170); TAN = (228, 180, 110); GREEN = (140, 226, 120); FAINT = (120, 110, 100)

def font(size, weight="Bold"):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size); f.set_variation_by_name(weight); return f
def mono(size):
    f = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", size)
    try: f.set_variation_by_name("Medium")
    except Exception: pass
    return f
F_KICK = font(30, "Semibold"); F_BIG = font(150, "Heavy"); F_TAG = font(46, "Semibold"); F_SMALL = font(28, "Medium")
F_MARK = font(30, "Bold"); F_SUB = font(44, "Medium"); F_HUD = mono(24); F_LABEL = font(34, "Bold")
def ease(x): x = min(max(x, 0), 1); return 1 - (1 - x) ** 3
def ease_io(x): x = min(max(x, 0), 1); return 3 * x * x - 2 * x * x * x
def back(x):
    x = min(max(x, 0), 1); c = 1.7; return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2

yy, xx = np.mgrid[0:H, 0:W]
dd = np.sqrt(((xx - W * 0.62) / W) ** 2 + ((yy - H * 0.5) / H) ** 2)
base = np.array([34, 25, 19]) * (1 - 0.62 * dd[..., None]) + np.array([9, 7, 6]) * 0.62 * dd[..., None]
BG = Image.fromarray(np.clip(base + np.random.default_rng(3).normal(0, 2.2, (H, W, 1)), 0, 255).astype(np.uint8)).convert("RGBA")

# ---- text ----------------------------------------------------------------------------
def wrap(text, f, width):
    words, lines, cur = text.split(), [], ""
    for w_ in words:
        trial = (cur + " " + w_).strip()
        if f.getlength(trial) <= width or not cur: cur = trial
        else: lines.append(cur); cur = w_
    lines.append(cur); return lines
def spaced(dr, xy, text, f, fill, track=4.0):
    x, y = xy
    for ch in text: dr.text((x, y), ch, font=f, fill=fill); x += f.getlength(ch) + track
    return x
def caption(img, kicker, head, t, x=80, width=560, y_mid=None, sizes=(84, 76, 68, 62), sub=None, out_at=None, shadow=False, maxlines=4):
    """Kicker, headline and an optional smaller line. Lines slide up one after another; everything leaves just before the cut."""
    if t < 0: return
    for size in sizes:
        f = font(size, "Bold"); lines = head.split("\n") if "\n" in head else wrap(head, f, width)
        if len(lines) <= maxlines and max(f.getlength(ln) for ln in lines) <= width: break
    lh = int(f.size * 1.13); sublines = wrap(sub, F_SUB, width) if sub else []
    block = 58 + len(lines) * lh + (22 + len(sublines) * 54 if sub else 0)
    y0 = (H - block) // 2 if y_mid is None else y_mid - block // 2
    gone = ease((t - out_at) / 0.22) if out_at is not None else 0
    if gone >= 1: return
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0)); dr = ImageDraw.Draw(layer)
    def put(xy, s, fnt, col, a):
        if shadow: dr.text((xy[0] + 2, xy[1] + 3), s, font=fnt, fill=(0, 0, 0, int(200 * a)))
        dr.text(xy, s, font=fnt, fill=col + (int(255 * a),))
    if kicker:
        a = ease(t / 0.18) * (1 - gone)
        if shadow: spaced(dr, (x + 2, y0 + 2), kicker, F_KICK, (0, 0, 0, int(190 * a)))
        spaced(dr, (x - (1 - ease(t / 0.18)) * 30, y0), kicker, F_KICK, TAN + (int(255 * a),))
        dr.rectangle((x, y0 + 44, x + int(56 * a), y0 + 48), fill=TAN + (int(255 * a),))
    for i, ln in enumerate(lines):
        p = (t - 0.06 - i * 0.07) / 0.3
        put((x, y0 + 64 + i * lh + (1 - ease(p)) * 46 - gone * 20), ln, f, TEXT, ease(p) * (1 - gone))
    for j, ln in enumerate(sublines):
        p = (t - 0.45 - j * 0.07) / 0.3
        put((x, y0 + 64 + len(lines) * lh + 22 + j * 54 + (1 - ease(p)) * 20), ln, F_SUB, DIM, ease(p) * (1 - gone))
    img.alpha_composite(layer)

# ---- the mark, as the app draws it ------------------------------------------------------
def mark(img, cx, cy, w, sweep, shown=1.0, alpha=1.0, strength=1.0):
    """The line of ground with a mound in it and the canopy above. A pass of light crosses it (sweep 0 to 1);
    shown below 1 draws only the columns the first pass has reached."""
    S = 3; h = w * 15 / 34; n = 15
    lw, lh = int(w * 1.3 * S), int(h * 1.6 * S)
    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0)); dr = ImageDraw.Draw(layer)
    ox, oy = (lw - w * S) / 2, (lh - h * S) / 2; dot = w / n * 0.62
    def lift(t): return math.exp(-((t - 0.5) / 0.17) ** 2)
    for i in range(n):
        t = i / (n - 1)
        vis = ease((shown * 1.25 - t) / 0.12)
        if vis <= 0: continue
        near = 0 if sweep is None else strength * max(0.0, 1 - abs(t - (sweep * 1.4 - 0.2)) / 0.18)
        x = t * (w - dot); ground = h - dot - lift(t) * h * 0.34
        grow = dot * (1 + 0.5 * near) * (0.4 + 0.6 * back(vis))
        gx, gy = x - (grow - dot) / 2, ground - (grow - dot) / 2
        col = tuple(int(c + (255 - c) * 0.35 * near) for c in TAN)
        dr.ellipse(((ox / S + gx) * S, (oy / S + gy) * S, (ox / S + gx + grow) * S, (oy / S + gy + grow) * S), fill=col + (int(255 * (0.7 + 0.3 * near) * vis * alpha),))
        for row in (1, 2):
            if (i + row) % 2 == 0 and 0 < i < n - 1:
                y = ground - row * h * 0.27
                dr.ellipse(((ox / S + x) * S, (oy / S + y) * S, (ox / S + x + dot) * S, (oy / S + y + dot) * S), fill=GREEN + (int(255 * (1 - 0.8 * near) * vis * alpha),))
    small = layer.resize((lw // S, lh // S), Image.LANCZOS)
    img.alpha_composite(small, (int(cx - small.width / 2), int(cy - small.height / 2)))
class Over:
    """A clear layer to draw on, laid over the picture when the block ends, so that alpha fades."""
    def __init__(self, img): self.img = img
    def __enter__(self):
        self.layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0)); return ImageDraw.Draw(self.layer)
    def __exit__(self, *exc): self.img.alpha_composite(self.layer)
def brand(img, a=1.0, t=0.0):
    if a <= 0: return
    mark(img, 104, 76, 50, (t % B) / B, alpha=a, strength=0.9)
    with Over(img) as dr: dr.text((142, 58), "Dighouse", font=F_MARK, fill=TEXT + (int(235 * a),))
def hud(img, lines, t, x=W - 80, y=64, col=DIM):
    """A small right-aligned readout that types itself on."""
    dr = ImageDraw.Draw(img)
    for i, s in enumerate(lines):
        n = int(max(0, (t - i * 0.12) * 60)); s2 = s[:n]
        dr.text((x - F_HUD.getlength(s), y + i * 30), s2, font=F_HUD, fill=col + (220,))
def corners(img, a=0.5):
    dr = ImageDraw.Draw(img); c = TAN + (int(255 * a),); m, l = 40, 46
    for (x, y, sx, sy) in [(m, m, 1, 1), (W - m, m, -1, 1), (m, H - m, 1, -1), (W - m, H - m, -1, -1)]:
        dr.line((x, y, x + sx * l, y), fill=c, width=3); dr.line((x, y, x, y + sy * l), fill=c, width=3)
def flash(img, amount, col=(255, 248, 236)):
    return Image.blend(img, Image.new("RGBA", img.size, col + (255,)), amount) if amount > 0 else img
def darken(img, k): return Image.blend(img, Image.new("RGBA", img.size, (0, 0, 0, 255)), k)
def pill(img, text, x, y, p, col=GREEN, f_=None, dot=None, fill=(22, 40, 22)):
    """A rounded label that pops in. With dot set (0 to 1) it carries a pulsing light instead of a tick."""
    if p <= 0: return 0
    f_ = f_ or font(38, "Bold"); tw = f_.getlength(text); a = ease(p); y = y + (1 - back(p)) * 30
    hgt = int(f_.size * 1.9); lead = int(f_.size * 1.9)
    with Over(img) as dr:
        dr.rounded_rectangle((x, y, x + tw + lead + 34, y + hgt), hgt // 2, fill=fill + (int(240 * a),), outline=col + (int(255 * a),), width=3)
        ty = y + (hgt - f_.size * 1.22) / 2
        if dot is None: dr.text((x + 28, ty), "✓", font=f_, fill=col + (int(255 * a),))
        else:
            cx_, cy_ = x + 40, y + hgt / 2; r = f_.size * 0.24
            rr = r * (1 + 1.6 * dot); dr.ellipse((cx_ - rr, cy_ - rr, cx_ + rr, cy_ + rr), outline=col + (int(200 * (1 - dot) * a),), width=3)
            dr.ellipse((cx_ - r, cy_ - r, cx_ + r, cy_ + r), fill=col + (int(255 * a),))
        dr.text((x + lead + 6, ty), text, font=f_, fill=TEXT + (int(255 * a),))
    return tw + lead + 34

# ---- footage and pictures, as cards tilted in space ---------------------------------------
def decode(name, start, dur, speed, crop, size):
    """crop is (x, y, w, h) in the recording's own pixels."""
    x, y, w, h = crop
    vf = f"crop={w}:{h}:{x}:{y},setpts=(PTS-STARTPTS)/{speed},fps={FPS},scale={size[0]}:{size[1]}:flags=lanczos"
    out = subprocess.run(["ffmpeg", "-v", "error", "-ss", str(start), "-t", str(dur), "-i", CLIPS + name, "-vf", vf,
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    return np.frombuffer(out, np.uint8).reshape(-1, size[1], size[0], 3)
def coeffs(dst, src):
    A, Bv = [], []
    for (x, y), (u, v) in zip(dst, src):
        A.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); A.append([0, 0, 0, x, y, 1, -v * x, -v * y]); Bv += [u, v]
    return np.linalg.solve(np.array(A, float), np.array(Bv, float))
_masks = {}
def place_card(img, frame, cx, cy, yaw=0.0, pitch=0.0, scale=1.0, alpha=1.0, radius=22):
    """Put a picture on the frame as a rounded card, turned a few degrees in space, with a soft shadow."""
    w, h = frame.size
    if (w, h, radius) not in _masks:
        m = Image.new("L", (w, h), 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
        b = Image.new("RGBA", (w, h), (0, 0, 0, 0)); ImageDraw.Draw(b).rounded_rectangle((0, 0, w - 1, h - 1), radius, outline=(255, 255, 255, 46), width=2)
        _masks[(w, h, radius)] = (m, b)
    m, b = _masks[(w, h, radius)]
    card = frame.convert("RGBA"); card.alpha_composite(b); card.putalpha(m)
    ya, pa = math.radians(yaw), math.radians(pitch); pts = []
    for px, py in [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]:
        X, Y = px * scale, py * scale
        X2, Z2 = X * math.cos(ya), -X * math.sin(ya)
        Y2, Z3 = Y * math.cos(pa) - Z2 * math.sin(pa), Y * math.sin(pa) + Z2 * math.cos(pa)
        s = 2600 / (2600 + Z3); pts.append((cx + X2 * s, cy + Y2 * s))
    sh = Image.new("L", (W // 4, H // 4), 0)
    ImageDraw.Draw(sh).polygon([((x + 10) / 4, (y + 34) / 4) for x, y in pts], fill=int(190 * alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(10)).resize((W, H), Image.BILINEAR)
    img.paste((0, 0, 0, 255), (0, 0), sh)
    warped = card.transform((W, H), Image.PERSPECTIVE, coeffs(pts, [(0, 0), (w, 0), (w, h), (0, h)]), Image.BICUBIC)
    if alpha < 1: warped.putalpha(ImageChops.multiply(warped.getchannel("A"), Image.new("L", (W, H), int(255 * alpha))))
    img.alpha_composite(warped)
    return pts
def pop(img, frame, cx, cy, p, yaw=0.0, pitch=0.0, scale=1.0, rise=70, radius=22):
    """A card that arrives from below with a small overshoot."""
    if p <= 0: return
    place_card(img, frame, cx, cy + (1 - back(p)) * rise, yaw=yaw, pitch=pitch, scale=scale * (0.8 + 0.2 * back(p)), alpha=ease(p), radius=radius)

# ---- timing --------------------------------------------------------------------------
SC = [("hero", 0, 8), ("live", 8, 12), ("score", 12, 14), ("slice", 14, 16), ("see", 16, 20), ("decide", 20, 22), ("range", 22, 24), ("end", 24, 26.5)]
SC = [(k, a * B, b * B) for k, a, b in SC]
_cl = {}
def cloud(folder, n, total):
    n = int(min(max(n, 0), total - 1)); key = (folder, n)
    if key not in _cl:
        if len(_cl) > 6: _cl.clear()
        _cl[key] = Image.open(f"{BUILD}{folder}/f{n:04d}.jpg").convert("RGBA")
    return _cl[key].copy()
MARKS = json.load(open(BUILD + "cloud-hero/marks.json")); MOUND = json.load(open(BUILD + "cloud-mound/marks.json"))
_fr = {}
def footage(key, *args):
    if key not in _fr:
        if len(_fr) > 3: _fr.clear()
        _fr[key] = decode(*args)
    return _fr[key]
def frame_at(arr, lt): return Image.fromarray(arr[min(max(int(lt * FPS), 0), len(arr) - 1)])
_im = {}
def still(path, crop=None, size=None):
    key = (path, crop, size)
    if key not in _im:
        im = Image.open(path).convert("RGB")
        if crop: im = im.crop((crop[0], crop[1], crop[0] + crop[2], crop[1] + crop[3]))
        if size: im = im.resize(size, Image.LANCZOS)
        _im[key] = im
    return _im[key]

def ring(img, xy, t, label=None, out=0.0):
    x, y = xy; k_ = ease(t / 0.3) * (1 - out)
    with Over(img) as dr:
        for k in range(2):
            p = ((t * 1.1 + k * 0.5) % 1.0); r = 26 + 90 * p
            dr.ellipse((x - r, y - r * 0.55, x + r, y + r * 0.55), outline=TAN + (int(230 * (1 - p) * k_),), width=4)
        dr.ellipse((x - 9, y - 9, x + 9, y + 9), fill=TAN + (int(255 * k_),), outline=(20, 16, 12, int(255 * k_)), width=3)
        if label:
            tw = F_LABEL.getlength(label)
            dr.rounded_rectangle((x + 30, y - 78, x + 30 + tw + 36, y - 22), 28, fill=(18, 14, 11, int(225 * k_)), outline=TAN + (int(255 * k_),), width=2)
            dr.text((x + 48, y - 72), label, font=F_LABEL, fill=TEXT + (int(255 * k_),))
def tag(img, text, x, y, a, col=TAN, f_=F_LABEL):
    if a <= 0: return
    tw = f_.getlength(text); hgt = int(f_.size * 1.65)
    with Over(img) as dr:
        dr.rounded_rectangle((x, y, x + tw + 36, y + hgt), hgt // 2, fill=(14, 11, 9, int(230 * a)), outline=col + (int(255 * a),), width=2)
        dr.text((x + 18, y + (hgt - f_.size * 1.22) / 2), text, font=f_, fill=col + (int(255 * a),))
def green_hud(img, s, t, dot=True):
    dr = ImageDraw.Draw(img); x = W - 80 - F_HUD.getlength(s)
    dr.text((x, 52), s, font=F_HUD, fill=GREEN + (230,))
    if dot and int(t * 2) % 2 == 0: dr.ellipse((x - 28, 59, x - 12, 75), fill=GREEN + (255,))

LIVE_SPAN = 61.5                         # the replay in the recording, from its first tile to its last find
VIEWS = ["composite", "relief_small", "sky_view", "hillshade", "positive_openness", "negative_openness", "vat", "msrm", "local_dominance"]
LIGHTS = [165, 180, 195, 210, 225, 240]

def render(kind, lt, dur, t):
    if kind == "hero":
        img = cloud("cloud-hero", lt * FPS, 588)
        corners(img, 0.45)
        hud(img, ["OPEN USGS LIDAR  ·  SERPENT MOUND, OHIO", "7,020,212 LASER RETURNS"], lt + 10)
        T_OUT = 2 * B - 0.1
        if lt < T_OUT + 0.4:                                      # the mark, the name and what it is, whole from the first frame
            g = ease((lt - T_OUT) / 0.35); a = 1 - g
            shade = Image.new("L", (W, H), 0); ImageDraw.Draw(shade).ellipse((W // 2 - 780, 110, W // 2 + 780, 840), fill=165)
            img.paste((0, 0, 0, 255), (0, 0), shade.filter(ImageFilter.GaussianBlur(120)).point(lambda v: int(v * a)))
            layer = Image.new("RGBA", img.size, (0, 0, 0, 0)); dr = ImageDraw.Draw(layer)
            mark(layer, W // 2, 262 - g * 30, 500, ((lt + 0.6) % B) / B, alpha=a)
            tw = F_BIG.getlength("Dighouse")
            dr.text((W // 2 - tw / 2, 405 - g * 30), "Dighouse", font=F_BIG, fill=TEXT + (int(255 * a),))
            tg = "Agentic archaeology on your Mac."; tw2 = F_TAG.getlength(tg)
            dr.text((W // 2 - tw2 / 2, 598 - g * 30), tg, font=F_TAG, fill=TAN + (int(255 * a),))
            img.alpha_composite(layer)
        C1, C2, C3 = 2.08 * B, 4.5 * B, 6.72 * B
        if C1 <= lt < C2: caption(img, "OPEN LIDAR", "Lasers have mapped the ground under the trees.", lt - C1, width=1400, y_mid=int(H * 0.8), sizes=(92, 82), out_at=C2 - C1 - 0.3, shadow=True, maxlines=2)
        if C2 <= lt < C3: caption(img, "TOO MUCH TO LOOK OVER", "There is far more of it than anyone can look over by eye.", lt - C2, width=1400, y_mid=int(H * 0.8), sizes=(92, 82), out_at=C3 - C2 - 0.3, shadow=True, maxlines=2)
        if lt >= C3: caption(img, "DIGHOUSE", "Now agentic AI can\nsearch it for you.", lt - C3, width=1500, y_mid=int(H * 0.8), sizes=(92, 82), shadow=True, maxlines=2)
        if lt > 5.35 * B and lt < C3 + 0.2:
            m = MARKS[str(min(int(lt * FPS), 587))]; ring(img, m, lt - 5.35 * B, "Serpent Mound · 411 m long", out=ease((lt - C3 + 0.1) / 0.3))
        if lt >= C1: brand(img, ease((lt - C1) / 0.5), t)
        return img
    if kind == "live":
        img = BG.copy(); speed = LIVE_SPAN / dur
        fm = footage("livemap", "live-map.mp4", 0, LIVE_SPAN + 2, speed, (0, 0, 1629, 1466), (960, 864))
        fp = footage("livepanel", "live-panel.mp4", 0, LIVE_SPAN + 2, speed, (0, 0, 566, 374), (566, 374))
        e = ease_io(lt / dur)
        place_card(img, frame_at(fm, lt), 1338 - 26 * e, 548, yaw=-9 + 6 * e, pitch=2 - 1.5 * e, scale=0.94 + 0.06 * e)
        pop(img, frame_at(fp, lt), 372, 822, (lt - 0.5) / 0.4, yaw=7, pitch=-1, scale=1.0, radius=18)
        if lt < 2 * B: caption(img, "SEARCH", "Pick a place. Watch it search.", lt, width=560, y_mid=372, sizes=(84, 76), sub="Every tile is looked at.", out_at=2 * B - 0.3)
        else: caption(img, "FIND", "Finds arrive as it works.", lt - 2 * B, width=560, y_mid=372, sizes=(84, 76), sub="The strongest rise to the top.")
        brand(img, 1, t)
        green_hud(img, "REPLAY OF A REAL BLIND TEST  ·  A 4-MINUTE SEARCH", t)
        return flash(img, max(0, 1 - lt / 0.25) * 0.8)
    if kind == "score":
        img = BG.copy()
        card = still(STILLS + "scorecard.png", None, (986, 825))
        e = ease_io(lt / dur)
        place_card(img, card, 1350 - 16 * e, 548, yaw=-8 + 4 * e, pitch=2 - e, scale=0.95 + 0.05 * e)
        caption(img, "TESTED BLIND", "19 of 19 published\nfeatures found.", lt, width=600, y_mid=400, sizes=(88, 80), sub="It was never told the site: Mound City Group, Ohio.")
        a = ease((lt - 2.0) / 0.4)
        with Over(img) as dr:
            for i, s_ in enumerate(["13 known sites tested blind so far:", "67 of 105 published features found."]):
                dr.text((80, 880 + i * 40 + (1 - a) * 14), s_, font=font(30, "Medium"), fill=DIM + (int(235 * a),))
        brand(img, 1, t); green_hud(img, "THE SCORECARD OF THAT SEARCH", t, dot=False)
        return flash(img, max(0, 1 - lt / 0.1) * 0.25)
    if kind == "slice":
        img = cloud("cloud-slice", lt * FPS, 148); corners(img, 0.45); brand(img, 1, t)
        caption(img, "CHECK", "In the ground, or just the trees?", lt, width=1400, y_mid=int(H * 0.8), sizes=(96, 84), shadow=True, maxlines=2)
        a = ease((lt - 1.9) / 0.3)
        tag(img, "treetops", 1010, 250, a, GREEN); tag(img, "the ground", 700, 560, a, TAN)
        hud(img, ["A SLICE THROUGH THE LASER POINTS"], lt)
        return img
    if kind == "see":
        cuts = [0, 1.1 * B, 2.2 * B, dur]; k = 2 if lt >= cuts[2] else 1 if lt >= cuts[1] else 0
        l2 = lt - cuts[k]; beat = cuts[k + 1] - cuts[k]; e = ease_io(l2 / beat); img = BG.copy()
        if k == 0:
            fv = footage("views", "close-views.mp4", 0, 11.6, 11.3 / beat, (0, 0, 630, 608), (630, 608))
            place_card(img, frame_at(fv, l2), 940 - 12 * e, 528, yaw=7 - 3 * e, pitch=1, scale=0.98 + 0.04 * e)
            for i, v in enumerate(VIEWS):
                tile = still(STILLS + f"views/{v}.png", None, (172, 172))
                pop(img, tile, 1404 + (i % 3) * 188, 340 + (i // 3) * 188, (l2 - 0.2 - i * 0.16) / 0.3, yaw=-8, pitch=1, rise=40, radius=14)
            caption(img, "LOOK CLOSER", "Nine ways to see a find.", l2, width=520, sizes=(84, 76), out_at=beat - 0.25)
            brand(img, 1, t); hud(img, ["ANGEL MOUNDS, INDIANA  ·  OPEN USGS LIDAR"], lt)
        elif k == 1:
            S = 620; a13 = still(STILLS + "flights.png", (0, 0, 300, 300), (S, S)); a19 = still(STILLS + "flights.png", (308, 0, 300, 300), (S, S))
            chg = still(STILLS + "flights.png", (616, 0, 300, 300), (380, 380))
            x = int(S * (0.86 - 0.72 * ease_io((l2 - 0.3) / (beat - 1.0))))
            pic = a19.copy(); pic.paste(a13.crop((0, 0, x, S)), (0, 0)); dr = ImageDraw.Draw(pic)
            dr.rectangle((x - 3, 0, x + 3, S), fill=(255, 255, 255)); dr.ellipse((x - 22, S // 2 - 22, x + 22, S // 2 + 22), fill=(250, 246, 240))
            for s_, px in (("2013", 18), ("2019", S - 18 - font(36, "Bold").getlength("2019"))):
                dr.rounded_rectangle((px - 10, S - 66, px + font(36, "Bold").getlength(s_) + 10, S - 16), 12, fill=(14, 11, 9)); dr.text((px, S - 62), s_, font=font(36, "Bold"), fill=TEXT)
            place_card(img, pic, 1050 - 10 * e, 510, yaw=6 - 3 * e, pitch=1, scale=1.0 + 0.03 * e)
            pop(img, chg, 1590, 600, (l2 - 0.7) / 0.35, yaw=-9, pitch=1, radius=16)
            a = ease((l2 - 1.0) / 0.3)
            with Over(img) as dr: dr.text((1402, 818 + (1 - a) * 12), "What changed between them", font=font(28, "Medium"), fill=DIM + (int(235 * a),))
            caption(img, "COMPARE", "Two flights, six years apart.", l2, width=520, sizes=(84, 76), y_mid=440, out_at=beat - 0.25)
            pill(img, "Present in both flights", 80, 676, (l2 - 1.25) / 0.3, f_=font(34, "Bold"))
            brand(img, 1, t); hud(img, ["ANGEL MOUNDS, INDIANA  ·  OPEN USGS LIDAR"], lt)
        else:
            # the ground itself, turning: heights stretched from x1 to x4, the light swinging, a contour left every metre
            n = min(int(l2 * FPS), 135); mk = MOUND[str(n)]
            img = cloud("cloud-mound", n, 136); corners(img, 0.45)
            px, py = mk["person"]; tag(img, "a person, 1.70 m", px + 20, py - 34, ease((l2 - 1.7) / 0.3), TEXT, font(28, "Bold"))
            caption(img, "TURN IT", "See it in 3D.", l2, width=1400, y_mid=int(H * 0.8), sizes=(96, 84), sub="Stretch the heights. Swing the light.", shadow=True, maxlines=2)
            hud(img, ["ANGEL MOUNDS, INDIANA  ·  MOUND A", f"HEIGHTS \u00d7{mk['zx']:.1f}  ·  OPEN USGS LIDAR"], lt)
            # and the app's own 3D view of the same mound, small, with its light moving
            u = min(l2 / (beat - 0.3), 1) * (len(LIGHTS) - 1); i0 = min(int(u), len(LIGHTS) - 2); f_ = u - i0
            size = (530, 295)
            pic = Image.blend(still(STILLS + f"3d-light-{LIGHTS[i0]}.png", None, size), still(STILLS + f"3d-light-{LIGHTS[i0 + 1]}.png", None, size), ease_io(f_))
            p = (l2 - 1.3) / 0.4; pop(img, pic, 1580, 846, p, yaw=-7, pitch=1, rise=50, radius=16)
            with Over(img) as dr: dr.text((1324, 668), "IN THE APP", font=F_HUD, fill=DIM + (int(230 * ease(p)),))
            brand(img, 1, t)
            return flash(img, max(0, 1 - l2 / 0.22) * 0.7)
        return flash(img, max(0, 1 - l2 / 0.1) * 0.22)
    if kind == "decide":
        img = BG.copy(); e = ease_io(lt / dur)
        top = still(STILLS + "decide.png", (20, 132, 1196, 770), (964, 621))
        place_card(img, top, 1356 - 16 * e, 436, yaw=-8 + 4 * e, pitch=2 - e, scale=0.9 + 0.05 * e)
        ev = still(STILLS + "decide.png", (20, 940, 900, 180), (860, 172))
        pop(img, ev, 1250, 822, (lt - 0.7) / 0.4, yaw=5, pitch=-1, radius=18)
        keys = still(STILLS + "decide.png", (20, 1410, 900, 74), (800, 66))
        pop(img, keys, 1360, 978, (lt - 1.5) / 0.4, yaw=-4, pitch=1, rise=40, radius=16)
        caption(img, "DECIDE", "It finds.\nYou decide.", lt, width=560, sizes=(96, 88), sub="Every find shows the case for it and the case against.")
        brand(img, 1, t); hud(img, ["ANGEL MOUNDS, INDIANA  ·  OPEN USGS LIDAR"], lt + 2)
        return flash(img, max(0, 1 - lt / 0.1) * 0.22)
    if kind == "range":
        img = BG.copy(); step = dur / 4
        kinds = [("Mounds.", "cahokia", "Cahokia, Illinois"), ("Hillforts.", "maiden-castle", "Maiden Castle, England"),
                 ("Enclosures.", "newark", "Newark Great Circle, Ohio"), ("Wrecks.", "thunder-bay", "Thunder Bay, Lake Huron")]
        for i, (word, name, place) in enumerate(kinds):
            p = (lt - i * step) / 0.35
            if p <= 0: continue
            pic = still(STARTS + name + ".jpg", None, (590, 332)).copy(); dr = ImageDraw.Draw(pic); f_ = font(26, "Semibold")
            dr.rounded_rectangle((14, 332 - 56, 14 + f_.getlength(place) + 24, 332 - 14), 12, fill=(14, 11, 9)); dr.text((26, 332 - 52), place, font=f_, fill=TEXT)
            col, row = i % 2, i // 2
            pop(img, pic, 962 + col * 614, 372 + row * 362, p, yaw=(col - 0.5) * -8, pitch=(0.5 - row) * 4, rise=60, radius=18)
        # the four words light one after another, each with its picture
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0)); dr = ImageDraw.Draw(layer); f_ = font(84, "Bold"); y0 = 290
        a = ease(lt / 0.18); spaced(dr, (80 - (1 - a) * 30, y0 - 64), "OPEN DATA", F_KICK, TAN + (int(255 * a),)); dr.rectangle((80, y0 - 20, 80 + int(56 * a), y0 - 16), fill=TAN + (int(255 * a),))
        for i, (word, _, _) in enumerate(kinds):
            p = ease((lt - i * step) / 0.3); col = tuple(int(FAINT[c] * 0.6 + (TEXT[c] - FAINT[c] * 0.6) * p) for c in range(3))
            dr.text((80, y0 + i * 96 + (1 - ease((lt - 0.05 - i * 0.07) / 0.3)) * 30), word, font=f_, fill=col + (int(255 * ease((lt - 0.05 - i * 0.07) / 0.3)),))
        a = ease((lt - 0.5) / 0.4)
        for j, ln in enumerate(["Open lidar on land.", "Open sonar under water."]):
            dr.text((80, y0 + 4 * 96 + 26 + j * 54 + (1 - a) * 20), ln, font=F_SUB, fill=DIM + (int(255 * a),))
        img.alpha_composite(layer); brand(img, 1, t)
        return flash(img, max(0, 1 - lt / 0.1) * 0.22)
    # the end card over the bare ground, still turning
    img = darken(cloud("cloud-end", lt * FPS, 224), 0.58)
    mark(img, W // 2, 140, 400, ((lt + 0.2) % B) / B, shown=lt / 0.7)
    rows = [("Dighouse", F_BIG, TEXT, 236, 0.08), ("Agentic archaeology on your Mac.", font(70, "Semibold"), TAN, 428, 0.45),
            ("Free and open source for macOS. Try it on a site you know.", font(42, "Medium"), DIM, 690, 1.15), ("github.com/chrissotraidis/dighouse", font(58, "Semibold"), TEXT, 768, 1.4)]
    with Over(img) as dr:
        for txt, f, col, y, delay in rows:
            a = ease((lt - delay) / 0.3); tw = f.getlength(txt)
            dr.text((W // 2 - tw / 2, y + (1 - a) * 22), txt, font=f, fill=col + (int(255 * a),))
    f_b = font(40, "Bold"); bt = "PUBLIC BETA  ·  NOW LIVE"; bw = f_b.getlength(bt) + int(f_b.size * 1.9) + 34
    pill(img, bt, W // 2 - bw / 2, 566, (lt - 0.8) / 0.35, f_=f_b, dot=((lt * 0.8) % 1.0))
    corners(img, 0.4)
    img = flash(img, max(0, 1 - lt / 0.25) * 0.7)
    out = (t - (DUR - 1.0)) / 1.0
    return darken(img, min(out, 1)) if out > 0 else img

def index(t):
    for i, (k, a, b) in enumerate(SC):
        if a <= t < b: return i
    return len(SC) - 1
def sweep(new, old, p):
    """A line of light crosses the picture, bringing the next shot with it."""
    x = int(W * ease_io(p)); out = old.copy(); out.paste(new.crop((0, 0, x, H)), (0, 0)); dr = ImageDraw.Draw(out)
    for wdt, a in ((26, 40), (12, 90), (4, 255)): dr.rectangle((x - wdt, 0, x + wdt, H), fill=(255, 236, 200, a))
    return out

args = sys.argv[1:]; rng = None
if args and args[0] == "--range": rng = (float(args[1]), float(args[2])); outfile = args[3]; args = []
only = [float(v) for v in args]
enc = None
if not only:
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                            "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-maxrate", "12M", "-bufsize", "24M", "-pix_fmt", "yuv420p", outfile if rng else BUILD + "video-only.mp4"], stdin=subprocess.PIPE)
SW = 0.22
for n in range(int(round(DUR * FPS))):
    t = n / FPS
    if only and not any(abs(t - o) < 0.5 / FPS for o in only): continue
    if rng and not (rng[0] - 1e-6 <= t < rng[1] - 1e-6): continue
    i = index(t); k, a, b = SC[i]
    img = render(k, t - a, b - a, t)
    if i > 0 and t - a < SW and k in ("score", "slice", "see", "end"):
        pk, pa, pb = SC[i - 1]; img = sweep(img, render(pk, t - pa, pb - pa, t), (t - a) / SW)
    rgb = img.convert("RGB")
    if only: rgb.save(f"{BUILD}still-{t:05.2f}.jpg", quality=88)
    else: enc.stdin.write(rgb.tobytes())
    if n % 90 == 0: print("frame", n, flush=True)
if enc: enc.stdin.close(); enc.wait()
print("done")

