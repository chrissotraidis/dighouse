"""Give every open find in the given projects a second opinion, the way the app does: Claude Sonnet 5.5, then GLM-5.3,
then Kimi K3, each shown a 120 m crop in composite and local relief, written through the second_look tool.

Run with: uv run python scripts/second_opinions.py PROJECT [PROJECT ...]
"""
from __future__ import annotations

import base64, io, json, sys
from pathlib import Path

import httpx, pyproj

from dighouse import ledger, server, terrain as T
from dighouse.project import Project

ROUTER = "http://127.0.0.1:10100/v1/responses"
ORDER = [("anthropic/claude-sonnet-5-5", "Cl · Sonnet 5.5"), ("opencode-go-secondary/glm-5.3", "G2 · GLM 5.3"), ("opencode-go/kimi-k3", "G1 · Kimi K3")]
Q = ("You are giving an independent second opinion on a possible archaeological feature in lidar of bare ground. "
     "The two pictures show the same 120 m square, north up: a composite view and a local relief view. Look only at the "
     "feature at the very centre. Does it look built by people? Reply with JSON only: "
     "{\"agrees\": true if it looks built, false if not, \"note\": \"one sentence\"}.")


def png(img) -> str:
    buf = io.BytesIO(); img.convert("L").resize((384, 384)).save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def crops(p: Project, cid: str):
    loc = p.load("locations")[cid]
    tid = p.load("tiles")[loc["tile"]]["terrain"]
    meta = p.load("terrains")[tid]
    dtm, gap, out = T.load_terrain(p.path(meta["file"]))
    x, y = pyproj.Transformer.from_crs(4326, meta["epsg"], always_xy=True).transform(loc["lon"], loc["lat"])
    res, (x0, _, _, y1) = meta["res"], meta["box"]
    r, c, h = int((y1 - y) / res), int((x - x0) / res), int(60 / meta["res"])
    win = (slice(max(r - h, 0), r + h), slice(max(c - h, 0), c + h))
    return [png(T.render(dtm[win], gap[win], out[win], res, s)) for s in ("composite", "local_relief")]


def ask(model: str, images: list[str]):
    content = [{"type": "input_text", "text": Q}] + [{"type": "input_image", "image_url": u} for u in images]
    r = httpx.post(ROUTER, json={"model": model, "input": [{"role": "user", "content": content}], "stream": False}, timeout=180)
    d = r.json()
    text = d.get("output_text") or "".join(c.get("text", "") for o in d.get("output", []) for c in (o.get("content") or []) if isinstance(c, dict))
    if not text:
        raise RuntimeError(str(d.get("error"))[:200])
    v = json.loads(text[text.find("{"): text.rfind("}") + 1])
    return bool(v["agrees"]), str(v.get("note", ""))[:300]


for folder in sys.argv[1:]:
    p = Project(folder).check()
    for m in ledger.everything(p):
        if m["status"] not in ("flagged", "ground_confirmed") or m["checks"].get("second_look"):
            continue
        try:
            images = crops(p, m["id"])
        except Exception as exc:
            print(f"{Path(folder).name} {m['id']}: no ground here ({exc})"); continue
        for model, name in ORDER:
            try:
                agrees, note = ask(model, images)
                server.second_look(folder, m["id"], agrees, name, note)
                print(f"{Path(folder).name} {m['id']} [{(m.get('suggestion') or {}).get('status')}] {name}: {'built' if agrees else 'not built'}. {note[:110]}")
                break
            except Exception as exc:
                last = f"{name}: {exc}"
        else:
            server.second_look_failed(folder, m["id"], "all second-opinion models", last)
            print(f"{Path(folder).name} {m['id']}: no model answered ({last[:100]})")

