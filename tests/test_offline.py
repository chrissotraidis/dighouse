"""The whole chain on synthetic data: fetch, tile, screen, flag, section, checks, statuses."""

import json
import math
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
    assert "Slice: 0.8 m high, in the ground" in text and "Second model: has not looked" in text
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
    assert set(ks) == {"angel-mounds", "mound-city", "serpent-mound", "cahokia", "maiden-castle", "borre"}
    for k in ks.values():
        w, s, e, n = k["box"]
        assert k["sources"] and k["published"] and k["coverage"] in ("register", "partial")
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
