import 'package:flutter/material.dart';

import 'radar.dart';
import 'seiten/einrichtung.dart';
import 'seiten/hauptseite.dart';
import 'seiten/intro.dart';
import 'zustand.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final zustand = AppZustand()..laden();
  runApp(BierApp(zustand: zustand));
}

/// Gibt den App-Zustand an alle Seiten weiter.
class ZustandScope extends InheritedNotifier<AppZustand> {
  const ZustandScope({super.key, required AppZustand zustand, required super.child})
    : super(notifier: zustand);

  static AppZustand of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZustandScope>()!.notifier!;
}

const _karte = Color(0xFF0F2A1C);
const _flaeche = Color(0xFF0B1F14);

/// Radar-Look: dunkler Schirm, leuchtendes Radar-Grün, Bier-Bernstein.
ThemeData radarDesign() {
  final farben = const ColorScheme.dark(
    primary: radarGruen,
    onPrimary: Color(0xFF00210F),
    secondary: bierBernstein,
    onSecondary: Color(0xFF2A1A00),
    surface: _flaeche,
    onSurface: Color(0xFFE8F5EC),
    onSurfaceVariant: Color(0xFF9CC3AC),
    surfaceContainerHighest: Color(0xFF16382A),
    secondaryContainer: Color(0xFF173B29),
    onSecondaryContainer: Color(0xFFE8F5EC),
    tertiaryContainer: Color(0xFF3B2A06),
    onTertiaryContainer: Color(0xFFFFDFA0),
    error: Color(0xFFFF7A7A),
    outline: Color(0xFF4F7562),
    outlineVariant: Color(0xFF24463A),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: farben,
    scaffoldBackgroundColor: radarHintergrund,
    appBarTheme: const AppBarTheme(
      backgroundColor: radarHintergrund,
      foregroundColor: Color(0xFFE8F5EC),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE8F5EC)),
    ),
    cardTheme: CardThemeData(
      color: _karte,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: radarGruen.withValues(alpha: 0.18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF081A10),
      indicatorColor: radarGruen.withValues(alpha: 0.22),
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: radarGruen,
        foregroundColor: const Color(0xFF00210F),
        disabledBackgroundColor: const Color(0xFF1C3A2C),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _karte,
      selectedColor: radarGruen.withValues(alpha: 0.25),
      side: BorderSide(color: radarGruen.withValues(alpha: 0.35)),
      checkmarkColor: radarGruen,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _karte,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF1C3A2C)),
  );
}

class BierApp extends StatelessWidget {
  const BierApp({super.key, required this.zustand});
  final AppZustand zustand;

  @override
  Widget build(BuildContext context) {
    return ZustandScope(
      zustand: zustand,
      child: MaterialApp(
        title: 'Bierradar',
        debugShowCheckedModeBanner: false,
        theme: radarDesign(),
        home: const _Start(),
      ),
    );
  }
}

class _Start extends StatefulWidget {
  const _Start();

  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  bool _introVorbei = false;

  @override
  Widget build(BuildContext context) {
    final z = ZustandScope.of(context);
    final Widget inhalt;
    if (!_introVorbei || !z.geladen) {
      inhalt = Intro(key: const ValueKey('intro'), fertig: () => setState(() => _introVorbei = true));
    } else {
      inhalt = z.einrichtungFertig
          ? const Hauptseite(key: ValueKey('haupt'))
          : const Einrichtung(key: ValueKey('einrichtung'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: inhalt);
  }
}
