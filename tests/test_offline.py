"""The whole chain on synthetic data: fetch, tile, screen, flag, section, checks, statuses."""

import json
import numpy as np
import math
from pathlib import Path

import pytest

from dighouse import checks, server, sources, tiles
from dighouse.project import Project


def tile_at(p, xy):
    """The readable tile containing a projected point, and the point as fractions of it."""
    terrain = next(iter(p.load("terrains").values()))
    x0, _, _, y1 = terrain["box"]
    for tid, t in p.load("tiles").items():
        r, c, h, w = t["window"]
        fx = ((xy[0] - x0) / terrain["res"] - c) / w
        fy = ((y1 - xy[1]) / terrain["res"] - r) / h
        if 0.05 < fx < 0.95 and 0.05 < fy < 0.95 and t["status"] != "unreadable":
            return tid, fx, fy
    raise AssertionError("no tile holds the point")


def test_a_project_holds_named_areas_and_follows_them(tmp_path, survey):
    """A region project: named, its box widened by each area fetched into it, each area named in the record."""
    from dighouse import record

    root = str(tmp_path / "region")
    w, s, e, n = survey["bbox"]
    server.init_project(root, "Search on its own", "To be named", w, s, w + 0.0005, s + 0.0005)
    p = Project(root)
    p.save("recorded", [])   # a cached reading of the sites on record for the old box
    got = server.name_project(root, "Petén lowland", "What built ground survives in the lowland forest?")
    assert got["name"] == "Petén lowland" and p.load("project")["name"] == "Petén lowland"
    head = p.path("PROJECT.md").read_text()
    assert head.startswith("# Petén lowland\n") and "What built ground survives in the lowland forest?" in head
    with pytest.raises(ValueError, match="coordinates"):
        server.name_project(root, "Area at 17.12345", "q")
    with pytest.raises(ValueError, match="coordinates"):
        server.fetch_terrain(root, "usgs:synthetic", *survey["bbox"], area="spot -89.50123")

    t = server.fetch_terrain(root, "usgs:synthetic", *survey["bbox"], area="Plaza A1")
    assert "lonlat" not in t and p.load("terrains")[t["terrain"]]["area"] == "Plaza A1"
    assert p.load("project")["bbox"] == [w, s, e, n] and p.load("recorded") is None
    assert record.areas(p.load("terrains")) == ["Plaza A1"]
    p.grow_area([e, n, e + 0.01, n + 0.01])
    assert p.load("project")["bbox"] == [w, s, e + 0.01, n + 0.01]


def test_full_chain(tmp_path, survey, monkeypatch):
    root = str(tmp_path / "proj")
    server.init_project(root, "Synthetic", "Is there a mound?", *survey["bbox"])
    p = Project(root)

    got = server.fetch_terrain(root, "usgs:synthetic", *survey["bbox"])
    assert got["ground_classified"] and 0.1 < got["share_without_ground_data"] < 0.3
    terrain = got["terrain"]
    assert p.path("data", "terrain", f"{terrain}.tif").exists()

    made = server.make_tiles(root, terrain, tile_m=100)
    assert made["tiles_added"] >= 9 and made["unreadable"] >= 3

    # an unreadable tile can be looked at but not judged
    blind = next(t for t, v in p.load("tiles").items() if v["status"] == "unreadable")
    server.view_tile(root, blind)
    with pytest.raises(ValueError, match="unreadable"):
        server.record_verdict(root, blind, "nothing", "empty", "model-a")

    tile, fx, fy = tile_at(p, survey["mound_xy"])
    assert tile in server.next_tiles(root, 100)
    server.record_verdict(root, tile, "built", "regular mound beside a flat rectangle", "model-a")
    flagged = server.flag_candidate(root, tile, fx, fy, "Mound group", "Oval mound beside a levelled plaza", "model-a")
    assert '"C-001"' in flagged[0] and p.path("candidates", "img", "C-001-relief.png").exists()

    # close views for the person: the same 60 m square in every style, kept out of the history, drawn once
    views = server.find_views(root, "C-001")
    from PIL import Image as _Image
    assert set(views["views"]) == set(tiles.FIND_VIEWS) and views["metres"] == 60
    first = p.root / views["views"]["sky_view"]
    assert first.parent == p.path("data", "views") and _Image.open(first).size == (480, 480)
    stamp = first.stat().st_mtime_ns
    server.find_views(root, "C-001")
    assert first.stat().st_mtime_ns == stamp

    # nothing may be claimed before the checks exist
    with pytest.raises(ValueError, match="no slice"):
        server.set_status(root, "C-001", "ground_confirmed")

    cut = server.cut_section(root, tile, fx - 0.3, fy, fx + 0.3, fy, candidate="C-001")
    stats = __import__("json").loads(cut[0])
    # height is measured above the straight line joining the ground at the two ends of the section
    mx, my = survey["mound_xy"]
    ends = (survey["height_at"](mx - 30, my) + survey["height_at"](mx + 30, my)) / 2
    assert abs(stats["feature_height_m"] - (survey["height_at"](mx, my) - ends)) < 0.8
    assert stats["in_ground"] and stats["has_vegetation_returns"]
    assert 12 < stats["canopy_height_m"] < 18
    assert server.set_status(root, "C-001", "ground_confirmed")["status"] == "ground_confirmed"

    with pytest.raises(ValueError, match="different model"):
        server.second_look(root, "C-001", True, "model-a", "same model")
    server.second_look(root, "C-001", True, "model-b", "agree: mound and plaza")

    monkeypatch.setattr(checks, "modern_features", lambda lon, lat, r, named=True: {
        "roads": [], "buildings": [], "land_use": [], "structures": [], "historic_within_2km": [],
        "mapped_features_within_radius": 0, "radius_m": r})
    server.check_modern(root, "C-001")
    server.log_source(root, "C-001", "Regional survey 2019", "read", "does not cover this hilltop")
    server.log_source(root, "C-001", "Paper using the same data", "could_not_open", "paywalled")
    pages = Path(root) / "sources" / "pages"
    pages.mkdir(parents=True, exist_ok=True)
    (pages / "page-test.txt").write_text("Address: https://example.org/paper\nThe survey covered the hilltop.")
    got = server.read_source(root, "page-test.txt")
    assert got["saved_by_person"] and got["url"] == "https://example.org/paper" and "hilltop" in got["text"]
    assert server.write_summary(root, "Screened one tile. C-001 has a section and a second look.")["written"].startswith("notes/")
    with pytest.raises(ValueError, match="coordinates"):
        server.write_summary(root, "C-001 sits at 38.66012, -90.06211")
    assert server.log_source(root, "all", "Site report 1967", "not_relevant", "about another county")["logged_on"] == {"C-001": 3}

    # an agent cannot mark it; a person can, and the open item is written into the record
    with pytest.raises(ValueError, match="person must decide"):
        server.set_status(root, "C-001", "no_match_in_sources_read")
    assert "could not be opened" in " ".join(server.list_candidates(root)[0]["open_items"])
    server.set_status(root, "C-001", "no_match_in_sources_read", decided_by="Chris", reason="Accepting one unread paper.")

    record = p.path("candidates", "C-001.md").read_text()
    assert "No match in the sources read" in record and "Open at the time" in record
    assert "new" not in record.lower().split("## notes")[0].replace("renew", "")
    lon, lat = survey["mound_lonlat"]
    for text in (record, p.path("PROJECT.md").read_text(), next(p.path("notes").glob("*.md")).read_text()):
        assert f"{lon:.2f}" not in text and f"{lat:.2f}" not in text  # locations stay under private/

    server.add_control(root, "Known mound", lon, lat)
    server.add_control(root, "Site we missed", lon + 0.001, lat + 0.001)
    status = server.run_status(root)
    assert status["controls"] == {"registered": 2, "found_again": 1, "missed": ["Site we missed"]}
    assert status["coverage"]["unreadable"] == made["unreadable"] and status["coverage"]["verdicts"]["built"] == 1


def test_records_keep_notes(tmp_path, survey):
    root = str(tmp_path / "proj")
    server.init_project(root, "Synthetic", "q", *survey["bbox"])
    p = Project(root)
    terrain = server.fetch_terrain(root, "usgs:synthetic", *survey["bbox"])["terrain"]
    server.make_tiles(root, terrain, tile_m=100)
    tile, fx, fy = tile_at(p, survey["mound_xy"])
    server.flag_candidate(root, tile, fx, fy, "Mound", "note", "model-a")
    f = p.path("candidates", "C-001.md")
    f.write_text(f.read_text() + "A person wrote this by hand.\n")
    server.add_evidence(root, "C-001", "Second line")
    assert "A person wrote this by hand." in f.read_text() and "- Second line" in f.read_text()


def test_a_map_service_that_is_down_leaves_the_check_open(tmp_path, monkeypatch):
    """When OpenStreetMap's map servers do not answer, the check says so plainly and writes nothing on the record."""
    import httpx
    from dighouse import ledger

    root = str(tmp_path / "maps")
    server.init_project(root, "Maps", "Is the map check honest?", 0, 0, 0.01, 0.01)
    p = Project(root)
    ledger.create(p, "A low bank", "t-1", (0.004, 0.006), "seen in two styles", "test")

    def down(*args, **kwargs):
        raise httpx.ConnectTimeout("no answer")

    monkeypatch.setattr(checks, "_overpass_back", 0.0)
    monkeypatch.setattr(checks._client, "post", down)
    monkeypatch.setattr(checks._client, "get", down)
    with pytest.raises(RuntimeError, match="did not answer"):
        server.check_modern(root, "C-001")
    assert "modern" not in ledger.get(p, "C-001")[0]["checks"]
    assert "modern features have not been checked" in server.list_candidates(root)[0]["open_items"]
    # The try that got no answer is in the research record, so the next person knows why the check is open.
    server.document_project(root)
    assert "the map service did not answer on" in p.path("RESEARCH.md").read_text()

    # When a server answers, what it maps is counted and written on the record.
    class Reply:
        status_code = 200

        def json(self):
            return {"elements": [{"tags": {"highway": "track"}}, {"tags": {"historic": "archaeological_site", "name": "Old Fort"}}]}

    monkeypatch.setattr(checks._client, "post", lambda *args, **kwargs: Reply())
    monkeypatch.setattr(checks, "_overpass_back", 0.0)  # the ten minutes of not asking the servers that were down are over
    got = server.check_modern(root, "C-001")
    assert got["mapped_features_within_radius"] == 1 and got["historic_within_2km"] == ["Old Fort"]
    assert got["summary"] == "within 150 m open maps show paths or roads (track); historic places mapped within 2 km: Old Fort"
    assert ledger.get(p, "C-001")[0]["checks"]["modern"]["likely_modern"] is True


def test_the_map_check_has_a_second_way_in(monkeypatch):
    """With the Overpass servers down, OpenStreetMap's own map service is asked for a square and the sorting is done here."""
    import httpx

    def down(*args, **kwargs):
        raise httpx.ConnectTimeout("no answer")

    def node(i, east_m, north_m, **tags):
        return {"type": "node", "id": i, "lon": east_m / 111_320, "lat": north_m / 111_320, **({"tags": tags} if tags else {})}

    square = [node(1, -500, 40), node(2, 500, 40),      # a track that passes 40 m north of the point
              node(3, 900, 900), node(4, 950, 950),      # a house 1.3 km away
              node(5, 0, 1500, historic="archaeological_site", name="Old Fort"),
              node(6, 3000, 3000, historic="memorial", name="Too far"),
              node(7, 20, 0, man_made="mast"), node(8, 10, 10, highway="crossing"),
              {"type": "way", "id": 1, "nodes": [1, 2], "tags": {"highway": "track"}},
              {"type": "way", "id": 2, "nodes": [3, 4, 3], "tags": {"building": "house"}}]
    asked = []

    class Reply:
        status_code = 200

        def json(self):
            return {"elements": square}

    def get(url, params=None, **kwargs):
        asked.append(params["bbox"])
        return Reply()

    monkeypatch.setattr(checks, "_boxes", {})
    monkeypatch.setattr(checks, "_overpass_back", 0.0)
    monkeypatch.setattr(checks._client, "post", down)
    monkeypatch.setattr(checks._client, "get", get)
    got = checks.modern_features(0.0, 0.0, 150)
    # The track counts though neither of its ends is within 150 m; the far house, the far memorial and a tagged node on a road do not.
    assert got["roads"] == ["track"] and got["buildings"] == [] and got["structures"] == ["mast"]
    assert got["historic_within_2km"] == ["Old Fort"] and got["mapped_features_within_radius"] == 2
    assert got["asked"] == "OpenStreetMap's map service" and got["historic_searched_within_m"] == 2000

    # A square that holds too much is refused; the radius alone is asked for, and the answer says how far it looked.
    class Refused:
        status_code = 400

    monkeypatch.setattr(checks, "_boxes", {})  # a new session: nothing kept from the first case
    replies = [Refused(), Reply()]
    monkeypatch.setattr(checks._client, "get", lambda url, params=None, **kwargs: replies.pop(0))
    got = checks.modern_features(0.0, 0.0, 150)
    assert got["historic_searched_within_m"] == 150 and got["historic_within_2km"] == [] and got["roads"] == ["track"]



def test_literature_search_falls_back_when_openalex_refuses(monkeypatch):
    """OpenAlex meters requests that carry no key. When it turns one away, Crossref is asked, and the result says which answered."""
    asked = []

    class Reply:
        def __init__(self, status, body):
            self.status_code, self._body = status, body

        def json(self):
            return self._body

        def raise_for_status(self):
            assert self.status_code == 200

    def get(url, params=None, **kwargs):
        asked.append(url)
        if url == checks.OPENALEX:
            return Reply(429, {"error": "Rate limit exceeded", "retryAfter": 3600})
        return Reply(200, {"message": {"items": [{"title": ["A county survey"], "DOI": "10.1/x", "issued": {"date-parts": [[1998, 5]]},
                                                  "author": [{"given": "A.", "family": "Digger"}],
                                                  "abstract": "<jats:p>A boundary  bank.</jats:p>", "is-referenced-by-count": 4}]}})

    monkeypatch.setattr(checks._client, "get", get)
    got = checks.search_literature("boundary bank", 5)
    assert asked == [checks.OPENALEX, checks.CROSSREF]  # a spent budget is not waited for
    assert got == [{"title": "A county survey", "year": 1998, "authors": ["A. Digger"], "doi": "https://doi.org/10.1/x", "open_copy": None,
                    "cited_by": 4, "abstract": "A boundary bank.", "index": "Crossref"}]


def test_a_refused_page_says_to_log_it(monkeypatch):
    """A publisher that refuses a program gives a message the agent can act on, not a stack of library errors."""
    class Refused:
        status_code = 403
        headers = {"content-type": "text/html"}
        text = "Forbidden"
        content = b"Forbidden"
        url = "https://example.org/paper"

    monkeypatch.setattr(checks, "_fetch_source", lambda *args, **kwargs: Refused())
    with pytest.raises(RuntimeError, match="could_not_open"):
        checks.read_source("https://example.org/paper")

def test_sky_view_darkens_a_ditch():
    import numpy as np
    from dighouse import terrain as T
    ground = np.zeros((80, 80), np.float32)
    ground[:, 38:42] = -1.5   # a ditch 2 m wide and 1.5 m deep
    svf = T.sky_view(ground, 0.5)
    assert svf[40, 40] < svf[40, 10] - 0.05 and abs(svf[40, 10] - 1) < 0.01


def test_export_finds_writes_geojson_under_private(tmp_path):
    from dighouse import ledger
    from dighouse.project import Project
    root = str(tmp_path / "export")
    server.init_project(root, "Export", "Can finds be exported?", 0, 0, 0.01, 0.01)
    ledger.create(Project(root), "A low bank", "t-1", (0.004, 0.006), "seen in two styles", "test")
    got = server.export_finds(root)
    data = json.loads(Path(got["file"]).read_text())
    assert got["candidates"] == 1 and "/private/exports/" in got["file"]
    assert data["features"][0]["geometry"]["coordinates"] == [0.004, 0.006]


def test_research_record_covers_what_was_done(tmp_path):
    """RESEARCH.md lists the data, tiles, sources and what is left, copes with a ready-made ground model, and holds no coordinates."""
    from dighouse import ledger, record

    p = Project.create(tmp_path / "rec", "Record check", "Is the bank built?", [0.0, 51.0, 0.01, 51.01])
    p.save("terrains", {"t1": {"dataset": "uk:ea-dtm-1m", "area_km2": 1.0, "ground_points_per_m2": None, "res": 1.0}})
    p.save("tiles", {"t1-r000c000": {"terrain": "t1", "window": [0, 0, 500, 500], "status": "screened", "verdict": "nothing",
                                     "note": "Plough lines only, near 51.00523", "model": "test-model"},
                     "t1-r000c001": {"terrain": "t1", "window": [0, 500, 500, 500], "status": "unscreened"}})
    cid = ledger.create(p, "Low bank", "t1-r000c000", (0.005, 51.005), "A straight low bank", "test-model")["id"]
    ledger.add_source(p, cid, "A county survey", "could_not_open", "Behind a paywall; see doi 10.2307/503404")
    out = record.document(p)

    text = p.path("RESEARCH.md").read_text()
    assert "Environment Agency (England)" in text and "ready-made ground model" in text
    assert "1 nothing" in text and "Plough lines only" in text
    assert "51.00523" not in text and "10.2307/503404" in text
    assert any("Look at 1 tile" in t for t in out["still_to_do"])
    assert any("could not be opened" in t for t in out["still_to_do"])
    assert "How this project keeps its record" in p.path("METHODOLOGY.md").read_text()
    # The top is written for a newcomer: what the project asks, a link to each find, and how to carry on.
    assert "**In short.** This project asks: Is the bank built?" in text
    assert f"- [{cid} Low bank](candidates/{cid}.md): waiting for a person's decision." in text
    assert "**How to continue.** Open this folder in Dighouse" in text


def test_the_record_survives_a_handover(tmp_path):
    """A shared project arrives without private/ and data/. Its record must still say what was looked at."""
    import shutil
    from dighouse import ledger, record

    p = Project.create(tmp_path / "first", "Handover check", "Is the bank built?", [0.0, 51.0, 0.01, 51.01])
    p.save("terrains", {"t1": {"dataset": "usgs:TEST_2020", "area_km2": 0.5, "ground_points_per_m2": 6.2, "res": 0.5,
                               "box": [500000.0, 5650000.0, 500700.0, 5650700.0]}})
    p.save("tiles", {"t1-r000c000": {"terrain": "t1", "window": [0, 0, 500, 500], "status": "screened", "verdict": "natural",
                                     "note": "A stream channel and nothing built", "model": "test-model"}})
    cid = ledger.create(p, "Low bank", "t1-r000c000", (0.005, 51.005), "A straight low bank", "test-model")["id"]
    record.document(p)

    # What Export project hands over: everything but private/ and data/.
    second = tmp_path / "second"
    shutil.copytree(p.root, second, ignore=shutil.ignore_patterns("private", "data"))
    q = Project(second).check()
    out = record.document(q)
    text = q.path("RESEARCH.md").read_text()

    assert out["handed_over"] and out["screened_before"] == 1
    assert "# Research record: Handover check" in text and "handed over" in text
    assert "usgs:TEST_2020" in text and "A stream channel and nothing built" in text and "natural (earlier)" in text
    assert "already looked at" in out["still_to_do"][-1]
    assert "5650000" not in q.path("notes", "record.json").read_text()   # the terrain's corner is a location
    # A tool that needs a location says why it cannot run here.
    with pytest.raises(ValueError, match="not on this Mac"):
        server.check_modern(str(second), cid)
    # Work done after the handover is added to the earlier work, not put in its place.
    q.save("terrains", {"t2": {"dataset": "usgs:TEST_2024", "area_km2": 0.2, "ground_points_per_m2": 9.0, "res": 0.5}})
    q.save("tiles", {"t2-r000c000": {"terrain": "t2", "window": [0, 0, 500, 500], "status": "unscreened"}})
    after = record.document(q)
    text = q.path("RESEARCH.md").read_text()
    assert not after["handed_over"] and "usgs:TEST_2020" in text and "usgs:TEST_2024" in text
    assert any("Look at 1 tile" in t for t in after["still_to_do"])


def test_the_search_report_says_what_the_records_say(tmp_path):
    """The report a search ends with: built from the records, linked from the research record, and without coordinates."""
    from dighouse import ledger

    root = str(tmp_path / "report")
    p = Project.create(root, "Report check", "Is the bank built?", [0.0, 51.0, 0.01, 51.01])
    p.save("terrains", {"t1": {"dataset": "usgs:TEST_2020", "area_km2": 0.5, "ground_points_per_m2": 6.2, "res": 0.5}})
    p.save("tiles", {"t1-r000c000": {"terrain": "t1", "window": [0, 0, 500, 500], "status": "screened", "verdict": "built",
                                     "note": "A straight bank", "model": "model-a"},
                     "t1-r000c001": {"terrain": "t1", "window": [0, 500, 500, 500], "status": "screened", "verdict": "natural",
                                     "note": "A stream channel", "model": "model-a"}})
    cid = ledger.create(p, "Low bank", "t1-r000c000", (0.005, 51.005), "A straight low bank across the slope", "model-a")["id"]
    ledger.set_check(p, cid, "section", {"feature_height_m": 0.8, "in_ground": True, "ground_returns_within_5m_of_peak": 40})
    ledger.add_source(p, cid, "A county survey, 1998", "read", "Lists a boundary bank on this hill", "https://example.org/survey")
    ledger.suggest(p, cid, "already_published", "A county survey, 1998, lists a boundary bank here.", "model-a")

    with pytest.raises(ValueError, match="coordinates"):
        server.write_report(root, "Look again near 51.00512, 0.00498.")
    got = server.write_report(root, "Try the sky view on the next tile north.")
    text = p.path(got["written"]).read_text()
    assert got["waiting_for_a_person"] == [cid] and got["words"] < 400
    headings = ("What needs your decision", "What was asked", "What was done", "What is already published",
                "What was ruled out or decided", "What to try next")
    assert [l[3:] for l in text.splitlines() if l.startswith("## ")] == list(headings)
    assert "Is the bank built?" in text and "TEST_2020" in text and "2 of 2" in text and "1 looked built, 1 natural" in text
    assert "Slice: 0.8 m above the line between the slice's ends, in the ground" in text and "Second model: has not looked" in text
    assert "A county survey, 1998" in text and "https://example.org/survey" in text
    assert "1 tile showed natural ground." in text
    assert "The agent suggests: already published." in text and "Try the sky view on the next tile north." in text
    assert "51.00" not in text and "new" not in text.lower().replace("nothing here is called new", "")
    assert f"reports/{p.path(got['written']).name}" in p.path("RESEARCH.md").read_text()

    # A decision changes the report, and rebuilding it the same day keeps the agent's advice.
    server.set_status(root, cid, "already_published", decided_by="Chris", reason="In the county survey.")
    again = p.path(server.write_report(root)["written"]).read_text()
    assert "Nothing. Every find has been decided." in again and "1 find has been decided: C-001, already published, by Chris" in again
    assert "Try the sky view on the next tile north." in again


def test_the_report_follows_the_records(tmp_path):
    """When a second opinion comes in or a person decides, the newest report is brought up to date in place, keeping
    the agent's advice, so it never asks for what is already done."""
    from dighouse import ledger, record

    root = str(tmp_path / "follow")
    p = Project.create(root, "Follow", "Is the bank built?", [0.0, 51.0, 0.01, 51.01])
    cid = ledger.create(p, "A bank", "t1-r000c000", (0.005, 51.005), "a bank", "model-a")["id"]
    ledger.set_check(p, cid, "section", {"feature_height_m": 0.8, "in_ground": True, "ground_returns_within_5m_of_peak": 40})
    ledger.set_check(p, cid, "modern", {"likely_modern": False, "summary": "nothing modern mapped within 150 m"})
    got = server.write_report(root, "Look at the bank in sky view.")
    f = p.path(got["written"])
    assert "a second opinion from another model" in f.read_text()

    ledger.set_check(p, cid, "second_look", {"agrees": True, "model": "model-b", "note": "a bank"})
    record.document(p)
    text = f.read_text()
    assert "a second opinion from another model" not in text and "Look at the bank in sky view." in text
    assert sorted(p.path("reports").glob("*.md")) == [f]

    server.set_status(root, cid, "natural", decided_by="Chris", reason="A field edge.")
    assert "Nothing. Every find has been decided." in f.read_text()


def test_measured_rises_stay_on_the_map_until_raised(tmp_path):
    """A measured rise reaches a person when the second model calls it built and it ranks in the top half of the
    project's rises, or when a person raises it; the rest stay on the map and out of the report's decisions."""
    from dighouse import ledger

    root = str(tmp_path / "layer")
    p = Project.create(root, "Layer", "Which rises are built?", [0.0, 51.0, 0.01, 51.01])
    seen = ledger.create(p, "A bank", "t1-r000c000", (0.005, 51.005), "a bank", "model-a")["id"]
    rises = {}
    for rank, agrees in ((1.0, True), (2.0, None), (3.0, False), (4.0, True)):
        cid = ledger.create(p, f"Measured rise {rank}", "t1-r000c000", (0.005, 51.005), "a rise", "measured (find_mounds)")["id"]
        ledger.set_check(p, cid, "shape", {"rank": rank})
        if agrees is not None:
            ledger.set_check(p, cid, "second_look", {"agrees": agrees, "model": "model-b", "note": ""})
        rises[rank] = cid
    records = ledger.everything(p)
    assert ledger.layer(records) == {rises[1.0], rises[2.0], rises[3.0]}
    assert seen not in ledger.layer(records) and rises[4.0] not in ledger.layer(records)

    got = server.write_report(root)
    assert sorted(got["waiting_for_a_person"]) == sorted([seen, rises[4.0]])
    text = p.path(got["written"]).read_text()
    assert "3 finds are kept on the map, not put to you" in text
    research = p.path("RESEARCH.md").read_text()
    assert "A person has decided 0 of 2. 3 finds are kept as a layer on the map" in research
    assert f"{rises[2.0]} Measured rise 2.0](candidates/{rises[2.0]}.md): kept on the map." in research

    server.raise_rise(root, rises[1.0], "Chris")
    assert ledger.layer(ledger.everything(p)) == {rises[2.0], rises[3.0]}
    with pytest.raises(ValueError, match="not kept on the map"):
        server.raise_rise(root, seen, "Chris")
    # A shape the bulk look pointed at waits on the map too, until the second model calls it built.
    bulk = ledger.create(p, "Seen in bulk: a mound", "t1-r000c000", (0.006, 51.006), "", "seen in bulk by m")["id"]
    assert bulk in ledger.layer(ledger.everything(p))
    ledger.set_check(p, bulk, "second_look", {"agrees": True, "model": "model-b", "note": ""})
    assert bulk not in ledger.layer(ledger.everything(p))
    listed = {c["id"]: c["kept_on_the_map"] for c in server.list_candidates(root)}
    assert listed[rises[3.0]] and not listed[rises[1.0]]


def test_many_decisions_at_once_and_undo(tmp_path):
    """Agreeing with many finds writes each record with the person's name and reason in one commit; undo puts one back."""
    import subprocess
    from dighouse import ledger

    root = str(tmp_path / "decide")
    p = Project.create(root, "Decide", "Which banks are built?", [0.0, 51.0, 0.01, 51.01])
    ids = [ledger.create(p, f"Bank {i}", "t1-r000c000", (0.005, 51.005), "a bank", "model-a")["id"] for i in range(3)]
    commits = lambda: int(subprocess.run(["git", "-C", root, "rev-list", "--count", "HEAD"], capture_output=True, text=True).stdout)
    before = commits()
    with pytest.raises(ValueError, match="reason"):
        server.decide_many(root, [{"candidate": ids[0], "status": "natural", "reason": " "}], "Chris")
    with pytest.raises(ValueError, match="person"):
        server.decide_many(root, [{"candidate": ids[0], "status": "natural", "reason": "a field edge"}], "")
    assert commits() == before and ledger.get(p, ids[0])[0]["status"] == "flagged"

    got = server.decide_many(root, [{"candidate": c, "status": "natural", "reason": f"field edge {c}"} for c in ids], "Chris")
    assert got["decided"] == ids and commits() == before + 1
    for c in ids:
        meta = ledger.get(p, c)[0]
        assert meta["status"] == "natural" and meta["decisions"][-1]["by"] == "Chris" and c in meta["decisions"][-1]["reason"]
    assert "A person has decided 3 of 3." in p.path("RESEARCH.md").read_text()

    assert server.undo_decision(root, ids[1], "Chris")["status"] == "flagged"
    meta = ledger.get(p, ids[1])[0]
    assert meta["decisions"] == [] and commits() == before + 2
    assert "A person has decided 2 of 3." in p.path("RESEARCH.md").read_text()
    with pytest.raises(ValueError, match="no decision"):
        server.undo_decision(root, ids[1], "Chris")


def test_the_search_report_has_a_ceiling(tmp_path):
    """Twenty finds, long notes and long advice still give a report under 400 words, with the decisions first."""
    from dighouse import ledger, report

    root = str(tmp_path / "many")
    p = Project.create(root, "Twenty finds", "Which of the banks on this ridge were built? " * 6, [0.0, 51.0, 0.01, 51.01])
    p.save("terrains", {f"t{i}": {"dataset": f"usgs:TEST_{i}", "area_km2": 0.5, "ground_points_per_m2": 6.2, "res": 0.5} for i in range(4)})
    p.save("tiles", {f"t1-r000c{i:03d}": {"terrain": "t1", "window": [0, 0, 500, 500], "status": "screened", "verdict": "built",
                                          "note": "A bank", "model": "model-a"} for i in range(20)})
    long = "A straight low bank that crosses the slope and turns a corner by the stream, seen in both views of the tile. " * 4
    for i in range(20):
        cid = ledger.create(p, f"Low bank number {i + 1} on the long ridge", f"t1-r000c{i:03d}", (0.005, 51.005), long, "model-a")["id"]
        ledger.set_check(p, cid, "section", {"feature_height_m": 0.8, "in_ground": True, "ground_returns_within_5m_of_peak": 40})
        ledger.set_check(p, cid, "second_look", {"agrees": i % 2 == 0, "model": "model-b", "note": long})
        ledger.set_check(p, cid, "modern", {"likely_modern": False, "summary": "nothing modern mapped within 150 m"})
        for n in range(4):
            ledger.add_source(p, cid, f"A long county survey title that goes on, volume {n}", "read", long, "https://example.org/survey")
        ledger.suggest(p, cid, "already_published", long, "model-a")
    for i in range(5):
        ledger.set_status(p, f"C-{16 + i:03d}", "natural", decided_by="Chris", reason=long)

    got = server.write_report(root, long * 3)
    text = p.path(got["written"]).read_text()
    assert got["words"] == report.count(text) < report.LIMIT == 400
    assert len(got["waiting_for_a_person"]) == 15
    # The decisions come first, the first finds are named, and the rest are counted, not dropped without a word.
    assert text.index("## What needs your decision") < text.index("## What was asked")
    shown = text.count("](../candidates/C-")
    assert shown >= 2 and "C-001" in text and f"{15 - shown} more finds wait for your decision" in text
    assert "5 finds have been decided: 5 natural feature." in text


def test_a_stopped_run_is_on_the_record(tmp_path):
    """When a person stops a run, the record says when and during what, until a run finishes after it."""
    root = str(tmp_path / "stop")
    p = Project.create(root, "Stop check", "Does a stop leave a trace?", [0.0, 51.0, 0.01, 51.01])
    server.document_project(root, stopped_during="Looking at the tiles")
    assert "The last run was stopped** by a person" in p.path("RESEARCH.md").read_text()
    assert "during: Looking at the tiles." in p.path("RESEARCH.md").read_text()
    server.write_summary(root, "Finished the screening.")
    assert "The last run was stopped" not in p.path("RESEARCH.md").read_text()


def test_answer_keys_are_sourced_and_inside_their_areas():
    """Every launch key has counted features, each with a source, and every feature lies inside the key's test area."""
    from dighouse import answers

    ks = {k["id"]: k for k in answers.keys()}
    assert {"angel-mounds", "mound-city", "serpent-mound", "cahokia", "maiden-castle", "borre", "andia"} <= set(ks)
    for k in ks.values():
        w, s, e, n = k["box"]
        assert k["sources"] and k["published"] and k["coverage"] in ("register", "partial", "charted")
        assert any(f["expect"] for f in k["features"]), k["id"]
        for f in k["features"]:
            assert f["source"] and f["what"], (k["id"], f["id"])
            pts = [(f["lon"], f["lat"])] if f["kind"] == "point" else [p for line in f["lines"] for p in line]
            assert all(w - 0.002 <= x <= e + 0.002 and s - 0.002 <= y <= n + 0.002 for x, y in pts), (k["id"], f["id"])
        shown = json.dumps(answers.summary(k))
        assert '"lon"' not in shown and '"lat"' not in shown


def test_scoring_counts_found_missed_and_extra():
    """A perfect run, a miss, a false find, one find between two mounds, and several finds on one rampart."""
    from dighouse import answers

    k = {"name": "Test site", "coverage": "register", "features": [
        {"id": "A", "what": "Mound", "kind": "point", "lon": 10.0, "lat": 59.0, "size_m": 20, "expect": True, "source": "s"},
        {"id": "B", "what": "Mound", "kind": "point", "lon": 10.0006, "lat": 59.0, "size_m": 20, "expect": True, "source": "s"},
        {"id": "G", "what": "Gone mound", "kind": "point", "lon": 10.003, "lat": 59.0, "size_m": 10, "expect": False, "source": "s"},
        {"id": "R", "what": "Rampart", "kind": "work", "lines": [[[10.0, 59.002], [10.002, 59.002]]], "area": False, "expect": True, "source": "s"},
    ]}
    east = 1 / (111_320 * math.cos(math.radians(59)))  # one metre east, in degrees
    perfect = answers.score(k, {"C-1": {"lon": 10.0, "lat": 59.0}, "C-2": {"lon": 10.0006, "lat": 59.0}, "C-3": {"lon": 10.001, "lat": 59.002}})
    assert (perfect["found"], perfect["known"], perfect["missed"], perfect["extra"]) == (3, 3, [], [])

    # One find halfway between the two mounds (about 17 m from each) takes one of them; the other is missed.
    between = answers.score(k, {"C-1": {"lon": 10.0003, "lat": 59.0}})
    assert between["found"] == 1 and len(between["missed"]) == 2 and between["extra"] == []

    # A find far from everything is extra; finds on the rampart count it once and are not extra; the gone mound is not counted.
    mixed = answers.score(k, {"C-1": {"lon": 10.0 - 20 * east, "lat": 59.0}, "C-2": {"lon": 10.01, "lat": 59.01},
                              "C-3": {"lon": 10.0005, "lat": 59.002}, "C-4": {"lon": 10.0015, "lat": 59.0021},
                              "C-5": {"lon": 10.003, "lat": 59.0}})
    assert mixed["found"] == 2 and mixed["known"] == 3
    assert [m["feature"] for m in mixed["missed"]] == ["B"]
    assert mixed["extra"] == ["C-2"]
    assert any(r["find"] == "C-5" and r["counted"] is False for r in mixed["matches"])

    # A find nearer an uncounted feature but within a counted mound's reach goes to the mound.
    k["features"].append({"id": "H", "what": "Reconstructed house", "kind": "point", "lon": 10.0 - 30 * east, "lat": 59.0,
                          "size_m": 10, "expect": False, "source": "s"})
    near_house = answers.score(k, {"C-1": {"lon": 10.0 - 22 * east, "lat": 59.0}})
    assert near_house["found"] == 1 and near_house["matches"][0]["feature"] == "A"


def test_blind_test_closes_the_literature_until_scored(tmp_path, monkeypatch):
    """A blind test hides the place, refuses literature and record lookups for its area, and opens them once scored."""
    from dighouse import answers, ledger

    monkeypatch.setenv("DIGHOUSE_CACHE", str(tmp_path / "cache"))
    started = server.start_test(str(tmp_path), "borre")
    root = started["project"]
    assert "borre" not in root.lower() and "Borre" not in started["name"] + started["question"]
    p = Project(root)
    assert "Borre" not in p.path("PROJECT.md").read_text()
    assert "blind_test" in server.run_status(root)
    w, s, e, n = started["box"]
    for call in (lambda: server.search_literature(root, "burial mounds"), lambda: server.read_source(root, "https://example.org"),
                 lambda: server.log_source(root, "all", "A book", "read", "x"), lambda: server.survey_area(w, s, e, n),
                 lambda: server.find_gaps(w, s, e, n), lambda: server.search_records("mound", w, s, e, n)):
        with pytest.raises(Exception, match="blind test"):
            call()

    k = answers.key("borre")
    counted = [f for f in k["features"] if f["expect"]]
    ledger.create(p, "Large mound", "t", (counted[0]["lon"], counted[0]["lat"]), "round", "model-a")
    ledger.create(p, "Low rise", "t", (w + 0.0001, s + 0.0001), "low", "model-a")
    out = server.score_test(root)
    assert out["found"] == 1 and out["known"] == len(counted) and out["extra"] == ["C-002"]
    assert not answers.is_blind(p) and "blind_test" not in server.run_status(root)
    text = p.path("RESEARCH.md").read_text()
    assert "## Blind test" in text and f"1 of {len(counted)}" in text and "Borre" in text
    assert str(counted[0]["lat"])[:7] not in text and str(counted[0]["lon"])[:7] not in text
    assert not answers.blind_box(started["box"])
    written = server.write_report(root)
    report = p.path(written["written"]).read_text()
    assert "1 of" in report and "not in the key" in report and written["words"] <= 400


def test_quick_look_prefers_a_ready_made_ground_model():
    """A quick look takes a national ground model first, then USGS, then OpenTopography, and its square is the size asked."""
    from dighouse import quicklook

    rows = [{"id": "ot:X", "source": "OpenTopography"}, {"id": "usgs:Y"}, {"id": "uk:ea-dtm-1m", "ready_made_ground_model": True}, {"errors": ["x"]}]
    assert quicklook._choose(rows)["id"] == "uk:ea-dtm-1m"
    assert quicklook._choose(rows[:2])["id"] == "usgs:Y"
    assert quicklook._choose([{"errors": []}]) is None
    w, s, e, n = quicklook._box(10.0, 59.0, 200)
    assert abs((n - s) * 110_540 - 400) < 1 and abs((e - w) * 111_320 * math.cos(math.radians(59)) - 400) < 1


def test_a_poor_calibration_stops_the_search(tmp_path, monkeypatch, survey):
    """A calibration test that finds too little blocks marking finds, and the record says why; a good one does not."""
    from dighouse import answers, ledger

    monkeypatch.setenv("DIGHOUSE_CACHE", str(tmp_path / "cache"))
    assert answers.calibration_site([-83.1, 39.3, -83.0, 39.4], "usgs:X")["site"] in ("mound-city", "serpent-mound")
    root = str(tmp_path / "search")
    server.init_project(root, "Search", "Anything here?", *survey["bbox"])
    p = Project(root)
    monkeypatch.setattr(answers, "on_record_near", lambda *a, **k: [])

    poor = server.start_test(str(tmp_path), "cahokia")["project"]
    server.score_test(poor)  # no finds at all: 0 of 1
    out = server.record_calibration(root, poor)
    assert out["passed"] is False and out["found"] == 0
    p.save("tiles", {"t-r000c000": {"terrain": "t", "window": [0, 0, 10, 10], "status": "screened"}})
    with pytest.raises(Exception, match="calibration"):
        server.flag_candidate(root, "t-r000c000", 0.5, 0.5, "Mound", "Guide: burial mound.", "m")
    assert "## Calibration" in p.path("RESEARCH.md").read_text() and "stopped" in p.path("RESEARCH.md").read_text()
    assert server.run_status(root)["calibration"]["passed"] is False

    good = server.start_test(str(tmp_path), "cahokia")["project"]
    monks = answers.key("cahokia")["features"][0]["lines"][0][0]
    ledger.create(Project(good), "Big mound", "t", (monks[0], monks[1]), "", "m")
    server.score_test(good)
    assert server.record_calibration(root, good)["passed"] is True
    answers.guard_calibration(p)  # no longer raises


def test_blind_map_check_names_nothing():
    """In a blind test the map check gives kinds of things, never their names."""
    from dighouse import checks

    els = [{"type": "way", "id": 1, "tags": {"highway": "service", "name": "City Mound access road"}},
           {"type": "way", "id": 2, "tags": {"building": "yes", "name": "Visitor Center"}},
           {"type": "node", "id": 3, "tags": {"historic": "archaeological_site", "name": "Mound City Group"}}]
    named, blind = checks._sort(els), checks._sort(els, named=False)
    assert "Visitor Center" in named["buildings"] and "City Mound access road" in named["roads"]
    assert json.dumps(blind).count("Mound") == 0 and "Visitor" not in json.dumps(blind)
    assert blind["roads"] == ["service"] and blind["buildings"] == ["a building"]


def test_mound_finder_measures_small_round_mounds():
    """Two small domes on a slope are found with their size; a long bank and a flat field are not."""
    from dighouse import mounds

    y, x = np.mgrid[0:200, 0:200].astype(float)
    dtm = 50 + 0.05 * x  # a gentle slope, 1 m cells
    for cx, cy, r, h in ((50, 50, 4, 0.6), (140, 120, 8, 1.2)):
        d = np.hypot(x - cx, y - cy) / r
        dtm += h * np.clip(1 - d ** 2, 0, None)
    dtm += 0.5 * np.clip(1 - np.abs(y - 170) / 3, 0, None) * ((x > 20) & (x < 180))  # a long bank
    found = mounds.bumps(dtm, 1.0, min_h=0.3)
    near = lambda cx, cy: [b for b in found if abs(b["col"] - cx) <= 2 and abs(b["row"] - cy) <= 2]
    assert near(50, 50) and near(140, 120)
    assert 5 <= near(50, 50)[0]["diameter_m"] <= 10 and near(140, 120)[0]["height_m"] > 0.8
    assert not [b for b in found if abs(b["row"] - 170) <= 3]

def test_parallel_verdicts_and_finds_are_all_kept(tmp_path):
    """Agents look at tiles in parallel. Verdicts and finds made at the same moment must all land, in a readable file."""
    from concurrent.futures import ThreadPoolExecutor
    from dighouse import ledger, tiles
    p = Project.create(tmp_path / "par", "Parallel check", "Is the bank built?", [0.0, 51.0, 0.01, 51.01])
    p.save("tiles", {f"t{i:02d}": {"status": "unscreened"} for i in range(40)})
    with ThreadPoolExecutor(16) as pool:
        list(pool.map(lambda i: tiles.record_verdict(p, f"t{i:02d}", "natural", "", "test"), range(40)))
        made = list(pool.map(lambda i: ledger.create(p, f"Find {i}", "t00", (0.001 * i, 51.0), "", "test")["id"], range(12)))
    assert all(t["status"] == "screened" for t in p.load("tiles").values())
    assert len(set(made)) == 12 and len(p.load("locations")) == 12

def test_a_service_that_needs_a_token_says_so(tmp_path, monkeypatch):
    """Denmark's ground model needs a free token: without one the data finder says where to get it, and with one it is read."""
    from dighouse import national
    monkeypatch.delenv("DIGHOUSE_DATAFORSYNINGEN_TOKEN", raising=False)
    monkeypatch.setenv("DIGHOUSE_KEYS", str(tmp_path / "keys.json"))
    box = [11.26, 55.39, 11.27, 55.40]
    dk = [d for d in national.find(box) if d["id"] == "dk:dhm-terraen"][0]
    assert dk["needs_token"] and not dk["ready_made_ground_model"] and "Settings" in dk["about"]
    with pytest.raises(ValueError, match="free token"):
        national.fetch_dtm("dk:dhm-terraen", box)
    (tmp_path / "keys.json").write_text(json.dumps({"dataforsyningen": " abc123 "}))
    assert national.access_key("dataforsyningen") == "abc123"
    assert [d for d in national.find(box) if d["id"] == "dk:dhm-terraen"][0]["ready_made_ground_model"]

def test_every_new_project_gets_its_own_folder_and_repository(tmp_path, monkeypatch):
    """A bare name goes in the projects folder, a used folder is never reused, and each project starts as a git repo."""
    import subprocess
    monkeypatch.setenv("DIGHOUSE_PROJECTS_HOME", str(tmp_path / "home"))
    first = server.init_project("hill", "Hill", "What is on the hill?", 0.0, 51.0, 0.01, 51.01)["project"]
    second = server.init_project("hill", "Hill again", "And now?", 0.0, 51.0, 0.01, 51.01)["project"]
    assert first == str((tmp_path / "home" / "hill").resolve()) and second.endswith("hill-2")
    assert "Hill" in (Path(first) / "PROJECT.md").read_text() and "Hill again" in (Path(second) / "PROJECT.md").read_text()
    for root in (first, second):
        for part in ("PROJECT.md", "METHODOLOGY.md", "notes", "candidates", "sources", "reports", ".gitignore"):
            assert (Path(root) / part).exists(), part
        log = subprocess.run(["git", "-C", root, "log", "--oneline"], capture_output=True, text=True).stdout.splitlines()
        tracked = subprocess.run(["git", "-C", root, "ls-files"], capture_output=True, text=True).stdout
        assert len(log) == 1 and "private/" not in tracked and "data/" not in tracked


def test_offering_a_project_makes_nothing(tmp_path, monkeypatch):
    """suggest_project only describes the project for the person's card; the folder appears when they press it."""
    monkeypatch.setenv("DIGHOUSE_PROJECTS_HOME", str(tmp_path / "home"))
    offer = server.suggest_project("Hill", "What is on the hill?", "A wooded hill with no recorded sites.", "",
                                   0.0, 51.0, 0.01, 51.01)
    assert offer["offered"] and offer["box"] == [0.0, 51.0, 0.01, 51.01] and offer["why_here"].startswith("A wooded")
    assert server.suggest_project("Hill", "What is on the hill?", place="Box Hill")["box"] is None
    with pytest.raises(ValueError):
        server.suggest_project("Hill", "What is on the hill?")
    assert not (tmp_path / "home").exists()


def test_a_chat_becomes_the_projects_first_records(tmp_path):
    """What the chat settled is written into the layout and committed, with coordinates taken out."""
    import subprocess
    root = server.init_project(str(tmp_path / "hill"), "Hill", "What is on the hill?", 0.0, 51.0, 0.01, 51.01)["project"]
    server.start_from_chat(root, "Choosing a hill", "Open lidar and only one recorded barrow.",
                           ["Smith 1990, Barrows of the Downs, https://example.org/smith: lists one barrow on the hill",
                            "Survey of the Downs, https://doi.org/10.5069/G9VT1Q1G: the lidar"],
                           ["The next valley: already surveyed in 2004"],
                           "**Person:** What about the hill at 51.00512, 0.00733?\n\n**Agent:** It has open lidar.")
    project_md = (Path(root) / "PROJECT.md").read_text()
    assert "## Why this area" in project_md and project_md.index("## Why this area") < project_md.index("## Rules for agents")
    note = next((Path(root) / "notes").glob("*-started-from-chat.md")).read_text()
    assert "The next valley" in note and "Smith 1990" in note and "51.00512" not in note and "kept private" in note
    assert "https://doi.org/10.5069/G9VT1Q1G" in note
    assert "Smith 1990" in (Path(root) / "sources" / "read-log.md").read_text()
    assert "started-from-chat" in (Path(root) / "notes" / "INDEX.md").read_text()
    log = subprocess.run(["git", "-C", root, "log", "--format=%s"], capture_output=True, text=True).stdout
    assert log.splitlines()[0] == "Started from chat: Choosing a hill"
    research = server.document_project(root) and (Path(root) / "RESEARCH.md").read_text()
    assert "Read in the chat that started the project" in research and "](notes/" in research


def test_github_only_when_asked_and_never_inside_a_repository_or_icloud(tmp_path, monkeypatch):
    """Offers go in the projects folder unless the person asked for GitHub; a taken name gets a number; a folder in an
    existing repository or in iCloud is refused."""
    import subprocess
    monkeypatch.setenv("DIGHOUSE_PROJECTS_HOME", str(tmp_path / "home"))
    monkeypatch.setenv("DIGHOUSE_GITHUB_HOME", str(tmp_path / "GitHub"))
    (tmp_path / "GitHub" / "hill").mkdir(parents=True)
    (tmp_path / "GitHub" / "hill" / "README.md").write_text("someone's repo")
    assert server.suggest_project("Hill", "q", place="Box Hill")["folder"] == str((tmp_path / "home" / "hill").resolve())
    assert server.suggest_project("Hill", "q", place="Box Hill", work_in_github=True)["folder"].endswith("GitHub/hill-2")
    subprocess.run(["git", "init", "-q", str(tmp_path / "GitHub" / "hill")], check=True)
    with pytest.raises(ValueError, match="inside the repository"):
        server.init_project(str(tmp_path / "GitHub" / "hill" / "sub"), "Hill", "q", 0.0, 51.0, 0.01, 51.01)
    monkeypatch.setenv("HOME", str(tmp_path))
    (tmp_path / "Library" / "Mobile Documents" / "com~apple~CloudDocs" / "Documents").mkdir(parents=True)
    with pytest.raises(ValueError, match="iCloud"):
        server.init_project(str(tmp_path / "Documents" / "hill"), "Hill", "q", 0.0, 51.0, 0.01, 51.01)


def test_publishing_is_checked_for_locations(tmp_path):
    """A project is ready to publish only when private/ and data/ stay out and no shared file holds a coordinate."""
    root = server.init_project(str(tmp_path / "hill"), "Hill", "q", 0.0, 51.0, 0.01, 51.01)["project"]
    (Path(root) / "sources" / "read-log.md").write_text("- Smith 1990, https://doi.org/10.2307/503404, doi:10.1179/mca.2013.008\n")
    assert server.check_before_publishing(root) == {"ready": True, "problems": [], "remote": ""}
    (Path(root) / "notes" / "slip.md").write_text("The mound is at 39.02541, -83.43012.\n")
    from dighouse.project import commit
    commit(Path(root), "A note with a location in it")
    problems = server.check_before_publishing(root)["problems"]
    assert problems == ["notes/slip.md, line 1, looks like it holds a coordinate."]


def test_a_refused_second_opinion_is_on_the_record(tmp_path):
    """When the second model cannot answer, the record and the report say it was asked, and what to do; it is not counted."""
    from dighouse import ledger, record, report
    p = Project.create(tmp_path / "refused", "Refused", "Is the bank built?", [0.0, 51.0, 0.01, 51.01])
    cid = ledger.create(p, "Low bank", "t1-r000c000", (0.005, 51.005), "A straight low bank", "model-a")["id"]
    server.second_look_failed(str(p.root), cid, "Other model", "403: this service has been disabled")
    todo = record.document(p)["still_to_do"]
    assert any("could not be answered" in t and "Settings, Models" in t for t in todo)
    assert "asked, no answer" in p.path("RESEARCH.md").read_text()
    assert "second_look" not in ledger.get(p, cid)[0]["checks"]
    report.write(p) if hasattr(report, "write") else server.write_report(str(p.root))
    text = next(p.path("reports").glob("*-search-report.md")).read_text()
    assert "asked Other model" in text and "could not answer" in text


def test_shizuoka_map_sheets_are_named_and_none_is_skipped():
    """Japan's 300 by 400 m sheets in zone VIII: a point gets its published name, and a box across sheet borders gets every
    sheet it touches (Yamanaka Castle's sheet is 08NF1172 in the 2019 survey)."""
    from dighouse import national
    assert national._shizuoka_sheets(45100, -95200, 45110, -95190) == ["08NF1172"]
    assert sorted(national._shizuoka_sheets(44750, -95250, 45100, -94950)) == ["08NF1161", "08NF1162", "08NF1171", "08NF1172"]



def test_original_figure_and_project_evidence(tmp_path, monkeypatch):
    import io
    import httpx
    from PIL import Image

    root = str(tmp_path / "figure-test")
    server.init_project(root, "Figure test", "Is the plan usable?", 0, 0, .001, .001)
    p = Project(root)
    pdf = io.BytesIO()
    Image.new("RGB", (80, 50), "orange").save(pdf, format="PDF")
    url = "https://example.org/field-plan.pdf"
    monkeypatch.setattr(checks, "_source_response", lambda _: httpx.Response(200, content=pdf.getvalue()))
    folder = p.path("private", "source-pdfs")
    assert checks.read_source(url, folder=folder)["pages"] == 1
    monkeypatch.setattr(checks, "_source_response", lambda _: pytest.fail("Fetched a cached original"))
    info, png = checks.source_page(folder, url, 1)
    assert info["page"] == 1 and Image.open(io.BytesIO(png)).format == "PNG"
    with pytest.raises(ValueError, match="from 1 to 1"):
        checks.source_page(folder, url, 2)
    server.log_source(root, "project", "Field plan", "read", "Contours visible.", url, "inspected", 1)
    lesson = "Register this plan against two withheld landmarks."
    server.write_summary(root, "Map inspected.", lesson)
    p.add_lesson(lesson)
    assert p.path("METHODOLOGY.md").read_text().count(lesson) == 1
    for path in ["sources/read-log.md", "RESEARCH.md", "sources/project.json"]:
        assert "Figure inspected (PDF page 1)" in p.path(path).read_text()


def test_unmatched_calibration_is_unavailable():
    from dighouse import answers

    assert answers.calibration_site([0, 0, 1, 1], "unmatched:acquisition")["available"] is False


def test_readable_link_turns_api_addresses_into_pages():
    from dighouse.ledger import readable_link
    assert readable_link("https://api.datacite.org/dois/10.6067/xcv808676b") == "https://doi.org/10.6067/xcv808676b"
    assert readable_link("https://api.crossref.org/works/10.1016/j.jas.2020.105123") == "https://doi.org/10.1016/j.jas.2020.105123"
    assert readable_link("https://api.openalex.org/works/W2741809807") == "https://openalex.org/W2741809807"
    assert readable_link("https://api.openalex.org/works/https://doi.org/10.1/x") == "https://doi.org/10.1/x"
    assert readable_link("https://www.mesoweb.com/a.pdf#page=7") == "https://www.mesoweb.com/a.pdf#page=7"
    assert readable_link("") == ""


def test_sources_refuse_this_mac_and_private_networks():
    import pytest
    from dighouse import checks
    for url in ("http://127.0.0.1:8080/", "http://localhost/", "http://10.0.0.1/", "http://169.254.169.254/", "file:///etc/passwd"):
        with pytest.raises(RuntimeError):
            checks._source_response(url)


def test_read_source_refuses_an_address_carrying_the_projects_location(tmp_path):
    import pytest
    from dighouse import server
    from dighouse.project import Project
    p = Project.create(tmp_path / "p", "Test", "Q", [-90.1, 38.6, -90.0, 38.7])
    with pytest.raises(ValueError, match="coordinates"):
        server._no_location_in(p, "https://example.org/collect?lat=38.6612&lon=-90.0543")
    server._no_location_in(p, "https://doi.org/10.1016/j.jas.2020.105123")


def test_shape_tells_a_mound_from_a_tree_throw_and_openness_lights_both():
    import numpy as np
    from dighouse import mounds, terrain as T
    res = 0.5
    yy, xx = np.mgrid[:160, :160]
    d = np.hypot(yy - 80, xx - 80) * res
    mound = np.where(d < 6, 0.8 * (1 - (d / 6) ** 2), 0.0).astype(np.float32)
    throw = mound.copy()
    dp = np.hypot(yy - 80, xx - 100) * res
    throw -= np.where(dp < 3, 0.6 * (1 - (dp / 3) ** 2), 0.0).astype(np.float32)
    gap = np.zeros_like(mound)
    a = mounds.shape(mound, gap, res, 80, 80, 12)
    b = mounds.shape(throw, gap, res, 80, 80, 12)
    assert a["hints"] == ["a coherent, round rise"] and a["symmetry"] > 0.8
    assert any("tree throw" in h for h in b["hints"])
    pos, neg = T.openness(throw, res)
    assert pos[80, 80] > pos[80, 20] and neg[80, 100] > neg[80, 20]
    pond = -mound
    c = mounds.shape(pond, gap, res, 80, 80, 12)
    assert any("hollow" in h for h in c["hints"]) and c["rank"] == 0


def test_measured_rises_go_on_possible_tiles_and_skip_existing_finds(tmp_path):
    import numpy as np
    from dighouse import server, terrain as T
    from dighouse.project import Project
    p = Project.create(tmp_path / "p", "T", "Q", [-90.1, 38.6, -90.09, 38.61])
    res = 1.0
    yy, xx = np.mgrid[:200, :200]
    dtm = np.zeros((200, 200), np.float32)
    for cy, cx in ((50, 50), (150, 150)):
        d = np.hypot(yy - cy, xx - cx) * res
        dtm += np.where(d < 6, 1.0 * (1 - (d / 6) ** 2), 0).astype(np.float32)
    gap = np.zeros_like(dtm); out = np.zeros_like(dtm, dtype=bool)
    T.save_terrain(p.path("data", "t.tif"), dtm, gap, out, 0, 200, res, 32616) if hasattr(T, "save_terrain") else None
    if not p.path("data", "t.tif").exists():
        import pytest; pytest.skip("no terrain writer")
    p.save("terrains", {"t": {"file": "data/t.tif", "res": res, "box": [0, 0, 200, 200], "epsg": 32616, "area_km2": 0.04}})
    p.save("tiles", {"t-a": {"terrain": "t", "window": [0, 0, 100, 100], "status": "screened", "verdict": "possible"},
                     "t-b": {"terrain": "t", "window": [100, 100, 100, 100], "status": "screened", "verdict": "nothing"}})
    got = server.measured_rises(p, 1000, verdicts=("possible", "built"))
    assert len(got) == 1 and got[0]["tile"] == "t-a"
    assert server.measured_rises(p, 1000, verdicts=("possible", "built"), exclude={"C-001": {"lon": got[0]["lon"], "lat": got[0]["lat"]}}) == []
    # By default every tile looked at counts, so the rise on the tile called nothing is listed too.
    assert {m["tile"] for m in server.measured_rises(p, 1000)} == {"t-a", "t-b"}
    # Ground that already has its measured rises is skipped, so a project searched area by area does not fill again.
    assert server.measured_rises(p, 1000, skip_terrains={"t"}) == []
    added = server.add_measured_rises(str(p.root), 1000)["count"]
    assert added == 2 and server.add_measured_rises(str(p.root), 1000)["count"] == 0


def test_projects_never_land_in_tmp(tmp_path, monkeypatch):
    """A blind test asked for in /tmp goes to the projects folder instead; an ordinary folder is kept."""
    from dighouse.project import lasting_folder
    monkeypatch.setenv("DIGHOUSE_PROJECTS_HOME", str(tmp_path / "home"))
    assert lasting_folder("/tmp/dighouse-calibration") == tmp_path / "home"
    assert lasting_folder("/private/tmp") == tmp_path / "home"
    assert lasting_folder(tmp_path / "mine") == (tmp_path / "mine").resolve()


def test_calibration_waits_for_a_named_region(tmp_path):
    """A session's project starts with no area; calibration must not pick the known site nearest to 0, 0."""
    import pytest
    root = str(tmp_path / "session")
    server.init_project(root, "Search on its own, 23 Nov", "To be named", 0, 0, 0, 0)
    with pytest.raises(ValueError, match="name_project"):
        server.start_calibration(str(tmp_path), root, "usgs:OH_Statewide_Phase2_4_2020")

def test_os_grid_names():
    """Scotland's sheets are named by Ordnance Survey grid reference; a wrong letter reads the wrong place silently."""
    from dighouse import national
    assert national._os_name(120_500, 804_500, 2) == "NG2004"
    assert national._os_name(358_100, 674_600, 2) == "NT5874"
    assert national._os_name(316_500, 666_500, 1) == "NT16"
    assert national._os_name(390_000, 1_010_000, 1) == "HY91"

def test_shizuoka_sheets_in_both_layouts():
    """Older sheets are "x y z"; newer ones are "n,x,y,z,flag". Reading the newer as the older failed every fetch there."""
    from dighouse import national
    old = national._xyz("-11599.75 -109500.25 53.60\n-11599.25 -109500.25 53.70\n")
    new = national._xyz("1,-11599.75,-109500.25,53.60,1\n2,-11599.25,-109500.25,53.70,1\n")
    assert old.shape == new.shape == (2, 3) and np.allclose(old, new)


def test_funnel_counts_what_reaches_a_person(tmp_path):
    """The funnel FIND_LOOP is judged by: finds, those put to a person, decided, and answered."""
    from dighouse import funnel
    root = str(tmp_path / "f")
    server.init_project(root, "Funnel", "Does the funnel count?", -83.0, 39.0, -82.99, 39.01)
    row = funnel.funnel(root)
    assert row["finds"] == row["to_a_person"] == row["decided"] == row["answered"] == 0 and not row["blind_test"]
    assert funnel.totals([row])["projects"] == 1

def test_a_closer_look_takes_over_a_bulk_find(tmp_path, survey):
    """The agent marks every shape on a shortlisted tile; one the bulk look opened keeps one record, at the agent's place."""
    from dighouse import ledger, tiles as T
    root = str(tmp_path / "proj")
    server.init_project(root, "Synthetic", "q", *survey["bbox"])
    p = Project(root)
    terrain = server.fetch_terrain(root, "usgs:synthetic", *survey["bbox"])["terrain"]
    server.make_tiles(root, terrain, tile_m=100)
    tile, fx, fy = tile_at(p, survey["mound_xy"])
    ledger.create(p, "Seen in bulk: a mound", tile, T.tile_lonlat(p, tile, fx + 0.02, fy), "", "seen in bulk by m")
    server.flag_candidate(root, tile, fx, fy, "Mound", "Guide: burial mound.", "agent")
    records = ledger.everything(p)
    assert len(records) == 1 and records[0]["flagged_by"] == "agent" and records[0]["name"] == "Mound"
    assert abs(p.load("locations")["C-001"]["x"] - fx) < 1e-9

def test_a_find_inside_a_recorded_area_is_on_it():
    """England's and Denmark's registers map areas; a find inside one is on it however far its middle is."""
    from dighouse import answers
    ring = [[0.0, 0.0], [0.01, 0.0], [0.01, 0.01], [0.0, 0.01], [0.0, 0.0]]
    site = {"lon": 0.005, "lat": 0.005, "ring": ring}
    assert answers._metres_to(site, 0.009, 0.009) == 0.0
    assert 100 < answers._metres_to(site, 0.012, 0.005) < 400


def test_which_registers_cover_a_place():
    """A register is named only where it can be read; elsewhere a find's record must say the records were not read."""
    from dighouse import discover, ledger
    assert [r["register"] for r in discover.covering_registers(9.8, 56.2)] == ["Fund og Fortidsminder"]
    assert discover.covering_registers(-82.9, 39.3) == []
    words = ledger.records_words({"date": "2026-11-23", "reach_m": 120, "answered": ["OpenStreetMap"], "silent": [], "registers": [], "near": []})
    assert "not read" in words and "nothing within 120 m" in words

def test_the_second_opinion_pictures_ring_the_find(tmp_path, survey):
    """Without the router, the chat path hands a model the same ringed tile the router path sends."""
    from pathlib import Path
    root = str(tmp_path / "proj")
    server.init_project(root, "Synthetic", "q", *survey["bbox"])
    p = Project(root)
    terrain = server.fetch_terrain(root, "usgs:synthetic", *survey["bbox"])["terrain"]
    server.make_tiles(root, terrain, tile_m=100)
    tile, fx, fy = tile_at(p, survey["mound_xy"])
    server.flag_candidate(root, tile, fx, fy, "Mound", "note", "model-a")
    got = server.opinion_pictures(root, "C-001")
    assert len(got["pictures"]) == 2 and all(Path(f).stat().st_size > 1000 for f in got["pictures"])
    assert "ring" in got["question"] and all("/data/views/" in f for f in got["pictures"])

def test_who_to_tell_names_the_office_and_whether_its_record_is_open():
    """A report goes to the body that keeps the record; where that record is closed, the person is told to ask it."""
    from dighouse import authorities
    norway = authorities.who_to_tell(10.47, 59.38)
    assert norway["country"] == "Norway" and norway["records_open"] and "fylkeskommunen" in norway["tell"]
    ohio = authorities.who_to_tell(-82.9, 39.3)
    assert not ohio["records_open"] and "SHPO" in ohio["tell"] and "not open" in ohio["records"]
    assert "public" in ohio["before_sending"]


def test_points_are_kept_once_and_the_cache_drops_only_what_no_project_holds(tmp_path, monkeypatch):
    """A project's points are a link to the cache's copy; trimming the cache never takes a project's points."""
    import os
    monkeypatch.setenv("DIGHOUSE_CACHE", str(tmp_path / "cache"))
    pts = sources.Points(np.arange(5000.0), np.arange(5000.0), np.ones(5000), np.full(5000, 2, np.uint8), 32617)
    held, old, new = ([0, 0, 1, 1], 0.35), ([2, 2, 3, 3], 0.35), ([4, 4, 5, 5], 0.35)
    for i, (box, spacing) in enumerate((held, old, new)):
        f = sources.kept_points("usgs:x", box, spacing)
        f.parent.mkdir(parents=True, exist_ok=True)
        pts.save(f)
        os.utime(f, (1000 + i, 1000 + i))
    dest = tmp_path / "proj" / "data" / "points" / "a.npz"
    sources.keep_in_project(pts, "usgs:x", *held, dest)
    assert os.path.samefile(dest, sources.kept_points("usgs:x", *held))
    size = dest.stat().st_size
    sources.trim_points_cache(limit_gb=size * 1.5 / 1e9)
    assert dest.exists() and sources.kept_points("usgs:x", *held).exists()
    assert not sources.kept_points("usgs:x", *old).exists() and sources.kept_points("usgs:x", *new).exists()


def test_a_register_is_asked_only_where_it_reaches(monkeypatch):
    """A find in Arizona is not said to have been checked against Denmark's or Norway's register."""
    from dighouse import discover
    asked = []
    monkeypatch.setattr(discover, "SITE_READERS", {n: (lambda b, n=n: asked.append(n) or []) for n in discover.SITE_READERS})
    discover.recorded_sites([-112.2, 34.2, -112.18, 34.22])
    assert "National Register of Historic Places" in asked and "OpenStreetMap" in asked
    assert not {"Fund og Fortidsminder", "Norway's heritage register", "Navarre's heritage register", "National Heritage List for England"} & set(asked)
    asked.clear()
    discover.recorded_sites([10.4, 59.3, 10.5, 59.4])
    assert "Norway's heritage register" in asked and "National Register of Historic Places" not in asked
    assert "Fund og Fortidsminder" not in discover._answered([], [10.4, 59.3, 10.5, 59.4])


def test_a_calibration_is_judged_on_the_last_few_tests_of_its_site(tmp_path, monkeypatch, survey):
    """One test varies by a few features, so the gate pools the last tests of the same site on the same lidar."""
    from dighouse import answers
    monkeypatch.setenv("DIGHOUSE_CACHE", str(tmp_path / "cache"))
    monkeypatch.setattr(answers, "on_record_near", lambda *a, **k: [])
    root = str(tmp_path / "search")
    server.init_project(root, "Search", "Anything here?", *survey["bbox"])
    answers._scores_file().write_text(json.dumps([{"site": "cahokia", "sources": [], "found": 1, "known": 1,
                                                   "scored": "2026-11-23", "test": f"earlier-{i}"} for i in range(3)]))
    poor = server.start_test(str(tmp_path), "cahokia")["project"]
    server.score_test(poor)  # 0 of 1 this time
    out = server.record_calibration(root, poor)
    assert out["found"] == 0 and out["pooled_tests"] == 4 and out["pooled_share"] == 0.75 and out["passed"] is True
    assert "75% over the last 4 tests" in Project(root).path("notes").joinpath(f"{__import__('datetime').date.today()}.md").read_text()
