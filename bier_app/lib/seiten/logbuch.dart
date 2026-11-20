// Piraten-Logbuch: Rang, „Dein Bierjahr“-Statistik (zum Teilen) und der Einkaufszettel.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../daten.dart';
import '../main.dart';
import '../radar.dart';
import '../zustand.dart';
import 'willkommen.dart' show BierRegenMaler;

// ---------------------------------------------------------------- Rang-Aufstieg

/// Kleine Feier mit Bier-Regen, wenn man einen neuen Piraten-Rang erreicht.
Future<void> zeigeRangAufstieg(BuildContext context, Rang rang) => showDialog<void>(
  context: context,
  barrierColor: Colors.black87,
  builder: (c) => _RangFeier(rang: rang),
);

class _RangFeier extends StatefulWidget {
  const _RangFeier({required this.rang});
  final Rang rang;

  @override
  State<_RangFeier> createState() => _RangFeierState();
}

class _RangFeierState extends State<_RangFeier> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => CustomPaint(painter: BierRegenMaler(_c.value)),
          ),
        ),
      ),
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (_, s, kind) => Transform.scale(scale: s, child: kind),
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: karteFarbe,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: bierGoldHell, width: 2),
                boxShadow: [BoxShadow(color: bierOrange.withValues(alpha: 0.5), blurRadius: 40)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'BEFÖRDERT!',
                    style: TextStyle(color: radarGruen, letterSpacing: 3, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.rang.emoji, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 8),
                  Text(
                    widget.rang.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: bierGoldHell),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Arrr! Du hast mit BierRadar ordentlich gespart.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFB8C4D9)),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Prost! 🍻')),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------- Logbuch

const _monate = ['Jän', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];

class LogbuchSeite extends StatefulWidget {
  const LogbuchSeite({super.key});

  @override
  State<LogbuchSeite> createState() => _LogbuchSeiteState();
}

class _LogbuchSeiteState extends State<LogbuchSeite> {
  final _karte = GlobalKey();

  Future<void> _teilen() async {
    final grenze = _karte.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bild = await grenze.toImage(pixelRatio: 3);
    final daten = await bild.toByteData(format: ui.ImageByteFormat.png);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(daten!.buffer.asUint8List(), mimeType: 'image/png', name: 'Mein-Bierjahr.png'),
        ],
        text: 'Mein Bierjahr mit BierRadar 🍺🏴‍☠️',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final gespart = z.gespartGesamt;
    final rang = rangFuer(gespart);
    final naechster = naechsterRang(gespart);
    final kaeufe = z.gekauft.values.toList();
    final stueck = kaeufe.fold(0, (s, k) => s + k.anzahl);
    final liter = kaeufe.fold(0.0, (s, k) {
      final v = Verpackung.values.where((x) => x.name == k.verpackung).firstOrNull;
      return s + (v?.liter ?? 0) * k.anzahl;
    });

    // Lieblingsbier und bester Deal
    final jeBier = <String, int>{};
    for (final k in kaeufe) {
      jeBier[k.bierId] = (jeBier[k.bierId] ?? 0) + k.anzahl;
    }
    final lieblings = jeBier.entries.isEmpty
        ? null
        : (jeBier.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
    final bester = kaeufe.isEmpty
        ? null
        : (kaeufe.toList()..sort((a, b) => b.ersparnisJe.compareTo(a.ersparnisJe))).first;

    // Ersparnis der letzten 6 Monate
    final jetzt = DateTime.now();
    final monate = [for (var i = 5; i >= 0; i--) DateTime(jetzt.year, jetzt.month - i)];
    final proMonat = [
      for (final m in monate)
        kaeufe
            .where((k) => k.datum.year == m.year && k.datum.month == m.month)
            .fold(0.0, (s, k) => s + k.ersparnisJe * k.anzahl),
    ];
    final maxMonat = proMonat.fold(1.0, (a, b) => b > a ? b : a);

    return Scaffold(
      appBar: AppBar(title: const Text('Piraten-Logbuch')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          RepaintBoundary(
            key: _karte,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16203A), Color(0xFF0A0E17), Color(0xFF2A1E0E)],
                ),
                border: Border.all(color: bierGoldHell.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const RadarLogo(groesse: 30),
                      const SizedBox(width: 8),
                      Text(
                        'Mein Bierjahr ${jetzt.year}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: textHell, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(rang.emoji, style: const TextStyle(fontSize: 44)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Dein Rang', style: TextStyle(color: textGedaempft, fontSize: 12)),
                            Text(
                              rang.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: bierGoldHell,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (naechster != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: ((gespart - rang.ab) / (naechster.ab - rang.ab)).clamp(0.0, 1.0),
                        color: bierGoldHell,
                        backgroundColor: const Color(0xFF1B2438),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Noch ${euro(naechster.ab - gespart)} bis ${naechster.emoji} ${naechster.name}',
                      style: const TextStyle(color: textGedaempft, fontSize: 12),
                    ),
                  ] else
                    const Text(
                      'Höchster Rang erreicht – Respekt! 👑',
                      style: TextStyle(color: textGedaempft),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Zahl('Gespart', euro(gespart), radarGruen),
                      _Zahl('Gekauft', '$stueck ×', bierGoldHell),
                      _Zahl('Bier', '${liter.toStringAsFixed(0)} l', spezialLila),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (lieblings != null) _Zeile(Icons.favorite, 'Lieblingsbier', bierMitId(lieblings).name),
                  if (bester != null && bester.ersparnisJe > 0)
                    _Zeile(
                      Icons.local_fire_department,
                      'Bester Deal',
                      '${bierMitId(bester.bierId).name} bei ${bester.haendler} (−${euro(bester.ersparnisJe)})',
                    ),
                  const SizedBox(height: 14),
                  const Text('Ersparnis pro Monat', style: TextStyle(color: textGedaempft, fontSize: 12)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < monate.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (proMonat[i] > 0)
                                    Text(
                                      proMonat[i].toStringAsFixed(0),
                                      style: const TextStyle(color: textGedaempft, fontSize: 10),
                                    ),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: proMonat[i] / maxMonat),
                                    duration: const Duration(milliseconds: 800),
                                    builder: (_, h, _) => Container(
                                      height: 4 + 56 * h,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: const LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [bierOrange, bierGoldHell],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _monate[monate[i].month - 1],
                                    style: const TextStyle(color: textGedaempft, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '🏴‍☠️ Gefunden mit BierRadar',
                    style: TextStyle(color: textGedaempft, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _teilen,
            icon: const Icon(Icons.share),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Mein Bierjahr teilen'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Alle Ränge',
            style: TextStyle(color: textGedaempft, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final r in raenge)
            ListTile(
              dense: true,
              leading: Text(r.emoji, style: const TextStyle(fontSize: 24)),
              title: Text(
                r.name,
                style: TextStyle(
                  color: r == rang ? bierGoldHell : textHell,
                  fontWeight: r == rang ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
              trailing: Text(
                r.ab == 0 ? 'Start' : 'ab ${euro(r.ab)}',
                style: const TextStyle(color: textGedaempft),
              ),
            ),
          if (kaeufe.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Tipp: Tippe bei einem Angebot auf „Gekauft! 🍺“ – dann füllt sich dein Logbuch.',
                style: TextStyle(color: textGedaempft),
              ),
            ),
        ],
      ),
    );
  }
}

class _Zahl extends StatelessWidget {
  const _Zahl(this.titel, this.wert, this.farbe);
  final String titel;
  final String wert;
  final Color farbe;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titel, style: const TextStyle(color: textGedaempft, fontSize: 12)),
        Text(
          wert,
          style: TextStyle(color: farbe, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _Zeile extends StatelessWidget {
  const _Zeile(this.icon, this.titel, this.text);
  final IconData icon;
  final String titel;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: bierBernstein),
        const SizedBox(width: 8),
        Text('$titel: ', style: const TextStyle(color: textGedaempft)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: textHell, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Einkaufszettel

class EinkaufszettelSeite extends StatelessWidget {
  const EinkaufszettelSeite({super.key});

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final heute = DateTime.now();
    final tag = DateTime(heute.year, heute.month, heute.day);
    final eintraege = [
      for (final a in z.angebote)
        if (z.gemerkt.contains(AppZustand.angebotSchluessel(a)) && !a.bis.isBefore(tag)) a,
    ];
    final jeHaendler = <String, List<Angebot>>{};
    for (final a in eintraege) {
      jeHaendler.putIfAbsent(a.haendler, () => []).add(a);
    }
    final haendler = jeHaendler.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Einkaufszettel')),
      body: eintraege.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Dein Zettel ist leer.\nMerke dir Angebote mit dem ⭐ – sie landen hier, sortiert nach Geschäft.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textGedaempft, height: 1.5),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              children: [
                for (final h in haendler) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: bierBernstein, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            z.filialText(h),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: textHell,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final a in jeHaendler[h]!)
                    Builder(
                      builder: (_) {
                        final k = AppZustand.angebotSchluessel(a);
                        final erledigt = z.abgehakt.contains(k);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: karteFarbe,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: CheckboxListTile(
                            value: erledigt,
                            onChanged: (_) => z.abhakenUmschalten(k),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              a.bier.name,
                              style: TextStyle(
                                decoration: erledigt ? TextDecoration.lineThrough : null,
                                color: erledigt ? textGedaempft : textHell,
                              ),
                            ),
                            subtitle: Text(
                              '${a.verpackung.bezeichnung} · ${euro(a.preis)} · bis ${a.bis.day}.${a.bis.month}.'
                              '${pfandText(a.verpackung) != null ? ' · ${pfandText(a.verpackung)}' : ''}',
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
    );
  }
}
