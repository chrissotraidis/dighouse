"""The Dighouse tool server. Every tool takes the absolute path of a project folder."""

from __future__ import annotations

import functools
import hashlib
import json
import re
import time

import httpx
import numpy as np
from pathlib import Path

from mcp.server.mcpserver import Image, MCPServer
from mcp.server.mcpserver.exceptions import ToolError

from . import checks, discover, ledger, national, record, report, section, sources, tiles
from . import terrain as T
from .project import Project

mcp = MCPServer(
    "dighouse",
    instructions=(
        "Archaeology tools for searching open lidar. To choose where to look, use find_place, open_surveys and "
        "survey_area; they need no project. Everything else works inside one project folder. "
        "Order of work: init_project, find_data, fetch_terrain, make_tiles, then for each tile view_tile and "
        "record_verdict; flag_candidate for anything that looks built; then cut_section, second_look, "
        "check_modern, search_literature and log_source for every flag; set_status last. End a run with "
        "write_summary, and with write_report when asked to report back. "
        "Never call a site new and never write coordinates into Markdown or messages."
    ),
)

MAX_KM2 = 6.0


def tool(fn):
    """Register a tool. Over MCP a failure reaches the agent as a plain sentence it can act on."""

    @functools.wraps(fn)
    def safe(*args, **kwargs):
        try:
            return fn(*args, **kwargs)
        except KeyError as exc:
            raise ToolError(f"Unknown id {exc}. Check the terrain, tile or candidate id.") from exc
        except httpx.HTTPError as exc:
            raise ToolError(plain_network_error(exc)) from exc
        except Exception as exc:
            raise ToolError(str(exc)) from exc

    mcp.tool()(safe)
    return fn


def plain_network_error(exc: httpx.HTTPError) -> str:
    """Say which service failed and what the person can do, in place of the library's message."""
    try:
        host = exc.request.url.host
    except RuntimeError:
        host = "an open data service"
    if isinstance(exc, httpx.TimeoutException):
        return f"{host} did not answer in time. It may be busy or down; try again in a few minutes."
    if isinstance(exc, httpx.ConnectError):
        return f"Could not reach {host}. Check that this Mac is online; if it is, the service may be down, so try again later."
    if isinstance(exc, httpx.HTTPStatusError):
        code = exc.response.status_code
        if code == 429:
            return f"{host} asked for fewer requests (429). Wait a few minutes, then try again."
        if code in (401, 403):
            return f"{host} refused the request ({code}). The page may need a sign-in; open it yourself from the Sources tab."
        if code >= 500:
            return f"{host} had a problem of its own ({code}). Try again later."
        return f"{host} answered with an error ({code})."
    return f"The connection to {host} failed: {exc}. Try again."


def _reply(info: dict, image=None) -> list:
    out = [json.dumps(info, indent=1, ensure_ascii=False)]
    if image is not None:
        out.append(Image(path=str(image)))
    return out


@tool
def find_place(query: str) -> list[dict]:
    """Look up a place name. Returns matching places with their centre and bounding box in degrees."""
    return discover.find_place(query)


@tool
def open_surveys(keyword: str = "") -> list[dict]:
    """List open lidar surveys on OpenTopography flown with archaeology in mind, or matching a keyword.

    Each has its footprint, why it matched, and whether its points can be fetched without an account.
    checked_start is a small box known to hold ground data, for surveys whose fetch has been tested.
    known_problem says why a survey that can be downloaded still cannot be used. Do not propose those.
    """
    return discover.open_surveys(keyword)


@tool
def survey_area(west: float, south: float, east: float, north: float) -> dict:
    """Size up an area before committing to it: which open lidar covers it and which sites are already recorded.

    Use it on areas up to 2 degrees across. Recorded sites come from Wikidata, OpenStreetMap and the public
    US National Register, and are listed by name, distance and direction from the centre of the area.
    """
    return discover.survey_area([west, south, east, north])


@tool
def find_gaps(west: float, south: float, east: float, north: float) -> dict:
    """Rank the parts of a region by where a search could add most: open lidar, and few sites on open record.

    The region (up to 2 degrees across) is cut into a 4 by 4 grid. Cells covered by lidar flown for archaeology
    come first, then cells with the fewest recorded sites. Read how_to_read before telling anyone a cell is empty.
    """
    return discover.find_gaps([west, south, east, north])


@tool
def open_resources(topic: str = "") -> list[dict]:
    """List the open archives a search can draw on: what each holds, how big it is, and which tools read it.

    Use it when someone asks what to research or where archaeologists look. topic filters the list, for example
    "lidar", "recorded sites", "literature" or a region.
    """
    return discover.open_resources(topic)


@tool
def search_records(query: str, west: float = 0, south: float = 0, east: float = 0, north: float = 0) -> dict:
    """Search Open Context for published excavation and survey records, optionally inside a lon/lat box.

    Returns how many records match and the first ten, each with its project, place and date range.
    """
    box = [west, south, east, north] if east > west and north > south else None
    return discover.search_records(query, box)


@tool
def export_finds(project: str) -> dict:
    """Save the project's candidates as a GeoJSON file for mapping software (QGIS, ArcGIS, Google Earth).

    Each point carries the candidate's id, name, status and the checks on its record. The file is
    written under private/exports/, next to the other locations, because it holds coordinates:
    it is for the person's own mapping software and is never copied into the Markdown records.
    """
    p = Project(project).check()
    locations = p.load("locations", {})
    features = []
    for c in ledger.everything(p):
        at = locations.get(c["id"])
        if not at:
            continue
        features.append({"type": "Feature", "geometry": {"type": "Point", "coordinates": [round(at["lon"], 7), round(at["lat"], 7)]},
                         "properties": {"id": c["id"], "name": c["name"], "status": c["status"], "flagged": c.get("flagged"),
                                        "checks": ", ".join(sorted(c.get("checks", {}))), "sources_logged": len(c.get("sources", []))}})
    folder = p.path("private", "exports")
    folder.mkdir(parents=True, exist_ok=True)
    f = folder / "candidates.geojson"
    f.write_text(json.dumps({"type": "FeatureCollection", "features": features}, indent=1))
    return {"file": str(f), "candidates": len(features),
            "note": "The file holds coordinates. It stays under private/ and is not part of what a project shares."}


@tool
def init_project(project: str, name: str, question: str, west: float, south: float, east: float, north: float) -> dict:
    """Create a project folder (or adopt an existing one). The box is the search area in degrees."""
    p = Project.create(project, name, question, [west, south, east, north])
    return {"project": str(p.root), "read_first": ["RESEARCH.md", "METHODOLOGY.md"]}


@tool
def find_data(west: float, south: float, east: float, north: float) -> list[dict]:
    """List open lidar datasets overlapping a lon/lat box, with the citation each one asks for.

    Read each dataset's description: it often names earlier studies of the same data,
    which are the first things a literature search must cover.
    """
    return sources.find_data([west, south, east, north])


@tool
def fetch_terrain(project: str, dataset: str, west: float, south: float, east: float, north: float,
                  resolution_m: float = 0.5) -> dict:
    """Download one dataset's points for a lon/lat box and build the bare-ground model.

    Keep each box under 6 square km and fetch large areas in parts. The reply says how
    dense the ground returns are and how much of the area has no ground data at all.
    """
    p = Project(project).check()
    bbox = [west, south, east, north]
    km2 = ledger.distance_m((west, south), (east, south)) * ledger.distance_m((west, south), (west, north)) / 1e6
    if km2 > MAX_KM2:
        raise ValueError(f"The box covers {km2:.1f} square km. Fetch at most {MAX_KM2} at a time.")
    tid = re.sub(r"[^a-z0-9]+", "-", dataset.split(":")[-1].lower()).strip("-")[:28] + "-" + \
        hashlib.sha1(json.dumps(bbox).encode()).hexdigest()[:4]
    started = time.time()

    stop = p.path("private", "state", "stop-download")
    stop.unlink(missing_ok=True)
    stopped: list[bool] = []

    def report(done: int, total: int) -> None:
        # The app reads this to show what is downloading and roughly how long is left. No coordinates go in it.
        # It writes stop-download when the person presses Cancel; the fetch ends at the next part.
        if stopped or stop.exists():
            stopped.append(True)
            stop.unlink(missing_ok=True)
            raise RuntimeError("Stopped by the person before the download finished. Nothing was added to the project.")
        p.save("progress", {"dataset": dataset, "done": done, "total": total, "started": started, "updated": time.time()})

    sources.progress = report
    sources.cancelled = lambda: bool(stopped) or stop.exists()
    try:
        return _fetch(p, dataset, bbox, km2, tid, resolution_m)
    finally:
        sources.progress = lambda done, total: None
        sources.cancelled = lambda: False
        p.path("private", "state", "progress.json").unlink(missing_ok=True)


def _fetch(p, dataset: str, bbox: list[float], km2: float, tid: str, resolution_m: float) -> dict:
    west, south, east, north = bbox
    if dataset in national.NATIONAL:  # a ready-made ground model, not points
        dtm, outside, x0, y1, resolution_m, epsg, how = national.fetch_dtm(dataset, bbox, resolution_m)
        gap = np.zeros_like(dtm)
        x1, y0 = x0 + dtm.shape[1] * resolution_m, y1 - dtm.shape[0] * resolution_m
        stats = {"ground_classified": True, "ground_points": None, "ground_points_per_m2": None,
                 "share_outside_survey": round(float(outside.mean()), 3), "share_without_ground_data": 0.0}
        points = None
        summary = f"a ready-made ground model at {resolution_m:g} m, {stats['share_outside_survey']:.0%} of the box outside its coverage"
    else:
        pts, how = sources.fetch_points(dataset, bbox)
        if not len(pts):
            raise ValueError("The dataset has no points inside this box. Check the box against the dataset's footprint.")
        epsg = pts.epsg
        x0, y0, x1, y1 = (round(v / resolution_m) * resolution_m for v in sources.project_bbox(bbox, epsg))
        dtm, gap, outside, stats = T.grid_ground(pts, (x0, y0, x1, y1), resolution_m)
        points = f"data/points/{tid}.npz"
        pts.save(p.path(points))
        summary = f"{stats['ground_points']:,} ground returns, {stats['share_without_ground_data']:.0%} of the area without ground data"
    T.save_terrain(p.path("data", "terrain", f"{tid}.tif"), dtm, gap, outside, x0, y1, resolution_m, epsg)
    meta = {"dataset": dataset, "file": f"data/terrain/{tid}.tif", "points": points,
            "epsg": epsg, "res": resolution_m, "box": [x0, y0, x1, y1], "area_km2": round(km2, 2), **stats, **how}
    year = re.search(r"(?<!\d)(19|20)\d\d(?!\d)", dataset)  # most survey names carry the year they were flown
    if year:
        meta["collected"] = year.group(0)
    terrains = p.load("terrains", {})
    terrains[tid] = meta
    p.save("terrains", terrains)
    p.note(f"Fetched {dataset} as terrain {tid}: {summary}")
    warn = [] if stats["ground_classified"] else ["This dataset has no ground classification; the model uses the lowest return per cell and will include low vegetation."]
    if points is None:
        warn.append("This is a national agency's ready-made ground model. There are no raw points, so a section shows the ground profile only and cannot tell a feature in the ground from one in the trees.")
    return {"terrain": tid, **{k: v for k, v in meta.items() if k not in ("box", "file", "points", "epsg")}, "warnings": warn}


@tool
def import_terrain(project: str, file: str, name: str = "") -> dict:
    """Use the person's own data as a terrain: a ground model (GeoTIFF) or a point cloud (LAS or LAZ) on this Mac.

    The file needs a coordinate system in metres (a projected one, such as UTM or a national grid). A point
    cloud's ground returns are gridded at 0.5 m; a ground model is used at its own cell size. The terrain then
    tiles, renders and cuts like one that was fetched.
    """
    import rasterio
    p = Project(project).check()
    src = Path(file).expanduser()
    if not src.exists():
        raise ValueError(f"No file at {src}.")
    stem = re.sub(r"[^a-z0-9]+", "-", (name or src.stem).lower()).strip("-")[:28] or "own"
    tid = stem + "-" + hashlib.sha1(str(src.resolve()).encode()).hexdigest()[:4]
    ext = src.suffix.lower()
    if ext in (".tif", ".tiff"):
        with rasterio.open(src) as r:
            if r.crs is None or not r.crs.is_projected:
                raise ValueError("This GeoTIFF has no projected coordinate system in metres, so distances and heights "
                                 "cannot be measured. Reproject it (for example to UTM) and try again.")
            epsg = r.crs.to_epsg()
            if epsg is None:
                raise ValueError("Dighouse could not read an EPSG code from this GeoTIFF's coordinate system.")
            dtm = r.read(1).astype(np.float32)
            if r.nodata is not None:
                dtm[dtm == r.nodata] = np.nan
            res, x0, y1 = abs(r.transform.a), r.transform.c, r.transform.f
        dtm[(dtm < -500) | (dtm > 9000)] = np.nan
        outside = np.isnan(dtm)
        if outside.all():
            raise ValueError("This GeoTIFF has no valid heights.")
        dtm[outside] = float(np.nanmedian(dtm))
        gap = np.zeros_like(dtm)
        x1, y0 = x0 + dtm.shape[1] * res, y1 - dtm.shape[0] * res
        stats = {"ground_classified": True, "ground_points": None, "ground_points_per_m2": None,
                 "share_outside_survey": round(float(outside.mean()), 3), "share_without_ground_data": 0.0}
        points, kind = None, "ground model"
    elif ext in (".las", ".laz"):
        import laspy
        with laspy.open(src) as reader:
            crs = reader.header.parse_crs()
            h = reader.header
            box = (h.x_min, h.y_min, h.x_max, h.y_max)
        if crs is None or not crs.is_projected:
            raise ValueError("This point cloud has no projected coordinate system in metres. Add one (for example with "
                             "PDAL or LAStools) and try again.")
        epsg = crs.to_epsg()
        if epsg is None:
            raise ValueError("Dighouse could not read an EPSG code from this point cloud's coordinate system.")
        pts = sources._join([sources._read_las(src, box)], epsg)
        if not len(pts):
            raise ValueError("The point cloud is empty.")
        res = 0.5
        x0, y0, x1, y1 = (round(v / res) * res for v in box)
        dtm, gap, outside, stats = T.grid_ground(pts, (x0, y0, x1, y1), res)
        points = f"data/points/{tid}.npz"
        pts.save(p.path(points))
        kind = "point cloud"
    else:
        raise ValueError("Dighouse reads ground models as GeoTIFF (.tif) and point clouds as LAS or LAZ.")
    km2 = round((x1 - x0) * (y1 - y0) / 1e6, 2)
    p.path("data", "terrain").mkdir(parents=True, exist_ok=True)
    T.save_terrain(p.path("data", "terrain", f"{tid}.tif"), dtm, gap, outside, x0, y1, res, epsg)
    meta = {"dataset": f"own:{src.name}", "file": f"data/terrain/{tid}.tif", "points": points, "epsg": epsg, "res": res,
            "box": [x0, y0, x1, y1], "area_km2": km2, **stats, "source": "the person's own file", "imported_from": src.name}
    terrains = p.load("terrains", {})
    terrains[tid] = meta
    p.save("terrains", terrains)
    p.note(f"Imported the person's own {kind} {src.name} as terrain {tid}: {km2} sq km at {res:g} m")
    warn = [] if points is not None else ["A ground model has no raw points, so a section shows the ground profile only."]
    return {"terrain": tid, **{k: v for k, v in meta.items() if k not in ("box", "file", "points", "epsg")}, "warnings": warn}


@tool
def view_terrain(project: str, terrain: str, style: str = "composite") -> list:
    """Look at a whole terrain at reduced size. Styles: composite, hillshade, slope, local_relief, sky_view (dark ditches and hollows, bright banks; no light direction)."""
    p = Project(project).check()
    meta = p.load("terrains", {})[terrain]
    img = T.render(*T.load_terrain(p.path(meta["file"])), meta["res"], style)
    img.thumbnail((1400, 1400))
    f = p.path("data", "tiles", f"{terrain}-overview-{style}.png")
    img.save(f)
    return _reply({"terrain": terrain, "style": style, "area_km2": meta["area_km2"]}, f)


@tool
def render_tiles(project: str, style: str = "sky_view") -> dict:
    """Render every tile of the project in one style, so the map can show them all that way.

    Styles: composite, hillshade, slope, local_relief, sky_view. Tiles already rendered are kept.
    """
    p = Project(project).check()
    if style not in T.STYLES:
        raise ValueError(f"style must be one of {', '.join(T.STYLES)}")
    made = 0
    for tid in p.load("tiles", {}):
        f = p.path("data", "tiles", f"{tid}-{style}.png")
        if not f.exists():
            tiles.cached_tile(p, tid, style)
            made += 1
    return {"style": style, "rendered": made}


@tool
def make_tiles(project: str, terrain: str, tile_m: float = 250) -> dict:
    """Cut a terrain into overlapping tiles for screening. Tiles with too little ground data are marked unreadable."""
    p = Project(project).check()
    out = tiles.make_tiles(p, terrain, tile_m)
    p.note(f"Cut {terrain} into {out['tiles_added']} tiles, {out['unreadable']} unreadable")
    return out


@tool
def next_tiles(project: str, count: int = 8) -> list[str]:
    """The next tiles nobody has screened yet."""
    return tiles.next_unscreened(Project(project).check(), count)


@tool
def view_tile(project: str, tile: str, style: str = "composite") -> list:
    """Look at one tile. North is up. Styles: composite, hillshade, slope, local_relief, sky_view (dark ditches and hollows, bright banks; no light direction).

    Look for straight edges, right angles, flat rectangles, regular mounds and
    platforms. Flat dark grey means no ground data there.
    """
    p = Project(project).check()
    t = p.load("tiles", {})[tile]
    meta = p.load("terrains", {})[t["terrain"]]
    info = {"tile": tile, "status": t["status"], "width_m": round(t["window"][3] * meta["res"]),
            "height_m": round(t["window"][2] * meta["res"]), "share_without_ground_data": t["share_without_ground_data"]}
    return _reply(info, tiles.cached_tile(p, tile, style))


@tool
def record_verdict(project: str, tile: str, verdict: str, note: str, model: str) -> dict:
    """Record what a tile shows: nothing, natural, modern, possible or built. Name the model that looked."""
    return tiles.record_verdict(Project(project).check(), tile, verdict, note, model)


@tool
def flag_candidate(project: str, tile: str, x: float, y: float, name: str, note: str, model: str) -> list:
    """Open a candidate record for something that looks built.

    x and y give its centre as fractions of the tile image: 0,0 is the top left corner, 1,1 the bottom right.
    """
    p = Project(project).check()
    meta = ledger.create(p, name, tile, tiles.tile_lonlat(p, tile, x, y), note, model, at=(x, y))
    f = p.path("candidates", "img", f"{meta['id']}-relief.png")
    tiles.tile_image(p, tile, "composite", mark=(x, y)).save(f)
    p.note(f"{meta['id']} marked on {tile} by {model}: {name}")
    return _reply({"candidate": meta["id"], "record": f"candidates/{meta['id']}.md", "status": meta["status"]}, f)


@tool
def cut_section(project: str, tile: str, x1: float, y1: float, x2: float, y2: float, candidate: str = "",
                width_m: float = 4.0) -> list:
    """Cut a vertical slice through the raw points along a line on a tile.

    The line runs from x1,y1 to x2,y2, as fractions of the tile image. Tan dots are ground
    returns, green dots everything else. Pass a candidate id to file the section on its record.
    feature_height_m is the highest the ground rises above a straight line joining the two ends,
    so start and end the line on the surrounding ground. The feature counts as being in the
    ground when the ground returns around its peak are dense.
    """
    p = Project(project).check()
    ax, ay, _ = tiles.tile_xy(p, tile, x1, y1)
    bx, by, _ = tiles.tile_xy(p, tile, x2, y2)
    terrain = p.load("tiles", {})[tile]["terrain"]
    img, stats = section.cut(p, terrain, (ax, ay), (bx, by), width_m)
    if stats.get("from_ground_model_only"):
        stats["in_ground"] = None
        stats["note"] = ("This terrain is a national agency's ground model with no raw points. The height is measured on the model; "
                         "whether the feature is in the ground or is vegetation the agency left in cannot be told from it.")
    else:
        stats["in_ground"] = stats["ground_returns_within_5m_of_peak"] >= 20 and stats["ground_returns_per_m"] >= 2
    if not stats["has_vegetation_returns"] and not stats.get("from_ground_model_only"):
        stats["note"] = "This dataset holds ground returns only, so the slice cannot show the canopy."
    if candidate:
        f = p.path("candidates", "img", f"{candidate}-section.png")
        img.save(f)
        ledger.set_check(p, candidate, "section", {**stats, "image": True})
    else:
        f = p.path("data", "tiles", f"{tile}-section.png")
        img.save(f)
    return _reply(stats, f)


@tool
def second_look(project: str, candidate: str, agrees: bool, model: str, note: str) -> dict:
    """Record a second opinion on a candidate from a different model than the one that flagged it."""
    p = Project(project).check()
    meta, _ = ledger.get(p, candidate)
    if model.strip().lower() == meta["flagged_by"].strip().lower():
        raise ValueError(f"The second look must come from a different model than {meta['flagged_by']}.")
    ledger.set_check(p, candidate, "second_look", {"agrees": agrees, "model": model, "note": note})
    return {"candidate": candidate, "second_look_agrees": agrees}


@tool
def check_modern(project: str, candidate: str, radius_m: int = 150) -> dict:
    """Check OpenStreetMap around a candidate for roads, buildings and land use, and for sites already mapped nearby."""
    p = Project(project).check()
    lon, lat = ledger.location(p, candidate)
    try:
        found = checks.modern_features(lon, lat, radius_m)
    except RuntimeError:
        # A check that was tried and got no answer leaves a trace too, so the record can say why it is still open.
        p.note(f"Could not check for modern features near {candidate}: the open map services did not answer")
        raise
    n = found["mapped_features_within_radius"]
    # Say what is there, in words: "paths or roads (footway, track); buildings (Museum)".
    near = [f"{what} ({', '.join(x.replace('_', ' ') for x in found[key][:4])})" for key, what in
            (("roads", "paths or roads"), ("buildings", "buildings"), ("land_use", "land in use"), ("structures", "structures")) if found[key]]
    summary = f"within {radius_m} m open maps show {'; '.join(near)}" if near else f"nothing modern mapped within {radius_m} m"
    if found["historic_within_2km"]:
        reach = found.get("historic_searched_within_m", 2000)
        summary += (f"; historic places mapped within {'2 km' if reach == 2000 else f'{reach} m'}: "
                    f"{', '.join(x.replace('_', ' ') for x in found['historic_within_2km'][:6])}")
    ledger.set_check(p, candidate, "modern", {"likely_modern": n > 0, "summary": summary, "radius_m": radius_m,
                                              "near": [w.split(" (")[0] for w in near]})
    return {"candidate": candidate, **found, "summary": summary}


@tool
def search_literature(project: str, query: str, limit: int = 15) -> list[dict]:
    """Search scholarly works. Start with the dataset's name and the studies its description cites.

    Each result has its abstract when the index holds one, and a link to an open copy when there is one.
    Finding a title is not reading it: open the source with read_source, then log it with log_source.
    """
    p = Project(project).check()
    found = checks.search_literature(query, limit)
    p.note(f"Searched the literature for '{query}': {len(found)} results")
    return found


@tool
def read_source(project: str, url: str, start: int = 0) -> dict:
    """Open a source, a web page or a PDF, and return its text, 12,000 characters at a time.

    Pass the open_copy or doi link from search_literature. When more_from is set, call again with
    start set to it to read on. If the source cannot be opened, log it as could_not_open.
    A file name starting with "page-" reads a page the person opened and saved from the Sources tab.
    """
    p = Project(project).check()
    saved = p.path("sources", "pages", url) if url.startswith("page-") and "/" not in url else None
    if saved and saved.exists():
        # A page the person opened in the Sources tab and handed over. Its first line is the address it came from.
        text = saved.read_text()
        address, _, body = text.partition("\n")
        out = {"url": address.removeprefix("Address: ").strip(), "saved_by_person": True, "characters": len(body),
               "start": start, "text": body[start:start + 12000],
               "more_from": start + 12000 if len(body) > start + 12000 else None}
    else:
        out = checks.read_source(url, start)
    p.note(f"Opened {out['url']} ({out['characters']} characters)" + (" from the copy the person saved" if saved else ""))
    return out


@tool
def log_source(project: str, candidate: str, title: str, status: str, finding: str, link: str = "") -> dict:
    """Log one source against a candidate. status is read, could_not_open or not_relevant.

    finding says what the source shows about this place, without coordinates. candidate may be one id,
    several separated by commas, or "all" when the source bears on every candidate in the project.
    """
    p = Project(project).check()
    ids = [c["id"] for c in ledger.everything(p)] if candidate.strip().lower() == "all" else [c.strip() for c in candidate.split(",") if c.strip()]
    counts = {cid: len(ledger.add_source(p, cid, title, status, finding, link)["sources"]) for cid in ids}
    return {"logged_on": counts}


@tool
def add_evidence(project: str, candidate: str, text: str) -> dict:
    """Add one line of evidence to a candidate record. No coordinates."""
    p = Project(project).check()
    meta, notes = ledger.get(p, candidate)
    meta["evidence"].append(text)
    ledger.write(p, meta, notes)
    return {"candidate": candidate, "evidence_lines": len(meta["evidence"])}


@tool
def suggest_decision(project: str, candidate: str, status: str, reason: str, model: str) -> dict:
    """Suggest the decision the person should make on a candidate, and why, so their review starts prepared.

    status is already_published, modern, natural or no_match_in_sources_read. The reason is what the person
    will read: for already_published, name where it is published (author, year, title, or the record); for
    modern or natural, what shows it. Suggest no_match_in_sources_read only when the record's checks support it.
    This changes nothing else on the record; the person makes the decision.
    """
    p = Project(project).check()
    meta = ledger.suggest(p, candidate, status, reason, model)
    return {"candidate": candidate, "suggestion": meta["suggestion"]}


@tool
def set_status(project: str, candidate: str, status: str, decided_by: str = "", reason: str = "") -> dict:
    """Move a candidate to a status: ground_confirmed, modern, natural, already_published,
    no_match_in_sources_read or reported.

    The record's checks must support the status. no_match_in_sources_read and reported
    need a person's decision: ask them, then pass their name as decided_by.
    """
    p = Project(project).check()
    meta = ledger.set_status(p, candidate, status, decided_by, reason)
    return {"candidate": candidate, "status": meta["status"]}


@tool
def list_candidates(project: str) -> list[dict]:
    """Every candidate with its status and what still blocks it from being marked as having no match."""
    p = Project(project).check()
    return [{"id": m["id"], "name": m["name"], "status": m["status"],
             "open_items": ledger.blockers(m, "no_match_in_sources_read")} for m in ledger.everything(p)]


@tool
def add_control(project: str, name: str, lon: float, lat: float) -> dict:
    """Register a published site inside the search area as a control. A run should find its controls again."""
    p = Project(project).check()
    controls = p.load("controls", {})
    controls[name] = {"lon": lon, "lat": lat}
    p.save("controls", controls)
    return {"controls": len(controls)}


@tool
def write_summary(project: str, text: str) -> dict:
    """Write the run summary in Markdown at the end of every run, even one that stopped early.

    Say what was done, what each candidate's checks show, which sources were read or could not be opened,
    what is left, and what is waiting for the person. No coordinates.
    """
    p = Project(project).check()
    if re.search(r"-?\d{1,3}\.\d{4,}", text):
        raise ValueError("The summary looks like it holds coordinates. Refer to places by candidate id instead.")
    return {"written": f"notes/{p.summary(text)}"}


@tool
def write_report(project: str, advice: str = "") -> dict:
    """Write the search report, the two-minute read a person gets when a search ends: what was asked, the data used,
    what was looked at, what was flagged and why, what is already published, what was ruled out, what needs their
    decision and what to try next. It is built from the project's records, so finish the records first.

    Call it last, after write_summary. Pass advice: two or three plain sentences on what you would try next and why.
    No coordinates. It returns the candidates waiting for a person.
    """
    return report.write(Project(project).check(), advice)


@tool
def document_project(project: str, stopped_during: str = "") -> dict:
    """Rebuild RESEARCH.md, the project's research record: data used, every tile looked at, every candidate's
    checks and decision, every source and literature search, and what is still to do. Read it before a run;
    call this after work that the record should show. It returns what is still to do.

    stopped_during is for the app: when a person stops a run, it names the stage the run was on, so the record says so."""
    p = Project(project).check()
    if stopped_during.strip():
        p.note(f"{record.STOPPED}{' '.join(stopped_during.split())[:80]}")
    return record.document(p)


@tool
def run_status(project: str) -> dict:
    """Where the run stands: tile coverage, candidates by status, controls found again, and what needs a person."""
    p = Project(project).check()
    records = ledger.everything(p)
    places = p.load("locations", {})
    controls = p.load("controls", {})
    found = [name for name, c in controls.items()
             if any(ledger.distance_m((c["lon"], c["lat"]), (v["lon"], v["lat"])) < 150 for v in places.values())]
    waiting = [m["id"] for m in records if m["status"] in ("flagged", "ground_confirmed")
               and not [b for b in ledger.blockers(m, "no_match_in_sources_read") if "could not be opened" not in b]]
    return {
        "coverage": tiles.coverage(p),
        "candidates": {s: sum(m["status"] == s for m in records) for s in ledger.STATUSES},
        "controls": {"registered": len(controls), "found_again": len(found), "missed": sorted(set(controls) - set(found))},
        "needs_a_person": waiting,
    }


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
