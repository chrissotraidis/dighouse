"""Second opinions asked straight of a model: the whole tile a find is on, in composite and local relief, with the find
ringed and the model asked to say what is in the ring before it judges (FIND_LOOP G3), sent through the OpenCodex router
or Claude Code, a few finds at once. A model that fails is set aside and the
next is asked about the same find. Each record names the model."""

from __future__ import annotations

import base64
import io
import json
import os
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx

from . import ledger
from .project import Project, today, without_coordinates

ROUTER = os.environ.get("DIGHOUSE_ROUTER", "http://127.0.0.1:10100/v1/responses")
QUESTION = ("You are giving an independent second opinion on a possible archaeological feature in lidar of bare ground. "
            "The two pictures show the same tile, north up: a composite view and a local relief view. The feature is inside "
            "the orange ring. Judge only what is inside the ring, not the rest of the tile. First say in a few words what is "
            "inside the ring, then whether it looks built by people. Reply with JSON only: "
            '{"inside_ring": "a few words", "agrees": true if it looks built, false if not, "note": "one sentence"}.')
# The ring and "say what is in it first" (FIND_LOOP G3): rated on 102 views of known ground with Sonnet, a "built" from
# the second model was right 19 times in 27 with the ring, against 18 in 52 with the place given in words, and it found
# as many of the published features (19 of 24, against 18).
RING_M = 25
_client = httpx.Client(timeout=180)


def crops(p: Project, cid: str) -> tuple[list[str], str]:
    """The tile a find is on, as two pictures (composite and local relief) with the find ringed, and the question."""
    from PIL import ImageDraw
    from . import tiles
    loc = p.load("locations")[cid]
    t = p.load("tiles")[loc["tile"]]
    res = p.load("terrains")[t["terrain"]]["res"]
    out = []
    for style in ("composite", "local_relief"):
        img = tiles.tile_image(p, loc["tile"], style).convert("RGB").resize((768, 768))
        rad = 768 * RING_M / (t["window"][3] * res)
        cx, cy = loc.get("x", 0.5) * 768, loc.get("y", 0.5) * 768
        ImageDraw.Draw(img).ellipse([cx - rad, cy - rad, cx + rad, cy + rad], outline=(255, 140, 0), width=4)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        out.append("data:image/png;base64," + base64.b64encode(buf.getvalue()).decode())
    return out, QUESTION


CLAUDE_CODE = "claude-code/"   # second opinions asked through Claude Code on the person's own Claude plan (EASE_LOOP E5)


def claude_binary() -> str:
    """Where Claude Code is: the path the app found, then the usual places."""
    for found in (os.environ.get("DIGHOUSE_CLAUDE"), shutil.which("claude"), str(Path.home() / ".local" / "bin" / "claude"),
                  "/opt/homebrew/bin/claude", "/usr/local/bin/claude"):
        if found and Path(found).is_file():
            return found
    raise RuntimeError("Claude Code is not on this Mac")


def ask_claude_code(model: str, images: list[str], question: str) -> str:
    """The reply of a Claude model run through Claude Code, with no tools, no tool servers, no settings, hooks or memory
    of the person's own and no saved session: it sees the pictures and the question and nothing else."""
    content = [{"type": "text", "text": question}] + [
        {"type": "image", "source": {"type": "base64", "media_type": u[5:u.index(";")], "data": u.split(",", 1)[1]}} for u in images]
    alias = model.removeprefix(CLAUDE_CODE).removeprefix("claude-")
    run = subprocess.run([claude_binary(), "-p", "--safe-mode", "--tools", "", "--strict-mcp-config", "--no-session-persistence",
                          "--model", alias, "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"],
                         input=json.dumps({"type": "user", "message": {"role": "user", "content": content}}) + "\n",
                         capture_output=True, text=True, timeout=240, cwd=tempfile.gettempdir())
    result = None
    for line in run.stdout.splitlines():
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("type") == "result":
            result = d
    if not result or result.get("is_error"):
        why = str((result or {}).get("result") or run.stderr.strip() or run.stdout.strip() or f"Claude Code stopped ({run.returncode})")
        if "authenticat" in why.lower() or "log in" in why.lower() or "/login" in why:
            why = "Claude Code is not signed in: run claude in Terminal and sign in with /login"
        raise RuntimeError(why[:300])
    return str(result.get("result") or "")


def ask(model: str, images: list[str], question: str) -> tuple[bool, str]:
    """One model's verdict on the pictures: (looks built, one sentence). Raises with the provider's words when it fails."""
    if model.startswith(CLAUDE_CODE):
        text = ask_claude_code(model, images, question)
        if not text:
            raise RuntimeError("Claude Code gave no answer")
    else:
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

