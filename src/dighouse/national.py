"""National lidar published as ready-made ground models: England, the Netherlands, France, Flanders, Norway, Estonia,
Switzerland, Navarre and the Basque Country (Spain), Bavaria, Saxony, North Rhine-Westphalia, Scotland, Wales, Slovenia,
New Zealand, Denmark (with a free token) and the conterminous United States (USGS 3DEP).

These services hand out a bare-ground raster (a DTM) built by the national mapping agency,
not raw points. The terrain is as good as their ground classification; a section through it
shows the ground profile only, with no canopy to compare against.
"""

from __future__ import annotations

import io
import math
import time
from concurrent.futures import ThreadPoolExecutor

import httpx
import numpy as np
import rasterio

from . import sources

def _km_grid(step_km: int, url: str):
    """Files named by the lower-left corner of a square grid in km, such as 698_5331: the sheets covering a box."""
    def sheets(x0: float, y0: float, x1: float, y1: float) -> list[str]:
        k = step_km * 1000
        return [url.format(e=e * step_km, n=n * step_km)
                for e in range(math.floor(x0 / k), math.ceil(x1 / k)) for n in range(math.floor(y0 / k), math.ceil(y1 / k))]
    return sheets


_OS_LETTERS = "ABCDEFGHJKLMNOPQRSTUVWXYZ"  # the Ordnance Survey grid skips I


def _os_name(e: float, n: float, digits: int) -> str:
    """The Ordnance Survey grid reference of a point, such as NG2004 (digits=2, 1 km) or NG20 (digits=1, 10 km)."""
    e, n = int(e), int(n)
    e100, n100 = e // 100_000, n // 100_000
    first = (19 - n100) - (19 - n100) % 5 + (e100 + 10) // 5
    second = (19 - n100) * 5 % 25 + e100 % 5
    step = 10 ** (5 - digits)
    return f"{_OS_LETTERS[first]}{_OS_LETTERS[second]}{(e % 100_000) // step:0{digits}d}{(n % 100_000) // step:0{digits}d}"


def _scotland(base: str):
    """Scotland's open lidar, newest first for each part of a box: the National LiDAR Programme (0.5 m, 1 km sheets), then
    the earlier phases 6 to 3 (0.5 m, 5 km quarter sheets such as NS16NE) and 2 to 1 (1 m, 10 km sheets such as NS16)."""
    def cells(x0, y0, x1, y1, size):
        return [(e * size, n * size) for e in range(math.floor(x0 / size), math.ceil(x1 / size))
                for n in range(math.floor(y0 / size), math.ceil(y1 / size))]

    def sheets(x0: float, y0: float, x1: float, y1: float) -> list[str]:
        out = [f"{base}/national-lidar-programme/dtm/27700/gridded/{_os_name(e, n, 2)}_50cm_DTM_ScotlandNationalLiDAR.tif"
               for e, n in cells(x0, y0, x1, y1, 1000)]
        quarters = [_os_name(e, n, 1) + ("N" if n % 10_000 >= 5000 else "S") + ("E" if e % 10_000 >= 5000 else "W")
                    for e, n in cells(x0, y0, x1, y1, 5000)]
        out += [f"{base}/phase-{ph}/dtm/27700/gridded/{q}_50CM_DTM_PHASE{ph}.tif" for ph in (6, 5, 4, 3) for q in quarters]
        tens = [_os_name(e, n, 1) for e, n in cells(x0, y0, x1, y1, 10_000)]
        out += [f"{base}/phase-{ph}/dtm/27700/gridded/{t}_1M_DTM_PHASE{ph}.tif" for ph in (2, 1) for t in tens]
        return out
    return sheets

_TOPO50_LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ"  # New Zealand's Topo50 sheet rows skip I and O


def _topo50(url: str):
    """New Zealand Topo50 map sheets (24 km wide, 36 km tall in NZTM, such as BA31) covering a box."""
    def sheets(x0: float, y0: float, x1: float, y1: float) -> list[str]:
        out = []
        for row in range(math.floor((6_810_000 - y1) / 36_000), math.floor((6_810_000 - y0) / 36_000) + 1):
            for col in range(math.floor((x0 - 1_012_000) / 24_000) + 1, math.floor((x1 - 1_012_000) / 24_000) + 2):
                if 0 <= row < 24 * 24 and 1 <= col <= 99:
                    out.append(url.format(sheet=f"{_TOPO50_LETTERS[row // 24]}{_TOPO50_LETTERS[row % 24]}{col:02d}"))
        return out
    return sheets


NATIONAL = {
    "uk:ea-dtm-1m": {
        "publisher": "the Environment Agency (England)",
        "title": "Environment Agency lidar composite DTM, 1 m (England)",
        "source": "Environment Agency", "country": "England", "outline": [(-5.8, 50.0), (-4.2, 50.3), (-3.0, 50.6), (-1.0, 50.7), (1.4, 51.1), (1.8, 52.6), (0.3, 53.5), (-0.1, 54.5), (-1.6, 55.65), (-2.1, 55.85), (-3.1, 55.05), (-3.6, 54.5), (-3.1, 53.35), (-2.95, 52.0), (-2.65, 51.6), (-3.6, 51.2), (-4.6, 51.1), (-5.8, 50.0)],
        "epsg": 27700, "res": 1.0, "kind": "wcs", "axes": ("E", "N"), "chunk_px": 500, "parallel": 1,
        "url": "https://environment.data.gov.uk/spatialdata/lidar-composite-digital-terrain-model-dtm-1m/wcs",
        "coverage": "13787b9a-26a4-4775-8523-806d13af58fc__Lidar_Composite_Elevation_DTM_1m",
        "citation": "Contains Environment Agency information © Environment Agency and/or database right. Open Government Licence v3.0.",
        "landing_page": "https://environment.data.gov.uk/dataset/13787b9a-26a4-4775-8523-806d13af58fc",
    },
    "nl:ahn-dtm-05m": {
        "publisher": "AHN (Netherlands)",
        "title": "AHN, Actueel Hoogtebestand Nederland, DTM 0.5 m (Netherlands)",
        "source": "Rijkswaterstaat / PDOK", "country": "the Netherlands", "outline": [(3.3, 51.4), (3.4, 51.2), (5.8, 51.0), (6.0, 50.75), (6.2, 51.4), (6.9, 51.9), (7.25, 53.2), (6.9, 53.6), (4.8, 53.4), (4.5, 52.5), (3.9, 51.9), (3.3, 51.4)],
        "epsg": 28992, "res": 0.5, "kind": "wcs", "axes": ("x", "y"),
        "url": "https://service.pdok.nl/rws/ahn/wcs/v1_0", "coverage": "dtm_05m",
        "citation": "AHN, Rijkswaterstaat, via PDOK. CC0 1.0.",
        "landing_page": "https://www.ahn.nl",
    },
    "fr:lidarhd-mnt": {
        "publisher": "IGN (France)",
        "title": "IGN LiDAR HD, ground model (MNT) 0.5 m (France)",
        "source": "IGN", "country": "metropolitan France", "outline": [(-4.9, 48.4), (-1.6, 48.7), (-1.4, 49.75), (1.6, 50.95), (2.55, 51.1), (4.2, 49.95), (6.4, 49.5), (8.25, 48.95), (7.6, 47.55), (6.9, 47.35), (6.0, 46.2), (7.05, 45.9), (6.6, 45.1), (7.6, 43.8), (6.2, 43.05), (3.1, 43.0), (3.2, 42.4), (-1.8, 43.35), (-1.2, 46.0), (-2.6, 47.3), (-4.9, 48.4)],
        "epsg": 2154, "res": 0.5, "kind": "wms",
        "url": "https://data.geopf.fr/wms-r/wms", "coverage": "IGNF_LIDAR-HD_MNT_ELEVATION.ELEVATIONGRIDCOVERAGE.LAMB93",
        "citation": "IGN, LiDAR HD. Licence Ouverte Etalab 2.0.",
        "landing_page": "https://geoservices.ign.fr/lidarhd",
    },
    "be:dhmv-dtm-1m": {
        "publisher": "Digitaal Vlaanderen (Flanders)",
        "title": "Digitaal Hoogtemodel Vlaanderen II, DTM 1 m (Flanders, Belgium)",
        "source": "Digitaal Vlaanderen", "country": "Flanders", "maker": "the Flemish government",
        "outline": [(2.55, 51.09), (3.37, 51.37), (4.24, 51.37), (5.04, 51.49), (5.85, 51.16), (5.9, 50.75), (5.1, 50.71), (4.3, 50.69), (3.2, 50.71), (2.6, 50.8), (2.55, 51.09)],
        "epsg": 31370, "res": 1.0, "kind": "wcs", "axes": ("x", "y"), "chunk_px": 500, "parallel": 2,
        "url": "https://geo.api.vlaanderen.be/DHMV/wcs", "coverage": "DHMVII_DTM_1m",
        "citation": "Digitaal Hoogtemodel Vlaanderen II, Digitaal Vlaanderen. Open data of the Flemish government.",
        "landing_page": "https://www.vlaanderen.be/digitaal-vlaanderen/onze-oplossingen/earth-observation-data-science-eodas/het-digitaal-hoogtemodel/digitaal-hoogtemodel-vlaanderen-ii",
    },
    "no:nhm-dtm-1m": {
        "publisher": "Kartverket (Norway)",
        "title": "Nasjonal høydemodell, DTM 1 m (Norway)",
        "source": "Kartverket", "country": "Norway",
        "outline": [(4.6, 58.0), (7.0, 57.9), (11.8, 58.9), (12.6, 60.0), (12.2, 63.5), (14.5, 65.5), (16.5, 68.5), (20.5, 69.0), (26.0, 69.9), (31.2, 70.4), (28.0, 71.2), (20.0, 70.3), (13.5, 68.3), (10.5, 64.5), (4.8, 62.0), (4.6, 58.0)],
        "epsg": 25833, "res": 1.0, "kind": "wcs1", "chunk_px": 500, "parallel": 2,
        "url": "https://wcs.geonorge.no/skwms1/wcs.hoyde-dtm-nhm-25833", "coverage": "nhm_dtm_topo_25833",
        "citation": "Nasjonal høydemodell, © Kartverket. CC BY 4.0.",
        "landing_page": "https://hoydedata.no",
    },
    "ee:dtm-1m": {
        "publisher": "the Estonian Land Board",
        "title": "Estonian elevation model, DTM 1 m (Estonia)",
        "source": "Estonian Land and Spatial Development Board", "country": "Estonia",
        "outline": [(21.7, 57.9), (23.3, 57.5), (26.5, 57.5), (27.4, 57.5), (28.2, 59.4), (26.0, 59.7), (23.4, 59.5), (21.7, 58.9), (21.7, 57.9)],
        "epsg": 3301, "res": 1.0, "kind": "wcs", "axes": ("x", "y"), "chunk_px": 500, "parallel": 2,
        "url": "https://teenus.maaamet.ee/ows/wcs-dtm", "coverage": "dtm-1",
        "citation": "Elevation data, Estonian Land and Spatial Development Board. Open data.",
        "landing_page": "https://geoportaal.maaamet.ee/eng/Spatial-Data/Elevation-data-p308.html",
    },
    "ch:swissalti3d-05m": {
        "publisher": "swisstopo (Switzerland)",
        "title": "swissALTI3D, DTM 0.5 m (Switzerland)",
        "source": "swisstopo", "country": "Switzerland",
        "outline": [(5.95, 46.13), (6.8, 45.83), (7.9, 45.9), (9.0, 45.82), (10.5, 46.5), (10.45, 46.95), (9.5, 47.55), (8.6, 47.82), (7.5, 47.6), (6.0, 46.6), (5.95, 46.13)],
        "epsg": 2056, "res": 0.5, "kind": "files", "chunk_px": 2000, "parallel": 2,
        "url": "https://data.geo.admin.ch/api/stac/v0.9/collections/ch.swisstopo.swissalti3d/items",
        "citation": "swissALTI3D, © swisstopo. Open government data.",
        "landing_page": "https://www.swisstopo.admin.ch/en/height-model-swissalti3d",
    },
    "es:navarra-mdt-2m": {
        "publisher": "the Government of Navarre (Spain)",
        "title": "MDT 2 m from lidar, Government of Navarre (Navarre, Spain)",
        "source": "IDENA, Government of Navarre", "country": "Navarre (Spain)", "maker": "the Government of Navarre",
        "outline": [(-1.79, 43.31), (-1.39, 43.27), (-0.72, 42.92), (-0.85, 42.79), (-1.2, 42.55), (-1.3, 42.3), (-1.4, 41.91), (-1.85, 42.0), (-1.9, 42.3), (-2.25, 42.45), (-2.5, 42.6), (-2.4, 42.9), (-2.0, 43.0), (-1.79, 43.31)],
        "epsg": 25830, "res": 2.0, "kind": "wcs", "axes": ("E", "N"), "chunk_px": 500, "parallel": 2,
        "url": "https://idena.navarra.es/ogc/wcs", "coverage": "IDENA.WCS__ELEVAC_Ras_MDT_2M",
        "citation": "Modelo digital del terreno 2 m, © Gobierno de Navarra, IDENA. CC BY 4.0.",
        "landing_page": "https://idena.navarra.es",
        "note": "Spain's national services do not serve this: IGN's ground model service rounds heights to whole metres, and the CNIG download centre cannot be reached by a script, so for now Spain means Navarre.",
    },
    "de-by:dgm1": {
        "publisher": "the Bavarian Surveying Administration (Germany)",
        "title": "DGM1, digital terrain model 1 m (Bavaria, Germany)",
        "source": "Bayerische Vermessungsverwaltung", "country": "Bavaria (Germany)", "maker": "the Bavarian Surveying Administration",
        "outline": [(9.0, 50.1), (9.9, 50.6), (11.0, 50.5), (12.1, 50.3), (12.5, 49.9), (12.4, 49.7), (13.0, 49.3), (13.8, 48.8), (13.5, 48.6), (13.0, 48.3), (12.9, 47.7), (13.0, 47.5), (12.2, 47.6), (11.0, 47.4), (10.2, 47.3), (9.5, 47.55), (10.1, 48.0), (10.1, 48.5), (10.4, 48.7), (10.2, 49.3), (9.5, 49.6), (9.0, 50.1)],
        "epsg": 25832, "res": 1.0, "kind": "tiles", "chunk_px": 2000, "parallel": 2,
        "sheets": _km_grid(1, "https://download1.bayernwolke.de/a/dgm/dgm1/{e}_{n}.tif"),
        "citation": "DGM1, © Bayerische Vermessungsverwaltung, www.geodaten.bayern.de. CC BY 4.0.",
        "landing_page": "https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=dgm1",
    },
    "de-sn:dgm1": {
        "publisher": "GeoSN, the Saxon State Survey (Germany)",
        "title": "DGM1, digital terrain model 1 m (Saxony, Germany)",
        "source": "GeoSN", "country": "Saxony (Germany)", "maker": "the Saxon State Office for Geodata and Surveying",
        "outline": [(11.9, 50.4), (12.3, 50.2), (12.9, 50.4), (13.5, 50.6), (14.0, 50.8), (14.3, 50.9), (14.8, 50.8), (15.0, 51.0), (14.95, 51.4), (14.7, 51.6), (14.0, 51.5), (13.2, 51.6), (12.6, 51.5), (12.2, 51.3), (12.15, 51.0), (11.9, 50.6), (11.9, 50.4)],
        "epsg": 25833, "res": 1.0, "kind": "tiles", "chunk_px": 2000, "parallel": 2,
        "sheets": _km_grid(2, "https://geocloud.landesvermessung.sachsen.de/public.php/dav/files/JCcXyifaNdLDnxZ/dgm1_33{e}_{n}_2_sn_tiff.zip"),
        "citation": "DGM1, © GeoSN, Staatsbetrieb Geobasisinformation und Vermessung Sachsen. Data licence Germany, attribution, version 2.0 (dl-de/by-2-0).",
        "landing_page": "https://www.geodaten.sachsen.de/downloadbereich-digitale-hoehenmodelle-4851.html",
    },
    "de-nw:dgm1": {
        "publisher": "Geobasis NRW (Germany)",
        "title": "DGM1, digital terrain model 1 m (North Rhine-Westphalia, Germany)",
        "source": "Geobasis NRW, Bezirksregierung Köln", "country": "North Rhine-Westphalia (Germany)", "maker": "Geobasis NRW",
        "outline": [(5.87, 51.05), (6.1, 50.75), (6.4, 50.32), (6.8, 50.32), (7.2, 50.55), (7.9, 50.6), (8.2, 50.9), (8.6, 51.3), (9.15, 51.45), (9.45, 51.65), (8.9, 52.05), (8.7, 52.5), (7.95, 52.35), (7.0, 52.25), (6.7, 51.9), (5.95, 51.75), (5.87, 51.05)],
        "epsg": 25832, "res": 1.0, "kind": "wcs", "axes": ("x", "y"), "chunk_px": 1000, "parallel": 2,
        "url": "https://www.wcs.nrw.de/geobasis/wcs_nw_dgm", "coverage": "nw_dgm",
        "citation": "DGM1, © Geobasis NRW. Data licence Germany, zero, version 2.0 (dl-de/zero-2-0).",
        "landing_page": "https://www.bezreg-koeln.nrw.de/geobasis-nrw/produkte-und-dienste/hoehenmodelle/digitale-gelaendemodelle/digitales-gelaendemodell",
    },
    "uk-sc:lidar-dtm": {
        "publisher": "the Scottish Government (Scotland)",
        "title": "Scottish Public Sector LiDAR, DTM 0.5 to 1 m (Scotland)",
        "source": "Scottish Government, Scottish Remote Sensing Portal", "country": "Scotland", "maker": "the Scottish Government",
        "outline": [(-5.1, 54.6), (-3.1, 54.95), (-2.05, 55.8), (-1.6, 55.9), (-2.5, 56.3), (-1.75, 57.6), (-3.0, 58.7), (-5.0, 58.65), (-6.3, 57.6), (-7.7, 57.0), (-7.6, 56.8), (-6.4, 56.2), (-5.8, 55.3), (-5.1, 54.6)],
        "epsg": 27700, "res": 0.5, "kind": "tiles", "chunk_px": 2000, "parallel": 2,
        "sheets": _scotland("https://srsp-open-data.s3.eu-west-2.amazonaws.com/lidar"),
        "citation": "Scotland National LiDAR Programme, © Scottish Government, via the Scottish Remote Sensing Portal. Open Government Licence v3.0.",
        "landing_page": "https://remotesensingdata.gov.scot",
        "note": "Read newest first: the National LiDAR Programme, then phases 6 to 1. Some of Scotland has not been flown; it comes back as outside the survey.",
    },
    "uk-wa:lidar-dtm": {
        "publisher": "the Welsh Government (Wales)",
        "title": "Wales lidar composite, DTM 1 m (Wales)",
        "source": "Welsh Government, DataMapWales", "country": "Wales", "maker": "the Welsh Government",
        "outline": [(-5.35, 51.75), (-4.9, 51.6), (-4.1, 51.55), (-3.35, 51.38), (-2.65, 51.6), (-2.7, 52.0), (-3.1, 52.35), (-3.05, 52.9), (-2.75, 52.95), (-3.0, 53.3), (-3.4, 53.35), (-4.3, 53.45), (-4.7, 53.3), (-4.75, 52.8), (-4.1, 52.6), (-4.15, 52.25), (-4.65, 52.1), (-5.35, 51.75)],
        "epsg": 27700, "res": 1.0, "kind": "tiles", "chunk_px": 2000, "parallel": 2,
        # One cloud-optimised file for all of Wales; only the part a box needs is read.
        "sheets": lambda x0, y0, x1, y1: ["https://dmwproductionblob.blob.core.windows.net/cogs/lidar/wales_dtm_32bit_cog.tif"],
        "citation": "Lidar composite DTM, © Welsh Government, DataMapWales. Open Government Licence v3.0.",
        "landing_page": "https://datamap.gov.wales/maps/lidar-viewer/",
    },
    "si:dmr1": {
        "publisher": "ARSO, the Slovenian Environment Agency",
        "title": "Lidar DMR, digital terrain model 1 m (Slovenia)",
        "source": "ARSO, Slovenian Environment Agency", "country": "Slovenia", "maker": "the Slovenian Environment Agency",
        "outline": [(13.65, 45.6), (13.9, 45.45), (14.6, 45.5), (15.3, 45.45), (15.7, 45.8), (15.6, 46.2), (16.3, 46.4), (16.6, 46.5), (16.1, 46.85), (15.0, 46.65), (14.5, 46.42), (13.7, 46.53), (13.4, 46.35), (13.65, 46.15), (13.5, 45.95), (13.65, 45.6)],
        "epsg": 3794, "res": 1.0, "kind": "xyz-text", "chunk_px": 2000, "parallel": 1,
        "sheets": lambda *box: _slovenia_sheets(*box),   # defined further down
        "citation": "Lidar data, Slovenian Environment Agency (ARSO), Ministry of the Environment and Spatial Planning. Open data, CC BY 4.0.",
        "landing_page": "https://gis.arso.gov.si/evode/profile.aspx?id=atlas_voda_Lidar@Arso",
        "note": "Read as text, about 27 MB for each square km, so a first fetch is slower than elsewhere; sheets are kept after that.",
    },
    "nz:dem-1m": {
        "publisher": "Toitū Te Whenua Land Information New Zealand",
        "title": "New Zealand LiDAR 1 m DEM (New Zealand)",
        "source": "Toitū Te Whenua LINZ", "country": "New Zealand", "maker": "Toitū Te Whenua Land Information New Zealand",
        "outline": [(172.6, -34.4), (174.9, -36.1), (178.6, -37.6), (178.0, -39.3), (176.9, -40.2), (175.2, -41.7), (174.2, -41.8), (174.0, -42.5), (173.0, -43.8), (171.2, -44.9), (170.6, -46.0), (169.0, -46.7), (166.4, -46.0), (167.0, -45.0), (168.4, -44.0), (170.8, -42.8), (172.1, -40.8), (173.1, -40.8), (174.6, -39.9), (173.7, -39.2), (174.6, -38.0), (173.1, -35.2), (172.6, -34.4)],
        "epsg": 2193, "res": 1.0, "kind": "tiles", "chunk_px": 2000, "parallel": 2,
        "sheets": _topo50("https://nz-elevation.s3.ap-southeast-2.amazonaws.com/new-zealand/new-zealand/dem_1m/2193/{sheet}.tiff"),
        "citation": "New Zealand LiDAR 1 m DEM, sourced from Toitū Te Whenua Land Information New Zealand. CC BY 4.0.",
        "landing_page": "https://registry.opendata.aws/nz-elevation/",
        "note": "Some areas have not been flown yet; they come back as outside the survey.",
    },
    "es-pv:mdt-1m": {
        "publisher": "the Basque Government (Spain)",
        "title": "MDT LiDAR 1 m, latest flight (Basque Country, Spain)",
        "source": "geoEuskadi, Basque Government", "country": "the Basque Country (Spain)", "maker": "the Basque Government",
        "outline": [(-3.45, 43.24), (-3.15, 43.35), (-2.75, 43.45), (-2.2, 43.32), (-1.79, 43.39), (-1.73, 43.30), (-2.05, 43.05), (-2.25, 42.9), (-2.4, 42.65), (-2.6, 42.48), (-2.9, 42.55), (-3.1, 42.75), (-3.3, 42.9), (-3.45, 43.24)],
        "epsg": 25830, "res": 1.0, "kind": "wcs", "axes": ("x", "y"), "chunk_px": 1000, "parallel": 2,
        "url": "https://www.geo.euskadi.eus/WCS_KARTOGRAFIA", "coverage": "MDT_LIDAR_1M_EGUNERATUENA_MAS_ACTUALIZADA",
        "citation": "MDT LiDAR 1 m, © Gobierno Vasco / Eusko Jaurlaritza, geoEuskadi. CC BY 4.0.",
        "landing_page": "https://www.geo.euskadi.eus",
    },
    "dk:dhm-terraen": {
        "publisher": "the Danish Agency for Climate Data (Denmark)",
        "title": "Danmarks Højdemodel, terrain 0.4 m (Denmark)",
        "source": "Klimadatastyrelsen", "country": "Denmark", "maker": "the Danish Agency for Climate Data",
        "outline": [(8.0, 55.0), (8.1, 56.6), (8.6, 57.1), (10.0, 57.6), (10.6, 57.75), (10.5, 57.2), (10.3, 56.5), (10.9, 56.4), (12.6, 56.1), (12.7, 55.6), (12.1, 54.9), (11.0, 54.6), (10.0, 54.8), (9.4, 54.8), (8.6, 54.9), (8.0, 55.0)],
        "epsg": 25832, "res": 0.4, "kind": "wcs1", "chunk_px": 1000, "parallel": 2, "format": "GTiff",
        "url": "https://api.dataforsyningen.dk/dhm_wcs_DAF", "coverage": "dhm_terraen", "token": "dataforsyningen",
        "citation": "Danmarks Højdemodel, © Klimadatastyrelsen, through Dataforsyningen. Free data, attribution required.",
        "landing_page": "https://dataforsyningen.dk/data/930",
        "note": "Dataforsyningen asks for a free account and token. Paste it in Settings, Data and keys.",
    },
    "cz:dmr5g": {
        "publisher": "ČÚZK (Czechia)",
        "title": "DMR 5G, digital terrain model 2 m from lidar (Czechia)",
        "source": "ČÚZK", "country": "Czechia", "maker": "the Czech Office for Surveying, Mapping and Cadastre",
        "outline": [(12.09, 50.25), (12.5, 50.4), (13.0, 50.6), (14.3, 51.05), (15.0, 51.0), (15.4, 50.8), (16.3, 50.65), (16.9, 50.45), (17.7, 50.3), (18.5, 49.95), (18.85, 49.5), (17.6, 48.8), (16.9, 48.6), (16.0, 48.75), (15.0, 49.0), (14.7, 48.6), (13.8, 48.75), (13.3, 49.1), (12.6, 49.5), (12.4, 49.9), (12.09, 50.25)],
        "epsg": 5514, "res": 2.0, "kind": "image", "chunk_px": 1000, "parallel": 2,
        "url": "https://ags.cuzk.cz/arcgis2/rest/services/dmr5g/ImageServer",
        "citation": "Digitální model reliefu České republiky 5. generace (DMR 5G), © ČÚZK. CC BY 4.0.",
        "landing_page": "https://geoportal.cuzk.cz",
        "note": "Built from lidar flown 2009 to 2013, served as a 2 m grid. Heights are in the Baltic system (Bpv).",
    },
    "ca:hrdem": {
        "publisher": "Natural Resources Canada",
        "title": "HRDEM, high resolution digital terrain model 1 m, mostly from lidar (Canada)",
        "source": "Natural Resources Canada", "country": "Canada", "maker": "Natural Resources Canada",
        "outline": [(-141.0, 60.0), (-141.0, 69.6), (-110.0, 68.5), (-95.0, 68.5), (-80.0, 63.0), (-64.0, 60.0), (-55.0, 53.0), (-52.4, 47.8), (-53.0, 46.5), (-59.5, 45.6), (-65.9, 43.3), (-66.9, 44.4), (-67.8, 45.6), (-70.0, 45.2), (-71.5, 45.0), (-74.7, 45.0), (-76.4, 44.2), (-79.1, 43.1), (-79.0, 42.5), (-82.6, 41.7), (-83.1, 42.1), (-82.4, 43.0), (-84.6, 46.5), (-89.6, 48.0), (-95.2, 49.0), (-123.3, 49.0), (-123.0, 48.2), (-124.9, 48.2), (-133.0, 54.5), (-130.0, 56.0), (-141.0, 60.0)],
        "epsg": 3979, "res": 1.0, "kind": "wcs11", "chunk_px": 1000, "parallel": 2,
        "url": "https://datacube.services.geo.ca/wrapper/ogc/elevation-hrdem-mosaic", "coverage": "dtm",
        "citation": "High Resolution Digital Elevation Model (HRDEM), Natural Resources Canada. Open Government Licence – Canada.",
        "landing_page": "https://open.canada.ca/data/en/dataset/0fe65119-e96e-4a57-8bfe-9d9245fba06b",
        "note": "A mosaic of 1 m terrain models, mostly from lidar, where Canada and its provinces have flown it: most of the south and some of the north. Elsewhere the reply has no ground data.",
    },
    "ie:infomar": {
        "publisher": "INFOMAR, Geological Survey Ireland and the Marine Institute",
        "title": "INFOMAR seabed survey, depth model about 4 m (Irish waters)",
        "source": "INFOMAR", "country": "Irish waters", "maker": "INFOMAR, from multibeam sonar surveys",
        "outline": [(-11.5, 51.0), (-11.5, 55.6), (-7.0, 55.6), (-5.4, 54.6), (-5.3, 53.2), (-6.0, 52.0), (-8.0, 51.3), (-10.0, 51.3), (-11.5, 51.0)],
        "epsg": "utm", "res": 4.0, "kind": "image", "chunk_px": 1000, "parallel": 2, "seafloor": True, "valid": (-11000.0, 50.0),
        "url": "https://infomar.marine.ie/arcgis/rest/services/INFOMAR/AllBathymetry/ImageServer",
        "citation": "INFOMAR bathymetry, Geological Survey Ireland and the Marine Institute. CC BY 4.0.",
        "landing_page": "https://www.infomar.ie",
        "note": "The seafloor from multibeam sonar, as depth (negative height), about 4 m on the ground. Large wrecks show; small ones may not. Charts of cables and pipelines are not read here.",
    },
    "jp-22:shizuoka-dem": {
        "publisher": "Shizuoka Prefecture (Japan)",
        "title": "VIRTUAL SHIZUOKA, ground model 0.5 m from lidar (Shizuoka, Japan)",
        "source": "Shizuoka Prefecture", "country": "Shizuoka (Japan)", "maker": "Shizuoka Prefecture",
        "outline": [(137.47, 34.58), (138.25, 34.58), (138.75, 34.58), (138.85, 34.60), (139.18, 34.85), (139.18, 35.25), (138.95, 35.33), (138.75, 35.45), (138.55, 35.65), (138.20, 35.50), (137.90, 35.20), (137.47, 34.95), (137.47, 34.58)],
        "epsg": 6676, "res": 0.5, "kind": "xyz-sheets", "chunk_px": 2000, "parallel": 2,
        "url": "https://virtual-shizuoka.s3.ap-northeast-1.amazonaws.com", "layer": "LP/Grid", "years": (2025, 2022, 2021, 2020, 2019),
        "sheets": lambda *box: _shizuoka_sheets(*box),   # defined further down
        "citation": "VIRTUAL SHIZUOKA point cloud data, Shizuoka Prefecture. CC BY 4.0.",
        "landing_page": "https://github.com/aigidjp/opendata_virtualshizuoka",
        "note": "Flown in parts between 2019 and 2025; each 300 by 400 m sheet comes from the newest survey that has it.",
    },
    "us:3dep-dem-1m": {
        "publisher": "USGS 3DEP (United States)",
        "title": "USGS 3DEP ground model, best available, about 1 m (conterminous United States)",
        "source": "USGS 3D Elevation Program", "country": "the conterminous United States", "maker": "the USGS 3D Elevation Program",
        "outline": [(-124.7, 48.4), (-123.0, 49.0), (-95.0, 49.0), (-89.5, 48.0), (-84.8, 46.9), (-82.4, 45.3), (-82.5, 42.0), (-79.0, 43.5), (-75.0, 45.0), (-71.5, 45.0), (-69.0, 47.4), (-67.0, 45.0), (-70.0, 43.0), (-70.0, 41.5), (-74.0, 40.5), (-75.5, 38.5), (-76.0, 35.0), (-81.0, 31.5), (-80.0, 25.2), (-82.0, 26.0), (-83.0, 29.0), (-85.0, 29.6), (-89.0, 30.0), (-94.0, 29.5), (-97.2, 26.0), (-99.5, 27.6), (-104.5, 29.6), (-106.5, 31.8), (-111.0, 31.3), (-114.8, 32.5), (-117.1, 32.5), (-120.6, 34.5), (-122.5, 37.5), (-124.3, 40.4), (-124.7, 48.4)],
        "epsg": "utm", "res": 1.0, "kind": "image", "chunk_px": 2000, "parallel": 4,
        "url": "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer",
        "citation": "U.S. Geological Survey, 3D Elevation Program. Public domain.",
        "landing_page": "https://www.usgs.gov/3d-elevation-program",
        "note": "The ready-made bare-ground model USGS builds from its lidar, much faster to fetch than the points. Where no 1 m model exists yet the service fills in coarser ground (10 or 30 m), which hides small features; the points (the usgs: surveys) show what was flown.",
    },
    "us:noaa-bag": {
        "publisher": "NOAA (United States)",
        "title": "NOAA hydrographic surveys, BAG depth grids (US waters and the Great Lakes)",
        "source": "NOAA NCEI", "country": "US coastal waters and the Great Lakes", "maker": "NOAA's Office of Coast Survey",
        "outline": [(-126.0, 30.0), (-126.0, 49.5), (-95.0, 49.5), (-89.0, 48.5), (-82.0, 46.5), (-76.0, 44.5), (-66.0, 45.5), (-65.0, 40.0), (-75.0, 34.0), (-79.0, 24.0), (-98.0, 24.0), (-118.0, 31.0), (-126.0, 30.0)],
        "epsg": "utm", "res": 1.0, "kind": "image", "chunk_px": 1000, "parallel": 2, "seafloor": True, "valid": (-11000.0, 50.0),
        "catalog": "noaa",
        "url": "https://gis.ngdc.noaa.gov/arcgis/rest/services/bag_bathymetry/ImageServer",
        "citation": "NOAA National Centers for Environmental Information, NOS hydrographic survey data (BAG). Public domain.",
        "landing_page": "https://www.ncei.noaa.gov/products/nos-hydrographic-survey",
        "note": "The seafloor from sonar surveys, as depth below the chart datum (negative height). Offered only where a survey 2 m or finer covers the box.",
    },
}
CHUNK_PX = 1000  # the services answer faster for several small requests than for one large one
_client = httpx.Client(timeout=120, follow_redirects=True,
                       headers={"User-Agent": "dighouse/0.1 (https://github.com/chrissotraidis/dighouse)"})


OTHER_PUBLISHERS = {"usgs": "USGS 3DEP", "ot": "OpenTopography", "own": "a file added by a person"}


def publisher(dataset: str) -> str:
    """Who publishes a dataset, from its id or its prefix ("es:mdt-5m" or "es")."""
    prefix = dataset.split(":")[0]
    if prefix in OTHER_PUBLISHERS:
        return OTHER_PUBLISHERS[prefix]
    return next((d["publisher"] for k, d in NATIONAL.items() if k.split(":")[0] == prefix), prefix)


def countries() -> str:
    """The places with a national ground model, as a sentence fragment: "England, ..., and Spain"."""
    names = [d["country"] for d in NATIONAL.values()]
    return ", ".join(names[:-1]) + " and " + names[-1]


TOKEN_HELP = {"dataforsyningen": "https://confluence.kds.dk/display/MYD/Log%2Bind%2Bog%2BToken"}


def access_key(name: str) -> str:
    """A free key or token an open data service asks for: from DIGHOUSE_<NAME>_TOKEN, or the keys file the app's Settings write."""
    import json
    import os
    from pathlib import Path
    if os.environ.get(f"DIGHOUSE_{name.upper()}_TOKEN"):
        return os.environ[f"DIGHOUSE_{name.upper()}_TOKEN"].strip()
    f = Path(os.environ.get("DIGHOUSE_KEYS", Path.home() / "Library" / "Application Support" / "Dighouse" / "keys.json"))
    try:
        return str(json.loads(f.read_text()).get(name) or "").strip()
    except (OSError, ValueError):
        return ""


def _surveys(d: dict, bbox: list[float], finest_m: float = 2.0) -> list[dict]:
    """The sonar surveys inside a box that are fine enough to show a wreck, from the image service's own catalog."""
    w, s, e, n = bbox
    r = _client.get(d["url"] + "/query", params={
        "geometry": f"{w},{s},{e},{n}", "geometryType": "esriGeometryEnvelope", "inSR": 4326, "spatialRel": "esriSpatialRelIntersects",
        "where": "Category = 1", "outFields": "SurveyID,Name,LowPS", "returnGeometry": "false", "f": "json"})
    r.raise_for_status()
    out = []
    for f in r.json().get("features", []):
        a = f["attributes"]
        res = (a.get("LowPS") or 1) * 111_320
        if res <= finest_m and a.get("SurveyID"):
            out.append({"survey": a["SurveyID"], "res_m": round(res, 1), "file": a.get("Name", "")})
    return out


NOS_SURVEYS = "https://gis.ngdc.noaa.gov/arcgis/rest/services/web_mercator/nos_hydro_dynamic/MapServer/0/query"


def survey_details(found: list[dict]) -> list[dict]:
    """When each sonar survey was made, by what vessel, and how sure its depths are (the median of the BAG's uncertainty layer)."""
    import datetime as dt
    ids = sorted({f["survey"] for f in found})
    if not ids:
        return []
    r = _client.get(NOS_SURVEYS, params={"where": "SURVEY_ID IN (" + ",".join(f"'{i}'" for i in ids) + ")", "f": "json",
                                         "outFields": "SURVEY_ID,DATE_SURVEY_BEGIN,DATE_SURVEY_END,PLATFORM,DOWNLOAD_URL", "returnGeometry": "false"})
    r.raise_for_status()
    day = lambda ms: dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc).date().isoformat() if ms else None
    out = []
    for a in (f["attributes"] for f in r.json().get("features", [])):
        row = {"survey": a["SURVEY_ID"], "surveyed": " to ".join(x for x in (day(a.get("DATE_SURVEY_BEGIN")), day(a.get("DATE_SURVEY_END"))) if x),
               "platform": a.get("PLATFORM"), "record": a.get("DOWNLOAD_URL")}
        folder = (a.get("DOWNLOAD_URL") or "").split("/nos/")[-1].rsplit("/", 1)[0]
        files = [f["file"].replace("_interp1m", "") for f in found if f["survey"] == a["SURVEY_ID"] and f.get("file")]
        if folder and files:
            try:  # the BAG's small overview grid carries the uncertainty layer, so this reads a few kilobytes
                with rasterio.open(f"/vsicurl/https://data.ngdc.noaa.gov/platforms/ocean/nos/coast/{folder}/{a['SURVEY_ID']}/BAG/{files[0]}.bag") as src:
                    if src.count >= 2:
                        u = src.read(2).astype(float)
                        u = u[(u > 0) & (u < 100)]
                        if u.size:
                            row["uncertainty_m"] = round(float(np.median(u)), 2)
            except Exception:
                pass
        out.append(row)
    return out


def _inside(x: float, y: float, ring: list[tuple[float, float]]) -> bool:
    hit = False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            hit = not hit
    return hit


def _overlaps(bbox: list[float], ring: list[tuple[float, float]]) -> bool:
    """A coarse test: a corner or the centre of the box is in the country, or a point of its outline is in the box."""
    w, s, e, n = bbox
    probes = [(w, s), (w, n), (e, s), (e, n), ((w + e) / 2, (s + n) / 2)]
    return any(_inside(x, y, ring) for x, y in probes) or any(w <= x <= e and s <= y <= n for x, y in ring)


def find(bbox: list[float]) -> list[dict]:
    """National ground models whose country overlaps a lon/lat box."""
    out = []
    for key, d in NATIONAL.items():
        if _overlaps(bbox, d["outline"]):
            if d.get("catalog") == "noaa":
                try:
                    found = _surveys(d, bbox)
                except Exception:  # the survey catalog being down should not hide the ground models
                    found = []
                if not found:
                    continue
                names = sorted({f"{x['survey']} ({x['res_m']:g} m)" for x in found})
                out.append({"id": key, "source": d["source"], "title": d["title"], "landing_page": d["landing_page"],
                            "citation": d["citation"], "ready_made_ground_model": True, "seafloor": True,
                            "about": f"{d['note']} Surveys here: {', '.join(names[:8])}. Each survey's record and date are at "
                                     "https://www.ncei.noaa.gov/maps/bathymetry/."})
                continue
            if d.get("token") and not access_key(d["token"]):
                out.append({"id": key, "source": d["source"], "title": d["title"], "landing_page": d["landing_page"],
                            "citation": d["citation"], "ready_made_ground_model": False, "needs_token": True,
                            "about": f"{d['source']} asks for a free token before it hands out its ground model. Get one at "
                                     f"{TOKEN_HELP[d['token']]}, then paste it in Settings, Data and keys."})
                continue
            out.append({"id": key, "source": d["source"], "title": d["title"], "landing_page": d["landing_page"],
                        "citation": d["citation"], "ready_made_ground_model": True, **({"seafloor": True} if d.get("seafloor") else {}),
                        "about": (f"A depth model of the seafloor in {d['country']} at about {d['res']:g} m, from {d.get('maker', 'sonar surveys')}. "
                                  if d.get("seafloor") else
                                  f"A bare-ground model for {d['country']} at {d['res']:g} m, built by {d.get('maker', 'the national agency')} from its lidar. ")
                                 + (d["note"] + " " if d.get("note") else "")
                                 + "The box is matched against a rough outline of the country; parts of it with no data come back as outside the survey."})
    return out


def _chunk(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    tries = 6
    for attempt in range(tries):  # these services time out or limit the request rate now and then
        wait = 5 * (attempt + 1)
        try:
            return _request(d, x0, y0, x1, y1)
        except httpx.HTTPStatusError as exc:
            code = exc.response.status_code
            if (code != 429 and code < 500) or attempt == tries - 1:
                raise
            if code == 429:  # too many requests: wait as long as the server asks, or longer each time
                after = exc.response.headers.get("Retry-After", "")
                wait = int(after) if after.isdigit() else 20 * (attempt + 1)
        except httpx.TimeoutException:
            if attempt == tries - 1:
                raise
        for _ in range(int(min(wait, 90))):  # wait in short steps, so a cancelled fetch ends promptly
            if sources.cancelled():
                raise RuntimeError("Stopped by the person before the download finished.")
            time.sleep(1)
    raise RuntimeError("unreachable")


def _from_files(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    """A ground model published as one file for each map sheet: ask the catalog which sheets cover the box, and read only
    the part of each that is needed. Where a sheet was flown more than once, the newest is used."""
    from pyproj import Transformer
    from rasterio.windows import from_bounds

    res = d["res"]
    back = Transformer.from_crs(d["epsg"], 4326, always_xy=True)
    west, south = back.transform(x0, y0)
    east, north = back.transform(x1, y1)
    r = _client.get(d["url"], params={"bbox": f"{west},{south},{east},{north}", "limit": 100})
    r.raise_for_status()
    newest: dict[str, tuple[str, str]] = {}
    for item in r.json().get("features", []):
        _, year, sheet = item["id"].split("_")[:3]
        link = next((a["href"] for name, a in item["assets"].items() if name.endswith(".tif") and a.get("eo:gsd") == res), None)
        if link and (sheet not in newest or year > newest[sheet][0]):
            newest[sheet] = (year, link)
    out = np.full((int(round((y1 - y0) / res)), int(round((x1 - x0) / res))), np.nan, np.float32)
    for _, link in newest.values():
        with rasterio.open("/vsicurl/" + link) as src:
            part = src.read(1, window=from_bounds(x0, y0, x1, y1, src.transform), boundless=True, fill_value=np.nan, out_shape=out.shape).astype(np.float32)
            if src.nodata is not None:
                part[part == src.nodata] = np.nan
        out = np.where(np.isnan(out), part, out)
    return out, x0, y1, res, None


def _sheet(url: str) -> str | None:
    """A path GDAL can read for one sheet, or None when the sheet does not exist (sea, or outside the region).
    Zipped sheets are downloaded once into the cache; plain ones are read in place, only the part that is needed."""
    if not url.endswith(".zip"):
        return "/vsicurl/" + url
    import hashlib
    import zipfile
    local = sources.cache_dir() / "national" / (hashlib.sha1(url.encode()).hexdigest()[:16] + ".zip")
    if not local.exists():
        r = _client.get(url)
        if r.status_code == 404:
            return None
        r.raise_for_status()
        local.parent.mkdir(parents=True, exist_ok=True)
        part = local.with_suffix(".part")
        part.write_bytes(r.content)
        part.rename(local)
    inner = next((n for n in zipfile.ZipFile(local).namelist() if n.lower().endswith((".tif", ".tiff"))), None)
    return f"/vsizip/{local}/{inner}" if inner else None


def _from_tiles(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    """A ground model published as one file per map sheet on a fixed grid: read the part of each sheet the box needs."""
    from rasterio.errors import RasterioIOError
    from rasterio.windows import from_bounds

    res = d["res"]
    out = np.full((int(round((y1 - y0) / res)), int(round((x1 - x0) / res))), np.nan, np.float32)
    for url in d["sheets"](x0, y0, x1, y1):
        path = _sheet(url)
        if not path:
            continue
        try:
            with rasterio.open(path) as src:
                part = src.read(1, window=from_bounds(x0, y0, x1, y1, src.transform), boundless=True, fill_value=np.nan,
                                out_shape=out.shape).astype(np.float32)
                if src.nodata is not None:
                    part[part == src.nodata] = np.nan
        except RasterioIOError:  # no such sheet: the area has not been flown, or it is sea
            continue
        out = np.where(np.isnan(out), part, out)
    return out, x0, y1, res, None


def _shizuoka_sheets(x0: float, y0: float, x1: float, y1: float) -> list[str]:
    """Japan's map sheets in plane zone VIII: 30 by 40 km sheets lettered from 300 km north and 160 km west, each split
    10 by 10 into 3 by 4 km sheets, and those 10 by 10 into the 300 by 400 m sheets a ground model is published in.
    "08NF1172" is zone 8, row N, column F, then row 1 column 1, then row 7 column 2."""
    import math
    out = []
    # Step through the sheet grid itself, at the middle of each sheet the box touches.
    y = 300000 - (math.floor((300000 - y1) / 300) * 300) - 150
    while y > y0 - 150:
        x = -160000 + math.floor((x0 + 160000) / 400) * 400 + 200
        while x < x1 + 200:
            c, r = int((x + 160000) // 40000), int((300000 - y) // 30000)
            left, top = -160000 + c * 40000, 300000 - r * 30000
            c5, r5 = int((x - left) // 4000), int((top - y) // 3000)
            c2, r2 = int((x - left - c5 * 4000) // 400), int((top - r5 * 3000 - y) // 300)
            name = f"08{chr(65 + r)}{chr(65 + c)}{r5}{c5}{r2}{c2}"
            if 0 <= r < 20 and 0 <= c < 8 and name not in out:
                out.append(name)
            x += 400
        y -= 300
    return out


def _from_xyz_sheets(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    """A ground model published as zipped text (x y z per cell) in one file per map sheet, flown in different years:
    each sheet is taken from the newest year that has it."""
    import hashlib
    import zipfile
    res = d["res"]
    out = np.full((int(round((y1 - y0) / res)), int(round((x1 - x0) / res))), np.nan, np.float32)
    for name in d["sheets"](x0, y0, x1, y1):
        for year in d["years"]:
            url = f"{d['url']}/{year}/{d['layer']}/08/{name[2:4]}/{name[4:6]}/{name}.zip"
            local = sources.cache_dir() / "national" / (hashlib.sha1(url.encode()).hexdigest()[:16] + ".zip")
            if not local.exists():
                r = _client.get(url)
                if r.status_code in (403, 404):
                    continue
                r.raise_for_status()
                local.parent.mkdir(parents=True, exist_ok=True)
                local.with_suffix(".part").write_bytes(r.content)
                local.with_suffix(".part").rename(local)
            with zipfile.ZipFile(local) as z:
                inner = next((n for n in z.namelist() if n.lower().endswith(".txt")), None)
                if not inner:
                    continue
                xyz = _xyz(z.read(inner).decode("utf-8", "replace"))
            if xyz.size:
                col = np.floor((xyz[:, 0] - x0) / res).astype(int)
                row = np.floor((y1 - xyz[:, 1]) / res).astype(int)
                ok = (row >= 0) & (row < out.shape[0]) & (col >= 0) & (col < out.shape[1])
                out[row[ok], col[ok]] = xyz[ok, 2]
            break
    return out, x0, y1, res, None


def _xyz(text: str) -> np.ndarray:
    """x, y, z per cell from a sheet's text: "x y z", or newer sheets' "n,x,y,z,flag" with commas."""
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if not lines:
        return np.empty((0, 3))
    sep = "," if "," in lines[0] else None
    a = np.loadtxt(lines, delimiter=sep, dtype=np.float64, ndmin=2)
    return a[:, 1:4] if a.shape[1] >= 5 else a[:, :3]


def _slovenia_sheets(x0: float, y0: float, x1: float, y1: float) -> list[str]:
    """Slovenia's 1 km sheets (TM1_462_101: east and north in km, D96/TM). Each sits in one of the flight blocks b_11 to
    b_39, which follow the survey rather than a grid, so the block is found once by asking for the sheet in each, and kept."""
    import json
    store = sources.cache_dir() / "national" / "slovenia-blocks.json"
    known = json.loads(store.read_text()) if store.exists() else {}
    base = "https://gis.arso.gov.si/lidar/dmr1"

    def block(name: str) -> int | None:
        def has(b: int) -> int | None:
            return b if _client.head(f"{base}/b_{b}/D96TM/{name}.asc").status_code == 200 else None
        with ThreadPoolExecutor(10) as pool:
            return next((b for b in pool.map(has, range(11, 40)) if b), None)

    out = []
    for e in range(math.floor(x0 / 1000), math.ceil(x1 / 1000)):
        for n in range(math.floor(y0 / 1000), math.ceil(y1 / 1000)):
            name = f"TM1_{e}_{n}"
            if name not in known:
                known[name] = block(name)
            if known[name]:
                out.append(f"{base}/b_{known[name]}/D96TM/{name}.asc")
    store.parent.mkdir(parents=True, exist_ok=True)
    store.write_text(json.dumps(known))
    return out


def _from_xyz_text(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    """A ground model published as plain text, one "x;y;z" line per cell, one file per sheet. Files are kept in the cache."""
    import hashlib
    res = d["res"]
    out = np.full((int(round((y1 - y0) / res)), int(round((x1 - x0) / res))), np.nan, np.float32)
    for url in d["sheets"](x0, y0, x1, y1):
        local = sources.cache_dir() / "national" / (hashlib.sha1(url.encode()).hexdigest()[:16] + ".xyz")
        if not local.exists():
            r = _client.get(url, timeout=300)
            if r.status_code in (403, 404):
                continue
            r.raise_for_status()
            local.parent.mkdir(parents=True, exist_ok=True)
            local.with_suffix(".part").write_bytes(r.content)
            local.with_suffix(".part").rename(local)
        xyz = np.loadtxt(local, delimiter=d.get("delimiter", ";"), dtype=np.float64, ndmin=2)
        if xyz.size:
            col = np.floor((xyz[:, 0] - x0) / res).astype(int)
            row = np.floor((y1 - xyz[:, 1]) / res).astype(int)
            ok = (row >= 0) & (row < out.shape[0]) & (col >= 0) & (col < out.shape[1])
            out[row[ok], col[ok]] = xyz[ok, 2]
    return out, x0, y1, res, None


def _request(d: dict, x0: float, y0: float, x1: float, y1: float) -> tuple[np.ndarray, float, float, float, float | None]:
    if d["kind"] == "xyz-text":
        return _from_xyz_text(d, x0, y0, x1, y1)
    if d["kind"] == "xyz-sheets":
        return _from_xyz_sheets(d, x0, y0, x1, y1)
    if d["kind"] == "files":
        return _from_files(d, x0, y0, x1, y1)
    if d["kind"] == "tiles":
        return _from_tiles(d, x0, y0, x1, y1)
    if d["kind"] == "image":  # an ArcGIS image service: export the box as 32-bit heights
        res = d["res"]
        r = _client.get(d["url"] + "/exportImage", params={
            "bbox": f"{x0},{y0},{x1},{y1}", "bboxSR": d["epsg"], "imageSR": d["epsg"],
            "size": f"{int(round((x1 - x0) / res))},{int(round((y1 - y0) / res))}", "format": "tiff", "pixelType": "F32",
            "noData": "-99999", "interpolation": "RSP_BilinearInterpolation", "f": "image"})
        r.raise_for_status()
        with rasterio.open(io.BytesIO(r.content)) as src:
            a = src.read(1).astype(np.float32)
            t = src.transform
            return a, t.c, t.f, t.a, -99999.0
    if d["kind"] == "wcs1":  # the older form of the request, which some servers still want
        res = d["res"]
        params = {"service": "WCS", "version": "1.0.0", "request": "GetCoverage", "coverage": d["coverage"], "crs": f"EPSG:{d['epsg']}",
                  "bbox": f"{x0},{y0},{x1},{y1}", "width": int(round((x1 - x0) / res)), "height": int(round((y1 - y0) / res)),
                  "format": d.get("format", "GeoTIFF")}
        if d.get("token"):
            params["token"] = access_key(d["token"])
        r = _client.get(d["url"], params=params)
    elif d["kind"] == "wcs11":  # WCS 1.1, which names the grid by its origin and cell size
        res, crs = d["res"], f"urn:ogc:def:crs:EPSG::{d['epsg']}"
        r = _client.get(d["url"], params={
            "service": "WCS", "version": "1.1.1", "request": "GetCoverage", "identifier": d["coverage"],
            "BoundingBox": f"{x0},{y0},{x1},{y1},{crs}", "format": "image/geotiff", "GridBaseCRS": crs,
            "GridCS": "urn:ogc:def:cs:OGC:0.0:Grid2dSquareCS", "GridType": "urn:ogc:def:method:WCS:1.1:2dGridIn2dCrs",
            "GridOrigin": f"{x0},{y1}", "GridOffsets": f"{res},{-res}"})
    elif d["kind"] == "wms":
        res = d["res"]
        r = _client.get(d["url"], params={
            "SERVICE": "WMS", "VERSION": "1.3.0", "REQUEST": "GetMap", "LAYERS": d["coverage"], "STYLES": "",
            "CRS": f"EPSG:{d['epsg']}", "BBOX": f"{x0},{y0},{x1},{y1}", "FORMAT": "image/geotiff",
            "WIDTH": int(round((x1 - x0) / res)), "HEIGHT": int(round((y1 - y0) / res))})
    else:
        ax, ay = d["axes"]
        r = _client.get(d["url"], params=[
            ("service", "WCS"), ("version", "2.0.1"), ("request", "GetCoverage"), ("coverageId", d["coverage"]),
            ("format", "image/tiff"), ("subset", f"{ax}({x0},{x1})"), ("subset", f"{ay}({y0},{y1})")])
    if d.get("token") and r.status_code in (401, 403):
        raise ValueError(f"{d['source']} did not accept the token. Check it at {TOKEN_HELP[d['token']]} and paste it again in Settings, Data and keys.")
    r.raise_for_status()
    body = r.content
    if "multipart" in r.headers.get("content-type", ""):  # some servers wrap the picture in a description of it
        start = max(body.find(b"II*\x00"), body.find(b"MM\x00*"))
        body = body[start:] if start >= 0 else body
    elif "xml" in r.headers.get("content-type", "") or body[:5] == b"<?xml" or "html" in r.headers.get("content-type", ""):
        raise RuntimeError(f"{d['source']} refused the request: {r.text[:200]}")
    with rasterio.open(io.BytesIO(body)) as src:
        a = src.read(1).astype(np.float32)
        t = src.transform
        return a, t.c, t.f, t.a, src.nodata


def fetch_dtm(dataset: str, bbox: list[float], res: float | None = None) -> tuple[np.ndarray, np.ndarray, float, float, float, int, dict]:
    """Download a national ground model for a lon/lat box. Returns the model, the no-data mask, its corner, cell size and EPSG."""
    d = NATIONAL.get(dataset)
    if not d:
        raise ValueError(f"Unknown national dataset {dataset!r}.")
    if d.get("epsg") == "utm":  # a service that answers in any projection: use the box's own UTM zone
        d = {**d, "epsg": sources.utm_epsg((bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2)}
    if d.get("token") and not access_key(d["token"]):
        raise ValueError(f"{d['source']} asks for a free token. Get one at {TOKEN_HELP[d['token']]}, then paste it in Settings, Data and keys.")
    res = max(res or d["res"], d["res"])
    x0, y0, x1, y1 = (math.floor(v / res) * res if i < 2 else math.ceil(v / res) * res
                      for i, v in enumerate(sources.project_bbox(bbox, d["epsg"])))
    cols, rows = int(round((x1 - x0) / res)), int(round((y1 - y0) / res))
    dtm = np.full((rows, cols), np.nan, np.float32)
    step = d.get("chunk_px", CHUNK_PX) * d["res"]
    parts = [(cx, cy, min(cx + step, x1), min(cy + step, y1))
             for cx in np.arange(x0, x1, step) for cy in np.arange(y0, y1, step)]
    sources.progress(0, len(parts))
    with ThreadPoolExecutor(d.get("parallel", 4)) as pool:
        got = list(pool.map(sources._counted(lambda b: (b, _chunk(d, *b)), len(parts)), parts))
    for _, (a, left, top, cell, nodata) in got:
        if nodata is not None:
            a[a == nodata] = np.nan
        lo, hi = d.get("valid", (-500.0, 9000.0))
        a[(a < lo) | (a > hi)] = np.nan  # sentinel values the services use for "no data"
        if abs(cell - res) > 1e-3:  # resample to the requested cell size
            k = max(int(round(res / cell)), 1)
            h, w = a.shape[0] // k * k, a.shape[1] // k * k
            a = np.nanmean(a[:h, :w].reshape(h // k, k, w // k, k), axis=(1, 3))
            cell = res
        r0, c0 = int(round((y1 - top) / res)), int(round((left - x0) / res))
        rr0, cc0 = max(r0, 0), max(c0, 0)
        rr1, cc1 = min(r0 + a.shape[0], rows), min(c0 + a.shape[1], cols)
        if rr1 > rr0 and cc1 > cc0:
            block = a[rr0 - r0:rr1 - r0, cc0 - c0:cc1 - c0]
            target = dtm[rr0:rr1, cc0:cc1]
            dtm[rr0:rr1, cc0:cc1] = np.where(np.isnan(block), target, block)
    outside = np.isnan(dtm)
    if outside.all():
        if d.get("seafloor"):
            raise ValueError(f"{d['source']} has no survey inside this box. Seafloor surveys cover strips and patches; try find_data on a nearby box.")
        raise ValueError(f"{d['source']} has no ground model inside this box. It covers {d['country']} only.")
    if outside.any():
        dtm[outside] = float(np.nanmedian(dtm))
    how = {"source": d["source"], "citation": d["citation"], "ready_made_ground_model": True, "requests": len(parts)}
    if d.get("seafloor"):
        how["seafloor"] = True
    if d.get("catalog") == "noaa":
        found = _surveys(d, bbox)
        how["surveys"] = sorted({f"{x['survey']} ({x['res_m']:g} m)" for x in found})
        try:
            how["survey_details"] = survey_details(found)
        except Exception:  # the survey catalog being down should not stop a fetch; the record says the details are missing
            how["survey_details"] = []
        dates = [x["surveyed"] for x in how["survey_details"] if x.get("surveyed")]
        if dates:
            first, last = min(d[:4] for d in dates), max(d[-10:][:4] for d in dates)
            how["collected"] = first if first == last else f"{first} to {last}"
    return dtm, outside, x0, y1, res, d["epsg"], how
