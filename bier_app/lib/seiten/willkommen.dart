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
                builder: (_, _) => CustomPaint(painter: BierRegenMaler(_konfetti.value)),
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
                    dimension: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const LiveRadar(groesse: 240, dauer: Duration(milliseconds: 2600)),
                        AnimatedBuilder(
                          animation: _welle,
                          builder: (_, _) => Container(
                            width: 150 + 90 * _welle.value,
                            height: 150 + 90 * _welle.value,
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
                          child: AnimatedBuilder(
                            animation: _welle,
                            // Leichtes Schaukeln – der Pirat hat schon ein paar Bier intus
                            builder: (_, c) => Transform.rotate(
                              angle: math.sin(_welle.value * 2 * math.pi) * 0.05,
                              child: c,
                            ),
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: bierGoldHell, width: 3),
                                boxShadow: [
                                  BoxShadow(color: bierOrange.withValues(alpha: 0.6), blurRadius: 30),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset('assets/bilder/pirat.png', fit: BoxFit.cover),
                              ),
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
                      'MICHAEL HAT DICH EINGELADEN',
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
                  if (bis != null)
                    _rein(
                      0.5,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: bierBernstein.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: bierBernstein.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_top, size: 15, color: bierGoldHell),
                            const SizedBox(width: 5),
                            Text(
                              'Noch ${bis.difference(DateTime.now()).inDays.clamp(0, betaTage)} Tage gratis testen',
                              style: const TextStyle(
                                color: bierGoldHell,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  _rein(
                    0.5,
                    Text(
                      bis == null
                          ? 'Willkommen in der Crew! Du bist einer der ersten Beta-Tester von BierRadar. '
                                'Ab jetzt entgeht dir keine Bier-Aktion mehr.'
                          : 'Willkommen in der Crew! Du bist einer der ersten Beta-Tester von BierRadar '
                                'und testest die App $betaTage Tage lang gratis. Ab jetzt entgeht dir keine Bier-Aktion mehr.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB8C4D9), fontSize: 15, height: 1.5),
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
                                : 'Die Zeit läuft: Deine Beta gilt $betaTage Tage, also bis ${_datum(bis)}. '
                                      'Danach schickt dir Michael die neue Version.',
                          ),
                          if (Theme.of(context).platform == TargetPlatform.android)
                            const _Regel(
                              Icons.notifications_active_outlined,
                              'Gleich kommt die Frage nach Benachrichtigungen – bitte „Zulassen“! '
                              'Wenn du ablehnst, bekommst du keine Meldungen über Bier-Aktionen, '
                              'und genau dafür ist BierRadar da.',
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

class BierRegenMaler extends CustomPainter {
  BierRegenMaler(this.t);
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
  bool shouldRepaint(BierRegenMaler alt) => alt.t != t;
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
            ],
          ),
        ),
      ),
    );
  }
}
