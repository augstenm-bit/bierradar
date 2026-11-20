// Was der Benutzer ausgewählt hat – wird am Handy gespeichert.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'daten.dart';

class Wunsch {
  Wunsch({this.maxPreis, this.immerMelden = false});

  double? maxPreis;
  bool immerMelden;

  Map<String, dynamic> toJson() => {'p': maxPreis, 'i': immerMelden};
  factory Wunsch.fromJson(Map<String, dynamic> j) =>
      Wunsch(maxPreis: (j['p'] as num?)?.toDouble(), immerMelden: j['i'] == true);
}

enum Bewertung { spezialitaet, guterDeal, nurMitKarte, zuTeuer }

class Treffer {
  Treffer(this.angebot, this.bewertung, this.preisFuerMich, this.wunsch);
  final Angebot angebot;
  final Bewertung bewertung;
  final double preisFuerMich;
  final Wunsch wunsch;

  double get literPreis => preisFuerMich / angebot.verpackung.liter;
}

class AppZustand extends ChangeNotifier {
  bool geladen = false;
  bool einrichtungFertig = false;

  /// bierId -> Verpackung -> Wunsch
  final Map<String, Map<Verpackung, Wunsch>> auswahl = {};
  final Set<Kundenkarte> karten = {};
  bool kartenAngeboteZeigen = true;
  Gebiet gebiet = Gebiet.amstetten;

  /// Letzter bekannter Standort (null = nicht erlaubt/unbekannt) und Radar-Reichweite in km.
  double? standortBreite;
  double? standortLaenge;
  double radiusKm = 25;

  void gebietSetzen(Gebiet g) {
    gebiet = g;
    aenderung();
  }

  /// Genauigkeit des Standorts in Metern und ob iOS nur den ungefähren Standort liefert.
  double? standortGenauigkeit;
  bool standortUngenau = false;
  DateTime? standortZeit;

  void standortSetzen(double breite, double laenge, {double? genauigkeitMeter, bool ungenau = false}) {
    standortBreite = breite;
    standortLaenge = laenge;
    standortGenauigkeit = genauigkeitMeter;
    standortUngenau = ungenau;
    standortZeit = DateTime.now();
    gebiet = Gebiet.values.reduce(
      (a, b) =>
          entfernungKm(breite, laenge, a.breite, a.laenge) <= entfernungKm(breite, laenge, b.breite, b.laenge)
          ? a
          : b,
    );
    aenderung();
  }

  void radiusSetzen(double km) {
    radiusKm = km;
    aenderung();
  }

  /// Echte Filialen (OpenStreetMap) – damit nur Ketten mit Geschäft im Umkreis angezeigt werden.
  List<Filiale> filialen = [];

  /// Mittelpunkt der Suche: eigener Standort, sonst Mitte des Bezirks.
  double get mitteBreite => gewaehlterOrt?.breite ?? standortBreite ?? gebiet.breite;
  double get mitteLaenge => gewaehlterOrt?.laenge ?? standortLaenge ?? gebiet.laenge;

  // ---- Meine Orte (bis zu [maxOrte], mit eigenem Namen) ----
  /// Gespeicherte Orte (Schlüssel = interne Kennung). Bleiben nur am Handy.
  final Map<String, Ort> orte = {};

  /// Tipp „Orte speichern“ auf der Radar-Seite schon weggeklickt?
  bool ortTippGesehen = false;

  void ortTippSchliessen() {
    ortTippGesehen = true;
    aenderung();
  }

  /// Neue Kennung für einen weiteren Ort.
  String neueOrtKennung() {
    var i = 1;
    while (orte.containsKey('ort$i')) {
      i++;
    }
    return 'ort$i';
  }

  /// Was der Mittelpunkt der Suche ist: 'standort' oder eine Kennung aus [orte].
  String ortWahl = 'standort';

  Ort? get gewaehlterOrt => ortWahl == 'standort' ? null : orte[ortWahl];

  /// Nächstes Gebiet zum aktuellen Mittelpunkt (für Bundesland-Regeln).
  Gebiet get naechstesGebiet => Gebiet.values.reduce(
    (a, b) =>
        entfernungKm(mitteBreite, mitteLaenge, a.breite, a.laenge) <=
            entfernungKm(mitteBreite, mitteLaenge, b.breite, b.laenge)
        ? a
        : b,
  );

  void ortSetzen(String art, Ort ort) {
    orte[art] = ort;
    ortTippGesehen = true;
    aenderung();
  }

  void ortLoeschen(String art) {
    orte.remove(art);
    if (ortWahl == art) ortWahl = 'standort';
    aenderung();
  }

  void ortWaehlen(String art) {
    ortWahl = art;
    aenderung();
  }

  /// Nächste Filiale eines Händlers mit Entfernung in km (null = keine bekannt).
  (Filiale, double)? naechsteFiliale(String haendler) {
    (Filiale, double)? beste;
    for (final f in filialen) {
      if (f.haendler != haendler) continue;
      final d = entfernungKm(mitteBreite, mitteLaenge, f.breite, f.laenge);
      if (beste == null || d < beste.$2) beste = (f, d);
    }
    return beste;
  }

  /// Kleinster Umkreis (in sinnvollen Schritten) mit Treffern: (km, Anzahl) – oder null bis 100 km.
  (int, int)? umkreisVorschlag() {
    final vorher = radiusKm;
    try {
      for (final km in [2, 3, 5, 7, 10, 15, 20, 25, 30, 40, 50, 75, 100]) {
        if (km <= vorher) continue;
        radiusKm = km.toDouble(); // nur zum Durchrechnen, ohne Speichern
        final n = treffer(angebote).where((t) => t.bewertung != Bewertung.zuTeuer).length;
        if (n > 0) return (km, n);
      }
      return null;
    } finally {
      radiusKm = vorher;
    }
  }

  /// Kurzer Text zur nächsten Filiale, z. B. „Billa Steyr · 2,3 km“ (sonst nur der Händler).
  String filialText(String haendler) {
    final n = naechsteFiliale(haendler);
    if (n == null) return haendler;
    final (f, km) = n;
    // Ort aus der Adresse („…, 4400 Steyr“ → „Steyr“), sonst aus dem Namen
    var ort = '';
    if (f.adresse.contains(',')) {
      ort = f.adresse.split(',').last.trim().replaceFirst(RegExp(r'^\d{4}\s*'), '');
    } else if (RegExp(r'^\d{4}\s').hasMatch(f.adresse)) {
      ort = f.adresse.replaceFirst(RegExp(r'^\d{4}\s*'), '');
    }
    if (ort.isEmpty) {
      final rest = f.name.replaceFirst(RegExp(haendler, caseSensitive: false), '').trim();
      ort = rest.replaceAll(RegExp(r'^[-–,\s]+'), '');
    }
    final entfernung = km < 10 ? km.toStringAsFixed(1).replaceAll('.', ',') : km.round().toString();
    return '${ort.isEmpty ? haendler : '$haendler $ort'} · $entfernung km';
  }

  /// Anzahl Geschäfte (aller Ketten) im Umkreis.
  int get geschaefteImUmkreis =>
      filialen.where((f) => entfernungKm(mitteBreite, mitteLaenge, f.breite, f.laenge) <= radiusKm).length;

  /// Gebiete im Radar: immer das nächste Gebiet, dazu alle, deren Mitte im Umkreis liegt.
  Set<Gebiet> get aktiveGebiete {
    final b = mitteBreite;
    final l = mitteLaenge;
    return {
      naechstesGebiet,
      for (final g in Gebiet.values)
        if (entfernungKm(b, l, g.breite, g.laenge) <= radiusKm) g,
    };
  }

  DateTime? kartenHinweisVersteckt;

  /// Gemerkte Angebote (Schlüssel siehe [angebotSchluessel]) → für die „endet morgen“-Erinnerung.
  final Set<String> gemerkt = {};

  /// Gekaufte Angebote (mit Anzahl, Datum, Ersparnis je Stück) – Grundlage für Ersparnis, Ränge, Bierjahr.
  final Map<String, Kauf> gekauft = {};

  /// Ersparnis aus einer älteren App-Version (vor den Kauf-Details).
  double gespartAlt = 0;

  /// Abgehakte Einträge auf dem Einkaufszettel.
  final Set<String> abgehakt = {};

  double get gespartGesamt => gespartAlt + gekauft.values.fold(0.0, (s, k) => s + k.ersparnisJe * k.anzahl);

  static String angebotSchluessel(Angebot a) =>
      '${a.bierId}|${a.verpackung.name}|${a.haendler}|${a.preis}|${a.von.toIso8601String().substring(0, 10)}';

  void merkenUmschalten(Angebot a) {
    final k = angebotSchluessel(a);
    if (!gemerkt.remove(k)) gemerkt.add(k);
    abgehakt.remove(k);
    aenderung();
  }

  void abhakenUmschalten(String k) {
    if (!abgehakt.remove(k)) abgehakt.add(k);
    aenderung();
  }

  /// Ersparnis eines Angebots gegenüber dem Normalpreis (0, wenn unbekannt).
  static double ersparnis(Angebot a, double preisFuerMich) =>
      a.statt != null && a.statt! > preisFuerMich ? a.statt! - preisFuerMich : 0;

  /// Setzt die gekaufte Anzahl (0 = nicht gekauft). Gibt den neuen Rang zurück, wenn man aufgestiegen ist.
  Rang? gekauftSetzen(Angebot a, double preisFuerMich, int anzahl) {
    final rangVorher = rangFuer(gespartGesamt);
    final k = angebotSchluessel(a);
    if (anzahl <= 0) {
      gekauft.remove(k);
    } else {
      gekauft[k] = Kauf(
        bierId: a.bierId,
        verpackung: a.verpackung.name,
        haendler: a.haendler,
        preis: preisFuerMich,
        ersparnisJe: ersparnis(a, preisFuerMich),
        anzahl: anzahl,
        datum: gekauft[k]?.datum ?? DateTime.now(),
      );
    }
    aenderung();
    final rangJetzt = rangFuer(gespartGesamt);
    return raenge.indexOf(rangJetzt) > raenge.indexOf(rangVorher) ? rangJetzt : null;
  }

  static const _schluessel = 'bier_app_zustand_v1';
  static const _angeboteSchluessel = 'bier_app_angebote_v1';

  // ---- Angebote (vom Abruf-Server) ----
  List<Angebot> angebote = [];

  /// Preis-Gedächtnis: „bierId|verpackung“ → {Aktions-Start → niedrigster Literpreis}.
  Map<String, Map<String, double>> preisverlauf = {};

  /// Wenn das Angebot so günstig ist wie seit mindestens 2 Wochen nicht: Anzahl Wochen, sonst null.
  int? tiefstpreisWochen(Angebot a, double literPreis) {
    final v = preisverlauf['${a.bierId}|${a.verpackung.name}'];
    if (v == null) return null;
    final vonText = a.von.toIso8601String().substring(0, 10);
    final frueher = v.entries.where((e) => e.key.compareTo(vonText) < 0).toList();
    if (frueher.isEmpty) return null;
    final minFrueher = frueher.map((e) => e.value).reduce((x, y) => x < y ? x : y);
    if (literPreis > minFrueher + 0.001) return null;
    final aeltestes = DateTime.parse(frueher.map((e) => e.key).reduce((x, y) => x.compareTo(y) < 0 ? x : y));
    final wochen = a.von.difference(aeltestes).inDays ~/ 7;
    return wochen >= 2 ? wochen : null;
  }

  DateTime? angeboteStand;
  bool angeboteLaden = false;
  String? angeboteFehler;

  Future<void> laden() async {
    try {
      await _ladenIntern();
    } catch (e) {
      debugPrint('Gespeicherte Auswahl konnte nicht geladen werden: $e');
    }
    geladen = true;
    notifyListeners();
    angeboteAktualisieren();
  }

  /// Holt die neuesten Angebote: zuerst Internet, sonst letzter Stand am Handy,
  /// sonst die mitgelieferte Datei.
  Future<void> angeboteAktualisieren() async {
    angeboteLaden = true;
    angeboteFehler = null;
    notifyListeners();
    String? text;
    final prefs = await SharedPreferences.getInstance();
    if (angeboteUrl.isNotEmpty) {
      try {
        final r = await http.get(Uri.parse(angeboteUrl)).timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          text = utf8.decode(r.bodyBytes);
          await prefs.setString(_angeboteSchluessel, text);
        } else {
          angeboteFehler = 'Server antwortet nicht (${r.statusCode}).';
        }
      } catch (_) {
        angeboteFehler = 'Keine Internetverbindung – zeige letzten Stand.';
      }
    }
    if (angeboteUrl.isNotEmpty) {
      try {
        final r = await http
            .get(Uri.parse(angeboteUrl.replaceFirst('angebote.json', 'preisverlauf.json')))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
          preisverlauf = j.map(
            (k, v) =>
                MapEntry(k, (v as Map<String, dynamic>).map((d, p) => MapEntry(d, (p as num).toDouble()))),
          );
        }
      } catch (_) {}
    }
    await _filialenLaden(prefs);
    text ??= prefs.getString(_angeboteSchluessel);
    text ??= await rootBundle.loadString('assets/angebote.json');
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      angeboteStand = DateTime.tryParse(j['stand'] as String? ?? '')?.toLocal();
      final heute = DateTime.now();
      final tag = DateTime(heute.year, heute.month, heute.day);
      angebote = [
        for (final a in (j['angebote'] as List))
          if (Angebot.ausJson(a as Map<String, dynamic>) case final angebot?)
            if (!angebot.bis.isBefore(tag)) angebot,
      ];
    } catch (e) {
      angeboteFehler = 'Angebote konnten nicht gelesen werden.';
    }
    angeboteLaden = false;
    notifyListeners();
  }

  static const _filialenSchluessel = 'bier_app_filialen_v1';

  Future<void> _filialenLaden(SharedPreferences prefs) async {
    String? text;
    if (angeboteUrl.isNotEmpty) {
      try {
        final r = await http
            .get(Uri.parse(angeboteUrl.replaceFirst('angebote.json', 'filialen.json')))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          text = utf8.decode(r.bodyBytes);
          await prefs.setString(_filialenSchluessel, text);
        }
      } catch (_) {}
    }
    text ??= prefs.getString(_filialenSchluessel);
    try {
      text ??= await rootBundle.loadString('assets/filialen.json');
      filialen = [for (final f in jsonDecode(text) as List) Filiale.ausJson(f as Map<String, dynamic>)];
    } catch (e) {
      debugPrint('Filialen nicht geladen: $e');
    }
  }

  /// Nur die gespeicherte Auswahl laden (für Push-Meldungen im Hintergrund).
  Future<void> auswahlLaden() => _ladenIntern();

  Future<void> _ladenIntern() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_schluessel);
    if (text != null) {
      final j = jsonDecode(text) as Map<String, dynamic>;
      einrichtungFertig = j['fertig'] == true;
      kartenAngeboteZeigen = j['kartenZeigen'] != false;
      gebiet = Gebiet.values.where((g) => g.name == j['gebiet']).firstOrNull ?? Gebiet.amstetten;
      standortBreite = (j['breite'] as num?)?.toDouble();
      standortLaenge = (j['laenge'] as num?)?.toDouble();
      radiusKm = (j['radius'] as num?)?.toDouble() ?? 25;
      // Frühere feste Namen übernehmen (damals: Zuhause 1, Zuhause 2, Arbeit)
      const alteNamen = {'zuhause1': 'Zuhause 1', 'zuhause2': 'Zuhause 2', 'arbeit': 'Arbeit'};
      (j['orte'] as Map<String, dynamic>? ?? {}).forEach(
        (k, v) => orte[k] = Ort.fromJson(v as Map<String, dynamic>, ersatzName: alteNamen[k] ?? 'Mein Ort'),
      );
      ortTippGesehen = j['ortTipp'] == true || orte.isNotEmpty;
      ortWahl = j['ortWahl'] as String? ?? 'standort';
      if (ortWahl != 'standort' && !orte.containsKey(ortWahl)) ortWahl = 'standort';
      final versteckt = j['hinweisVersteckt'] as String?;
      kartenHinweisVersteckt = versteckt == null ? null : DateTime.tryParse(versteckt);
      gemerkt.addAll(((j['gemerkt'] as List?) ?? []).cast<String>());
      final g = j['gekauft'];
      if (g is Map && g.values.every((v) => v is Map)) {
        g.forEach((k, v) => gekauft[k as String] = Kauf.fromJson(v as Map<String, dynamic>));
        gespartAlt = (j['gespartAlt'] as num?)?.toDouble() ?? 0;
      } else {
        gespartAlt = (j['gespart'] as num?)?.toDouble() ?? 0; // ältere Version
      }
      abgehakt.addAll(((j['abgehakt'] as List?) ?? []).cast<String>());
      for (final k in (j['karten'] as List? ?? [])) {
        final karte = Kundenkarte.values.where((x) => x.name == k).firstOrNull;
        if (karte != null) karten.add(karte);
      }
      final a = j['auswahl'] as Map<String, dynamic>? ?? {};
      a.forEach((bierId, packs) {
        if (!biere.any((b) => b.id == bierId)) return;
        final m = <Verpackung, Wunsch>{};
        (packs as Map<String, dynamic>).forEach((v, w) {
          final pack = Verpackung.values.where((x) => x.name == v).firstOrNull;
          if (pack != null) m[pack] = Wunsch.fromJson(w as Map<String, dynamic>);
        });
        auswahl[bierId] = m;
      });
    }
  }

  Future<void> speichern() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _schluessel,
      jsonEncode({
        'fertig': einrichtungFertig,
        'kartenZeigen': kartenAngeboteZeigen,
        'gebiet': gebiet.name,
        'orte': orte.map((k, v) => MapEntry(k, v.toJson())),
        'ortWahl': ortWahl,
        'ortTipp': ortTippGesehen,
        'breite': standortBreite,
        'laenge': standortLaenge,
        'radius': radiusKm,
        'hinweisVersteckt': kartenHinweisVersteckt?.toIso8601String(),
        'gemerkt': gemerkt.toList(),
        'gekauft': gekauft.map((k, v) => MapEntry(k, v.toJson())),
        'gespartAlt': gespartAlt,
        'abgehakt': abgehakt.toList(),
        'karten': karten.map((k) => k.name).toList(),
        'auswahl': auswahl.map(
          (bierId, packs) => MapEntry(bierId, packs.map((v, w) => MapEntry(v.name, w.toJson()))),
        ),
      }),
    );
  }

  void aenderung() {
    notifyListeners();
    speichern();
  }

  // ---- Biere ----
  bool istGewaehlt(String bierId) => auswahl.containsKey(bierId);

  void bierUmschalten(Bier bier) {
    if (auswahl.containsKey(bier.id)) {
      auswahl.remove(bier.id);
      aenderung();
    } else {
      bierHinzufuegen(bier);
    }
  }

  /// Fügt ein Bier mit sinnvoller Vorauswahl hinzu:
  /// österreichische/deutsche Biere → Kiste, Importe → Karton + Einzelflasche.
  void bierHinzufuegen(Bier bier) {
    if (auswahl.containsKey(bier.id)) return;
    final packs = <Verpackung, Wunsch>{};
    final vorschlag = bier.spezialitaet
        ? [Verpackung.karton24x033, Verpackung.flasche033, Verpackung.flasche05]
        : [Verpackung.kiste20x05];
    for (final v in vorschlag.where(bier.verpackungen.contains)) {
      packs[v] = Wunsch(
        maxPreis: bier.spezialitaet ? null : bier.vorschlagPreis(v),
        immerMelden: bier.spezialitaet,
      );
    }
    if (packs.isEmpty && bier.verpackungen.isNotEmpty) {
      final v = bier.verpackungen.first;
      packs[v] = Wunsch(
        maxPreis: bier.spezialitaet ? null : bier.vorschlagPreis(v),
        immerMelden: bier.spezialitaet,
      );
    }
    auswahl[bier.id] = packs;
    aenderung();
  }

  void bierEntfernen(String bierId) {
    auswahl.remove(bierId);
    aenderung();
  }

  // ---- Verpackungen ----
  bool verpackungGewaehlt(String bierId, Verpackung v) => auswahl[bierId]?.containsKey(v) ?? false;

  void verpackungUmschalten(Bier bier, Verpackung v) {
    final packs = auswahl.putIfAbsent(bier.id, () => {});
    if (packs.containsKey(v)) {
      packs.remove(v);
    } else {
      packs[v] = Wunsch(
        maxPreis: bier.spezialitaet ? null : bier.vorschlagPreis(v),
        immerMelden: bier.spezialitaet,
      );
    }
    aenderung();
  }

  // ---- Kundenkarten ----
  void karteUmschalten(Kundenkarte k) {
    karten.contains(k) ? karten.remove(k) : karten.add(k);
    aenderung();
  }

  bool get kartenHinweisAktiv =>
      kartenHinweisVersteckt == null || DateTime.now().difference(kartenHinweisVersteckt!).inDays >= 7;

  void kartenHinweisSpaeter() {
    kartenHinweisVersteckt = DateTime.now();
    aenderung();
  }

  void einrichtungAbschliessen() {
    einrichtungFertig = true;
    aenderung();
  }

  Future<void> allesZuruecksetzen() async {
    auswahl.clear();
    karten.clear();
    kartenAngeboteZeigen = true;
    kartenHinweisVersteckt = null;
    gemerkt.clear();
    einrichtungFertig = false;
    aenderung();
  }

  // ---- Angebote bewerten ----
  List<Treffer> treffer(List<Angebot> angebote) {
    final liste = <Treffer>[];
    for (final a in angebote) {
      final wunsch = auswahl[a.bierId]?[a.verpackung];
      if (wunsch == null) continue;
      final aktiv = aktiveGebiete;
      if (a.regionen != null && !aktiv.any((g) => a.regionen!.contains(g.bundesland))) continue;
      if (filialen.isNotEmpty) {
        // Nur Ketten mit einer echten Filiale im Umkreis (sonst z. B. Maximarkt Haid in Steyr)
        final n = naechsteFiliale(a.haendler);
        if (n == null || n.$2 > radiusKm) continue;
      } else if (a.gebiete != null && !aktiv.any((g) => a.gebiete!.contains(g.name))) {
        continue;
      }
      final gewerbe = gewerbeHaendler[a.haendler];
      if (gewerbe != null && !karten.contains(gewerbe)) continue; // nur mit Gewerbekarte

      final hatKarte = a.karte != null && karten.contains(a.karte);
      final preis = (hatKarte && a.kartenPreis != null) ? a.kartenPreis! : a.preis;

      Bewertung b;
      if (wunsch.immerMelden) {
        b = Bewertung.spezialitaet;
      } else if (wunsch.maxPreis != null && preis <= wunsch.maxPreis! + 0.001) {
        b = Bewertung.guterDeal;
      } else if (!hatKarte &&
          a.kartenPreis != null &&
          wunsch.maxPreis != null &&
          a.kartenPreis! <= wunsch.maxPreis! + 0.001) {
        b = Bewertung.nurMitKarte;
      } else {
        b = Bewertung.zuTeuer;
      }
      if (b == Bewertung.nurMitKarte && !kartenAngeboteZeigen) b = Bewertung.zuTeuer;
      liste.add(Treffer(a, b, preis, wunsch));
    }
    liste.sort((x, y) {
      final r = x.bewertung.index.compareTo(y.bewertung.index);
      return r != 0 ? r : x.literPreis.compareTo(y.literPreis);
    });
    return liste;
  }
}

class Kauf {
  Kauf({
    required this.bierId,
    required this.verpackung,
    required this.haendler,
    required this.preis,
    required this.ersparnisJe,
    required this.anzahl,
    required this.datum,
  });

  final String bierId;
  final String verpackung;
  final String haendler;
  final double preis;
  final double ersparnisJe;
  final int anzahl;
  final DateTime datum;

  Map<String, dynamic> toJson() => {
    'b': bierId,
    'v': verpackung,
    'h': haendler,
    'p': preis,
    'e': ersparnisJe,
    'n': anzahl,
    'd': datum.toIso8601String(),
  };

  factory Kauf.fromJson(Map<String, dynamic> j) => Kauf(
    bierId: j['b'] as String,
    verpackung: j['v'] as String,
    haendler: j['h'] as String,
    preis: (j['p'] as num).toDouble(),
    ersparnisJe: (j['e'] as num).toDouble(),
    anzahl: (j['n'] as num).toInt(),
    datum: DateTime.parse(j['d'] as String),
  );
}

/// Level nach Gesamt-Ersparnis.
class Rang {
  const Rang(this.emoji, this.name, this.ab);
  final String emoji;
  final String name;
  final double ab;
}

const raenge = [
  Rang('🍺', 'Einsteiger', 0),
  Rang('🍻', 'Stammgast', 50),
  Rang('🎯', 'Schnäppchenjäger', 150),
  Rang('🏆', 'Bier-Profi', 400),
  Rang('👑', 'BierRadar-Legende', 1000),
];

Rang rangFuer(double gespart) => raenge.lastWhere((r) => gespart >= r.ab);

Rang? naechsterRang(double gespart) => raenge.where((r) => r.ab > gespart).firstOrNull;

/// So viele eigene Orte kann man speichern.
const maxOrte = 3;

/// Ein gespeicherter Ort mit eigenem Namen (z. B. „Zuhause“, „Arbeit“, „Oma“).
class Ort {
  const Ort(this.name, this.adresse, this.breite, this.laenge);
  final String name;
  final String adresse;
  final double breite;
  final double laenge;

  Map<String, dynamic> toJson() => {'n': name, 'a': adresse, 'b': breite, 'l': laenge};
  factory Ort.fromJson(Map<String, dynamic> j, {String ersatzName = 'Mein Ort'}) => Ort(
    (j['n'] as String?) ?? ersatzName,
    j['a'] as String,
    (j['b'] as num).toDouble(),
    (j['l'] as num).toDouble(),
  );
}
