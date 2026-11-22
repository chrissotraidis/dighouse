"""Second opinions asked straight of a model: the whole tile a find is on, in composite and local relief, with where the
find sits given in words (the view the app's agent chat gave, which rated better on known ground than a centred crop:
MOUND_LOOP, after M7), sent through the OpenCodex router, a few finds at once. A model that fails is set aside and the
next is asked about the same find. Each record names the model."""

from __future__ import annotations

import base64
import io
import json
import os
from concurrent.futures import ThreadPoolExecutor

import httpx

from . import ledger, terrain as T
from .project import Project, today, without_coordinates

ROUTER = os.environ.get("DIGHOUSE_ROUTER", "http://127.0.0.1:10100/v1/responses")
QUESTION = ("You are giving an independent second opinion on a possible archaeological feature in lidar of bare ground. "
            "The two pictures show the same tile, north up: a composite view and a local relief view. The feature sits about "
            "{x} percent across and {y} percent down the tile. Look at what is there. Does it look built by people? Reply with "
            "JSON only: {{\"agrees\": true if it looks built, false if not, \"note\": \"one sentence\"}}.")
_client = httpx.Client(timeout=180)


def crops(p: Project, cid: str) -> tuple[list[str], str]:
    """The tile a find is on, as two pictures (composite and local relief), and the question saying where the find sits."""
    from . import tiles
    loc = p.load("locations")[cid]
    out = []
    for style in ("composite", "local_relief"):
        img = tiles.tile_image(p, loc["tile"], style).convert("L").resize((768, 768))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        out.append("data:image/png;base64," + base64.b64encode(buf.getvalue()).decode())
    return out, QUESTION.format(x=int(loc.get("x", 0.5) * 100), y=int(loc.get("y", 0.5) * 100))


def ask(model: str, images: list[str], question: str) -> tuple[bool, str]:
    """One model's verdict on the pictures: (looks built, one sentence). Raises with the provider's words when it fails."""
    content = [{"type": "input_text", "text": question}] + [{"type": "input_image", "image_url": u} for u in images]
    r = _client.post(ROUTER, json={"model": model, "input": [{"role": "user", "content": content}], "stream": False})
    d = r.json()
    text = d.get("output_text") or "".join(c.get("text", "") for o in d.get("output", []) for c in (o.get("content") or [])
                                           if isinstance(c, dict))
    if not text:
        raise RuntimeError(str(d.get("error") or f"HTTP {r.status_code}")[:300])
    v = json.loads(text[text.find("{"): text.rfind("}") + 1])
    return bool(v["agrees"]), str(v.get("note", ""))[:300]


def router_answers() -> bool:
    try:
        return _client.get(ROUTER.rsplit("/responses", 1)[0] + "/models", timeout=3).status_code == 200
    except httpx.HTTPError:
        return False


def second_opinions(project: str, candidates: list[str], models: list[tuple[str, str]], at_once: int = 4) -> dict:
    """Ask for each find in turn down the list of (model id, name) until one answers, at_once finds at a time. A model
    that fails is not asked again in this call. Writes second_look (or second_look_failed) on each record."""
    p = Project(project).check()
    refused: dict[str, str] = {}

    def one(cid: str) -> dict:
        try:
            images, question = crops(p, cid)
        except Exception as exc:
            return {"candidate": cid, "failed": f"no ground on this Mac to show ({str(exc)[:120]})"}
        last = "no second-opinion model is offered"
        for model, name in models:
            if model in refused:
                continue
            try:
                agrees, note = ask(model, images, question)
            except (ValueError, KeyError) as exc:   # an answer that is not the JSON asked for: try the next model for this find
                last = f"{name}: no usable answer ({str(exc)[:120]})"
                continue
            except Exception as exc:
                last = f"{name}: {str(exc)[:200]}"
                refused[model] = str(exc)[:200]
                continue
            meta, _ = ledger.get(p, cid)
            if name.strip().lower() == meta["flagged_by"].strip().lower():
                continue
            ledger.set_check(p, cid, "second_look", {"agrees": agrees, "model": name, "note": without_coordinates(note)})
            return {"candidate": cid, "model": name, "agrees": agrees}
        ledger.set_check(p, cid, "second_look_tried", {"model": "all second-opinion models", "reason": without_coordinates(last)[:300],
                                                       "date": today()})
        return {"candidate": cid, "failed": last}

    with ThreadPoolExecutor(max(1, at_once)) as pool:
        rows = list(pool.map(one, candidates))
    answered = [r for r in rows if "model" in r]
    if answered:
        p.note(f"Second opinions on {len(answered)} finds, asked straight of the model: " + ", ".join(sorted({r['model'] for r in answered})))
    return {"answered": answered, "failed": [r for r in rows if "failed" in r], "models_set_aside": refused}

