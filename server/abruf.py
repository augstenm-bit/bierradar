"""BierRadar – Angebots-Abruf.

Öffnet die öffentlichen marktguru-Suchseiten wie ein normaler Besucher (unsichtbarer Browser),
liest die Bier-Angebote heraus und schreibt sie nach angebote.json.

Aufruf:  .venv/bin/python abruf.py [ausgabe.json]
"""
from __future__ import annotations

import datetime as dt
import json
import re
import sys
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

BASIS = "https://www.marktguru.at/search/"
PAUSE_SEKUNDEN = 1.0  # höflich bleiben
MAX_SEITEN_BIER = 15

# Zusätzliche Suchwörter, damit auch Spezialitäten sicher gefunden werden.
EXTRA_SUCHWOERTER = [
    # Biersorten – viele Angebote heißen „Märzen“, „Pils“ … ohne das Wort „Bier“
    "märzen", "pils", "helles", "lager", "weißbier", "zwickl", "radler",
    # Marken
    "gösser", "stiegl", "zipfer", "kaiser bier", "ottakringer", "puntigamer", "schwechater", "wieselburger",
    "villacher", "egger", "freistädter", "hirter", "trumer", "edelweiss", "schremser", "zwettler",
    "eggenberger", "murauer", "schladminger", "paulaner", "augustiner", "erdinger", "franziskaner",
    "weihenstephaner", "heineken", "budweiser", "kozel", "jelen",
    # Spezialitäten / Importe
    "chang", "singha", "leo bier", "asahi", "kirin", "sapporo", "tsingtao", "tiger bier", "corona",
    "saigon bier", "asia bier", "thai bier", "japanisches bier", "import bier",
]

# Händler im Bezirk Amstetten (Schreibweise wie in der App).
HAENDLER = {
    "BILLA": "Billa",
    "BILLA PLUS": "Billa Plus",
    "SPAR": "Spar",
    "EUROSPAR": "Eurospar",
    "INTERSPAR": "Interspar",
    "HOFER": "Hofer",
    "LIDL": "Lidl",
    "PENNY": "Penny",
    "UNIMARKT": "Unimarkt",
    "ADEG": "ADEG",
    "ADEG AKTIV": "ADEG",
    "NAH&FRISCH": "Nah & Frisch",
    "NAH & FRISCH": "Nah & Frisch",
    "ADEG NAHVERSORGER": "ADEG",
    "LAGERHAUS": "Lagerhaus",
    "NORMA": "Norma",
    "MAXIMARKT": "Maximarkt",
    "SPAR-GOURMET": "Spar Gourmet",
    "SPAR GOURMET": "Spar Gourmet",
    "MPREIS": "MPreis",
    "M-PREIS": "MPreis",
    "METRO": "Metro",  # nur mit Gewerbekarte
    "TRANSGOURMET": "Transgourmet",  # nur mit Gewerbekarte
}

# Marke (klein geschrieben) -> Bier-ID in der App
MARKEN = {
    "gösser": "goesser", "stiegl": "stiegl", "kaiser": "kaiser", "ottakringer": "ottakringer",
    "wieselburger": "wieselburger", "schwechater": "schwechater", "puntigamer": "puntigamer",
    "murauer": "murauer", "egger": "egger", "freistädter": "freistaedter", "hirter": "hirter",
    "trumer": "trumer", "edelweiss": "edelweiss", "schremser": "schremser", "zwettler": "zwettler",
    "eggenberger": "eggenberg", "eggenberg": "eggenberg", "chang": "chang", "singha": "singha",
    "leo": "leo", "asahi": "asahi", "kirin": "kirin", "sapporo": "sapporo", "tsingtao": "tsingtao",
    "tiger": "tiger", "corona": "corona", "jelen": "jelen", "villacher": "villacher",
    "heineken": "heineken", "budweiser": "budweiser", "kozel": "kozel", "gambrinus": "gambrinus",
    "schladminger": "schladminger", "paulaner": "paulaner", "augustiner": "augustiner", "erdinger": "erdinger",
    "franziskaner": "franziskaner", "weihenstephaner": "weihenstephaner", "saigon": "saigon", "333": "saigon",
}

GUELTIG = re.compile(r"Gültig:\s*(\d{1,2})\.(\d{1,2})\.\s*-\s*(\d{1,2})\.(\d{1,2})\.")
EURO = re.compile(r"€\s*([\d.]+,\d{2}|\d+)")
LITERPREIS = re.compile(r"€\s*([\d.]+,\d{2})\s*/\s*l\b")
LIDL_PLUS = re.compile(r"LIDL PLUS APP\s*([\d]+[.,]\d{2})", re.I)


def zahl(text: str) -> float:
    return float(text.replace(".", "").replace(",", ".")) if "," in text else float(text)


def datum(tag: str, monat: str, heute: dt.date) -> str:
    jahr = heute.year
    m = int(monat)
    if m < heute.month - 6:
        jahr += 1
    elif m > heute.month + 6:
        jahr -= 1
    return dt.date(jahr, m, int(tag)).isoformat()


def verpackung_aus_liter(liter: float, text: str) -> str:
    t = text.lower()
    if 9.5 <= liter <= 10.5:
        return "kiste20x05"
    if 7.6 <= liter <= 8.6:
        return "karton24x033"
    if 2.8 <= liter <= 3.2:
        return "tragerl6x05"
    if 0.45 <= liter <= 0.55:
        return "dose05" if "dose" in t else "flasche05"
    if 0.30 <= liter <= 0.36:
        return "flasche033"
    return "sonstige"


BUNDESLAENDER = ["Wien", "Niederösterreich", "Burgenland", "Oberösterreich", "Salzburg",
                 "Steiermark", "Kärnten", "Tirol", "Vorarlberg"]


def regionen(text: str) -> list[str] | None:
    """Bundesländer, in denen das Angebot gilt (None = ganz Österreich bzw. unbekannt)."""
    t = text or ""
    if "…" in t or "..." in t:
        return None  # abgeschnittener Text – lieber nicht ausfiltern
    genannt = [b for b in BUNDESLAENDER if b in t]
    if "Süd-Burgenland" in t and "Burgenland" not in genannt:
        genannt.append("Burgenland")
    if not genannt:
        return None
    if "nicht erhältlich" in t or "ausgenommen" in t:
        return [b for b in BUNDESLAENDER if b not in genannt]
    if "gültig in" in t.lower() or "nur in" in t.lower():
        return genannt
    return None


def angebote_aus_text(text: str, heute: dt.date) -> list[dict]:
    zeilen = [z.strip() for z in text.splitlines() if z.strip()]
    ergebnis = []
    for i, z in enumerate(zeilen):
        if z != "Marke:" or i + 1 >= len(zeilen) or i == 0:
            continue
        titel = zeilen[i - 1]
        marke = zeilen[i + 1]
        preise: list[float] = []
        von = bis = None
        haendler = beschreibung = None
        j = i + 2
        while j < len(zeilen) and j < i + 14:
            zj = zeilen[j]
            if zj.startswith("€") and von is None:
                m = EURO.search(zj)
                if m:
                    preise.append(zahl(m.group(1)))
            g = GUELTIG.search(zj)
            if g:
                von = datum(g.group(1), g.group(2), heute)
                bis = datum(g.group(3), g.group(4), heute)
            if zj == "Händler:" and j + 1 < len(zeilen):
                haendler = zeilen[j + 1]
                beschreibung = zeilen[j + 2] if j + 2 < len(zeilen) else ""
                break
            j += 1
        if not preise or haendler is None or von is None:
            continue

        haendler_app = HAENDLER.get(haendler.upper())
        if haendler_app is None:
            continue  # nicht im Bezirk Amstetten
        voll = f"{titel} {beschreibung}"

        preis = preise[0]
        lp = LITERPREIS.search(beschreibung or "")
        if not lp:
            continue  # kein Literpreis = kein Getränk (z. B. „Egger Zuckerln“)
        literpreis = zahl(lp.group(1))
        liter = round(preis / literpreis, 2) if literpreis else None
        verpackung = verpackung_aus_liter(liter, voll) if liter else "sonstige"

        karten_preis = karte = None
        lidl = LIDL_PLUS.search(beschreibung or "")
        if lidl:
            karten_preis, karte = zahl(lidl.group(1).replace(".", ",")), "lidlPlus"

        marke_klein = marke.lower()
        bier_id = next((v for k, v in MARKEN.items() if marke_klein == k or marke_klein.startswith(k + " ")), None)
        if bier_id is None:
            # Spezialitäten stehen oft unter einer Händlermarke (z. B. „Asia-Woche“) – dann im Titel suchen
            titel_klein = f" {titel.lower()} "
            bier_id = next((v for k, v in MARKEN.items() if len(k) > 3 and f" {k} " in titel_klein), None)
        if marke_klein == "zipfer":
            bier_id = "zipfer_urtyp" if "urtyp" in voll.lower() else "zipfer_maerzen"

        hinweis = re.sub(r"^€\s*[\d.,]+\s*/\s*l\s*-\s*", "", beschreibung or "").strip()

        ergebnis.append({
            "bierId": bier_id,
            "marke": marke,
            "titel": titel,
            "verpackung": verpackung,
            "liter": liter,
            "haendler": haendler_app,
            "preis": preis,
            "statt": preise[1] if len(preise) > 1 and preise[1] > preis else None,
            "kartenPreis": karten_preis,
            "karte": karte,
            "von": von,
            "bis": bis,
            "hinweis": hinweis or None,
            "regionen": regionen(beschreibung),
        })
    return ergebnis


# Gebiete: Standort (PLZ + Ortsname, wie ihn die Angebotsseite vorschlägt) – je Gebiet wird einmal gesucht.
GEBIETE = [
    ("amstetten", "3300", "Amstetten"),
    ("steyr", "4400", "Steyr"),
]


def abrufen() -> list[dict]:
    heute = dt.date.today()
    alle: dict[tuple, dict] = {}
    with sync_playwright() as p:
        browser = p.chromium.launch()
        for gebiet, plz, ort in GEBIETE:
            seite = browser.new_page(locale="de-AT", timezone_id="Europe/Vienna")

            def lade(url: str) -> str:
                seite.goto(url, wait_until="networkidle", timeout=60000)
                time.sleep(PAUSE_SEKUNDEN)
                try:
                    return seite.inner_text("main", timeout=10000)
                except Exception:
                    return ""

            # Standort auf das Gebiet setzen (wie ein Besucher über „Standort festlegen“)
            try:
                lade(f"{BASIS}bier")
                seite.get_by_text("Standort festlegen").first.click()
                seite.wait_for_timeout(1000)
                seite.get_by_placeholder("Suche Postleitzahl oder Ort").fill(plz)
                seite.wait_for_timeout(2500)
                seite.get_by_text(ort).first.click()
                seite.wait_for_timeout(2500)
            except Exception as e:
                print(f"WARNUNG: Standort {ort} konnte nicht gesetzt werden: {e}")

            def merken(a: dict) -> None:
                k = (a["marke"], a["titel"], a["haendler"], a["preis"], a["von"], a["verpackung"])
                if k in alle:
                    if gebiet not in alle[k]["gebiete"]:
                        alle[k]["gebiete"].append(gebiet)
                else:
                    a["gebiete"] = [gebiet]
                    alle[k] = a

            urls = [f"{BASIS}bier"] + [f"{BASIS}bier?title=bier&page={n}" for n in range(1, MAX_SEITEN_BIER)]
            for url in urls:
                text = lade(url)
                if "Händler:" not in text:
                    break
                for a in angebote_aus_text(text, heute):
                    merken(a)
            for wort in EXTRA_SUCHWOERTER:
                for seite_nr in range(0, 4):  # bis zu 4 Ergebnisseiten je Suchwort
                    url = BASIS + wort if seite_nr == 0 else f"{BASIS}{wort}?title={wort}&page={seite_nr}"
                    text = lade(url)
                    if "Händler:" not in text:
                        break
                    for a in angebote_aus_text(text, heute):
                        if a["bierId"] is not None:  # Extra-Suche nur für bekannte Biere
                            merken(a)
                    if "NÄCHSTE SEITE" not in text.upper():
                        break
            seite.close()
        browser.close()

    # Abgelaufene Angebote weglassen
    return sorted(
        (a for a in alle.values() if a["bis"] >= heute.isoformat()),
        key=lambda a: (a["von"], a["haendler"], a["marke"]),
    )


def main() -> None:
    ziel = Path(sys.argv[1] if len(sys.argv) > 1 else "angebote.json")
    start = time.time()
    angebote = abrufen()

    # Absicherung: Liefert die Quelle (fast) nichts, behalten wir die bisherigen, noch gültigen Angebote.
    if len(angebote) < 20 and ziel.exists():
        alt = json.loads(ziel.read_text(encoding="utf-8")).get("angebote", [])
        heute_text = dt.date.today().isoformat()
        alt_gueltig = [a for a in alt if a.get("bis", "") >= heute_text]
        if len(alt_gueltig) > len(angebote):
            print(f"WARNUNG: Nur {len(angebote)} Angebote gefunden – behalte {len(alt_gueltig)} bisherige.")
            angebote = alt_gueltig
    daten = {
        "stand": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "gebiet": "Bezirk Amstetten",
        "quelle": "marktguru.at (öffentliche Suchseiten)",
        "anzahl": len(angebote),
        "angebote": angebote,
    }
    ziel.write_text(json.dumps(daten, ensure_ascii=False, indent=1), encoding="utf-8")

    # Flugblatt-Rhythmus mitschreiben: wann wurde ein neues Angebot eines Händlers zum ersten Mal gesehen?
    log_datei = ziel.with_name("erstmals_gesehen.json")
    log = json.loads(log_datei.read_text(encoding="utf-8")) if log_datei.exists() else {}
    jetzt = dt.datetime.now().isoformat(timespec="minutes")
    for a in angebote:
        log.setdefault(f'{a["haendler"]} ab {a["von"]}', jetzt)
    log_datei.write_text(json.dumps(log, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")

    # Preis-Gedächtnis: je Bier + Verpackung der niedrigste Literpreis pro Aktions-Start (1 Jahr)
    verlauf_datei = ziel.with_name("preisverlauf.json")
    verlauf = json.loads(verlauf_datei.read_text(encoding="utf-8")) if verlauf_datei.exists() else {}
    for a in angebote:
        if not a.get("bierId") or not a.get("liter"):
            continue
        lp = round(min(a["preis"], a.get("kartenPreis") or a["preis"]) / a["liter"], 3)
        eintrag = verlauf.setdefault(f'{a["bierId"]}|{a["verpackung"]}', {})
        eintrag[a["von"]] = min(lp, eintrag.get(a["von"], lp))
    grenze = (dt.date.today() - dt.timedelta(days=365)).isoformat()
    verlauf = {k: {d: p for d, p in v.items() if d >= grenze} for k, v in verlauf.items()}
    verlauf_datei.write_text(json.dumps(verlauf, ensure_ascii=False, sort_keys=True), encoding="utf-8")

    print(f"{len(angebote)} Angebote in {time.time() - start:.0f} s -> {ziel}")


if __name__ == "__main__":
    main()
