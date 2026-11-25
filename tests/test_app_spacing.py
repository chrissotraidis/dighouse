"""The app keeps to one spacing scale (EASE_LOOP E2): every padding and stack spacing is one of a few steps, so pages
line up with each other. A padding that lines content up under an icon is marked "// aligns" and may differ."""

import re
from pathlib import Path

SCALE = {0, 1, 2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 32, 48}
PATTERN = re.compile(r"(?:padding\((?:\.[a-zA-Z]+, )?|spacing: )(\d+)(?![\d.])")


def test_spacing_is_on_the_scale():
    off = []
    for f in sorted((Path(__file__).parent.parent / "app" / "Sources" / "Dighouse").glob("*.swift")):
        for n, line in enumerate(f.read_text().splitlines(), 1):
            if "// aligns" in line:
                continue
            off += [f"{f.name}:{n} {v}" for v in PATTERN.findall(line) if int(v) not in SCALE]
    assert not off, "Spacing off the scale " + str(sorted(SCALE)) + ": " + ", ".join(off)
