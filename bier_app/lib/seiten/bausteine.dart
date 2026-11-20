// Bausteine, die in der Einrichtung und unter „Meine Biere“ verwendet werden.

import 'package:flutter/material.dart';

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

    Widget kachel(Bier b) {
      final gewaehlt = z.istGewaehlt(b.id);
      return ListTile(
        onTap: () => zeigeBierEinstellung(context, b),
        title: Text(b.name),
        subtitle: Text(
          gewaehlt ? auswahlText(b, z.auswahl[b.id] ?? {}) : b.herkunft,
          style: TextStyle(color: gewaehlt ? radarMintHell : null),
        ),
        leading: Icon(
          b.spezialitaet ? Icons.public : Icons.sports_bar,
          color: b.spezialitaet ? const Color(0xFFD59BFF) : bierBernstein,
        ),
        trailing: gewaehlt
            ? const Icon(Icons.check_circle, color: radarGruen)
            : const Icon(Icons.add_circle_outline, color: textGedaempft),
      );
    }

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
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Verstanden')),
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

/// Kurze Beschreibung der Auswahl, z. B. „Kiste bis 16,00 €“.
String auswahlText(Bier bier, Map<Verpackung, Wunsch> packs) {
  if (packs.isEmpty) return 'Noch keine Verpackung gewählt';
  return packs.entries
      .map(
        (e) => e.value.immerMelden
            ? '${e.key.titel} · immer'
            : '${e.key.titel} bis ${euro(e.value.maxPreis ?? 0)}',
      )
      .join('  ·  ');
}

/// Öffnet das Einstellungsfenster für ein Bier (fügt es vorher mit Vorauswahl hinzu).
Future<void> zeigeBierEinstellung(BuildContext context, Bier bier) {
  final z = ZustandScope.of(context);
  z.bierHinzufuegen(bier);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111827),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => ZustandScope(
      zustand: z,
      child: _BierEinstellung(bier: bier),
    ),
  );
}

class _BierEinstellung extends StatelessWidget {
  const _BierEinstellung({required this.bier});
  final Bier bier;

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final packs = z.auswahl[bier.id] ?? {};
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  bier.spezialitaet ? Icons.public : Icons.sports_bar,
                  color: bier.spezialitaet ? spezialLila : bierBernstein,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bier.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textHell),
                  ),
                ),
                if (bier.spezialitaet)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: spezialLila.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Spezialität',
                      style: TextStyle(color: Color(0xFFC9B8FF), fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Was kaufst du?', style: TextStyle(color: textGedaempft)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final v in bier.verpackungen)
                  FilterChip(
                    label: Text(v.bezeichnung),
                    selected: packs.containsKey(v),
                    onSelected: (_) => z.verpackungUmschalten(bier, v),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in packs.entries) _PreisZeile(bier: bier, verpackung: e.key, wunsch: e.value),
            if (packs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Wähle mindestens eine Verpackung.', style: TextStyle(color: Color(0xFFFF7A8A))),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    z.bierEntfernen(bier.id);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline, color: textGedaempft),
                  label: const Text('Entfernen', style: TextStyle(color: textGedaempft)),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    if (packs.isEmpty) z.bierEntfernen(bier.id);
                    Navigator.pop(context);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Text('Fertig', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreisZeile extends StatelessWidget {
  const _PreisZeile({required this.bier, required this.verpackung, required this.wunsch});
  final Bier bier;
  final Verpackung verpackung;
  final Wunsch wunsch;

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final v = verpackung;
    // Kisten/Kartons in 50-Cent-Schritten, Einzelflaschen in 5-Cent-Schritten
    final schritt = v.liter >= 2 ? 0.5 : 0.05;
    final preis = wunsch.maxPreis ?? bier.vorschlagPreis(v);
    void setze(double p) {
      wunsch.maxPreis = double.parse(p.clamp(schritt, 999).toStringAsFixed(2));
      z.aenderung();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 10),
      decoration: BoxDecoration(color: karteFarbe, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  v.bezeichnung,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: textHell),
                ),
              ),
              const Text('Immer melden', style: TextStyle(fontSize: 13, color: textGedaempft)),
              Switch(
                value: wunsch.immerMelden,
                onChanged: (an) {
                  wunsch.immerMelden = an;
                  wunsch.maxPreis ??= bier.vorschlagPreis(v);
                  z.aenderung();
                },
              ),
            ],
          ),
          if (!wunsch.immerMelden)
            Row(
              children: [
                const Text('Melden ab', style: TextStyle(color: textGedaempft)),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => setze(preis - schritt),
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    euro(preis),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: bierGoldHell),
                  ),
                ),
                IconButton.filledTonal(onPressed: () => setze(preis + schritt), icon: const Icon(Icons.add)),
              ],
            ),
          if (!wunsch.immerMelden)
            Text(
              '= ${euro(preis / v.liter)} pro Liter',
              style: const TextStyle(fontSize: 12, color: textGedaempft),
            ),
        ],
      ),
    );
  }
}

/// Übersicht „Deine Biere“: kurze Kärtchen, antippen = ändern, wischen = entfernen.
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
          child: Text(
            'Du hast noch kein Bier ausgewählt.\nTippe oben auf „Biere wählen“.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textGedaempft, height: 1.5),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Antippen zum Ändern · nach links wischen zum Entfernen',
            style: TextStyle(color: textGedaempft, fontSize: 12.5),
          ),
        ),
        for (final b in gewaehlt)
          Dismissible(
            key: ValueKey('bier_${b.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF5A1F28),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) => z.bierEntfernen(b.id),
            child: GestureDetector(
              onTap: () => zeigeBierEinstellung(context, b),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: karteFarbe,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(
                      b.spezialitaet ? Icons.public : Icons.sports_bar,
                      color: b.spezialitaet ? spezialLila : bierBernstein,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: textHell),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auswahlText(b, z.auswahl[b.id] ?? {}),
                            style: const TextStyle(fontSize: 12.5, color: textGedaempft),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.tune, color: textGedaempft, size: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
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
