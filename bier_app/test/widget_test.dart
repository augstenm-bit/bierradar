import 'package:bier_app/daten.dart';
import 'package:bier_app/zustand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Wunschpreis und Kundenkarte werden richtig bewertet', () {
    final z = AppZustand();
    z.auswahl['kaiser'] = {Verpackung.kiste20x05: Wunsch(maxPreis: 13.00)};
    z.auswahl['chang'] = {Verpackung.karton24x033: Wunsch(immerMelden: true)};
    final ohneKarte = z.treffer(testAngebote);
    expect(ohneKarte.firstWhere((t) => t.angebot.bierId == 'kaiser').bewertung, Bewertung.nurMitKarte);
    expect(ohneKarte.firstWhere((t) => t.angebot.bierId == 'chang').bewertung, Bewertung.spezialitaet);
    z.karten.add(Kundenkarte.lidlPlus);
    final mitKarte = z.treffer(testAngebote).firstWhere((t) => t.angebot.bierId == 'kaiser');
    expect(mitKarte.bewertung, Bewertung.guterDeal);
    expect(mitKarte.preisFuerMich, 12.80);
  });
}
