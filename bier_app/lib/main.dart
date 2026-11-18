import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'beta.dart';
import 'push.dart';
import 'radar.dart';
import 'seiten/einrichtung.dart';
import 'seiten/hauptseite.dart';
import 'seiten/intro.dart';
import 'seiten/willkommen.dart';
import 'zustand.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Nur Hochformat – quer sieht man ohnehin nichts.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final zustand = AppZustand()..laden();
  pushStarten(zustand);
  final beta = BetaPruefung()..pruefen();
  runApp(BierApp(zustand: zustand, beta: beta));
}

/// Gibt den App-Zustand an alle Seiten weiter.
class ZustandScope extends InheritedNotifier<AppZustand> {
  const ZustandScope({super.key, required AppZustand zustand, required super.child})
    : super(notifier: zustand);

  static AppZustand of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZustandScope>()!.notifier!;
}

const _flaeche = Color(0xFF0E1320);

/// Moderner Radar-Look: Nachtblau, Mint, Bier-Orange.
ThemeData radarDesign() {
  const farben = ColorScheme.dark(
    primary: radarGruen,
    onPrimary: Color(0xFF00271A),
    secondary: bierBernstein,
    onSecondary: Color(0xFF3A1C00),
    surface: _flaeche,
    onSurface: textHell,
    onSurfaceVariant: textGedaempft,
    surfaceContainerHighest: Color(0xFF1B2438),
    secondaryContainer: Color(0xFF16233A),
    onSecondaryContainer: textHell,
    tertiaryContainer: Color(0xFF3A2A12),
    onTertiaryContainer: Color(0xFFFFDFA0),
    error: Color(0xFFFF7A8A),
    outline: Color(0xFF56617A),
    outlineVariant: Color(0xFF232C40),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: farben,
    scaffoldBackgroundColor: radarHintergrund,
    appBarTheme: const AppBarTheme(
      backgroundColor: radarHintergrund,
      foregroundColor: textHell,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: textHell),
    ),
    cardTheme: CardThemeData(
      color: karteFarbe,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _flaeche,
      indicatorColor: radarGruen.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? radarGruen : const Color(0xFF6C7790)),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          color: s.contains(WidgetState.selected) ? radarGruen : const Color(0xFF6C7790),
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: radarGruen,
        foregroundColor: const Color(0xFF00271A),
        disabledBackgroundColor: const Color(0xFF1B2438),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: karteFarbe,
      selectedColor: radarGruen.withValues(alpha: 0.2),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      checkmarkColor: radarGruen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: karteFarbe,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF1B2438)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: radarGruen, linearTrackColor: Color(0xFF1B2438)),
  );
}

class BierApp extends StatelessWidget {
  const BierApp({super.key, required this.zustand, required this.beta});
  final AppZustand zustand;
  final BetaPruefung beta;

  @override
  Widget build(BuildContext context) {
    return ZustandScope(
      zustand: zustand,
      child: MaterialApp(
        title: 'BierRadar',
        debugShowCheckedModeBanner: false,
        theme: radarDesign(),
        home: _Start(beta: beta),
      ),
    );
  }
}

class _Start extends StatefulWidget {
  const _Start({required this.beta});
  final BetaPruefung beta;

  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  bool _introVorbei = false;

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    return ListenableBuilder(
      listenable: widget.beta,
      builder: (context, _) {
        final b = widget.beta;
        final Widget inhalt;
        if (!_introVorbei || !z.geladen || !b.geprueft) {
          inhalt = Intro(key: const ValueKey('intro'), fertig: () => setState(() => _introVorbei = true));
        } else if (b.gesperrt) {
          inhalt = BetaGesperrt(key: const ValueKey('gesperrt'), beta: b);
        } else if (!b.willkommenGesehen) {
          inhalt = Willkommen(key: const ValueKey('willkommen'), beta: b);
        } else {
          inhalt = z.einrichtungFertig
              ? const Hauptseite(key: ValueKey('haupt'))
              : const Einrichtung(key: ValueKey('einrichtung'));
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 500), child: inhalt);
      },
    );
  }
}
