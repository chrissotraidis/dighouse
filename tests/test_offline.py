"""The whole chain on synthetic data: fetch, tile, screen, flag, section, checks, statuses."""

import json
from pathlib import Path

import pytest

from dighouse import checks, server
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

    # nothing may be claimed before the checks exist
    with pytest.raises(ValueError, match="no section"):
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

    monkeypatch.setattr(checks, "modern_features", lambda lon, lat, r: {
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

    monkeypatch.setattr(checks._client, "post", down)
    monkeypatch.setattr(checks.time, "sleep", lambda seconds: None)
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
    got = server.check_modern(root, "C-001")
    assert got["mapped_features_within_radius"] == 1 and got["historic_within_2km"] == ["Old Fort"]
    assert ledger.get(p, "C-001")[0]["checks"]["modern"]["likely_modern"] is True


def test_a_refused_page_says_to_log_it(monkeypatch):
    """A publisher that refuses a program gives a message the agent can act on, not a stack of library errors."""
    class Refused:
        status_code = 403
        headers = {"content-type": "text/html"}
        text = "Forbidden"
        content = b"Forbidden"
        url = "https://example.org/paper"

    monkeypatch.setattr(checks._client, "get", lambda *args, **kwargs: Refused())
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
    assert any("Screen 1 tile" in t for t in out["still_to_do"])
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
    assert "already screened" in out["still_to_do"][-1]
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
    assert any("Screen 1 tile" in t for t in after["still_to_do"])


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
    assert got["waiting_for_a_person"] == [cid] and got["words"] < 500
    for heading in ("What was asked", "The data used", "What was looked at", "What was flagged, and why", "What is already published",
                    "What was ruled out", "What needs your decision", "What to try next"):
        assert f"## {heading}" in text
    assert "Is the bank built?" in text and "TEST_2020" in text and "2 of 2" in text and "1 looked built, 1 natural" in text
    assert "A straight low bank across the slope" in text and "measured 0.8 m, in the ground" in text and "no second model has looked yet" in text
    assert "A county survey, 1998" in text and "https://example.org/survey" in text
    assert "1 tile showed natural ground." in text
    assert "The agent suggests: already published." in text and "Try the sky view on the next tile north." in text
    assert "51.00" not in text and "new" not in text.lower().replace("nothing here is called new", "")
    assert f"reports/{p.path(got['written']).name}" in p.path("RESEARCH.md").read_text()

    # A decision changes the report, and rebuilding it the same day keeps the agent's advice.
    server.set_status(root, cid, "already_published", decided_by="Chris", reason="In the county survey.")
    again = p.path(server.write_report(root)["written"]).read_text()
    assert "Nothing. 1 find has been decided" in again and "Try the sky view on the next tile north." in again


def test_a_stopped_run_is_on_the_record(tmp_path):
    """When a person stops a run, the record says when and during what, until a run finishes after it."""
    root = str(tmp_path / "stop")
    p = Project.create(root, "Stop check", "Does a stop leave a trace?", [0.0, 51.0, 0.01, 51.01])
    server.document_project(root, stopped_during="Looking at the tiles")
    assert "The last run was stopped** by a person" in p.path("RESEARCH.md").read_text()
    assert "during: Looking at the tiles." in p.path("RESEARCH.md").read_text()
    server.write_summary(root, "Finished the screening.")
    assert "The last run was stopped" not in p.path("RESEARCH.md").read_text()
