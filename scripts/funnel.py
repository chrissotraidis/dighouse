"""Print where finds stop across projects: the folders given, or every project in the app's list.

    uv run python scripts/funnel.py [folder ...] [--json]
"""

import json
import sys
from pathlib import Path

from dighouse.funnel import app_projects, funnel, totals


args = [a for a in sys.argv[1:] if a != "--json"]
folders = [f for f in (args or app_projects()) if (Path(f) / "PROJECT.md").exists()]
rows = [funnel(f) for f in folders]
total = totals(rows)
if "--json" in sys.argv:
    print(json.dumps({"projects": rows, "total": total}, indent=1))
    sys.exit()
cols = ["km2_fetched", "km2_looked_at", "finds", "measured_rises", "to_a_person", "decided", "answered"]
print("project".ljust(34) + "".join(c[:12].rjust(13) for c in cols))
for r in rows:
    if not r["blind_test"]:
        print(r["project"][:33].ljust(34) + "".join(str(r[c]).rjust(13) for c in cols))
print("all " + str(total["projects"]) + " projects".ljust(30) + "".join(str(total[c]).rjust(13) for c in cols))
print(f"finds per km2 looked at: {total['finds_per_km2_looked_at']}; blind tests left out: {sum(r['blind_test'] for r in rows)}")
