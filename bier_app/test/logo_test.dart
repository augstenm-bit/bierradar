// Erzeugt das App-Symbol (Radar + Pirat) als PNG: flutter test test/logo_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bier_app/radar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _bildLaden(String pfad) async {
  final codec = await ui.instantiateImageCodec(File(pfad).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// Zeichnet das Logo in ein Quadrat der Größe [g]; [mitHintergrund] = false für Android-Vordergrund.
void _logo(Canvas canvas, double g, ui.Image pirat, {required bool mitHintergrund, double rand = 0}) {
  if (mitHintergrund) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, g, g),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16203A), radarHintergrund],
        ).createShader(Rect.fromLTWH(0, 0, g, g)),
    );
  }
  canvas.save();
  canvas.translate(rand, rand);
  final s = g - 2 * rand;
  // Radar ohne Bier, Zeiger oben rechts
  RadarMaler(zeigerGrad: -35, blipHelligkeit: const [0.9, 0.5, 0.8, 0.4, 0.6]).paint(canvas, Size.square(s));

  // Pirat in der Mitte mit goldenem Ring und Leuchten
  final mitte = Offset(s / 2, s / 2);
  final r = s * 0.30;
  canvas.drawCircle(
    mitte,
    r * 1.12,
    Paint()
      ..color = bierOrange.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
  );
  canvas.save();
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: mitte, radius: r)));
  final quelle = Rect.fromLTWH(0, 0, pirat.width.toDouble(), pirat.height.toDouble());
  canvas.drawImageRect(
    pirat,
    quelle,
    Rect.fromCircle(center: mitte, radius: r * 1.02),
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();
  canvas.drawCircle(
    mitte,
    r,
    Paint()
      ..shader = const SweepGradient(
        colors: [bierGoldHell, bierOrange, bierGoldHell],
      ).createShader(Rect.fromCircle(center: mitte, radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022,
  );
  // kleiner leuchtender Treffer-Punkt oben rechts am Radar
  final w = -35 * math.pi / 180;
  final p = mitte + Offset(math.cos(w), math.sin(w)) * s * 0.40;
  canvas.drawCircle(
    p,
    s * 0.03,
    Paint()
      ..color = radarGruen.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
  );
  canvas.drawCircle(p, s * 0.014, Paint()..color = radarMintHell);
  canvas.restore();
}

Future<void> _speichern(String pfad, double g, void Function(Canvas) malen) async {
  final rec = ui.PictureRecorder();
  malen(Canvas(rec));
  final bild = await rec.endRecording().toImage(g.toInt(), g.toInt());
  final daten = await bild.toByteData(format: ui.ImageByteFormat.png);
  File(pfad).writeAsBytesSync(daten!.buffer.asUint8List());
}

void main() {
  testWidgets('Logo als PNG speichern', (tester) async {
    await tester.runAsync(() async {
      final pirat = await _bildLaden('assets/bilder/pirat.png');
      const g = 1024.0;
      // iPhone / allgemein: mit Hintergrund, Radar etwas eingerückt
      await _speichern(
        'assets/logo/bierradar_icon.png',
        g,
        (c) => _logo(c, g, pirat, mitHintergrund: true, rand: g * 0.04),
      );
      // Android: transparenter Vordergrund mit Sicherheitsrand für runde Masken
      await _speichern(
        'assets/logo/bierradar_vordergrund.png',
        g,
        (c) => _logo(c, g, pirat, mitHintergrund: false, rand: g * 0.17),
      );
    });
    expect(File('assets/logo/bierradar_icon.png').existsSync(), isTrue);
  });
}
