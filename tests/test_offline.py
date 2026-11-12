"""The whole chain on synthetic data: fetch, tile, screen, flag, section, checks, statuses."""

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
