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
}
