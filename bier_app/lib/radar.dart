// Radar-Zeichnung für Logo, Startanimation und Live-Radar von BierRadar (moderner Look).

import 'dart:math' as math;

import 'package:flutter/material.dart';

// Farben
const radarHintergrund = Color(0xFF0A0E17); // Nachtblau
const radarGruen = Color(0xFF2EF2B1); // Mint (Name bleibt für den restlichen Code)
const radarMintHell = Color(0xFF7CFFD3);
const bierBernstein = Color(0xFFFFB547); // Bier-Orange
const bierGoldHell = Color(0xFFFFC861);
const bierOrange = Color(0xFFFF8A3D);
const spezialLila = Color(0xFFB9A4FF);
const textHell = Color(0xFFE9EEF8);
const textGedaempft = Color(0xFF8C97AD);
const karteFarbe = Color(0xFF141B2B);

/// Wo auf dem Radar das Bier gefunden wird (Winkel in Grad, Abstand 0..1).
const bierWinkelGrad = -40.0;
const bierAbstand = 0.55;

class Blip {
  const Blip(this.winkelGrad, this.abstand);
  final double winkelGrad;
  final double abstand;
}

const blips = [Blip(200, 0.75), Blip(120, 0.35), Blip(60, 0.82), Blip(250, 0.45), Blip(160, 0.62)];

class RadarMaler extends CustomPainter {
  RadarMaler({
    required this.zeigerGrad,
    this.bierSkala = 0,
    this.pingFortschritt = 0,
    this.blipHelligkeit = const [],
    this.fuerLogo = false,
    this.grau = false,
  });

  /// Winkel des Radar-Zeigers in Grad (0 = rechts, -90 = oben).
  final double zeigerGrad;

  /// 0 = Bier unsichtbar, 1 = Bier voll sichtbar.
  final double bierSkala;

  /// 0..1: Ring, der sich vom gefundenen Bier ausbreitet.
  final double pingFortschritt;

  /// Helligkeit je Blip (0..1).
  final List<double> blipHelligkeit;

  /// Logo: mit dunklem Hintergrund über die ganze Fläche.
  final bool fuerLogo;

  /// Ausgeschaltetes Radar (z. B. Beta abgelaufen).
  final bool grau;

  @override
  void paint(Canvas canvas, Size size) {
    final mitte = size.center(Offset.zero);
    final r = size.shortestSide * (fuerLogo ? 0.40 : 0.46);
    final akzent = grau ? const Color(0xFF4A5368) : radarGruen;

    if (fuerLogo) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141B2E), radarHintergrund],
          ).createShader(Offset.zero & size),
      );
    }

    // Schirm mit weichem Licht in der Mitte
    canvas.drawCircle(
      mitte,
      r,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF14273F), radarHintergrund])
            .createShader(Rect.fromCircle(center: mitte, radius: r)),
    );

    // Feine Ringe
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.008);
    for (final f in [0.36, 0.70]) {
      canvas.drawCircle(mitte, r * f, ring);
    }
    // Ganz zartes Fadenkreuz
    final kreuz = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = math.max(1, r * 0.006);
    canvas.drawLine(mitte.translate(-r, 0), mitte.translate(r, 0), kreuz);
    canvas.drawLine(mitte.translate(0, -r), mitte.translate(0, r), kreuz);

    // Lichtkegel hinter dem Zeiger
    final zeiger = zeigerGrad * math.pi / 180;
    const spur = 110 * math.pi / 180;
    final kreis = Rect.fromCircle(center: mitte, radius: r);
    if (!grau) {
      canvas.save();
      canvas.clipPath(Path()..addOval(kreis));
      canvas.drawArc(
        kreis,
        zeiger - spur,
        spur,
        true,
        Paint()
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: spur,
            colors: [
              akzent.withValues(alpha: 0),
              akzent.withValues(alpha: 0.12),
              akzent.withValues(alpha: 0.5),
            ],
            stops: const [0, 0.6, 1],
            transform: GradientRotation(zeiger - spur),
          ).createShader(kreis),
      );
      // Leuchtende Vorderkante
      final ende = mitte + Offset(math.cos(zeiger), math.sin(zeiger)) * r;
      canvas.drawLine(
        mitte,
        ende,
        Paint()
          ..color = akzent.withValues(alpha: 0.6)
          ..strokeWidth = r * 0.05
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
      );
      canvas.drawLine(
        mitte,
        ende,
        Paint()
          ..color = radarMintHell
          ..strokeWidth = math.max(1.2, r * 0.014)
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    // Außenring mit Leuchten
    canvas.drawCircle(
      mitte,
      r,
      Paint()
        ..color = akzent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
    );
    canvas.drawCircle(
      mitte,
      r,
      Paint()
        ..color = akzent.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, r * 0.016),
    );

    // Glühende Punkte
    for (var i = 0; i < blips.length && i < blipHelligkeit.length; i++) {
      final h = blipHelligkeit[i];
      if (h <= 0 || grau) continue;
      final b = blips[i];
      final w = b.winkelGrad * math.pi / 180;
      final p = mitte + Offset(math.cos(w), math.sin(w)) * r * b.abstand;
      canvas.drawCircle(
        p,
        r * 0.06,
        Paint()
          ..color = akzent.withValues(alpha: 0.5 * h)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
      );
      canvas.drawCircle(p, r * 0.022, Paint()..color = radarMintHell.withValues(alpha: h));
    }

    // Mittelpunkt
    canvas.drawCircle(mitte, r * 0.025, Paint()..color = grau ? akzent : radarMintHell);

    // Gefundenes Bier
    final bw = bierWinkelGrad * math.pi / 180;
    final bierPunkt = mitte + Offset(math.cos(bw), math.sin(bw)) * r * bierAbstand;

    if (pingFortschritt > 0 && pingFortschritt < 1) {
      for (final versatz in [0.0, 0.25]) {
        final f = (pingFortschritt - versatz).clamp(0.0, 1.0);
        if (f <= 0) continue;
        canvas.drawCircle(
          bierPunkt,
          r * (0.14 + 0.55 * f),
          Paint()
            ..color = bierBernstein.withValues(alpha: (1 - f) * 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.018,
        );
      }
    }
    if (bierSkala > 0) {
      final g = r * 0.26 * bierSkala;
      // Leuchten
      canvas.drawCircle(
        bierPunkt,
        g * 1.25,
        Paint()
          ..color = (grau ? Colors.grey : bierOrange).withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, g * 0.6),
      );
      // Abzeichen mit Farbverlauf
      final feld = RRect.fromRectAndRadius(
        Rect.fromCenter(center: bierPunkt, width: g * 1.7, height: g * 1.7),
        Radius.circular(g * 0.48),
      );
      canvas.drawRRect(
        feld,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: grau ? [const Color(0xFF6B7280), const Color(0xFF4B5563)] : [bierGoldHell, bierOrange],
          ).createShader(feld.outerRect),
      );
      _zeichneKrug(canvas, bierPunkt, g);
    }
  }

  /// Bierkrug (dunkel) mit weißer Schaumkrone, zentriert auf [p], Höhe ungefähr [h].
  void _zeichneKrug(Canvas canvas, Offset p, double h) {
    const dunkel = Color(0xFF3A1C00);
    final breite = h * 0.62;
    final hoehe = h * 0.74;
    final koerper = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p.translate(-h * 0.08, h * 0.12), width: breite, height: hoehe),
      Radius.circular(h * 0.1),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(koerper.right - h * 0.05, koerper.top + hoehe * 0.2, h * 0.27, hoehe * 0.5),
        Radius.circular(h * 0.12),
      ),
      Paint()
        ..color = dunkel
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.09,
    );
    canvas.drawRRect(koerper, Paint()..color = dunkel);
    final blase = Paint()..color = bierGoldHell.withValues(alpha: 0.85);
    canvas.drawCircle(p.translate(-h * 0.2, h * 0.28), h * 0.04, blase);
    canvas.drawCircle(p.translate(-h * 0.02, h * 0.1), h * 0.035, blase);
    canvas.drawCircle(p.translate(-h * 0.12, h * 0.4), h * 0.028, blase);
    final schaum = Paint()..color = Colors.white;
    final oben = koerper.top;
    for (final (dx, rad) in [(-0.24, 0.13), (-0.08, 0.16), (0.1, 0.13)]) {
      canvas.drawCircle(Offset(p.dx - h * 0.06 + h * dx * 1.1, oben), h * rad, schaum);
    }
  }

  @override
  bool shouldRepaint(RadarMaler alt) =>
      alt.zeigerGrad != zeigerGrad ||
      alt.bierSkala != bierSkala ||
      alt.pingFortschritt != pingFortschritt ||
      alt.blipHelligkeit != blipHelligkeit ||
      alt.grau != grau;
}

/// Das fertige Logo (Zeiger zeigt auf das gefundene Bier).
class RadarLogo extends StatelessWidget {
  const RadarLogo({super.key, this.groesse = 120});
  final double groesse;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: groesse,
    child: CustomPaint(
      painter: RadarMaler(
        zeigerGrad: bierWinkelGrad + 6,
        bierSkala: 1,
        blipHelligkeit: const [0.5, 0.3, 0.6, 0.25, 0.4],
      ),
    ),
  );
}

/// Kleines Radar, das sich ständig dreht (für Kopfzeile und Willkommen).
class LiveRadar extends StatefulWidget {
  const LiveRadar({
    super.key,
    this.groesse = 40,
    this.dauer = const Duration(milliseconds: 2400),
    this.mitBier = false,
  });
  final double groesse;
  final Duration dauer;
  final bool mitBier;

  @override
  State<LiveRadar> createState() => _LiveRadarState();
}

class _LiveRadarState extends State<LiveRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.dauer)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.groesse,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final grad = -90 + 360 * _c.value;
        return CustomPaint(
          painter: RadarMaler(
            zeigerGrad: grad,
            bierSkala: widget.mitBier ? 1 : 0,
            blipHelligkeit: [
              for (final b in blips) (1 - (((grad - b.winkelGrad) % 360 + 360) % 360) / 220).clamp(0.0, 1.0),
            ],
          ),
        );
      },
    ),
  );
}
