"""Bierradar – Push-Meldungen für neue Angebote.

Vergleicht angebote.json mit den schon gemeldeten Angeboten (gemeldet.json) und schickt für jedes
neue Angebot EINE Nachricht an das passende Firebase-Thema, z. B. „b_goesser_kiste20x05“.
Jedes Handy hat die Themen seiner Lieblingsbiere abonniert und entscheidet selbst anhand des
eigenen Wunschpreises, ob es eine Benachrichtigung zeigt. So braucht der Server keine Benutzerdaten.

Der geheime Firebase-Schlüssel kommt aus der Umgebungsvariable FIREBASE_SCHLUESSEL (GitHub Secret).
Ohne Schlüssel wird nur angezeigt, was gemeldet würde (Probelauf).

Aufruf:  python melden.py angebote.json
"""
from __future__ import annotations

import datetime as dt
import json
import os
import sys
from pathlib import Path

GEMELDET = Path(__file__).with_name("gemeldet.json")
MAX_PRO_LAUF = 60  # Sicherheitsgrenze


def thema(a: dict) -> str:
    return f'b_{a["bierId"]}_{a["verpackung"]}'


def schluessel(a: dict) -> str:
    return f'{a["bierId"]}|{a["verpackung"]}|{a["haendler"]}|{a["preis"]}|{a["von"]}'


def euro(x: float) -> str:
    return f"{x:.2f}".replace(".", ",") + " €"


def nachricht(a: dict) -> dict:
    """Reine Daten-Nachricht: das Handy baut daraus selbst die Benachrichtigung."""
    daten = {
        "art": "angebot",
        "bierId": a["bierId"],
        "marke": a["marke"],
        "titel": a["titel"],
        "verpackung": a["verpackung"],
        "haendler": a["haendler"],
        "preis": str(a["preis"]),
        "von": a["von"],
        "bis": a["bis"],
    }
    if a.get("kartenPreis"):
        daten["kartenPreis"] = str(a["kartenPreis"])
        daten["karte"] = a.get("karte") or ""
    if a.get("statt"):
        daten["statt"] = str(a["statt"])
    return {
        "message": {
            "topic": thema(a),
            "data": daten,
            "android": {"priority": "high", "ttl": "86400s"},
        }
    }


def senden(nachrichten: list[dict]) -> int:
    roh = os.environ.get("FIREBASE_SCHLUESSEL", "").strip()
    if not roh:
        for n in nachrichten:
            d = n["message"]["data"]
            print(f'[Probelauf] {n["message"]["topic"]}: {d["marke"]} bei {d["haendler"]} um {euro(float(d["preis"]))}')
        return 0

    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account

    info = json.loads(roh)
    zugang = service_account.Credentials.from_service_account_info(
        info, scopes=["https://www.googleapis.com/auth/firebase.messaging"]
    )
    sitzung = AuthorizedSession(zugang)
    url = f'https://fcm.googleapis.com/v1/projects/{info["project_id"]}/messages:send'
    ok = 0
    for n in nachrichten:
        r = sitzung.post(url, json=n, timeout=20)
        if r.status_code == 200:
            ok += 1
        else:
            print("Fehler beim Senden:", r.status_code, r.text[:200])
    return ok


def main() -> None:
    quelle = Path(sys.argv[1] if len(sys.argv) > 1 else "angebote.json")
    angebote = json.loads(quelle.read_text(encoding="utf-8"))["angebote"]
    gemeldet: dict[str, str] = json.loads(GEMELDET.read_text(encoding="utf-8")) if GEMELDET.exists() else {}
    erster_lauf = not GEMELDET.exists()

    heute = dt.date.today().isoformat()
    neu = [a for a in angebote if a.get("bierId") and a["bis"] >= heute and schluessel(a) not in gemeldet]

    if erster_lauf:
        # Beim allerersten Mal nichts verschicken, nur merken – sonst käme eine Flut alter Angebote.
        print(f"Erster Lauf: {len(neu)} Angebote als bekannt gemerkt, nichts gesendet.")
    else:
        auswahl = neu[:MAX_PRO_LAUF]
        gesendet = senden([nachricht(a) for a in auswahl])
        print(f"{len(neu)} neue Angebote, {gesendet} Meldungen gesendet.")

    jetzt = dt.datetime.now().isoformat(timespec="minutes")
    for a in neu:
        gemeldet[schluessel(a)] = jetzt
    # Abgelaufene Einträge aufräumen
    gueltig = {schluessel(a) for a in angebote}
    gemeldet = {k: v for k, v in gemeldet.items() if k in gueltig}
    GEMELDET.write_text(json.dumps(gemeldet, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")


if __name__ == "__main__":
    main()
