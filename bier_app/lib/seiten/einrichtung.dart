import 'package:flutter/material.dart';

import '../main.dart';
import 'bausteine.dart';

/// Ersteinrichtung in 3 Schritten: Biere → Verpackung & Preis → Kundenkarten.
class Einrichtung extends StatefulWidget {
  const Einrichtung({super.key});

  @override
  State<Einrichtung> createState() => _EinrichtungState();
}

class _EinrichtungState extends State<Einrichtung> {
  int _schritt = 0;

  static const _titel = ['1/3 · Deine Biere', '2/3 · Deine Auswahl', '3/3 · Kundenkarten'];
  static const _erklaerung = [
    'Tippe deine Biere an – Verpackung und Wunschpreis stellst du gleich dort ein.',
    'Passt alles? Tippe ein Bier an, um Verpackung oder Preis zu ändern.',
    'Damit wir dir die richtigen Preise zeigen.',
  ];

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final anzahl = z.auswahl.length;
    final ohneVerpackung = z.auswahl.values.any((p) => p.isEmpty);

    String? fehler;
    if (_schritt == 0 && anzahl == 0) fehler = 'Wähle mindestens ein Bier.';
    if (_schritt == 1 && ohneVerpackung) fehler = 'Bei jedem Bier mindestens eine Verpackung wählen.';

    return Scaffold(
      appBar: AppBar(
        title: Text(_titel[_schritt]),
        leading: _schritt > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _schritt--))
            : null,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_schritt + 1) / 3),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_erklaerung[_schritt], style: Theme.of(context).textTheme.bodyLarge),
          ),
          Expanded(
            child: switch (_schritt) {
              0 => const BierAuswahl(),
              1 => const VerpackungUndPreis(),
              _ => const KartenAuswahl(),
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fehler != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(fehler, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: fehler != null
                      ? null
                      : () {
                          if (_schritt < 2) {
                            setState(() => _schritt++);
                          } else {
                            z.einrichtungAbschliessen();
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _schritt == 0
                          ? 'Weiter ($anzahl ${anzahl == 1 ? 'Bier' : 'Biere'})'
                          : _schritt == 1
                          ? 'Weiter'
                          : 'Fertig – Angebote zeigen',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
