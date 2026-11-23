"""Look at every tile in bulk: each tile, in two views, is put straight to a vision model through the model router with
the feature guide, a few at a time, and its verdict recorded under that model's name. The agent then looks closely
only at the tiles called possible or built. The same model the agent would use looks at the same pictures; what goes
is the chat around each look (FIND_LOOP, G1). Where the router does not answer, the agent looks at every tile itself."""

from __future__ import annotations

import base64
import io
import json
import os
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from . import review, tiles
from .project import Project, without_coordinates

MODEL = os.environ.get("DIGHOUSE_SORT_MODEL", "primary/gpt-6.1-terra")
VIEWS = ("composite", "sky_view")
QUESTION = """You are looking at one tile of bare-ground lidar for an archaeological search: {width} by {height} metres, north up.
The first picture is a composite view, the second sky view (dark ditches and hollows, bright banks, no light direction).
Flat dark grey means no ground data.

Decide what the tile shows, using the feature guide below:
- built: a shape people clearly made (a mound, bank, ditch, enclosure, platform, terrace, hollow way)
- possible: something that may be built and needs a closer look
- modern: only roads, buildings, fields, quarries or other modern works
- natural: only natural ground (slopes, drainage, rock, tree throws)
- nothing: flat or featureless ground
A tile with modern works and something that may be old and built is possible or built: give the most interesting
verdict on the tile, in the order built, possible, modern, natural, nothing. When unsure between natural or modern
and possible, say possible: a closer look follows, and a miss here is lost.

Reply with JSON only: {{"verdict": "built|possible|modern|natural|nothing", "note": "one sentence on what you see", "spots": [{{"x": 0.0, "y": 0.0, "what": "a few words"}}]}}
spots are the shapes worth a closer look, as fractions across (x, from the left) and down (y, from the top), each on
the shape itself: one spot for every mound, so a group of 20 mounds is 20 spots; one spot on the bank or ditch of an
enclosure or rampart, where it shows most clearly, never in its middle. None when there are none.

FEATURE GUIDE
{guide}"""


def _picture(p: Project, tile_id: str, style: str) -> str:
    from PIL import Image
    img = Image.open(tiles.cached_tile(p, tile_id, style)).convert("L").resize((768, 768))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def _ask(model: str, images: list[str], question: str) -> dict:
    content = [{"type": "input_text", "text": question}] + [{"type": "input_image", "image_url": u} for u in images]
    r = review._client.post(review.ROUTER, json={"model": model, "input": [{"role": "user", "content": content}], "stream": False})
    d = r.json()
    text = d.get("output_text") or "".join(c.get("text", "") for o in d.get("output", []) for c in (o.get("content") or [])
                                           if isinstance(c, dict))
    if not text:
        raise RuntimeError(str(d.get("error") or f"HTTP {r.status_code}")[:300])
    v = json.loads(text[text.find("{"): text.rfind("}") + 1])
    if v.get("verdict") not in tiles.VERDICTS:
        raise RuntimeError(f"no verdict in the answer: {text[:120]}")
    spots = [s for s in (v.get("spots") or []) if isinstance(s, dict) and 0 <= float(s.get("x", -1)) <= 1 and 0 <= float(s.get("y", -1)) <= 1]
    return {"verdict": v["verdict"], "note": str(v.get("note", ""))[:300], "spots": spots[:40]}


MOUNDS = """The picture is a tile of bare-ground lidar in sky view (bright raised forms, dark hollows). Each numbered orange
ring is a round rise the ground model measured; below the tile, each one up close in hillshade, with its size.
Most measured rises are rocks, tree throws, knolls or field heaps. Which of the numbered rises look like mounds people
built (burial mounds, cairns, house mounds)? Reply with JSON only: {{"mounds": [numbers]}}, empty when none do.
{guide}"""


def _measured_mounds(p: Project, model: str, tid: str, guide: str) -> list[dict]:
    """The agent's step "look at each numbered spot and decide", put to the model straight: which measured rises on a
    tile look built. Positions come from the measurement, so they sit on the rise itself."""
    spots, img = tiles.mound_spots(p, tid)
    if not spots:
        return []
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="PNG")
    content = [{"type": "input_text", "text": MOUNDS.format(guide=guide)},
               {"type": "input_image", "image_url": "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()}]
    r = review._client.post(review.ROUTER, json={"model": model, "input": [{"role": "user", "content": content}], "stream": False})
    d = r.json()
    text = d.get("output_text") or "".join(c.get("text", "") for o in d.get("output", []) for c in (o.get("content") or [])
                                           if isinstance(c, dict))
    try:
        picked = {int(n) for n in json.loads(text[text.find("{"): text.rfind("}") + 1]).get("mounds", [])}
    except (ValueError, TypeError):
        return []
    return [{"x": sp["x"], "y": sp["y"], "what": f"round rise {sp['diameter_m']:.0f} m across, measured and judged a mound"}
            for sp in spots if sp["n"] in picked]


def sort_tiles(project: str, model: str = "", at_once: int = 8, limit: int = 0) -> dict:
    """Ask the model about every readable tile nobody has looked at, record each verdict, and return the shortlist: the
    tiles called possible or built, and any other tile where the model pointed at a shape, with those spots. A tile whose request fails stays unlooked."""
    p = Project(Path(project)).check()
    model = model or MODEL
    guide = (Path(__file__).parent / "FEATURES.md").read_text()
    all_tiles = p.load("tiles", {}) or {}
    terrains = p.load("terrains", {}) or {}
    todo = [tid for tid, t in all_tiles.items() if t["status"] == "unscreened"]
    if limit:
        todo = todo[:limit]
    start = time.time()

    def one(tid: str):
        t = all_tiles[tid]
        res = terrains[t["terrain"]]["res"]
        q = QUESTION.format(width=round(t["window"][3] * res), height=round(t["window"][2] * res), guide=guide)
        try:
            images = [_picture(p, tid, s) for s in VIEWS]
            v = _ask(model, images, q)
            # A tile set aside is looked at once more: the same model can answer differently, and a miss here is lost.
            if v["verdict"] not in ("possible", "built") and not v["spots"]:
                again = _ask(model, images, q)
                if again["verdict"] in ("possible", "built") or again["spots"]:
                    v = again
            if v["verdict"] in ("possible", "built") or v["spots"]:
                v["spots"] = v["spots"] + _measured_mounds(p, model, tid, guide)
            return tid, v, None
        except Exception as exc:  # one tile failing should not stop the rest
            return tid, None, str(exc)[:200]

    with ThreadPoolExecutor(at_once) as pool:
        results = list(pool.map(one, todo))
    looked, failed, shortlist = 0, [], []
    for tid, v, problem in results:
        if v is None:
            failed.append({"tile": tid, "problem": without_coordinates(problem or "")})
            continue
        note = without_coordinates(v["note"])
        tiles.record_verdict(p, tid, v["verdict"], note, f"{model} (sorted in bulk)")
        looked += 1
        # The closer look takes possible and built tiles, and any tile where the model pointed at a shape.
        if v["verdict"] in ("possible", "built") or (v["spots"] and v["verdict"] != "nothing"):
            shortlist.append({"tile": tid, "verdict": v["verdict"], "note": note,
                              "spots": [{"x": round(float(s["x"]), 3), "y": round(float(s["y"]), 3), "what": str(s.get("what", ""))[:60]} for s in v["spots"]]})
    return {"model": model, "looked_at": looked, "failed": failed, "seconds": round(time.time() - start, 1),
            "shortlist": shortlist, "verdicts": tiles.coverage(p).get("verdicts", {})}

SEEN_BY = "seen in bulk by {model}"
NEAR_M = 15.0   # tiles overlap by 25 m, so one shape can be pointed at from two tiles


def mark_spots(project: str, shortlist: list[dict], model: str = "") -> dict:
    """Open a find for each shape the bulk look pointed at on the shortlisted tiles, unless a find already sits within
    15 m. Each is marked as seen in bulk by the model, so a person knows where it came from; then it is sliced,
    checked and given a suggestion like any find."""
    from . import ledger
    p = Project(Path(project)).check()
    model = model or MODEL
    places = [(v["lon"], v["lat"]) for v in (p.load("locations", {}) or {}).values()]
    made = []
    for item in shortlist:
        for s in item.get("spots", []):
            lonlat = tiles.tile_lonlat(p, item["tile"], s["x"], s["y"])
            if any(ledger.distance_m(lonlat, q) < NEAR_M for q in places):
                continue
            what = (s.get("what") or "a shape").strip().rstrip(".")
            note = f"Seen in bulk: {what}. The tile: {item.get('note', '')}"
            meta = ledger.create(p, f"Seen in bulk: {what[:50]}", item["tile"], lonlat, note, SEEN_BY.format(model=model),
                                 at=(s["x"], s["y"]))
            tiles.tile_image(p, item["tile"], "composite", mark=(s["x"], s["y"])).save(p.path("candidates", "img", f"{meta['id']}-relief.png"))
            places.append(lonlat)
            made.append(meta["id"])
    p.note(f"Opened {len(made)} finds from the bulk look" + (f": {', '.join(made)}" if made else ""))
    return {"added": made, "count": len(made)}
