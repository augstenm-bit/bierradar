// Erzeugt das App-Symbol als PNG: flutter test test/logo_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bier_app/radar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _speichern(RadarMaler maler, String pfad, {double groesse = 1024}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  maler.paint(canvas, Size.square(groesse));
  final bild = await recorder.endRecording().toImage(groesse.toInt(), groesse.toInt());
  final daten = await bild.toByteData(format: ui.ImageByteFormat.png);
  File(pfad).writeAsBytesSync(daten!.buffer.asUint8List());
}

void main() {
  test('Logo als PNG speichern', () async {
    await _speichern(
      RadarMaler(
        zeigerGrad: bierWinkelGrad + 6,
        bierSkala: 1.5,
        blipHelligkeit: const [0.5, 0.3, 0.6, 0.25, 0.4],
        fuerLogo: true,
      ),
      'assets/logo/bierradar_icon.png',
    );
    expect(File('assets/logo/bierradar_icon.png').existsSync(), isTrue);

    // Vordergrund für Android (transparent, mit Rand für die runde/eckige Maske)
    const g = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(g * 0.17, g * 0.17);
    RadarMaler(
      zeigerGrad: bierWinkelGrad + 6,
      bierSkala: 1.5,
      blipHelligkeit: const [0.5, 0.3, 0.6, 0.25, 0.4],
    ).paint(canvas, const Size.square(g * 0.66));
    final bild = await recorder.endRecording().toImage(g.toInt(), g.toInt());
    final daten = await bild.toByteData(format: ui.ImageByteFormat.png);
    File('assets/logo/bierradar_vordergrund.png').writeAsBytesSync(daten!.buffer.asUint8List());
  });
}
