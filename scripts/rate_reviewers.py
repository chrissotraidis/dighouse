"""Rate second-opinion models on ground whose truth is known, from the blind tests on this Mac.

Run with: uv run python scripts/rate_reviewers.py [model ...]
For each scored blind test it takes published features from the answer key (built), measured rises the key does not list,
and plain ground away from both (not built), renders a 120 m crop in composite and local relief, and asks each model,
through the OpenCodex router, whether what is at the centre was built by people. Writes a table to stdout and the
answers to private/reviewer-ratings.json in each test. No coordinates are printed.
"""

from __future__ import annotations

import base64
import io
import json
import math
import random
import sys
import concurrent.futures as cf
from pathlib import Path

import httpx
import numpy as np
import pyproj

from dighouse import answers, mounds, terrain as T
from dighouse.project import Project

ROUTER = "http://127.0.0.1:10100/v1/responses"
TILE = "--tile" in sys.argv   # rate the view the app's agent-chat path gave: a whole 250 m tile and where the find sits in it
MODELS = [a for a in sys.argv[1:] if not a.startswith("--")] or ["anthropic/claude-sonnet-5-5", "opencode-go-secondary/glm-5.3", "opencode-go/kimi-k3"]
TILE_QUESTION = ("You are giving an independent second opinion on a possible archaeological feature in lidar of bare ground. "
                 "The two pictures show the same 250 m tile, north up: a composite view and a local relief view. The feature sits "
                 "about {x} percent across and {y} percent down the tile. Was it built by people (a mound, bank, ditch, platform), "
                 "or is it natural ground or nothing? Reply with JSON only: {{\"built\": true or false, \"why\": \"one short sentence\"}}.")
TILE_HALF_M = 125
QUESTION = ("You are giving an independent second opinion on a possible archaeological feature in lidar of bare ground. "
            "The two pictures show the same 120 m square, north up: a composite view and a local relief view. "
            "Look only at the feature at the very centre. Was it built by people (a mound, bank, ditch, platform), "
            "or is it natural ground or nothing? Reply with JSON only: {\"built\": true or false, \"why\": \"one short sentence\"}.")
HALF_M = 60
random.seed(int(__import__("os").environ.get("RATE_SEED", "7")))


def png(img) -> str:
    buf = io.BytesIO()
    img.convert("L").resize((384, 384)).save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def items(folder: Path, per_kind: int) -> list[dict]:
    p = Project(folder)
    test = p.load("test") or {}
    k = answers.key(test["key"])
    meta = max(p.load("terrains").values(), key=lambda m: m.get("area_km2") or 0)
    dtm, gap, out = T.load_terrain(p.path(meta["file"]))
    res = meta["res"]
    x0, _, _, y1 = meta["box"]
    fwd = pyproj.Transformer.from_crs(4326, meta["epsg"], always_xy=True)
    inv = pyproj.Transformer.from_crs(meta["epsg"], 4326, always_xy=True)
    h = int(HALF_M / res)

    def rc(lon, lat):
        x, y = fwd.transform(lon, lat)
        return int((y1 - y) / res), int((x - x0) / res)

    def inside(r, c):
        return h <= r < dtm.shape[0] - h and h <= c < dtm.shape[1] - h and not out[r, c] and gap[r, c] <= T.GAP_M

    feats = [f for f in k["features"] if f["kind"] == "point" and f["expect"]]
    pos = [(f, rc(f["lon"], f["lat"])) for f in feats]
    pos = [(f, (r, c)) for f, (r, c) in pos if inside(r, c)]
    near = lambda r, c, m: any(math.hypot(r - rr, c - cc) * res < m for _, (rr, cc) in pos)
    rises = [b for b in mounds.bumps(dtm, res, min_h=0.25, valid=~((gap > T.GAP_M) | out))
             if inside(b["row"], b["col"]) and not near(b["row"], b["col"], 25)]
    plain = []
    for _ in range(4000):
        r, c = random.randrange(h, dtm.shape[0] - h), random.randrange(h, dtm.shape[1] - h)
        if inside(r, c) and not near(r, c, 40) and all(math.hypot(r - b["row"], c - b["col"]) * res > 15 for b in rises):
            plain.append((r, c))
        if len(plain) >= per_kind:
            break
    chosen = ([("published feature", True, rc_) for _, rc_ in random.sample(pos, min(per_kind, len(pos)))]
              + [("measured rise not in the key", False, (b["row"], b["col"])) for b in random.sample(rises, min(per_kind, len(rises)))]
              + [("plain ground", False, rc_) for rc_ in plain])
    out_items = []
    for kind, truth, (r, c) in chosen:
        win = (slice(r - h, r + h), slice(c - h, c + h))
        z, g, o = dtm[win], gap[win], out[win]
        item = {"site": k["name"], "kind": kind, "built": truth,
                "images": [png(T.render(z, g, o, res, "composite")), png(T.render(z, g, o, res, "local_relief"))]}
        if TILE:
            # The same spot as the app's chat saw it: somewhere inside a 250 m tile, with its place given in words.
            t = int(TILE_HALF_M * 2 / res)
            fx, fy = random.uniform(0.15, 0.85), random.uniform(0.15, 0.85)
            r0 = min(max(r - int(fy * t), 0), dtm.shape[0] - t)
            c0 = min(max(c - int(fx * t), 0), dtm.shape[1] - t)
            tw = (slice(r0, r0 + t), slice(c0, c0 + t))
            def tile_png(style):
                buf = io.BytesIO(); T.render(dtm[tw], gap[tw], out[tw], res, style).convert("L").resize((768, 768)).save(buf, format="PNG")
                return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
            item["images"] = [tile_png("composite"), tile_png("local_relief")]
            item["question"] = TILE_QUESTION.format(x=int((c - c0) / t * 100), y=int((r - r0) / t * 100))
        out_items.append(item)
    return out_items


def ask(model: str, item: dict) -> dict:
    content = [{"type": "input_text", "text": item.get("question") or QUESTION}] + [{"type": "input_image", "image_url": u} for u in item["images"]]
    try:
        r = httpx.post(ROUTER, json={"model": model, "input": [{"role": "user", "content": content}], "stream": False}, timeout=180)
        d = r.json()
        text = d.get("output_text") or "".join(c.get("text", "") for o in d.get("output", []) for c in (o.get("content") or []) if isinstance(c, dict))
        if not text:
            return {"answer": None, "error": str(d.get("error"))[:200]}
        s = text[text.find("{"): text.rfind("}") + 1]
        v = json.loads(s)
        return {"answer": bool(v.get("built")), "why": str(v.get("why", ""))[:200]}
    except Exception as exc:
        return {"answer": None, "error": str(exc)[:200]}


def main():
    homes = [Path.home() / "Dighouse"]
    tests = [d for h in homes for d in h.rglob("private/state/score.json")]
    folders, seen = [], set()
    for s in tests:
        folder = s.parent.parent.parent
        key = (Project(folder).load("test") or {}).get("key")
        if key and key not in seen and key in ("borre", "mound-city", "angel-mounds", "cahokia"):
            seen.add(key)
            folders.append(folder)
    all_items = [it for f in folders for it in items(f, 10)]
    print(f"{len(all_items)} crops from {', '.join(sorted({i['site'] for i in all_items}))}")
    results = {m: [] for m in MODELS}
    with cf.ThreadPoolExecutor(6) as pool:
        jobs = {pool.submit(ask, m, it): (m, it) for m in MODELS for it in all_items}
        for job in cf.as_completed(jobs):
            m, it = jobs[job]
            results[m].append({**{k: v for k, v in it.items() if k not in ("images", "question")}, **job.result()})
    print(f"{'model':36s} {'answered':>8s} {'built found':>12s} {'rises refused':>14s} {'plain refused':>14s} {'overall':>8s}")
    for m, rows in results.items():
        got = [r for r in rows if r["answer"] is not None]
        def rate(kind):
            sub = [r for r in got if r["kind"] == kind]
            ok = sum(r["answer"] == r["built"] for r in sub)
            return f"{ok}/{len(sub)}"
        overall = sum(r["answer"] == r["built"] for r in got)
        yes = [r for r in got if r["answer"]]; no = [r for r in got if not r["answer"]]
        print(f"{m:36s} {len(got):>4d}/{len(rows):<3d} {rate('published feature'):>12s} {rate('measured rise not in the key'):>14s} {rate('plain ground'):>14s} {overall:>4d}/{len(got)}"
              f"  yes right {sum(r['built'] for r in yes)}/{len(yes)}, no right {sum(not r['built'] for r in no)}/{len(no)}")
        errs = {r.get('error') for r in rows if r['answer'] is None}
        if errs:
            print("    errors:", list(errs)[:2])
    Path(Path.home() / "Dighouse" / (".reviewer-ratings-tile.json" if TILE else ".reviewer-ratings.json")).write_text(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()

