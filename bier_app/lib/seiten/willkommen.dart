// Willkommen für Beta-Tester („Ahoi, Bierpirat!“) und Sperrbildschirm nach Ablauf.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../beta.dart';
import '../radar.dart';

String _datum(DateTime d) {
  const monate = [
    'Jänner',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  return '${d.day}. ${monate[d.month - 1]}';
}

class Willkommen extends StatefulWidget {
  const Willkommen({super.key, required this.beta});
  final BetaPruefung beta;

  @override
  State<Willkommen> createState() => _WillkommenState();
}

class _WillkommenState extends State<Willkommen> with TickerProviderStateMixin {
  late final AnimationController _auftritt = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();
  late final AnimationController _konfetti = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();
  late final AnimationController _welle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _auftritt.dispose();
    _konfetti.dispose();
    _welle.dispose();
    super.dispose();
  }

  Animation<double> _ab(double von, double bis, [Curve kurve = Curves.easeOutCubic]) => CurvedAnimation(
    parent: _auftritt,
    curve: Interval(von, bis, curve: kurve),
  );

  Widget _rein(double von, Widget kind) {
    final a = _ab(von, (von + 0.25).clamp(0, 1));
    return AnimatedBuilder(
      animation: a,
      builder: (_, c) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, 18 * (1 - a.value)), child: c),
      ),
      child: kind,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.beta;
    final bis = b.gueltigBis;
    final abzeichen = _ab(0.1, 0.55, Curves.elasticOut);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _konfetti,
                builder: (_, _) => CustomPaint(painter: _KonfettiMaler(_konfetti.value)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const Spacer(),
                  SizedBox.square(
                    dimension: 210,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const LiveRadar(groesse: 210, dauer: Duration(milliseconds: 2600)),
                        AnimatedBuilder(
                          animation: _welle,
                          builder: (_, _) => Container(
                            width: 104 + 100 * _welle.value,
                            height: 104 + 100 * _welle.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: bierBernstein.withValues(alpha: 0.8 * (1 - _welle.value)),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: abzeichen,
                          builder: (_, c) => Transform.rotate(
                            angle: -0.7 * (1 - abzeichen.value),
                            child: Transform.scale(scale: abzeichen.value, child: c),
                          ),
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [bierGoldHell, bierOrange],
                              ),
                              boxShadow: [
                                BoxShadow(color: bierOrange.withValues(alpha: 0.7), blurRadius: 30),
                              ],
                            ),
                            child: AnimatedBuilder(
                              animation: _welle,
                              builder: (_, _) => CustomPaint(painter: _PiratMaler(_welle.value)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _rein(
                    0.35,
                    const Text(
                      'NEUES CREW-MITGLIED GEORTET',
                      style: TextStyle(
                        color: radarGruen,
                        letterSpacing: 2,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _rein(
                    0.42,
                    ShaderMask(
                      shaderCallback: (r) =>
                          const LinearGradient(colors: [radarMintHell, bierGoldHell]).createShader(r),
                      child: const Text(
                        'Ahoi, Pirat!',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                  _rein(0.48, const _Arrr()),
                  const SizedBox(height: 6),
                  _rein(
                    0.5,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: bierBernstein.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Crew-Mitglied Nr. ${b.testerNummer}',
                        style: const TextStyle(
                          color: bierGoldHell,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _rein(
                    0.5,
                    const Text(
                      'Herzlichen Glückwunsch – du bist einer der ersten Beta-Tester von Bierradar. '
                      'Ab jetzt entgeht dir keine Bier-Aktion mehr.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFB8C4D9), fontSize: 15, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _rein(
                    0.6,
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: karteFarbe,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        children: [
                          _Regel(
                            Icons.hourglass_bottom,
                            bis == null
                                ? 'Das ist eine Test-Version direkt von Michael.'
                                : 'Deine Beta-Version gilt bis ${_datum(bis)}. Danach gibt’s die neue Version von Michael.',
                          ),
                          const _Regel(
                            Icons.lock_outline,
                            'Piratenehrenwort: Die App bleibt in der Crew – bitte nicht weiterschicken.',
                          ),
                          const _Regel(
                            Icons.chat_bubble_outline,
                            'Fehler oder Ideen? Sag’s Michael – du machst die App besser.',
                            letzte: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _rein(
                    0.75,
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: b.willkommenBestaetigen,
                        icon: const Icon(Icons.anchor),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Anheuern und Bier finden', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// „Arrrrr!“ – wackelt kurz wie ein echter Piratenruf.
class _Arrr extends StatefulWidget {
  const _Arrr();

  @override
  State<_Arrr> createState() => _ArrrState();
}

class _ArrrState extends State<_Arrr> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, c) {
      // kurzes Wackeln am Anfang jeder Runde, dann Ruhe
      final w = _c.value < 0.25 ? math.sin(_c.value * 4 * math.pi * 4) * (0.25 - _c.value) * 0.5 : 0.0;
      return Transform.rotate(
        angle: w,
        child: Transform.scale(scale: 1 + w.abs() * 0.6, child: c),
      );
    },
    child: const Text(
      'Arrrrr! 🏴‍☠️',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: bierGoldHell, letterSpacing: 2),
    ),
  );
}

/// Beschwipster Pirat mit Augenklappe, Hut, roten Bäckchen und einer Bierkiste in der Hand.
class _PiratMaler extends CustomPainter {
  _PiratMaler(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const haut = Color(0xFFFFD2A6);
    const dunkel = Color(0xFF1E1410);
    const rot = Color(0xFFE5484D);

    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));

    // Leichtes Schwanken (beschwipst)
    final schwank = math.sin(t * 2 * math.pi) * 0.09;
    canvas.translate(w * 0.5, h * 0.95);
    canvas.rotate(schwank);
    canvas.translate(-w * 0.5, -h * 0.95);

    // Körper / Hemd (rot-weiß gestreift)
    final koerper = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.24, h * 0.72, w * 0.52, h * 0.4),
      topLeft: Radius.circular(w * 0.2),
      topRight: Radius.circular(w * 0.2),
    );
    canvas.drawRRect(koerper, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(koerper);
    for (var y = 0.74; y < 1.1; y += 0.07) {
      canvas.drawRect(Rect.fromLTWH(0, h * y, w, h * 0.032), Paint()..color = rot);
    }
    canvas.restore();

    // Arm hoch zur Bierkiste (rechts)
    final kisteWackel = math.sin(t * 2 * math.pi + 0.8) * h * 0.012;
    canvas.drawLine(
      Offset(w * 0.68, h * 0.8),
      Offset(w * 0.8, h * 0.6 + kisteWackel),
      Paint()
        ..color = haut
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round,
    );
    // Bierkiste
    final kiste = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.66, h * 0.43 + kisteWackel, w * 0.28, h * 0.17),
      Radius.circular(w * 0.025),
    );
    canvas.drawRRect(kiste, Paint()..color = const Color(0xFF5C3A1A));
    canvas.drawRRect(
      kiste,
      Paint()
        ..color = dunkel
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014,
    );
    // Flaschen in der Kiste
    for (var i = 0; i < 4; i++) {
      final x = w * (0.69 + i * 0.065);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, h * 0.36 + kisteWackel, w * 0.04, h * 0.09),
          Radius.circular(w * 0.012),
        ),
        Paint()..color = const Color(0xFF2F6B2F),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + w * 0.008, h * 0.345 + kisteWackel, w * 0.024, h * 0.02),
        Paint()..color = bierGoldHell,
      );
    }
    // Hand an der Kiste
    canvas.drawCircle(Offset(w * 0.8, h * 0.6 + kisteWackel), w * 0.05, Paint()..color = haut);

    // Kopf
    final kopf = Offset(w * 0.44, h * 0.5);
    final r = w * 0.2;
    canvas.drawCircle(kopf, r, Paint()..color = haut);

    // Bart
    final bart = Path()
      ..moveTo(kopf.dx - r * 0.85, kopf.dy + r * 0.15)
      ..quadraticBezierTo(kopf.dx, kopf.dy + r * 1.55, kopf.dx + r * 0.85, kopf.dy + r * 0.15)
      ..quadraticBezierTo(kopf.dx, kopf.dy + r * 0.75, kopf.dx - r * 0.85, kopf.dy + r * 0.15)
      ..close();
    canvas.drawPath(bart, Paint()..color = const Color(0xFF8A4B1F));

    // Rote Bäckchen
    final backe = Paint()
      ..color = rot.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08);
    canvas.drawCircle(kopf.translate(-r * 0.55, r * 0.22), r * 0.2, backe);
    canvas.drawCircle(kopf.translate(r * 0.55, r * 0.22), r * 0.2, backe);

    // Grinsen
    canvas.drawArc(
      Rect.fromCenter(center: kopf.translate(0, r * 0.32), width: r * 0.8, height: r * 0.5),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..color = dunkel
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..strokeCap = StrokeCap.round,
    );

    // Nase (rötlich)
    canvas.drawCircle(kopf.translate(0, r * 0.08), r * 0.13, Paint()..color = const Color(0xFFF2A07B));

    // Rechtes Auge: zugekniffen, glücklich beschwipst
    canvas.drawArc(
      Rect.fromCenter(center: kopf.translate(r * 0.38, -r * 0.18), width: r * 0.36, height: r * 0.26),
      math.pi + 0.3,
      math.pi - 0.6,
      false,
      Paint()
        ..color = dunkel
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round,
    );

    // Augenklappe links mit Band
    canvas.drawLine(
      kopf.translate(-r * 0.95, -r * 0.55),
      kopf.translate(r * 0.95, -r * 0.05),
      Paint()
        ..color = dunkel
        ..strokeWidth = r * 0.07,
    );
    canvas.drawOval(
      Rect.fromCenter(center: kopf.translate(-r * 0.36, -r * 0.18), width: r * 0.48, height: r * 0.4),
      Paint()..color = dunkel,
    );

    // Piratenhut (Dreispitz) mit Totenkopf
    final hut = Path()
      ..moveTo(kopf.dx - r * 1.35, kopf.dy - r * 0.55)
      ..quadraticBezierTo(kopf.dx - r * 0.7, kopf.dy - r * 0.75, kopf.dx - r * 0.55, kopf.dy - r * 1.35)
      ..quadraticBezierTo(kopf.dx, kopf.dy - r * 1.75, kopf.dx + r * 0.55, kopf.dy - r * 1.35)
      ..quadraticBezierTo(kopf.dx + r * 0.7, kopf.dy - r * 0.75, kopf.dx + r * 1.35, kopf.dy - r * 0.55)
      ..quadraticBezierTo(kopf.dx, kopf.dy - r * 0.95, kopf.dx - r * 1.35, kopf.dy - r * 0.55)
      ..close();
    canvas.drawPath(hut, Paint()..color = dunkel);
    canvas.drawCircle(kopf.translate(0, -r * 1.12), r * 0.17, Paint()..color = Colors.white);
    canvas.drawLine(
      kopf.translate(-r * 0.2, -r * 0.88),
      kopf.translate(r * 0.2, -r * 0.88),
      Paint()
        ..color = Colors.white
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PiratMaler alt) => alt.t != t;
}

class _Regel extends StatelessWidget {
  const _Regel(this.icon, this.text, {this.letzte = false});
  final IconData icon;
  final String text;
  final bool letzte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: letzte ? 0 : 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: bierBernstein, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: Color(0xFFB8C4D9), height: 1.4, fontSize: 14)),
        ),
      ],
    ),
  );
}

class _KonfettiMaler extends CustomPainter {
  _KonfettiMaler(this.t);
  final double t;

  // Fallende Teile: Bierkrüge und ein bisschen Konfetti
  static final _teile = List.generate(20, (i) {
    final z = math.Random(i * 7919);
    return (
      x: z.nextDouble(),
      versatz: z.nextDouble(),
      tempo: 0.6 + z.nextDouble() * 0.6,
      art: i % 2, // 0 = Bier, 1 = Konfetti
      farbe: i % 3,
      dreh: z.nextDouble() * 6,
      groesse: 18 + z.nextDouble() * 12,
    );
  });

  // Aufsteigende Schaumbläschen
  static final _blasen = List.generate(22, (i) {
    final z = math.Random(i * 104729);
    return (
      x: z.nextDouble(),
      versatz: z.nextDouble(),
      tempo: 0.5 + z.nextDouble() * 0.7,
      r: 3 + z.nextDouble() * 8,
    );
  });

  static final Map<int, TextPainter> _bier = {};

  TextPainter _bierFuer(double g) => _bier.putIfAbsent(g.round(), () {
    return TextPainter(
      text: TextSpan(
        text: '🍺',
        style: TextStyle(fontSize: g),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  });

  @override
  void paint(Canvas canvas, Size size) {
    const farben = [radarGruen, bierBernstein, spezialLila];

    // Schaum steigt von unten auf
    for (final b in _blasen) {
      final f = ((t * b.tempo) + b.versatz) % 1.0;
      final y = size.height + 20 - f * (size.height * 0.75);
      final x = b.x * size.width + math.sin((f + b.versatz) * 14) * 10;
      final alpha = (f < 0.15 ? f / 0.15 : (1 - f)).clamp(0.0, 1.0);
      final mitte = Offset(x, y);
      canvas.drawCircle(mitte, b.r, Paint()..color = Colors.white.withValues(alpha: 0.10 * alpha));
      canvas.drawCircle(
        mitte,
        b.r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
        mitte.translate(-b.r * 0.35, -b.r * 0.35),
        b.r * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.6 * alpha),
      );
    }

    // Bier und Konfetti fallen von oben
    for (final k in _teile) {
      final f = ((t * k.tempo) + k.versatz) % 1.0;
      final y = -30 + f * (size.height + 60);
      final x = k.x * size.width + math.sin((f + k.versatz) * 10) * 16;
      final alpha = (f < 0.1 ? f * 10 : (f > 0.85 ? (1 - f) / 0.15 : 1.0)).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      if (k.art == 0) {
        canvas.rotate(math.sin((f + k.dreh) * 6) * 0.45); // Krug schaukelt beim Fallen
        final tp = _bierFuer(k.groesse);
        canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 0.75 * alpha));
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      } else {
        canvas.rotate(k.dreh + f * 9);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-3.5, -5.5, 7, 11), const Radius.circular(2)),
          Paint()..color = farben[k.farbe].withValues(alpha: 0.85 * alpha),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_KonfettiMaler alt) => alt.t != t;
}

/// Sperrbildschirm, wenn die Beta abgelaufen oder gesperrt ist.
class BetaGesperrt extends StatelessWidget {
  const BetaGesperrt({super.key, required this.beta});
  final BetaPruefung beta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 200,
                child: CustomPaint(painter: RadarMaler(zeigerGrad: -130, bierSkala: 1, grau: true)),
              ),
              const SizedBox(height: 28),
              const Text(
                'Leinen los, Bierpirat!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: textHell),
              ),
              const SizedBox(height: 12),
              Text(
                '${beta.sperrGrund}\nFrag Michael nach der neuen Version – dann geht die Bierjagd weiter.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB8C4D9), fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                'Bierpirat #${beta.testerNummer.toString().padLeft(3, '0')}',
                style: const TextStyle(color: textGedaempft, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
