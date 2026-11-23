"""Who to tell about a find, by country: the body that keeps the official record of sites and takes reports, whether that
record is open for Dighouse to read, and what the person should know before sending anything. Used by the report and the
records request a person sends; Dighouse itself sends nothing (FIND_LOOP G5).

The bodies named are the usual ones; a person should confirm the right office for their area on its page."""

from __future__ import annotations

from . import discover, national

ALWAYS = ("Do not post the location anywhere public, and do not dig or remove anything: in most countries that needs a "
          "permit, and a published location invites looting.")

BODIES = {
    "England": ("the county or district Historic Environment Record (HER); Historic England for scheduled monuments",
                "https://www.heritagegateway.org.uk/gateway/chr/"),
    "Scotland": ("Historic Environment Scotland (Canmore) and the council's Historic Environment Record", "https://canmore.org.uk"),
    "Wales": ("the regional Historic Environment Record (Archwilio)", "https://www.archwilio.org.uk"),
    "Norway": ("the county authority's cultural heritage section (fylkeskommunen), which keeps Askeladden up to date",
               "https://www.riksantikvaren.no"),
    "Denmark": ("the museum responsible for archaeology in the area, or Slots- og Kulturstyrelsen", "https://slks.dk"),
    "the Netherlands": ("the municipality's archaeologist, or the Rijksdienst voor het Cultureel Erfgoed", "https://www.cultureelerfgoed.nl"),
    "metropolitan France": ("the regional archaeology service (Service régional de l'archéologie) of the DRAC",
                            "https://www.culture.gouv.fr/Regions"),
    "Flanders": ("Agentschap Onroerend Erfgoed", "https://www.onroerenderfgoed.be"),
    "Switzerland": ("the cantonal archaeology service", "https://www.archaeologie-schweiz.ch"),
    "Estonia": ("the National Heritage Board (Muinsuskaitseamet)", "https://www.muinsuskaitseamet.ee"),
    "Slovenia": ("the Institute for the Protection of Cultural Heritage (ZVKDS)", "https://www.zvkds.si"),
    "Czechia": ("the National Heritage Institute (NPÚ) or the Institute of Archaeology of the Czech Academy of Sciences",
                "https://www.npu.cz"),
    "New Zealand": ("Heritage New Zealand Pouhere Taonga, and the NZAA site recording scheme", "https://www.heritage.org.nz"),
    "the conterminous United States": ("the State Historic Preservation Office (SHPO); on federal or tribal land, the land "
                                       "manager and the tribe as well", "https://ncshpo.org/directory/"),
    "Navarre": ("the Government of Navarre's historic heritage service", "https://www.navarra.es"),
    "Basque Country": ("the provincial council's heritage service (Diputación Foral)", "https://www.euskadi.eus"),
    "Bavaria": ("the Bavarian State Office for Monument Protection (BLfD)", "https://www.blfd.bayern.de"),
    "Saxony": ("the Saxon State Office for Archaeology (LfA)", "https://www.archaeologie.sachsen.de"),
    "North Rhine-Westphalia": ("the regional archaeology service (LVR or LWL)", "https://www.lvr.de"),
    "Shizuoka (Japan)": ("the prefectural or municipal board of education's cultural property section", "https://www.pref.shizuoka.jp"),
}


def _country(lon: float, lat: float) -> str:
    for d in national.NATIONAL.values():
        if not d.get("seafloor") and national._inside(lon, lat, d["outline"]):
            name = d["country"]
            return "Navarre" if "Navarre" in name or "Navarra" in d.get("title", "") else name
    return ""


def who_to_tell(lon: float, lat: float) -> dict:
    """The body to tell about a find at a place, whether its official record is open to Dighouse, and the cautions."""
    country = _country(lon, lat)
    body = BODIES.get(country) or next((v for k, v in BODIES.items() if k in country or country in k), None) if country else None
    registers = discover.covering_registers(lon, lat)
    full = [r for r in registers if "only" not in r["holds"]]
    return {
        "country": country or "not one Dighouse has a table entry for",
        "tell": body[0] if body else "the national or regional heritage authority; ask the local museum which office keeps the record",
        "link": body[1] if body else "",
        "records_open": bool(full),
        "records": ("; ".join(f"{r['register']} lists {r['holds']}" for r in registers) if registers
                    else "The official site record here is not open, so ask that office whether the place is already recorded."),
        "before_sending": ALWAYS,
    }
