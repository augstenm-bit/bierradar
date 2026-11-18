// Startanimation: Radar taucht auf, Zeiger kreist, findet das Bier, App öffnet sich.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../radar.dart';

class Intro extends StatefulWidget {
  const Intro({super.key, required this.fertig});
  final VoidCallback fertig;

  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _beendet = false;

  // Zeitplan (Anteile der Gesamtdauer)
  static const _gefundenBei = 0.62;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _fertig();
      })
      ..forward();
  }

  void _fertig() {
    if (_beendet) return;
    _beendet = true;
    widget.fertig();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _abschnitt(double t, double von, double bis) => ((t - von) / (bis - von)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: radarHintergrund,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _fertig, // Antippen überspringt die Animation
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;

            // 1) Radar taucht auf
            final auftauchen = Curves.easeOutBack.transform(_abschnitt(t, 0, 0.14));

            // 2) Zeiger kreist 2 Runden und bremst beim Bier ab
            const start = -90.0;
            const ziel = bierWinkelGrad + 720 + 90; // Strecke bis zum Bier
            final dreh = Curves.easeInOutCubic.transform(_abschnitt(t, 0.06, _gefundenBei));
            final zeigerGrad = start + ziel * dreh;

            // Blips leuchten auf, wenn der Zeiger vorbeikommt, und verblassen
            final helligkeit = [for (final b in blips) _blipHelligkeit(zeigerGrad, b.winkelGrad, t)];

            // 3) Bier gefunden
            final bier = Curves.elasticOut.transform(_abschnitt(t, _gefundenBei, _gefundenBei + 0.16));
            final ping = _abschnitt(t, _gefundenBei, _gefundenBei + 0.22);

            // 4) Schriftzug und Ausblenden
            final schrift = Curves.easeOut.transform(_abschnitt(t, 0.70, 0.84));
            final aus = 1 - _abschnitt(t, 0.93, 1.0);

            return Opacity(
              opacity: aus,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.5 + 0.5 * auftauchen,
                      child: Opacity(
                        opacity: auftauchen.clamp(0.0, 1.0),
                        child: SizedBox.square(
                          dimension: math.min(MediaQuery.sizeOf(context).width * 0.8, 380),
                          child: CustomPaint(
                            painter: RadarMaler(
                              zeigerGrad: zeigerGrad,
                              bierSkala: bier,
                              pingFortschritt: ping,
                              blipHelligkeit: helligkeit,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Opacity(
                      opacity: schrift,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - schrift)),
                        child: Column(
                          children: [
                            const Text(
                              'Bierradar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Bier gefunden!', style: TextStyle(color: bierBernstein, fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Ein Blip leuchtet kurz nach dem Überstreichen auf und verblasst dann.
  double _blipHelligkeit(double zeigerGrad, double blipGrad, double t) {
    if (t < 0.08) return 0;
    var abstand = (zeigerGrad - blipGrad) % 360;
    if (abstand < 0) abstand += 360;
    if (zeigerGrad < blipGrad) return 0; // noch nie überstrichen
    return (1 - abstand / 200).clamp(0.0, 1.0);
  }
}
