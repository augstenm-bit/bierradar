"""Bierradar – Angebots-Abruf.

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
    "chang", "singha", "leo bier", "asahi", "kirin", "sapporo", "tsingtao", "tiger bier",
    "corona", "jelen", "heineken", "budweiser", "kozel", "villacher", "zipfer", "egger", "freistädter", "hirter", "trumer", "edelweiss",
    "schremser", "zwettler", "eggenberger", "murauer", "kaiser bier", "wieselburger",
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


def gilt_in_noe(text: str) -> bool:
    t = text.lower()
    if "nur gültig in" in t or "gültig in" in t:
        return "niederösterreich" in t or "ganz österreich" in t or "…" in text or "..." in text
    return True


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
        if not gilt_in_noe(beschreibung):
            continue

        preis = preise[0]
        lp = LITERPREIS.search(beschreibung or "")
        literpreis = zahl(lp.group(1)) if lp else None
        liter = round(preis / literpreis, 2) if literpreis else None
        verpackung = verpackung_aus_liter(liter, voll) if liter else "sonstige"

        karten_preis = karte = None
        lidl = LIDL_PLUS.search(beschreibung or "")
        if lidl:
            karten_preis, karte = zahl(lidl.group(1).replace(".", ",")), "lidlPlus"

        marke_klein = marke.lower()
        bier_id = next((v for k, v in MARKEN.items() if marke_klein == k or marke_klein.startswith(k + " ")), None)
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
        })
    return ergebnis


def abrufen() -> list[dict]:
    heute = dt.date.today()
    alle: dict[tuple, dict] = {}
    with sync_playwright() as p:
        browser = p.chromium.launch()
        seite = browser.new_page(locale="de-AT")

        def lade(url: str) -> str:
            seite.goto(url, wait_until="networkidle", timeout=60000)
            time.sleep(PAUSE_SEKUNDEN)
            try:
                return seite.inner_text("main", timeout=10000)
            except Exception:
                return ""

        urls = [f"{BASIS}bier"] + [f"{BASIS}bier?title=bier&page={n}" for n in range(1, MAX_SEITEN_BIER)]
        for url in urls:
            text = lade(url)
            gefunden = angebote_aus_text(text, heute)
            if "Händler:" not in text:
                break
            for a in gefunden:
                alle[(a["marke"], a["titel"], a["haendler"], a["preis"], a["von"], a["verpackung"])] = a
        for wort in EXTRA_SUCHWOERTER:
            for a in angebote_aus_text(lade(BASIS + wort), heute):
                if a["bierId"] is None:
                    continue  # Extra-Suche nur für bekannte Biere (sonst z. B. Corona-Limo, Tiger-Balsam …)
                alle[(a["marke"], a["titel"], a["haendler"], a["preis"], a["von"], a["verpackung"])] = a
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

    print(f"{len(angebote)} Angebote in {time.time() - start:.0f} s -> {ziel}")


if __name__ == "__main__":
    main()
