// Radar-Zeichnung für Logo und Startanimation von Bierradar.

import 'dart:math' as math;

import 'package:flutter/material.dart';

const radarHintergrund = Color(0xFF06140D);
const radarGruen = Color(0xFF3DFF8F);
const bierBernstein = Color(0xFFF2A516);

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
  });

  /// Winkel des Radar-Zeigers in Grad (0 = rechts, -90 = oben).
  final double zeigerGrad;

  /// 0 = Bier unsichtbar, 1 = Bier voll sichtbar.
  final double bierSkala;

  /// 0..1: Ring, der sich vom gefundenen Bier ausbreitet.
  final double pingFortschritt;

  /// Helligkeit je Blip (0..1).
  final List<double> blipHelligkeit;

  /// Logo: mit abgerundetem dunklem Hintergrund über die ganze Fläche.
  final bool fuerLogo;

  @override
  void paint(Canvas canvas, Size size) {
    final mitte = size.center(Offset.zero);
    final r = size.shortestSide * (fuerLogo ? 0.40 : 0.46);

    if (fuerLogo) {
      canvas.drawRect(Offset.zero & size, Paint()..color = radarHintergrund);
    }

    // Leuchtender Radarschirm
    canvas.drawCircle(
      mitte,
      r,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0xFF0E3B22), radarHintergrund])
            .createShader(Rect.fromCircle(center: mitte, radius: r)),
    );

    // Ringe und Fadenkreuz
    final linie = Paint()
      ..color = radarGruen.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.012;
    for (final f in [0.33, 0.66]) {
      canvas.drawCircle(mitte, r * f, linie);
    }
    canvas.drawLine(mitte.translate(-r, 0), mitte.translate(r, 0), linie);
    canvas.drawLine(mitte.translate(0, -r), mitte.translate(0, r), linie);
    canvas.drawCircle(
      mitte,
      r,
      Paint()
        ..color = radarGruen.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.035,
    );

    // Leuchtspur hinter dem Zeiger
    final zeiger = zeigerGrad * math.pi / 180;
    const spur = 70 * math.pi / 180;
    final kreis = Rect.fromCircle(center: mitte, radius: r);
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
          colors: [radarGruen.withValues(alpha: 0), radarGruen.withValues(alpha: 0.55)],
          transform: GradientRotation(zeiger - spur),
        ).createShader(kreis),
    );
    canvas.restore();

    // Zeiger
    canvas.drawLine(
      mitte,
      mitte + Offset(math.cos(zeiger), math.sin(zeiger)) * r,
      Paint()
        ..color = radarGruen
        ..strokeWidth = r * 0.025
        ..strokeCap = StrokeCap.round,
    );

    // Blips (andere Punkte am Radar)
    for (var i = 0; i < blips.length && i < blipHelligkeit.length; i++) {
      final h = blipHelligkeit[i];
      if (h <= 0) continue;
      final b = blips[i];
      final w = b.winkelGrad * math.pi / 180;
      final p = mitte + Offset(math.cos(w), math.sin(w)) * r * b.abstand;
      canvas.drawCircle(p, r * 0.035, Paint()..color = radarGruen.withValues(alpha: h));
    }

    // Mittelpunkt
    canvas.drawCircle(mitte, r * 0.03, Paint()..color = radarGruen);

    // Gefundenes Bier
    final bw = bierWinkelGrad * math.pi / 180;
    final bierPunkt = mitte + Offset(math.cos(bw), math.sin(bw)) * r * bierAbstand;

    if (pingFortschritt > 0 && pingFortschritt < 1) {
      canvas.drawCircle(
        bierPunkt,
        r * (0.1 + 0.5 * pingFortschritt),
        Paint()
          ..color = bierBernstein.withValues(alpha: 1 - pingFortschritt)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.02,
      );
    }
    if (bierSkala > 0) {
      // Leuchten
      canvas.drawCircle(
        bierPunkt,
        r * 0.30 * bierSkala,
        Paint()
          ..shader = RadialGradient(
            colors: [bierBernstein.withValues(alpha: 0.55), bierBernstein.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: bierPunkt, radius: r * 0.30 * bierSkala)),
      );
      _zeichneKrug(canvas, bierPunkt, r * 0.30 * bierSkala);
    }
  }

  /// Bierkrug mit Schaum, zentriert auf [p], Höhe ungefähr [h].
  void _zeichneKrug(Canvas canvas, Offset p, double h) {
    final breite = h * 0.62;
    final hoehe = h * 0.78;
    final koerper = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p.translate(-h * 0.06, h * 0.1), width: breite, height: hoehe),
      Radius.circular(h * 0.08),
    );
    // Henkel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(koerper.right - h * 0.04, koerper.top + hoehe * 0.2, h * 0.26, hoehe * 0.5),
        Radius.circular(h * 0.1),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.08,
    );
    // Glas mit Bier
    canvas.drawRRect(koerper, Paint()..color = bierBernstein);
    // Glasrand
    canvas.drawRRect(
      koerper,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.06,
    );
    // Bläschen
    final blase = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(p.translate(-h * 0.18, h * 0.25), h * 0.035, blase);
    canvas.drawCircle(p.translate(h * 0.0, h * 0.05), h * 0.03, blase);
    canvas.drawCircle(p.translate(-h * 0.1, h * 0.38), h * 0.025, blase);
    // Schaumkrone
    final schaum = Paint()..color = Colors.white;
    final oben = koerper.top;
    for (final (dx, rad) in [(-0.22, 0.13), (-0.06, 0.16), (0.12, 0.13)]) {
      canvas.drawCircle(Offset(p.dx - h * 0.06 + h * dx * 1.1, oben), h * rad, schaum);
    }
  }

  @override
  bool shouldRepaint(RadarMaler alt) =>
      alt.zeigerGrad != zeigerGrad ||
      alt.bierSkala != bierSkala ||
      alt.pingFortschritt != pingFortschritt ||
      alt.blipHelligkeit != blipHelligkeit;
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
