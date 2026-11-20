"""BierRadar – Filialen-Liste aus OpenStreetMap (frei nutzbar, © OpenStreetMap-Mitwirkende, ODbL).

Holt alle Supermärkte, Getränkemärkte usw. in den unterstützten Bezirken und schreibt filialen.json:
[{"h": Händler wie in der App, "n": Name, "a": Adresse, "b": Breite, "l": Länge}, …]

Aufruf:  python filialen.py filialen.json     (einmal pro Woche reicht)
"""
from __future__ import annotations

import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

# Unterstützte Bezirke (Namen wie in OpenStreetMap)
BEZIRKE = ["Bezirk Amstetten", "Steyr", "Bezirk Steyr-Land"]

ABFRAGE = """
[out:json][timeout:120];
(
  area["name"="Bezirk Amstetten"]["boundary"="administrative"];
  area["name"="Steyr"]["boundary"="administrative"]["admin_level"~"6|8"];
  area["name"="Bezirk Steyr-Land"]["boundary"="administrative"];
)->.g;
(
  nwr["shop"~"^(supermarket|beverages|convenience|wholesale|department_store|agrarian|doityourself|garden_centre)$"](area.g);
)->.s;
.s out center tags;
"""

# Name/Marke in OpenStreetMap → Händler-Name in der App (Reihenfolge wichtig: Spezielles zuerst)
ZUORDNUNG = [
    ("interspar", "Interspar"),
    ("eurospar", "Eurospar"),
    ("spar gourmet", "Spar Gourmet"),
    ("spar", "Spar"),
    ("billa plus", "Billa Plus"),
    ("billa", "Billa"),
    ("hofer", "Hofer"),
    ("lidl", "Lidl"),
    ("penny", "Penny"),
    ("unimarkt", "Unimarkt"),
    ("adeg", "ADEG"),
    ("nah & frisch", "Nah & Frisch"),
    ("nah&frisch", "Nah & Frisch"),
    ("mpreis", "MPreis"),
    ("m-preis", "MPreis"),
    ("maximarkt", "Maximarkt"),
    ("norma", "Norma"),
    ("lagerhaus", "Lagerhaus"),
    ("metro", "Metro"),
    ("transgourmet", "Transgourmet"),
]


def haendler(tags: dict) -> str | None:
    text = f'{tags.get("brand", "")} {tags.get("name", "")} {tags.get("operator", "")}'.lower()
    if "genol" in text or tags.get("amenity") == "fuel":
        return None  # Tankstelle, kein Markt
    for stichwort, h in ZUORDNUNG:
        if stichwort in text:
            return h
    if tags.get("shop") == "beverages":
        return "Getränkehandel"
    return None


def adresse(tags: dict) -> str:
    strasse = " ".join(x for x in [tags.get("addr:street"), tags.get("addr:housenumber")] if x)
    ort = " ".join(x for x in [tags.get("addr:postcode"), tags.get("addr:city")] if x)
    return ", ".join(x for x in [strasse, ort] if x)


def main() -> None:
    ziel = Path(sys.argv[1] if len(sys.argv) > 1 else "filialen.json")
    daten = urllib.parse.urlencode({"data": ABFRAGE}).encode()
    anfrage = urllib.request.Request(
        "https://overpass-api.de/api/interpreter", data=daten, headers={"User-Agent": "BierRadar/1.0 (privat)"}
    )
    try:
        with urllib.request.urlopen(anfrage, timeout=150) as r:
            elemente = json.load(r)["elements"]
    except Exception:
        # Ausweichweg (z. B. alte Verschlüsselung am Mac): curl
        import subprocess

        roh = subprocess.run(
            ["curl", "-s", "--max-time", "150", "-A", "BierRadar/1.0 (privat)", "--data-urlencode", "data@-",
             "https://overpass-api.de/api/interpreter"],
            input=ABFRAGE.encode(), capture_output=True, check=True,
        ).stdout
        elemente = json.loads(roh)["elements"]

    filialen = []
    for e in elemente:
        t = e.get("tags", {})
        h = haendler(t)
        if not h:
            continue
        b = e.get("lat") or e.get("center", {}).get("lat")
        l = e.get("lon") or e.get("center", {}).get("lon")
        if b is None or l is None:
            continue
        filialen.append({"h": h, "n": t.get("name") or h, "a": adresse(t), "b": round(b, 5), "l": round(l, 5)})

    filialen.sort(key=lambda f: (f["h"], f["n"]))
    if len(filialen) < 50:
        print(f"WARNUNG: nur {len(filialen)} Filialen – behalte die alte Liste.")
        return
    ziel.write_text(json.dumps(filialen, ensure_ascii=False, indent=0), encoding="utf-8")
    print(f"{len(filialen)} Filialen -> {ziel}")


if __name__ == "__main__":
    main()
