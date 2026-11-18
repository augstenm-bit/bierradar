import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../daten.dart';
import '../main.dart';
import '../radar.dart';
import '../zustand.dart';
import 'bausteine.dart';

class Hauptseite extends StatefulWidget {
  const Hauptseite({super.key});

  @override
  State<Hauptseite> createState() => _HauptseiteState();
}

class _HauptseiteState extends State<Hauptseite> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final seiten = [const _AngeboteSeite(), const _MeineBiereSeite(), const _EinstellungenSeite()];
    return Scaffold(
      body: seiten[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Angebote',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_bar_outlined),
            selectedIcon: Icon(Icons.sports_bar),
            label: 'Meine Biere',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Angebote

class _AngeboteSeite extends StatelessWidget {
  const _AngeboteSeite();

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final alle = z.treffer(z.angebote);
    final s = z.angeboteStand;
    String zwei(int n) => n.toString().padLeft(2, '0');
    final standText = z.angeboteLaden
        ? 'Suche nach neuen Angeboten …'
        : s == null
        ? 'Noch keine Angebote geladen'
        : 'Stand ${s.day}.${s.month}. ${zwei(s.hour)}:${zwei(s.minute)} · ${z.angebote.length} Bier-Angebote';
    final fuerDich = alle.where((t) => t.bewertung != Bewertung.zuTeuer).toList();
    final zuTeuer = alle.where((t) => t.bewertung == Bewertung.zuTeuer).toList();

    // Kundenkarten-Tipp: Welche fehlende Karte würde bei meinen Bieren etwas bringen?
    final tippKarten = <Kundenkarte, double>{};
    for (final t in alle) {
      final a = t.angebot;
      if (a.karte != null && a.kartenPreis != null && !z.karten.contains(a.karte)) {
        tippKarten[a.karte!] = (tippKarten[a.karte!] ?? 0) + (a.preis - a.kartenPreis!);
      }
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Row(children: [RadarLogo(groesse: 40), SizedBox(width: 10), Text('Bierradar')]),
      ),
      body: RefreshIndicator(
        color: radarGruen,
        onRefresh: z.angeboteAktualisieren,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: radarGruen),
                title: const Text('Bezirk Amstetten', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(standText),
                trailing: Text(
                  '${fuerDich.length} Treffer',
                  style: const TextStyle(color: radarGruen, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (z.angeboteFehler != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(z.angeboteFehler!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (z.kartenHinweisAktiv)
              for (final e in tippKarten.entries) _KartenTipp(karte: e.key, ersparnis: e.value),
            if (fuerDich.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  z.auswahl.isEmpty
                      ? 'Du hast noch keine Biere ausgewählt.\n'
                            'Tippe unten auf „Meine Biere“ und wähle deine Lieblingsbiere.'
                      : 'Diese Woche gibt es keine passenden Angebote für deine Biere.\n'
                            'Sobald etwas kommt, bekommst du eine Nachricht.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final t in fuerDich) _AngebotKarte(treffer: t),
            if (zuTeuer.isNotEmpty)
              ExpansionTile(
                title: Text('Über deinem Wunschpreis (${zuTeuer.length})'),
                subtitle: const Text('Dafür bekommst du keine Nachricht'),
                children: [for (final t in zuTeuer) _AngebotKarte(treffer: t)],
              ),
          ],
        ),
      ),
    );
  }
}

class _KartenTipp extends StatelessWidget {
  const _KartenTipp({required this.karte, required this.ersparnis});
  final Kundenkarte karte;
  final double ersparnis;

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final farben = Theme.of(context).colorScheme;
    return Card(
      color: farben.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tipp: ${karte.titel} lohnt sich für dich',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Mit ${karte.titel} sparst du diese Woche bei deinen Bieren '
              '${euro(ersparnis)}. Die Karte ist gratis.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => launchUrl(Uri.parse(karte.link), mode: LaunchMode.externalApplication),
                  child: const Text('Karte jetzt holen'),
                ),
                TextButton(onPressed: () => z.karteUmschalten(karte), child: const Text('Hab ich schon')),
                TextButton(onPressed: z.kartenHinweisSpaeter, child: const Text('Später')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AngebotKarte extends StatelessWidget {
  const _AngebotKarte({required this.treffer});
  final Treffer treffer;

  @override
  Widget build(BuildContext context) {
    final a = treffer.angebot;
    final farben = Theme.of(context).colorScheme;
    final (String text, Color farbe, IconData icon) = switch (treffer.bewertung) {
      Bewertung.spezialitaet => ('Spezialität – endlich verfügbar!', const Color(0xFFD59BFF), Icons.public),
      Bewertung.guterDeal => ('Guter Deal', radarGruen, Icons.radar),
      Bewertung.nurMitKarte => ('Guter Deal nur mit ${a.karte!.titel}', bierBernstein, Icons.credit_card),
      Bewertung.zuTeuer => ('Über deinem Wunschpreis', farben.outline, Icons.remove_circle_outline),
    };
    final aktiv = treffer.bewertung != Bewertung.zuTeuer;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: aktiv ? farbe : Colors.transparent, width: 4)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: farbe.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: farbe, size: 15),
                      const SizedBox(width: 5),
                      Text(
                        text,
                        style: TextStyle(color: farbe, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (a.beispiel)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: farben.error),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('BEISPIEL', style: TextStyle(color: farben.error, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.bier.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('${a.verpackung.bezeichnung} · ${a.haendler}'),
                      Text('gültig ${zeitraum(a.von, a.bis)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      euro(treffer.preisFuerMich),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: aktiv ? bierBernstein : farben.outline,
                      ),
                    ),
                    Text('${euro(treffer.literPreis)}/l', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            if (a.kartenPreis != null) ...[
              const SizedBox(height: 6),
              _KartenZeile(angebot: a, preisFuerMich: treffer.preisFuerMich),
            ],
            if (a.hinweis != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(a.hinweis!, style: Theme.of(context).textTheme.bodySmall),
              ),
            if (!treffer.wunsch.immerMelden && treffer.wunsch.maxPreis != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Dein Wunschpreis: höchstens ${euro(treffer.wunsch.maxPreis!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KartenZeile extends StatelessWidget {
  const _KartenZeile({required this.angebot, required this.preisFuerMich});
  final Angebot angebot;
  final double preisFuerMich;

  @override
  Widget build(BuildContext context) {
    final a = angebot;
    final mitKarte = preisFuerMich == a.kartenPreis;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bierBernstein.withValues(alpha: 0.12),
        border: Border.all(color: bierBernstein.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card, size: 16, color: bierBernstein),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              mitKarte
                  ? 'Preis nur mit ${a.karte!.titel} – ohne Karte ${euro(a.preis)}'
                  : 'Mit ${a.karte!.titel} nur ${euro(a.kartenPreis!)}',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Meine Biere

class _MeineBiereSeite extends StatelessWidget {
  const _MeineBiereSeite();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Biere'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Biere wählen'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Biere wählen')),
                  body: const BierAuswahl(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: const VerpackungUndPreis(),
    );
  }
}

// ---------------------------------------------------------------- Einstellungen

class _EinstellungenSeite extends StatelessWidget {
  const _EinstellungenSeite();

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.location_on),
            title: Text('Gebiet'),
            subtitle: Text('Bezirk Amstetten\nBald: Steyr, später ganz Österreich'),
            isThreeLine: true,
          ),
          const ListTile(
            leading: Icon(Icons.notifications_active),
            title: Text('Benachrichtigungen'),
            subtitle: Text(
              'Kommen spätestens 1 Stunde nach einem neuen Flugblatt. '
              'Funktioniert, sobald der Server läuft (nächster Schritt).',
            ),
            isThreeLine: true,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('Kundenkarten'),
            subtitle: Text(z.karten.isEmpty ? 'Keine' : z.karten.map((k) => k.titel).join(', ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Kundenkarten')),
                  body: const KartenAuswahl(),
                ),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Alles zurücksetzen'),
            subtitle: const Text('Einrichtung von vorne beginnen'),
            onTap: () async {
              final ja = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Wirklich zurücksetzen?'),
                  content: const Text('Deine Biere, Preise und Karten werden gelöscht.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Zurücksetzen')),
                  ],
                ),
              );
              if (ja == true) z.allesZuruecksetzen();
            },
          ),
        ],
      ),
    );
  }
}
