import 'dart:math' as math;

// Stammdaten: Verpackungen, Biere, Händler, Kundenkarten und Test-Angebote.

enum Verpackung {
  kiste20x05('Kiste', '20 × 0,5 l', 10.0, 16.00),
  tragerl6x05('6er-Tragerl', '6 × 0,5 l', 3.0, 4.80),
  dose05('Dose', '0,5 l', 0.5, 0.80),
  flasche05('Flasche', '0,5 l', 0.5, 0.80),
  flasche033('Einwegflasche', '0,33 l', 0.33, 0.65),
  karton24x033('Karton', '24 × 0,33 l', 7.92, 30.00);

  const Verpackung(this.titel, this.inhalt, this.liter, this.vorschlagPreis);
  final String titel;
  final String inhalt;
  final double liter;

  /// Vorschlag für den Wunschpreis (der Benutzer kann ihn ändern).
  final double vorschlagPreis;

  String get bezeichnung => '$titel $inhalt';
}

enum Kundenkarte {
  joe('Jö-Karte', 'Billa, Billa Plus, Spar, Eurospar, Interspar, Penny', 'https://www.joe-club.at'),
  lidlPlus('Lidl Plus', 'Lidl', 'https://www.lidl.at/c/lidl-plus/s10007617'),
  metro('Metro-Karte', 'Metro (nur für Gewerbe)', 'https://www.metro.at'),
  transgourmet('Transgourmet-Karte', 'Transgourmet (nur für Gewerbe)', 'https://www.transgourmet.at');

  const Kundenkarte(this.titel, this.haendler, this.link);
  final String titel;
  final String haendler;
  final String link;
}

class Bier {
  const Bier(
    this.id,
    this.name,
    this.herkunft,
    this.verpackungen, {
    this.spezialitaet = false,
    this.premium = false,
  });

  final String id;
  final String name;
  final String herkunft;
  final List<Verpackung> verpackungen;

  /// Importe und seltene Biere: standardmäßig „Immer melden, Preis egal“.
  final bool spezialitaet;

  /// Teurere Biere (z. B. Zipfer Urtyp) bekommen einen höheren Preisvorschlag.
  final bool premium;

  double vorschlagPreis(Verpackung v) {
    if (premium && v == Verpackung.kiste20x05) return 20.00;
    if (premium && v == Verpackung.tragerl6x05) return 6.00;
    if (premium) return v.vorschlagPreis * 1.25;
    return v.vorschlagPreis;
  }
}

const _alle = [
  Verpackung.kiste20x05,
  Verpackung.tragerl6x05,
  Verpackung.dose05,
  Verpackung.flasche05,
  Verpackung.flasche033,
];
const _ohneDose = [
  Verpackung.kiste20x05,
  Verpackung.tragerl6x05,
  Verpackung.flasche05,
  Verpackung.flasche033,
];
const _import = [Verpackung.karton24x033, Verpackung.flasche033, Verpackung.dose05];

const biere = <Bier>[
  // Österreich
  Bier('zipfer_maerzen', 'Zipfer Märzen', 'Oberösterreich', _alle),
  Bier('zipfer_urtyp', 'Zipfer Urtyp', 'Oberösterreich', _alle, premium: true),
  Bier('goesser', 'Gösser Märzen', 'Steiermark', _alle),
  Bier('stiegl', 'Stiegl Goldbräu', 'Salzburg', _alle),
  Bier('kaiser', 'Kaiser Fasstyp', 'Österreich', _alle),
  Bier('ottakringer', 'Ottakringer Helles', 'Wien', _alle),
  Bier('wieselburger', 'Wieselburger Gold', 'Niederösterreich', _alle),
  Bier('schwechater', 'Schwechater', 'Niederösterreich', _alle),
  Bier('puntigamer', 'Puntigamer', 'Steiermark', _alle),
  Bier('murauer', 'Murauer Märzen', 'Steiermark', _ohneDose),
  Bier('egger', 'Egger Märzen', 'Niederösterreich', _alle),
  Bier('freistaedter', 'Freistädter Ratsherrn', 'Oberösterreich', _ohneDose, premium: true),
  Bier('hirter', 'Hirter Privat Pils', 'Kärnten', _ohneDose, premium: true),
  Bier('trumer', 'Trumer Pils', 'Salzburg', _ohneDose, premium: true),
  Bier('edelweiss', 'Edelweiss Weißbier', 'Salzburg', _ohneDose, premium: true),
  Bier('schremser', 'Schremser Märzen', 'Niederösterreich', _ohneDose),
  Bier('zwettler', 'Zwettler Original', 'Niederösterreich', _ohneDose),
  Bier('eggenberg', 'Eggenberger Märzen', 'Oberösterreich', _ohneDose),
  Bier('villacher', 'Villacher Märzen', 'Kärnten', _alle),
  Bier('schladminger', 'Schladminger', 'Steiermark', _ohneDose),
  // Deutschland
  Bier('paulaner', 'Paulaner', 'Deutschland', _ohneDose, premium: true),
  Bier('augustiner', 'Augustiner', 'Deutschland', _ohneDose, premium: true),
  Bier('erdinger', 'Erdinger Weißbier', 'Deutschland', _ohneDose, premium: true),
  Bier('franziskaner', 'Franziskaner Weißbier', 'Deutschland', _ohneDose, premium: true),
  Bier('weihenstephaner', 'Weihenstephaner', 'Deutschland', _ohneDose, premium: true),
  // Importe und Spezialitäten
  Bier('chang', 'Chang', 'Thailand', _import, spezialitaet: true),
  Bier('singha', 'Singha', 'Thailand', _import, spezialitaet: true),
  Bier('leo', 'Leo', 'Thailand', _import, spezialitaet: true),
  Bier('asahi', 'Asahi Super Dry', 'Japan', _import, spezialitaet: true),
  Bier('kirin', 'Kirin Ichiban', 'Japan', _import, spezialitaet: true),
  Bier('sapporo', 'Sapporo', 'Japan', _import, spezialitaet: true),
  Bier('tsingtao', 'Tsingtao', 'China', _import, spezialitaet: true),
  Bier('tiger', 'Tiger', 'Singapur', _import, spezialitaet: true),
  Bier('saigon', 'Saigon / 333', 'Vietnam', _import, spezialitaet: true),
  Bier('corona', 'Corona Extra', 'Mexiko', _import, spezialitaet: true),
  Bier('jelen', 'Jelen', 'Serbien', [Verpackung.flasche05, Verpackung.dose05], spezialitaet: true),
  Bier('heineken', 'Heineken', 'Niederlande', [..._alle, Verpackung.karton24x033], spezialitaet: true),
  Bier('budweiser', 'Budweiser Budvar', 'Tschechien', _alle, spezialitaet: true),
  Bier('kozel', 'Kozel', 'Tschechien', _alle, spezialitaet: true),
  Bier('gambrinus', 'Gambrinus', 'Tschechien', _alle, spezialitaet: true),
];

Bier bierMitId(String id) => biere.firstWhere((b) => b.id == id);

class Angebot {
  const Angebot({
    required this.bierId,
    required this.verpackung,
    required this.haendler,
    required this.preis,
    required this.von,
    required this.bis,
    this.kartenPreis,
    this.karte,
    this.hinweis,
    this.beispiel = false,
    this.statt,
    this.regionen,
    this.gebiete,
  });

  /// In welchen BierRadar-Gebieten das Angebot gefunden wurde (null = überall).
  final List<String>? gebiete;

  /// Bundesländer, in denen das Angebot gilt (null = ganz Österreich).
  final List<String>? regionen;

  final String bierId;
  final Verpackung verpackung;
  final String haendler;
  final double preis;
  final double? kartenPreis;
  final Kundenkarte? karte;
  final DateTime von;
  final DateTime bis;
  final String? hinweis;

  /// Erfundenes Beispiel, nur damit man sieht, wie es in der App ausschaut.
  final bool beispiel;

  /// Normalpreis laut Flugblatt (wenn angegeben).
  final double? statt;

  Bier get bier => bierMitId(bierId);

  /// Liest ein Angebot aus der Datei des Abrufs. Unbekanntes wird übersprungen (null).
  static Angebot? ausJson(Map<String, dynamic> j) {
    final id = j['bierId'] as String?;
    if (id == null || !biere.any((b) => b.id == id)) return null;
    final v = Verpackung.values.where((x) => x.name == j['verpackung']).firstOrNull;
    if (v == null) return null;
    final karte = Kundenkarte.values.where((x) => x.name == j['karte']).firstOrNull;
    return Angebot(
      bierId: id,
      verpackung: v,
      haendler: j['haendler'] as String,
      preis: (j['preis'] as num).toDouble(),
      kartenPreis: (j['kartenPreis'] as num?)?.toDouble(),
      karte: karte,
      von: DateTime.parse(j['von'] as String),
      bis: DateTime.parse(j['bis'] as String),
      hinweis: j['hinweis'] as String?,
      statt: (j['statt'] as num?)?.toDouble(),
      gebiete: switch (j['gebiete']) {
        final List<dynamic> l => l.cast<String>(),
        final String t when t.isNotEmpty => t.split(','),
        _ => null,
      },
      regionen: switch (j['regionen']) {
        final List<dynamic> l => l.cast<String>(),
        final String t when t.isNotEmpty => t.split(','),
        _ => null,
      },
    );
  }
}

DateTime _d(int tag, int monat) => DateTime(2026, monat, tag);

/// Echte Angebote aus Testrunde 1 (Flugblätter ab 19.11.2026), plus zwei Beispiele.
final testAngebote = <Angebot>[
  Angebot(
    bierId: 'kaiser',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Lidl',
    preis: 14.80,
    kartenPreis: 12.80,
    karte: Kundenkarte.lidlPlus,
    von: _d(19, 11),
    bis: _d(21, 11),
  ),
  Angebot(
    bierId: 'goesser',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Hofer',
    preis: 13.80,
    von: _d(20, 11),
    bis: _d(21, 11),
    hinweis: 'zzgl. Pfand',
  ),
  Angebot(
    bierId: 'goesser',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Billa',
    preis: 13.80,
    von: _d(19, 11),
    bis: _d(25, 11),
  ),
  Angebot(
    bierId: 'goesser',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Spar',
    preis: 14.90,
    von: _d(19, 11),
    bis: _d(2, 12),
  ),
  Angebot(
    bierId: 'stiegl',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Penny',
    preis: 14.40,
    von: _d(19, 11),
    bis: _d(21, 11),
  ),
  Angebot(
    bierId: 'murauer',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Lidl',
    preis: 14.80,
    kartenPreis: 14.40,
    karte: Kundenkarte.lidlPlus,
    von: _d(19, 11),
    bis: _d(21, 11),
  ),
  Angebot(
    bierId: 'puntigamer',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Billa Plus',
    preis: 14.80,
    von: _d(19, 11),
    bis: _d(25, 11),
    hinweis: 'gilt in Niederösterreich',
  ),
  Angebot(
    bierId: 'schwechater',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Spar',
    preis: 15.80,
    von: _d(19, 11),
    bis: _d(2, 12),
  ),
  Angebot(
    bierId: 'schwechater',
    verpackung: Verpackung.flasche05,
    haendler: 'Billa',
    preis: 0.59,
    von: _d(19, 11),
    bis: _d(25, 11),
  ),
  Angebot(
    bierId: 'ottakringer',
    verpackung: Verpackung.flasche05,
    haendler: 'Billa',
    preis: 0.69,
    von: _d(19, 11),
    bis: _d(25, 11),
  ),
  Angebot(
    bierId: 'wieselburger',
    verpackung: Verpackung.flasche05,
    haendler: 'Billa',
    preis: 0.69,
    von: _d(19, 11),
    bis: _d(25, 11),
  ),
  Angebot(
    bierId: 'goesser',
    verpackung: Verpackung.flasche05,
    haendler: 'Billa',
    preis: 0.74,
    von: _d(19, 11),
    bis: _d(25, 11),
  ),
  Angebot(
    bierId: 'stiegl',
    verpackung: Verpackung.dose05,
    haendler: 'Lidl',
    preis: 0.79,
    von: _d(19, 11),
    bis: _d(21, 11),
    hinweis: 'max. 120 Dosen',
  ),
  Angebot(
    bierId: 'goesser',
    verpackung: Verpackung.flasche033,
    haendler: 'Lidl',
    preis: 0.64,
    von: _d(19, 11),
    bis: _d(21, 11),
  ),
  Angebot(
    bierId: 'jelen',
    verpackung: Verpackung.flasche05,
    haendler: 'Lidl',
    preis: 1.39,
    von: _d(19, 11),
    bis: _d(25, 11),
  ),
  Angebot(
    bierId: 'chang',
    verpackung: Verpackung.karton24x033,
    haendler: 'Lidl',
    preis: 27.99,
    von: _d(24, 11),
    bis: _d(29, 11),
    beispiel: true,
  ),
  Angebot(
    bierId: 'zipfer_urtyp',
    verpackung: Verpackung.kiste20x05,
    haendler: 'Billa',
    preis: 18.99,
    kartenPreis: 17.49,
    karte: Kundenkarte.joe,
    von: _d(19, 11),
    bis: _d(25, 11),
    beispiel: true,
  ),
];

String euro(double wert) => '${wert.toStringAsFixed(2).replaceAll('.', ',')} €';

String zeitraum(DateTime von, DateTime bis) {
  if (von.month == bis.month) return '${von.day}.–${bis.day}.${bis.month}.';
  return '${von.day}.${von.month}.–${bis.day}.${bis.month}.';
}

/// Adresse der Angebotsdatei im Internet (wird mit dem GitHub-Konto gesetzt).
/// Leer = die App nimmt den letzten Stand bzw. die mitgelieferte Datei.
const angeboteUrl = 'https://raw.githubusercontent.com/augstenm-bit/bierradar/main/server/angebote.json';

/// Pfand in Österreich (Stand 2025/26): Mehrweg-Glasflasche 0,5 l = 0,20 €, Dose/PET = 0,25 €,
/// Bierkiste 20 × 0,5 l insgesamt ca. 7 € (Flaschen + Kiste). Einweg-Glas hat kein Pfand.
String? pfandText(Verpackung v) => switch (v) {
  Verpackung.kiste20x05 => '+ ca. 7 € Pfand',
  Verpackung.tragerl6x05 => '+ 1,20 € Pfand',
  Verpackung.flasche05 => '+ 0,20 € Pfand',
  Verpackung.dose05 => '+ 0,25 € Pfand',
  _ => null,
};

/// Gebiete, für die BierRadar Angebote zeigt.
enum Gebiet {
  amstetten('Bezirk Amstetten', 'Niederösterreich', 48.1229, 14.8720),
  steyr('Bezirk Steyr', 'Oberösterreich', 48.0427, 14.4213);

  const Gebiet(this.titel, this.bundesland, this.breite, this.laenge);
  final String titel;
  final String bundesland;
  final double breite;
  final double laenge;

  String get kurz => titel.replaceFirst('Bezirk ', '');
}

/// Entfernung in Kilometern (Luftlinie).
double entfernungKm(double b1, double l1, double b2, double l2) {
  const r = 6371.0;
  double rad(double g) => g * math.pi / 180;
  final db = rad(b2 - b1), dl = rad(l2 - l1);
  final a =
      math.sin(db / 2) * math.sin(db / 2) +
      math.cos(rad(b1)) * math.cos(rad(b2)) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Händler, die nur mit Gewerbekarte einkaufen lassen.
const gewerbeHaendler = {'Metro': Kundenkarte.metro, 'Transgourmet': Kundenkarte.transgourmet};

/// Eine echte Filiale (aus OpenStreetMap).
class Filiale {
  const Filiale(this.haendler, this.name, this.adresse, this.breite, this.laenge);
  final String haendler;
  final String name;
  final String adresse;
  final double breite;
  final double laenge;

  factory Filiale.ausJson(Map<String, dynamic> j) => Filiale(
    j['h'] as String,
    j['n'] as String,
    j['a'] as String? ?? '',
    (j['b'] as num).toDouble(),
    (j['l'] as num).toDouble(),
  );
}
