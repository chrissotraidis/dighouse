"""A Dighouse project is a folder. This module owns its layout and its small state files.

Shared, human-readable material lives in Markdown at the top level. Everything that
can reveal where a site is (state, coordinates, downloaded data) lives under
private/ and data/, which the project's .gitignore keeps out of version control.
"""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

DIRS = (
    "candidates/img",
    "notes",
    "sources",
    "reports",
    "data/points",
    "data/terrain",
    "data/tiles",
    "private/state",
)

PROJECT_MD = """# {name}

## Question

{question}

## Rules for agents

- Never call a site new. Say how many sources were read and that none matched.
- Never write coordinates in these Markdown files or in anything pushed elsewhere.
  Locations live only under private/.
- A tile with too little ground data is unreadable, not empty.
- Every flag needs a section, a second look by a different model, a check for
  modern features and a logged literature search before its status can move on.
- A person decides before anything is marked as having no match, and a person
  sends any report.
"""


class Project:
    def __init__(self, root: str | Path):
        self.root = Path(root).expanduser().resolve()

    @classmethod
    def create(cls, root: str | Path, name: str, question: str, bbox: list[float]) -> Project:
        p = cls(root)
        for d in DIRS:
            (p.root / d).mkdir(parents=True, exist_ok=True)
        if not p.path("PROJECT.md").exists():
            p.path("PROJECT.md").write_text(PROJECT_MD.format(name=name, question=question))
        if not p.path(".gitignore").exists():
            p.path(".gitignore").write_text("data/\nprivate/\n")
        p.save("project", {"name": name, "question": question, "bbox": bbox, "created": today()})
        return p

    def check(self) -> Project:
        if not self.path("PROJECT.md").exists():
            raise ValueError(f"{self.root} is not a Dighouse project. Call init_project first.")
        return self

    def path(self, *parts: str) -> Path:
        return self.root.joinpath(*parts)

    def rel(self, path: Path) -> str:
        return str(Path(path).resolve().relative_to(self.root))

    def load(self, name: str, default=None):
        f = self.path("private", "state", f"{name}.json")
        return json.loads(f.read_text()) if f.exists() else default

    def save(self, name: str, obj) -> None:
        f = self.path("private", "state", f"{name}.json")
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps(obj, indent=1))

    def note(self, text: str) -> None:
        f = self.path("notes", f"{today()}.md")
        if not f.exists():
            f.write_text(f"# Notes for {today()}\n\n")
        with f.open("a") as fh:
            fh.write(f"- {dt.datetime.now():%H:%M} {text}\n")


    def summary(self, text: str) -> str:
        """Write the end-of-run summary as its own file in notes/, beside the dated log."""
        f = self.path("notes", f"{today()}-run-{dt.datetime.now():%H%M}.md")
        body = text.strip()
        if body.startswith("# "):  # the agent often adds its own title; keep one
            body = body.split("\n", 1)[1].strip() if "\n" in body else ""
        f.write_text(f"# Run summary, {today()} {dt.datetime.now():%H:%M}\n\n{body}\n")
        self.note(f"Wrote the run summary {f.name}")
        return f.name


def today() -> str:
    return dt.date.today().isoformat()
