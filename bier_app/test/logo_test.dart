// Erzeugt das App-Symbol (Glas-Radar über Bier) als PNG: flutter test test/logo_test.dart
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
  canvas.saveLayer(null, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: r * 0.08, sigmaY: r * 0.08));
  canvas.drawImageRect(bier, _ausschnitt(bier), bierZiel, Paint()..filterQuality = FilterQuality.high);
  canvas.restore();
  canvas.drawCircle(mitte, r, Paint()..color = Colors.white.withValues(alpha: 0.16));
  canvas.restore();
  canvas.save();
  canvas.translate(mitte.dx - r, mitte.dy - r);
  GlasRadarMaler(0.94, 1).paint(canvas, Size.square(r * 2));
  canvas.restore();
}

/// iPhone / allgemein: Bier füllt das ganze Symbol, Glas-Radar in der Mitte.
void _symbol(Canvas canvas, double g, ui.Image bier) {
  final ziel = Rect.fromLTWH(0, 0, g, g);
  canvas.drawImageRect(bier, _ausschnitt(bier), ziel, Paint()..filterQuality = FilterQuality.high);
  _glasRadar(canvas, bier, ziel, Offset(g / 2, g * 0.54), g * 0.33);
}

/// Android-Vordergrund: transparenter Rand, Bier-Kreis mit Glas-Radar (Hintergrund ist Nachtblau).
void _vordergrund(Canvas canvas, double g, ui.Image bier) {
  final mitte = Offset(g / 2, g / 2);
  final rBier = g * 0.31;
  canvas.drawCircle(
    mitte,
    rBier * 1.08,
    Paint()
      ..color = bierOrange.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rBier * 0.15),
  );
  final ziel = Rect.fromCircle(center: mitte, radius: rBier);
  canvas.save();
  canvas.clipPath(Path()..addOval(ziel));
  canvas.drawImageRect(bier, _ausschnitt(bier), ziel, Paint()..filterQuality = FilterQuality.high);
  canvas.restore();
  _glasRadar(canvas, bier, ziel, mitte.translate(0, rBier * 0.08), rBier * 0.74);
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
      await _speichern('assets/logo/bierradar_icon.png', g, (c) => _symbol(c, g, bier));
      await _speichern('assets/logo/bierradar_vordergrund.png', g, (c) => _vordergrund(c, g, bier));
    });
    expect(File('assets/logo/bierradar_icon.png').existsSync(), isTrue);
  });
}
