"""What is this? A quick look at one place: a small square of ground in two renderings, and what open records hold nearby.

It works in a scratch folder in the cache, so no project is created unless the person asks for one. Nothing it returns
holds coordinates except the box, which the app needs to start a project there and keeps private.
"""

from __future__ import annotations

import hashlib
import json
import math
import time

from PIL import Image, ImageDraw, ImageFont

from . import answers, discover, national, sources
from . import terrain as T
from .project import Project


def _box(lon: float, lat: float, half_m: float) -> list[float]:
    dlat = half_m / 110_540
    dlon = half_m / (111_320 * max(math.cos(math.radians(lat)), 0.2))
    return [round(lon - dlon, 6), round(lat - dlat, 6), round(lon + dlon, 6), round(lat + dlat, 6)]


def _choose(found: list[dict]) -> dict | None:
    """A national ground model first (ready-made and quick), then USGS, then a survey on OpenTopography."""
    rows = [d for d in found if d.get("id")]
    for test in (lambda d: d.get("ready_made_ground_model"), lambda d: d["id"].startswith("usgs:"), lambda d: d["id"].startswith("ot:")):
        pick = [d for d in rows if test(d)]
        if pick:
            return pick[0]
    return None


def _panel(left: Image.Image, right: Image.Image, labels=("Sky view", "Hillshade")) -> Image.Image:
    side = 640
    out = Image.new("RGB", (side * 2 + 12, side), (24, 20, 17))
    for i, im in enumerate((left, right)):
        im = im.convert("RGB")
        scale = side / max(im.size)  # a 1 m ground model is only a few hundred pixels across, so draw it larger too
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
        x = i * (side + 12) + (side - im.width) // 2
        out.paste(im, (x, (side - im.height) // 2))
        d = ImageDraw.Draw(out)
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
        except OSError:
            font = ImageFont.load_default()
        d.rounded_rectangle([x + 10, 10, x + 140, 44], radius=8, fill=(20, 16, 14))
        d.text((x + 20, 14), labels[i], fill=(235, 225, 210), font=font)
    return out


def look(place: str = "", lon: float = 0.0, lat: float = 0.0, size_m: float = 400.0) -> tuple[dict, str | None]:
    """Fetch about size_m of ground around a place or a point, render it, and list what open records hold near it."""
    from . import server  # the fetch tool keeps progress, cancelling and caching in one place
    started = time.time()
    name = place.strip()
    if not (lon or lat):
        if not name:
            raise ValueError("Give a place name, or a point as lon and lat.")
        hits = discover.find_place(name)
        if not hits:
            raise ValueError(f"No place called {name!r} was found. Add the region or country.")
        lon, lat, name = hits[0]["lon"], hits[0]["lat"], hits[0].get("name") or name
    size_m = max(150.0, min(size_m, 800.0))
    box = _box(lon, lat, size_m / 2)
    answers.guard_box(box)
    found = sources.find_data(box)
    data = _choose(found)
    if not data:
        return ({"place": name, "found": False,
                 "why": "No open lidar covers this spot. Dighouse reads the United States, surveys on OpenTopography, and national "
                        f"ground models for {national.countries()}."}, None)
    tag = hashlib.sha1(json.dumps([data["id"], box, 1.0]).encode()).hexdigest()[:12]
    root = sources.cache_dir() / "quicklook" / tag
    if not (root / "PROJECT.md").exists():
        Project.create(root, f"Quick look: {name or 'a point'}", "What is this?", box)
    p = Project(root)
    terrains = p.load("terrains", {}) or {}
    if not terrains:
        server.fetch_terrain(str(root), data["id"], *box, resolution_m=1.0)  # 1 m is enough for a first look, and quicker
        terrains = p.load("terrains", {}) or {}
    meta = next(iter(terrains.values()))
    dtm, gap, outside = T.load_terrain(p.path(meta["file"]))
    picture = _panel(T.render(dtm, gap, outside, meta["res"], "sky_view"), T.render(dtm, gap, outside, meta["res"], "hillshade"))
    f = p.path("data", "tiles", "quick-look.png")
    f.parent.mkdir(parents=True, exist_ok=True)
    picture.save(f)
    near = discover.known_sites(_box(lon, lat, 1000))
    density = meta.get("ground_points_per_m2")
    return ({
        "place": name or "the point given",
        "found": True,
        "data": {"dataset": data["id"], "source": data.get("source"), "area_km2": meta.get("area_km2"),
                 "ground_points_per_m2": density if isinstance(density, (int, float)) else None,
                 "share_without_ground_data": meta.get("share_without_ground_data")},
        "on_record_within_1km": near.get("nearest", [])[:12],
        "on_record_count": near.get("count", 0),
        "record_sources_that_answered": near.get("sources_that_answered", []),
        "record_sources_that_did_not_answer": near.get("sources_that_did_not_answer", []),
        "box": box,
        "picture": str(f),
        "seconds": round(time.time() - started),
        "next": "Describe in plain words what the shapes in the two pictures probably are, say what is on record nearby and from "
                "which sources, and say nothing is new. Offer to search it properly as a project.",
    }, str(f))

