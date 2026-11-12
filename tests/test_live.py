"""Checks against the real services. Run with: pytest -m live"""

import json

import pytest

from dighouse import server

pytestmark = pytest.mark.live

MONKS_MOUND = [-90.0638, 38.6592, -90.0604, 38.6620]  # Cahokia, Illinois: a published earthwork about 30 m high


def test_find_data_sees_both_sources():
    ids = [d.get("id") for d in server.find_data(-89.0, 18.4, -88.6, 18.7)]
    assert any(i and i.startswith("ot:") for i in ids)
    ids = [d.get("id") for d in server.find_data(*MONKS_MOUND)]
    assert any(i and i.startswith("usgs:") for i in ids)


def test_monks_mound_is_found_in_the_ground(tmp_path):
    root = str(tmp_path / "cahokia")
    server.init_project(root, "Cahokia check", "Does a known mound show up?", *MONKS_MOUND)
    dataset = next(d["id"] for d in server.find_data(*MONKS_MOUND) if d.get("id", "").startswith("usgs:"))
    got = server.fetch_terrain(root, dataset, *MONKS_MOUND)
    assert got["ground_points"] > 50_000
    server.make_tiles(root, got["terrain"], tile_m=400)
    tile = server.next_tiles(root, 1)[0]
    stats = json.loads(server.cut_section(root, tile, 0.5, 0.05, 0.5, 0.95)[0])
    assert stats["feature_height_m"] > 15 and stats["in_ground"]


def test_discovery_tools_answer():
    places = server.find_place("Cahokia Mounds State Historic Site")
    assert places and abs(places[0]["lat"] - 38.65) < 0.1
    surveys = server.open_surveys()
    assert any("Yucatan" in s["title"] and s["fetchable_without_account"] for s in surveys)
    area = server.survey_area(-90.2, 38.5, -89.9, 38.8)
    assert any(d["id"].startswith("usgs:") for d in area["open_lidar"])
    assert any("Cahokia" in site["name"] for site in area["known_sites"]["nearest"])

def test_sources_can_be_found_and_read(tmp_path):
    root = str(tmp_path / "reading")
    server.init_project(root, "Reading check", "Can a source be opened?", *MONKS_MOUND)
    found = server.search_literature(root, "Cahokia Monks Mound lidar")
    assert found and any(work["abstract"] for work in found)
    page = server.read_source(root, "https://en.wikipedia.org/wiki/Monks_Mound")
    assert "Cahokia" in page["text"] and page["more_from"]
    paper = server.read_source(root, "https://arxiv.org/pdf/1706.03762")
    assert paper["characters"] > 10_000 and "attention" in paper["text"].lower()


def test_the_tools_can_say_where_to_look():
    region = [-90.35, 38.5, -89.8, 38.85]   # around Cahokia
    gaps = server.find_gaps(*region)
    assert gaps["cells_with_open_lidar"] > 0 and gaps["sites_on_open_record"] > 5
    assert all(cell["open_lidar"] for cell in gaps["ranked"])
    assert len({site["source"] for site in server.survey_area(*region)["known_sites"]["nearest"]}) >= 2
    found = server.search_records("mound", *region)
    assert found["total"] > 0 and found["records"][0]["project"]
    assert any(r["read_by"] == "search_records" for r in server.open_resources())
    assert server.open_resources("lidar")[0]["kind"] == "lidar"

def test_map_sites_come_from_qlever_without_overpass():
    from dighouse import discover
    for _ in range(3):
        sites = discover._osm_qlever([-83.6, 39.0, -82.6, 39.6])   # Ross County, Ohio
        assert len(sites) > 10 and any("Mound" in s["name"] for s in sites)
        assert all(s["record"].startswith("https://www.openstreetmap.org/") for s in sites)
