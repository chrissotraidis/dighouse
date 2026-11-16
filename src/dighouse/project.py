"""A Dighouse project is a folder. This module owns its layout and its small state files.

Shared, human-readable material lives in Markdown at the top level. Everything that
can reveal where a site is (state, coordinates, downloaded data) lives under
private/ and data/, which the project's .gitignore keeps out of version control.
"""

from __future__ import annotations

import contextlib
import datetime as dt
import fcntl
import json
import os
import shutil
import subprocess
import threading
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
- Every find needs a slice through the laser points, a second opinion from a
  different model, a check of open maps for modern features and a logged
  literature search before its status can move on.
- A person decides before anything is marked as having no match, and a person
  sends any report.
"""


METHODOLOGY_MD = """# Method

How searches in this project are done. The agent reads this before every run and follows it.
Edit it to change how the work is done; the agent adds to "Lessons" when a run teaches something.

## The order of work

1. **Read first.** RESEARCH.md (what has already been looked at, read and decided), this file, and the newest
   run summary in notes/. Do not repeat work RESEARCH.md lists unless you say why, such as a better survey or view.
2. **Get the ground.** Fetch open lidar for the project's area and build the bare ground. Record the survey,
   when it was flown and how dense the ground returns are.
3. **Look at every tile** in at least two views (local relief or sky view, plus hillshade). A tile with too
   little ground data is unreadable, not empty.
4. **Mark a find** only where a shape looks built: straight edges, right angles, regular mounds, platforms, banks.
5. **Check each find:** a slice through the laser points, a check of open maps for modern features,
   and a second opinion from a model by a different maker.
6. **Search what is published** about each find, starting with studies of the same place and survey.
   Log every source as read, could not open, or not relevant.
7. **Suggest a decision** for each find with its reason, then stop: a person decides.
8. **Write the run summary** in notes/, and add a line to notes/INDEX.md.

## Rules

- Never call a site new. Say how many sources were read and that none matched.
- No coordinates in any Markdown. Locations live only under private/.
- Known sites in the area are controls: finding them again shows the method works here.

{record}
## Lessons

Things learned in this project that the next run should know. Add a dated line for each.
"""

RECORD_SECTION = """## How this project keeps its record

The point of the record is that nobody, person or agent, has to redo work to know it was done,
and that someone else can pick the project up and add to it.

- **RESEARCH.md** is the project's memory: the data used, every tile looked at and what it showed,
  every find with its checks and decision, every source and literature search, and what is still to do.
  Dighouse rebuilds it from the files below; nobody edits it by hand.
- **Every look leaves a trace.** Each tile gets a verdict, nothing and natural included. Each source is logged
  as read, could not open, or not relevant, with what it says about this place. A search that finds nothing
  is still a result.
- **One record per find** in candidates/, holding its pictures, measurements, checks and sources.
  A decision carries the person's name, the date and the reason.
- **Each run ends with a summary** in notes/, listed in notes/INDEX.md. The dated notes log every step.
- **Lessons** below are for what this place teaches: surveys that build badly, shapes that often fool the eye.
- **Sharing:** File, then Export Project, gives everything except private/ and data/, so the project can be
  handed to another person, who opens the folder in Dighouse and carries on from RESEARCH.md. The downloads and
  the locations do not travel. The record of what was looked at and read does, so that ground is not looked at twice.
"""
METHODOLOGY_MD = METHODOLOGY_MD.replace("{record}", RECORD_SECTION)

INDEX_MD = """# Notes

The project's history, newest first. Each run summary is its own file; the dated files are the running log.

"""


def _git(root: Path, *args: str) -> bool:
    """Run git in the project folder. A project works without git; this only keeps a history when git is there."""
    if not shutil.which("git"):
        return False
    r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    return r.returncode == 0


def commit(root: Path, message: str) -> bool:
    """Save the project's records, notes and sources in its history. data/ and private/ are never included."""
    if not (root / ".git").exists() and not _git(root, "init", "-q"):
        return False
    _git(root, "add", "-A", "--", ".", ":(exclude)data", ":(exclude)private")
    return _git(root, "-c", "user.name=Dighouse", "-c", "user.email=dighouse@localhost", "commit", "-q", "-m", message)


def projects_home() -> Path:
    """Where new projects go: the folder the app passes in, else ~/Dighouse."""
    return Path(os.environ.get("DIGHOUSE_PROJECTS_HOME") or Path.home() / "Dighouse").expanduser()


def github_home() -> Path:
    """The person's GitHub folder, used only when they ask to work out of it: ~/GitHub, or the folder the app passes in."""
    return Path(os.environ.get("DIGHOUSE_GITHUB_HOME") or Path.home() / "GitHub").expanduser()


def slug(name: str) -> str:
    """A folder name from a project name, the same way the app makes one."""
    return "-".join(part for part in "".join(c if c.isalnum() else "-" for c in name.lower()).split("-") if part) or "project"


def in_icloud(path: Path) -> bool:
    """Whether macOS keeps this folder in iCloud (Desktop and Documents sync, or iCloud Drive). Files there go offline."""
    home = Path.home()
    cloud = [home / "Library" / "Mobile Documents"]
    if (home / "Library" / "Mobile Documents" / "com~apple~CloudDocs" / "Documents").exists():
        cloud += [home / "Documents", home / "Desktop"]
    path = path.resolve()
    return any(path == c or c in path.parents for c in cloud)


def new_folder(project: str | Path) -> Path:
    """A folder for a new project: a bare name goes in the projects folder, and a folder that already holds anything
    gets a number added rather than being reused. A folder in iCloud, or inside an existing repository, is refused."""
    root = Path(project).expanduser()
    if not root.is_absolute():
        root = projects_home() / root
    if in_icloud(root):
        raise ValueError(f"{root} is kept in iCloud, where files go offline and every read waits for a download. "
                         f"Put the project in {projects_home()} or in the GitHub folder instead.")
    inside = next((d for d in root.resolve().parents if (d / ".git").exists()), None)
    if inside:
        raise ValueError(f"{root} is inside the repository {inside}. A project is never written into an existing "
                         "repository; it gets a new folder of its own.")
    base, n = root, 2
    while root.exists() and any(root.iterdir()):
        root = base.with_name(f"{base.name}-{n}")
        n += 1
    return root.resolve()


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
        if not p.path("METHODOLOGY.md").exists():
            p.path("METHODOLOGY.md").write_text(METHODOLOGY_MD)
        if not p.path("notes", "INDEX.md").exists():
            p.path("notes", "INDEX.md").write_text(INDEX_MD)
        p.save("project", {"name": name, "question": question, "bbox": bbox, "created": today()})
        commit(p.root, f"Start the project: {name}")
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
        # Written beside the file and swapped in whole, so a reader never sees half a file.
        tmp = f.with_name(f".{f.name}.{os.getpid()}.{threading.get_ident()}.tmp")
        tmp.write_text(json.dumps(obj, indent=1))
        os.replace(tmp, f)

    @contextlib.contextmanager
    def locked(self, name: str):
        """Hold a lock on a piece of state while it is read and changed. Agents look at tiles in parallel."""
        f = self.path("private", "state", f".{name}.lock")
        f.parent.mkdir(parents=True, exist_ok=True)
        with f.open("a") as fh:
            fcntl.flock(fh, fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(fh, fcntl.LOCK_UN)

    @contextlib.contextmanager
    def change(self, name: str, default=None):
        """Load a piece of state, let the caller change it, and save it, all under its lock."""
        with self.locked(name):
            obj = self.load(name, default)
            yield obj
            self.save(name, obj)

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
        # One line in the index, newest first: the first sentence of the summary.
        index = self.path("notes", "INDEX.md")
        head = index.read_text() if index.exists() else INDEX_MD
        first = next((l.strip("-* ").strip() for l in body.splitlines() if l.strip() and not l.startswith("#")), "")
        line = f"- [{today()} {dt.datetime.now():%H:%M}]({f.name}) {first[:200]}\n"
        parts = head.split("\n\n", 2)
        index.write_text(head.rstrip("\n") + "\n\n" + line if len(parts) < 3 else "\n\n".join(parts[:2]) + "\n\n" + line + parts[2])
        from .record import document  # imported here: record reads the ledger, which imports this module
        document(self, commit_it=False)
        commit(self.root, f"Run summary {today()} {dt.datetime.now():%H:%M}: {first[:60]}")
        return f.name


def today() -> str:
    return dt.date.today().isoformat()


COORDINATES = r"-?\d{1,3}\.\d{4,}"


def without_coordinates(text: str) -> str:
    """Text that will be shared, with anything that looks like a coordinate taken out. Locations stay in private/."""
    import re
    return re.sub(COORDINATES, "(location kept private)", text)


def publish_problems(root: Path) -> list[str]:
    """What stops a project being published: private/ or data/ not kept out of the history, or a shared file that
    looks like it holds a coordinate. Links are ignored, so a DOI such as 10.2307/503404 is not taken for one."""
    import re
    problems = []
    ignored = (root / ".gitignore").read_text().split() if (root / ".gitignore").exists() else []
    problems += [f"{part} is not listed in .gitignore." for part in ("private/", "data/") if part not in ignored]
    listed = subprocess.run(["git", "-C", str(root), "ls-files", "-z"], capture_output=True, text=True)
    if listed.returncode != 0:
        return problems + ["The folder is not a git repository yet."]
    loose = re.compile(r"(?<![\w./-])-?\d{1,3}\.\d{4,}(?![\w/])")
    for name in filter(None, listed.stdout.split("\0")):
        if name.startswith(("private/", "data/")):
            problems.append(f"{name} is in the history, but private/ and data/ must stay on this Mac.")
            continue
        f = root / name
        if not f.is_file() or f.stat().st_size > 2_000_000:
            continue
        try:
            text = f.read_text()
        except (UnicodeDecodeError, OSError):
            continue   # pictures and other binary files
        for i, line in enumerate(text.splitlines(), 1):
            if loose.search(re.sub(r"https?://\S+|doi:\S+", "", line)):
                problems.append(f"{name}, line {i}, looks like it holds a coordinate.")
                break
    return problems


def start_from_chat(p: Project, title: str, why_here: str = "", sources: list[str] | None = None,
                    ruled_out: list[str] | None = None, conversation: str = "") -> str:
    """Make what a chat settled the project's first records, and commit them. Returns the note written."""
    clean = without_coordinates
    title, why_here = clean(title.strip()) or "a chat", clean(why_here.strip())
    sources = [clean(s.strip()) for s in sources or [] if s.strip()]
    ruled_out = [clean(s.strip()) for s in ruled_out or [] if s.strip()]
    question = (p.load("project", {}) or {}).get("question", "")
    name = f"{today()}-started-from-chat.md"

    project_md = p.path("PROJECT.md").read_text()
    if "## Why this area" not in project_md:
        section = (f"## Why this area\n\n{why_here or 'Not written yet.'}\n\n"
                   f"The project started from the chat “{title}” on {today()}. What that chat read and ruled out is in "
                   f"notes/{name}.\n\n")
        at = project_md.find("## Rules for agents")
        project_md = project_md[:at] + section + project_md[at:] if at >= 0 else project_md.rstrip() + "\n\n" + section
        p.path("PROJECT.md").write_text(project_md)

    if sources:
        log = p.path("sources", "read-log.md")
        if not log.exists():
            log.write_text("# Sources read\n\n")
        with log.open("a") as fh:
            fh.writelines(f"- {today()} · before the project, in the chat · read · {s}\n" for s in sources)

    lines = [f"# Started from a chat, {today()}", "",
             f"This project was made from the chat “{title}”, which settled the place and the question below.", "",
             "## Question", "", question or "Not written yet.", "", "## Why this area", "", why_here or "Not written yet.", "",
             "## Ruled out", ""]
    lines += [f"- {s}" for s in ruled_out] or ["- Nothing was ruled out in the chat."]
    lines += ["", "## Read in the chat", ""]
    lines += [f"- {s}" for s in sources] or ["- Nothing was read in the chat."]
    if conversation.strip():
        lines += ["", "## The chat", "", clean(conversation.strip())]
    p.path("notes", name).write_text("\n".join(lines) + "\n")

    index = p.path("notes", "INDEX.md")
    head = index.read_text() if index.exists() else INDEX_MD
    line = f"- [{today()}]({name}) Started from the chat “{title}”: the question, why this area, what was read and ruled out.\n"
    parts = head.split("\n\n", 2)
    index.write_text(head.rstrip("\n") + "\n\n" + line if len(parts) < 3 else "\n\n".join(parts[:2]) + "\n\n" + line + parts[2])
    commit(p.root, f"Started from chat: {title}")
    return name
