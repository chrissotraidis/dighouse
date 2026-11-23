"""Free the disk space downloaded points take twice. Each project's points become a hard link to the cache's copy
when the two hold the same points, then the cache keeps at most DIGHOUSE_POINTS_CACHE_GB (10) of points that no
project holds. Nothing a project holds is removed. Without --apply it only says what it would do.

    uv run python scripts/tidy.py [folder ...] [--apply]

With no folders it tidies every project in the app's list.
"""

import os
import sys
from pathlib import Path

import numpy as np

from dighouse import sources
from dighouse.funnel import app_projects
from dighouse.project import Project

apply = "--apply" in sys.argv
args = [a for a in sys.argv[1:] if a != "--apply"]
folders = [f for f in (args or app_projects()) if (Path(f) / "PROJECT.md").exists()]


def same(a: Path, b: Path) -> bool:
    if a.stat().st_size != b.stat().st_size:
        return False
    with np.load(a) as x, np.load(b) as y:
        return all(np.array_equal(x[k], y[k]) for k in ("x", "y", "z", "cls", "epsg"))


by_size: dict[int, list[Path]] = {}
for f in (sources.cache_dir() / "points").glob("*.npz"):
    by_size.setdefault(f.stat().st_size, []).append(f)

linked = saved = 0
for folder in folders:
    p = Project(folder)
    for tid, meta in p.load("terrains", {}).items():
        if not meta.get("points") or not meta.get("lonlat") or meta.get("dataset", "").split(":")[0] not in ("usgs", "ot"):
            continue
        dest = p.path(meta["points"])
        src = sources.kept_points(meta["dataset"], meta["lonlat"], 0.35 * max(1.0, meta["res"] / 0.5) ** 2)
        if not dest.exists() or dest.stat().st_nlink > 1:
            continue
        if not (src.exists() and same(src, dest)):  # older projects fetched at another spacing: match by content
            src = next((f for f in by_size.get(dest.stat().st_size, []) if same(f, dest)), None)
            if src is None:
                continue
        linked += 1
        saved += dest.stat().st_size
        if apply:
            tmp = dest.with_name(dest.name + ".link")
            tmp.unlink(missing_ok=True)
            os.link(src, tmp)
            os.replace(tmp, dest)

print(f"{'Linked' if apply else 'Would link'} {linked} project point files to the cache's copy, {saved / 1e9:.1f} GB freed.")
if apply:
    print("Cache:", sources.trim_points_cache())
else:
    loose = [f for f in (sources.cache_dir() / "points").glob("*.npz") if f.stat().st_nlink == 1]
    print(f"Cached points no project holds: {sum(f.stat().st_size for f in loose) / 1e9:.1f} GB "
          f"(after linking, fewer); the cache keeps {sources.POINTS_CACHE_GB:g} GB of them.")
