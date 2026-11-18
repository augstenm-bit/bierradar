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
    a.verpackungUmschalten(bierMitId('goesser'), Verpackung.kiste20x05);
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
}
