// Startsequenz: Bier füllt den Bildschirm von unten nach oben, Schaumkrone bildet sich,
// dann erscheint in der Mitte eine wehende schwarze Piratenflagge mit Totenkopf.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../radar.dart';

class Intro extends StatefulWidget {
  const Intro({super.key, required this.fertig});
  final VoidCallback fertig;

  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> with TickerProviderStateMixin {
  // Ablauf (einmalig) und laufende Bewegung (Wellen, Perlen, Flagge)
  late final AnimationController _ablauf =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..addStatusListener((s) {
        if (s == AnimationStatus.completed) _fertig();
      });
  late final AnimationController _bewegung = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  bool _beendet = false;

  @override
  void initState() {
    super.initState();
    _ablauf.forward();
  }

  void _fertig() {
    if (_beendet) return;
    _beendet = true;
    widget.fertig();
  }

  @override
  void dispose() {
    _ablauf.dispose();
    _bewegung.dispose();
    super.dispose();
  }

  double _ab(double t, double von, double bis) => ((t - von) / (bis - von)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: radarHintergrund,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _fertig, // Antippen überspringt
        child: AnimatedBuilder(
          animation: Listenable.merge([_ablauf, _bewegung]),
          builder: (context, _) {
            final t = _ablauf.value;
            final fuellung = Curves.easeInOutCubic.transform(_ab(t, 0.02, 0.55));
            final schaum = Curves.easeOut.transform(_ab(t, 0.45, 0.68));
            final flagge = Curves.easeOutBack.transform(_ab(t, 0.62, 0.82));
            final schrift = Curves.easeOut.transform(_ab(t, 0.75, 0.9));
            final aus = 1 - _ab(t, 0.94, 1.0);
            return Opacity(
              opacity: aus,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _BierMaler(fuellung, schaum, _bewegung.value)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: flagge.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.6 + 0.4 * flagge,
                            child: SizedBox(
                              width: math.min(MediaQuery.sizeOf(context).width * 0.72, 340),
                              height: math.min(MediaQuery.sizeOf(context).width * 0.72, 340) * 0.68,
                              child: CustomPaint(painter: _FlaggenMaler(_bewegung.value)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Opacity(
                          opacity: schrift,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - schrift)),
                            child: const Text(
                              'BierRadar',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: Color(0xFF2A1503),
                                shadows: [Shadow(color: Color(0x66FFFFFF), blurRadius: 12)],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Bier mit realistischem Farbverlauf, schwappender Oberfläche, Perlen und Schaumkrone.
class _BierMaler extends CustomPainter {
  _BierMaler(this.fuellung, this.schaum, this.zeit);
  final double fuellung; // 0 = leer, 1 = voll
  final double schaum; // 0..1 Schaumkrone
  final double zeit; // 0..1 läuft endlos

  static final _perlen = List.generate(70, (i) {
    final z = math.Random(i * 7121);
    return (
      x: z.nextDouble(),
      versatz: z.nextDouble(),
      tempo: 0.4 + z.nextDouble() * 0.9,
      r: 0.8 + z.nextDouble() * 2.6,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (fuellung <= 0) return;

    // Oberfläche: steigt von unten bis knapp über den oberen Rand (Schaum bleibt sichtbar oben)
    final oben = h - fuellung * (h * 0.9); // am Ende bleibt oben Platz für die Schaumkrone
    final welle = (1 - schaum) * 10 + 3;
    final phase = zeit * 2 * math.pi;

    Path oberflaeche(double hub, double verschiebung) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += w / 40) {
        final y =
            oben +
            math.sin(x / w * 2 * math.pi * 1.3 + phase + verschiebung) * hub +
            math.sin(x / w * 2 * math.pi * 2.7 - phase * 1.4) * hub * 0.35;
        p.lineTo(x, y);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    // Bier – Bernstein-Verlauf: unten dunkler, oben heller und goldener
    final bier = oberflaeche(welle, 0);
    canvas.drawPath(
      bier,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF7A3A05), Color(0xFFB8640C), Color(0xFFE39A1F), Color(0xFFF7C04A)],
          stops: [0, 0.35, 0.75, 1],
        ).createShader(Rect.fromLTWH(0, oben, w, h - oben)),
    );

    // Licht von links (Glas-Reflex) und leichte Abdunkelung am Rand
    canvas.save();
    canvas.clipPath(bier);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.08, 0, w * 0.06, h),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Kohlensäure-Perlen steigen auf
    for (final p in _perlen) {
      final f = ((zeit * p.tempo) + p.versatz) % 1.0;
      final y = h - f * (h - oben);
      final x = p.x * w + math.sin((f + p.versatz) * 18) * 4;
      final a = (f < 0.1 ? f * 10 : 1.0) * (1 - f * 0.4);
      canvas.drawCircle(Offset(x, y), p.r, Paint()..color = Colors.white.withValues(alpha: 0.22 * a));
      canvas.drawCircle(
        Offset(x - p.r * 0.3, y - p.r * 0.3),
        p.r * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.5 * a),
      );
    }
    canvas.restore();

    // Schaumkrone: cremig, mit feinen Bläschen
    if (schaum > 0) {
      final dicke = h * 0.07 * schaum;
      final schaumPfad = Path()..moveTo(0, oben + dicke);
      for (var x = 0.0; x <= w; x += w / 40) {
        schaumPfad.lineTo(x, oben - dicke * 0.55 + math.sin(x / w * 2 * math.pi * 3 + phase) * 3);
      }
      schaumPfad
        ..lineTo(w, oben + dicke)
        ..close();
      // weicher Übergang Schaum → Bier
      canvas.drawRect(
        Rect.fromLTWH(0, oben - dicke * 0.2, w, dicke * 1.6),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFFFFF6E0), const Color(0xFFFFF6E0).withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, oben - dicke * 0.2, w, dicke * 1.6)),
      );
      canvas.drawPath(
        schaumPfad,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF7), Color(0xFFF5E6C4)],
          ).createShader(Rect.fromLTWH(0, oben - dicke, w, dicke * 2)),
      );
      final z = math.Random(3);
      for (var i = 0; i < 90; i++) {
        final x = z.nextDouble() * w;
        final y = oben - dicke * 0.4 + z.nextDouble() * dicke * 1.1;
        canvas.drawCircle(
          Offset(x, y),
          0.8 + z.nextDouble() * 2.2,
          Paint()
            ..color = const Color(0xFFE8D3A6).withValues(alpha: 0.55 * schaum)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BierMaler alt) => alt.fuellung != fuellung || alt.schaum != schaum || alt.zeit != zeit;
}

/// Wehende schwarze Piratenflagge mit Totenkopf und gekreuzten Knochen – realistisch schattiert.
class _FlaggenMaler extends CustomPainter {
  _FlaggenMaler(this.zeit);
  final double zeit;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final phase = zeit * 2 * math.pi;

    // Stoff: Ränder wellen sich, Welle wird nach rechts stärker (Fahnenmast links gedacht)
    Offset punkt(double u, double v) {
      final hub = h * 0.05 * u;
      final dx = math.sin(u * 2 * math.pi * 1.1 - phase) * hub * 0.4;
      final dy = math.sin(u * 2 * math.pi * 1.4 - phase) * hub;
      return Offset(u * w + dx, v * h + dy);
    }

    final stoff = Path()..moveTo(punkt(0, 0).dx, punkt(0, 0).dy);
    for (var u = 0.0; u <= 1.0001; u += 0.05) {
      final p = punkt(u, 0);
      stoff.lineTo(p.dx, p.dy);
    }
    for (var u = 1.0; u >= -0.0001; u -= 0.05) {
      final p = punkt(u, 1);
      stoff.lineTo(p.dx, p.dy);
    }
    stoff.close();

    // Schatten unter der Flagge
    canvas.drawPath(
      stoff.shift(const Offset(0, 10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    // Stoff schwarz mit leichtem Glanz
    canvas.drawPath(
      stoff,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2B2E), Color(0xFF0B0B0C), Color(0xFF1C1C1F)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    // Falten: helle und dunkle Bahnen, die mit der Welle wandern
    canvas.save();
    canvas.clipPath(stoff);
    for (var i = 0; i < 5; i++) {
      final x = ((i / 5) + (zeit * 0.25)) % 1.0 * w * 1.2 - w * 0.1;
      canvas.drawRect(
        Rect.fromLTWH(x, -h * 0.2, w * 0.07, h * 1.4),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + w * 0.09, -h * 0.2, w * 0.06, h * 1.4),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Totenkopf und Knochen bewegen sich mit dem Stoff mit
    final mitte = punkt(0.5, 0.47);
    final s = h * 0.36; // Größe
    canvas.translate(mitte.dx, mitte.dy);
    canvas.rotate(math.sin(-phase + math.pi) * 0.03);

    final knochenFarbe = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF4F1EA), Color(0xFFCFC9BC)],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: s * 3, height: s * 3));

    // Gekreuzte Knochen
    for (final winkel in [math.pi / 4.6, -math.pi / 4.6]) {
      canvas.save();
      canvas.rotate(winkel);
      final laenge = s * 2.5;
      final dicke = s * 0.17;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, s * 0.15), width: laenge, height: dicke),
          Radius.circular(dicke / 2),
        ),
        knochenFarbe,
      );
      for (final ende in [-1.0, 1.0]) {
        for (final seite in [-1.0, 1.0]) {
          canvas.drawCircle(
            Offset(ende * laenge / 2, s * 0.15 + seite * dicke * 0.55),
            dicke * 0.62,
            knochenFarbe,
          );
        }
      }
      canvas.restore();
    }

    // Schädel
    final schaedel = Path()
      ..addOval(Rect.fromCenter(center: Offset(0, -s * 0.12), width: s * 1.25, height: s * 1.15))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, s * 0.45), width: s * 0.72, height: s * 0.42),
          Radius.circular(s * 0.12),
        ),
      );
    canvas.drawPath(
      schaedel.shift(Offset(0, s * 0.05)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
    );
    canvas.drawPath(schaedel, knochenFarbe);

    // Augenhöhlen, Nase, Zähne
    final dunkel = Paint()..color = const Color(0xFF111113);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-s * 0.25, -s * 0.05), width: s * 0.36, height: s * 0.32),
      dunkel,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.25, -s * 0.05), width: s * 0.36, height: s * 0.32),
      dunkel,
    );
    final nase = Path()
      ..moveTo(0, s * 0.12)
      ..lineTo(-s * 0.08, s * 0.27)
      ..lineTo(s * 0.08, s * 0.27)
      ..close();
    canvas.drawPath(nase, dunkel);
    final zahn = Paint()
      ..color = const Color(0xFF111113)
      ..strokeWidth = s * 0.035;
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(Offset(i * s * 0.12, s * 0.36), Offset(i * s * 0.12, s * 0.62), zahn);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlaggenMaler alt) => alt.zeit != zeit;
}
