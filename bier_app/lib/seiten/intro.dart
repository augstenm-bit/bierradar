// Startsequenz: Echtes Bier steigt von unten nach oben, Perlen steigen auf, die Schaumkrone erscheint.
// Dann taucht in der Mitte das Radar auf (grüner Ring, innen Bier mit Glas-Radar) – mattes Glas, weißer Lichtkegel, ein Fund leuchtet auf.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../radar.dart';

const _bierFoto = AssetImage('assets/bilder/bier_foto.jpg');
const _dunkelbraun = Color(0xFF2A1503);

class Intro extends StatefulWidget {
  const Intro({super.key, required this.fertig});
  final VoidCallback fertig;

  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> with TickerProviderStateMixin {
  // Ablauf (einmalig), Bewegung (Wellen, Perlen) und Radar-Zeiger (dreht sich)
  late final AnimationController _ablauf =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))..addStatusListener((s) {
        if (s == AnimationStatus.completed) _fertig();
      });
  late final AnimationController _bewegung = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  late final AnimationController _zeiger = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  bool _beendet = false;
  bool _gestartet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_gestartet) return;
    _gestartet = true;
    // Foto vorladen, damit es beim Aufsteigen sofort da ist
    precacheImage(_bierFoto, context).whenComplete(() {
      if (mounted) _ablauf.forward();
    });
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
    _zeiger.dispose();
    super.dispose();
  }

  double _ab(double t, double von, double bis) => ((t - von) / (bis - von)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final groesse = MediaQuery.sizeOf(context);
    final radarD = math.min(groesse.width * 0.8, 360.0);
    return Scaffold(
      backgroundColor: radarHintergrund,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _fertig, // Antippen überspringt
        child: AnimatedBuilder(
          animation: Listenable.merge([_ablauf, _bewegung, _zeiger]),
          builder: (context, _) {
            final t = _ablauf.value;
            final fuellung = Curves.easeInOutCubic.transform(_ab(t, 0.02, 0.46));
            final radar = Curves.easeOutBack.transform(_ab(t, 0.44, 0.58));
            final schrift = Curves.easeOut.transform(_ab(t, 0.52, 0.66));
            final fund = _ab(t, 0.64, 0.72);
            final aus = 1 - _ab(t, 0.94, 1.0);
            return Opacity(
              opacity: aus,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Bierfoto, sichtbar nur bis zur aufsteigenden Oberfläche
                  ClipPath(
                    clipper: _Fuellstand(fuellung, _bewegung.value),
                    child: const Image(image: _bierFoto, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                  // Perlen und heller Schaumrand an der Oberfläche
                  IgnorePointer(child: CustomPaint(painter: _PerlenMaler(fuellung, _bewegung.value))),
                  // Schrift oben in der Schaumkrone
                  Positioned(
                    left: 0,
                    right: 0,
                    top: groesse.height * 0.1,
                    child: Opacity(
                      opacity: schrift,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - schrift)),
                        child: const Column(
                          children: [
                            Text(
                              'BierRadar',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: _dunkelbraun,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Suche Bier-Aktionen in deiner Nähe …',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xCC2A1503)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Glas-Radar in der Mitte des Biers
                  Positioned(
                    left: (groesse.width - radarD) / 2,
                    top: groesse.height * 0.56 - radarD / 2,
                    width: radarD,
                    height: radarD,
                    child: Opacity(
                      opacity: radar.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * radar,
                        child: RadarAbzeichen(zeiger: _zeiger.value, fund: fund),
                      ),
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

/// Wellige Bier-Oberfläche, die von unten bis über den oberen Rand steigt.
class _Fuellstand extends CustomClipper<Path> {
  _Fuellstand(this.fuellung, this.zeit);
  final double fuellung;
  final double zeit;

  @override
  Path getClip(Size size) => oberflaechePfad(size, fuellung, zeit);

  @override
  bool shouldReclip(_Fuellstand alt) => alt.fuellung != fuellung || alt.zeit != zeit;
}

double _oben(Size size, double fuellung) => size.height + 30 - fuellung * (size.height + 60);

double _wellenY(Size size, double fuellung, double zeit, double x) {
  final phase = zeit * 2 * math.pi;
  final hub = 4 + 10 * (1 - fuellung);
  return _oben(size, fuellung) +
      math.sin(x / size.width * 2 * math.pi * 1.3 + phase) * hub +
      math.sin(x / size.width * 2 * math.pi * 2.7 - phase * 1.4) * hub * 0.35;
}

Path oberflaechePfad(Size size, double fuellung, double zeit) {
  final p = Path()..moveTo(0, size.height);
  for (var x = 0.0; x <= size.width + 0.1; x += size.width / 40) {
    p.lineTo(x, _wellenY(size, fuellung, zeit, x));
  }
  return p
    ..lineTo(size.width, size.height)
    ..close();
}

/// Aufsteigende Kohlensäure-Perlen und ein heller Schaumrand an der steigenden Oberfläche.
class _PerlenMaler extends CustomPainter {
  _PerlenMaler(this.fuellung, this.zeit);
  final double fuellung;
  final double zeit;

  static final _perlen = List.generate(45, (i) {
    final z = math.Random(i * 7121);
    return (x: z.nextDouble(), versatz: z.nextDouble(), tempo: 0.5 + z.nextDouble() * 0.9, r: 0.8 + z.nextDouble() * 2.2);
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fuellung <= 0) return;
    final w = size.width;
    final h = size.height;
    final oben = _oben(size, fuellung);

    canvas.save();
    canvas.clipPath(oberflaechePfad(size, fuellung, zeit));
    for (final p in _perlen) {
      final f = ((zeit * p.tempo) + p.versatz) % 1.0;
      final y = h - f * (h - math.max(oben, 0));
      final x = p.x * w + math.sin((f + p.versatz) * 18) * 4;
      final a = (f < 0.1 ? f * 10 : 1.0) * (1 - f * 0.5);
      canvas.drawCircle(Offset(x, y), p.r, Paint()..color = Colors.white.withValues(alpha: 0.18 * a));
      canvas.drawCircle(
        Offset(x - p.r * 0.3, y - p.r * 0.3),
        p.r * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.45 * a),
      );
    }
    canvas.restore();

    // Schaumrand an der Oberfläche, solange das Bier noch steigt
    if (oben > -20) {
      final rand = Path();
      for (var x = 0.0; x <= w + 0.1; x += w / 40) {
        final y = _wellenY(size, fuellung, zeit, x);
        x == 0 ? rand.moveTo(x, y) : rand.lineTo(x, y);
      }
      canvas.drawPath(
        rand,
        Paint()
          ..color = const Color(0xFFFFF8E8).withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        rand,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PerlenMaler alt) => alt.fuellung != fuellung || alt.zeit != zeit;
}

/// Wie auf der Willkommen-Seite: grünes Radar außen, innen Bier mit Glas-Radar.
/// Beide Zeiger drehen gemeinsam. [zeiger] 0..1 = eine Umdrehung.
class RadarAbzeichen extends StatelessWidget {
  const RadarAbzeichen({super.key, required this.zeiger, this.fund = 1});
  final double zeiger;
  final double fund;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final g = box.biggest.shortestSide;
      final grad = zeiger * 360;
      return Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(g),
            painter: RadarMaler(
              zeigerGrad: grad,
              blipHelligkeit: [
                for (final b in blips) (1 - (((grad - b.winkelGrad) % 360 + 360) % 360) / 220).clamp(0.0, 1.0),
              ],
            ),
          ),
          Container(
            width: g * 0.78,
            height: g * 0.78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: bierOrange.withValues(alpha: 0.5), blurRadius: 30)],
            ),
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/bilder/bier_foto.jpg', fit: BoxFit.cover, alignment: const Alignment(0, 0.2)),
                  GlasRadar(zeiger: zeiger, fund: fund),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Modernes Glas-Radar: mattes Glas, feine weiße Ringe, drehender Lichtkegel, ein aufleuchtender Fund.
/// [zeiger] 0..1 = eine Umdrehung, [fund] 0..1 = wie weit der Fund schon aufgeleuchtet ist.
class GlasRadar extends StatelessWidget {
  const GlasRadar({super.key, required this.zeiger, this.fund = 1});
  final double zeiger;
  final double fund;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // weicher Schatten unter dem Glas
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 30, offset: const Offset(0, 12))],
          ),
        ),
        ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
        CustomPaint(painter: GlasRadarMaler(zeiger, fund)),
      ],
    );
  }
}

class GlasRadarMaler extends CustomPainter {
  GlasRadarMaler(this.zeiger, this.fund);
  final double zeiger;
  final double fund;

  // Position des Funds (Winkel im Uhrzeigersinn ab „rechts“, Abstand zur Mitte)
  static const _fundWinkel = -0.75;
  static const _fundAbstand = 0.58;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final m = size.center(Offset.zero);
    final weiss = Colors.white;

    // Glasrand mit Lichtkante oben links
    canvas.drawCircle(
      m,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = weiss.withValues(alpha: 0.65),
    );
    canvas.drawArc(
      Rect.fromCircle(center: m, radius: r - 3),
      math.pi * 1.05,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = weiss.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Ringe und Fadenkreuz
    final linie = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (f, a) in [(0.33, 0.30), (0.66, 0.38)]) {
      canvas.drawCircle(m, r * f, linie..color = weiss.withValues(alpha: a));
    }
    linie.color = weiss.withValues(alpha: 0.2);
    canvas.drawLine(Offset(m.dx - r * 0.9, m.dy), Offset(m.dx + r * 0.9, m.dy), linie);
    canvas.drawLine(Offset(m.dx, m.dy - r * 0.9), Offset(m.dx, m.dy + r * 0.9), linie);

    // Gradskala am Rand
    for (var g = 0; g < 360; g += 10) {
      final w = g * math.pi / 180;
      final lang = g % 30 == 0;
      final innen = r * (lang ? 0.86 : 0.9);
      final aussen = r * 0.95;
      canvas.drawLine(
        m + Offset(math.cos(w), math.sin(w)) * innen,
        m + Offset(math.cos(w), math.sin(w)) * aussen,
        Paint()
          ..strokeWidth = lang ? 1.4 : 0.8
          ..color = weiss.withValues(alpha: lang ? 0.6 : 0.32),
      );
    }

    // Lichtkegel (dreht sich)
    final winkel = zeiger * 2 * math.pi;
    const breite = math.pi / 2.6;
    canvas.save();
    canvas.translate(m.dx, m.dy);
    canvas.rotate(winkel);
    final kegel = Rect.fromCircle(center: Offset.zero, radius: r * 0.95);
    // Verlauf: hinten durchsichtig, an der Zeigerkante hell
    canvas.save();
    canvas.rotate(-breite);
    canvas.drawArc(
      kegel,
      0,
      breite,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: breite,
          colors: [weiss.withValues(alpha: 0), weiss.withValues(alpha: 0.5)],
        ).createShader(kegel),
    );
    canvas.restore();
    canvas.drawLine(
      Offset.zero,
      Offset(r * 0.95, 0),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = weiss.withValues(alpha: 0.95),
    );
    canvas.restore();

    // Fund: leuchtet hell auf, wenn der Lichtkegel darüber streicht, und glimmt dann nach
    if (fund > 0) {
      final p = m + Offset(math.cos(_fundWinkel), math.sin(_fundWinkel)) * r * _fundAbstand;
      var seit = (winkel - _fundWinkel) % (2 * math.pi); // wie lange der Zeiger schon vorbei ist
      if (seit < 0) seit += 2 * math.pi;
      final nachleuchten = 1 - seit / (2 * math.pi);
      final hell = fund * (0.45 + 0.55 * nachleuchten);
      canvas.drawCircle(
        p,
        r * 0.12,
        Paint()
          ..color = weiss.withValues(alpha: 0.5 * hell)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.07),
      );
      canvas.drawCircle(p, r * 0.045, Paint()..color = weiss.withValues(alpha: 0.4 + 0.6 * hell));
      // Ping-Ring breitet sich aus
      final ping = seit / (2 * math.pi);
      canvas.drawCircle(
        p,
        r * (0.05 + 0.22 * ping),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = weiss.withValues(alpha: fund * 0.8 * (1 - ping)),
      );
    }

    // Mittelpunkt
    canvas.drawCircle(
      m,
      r * 0.06,
      Paint()
        ..color = weiss.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );
    canvas.drawCircle(m, r * 0.03, Paint()..color = weiss);
  }

  @override
  bool shouldRepaint(GlasRadarMaler alt) => alt.zeiger != zeiger || alt.fund != fund;
}
