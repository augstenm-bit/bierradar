// Bausteine, die in der Einrichtung und unter „Meine Biere“ verwendet werden.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../daten.dart';
import '../main.dart';
import '../radar.dart';
import '../zustand.dart';

/// Schritt 1: Biermarken auswählen.
class BierAuswahl extends StatefulWidget {
  const BierAuswahl({super.key});

  @override
  State<BierAuswahl> createState() => _BierAuswahlState();
}

class _BierAuswahlState extends State<BierAuswahl> {
  String _suche = '';

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    bool passt(Bier b) =>
        _suche.isEmpty || b.name.toLowerCase().contains(_suche) || b.herkunft.toLowerCase().contains(_suche);
    final oesterreich = biere.where((b) => !b.spezialitaet && passt(b)).toList();
    final importe = biere.where((b) => b.spezialitaet && passt(b)).toList();

    Widget kachel(Bier b) => CheckboxListTile(
      value: z.istGewaehlt(b.id),
      onChanged: (_) => z.bierUmschalten(b),
      title: Text(b.name),
      subtitle: Text(b.herkunft),
      secondary: Icon(
        b.spezialitaet ? Icons.public : Icons.sports_bar,
        color: b.spezialitaet ? const Color(0xFFD59BFF) : bierBernstein,
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Bier suchen …',
              border: OutlineInputBorder(),
            ),
            onChanged: (t) => setState(() => _suche = t.trim().toLowerCase()),
          ),
        ),
        if (oesterreich.isNotEmpty) const _Ueberschrift('Österreichische Biere'),
        ...oesterreich.map(kachel),
        if (importe.isNotEmpty) const _Ueberschrift('Importe & Spezialitäten'),
        ...importe.map(kachel),
        if (_suche.isEmpty) ...[
          const _Ueberschrift('Radler & Alkoholfrei'),
          for (final (name, info) in [
            ('Radler', 'Gösser Naturradler, Stiegl Radler …'),
            ('Alkoholfreies Bier', 'Schlossgold, Gösser Naturgold, Stiegl Freibier …'),
          ])
            ListTile(
              leading: const Icon(Icons.no_drinks_outlined, color: Color(0xFF6C7790)),
              title: Text(name, style: const TextStyle(color: Color(0xFF8C97AD))),
              subtitle: Text(info),
              trailing: const Icon(Icons.info_outline, color: Color(0xFF6C7790)),
              onTap: () => showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  icon: const Icon(Icons.sports_bar),
                  title: const Text('Nur echtes Bier an Bord'),
                  content: const Text('Solche Getränke werden von BierRadar nicht unterstützt.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Arrr, verstanden')),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Ueberschrift extends StatelessWidget {
  const _Ueberschrift(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
    ),
  );
}

/// Schritt 2: Pro Bier die Verpackung wählen und den Wunschpreis einstellen.
class VerpackungUndPreis extends StatelessWidget {
  const VerpackungUndPreis({super.key});

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final gewaehlt = biere.where((b) => z.istGewaehlt(b.id)).toList();
    if (gewaehlt.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Du hast noch kein Bier ausgewählt.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [for (final b in gewaehlt) _BierKarte(bier: b)],
    );
  }
}

class _BierKarte extends StatelessWidget {
  const _BierKarte({required this.bier});
  final Bier bier;

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final packs = z.auswahl[bier.id] ?? {};
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  bier.spezialitaet ? Icons.public : Icons.sports_bar,
                  color: bier.spezialitaet ? const Color(0xFFD59BFF) : bierBernstein,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(bier.name, style: Theme.of(context).textTheme.titleMedium)),
                if (bier.spezialitaet) const Chip(label: Text('Spezialität')),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Welche Verpackung willst du kaufen?'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final v in bier.verpackungen)
                  FilterChip(
                    label: Text(v.bezeichnung),
                    selected: packs.containsKey(v),
                    onSelected: (_) => z.verpackungUmschalten(bier, v),
                  ),
              ],
            ),
            if (packs.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bitte mindestens eine Verpackung wählen.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            for (final e in packs.entries)
              _WunschZeile(
                key: ValueKey('${bier.id}_${e.key.name}'),
                bier: bier,
                verpackung: e.key,
                wunsch: e.value,
              ),
          ],
        ),
      ),
    );
  }
}

class _WunschZeile extends StatefulWidget {
  const _WunschZeile({super.key, required this.bier, required this.verpackung, required this.wunsch});
  final Bier bier;
  final Verpackung verpackung;
  final Wunsch wunsch;

  @override
  State<_WunschZeile> createState() => _WunschZeileState();
}

class _WunschZeileState extends State<_WunschZeile> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    final p = widget.wunsch.maxPreis ?? widget.bier.vorschlagPreis(widget.verpackung);
    _c = TextEditingController(text: p.toStringAsFixed(2).replaceAll('.', ','));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final w = widget.wunsch;
    final v = widget.verpackung;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v.bezeichnung, style: const TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Immer melden, Preis egal'),
            value: w.immerMelden,
            onChanged: (an) {
              w.immerMelden = an;
              w.maxPreis ??= widget.bier.vorschlagPreis(v);
              z.aenderung();
            },
          ),
          if (!w.immerMelden)
            Row(
              children: [
                const Expanded(child: Text('Melden, wenn es höchstens kostet:')),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _c,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(suffixText: '€', isDense: true),
                    onChanged: (t) {
                      final p = double.tryParse(t.replaceAll(',', '.'));
                      if (p != null && p > 0) {
                        w.maxPreis = p;
                        z.aenderung();
                      }
                    },
                  ),
                ),
              ],
            ),
          if (!w.immerMelden && w.maxPreis != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Das sind ${euro(w.maxPreis! / v.liter)} pro Liter.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Schritt 3: Kundenkarten.
class KartenAuswahl extends StatelessWidget {
  const KartenAuswahl({super.key});

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'Welche Kundenkarten hast du?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Viele Bier-Aktionen gelten nur mit Kundenkarte. '
          'Die Karten sind gratis.',
        ),
        const SizedBox(height: 8),
        for (final k in Kundenkarte.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: z.karten.contains(k),
            onChanged: (_) => z.karteUmschalten(k),
            title: Text(k.titel),
            subtitle: Text(k.haendler),
            secondary: const Icon(Icons.credit_card),
          ),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auch Angebote zeigen, die nur mit Kundenkarte gelten'),
          subtitle: const Text('Du siehst dann, wie viel du mit einer Karte sparen würdest.'),
          value: z.kartenAngeboteZeigen,
          onChanged: (an) {
            z.kartenAngeboteZeigen = an;
            z.aenderung();
          },
        ),
      ],
    );
  }
}
