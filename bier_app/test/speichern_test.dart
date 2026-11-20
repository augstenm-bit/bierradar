import 'package:bier_app/daten.dart';
import 'package:bier_app/zustand.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Auswahl übersteht einen Neustart', () async {
    SharedPreferences.setMockInitialValues({});
    final a = AppZustand();
    await a.laden();
    a.bierUmschalten(bierMitId('goesser'));
    a.karteUmschalten(Kundenkarte.joe);
    a.einrichtungAbschliessen();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    // ignore: avoid_print
    print(prefs.getString('bier_app_zustand_v1'));
    final b = AppZustand();
    await b.laden();
    expect(b.einrichtungFertig, isTrue);
    expect(b.auswahl['goesser']?.keys, contains(Verpackung.kiste20x05));
    expect(b.karten, contains(Kundenkarte.joe));
  });

  test('Vorauswahl: Kiste bei Gösser, Karton + Einzelflasche bei Chang', () async {
    SharedPreferences.setMockInitialValues({});
    final z = AppZustand();
    z.bierHinzufuegen(bierMitId('goesser'));
    z.bierHinzufuegen(bierMitId('chang'));
    expect(z.auswahl['goesser']!.keys, [Verpackung.kiste20x05]);
    expect(z.auswahl['chang']!.keys, containsAll([Verpackung.karton24x033, Verpackung.flasche033]));
    expect(z.auswahl['chang']![Verpackung.karton24x033]!.immerMelden, isTrue);
  });

  test('Gekauft mit Anzahl: Ersparnis wird multipliziert und angepasst', () async {
    SharedPreferences.setMockInitialValues({});
    final z = AppZustand();
    final a = Angebot(
      bierId: 'kaiser',
      verpackung: Verpackung.kiste20x05,
      haendler: 'Lidl',
      preis: 14.80,
      statt: 24.40,
      von: DateTime(2026, 11, 19),
      bis: DateTime(2026, 11, 21),
    );
    z.gekauftSetzen(a, 14.80, 5);
    expect(z.gespartGesamt, closeTo(48.0, 0.001));
    z.gekauftSetzen(a, 14.80, 2);
    expect(z.gespartGesamt, closeTo(19.2, 0.001));
    z.gekauftSetzen(a, 14.80, 0);
    expect(z.gespartGesamt, closeTo(0, 0.001));
    expect(z.gekauft, isEmpty);
  });

  test('Preis-Gedächtnis und Ränge', () {
    final z = AppZustand();
    z.preisverlauf = {
      'goesser|kiste20x05': {'2026-10-01': 1.49, '2026-10-15': 1.45, '2026-11-01': 1.40},
    };
    final a = Angebot(
      bierId: 'goesser',
      verpackung: Verpackung.kiste20x05,
      haendler: 'Hofer',
      preis: 13.80,
      von: DateTime(2026, 11, 20),
      bis: DateTime(2026, 11, 21),
    );
    expect(z.tiefstpreisWochen(a, 1.38), 7);
    expect(z.tiefstpreisWochen(a, 1.45), isNull);
    expect(rangFuer(0).name, 'Schiffsjunge');
    expect(rangFuer(55).name, 'Bootsmann');
    expect(naechsterRang(55)!.name, 'Kapitän');
  });

  test('Standort und Umkreis', () {
    final z = AppZustand();
    z.standortSetzen(48.1229, 14.8720); // Amstetten
    expect(z.gebiet, Gebiet.amstetten);
    z.radiusKm = 20;
    expect(z.aktiveGebiete, {Gebiet.amstetten});
    z.radiusKm = 40; // Steyr ist ca. 35 km entfernt
    expect(z.aktiveGebiete, {Gebiet.amstetten, Gebiet.steyr});
    z.standortSetzen(48.0427, 14.4213); // Steyr
    z.radiusKm = 5;
    expect(z.aktiveGebiete, {Gebiet.steyr});
  });

  test('Nur Ketten mit Filiale im Umkreis (kein Maximarkt Haid in Steyr)', () {
    final z = AppZustand();
    z.filialen = const [
      Filiale('Lidl', 'Lidl Steyr', 'Steyr', 48.045, 14.42),
      Filiale('Maximarkt', 'Maximarkt Haid', 'Haid', 48.205, 14.245),
    ];
    z.auswahl['kaiser'] = {Verpackung.kiste20x05: Wunsch(maxPreis: 20)};
    z.standortSetzen(48.0427, 14.4213); // Steyr
    z.radiusKm = 15;
    Angebot an(String h) => Angebot(
      bierId: 'kaiser',
      verpackung: Verpackung.kiste20x05,
      haendler: h,
      preis: 14.8,
      von: DateTime(2026, 11, 19),
      bis: DateTime(2099, 1, 1),
    );
    final t = z.treffer([an('Lidl'), an('Maximarkt'), an('Hofer')]);
    expect(t.map((x) => x.angebot.haendler), ['Lidl']);
    z.radiusKm = 40; // Haid liegt ca. 23 km Luftlinie entfernt
    expect(z.treffer([an('Maximarkt')]).length, 1);
  });

  test('Umkreis-Vorschlag: Hinterbergerstraße Steyr, 1 km ohne Lidl → ab 3 km', () {
    final z = AppZustand();
    z.filialen = const [
      Filiale('Hofer', 'Hofer', 'Haager Straße 58', 48.0589, 14.4560),
      Filiale('Lidl', 'Lidl', 'Steyr', 48.0466, 14.4249),
    ];
    z.auswahl['kaiser'] = {Verpackung.kiste20x05: Wunsch(maxPreis: 20)};
    z.angebote = [
      Angebot(
        bierId: 'kaiser',
        verpackung: Verpackung.kiste20x05,
        haendler: 'Lidl',
        preis: 14.8,
        von: DateTime(2026, 11, 19),
        bis: DateTime(2099, 1, 1),
      ),
    ];
    z.standortSetzen(48.05466, 14.45104); // Hinterbergerstraße 2
    z.radiusKm = 1;
    expect(z.treffer(z.angebote), isEmpty);
    expect(z.umkreisVorschlag(), (3, 1));
    expect(z.radiusKm, 1); // Vorschlag ändert den Umkreis nicht
  });

  test('Meine Orte: Zuhause wählen ändert den Mittelpunkt und bleibt gespeichert', () async {
    SharedPreferences.setMockInitialValues({});
    final z = AppZustand();
    await z.laden();
    z.standortSetzen(48.1229, 14.8720); // gerade in Amstetten
    z.ortSetzen('zuhause1', const Ort('Hinterbergerstraße, 4400 Steyr', 48.05466, 14.45104));
    z.ortWaehlen('zuhause1');
    expect(z.mitteBreite, closeTo(48.05466, 0.0001));
    expect(z.naechstesGebiet, Gebiet.steyr);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final neu = AppZustand();
    await neu.auswahlLaden();
    expect(neu.ortWahl, 'zuhause1');
    expect(neu.orte['zuhause1']!.adresse, startsWith('Hinterbergerstraße'));
    neu.ortLoeschen('zuhause1');
    expect(neu.ortWahl, 'standort');
  });

  test('Filial-Text mit Ort und Entfernung', () {
    final z = AppZustand();
    z.filialen = const [
      Filiale('Billa', 'Billa', 'Anton-Plochberger-Straße 2, 4400 Steyr', 48.0466, 14.4249),
      Filiale('Hofer', 'Hofer Amstetten', '', 48.1229, 14.8720),
    ];
    z.standortSetzen(48.05466, 14.45104); // Hinterbergerstraße
    expect(z.filialText('Billa'), matches(RegExp(r'^Billa Steyr · \d,\d km$')));
    expect(z.filialText('Hofer'), startsWith('Hofer Amstetten · '));
    expect(z.filialText('Maximarkt'), 'Maximarkt');
  });
}
