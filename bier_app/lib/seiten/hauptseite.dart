import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../daten.dart';
import '../erinnerung.dart';
import '../main.dart';
import '../radar.dart';
import '../zustand.dart';
import 'bausteine.dart';
import 'logbuch.dart';

class Hauptseite extends StatefulWidget {
  const Hauptseite({super.key});

  @override
  State<Hauptseite> createState() => _HauptseiteState();
}

class _HauptseiteState extends State<Hauptseite> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final seiten = [
      const _AngeboteSeite(),
      const EinkaufszettelSeite(),
      const LogbuchSeite(),
      const _MeineBiereSeite(),
      const _EinstellungenSeite(),
    ];
    return Scaffold(
      body: seiten[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: 'Radar'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Zettel'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Logbuch'),
          NavigationDestination(
            icon: Icon(Icons.sports_bar_outlined),
            selectedIcon: Icon(Icons.sports_bar),
            label: 'Biere',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Mehr',
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
    _Filter.kisten =>
      t.angebot.verpackung == Verpackung.kiste20x05 || t.angebot.verpackung == Verpackung.karton24x033,
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
    final bester =
        fuerDichAlle.where((t) => t.bewertung != Bewertung.spezialitaet).firstOrNull ??
        fuerDichAlle.firstOrNull;
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
              _UmkreisLeiste(z: z),
              _ErsparnisLeiste(woche: _wochenErsparnis(fuerDichAlle), gesamt: z.gespartGesamt),
              if (z.angeboteFehler != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    z.angeboteFehler!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (z.kartenHinweisAktiv)
                for (final e in tippKarten.entries) _KartenTipp(karte: e.key, ersparnis: e.value),
              if (bester != null && _filter == _Filter.alle)
                _Einblenden(index: 0, child: _BesterDeal(treffer: bester)),
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
              for (final (i, t) in rest.indexed)
                _Einblenden(
                  index: i + 1,
                  child: _AngebotZeile(treffer: t),
                ),
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
      text = z.filialen.isEmpty
          ? 'Live · ${z.gebiet.titel} · $wann'
          : 'Live · ${z.geschaefteImUmkreis} Geschäfte im Umkreis · $wann';
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
                  'BierRadar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textHell,
                    letterSpacing: 0.3,
                  ),
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
          boxShadow: [
            BoxShadow(color: radarGruen.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
          ],
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${euro(treffer.literPreis)}/l',
                      style: const TextStyle(color: radarMintHell, fontSize: 13),
                    ),
                    if (a.kartenPreis != null && treffer.preisFuerMich != a.kartenPreis) ...[
                      const SizedBox(height: 6),
                      _KartenPreisSchraeg(angebot: a),
                    ],
                  ],
                ),
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
        Text(
          text,
          style: TextStyle(color: farbe, fontSize: 12, fontWeight: FontWeight.w600),
        ),
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
    final kartenHinweis = a.kartenPreis != null && !mitKarte;
    final tiefst = aktiv ? ZustandScope.of(context).tiefstpreisWochen(a, treffer.literPreis) : null;
    final gemerkt = ZustandScope.of(context).gemerkt.contains(AppZustand.angebotSchluessel(a));

    return GestureDetector(
      onTap: () => _zeigeDetails(context, treffer),
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: karteFarbe,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: spezial && aktiv
                ? spezialLila.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: farbe.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
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
                      if (gemerkt) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star, color: bierGoldHell, size: 16),
                      ],
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
                  if (tiefst != null) ...[
                    const SizedBox(height: 5),
                    _Plakette(
                      icon: Icons.trending_down,
                      text: 'Tiefstpreis seit $tiefst Wochen',
                      farbe: radarMintHell,
                      hintergrund: radarGruen.withValues(alpha: 0.14),
                    ),
                  ],
                  if (mitKarte) ...[
                    const SizedBox(height: 5),
                    _Plakette(
                      icon: Icons.credit_card,
                      text: 'mit ${a.karte!.titel}',
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
                    child: _Plakette(
                      text: '−$rabatt %',
                      farbe: const Color(0xFF3A1C00),
                      hintergrund: bierBernstein,
                    ),
                  ),
                Text(
                  euro(treffer.preisFuerMich),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: aktiv ? bierGoldHell : textGedaempft,
                  ),
                ),
                Text(
                  '${euro(treffer.literPreis)}/l',
                  style: const TextStyle(fontSize: 12, color: textGedaempft),
                ),
                if (kartenHinweis) ...[const SizedBox(height: 6), _KartenPreisSchraeg(angebot: a)],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _zeigeDetails(BuildContext context, Treffer t) {
  final z = ZustandScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111827),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => ZustandScope(
      zustand: z,
      child: _Details(treffer: t),
    ),
  );
}

class _Details extends StatefulWidget {
  const _Details({required this.treffer});
  final Treffer treffer;

  @override
  State<_Details> createState() => _DetailsState();
}

class _DetailsState extends State<_Details> {
  final _kartenSchluessel = GlobalKey();
  bool _teilt = false;

  Future<void> _alsBildTeilen() async {
    setState(() => _teilt = true);
    try {
      final grenze = _kartenSchluessel.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bild = await grenze.toImage(pixelRatio: 3);
      final daten = await bild.toByteData(format: ui.ImageByteFormat.png);
      final a = widget.treffer.angebot;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(daten!.buffer.asUint8List(), mimeType: 'image/png', name: 'BierRadar-Angebot.png'),
          ],
          text:
              '🍺 ${a.bier.name} um ${euro(widget.treffer.preisFuerMich)} bei ${a.haendler} – gefunden mit BierRadar 🏴‍☠️',
        ),
      );
    } catch (e) {
      debugPrint('Teilen fehlgeschlagen: $e');
    }
    if (mounted) setState(() => _teilt = false);
  }

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final t = widget.treffer;
    final a = t.angebot;
    final schluessel = AppZustand.angebotSchluessel(a);
    final istGemerkt = z.gemerkt.contains(schluessel);
    final anzahlGekauft = z.gekauft[schluessel]?.anzahl ?? 0;
    final istGekauft = anzahlGekauft > 0;
    final ersparnis = AppZustand.ersparnis(a, t.preisFuerMich);
    final filiale = z.naechsteFiliale(a.haendler);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.bier.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textHell),
                      ),
                      Text(
                        '${a.verpackung.bezeichnung} · ${a.haendler}',
                        style: const TextStyle(color: textGedaempft, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: istGemerkt ? 'Nicht mehr merken' : 'Merken und erinnern',
                  iconSize: 30,
                  icon: Icon(istGemerkt ? Icons.star : Icons.star_border, color: bierGoldHell),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    z.merkenUmschalten(a);
                    if (!istGemerkt) {
                      final text = await erinnerungPlanen(a, schluessel);
                      messenger.showSnackBar(SnackBar(content: Text(text)));
                    } else {
                      await erinnerungLoeschen(schluessel);
                      messenger.showSnackBar(const SnackBar(content: Text('Nicht mehr gemerkt.')));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 8),
            if (filiale != null)
              _DetailZeile(
                Icons.storefront,
                'Nächste Filiale: ${filiale.$1.name}'
                '${filiale.$1.adresse.isNotEmpty ? ', ${filiale.$1.adresse}' : ''} '
                '(${filiale.$2.toStringAsFixed(1).replaceAll('.', ',')} km)',
              ),
            _DetailZeile(Icons.event, 'Gültig ${zeitraum(a.von, a.bis)} (${_wann(a)})'),
            if (pfandText(a.verpackung) != null) _DetailZeile(Icons.recycling, pfandText(a.verpackung)!),
            if (a.statt != null)
              _DetailZeile(
                Icons.sell_outlined,
                'Normalpreis ${euro(a.statt!)} – du sparst ${euro(ersparnis)}',
              ),
            if (a.kartenPreis != null)
              _DetailZeile(
                Icons.credit_card,
                'Mit ${a.karte!.titel} ${euro(a.kartenPreis!)}, ohne Karte ${euro(a.preis)}',
              ),
            if (!t.wunsch.immerMelden && t.wunsch.maxPreis != null)
              _DetailZeile(Icons.flag_outlined, 'Dein Wunschpreis: höchstens ${euro(t.wunsch.maxPreis!)}'),
            if (a.hinweis != null) _DetailZeile(Icons.info_outline, a.hinweis!),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Route zur Filiale'),
                    onPressed: () => launchUrl(
                      Uri.parse(
                        filiale != null
                            ? 'https://www.google.com/maps/dir/?api=1&destination=${filiale.$1.breite},${filiale.$1.laenge}'
                            : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${a.haendler} ${z.gebiet.kurz}')}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: istGekauft
                        ? OutlinedButton.styleFrom(
                            backgroundColor: radarGruen.withValues(alpha: 0.15),
                            side: const BorderSide(color: radarGruen),
                          )
                        : null,
                    icon: Icon(istGekauft ? Icons.check_circle : Icons.shopping_cart_outlined),
                    label: Text(istGekauft ? 'Gekauft: $anzahlGekauft ✓' : 'Gekauft! 🍺'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final anzahl = await _frageAnzahl(
                        context,
                        a,
                        istGekauft ? anzahlGekauft : 1,
                        istGekauft,
                      );
                      if (anzahl == null) return;
                      final neuerRang = z.gekauftSetzen(a, t.preisFuerMich, anzahl);
                      if (anzahl > 0 && ersparnis > 0) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Prost! ${euro(ersparnis * anzahl)} gespart – insgesamt ${euro(z.gespartGesamt)}.',
                            ),
                          ),
                        );
                      }
                      if (neuerRang != null && context.mounted) await zeigeRangAufstieg(context, neuerRang);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('So sehen es deine Freunde:', style: TextStyle(color: textGedaempft, fontSize: 13)),
            const SizedBox(height: 8),
            RepaintBoundary(
              key: _kartenSchluessel,
              child: _TeilKarte(treffer: t),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _teilt
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.share),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Mit Freunden teilen'),
                ),
                onPressed: _teilt ? null : _alsBildTeilen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Schöne Angebotskarte im BierRadar-Design – wird als Bild geteilt.
class _TeilKarte extends StatelessWidget {
  const _TeilKarte({required this.treffer});
  final Treffer treffer;

  @override
  Widget build(BuildContext context) {
    final a = treffer.angebot;
    final rabatt = _rabatt(a, treffer.preisFuerMich);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16203A), Color(0xFF0A0E17), Color(0xFF2A1E0E)],
        ),
        border: Border.all(color: radarGruen.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RadarLogo(groesse: 34),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (r) =>
                    const LinearGradient(colors: [radarMintHell, bierGoldHell]).createShader(r),
                child: const Text(
                  'BierRadar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const Spacer(),
              if (rabatt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: bierBernstein, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '−$rabatt %',
                    style: const TextStyle(color: Color(0xFF3A1C00), fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.bier.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textHell),
                    ),
                    Text(
                      '${a.verpackung.bezeichnung}\nbei ${a.haendler}',
                      style: const TextStyle(color: Color(0xFFB8C4D9), fontSize: 13, height: 1.35),
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Image.asset('assets/bilder/pirat.png', width: 64, height: 64, fit: BoxFit.cover),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                euro(treffer.preisFuerMich),
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: bierGoldHell),
              ),
              const SizedBox(width: 8),
              if (a.statt != null && a.statt! > treffer.preisFuerMich)
                Text(
                  euro(a.statt!),
                  style: const TextStyle(
                    color: textGedaempft,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: textGedaempft,
                  ),
                ),
              const Spacer(),
              if (a.kartenPreis != null && treffer.preisFuerMich != a.kartenPreis)
                _KartenPreisSchraeg(angebot: a),
            ],
          ),
          Text(
            'gültig ${zeitraum(a.von, a.bis)} · ${euro(treffer.literPreis)}/l',
            style: const TextStyle(color: radarMintHell, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          const Text(
            '🏴‍☠️ Gefunden mit BierRadar – nie wieder eine Bier-Aktion verpassen!',
            style: TextStyle(color: textGedaempft, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
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
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFFB8C4D9), height: 1.35)),
        ),
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
          ListTile(
            leading: const Icon(Icons.location_on, color: radarGruen),
            title: const Text('Unterstützte Gebiete'),
            subtitle: Text(
              'Bezirk Amstetten (NÖ), Steyr und Bezirk Steyr-Land (OÖ)\n'
              '${z.standortBreite != null ? 'Dein Standort wird genutzt' : 'Kein Standort – Mitte: ${z.gebiet.titel}'}'
              ' · Umkreis ${z.radiusKm.round()} km auf der Radar-Seite',
            ),
            isThreeLine: true,
          ),
          ListTile(
            leading: Icon(Icons.notifications_active),
            title: Text('Benachrichtigungen'),
            subtitle: Text(
              Theme.of(context).platform == TargetPlatform.android
                  ? 'Aktiv: Du bekommst eine Meldung spätestens ca. 1 Stunde nach einem neuen Flugblatt, '
                        'wenn dein Bier unter deinem Wunschpreis ist.'
                  : 'In der iPhone-Beta gibt es noch keine Push-Meldungen. Öffne die App, um die neuesten Angebote zu sehen.',
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
          const Divider(height: 32),
          const _UeberDieApp(),
        ],
      ),
    );
  }
}

const appVersion = '1.0.0 · Beta';

/// „Über die App“ – ganz unten in den Einstellungen, wie bei anderen Apps üblich.
class _UeberDieApp extends StatelessWidget {
  const _UeberDieApp();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        children: [
          const RadarLogo(groesse: 64),
          const SizedBox(height: 10),
          const Text(
            'BierRadar',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textHell),
          ),
          const Text('Version $appVersion', style: TextStyle(color: textGedaempft, fontSize: 13)),
          const SizedBox(height: 14),
          const Text('Entwickelt von', style: TextStyle(color: textGedaempft, fontSize: 12)),
          const Text(
            'Michael Augsten',
            style: TextStyle(color: bierGoldHell, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          const Text(
            'Angebote aus öffentlichen Flugblatt-Daten.\nAlle Preise ohne Gewähr.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textGedaempft, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'BierRadar',
              applicationVersion: appVersion,
              applicationLegalese: '© ${DateTime.now().year} Michael Augsten',
            ),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF56617A)),
            child: const Text('Rechtliches & Lizenzen', style: TextStyle(fontSize: 12)),
          ),
          Text(
            '© ${DateTime.now().year} Michael Augsten · Prost! 🍻',
            style: const TextStyle(color: Color(0xFF56617A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Schräges Etikett „Lidl Plus nur 12,80 €“, wenn man die Karte (noch) nicht hat.
class _KartenPreisSchraeg extends StatelessWidget {
  const _KartenPreisSchraeg({required this.angebot});
  final Angebot angebot;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.1,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [bierGoldHell, bierOrange]),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: bierOrange.withValues(alpha: 0.4), blurRadius: 8)],
      ),
      child: Text(
        '${angebot.karte!.titel} nur ${euro(angebot.kartenPreis!)}',
        style: const TextStyle(color: Color(0xFF3A1C00), fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

/// Größte mögliche Ersparnis je Bier und Verpackung (damit gleiche Aktionen nicht doppelt zählen).
double _wochenErsparnis(List<Treffer> treffer) {
  final besteJe = <String, double>{};
  for (final t in treffer) {
    final e = AppZustand.ersparnis(t.angebot, t.preisFuerMich);
    final k = '${t.angebot.bierId}|${t.angebot.verpackung.name}';
    if (e > (besteJe[k] ?? 0)) besteJe[k] = e;
  }
  return besteJe.values.fold(0.0, (a, b) => a + b);
}

class _ErsparnisLeiste extends StatelessWidget {
  const _ErsparnisLeiste({required this.woche, required this.gesamt});
  final double woche;
  final double gesamt;

  @override
  Widget build(BuildContext context) {
    Widget feld(IconData icon, String titel, double wert, Color farbe) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: farbe.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: farbe.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: farbe, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titel, style: const TextStyle(color: textGedaempft, fontSize: 11.5)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: wert),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => Text(
                      euro(v),
                      style: TextStyle(color: farbe, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        children: [
          feld(Icons.savings_outlined, 'Diese Woche drin', woche, radarGruen),
          const SizedBox(width: 10),
          feld(Icons.emoji_events_outlined, 'Gespart seit Start', gesamt, bierGoldHell),
        ],
      ),
    );
  }
}

/// Fragt, wie viele (Kisten/Flaschen …) gekauft wurden. null = abgebrochen, 0 = entfernen.
Future<int?> _frageAnzahl(BuildContext context, Angebot a, int start, bool schonGekauft) {
  var anzahl = start.clamp(1, 99);
  final einheit = a.verpackung.titel;
  return showDialog<int>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setze) => AlertDialog(
        backgroundColor: const Color(0xFF141B2B),
        title: const Text('Wie viele hast du gekauft?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${a.bier.name} · $einheit', style: const TextStyle(color: textGedaempft)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: anzahl > 1 ? () => setze(() => anzahl--) : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '$anzahl',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: bierGoldHell),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: anzahl < 99 ? () => setze(() => anzahl++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              anzahl == 1 ? '1 × $einheit' : '$anzahl × $einheit',
              style: const TextStyle(color: textGedaempft, fontSize: 13),
            ),
          ],
        ),
        actions: [
          if (schonGekauft)
            TextButton(
              onPressed: () => Navigator.pop(c, 0),
              child: const Text('Entfernen', style: TextStyle(color: textGedaempft)),
            ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(c, anzahl), child: const Text('Speichern')),
        ],
      ),
    ),
  );
}

/// Schieber für die Radar-Reichweite (1–100 km). Nach „Suchen“ läuft kurz die Radar-Animation.
class _UmkreisLeiste extends StatefulWidget {
  const _UmkreisLeiste({required this.z});
  final AppZustand z;

  @override
  State<_UmkreisLeiste> createState() => _UmkreisLeisteState();
}

class _UmkreisLeisteState extends State<_UmkreisLeiste> {
  late double _km = widget.z.radiusKm;

  Future<void> _suchen() async {
    final z = widget.z;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LiveRadar(groesse: 220, dauer: Duration(milliseconds: 1200)),
              const SizedBox(height: 20),
              Material(
                color: Colors.transparent,
                child: Text(
                  'Radar sucht im Umkreis von ${_km.round()} km …',
                  style: const TextStyle(color: radarMintHell, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    z.radiusSetzen(_km.roundToDouble());
    await Future.wait([z.angeboteAktualisieren(), Future<void>.delayed(const Duration(milliseconds: 1800))]);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.z;
    final geaendert = _km.round() != z.radiusKm.round();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 4),
      decoration: BoxDecoration(
        color: karteFarbe,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: radarGruen.withValues(alpha: geaendert ? 0.6 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: radarGruen, size: 20),
              const SizedBox(width: 8),
              const Text('Radar-Reichweite', style: TextStyle(color: textGedaempft, fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                '${_km.round()} km',
                style: const TextStyle(color: radarMintHell, fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: geaendert ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: geaendert ? _suchen : null,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Suchen'),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: radarGruen,
              thumbColor: radarMintHell,
              inactiveTrackColor: const Color(0xFF1B2438),
              overlayColor: radarGruen.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: _km,
              min: 1,
              max: 100,
              divisions: 99,
              label: '${_km.round()} km',
              onChanged: (v) => setState(() => _km = v),
            ),
          ),
          if (z.standortBreite == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Ohne Standort gilt dein Gebiet aus den Einstellungen als Mittelpunkt.',
                style: TextStyle(color: textGedaempft, fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}
