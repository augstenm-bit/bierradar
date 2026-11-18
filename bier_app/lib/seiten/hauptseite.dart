import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
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
          NavigationDestination(icon: Icon(Icons.radar), label: 'Radar'),
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

enum _Filter { alle, kisten, einzeln, spezial }

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

String _wann(Angebot a) {
  final heute = DateTime.now();
  final tag = DateTime(heute.year, heute.month, heute.day);
  if (a.von.isAfter(tag)) return 'ab ${_wochentage[a.von.weekday - 1]} ${a.von.day}.${a.von.month}.';
  return 'bis ${_wochentage[a.bis.weekday - 1]} ${a.bis.day}.${a.bis.month}.';
}

int? _rabatt(Angebot a, double preis) {
  final statt = a.statt;
  if (statt == null || statt <= preis) return null;
  return ((1 - preis / statt) * 100).round();
}

class _AngeboteSeite extends StatefulWidget {
  const _AngeboteSeite();

  @override
  State<_AngeboteSeite> createState() => _AngeboteSeiteState();
}

class _AngeboteSeiteState extends State<_AngeboteSeite> {
  _Filter _filter = _Filter.alle;

  bool _passt(Treffer t) => switch (_filter) {
    _Filter.alle => true,
    _Filter.kisten => t.angebot.verpackung == Verpackung.kiste20x05 || t.angebot.verpackung == Verpackung.karton24x033,
    _Filter.einzeln => t.angebot.verpackung.liter < 1,
    _Filter.spezial => t.angebot.bier.spezialitaet,
  };

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final alle = z.treffer(z.angebote);
    final fuerDichAlle = alle.where((t) => t.bewertung != Bewertung.zuTeuer).toList();
    final fuerDich = fuerDichAlle.where(_passt).toList();
    final zuTeuer = alle.where((t) => t.bewertung == Bewertung.zuTeuer).where(_passt).toList();
    final bester = fuerDichAlle.where((t) => t.bewertung != Bewertung.spezialitaet).firstOrNull ?? fuerDichAlle.firstOrNull;
    final rest = fuerDich.where((t) => t != bester || _filter != _Filter.alle).toList();

    final tippKarten = <Kundenkarte, double>{};
    for (final t in alle) {
      final a = t.angebot;
      if (a.karte != null && a.kartenPreis != null && !z.karten.contains(a.karte)) {
        tippKarten[a.karte!] = (tippKarten[a.karte!] ?? 0) + (a.preis - a.kartenPreis!);
      }
    }

    int anzahl(_Filter f) {
      final alt = _filter;
      _filter = f;
      final n = fuerDichAlle.where(_passt).length;
      _filter = alt;
      return n;
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: radarGruen,
          backgroundColor: karteFarbe,
          onRefresh: z.angeboteAktualisieren,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Kopf(z: z, treffer: fuerDichAlle.length),
              if (z.angeboteFehler != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(z.angeboteFehler!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (z.kartenHinweisAktiv)
                for (final e in tippKarten.entries) _KartenTipp(karte: e.key, ersparnis: e.value),
              if (bester != null && _filter == _Filter.alle) _Einblenden(index: 0, child: _BesterDeal(treffer: bester)),
              if (fuerDichAlle.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    children: [
                      for (final (f, text) in [
                        (_Filter.alle, 'Alle'),
                        (_Filter.kisten, 'Kisten'),
                        (_Filter.einzeln, 'Einzeln'),
                        (_Filter.spezial, 'Spezialitäten'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterKnopf(
                            text: '$text ${anzahl(f)}',
                            aktiv: _filter == f,
                            onTap: () => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              if (fuerDich.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                  child: Column(
                    children: [
                      const LiveRadar(groesse: 120),
                      const SizedBox(height: 20),
                      Text(
                        z.auswahl.isEmpty
                            ? 'Du hast noch keine Biere ausgewählt.\nTippe unten auf „Meine Biere“.'
                            : 'Gerade nichts für dich auf dem Radar.\nSobald etwas auftaucht, melden wir uns.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: textGedaempft, height: 1.5),
                      ),
                    ],
                  ),
                ),
              for (final (i, t) in rest.indexed) _Einblenden(index: i + 1, child: _AngebotZeile(treffer: t)),
              if (zuTeuer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ExpansionTile(
                    iconColor: textGedaempft,
                    collapsedIconColor: textGedaempft,
                    title: Text(
                      'Über deinem Wunschpreis (${zuTeuer.length})',
                      style: const TextStyle(color: textGedaempft, fontSize: 15),
                    ),
                    children: [for (final t in zuTeuer) _AngebotZeile(treffer: t)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kopf extends StatelessWidget {
  const _Kopf({required this.z, required this.treffer});
  final AppZustand z;
  final int treffer;

  @override
  Widget build(BuildContext context) {
    final s = z.angeboteStand;
    String text;
    if (z.angeboteLaden) {
      text = 'Radar sucht …';
    } else if (s == null) {
      text = 'Noch keine Angebote';
    } else {
      final min = DateTime.now().difference(s).inMinutes;
      final wann = min < 1
          ? 'gerade eben'
          : min < 60
          ? 'vor $min Min.'
          : min < 60 * 24
          ? 'vor ${min ~/ 60} Std.'
          : 'am ${s.day}.${s.month}.';
      text = 'Live · Bezirk Amstetten · $wann';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Row(
        children: [
          const LiveRadar(groesse: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bierradar',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textHell, letterSpacing: 0.3),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const _PulsPunkt(),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        text,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: textGedaempft),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: radarGruen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$treffer Treffer',
              style: const TextStyle(color: radarGruen, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsPunkt extends StatefulWidget {
  const _PulsPunkt();

  @override
  State<_PulsPunkt> createState() => _PulsPunktState();
}

class _PulsPunktState extends State<_PulsPunkt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.25, end: 1.0).animate(_c),
    child: Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: radarGruen,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: radarGruen.withValues(alpha: 0.7), blurRadius: 6)],
      ),
    ),
  );
}

/// Lässt Inhalte nacheinander von unten hereingleiten.
class _Einblenden extends StatelessWidget {
  const _Einblenden({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final verzoegerung = (index * 70).clamp(0, 700);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + verzoegerung),
      builder: (_, wert, kind) {
        final t = Curves.easeOutCubic.transform(
          ((wert * (420 + verzoegerung) - verzoegerung) / 420).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: kind),
        );
      },
      child: child,
    );
  }
}

class _FilterKnopf extends StatelessWidget {
  const _FilterKnopf({required this.text, required this.aktiv, required this.onTap});
  final String text;
  final bool aktiv;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: aktiv ? radarGruen : karteFarbe,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: aktiv ? radarGruen : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: aktiv ? const Color(0xFF00271A) : const Color(0xFFB8C4D9),
          fontWeight: aktiv ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
    ),
  );
}

class _BesterDeal extends StatelessWidget {
  const _BesterDeal({required this.treffer});
  final Treffer treffer;

  @override
  Widget build(BuildContext context) {
    final a = treffer.angebot;
    final rabatt = _rabatt(a, treffer.preisFuerMich);
    return GestureDetector(
      onTap: () => _zeigeDetails(context, treffer),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: radarGruen.withValues(alpha: 0.35)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F6B5A), Color(0xFF14324A), Color(0xFF3A2A12)],
            stops: [0, 0.55, 1],
          ),
          boxShadow: [BoxShadow(color: radarGruen.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Plakette(
                  icon: Icons.local_fire_department_outlined,
                  text: 'Bester Deal für dich',
                  farbe: radarMintHell,
                  hintergrund: radarGruen.withValues(alpha: 0.18),
                ),
                const Spacer(),
                if (rabatt != null)
                  _Plakette(text: '−$rabatt %', farbe: const Color(0xFF3A1C00), hintergrund: bierBernstein),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              a.bier.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textHell),
            ),
            const SizedBox(height: 2),
            Text(
              '${a.verpackung.bezeichnung} · ${a.haendler} · ${_wann(a)}',
              style: const TextStyle(color: Color(0xFFB8C4D9), fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  euro(treffer.preisFuerMich),
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: bierGoldHell),
                ),
                const SizedBox(width: 10),
                if (a.statt != null && a.statt! > treffer.preisFuerMich)
                  Text(
                    euro(a.statt!),
                    style: const TextStyle(
                      fontSize: 14,
                      color: textGedaempft,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: textGedaempft,
                    ),
                  ),
                const Spacer(),
                Text('${euro(treffer.literPreis)}/l', style: const TextStyle(color: radarMintHell, fontSize: 13)),
              ],
            ),
            if (a.karte != null && treffer.preisFuerMich == a.kartenPreis) ...[
              const SizedBox(height: 6),
              _Plakette(
                icon: Icons.credit_card,
                text: 'nur mit ${a.karte!.titel}',
                farbe: bierGoldHell,
                hintergrund: bierBernstein.withValues(alpha: 0.16),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Plakette extends StatelessWidget {
  const _Plakette({required this.text, required this.farbe, required this.hintergrund, this.icon});
  final String text;
  final Color farbe;
  final Color hintergrund;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: hintergrund, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: farbe), const SizedBox(width: 4)],
        Text(text, style: TextStyle(color: farbe, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _KartenTipp extends StatelessWidget {
  const _KartenTipp({required this.karte, required this.ersparnis});
  final Kundenkarte karte;
  final double ersparnis;

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF221A10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bierBernstein.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: bierGoldHell, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${karte.titel} lohnt sich für dich',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: textHell),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Du sparst diese Woche bei deinen Bieren ${euro(ersparnis)}. Die Karte ist gratis.',
            style: const TextStyle(color: Color(0xFFB8C4D9), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: bierBernstein,
                  foregroundColor: const Color(0xFF3A1C00),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => launchUrl(Uri.parse(karte.link), mode: LaunchMode.externalApplication),
                child: const Text('Karte holen'),
              ),
              TextButton(onPressed: () => z.karteUmschalten(karte), child: const Text('Hab ich schon')),
              TextButton(
                onPressed: z.kartenHinweisSpaeter,
                child: const Text('Später', style: TextStyle(color: textGedaempft)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AngebotZeile extends StatelessWidget {
  const _AngebotZeile({required this.treffer});
  final Treffer treffer;

  @override
  Widget build(BuildContext context) {
    final a = treffer.angebot;
    final aktiv = treffer.bewertung != Bewertung.zuTeuer;
    final spezial = a.bier.spezialitaet;
    final farbe = !aktiv ? textGedaempft : (spezial ? spezialLila : radarGruen);
    final rabatt = _rabatt(a, treffer.preisFuerMich);
    final mitKarte = a.karte != null && treffer.preisFuerMich == a.kartenPreis;
    final kartenTipp = treffer.bewertung == Bewertung.nurMitKarte;

    return GestureDetector(
      onTap: () => _zeigeDetails(context, treffer),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: karteFarbe,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: spezial && aktiv ? spezialLila.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: farbe.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
              child: Icon(spezial ? Icons.public : Icons.sports_bar, color: farbe, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.bier.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: aktiv ? textHell : textGedaempft,
                          ),
                        ),
                      ),
                      if (spezial && aktiv) ...[
                        const SizedBox(width: 6),
                        _Plakette(
                          text: 'Spezialität',
                          farbe: const Color(0xFFC9B8FF),
                          hintergrund: spezialLila.withValues(alpha: 0.18),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${a.verpackung.titel} · ${a.haendler} · ${_wann(a)}',
                    style: const TextStyle(fontSize: 12.5, color: textGedaempft),
                  ),
                  if (mitKarte || kartenTipp) ...[
                    const SizedBox(height: 5),
                    _Plakette(
                      icon: Icons.credit_card,
                      text: mitKarte
                          ? 'mit ${a.karte!.titel}'
                          : 'mit ${a.karte!.titel} nur ${euro(a.kartenPreis!)}',
                      farbe: bierGoldHell,
                      hintergrund: bierBernstein.withValues(alpha: 0.14),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (rabatt != null && aktiv)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _Plakette(text: '−$rabatt %', farbe: const Color(0xFF3A1C00), hintergrund: bierBernstein),
                  ),
                Text(
                  euro(treffer.preisFuerMich),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: aktiv ? bierGoldHell : textGedaempft,
                  ),
                ),
                Text('${euro(treffer.literPreis)}/l', style: const TextStyle(fontSize: 12, color: textGedaempft)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _zeigeDetails(BuildContext context, Treffer t) {
  final a = t.angebot;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF111827),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.bier.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textHell)),
            Text(
              '${a.verpackung.bezeichnung} · ${a.haendler}',
              style: const TextStyle(color: textGedaempft, fontSize: 15),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  euro(t.preisFuerMich),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: bierGoldHell),
                ),
                const SizedBox(width: 10),
                Text('${euro(t.literPreis)} pro Liter', style: const TextStyle(color: radarMintHell)),
              ],
            ),
            const SizedBox(height: 12),
            _DetailZeile(Icons.event, 'Gültig ${zeitraum(a.von, a.bis)} (${_wann(a)})'),
            if (a.statt != null) _DetailZeile(Icons.sell_outlined, 'Normalpreis ${euro(a.statt!)}'),
            if (a.kartenPreis != null)
              _DetailZeile(
                Icons.credit_card,
                'Mit ${a.karte!.titel} ${euro(a.kartenPreis!)}, ohne Karte ${euro(a.preis)}',
              ),
            if (!t.wunsch.immerMelden && t.wunsch.maxPreis != null)
              _DetailZeile(Icons.flag_outlined, 'Dein Wunschpreis: höchstens ${euro(t.wunsch.maxPreis!)}'),
            if (t.wunsch.immerMelden) const _DetailZeile(Icons.notifications_active_outlined, 'Wird immer gemeldet'),
            if (a.hinweis != null) _DetailZeile(Icons.info_outline, a.hinweis!),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.share),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Mit Freunden teilen'),
                ),
                onPressed: () {
                  final karte = a.kartenPreis != null ? ' (mit ${a.karte!.titel} ${euro(a.kartenPreis!)})' : '';
                  SharePlus.instance.share(
                    ShareParams(
                      text:
                          '🍺 ${a.bier.name} – ${a.verpackung.bezeichnung} um ${euro(a.preis)}$karte '
                          'bei ${a.haendler}, gültig ${zeitraum(a.von, a.bis)}. '
                          'Gefunden mit Bierradar 🏴‍☠️',
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DetailZeile extends StatelessWidget {
  const _DetailZeile(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: textGedaempft),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFB8C4D9), height: 1.35))),
      ],
    ),
  );
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
