"""Every relative link in the repository's Markdown points at a file that exists (OPEN_LOOP O12), so moving a doc
cannot quietly break the README, AGENTS.md or a loop log. Links inside code spans and fenced blocks are not links."""

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).parent.parent
TICK = chr(96)
LINK = re.compile(r'\]\(<?([^)\s>]+)|(?:src|href)="([^"]+)"')
CODE = re.compile("(~~~|" + TICK * 3 + ").*?\\1|" + TICK + "[^" + TICK + "\\n]*" + TICK, re.S)


def test_relative_links_resolve():
    files = subprocess.run(["git", "ls-files", "*.md"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split()
    broken = []
    for name in files:
        f = ROOT / name
        if not f.exists():
            continue
        for m in LINK.finditer(CODE.sub("", f.read_text())):
            target = (m.group(1) or m.group(2)).split("#")[0]
            if target and not re.match(r"^[a-z]+:|/", target) and not (f.parent / target).exists():
                broken.append(f"{name} -> {target}")
    assert files and not broken, "Broken links: " + ", ".join(broken)
