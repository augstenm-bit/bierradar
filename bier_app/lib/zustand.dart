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
  DateTime? kartenHinweisVersteckt;

  /// Gemerkte Angebote (Schlüssel siehe [angebotSchluessel]) → für die „endet morgen“-Erinnerung.
  final Set<String> gemerkt = {};

  /// Als gekauft markierte Angebote und die gesamte Ersparnis seit Installation.
  final Set<String> gekauft = {};
  double gespartGesamt = 0;

  static String angebotSchluessel(Angebot a) =>
      '${a.bierId}|${a.verpackung.name}|${a.haendler}|${a.preis}|${a.von.toIso8601String().substring(0, 10)}';

  void merkenUmschalten(Angebot a) {
    final k = angebotSchluessel(a);
    gemerkt.contains(k) ? gemerkt.remove(k) : gemerkt.add(k);
    aenderung();
  }

  /// Ersparnis eines Angebots gegenüber dem Normalpreis (0, wenn unbekannt).
  static double ersparnis(Angebot a, double preisFuerMich) =>
      a.statt != null && a.statt! > preisFuerMich ? a.statt! - preisFuerMich : 0;

  void gekauftUmschalten(Angebot a, double preisFuerMich) {
    final k = angebotSchluessel(a);
    final e = ersparnis(a, preisFuerMich);
    if (gekauft.remove(k)) {
      gespartGesamt = (gespartGesamt - e).clamp(0, double.infinity);
    } else {
      gekauft.add(k);
      gespartGesamt += e;
    }
    aenderung();
  }

  static const _schluessel = 'bier_app_zustand_v1';
  static const _angeboteSchluessel = 'bier_app_angebote_v1';

  // ---- Angebote (vom Abruf-Server) ----
  List<Angebot> angebote = [];
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

  /// Nur die gespeicherte Auswahl laden (für Push-Meldungen im Hintergrund).
  Future<void> auswahlLaden() => _ladenIntern();

  Future<void> _ladenIntern() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_schluessel);
    if (text != null) {
      final j = jsonDecode(text) as Map<String, dynamic>;
      einrichtungFertig = j['fertig'] == true;
      kartenAngeboteZeigen = j['kartenZeigen'] != false;
      final versteckt = j['hinweisVersteckt'] as String?;
      kartenHinweisVersteckt = versteckt == null ? null : DateTime.tryParse(versteckt);
      gemerkt.addAll(((j['gemerkt'] as List?) ?? []).cast<String>());
      gekauft.addAll(((j['gekauft'] as List?) ?? []).cast<String>());
      gespartGesamt = (j['gespart'] as num?)?.toDouble() ?? 0;
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
        'hinweisVersteckt': kartenHinweisVersteckt?.toIso8601String(),
        'gemerkt': gemerkt.toList(),
        'gekauft': gekauft.toList(),
        'gespart': gespartGesamt,
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
      packs[v] = Wunsch(maxPreis: bier.spezialitaet ? null : bier.vorschlagPreis(v), immerMelden: bier.spezialitaet);
    }
    if (packs.isEmpty && bier.verpackungen.isNotEmpty) {
      final v = bier.verpackungen.first;
      packs[v] = Wunsch(maxPreis: bier.spezialitaet ? null : bier.vorschlagPreis(v), immerMelden: bier.spezialitaet);
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
