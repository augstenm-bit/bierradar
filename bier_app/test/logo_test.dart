// Erzeugt das App-Symbol (grünes Radar, darin Bier mit Glas-Radar) als PNG: flutter test test/logo_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bier_app/radar.dart';
import 'package:bier_app/seiten/intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _bildLaden(String pfad) async {
  final codec = await ui.instantiateImageCodec(File(pfad).readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

/// Ausschnitt aus dem Bierfoto: oben ein schmaler Streifen Schaum, darunter goldenes Bier mit Perlen.
Rect _ausschnitt(ui.Image bier) => Rect.fromLTWH(0, bier.height * 0.2, bier.width.toDouble(), bier.width.toDouble());

/// Glas-Radar: das Bier darunter verschwommen (mattes Glas), heller Schleier, weiße Ringe und Lichtkegel.
void _glasRadar(Canvas canvas, ui.Image bier, Rect bierZiel, Offset mitte, double r) {
  final kreis = Path()..addOval(Rect.fromCircle(center: mitte, radius: r));
  // Schatten
  canvas.drawCircle(
    mitte.translate(0, r * 0.06),
    r,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1),
  );
  canvas.save();
  canvas.clipPath(kreis);
  canvas.saveLayer(null, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: r * 0.035, sigmaY: r * 0.035));
  canvas.drawImageRect(bier, _ausschnitt(bier), bierZiel, Paint()..filterQuality = FilterQuality.high);
  canvas.restore();
  canvas.drawCircle(mitte, r, Paint()..color = Colors.white.withValues(alpha: 0.16));
  canvas.restore();
  canvas.save();
  canvas.translate(mitte.dx - r, mitte.dy - r);
  GlasRadarMaler(0.94, 1).paint(canvas, Size.square(r * 2));
  canvas.restore();
}

/// Wie auf der Willkommen-Seite: grünes Radar, in der Mitte Bier mit Glas-Radar.
/// [mitHintergrund] = false für den Android-Vordergrund (Hintergrund kommt dort extra).
void _logo(Canvas canvas, double g, ui.Image bier, {required bool mitHintergrund, double rand = 0}) {
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
  RadarMaler(zeigerGrad: -35, blipHelligkeit: const [0.9, 0.5, 0.8, 0.4, 0.6]).paint(canvas, Size.square(s));
  final mitte = Offset(s / 2, s / 2);
  final r = s * 0.39;
  canvas.drawCircle(
    mitte,
    r * 1.05,
    Paint()
      ..color = bierOrange.withValues(alpha: 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.14),
  );
  _glasRadar(canvas, bier, Rect.fromCircle(center: mitte, radius: r), mitte, r);
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
      final bier = await _bildLaden('assets/bilder/bier_foto.jpg');
      const g = 1024.0;
      await _speichern('assets/logo/bierradar_icon.png', g, (c) => _logo(c, g, bier, mitHintergrund: true, rand: g * 0.03));
      await _speichern('assets/logo/bierradar_vordergrund.png', g, (c) => _logo(c, g, bier, mitHintergrund: false, rand: g * 0.17));
    });
    expect(File('assets/logo/bierradar_icon.png').existsSync(), isTrue);
  });
}
