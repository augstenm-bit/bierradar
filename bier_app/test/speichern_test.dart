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
}
